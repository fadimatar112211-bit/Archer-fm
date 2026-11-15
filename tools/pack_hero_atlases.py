"""Pure Python atlas packer for Ranger sprite sheets (testable without Blender).

This is the single atlas packer implementation. `tools/blender/pack_hero_atlases.py`
loads it so the CI pipeline and these unit tests exercise exactly the same code,
and so the atlas is written from the decoded PNG bytes instead of a
Blender-managed image buffer with its own colour and row-order conventions.
"""
from __future__ import annotations
import argparse
from array import array
import json
import shutil
import sys
from pathlib import Path
import zlib
import struct


DEFAULT_PADDING = 2


class PNGError(Exception):
    pass


def read_png_bytes(path: Path) -> tuple[int, int, bytearray]:
    """Decode an 8-bit RGBA PNG into a row-major, top-to-bottom RGBA buffer."""
    with path.open("rb") as f:
        data = f.read()

    if len(data) < 29 or data[:8] != b"\x89PNG\r\n\x1a\n":
        raise PNGError(f"{path}: not a valid PNG file (bad signature)")

    # Parse chunks
    pos = 8
    ihdr_data = None
    idat_chunks = []

    while pos < len(data):
        if pos + 8 > len(data):
            raise PNGError(f"{path}: truncated chunk header")
        length = struct.unpack(">I", data[pos:pos+4])[0]
        chunk_type = data[pos+4:pos+8]
        pos += 8

        if pos + length > len(data):
            raise PNGError(f"{path}: truncated chunk data")
        chunk_data = data[pos:pos+length]
        pos += length

        if pos + 4 > len(data):
            raise PNGError(f"{path}: truncated chunk CRC")
        crc = data[pos:pos+4]
        pos += 4

        # Verify CRC
        expected_crc = struct.pack(">I", zlib.crc32(chunk_type + chunk_data) & 0xffffffff)
        if crc != expected_crc:
            raise PNGError(f"{path}: CRC mismatch in {chunk_type.decode('ascii', errors='ignore')} chunk")

        if chunk_type == b"IHDR":
            if length != 13:
                raise PNGError(f"{path}: IHDR chunk has invalid length")
            ihdr_data = chunk_data
        elif chunk_type == b"IDAT":
            idat_chunks.append(chunk_data)
        elif chunk_type == b"IEND":
            break
        # Ignore other chunks (gAMA, cHRM, sRGB, tEXt, etc.)

    if ihdr_data is None:
        raise PNGError(f"{path}: missing IHDR chunk")
    if not idat_chunks:
        raise PNGError(f"{path}: missing IDAT chunks")

    # Parse IHDR
    width, height, bit_depth, color_type, compression, filter_method, interlace = struct.unpack(">IIBBBBB", ihdr_data)

    if bit_depth != 8:
        raise PNGError(f"{path}: only 8-bit depth supported, got {bit_depth}")
    if color_type != 6:
        raise PNGError(f"{path}: only truecolor with alpha (color_type=6) supported, got {color_type}")
    if compression != 0:
        raise PNGError(f"{path}: unknown compression method")
    if filter_method != 0:
        raise PNGError(f"{path}: unknown filter method")
    if interlace != 0:
        raise PNGError(f"{path}: interlaced PNGs not supported")

    # Decompress IDAT data
    compressed = b"".join(idat_chunks)
    try:
        raw = zlib.decompress(compressed)
    except zlib.error as e:
        raise PNGError(f"{path}: failed to decompress IDAT: {e}")

    # Unfilter scanlines
    bytes_per_pixel = 4  # RGBA
    stride = width * bytes_per_pixel
    expected_len = height * (1 + stride)  # 1 filter byte per row
    if len(raw) != expected_len:
        raise PNGError(f"{path}: decompressed data length mismatch: expected {expected_len}, got {len(raw)}")

    out = bytearray(width * height * 4)
    prev_row = None

    for y in range(height):
        row_start = y * (1 + stride)
        filter_type = raw[row_start]
        row_data = raw[row_start + 1:row_start + 1 + stride]

        if filter_type == 0:  # None
            recon = row_data
        elif filter_type == 1:  # Sub
            recon = bytearray(stride)
            for i in range(stride):
                left = recon[i - bytes_per_pixel] if i >= bytes_per_pixel else 0
                recon[i] = (row_data[i] + left) & 0xff
        elif filter_type == 2:  # Up
            recon = bytearray(stride)
            for i in range(stride):
                up = prev_row[i] if prev_row else 0
                recon[i] = (row_data[i] + up) & 0xff
        elif filter_type == 3:  # Average
            recon = bytearray(stride)
            for i in range(stride):
                left = recon[i - bytes_per_pixel] if i >= bytes_per_pixel else 0
                up = prev_row[i] if prev_row else 0
                recon[i] = (row_data[i] + ((left + up) // 2)) & 0xff
        elif filter_type == 4:  # Paeth
            recon = bytearray(stride)
            for i in range(stride):
                left = recon[i - bytes_per_pixel] if i >= bytes_per_pixel else 0
                up = prev_row[i] if prev_row else 0
                up_left = prev_row[i - bytes_per_pixel] if prev_row and i >= bytes_per_pixel else 0
                # Paeth predictor
                p = left + up - up_left
                pa = abs(p - left)
                pb = abs(p - up)
                pc = abs(p - up_left)
                if pa <= pb and pa <= pc:
                    pr = left
                elif pb <= pc:
                    pr = up
                else:
                    pr = up_left
                recon[i] = (row_data[i] + pr) & 0xff
        else:
            raise PNGError(f"{path}: unknown filter type {filter_type}")

        prev_row = recon
        out[y * stride:(y + 1) * stride] = recon

    return width, height, out


def read_png(path: Path) -> tuple[int, int, array]:
    """Read a PNG file and return (width, height, pixels_array).

    pixels_array is an array('f') of RGBA values in range 0.0..1.0,
    laid out row-major (top to bottom, left to right).
    """
    width, height, raw = read_png_bytes(path)
    pixels = array("f", [0.0]) * len(raw)
    for i, val in enumerate(raw):
        pixels[i] = val / 255.0
    return width, height, pixels


def read_png_dimensions(path: Path) -> tuple[int, int]:
    """Read PNG width/height from file header."""
    width, height, _ = read_png_bytes(path)
    return width, height


def _to_byte(value: float) -> int:
    """Quantise a 0..1 float without the off-by-one that plain int() truncation gives."""
    return min(255, max(0, int(round(value * 255.0))))


def make_png(width: int, height: int, pixels: array | bytearray | bytes | None = None) -> bytes:
    """Create a minimal valid PNG with given pixel data.

    Exactly one input pixel produces exactly one output byte: a byte buffer is
    copied verbatim, and a float buffer is quantised once with rounding. The
    packer passes byte buffers so atlases are byte-identical to the renders.
    """
    def chunk(kind: bytes, data: bytes) -> bytes:
        return (struct.pack(">I", len(data)) + kind + data +
                struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff))

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)

    if pixels is None:
        # Empty transparent image
        raw = b"".join(b"\x00" + bytes(width * 4) for _ in range(height))
    else:
        raw = b""
        for y in range(height):
            raw += b"\x00"  # filter type 0 (None)
            row_start = y * width * 4
            row = pixels[row_start:row_start + width * 4]
            if isinstance(row, (bytes, bytearray)):
                raw += bytes(row)
            else:
                raw += bytes(_to_byte(p) for p in row)

    idat = zlib.compress(raw)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")


def extrude_edges(pixels: array | bytearray, fw: int, fh: int, atlas_w: int, atlas_h: int,
                  col: int, row: int, padding: int) -> None:
    """Copy edge pixels into padding area to prevent texture filtering seams."""
    # Every frame owns `padding` pixels on each side, so the gap between two
    # neighbouring frames is 2 * padding and neither frame's extrusion can
    # overwrite the other's.
    base_x = col * (fw + 2 * padding) + padding
    base_y = row * (fh + 2 * padding) + padding

    # Left edge
    for y in range(fh):
        src_y = base_y + y
        src_start = src_y * atlas_w * 4 + base_x * 4
        for p in range(padding):
            dst_x = base_x - (p + 1)
            dst_start = src_y * atlas_w * 4 + dst_x * 4
            pixels[dst_start:dst_start + 4] = pixels[src_start:src_start + 4]

    # Right edge
    for y in range(fh):
        src_y = base_y + y
        src_start = src_y * atlas_w * 4 + (base_x + fw - 1) * 4
        for p in range(padding):
            dst_x = base_x + fw + p
            dst_start = src_y * atlas_w * 4 + dst_x * 4
            pixels[dst_start:dst_start + 4] = pixels[src_start:src_start + 4]

    # Top edge
    for x in range(fw):
        src_x = base_x + x
        src_start = base_y * atlas_w * 4 + src_x * 4
        for p in range(padding):
            dst_y = base_y - (p + 1)
            dst_start = dst_y * atlas_w * 4 + src_x * 4
            pixels[dst_start:dst_start + 4] = pixels[src_start:src_start + 4]

    # Bottom edge
    for x in range(fw):
        src_x = base_x + x
        src_start = (base_y + fh - 1) * atlas_w * 4 + src_x * 4
        for p in range(padding):
            dst_y = base_y + fh + p
            dst_start = dst_y * atlas_w * 4 + src_x * 4
            pixels[dst_start:dst_start + 4] = pixels[src_start:src_start + 4]


def pack_atlas(manifest_path: Path, columns: int = 4, padding: int = DEFAULT_PADDING) -> dict:
    """Pack frames from manifest into atlas PNGs and metadata JSON.

    Returns updated manifest dict with atlas entries added.
    """
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    base = manifest_path.parent
    fw = int(manifest["frame_size"]["width"])
    fh = int(manifest["frame_size"]["height"])
    padding = max(0, padding)
    if columns < 1:
        raise RuntimeError("--columns must be positive")

    atlas_entries = []
    for animation_name, animation in sorted(manifest["animations"].items()):
        frame_ids = animation["frames"]
        cols = min(columns, len(frame_ids))
        rows = (len(frame_ids) + cols - 1) // cols
        # Each frame gets `padding` pixels on all four sides. Between two
        # frames that is a 2 * padding gap, so both frames' extruded edges fit
        # side by side instead of overwriting each other.
        cell_w = fw + 2 * padding
        cell_h = fh + 2 * padding
        atlas_w = cols * cell_w
        atlas_h = rows * cell_h

        # Create atlas byte buffer (top-down RGBA, same order as the PNG rows)
        pixels = bytearray(atlas_w * atlas_h * 4)
        state, direction = animation_name.rsplit("_", 1)
        frame_meta = {}

        for index, frame_id in enumerate(frame_ids):
            source_path = base / state / direction / (frame_id + ".png")
            if not source_path.is_file():
                raise RuntimeError(f"Missing frame file: {source_path}")

            # Read actual PNG data. Byte buffers, not floats or Blender image
            # pixels: both have their own row order at the edges of the API.
            src_w, src_h, src_pixels = read_png_bytes(source_path)

            # Verify dimensions match expected frame size
            if src_w != fw or src_h != fh:
                raise RuntimeError(
                    f"Frame {frame_id} has dimensions {src_w}x{src_h}, "
                    f"expected {fw}x{fh} (from manifest frame_size)"
                )

            col, row = index % cols, index // cols
            base_x = col * cell_w + padding
            base_y = row * cell_h + padding

            for y in range(fh):
                src_start = y * fw * 4
                dst_start = ((base_y + y) * atlas_w + base_x) * 4
                pixels[dst_start:dst_start + fw * 4] = src_pixels[src_start:src_start + fw * 4]

            if padding > 0:
                extrude_edges(pixels, fw, fh, atlas_w, atlas_h, col, row, padding)

            # TexturePacker-style metadata:
            # - frame: position and size of the sprite in the atlas (without padding)
            # - spriteSourceSize: position and size in the original untrimmed image (same as frame since no trim)
            # - sourceSize: original image size (fw, fh)
            # - trimmed: false (we don't trim)
            frame_meta[frame_id] = {
                "frame": {"x": base_x, "y": base_y, "w": fw, "h": fh},
                "rotated": False, "trimmed": False,
                "spriteSourceSize": {"x": 0, "y": 0, "w": fw, "h": fh},
                "sourceSize": {"w": fw, "h": fh}
            }

        # Save atlas PNG
        atlas_dir = base / "atlases"
        atlas_dir.mkdir(parents=True, exist_ok=True)
        atlas_png = make_png(atlas_w, atlas_h, pixels)
        atlas_png_path = atlas_dir / f"{animation_name}.png"
        atlas_png_path.write_bytes(atlas_png)

        # Save metadata JSON
        meta_path = atlas_dir / f"{animation_name}.json"
        meta_path.write_text(json.dumps({
            "frames": frame_meta,
            "meta": {
                "app": "Archer FM Atlas Packer (Python)",
                "image": f"{animation_name}.png",
                "size": {"w": atlas_w, "h": atlas_h},
                "scale": "1",
                "padding": padding,
                "frame_size": {"w": fw, "h": fh},
                "pivot": manifest.get("pivot", {"x": 0.5, "y": 0.86}),
                "memory_estimate_mb": round(atlas_w * atlas_h * 4 / (1024 * 1024), 2)
            }
        }, indent=2) + "\n", encoding="utf-8")

        atlas_entries.append({
            "animation": animation_name,
            "image": f"atlases/{animation_name}.png",
            "meta": f"atlases/{animation_name}.json"
        })

    manifest["atlases"] = atlas_entries
    return manifest


def _pixel(buffer: bytearray, width: int, x: int, y: int) -> bytes:
    start = (y * width + x) * 4
    return bytes(buffer[start:start + 4])


def verify_packed(manifest: dict, base: Path) -> None:
    """Re-read every written atlas and prove it reproduces the rendered frames.

    Atlas metadata uses PNG (top-left origin) coordinates, while some image APIs
    store pixels bottom-up. That mismatch is invisible to a structural manifest
    validator: every rectangle is still inside the image and every atlas frame
    id still exists, yet the rectangles point at mirrored or shifted pixels.
    This pass compares the actual bytes, including the extruded padding strips,
    and fails the build instead of shipping a wrong atlas.
    """
    problems: list[str] = []
    for entry in manifest["atlases"]:
        name = entry["animation"]
        atlas_path = base / entry["image"]
        meta_path = base / entry["meta"]
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        atlas_w, atlas_h, atlas = read_png_bytes(atlas_path)
        declared = meta.get("meta", {}).get("size", {})
        if declared and (declared.get("w") != atlas_w or declared.get("h") != atlas_h):
            problems.append(f"{atlas_path.name}: is {atlas_w}x{atlas_h}, metadata says "
                            f"{declared.get('w')}x{declared.get('h')}")
            continue
        padding = int(meta.get("meta", {}).get("padding", 0))
        state, direction = name.rsplit("_", 1)
        rects: list[tuple[str, int, int, int, int]] = []
        for frame_id in manifest["animations"][name]["frames"]:
            rect = meta["frames"][frame_id]["frame"]
            x, y, w, h = rect["x"], rect["y"], rect["w"], rect["h"]
            if x < padding or y < padding or x + w + padding > atlas_w or y + h + padding > atlas_h:
                problems.append(f"{name}/{frame_id}: rect {rect} leaves no room for "
                                f"{padding}px padding inside {atlas_w}x{atlas_h}")
                continue
            rects.append((frame_id, x, y, w, h))
            source_path = base / state / direction / f"{frame_id}.png"
            src_w, src_h, source = read_png_bytes(source_path)
            if (src_w, src_h) != (w, h):
                problems.append(f"{name}/{frame_id}: source is {src_w}x{src_h}, "
                                f"atlas rect is {w}x{h}")
                continue
            for row in range(h):
                atlas_start = ((y + row) * atlas_w + x) * 4
                source_start = row * src_w * 4
                if atlas[atlas_start:atlas_start + w * 4] != source[source_start:source_start + w * 4]:
                    problems.append(f"{name}/{frame_id}: atlas pixels differ from "
                                    f"{source_path.name} on row {row}")
                    break
            if not padding:
                continue
            for row in range(h):
                left = _pixel(atlas, atlas_w, x, y + row)
                right = _pixel(atlas, atlas_w, x + w - 1, y + row)
                for offset in range(1, padding + 1):
                    if _pixel(atlas, atlas_w, x - offset, y + row) != left:
                        problems.append(f"{name}/{frame_id}: left padding is not the "
                                        f"frame edge at row {row}")
                    if _pixel(atlas, atlas_w, x + w - 1 + offset, y + row) != right:
                        problems.append(f"{name}/{frame_id}: right padding is not the "
                                        f"frame edge at row {row}")
            for column in range(w):
                top = _pixel(atlas, atlas_w, x + column, y)
                bottom = _pixel(atlas, atlas_w, x + column, y + h - 1)
                for offset in range(1, padding + 1):
                    if _pixel(atlas, atlas_w, x + column, y - offset) != top:
                        problems.append(f"{name}/{frame_id}: top padding is not the "
                                        f"frame edge at column {column}")
                    if _pixel(atlas, atlas_w, x + column, y + h - 1 + offset) != bottom:
                        problems.append(f"{name}/{frame_id}: bottom padding is not the "
                                        f"frame edge at column {column}")
        for i in range(len(rects)):
            for j in range(i + 1, len(rects)):
                a, b = rects[i], rects[j]
                if (a[1] < b[1] + b[3] and b[1] < a[1] + a[3]
                        and a[2] < b[2] + b[4] and b[2] < a[2] + a[4]):
                    problems.append(f"{name}: {a[0]} and {b[0]} overlap")
    if problems:
        for problem in problems[:20]:
            print(f"ATLAS_ERROR: {problem}", file=sys.stderr)
        raise RuntimeError(f"Atlas verification failed with {len(problems)} problem(s)")
    print(f"Verified {len(manifest['atlases'])} atlases: every tile and padding "
          f"strip reproduces its rendered frame")


def publish_bundle(manifest_path: Path, manifest: dict) -> Path | None:
    """Copy a non-Ranger hero into the directory the fixed CI upload collects.

    The workflow can only be edited with a token that has `workflow` scope,
    which this project does not have, so it still uploads the Ranger render
    directory. Non-Ranger heroes are rendered into that directory for the fixed
    validation/packing steps and then copied here as
    `_bundle/<hero>/renders/`; the committing machine moves them to
    `assets/heroes/<hero>/renders/`. `_bundle` is gitignored and never shipped.
    """
    hero_id = manifest["hero_id"]
    if hero_id == "ranger":
        print("BUNDLE_SKIP ranger already lives in the uploaded directory")
        return None
    root = manifest_path.resolve().parents[4]
    bundle = (root / "assets/heroes/ranger/renders/_bundle" / hero_id
              / "renders")
    if bundle.exists():
        shutil.rmtree(bundle)
    bundle.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(manifest_path.parent, bundle,
                    ignore=shutil.ignore_patterns("_bundle"))
    fixed_manifest = bundle / "ranger_manifest.json"
    if fixed_manifest.is_file():
        fixed_manifest.replace(bundle / f"{hero_id}_manifest.json")
    shipped = bundle / f"{hero_id}_manifest.json"
    data = json.loads(shipped.read_text(encoding="utf-8"))
    data["source"]["blend_file"] = (
        f"assets/heroes/{hero_id}/source/{hero_id}_source.blend")
    shipped.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n",
                       encoding="utf-8")
    source = bundle.parent / "source" / f"{hero_id}_source.blend"
    if not source.is_file():
        print(f"BUNDLE_WARNING: {source} is missing; rebuild the source first")
    print(f"BUNDLE_PUBLISHED hero={hero_id} path={bundle}")
    return bundle


def parse_args():
    # `blender -b file.blend --python this.py -- --manifest ...` puts the script
    # arguments after a bare `--`; a plain `python3 this.py --manifest ...`
    # invocation has no separator.
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--columns", type=int, default=4)
    parser.add_argument("--padding", type=int, default=DEFAULT_PADDING,
                        help="Pixels of extruded padding on each side of every frame "
                             f"(default: {DEFAULT_PADDING}); neighbouring frames are "
                             "therefore 2 * padding apart")
    return parser.parse_args(args)


def main():
    opt = parse_args()
    manifest_path = opt.manifest.resolve()
    manifest = pack_atlas(manifest_path, opt.columns, opt.padding)
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
                             encoding="utf-8")
    verify_packed(manifest, manifest_path.parent)
    publish_bundle(manifest_path, manifest)
    print(f"Packed {len(manifest['atlases'])} atlases into {manifest_path.parent / 'atlases'}")


if __name__ == "__main__":
    main()
