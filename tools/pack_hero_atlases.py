"""Pure Python atlas packer for Ranger sprite sheets (testable without Blender).

This module mirrors the Blender atlas packing logic in tools/blender/pack_hero_atlases.py
but uses only Python standard library. It can be unit tested independently.
"""
from __future__ import annotations
import argparse
from array import array
import json
import sys
from pathlib import Path
import zlib
import struct


DEFAULT_PADDING = 2


class PNGError(Exception):
    pass


def read_png(path: Path) -> tuple[int, int, array]:
    """Read a PNG file and return (width, height, pixels_array).

    pixels_array is an array('f') of RGBA values in range 0.0..1.0,
    laid out row-major (top to bottom, left to right).
    """
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

    pixels = array("f", [0.0]) * (width * height * 4)
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
        # Convert to float 0..1
        for i, val in enumerate(recon):
            pixels[y * stride + i] = val / 255.0

    return width, height, pixels


def read_png_dimensions(path: Path) -> tuple[int, int]:
    """Read PNG width/height from file header."""
    width, height, _ = read_png(path)
    return width, height


def make_png(width: int, height: int, pixels: array | None = None) -> bytes:
    """Create a minimal valid PNG with given pixel data."""
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
            row_data = bytes(int(p * 255) for p in pixels[row_start:row_start + width * 4])
            raw += row_data

    idat = zlib.compress(raw)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")


def extrude_edges(pixels: array, fw: int, fh: int, atlas_w: int, atlas_h: int,
                  col: int, row: int, padding: int) -> None:
    """Copy edge pixels into padding area to prevent texture filtering seams."""
    base_x = col * fw + (col + 1) * padding
    base_y = row * fh + (row + 1) * padding

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
        atlas_w = cols * fw + (cols + 1) * padding
        atlas_h = rows * fh + (rows + 1) * padding

        # Create atlas pixel array (RGBA float 0..1)
        pixels = array("f", [0.0]) * (atlas_w * atlas_h * 4)
        state, direction = animation_name.rsplit("_", 1)
        frame_meta = {}

        for index, frame_id in enumerate(frame_ids):
            source_path = base / state / direction / (frame_id + ".png")
            if not source_path.is_file():
                raise RuntimeError(f"Missing frame file: {source_path}")

            # Read actual PNG data
            src_w, src_h, src_pixels = read_png(source_path)

            # Verify dimensions match expected frame size
            if src_w != fw or src_h != fh:
                raise RuntimeError(
                    f"Frame {frame_id} has dimensions {src_w}x{src_h}, "
                    f"expected {fw}x{fh} (from manifest frame_size)"
                )

            col, row = index % cols, index // cols
            base_x = col * fw + (col + 1) * padding
            base_y = row * fh + (row + 1) * padding

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


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--columns", type=int, default=4)
    parser.add_argument("--padding", type=int, default=DEFAULT_PADDING,
                        help=f"Pixel gap between frames (default: {DEFAULT_PADDING})")
    return parser.parse_args(argv)


def main():
    opt = parse_args()
    manifest_path = opt.manifest.resolve()
    manifest = pack_atlas(manifest_path, opt.columns, opt.padding)
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
                             encoding="utf-8")
    print(f"Packed {len(manifest['atlases'])} atlases into {manifest_path.parent / 'atlases'}")


if __name__ == "__main__":
    main()
