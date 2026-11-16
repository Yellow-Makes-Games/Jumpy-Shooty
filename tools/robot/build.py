#!/usr/bin/env python3
"""Builds the robot model files the game loads.

    python3 tools/robot/build.py            # writes every playable character into game/player/robot/
    python3 tools/robot/build.py --drafts DIR   # writes every draft design into DIR, for comparing looks

Each playable character (designs.PLAYABLE) gets NAME.glb (the full body) and
NAME_arms.glb (the first-person arms and guns). They share one skeleton and one
set of animations: designs.py is each robot's shape, weapons.py the guns every robot
carries, animations.py the moves and weapon_anims.py the long guns' versions of them.
After changing either, run this and then open the project in Godot (it re-imports
the files on its own).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import designs  # noqa: E402
from glb import write_model  # noqa: E402
from kit import Tri  # noqa: E402
from rig import BODY  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def body_clips():
    try:
        import animations
        import weapon_anims
    except ImportError:
        return []
    return [c.bake(BODY) for c in animations.body_clips() + weapon_anims.body_clips()]


def slim(mesh, k):
    """Thin the forearms and hands around their own length (first-person arms only)."""
    if k == 1.0:
        return
    for i, t in enumerate(mesh.tris):
        side = {"forearm_l": -1, "hand_l": -1, "forearm_r": 1, "hand_r": 1}.get(t.bone)
        if side is None:
            continue
        cx = BODY.bone("forearm_l").pos[0] * -side
        pts = t.points.copy()
        pts[:, 0] = cx + (pts[:, 0] - cx) * k
        pts[:, 2] *= k
        mesh.tris[i] = Tri(pts, t.material, t.bone)


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
    import animations
    import weapon_anims
    out = os.path.join(ROOT, "game", "player", "robot")
    os.makedirs(out, exist_ok=True)
    clips = body_clips()
    arm_clips = [c.bake(BODY) for c in animations.arms_clips() + weapon_anims.arms_clips()]
    for name in designs.PLAYABLE:
        mesh = designs.DESIGNS[name]()
        write_model(os.path.join(out, name + ".glb"), BODY, mesh, designs.MATERIALS, clips, name=name.capitalize())
        print("%s.glb: %d triangles, %d bones, %d clips" % (name, mesh.count(), len(BODY.bones), len(clips)))
        # First-person arms: the same robot with only its arms and gun, and its own clips.
        arms = designs.DESIGNS[name]()
        arms.tris = [t for t in arms.tris if t.bone in designs.ARM_BONES]
        slim(arms, designs.FP_SLIM.get(name, 1.0))
        write_model(os.path.join(out, name + "_arms.glb"), BODY, arms, designs.MATERIALS, arm_clips, name=name.capitalize() + "Arms")
        print("%s_arms.glb: %d triangles, %d clips" % (name, arms.count(), len(arm_clips)))


if __name__ == "__main__":
    main()
