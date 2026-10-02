extends RefCounted
class_name TestWeatherManager

static func run() -> bool:
    var weather: WeatherManager = preload("res://world/weather/weather_manager.gd").new()
    var changes: Array[String] = []
    weather.changed.connect(func(value: String): changes.append(value))
    weather.set_weather("rain")
    var rain: bool = weather.weather == "rain" and changes == ["rain"]
    weather.set_weather("not_a_weather")
    var rejected: bool = weather.weather == "rain"
    var snapshot: Dictionary = weather.snapshot()
    var other: WeatherManager = preload("res://world/weather/weather_manager.gd").new()
    other.restore(snapshot)
    var restored: bool = other.weather == "rain"
    weather.free()
    other.free()
    return rain and rejected and restored
