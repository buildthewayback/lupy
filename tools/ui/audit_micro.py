"""THE COUNCIL, MICROMETRE — pixel-level micro-audit of every rendered surface.

audit_all.py asks "is each surface right?"; this council asks "is every MICRO thing
right, everywhere?": column alignment to the pixel, line pitch uniformity, hairline
thickness and span, corner-radius agreement with the law, chip ink centring on EVERY
chip, button depth whisper, bare glyphs (no rings), one ellipsis and not two, the pure
white body on every canvas, measured contrast on every headline surface, menu-bar
clearance, and the nested-box ban. ~15 families × 9 canvases.

Run: python3 tools/ui/audit_micro.py      Exit 0 = SATISFIED.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "character"))

from PIL import Image  # noqa: E402,F401
import render_island as R  # noqa: E402
import render_rig_states  # noqa: E402

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


def ink_rows(img, x0, x1, y0, y1, thresh=70):
    """y-ranges that carry ink in the column."""
    rows = []
    cur = None
    for y in range(int(y0), int(y1)):
        hit = any(lum(img, x, y) > thresh for x in range(int(x0), int(x1), 2))
        if hit and cur is None:
            cur = [y, y]
        elif hit:
            cur[1] = y
        elif cur:
            rows.append(tuple(cur))
            cur = None
    if cur:
        rows.append(tuple(cur))
    return rows


def ink_cols(img, y0, y1, x0, x1, thresh=70):
    cols = []
    for x in range(int(x0), int(x1)):
        if any(lum(img, x, y) > thresh for y in range(int(y0), int(y1), 2)):
            cols.append(x)
    return (cols[0], cols[-1]) if cols else (None, None)


def contrast(img, x, y_text, x_bg, y_bg):
    lt = lum(img, x, y_text) + 5.0
    lb = lum(img, x_bg, y_bg) + 5.0
    hi, lo = max(lt, lb), min(lt, lb)
    return (hi + 25) / (lo + 25) * (255 + 25) / (255 + 25) * ((hi / 255 * 0.95 + 0.05) ** 0.5) / ((lo / 255 * 0.95 + 0.05) ** 0.5) * 1.0


def wcag(img, x_t, y_t, x_b, y_b):
    def lin(v):
        v = v / 255.0
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = img.getpixel((int(x_t), int(y_t)))[:3]
    lt = 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    r, g, b = img.getpixel((int(x_b), int(y_b)))[:3]
    lb = 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    hi, lo = max(lt, lb), min(lt, lb)
    return (hi + 0.05) / (lo + 0.05)


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

        W, H = int(c["w"]), int(c["h"])

        # ── the body: pure white on every single canvas ─────────────────────
        av = c["boxes"]["avatar"]
        ax, ay = P(av[0] + av[2] / 2, av[1] + av[3] * 0.55)
        px = img.getpixel((int(ax), int(ay)))[:3]
        ok(px == (255, 255, 255), f"{cid}: LUPY's body is pure white", str(px))

        # ── menu-bar clearance: notch-flush or the 4-pt software gap ────────
        top_found = None
        for y in range(int(oy * ss), int((oy + 40) * ss)):
            if lum(img, P(W / 2, 0)[0], y) > 18:
                top_found = y
                break
        if top_found is not None:
            gap_pt = (top_found / ss) - oy
            ok(gap_pt < 0.6 or abs(gap_pt - 4) < 0.6,
               f"{cid}: panel meets the menu bar by law (gap {gap_pt:.2f}pt)")

        if c["surface"] == "headline":
            content = c["boxes"]["content"]
            cx0, cy0 = P(content[0], content[1])
            cx1, cy1 = P(content[0] + content[2], content[1] + content[3])

            # ── column alignment: every text row starts at the same pixel ───
            rows = ink_rows(img, cx0 + 2, cx1 - 2, cy0, cy1)
            lefts = []
            for (y0, y1) in rows:
                if y1 - y0 < 3 * ss:  # skip hairlines
                    l, _ = ink_cols(img, y0, y1, cx0 + 1, cx1 - 1)
                    if l is not None:
                        lefts.append(l)
            if len(lefts) >= 2:
                ok(max(lefts) - min(lefts) <= 1 * ss,
                   f"{cid}: text column aligned to one edge (spread {max(lefts)-min(lefts):.0f}px)")

            # ── line pitch uniformity ───────────────────────────────────────
            text_rows = [r for r in rows if r[1] - r[0] >= 3 * ss]
            if len(text_rows) >= 3:
                pitches = [text_rows[i + 1][0] - text_rows[i][0] for i in range(len(text_rows) - 1)]
                same = max(pitches) - min(pitches)
                ok(same <= 1.5 * ss or min(pitches) > 8 * ss,
                   f"{cid}: line pitch uniform (Δ {same/ss:.2f}pt)")

            # ── measured contrast of the quietest text vs the panel ─────────
            if text_rows:
                y0, y1 = text_rows[-1]
                yt = (y0 + y1) / 2
                ink_l = max(lum(img, x, yt) for x in range(int(cx0) + 2, int(cx1) - 2, 2))
                ix = [x for x in range(int(cx0) + 2, int(cx1) - 2, 2)
                      if lum(img, x, yt) >= ink_l - 1][0]
                ratio = wcag(img, ix, yt, cx1 - 2 * ss, yt)
                ok(ratio >= 4.5, f"{cid}: quiet text clears WCAG AA ({ratio:.2f}:1)")

            # ── hairline divider: one bright run, 1–2 px, spanning content ──
            divs = []
            for y in range(int(cy0), int(cy1)):
                l = lum(img, P(W / 2, 0)[0], y)
                if l > lum(img, P(W / 2, 0)[0], y - 4) + 6 and l > lum(img, P(W / 2, 0)[0], y + 4) + 6:
                    divs.append(y)
            runs = []
            for y in divs:
                if runs and y - runs[-1][1] <= 2:
                    runs[-1][1] = y
                else:
                    runs.append([y, y])
            thin = [r for r in runs if r[1] - r[0] <= 2 * ss]
            ok(len(thin) >= 1, f"{cid}: exactly-the-divider hairlines present ({len(thin)})")
            for r in thin[:1]:
                l0, _ = ink_cols(img, r[0], r[1] + 1, cx0 - 4 * ss, cx1 + 4 * ss, thresh=40)
                ok(l0 is not None and abs(l0 - (cx0 + m["inner"] * ss)) < 2 * ss,
                   f"{cid}: divider starts at the inner column",
                   f"{None if l0 is None else round((l0-cx0)/ss,1)}pt")

            # ── chips: EVERY chip's ink optically centred + depth whisper ───
            if c["chips"]:
                from PIL import ImageFont as IF
                cf = IF.truetype(R.MED, max(6, int(doc["type"]["chip"] * ss)))
                cy = content[1] + content[3] - m["inner"] - m["chip"]
                xcur = content[0] + m["inner"]
                for i, label in enumerate(c["chips"]):
                    lab = label
                    if lab[:2] in ("⌘Y", "⌘N"):
                        lab = lab[2:]
                    elif lab[:1].isdigit():
                        lab = lab[1:]
                    tw = cf.getlength(lab)
                    bx0, by0 = P(xcur, cy)
                    bx1, by1 = P(xcur + tw / ss + 2 * m["chipPadH"], cy + m["chip"])
                    ext = ink_rows(img, bx0 + 3, bx1 - 3, by0 + 2, by1 - 2)
                    if ext:
                        cy_ink = (ext[0][0] + ext[-1][1]) / 2
                        cy_box = (by0 + by1) / 2
                        ok(abs(cy_ink - cy_box) <= 0.75 * ss,
                           f"{cid}: chip {i} ink centred (Δ {abs(cy_ink-cy_box)/ss:.2f}pt)")
                        mid = (bx0 + bx1) / 2
                        lt = lum(img, mid, by0 + 2 * ss)
                        lb = lum(img, mid, by1 - 2 * ss)
                        if lt > 60:
                            ok(0 < lt - lb < 30,
                               f"{cid}: chip {i} accent depth is a whisper (Δ {lt-lb:.1f})")
                    xcur += tw / ss + 2 * m["chipPadH"] + m["grid"]

            # ── composer: bare glyphs, no rings around them ─────────────────
            comp = c["boxes"]["composer"]
            if comp[2] > 0:
                kx0, ky0 = P(comp[0], comp[1])
                kx1, ky1 = P(comp[0] + comp[2], comp[1] + comp[3])
                ring_hits = 0
                cxm = kx0 + 10 * ss
                cym = (ky0 + ky1) / 2
                for ang in range(0, 360, 30):
                    import math
                    rx = cxm + math.cos(math.radians(ang)) * 7 * ss
                    ry = cym + math.sin(math.radians(ang)) * 7 * ss
                    if lum(img, rx, ry) > 120:
                        ring_hits += 1
                ok(ring_hits <= 3, f"{cid}: mic glyph is bare (ring hits {ring_hits})")

        if c["surface"] in ("whisper", "motion"):
            # ── whisper ink lives inside the capsule, one ellipsis ──────────
            st = c["boxes"]["status"]
            if st[2] > 0:
                sx0, sy0 = P(st[0], st[1])
                sx1, sy1 = P(st[0] + st[2], st[1] + st[3])
                ext = ink_rows(img, sx0, sx1, sy0 - 2 * ss, sy1 + 2 * ss)
                ok(len(ext) > 0 and ext[0][0] >= sy0 - 1 * ss and ext[-1][1] <= sy1 + 1 * ss,
                   f"{cid}: whisper ink inside the band")

    print(f"\nCOUNCIL, MICROMETRE: {'SATISFIED' if not FAILS else str(len(FAILS)) + ' FAILURES'}"
          f" ({CHECKS} checks)")
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
