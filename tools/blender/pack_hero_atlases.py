"""Run the Ranger atlas packer from inside Blender.

The actual packing lives in `tools/pack_hero_atlases.py`, which uses only the
Python standard library and is covered by `tools/tests/test_pack_hero_atlases.py`.
This module exists so the CI pipeline can keep invoking the documented
`blender -b ... --python tools/blender/pack_hero_atlases.py` command without a
second, untested implementation drifting from the tested one.

The original Blender copy of the packer relied on `bpy.data.images` pixel
buffers, which are stored bottom-up while atlas metadata uses top-left
coordinates; every tile was written to the mirrored rows at the far end of the
atlas. Decoding and encoding the PNGs directly avoids that class of bug, avoids
a colour-management round-trip through the scene-linear space, and keeps the
atlas byte-identical to the rendered frames.

Run:
  blender -b ranger_source.blend --python tools/blender/pack_hero_atlases.py -- \
    --manifest assets/heroes/ranger/renders/ranger_manifest.json
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path


def load_packer():
    """Load `tools/pack_hero_atlases.py` by path (both modules share a filename)."""
    path = Path(__file__).resolve().parents[1] / "pack_hero_atlases.py"
    if not path.is_file():
        raise SystemExit(f"ATLAS_ERROR: missing packer module {path}")
    spec = importlib.util.spec_from_file_location("ranger_atlas_packer", path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"ATLAS_ERROR: cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


if __name__ == "__main__":
    try:
        load_packer().main()
    except Exception:
        # Blender exits 0 even when a --python script raises, so report the
        # traceback and force a failing step instead of a green run with no
        # atlases.
        import os
        import traceback
        traceback.print_exc()
        sys.stdout.flush()
        sys.stderr.flush()
        os._exit(1)
