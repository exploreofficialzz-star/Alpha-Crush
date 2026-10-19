extends Node
class_name ProgressionManager

signal changed(level: int, xp: int)
var xp := 0
var level := 1

func grant(value: int) -> void:
    if value <= 0:
        return
    xp += value
    while xp >= level * 100:
        xp -= level * 100
        level += 1
    changed.emit(level, xp)

func restore(value: Dictionary) -> void:
    level = maxi(1, int(value.get("level", 1)))
    xp = maxi(0, int(value.get("xp", 0)))
    changed.emit(level, xp)
