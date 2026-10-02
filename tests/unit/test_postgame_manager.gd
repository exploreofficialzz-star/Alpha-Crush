extends RefCounted
class_name TestPostgameManager

static func run() -> bool:
    var postgame: PostgameManager = preload("res://gameplay/campaign/postgame_manager.gd").new()
    var challenge: Dictionary = postgame.next_challenge()
    if challenge.is_empty() or postgame.active_id.is_empty():
        return false
    var completed: Dictionary = postgame.complete_word(str(challenge["word"]))
    if completed.is_empty() or postgame.active_id != "":
        return false
    # A word that is not the active challenge must not grant a reward.
    var second: Dictionary = postgame.next_challenge()
    var wrong_word := "FUTURE" if str(second["word"]) != "FUTURE" else "FOREST"
    return postgame.complete_word(wrong_word).is_empty()
