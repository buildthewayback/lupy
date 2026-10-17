#!/usr/bin/env python3
"""Turn rig animation frames into an animated proof (GIF + MP4 when available).

Input is the text emitted by tools/character/rig_anim.swift — the shipping Swift
rig, stepped at 60 Hz along a pointer path. Nothing here re-implements Lupy.
"""
import os
import shutil
import subprocess
import sys
from PIL import Image, ImageDraw, ImageFilter

SS = 3
BODY = (255, 255, 255)
INK = (0, 0, 0)
BG = (18, 18, 21)


def parse(path):
    frames = []
    cur = None
    for line in open(path):
        p = line.split()
        if not p:
            continue
        if p[0] == "FRAME":
            cur = {"i": int(p[1]), "gx": float(p[2]), "gy": float(p[3]),
                   "body": [], "eyes": [], "cursor": None}
            frames.append(cur)
        elif p[0] == "BODY":
            cur["body"] = [tuple(map(float, q.split(","))) for q in p[1:]]
        elif p[0] == "EYE":
            _, side, cx, cy, rx, ry = p
            cur["eyes"].append((float(cx), float(cy), float(rx), float(ry)))
        elif p[0] == "CURSOR":
            cur["cursor"] = (float(p[1]), float(p[2]))
    return frames


def make_glow(size, body_px, pad):
    """A soft warm halo so the white body sits in light, like the reference art.
    Renderer dressing only — it is not part of the character."""
    g = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(g)
    r = body_px * 0.62
    cx = cy = size / 2
    for i in range(26, 0, -1):
        k = i / 26
        rr = r * (0.55 + 0.75 * k)
        v = int(26 * (1 - k) ** 1.6)
        d.ellipse([cx - rr, cy - rr * 0.94, cx + rr, cy + rr * 0.94], fill=v)
    return g.filter(ImageFilter.GaussianBlur(size * 0.05))


ARROW = [(0, 0), (0, 17.2), (4.1, 13.4), (6.9, 19.4), (9.9, 18.1),
         (7.1, 12.2), (12.4, 12.0)]


def draw_cursor(d, cx, cy, k):
    """A real macOS arrow: instant readability that this is the user's mouse."""
    pts = [(cx + x * k, cy + y * k) for x, y in ARROW]
    d.polygon(pts, fill=(250, 250, 252), outline=(20, 20, 24), width=max(1, int(1.4 * k)))


def render_frame(f, size, body_px, glow):
    s = body_px  # body width == 1.0 local unit
    cxp = cyp = size / 2
    img = Image.new("RGB", (size * SS, size * SS), BG)
    d = ImageDraw.Draw(img)

    def px(x, y):
        return (cxp * SS + x * s * SS, cyp * SS - y * s * SS)

    d = ImageDraw.Draw(img)
    d.polygon([px(x, y) for x, y in f["body"]], fill=BODY)

    for cx, cy, rx, ry in f["eyes"]:
        if ry < 0.002:
            ry = 0.002
        x0, y0 = px(cx - rx, cy + ry)
        x1, y1 = px(cx + rx, cy - ry)
        d.rounded_rectangle([x0, y0, x1, y1], radius=min(x1 - x0, y1 - y0) / 2, fill=INK)

    if f["cursor"]:
        cx, cy = px(*f["cursor"])
        draw_cursor(d, cx, cy, size * SS / 460.0)

    return img.resize((size, size), Image.LANCZOS)


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "/tmp/anim.txt"
    out = sys.argv[2] if len(sys.argv) > 2 else "/tmp/lupy.mp4"
    size = int(sys.argv[3]) if len(sys.argv) > 3 else 420

    frames = parse(src)
    body_px = int(size * 0.72)
    print(f"{len(frames)} frames at {size}px")

    imgs = [render_frame(f, size, body_px, None) for f in frames]

    if shutil.which("ffmpeg"):
        tmp = "/tmp/_rigframes"
        os.makedirs(tmp, exist_ok=True)
        for i, im in enumerate(imgs):
            im.save(os.path.join(tmp, f"f{i:04d}.png"))
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", "60",
                        "-i", os.path.join(tmp, "f%04d.png"), "-c:v", "libx264",
                        "-pix_fmt", "yuv420p", "-crf", "18", "-movflags", "+faststart",
                        out], check=True)
        print("wrote", out, os.path.getsize(out) // 1024, "KB")
        gif = os.path.splitext(out)[0] + ".gif"
    else:
        gif = out if out.endswith(".gif") else os.path.splitext(out)[0] + ".gif"

    small = [im.convert("P", palette=Image.ADAPTIVE, colors=64) for im in imgs]
    small[0].save(gif, save_all=True, append_images=small[1:], duration=20, loop=0,
                  optimize=True, disposal=2)
    print("wrote", gif, os.path.getsize(gif) // 1024, "KB")


if __name__ == "__main__":
    main()
