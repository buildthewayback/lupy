#!/usr/bin/env python3
"""Render Lupy's ORIGINAL app icon (a small wolf pup under a moon) into the asset catalog.

Geometry mirrors App/Sources/LupyCharacter.swift (LupyRenderer) so the icon matches the in-app
character. Drawn at 4x and downsampled for anti-aliasing. Requires Pillow.
Usage: python3 scripts/make-icon.py
"""
import json
import math
import os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "App", "Resources", "Assets.xcassets", "AppIcon.appiconset")
SS = 4
N = 1024 * SS


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def quad(p0, c, p1, steps=24):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * c[0] + t * t * p1[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * c[1] + t * t * p1[1]) for t in [i / steps for i in range(steps + 1)]]


def rounded_rect_mask(size, box, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle(box, radius=radius, fill=255)
    return m


def render():
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    # macOS icon grid: 824/1024 body with soft shadow.
    inset, body = 100 * SS, 824 * SS
    box = (inset, inset, inset + body, inset + body)
    shadow = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((box[0], box[1] + 14 * SS, box[2], box[3] + 14 * SS), radius=185 * SS, fill=(0, 0, 0, 110))
    img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(18 * SS)))
    # Night-sky gradient
    bg = Image.new("RGBA", (N, N))
    top, bottom = hexc("#25304A"), hexc("#090C14")
    px = bg.load()
    for y in range(N):
        t = min(1, max(0, (y - box[1]) / body))
        col = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,)
        for x in range(N):
            px[x, y] = col
    img.paste(bg, (0, 0), rounded_rect_mask((N, N), box, 185 * SS))
    d = ImageDraw.Draw(img)
    # Stars
    for (sx, sy, sr) in [(250, 260, 5), (330, 205, 3), (790, 430, 4), (215, 420, 3), (640, 190, 3), (820, 600, 3)]:
        d.ellipse([(sx - sr) * SS, (sy - sr) * SS, (sx + sr) * SS, (sy + sr) * SS], fill=hexc("#F5F6F8", 200))
    # Crescent moon (amber)
    mx, my, mr = 770 * SS, 225 * SS, 74 * SS
    moon = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    md = ImageDraw.Draw(moon)
    md.ellipse([mx - mr, my - mr, mx + mr, my + mr], fill=hexc("#FFB547"))
    md.ellipse([mx - mr + 42 * SS, my - mr - 22 * SS, mx + mr + 42 * SS, my + mr - 22 * SS], fill=(0, 0, 0, 0))
    glow = moon.filter(ImageFilter.GaussianBlur(28 * SS))
    img = Image.alpha_composite(img, Image.blend(Image.new("RGBA", (N, N), (0, 0, 0, 0)), glow, 0.55))
    img = Image.alpha_composite(img, moon)
    d = ImageDraw.Draw(img)

    # Lupy (same proportions as LupyRenderer): s = character canvas size
    s = 760 * SS
    cx, cy = 512 * SS, 545 * SS + 0.09 * s * 0.25
    r = 0.29 * s
    fur, fur_dark = hexc("#AEBBCC"), hexc("#76859B")
    muzzle, inner_ear, eye, nose = hexc("#EEF1F5"), hexc("#F3B27A", 220), hexc("#1B1E24"), hexc("#2A2E36")
    for side in (-1, 1):
        bx, by = cx + side * r * 0.62, cy - r * 0.6
        pts = [(bx - side * r * 0.44, by + r * 0.14)]
        pts += quad(pts[-1], (bx - side * r * 0.26, by - r * 0.56), (bx + side * r * 0.2, by - r * 0.82))[1:]
        pts += quad(pts[-1], (bx + side * r * 0.46, by - r * 0.36), (bx + side * r * 0.44, by + r * 0.22))[1:]
        d.polygon(pts, fill=fur_dark)
        ip = [(bx - side * r * 0.22, by + r * 0.04)]
        ip += quad(ip[-1], (bx - side * r * 0.12, by - r * 0.4), (bx + side * r * 0.15, by - r * 0.56))[1:]
        ip += quad(ip[-1], (bx + side * r * 0.29, by - r * 0.26), (bx + side * r * 0.27, by + r * 0.1))[1:]
        d.polygon(ip, fill=inner_ear)
    for side in (-1, 1):
        d.polygon([(cx + side * r * 0.95, cy - r * 0.02), (cx + side * r * 1.24, cy + r * 0.34), (cx + side * r * 0.86, cy + r * 0.46)], fill=fur_dark)
    # Head with vertical gradient
    head = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    hbox = (cx - r * 1.08, cy - r * 0.95, cx + r * 1.08, cy + r * 0.95)
    mask = Image.new("L", (N, N), 0)
    ImageDraw.Draw(mask).ellipse(hbox, fill=255)
    grad = Image.new("RGBA", (N, N))
    gp = grad.load()
    y0, y1 = int(hbox[1]), int(hbox[3])
    for y in range(max(0, y0), min(N, y1 + 1)):
        t = (y - y0) / max(1, y1 - y0)
        col = tuple(int(fur[i] + (fur_dark[i] - fur[i]) * t) for i in range(3)) + (255,)
        for x in range(int(hbox[0]), int(hbox[2]) + 1):
            gp[x, y] = col
    head.paste(grad, (0, 0), mask)
    img = Image.alpha_composite(img, head)
    d = ImageDraw.Draw(img)
    stripe = [(cx, cy - r * 0.92)] + quad((cx, cy - r * 0.92), (cx - r * 0.13, cy - r * 0.52), (cx, cy - r * 0.2))[1:]
    stripe += quad((cx, cy - r * 0.2), (cx + r * 0.13, cy - r * 0.52), (cx, cy - r * 0.92))[1:]
    d.polygon(stripe, fill=hexc("#EEF1F5", 128))
    d.ellipse((cx - r * 0.56, cy + r * 0.02, cx + r * 0.56, cy + r * 0.8), fill=muzzle)
    for side in (-1, 1):
        ex, ey = cx + side * r * 0.42, cy - r * 0.17
        w, h = r * 0.21, r * 0.27
        d.ellipse((ex - w / 2, ey - h / 2, ex + w / 2, ey + h / 2), fill=eye)
        hl = r * 0.07
        d.ellipse((ex + w * 0.06, ey - h / 2 + h * 0.14, ex + w * 0.06 + hl, ey - h / 2 + h * 0.14 + hl), fill=(255, 255, 255, 230))
    ny = cy + r * 0.2
    npts = [(cx - r * 0.15, ny)] + quad((cx - r * 0.15, ny), (cx, ny - r * 0.09), (cx + r * 0.15, ny))[1:]
    npts += quad((cx + r * 0.15, ny), (cx, ny + r * 0.22), (cx - r * 0.15, ny))[1:]
    d.polygon(npts, fill=nose)
    my2 = ny + r * 0.16
    smile = quad((cx - r * 0.2, my2), (cx - r * 0.1, my2 + r * 0.12), (cx, my2)) + quad((cx, my2), (cx + r * 0.1, my2 + r * 0.12), (cx + r * 0.2, my2))[1:]
    d.line(smile, fill=nose, width=int(r * 0.06), joint="curve")
    return img.resize((1024, 1024), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    base = render()
    entries = []
    for pt in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            px = pt * scale
            name = f"icon_{pt}x{pt}{'@2x' if scale == 2 else ''}.png"
            base.resize((px, px), Image.LANCZOS).save(os.path.join(OUT, name))
            entries.append({"idiom": "mac", "size": f"{pt}x{pt}", "scale": f"{scale}x", "filename": name})
    with open(os.path.join(OUT, "Contents.json"), "w") as f:
        json.dump({"images": entries, "info": {"author": "xcode", "version": 1}}, f, indent=2)
    with open(os.path.join(os.path.dirname(OUT), "Contents.json"), "w") as f:
        json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)
    accent = os.path.join(os.path.dirname(OUT), "AccentColor.colorset")
    os.makedirs(accent, exist_ok=True)
    with open(os.path.join(accent, "Contents.json"), "w") as f:
        json.dump({"colors": [{"idiom": "universal", "color": {"color-space": "srgb", "components": {"red": "1.000", "green": "0.710", "blue": "0.278", "alpha": "1.000"}}}],
                   "info": {"author": "xcode", "version": 1}}, f, indent=2)
    os.makedirs(os.path.join(ROOT, "docs", "media"), exist_ok=True)
    base.resize((512, 512), Image.LANCZOS).save(os.path.join(ROOT, "docs", "media", "lupy-icon.png"))
    print("icon written to", OUT)


if __name__ == "__main__":
    main()
