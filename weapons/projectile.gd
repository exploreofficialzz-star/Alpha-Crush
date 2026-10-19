extends Node3D
class_name Projectile

## Rockets and grenades. Integrated by hand (a short ray per physics step) so fast rockets never tunnel through a wall.
## Rockets explode on the first thing they touch; grenades bounce and explode when their fuse runs out.
const MAX_AGE := 8.0

var kind := "rocket"
var velocity := Vector3.ZERO
var gravity := 0.0
var fuse := -1.0
var explode_on_impact := true
var blast_radius := 4.0
var blast_damage := 100.0
var knockback := 10.0
var team := 0
var shooter: Node3D = null
var director: CombatDirector
var fx: CombatFX
var audio: AudioManager

var _age := 0.0
var _finished := false
var _skip: Array[RID] = []

static func create(p_kind: String) -> Projectile:
    var projectile := Projectile.new()
    projectile.kind = p_kind
    projectile._build_visual()
    return projectile

func configure(p_director: CombatDirector, p_fx: CombatFX, p_audio: AudioManager, p_team: int, p_shooter: Node3D) -> void:
    director = p_director
    fx = p_fx
    audio = p_audio
    team = p_team
    shooter = p_shooter
    var body := p_shooter as CollisionObject3D
    _skip.clear()
    if body != null:
        _skip.append(body.get_rid())

func _build_visual() -> void:
    name = "Projectile_" + kind
    if kind == "grenade":
        var ball := MeshInstance3D.new()
        var sphere := SphereMesh.new()
        sphere.radius = 0.1
        sphere.height = 0.2
        sphere.radial_segments = 8
        sphere.rings = 4
        ball.mesh = sphere
        var shell := StandardMaterial3D.new()
        shell.albedo_color = Color(0.22, 0.30, 0.18)
        shell.roughness = 0.6
        ball.material_override = shell
        ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(ball)
        var cap := MeshInstance3D.new()
        var cap_mesh := CylinderMesh.new()
        cap_mesh.top_radius = 0.03
        cap_mesh.bottom_radius = 0.03
        cap_mesh.height = 0.07
        cap.mesh = cap_mesh
        cap.position = Vector3(0.0, 0.11, 0.0)
        var cap_material := StandardMaterial3D.new()
        cap_material.albedo_color = Color(0.9, 0.7, 0.2)
        cap.material_override = cap_material
        cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(cap)
        return
    var body := MeshInstance3D.new()
    var tube := CylinderMesh.new()
    tube.top_radius = 0.07
    tube.bottom_radius = 0.07
    tube.height = 0.5
    tube.radial_segments = 8
    tube.rings = 1
    body.mesh = tube
    body.rotation_degrees = Vector3(90.0, 0.0, 0.0)
    var paint := StandardMaterial3D.new()
    paint.albedo_color = Color(0.82, 0.82, 0.78)
    paint.metallic = 0.4
    body.material_override = paint
    body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(body)
    var nose := MeshInstance3D.new()
    var cone := CylinderMesh.new()
    cone.top_radius = 0.0
    cone.bottom_radius = 0.07
    cone.height = 0.18
    cone.radial_segments = 8
    cone.rings = 1
    nose.mesh = cone
    nose.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
    nose.position = Vector3(0.0, 0.0, -0.34)
    var nose_material := StandardMaterial3D.new()
    nose_material.albedo_color = Color(0.9, 0.25, 0.18)
    nose.material_override = nose_material
    nose.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(nose)
    var flame := MeshInstance3D.new()
    var flame_mesh := SphereMesh.new()
    flame_mesh.radius = 0.09
    flame_mesh.height = 0.18
    flame_mesh.radial_segments = 6
    flame_mesh.rings = 3
    flame.mesh = flame_mesh
    flame.position = Vector3(0.0, 0.0, 0.28)
    var glow := StandardMaterial3D.new()
    glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    glow.albedo_color = Color(1.0, 0.65, 0.2)
    flame.material_override = glow
    flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(flame)

func _physics_process(delta: float) -> void:
    if _finished:
        return
    _age += delta
    velocity.y -= gravity * delta
    var from := global_position
    var to := from + velocity * delta
    var query := PhysicsRayQueryParameters3D.create(from, to, Teams.bullet_mask_for(team))
    query.exclude = _skip
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        global_position = to
    else:
        var point: Vector3 = hit["position"]
        var normal: Vector3 = hit["normal"]
        global_position = point
        if explode_on_impact:
            _explode()
            return
        velocity = velocity.bounce(normal) * 0.45
        if velocity.length() < 1.5:
            velocity = Vector3.ZERO
        global_position = point + normal * 0.06
    if kind == "rocket":
        if velocity.length() > 0.5 and absf(velocity.normalized().y) < 0.98:
            look_at(global_position + velocity, Vector3.UP)
        if fx != null:
            fx.tracer(from, global_position, Color(1.0, 0.6, 0.25, 0.9))
    if fuse > 0.0 and _age >= fuse:
        _explode()
    elif _age > MAX_AGE:
        queue_free()

func _explode() -> void:
    if _finished:
        return
    _finished = true
    var source: Node3D = shooter if is_instance_valid(shooter) else null
    Explosion.detonate(director, fx, global_position, blast_radius, blast_damage, team, source, knockback)
    if audio != null:
        audio.play_sfx("explosion", randf_range(0.92, 1.08), 2.0)
    queue_free()
