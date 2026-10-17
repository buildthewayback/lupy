#!/usr/bin/env python3
"""Turn rig animation frames into an animated proof (GIF + MP4 when available).

Input is the text emitted by tools/character/rig_anim.swift — the shipping Swift rig,
stepped along a pointer path. The drawing comes from scene.py, the same module the
state sheets use, so the animation and the sheets can never disagree.

The story is the whole point of the character: a calm Mac, a working one, one that
runs out of memory, and the return to calm — with the bubble saying each thing as it
happens.
"""
import os
import shutil
import subprocess
import sys

from PIL import Image

from scene import BG, draw_character, draw_bubble

SS = 2


def parse(path):
    frames = []
    cur = None
    for line in open(path):
        p = line.split()
        if not p:
            continue
        if p[0] == "FRAME":
            cur = {"i": int(p[1]), "gx": float(p[2]), "gy": float(p[3]),
                   "body": [], "eyes": [], "tint": (1, 1, 1), "amount": 0.3,
                   "icon": "none", "label": "", "hot": 0.0}
            frames.append(cur)
        elif p[0] == "MOOD":
            cur["hot"] = float(p[1])
        elif p[0] == "BODY":
            cur["body"] = [tuple(map(float, q.split(","))) for q in p[1:]]
        elif p[0] == "EYE":
            _, side, cx, cy, rx, ry, style = p
            cur["eyes"].append((float(cx), float(cy), float(rx), float(ry), style))
        elif p[0] == "STATE":
            cur["amount"] = float(p[1])
            cur["tint"] = (float(p[2]), float(p[3]), float(p[4]))
            cur["icon"] = p[5]
            cur["label"] = " ".join(p[6:])
    for f in frames:
        f["ongoing"] = f["label"].endswith("…")
    return frames


def render_frame(f, size, body_px):
    """The scene at `size`, with the body `body_px` wide."""
    W = int(round(body_px * 2.45))
    H = int(round(body_px * 1.42))
    img = Image.new("RGB", (W * SS, H * SS), BG)
    cx = body_px * 0.64 * SS
    cy = H * SS * 0.52
    draw_character(img, f, body_px, cx, cy, ss=SS)
    # the three dots travel with the animation clock, not with a fixed phase
    phase = (f["i"] / 25.0) / 1.2
    draw_bubble(img, f, body_px, body_px * 1.20 * SS, cy, ss=SS, phase=phase)
    return img.resize((W, H), Image.LANCZOS)


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "/tmp/anim.txt"
    out = sys.argv[2] if len(sys.argv) > 2 else "/tmp/lupy.mp4"
    body_px = int(sys.argv[3]) if len(sys.argv) > 3 else 190
    fps = int(sys.argv[4]) if len(sys.argv) > 4 else 25

    frames = parse(src)
    print(f"{len(frames)} frames, body {body_px}px")

    imgs = [render_frame(f, body_px, body_px) for f in frames]

    if shutil.which("ffmpeg"):
        tmp = "/tmp/_rigframes"
        os.makedirs(tmp, exist_ok=True)
        for old in os.listdir(tmp):
            os.remove(os.path.join(tmp, old))
        for i, im in enumerate(imgs):
            im.save(os.path.join(tmp, f"f{i:04d}.png"))
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(fps),
                        "-i", os.path.join(tmp, "f%04d.png"), "-c:v", "libx264",
                        "-pix_fmt", "yuv420p", "-crf", "20", "-movflags", "+faststart",
                        out], check=True)
        print("wrote", out, os.path.getsize(out) // 1024, "KB")

    gif = os.path.splitext(out)[0] + ".gif"
    quant = [im.convert("P", palette=Image.ADAPTIVE, colors=128) for im in imgs]
    quant[0].save(gif, save_all=True, append_images=quant[1:],
                  duration=int(1000 / fps), loop=0, optimize=True, disposal=2)
    print("wrote", gif, os.path.getsize(gif) // 1024, "KB")


if __name__ == "__main__":
    main()
