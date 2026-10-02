extends Node
class_name WeatherManager

signal changed(weather: String)
var weather := "clear"
var timer := 0.0
var transition_seconds := 180.0
var forecast: Array[String] = ["clear", "cloudy", "rain"]

func _process(delta: float) -> void:
    timer += delta
    if timer < transition_seconds:
        return
    timer = 0.0
    var next: String = forecast[randi() % forecast.size()]
    if next != weather:
        weather = next
        changed.emit(weather)

func set_weather(value: String) -> void:
    if value not in forecast:
        return
    weather = value
    timer = 0.0
    changed.emit(weather)

func snapshot() -> Dictionary:
    return {"weather": weather, "timer": timer}

func restore(value: Dictionary) -> void:
    var restored := str(value.get("weather", "clear"))
    weather = restored if restored in forecast else "clear"
    timer = clampf(float(value.get("timer", 0.0)), 0.0, transition_seconds)
    changed.emit(weather)
