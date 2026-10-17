#!/usr/bin/env python3
"""
LUPY character renderer — V2, real shading.

Replaces the flat ImageMagick pass with actual pixel math (Pillow + numpy-free).
One body geometry from docs/concepts/lupy-character-spec-v1.json; every state
reuses the exact same silhouette and shading stack, so the character can never
drift. Only eyes / body colour / halo / badge / overlay change.

Shading stack (per state):
    1. base vertical gradient (light top -> shade at the base)
    2. inner rim shading from a blur of the distance-to-edge field (gives volume)
    3. broad top-front specular + tight hotspot (screen)
    4. bottom contact shading + soft floor shadow
    5. outer colour halo
    6. blush, then eyes (drawn with colour, never pure black-on-white haze)
    7. badge / overlays

Usage:
    python3 tools/character/render_states.py [--tile 420] [--out DIR] [--sheet]
"""
import argparse
import json
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageChops

HERE = os.path.dirname(os.path.abspath(__file__))
SPEC_PATH = os.path.join(HERE, "..", "..", "docs", "concepts", "lupy-character-spec-v1.json")

# ---------------------------------------------------------------- palette ----
INK = (26, 20, 18)          # warm near-black, like the reference (never pure #000)
BG = (13, 13, 17)

STATES = [
    # key,        body colour, eye,       badge,      halo,  extra
    ("idle",      (255, 255, 255), "pill",    None,       0.22, None),
    ("working",   (159, 216, 245), "pill",    "dots",     0.50, None),
    ("thinking",  (201, 174, 236), "pill",    "dots",     0.46, None),
    ("searching", (143, 134, 222), "pill",    "dots",     0.50, None),
    ("approval",  (249, 212, 155), "wide",    "bang",     0.55, None),
    ("question",  (134, 224, 236), "pill",    "question", 0.50, None),
    ("error",     (249, 140, 134), "flat",    "ring",     0.50, None),
    ("finished",  (168, 230, 198), "happy",   "dot",      0.46, "sparkle"),
    ("ratelimit", (249, 174, 119), "tired",   "dot",      0.42, "sweat"),
    ("sleeping",  (246, 227, 205), "closed",  None,       0.20, "zzz"),
    ("dizzy",     (243, 189, 191), "spiral",  None,       0.50, "bubbles"),
]

EMOTES = [
    ("love",      (255, 194, 214), "heart",   None, 0.42, None),
    ("surprised", (255, 255, 255), "wide",    None, 0.28, None),
    ("wink",      (255, 255, 255), "wink",    None, 0.24, None),
    ("happy",     (255, 255, 255), "happy",   None, 0.32, None),
    ("annoyed",   (242, 220, 216), "line",    None, 0.18, None),
    ("yawn",      (255, 255, 255), "closed",  None, 0.18, "zzz"),
    ("proud",     (255, 240, 196), "star",    None, 0.32, "sparkle"),
    ("listening", (168, 232, 220), "wide",    None, 0.46, None),
]


# --------------------------------------------------------------- geometry ----
def catmull_polygon(pts, sx, sy, ox, oy, samples_per_seg=6):
    """Closed Catmull-Rom -> dense polygon (list of (x, y) in pixel space)."""
    n = len(pts)
    out = []
    for i in range(n):
        p0, p1, p2, p3 = pts[(i - 1) % n], pts[i], pts[(i + 1) % n], pts[(i + 2) % n]
        for s in range(samples_per_seg):
            t = s / samples_per_seg
            t2, t3 = t * t, t * t * t
            x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t +
                       (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 +
                       (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t +
                       (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 +
                       (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            out.append((x * sx + ox, y * sy + oy))
    return out


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def shade(c, amount):
    return mix(c, (0, 0, 0), amount) if amount > 0 else mix(c, (255, 255, 255), -amount)


# ------------------------------------------------------------- primitives ----
def radial(W, H, cx, cy, rx, ry, peak, falloff=2.0):
    """White radial blob as an L mask (1.0 at centre)."""
    img = Image.new("L", (W, H), 0)
    px = img.load()
    x0, x1 = max(0, int(cx - rx)), min(W, int(cx + rx))
    y0, y1 = max(0, int(cy - ry)), min(H, int(cy + ry))
    inv = 1.0 / max(1e-6, falloff)
    for y in range(y0, y1):
        dy = (y - cy) / ry
        for x in range(x0, x1):
            dx = (x - cx) / rx
            d = math.hypot(dx, dy)
            if d >= 1.0:
                continue
            v = (1.0 - d) ** inv
            px[x, y] = int(255 * v * peak)
    return img


def vgradient(W, H, top, bottom, y0, y1):
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = (y - y0) / max(1.0, (y1 - y0))
        t = min(1.0, max(0.0, t))
        d.line([(0, y), (W, y)], fill=mix(top, bottom, t))
    return img


def inner_rim(mask, blur, strength):
    """Bright at the silhouette edge, dark inside -> invert of a blurred mask."""
    m = mask.filter(ImageFilter.GaussianBlur(blur))
    return m.point(lambda v: int(strength * (255 - v)))


def screen(base, layer_mask, colour):
    """Screen a coloured layer onto base using a mask."""
    lay = Image.new("RGB", base.size, colour)
    base = Image.composite(ImageChops.screen(base, lay), base, layer_mask)
    return base


def multiply_mask(base, mask, amount=1.0):
    dark = Image.new("RGB", base.size, (0, 0, 0))
    m = mask.point(lambda v: int(v * amount))
    return Image.composite(ImageChops.multiply(base, dark), base, m)


# ------------------------------------------------------------------ eyes -----
def draw_eyes(draw, shape, spec, scale, cx, base_y, W, H, colour=INK):
    e = spec["eye"]
    ew, eh = e["w"] * scale, e["h"] * scale
    dx = e["centre_x"] * scale
    cy = base_y - e["centre_y_from_bottom"] * scale
    lw = max(2, int(ew * 0.42))

    for sgn in (-1, 1):
        ex = cx + sgn * dx
        x0, y0 = ex - ew / 2, cy - eh / 2
        x1, y1 = ex + ew / 2, cy + eh / 2
        r = ew / 2
        if shape == "pill":
            draw.rounded_rectangle([x0, y0, x1, y1], radius=r, fill=colour)
        elif shape == "wide":
            w2, h2 = ew * 1.18, eh * 1.10
            draw.rounded_rectangle([ex - w2 / 2, cy - h2 / 2, ex + w2 / 2, cy + h2 / 2],
                                   radius=w2 / 2, fill=colour)
        elif shape == "dot":
            rr = ew * 0.52
            draw.ellipse([ex - rr, cy - rr, ex + rr, cy + rr], fill=colour)
        elif shape in ("flat", "line"):
            w2, h2 = ew * 1.55, ew * 0.40
            draw.rounded_rectangle([ex - w2 / 2, cy - h2 / 2, ex + w2 / 2, cy + h2 / 2],
                                   radius=h2 / 2, fill=colour)
        elif shape == "tired":
            w2, h2 = ew * 1.10, eh * 0.34
            yy = cy + eh * 0.15
            draw.rounded_rectangle([ex - w2 / 2, yy - h2 / 2, ex + w2 / 2, yy + h2 / 2],
                                   radius=h2 / 2, fill=colour)
        elif shape == "happy":
            # capped arch n — explicit polyline so the stroke is always visible
            arc = []
            for i in range(25):
                t = -1 + 2 * i / 24
                arc.append((ex + t * ew * 0.62, cy - math.sqrt(max(0.0, 1 - t * t)) * eh * 0.46))
            wpx = max(2, int(ew * 0.52))
            draw.line(arc, fill=colour, width=wpx, joint="curve")
            for pnt in (arc[0], arc[-1]):
                draw.ellipse([pnt[0] - wpx / 2, pnt[1] - wpx / 2,
                              pnt[0] + wpx / 2, pnt[1] + wpx / 2], fill=colour)
        elif shape == "closed":
            # cup smile u
            arc = []
            for i in range(25):
                t = -1 + 2 * i / 24
                arc.append((ex + t * ew * 0.58, cy + math.sqrt(max(0.0, 1 - t * t)) * eh * 0.34))
            wpx = max(2, int(ew * 0.50))
            draw.line(arc, fill=colour, width=wpx, joint="curve")
            for pnt in (arc[0], arc[-1]):
                draw.ellipse([pnt[0] - wpx / 2, pnt[1] - wpx / 2,
                              pnt[0] + wpx / 2, pnt[1] + wpx / 2], fill=colour)
        elif shape == "wink":
            if sgn < 0:
                arc = []
                for i in range(25):
                    t = -1 + 2 * i / 24
                    arc.append((ex + t * ew * 0.58,
                                cy + math.sqrt(max(0.0, 1 - t * t)) * eh * 0.34))
                wpx = max(2, int(ew * 0.50))
                draw.line(arc, fill=colour, width=wpx, joint="curve")
                for pnt in (arc[0], arc[-1]):
                    draw.ellipse([pnt[0] - wpx / 2, pnt[1] - wpx / 2,
                                  pnt[0] + wpx / 2, pnt[1] + wpx / 2], fill=colour)
            else:
                draw.rounded_rectangle([x0, y0, x1, y1], radius=r, fill=colour)
        elif shape == "spiral":
            pts = []
            for i in range(120):
                a = i / 119 * 2.6 * 2 * math.pi
                rr = ew * 0.10 + (i / 119) * ew * 1.02
                pts.append((ex + math.cos(a) * rr, cy + math.sin(a) * rr))
            draw.line(pts, fill=colour, width=max(2, int(ew * 0.24)), joint="curve")
        elif shape == "heart":
            rr = ew * 0.34
            draw.ellipse([ex - rr * 1.7, cy - rr * 1.35, ex - rr * 0.1, cy + rr * 0.1],
                         fill=colour)
            draw.ellipse([ex + rr * 0.1, cy - rr * 1.35, ex + rr * 1.7, cy + rr * 0.1],
                         fill=colour)
            draw.polygon([(ex - ew * 0.66, cy - rr * 0.1), (ex + ew * 0.66, cy - rr * 0.1),
                          (ex, cy + eh * 0.42)], fill=colour)
        elif shape == "star":
            pts = []
            for i in range(10):
                a = -math.pi / 2 + i * math.pi / 5
                rr = ew * 0.60 if i % 2 == 0 else ew * 0.25
                pts.append((ex + math.cos(a) * rr, cy + math.sin(a) * rr))
            draw.polygon(pts, fill=colour)
        else:
            draw.rounded_rectangle([x0, y0, x1, y1], radius=r, fill=colour)


# ----------------------------------------------------------------- badge -----
def draw_badge(img, kind, colour, scale, cx, base_y):
    if not kind:
        return
    W, H = img.size
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    bx = cx - 0.360 * scale
    by = base_y - 0.790 * scale
    bw, bh = 0.262 * scale, 0.188 * scale

    if kind == "dots":
        d.rounded_rectangle([bx - bw / 2, by - bh / 2, bx + bw / 2, by + bh / 2],
                            radius=bh * 0.46, fill=colour + (255,))
        d.polygon([(bx + bw * 0.02, by + bh * 0.30),
                   (bx + bw * 0.34, by + bh * 0.30),
                   (bx + bw * 0.12, by + bh * 0.86)], fill=colour + (255,))
        for o in (-bw * 0.22, 0, bw * 0.22):
            rr = bh * 0.135
            d.ellipse([bx + o - rr, by - rr, bx + o + rr, by + rr], fill=(255, 255, 255, 255))
    elif kind == "bang":
        rr = bh * 0.52
        d.ellipse([bx - rr, by - rr, bx + rr, by + rr], fill=colour + (255,))
        w2 = bw * 0.115
        d.rounded_rectangle([bx - w2, by - bh * 0.32, bx + w2, by + bh * 0.10],
                            radius=w2, fill=(255, 255, 255, 255))
        r2 = bh * 0.062
        d.ellipse([bx - r2, by + bh * 0.25 - r2, bx + r2, by + bh * 0.25 + r2],
                  fill=(255, 255, 255, 255))
    elif kind == "question":
        rr = bh * 0.52
        d.ellipse([bx - rr, by - rr, bx + rr, by + rr], fill=colour + (255,))
        w = max(2, int(bh * 0.075))
        d.arc([bx - bw * 0.10, by - bh * 0.36, bx + bw * 0.10, by + bh * 0.04],
              200, 20, fill=(255, 255, 255, 255), width=w)
        d.line([(bx + bw * 0.095, by - bh * 0.05), (bx, by + bh * 0.13)],
               fill=(255, 255, 255, 255), width=w)
        r2 = bh * 0.058
        d.ellipse([bx - r2, by + bh * 0.27 - r2, bx + r2, by + bh * 0.27 + r2],
                  fill=(255, 255, 255, 255))
    elif kind == "ring":
        rr = bh * 0.42
        d.ellipse([bx - rr, by - rr, bx + rr, by + rr], outline=(120, 40, 40, 255),
                  width=max(3, int(rr * 0.30)))
    elif kind == "dot":
        rr = bh * 0.30
        d.ellipse([bx - rr, by - rr, bx + rr, by + rr], fill=shade_dark(colour, 0.55, 255))

    img.alpha_composite(layer)


def shade_dark(c, amount, alpha):
    return (int(c[0] * (1 - amount)), int(c[1] * (1 - amount)), int(c[2] * (1 - amount)), alpha)


def draw_overlay(img, extra, scale, cx, base_y):
    if not extra:
        return
    W, H = img.size
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    white = (255, 255, 255, 255)

    if extra == "sparkle":
        for (sx, sy, sr) in ((0.335, 0.245, 0.033), (0.255, 0.180, 0.022),
                             (0.415, 0.190, 0.026)):
            x, y, r = sx * W, sy * H, sr * W
            d.polygon([(x, y - r * 2.3), (x + r * 0.6, y - r * 0.55), (x + r * 2.3, y),
                       (x + r * 0.6, y + r * 0.55), (x, y + r * 2.3), (x - r * 0.6, y + r * 0.55),
                       (x - r * 2.3, y), (x - r * 0.6, y - r * 0.55)], fill=white)
    elif extra == "sweat":
        x, y = cx + 0.30 * scale, base_y - 0.76 * scale
        r = 0.042 * scale
        d.ellipse([x - r, y - r, x + r, y + r], fill=(150, 205, 245, 235))
        d.polygon([(x - r * 0.85, y - r * 0.2), (x + r * 0.85, y - r * 0.2),
                   (x, y - r * 2.1)], fill=(150, 205, 245, 235))
    elif extra == "zzz":
        for (zx, zy, zs) in ((0.330, 0.300, 0.046), (0.398, 0.212, 0.030)):
            x, y, s = zx * W, zy * H, zs * W
            d.polygon([(x - s, y - s), (x + s, y - s), (x - s, y + s), (x + s, y + s)],
                      fill=white)
    elif extra == "bubbles":
        for (bx, by, br) in ((0.245, 0.255, 0.026), (0.170, 0.180, 0.018),
                             (0.120, 0.115, 0.012)):
            x, y, r = bx * W, by * H, br * W
            d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255, 210))

    img.alpha_composite(layer)


# ----------------------------------------------------------------- render ----
def render(key, colour, eye, badge, halo, extra, spec, outdir, tile, bg=BG):
    W = H = tile
    cx = W / 2.0
    scale = 0.66 * W
    base_y = H * 0.80

    poly = catmull_polygon(spec["outline"], scale, -scale, cx, base_y)
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).polygon(poly, fill=255)

    # -- soft floor shadow
    shadow = Image.new("L", (W, H), 0)
    sd = ImageDraw.Draw(shadow)
    sw, sh_ = scale * 0.42, scale * 0.055
    sd.ellipse([cx - sw, base_y - sh_ * 0.6, cx + sw, base_y + sh_ * 2.2], fill=110)
    shadow = shadow.filter(ImageFilter.GaussianBlur(scale * 0.045))

    # -- body base gradient
    body = vgradient(W, H, shade(colour, -0.30), shade(colour, -0.02),
                     y0=base_y - scale * 0.86, y1=base_y + scale * 0.02)

    # -- inner rim shading (volume)
    rim = inner_rim(mask, blur=max(2, scale * 0.055), strength=0.55)
    body = multiply_mask(body, rim)

    # -- top-front specular, broad + tight
    spec1 = radial(W, H, cx - scale * 0.13, base_y - scale * 0.60,
                   scale * 0.42, scale * 0.40, 0.55, 1.7)
    spec1 = spec1.filter(ImageFilter.GaussianBlur(scale * 0.05))
    body = screen(body, spec1, (255, 255, 255))

    spec2 = radial(W, H, cx - scale * 0.10, base_y - scale * 0.72,
                   scale * 0.15, scale * 0.13, 0.80, 1.5)
    spec2 = spec2.filter(ImageFilter.GaussianBlur(scale * 0.02))
    body = screen(body, spec2, (255, 255, 255))

    # -- bottom contact shade
    contact = radial(W, H, cx, base_y + scale * 0.10, scale * 0.55, scale * 0.20, 0.35, 2.0)
    body = multiply_mask(body, contact.filter(ImageFilter.GaussianBlur(scale * 0.05)))

    # -- composite body onto canvas
    canvas = Image.new("RGBA", (W, H), bg + (255,))
    floor = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    floor.paste((0, 0, 0, 255), (0, 0), shadow)
    canvas.alpha_composite(floor)

    halo_img = Image.new("RGB", (W, H), colour)
    halo_mask = mask.filter(ImageFilter.GaussianBlur(scale * 0.07)).point(
        lambda v: int(min(255, v * halo * 1.6)))
    halo_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    halo_layer.paste(halo_img, (0, 0), halo_mask)
    canvas = Image.alpha_composite(canvas, halo_layer)

    body_rgba = body.convert("RGBA")
    body_rgba.putalpha(mask)
    canvas = Image.alpha_composite(canvas, body_rgba)

    # -- blush (clipped to the body)
    b = spec["blush"]
    blush = Image.new("L", (W, H), 0)
    bd = ImageDraw.Draw(blush)
    brx, bry = b["radius_x"] * scale, b["radius_y"] * scale
    bcy = base_y - b["centre_y_from_bottom"] * scale
    for sgn in (-1, 1):
        bx = cx + sgn * b["centre_x"] * scale
        bd.ellipse([bx - brx, bcy - bry, bx + brx, bcy + bry], fill=int(255 * b["opacity"] * 2.1))
    blush = blush.filter(ImageFilter.GaussianBlur(scale * 0.028))
    blush = ImageChops.multiply(blush, mask)
    br, bg_, bb = (int(b["colour"][i:i+2], 16) for i in (1, 3, 5))
    blush_layer = Image.new("RGBA", (W, H), (br, bg_, bb, 0))
    blush_layer.putalpha(blush)
    canvas = Image.alpha_composite(canvas, blush_layer)

    # -- eyes (clipped to the body)
    eyes = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ed = ImageDraw.Draw(eyes)
    draw_eyes(ed, eye, spec, scale, cx, base_y, W, H)
    eyes.putalpha(ImageChops.multiply(eyes.split()[3], mask))
    canvas = Image.alpha_composite(canvas, eyes)

    # -- overlays + badge
    draw_overlay(canvas, extra, scale, cx, base_y)
    draw_badge(canvas, badge, colour, scale, cx, base_y)

    out = os.path.join(outdir, f"lupy-{key}.png")
    canvas.convert("RGB").save(out)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(HERE, "..", "..", "docs", "concepts", "states"))
    ap.add_argument("--tile", type=int, default=420)
    ap.add_argument("--sheet", action="store_true")
    args = ap.parse_args()

    spec = json.load(open(SPEC_PATH))
    os.makedirs(args.out, exist_ok=True)

    made = []
    for key, colour, eye, badge, halo, extra in STATES + EMOTES:
        made.append(render(key, colour, eye, badge, halo, extra, spec, args.out, args.tile))
    print(f"rendered {len(made)} states -> {os.path.abspath(args.out)}")

    if args.sheet:
        cols, pad = 5, 10
        rows = (len(made) + cols - 1) // cols
        tw = args.tile
        sheet = Image.new("RGB", (cols * tw + pad * (cols + 1),
                                  rows * tw + pad * (rows + 1)), (11, 11, 13))
        for i, path in enumerate(made):
            im = Image.open(path)
            r, c = divmod(i, cols)
            sheet.paste(im, (pad + c * (tw + pad), pad + r * (tw + pad)))
        out = os.path.join(os.path.dirname(args.out), "lupy-character-states.png")
        sheet.save(out)
        print(f"sheet -> {out}")


if __name__ == "__main__":
    main()
