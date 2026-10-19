extends Node3D
class_name VFXManager

func burst(pos: Vector3) -> void:
    var particles := GPUParticles3D.new()
    particles.amount = 18
    particles.lifetime = 0.7
    particles.position = pos
    var process_material := ParticleProcessMaterial.new()
    process_material.direction = Vector3(0, 1, 0)
    process_material.initial_velocity_min = 1.5
    process_material.initial_velocity_max = 3.0
    process_material.gravity = Vector3(0, -3, 0)
    process_material.scale_min = 0.7
    process_material.scale_max = 1.2
    particles.process_material = process_material
    particles.one_shot = true
    particles.explosiveness = 0.85
    var quad := QuadMesh.new()
    quad.size = Vector2(0.12, 0.12)
    # Without a material the quads are lit, single-sided white cards that vanish edge-on.
    var spark := StandardMaterial3D.new()
    spark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    spark.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    spark.albedo_color = Color("#f4d35e")
    quad.material = spark
    particles.draw_pass_1 = quad
    add_child(particles)
    particles.emitting = true
    get_tree().create_timer(1.0).timeout.connect(particles.queue_free)
