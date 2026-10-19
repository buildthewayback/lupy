#!/usr/bin/env python3
"""Draw rig frames emitted by tools/character/rig_emit.swift.

This does NOT re-implement the character. It reads the polygon and eye rectangles
that the *shipping Swift code* printed and fills those exact shapes. If the Swift
geometry is wrong, this picture is wrong — nothing is fudged here.
"""
import sys, math
from PIL import Image, ImageDraw

SS = 4                     # supersample factor
BODY = (255, 255, 255)
INK = (0, 0, 0)
BG = (20, 20, 23)


def parse(path):
    frames = []
    for line in open(path):
        parts = line.split()
        if not parts:
            continue
        if parts[0] == "FRAME":
            frames.append({"name": parts[1], "body": [], "eyes": []})
        elif parts[0] == "BODY":
            frames[-1]["body"] = [tuple(map(float, p.split(","))) for p in parts[1:]]
        elif parts[0] == "EYE":
            _, side, cx, cy, rx, ry = parts
            frames[-1]["eyes"].append((float(cx), float(cy), float(rx), float(ry)))
    return frames


def render(frame, size_px, pad=0.16, bg=BG):
    """size_px = body width in final pixels."""
    W = int(round(size_px * (1 + 2 * pad)))
    img = Image.new("RGB", (W * SS, W * SS), bg)
    d = ImageDraw.Draw(img)

    # local units -> pixels. Body spans [-0.5, 0.5] in x; y is up.
    s = size_px * SS / 1.0
    cxp = W * SS / 2
    cyp = W * SS / 2

    def px(x, y):
        return (cxp + x * s, cyp - y * s)

    poly = [px(x, y) for x, y in frame["body"]]
    d.polygon(poly, fill=BODY)

    for cx, cy, rx, ry in frame["eyes"]:
        if ry < 0.002:
            # a blink is a hairline, not a dot: keep it as a thin capsule
            ry = max(ry, 0.0025)
        x0, y0 = px(cx - rx, cy + ry)
        x1, y1 = px(cx + rx, cy - ry)
        rad = min(abs(x1 - x0), abs(y1 - y0)) / 2
        d.rounded_rectangle([x0, y0, x1, y1], radius=rad, fill=INK)

    return img.resize((W, W), Image.LANCZOS)


def sheet(frames, out, size_px=220, cols=4, labels=True):
    tiles = [render(f, size_px) for f in frames]
    tw, th = tiles[0].size
    lab = 26 if labels else 0
    rows = (len(tiles) + cols - 1) // cols
    canvas = Image.new("RGB", (tw * cols, (th + lab) * rows), (12, 12, 14))
    d = ImageDraw.Draw(canvas)
    for i, (t, f) in enumerate(zip(tiles, frames)):
        cx, cy = (i % cols) * tw, (i // cols) * (th + lab)
        canvas.paste(t, (cx, cy))
        if labels:
            d.text((cx + 10, cy + th + 6), f["name"], fill=(140, 140, 150))
    canvas.save(out)
    print(f"wrote {out}  {canvas.size[0]}x{canvas.size[1]}")


def strip(frames, out, size_px=200, bg=(20, 20, 23)):
    """One row, tight padding — for tiny sizes side by side."""
    tiles = [render(f, size_px) for f in frames]
    tw, th = tiles[0].size
    canvas = Image.new("RGB", (tw * len(tiles), th), bg)
    for i, t in enumerate(tiles):
        canvas.paste(t, (i * tw, 0))
    canvas.save(out)
    print(f"wrote {out}  {canvas.size[0]}x{canvas.size[1]}")


if __name__ == "__main__":
    src = sys.argv[1] if len(sys.argv) > 1 else "/tmp/frames.txt"
    frames = parse(src)
    print(f"{len(frames)} frames")
    sheet(frames, "/tmp/rig_sheet.png", size_px=200, cols=4)
