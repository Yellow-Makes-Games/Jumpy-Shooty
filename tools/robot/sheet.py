#!/usr/bin/env python3
"""Renders contact sheets of animation clips (a row of poses over time, from the
side and from the front), for checking animations without opening the editor.

    python3 tools/robot/sheet.py OUT_DIR clip[:frames[:t0:t1]] [clip ...] [--glb PATH] [--gl]
"""
import json
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw, ImageFont  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
COLORS = {"accent": [0.90, 0.14, 0.08], "visor": [0.90, 0.14, 0.08]}


def main():
    args = sys.argv[1:]
    glb = os.path.join(ROOT, "game", "player", "robot", "needle.glb")
    mode = []
    if "--gl" in args:
        args.remove("--gl")
        mode = ["gl"]
    if "--glb" in args:
        i = args.index("--glb")
        glb = os.path.abspath(args[i + 1])
        del args[i:i + 2]
    out_dir = os.path.abspath(args[0])
    os.makedirs(out_dir, exist_ok=True)
    import animations
    durations = {c.name: c.duration for c in animations.body_clips()}
    shots, plan = [], []
    for spec in args[1:]:
        parts = spec.split(":")
        clip = parts[0]
        n = int(parts[1]) if len(parts) > 1 else 6
        t0 = float(parts[2]) if len(parts) > 2 else 0.0
        t1 = float(parts[3]) if len(parts) > 3 else durations[clip]
        times = [t0 + (t1 - t0) * i / max(n - 1, 1) for i in range(n)]
        if len(parts) <= 2 and n > 1:
            times = [durations[clip] * i / n for i in range(n)]  # loops: skip the repeated last frame
        gap = 1.5
        width = gap * n
        for view, yaw in (("side", 90), ("front", 30)):
            items = [{"glb": glb, "clip": clip, "time": t, "yaw": yaw, "colors": COLORS,
                      "pos": [width / 2 - gap * (i + 0.5), 0, 0]} for i, t in enumerate(times)]
            path = os.path.join(out_dir, "_%s_%s.png" % (clip, view))
            shots.append({"out": path, "size": [int(250 * n), 400], "items": items,
                          "camera": {"pos": [0, 1.0, -9], "look": [0, 1.0, 0], "ortho": 2.4}})
        plan.append((clip, times))
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        json.dump({"shots": shots}, f)
    subprocess.run([os.path.join(ROOT, "tools", "robot", "preview.sh"), f.name] + mode, check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 20)
    for clip, times in plan:
        a = Image.open(os.path.join(out_dir, "_%s_side.png" % clip)).convert("RGB")
        b = Image.open(os.path.join(out_dir, "_%s_front.png" % clip)).convert("RGB")
        sheet = Image.new("RGB", (a.width, a.height + b.height), (0, 0, 0))
        sheet.paste(a, (0, 0))
        sheet.paste(b, (0, a.height))
        d = ImageDraw.Draw(sheet)
        d.text((8, 6), clip, font=font, fill=(255, 255, 255))
        for i, t in enumerate(times):
            d.text((250 * i + 100, 372), "%.2fs" % t, font=font, fill=(255, 255, 255))
        sheet.save(os.path.join(out_dir, clip + ".png"))
        os.remove(os.path.join(out_dir, "_%s_side.png" % clip))
        os.remove(os.path.join(out_dir, "_%s_front.png" % clip))
        print(os.path.join(out_dir, clip + ".png"))


if __name__ == "__main__":
    main()
