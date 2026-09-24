"""First-person arms from the licensed Synty Palm City character rig (Blender 4.4).

Run from the project root after staging the licensed source (see docs/handoffs/C00.md):

    blender -b --factory-startup --python tools/blender/build_fp_arms.py

Keeps one character's two arms (upper arm to fingertips) skinned to the shared Synty
skeleton and exports them to art/synty/hands/fp_arms.glb. That folder is Git-ignored like the
other staged Synty art: the output contains licensed geometry and must not be committed.
The game poses the arms at runtime (scripts/player/fp_arms.gd), so no animation is exported.
"""

import os
import sys

import bpy

SOURCE = os.path.join("Assets", "Synty", "POLYGON_Palm_City", "models", "PalmCityCharacters.fbx")
CHARACTER = "SM_Chr_Surfer_Male_01"
OUTPUT = os.path.join("art", "synty", "hands", "fp_arms.glb")
ARM_BONE_PREFIXES = ("Shoulder_", "Elbow_", "Hand_", "Thumb_", "IndexFinger_", "Finger_")
KEEP_BONES = {"Root", "Hips", "Spine_01", "Spine_02", "Spine_03", "Clavicle_L", "Clavicle_R"}


def is_arm_bone(name):
    return name.startswith(ARM_BONE_PREFIXES)


def main():
    root = os.getcwd()
    source = os.path.join(root, SOURCE)
    if not os.path.exists(source):
        print("MISSING licensed source: %s" % source)
        sys.exit(1)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=source)
    armature = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    body = bpy.data.objects[CHARACTER]
    for obj in list(bpy.data.objects):
        if obj.type == "MESH" and obj is not body:
            bpy.data.objects.remove(obj, do_unlink=True)

    # Metres, Z up: bake the FBX unit scale and axis rotation into rig and mesh.
    bpy.ops.object.select_all(action="DESELECT")
    armature.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

    # Keep vertices mostly driven by arm bones, then split them into left and right arms.
    groups = {g.index: g.name for g in body.vertex_groups}
    mesh = body.data
    keep = set()
    side_of = {}
    for vertex in mesh.vertices:
        arm_weight = {"L": 0.0, "R": 0.0}
        total = 0.0
        for element in vertex.groups:
            name = groups.get(element.group, "")
            total += element.weight
            if is_arm_bone(name):
                arm_weight[name[-1]] += element.weight
        side = "L" if arm_weight["L"] >= arm_weight["R"] else "R"
        if total > 0.0 and arm_weight[side] / total >= 0.5:
            keep.add(vertex.index)
            side_of[vertex.index] = side
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="DESELECT")
    bpy.ops.object.mode_set(mode="OBJECT")
    for vertex in mesh.vertices:
        vertex.select = vertex.index not in keep
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.delete(type="VERT")
    bpy.ops.object.mode_set(mode="OBJECT")
    body.name = "Arms"
    body.data.name = "Arms"
    print("ARM verts=%d faces=%d" % (len(body.data.vertices), len(body.data.polygons)))

    # Drop leg, head and face bones; the arm chains hang from the spine.
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.mode_set(mode="EDIT")
    for bone in list(armature.data.edit_bones):
        if bone.name not in KEEP_BONES and not is_arm_bone(bone.name):
            armature.data.edit_bones.remove(bone)
    bpy.ops.object.mode_set(mode="OBJECT")
    for group in list(body.vertex_groups):
        if group.name not in armature.data.bones:
            body.vertex_groups.remove(group)
    armature.name = "ArmRig"

    out = os.path.join(root, OUTPUT)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    armature.select_set(True)
    body.select_set(True)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_yup=True,
                              export_skins=True, export_animations=False, export_texcoords=True,
                              export_normals=True, export_materials="PLACEHOLDER", export_extras=False)
    print("EXPORTED %s" % out)


if __name__ == "__main__":
    main()
