#!/usr/bin/env python3
"""Draw the 11 LUPY states from frames emitted by tools/character/rig_states.swift.

Only rasterises: every number (silhouette, eye position, style, tint, badge) comes
from the shipping Swift rig.
"""
import sys
from PIL import Image, ImageDraw, ImageFilter

SS = 3
BODY = (255, 255, 255)
INK = (0, 0, 0)
BG = (17, 17, 20)


def parse(path):
    states = []
    cur = None
    for line in open(path):
        p = line.split()
        if not p:
            continue
        if p[0] == "FRAME":
            cur = {"name": p[1], "body": [], "eyes": [], "tint": (1, 1, 1), "badge": "none"}
            states.append(cur)
        elif p[0] == "STATE":
            cur["tint"] = tuple(float(v) for v in p[2:5])
            cur["badge"] = p[5] if len(p) > 5 else "none"
        elif p[0] == "BODY":
            cur["body"] = [tuple(map(float, q.split(","))) for q in p[1:]]
        elif p[0] == "EYE":
            _, side, cx, cy, rx, ry, style = p[:7]
            cur["eyes"].append((float(side), float(cx), float(cy),
                                float(rx), float(ry), style))
    return states


def rounded(d, box, radius, fill):
    d.rounded_rectangle(box, radius=radius, fill=fill)


def draw_arc_eye(d, cx, cy, half_w, style, unit, tinted):
    """Wide arc eye: a stroked quadratic with round caps, never a filled blob."""
    w = half_w * 2 * 1.35            # arcs are wider than the capsule
    thickness = half_w * 0.92
    bow = 0.052 * unit
    if style == "arch":
        bow = -bow                  # ∩
    n = 22
    pts = []
    for i in range(n + 1):
        t = i / n
        x = cx - w / 2 + w * t
        y = cy + bow * (1 - (2 * t - 1) ** 2)   # parabola peaking at the centre
        pts.append((x, y))
    d.line(pts, fill=tinted, width=int(max(1, round(thickness))), joint="curve")
    r = thickness / 2
    for (x, y) in (pts[0], pts[-1]):
        d.ellipse([x - r, y - r, x + r, y + r], fill=tinted)


def draw_spiral_eye(d, cx, cy, unit):
    """Dizzy: one thin solid spiral per eye. Still ink, still no pupil."""
    n = 44
    pts = []
    for i in range(n + 1):
        a = i * 0.15
        r = unit * (0.011 + 0.0135 * a)
        pts.append((cx + r * __import__("math").cos(a), cy - r * __import__("math").sin(a) * 0.86))
    d.line(pts, fill=INK, width=int(max(1, round(unit * 0.016))), joint="curve")
    r = unit * 0.008
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=INK)


def draw_badge(d, badge, unit, cx, cy):
    """Upper-LEFT overlay, brand rule. Drawn in ink on a soft light bubble."""
    # Upper-left and completely detached: the body must never look like it grew an
    # ear (hard brand rule). The gap is deliberate.
    bx = cx - 0.545 * unit
    by = cy - 0.395 * unit
    s = unit * 0.048
    ink = (26, 20, 24)
    if badge == "none":
        return
    if badge == "dots":
        pw, ph = s * 3.4, s * 1.9
        rounded(d, [bx - pw, by - ph, bx + pw, by + ph], ph, (255, 255, 255, 235))
        for i in (-1, 0, 1):
            r = s * 0.30
            d.ellipse([bx + i * s * 0.95 - r, by - r, bx + i * s * 0.95 + r, by + r], fill=ink)
    elif badge in ("exclamation", "question", "ring", "dot"):
        r = s * 1.75
        d.ellipse([bx - r, by - r, bx + r, by + r], fill=(255, 255, 255, 240))
        if badge == "exclamation":
            d.rounded_rectangle([bx - s * 0.26, by - s * 1.05, bx + s * 0.26, by + s * 0.28],
                                s * 0.26, fill=ink)
            d.ellipse([bx - s * 0.3, by + s * 0.62, bx + s * 0.3, by + s * 1.22], fill=ink)
        elif badge == "question":
            # a hook and a dot — a drawn "?", not a font glyph
            pts = []
            for i in range(18):
                a = -2.55 + i * (3.35 / 18)
                pts.append((bx + s * 0.62 * __import__("math").cos(a),
                            by - s * 0.30 + s * 0.62 * __import__("math").sin(a)))
            d.line(pts, fill=ink, width=int(max(1, s * 0.42)), joint="curve")
            d.line([(bx + s * 0.02, by + s * 0.02), (bx + s * 0.02, by + s * 0.42)],
                   fill=ink, width=int(max(1, s * 0.42)))
            d.ellipse([bx - s * 0.22, by + s * 0.80, bx + s * 0.22, by + s * 1.24], fill=ink)
        elif badge == "ring":
            d.ellipse([bx - s * 0.75, by - s * 0.75, bx + s * 0.75, by + s * 0.75],
                      outline=ink, width=int(max(1, s * 0.42)))
        elif badge == "dot":
            r2 = s * 0.62
            d.ellipse([bx - r2, by - r2, bx + r2, by + r2], fill=ink)
    elif badge == "zzz":
        for i, k in enumerate((1.0, 1.55)):
            zx = bx + (i * s * 1.5)
            zy = by - (i * s * 1.15)
            z = s * 0.85 * k
            d.line([(zx - z / 2, zy - z / 2), (zx + z / 2, zy - z / 2),
                    (zx - z / 2, zy + z / 2), (zx + z / 2, zy + z / 2)],
                   fill=(236, 240, 248), width=int(max(1, s * 0.3)), joint="curve")


def render(state, size, pad=0.20):
    W = int(round(size * (1 + 2 * pad)))
    img = Image.new("RGB", (W * SS, W * SS), BG)
    d = ImageDraw.Draw(img)
    s = size * SS
    cx = cy = W * SS / 2

    def px(x, y):
        return (cx + x * s, cy - y * s)

    tint = state["tint"]
    body_pts = [px(x, y) for x, y in state["body"]]

    # halo: the body mask, blurred hard and tinted. It hugs the silhouette and fades
    # to nothing — no hard edge, no offset "shadow".
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon(body_pts, fill=255)
    glow = mask.filter(ImageFilter.GaussianBlur(s * 0.085))
    tint_rgb = tuple(int(c * 255) for c in tint)
    glow_layer = Image.new("RGB", img.size, tint_rgb)
    strength = 0.46 if state["name"] != "idle" else 0.26
    scaled = glow.point(lambda v: min(255, int(v * strength)))
    img = Image.composite(glow_layer, img, scaled)

    d = ImageDraw.Draw(img)

    # body: pure white, brand law
    d.polygon(body_pts, fill=BODY)

    cyw = cy
    for side, ex, ey, rx, ry, style in state["eyes"]:
        ex_p, ey_p = px(ex, ey)
        if style in ("capsule", "wide", "dash", "half_lid"):
            k = {"capsule": (1.0, 1.0), "wide": (1.16, 1.06),
                 "dash": (1.12, 0.20), "half_lid": (1.30, 0.28)}[style]
            w = rx * 2 * k[0]
            h = ry * 2 * k[1]
            rounded(d, [ex_p - w * s / 2, ey_p - h * s / 2,
                        ex_p + w * s / 2, ey_p + h * s / 2],
                    min(w, h) * s / 2, INK)
        elif style == "spiral":
            draw_spiral_eye(d, ex_p, ey_p, s)
        else:
            draw_arc_eye(d, ex_p, ey_p, rx * s, style, s, INK)

    draw_badge(d, state["badge"], s, cx, cy)
    return img.resize((W, W), Image.LANCZOS)


def _offset(pts, grow):
    """Push a polygon outward from its centroid — a cheap, stable halo shell."""
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    out = []
    for x, y in pts:
        dx, dy = x - cx, y - cy
        n = (dx * dx + dy * dy) ** 0.5 or 1
        out.append((x + dx / n * grow, y + dy / n * grow))
    return out


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "/tmp/states.txt"
    out = sys.argv[2] if len(sys.argv) > 2 else "docs/concepts/lupy-rig-states.png"
    size = int(sys.argv[3]) if len(sys.argv) > 3 else 190
    states = parse(src)
    cols = 6
    rows = (len(states) + cols - 1) // cols
    tiles = [render(s, size) for s in states]
    tw, th = tiles[0].size
    label = 30
    canvas = Image.new("RGB", (tw * cols, (th + label) * rows), (12, 12, 15))
    d = ImageDraw.Draw(canvas)
    for i, (t, s) in enumerate(zip(tiles, states)):
        x, y = (i % cols) * tw, (i // cols) * (th + label)
        canvas.paste(t, (x, y))
        d.text((x + 12, y + th + 8), s["name"], fill=(170, 172, 184))
    canvas.save(out)
    print(f"wrote {out} {canvas.size[0]}x{canvas.size[1]}")


if __name__ == "__main__":
    main()
