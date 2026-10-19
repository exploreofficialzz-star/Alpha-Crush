#!/usr/bin/env python3
"""Writes Godot .import sidecars for the combat edition's generated icons (PNG) and audio (WAV) so a fresh checkout imports them
with the same settings as the older assets. Godot rewrites these on first import; they only pin the settings.
Run after build_combat_icons.py and build_combat_audio.py:  python3 tools/assetgen/write_combat_imports.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from write_imports import ROOT, md5, uid_for  # noqa: E402

PNG_TEMPLATE = '''[remap]

importer="texture"
type="CompressedTexture2D"
uid="{uid}"
path="res://.godot/imported/{name}-{digest}.ctex"
metadata={{
"vram_texture": false
}}

[deps]

source_file="{res}"
dest_files=["res://.godot/imported/{name}-{digest}.ctex"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
'''

WAV_TEMPLATE = '''[remap]

importer="wav"
type="AudioStreamWAV"
uid="{uid}"
path="res://.godot/imported/{name}-{digest}.sample"

[deps]

source_file="{res}"
dest_files=["res://.godot/imported/{name}-{digest}.sample"]

[params]

force/8_bit=false
force/mono=false
force/max_rate=false
force/max_rate_hz=44100
edit/trim=false
edit/normalize=false
edit/loop_mode=0
edit/loop_begin=0
edit/loop_end=-1
compress/mode=2
'''


def write_for(folder, extension, template):
    count = 0
    base = os.path.join(ROOT, folder)
    for dirpath, _dirs, files in os.walk(base):
        for file in sorted(files):
            if not file.endswith(extension):
                continue
            full = os.path.join(dirpath, file)
            res = "res://" + os.path.relpath(full, ROOT).replace(os.sep, "/")
            target = full + ".import"
            if os.path.exists(target):
                continue
            with open(target, "w") as handle:
                handle.write(template.format(uid=uid_for(res), name=file, digest=md5(res), res=res))
            count += 1
    return count


if __name__ == "__main__":
    pngs = write_for("assets/ui/icons", ".png", PNG_TEMPLATE)
    wavs = write_for("audio", ".wav", WAV_TEMPLATE)
    print("wrote %d png and %d wav import files" % (pngs, wavs))
