"""Writes Godot .import sidecar files for the generated human assets so a fresh checkout imports them with the
intended settings (scene without LOD generation for skinned meshes, VRAM-compressed textures, mipmaps for
tiling maps, no mipmaps for UI portraits). Godot rewrites these on first import; they only pin the settings."""
import hashlib, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
ALPHABET = "abcdefghijklmnopqrstuvwxy012345678"


def uid_for(res_path):
    h = int(hashlib.sha1(("alpha_crush:" + res_path).encode()).hexdigest(), 16)
    s = ""
    for _ in range(13):
        s += ALPHABET[h % len(ALPHABET)]; h //= len(ALPHABET)
    return "uid://" + s


def md5(res_path):
    return hashlib.md5(res_path.encode()).hexdigest()


def scene_import(res_path):
    name = os.path.basename(res_path)
    dest = f"res://.godot/imported/{name}-{md5(res_path)}.scn"
    return f'''[remap]

importer="scene"
importer_version=1
type="PackedScene"
uid="{uid_for(res_path)}"
path="{dest}"

[deps]

source_file="{res_path}"
dest_files=["{dest}"]

[params]

nodes/root_type=""
nodes/root_name=""
nodes/root_script=null
mesh_library/use_node_names_as_mesh_names=false
array_mesh/deduplicate_surfaces=true
nodes/apply_root_scale=true
nodes/root_scale=1.0
nodes/import_as_skeleton_bones=false
nodes/use_name_suffixes=true
nodes/use_node_type_suffixes=true
meshes/ensure_tangents=true
meshes/generate_lods=false
meshes/create_shadow_meshes=false
meshes/light_baking=0
meshes/lightmap_texel_size=0.2
meshes/force_disable_compression=false
skins/use_named_skins=true
animation/import=false
animation/fps=30
animation/trimming=false
animation/remove_immutable_tracks=true
animation/import_rest_as_RESET=false
import_script/path=""
materials/extract=0
materials/extract_format=0
materials/extract_path=""
_subresources={{}}
gltf/naming_version=2
gltf/embedded_image_handling=1
gltf/texture_map_mode=1
'''


def texture_import(res_path, normal=False, mipmaps=True, lossless=False):
    name = os.path.basename(res_path)
    dest = f"res://.godot/imported/{name}-{md5(res_path)}.ctex"
    mode = 0 if lossless else 2
    vram = "" if lossless else 'metadata={\n"vram_texture": true\n}\n'
    return f'''[remap]

importer="texture"
type="CompressedTexture2D"
uid="{uid_for(res_path)}"
path="{dest}"
{vram}
[deps]

source_file="{res_path}"
dest_files=["{dest}"]

[params]

compress/mode={mode}
compress/high_quality=false
compress/lossy_quality=0.8
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map={1 if normal else 0}
compress/channel_pack=0
mipmaps/generate={"true" if mipmaps else "false"}
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
detect_3d/compress_to={1 if not lossless else 0}
'''


def write(path, text):
    with open(path, "w") as f:
        f.write(text)


def main():
    n = 0
    models = os.path.join(ROOT, "assets", "models")
    for f in sorted(os.listdir(models)):
        if f.startswith("avatar_") and f.endswith(".glb"):
            write(os.path.join(models, f + ".import"), scene_import("res://assets/models/" + f)); n += 1
    tdir = os.path.join(ROOT, "assets", "textures", "avatar")
    if os.path.isdir(tdir):
        for f in sorted(os.listdir(tdir)):
            if f.endswith(".png"):
                normal = f.endswith("_n.png")
                write(os.path.join(tdir, f + ".import"), texture_import("res://assets/textures/avatar/" + f, normal=normal)); n += 1
    pdir = os.path.join(ROOT, "assets", "ui", "portraits")
    if os.path.isdir(pdir):
        for f in sorted(os.listdir(pdir)):
            if f.endswith(".png"):
                write(os.path.join(pdir, f + ".import"), texture_import("res://assets/ui/portraits/" + f, mipmaps=False, lossless=True)); n += 1
    print("wrote", n, "import files")


if __name__ == "__main__":
    main()
