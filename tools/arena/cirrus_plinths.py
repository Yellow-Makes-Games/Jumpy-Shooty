#!/usr/bin/env python3
"""Cuts the plinth round each of Cirrus's buildings at its doorways (kept as a record; a
second run changes nothing).

The plinth is a drawn-only strip 0.7 m high along the foot of every outside wall. It
was made as one piece for each side of a building, so it ran across the bottoms of the
doorways too. This edits game/maps/cirrus.tscn as text: each plinth piece is kept only
where a wall stands behind it (a solid box named Wall..., from the ground to above the
plinth's top), as one piece for each such stretch.

    python3 tools/arena/cirrus_plinths.py
"""
import os
import re

SCENE = os.path.join(os.path.dirname(__file__), "..", "..", "game", "maps", "cirrus.tscn")
NEAR = 0.35      # how far behind a plinth the wall's box may be
CORNER = 0.75    # a stretch that ends this near the plinth's end runs on to it (the corner)


def num(x):
    return ("%.4f" % x).rstrip("0").rstrip(".") or "0"


def read(part):
    """A box block as (name, parent, [x, y, z], [sx, sy, sz], its settings), or None."""
    head = re.match(r'\[node name="([^"]+)" type="[^"]+" parent="([^"]+)"', part)
    if not head:
        return None
    props = dict(re.findall(r"(?m)^(\w+) = (.*)$", part))
    xf = re.match(r"Transform3D\(([^)]*)\)", props.get("transform", "Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0)"))
    size = re.match(r"Vector3\(([^)]*)\)", props.get("size", ""))
    if not xf or not size or props.get("shape", "0") != "0":
        return None
    t = [float(v) for v in xf.group(1).split(",")]
    if [round(v, 3) for v in t[:9]] != [1, 0, 0, 0, 1, 0, 0, 0, 1]:
        return None
    return head.group(1), head.group(2), t[9:], [float(v) for v in size.group(1).split(",")], props


def main():
    with open(SCENE) as fh:
        text = fh.read()
    parts = re.split(r"(?m)^(?=\[)", text)
    walls = {}   # parent -> [(lo, hi)]
    for part in parts:
        block = read(part)
        if block and block[0].startswith("Wall") and block[4].get("solid", "true") == "true":
            lo = [block[2][a] - block[3][a] / 2 for a in range(3)]
            hi = [block[2][a] + block[3][a] / 2 for a in range(3)]
            walls.setdefault(block[1], []).append((lo, hi))
    cut = 0
    for n, part in enumerate(parts):
        block = read(part)
        if not block or not re.fullmatch(r"Plinth\d*", block[0]) or "/Building/" not in block[1] + "/":
            continue
        name, parent, at, size, _props = block
        along = 0 if size[0] > size[2] else 2
        across = 2 - along
        start, end = at[along] - size[along] / 2, at[along] + size[along] / 2
        top = at[1] + size[1] / 2
        spans = []
        for lo, hi in walls.get(parent, []):
            if lo[1] > 0.05 or hi[1] < top - 0.01:
                continue   # (not from the ground to above the plinth)
            if at[across] < lo[across] - NEAR or at[across] > hi[across] + NEAR:
                continue
            spans.append([max(lo[along], start), min(hi[along], end)])
        spans = sorted(s for s in spans if s[1] - s[0] > 0.01)
        merged = []
        for s in spans:
            if merged and s[0] <= merged[-1][1] + 0.02:
                merged[-1][1] = max(merged[-1][1], s[1])
            else:
                merged.append(s)
        if not merged:
            continue
        if merged[0][0] - start < CORNER:
            merged[0][0] = start
        if end - merged[-1][1] < CORNER:
            merged[-1][1] = end
        if len(merged) == 1 and merged[0] == [start, end]:
            continue   # (no doorway in this side)
        out = []
        for i, (a, b) in enumerate(merged):
            where = list(at)
            where[along] = (a + b) / 2
            long = list(size)
            long[along] = b - a
            piece = re.sub(r'(?m)^\[node name="[^"]+"', '[node name="%s"' % (name if i == 0 else "%s_%d" % (name, i + 1)), part, count=1)
            piece = re.sub(r"(?m)^transform = .*$", "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s)" % ", ".join(num(v) for v in where), piece, count=1)
            piece = re.sub(r"(?m)^size = .*$", "size = Vector3(%s)" % ", ".join(num(v) for v in long), piece, count=1)
            out.append(piece)
        parts[n] = "".join(out)
        cut += 1
        print("%s/%s: %s" % (parent, name, ", ".join("%s to %s" % (num(a), num(b)) for a, b in merged)))
    with open(SCENE, "w") as fh:
        fh.write("".join(parts))
    print("cut %d plinth pieces" % cut)


if __name__ == "__main__":
    main()
