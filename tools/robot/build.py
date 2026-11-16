#!/usr/bin/env python3
"""Builds the robot model files the game loads.

    python3 tools/robot/build.py            # writes game/player/robot/robot.glb (and the first-person arms)
    python3 tools/robot/build.py --drafts DIR   # writes every draft design into DIR, for comparing looks

The robot is described in code: designs.py is its shape, animations.py its moves.
After changing either, run this and then open the project in Godot (it re-imports
the files on its own).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import designs  # noqa: E402
from glb import write_model  # noqa: E402
from rig import BODY  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def body_clips():
    try:
        import animations
    except ImportError:
        return []
    return [c.bake(BODY) for c in animations.body_clips()]


def main():
    if "--drafts" in sys.argv:
        out = sys.argv[sys.argv.index("--drafts") + 1]
        os.makedirs(out, exist_ok=True)
        clips = body_clips()
        for name, fn in designs.DESIGNS.items():
            mesh = fn()
            write_model(os.path.join(out, name + ".glb"), BODY, mesh, designs.MATERIALS, clips)
            print("%s: %d triangles" % (name, mesh.count()))
        return
    mesh = designs.DESIGNS[designs.CHOSEN]()
    path = os.path.join(ROOT, "game", "player", "robot", "robot.glb")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    clips = body_clips()
    write_model(path, BODY, mesh, designs.MATERIALS, clips)
    print("robot.glb: %d triangles, %d bones, %d clips" % (mesh.count(), len(BODY.bones), len(clips)))

    # First-person arms: the same robot with only its arms and gun, and its own clips.
    import animations
    arms = designs.DESIGNS[designs.CHOSEN]()
    arms.tris = [t for t in arms.tris if t.bone in designs.ARM_BONES]
    arm_clips = [c.bake(BODY) for c in animations.arms_clips()]
    write_model(os.path.join(os.path.dirname(path), "robot_arms.glb"), BODY, arms, designs.MATERIALS, arm_clips, name="RobotArms")
    print("robot_arms.glb: %d triangles, %d clips" % (arms.count(), len(arm_clips)))


if __name__ == "__main__":
    main()
