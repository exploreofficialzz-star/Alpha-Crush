extends RefCounted
class_name TestSeedDeterminism

static func run() -> bool:
    var gen = preload("res://world/generation/seeded_generator.gd").new(482913)
    var a = gen.rng_for(3, -2).randi()
    var b = gen.rng_for(3, -2).randi()
    return a == b and gen.region_for(0, 0) == gen.region_for(0, 0)
