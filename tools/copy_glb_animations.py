# Copies the animation tracks of one GLB onto another GLB that shares the same
# joint skeleton (bone names + rest transforms + inverse bind matrices).
#
# Used for Storm: the playable storm_animated.glb was rigged from the original
# uploaded mesh onto the house 30-bone skeleton (identical to Flame's rig), but
# the rig script exported with the armature forced to REST, so every clip came
# out as a constant pose. Re-running Blender on Storm is not possible here (the
# storm_source.blend was a temporary build artifact), so the authored Flame
# motion is transplanted bone-for-bone: the target mesh, skin, materials and
# embedded texture stay byte-identical, only animation data is added under
# `Storm_*` names.
#
# Channels are retargeted by NODE NAME (the two files order their nodes
# differently because Flame has one node per mesh), so this is safe even when
# node indices do not line up.
#
# Usage:
#   python3 tools/copy_glb_animations.py \
#     assets/heroes/flame/model/flame_animated.glb \
#     assets/heroes/storm/model/storm_animated.glb Flame_ Storm_

import json
import struct
import sys

FLOAT = 5126
VEC = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}


def load_glb(path):
    data = open(path, 'rb').read()
    off = 12
    gltf = None
    binary = b''
    while off < len(data):
        clen, ctype = struct.unpack_from('<II', data, off)
        chunk = data[off + 8:off + 8 + clen]
        if ctype == 0x4E4F534A:
            gltf = json.loads(chunk)
        elif ctype == 0x004E4942:
            binary = chunk
        off += 8 + clen
    return gltf, binary


def node_names(gltf):
    return [n.get('name', '') for n in gltf['nodes']]


def patch(src_path, dst_path, prefix_map):
    src, src_bin = load_glb(src_path)
    tgt, tgt_bin = load_glb(dst_path)

    def rename(name):
        for old, new in prefix_map:
            if name.startswith(old):
                return new + name[len(old):]
        return name

    tgt_names = node_names(tgt)
    tgt_by_name = {name: i for i, name in enumerate(tgt_names) if name}
    src_names = node_names(src)

    bin_pad = (-len(tgt_bin)) % 4
    extra_base = len(tgt_bin) + bin_pad
    additions = []
    cursor = 0

    def copy_accessor(src_idx):
        nonlocal cursor
        acc = src['accessors'][src_idx]
        view = src['bufferViews'][acc['bufferView']]
        comps = VEC[acc['type']]
        start = view.get('byteOffset', 0) + acc.get('byteOffset', 0)
        vals = struct.unpack_from(
            '<%df' % (acc['count'] * comps), src_bin, start)
        payload = struct.pack('<%df' % len(vals), *vals)
        pad = (-len(payload)) % 4
        tgt['bufferViews'].append({
            'buffer': 0,
            'byteOffset': extra_base + cursor,
            'byteLength': len(payload),
        })
        new_acc = {
            'bufferView': len(tgt['bufferViews']) - 1,
            'componentType': FLOAT,
            'count': acc['count'],
            'type': acc['type'],
        }
        if 'min' in acc:
            new_acc['min'] = acc['min']
        if 'max' in acc:
            new_acc['max'] = acc['max']
        tgt['accessors'].append(new_acc)
        additions.append(payload + b'\x00' * pad)
        cursor += len(payload) + pad
        return len(tgt['accessors']) - 1

    copied = 0
    skipped = 0
    new_anims = []
    for anim in src.get('animations', []):
        new_anim = {
            'name': rename(anim.get('name', 'clip')),
            'channels': [],
            'samplers': [],
        }
        for sampler in anim['samplers']:
            new_anim['samplers'].append({
                'input': copy_accessor(sampler['input']),
                'output': copy_accessor(sampler['output']),
                'interpolation': sampler.get('interpolation', 'LINEAR'),
            })
        for ch in anim['channels']:
            node = ch['target'].get('node')
            path = ch['target'].get('path')
            if node is None or path is None:
                continue
            name = src_names[node]
            if name not in tgt_by_name:
                skipped += 1
                continue
            new_anim['channels'].append({
                'sampler': ch['sampler'],
                'target': {'node': tgt_by_name[name], 'path': path},
            })
            copied += 1
        new_anims.append(new_anim)

    # Replace same-named clips instead of keeping both (the target already
    # carries placeholder constant-pose clips under the same names).
    replaced = {a['name'] for a in new_anims}
    tgt['animations'] = [
        a for a in tgt.get('animations', []) if a.get('name') not in replaced
    ] + new_anims

    tgt['buffers'][0]['byteLength'] = extra_base + cursor
    json_bytes = json.dumps(tgt, separators=(',', ':')).encode('utf-8')
    json_bytes += b' ' * ((-len(json_bytes)) % 4)
    combined = tgt_bin + b'\x00' * bin_pad + b''.join(additions)
    total = 12 + 8 + len(json_bytes) + 8 + len(combined)
    with open(dst_path, 'wb') as out:
        out.write(struct.pack('<III', 0x46546C67, 2, total))
        out.write(struct.pack('<II', len(json_bytes), 0x4E4F534A))
        out.write(json_bytes)
        out.write(struct.pack('<II', len(combined), 0x004E4942))
        out.write(combined)
    print('WROTE', dst_path,
          'animations', len(tgt['animations']),
          'channels copied', copied,
          'channels skipped', skipped)


if __name__ == '__main__':
    src_path, dst_path = sys.argv[1], sys.argv[2]
    args = sys.argv[3:]
    pairs = [(args[i], args[i + 1]) for i in range(0, len(args), 2)]
    patch(src_path, dst_path, pairs)
