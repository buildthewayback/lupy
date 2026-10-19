"""THE COUNCIL, ALL SURFACES — every canvas the island can become, measured.

For each of the nine emitted canvases the council looks at the rendered picture:
  expanded surfaces:  strings keep padInner on both edges · chip labels optically
                      centred · exactly one light divider · the composer recess has
                      a 1-px hairline and both bare glyphs
  band surfaces:      the whisper's ink lives inside the capsule, clear of its
                      corners · at rest, LUPY's white body is where the law put him
Nothing here trusts intent; everything measures pixels. Exit 0 = all satisfied.

Run: python3 tools/ui/audit_all.py
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "character"))

from PIL import ImageFont  # noqa: E402
import render_island as R  # noqa: E402
import render_rig_states   # noqa: E402

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


def ink_extent_y(img, box, test):
    first = last = None
    for y in range(int(box[1]), int(box[3])):
        hit = any(test(lum(img, x, y)) for x in range(int(box[0]), int(box[2]), 2))
        if hit:
            if first is None:
                first = y
            last = y
    return (first, last)


def main():
    doc = R.parse_layout("/tmp/island_layout.txt")
    rig = {s["name"]: s for s in render_rig_states.parse("/tmp/states.txt")}
    m = doc["metric"]
    pp = 2.0
    ss = R.SS * pp
    min_w = max(R.scene_width_pt(c) for c in doc["canvases"])

    for c in doc["canvases"]:
        cid = c["id"]
        img = R.draw_scene(doc, c, rig, "dark", pp, min_w=min_w)
        side = 26 + max(0, min_w - (int(c["w"]) + 52)) // 2
        oy = R.MENUBAR

        def P(x, y):
            return ((side + x) * ss, (oy + y) * ss)

        if c["surface"] == "headline":
            content = c["boxes"]["content"]
            status = c["boxes"]["status"]
            composer = c["boxes"]["composer"]
            lx = P(content[0], 0)[0]
            rx = P(content[0] + content[2], 0)[0]

            # left edge: first ink of the first body row, padInner of air
            by = status[1] + status[3] + m["inner"]
            bg = lum(img, lx + 2 * ss, P(0, by)[1] + 2)
            first = None
            for xx in range(int(lx), int(rx)):
                if any(abs(lum(img, xx, yy) - bg) > 28
                       for yy in range(int(P(0, by)[1]) + 2, int(P(0, by + m["row"])[1]) - 2, 2)):
                    first = xx
                    break
            ok(first is not None and (first - lx) >= (m["inner"] - 1) * ss,
               f"{cid}: body keeps padInner left",
               f"{None if first is None else round((first - lx) / ss, 1)}pt")

            # right edge: meta's ink stops padInner short of the card edge
            if c.get("meta"):
                last = None
                for xx in range(int(rx) - 1, int(lx), -1):
                    if any(abs(lum(img, xx, yy) - bg) > 24
                           for yy in range(int(P(0, status[1])[1]) + 4,
                                           int(P(0, status[1] + status[3])[1]) - 4, 2)):
                        last = xx
                        break
                ok(last is not None and (rx - last) >= (m["inner"] - 1) * ss,
                   f"{cid}: meta keeps padInner right",
                   f"{None if last is None else round((rx - last) / ss, 1)}pt")

            # exactly one light divider between headline and chips/rows end
            cx = int(P(content[0] + content[2] * 0.5, 0)[0])
            y0 = int(P(0, status[1] + status[3] - 4)[1])
            # stop above the chip row: a chip's own top hairline is a control
            # edge, not a hidden frame — the scan judges the card's body only
            chip_top = (content[1] + content[3] - m["inner"] - m["chip"]
                        if c["chips"] else content[1] + content[3])
            y1 = int(P(0, chip_top - 3)[1])
            # A hairline is 1-2 px; a text line is 13 pt of ink. Thickness,
            # not brightness, is what tells a frame from a sentence.
            def thin_bright(yy):
                l = lum(img, cx, yy)
                return (l > lum(img, cx, yy - 4) + 6 and l > lum(img, cx, yy + 4) + 6
                        and not (lum(img, cx, yy + 3) > lum(img, cx, yy + 7) + 6)
                        and not (lum(img, cx, yy - 3) > lum(img, cx, yy - 7) + 6))
            dips, in_dip = 0, False
            for yy in range(y0, y1):
                b = thin_bright(yy)
                if b and not in_dip:
                    dips += 1
                    in_dip = True
                elif not b:
                    in_dip = False
            ok(dips == 1, f"{cid}: one hairline divider, no hidden frames", f"dips {dips}")

            # chips: optically centred ink, and inside the card's padding
            if c["chips"]:
                cf = ImageFont.truetype(R.MED, max(6, int(doc["type"]["chip"] * ss)))
                cy = content[1] + content[3] - m["inner"] - m["chip"]
                label = c["chips"][0]
                if label[:2] in ("⌘Y", "⌘N"):
                    label = label[2:]
                elif label[:1].isdigit():
                    label = label[1:]
                x0, y0c = P(content[0] + m["inner"], cy)
                tw = cf.getlength(label)
                box = (x0, y0c, x0 + tw + 2 * m["chipPadH"] * ss, y0c + m["chip"] * ss)
                ext = ink_extent_y(img, (box[0] + 3, box[1] + 2, box[2] - 3, box[3] - 2),
                                   lambda l: l < 45)
                want = (box[1] + box[3]) / 2
                got = None if ext[0] is None else (ext[0] + ext[1]) / 2
                ok(got is not None and abs(got - want) <= 1.0,
                   f"{cid}: chip label ink centred",
                   f"drift {None if got is None else round(got - want, 2)}px")

            # composer: 1-px hairline + bare glyphs
            fx, fy = P(composer[0], composer[1])
            fw, fh = composer[2] * ss, composer[3] * ss
            col_x = int(fx + fw * 0.5)
            runs, in_run = 0, False
            for yy in range(int(fy - 4), int(fy + fh + 4)):
                bright = (lum(img, col_x, yy) > lum(img, col_x, yy - 6) + 10
                          and lum(img, col_x, yy) > lum(img, col_x, yy + 6) + 10)
                if bright and not in_run:
                    runs += 1
                    in_run = True
                elif not bright:
                    in_run = False
            ok(runs <= 2, f"{cid}: recess hairline is one device pixel", f"runs {runs}")
            mic = sum(1 for yy in range(int(fy + fh / 2 - 9 * ss), int(fy + fh / 2 + 9 * ss), 2)
                      for xx in range(int(fx + 8 * ss), int(fx + 24 * ss), 2)
                      if abs(lum(img, xx, yy) - lum(img, fx + 30 * ss, fy + 4 * ss)) > 24)
            ret = sum(1 for yy in range(int(fy + fh / 2 - 9 * ss), int(fy + fh / 2 + 9 * ss), 2)
                      for xx in range(int(fx + fw - 24 * ss), int(fx + fw - 8 * ss), 2)
                      if abs(lum(img, xx, yy) - lum(img, fx + fw - 30 * ss, fy + 4 * ss)) > 24)
            ok(mic > 20 and ret > 20, f"{cid}: mic and return glyphs, bare")

        else:  # the band: whisper ink inside the capsule, LUPY at rest present
            band_h = c["h"]
            if c["surface"] == "whisper":
                sb = c["boxes"]["status"]
                ext = ink_extent_y(img, (P(sb[0], sb[1])[0], P(sb[0], sb[1])[1],
                                         P(sb[0] + sb[2], sb[1])[0],
                                         P(sb[0], sb[1] + sb[3])[1]),
                                   lambda l: l > 120)
                ok(ext[0] is not None,
                   f"{cid}: whisper ink present inside the band")
                ok(ext[0] is not None and ext[0] >= P(0, 2)[1] and ext[1] <= P(0, band_h - 2)[1],
                   f"{cid}: whisper ink clears the capsule's top and bottom",
                   f"{ext}")
            av = c["boxes"]["avatar"]
            body = sum(1 for yy in range(int(P(av[0], av[1])[1]), int(P(av[0], av[1] + av[3])[1]), 2)
                       for xx in range(int(P(av[0], av[1])[0]), int(P(av[0] + av[2], av[1])[0]), 2)
                       if lum(img, xx, yy) > 200)
            ok(body > 30, f"{cid}: LUPY's white body is where the law put him", f"{body}")

    print(f"\nCOUNCIL, ALL SURFACES: "
          f"{'SATISFIED' if not FAILS else str(len(FAILS)) + ' FAILURES'} ({CHECKS} checks)")
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
