#!/usr/bin/env python3
"""THE ICON FORGE — renders LUPY's locked character into the app icon, everywhere.

One character, one geometry: this forge parses the shipped kernel geometry
(`Mac/Sources/Lupy/Character/LupyGeometry.swift` — itself generated from
`docs/concepts/lupy-character-spec-v1.json` by tools/character/gen_geometry.py)
and reads the same law the app reads: pure-white body, `showsBlush` honoured,
flat-matte-black capsule eyes at the measured metrics, and the idle glow exactly
as the in-app renderer does it (silhouette blurred at 0.09 body-widths, white at
the idle strength — see LupyCharacterMath / tools/character/scene.py). If the
kernel geometry ever changes, re-run this and the icon follows: the icon cannot
quietly disagree with the app again (founder law: "there is no chance for
character error is branding" — docs/LUPY_BRAND_CHARACTER.md).

Outputs (all from one 4x-supersampled master):
  · Mac/CoucouAssets/Assets.xcassets/AppIcon.appiconset/*.png + Contents.json
      → the Xcode road (actool compiles these; project.yml's
        ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon).
  · Mac/LupyAppIcon/AppIcon.icns + AppIcon-1024.png
      → the no-Xcode road (scripts/build-no-xcode.sh copies the .icns into
        Lupy.app; Mac/Resources/Info.plist names it via CFBundleIconFile),
        and the preview the founder eyeballs.
  · Install LUPY.app/Contents/Resources/AppIcon.icns
      → the double-click installer's face (the same icon: what you double-click
        is who you get).

The .icns is written by hand (PNG-backed entries — the same container `iconutil`
produces) so the forge runs anywhere Pillow runs, no Mac required.

Usage:  python3 tools/ui/make_appicon.py           # forge + write
        python3 tools/ui/make_appicon.py --check   # verify committed outputs
Exit 0 = forged (or, with --check, everything already matches).
"""
import io
import json
import os
import re
import struct
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GEOMETRY_SWIFT = os.path.join(ROOT, "Mac", "Sources", "Lupy", "Character", "LupyGeometry.swift")
APPICONSET = os.path.join(ROOT, "Mac", "CoucouAssets", "Assets.xcassets", "AppIcon.appiconset")
ICNS_DIR = os.path.join(ROOT, "Mac", "LupyAppIcon")
ICNS_PATH = os.path.join(ICNS_DIR, "AppIcon.icns")
PREVIEW_PATH = os.path.join(ICNS_DIR, "AppIcon-1024.png")
INSTALLER_ICNS = os.path.join(ROOT, "Install LUPY.app", "Contents", "Resources", "AppIcon.icns")

# ── macOS icon grid + composition (1024-space) ────────────────────────────────
SS = 4                       # supersampling: render at 4096, downsample LANCZOS
N = 1024 * SS
TILE_INSET = 100 * SS        # the 824/1024 body, Apple's grid
TILE = 824 * SS
TILE_RADIUS = 185 * SS       # 22.45 % of the tile — the squircle's corner
TILE_TOP = (26, 26, 31)      # the island dark, a breath lighter at the top
TILE_BOTTOM = (9, 9, 12)
BODY_SHADE_BOTTOM = (0xE8, 0xE8, 0xEF)   # brand law: #FFFFFF -> #E8E8EF, ≈ -10 %
EYE_INK = (0, 0, 0)          # brand law: flat matte #000000, no pupil, no glint
# the idle glow, from the kernel (LupyCharacterMath: tint .idle = white,
# glowStrength .idle = 0.24, LupyComposition.glowBlur = 0.09) — mirrored here
# because those constants live in another file than the geometry; scene.py
# carries the same pair for the same reason.
GLOW_BLUR = 0.09
GLOW_STRENGTH = 0.24
BODY_WIDTH_FRAC = 0.66       # body width as a fraction of the TILE (glow fits)

# AppIcon.appiconset slots: (point size, scale) — mirrors the committed Contents.json.
SLOTS = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
# .icns PNG-backed entry types by pixel size (what iconutil writes).
ICNS_TYPES = {
    16: [b"ic04"],
    32: [b"ic05", b"ic11"],
    64: [b"ic06", b"ic12"],
    128: [b"ic07"],
    256: [b"ic08", b"ic13"],
    512: [b"ic09", b"ic14"],
    1024: [b"ic10"],
}


def slot_filename(pt, scale):
    return f"icon_{pt}x{pt}{'@2x' if scale == 2 else ''}.png"


# ── the locked character, read from the shipped kernel ───────────────────────

def load_geometry():
    """Parse LupyGeometry.swift. Fail loudly: a wrong character is worse than none."""
    src = open(GEOMETRY_SWIFT).read()

    m = re.search(r"static let outline: \[\(Double, Double\)\] = \[(.*?)\n    \]", src, re.S)
    if not m:
        sys.exit("FORGE FAILED: outline not found in LupyGeometry.swift — refusing to guess")
    outline = [(float(a), float(b)) for a, b in
               re.findall(r"\((-?\d+\.\d+), (-?\d+\.\d+)\)", m.group(1))]
    if len(outline) < 100:
        sys.exit(f"FORGE FAILED: outline has only {len(outline)} points — refusing to guess")

    def num(name):
        mm = re.search(rf"static let {name}: Double = (-?[\d.]+)", src)
        if not mm:
            sys.exit(f"FORGE FAILED: {name} not found in LupyGeometry.swift")
        return float(mm.group(1))

    mb = re.search(r"static let showsBlush: Bool = (true|false)", src)
    mbc = re.search(r"bodyColour: \(r: Double, g: Double, b: Double\) = \(([\d.]+), ([\d.]+), ([\d.]+)\)", src)
    if not mb or not mbc:
        sys.exit("FORGE FAILED: showsBlush/bodyColour not found in LupyGeometry.swift")

    geo = {
        "outline": outline,
        "aspect": num("bodyAspect"),
        "eye_w": num("eyeW"), "eye_h": num("eyeH"),
        "eye_cx": num("eyeCentreX"), "eye_cy": num("eyeCentreYFromBase"),
        "shows_blush": mb.group(1) == "true",
        "body": tuple(int(round(float(c) * 255)) for c in mbc.groups()),
    }
    if geo["shows_blush"]:
        geo.update({
            "blush_x": num("blushX"), "blush_y": num("blushYFromBase"),
            "blush_rx": num("blushRX"), "blush_ry": num("blushRY"),
            "blush_opacity": num("blushOpacity"),
        })
        mc = re.search(r"blushColour: \(r: Double, g: Double, b: Double\) = \(([\d.]+), ([\d.]+), ([\d.]+)\)", src)
        if not mc:
            sys.exit("FORGE FAILED: blushColour not found in LupyGeometry.swift")
        geo["blush"] = tuple(int(round(float(c) * 255)) for c in mc.groups())
    return geo


def catmull_closed(pts, samples_per_seg=6):
    """Closed Catmull-Rom through the measured outline (the app fits Béziers
    through the same points; at 4x supersampling the two are indistinguishable).
    Same helper family as tools/character/render_states.py."""
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


# ── raster helpers (fast paths: gradients via 1-px strips, no per-pixel loops) ─

def vgradient(size, top, bottom, box=None):
    """Vertical gradient across `box` (default: whole image), clamped outside."""
    w, h = size
    strip = Image.new("RGB", (1, h))
    y0, y1 = (0, h) if box is None else (int(box[1]), int(box[3]))
    px = strip.load()
    for y in range(h):
        t = min(1.0, max(0.0, (y - y0) / max(1.0, (y1 - y0))))
        px[0, y] = tuple(int(round(top[i] + (bottom[i] - top[i]) * t)) for i in range(3))
    return strip.resize((w, h))


def radial_mask(size, cx, cy, rx, ry, peak):
    """Soft radial blob as an L mask (peak 0..1 at centre), ellipse + blur."""
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=int(255 * peak))
    return m.filter(ImageFilter.GaussianBlur(min(rx, ry) * 0.55))


# ── the render ────────────────────────────────────────────────────────────────

def render_master(geo):
    """The 1024 master: dark squircle, white glow, Lupy. Brand-law neutral."""
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    tile_box = (TILE_INSET, TILE_INSET, TILE_INSET + TILE, TILE_INSET + TILE)

    # shadow, then the tile (macOS grid: soft, low, dark)
    shadow = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (tile_box[0], tile_box[1] + 14 * SS, tile_box[2], tile_box[3] + 14 * SS),
        radius=TILE_RADIUS, fill=(0, 0, 0, 110))
    img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(18 * SS)))
    tile_mask = Image.new("L", (N, N), 0)
    ImageDraw.Draw(tile_mask).rounded_rectangle(tile_box, radius=TILE_RADIUS, fill=255)
    img.paste(vgradient((N, N), TILE_TOP, TILE_BOTTOM, tile_box).convert("RGBA"),
              (0, 0), tile_mask)

    # composition: body centred in the tile (kernel composition reserves room
    # around him for the glow — the icon honours the same margin)
    u = TILE * BODY_WIDTH_FRAC
    cx = N / 2.0
    body_h = u * geo["aspect"]
    base_y = N / 2.0 + body_h / 2.0        # body bbox vertically centred

    def px(x, y):
        return (cx + x * u, base_y - y * u)

    outline_px = [px(x, y) for x, y in catmull_closed(geo["outline"])]
    body_mask = Image.new("L", (N, N), 0)
    ImageDraw.Draw(body_mask).polygon(outline_px, fill=255)

    # 1 · the glow: his light — the state's white, blurred out of the
    #     silhouette, kept inside the tile (scene.py's exact math)
    glow = body_mask.filter(ImageFilter.GaussianBlur(u * GLOW_BLUR))
    glow = glow.point(lambda v: min(255, int(v * GLOW_STRENGTH)))
    glow = ImageChops.darker(glow, tile_mask)
    img.paste(Image.new("RGBA", (N, N), geo["body"] + (255,)), (0, 0), glow)

    # 2 · the body: pure white with the law's soft shaping (all neutral —
    #     gradient #FFFFFF -> #E8E8EF, inner rim for volume, one top-front
    #     specular like the locked master, the faintest grounding at the base)
    top_y = base_y - body_h
    body = vgradient((N, N), geo["body"], BODY_SHADE_BOTTOM,
                     box=(0, top_y - u * 0.04, 0, base_y + u * 0.02)).convert("RGBA")
    body.putalpha(body_mask)
    img = Image.alpha_composite(img, body)

    # inner rim: darken a soft band just inside the edge (volume, no tint)
    rim = body_mask.filter(ImageFilter.GaussianBlur(u * 0.062)).point(
        lambda v: int(0.30 * (255 - v)))
    rim = ImageChops.multiply(rim, body_mask.point(lambda v: v))
    black = Image.new("RGBA", (N, N), (0, 0, 0, 255))
    img = Image.composite(black, img, rim)

    spec = radial_mask((N, N), cx - u * 0.13, top_y + body_h * 0.30, u * 0.30, u * 0.20, 0.16)
    spec_body = Image.new("L", (N, N), 0)
    spec_body.paste(spec, (0, 0), body_mask)
    img = Image.composite(Image.new("RGBA", (N, N), (255, 255, 255, 255)), img, spec_body)

    contact = radial_mask((N, N), cx, base_y + u * 0.10, u * 0.55, u * 0.16, 0.10)
    contact_body = Image.new("L", (N, N), 0)
    contact_body.paste(contact, (0, 0), body_mask)
    img = Image.composite(black, img, contact_body)

    # 3 · blush — only if the kernel says so (today it does not)
    if geo["shows_blush"]:
        blush = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        bd = ImageDraw.Draw(blush)
        a = int(255 * geo["blush_opacity"])
        for sgn in (-1, 1):
            bx, by = px(sgn * geo["blush_x"], geo["blush_y"])
            rx, ry = geo["blush_rx"] * u, geo["blush_ry"] * u
            bd.ellipse([bx - rx, by - ry, bx + rx, by + ry], fill=geo["blush"] + (a,))
        blush = blush.filter(ImageFilter.GaussianBlur(u * 0.022))
        blush.putalpha(Image.composite(blush.split()[3], Image.new("L", (N, N), 0), body_mask))
        img = Image.alpha_composite(img, blush)

    # 4 · THE eyes: two tall capsules, flat matte black, measured. Nothing else.
    d = ImageDraw.Draw(img)
    ew, eh = geo["eye_w"] * u, geo["eye_h"] * u
    for sgn in (-1, 1):
        ex, ey = px(sgn * geo["eye_cx"], geo["eye_cy"])
        d.rounded_rectangle([ex - ew / 2, ey - eh / 2, ex + ew / 2, ey + eh / 2],
                            radius=ew / 2, fill=EYE_INK + (255,))

    return img.resize((1024, 1024), Image.LANCZOS)


# ── outputs ───────────────────────────────────────────────────────────────────

def png_bytes(img):
    buf = io.BytesIO()
    img.save(buf, format="PNG", optimize=True)
    return buf.getvalue()


def build_icns(master):
    """PNG-backed .icns, the ic04-ic14 entry set iconutil writes."""
    entries = b""
    for px_size in sorted(ICNS_TYPES):
        data = png_bytes(master.resize((px_size, px_size), Image.LANCZOS)
                         if px_size != 1024 else master)
        for tag in ICNS_TYPES[px_size]:
            entries += tag + struct.pack(">I", len(data) + 8) + data
    return b"icns" + struct.pack(">I", len(entries) + 8) + entries


def render_all(geo):
    """Every output as {absolute path: bytes}. Pure: no disk writes."""
    master = render_master(geo)
    out = {}

    images = []
    for pt, scale in SLOTS:
        px = pt * scale
        name = slot_filename(pt, scale)
        slot_img = master if px == 1024 else master.resize((px, px), Image.LANCZOS)
        out[os.path.join(APPICONSET, name)] = png_bytes(slot_img)
        images.append({"filename": name, "idiom": "mac", "scale": f"{scale}x", "size": f"{pt}x{pt}"})
    # Contents.json in the exact key order/shape the committed file already has
    images.sort(key=lambda e: (int(e["size"].split("x")[0]), e["scale"]))
    contents = {"images": [
        {"idiom": e["idiom"], "size": e["size"], "scale": e["scale"], "filename": e["filename"]}
        for e in images
    ], "info": {"author": "xcode", "version": 1}}
    # byte-identical to the Xcode-written original (no trailing newline), so the
    # forge never churns this file — only the pixels are new.
    out[os.path.join(APPICONSET, "Contents.json")] = json.dumps(contents, indent=2).encode()

    icns = build_icns(master)
    out[ICNS_PATH] = icns
    out[PREVIEW_PATH] = png_bytes(master)
    if os.path.isdir(os.path.dirname(INSTALLER_ICNS)) or os.path.isdir(os.path.join(ROOT, "Install LUPY.app")):
        out[INSTALLER_ICNS] = icns
    return out


def main():
    check = "--check" in sys.argv
    geo = load_geometry()
    outputs = render_all(geo)

    if check:
        stale = []
        for path, data in outputs.items():
            if not os.path.exists(path) or open(path, "rb").read() != data:
                stale.append(os.path.relpath(path, ROOT))
        if stale:
            print("ICON FORGE: STALE — re-run python3 tools/ui/make_appicon.py")
            for s in stale:
                print("  stale:", s)
            return 1
        print(f"ICON FORGE: SATISFIED ({len(outputs)} outputs match the locked character)")
        return 0

    for path, data in outputs.items():
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as f:
            f.write(data)
        print("forged", os.path.relpath(path, ROOT), f"({len(data)} B)")
    print("ICON FORGED — the locked character, "
          f"blush={'on' if geo['shows_blush'] else 'off (kernel law)'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
