#!/usr/bin/env python3
"""Draw the island the way it will actually appear: hanging from the menu bar, over a
real desktop, with real controls.

Discipline unchanged: every rectangle, radius, colour, opacity and font size comes out
of `tools/ui/layout_emit.swift`, which reads the shipping law (`LupyIslandDesign.swift`).
LUPY himself is drawn by `scene.py` from the rig's emitted geometry. This file adds only
what the law does not own — the desktop behind, the menu bar above, and the *craft* of
the controls (gradients, highlights, shadows, icons) — because those are what make a
proof picture readable as a product rather than as a wireframe.

Anything drawn here that the law owns is a bug: the layout emit is the single source.

Usage:
    node --no-warnings tools/swiftwasm/swiftc-wasm.mjs --run \\
        Mac/Sources/Lupy/Character/LupyGeometry.swift \\
        Mac/Sources/Lupy/Character/LupyCharacterMath.swift \\
        Mac/Sources/Lupy/UI/LupyIslandDesign.swift \\
        tools/ui/layout_emit.swift > /tmp/island_layout.txt
    node --no-warnings tools/swiftwasm/swiftc-wasm.mjs --run \\
        Mac/Sources/Lupy/Character/LupyGeometry.swift \\
        Mac/Sources/Lupy/Character/LupyCharacterMath.swift \\
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

# Inter: the free Google-metric stand-in for SF Pro (same proportions, open licence).
# The shipping app uses the native system font; proofs use Inter so the pictures tell
# the truth about size and weight. Weights map to HIG roles, not to moods.
_F = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fonts")
REG = os.path.join(_F, "Inter-Regular.ttf")     # body, meta
MED = os.path.join(_F, "Inter-Medium.ttf")       # chip labels, whisper line
SEMI = os.path.join(_F, "Inter-SemiBold.ttf")    # emphasized body
BOLD = os.path.join(_F, "Inter-Bold.ttf")        # HIG "Headline": 13 Bold
MONO = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"

SS = 3                      # supersample: the founder called an early render "pixelated"
MENUBAR = 24   # HIG: the menu bar is 24 pt on every non-notch Mac                # pt, the macOS menu bar the island hangs from
LAYOUT = "/tmp/island_layout.txt"
RIG = "/tmp/states.txt"
OUT = os.path.join(HERE, "..", "..", "docs", "concepts")


# --------------------------------------------------------------------- the emitted law

def parse_layout(path):
    doc = {"type": {}, "glass": {}, "colour": {}, "behind": {}, "metric": {},
           "contrast": {}, "canvases": []}
    cur = None
    for raw in open(path):
        p = raw.split()
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
                   "headline": "", "provenance": "", "meta": "", "legal": []}
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
            elif p[1] == "META":
                cur["meta"] = " ".join(p[2:])
        elif k == "LEGAL":
            cur["legal"].append(" ".join(p[1:]))
    return doc


def rgb(t):
    return tuple(int(round(c * 255)) for c in t[:3])


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def irgb(t):
    """mix() works in floats; PIL wants integers. Forgetting this is a TypeError, not a
    slightly wrong colour — which is the kinder failure of the two."""
    return tuple(int(round(v)) for v in t)


# --------------------------------------------------------------------- the desktop

def desktop(w, h, kind, seed=3):
    """A believable desktop: wallpaper, one open window with chrome, and — for the light
    case — a document. The glass needs something true behind it or the proof is a lie."""
    if kind == "bright":
        top, bot = (232, 236, 244), (206, 214, 228)
        win_bg, win_bar, win_ink = (250, 250, 252), (236, 237, 241), (196, 200, 210)
        accent_blob = (255, 208, 168)
    else:
        top, bot = (16, 18, 28), (8, 9, 14)
        win_bg, win_bar, win_ink = (24, 26, 34), (32, 34, 44), (44, 48, 60)
        accent_blob = (30, 70, 130)
    img = Image.new("RGB", (w, h), top)
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        d.line([(0, y), (w, y)], fill=irgb(mix(top, bot, t)))
    # two soft colour fields, so the blur has colour to smear
    for fx, fy, fr, col in [(0.22, 0.30, 0.55, accent_blob),
                            (0.82, 0.62, 0.50, irgb(mix(accent_blob, (120, 60, 140), 0.5)))]:
        layer = Image.new("RGB", (w, h), col)
        mask = Image.new("L", (w, h), 0)
        ImageDraw.Draw(mask).ellipse([fx * w - fr * w, fy * h - fr * w,
                                      fx * w + fr * w, fy * h + fr * w], fill=120)
        mask = mask.filter(ImageFilter.GaussianBlur(fr * w * 0.4))
        img.paste(layer, (0, 0), mask)
    # one window behind the island: chrome, traffic lights, code
    wx, wy = int(w * 0.10), int(h * 0.30)
    ww, wh = int(w * 0.62), int(h * 0.62)
    d = ImageDraw.Draw(img)
    sh = Image.new("L", (w, h), 0)
    ImageDraw.Draw(sh).rounded_rectangle([wx, wy + 8, wx + ww, wy + wh + 8], 12, fill=90)
    sh = sh.filter(ImageFilter.GaussianBlur(14))
    img.paste(Image.new("RGB", (w, h), (0, 0, 0)), (0, 0), sh)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([wx, wy, wx + ww, wy + wh], 12, fill=win_bg)
    d.rounded_rectangle([wx, wy, wx + ww, wy + 30], 12, fill=win_bar)
    d.rectangle([wx, wy + 18, wx + ww, wy + 30], fill=win_bar)
    for i, c in enumerate([(255, 95, 86), (255, 189, 46), (39, 201, 63)]):
        d.ellipse([wx + 12 + i * 20, wy + 9, wx + 24 + i * 20, wy + 21], fill=c)
    y = wy + 46
    i = 0
    while y < wy + wh - 16:
        lw = int(ww * (0.18 + 0.55 * abs(math.sin(i * 2.3 + seed))))
        d.rectangle([wx + 18, y, wx + 18 + lw, y + 6], fill=win_ink)
        y += 16
        i += 1
    return img


def menu_bar(w, ss, kind, notch_w):
    """The macOS menu bar, with the notch the island hangs from."""
    h = int(MENUBAR * ss)
    bar = Image.new("RGB", (w, h), (246, 247, 250) if kind == "bright" else (18, 19, 24))
    d = ImageDraw.Draw(bar)
    f = ImageFont.truetype(BOLD, int(13 * ss))
    fr = ImageFont.truetype(REG, int(12 * ss))
    ink = (30, 32, 40) if kind == "bright" else (226, 228, 234)
    d.text((int(14 * ss), (h - f.size) // 2), "", font=f, fill=ink)
    # apple-ish mark + app name, left of the notch
    d.ellipse([int(14 * ss), int(7 * ss), int(26 * ss), int(19 * ss)], fill=ink)
    d.text((int(32 * ss), (h - f.size) // 2), "Lupy", font=f, fill=ink)
    for i, m in enumerate(["File", "Edit", "View", "Help"]):
        d.text((int((74 + i * 40) * ss), (h - fr.size) // 2), m, font=fr, fill=ink)
    # right-hand status items
    x = w - int(14 * ss)
    for m in ["100%", "Wi-Fi", "Mon 09:41"]:
        tw = d.textlength(m, font=fr)
        d.text((x - tw, (h - fr.size) // 2), m, font=fr, fill=ink)
        x -= int(tw + 16 * ss)
    # the notch: black, centred, the island's home
    nw = int(notch_w * ss)
    d.rounded_rectangle([(w - nw) // 2, -int(6 * ss), (w + nw) // 2, h],
                        radius=int(10 * ss), fill=(0, 0, 0))
    return bar


# --------------------------------------------------------------------- glass + controls

def rounded_mask(size, rect, radius, ss=None, width=None):
    m = Image.new("L", size, 0)
    if width:
        ImageDraw.Draw(m).rounded_rectangle(rect, radius=radius, outline=255, width=width)
    else:
        ImageDraw.Draw(m).rounded_rectangle(rect, radius=radius, fill=255)
    return m


def paste_glass(img, box, corner, glass, ss, shadow=True, highlight=True):
    """The recipe: soft shadow, blurred+saturated backdrop, tint at the derived alpha,
    hairline, and a directional top highlight — light comes from above, so the top edge
    catches it and the bottom does not."""
    W, H = img.size
    x, y, w, h = [v * ss for v in box]
    rect = [int(x), int(y), int(x + w), int(y + h)]
    r = corner * ss

    if shadow:
        sm = Image.new("L", (W, H), 0)
        ImageDraw.Draw(sm).rounded_rectangle(
            [rect[0], rect[1] + glass["shadow_y"] * ss, rect[2], rect[3] + glass["shadow_y"] * ss],
            radius=r, fill=int(glass["shadow_a"] * 255))
        sm = sm.filter(ImageFilter.GaussianBlur(glass["shadow_r"] * ss * 0.6))
        img.paste(Image.new("RGB", (W, H), (0, 0, 0)), (0, 0), sm)

    back = img.crop(rect).convert("RGB")
    back = back.filter(ImageFilter.GaussianBlur(max(0.4, glass["blur"] * ss * 0.32)))
    back = ImageEnhance.Color(back).enhance(glass["sat"])
    back = ImageEnhance.Brightness(back).enhance(0.97)
    tint = Image.new("RGBA", back.size, rgb(glass["base"]) + (int(glass["alpha"] * 255),))
    panel = Image.alpha_composite(back.convert("RGBA"), tint).convert("RGB")

    if highlight:
        # directional light: a bright hairline just inside the top edge, fading by 40%
        hl = Image.new("L", back.size, 0)
        hd = ImageDraw.Draw(hl)
        hh = max(2, int(back.size[1] * 0.16))
        for i in range(hh):
            a = int(11 * (1 - i / hh))
            hd.line([(int(r * 0.6), i), (back.size[0] - int(r * 0.6), i)], fill=a)
        hl = hl.filter(ImageFilter.GaussianBlur(ss * 0.5))
        panel.paste(Image.new("RGB", back.size, (255, 255, 255)), (0, 0), hl)

    mask = Image.new("L", back.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, back.size[0] - 1, back.size[1] - 1],
                                           radius=r, fill=255)
    img.paste(panel, (rect[0], rect[1]), mask)

    hm = Image.new("L", (W, H), 0)
    ImageDraw.Draw(hm).rounded_rectangle(rect, radius=r, outline=int(glass["hairline"] * 255),
                                         width=max(1, int(ss * 0.7)))
    img.paste(Image.new("RGB", (W, H), (255, 255, 255)), (0, 0), hm)
    return img


def button(img, rect, ss, label, font, kind, accent, ink_text, body_text, radius=None):
    """A macOS button: flat fill, one hairline on the glass variant, no gradient,
    no gloss, no shadow. Sequoia controls are quiet; the proof must be too."""
    x0, y0, x1, y1 = [int(v) for v in rect]
    w, h = x1 - x0, y1 - y0
    rad = radius if radius is not None else int(h / 2)
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    if kind == "primary":
        ld.rounded_rectangle([0, 0, w - 1, h - 1], rad, fill=rgb(accent) + (255,))
    else:
        ld.rounded_rectangle([0, 0, w - 1, h - 1], rad, fill=(255, 255, 255, 23))
        ld.rounded_rectangle([0, 0, w - 1, h - 1], rad,
                             outline=(255, 255, 255, 31), width=max(1, int(ss * 0.5)))
    img.paste(layer.convert("RGB"), (x0, y0), layer.split()[3])
    if label:
        d = ImageDraw.Draw(img)
        tw = d.textlength(label, font=font)
        d.text((x0 + (w - tw) / 2, y0 + (h - font.size) / 2), label, font=font,
               fill=ink_text if kind == "primary" else body_text)
    return img


def icon_mic(d, cx, cy, s, color, ss):
    """SF Symbols' mic, stroke-drawn: capsule body, cradle arc, stem, base."""
    wdt = max(1, int(round(1.5 * ss)))
    d.rounded_rectangle([cx - 0.17 * s, cy - 0.44 * s, cx + 0.17 * s, cy + 0.06 * s],
                        radius=0.17 * s, outline=color, width=wdt)
    d.arc([cx - 0.34 * s, cy - 0.22 * s, cx + 0.34 * s, cy + 0.30 * s], 0, 180,
          fill=color, width=wdt)
    d.line([cx, cy + 0.30 * s, cx, cy + 0.46 * s], fill=color, width=wdt)
    d.line([cx - 0.16 * s, cy + 0.46 * s, cx + 0.16 * s, cy + 0.46 * s],
           fill=color, width=wdt)


def icon_return(d, cx, cy, s, color, ss):
    """SF Symbols' return.left: shaft, chevron head, tail dropping at the right."""
    wdt = max(1, int(round(1.6 * ss)))
    d.line([cx - 0.28 * s, cy - 0.16 * s, cx + 0.34 * s, cy - 0.16 * s],
           fill=color, width=wdt)
    d.line([cx - 0.10 * s, cy - 0.36 * s, cx - 0.30 * s, cy - 0.16 * s,
            cx - 0.10 * s, cy + 0.04 * s], fill=color, width=wdt, joint="curve")
    d.line([cx + 0.34 * s, cy - 0.16 * s, cx + 0.34 * s, cy + 0.10 * s],
           fill=color, width=wdt)
    d.arc([cx + 0.10 * s, cy + 0.10 * s, cx + 0.58 * s, cy + 0.58 * s], 180, 270,
          fill=color, width=wdt)
    d.line([cx + 0.10 * s, cy + 0.34 * s, cx - 0.10 * s, cy + 0.34 * s],
           fill=color, width=wdt)


def scene_width_pt(canvas):
    """The screen width, in points, this canvas wants when drawn alone."""
    return int(canvas["w"]) + 52


def draw_scene(doc, canvas, rig, kind, pp, context=True, below=26, min_w=None):
    """One island, hanging from a menu bar over a desktop. Returns RGB at pp*SS px/pt.
    min_w (points) lets a sheet share one screen width, so every row's menu bar
    runs edge to edge instead of being chopped to the island's own width."""
    ss = SS * pp
    w, h, corner = canvas["w"], canvas["h"], canvas["corner"]
    side = 26
    if min_w and w + 2 * side < min_w:
        side += (min_w - (w + 2 * side)) // 2
    top = MENUBAR if context else 0
    W = int((w + 2 * side) * ss)
    H = int((top + h + below) * ss)

    img = desktop(W, H, kind)
    if context:
        bar = menu_bar(W, ss, kind, min(w, 210))
        img.paste(bar, (0, 0))

    oy = top
    g = doc["glass"]["panel"]
    paste_glass(img, (side, oy, w, h), corner, g, ss)
    d = ImageDraw.Draw(img)

    def P(bx, by):
        return ((side + bx) * ss, (oy + by) * ss)

    boxes = canvas["boxes"]
    content, composer = boxes.get("content"), boxes.get("composer")
    status, avatar = boxes.get("status"), boxes.get("avatar")
    m = doc["metric"]
    col = doc["colour"]
    body_text = rgb(col["body"])
    primary = rgb(col["primary"])
    ink_text = (7, 10, 16)

    # Divider under the headline row: structure without a box. macOS groups with
    # hairlines and spacing; the card's glass frame is gone on purpose.
    if content and content[2] > 0 and status and status[2] > 0:
        d = ImageDraw.Draw(img)
        dy = (oy + status[1] + status[3]) * ss
        d.line([P(content[0] + m["inner"], 0)[0], dy,
                P(content[0] + content[2] - m["inner"], 0)[0], dy],
               fill=rgb(mix(col["line"], (0, 0, 0), 0.45)),
               width=max(1, int(ss * 0.5)))

    # ---- headline row: the sentence left, the card's meta right
    if status and status[2] > 0 and canvas["surface"] in ("headline", "whisper"):
        size = doc["type"]["headline"] if canvas["surface"] == "headline" else doc["type"]["peek"]
        wf = BOLD if canvas["surface"] == "headline" else SEMI
        f = ImageFont.truetype(wf, max(6, int(size * ss)))
        tx, ty = P(status[0] + m["inner"], status[1])
        share = 0.62 if canvas["meta"] else 0.98
        text = fit(canvas["headline"], f, (status[2] - 2 * m["inner"]) * ss * share, d)
        # his light, faint, behind the sentence — the state's own colour only
        glow = canvas.get("glow")
        if glow and canvas["surface"] == "headline":
            gm = Image.new("L", img.size, 0)
            ImageDraw.Draw(gm).ellipse([tx - 26 * ss, ty - 4 * ss,
                                        tx + 70 * ss, ty + status[3] * ss + 4 * ss], fill=52)
            gm = gm.filter(ImageFilter.GaussianBlur(14 * ss))
            img.paste(Image.new("RGB", img.size, rgb(glow)), (0, 0), gm)
            d = ImageDraw.Draw(img)
        d.text((tx + ss, ty + (status[3] * ss - f.size) / 2), text, font=f, fill=primary)
        if canvas["meta"]:
            mf = ImageFont.truetype(REG, max(6, int(doc["type"]["provenance"] * ss)))
            mtw = d.textlength(canvas["meta"], font=mf)
            d.text((P(status[0] + status[2] - m["inner"], 0)[0] - mtw,
                    ty + (status[3] * ss - mf.size) / 2), canvas["meta"], font=mf,
                   fill=body_text)

    # ---- card rows
    if content and content[2] > 0 and canvas["lines"]:
        body_f = ImageFont.truetype(REG, max(6, int(doc["type"]["body"] * ss)))
        mono_f = ImageFont.truetype(MONO, max(6, int(doc["type"]["body"] * ss)))
        prov_f = ImageFont.truetype(REG, max(6, int(doc["type"]["provenance"] * ss)))
        rows = list(canvas["lines"]) + ([canvas["provenance"]] if canvas["provenance"] else [])
        y = status[1] + status[3] + m["inner"] if status else content[1]
        for i, line in enumerate(rows):
            if i == len(canvas["lines"]):
                f = prov_f
                fill = rgb(mix(col["body"], col["icon"], 0.35))
            else:
                f = mono_f if line.startswith("  ") else body_f
                fill = body_text
            tx, ty = P(content[0] + m["inner"], y)
            d.text((tx, ty + (m["row"] * ss - f.size) / 2),
                   fit(line, f, (content[2] - 2 * m["inner"]) * ss, d), font=f, fill=fill)
            y += m["row"]
            if i < len(rows) - 1:
                y += m["inner"]
        chip_y = content[1] + content[3] - m["inner"] - m["chip"]
    else:
        chip_y = None

    # ---- chips: flat macOS buttons; shortcuts stay on the keyboard
    if canvas["chips"] and content and chip_y is not None:
        cf = ImageFont.truetype(MED, max(6, int(doc["type"]["chip"] * ss)))
        cx = content[0] + m["inner"]
        accent = col["accent"]
        for i, ch in enumerate(canvas["chips"]):
            label = ch
            # macOS dialog buttons never print their shortcut on the face; the
            # emitter's ⌘X / digit prefixes are for the rig, not for the button.
            if label[:2] in ("⌘Y", "⌘N"):
                label = label[2:]
            elif label[:1].isdigit():
                label = label[1:]
            padH = m["chipPadH"]
            tw = d.textlength(label, font=cf) / ss
            cw = tw + 2 * padH
            if cx + cw > content[0] + content[2] - m["inner"]:
                break
            x0, y0 = P(cx, chip_y)
            rect = [x0, y0, x0 + cw * ss, y0 + m["chip"] * ss]
            button(img, rect, ss, "", cf, "primary" if i == 0 else "glass",
                   accent, ink_text, body_text, radius=int(m["chipCorner"] * ss))
            d = ImageDraw.Draw(img)
            d.text((x0 + padH * ss, y0 + (m["chip"] * ss - cf.size) / 2), label,
                   font=cf, fill=ink_text if i == 0 else body_text)
            cx += cw + 8

    # ---- composer: one recessed field, bare glyphs, no shapes of their own
    if composer and composer[2] > 0:
        fx, fy = P(composer[0], composer[1])
        fw, fh = composer[2] * ss, composer[3] * ss
        box = [fx + ss * 0.5, fy + ss * 0.5, fx + fw - ss * 0.5, fy + fh - ss * 0.5]
        rad = m["fieldCorner"] * ss
        ov = Image.new("RGB", img.size, (0, 0, 0))
        msk = Image.new("L", img.size, 0)
        ImageDraw.Draw(msk).rounded_rectangle(box, rad, fill=56)   # black at 22 %
        img.paste(ov, (0, 0), msk)
        d = ImageDraw.Draw(img)
        # a hairline is ONE device pixel, at any proof scale
        d.rounded_rectangle(box, rad, outline=(255, 255, 255, 26), width=1)
        icon_mic(d, fx + 16 * ss, fy + fh / 2, 16 * ss, rgb(col["icon"]), ss)
        pf = ImageFont.truetype(REG, max(6, int(doc["type"]["body"] * ss)))
        d.text((fx + 36 * ss, fy + (fh - pf.size) / 2), "Ask LUPY anything…",
               font=pf, fill=body_text)
        icon_return(d, fx + fw - 16 * ss, fy + fh / 2, 16 * ss, rgb(col["accent"]), ss)

    # ---- LUPY, last: his light sits over the glass he stands on
    if avatar and avatar[2] > 0:
        st = dict(rig[canvas["state"]])
        body_w = min(avatar[2], avatar[3]) * 0.72
        if body_w < 30:
            st["icon"] = "none"
        cx, cy = P(avatar[0] + avatar[2] / 2, avatar[1] + avatar[3] / 2)
        draw_character(img, st, body_w * ss, cx, cy, ss=1)

    return img


def fit(text, font, avail, d):
    if d.textlength(text, font=font) <= avail:
        return text
    while text and d.textlength(text + "…", font=font) > avail:
        text = text[:-1]
    return text.rstrip() + "…"


# --------------------------------------------------------------------- sheets

def stack(doc, rig, ids, kind, pp, title=None, note=None, gap=18, min_w=None):
    cs = sorted([c for c in doc["canvases"] if c["id"] in ids],
                key=lambda c: ids.index(c["id"]))
    if min_w is None:
        min_w = max(scene_width_pt(c) for c in cs)
    tiles = [draw_scene(doc, c, rig, kind, pp, min_w=min_w) for c in cs]
    lab = int(26 * pp)
    W = max(t.size[0] for t in tiles)
    head = int(56 * pp) if title else 0
    H = head + sum(t.size[1] + lab for t in tiles) + int(gap * pp)
    out = Image.new("RGB", (W, H), (11, 12, 16))
    d = ImageDraw.Draw(out)
    if title:
        tf = ImageFont.truetype(BOLD, max(10, int(18 * pp)))
        nf = ImageFont.truetype(REG, max(9, int(12.5 * pp)))
        d.text((int(12 * pp), int(10 * pp)), title, font=tf, fill=(228, 231, 238))
        if note:
            d.text((int(12 * pp), int(32 * pp)), note, font=nf, fill=(148, 154, 168))
    lf = ImageFont.truetype(REG, max(8, int(11 * pp)))
    y = head
    for t, cid in zip(tiles, ids):
        out.paste(t, (0, y))
        y += t.size[1]
        c = [c for c in doc["canvases"] if c["id"] == cid][0]
        bad = [l for l in c["legal"] if l != "yes"]
        d.text((int(10 * pp), y + int(6 * pp)),
               f"{cid}   {int(c['w'])}×{int(c['h'])} pt   "
               f"{'ok' if not bad else 'ILLEGAL ' + ';'.join(bad)}",
               font=lf, fill=(122, 196, 148) if not bad else (240, 120, 120))
        y += lab
    return out


def columns(doc, rig, groups, pp, title=None, note=None):
    """Side-by-side columns of stacked tiles — used for the light/dark pair."""
    allc = [c for (ids, k, cap) in groups for c in doc["canvases"] if c["id"] in ids]
    min_w = max(scene_width_pt(c) for c in allc)
    cols = [stack(doc, rig, ids, k, pp, title=cap, min_w=min_w)
            for (ids, k, cap) in groups]
    gap = int(24 * pp)
    W = sum(c.size[0] for c in cols) + gap * (len(cols) - 1)
    H = max(c.size[1] for c in cols)
    out = Image.new("RGB", (W, H), (11, 12, 16))
    x = 0
    for c in cols:
        out.paste(c, (x, 0))
        x += c.size[0] + gap
    return out


def grid(doc, rig, pp, cols=2, ids=None, title=None, note=None):
    tiles = []
    cs = [c for c in doc["canvases"] if not ids or c["id"] in ids]
    min_w = max(scene_width_pt(c) for c in cs) if cs else None
    for c in cs:
        tiles.append((draw_scene(doc, c, rig, "dark", pp, min_w=min_w), c))
    lab = int(24 * pp)
    colw, rowh = {}, {}
    for i, (t, _) in enumerate(tiles):
        colw[i % cols] = max(colw.get(i % cols, 0), t.size[0])
        rowh[i // cols] = max(rowh.get(i // cols, 0), t.size[1])
    xs, x = {}, 0
    for c in range(cols):
        xs[c] = x
        x += colw.get(c, 0)
    ys, y = {}, int(52 * pp) if title else 0
    for r in sorted(rowh):
        ys[r] = y
        y += rowh[r] + lab
    out = Image.new("RGB", (x, y), (11, 12, 16))
    d = ImageDraw.Draw(out)
    if title:
        tf = ImageFont.truetype(BOLD, max(9, int(16 * pp)))
        nf = ImageFont.truetype(REG, max(8, int(11 * pp)))
        d.text((int(10 * pp), int(8 * pp)), title, font=tf, fill=(228, 231, 238))
        if note:
            d.text((int(10 * pp), int(28 * pp)), note, font=nf, fill=(148, 154, 168))
    lf = ImageFont.truetype(REG, max(8, int(10.5 * pp)))
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
    c = doc["contrast"]
    g = doc["glass"]["panel"]
    print(f"panel alpha {g['alpha']:.3f} · contrast {c['primary_bright']:.2f}:1 bright, "
          f"{c['body_bright']:.2f}:1 body")

    def save(img, name):
        p = os.path.join(OUT, name)
        img.save(p)
        print(f"wrote {name}  {img.size[0]}x{img.size[1]}")

    # 1 · what the island is: resting, whispering, open — on a real desktop
    save(stack(doc, rig, ["rest", "whisper", "decision"], "dark", 1.5,
               title="1 · what the island is",
               note="it hangs from the menu bar · resting → one line → open when it needs you"),
         "walk-1-what-it-is.png")

    # 2 · the glass rule, over the two worst desktops
    save(columns(doc, rig, [
        (["whisper", "decision"], "bright", "on a light desktop"),
        (["whisper", "decision"], "dark", "on a dark desktop")], 1.2,
        title="2 · the same glass, over the two worst desktops",
        note=f"text stays readable on both: {c['body_bright']:.1f}:1 and "
             f"{c['body_dark']:.1f}:1 (the floor is 4.5:1)"),
         "walk-2-glass.png")

    # 3 · the four surfaces, for the choice
    save(grid(doc, rig, 1.15, cols=2, ids=["decision", "answer", "task", "chat"],
              title="3 · pick the first one to build",
              note="approval · answer · task ledger · conversation"),
         "walk-3-choices.png")

    # extras
    save(stack(doc, rig, ["answer", "task", "question", "error", "transcript"], "dark", 1.1),
         "lupy-island-surfaces.png")
    save(grid(doc, rig, 0.9, cols=3), "lupy-island-all.png")


if __name__ == "__main__":
    main()
