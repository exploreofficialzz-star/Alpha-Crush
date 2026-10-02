extends RefCounted
class_name TestWorldAuthority

static func run() -> bool:
    var state: WorldState = preload("res://world/world_state/world_state.gd").new()
    var authority: WorldAuthority = preload("res://multiplayer/authority/world_authority.gd").new()
    authority.configure(state)
    var valid := authority.commit("word_ladder", "COMPLETE")
    var invalid_object := authority.commit("admin_override", "COMPLETE")
    var invalid_state := authority.commit("word_orange", "UPGRADED")
    var duplicate := authority.commit("word_ladder", "COMPLETE")
    var result: bool = valid and state.is_complete("word_ladder") and not invalid_object and not invalid_state and not duplicate
    authority.free()
    state.free()
    return result
