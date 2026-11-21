"""Validate the playable Ranger-new Blender scene before sprite rendering.

The production Ranger is the original high-detail skinned GLB with authored
actions. It is not the legacy procedural Ranger profile in hero_profiles.py.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import bpy


def fail(message: str) -> None:
    print("RANGER_NEW_SOURCE_ERROR: " + message, file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    root = Path(__file__).resolve().parents[2]
    config_path = root / "assets/heroes/ranger_new/source/render_config.json"
    config = json.loads(config_path.read_text(encoding="utf-8"))
    hero = config["heroes"]["ranger_new"]
    armature_name = hero["armature_object"]
    armature = bpy.data.objects.get(armature_name)
    if armature is None or armature.type != "ARMATURE":
        fail(f"missing {armature_name} armature")
    if len(armature.data.bones) < 20:
        fail(f"expected the original detailed rig, found {len(armature.data.bones)} bones")
    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    if not meshes:
        fail("source scene has no skinned mesh")
    if not any(any(mod.type == "ARMATURE" and mod.object == armature
                   for mod in obj.modifiers) for obj in meshes):
        fail("no mesh is skinned to the playable Ranger armature")
    if bpy.context.scene.camera is None:
        fail("source scene has no active camera")

    defaults = config.get("defaults", {})
    ranges = defaults.get("action_ranges", {})
    for state, action_name in hero["actions"].items():
        action = bpy.data.actions.get(action_name)
        if action is None:
            fail("missing action " + action_name)
        if not getattr(action, "fcurves", None):
            fail("action has no keyed channels: " + action_name)
        if state not in ranges:
            fail("render config has no frame range for " + state)
        start, end = map(int, ranges[state])
        actual_start, actual_end = action.frame_range
        if actual_start < start or actual_end > end:
            fail(f"{action_name} range {(actual_start, actual_end)} "
                 f"exceeds configured range {(start, end)}")

    print("RANGER_NEW_SOURCE_OK")
    print("bones=" + str(len(armature.data.bones)))
    print("meshes=" + str(len(meshes)))
    print("actions=" + str(len(hero["actions"])))


if __name__ == "__main__":
    main()
