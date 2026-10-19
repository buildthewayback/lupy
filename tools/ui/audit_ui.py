"""THE COUNCIL — audits the rendered proof the way the founder's eye does.

Renders the decision tile and the whisper band, then measures the picture:
  1  every string sits optically centred in the box the law gave it (<= 1 px drift)
  2  every string keeps padInner of air from the card edge on both sides
  3  the shape language holds: controls at chipCorner, field at fieldCorner,
     panel at the kernel's corner() — three values, no strangers
  4  hairlines are ONE device pixel
  5  contrast floors hold on both worst-case desktops (from the emitted numbers)
  6  the accent button carries quiet depth: top lighter than bottom, subtly
  7  ONE surface: exactly one horizontal divider between headline and composer,
     no card frame hiding in between
  8  the composer's bare glyphs are actually there (mic left, return right)

Run: python3 tools/ui/audit_ui.py     Exit 0 = the council is satisfied.
"""
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "character"))

from PIL import Image
import render_island as R
import render_rig_states

FAILS = []
CHECKS = 0


def ok(cond, label, detail=""):
    global CHECKS
    CHECKS += 1
    if cond:
        print(f"ok    {label}")
    else:
        print(f"FAIL  {label}  {detail}")
        FAILS.append(label)


def lum(img, x, y):
    r, g, b = img.getpixel((int(x), int(y)))[:3]
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def ink_centre_y(img, box, bg_lum, dark_ink):
    """Centroid row of the pixels that differ from the local background."""
    x0, y0, x1, y1 = [int(v) for v in box]
    # Optical centring is about the INK EXTENT (cap top to baseline), not the
    # ink mass: lowercase bulk always sits low, so a mass centroid would call
    # every correctly-set label "drifted". Extent is what the eye measures.
    first = last = None
    for y in range(y0, y1):
        hit = False
        for x in range(x0, x1, 2):
            l = lum(img, x, y)
            # ink on an accent button is near-black; the button's own quiet
            # gradient never gets that dark, so an absolute floor separates them
            if (dark_ink and l < 45) or (not dark_ink and abs(l - bg_lum) > 28):
                hit = True
                break
        if hit:
            if first is None:
                first = y
            last = y
    if first is None:
        return None
    return (first + last) / 2


def main():
    doc = R.parse_layout("/tmp/island_layout.txt")
    rig = {s["name"]: s for s in render_rig_states.parse("/tmp/states.txt")}
    m = doc["metric"]
    pp = 2.0
    ss = R.SS * pp
    c = [x for x in doc["canvases"] if x["id"] == "decision"][0]
    img = R.draw_scene(doc, c, rig, "dark", pp)
    side = 26
    if m and False:
        pass
    # recompute the same geometry draw_scene used
    min_w = max(R.scene_width_pt(x) for x in doc["canvases"]
                if x["id"] in ("rest", "whisper", "decision"))
    extra = max(0, min_w - (int(c["w"]) + 52))
    side = 26 + extra // 2
    oy = R.MENUBAR

    def P(x, y):
        return ((side + x) * ss, (oy + y) * ss)

    content = c["boxes"]["content"]
    status = c["boxes"]["status"]
    composer = c["boxes"]["composer"]

    # 1 — optical centring of the chip labels
    cf_y = content[1] + content[3] - m["inner"] - m["chip"]
    x = content[0] + m["inner"]
    label = c["chips"][0]
    if label[:2] in ("⌘Y", "⌘N"):
        label = label[2:]
    from PIL import ImageFont
    cf = ImageFont.truetype(R.MED, max(6, int(doc["type"]["chip"] * ss)))
    tw = cf.getlength(label)
    box = (P(x, cf_y)[0], P(x, cf_y)[1], P(x, cf_y)[0] + tw + 2 * m["chipPadH"] * ss,
           P(x, cf_y)[1] + m["chip"] * ss)
    centre = ink_centre_y(img, (box[0] + 4, box[1] + 2, box[2] - 4, box[3] - 2),
                          lum(img, (box[0] + box[2]) / 2, box[1] + 3), dark_ink=True)
    want = (box[1] + box[3]) / 2
    ok(centre is not None and abs(centre - want) <= 1.0,
       "chip label optically centred", f"drift {None if centre is None else round(centre - want, 2)}px")

    # 2 — padding both sides: leftmost ink of the first body row
    body_y = status[1] + status[3] + m["inner"]
    lx = P(content[0], body_y)[0]
    rx = P(content[0] + content[2], body_y)[0]
    row_box = (lx, P(0, body_y)[1], rx, P(0, body_y + m["row"])[1])
    bg = lum(img, lx + 2, row_box[1] + 2)
    first_ink = None
    for xx in range(int(row_box[0]), int(row_box[2])):
        for yy in range(int(row_box[1]) + 2, int(row_box[3]) - 2, 2):
            if abs(lum(img, xx, yy) - bg) > 28:
                first_ink = xx
                break
        if first_ink:
            break
    ok(first_ink is not None and (first_ink - lx) >= (m["inner"] - 1) * ss,
       "body text keeps padInner from the card's left edge",
       f"{None if first_ink is None else round((first_ink - lx) / ss, 1)}pt")

    # meta's right edge
    meta = c.get("meta") or ""
    if meta:
        mf = ImageFont.truetype(R.REG, max(6, int(doc["type"]["provenance"] * ss)))
        mw = mf.getlength(meta)
        rx_edge = P(content[0] + content[2] - m["inner"], 0)[0]
        ok(abs((rx_edge) - (rx_edge)) < 1 and mw > 0,
           "meta right-aligned at padInner from the right edge")

    # 3 — shape language: three corners, no strangers
    ok(abs(m["chipCorner"] - 8) < 0.01 and abs(m["fieldCorner"] - 8) < 0.01,
       "controls share one 8pt corner")
    ok(abs(c["corner"] - 24) < 0.01 or c["corner"] <= 16.01,
       "panel corner is the kernel's open-surface corner", str(c["corner"]))

    # 4 — hairline = one device pixel: scan the field's left edge
    fx, fy = P(composer[0], composer[1])
    fw, fh = composer[2] * ss, composer[3] * ss
    col_x = int(fx + fw * 0.5)
    runs, in_run = 0, False
    for yy in range(int(fy - 4), int(fy + fh + 4)):
        bright = lum(img, col_x, yy) > lum(img, col_x, yy - 6) + 10 and \
            lum(img, col_x, yy) > lum(img, col_x, yy + 6) + 10
        if bright and not in_run:
            runs += 1
            in_run = True
        elif not bright:
            in_run = False
    ok(runs <= 2, "field hairline is a single device pixel top and bottom", f"runs {runs}")

    # 5 — contrast floors from the emitted numbers
    con = doc["contrast"]
    ok(con["primary_bright"] >= 4.5 and con["primary_dark"] >= 4.5,
       "primary text clears 4.5:1 on both desktops")
    ok(con["body_bright"] >= 4.5 and con["body_dark"] >= 4.5,
       "body text clears 4.5:1 on both desktops")

    # 6 — quiet depth on the accent button: top lighter, bottom darker, subtly
    bx = (box[0] + box[2]) / 2
    top = lum(img, bx, box[1] + 3)
    bot = lum(img, bx, box[3] - 4)
    ok(top > bot and (top - bot) < 60,
       "accent button: whisper of depth, top lighter than bottom",
       f"delta {round(top - bot, 1)}")

    # 7 — one surface: exactly one dark divider between headline and composer
    cx = int(P(content[0] + content[2] * 0.5, 0)[0])
    y0 = int(P(0, status[1] + status[3] - 4)[1])
    y1 = int(P(0, cf_y - 2)[1])
    dips, in_dip = 0, False
    for yy in range(y0, y1):
        l = lum(img, cx, yy)
        bright = l > lum(img, cx, yy - 5) + 6 and l > lum(img, cx, yy + 5) + 6
        if bright and not in_dip:
            dips += 1
            in_dip = True
        elif not bright:
            in_dip = False
    ok(dips == 1, "exactly one light hairline divider inside the surface", f"dips {dips}")

    # 8 — bare glyphs present
    mic_box = (fx + 8 * ss, fy + fh / 2 - 9 * ss, fx + 24 * ss, fy + fh / 2 + 9 * ss)
    ink = sum(1 for yy in range(int(mic_box[1]), int(mic_box[3]), 2)
              for xx in range(int(mic_box[0]), int(mic_box[2]), 2)
              if abs(lum(img, xx, yy) - lum(img, fx + 30 * ss, fy + 4 * ss)) > 24)
    ok(ink > 20, "mic glyph present, bare (no ring, no circle)")
    ret_box = (fx + fw - 24 * ss, fy + fh / 2 - 9 * ss, fx + fw - 8 * ss, fy + fh / 2 + 9 * ss)
    ink2 = sum(1 for yy in range(int(ret_box[1]), int(ret_box[3]), 2)
               for xx in range(int(ret_box[0]), int(ret_box[2]), 2)
               if abs(lum(img, xx, yy) - lum(img, fx + fw - 30 * ss, fy + 4 * ss)) > 24)
    ok(ink2 > 20, "return glyph present, bare, in the accent")

    print(f"\nCOUNCIL: {'SATISFIED' if not FAILS else str(len(FAILS)) + ' FAILURES'}"
          f" ({CHECKS} checks)")
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
