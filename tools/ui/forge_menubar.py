#!/usr/bin/env python3
"""Forge Lupy's OWN menu-bar template icon from the locked character geometry.

White-label law (founder, 2026-10-22): Coucou is engineering blueprint only —
no Coucou artwork ships in Lupy. The old build copied Coucou's menubar icon
into Lupy. This forge draws OUR gumdrop from the same measured outline the app
icon uses (`LupyGeometry.swift` `outline` + eye metrics, parsed — never
guessed), as a macOS template image: solid black silhouette, eyes punched
transparent, alpha IS the picture.

Outputs (committed, copied by build-no-xcode.sh into Contents/Resources):
  Mac/LupyAssets/MenuBarIcon.png     18x18  (1x)
  Mac/LupyAssets/MenuBarIcon@2x.png  36x36  (2x)

Run: python3 tools/ui/forge_menubar.py   (from repo root)
"""
import os
import re
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GEOMETRY_SWIFT = os.path.join(ROOT, "Mac/Sources/Lupy/Character/LupyGeometry.swift")
OUT_DIR = os.path.join(ROOT, "Mac/LupyAssets")


def load_geometry():
    src = open(GEOMETRY_SWIFT).read()
    m = re.search(r"static let outline: \[\(Double, Double\)\] = \[(.*?)\n    \]", src, re.S)
    if not m:
        sys.exit("FORGE FAILED: outline not found — refusing to guess")
    outline = [(float(a), float(b)) for a, b in
               re.findall(r"\((-?\d+\.\d+), (-?\d+\.\d+)\)", m.group(1))]
    if len(outline) < 100:
        sys.exit(f"FORGE FAILED: outline has only {len(outline)} points")

    def num(name):
        mm = re.search(rf"static let {name}: Double = (-?[\d.]+)", src)
        if not mm:
            sys.exit(f"FORGE FAILED: {name} not found")
        return float(mm.group(1))

    return {
        "outline": outline,
        "aspect": num("bodyAspect"),
        "eye_w": num("eyeW"), "eye_h": num("eyeH"),
        "eye_cx": num("eyeCentreX"), "eye_cy": num("eyeCentreYFromBase"),
    }


def catmull_closed(pts, samples_per_seg=6):
    n = len(pts)
    out = []
    for i in range(n):
        p0, p1, p2, p3 = pts[(i - 1) % n], pts[i], pts[(i + 1) % n], pts[(i + 2) % n]
        for s in range(samples_per_seg):
            t = s / samples_per_seg
            t2, t3 = t * t, t * t * t
            out.append((
                0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t
                       + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2
                       + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3),
                0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t
                       + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2
                       + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3),
            ))
    return out


def render(geo, px, supersample=8):
    """Template silhouette at px*px (supersampled then box-downsampled)."""
    S = px * supersample
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Body occupies ~86% of width, centred; outline points are in unit u space
    # (x centred 0, y measured UP from base 0..aspect) per LupyGeometry.
    body_w = S * 0.86
    body_h = body_w * geo["aspect"]
    cx = S / 2
    base_y = (S + body_h) / 2  # bottom of the body in image coords (y down)

    def to_px(x, y_up):
        return (cx + x * body_w, base_y - y_up * body_w)

    poly = [to_px(x, y) for x, y in catmull_closed(geo["outline"])]
    d.polygon(poly, fill=(0, 0, 0, 255))
    # Eyes punched transparent (template images knock out via alpha).
    ew, eh = geo["eye_w"] * body_w, geo["eye_h"] * body_w
    for sx in (-1, 1):
        ex, ey = to_px(sx * geo["eye_cx"], geo["eye_cy"])
        d.ellipse([ex - ew / 2, ey - eh / 2, ex + ew / 2, ey + eh / 2], fill=(0, 0, 0, 0))
    return img.resize((px, px), Image.LANCZOS)


def main():
    geo = load_geometry()
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, px in (("MenuBarIcon.png", 18), ("MenuBarIcon@2x.png", 36)):
        path = os.path.join(OUT_DIR, name)
        render(geo, px).save(path)
        print(f"forged {path} ({px}x{px}, outline {len(geo['outline'])} pts)")


if __name__ == "__main__":
    main()
