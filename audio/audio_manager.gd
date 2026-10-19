extends Node
class_name AudioManager

## Sound for the whole game. Effects play through a small pool of reusable voices (a firefight can fire a dozen shots a
## second, so nothing is created or freed per shot) and the same sound is rate-limited so layered gunfire never turns into
## a wall of noise. Music and ambience are looping beds that fade between scenes.
const SFX_IDS: Array[String] = [
    "ui_click", "ui_open", "ui_back", "unlock", "levelup", "pickup", "footstep", "footstep_grass_0", "footstep_grass_1", "footstep_grass_2",
    "gun_pistol", "gun_smg", "gun_rifle", "gun_shotgun", "gun_sniper", "gun_lmg", "gun_launcher",
    "reload_mag", "reload_done", "punch_light", "kick_hit", "whoosh", "hit_flesh", "hit_marker", "hit_kill",
    "explosion", "grenade_pin", "dodge_roll", "crush_ready", "crush_quake", "crush_dragon", "crush_storm", "crush_slam",
    "pickup_ammo", "pickup_health", "pickup_coin", "streak_ready", "streak_use", "airstrike_whistle", "alarm_warning",
    "victory_fanfare", "defeat_sting", "countdown_tick", "capture_done", "wave_start"
]
const MUSIC := {
    "menu": "res://audio/music/menu_theme.wav",
    "battle": "res://audio/music/battle_loop.wav",
    "boss": "res://audio/music/boss_loop.wav"
}
const AMBIENCE := {
    "day": "res://audio/ambience/day_wind_birds.wav", "night": "res://audio/ambience/night_crickets.wav",
    "rain": "res://audio/ambience/rain.wav", "war": "res://audio/ambience/war_rumble.wav"
}
const AMBIENCE_LEVEL := {"day": 0.5, "night": 0.45, "rain": 0.8, "war": 0.55}
const VOICES := 20
const SAME_SOUND_GAP_MSEC := 35

var players: Dictionary = {}
var enabled := true
var volume_db := -4.0
var music_volume_db := -12.0
var music_player: AudioStreamPlayer
var music_streams: Dictionary = {}
var ambience_players: Dictionary = {}

var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _last_played: Dictionary = {}
var _music_id := ""
var _music_tween: Tween = null

func _ready() -> void:
    # Keep playing while the game is paused so menu taps and the pause screen still click.
    process_mode = Node.PROCESS_MODE_ALWAYS
    for id in SFX_IDS:
        _register(id, "res://audio/sfx/%s.wav" % id)
    for id in MUSIC.keys():
        _register_music(str(id), str(MUSIC[id]))
    for id in AMBIENCE.keys():
        _make_ambience(str(id), str(AMBIENCE[id]))
    for i in VOICES:
        var voice := AudioStreamPlayer.new()
        voice.name = "Voice%d" % i
        add_child(voice)
        _voices.append(voice)
    music_player = AudioStreamPlayer.new()
    music_player.name = "MusicPlayer"
    music_player.volume_db = music_volume_db
    add_child(music_player)

func _load_stream(path: String) -> AudioStream:
    if not ResourceLoader.exists(path):
        return null
    return load(path) as AudioStream

func _loop(stream: AudioStream) -> void:
    var wav := stream as AudioStreamWAV
    if wav != null:
        wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
        wav.loop_begin = 0
        wav.loop_end = int(wav.get_length() * float(wav.mix_rate))

func _make_ambience(id: String, path: String) -> void:
    var stream := _load_stream(path)
    if stream == null:
        return
    _loop(stream)
    var player := AudioStreamPlayer.new()
    player.name = "Ambience_" + id
    player.stream = stream
    player.volume_db = -80.0
    add_child(player)
    player.play()
    ambience_players[id] = player

## Called every frame by Atmosphere: fades the day / night / rain beds with time of day and weather. The "war" rumble always
## runs softly underneath. (river_closeness is kept in the signature for Atmosphere but there is no river in a battle.)
func update_ambience(daylight: float, raining: bool, _river_closeness: float, delta: float) -> void:
    var rain_amount := 1.0 if raining else 0.0
    var targets := {
        "day": daylight * (1.0 - rain_amount * 0.75),
        "night": (1.0 - daylight) * (1.0 - rain_amount * 0.8),
        "rain": rain_amount,
        "war": 1.0
    }
    for id in ambience_players.keys():
        var player: AudioStreamPlayer = ambience_players[id]
        var amount := float(targets.get(id, 0.0)) * float(AMBIENCE_LEVEL.get(id, 0.6)) if enabled else 0.0
        var target_db := -80.0 if amount < 0.002 else linear_to_db(amount) - 6.0
        player.volume_db = lerpf(player.volume_db, target_db, minf(1.0, delta * 1.5))

func play_footstep(surface: String = "grass") -> void:
    var id := "footstep_%s_%d" % [surface, randi() % 3]
    if not players.has(id):
        id = "footstep"
    play_sfx(id, randf_range(0.9, 1.1), -5.0)

func _register_music(id: String, path: String) -> void:
    var stream := _load_stream(path)
    if stream != null:
        _loop(stream)
        music_streams[id] = stream

func set_music_enabled(value: bool) -> void:
    if music_player != null:
        music_player.stream_paused = not value

func play_music(id: String) -> void:
    if not music_streams.has(id) or music_player == null:
        return
    if _music_id == id and music_player.playing:
        return
    _music_id = id
    if _music_tween != null and _music_tween.is_valid():
        _music_tween.kill()
    music_player.stream = music_streams[id]
    music_player.volume_db = -40.0
    music_player.play()
    _music_tween = create_tween()
    _music_tween.tween_property(music_player, "volume_db", music_volume_db, 1.2)

func stop_music() -> void:
    _music_id = ""
    if _music_tween != null and _music_tween.is_valid():
        _music_tween.kill()
    if music_player != null:
        music_player.stop()

func _register(id: String, path: String) -> void:
    var stream := _load_stream(path)
    if stream != null:
        players[id] = stream

## `pitch` 1.0 is normal; `db_offset` is added to the master effects volume (negative = quieter, used for distance).
func play_sfx(id: String, pitch: float = 1.0, db_offset: float = 0.0) -> void:
    if not enabled or not players.has(id) or _voices.is_empty():
        return
    var now := Time.get_ticks_msec()
    if now - int(_last_played.get(id, -1000)) < SAME_SOUND_GAP_MSEC:
        return
    _last_played[id] = now
    var voice := _voices[_next_voice]
    _next_voice = (_next_voice + 1) % _voices.size()
    voice.stop()
    voice.stream = players[id]
    voice.volume_db = volume_db + db_offset
    voice.pitch_scale = pitch
    voice.play()
