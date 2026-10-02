extends RefCounted
class_name SeededGenerator

var seed_value: int
const REGION_TYPES := ["starter_village", "forest", "orchard", "riverlands", "farmland", "caves", "coastal_town", "mountain", "beach", "desert", "snow", "wetlands", "canyon", "ruins", "industrial", "futuristic_city", "harbor", "highlands"]

func _init(seed_number: int = 482913) -> void:
    seed_value = seed_number

func rng_for(cx: int, cz: int) -> RandomNumberGenerator:
    var r := RandomNumberGenerator.new()
    r.seed = int(seed_value) ^ int(cx * 73856093) ^ int(cz * 19349663)
    return r

func region_for(cx: int, cz: int) -> String:
    var hash_value: int = absi((cx + 17) * 31 + (cz - 11) * 17 + seed_value)
    return str(REGION_TYPES[hash_value % REGION_TYPES.size()])

func height_at(x: float, z: float) -> float:
    return sin((x + seed_value) * 0.01) * 0.7 + cos((z - seed_value) * 0.008) * 0.55
