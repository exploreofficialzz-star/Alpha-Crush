extends StaticBody3D
class_name BreakableProp

## Crates drop supplies when smashed; red barrels explode and hurt whoever stands near them (the shooter's enemies).
## Both are cover for the AI and fair game for bullets, kicks and blasts.
signal destroyed(prop: BreakableProp)

const BARREL_BLAST_RADIUS := 4.2
const BARREL_BLAST_DAMAGE := 120.0

var kind := "crate"
var health := 40.0
var director: CombatDirector
var fx: CombatFX
var audio: AudioManager
## Called with the prop's position when a crate breaks, so the world can drop a pickup there.
var loot_callback: Callable = Callable()

var _dead := false
var _mesh: MeshInstance3D

## Builds the visible box / drum and its collision shape.
func setup(p_kind: String) -> void:
    kind = p_kind
    collision_layer = Teams.LAYER_BREAKABLE
    collision_mask = 0
    add_to_group("breakable")
    add_to_group("cover")
    _mesh = MeshInstance3D.new()
    _mesh.name = "Mesh"
    _mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var shape_node := CollisionShape3D.new()
    if kind == "barrel":
        health = 30.0
        var drum := CylinderMesh.new()
        drum.top_radius = 0.38
        drum.bottom_radius = 0.38
        drum.height = 1.0
        drum.radial_segments = 10
        drum.rings = 1
        _mesh.mesh = drum
        _mesh.position = Vector3(0.0, 0.5, 0.0)
        var paint := StandardMaterial3D.new()
        paint.albedo_color = Color(0.78, 0.14, 0.10)
        paint.metallic = 0.3
        paint.roughness = 0.55
        _mesh.material_override = paint
        var band := MeshInstance3D.new()
        var band_mesh := CylinderMesh.new()
        band_mesh.top_radius = 0.39
        band_mesh.bottom_radius = 0.39
        band_mesh.height = 0.16
        band_mesh.radial_segments = 10
        band_mesh.rings = 1
        band.mesh = band_mesh
        band.position = Vector3(0.0, 0.0, 0.0)
        var stripe := StandardMaterial3D.new()
        stripe.albedo_color = Color(0.98, 0.82, 0.12)
        band.material_override = stripe
        band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        _mesh.add_child(band)
        var cylinder := CylinderShape3D.new()
        cylinder.radius = 0.38
        cylinder.height = 1.0
        shape_node.shape = cylinder
        shape_node.position = Vector3(0.0, 0.5, 0.0)
    else:
        health = 36.0
        var crate := BoxMesh.new()
        crate.size = Vector3(0.95, 0.95, 0.95)
        _mesh.mesh = crate
        _mesh.position = Vector3(0.0, 0.475, 0.0)
        var wood := MaterialLibrary.get_material("wood_planks")
        if wood != null:
            _mesh.material_override = wood
        else:
            var plain := StandardMaterial3D.new()
            plain.albedo_color = Color(0.5, 0.36, 0.2)
            _mesh.material_override = plain
        var box := BoxShape3D.new()
        box.size = Vector3(0.95, 0.95, 0.95)
        shape_node.shape = box
        shape_node.position = Vector3(0.0, 0.475, 0.0)
    add_child(_mesh)
    add_child(shape_node)

func configure(p_director: CombatDirector, p_fx: CombatFX, p_audio: AudioManager) -> void:
    director = p_director
    fx = p_fx
    audio = p_audio

func take_damage(info: DamageInfo) -> float:
    if _dead:
        return 0.0
    health -= info.amount
    if _mesh != null and is_inside_tree():
        var pulse := create_tween()
        pulse.tween_property(_mesh, "scale", Vector3(1.08, 0.94, 1.08), 0.05)
        pulse.tween_property(_mesh, "scale", Vector3.ONE, 0.1)
    if health <= 0.0:
        _break(info)
    return info.amount

func _break(info: DamageInfo) -> void:
    _dead = true
    collision_layer = 0
    remove_from_group("breakable")
    remove_from_group("cover")
    var center := global_position + Vector3(0.0, 0.5, 0.0)
    if kind == "barrel":
        var team := info.source_team if info.source_team >= 0 else Teams.ALPHA
        var source: Node3D = info.source if is_instance_valid(info.source) else null
        Explosion.detonate(director, fx, center, BARREL_BLAST_RADIUS, BARREL_BLAST_DAMAGE, team, source, 12.0, 0.8)
        if audio != null:
            audio.play_sfx("explosion", randf_range(0.9, 1.05), 1.0)
    else:
        if fx != null:
            fx.poof(center, Color(0.85, 0.65, 0.35, 1.0))
        if audio != null:
            audio.play_sfx("hit_flesh", 0.7, -4.0)
        if loot_callback.is_valid():
            loot_callback.call(center)
    destroyed.emit(self)
    queue_free()
