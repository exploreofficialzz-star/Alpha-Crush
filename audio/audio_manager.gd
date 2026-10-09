extends Node
class_name AudioManager

var players: Dictionary = {}
var enabled := true
var volume_db := -4.0
var music_volume_db := -10.0
var music_player: AudioStreamPlayer
var music_streams: Dictionary = {}
var ambience_players: Dictionary = {}

const AMBIENCE := {
    "day": "res://audio/ambience/day_wind_birds.wav", "night": "res://audio/ambience/night_crickets.wav",
    "river": "res://audio/ambience/river.wav", "rain": "res://audio/ambience/rain.wav"
}
const AMBIENCE_LEVEL := {"day": 0.75, "night": 0.6, "river": 0.9, "rain": 0.8}

func _ready() -> void:
    for id in ["pickup", "word_complete", "unlock", "harvest", "market", "ui_click", "construction", "hint", "levelup", "footstep", "discovery", "footstep_grass_0", "footstep_grass_1", "footstep_grass_2"]:
        _register(id, "res://audio/sfx/%s.wav" % id)
    _register_music("village", "res://audio/music/village_theme.wav")
    _register_music("exploration", "res://audio/music/exploration_theme.wav")
    _register_music("discovery", "res://audio/music/discovery_theme.wav")
    for id in AMBIENCE.keys():
        _make_ambience(str(id), str(AMBIENCE[id]))
    music_player = AudioStreamPlayer.new()
    music_player.name = "MusicPlayer"
    music_player.volume_db = music_volume_db
    add_child(music_player)
    music_player.finished.connect(func():
        if music_player.stream:
            music_player.play()
    )

func _make_ambience(id: String, path: String) -> void:
    var stream := load(path) as AudioStream
    if stream == null:
        return
    var wav := stream as AudioStreamWAV
    if wav != null:
        wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
        wav.loop_begin = 0
        wav.loop_end = int(wav.get_length() * float(wav.mix_rate))
    var player := AudioStreamPlayer.new()
    player.name = "Ambience_" + id
    player.stream = stream
    player.volume_db = -80.0
    add_child(player)
    player.play()
    if wav == null:
        player.finished.connect(player.play)
    ambience_players[id] = player

## Called every frame by Atmosphere: fades the day/night/river/rain beds with time of day, weather and position.
func update_ambience(daylight: float, raining: bool, river_closeness: float, delta: float) -> void:
    var rain_amount := 1.0 if raining else 0.0
    var targets := {
        "day": daylight * (1.0 - rain_amount * 0.75),
        "night": (1.0 - daylight) * (1.0 - rain_amount * 0.8),
        "river": clampf(river_closeness, 0.0, 1.0),
        "rain": rain_amount,
    }
    for id in ambience_players.keys():
        var player: AudioStreamPlayer = ambience_players[id]
        var amount := float(targets.get(id, 0.0)) * float(AMBIENCE_LEVEL.get(id, 0.7)) if enabled else 0.0
        var target_db := -80.0 if amount < 0.002 else linear_to_db(amount) - 6.0
        player.volume_db = lerpf(player.volume_db, target_db, minf(1.0, delta * 1.5))

func play_footstep(surface: String = "grass") -> void:
    var id := "footstep_%s_%d" % [surface, randi() % 3]
    if not players.has(id):
        id = "footstep"
    play_sfx(id, randf_range(0.9, 1.1), -5.0)

func _register_music(id: String, path: String) -> void:
    var stream = load(path)
    if stream:
        music_streams[id] = stream

func set_music_enabled(value: bool) -> void:
    if music_player:
        music_player.stream_paused = not value

func play_music(id: String) -> void:
    if not music_streams.has(id) or music_player == null:
        return
    if music_player.stream == music_streams[id] and music_player.playing:
        return
    music_player.stream = music_streams[id]
    music_player.play()

func _register(id: String, path: String) -> void:
    var stream = load(path)
    if stream == null:
        return
    players[id] = stream

func play_sfx(id: String, pitch: float = 1.0, db_offset: float = 0.0) -> void:
    if not enabled or not players.has(id):
        return
    var player := AudioStreamPlayer.new()
    player.stream = players[id]
    player.volume_db = volume_db + db_offset
    player.pitch_scale = pitch
    add_child(player)
    player.play()
    player.finished.connect(player.queue_free)
