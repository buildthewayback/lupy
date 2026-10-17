#!/usr/bin/env python3
"""
LUPY character state renderer — spec-driven, body-locked.

Every state draws the SAME body path from lupy-character-spec-v1.json; only the
eye shape, body tint, halo and badge change. That is the whole character system:
one body, expression in the eyes.

Design-time asset generator (needs ImageMagick). The shipping app draws the same
geometry procedurally in Swift, the way Coucou's BotEngine does.

Usage:
    python3 tools/character/render_states.py [--out DIR] [--tile PX] [--sheet]
"""
import json, math, os, subprocess, argparse, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
SPEC_PATH = os.path.join(HERE, "..", "..", "docs", "concepts", "lupy-character-spec-v1.json")


# ---------------------------------------------------------------- geometry ---
def catmull_to_cubic(pts, sx, sy, ox, oy):
    n = len(pts)
    f = lambda p: (p[0] * sx + ox, p[1] * sy + oy)
    x0, y0 = f(pts[0])
    d = f"M {x0:.2f},{y0:.2f} "
    for i in range(n):
        p0, p1, p2, p3 = pts[(i - 1) % n], pts[i], pts[(i + 1) % n], pts[(i + 2) % n]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6.0, p1[1] + (p2[1] - p0[1]) / 6.0)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6.0, p2[1] - (p3[1] - p1[1]) / 6.0)
        a, b, c = f(c1), f(c2), f(p2)
        d += f"C {a[0]:.2f},{a[1]:.2f} {b[0]:.2f},{b[1]:.2f} {c[0]:.2f},{c[1]:.2f} "
    return d + "Z"


def run(*args):
    subprocess.run(args, check=True, capture_output=True)


def shade(hexcolour, amount):
    r, g, b = (int(hexcolour[i:i + 2], 16) for i in (1, 3, 5))
    if amount >= 0:
        r, g, b = (int(c + (255 - c) * amount) for c in (r, g, b))
    else:
        r, g, b = (int(c * (1 + amount)) for c in (r, g, b))
    return "#%02X%02X%02X" % (r, g, b)


# ------------------------------------------------------------------ states ---
STATES = [
    ("idle",      "idle",      "#FFFFFF", "pill",     None,      0.20, None),
    ("working",   "working",   "#3B9EFF", "pill",     "dots",    0.50, None),
    ("thinking",  "thinking",  "#8B5CF6", "pill",     "dots",    0.46, None),
    ("searching", "searching", "#635FF2", "pill",     "dots",    0.50, None),
    ("approval",  "approval",  "#F5A523", "wide",     "bang",    0.55, None),
    ("question",  "question",  "#22D3EE", "pill",     "question",0.50, None),
    ("error",     "error",     "#F4505E", "flat",     "dot",     0.50, None),
    ("finished",  "finished",  "#34D399", "happy",    "dot",     0.46, "sparkle"),
    ("ratelimit", "ratelimit", "#F0923C", "tired",    "dot",     0.42, "sweat"),
    ("sleeping",  "sleeping",  "#94A2B8", "closed",   None,      0.18, "zzz"),
    ("dizzy",     "dizzy",     "#F472B6", "spiral",   None,      0.50, "bubbles"),
]

EMOTES = [
    ("love",      "love",      "#FF6B9D", "heart",   None, 0.42, None),
    ("surprised", "surprised", "#FFFFFF", "wide",    None, 0.28, None),
    ("wink",      "wink",      "#FFFFFF", "wink",    None, 0.24, None),
    ("happy",     "happy",     "#FFFFFF", "happy",   None, 0.32, None),
    ("annoyed",   "annoyed",   "#E8E8EF", "line",    None, 0.18, None),
    ("yawn",      "yawn",      "#FFFFFF", "closed",  None, 0.18, "zzz"),
    ("proud",     "proud",     "#FFFFFF", "star",    None, 0.32, "sparkle"),
    ("listening", "listening", "#5EEAD4", "wide",    None, 0.46, None),
]


# ------------------------------------------------------------------ layers ---
def alpha_layer(W, H, draws, stroke=None, fill="white", tmp=""):
    """Transparent RGBA canvas with shapes drawn on it."""
    out = os.path.join(tmp, "layer.png")
    cmd = ["convert", "-size", f"{W}x{H}", "xc:none",
           "-fill", fill, "-stroke", stroke or "none"]
    if stroke:
        cmd += ["-strokewidth", f"{stroke[1]:.1f}"] if isinstance(stroke, tuple) else []
    for d in draws:
        cmd += ["-draw", d]
    cmd += [out]
    run(*cmd)
    return out


def rounded(cx, cy, w, h, r):
    x0, y0 = cx - w / 2, cy - h / 2
    return f"roundrectangle {x0:.1f},{y0:.1f} {x0+w:.1f},{y0+h:.1f} {r:.1f},{r:.1f}"


def eye_draws(shape, spec, scale, cx, base_y):
    """Returns (draws, stroke_width_or_None). Solid shapes fill, curved ones stroke."""
    e = spec["eye"]
    ew, eh = e["w"] * scale, e["h"] * scale
    dx = e["centre_x"] * scale
    cy = base_y - e["centre_y_from_bottom"] * scale
    solid, stroke = [], []
    sw = ew * 0.30 if shape == "spiral" else ew * 0.46

    for sgn in (-1, 1):
        ex = cx + sgn * dx
        if shape == "pill":
            solid.append(rounded(ex, cy, ew, eh, ew / 2))
        elif shape == "wide":
            solid.append(rounded(ex, cy, ew * 1.18, eh * 1.10, ew / 2))
        elif shape == "dot":
            r = ew * 0.52
            solid.append(f"circle {ex:.1f},{cy:.1f} {ex+r:.1f},{cy:.1f}")
        elif shape == "flat":
            w, h = ew * 1.55, ew * 0.42
            solid.append(rounded(ex, cy, w, h, h / 2))
        elif shape == "line":
            w, h = ew * 1.65, ew * 0.44
            solid.append(rounded(ex, cy, w, h, h / 2))
        elif shape == "tired":
            w, h = ew * 1.20, eh * 0.36
            solid.append(rounded(ex, cy + eh * 0.14, w, h, h / 2))
        elif shape == "happy":
            stroke.append(f"ellipse {ex:.1f},{cy + eh*0.16:.1f} {ew*0.98:.1f},{eh*0.46:.1f} 200,340")
        elif shape == "closed":
            stroke.append(f"ellipse {ex:.1f},{cy + eh*0.20:.1f} {ew*0.94:.1f},{eh*0.46:.1f} 200,340")
        elif shape == "wink":
            if sgn < 0:
                stroke.append(f"ellipse {ex:.1f},{cy + eh*0.18:.1f} {ew*0.9:.1f},{eh*0.44:.1f} 200,340")
            else:
                solid.append(rounded(ex, cy, ew, eh, ew / 2))
        elif shape == "spiral":
            moves = []
            turns = 2.6
            for i in range(96):
                a = i / 95 * turns * 2 * math.pi
                r = ew * 0.10 + (i / 95) * ew * 0.62
                x_ = ex + math.cos(a) * r
                y_ = cy - math.sin(a) * r
                moves.append(("M" if i == 0 else "L") + f" {x_:.1f},{y_:.1f}")
            stroke.append("path '" + " ".join(moves) + "'")
        elif shape == "heart":
            r = ew * 0.33
            solid.append(f"circle {ex-r*0.74:.1f},{cy-r*0.30:.1f} {ex-r*0.74+r:.1f},{cy-r*0.30:.1f}")
            solid.append(f"circle {ex+r*0.74:.1f},{cy-r*0.30:.1f} {ex+r*0.74+r:.1f},{cy-r*0.30:.1f}")
            solid.append(f"polygon {ex-ew*0.66:.1f},{cy+r*0.12:.1f} {ex+ew*0.66:.1f},{cy+r*0.12:.1f} "
                         f"{ex:.1f},{cy+eh*0.40:.1f}")
        elif shape == "star":
            pts = []
            for i in range(10):
                a = -math.pi / 2 + i * math.pi / 5
                r = ew * 0.60 if i % 2 == 0 else ew * 0.25
                pts.append(f"{ex + math.cos(a)*r:.1f},{cy + math.sin(a)*r:.1f}")
            solid.append("polygon " + " ".join(pts))
        else:
            solid.append(rounded(ex, cy, ew, eh, ew / 2))
    return solid, stroke, sw


def badge_draws(kind, colour, scale, cx, base_y):
    """Reference-style badge: a rounded speech bubble sitting on the upper-right edge."""
    if not kind:
        return []
    bx, by = cx + 0.315 * scale, base_y - 0.70 * scale
    r = 0.115 * scale
    bw, bh = r * 2.30, r * 1.85
    tail = (f"polygon {bx-r*0.30:.1f},{by+bh*0.42:.1f} {bx+r*0.34:.1f},{by+bh*0.42:.1f} "
            f"{bx-r*0.52:.1f},{by+bh*1.02:.1f}")

    if kind == "dots":
        d = [(rounded(bx, by, bw, bh, r * 0.62), colour), (tail, colour)]
        for o in (-r * 0.52, 0, r * 0.52):
            d.append((f"circle {bx+o:.1f},{by-r*0.05:.1f} {bx+o+r*0.19:.1f},{by-r*0.05:.1f}", "white"))
        return d
    if kind == "bang":
        d = [(rounded(bx, by, bw, bh, r * 0.62), colour), (tail, colour)]
        d.append((rounded(bx, by - r * 0.10, r * 0.26, r * 0.66, r * 0.13), "white"))
        d.append((f"circle {bx:.1f},{by+r*0.52:.1f} {bx+r*0.15:.1f},{by+r*0.52:.1f}", "white"))
        return d
    if kind == "question":
        d = [(rounded(bx, by, bw, bh, r * 0.62), colour), (tail, colour)]
        # simple question mark: hook arc + dot
        d.append((f"ellipse {bx:.1f},{by-r*0.28:.1f} {r*0.30:.1f},{r*0.30:.1f} 200,20", "white"))
        d.append((f"path 'M {bx-r*0.30:.1f},{by-r*0.05:.1f} L {bx:.1f},{by+r*0.22:.1f}'", "white"))
        d.append((f"circle {bx:.1f},{by+r*0.48:.1f} {bx+r*0.13:.1f},{by+r*0.48:.1f}", "white"))
        return d
    if kind == "dot":
        return [(f"circle {bx:.1f},{by:.1f} {bx+r*0.60:.1f},{by:.1f}", colour)]
    return []


def extra_draws(extra, W, H, scale, cx, base_y):
    d = []
    if extra == "sparkle":
        for (sx, sy, sr) in ((0.335, 0.245, 0.032), (0.255, 0.180, 0.021),
                             (0.415, 0.190, 0.025)):
            x, y, r = sx * W, sy * H, sr * W
            d.append(f"polygon {x:.1f},{y-r*2.3:.1f} {x+r*0.6:.1f},{y-r*0.55:.1f} "
                     f"{x+r*2.3:.1f},{y:.1f} {x+r*0.6:.1f},{y+r*0.55:.1f} "
                     f"{x:.1f},{y+r*2.3:.1f} {x-r*0.6:.1f},{y+r*0.55:.1f} "
                     f"{x-r*2.3:.1f},{y:.1f} {x-r*0.6:.1f},{y-r*0.55:.1f}")
    if extra == "sweat":
        x, y = cx + 0.30 * scale, base_y - 0.76 * scale
        r = 0.040 * scale
        d.append(f"circle {x:.1f},{y:.1f} {x+r:.1f},{y:.1f}")
        d.append(f"polygon {x-r*0.85:.1f},{y-r*0.22:.1f} {x+r*0.85:.1f},{y-r*0.22:.1f} "
                 f"{x:.1f},{y-r*2.1:.1f}")
    if extra == "zzz":
        for (zx, zy, zs) in ((0.330, 0.300, 0.046), (0.398, 0.212, 0.030)):
            x, y, s = zx * W, zy * H, zs * W
            d.append(f"polygon {x-s:.1f},{y-s:.1f} {x+s:.1f},{y-s:.1f} "
                     f"{x-s:.1f},{y+s:.1f} {x+s:.1f},{y+s:.1f}")
    if extra == "bubbles":
        for (bx, by, br) in ((0.300, 0.300, 0.024), (0.362, 0.248, 0.017),
                             (0.412, 0.196, 0.011)):
            x, y, r = bx * W, by * H, br * W
            d.append(f"circle {x:.1f},{y:.1f} {x+r:.1f},{y:.1f}")
    return d


# ------------------------------------------------------------------ render ---
def render_state(key, label, colour, eye, badge, halo, extra, spec, outdir, tile, bg):
    W = H = tile
    tmp = os.path.join(outdir, f".tmp_{key}")
    shutil.rmtree(tmp, ignore_errors=True)
    os.makedirs(tmp, exist_ok=True)

    cx = W / 2.0
    scale = 0.70 * W
    base_y = H * 0.80
    path = catmull_to_cubic(spec["outline"], scale, -scale, cx, base_y)

    # ---- body mask (real alpha) ----
    mask = os.path.join(tmp, "mask.png")
    run("convert", "-size", f"{W}x{H}", "xc:none", "-fill", "white", "-stroke", "none",
        "-draw", f"path '{path}'", "-colorspace", "sRGB", "-type", "TrueColorAlpha", mask)

    # ---- body: vertical gradient + soft top-front specular, clipped to mask ----
    grad = os.path.join(tmp, "grad.png")
    run("convert", "-size", f"{W}x{H}",
        f"gradient:{shade(colour,0.10)}-{shade(colour,-0.10)}",
        "-alpha", "set", "-type", "TrueColorAlpha", grad)
    # radial white -> transparent, screened onto the body (never an opaque blob)
    spec_l = os.path.join(tmp, "spec.png")
    run("convert", "-size", f"{W}x{H}", "radial-gradient:white-none",
        "-resize", f"{int(0.62*W)}x{int(0.78*H)}!",
        "-background", "none", "-gravity", "northwest",
        "-extent", f"{W}x{H}", "-roll", f"+{int(-0.10*W)}+{int(-0.16*H)}",
        "-channel", "A", "-evaluate", "multiply", "0.9", "+channel", spec_l)
    spec_c = os.path.join(tmp, "specc.png")
    run("convert", spec_l, mask, "-compose", "DstIn", "-composite", spec_c)
    body = os.path.join(tmp, "body.png")
    run("convert", grad, spec_c, "-compose", "screen", "-composite",
        "-alpha", "set", "-type", "TrueColorAlpha",
        mask, "-compose", "DstIn", "-composite", "-colorspace", "sRGB", body)

    # ---- blush ----
    b = spec["blush"]
    blush = os.path.join(tmp, "blush.png")
    run("convert", "-size", f"{W}x{H}", "xc:none", "-fill", b["colour"], "-stroke", "none",
        "-draw", f"ellipse {cx-b['centre_x']*scale:.1f},{base_y-b['centre_y_from_bottom']*scale:.1f} "
                 f"{b['radius_x']*scale:.1f},{b['radius_y']*scale:.1f} 0,360",
        "-draw", f"ellipse {cx+b['centre_x']*scale:.1f},{base_y-b['centre_y_from_bottom']*scale:.1f} "
                 f"{b['radius_x']*scale:.1f},{b['radius_y']*scale:.1f} 0,360",
        "-blur", f"0x{int(0.038*W)}",
        "-evaluate", "multiply", str(b["opacity"]*1.5), blush)
    blush_c = os.path.join(tmp, "blushc.png")
    run("convert", blush, mask, "-compose", "DstIn", "-composite", blush_c)

    body_b = os.path.join(tmp, "bodyb.png")
    run("convert", body, blush_c, "-compose", "over", "-composite", body_b)

    # ---- eyes ----
    solid, stroke, sw = eye_draws(eye, spec, scale, cx, base_y)
    eyes = os.path.join(tmp, "eyes.png")
    run("convert", "-size", f"{W}x{H}", "xc:none",
        "-fill", "#000000", "-stroke", "none", *sum((["-draw", d] for d in solid), []),
        "-fill", "none", "-stroke", "#000000", "-strokewidth", f"{sw:.1f}",
        *sum((["-draw", "stroke-linecap round " + d] for d in stroke), []), eyes)
    eyes_c = os.path.join(tmp, "eyesc.png")
    run("convert", eyes, mask, "-compose", "DstIn", "-composite", eyes_c)

    body_full = os.path.join(tmp, "bodyfull.png")
    run("convert", body_b, eyes_c, "-compose", "over", "-composite", body_full)

    # ---- halo (transparent, outside the body) ----
    halo_img = os.path.join(tmp, "halo.png")
    run("convert", mask, "-blur", f"0x{int(0.055*W)}",
        "-fill", colour, "-colorize", "100",
        "-evaluate", "multiply", str(halo), halo_img)

    # ---- extras ----
    extra_img = None
    ed = extra_draws(extra, W, H, scale, cx, base_y)
    if ed:
        extra_img = os.path.join(tmp, "extra.png")
        run("convert", "-size", f"{W}x{H}", "xc:none", "-fill", "white", "-stroke", "none",
            *sum((["-draw", d] for d in ed), []), extra_img)

    # ---- badge ----
    badge_img = None
    bd = badge_draws(badge, shade(colour, 0.0), scale, cx, base_y)
    if bd:
        badge_img = os.path.join(tmp, "badge.png")
        layers = []
        for d, col in bd:
            l = os.path.join(tmp, f"b{len(layers)}.png")
            stroke = d.startswith("ellipse") or d.startswith("path 'M")
            run("convert", "-size", f"{W}x{H}", "xc:none",
                "-fill", "none" if stroke else col,
                "-stroke", col if stroke else "none",
                "-strokewidth", f"{max(2.0, 0.022*scale):.1f}",
                "-draw", d, l)
            layers.append(l)
        if len(layers) == 1:
            shutil.copy(layers[0], badge_img)
        else:
            run("convert", *layers, "-compose", "over", "-composite", badge_img)

    # ---- compose ----
    out = os.path.join(outdir, f"lupy-{key}.png")
    chain = ["-size", f"{W}x{H}", f"xc:{bg}", halo_img, "-compose", "screen", "-composite",
             body_full, "-compose", "over", "-composite"]
    if badge_img:
        chain += [badge_img, "-compose", "over", "-composite"]
    if extra_img:
        chain += [extra_img, "-compose", "over", "-composite"]
    run("convert", *chain, out)
    shutil.rmtree(tmp, ignore_errors=True)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(HERE, "..", "..", "docs", "concepts", "states"))
    ap.add_argument("--tile", type=int, default=420)
    ap.add_argument("--bg", default="#121216")
    ap.add_argument("--sheet", action="store_true")
    args = ap.parse_args()

    spec = json.load(open(SPEC_PATH))
    os.makedirs(args.out, exist_ok=True)

    made = [render_state(*r, spec=spec, outdir=args.out, tile=args.tile, bg=args.bg)
            for r in STATES]
    made += [render_state(*r, spec=spec, outdir=args.out, tile=args.tile, bg=args.bg)
             for r in EMOTES]
    print(f"rendered {len(made)} states -> {os.path.abspath(args.out)}")

    if args.sheet:
        sheet = os.path.join(os.path.dirname(args.out), "lupy-character-states.png")
        run("montage", *made, "-tile", "5x4", "-geometry", "+8+8",
            "-background", "#0b0b0d", sheet)
        print(f"sheet -> {sheet}")


if __name__ == "__main__":
    main()
