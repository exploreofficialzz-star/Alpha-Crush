extends RefCounted
class_name TestDailyManager

static func run() -> bool:
    var daily = preload("res://gameplay/daily/daily_manager.gd").new()
    daily.refresh("2099-01-01")
    daily.progress("daily_harvest", 5)
    return daily.completed("daily_harvest")
