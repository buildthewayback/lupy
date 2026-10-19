#!/usr/bin/env python3
"""Regenerate Mac/Sources/Lupy/Character/LupyGeometry.swift from the spec JSON.

    python3 tools/character/gen_geometry.py

The Swift file is generated, never hand-edited. This keeps the shipping rig tied to
the measured reference: change the measurement, regenerate, rerun the rig tests.
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SPEC = os.path.join(ROOT, "docs/concepts/lupy-character-spec-v1.json")
OUT = os.path.join(ROOT, "Mac/Sources/Lupy/Character/LupyGeometry.swift")


def apex_patch(outline, aspect, join_x=0.16043):
    """Rebuild the top of the silhouette as a tangent-matched curve.

    The outline was measured from a glowing reference photo, where the top few
    pixels of the body fade into the halo. A brightness threshold therefore clips
    the apex, leaving a flat cap with visible corners (verified: the reference apex
    is a broad circular cap, radius ~0.30 body-widths).

    So the measured sides and base are kept verbatim, and only the region above the
    first measured point at |x| >= join_x is replaced by one symmetric cubic that:
      * passes through both shoulders,
      * matches the measured tangent slope at each shoulder (C1),
      * peaks horizontally at exactly `aspect` on the centre line.

    Nothing else about the character changes, and the reconstruction is deterministic.
    """
    pts = [(x, y) for x, y in outline]
    # shoulder = the highest measured point on each side at or beyond join_x
    def shoulder(sign):
        best = None
        for (x, y) in pts:
            if sign * x >= join_x - 1e-9:
                if best is None or y > best[1]:
                    best = (x, y)
        return best

    L, R = shoulder(-1), shoulder(1)          # left (negative x) and right
    xa, ya = abs(R[0]), R[1]
    h = (aspect - ya) / 0.75                  # cubic with y1=y2=ya+h peaks at ya+0.75h
    # slope of the measured outline just inside the shoulder
    near = sorted([p for p in pts if 0.09 < p[0] < xa - 0.005], key=lambda p: -p[0])
    if len(near) >= 1:
        xb, yb = near[0]
        slope = abs((ya - yb) / (xa - xb))
    else:
        slope = 0.45
    c = max(0.004, xa - h / slope)            # control point offset from the axis

    patch = []
    n = 26
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        x = (u * u * u) * (-xa) + 3 * (u * u) * t * (-c) + 3 * u * (t * t) * c + (t * t * t) * xa
        y = (u * u * u) * ya + 3 * (u * u) * t * (ya + h) + 3 * u * (t * t) * (ya + h) + (t * t * t) * ya
        patch.append((x, y))
    # keep every measured point strictly below the shoulders
    kept = [p for p in pts if p[1] < ya - 1e-9]
    # walk the kept points starting from the right shoulder going clockwise
    idx = min(range(len(kept)), key=lambda i: (kept[i][0] - xa) ** 2 + (kept[i][1] - ya) ** 2)
    ordered = kept[idx:] + kept[:idx]
    return patch[1:-1] + ordered   # shoulders come from the patch endpoints

def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def main():
    spec = json.load(open(SPEC))
    outline = apex_patch(spec["outline"], spec["body"]["aspect_h_over_w"])
    body, eye, blush = spec["body"], spec["eye"], spec["blush"]
    body_colour = spec["body_colour"]

    L = []
    a = L.append
    a("// GENERATED FILE — do not edit by hand.")
    a("// Source: docs/concepts/lupy-character-spec-v1.json")
    a("// Regenerate: python3 tools/character/gen_geometry.py")
    a("//")
    a("// Measured outline of the founder's reference, symmetrised, with the apex")
    a("// reconstructed as a tangent-matched curve (the photo's glow clipped it):")
    a("// %d points, ordered from the apex. x is in body-width units, y is UP" % len(outline))
    a("// from the body base. The rig resamples by arc length and fits smooth cubic")
    a("// Béziers, so the character stays a true vector at every size.")
    a("")
    a("enum LupyGeometry {")
    a("    static let outline: [(Double, Double)] = [")
    row = []
    for i, (x, y) in enumerate(outline):
        row.append("(%.5f, %.5f)" % (x, y))
        if len(row) == 4 or i == len(outline) - 1:
            a("        " + ", ".join(row) + ",")
            row = []
    a("    ]")
    a("")
    a("    /// Body height / width, measured from the reference.")
    a("    static let bodyAspect: Double = %.4f" % body["aspect_h_over_w"])
    a("")
    a("    /// Eye metrics in body-width units (rest pose, flat projection).")
    a("    static let eyeW: Double = %.5f" % eye["w"])
    a("    static let eyeH: Double = %.5f" % eye["h"])
    a("    static let eyeCentreX: Double = %.5f" % eye["centre_x"])
    a("    static let eyeCentreYFromBase: Double = %.5f" % eye["centre_y_from_bottom"])
    a("")
    a("    /// Blush, in body-width units.")
    a("    static let blushX: Double = %.5f" % blush["centre_x"])
    a("    static let blushYFromBase: Double = %.5f" % blush["centre_y_from_bottom"])
    a("    static let blushRX: Double = %.5f" % blush["radius_x"])
    a("    static let blushRY: Double = %.5f" % blush["radius_y"])
    a("    static let blushOpacity: Double = %.4f" % blush["opacity"])
    r, g, b = hex_rgb(blush["colour"])
    a("    static let blushColour: (r: Double, g: Double, b: Double) = (%.5f, %.5f, %.5f)" % (r, g, b))
    a("")
    r, g, b = hex_rgb(body_colour["base"])
    a("    /// Brand law: the body is pure neutral white.")
    a("    static let bodyColour: (r: Double, g: Double, b: Double) = (%.5f, %.5f, %.5f)" % (r, g, b))
    a("}")

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        f.write("\n".join(L) + "\n")
    print("wrote %s (%d outline points)" % (os.path.relpath(OUT, ROOT), len(outline)))


if __name__ == "__main__":
    main()
