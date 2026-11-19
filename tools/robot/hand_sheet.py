#!/usr/bin/env python3
"""A picture sheet of the robots' hands, for reviewing a change to them (hands.py, the
poses in rig.HANDS) without opening the game: each robot's right hand open (back and
palm), relaxed and as a fist, then holding a pistol (from both sides), a sword, and the
left hand under a rifle (seen from the front).

    python3 tools/robot/hand_sheet.py OUT.png [robot ...]     (default: every playable robot;
                                                               or a Character Creator body: frog, yeti...)
"""
import json
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import creatures  # noqa: E402
import designs  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CELL = 300
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
# [title, what the shot shows]
COLUMNS = [
    ("Open: back", {"hand": "open", "bone": "index_r", "aim": [0.0, 0.0, 0.0], "from": [1.0, 0.35, -0.2], "ortho": 0.26}),
    ("Open: palm", {"hand": "open", "bone": "index_r", "aim": [0.0, 0.0, 0.0], "from": [-1.0, 0.35, -0.2], "ortho": 0.26}),
    ("Relaxed", {"hand": "relaxed", "bone": "index_r", "aim": [0.0, 0.0, 0.0], "from": [-0.9, 0.4, -0.6], "ortho": 0.26}),
    ("Fist", {"hand": "fist", "bone": "index_r", "aim": [0.0, 0.01, 0.02], "from": [-0.9, 0.4, -0.6], "ortho": 0.26}),
    ("Pistol: left side", {"weapon": "pistol", "bone": "pistol", "aim": [0.0, 0.02, -0.02], "from": [-1.0, 0.3, -0.45], "ortho": 0.34}),
    ("Pistol: right side", {"weapon": "pistol", "bone": "pistol", "aim": [0.0, 0.02, -0.02], "from": [1.0, 0.3, -0.45], "ortho": 0.34}),
    ("Sword", {"weapon": "sword", "bone": "pistol", "aim": [0.0, 0.0, 0.03], "from": [-1.0, 0.3, -0.3], "ortho": 0.32}),
    ("Rifle: fore-end", {"weapon": "rifle", "bone": "hand_l", "aim": [0.04, 0.02, 0.0], "from": [0.0, 0.15, -1.0], "ortho": 0.3}),
]


def main():
    out = os.path.abspath(sys.argv[1])
    robots = sys.argv[2:] or list(designs.PLAYABLE)
    shots = []
    with tempfile.TemporaryDirectory() as tmp:
        for robot in robots:
            for i, (_, what) in enumerate(COLUMNS):
                # (a Character Creator body, by its kit's name: the whole character from that kit)
                who = "custom:n=X|l=%s|t=%s|h=%s" % (robot, robot, robot) if robot in creatures.KITS else robot
                shots.append(dict(what, out=os.path.join(tmp, "%s_%d.png" % (robot, i)), character=who, size=[CELL * 2, CELL * 2]))
        job = os.path.join(tmp, "job.json")
        json.dump({"shots": shots}, open(job, "w"))
        env = dict(os.environ)
        env.setdefault("VK_ICD_FILENAMES", "/usr/share/vulkan/icd.d/lvp_icd.json")
        subprocess.run(["xvfb-run", "-a", "-s", "-screen 0 1280x1280x24", os.environ.get("GODOT", "godot"), "--rendering-driver", "vulkan",
                        "--path", ROOT, "--script", "tools/robot/hand_preview.gd", "--", "--job=" + job],
                       check=True, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1200)
        head = 44
        side = 150
        sheet = Image.new("RGB", (side + CELL * len(COLUMNS), head + CELL * len(robots)), (38, 41, 48))
        d = ImageDraw.Draw(sheet)
        font = ImageFont.truetype(FONT, 20)
        for c, (title, _) in enumerate(COLUMNS):
            d.text((side + CELL * c + CELL // 2, 12), title, font=font, fill=(215, 220, 230), anchor="ma")
        for r, robot in enumerate(robots):
            d.text((14, head + r * CELL + CELL // 2), robot.capitalize(), font=font, fill=(255, 255, 255), anchor="lm")
            for c in range(len(COLUMNS)):
                im = Image.open(os.path.join(tmp, "%s_%d.png" % (robot, c))).resize((CELL - 2, CELL - 2), Image.LANCZOS)
                sheet.paste(im, (side + c * CELL + 1, head + r * CELL + 1))
        sheet.save(out)
        print(out)


if __name__ == "__main__":
    main()
