extends Node
class_name AudioManager

var players: Dictionary = {}
var enabled := true
var volume_db := -4.0
var music_volume_db := -10.0
var music_player: AudioStreamPlayer
var music_streams: Dictionary = {}

func _ready() -> void:
    for id in ["pickup", "word_complete", "unlock", "harvest", "market", "ui_click", "construction", "hint", "levelup", "footstep", "discovery"]:
        _register(id, "res://audio/sfx/%s.wav" % id)
    _register_music("village", "res://audio/music/village_theme.wav")
    _register_music("exploration", "res://audio/music/exploration_theme.wav")
    _register_music("discovery", "res://audio/music/discovery_theme.wav")
    music_player = AudioStreamPlayer.new()
    music_player.name = "MusicPlayer"
    music_player.volume_db = music_volume_db
    add_child(music_player)
    music_player.finished.connect(func():
        if music_player.stream:
            music_player.play()
    )

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

func play_sfx(id: String) -> void:
    if not enabled or not players.has(id):
        return
    var player := AudioStreamPlayer.new()
    player.stream = players[id]
    player.volume_db = volume_db
    add_child(player)
    player.play()
    player.finished.connect(player.queue_free)
