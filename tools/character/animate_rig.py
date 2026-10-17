#!/usr/bin/env python3
"""Turn rig animation frames into an animated proof (GIF + MP4 when available).

Input is the text emitted by tools/character/rig_anim.swift — the shipping Swift
rig, stepped along a pointer path. Nothing here re-implements Lupy: the body, the
eyes, the colour, the badge and the words all come from the rig.
"""
import os
import shutil
import subprocess
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

from render_rig_states import (BG, BODY, INK, SS, draw_spiral_eye, draw_arc_eye, rounded)
from status_bubble import draw_status_bubble

FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def parse(path):
    frames = []
    cur = None
    for line in open(path):
        p = line.split()
        if not p:
            continue
        if p[0] == "FRAME":
            cur = {"i": int(p[1]), "gx": float(p[2]), "gy": float(p[3]),
                   "body": [], "eyes": [], "cursor": None, "amount": 0.0,
                   "tint": (1, 1, 1), "badge": "none", "icon": "none", "label": ""}
            frames.append(cur)
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
        elif p[0] == "CURSOR":
            cur["cursor"] = (float(p[1]), float(p[2]))
    return frames


ARROW = [(0, 0), (0, 17.2), (4.1, 13.4), (6.9, 19.4), (9.9, 18.1),
         (7.1, 12.2), (12.4, 12.0)]


def draw_cursor(d, cx, cy, k):
    """A real macOS arrow: instantly legible as the user's mouse."""
    pts = [(cx + x * k, cy + y * k) for x, y in ARROW]
    d.polygon(pts, fill=(250, 250, 252), outline=(20, 20, 24), width=max(1, int(1.4 * k)))


def draw_label(d, label, tint, size, px_size):
    """The sentence that goes with the face, in the same pill as the app draws."""
    if not label:
        return
    font = ImageFont.truetype(FONT, max(9, int(px_size * 0.038)))
    tw = d.textlength(label, font=font)
    h = px_size * 0.078
    w = tw + px_size * 0.13
    cx = px_size / 2
    top = px_size * 0.045
    rounded(d, [cx - w / 2, top, cx + w / 2, top + h], h / 2, (30, 30, 36))
    d.text((cx - tw / 2 + px_size * 0.012, top + h * 0.27), label, font=font,
           fill=(233, 234, 241))
    r = max(1.5, px_size * 0.008)
    dot_cx = cx - w / 2 + px_size * 0.038
    d.ellipse([dot_cx - r, top + h / 2 - r, dot_cx + r, top + h / 2 + r],
              fill=tuple(int(c * 255) for c in tint))


def render_frame(f, size, body_px):
    s = body_px
    W = size * SS
    img = Image.new("RGB", (W, W), BG)
    d = ImageDraw.Draw(img)
    cxp = cyp = W / 2

    def px(x, y):
        return (cxp + x * s * SS, cyp - y * s * SS)

    body_pts = [px(x, y) for x, y in f["body"]]

    # light: the state colour, behind the body, blurred into the background
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon(body_pts, fill=255)
    glow = mask.filter(ImageFilter.GaussianBlur(s * SS * 0.09))
    strength = min(0.92, f["amount"])
    glow = glow.point(lambda v: min(255, int(v * strength)))
    layer = Image.new("RGB", img.size, tuple(int(c * 255) for c in f["tint"]))
    img = Image.composite(layer, img, glow)
    d = ImageDraw.Draw(img)

    # brand law: pure white body in every state; the light carries the colour
    d.polygon(body_pts, fill=BODY)

    for cx, cy, rx, ry, style in f["eyes"]:
        if ry < 0.002:
            ry = 0.002
        ex, ey = px(cx, cy)
        if style in ("capsule", "wide", "dash", "half_lid"):
            w, h = rx * 2 * s * SS, ry * 2 * s * SS
            rounded(d, [ex - w / 2, ey - h / 2, ex + w / 2, ey + h / 2],
                    min(w, h) / 2, INK)
        elif style == "spiral":
            draw_spiral_eye(d, ex, ey, s * SS)
        else:
            draw_arc_eye(d, ex, ey, rx * s * SS, style, s * SS, INK)

    if f["cursor"]:
        draw_cursor(d, *px(*f["cursor"]), size * SS / 460.0)

    img = img.resize((size, size), Image.LANCZOS)
    phase = (f["i"] // 8) % 4
    # the bubble is sized by the *body* width, exactly as the app sizes it
    draw_status_bubble(ImageDraw.Draw(img), f["label"], f["icon"], f["tint"],
                       float(body_px), size / 2, size * 0.035, phase=phase)
    return img


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "/tmp/anim.txt"
    out = sys.argv[2] if len(sys.argv) > 2 else "/tmp/lupy.mp4"
    size = int(sys.argv[3]) if len(sys.argv) > 3 else 420
    fps = int(sys.argv[4]) if len(sys.argv) > 4 else 25

    frames = parse(src)
    body_px = int(size * 0.56)
    print(f"{len(frames)} frames at {size}px")

    imgs = [render_frame(f, size, body_px) for f in frames]

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
    quant = [im.convert("P", palette=Image.ADAPTIVE, colors=64) for im in imgs]
    quant[0].save(gif, save_all=True, append_images=quant[1:], duration=int(1000 / fps),
                  loop=0, optimize=True, disposal=2)
    print("wrote", gif, os.path.getsize(gif) // 1024, "KB")


if __name__ == "__main__":
    main()
