extends Node3D
class_name CaptureZone

## A "Domination" flag point. Stand in the ring (alone) to capture it; if both sides are inside it is contested and nothing
## changes. Progress runs from -1 (fully opposition) to +1 (fully ALPHA).
signal ownership_changed(zone: CaptureZone, new_owner: int)

const RADIUS := 7.5
const CAPTURE_RATE := 0.22
const ALPHA_COLOR := Color(0.20, 0.85, 0.88)
const OPPOSITION_COLOR := Color(0.95, 0.28, 0.22)
const NEUTRAL_COLOR := Color(0.90, 0.90, 0.92)
const CONTESTED_COLOR := Color(1.0, 0.85, 0.20)

var zone_name := "A"
var radius: float = RADIUS
var owner_team := -1
var progress := 0.0
var contested := false

var _ring_material: StandardMaterial3D
var _flag_material: StandardMaterial3D
var _flag: MeshInstance3D
var _label: Label3D
var _pulse := 0.0

func setup(p_name: String, p_radius: float = RADIUS) -> void:
    zone_name = p_name
    radius = p_radius
    var ring := MeshInstance3D.new()
    ring.name = "Ring"
    var torus := TorusMesh.new()
    torus.inner_radius = radius - 0.25
    torus.outer_radius = radius
    torus.rings = 40
    torus.ring_segments = 4
    ring.mesh = torus
    ring.position = Vector3(0.0, 0.08, 0.0)
    ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _ring_material = StandardMaterial3D.new()
    _ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _ring_material.albedo_color = NEUTRAL_COLOR
    ring.material_override = _ring_material
    add_child(ring)
    var pole := MeshInstance3D.new()
    pole.name = "Pole"
    var pole_mesh := CylinderMesh.new()
    pole_mesh.top_radius = 0.07
    pole_mesh.bottom_radius = 0.09
    pole_mesh.height = 4.2
    pole_mesh.radial_segments = 6
    pole_mesh.rings = 1
    pole.mesh = pole_mesh
    pole.position = Vector3(0.0, 2.1, 0.0)
    var steel := StandardMaterial3D.new()
    steel.albedo_color = Color(0.7, 0.72, 0.76)
    steel.metallic = 0.6
    pole.material_override = steel
    pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(pole)
    _flag = MeshInstance3D.new()
    _flag.name = "Flag"
    var cloth := BoxMesh.new()
    cloth.size = Vector3(1.5, 0.9, 0.05)
    _flag.mesh = cloth
    _flag_material = StandardMaterial3D.new()
    _flag_material.albedo_color = NEUTRAL_COLOR
    _flag_material.emission_enabled = true
    _flag_material.emission = NEUTRAL_COLOR
    _flag_material.emission_energy_multiplier = 0.6
    _flag.material_override = _flag_material
    _flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_flag)
    _label = Label3D.new()
    _label.text = zone_name
    _label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _label.no_depth_test = true
    _label.shaded = false
    _label.font_size = 96
    _label.pixel_size = 0.01
    _label.outline_size = 14
    _label.outline_modulate = Color(0.05, 0.08, 0.2, 1.0)
    _label.position = Vector3(0.0, 5.4, 0.0)
    add_child(_label)
    _refresh_visuals()

func set_initial_owner(team: int) -> void:
    owner_team = team
    if team == Teams.ALPHA:
        progress = 1.0
    elif team == Teams.OPPOSITION:
        progress = -1.0
    else:
        progress = 0.0
    _refresh_visuals()

func owner_color() -> Color:
    if owner_team == Teams.ALPHA:
        return ALPHA_COLOR
    if owner_team == Teams.OPPOSITION:
        return OPPOSITION_COLOR
    return NEUTRAL_COLOR

func contains(point: Vector3) -> bool:
    var offset := point - global_position
    offset.y = 0.0
    return offset.length() <= radius

## Advances capture progress from how many fighters of each side stand inside the ring.
func update_zone(delta: float, alpha_count: int, opposition_count: int) -> void:
    _pulse += delta
    contested = alpha_count > 0 and opposition_count > 0
    if not contested:
        var direction := 0.0
        var strength := 0
        if alpha_count > 0:
            direction = 1.0
            strength = mini(alpha_count, 3)
        elif opposition_count > 0:
            direction = -1.0
            strength = mini(opposition_count, 3)
        if direction != 0.0:
            progress = clampf(progress + direction * CAPTURE_RATE * float(strength) * delta, -1.0, 1.0)
            var next_owner := owner_team
            if progress >= 0.999:
                next_owner = Teams.ALPHA
            elif progress <= -0.999:
                next_owner = Teams.OPPOSITION
            if next_owner != owner_team:
                owner_team = next_owner
                ownership_changed.emit(self, owner_team)
    _refresh_visuals()

func _refresh_visuals() -> void:
    if _ring_material == null:
        return
    var color := NEUTRAL_COLOR
    if progress > 0.02:
        color = NEUTRAL_COLOR.lerp(ALPHA_COLOR, clampf(progress, 0.0, 1.0))
    elif progress < -0.02:
        color = NEUTRAL_COLOR.lerp(OPPOSITION_COLOR, clampf(-progress, 0.0, 1.0))
    if contested:
        color = CONTESTED_COLOR
    var alpha := 0.55 + 0.25 * sin(_pulse * 5.0) if contested else 0.5
    _ring_material.albedo_color = Color(color.r, color.g, color.b, alpha)
    _flag_material.albedo_color = color
    _flag_material.emission = color
    _flag.position = Vector3(0.78, 1.0 + 2.6 * (absf(progress) * 0.5 + 0.5), 0.0)
