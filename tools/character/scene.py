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

# mirrors LupyComposition in LupyCharacterMath.swift, all measured off the
# founder's sketch and expressed in body widths
UNIT_FRACTION = 0.72
BADGE_R = 0.0985          # the coloured disc
RING_W = 0.035           # the dark ring around it
BADGE_DROP = 0.129        # centre, as a fraction of body height below the apex
BADGE_OVERLAP = 0.0175     # how much the ring overlaps the silhouette
RING = (11, 12, 14)
GLOW_BLUR = 0.09

# the bubble, also from the sketch
BUBBLE_HEIGHT = 0.323
BUBBLE_FONT = 0.163
BUBBLE_PAD = 0.075
BUBBLE_TRAILING_INSET = 0.37   # right edge, from the body's centre
BUBBLE_RISE = 0.34            # centre, above the body's centre
ARC_SPAN = 1.38          # the ∪ is 1.8x a capsule's width
ARC_BOW = 0.050
ARC_STROKE = 0.60
DOT_R = 0.018
DOT_GAP = 0.016


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


def half_width_at(body, y):
    """Half the silhouette's width at height y, from the emitted polygon."""
    xs = []
    for i in range(len(body)):
        x0, y0 = body[i]
        x1, y1 = body[(i + 1) % len(body)]
        if (y0 - y) * (y1 - y) <= 0 and y0 != y1:
            t = (y - y0) / (y1 - y0)
            xs.append(x0 + (x1 - x0) * t)
    if not xs:
        return max(abs(x) for x, _ in body)
    return max(abs(x) for x in xs)


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
            # `w` is the drawn span (1.8x a capsule); the stroke is defined against the
            # capsule's base width, as in the app. Using the span made the sheet's arcs
            # nearly twice as heavy as the app's.
            base_w = w / (ARC_SPAN if style in ("arch", "cup") else 1.0)
            bow = ARC_BOW * u * ss * (-1 if style == "arch" else 1)
            n = 24
            pts = []
            for i in range(n + 1):
                t = i / n
                x = ex_p - w / 2 + w * t
                y = ey_p - bow / 2 + bow * (1 - (2 * t - 1) ** 2)
                pts.append((x, y))
            stroke(d, pts, max(1.0, base_w * ARC_STROKE), INK)

    # badge: pinned to the right rim, ring kissing the silhouette
    icon = state.get("icon", "none")
    if icon != "none":
        apex = max(y for _, y in state["body"])
        byy = apex - BADGE_DROP * (apex - min(y for _, y in state["body"]))
        rim = half_width_at(state["body"], byy)
        bxx = rim + (RING_W + BADGE_R - BADGE_OVERLAP)
        bx, by = px(bxx, byy)
        r = BADGE_R * u * ss
        ring = RING_W * u * ss
        d.ellipse([bx - r - ring, by - r - ring, bx + r + ring, by + r + ring], fill=RING)
        d.ellipse([bx - r, by - r, bx + r, by + r],
                  fill=tuple(int(c * 255) for c in tint))
        lum = 0.2126 * tint[0] + 0.7152 * tint[1] + 0.0722 * tint[2]
        ink = (10, 10, 12) if lum > 0.52 else (255, 255, 255)
        draw_icon(d, icon, r * 2 * 0.62, bx, by, max(1, int(r * 2 * 0.62 * 0.115)), ink)


# ---------------------------------------------------------------- bubble

def measure_bubble(state, u, ss=1):
    """The capsule's width, so a scene can be laid out before anything is drawn."""
    h = u * BUBBLE_HEIGHT * ss
    font = ImageFont.truetype(FONT_BOLD, max(9, int(u * BUBBLE_FONT * ss)))
    probe = ImageDraw.Draw(Image.new("RGB", (8, 8)))
    tw = probe.textlength(state["label"], font=font)
    dot_r = u * DOT_R * ss
    dot_gap = u * DOT_GAP * ss
    dots_w = (dot_r * 2 * 3 + dot_gap * 2 + u * 0.020 * ss) if state.get("ongoing") else 0
    return u * BUBBLE_PAD * ss * 2 + tw + dots_w, h


def draw_bubble(img, state, u, centre_x, centre_y, ss=1, phase=0.0):
    """The status bubble, placed by its centre: glass capsule, sentence, moving dots."""
    d = ImageDraw.Draw(img)
    tint = state["tint"]
    label = state["label"]
    h = u * BUBBLE_HEIGHT * ss
    font = ImageFont.truetype(FONT_BOLD, max(9, int(u * BUBBLE_FONT * ss)))

    tw = d.textlength(label, font=font)
    dot_r = u * DOT_R * ss
    dot_gap = u * DOT_GAP * ss
    dots_w = (dot_r * 2 * 3 + dot_gap * 2 + u * 0.020 * ss) if state.get("ongoing") else 0
    pad_l = u * BUBBLE_PAD * ss
    pad_r = u * BUBBLE_PAD * ss
    w = pad_l + tw + dots_w + pad_r
    left = centre_x - w / 2
    top = centre_y - h / 2

    # drop shadow
    d.rounded_rectangle([left + u * 0.004 * ss, top + u * 0.010 * ss,
                         left + w + u * 0.004 * ss, top + h + u * 0.010 * ss],
                        radius=h / 2, fill=(10, 10, 12))

    # the capsule itself: a true vertical gradient, masked by the pill shape
    pill = Image.new("L", (int(w) + 2, int(h) + 2), 0)
    ImageDraw.Draw(pill).rounded_rectangle([0, 0, w, h], radius=h / 2, fill=255)
    grad = Image.new("RGB", (int(w) + 2, int(h) + 2))
    gd = ImageDraw.Draw(grad)
    rows = max(1, int(h))
    for i in range(rows):
        t = i / max(1, rows - 1)
        shade = int(40 - 12 * t)
        gd.line([(0, i), (w + 2, i)], fill=(shade, shade, shade + 3))
    img.paste(grad, (int(left), int(top)), pill)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([left, top, left + w, top + h], radius=h / 2,
                        outline=(66, 66, 76), width=max(1, int(ss)))
    d.rounded_rectangle([left, top, left + w, top + h], radius=h / 2,
                        outline=tuple(int(c * 255) for c in tint), width=max(1, int(ss * 0.7)))

    ty = top + h / 2
    d.text((left + pad_l, ty), label, font=font, fill=(242, 243, 248), anchor="lm")

    if state.get("ongoing"):
        x = left + pad_l + tw + u * 0.020 * ss
        for i in range(3):
            lit = 1.0 - min(1.0, abs(((phase + i / 3.0) % 1.0) - 0.0) / 0.45)
            lit = max(0.0, 1.0 - (((phase + i / 3.0) % 1.0) / 0.45)) if ((phase + i / 3.0) % 1.0) < 0.45 else 0.0
            lit = lit * lit * (3 - 2 * lit)
            col = tuple(int((0.28 + 0.62 * lit) * c * 255) for c in tint)
            r = dot_r * (0.86 + 0.24 * lit)
            d.ellipse([x - r, ty - r, x + r, ty + r], fill=col)
            x += dot_r * 2 + dot_gap
    return w


# ---------------------------------------------------------------- whole scene

def compose(state, u, ss=1, phase=0.15, generous=1.0, canvas=None):
    """The character, the badge on his rim and the bubble beside him — one function,
    used by the state sheet and by the animation, so they cannot disagree.

    `u` is the body width in final pixels. Returns the composed image at `ss` scale;
    the caller crops/downsamples.
    """
    bw, _ = measure_bubble(state, u, ss)     # already in canvas pixels
    W = int(round((bw + u * 1.7 * ss) * generous))
    H = int(round(u * 1.9 * ss * generous))
    if canvas:
        W, H = canvas
    img = Image.new("RGB", (W, H), BG)

    cx = W - u * 0.62 * ss
    cy = H * 0.55

    draw_character(img, state, u, cx, cy, ss=ss)

    if state.get("hot", 0) > 0.01:
        tint = state["tint"]
        warm = (1.0, 0.42, 0.20)
        h = min(0.35, 0.35 * state["hot"])
        state = dict(state)
        state["tint"] = tuple(tint[i] * (1 - h) + warm[i] * h for i in range(3))

    bubble_right = cx - u * BUBBLE_TRAILING_INSET * ss
    draw_bubble(img, state, u, bubble_right - bw / 2,
                cy - u * BUBBLE_RISE * ss, ss=ss, phase=phase)
    return img
