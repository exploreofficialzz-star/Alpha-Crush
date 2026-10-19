extends RefCounted
class_name TestWorldState

static func run() -> bool:
    var state = preload("res://world/world_state/world_state.gd").new()
    state.set_state("bridge", "COMPLETE")
    state.set_property("bridge", "level", 2)
    state.set_state("bridge", "UPGRADED")
    return state.is_complete("bridge") and state.get_state("bridge") == "UPGRADED" and int(state.get_property("bridge", "level", 0)) == 2
