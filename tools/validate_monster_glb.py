#!/usr/bin/env python3
"""Validate Archer FM monster GLB files without third-party Python packages.

Usage:
  python3 tools/validate_monster_glb.py --root assets/monsters/3d

The validator checks container integrity, meshes, skins, embedded images and
required animation names. It deliberately does not claim to validate visual
quality, foot contact, deformation or Android runtime performance.
"""
from __future__ import annotations

import argparse
import json
import struct
import sys
from pathlib import Path

MAGIC = 0x46546C67
JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942
REQUIRED = {
    "runner": {"idle", "walk", "run", "attack", "hit", "death"},
    "tank": {"idle", "walk", "attack", "hit", "death"},
    "stalker": {"idle", "walk", "attack", "hit", "death"},
    "ranged": {"idle", "walk", "attack", "cast", "release", "hit", "death"},
}


def read_glb(path: Path) -> dict:
    data = path.read_bytes()
    if len(data) < 20:
        raise ValueError("file is shorter than a GLB header plus JSON chunk")
    magic, version, total = struct.unpack_from("<III", data, 0)
    if magic != MAGIC:
        raise ValueError("invalid GLB magic")
    if version != 2:
        raise ValueError(f"expected GLB version 2, got {version}")
    if total != len(data):
        raise ValueError(f"header length {total} differs from file length {len(data)}")

    offset = 12
    document = None
    has_binary = False
    while offset + 8 <= len(data):
        length, kind = struct.unpack_from("<II", data, offset)
        offset += 8
        end = offset + length
        if end > len(data):
            raise ValueError("chunk extends beyond file boundary")
        chunk = data[offset:end]
        if kind == JSON_CHUNK:
            document = json.loads(chunk.decode("utf-8").rstrip(" \\t\\r\\n\\0"))
        elif kind == BIN_CHUNK:
            has_binary = True
        offset = end
    if offset != len(data):
        raise ValueError("trailing bytes after final GLB chunk")
    if document is None:
        raise ValueError("missing JSON chunk")
    document["_hasBinaryChunk"] = has_binary
    return document


def validate_one(root: Path, monster: str, entry: dict) -> list[str]:
    errors: list[str] = []
    relative = entry.get("file")
    if not isinstance(relative, str) or not relative:
        return [f"{monster}: manifest has no file path"]
    path = (root / relative).resolve()
    if root.resolve() not in path.parents:
        return [f"{monster}: file path escapes the asset root"]
    if not path.is_file():
        return [f"{monster}: missing file {path}"]
    try:
        gltf = read_glb(path)
    except Exception as exc:  # report corrupt assets without stopping other types
        return [f"{monster}: {path.name}: {exc}"]

    meshes = gltf.get("meshes", [])
    nodes = gltf.get("nodes", [])
    skins = gltf.get("skins", [])
    animations = gltf.get("animations", [])
    if not meshes:
        errors.append(f"{monster}: no meshes")
    if not nodes:
        errors.append(f"{monster}: no nodes")
    if not skins:
        errors.append(f"{monster}: no skin/skeleton")
    if not animations:
        errors.append(f"{monster}: no animation clips")

    # Validate references that a simple header/clip-name check would miss.
    accessors = gltf.get("accessors", [])
    for mesh_index, mesh in enumerate(meshes):
        for primitive_index, primitive in enumerate(mesh.get("primitives", [])):
            attributes = primitive.get("attributes", {})
            if "POSITION" not in attributes:
                errors.append(
                    f"{monster}: mesh {mesh_index} primitive {primitive_index} has no POSITION attribute"
                )
            for semantic, accessor_index in attributes.items():
                if not isinstance(accessor_index, int) or not 0 <= accessor_index < len(accessors):
                    errors.append(
                        f"{monster}: mesh {mesh_index} primitive {primitive_index} "
                        f"attribute {semantic} references invalid accessor {accessor_index}"
                    )
            indices = primitive.get("indices")
            if indices is not None and (
                not isinstance(indices, int) or not 0 <= indices < len(accessors)
            ):
                errors.append(
                    f"{monster}: mesh {mesh_index} primitive {primitive_index} "
                    f"references invalid index accessor {indices}"
                )

    for skin_index, skin in enumerate(skins):
        joints = skin.get("joints", [])
        if not joints:
            errors.append(f"{monster}: skin {skin_index} has no joints")
        for joint in joints:
            if not isinstance(joint, int) or not 0 <= joint < len(nodes):
                errors.append(f"{monster}: skin {skin_index} references invalid joint node {joint}")
        inverse_bind = skin.get("inverseBindMatrices")
        if inverse_bind is not None and (
            not isinstance(inverse_bind, int) or not 0 <= inverse_bind < len(accessors)
        ):
            errors.append(f"{monster}: skin {skin_index} has invalid inverseBindMatrices accessor")

    for animation in animations:
        for channel_index, channel in enumerate(animation.get("channels", [])):
            target_node = channel.get("target", {}).get("node")
            if target_node is not None and (
                not isinstance(target_node, int) or not 0 <= target_node < len(nodes)
            ):
                errors.append(
                    f"{monster}: animation '{animation.get('name', '<unnamed>')}' "
                    f"channel {channel_index} targets invalid node {target_node}"
                )
            sampler_index = channel.get("sampler")
            samplers = animation.get("samplers", [])
            if not isinstance(sampler_index, int) or not 0 <= sampler_index < len(samplers):
                errors.append(
                    f"{monster}: animation '{animation.get('name', '<unnamed>')}' "
                    f"channel {channel_index} references invalid sampler {sampler_index}"
                )
        for sampler_index, sampler in enumerate(animation.get("samplers", [])):
            for accessor_field in ("input", "output"):
                accessor_index = sampler.get(accessor_field)
                if not isinstance(accessor_index, int) or not 0 <= accessor_index < len(accessors):
                    errors.append(
                        f"{monster}: animation '{animation.get('name', '<unnamed>')}' "
                        f"sampler {sampler_index} has invalid {accessor_field} accessor {accessor_index}"
                    )

    image_count = len(gltf.get("images", []))
    external_images = [
        image.get("uri", "")
        for image in gltf.get("images", [])
        if image.get("uri", "").startswith(("http://", "https://"))
        or (image.get("uri") and not image.get("uri").startswith("data:"))
    ]
    if external_images:
        errors.append(f"{monster}: external image references are not self-contained: {external_images}")
    if image_count and not gltf["_hasBinaryChunk"] and not any(
        image.get("uri", "").startswith("data:") for image in gltf.get("images", [])
    ):
        errors.append(f"{monster}: images exist but no embedded binary chunk/data URI was found")

    clip_map = entry.get("clips", {})
    actual_names = {clip.get("name", "") for clip in animations}
    mapped_names = set(clip_map.values()) if isinstance(clip_map, dict) else set()
    for required in REQUIRED[monster]:
        mapped = clip_map.get(required) if isinstance(clip_map, dict) else None
        if not mapped:
            errors.append(f"{monster}: manifest missing clip mapping '{required}'")
        elif mapped not in actual_names:
            errors.append(f"{monster}: animation '{mapped}' for '{required}' not found; actual={sorted(actual_names)}")

    for clip in animations:
        if not clip.get("name"):
            errors.append(f"{monster}: animation without a name")
        if not clip.get("samplers") or not clip.get("channels"):
            errors.append(f"{monster}: animation '{clip.get('name', '<unnamed>')}' has no channels/samplers")

    print(
        f"{monster}: {path.stat().st_size:,} bytes | "
        f"{len(meshes)} meshes | {len(skins)} skins | "
        f"{len(animations)} animations | {image_count} images"
    )
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("assets/monsters/3d"))
    args = parser.parse_args()
    manifest_path = args.root / "manifest.json"
    if not manifest_path.is_file():
        print(f"ERROR: missing manifest: {manifest_path}", file=sys.stderr)
        return 2
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except Exception as exc:
        print(f"ERROR: invalid manifest JSON: {exc}", file=sys.stderr)
        return 2
    if manifest.get("schemaVersion") != 1:
        print("ERROR: manifest schemaVersion must be 1", file=sys.stderr)
        return 2

    entries = manifest.get("monsters", {})
    errors: list[str] = []
    for monster in REQUIRED:
        entry = entries.get(monster)
        if not isinstance(entry, dict):
            errors.append(f"{monster}: missing manifest entry")
            continue
        errors.extend(validate_one(args.root, monster, entry))

    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    if errors:
        print(f"FAILED: {len(errors)} validation issue(s)", file=sys.stderr)
        return 1
    print("PASS: all four monster GLBs passed structural/clip validation.")
    print("NOTE: visual quality, animation playback and Android performance still require manual/runtime review.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
