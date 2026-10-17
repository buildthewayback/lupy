#!/usr/bin/env python3
"""The scene the app shows: the character, his badge on his own edge, and his bubble.

Everything is measured in **body widths** (u), because that is how the SwiftUI views
lay it out: the badge is offset by LupyComposition.badgeCentreX and the bubble sits
beside him with a fixed gap. Nothing here invents a number the app does not have.

Drawn at 3–4x and downsampled with LANCZOS: the founder's note was that the character
looked pixelated, and a rasteriser that renders at the final size (or worse, is then
scaled up by a retina display) is exactly how that happens.
"""
import math

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

BG = (16, 16, 19)
INK = (0, 0, 0)
BODY = (255, 255, 255)

# mirrors LupyComposition in LupyCharacterMath.swift
UNIT_FRACTION = 0.72
BADGE_X = 0.497
BADGE_Y = 0.085
BADGE_R = 0.082
RING_W = 0.020
RING = (11, 12, 14)
GLOW_BLUR = 0.09


def stroke(d, pts, width, ink):
    """A round-capped, round-jointed stroke, stamped rather than drawn.

    PIL's ``joint="curve"`` produces spikes when the stroke is much thicker than the
    spacing between points (which is exactly the case for Lupy's fat eye arcs). Stamping
    overlapping discs along the polyline is unconditionally smooth, at any thickness.
    """
    r = width / 2.0
    for i in range(len(pts) - 1):
        x0, y0 = pts[i]
        x1, y1 = pts[i + 1]
        dx, dy = x1 - x0, y1 - y0
        dist = math.hypot(dx, dy)
        steps = max(1, int(dist / max(0.75, r * 0.5)))
        for k in range(steps + 1):
            t = k / steps
            d.ellipse([x0 + dx * t - r, y0 + dy * t - r,
                       x0 + dx * t + r, y0 + dy * t + r], fill=ink)


def rounded(d, box, radius, fill, outline=None, width=1):
    d.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


# ---------------------------------------------------------------- icons

def icon_ops(icon, s, cx, cy):
    """The same glyphs as LupyStateIconShape, on a square of side `s`."""
    def p(x, y):
        return (cx + x * s, cy + y * s)

    ops = []
    if icon == "standby":
        ops.append(("circle", cx, cy, s * 0.26))
    elif icon == "gear":
        for i in range(8):
            a = i * math.pi / 4
            ops.append(("line", [p(math.cos(a) * 0.30, math.sin(a) * 0.30),
                                 p(math.cos(a) * 0.44, math.sin(a) * 0.44)]))
        ops.append(("circle", cx, cy, s * 0.24))
    elif icon == "bulb":
        ops.append(("arc", p(0, -0.06), s * 0.34, 155, 385))
        ops.append(("line", [p(-0.11, 0.20), p(-0.11, 0.30)]))
        ops.append(("line", [p(0.11, 0.20), p(0.11, 0.30)]))
        ops.append(("line", [p(-0.19, 0.44), p(0.19, 0.44)]))
    elif icon == "magnifier":
        ops.append(("circle", cx - s * 0.10, cy - s * 0.10, s * 0.30))
        ops.append(("line", [p(0.08, 0.08), p(0.40, 0.40)]))
    elif icon == "bell":
        ops.append(("poly", [p(-0.38, 0.16), p(-0.27, -0.20), p(0, -0.40),
                             p(0.27, -0.20), p(0.38, 0.16), p(-0.38, 0.16)]))
        ops.append(("line", [p(0, 0.16), p(0, 0.30)]))
        ops.append(("line", [p(-0.13, 0.38), p(0.13, 0.38)]))
    elif icon == "question":
        ops.append(("poly", [p(-0.19, -0.14), p(-0.10, -0.34), p(0.12, -0.38),
                             p(0.23, -0.22), p(0.16, -0.04), p(0, 0.08)]))
        ops.append(("dot", p(0, 0.34), s * 0.085))
    elif icon == "exclamation":
        ops.append(("line", [p(0, -0.38), p(0, 0.14)]))
        ops.append(("dot", p(0, 0.35), s * 0.085))
    elif icon == "check":
        ops.append(("poly", [p(-0.36, 0.02), p(-0.10, 0.28), p(0.38, -0.28)]))
    elif icon == "clock":
        ops.append(("circle", cx, cy, s * 0.38))
        ops.append(("line", [p(0, -0.21), p(0, 0), p(0.17, 0.11)]))
    elif icon == "zzz":
        ops.append(("poly", [p(-0.40, 0.36), p(0.04, 0.36), p(-0.40, 0.04),
                             p(0.04, 0.04)]))
        ops.append(("poly", [p(0.08, -0.40), p(0.36, -0.40), p(0.08, -0.16),
                             p(0.36, -0.16)]))
    elif icon == "spiral":
        pts, a = [], 0.0
        while a < 4.4:
            r = 0.06 + 0.088 * a
            pts.append(p(math.cos(a) * r, math.sin(a) * r))
            a += 0.22
        ops.append(("poly", pts))
    return ops


def draw_icon(d, icon, s, cx, cy, width, ink):
    for op in icon_ops(icon, s, cx, cy):
        kind = op[0]
        if kind in ("line", "poly"):
            d.line(op[1], fill=ink, width=width, joint="curve")
            for pt in (op[1][0], op[1][-1]):
                r = width / 2
                d.ellipse([pt[0] - r, pt[1] - r, pt[0] + r, pt[1] + r], fill=ink)
        elif kind == "circle":
            _, x, y, r = op
            d.ellipse([x - r, y - r, x + r, y + r], outline=ink, width=width)
        elif kind == "arc":
            _, c, r, a0, a1 = op
            d.arc([c[0] - r, c[1] - r, c[0] + r, c[1] + r], a0, a1, fill=ink, width=width)
        elif kind == "dot":
            _, c, r = op
            d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=ink)


# ---------------------------------------------------------------- character

def draw_character(img, state, u, cx, cy, ss=1):
    """Body, light, eyes, badge. `u` is the body width in final pixels."""
    d = ImageDraw.Draw(img)
    W, H = img.size
    tint = state["tint"]

    def px(x, y):
        return (cx + x * u * ss, cy - y * u * ss)

    body_pts = [px(x, y) for x, y in state["body"]]

    # light: the state's colour, blurred out of the silhouette
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon(body_pts, fill=255)
    glow = mask.filter(ImageFilter.GaussianBlur(u * ss * GLOW_BLUR))
    strength = min(0.95, state.get("amount", 0.3))
    glow = glow.point(lambda v: min(255, int(v * strength)))
    layer = Image.new("RGB", img.size, tuple(int(c * 255) for c in tint))
    img.paste(layer, (0, 0), glow)
    d = ImageDraw.Draw(img)

    # body: pure white, always
    d.polygon(body_pts, fill=BODY)

    # eyes
    for ex, ey, rx, ry, style in state["eyes"]:
        if ry < 0.002:
            ry = 0.002
        ex_p, ey_p = px(ex, ey)
        w, h = rx * 2 * u * ss, ry * 2 * u * ss
        if style in ("capsule", "wide", "dash", "half_lid"):
            rounded(d, [ex_p - w / 2, ey_p - h / 2, ex_p + w / 2, ey_p + h / 2],
                    min(w, h) / 2, INK)
        elif style == "spiral":
            # Two full turns that fill the eye, in the same ink mass as a capsule eye.
            pts, a = [], 0.0
            while a < 12.566:                       # 4π: two full turns
                r = (0.006 + 0.0094 * a) * u * ss
                pts.append((ex_p + r * math.cos(a + 0.8),
                            ey_p - r * math.sin(a + 0.8) * 0.92))
                a += 0.10
            stroke(d, pts, max(1.0, w * 0.20), INK)
        else:
            bow = 0.052 * u * ss * (-1 if style == "arch" else 1)
            n = 24
            pts = []
            for i in range(n + 1):
                t = i / n
                x = ex_p - w / 2 + w * t
                y = ey_p + bow * (1 - (2 * t - 1) ** 2)
                pts.append((x, y))
            stroke(d, pts, max(1.0, w * 0.46), INK)

    # badge: on the character's right edge, half on him and half off
    icon = state.get("icon", "none")
    if icon != "none":
        bx, by = px(BADGE_X, BADGE_Y)
        r = BADGE_R * u * ss
        ring = RING_W * u * ss
        d.ellipse([bx - r - ring, by - r - ring, bx + r + ring, by + r + ring], fill=RING)
        d.ellipse([bx - r, by - r, bx + r, by + r],
                  fill=tuple(int(c * 255) for c in tint))
        lum = 0.2126 * tint[0] + 0.7152 * tint[1] + 0.0722 * tint[2]
        ink = (10, 10, 12) if lum > 0.52 else (255, 255, 255)
        draw_icon(d, icon, r * 2 * 0.62, bx, by, max(1, int(r * 2 * 0.62 * 0.115)), ink)


# ---------------------------------------------------------------- bubble

def draw_bubble(img, state, u, left, cy, ss=1, phase=0.0):
    """The status bubble: glass capsule, the sentence, three travelling dots."""
    d = ImageDraw.Draw(img)
    tint = state["tint"]
    label = state["label"]
    h = u * 0.200 * ss
    font = ImageFont.truetype(FONT_BOLD, max(9, int(u * 0.078 * ss)))

    tw = d.textlength(label, font=font)
    dot_r = u * 0.0135 * ss
    dot_gap = u * 0.0110 * ss
    dots_w = (dot_r * 2 * 3 + dot_gap * 2 + u * 0.024 * ss) if state.get("ongoing") else 0
    pad_l = u * 0.085 * ss
    pad_r = u * 0.090 * ss
    w = pad_l + tw + dots_w + pad_r
    top = cy - h / 2

    # drop shadow, then the capsule's two greys
    d.rounded_rectangle([left + u * 0.004 * ss, top + u * 0.010 * ss,
                         left + w + u * 0.004 * ss, top + h + u * 0.010 * ss],
                        radius=h / 2, fill=(10, 10, 12))
    steps = 18
    for i in range(steps):
        t = i / (steps - 1)
        shade = int(40 - 12 * t)
        d.rounded_rectangle([left, top + h * t / 2, left + w, top + h - h * t / 2],
                            radius=h / 2, fill=(shade, shade, shade + 3))
    d.rounded_rectangle([left, top, left + w, top + h], radius=h / 2,
                        outline=(66, 66, 76), width=max(1, int(ss)))
    d.rounded_rectangle([left, top, left + w, top + h], radius=h / 2,
                        outline=tuple(int(c * 255) for c in tint), width=max(1, int(ss * 0.7)))

    ty = top + h / 2
    d.text((left + pad_l, ty), label, font=font, fill=(242, 243, 248), anchor="lm")

    if state.get("ongoing"):
        x = left + pad_l + tw + u * 0.024 * ss
        for i in range(3):
            lit = 1.0 - min(1.0, abs(((phase + i / 3.0) % 1.0) - 0.0) / 0.45)
            lit = max(0.0, 1.0 - (((phase + i / 3.0) % 1.0) / 0.45)) if ((phase + i / 3.0) % 1.0) < 0.45 else 0.0
            lit = lit * lit * (3 - 2 * lit)
            col = tuple(int((0.28 + 0.62 * lit) * c * 255) for c in tint)
            r = dot_r * (0.86 + 0.24 * lit)
            d.ellipse([x - r, ty - r, x + r, ty + r], fill=col)
            x += dot_r * 2 + dot_gap
    return w
