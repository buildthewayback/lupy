#!/usr/bin/env python3
"""The status bubble, drawn the same way the app draws it.

The rig emits the state, its colour and its icon; this module puts them in the pill
above the character's head: the sentence on the left, the state's own icon in a
circle of the state's colour on the right.

Everything here is relative to the body width (`u`), which is how the SwiftUI view
lays it out too, so a 190 px sheet tile and a 420 px window look like the same thing.
"""
import math

from PIL import Image, ImageDraw, ImageFont

FONT_PATH = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
INK = (18, 16, 22)


def rounded(d, box, radius, fill, outline=None, width=1):
    """A rounded rectangle by hand: PIL's rounded_rectangle is fine, but this keeps
    the same call shape as the rest of the character tooling."""
    d.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def _font(u):
    return ImageFont.truetype(FONT_PATH, max(8, int(u * 0.082)))


def icon_path(icon, u, cx, cy, span=None):
    """Return a list of drawing ops for one icon, on a unit square of side 0.30u.

    Mirrors LupyStateIconShape in LupyLabelBubble.swift: stroke-only, round caps,
    same optical weight for every glyph.
    """
    s = span if span is not None else u * 0.30

    def p(x, y):
        return (cx + x * s, cy + y * s)

    ops = []
    if icon == "gear":
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
    elif icon == "standby":
        ops.append(("circle", cx, cy, s * 0.26))
    elif icon == "question":
        ops.append(("poly", [p(-0.19, -0.18), p(-0.12, -0.36), p(0.10, -0.40),
                             p(0.21, -0.24), p(0.16, -0.06), p(0, 0.06)]))
        ops.append(("dot", p(0, 0.32), s * 0.075))
    elif icon == "exclamation":
        ops.append(("line", [p(0, -0.36), p(0, 0.12)]))
        ops.append(("dot", p(0, 0.33), s * 0.075))
    elif icon == "check":
        ops.append(("poly", [p(-0.34, 0.02), p(-0.10, 0.26), p(0.36, -0.26)]))
    elif icon == "clock":
        ops.append(("circle", cx, cy, s * 0.36))
        ops.append(("line", [p(0, -0.20), p(0, 0), p(0.16, 0.10)]))
    elif icon == "zzz":
        ops.append(("poly", [p(-0.38, 0.34), p(0.04, 0.34), p(-0.38, 0.04),
                             p(0.04, 0.04)]))
        ops.append(("poly", [p(0.08, -0.38), p(0.34, -0.38), p(0.08, -0.16),
                             p(0.34, -0.16)]))
    elif icon == "spiral":
        pts, a = [], 0.0
        while a < 4.4:
            r = 0.055 + 0.085 * a
            pts.append(p(math.cos(a) * r, math.sin(a) * r))
            a += 0.25
        ops.append(("poly", pts))
    return ops


def draw_icon(d, icon, u, cx, cy, width, ink=INK, span=None):
    for op in icon_path(icon, u, cx, cy, span):
        kind = op[0]
        if kind == "line":
            d.line(op[1], fill=ink, width=width, joint="curve")
            for pt in (op[1][0], op[1][-1]):
                d.ellipse([pt[0] - width / 2, pt[1] - width / 2,
                           pt[0] + width / 2, pt[1] + width / 2], fill=ink)
        elif kind == "poly":
            d.line(op[1], fill=ink, width=width, joint="curve")
            for pt in (op[1][0], op[1][-1]):
                d.ellipse([pt[0] - width / 2, pt[1] - width / 2,
                           pt[0] + width / 2, pt[1] + width / 2], fill=ink)
        elif kind == "circle":
            _, x, y, r = op
            d.ellipse([x - r, y - r, x + r, y + r], outline=ink, width=width)
        elif kind == "arc":
            _, c, r, a0, a1 = op
            d.arc([c[0] - r, c[1] - r, c[0] + r, c[1] + r], a0, a1,
                  fill=ink, width=width)
        elif kind == "dot":
            _, c, r = op
            d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=ink)


def draw_status_bubble(d, label, icon, tint, u, cx, top, phase=3):
    """The pill: the sentence, animated dots, then the state's icon on the right."""
    h = u * 0.215
    font = _font(u)
    pad_l = u * 0.055
    pad_r = u * 0.030
    dot_r = u * 0.0075
    dot_gap = u * 0.019
    icon_size = u * 0.170

    ongoing = label.endswith("…")
    base = label[:-1] if ongoing else label
    text_w = d.textlength(base, font=font)
    dots_w = (dot_gap * 2 + dot_r * 2) if ongoing else 0
    text_w += dots_w
    gap_icon = u * 0.045
    w = pad_l + text_w + gap_icon + icon_size + pad_r

    x0 = cx - w / 2
    # The pill reads as glass, not a card: the background shows through it.
    d.rounded_rectangle([x0, top, x0 + w, top + h], radius=h / 2, fill=(38, 38, 46))
    d.rounded_rectangle([x0, top, x0 + w, top + h], radius=h / 2,
                        outline=(78, 78, 90), width=max(1, int(u * 0.004)))

    # text
    ty = top + h / 2
    d.text((x0 + pad_l, ty), base, font=font, fill=(233, 234, 241), anchor="lm")
    if ongoing:
        for i in range(3):
            dx = x0 + pad_l + d.textlength(base, font=font) + dot_r + i * (dot_r * 2 + dot_gap)
            lit = i < phase % 4
            r = dot_r
            d.ellipse([dx - r, ty - r, dx + r, ty + r],
                      fill=(233, 234, 241) if lit else (90, 90, 100))

    # icon circle on the right, in the state's colour
    icx = x0 + w - pad_r - icon_size / 2
    icy = ty
    r = icon_size / 2
    col = tuple(int(c * 255) for c in tint)
    d.ellipse([icx - r, icy - r, icx + r, icy + r], fill=col)
    luminance = 0.2126 * tint[0] + 0.7152 * tint[1] + 0.0722 * tint[2]
    ink = (18, 16, 22) if luminance > 0.52 else (255, 255, 255)
    # the glyph is sized by the circle it lives in, with a little breathing room
    draw_icon(d, icon, u, icx, icy, max(1, int(u * 0.019)), ink, span=icon_size * 0.52)
