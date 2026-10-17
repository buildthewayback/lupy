#!/usr/bin/env python3
"""Draw the 11 LUPY states, and the machine-mood states, from frames the rig emits.

Only rasterises: every number (silhouette, eye position, style, tint, badge icon,
composition) comes from the shipping Swift rig. The drawing lives in scene.py, which
mirrors the SwiftUI views.

The founder's note was that the character looked pixelated, so every scene is drawn at
4x and downsampled with LANCZOS. A sheet that renders at its display size and is then
shown on a retina screen is a blurry sheet, however good the vector maths is.
"""
import sys
from PIL import Image, ImageDraw, ImageChops

from scene import BG, BODY, INK, compose, measure_bubble

SS = 4                      # supersample factor for every scene


def parse(path):
    states = []
    cur = None
    for line in open(path):
        p = line.split()
        if not p:
            continue
        if p[0] == "FRAME":
            cur = {"name": p[1], "body": [], "eyes": [], "tint": (1, 1, 1),
                   "amount": 0.3, "icon": "none", "label": p[1],
                   "hot": 0.0, "busy": 0.0, "full": 0.0, "tired": 0.0, "asleep": False}
            states.append(cur)
        elif p[0] == "MOOD":
            cur["hot"] = float(p[1]); cur["busy"] = float(p[2])
            cur["full"] = float(p[3]); cur["tired"] = float(p[4])
            cur["asleep"] = p[5] == "1"
        elif p[0] == "STATE":
            cur["tint"] = (float(p[2]), float(p[3]), float(p[4]))
            cur["amount"] = float(p[5])
            cur["icon"] = p[6] if len(p) > 6 else "none"
            cur["label"] = " ".join(p[7:]) if len(p) > 7 else p[1]
        elif p[0] == "BODY":
            cur["body"] = [tuple(map(float, q.split(","))) for q in p[1:]]
        elif p[0] == "EYE":
            _, side, cx, cy, rx, ry, style = p
            cur["eyes"].append((float(cx), float(cy), float(rx), float(ry), style))
    for s in states:
        s["ongoing"] = s["label"].endswith("…")
    return states


def render_scene(state, body_px=280, pad=0.30):
    """One scene, from the same layout the app uses. Cropped to its content."""
    u = float(body_px)
    img = compose(state, u, ss=SS, phase=0.15)
    return trim(img, pad * u * SS)


def trim(img, margin):
    """Crop to the drawn content, then put a uniform margin back around it."""
    from PIL import ImageChops
    px = img.convert("RGB")
    bg = Image.new("RGB", px.size, BG)
    box = ImageChops.difference(px, bg).getbbox()
    if not box:
        return px
    l, t, r, b = box
    l = max(0, int(l - margin)); t = max(0, int(t - margin))
    r = min(px.size[0], int(r + margin)); b = min(px.size[1], int(b + margin))
    out = px.crop((l, t, r, b))
    return out.resize((out.size[0] // SS, out.size[1] // SS), Image.LANCZOS)


def sheet(states, out, body_px, cols):
    # every tile gets the same cell, sized by the widest bubble, so the bodies all
    # come out the same size on the page
    widest = max(measure_bubble(s, float(body_px), 1)[0] for s in states)
    cell_w = int(round(widest + body_px * 1.30))
    cell_h = int(round(body_px * 1.34))

    def place(tile):
        cell = Image.new("RGB", (cell_w, cell_h), BG)
        h = min(tile.size[1], cell_h)
        w = min(tile.size[0], cell_w)
        # flush right, so the badge never sits near the cell's edge
        cell.paste(tile.crop((0, 0, w, h)), (cell_w - w, 0))
        return cell

        return cell

    tiles = [place(render_scene(s, body_px)) for s in states]
    tw, th = cell_w, cell_h
    rows = (len(tiles) + cols - 1) // cols
    canvas = Image.new("RGB", (tw * cols, th * rows), BG)
    for i, t in enumerate(tiles):
        canvas.paste(t, ((i % cols) * tw, (i // cols) * th))
    canvas.save(out)
    print(f"wrote {out} {canvas.size[0]}x{canvas.size[1]}")


MOOD_LABELS = {
    "mood_calm": ("Ready", "standby"),
    "cpu_pinned": ("Working", "gear"),
    "ram_critical": ("Overloaded", "spiral"),
    "too_hot": ("Working", "gear"),
}


def main():
    src = sys.argv[1]
    out = sys.argv[2]
    body_px = int(sys.argv[3]) if len(sys.argv) > 3 else 280

    states = parse(src)
    real = [t for t in states if t["name"] in [s for s in (
        "idle", "working", "thinking", "searching", "approval", "question",
        "error", "finished", "rate_limit", "sleeping", "dizzy")]]
    moods = [t for t in states if t not in real]
    for t in moods:
        t["label"], icon = MOOD_LABELS.get(t["name"], (t["name"], "none"))
        t["icon"] = t["icon"] if t["icon"] != "none" else icon
        t["ongoing"] = False

    if moods:
        sheet(moods, out.replace(".png", "-machine.png"), body_px, len(moods))
    sheet(real, out, body_px, 4)


if __name__ == "__main__":
    main()
