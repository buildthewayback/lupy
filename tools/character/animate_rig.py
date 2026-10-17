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

from scene import BG, compose

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


def render_frame(f, size, body_px, canvas=None):
    """One frame of the same scene the sheets draw, from the shipping rig's numbers."""
    from PIL import ImageChops
    # the three dots travel with the animation clock, not with a fixed phase
    phase = (f["i"] / 25.0) / 1.2
    img = compose(f, float(body_px), ss=SS, phase=phase, canvas=canvas)
    if canvas:
        return img.resize((canvas[0] // SS, canvas[1] // SS), Image.LANCZOS)
    return img


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "/tmp/anim.txt"
    out = sys.argv[2] if len(sys.argv) > 2 else "/tmp/lupy.mp4"
    body_px = int(sys.argv[3]) if len(sys.argv) > 3 else 190
    fps = int(sys.argv[4]) if len(sys.argv) > 4 else 25

    frames = parse(src)
    print(f"{len(frames)} frames, body {body_px}px")

    # Every frame shares one canvas: a per-frame crop would make the GIF breathe
    # in and out as the labels change length.
    from scene import measure_bubble
    widest = max(measure_bubble(f, float(body_px), SS)[0] for f in frames)
    canvas = (int(round(widest + body_px * 1.34 * SS)),
              int(round(body_px * 1.20 * SS)))
    imgs = [render_frame(f, body_px, body_px, canvas) for f in frames]

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
