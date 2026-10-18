#!/usr/bin/env python3
"""Draw the island from the boxes the shipping law emitted.

Same discipline as the character sheets: this file re-implements nothing. Every
rectangle, radius, colour, opacity and font size comes out of
`tools/ui/layout_emit.swift`, which reads `LupyIslandLayout` / `LupyGlass` /
`LupyPalette` — the code the app runs. LUPY himself is drawn by `scene.py` from the
rig's emitted geometry. If a pixel here is wrong, the law is wrong.

The one thing this file *does* add is the desktop behind the glass, because that is the
whole point of proving the glass: a floating panel is only readable if it is readable
over a white document AND a black terminal. So each island is composited over a real
backdrop — blurred, saturation-boosted, then tinted — exactly as the recipe says.

Usage:
    node --no-warnings tools/swiftwasm/swiftc-wasm.mjs --run \
        Mac/Sources/Lupy/Character/LupyGeometry.swift \
        Mac/Sources/Lupy/Character/LupyCharacterMath.swift \
        Mac/Sources/Lupy/UI/LupyIslandDesign.swift \
        tools/ui/layout_emit.swift > /tmp/island_layout.txt
    node --no-warnings tools/swiftwasm/swiftc-wasm.mjs --run \
        Mac/Sources/Lupy/Character/LupyGeometry.swift \
        Mac/Sources/Lupy/Character/LupyCharacterMath.swift \
        tools/character/rig_states.swift > /tmp/states.txt
    python3 tools/ui/render_island.py
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "character"))

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont  # noqa: E402
from render_rig_states import parse as parse_rig                        # noqa: E402
from scene import draw_character                                        # noqa: E402

REG = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
MONO = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"

SS = 3            # supersample: the founder called an early render "pixelated"
LAYOUT = "/tmp/island_layout.txt"
RIG = "/tmp/states.txt"
OUT = os.path.join(HERE, "..", "..", "docs", "concepts")


# --------------------------------------------------------------------- the emitted law

def parse_layout(path):
    """Read the emitter's lines. Nothing is defaulted: a missing field is a bug."""
    doc = {"type": {}, "glass": {}, "colour": {}, "behind": {}, "metric": {},
           "contrast": {}, "canvases": []}
    cur = None
    for raw in open(path):
        line = raw.rstrip("\n")
        p = line.split()
        if not p or p[0].startswith("#"):
            continue
        k = p[0]
        if k == "TYPE":
            for i in range(1, len(p), 2):
                doc["type"][p[i]] = float(p[i + 1])
        elif k == "GLASS":
            doc["glass"][p[1]] = dict(
                base=(float(p[2]), float(p[3]), float(p[4])), alpha=float(p[5]),
                blur=float(p[6]), sat=float(p[7]), hairline=float(p[8]),
                shadow_a=float(p[9]), shadow_r=float(p[10]), shadow_y=float(p[11]))
        elif k == "COLOUR":
            doc["colour"][p[1]] = (float(p[2]), float(p[3]), float(p[4]))
        elif k == "BEHIND":
            doc["behind"][p[1]] = (float(p[2]), float(p[3]), float(p[4]))
        elif k == "METRIC":
            for i in range(1, len(p), 2):
                doc["metric"][p[i]] = float(p[i + 1])
        elif k == "CONTRAST":
            for i in range(1, len(p), 2):
                doc["contrast"][p[i]] = float(p[i + 1])
        elif k == "CANVAS":
            cur = {"id": p[1], "boxes": {}, "lines": [], "chips": [],
                   "headline": "", "provenance": "", "legal": []}
            doc["canvases"].append(cur)
        elif k == "NEED":
            cur["need"] = " ".join(p[1:])
        elif k == "STATE":
            cur["state"] = p[1]
        elif k == "FRAME":
            cur["w"], cur["h"], cur["corner"] = float(p[1]), float(p[2]), float(p[3])
        elif k == "SURFACE":
            cur["surface"] = p[1]
        elif k == "BOX":
            cur["boxes"][p[1]] = tuple(float(x) for x in p[2:6])
        elif k == "GLOW":
            cur["glow"] = (float(p[1]), float(p[2]), float(p[3]), float(p[4]))
        elif k == "TEXT":
            if p[1] == "HEADLINE":
                cur["headline"] = " ".join(p[2:])
            elif p[1] == "LINE":
                cur["lines"].append(" ".join(p[2:]))
            elif p[1] == "CHIP":
                cur["chips"].append(" ".join(p[2:]))
            elif p[1] == "PROVENANCE":
                cur["provenance"] = " ".join(p[2:])
        elif k == "LEGAL":
            cur["legal"].append(" ".join(p[1:]))
    return doc


def rgb(t):
    return tuple(int(round(c * 255)) for c in t[:3])


# --------------------------------------------------------------------- the desktop

def wallpaper(w, h, kind, seed=7):
    """A desktop worth floating glass over: colour that the blur can smear, and
    structure that the saturation boost can show up. Not a flat fill — a flat fill
    would prove nothing about a translucent panel."""
    if kind == "bright":
        img = Image.new("RGB", (w, h), (248, 248, 251))
        blobs = [(0.18, 0.30, 0.42, (255, 214, 170)), (0.72, 0.22, 0.34, (178, 216, 255)),
                 (0.50, 0.78, 0.46, (206, 240, 214)), (0.88, 0.70, 0.30, (255, 190, 220))]
        ink = (214, 216, 224)
    else:
        img = Image.new("RGB", (w, h), (9, 10, 15))
        blobs = [(0.20, 0.28, 0.40, (24, 78, 148)), (0.74, 0.24, 0.34, (96, 44, 148)),
                 (0.48, 0.80, 0.44, (16, 96, 78)), (0.86, 0.68, 0.28, (140, 40, 70))]
        ink = (30, 33, 42)
    d = ImageDraw.Draw(img)
    for fx, fy, fr, col in blobs:
        cx, cy, r = fx * w, fy * h, fr * min(w, h)
        layer = Image.new("RGB", (w, h), col)
        mask = Image.new("L", (w, h), 0)
        ImageDraw.Draw(mask).ellipse([cx - r, cy - r, cx + r, cy + r], fill=150)
        mask = mask.filter(ImageFilter.GaussianBlur(r * 0.5))
        img.paste(layer, (0, 0), mask)
    # document/terminal lines: structure the blur will soften but not erase
    d = ImageDraw.Draw(img)
    y = int(h * 0.08)
    i = 0
    while y < h * 0.95:
        lw = int(w * (0.30 + 0.42 * abs(math.sin(i * 1.7 + seed))))
        d.rectangle([int(w * 0.06), y, int(w * 0.06) + lw, y + max(2, h // 220)], fill=ink)
        y += max(8, h // 42)
        i += 1
    return img


# --------------------------------------------------------------------- glass

def rounded_mask(size, box, corner, ss):
    x, y, w, h = [v * ss for v in box]
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([x, y, x + w, y + h], radius=corner * ss, fill=255)
    return m


def paste_glass(img, box, corner, glass, ss, shadow=True):
    """The recipe, literally: soft shadow, backdrop blur + saturation boost, tint at the
    derived alpha, 1px hairline. `box` is (x, y, w, h) in points, island-relative."""
    W, H = img.size
    x, y, w, h = [v * ss for v in box]
    rect = [int(x), int(y), int(x + w), int(y + h)]
    r = corner * ss

    if shadow:
        sm = Image.new("L", (W, H), 0)
        ImageDraw.Draw(sm).rounded_rectangle(
            [rect[0], rect[1] + glass["shadow_y"] * ss,
             rect[2], rect[3] + glass["shadow_y"] * ss],
            radius=r, fill=int(glass["shadow_a"] * 255))
        sm = sm.filter(ImageFilter.GaussianBlur(glass["shadow_r"] * ss * 0.6))
        img.paste(Image.new("RGB", (W, H), (0, 0, 0)), (0, 0), sm)

    # backdrop: what is really behind the panel, blurred and pushed — this is the step
    # that separates glass from a flat translucent rectangle
    back = img.crop(rect).convert("RGB")
    back = back.filter(ImageFilter.GaussianBlur(max(0.4, glass["blur"] * ss * 0.32)))
    back = ImageEnhance.Color(back).enhance(glass["sat"])
    back = ImageEnhance.Brightness(back).enhance(0.97)

    # tint at the derived alpha, then clip the whole thing to the rounded shape
    tint = Image.new("RGBA", back.size,
                     rgb(glass["base"]) + (int(glass["alpha"] * 255),))
    panel = Image.alpha_composite(back.convert("RGBA"), tint).convert("RGB")
    mask = Image.new("L", back.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, back.size[0] - 1, back.size[1] - 1],
                                           radius=r, fill=255)
    img.paste(panel, (rect[0], rect[1]), mask)

    # hairline: white at the recipe's alpha, one physical pixel-ish
    hm = Image.new("L", (W, H), 0)
    ImageDraw.Draw(hm).rounded_rectangle(rect, radius=r,
                                         outline=int(glass["hairline"] * 255),
                                         width=max(1, int(ss * 0.7)))
    img.paste(Image.new("RGB", (W, H), (255, 255, 255)), (0, 0), hm)
    return img


def draw_island(doc, canvas, rig, kind, pp, margin=0):
    """One island, on one desktop. Returns an RGB image at pp×SS pixels per point."""
    ss = SS * pp
    w, h, corner = canvas["w"], canvas["h"], canvas["corner"]
    W, H = int((w + 2 * margin) * ss), int((h + 2 * margin) * ss)

    img = wallpaper(W, H, kind)

    g = doc["glass"]["panel"]
    box = (margin, margin, w, h)
    paste_glass(img, box, corner, g, ss)

    d = ImageDraw.Draw(img)
    ox, oy = margin * ss, margin * ss

    def P(bx, by):
        return (ox + bx * ss, oy + by * ss)

    boxes = canvas["boxes"]
    content = boxes.get("content")
    composer = boxes.get("composer")
    status = boxes.get("status")
    avatar = boxes.get("avatar")

    # ---- the card, on its own lifted glass
    if content and content[2] > 0:
        card = doc["glass"]["card"]
        paste_glass(img, (margin + content[0], margin + content[1], content[2], content[3]),
                    16, card, ss, shadow=False)
        d = ImageDraw.Draw(img)

    # ---- the status sentence, in the one home the law gave it
    if status and status[2] > 0 and canvas["surface"] in ("headline", "whisper"):
        size = doc["type"]["headline"] if canvas["surface"] == "headline" else doc["type"]["peek"]
        f = ImageFont.truetype(BOLD, max(6, int(size * ss)))
        text = canvas["headline"]
        tx, ty = P(status[0], status[1])
        avail = status[2] * ss - 2 * ss
        text = fit(text, f, avail, d)
        d.text((tx + ss, ty + (status[3] * ss - f.size) / 2), text,
               font=f, fill=rgb(doc["colour"]["primary"]))
        # his light under the sentence: the state's own colour, faint, never a second hue
        glow = canvas.get("glow")
        if glow and canvas["surface"] == "headline":
            gm = Image.new("L", img.size, 0)
            ImageDraw.Draw(gm).ellipse(
                [tx - 30 * ss, ty - 6 * ss, tx + 60 * ss, ty + status[3] * ss + 6 * ss], fill=60)
            gm = gm.filter(ImageFilter.GaussianBlur(18 * ss))
            img.paste(Image.new("RGB", img.size, rgb(glow)), (0, 0), gm)
            d = ImageDraw.Draw(img)
            d.text((tx + ss, ty + (status[3] * ss - f.size) / 2), text,
                   font=f, fill=rgb(doc["colour"]["primary"]))

    # ---- the card's rows
    rows_drawn = 0
    if content and content[2] > 0 and canvas["lines"]:
        m = doc["metric"]
        top = status[1] + status[3] + m["inner"] if status else content[1]
        body_f = ImageFont.truetype(REG, max(6, int(doc["type"]["body"] * ss)))
        mono_f = ImageFont.truetype(MONO, max(6, int(doc["type"]["body"] * ss)))
        # The provenance line is a row of its own at its own size — the law measured it
        # as a row, so the picture must too, or the card gets dead space.
        PROV_F = ImageFont.truetype(REG, max(6, int(doc["type"]["provenance"] * ss)))
        MONO_F = mono_f
        y = top
        rows = list(canvas["lines"]) + ([canvas["provenance"]] if canvas["provenance"] else [])
        for i, line in enumerate(rows):
            f = (MONO_F if line.startswith("  ") else body_f) if i < len(canvas["lines"]) \
                else PROV_F
            tx, ty = P(content[0], y)
            d.text((tx + ss, ty + (m["row"] * ss - f.size) / 2),
                   fit(line, f, content[2] * ss - 4 * ss, d), font=f,
                   fill=rgb(doc["colour"]["body"]))
            y += m["row"]
            if i < len(rows) - 1:
                y += m["inner"]
            rows_drawn += 1
        rows_bottom = y
        # The law's own arithmetic, repeated here as a check, not as a layout source:
        # the rows must end inside the card, and the chip row must end exactly at the
        # card's bottom edge. If these drift, the law and the picture disagree.
        card_bottom = content[1] + content[3]
        if rows_bottom > card_bottom + 0.6:
            print(f"  ! {canvas['id']}: {rows_drawn} rows end at {rows_bottom:.1f} but the "
                  f"card ends at {card_bottom:.1f} — the law under-measured the card")
        chip_y = (card_bottom - m["chip"]) if canvas["chips"] else None
        canvas["_chip_y"] = chip_y
        canvas["_scrolls"] = rows_bottom > card_bottom + 0.6

    # ---- quick-reply chips
    if canvas["chips"] and content:
        # Chip layout runs entirely in POINTS, converting to pixels only when drawing.
        # Mixing the two is the bug this renderer has already been bitten by once: a
        # pixel width tested against a point limit passes at one scale and silently
        # drops every chip at another.
        m = doc["metric"]
        cy = canvas.get("_chip_y") or (composer[1] - m["chip"] - m["inner"] if composer else content[3])
        cx = content[0]
        cf = ImageFont.truetype(BOLD, max(6, int(doc["type"]["chip"] * ss)))
        pad_x = 10.0
        for ch in canvas["chips"]:
            tw_pt = d.textlength(ch, font=cf) / ss
            cw_pt = tw_pt + 2 * pad_x
            if cx + cw_pt > content[0] + content[2]:
                break
            x0, y0 = P(cx, cy)
            rect = [x0, y0, x0 + cw_pt * ss, y0 + m["chip"] * ss]
            accent = doc["colour"]["accent"]
            d.rounded_rectangle(rect, radius=m["chip"] * ss * 0.36,
                                fill=tuple(int(c * 255 * 0.24) for c in accent),
                                outline=tuple(int(c * 255 * 0.55) for c in accent),
                                width=max(1, int(ss * 0.6)))
            d.text((x0 + pad_x * ss, y0 + (m["chip"] * ss - cf.size) / 2), ch,
                   font=cf, fill=rgb(doc["colour"]["primary"]))
            cx += cw_pt + 8

    # ---- the composer: mic + field, the only permanent control
    if composer and composer[2] > 0:
        m = doc["metric"]
        fx, fy = P(composer[0], composer[1])
        fw, fh = composer[2] * ss, composer[3] * ss
        # The field is glass like everything else. A transparent field lets a white
        # desktop through and turns the island's one permanent control into a white bar
        # with unreadable text — exactly what the glass proof is here to catch.
        field = (composer[0] + 2, composer[1] + composer[3] * 0.06,
                 composer[2] - 4, composer[3] * 0.88)
        paste_glass(img, field, composer[3] * 0.44, doc["glass"]["card"], ss, shadow=False)
        d = ImageDraw.Draw(img)
        # mic, in the tone the law allows for icons (never for words)
        mx, my = fx + fh * 0.52, fy + fh * 0.50
        mr = fh * 0.155
        icon = rgb(doc["colour"]["icon"])
        d.rounded_rectangle([mx - mr * 0.42, my - mr * 1.15, mx + mr * 0.42, my + mr * 0.35],
                            radius=mr * 0.42, fill=icon)
        d.arc([mx - mr * 0.85, my - mr * 0.75, mx + mr * 0.85, my + mr * 0.95],
              start=0, end=180, fill=icon, width=max(1, int(mr * 0.30)))
        d.line([mx, my + mr * 0.95, mx, my + mr * 1.45], fill=icon, width=max(1, int(mr * 0.30)))
        # the field's own text is body text, so it takes a colour that clears AA
        pf = ImageFont.truetype(REG, max(6, int(doc["type"]["body"] * ss)))
        d.text((mx + mr * 2.4, fy + fh * 0.5 - pf.size * 0.5),
               "Ask LUPY anything…", font=pf, fill=rgb(doc["colour"]["body"]))
        # send
        sf = ImageFont.truetype(BOLD, max(6, int(doc["type"]["chip"] * ss)))
        label = "↵"
        sw = d.textlength(label, font=sf) + 16 * ss
        srect = (fx + fw - sw - fh * 0.16, fy + fh * 0.18,
                 fx + fw - fh * 0.16, fy + fh * 0.82)
        d.rounded_rectangle(srect, radius=(srect[3] - srect[1]) * 0.32,
                            fill=rgb(doc["colour"]["accent"]))
        d.text((srect[0] + 8 * ss, srect[1] + (srect[3] - srect[1] - sf.size) / 2), label,
               font=sf, fill=(6, 10, 18))

    # ---- LUPY, last, so his light sits on top of everything
    if avatar and avatar[2] > 0:
        st = dict(rig[canvas["state"]])
        body_w = min(avatar[2], avatar[3]) * 0.72      # LupyComposition.unitFraction
        # the small-size law is the character's, not this renderer's: below 30 pt of body
        # the badge glyph has no room, so the island does not ask for one
        if body_w < 30:
            st["icon"] = "none"
        cx, cy = P(avatar[0] + avatar[2] / 2, avatar[1] + avatar[3] / 2)
        # The rig's polygon is in body-width units and already centred on (0, 0), so the
        # unit passed here IS the body width in pixels and the box centre is his centre.
        # No fitting maths of this renderer's own: that is how a picture starts lying.
        draw_character(img, st, body_w * ss, cx, cy, ss=1)

    return img


def fit(text, font, avail, d):
    """Truncate to the box the law gave, the way SwiftUI would."""
    if d.textlength(text, font=font) <= avail:
        return text
    while text and d.textlength(text + "…", font=font) > avail:
        text = text[:-1]
    return text.rstrip() + "…"


# --------------------------------------------------------------------- sheets

def sheet(doc, rig, ids, kind, pp, pad=26, title=None, note=None):
    canvases = [c for c in doc["canvases"] if c["id"] in ids]
    canvases.sort(key=lambda c: ids.index(c["id"]))
    tiles = [draw_island(doc, c, rig, kind, pp, margin=pad / (SS * pp) * 0.5) for c in canvases]
    lab = int(34 * pp)
    W = max(t.size[0] for t in tiles)
    H = sum(t.size[1] + lab for t in tiles) + (int(70 * pp) if title else 0)
    out = Image.new("RGB", (W, H), (13, 14, 18))
    d = ImageDraw.Draw(out)
    y = 0
    tf = ImageFont.truetype(BOLD, max(10, int(20 * pp)))
    nf = ImageFont.truetype(REG, max(9, int(14 * pp)))
    if title:
        d.text((14, int(14 * pp)), title, font=tf, fill=(226, 229, 236))
        if note:
            d.text((14, int(40 * pp)), note, font=nf, fill=(150, 156, 170))
        y = int(70 * pp)
    lf = ImageFont.truetype(REG, max(9, int(13 * pp)))
    for t, c in zip(tiles, canvases):
        out.paste(t, (0, y))
        y += t.size[1]
        bad = [l for l in c["legal"] if l != "yes"]
        tag = f"{c['id']}   {int(c['w'])}×{int(c['h'])} pt   r{int(c['corner'])}   " \
              f"{c['surface']}   {c['state']}   {'LEGAL' if not bad else 'ILLEGAL: ' + '; '.join(bad)}"
        d.text((14, y + int(8 * pp)), tag, font=lf,
               fill=(126, 200, 150) if not bad else (240, 120, 120))
        y += lab
    return out


def duo(doc, rig, ids, pp, pad=26, title=None, note=None):
    """The same island over a bright desktop and a dark one, side by side — the proof
    that the derived opacity is readable over both, which is the only claim that matters."""
    a = sheet(doc, rig, ids, "bright", pp, pad)
    b = sheet(doc, rig, ids, "dark", pp, pad)
    gap = int(28 * pp)
    head = int(64 * pp)
    out = Image.new("RGB", (a.size[0] + b.size[0] + gap,
                            max(a.size[1], b.size[1]) + head), (13, 14, 18))
    d = ImageDraw.Draw(out)
    tf = ImageFont.truetype(BOLD, max(10, int(19 * pp)))
    nf = ImageFont.truetype(REG, max(9, int(13 * pp)))
    c = doc["contrast"]
    if title:
        d.text((14, int(10 * pp)), title, font=tf, fill=(226, 229, 236))
    if note:
        d.text((14, int(34 * pp)), note, font=nf, fill=(150, 156, 170))
    d.text((14, head - int(22 * pp)), "over a WHITE document", font=nf, fill=(190, 195, 205))
    d.text((a.size[0] + gap + 14, head - int(22 * pp)), "over a BLACK terminal",
           font=nf, fill=(190, 195, 205))
    out.paste(a, (0, head))
    out.paste(b, (a.size[0] + gap, head))
    return out


def grid(doc, rig, pp, cols=3, pad=22):
    """Every surface the island has, at once. Columns are sized per column so a wide
    canvas does not leave a dead gutter next to a narrow one."""
    tiles = []
    for c in doc["canvases"]:
        tiles.append((draw_island(doc, c, rig, "dark", pp, margin=pad * 0.4), c))
    lab = int(24 * pp)
    colw = {}
    for i, (t, _) in enumerate(tiles):
        colw[i % cols] = max(colw.get(i % cols, 0), t.size[0])
    xs = {}
    x = 0
    for cix in range(cols):
        xs[cix] = x
        x += colw.get(cix, 0)
    rowh = {}
    for i, (t, _) in enumerate(tiles):
        rowh[i // cols] = max(rowh.get(i // cols, 0), t.size[1])
    ys = {}
    y = int(56 * pp)
    for r in sorted(rowh):
        ys[r] = y
        y += rowh[r] + lab
    out = Image.new("RGB", (x, y), (13, 14, 18))
    d = ImageDraw.Draw(out)
    tf = ImageFont.truetype(BOLD, max(9, int(17 * pp)))
    lf = ImageFont.truetype(REG, max(8, int(11 * pp)))
    d.text((12, int(10 * pp)), "every surface, one law", font=tf, fill=(226, 229, 236))
    d.text((12, int(30 * pp)),
           "size is computed from what the canvas must show — never a table of fixed heights",
           font=lf, fill=(150, 156, 170))
    for i, (t, c) in enumerate(tiles):
        cx, cy = xs[i % cols], ys[i // cols]
        out.paste(t, (cx + (colw[i % cols] - t.size[0]) // 2, cy))
        d.text((cx + 8, cy + rowh[i // cols] + int(5 * pp)),
               f"{c['id']}  {int(c['w'])}×{int(c['h'])}", font=lf, fill=(140, 146, 160))
    return out


def main():
    doc = parse_layout(LAYOUT)
    rig = {s["name"]: s for s in parse_rig(RIG)}
    os.makedirs(OUT, exist_ok=True)

    print(f"{len(doc['canvases'])} canvases, {len(rig)} rig frames")
    print(f"panel glass: base {rgb(doc['glass']['panel']['base'])} "
          f"alpha {doc['glass']['panel']['alpha']:.3f} blur {doc['glass']['panel']['blur']}")
    print(f"contrast: primary {doc['contrast']['primary_bright']:.2f}:1 bright / "
          f"{doc['contrast']['primary_dark']:.2f}:1 dark; "
          f"body {doc['contrast']['body_bright']:.2f}:1 / {doc['contrast']['body_dark']:.2f}:1")

    a = duo(doc, rig, ["rest", "whisper", "decision"], 1.15,
            title="the glass, over both desktops it can float on",
            note=f"opacity is derived, not chosen — body text clears WCAG AA "
                 f"({doc['contrast']['body_bright']:.2f}:1 bright, "
                 f"{doc['contrast']['body_dark']:.2f}:1 dark) and "
                 f"{100 * (1 - doc['glass']['panel']['alpha']):.0f}% of the desktop still comes through")
    pa = os.path.join(OUT, "lupy-island-glass.png")
    a.save(pa)
    print(f"wrote {pa}  {a.size[0]}x{a.size[1]}")

    b = sheet(doc, rig, ["rest", "whisper", "decision", "task"], "dark", 1.5,
              title="the canvas grows per need",
              note="avatar-first · the composer is the only permanent control · one status sentence, one home")
    b2 = sheet(doc, rig, ["answer", "chat", "question", "error", "transcript"], "dark", 1.5)
    pb = os.path.join(OUT, "lupy-island-canvas.png")
    b.save(pb)
    print(f"wrote {pb}  {b.size[0]}x{b.size[1]}")
    pb2 = os.path.join(OUT, "lupy-island-surfaces.png")
    b2.save(pb2)
    print(f"wrote {pb2}  {b2.size[0]}x{b2.size[1]}")

    c = grid(doc, rig, 0.85, cols=3)
    pc = os.path.join(OUT, "lupy-island-all.png")
    c.save(pc)
    print(f"wrote {pc}  {c.size[0]}x{c.size[1]}")


if __name__ == "__main__":
    main()
