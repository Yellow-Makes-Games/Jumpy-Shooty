"""A minimal .glb (binary glTF 2.0) writer: one skinned mesh, a bone tree, animations."""
import json
import struct
import numpy as np


class Glb:
    def __init__(self):
        self.bin = bytearray()
        self.views = []
        self.accessors = []
        self.doc = {"asset": {"version": "2.0", "generator": "Jumpy Shooty robot builder"}}

    def _view(self, data: bytes, target=None):
        while len(self.bin) % 4:
            self.bin.append(0)
        view = {"buffer": 0, "byteOffset": len(self.bin), "byteLength": len(data)}
        if target:
            view["target"] = target
        self.bin.extend(data)
        self.views.append(view)
        return len(self.views) - 1

    def accessor(self, array, kind, ctype, target=None, minmax=False):
        """kind: SCALAR/VEC3/VEC4/MAT4. ctype: numpy dtype."""
        arr = np.ascontiguousarray(array, dtype=ctype)
        comp = {np.float32: 5126, np.uint16: 5123, np.uint8: 5121, np.uint32: 5125}[ctype]
        count = arr.shape[0]
        acc = {"bufferView": self._view(arr.tobytes(), target), "componentType": comp, "count": count, "type": kind}
        if minmax:
            flat = arr.reshape(count, -1)
            acc["min"] = [float(x) for x in flat.min(axis=0)]
            acc["max"] = [float(x) for x in flat.max(axis=0)]
        self.accessors.append(acc)
        return len(self.accessors) - 1

    def write(self, path):
        self.doc["buffers"] = [{"byteLength": len(self.bin)}]
        self.doc["bufferViews"] = self.views
        self.doc["accessors"] = self.accessors
        js = json.dumps(self.doc, separators=(",", ":")).encode()
        while len(js) % 4:
            js += b" "
        while len(self.bin) % 4:
            self.bin.append(0)
        total = 12 + 8 + len(js) + 8 + len(self.bin)
        with open(path, "wb") as f:
            f.write(struct.pack("<4sII", b"glTF", 2, total))
            f.write(struct.pack("<I4s", len(js), b"JSON"))
            f.write(js)
            f.write(struct.pack("<I4s", len(self.bin), b"BIN\0"))
            f.write(bytes(self.bin))


def write_model(path, skeleton, mesh, materials, clips, name="Robot"):
    """skeleton: rig.Skeleton. mesh: kit.Mesh (positions in rest pose, each triangle tied to a bone).
    materials: {name: dict(color, metallic, roughness, emission)}. clips: list of rig.Clip (already baked)."""
    g = Glb()
    bones = skeleton.bones
    nodes = []
    for b in bones:
        local = b.pos - (bones[b.parent].pos if b.parent >= 0 else 0.0)
        node = {"name": b.name, "translation": [float(x) for x in local]}
        kids = [i for i, c in enumerate(bones) if c.parent == b.index]
        if kids:
            node["children"] = kids
        nodes.append(node)

    mat_names = list(materials.keys())
    g.doc["materials"] = []
    for mname in mat_names:
        m = materials[mname]
        c = m["color"]
        mat = {"name": mname, "pbrMetallicRoughness": {
            "baseColorFactor": [c[0], c[1], c[2], 1.0],
            "metallicFactor": m.get("metallic", 0.0), "roughnessFactor": m.get("roughness", 0.7)}}
        if "emission" in m:
            e = m["emission"]
            mat["emissiveFactor"] = [min(e[0], 1.0), min(e[1], 1.0), min(e[2], 1.0)]
        g.doc["materials"].append(mat)

    prims = []
    for mi, mname in enumerate(mat_names):
        tris = [t for t in mesh.tris if t.material == mname]
        if not tris:
            continue
        pos = np.array([p for t in tris for p in t.points], dtype=np.float32)
        nrm = np.array([t.normal for t in tris for _ in range(3)], dtype=np.float32)
        joints = np.zeros((len(pos), 4), dtype=np.uint8)
        joints[:, 0] = [skeleton.index(t.bone) for t in tris for _ in range(3)]
        weights = np.zeros((len(pos), 4), dtype=np.float32)
        weights[:, 0] = 1.0
        idx = np.arange(len(pos), dtype=np.uint32)
        prims.append({
            "attributes": {
                "POSITION": g.accessor(pos, "VEC3", np.float32, 34962, minmax=True),
                "NORMAL": g.accessor(nrm, "VEC3", np.float32, 34962),
                "JOINTS_0": g.accessor(joints, "VEC4", np.uint8, 34962),
                "WEIGHTS_0": g.accessor(weights, "VEC4", np.float32, 34962),
            },
            "indices": g.accessor(idx, "SCALAR", np.uint32, 34963),
            "material": mi,
        })
    g.doc["meshes"] = [{"name": name, "primitives": prims}]

    ibm = np.zeros((len(bones), 16), dtype=np.float32)
    for i, b in enumerate(bones):
        m = np.eye(4, dtype=np.float32)
        m[:3, 3] = -b.pos
        ibm[i] = m.T.reshape(16)  # column-major
    g.doc["skins"] = [{"joints": list(range(len(bones))), "skeleton": 0,
                       "inverseBindMatrices": g.accessor(ibm, "MAT4", np.float32)}]
    mesh_node = len(nodes)
    nodes.append({"name": name, "mesh": 0, "skin": 0})
    g.doc["nodes"] = nodes
    g.doc["scenes"] = [{"name": name, "nodes": [0, mesh_node]}]
    g.doc["scene"] = 0

    anims = []
    for clip in clips:
        times = g.accessor(np.array(clip.times, dtype=np.float32), "SCALAR", np.float32, minmax=True)
        samplers, channels = [], []
        for bone_name, quats in clip.rotations.items():
            samplers.append({"input": times, "output": g.accessor(quats, "VEC4", np.float32), "interpolation": "LINEAR"})
            channels.append({"sampler": len(samplers) - 1, "target": {"node": skeleton.index(bone_name), "path": "rotation"}})
        for bone_name, positions in clip.positions.items():
            samplers.append({"input": times, "output": g.accessor(positions, "VEC3", np.float32), "interpolation": "LINEAR"})
            channels.append({"sampler": len(samplers) - 1, "target": {"node": skeleton.index(bone_name), "path": "translation"}})
        anims.append({"name": clip.name, "samplers": samplers, "channels": channels})
    if anims:
        g.doc["animations"] = anims
    g.write(path)
