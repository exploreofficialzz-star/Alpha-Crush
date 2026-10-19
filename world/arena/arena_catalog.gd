extends RefCounted
class_name ArenaCatalog

## The eight battlefields. `region` picks the ground look (see Vegetation.PROFILES), `time` is the fraction of the day-night
## cycle the fight is frozen at (0.30 morning, 0.45 noon, 0.62 afternoon, 0.80 dusk), `cluster_mix` weights the kinds of cover.
const ORDER: Array[String] = ["farmstead", "dustline", "frostgate", "ironworks", "oldtown", "greenline", "harbor_yard", "highcamp"]

const ARENAS := {
    "farmstead": {"name": "OLD FARMSTEAD", "region": "farmland", "time": 0.32, "weather": "clear", "hills": 5.0, "clusters": 15,
        "trees": 22, "woods": ["oak"], "rocks": 8, "buildings": ["house_cottage", "storage_hut", "workshop_shed"], "building_count": 3,
        "cluster_mix": {"sandbag": 3, "crate": 3, "barrel": 2, "barrier": 1, "container": 1, "ruin": 1}},
    "dustline": {"name": "DUSTLINE", "region": "desert", "time": 0.45, "weather": "clear", "hills": 7.0, "clusters": 16,
        "trees": 0, "woods": [], "rocks": 20, "buildings": ["storage_hut", "workshop_shed"], "building_count": 2,
        "cluster_mix": {"sandbag": 3, "crate": 2, "barrel": 2, "barrier": 2, "container": 2, "ruin": 2}},
    "frostgate": {"name": "FROSTGATE", "region": "snow", "time": 0.27, "weather": "cloudy", "hills": 8.0, "clusters": 14,
        "trees": 22, "woods": ["pine"], "rocks": 12, "buildings": ["storage_hut", "house_cottage"], "building_count": 2,
        "cluster_mix": {"sandbag": 2, "crate": 3, "barrel": 2, "barrier": 2, "container": 2, "ruin": 1}},
    "ironworks": {"name": "IRONWORKS", "region": "industrial", "time": 0.55, "weather": "cloudy", "hills": 3.0, "clusters": 18,
        "trees": 4, "woods": ["oak"], "rocks": 6, "buildings": ["workshop_shed", "community_hall"], "building_count": 2,
        "cluster_mix": {"container": 5, "barrel": 3, "crate": 3, "barrier": 2, "sandbag": 1, "ruin": 0}},
    "oldtown": {"name": "OLD TOWN", "region": "ruins", "time": 0.80, "weather": "clear", "hills": 4.0, "clusters": 14,
        "trees": 8, "woods": ["oak"], "rocks": 10, "buildings": ["market_hall", "community_hall", "house_cottage"], "building_count": 3,
        "cluster_mix": {"ruin": 5, "crate": 2, "barrel": 2, "sandbag": 2, "barrier": 1, "container": 0}},
    "greenline": {"name": "GREENLINE", "region": "forest", "time": 0.62, "weather": "rain", "hills": 6.0, "clusters": 13,
        "trees": 46, "woods": ["oak", "pine"], "rocks": 10, "buildings": ["storage_hut"], "building_count": 1,
        "cluster_mix": {"sandbag": 3, "crate": 3, "barrel": 2, "barrier": 1, "container": 1, "ruin": 1}},
    "harbor_yard": {"name": "HARBOR YARD", "region": "harbor", "time": 0.50, "weather": "cloudy", "hills": 3.0, "clusters": 17,
        "trees": 3, "woods": ["oak"], "rocks": 8, "buildings": ["storage_hut", "workshop_shed"], "building_count": 2,
        "cluster_mix": {"container": 4, "crate": 4, "barrel": 3, "barrier": 1, "sandbag": 1, "ruin": 0}},
    "highcamp": {"name": "HIGH CAMP", "region": "highlands", "time": 0.74, "weather": "clear", "hills": 9.0, "clusters": 14,
        "trees": 20, "woods": ["pine", "oak"], "rocks": 14, "buildings": ["storage_hut", "house_cottage"], "building_count": 2,
        "cluster_mix": {"sandbag": 3, "crate": 2, "barrel": 2, "barrier": 2, "container": 1, "ruin": 2}}
}

static func arena(id: String) -> Dictionary:
    return ARENAS.get(id, ARENAS["farmstead"])

static func arena_name(id: String) -> String:
    return str(arena(id).get("name", "ARENA"))

static func is_valid(id: String) -> bool:
    return ARENAS.has(id)

## Weighted pick of a cover kind for a 0..1 roll (deterministic, so tests and seeded layouts agree).
static func pick_cluster(id: String, roll: float) -> String:
    var mix: Dictionary = arena(id).get("cluster_mix", {})
    var total := 0.0
    for kind in mix.keys():
        total += float(mix[kind])
    if total <= 0.0:
        return "crate"
    var cursor := clampf(roll, 0.0, 0.9999) * total
    for kind in mix.keys():
        cursor -= float(mix[kind])
        if cursor < 0.0:
            return str(kind)
    return "crate"
