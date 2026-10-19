extends Node3D
class_name WordAssembly

signal completed(word: String)

func assemble(word: String, at_position: Vector3) -> void:
    var root := Node3D.new()
    root.name = "Assembly_%s_%d" % [word, Time.get_ticks_msec()]
    root.position = at_position
    add_child(root)
    for i in range(word.length()):
        var l := Label3D.new()
        l.text = word.substr(i, 1)
        l.font_size = 72
        l.outline_size = 14
        l.modulate = Color("#f4d35e")
        l.position = Vector3((i - (word.length() - 1) / 2.0) * 1.0, 0, 0)
        l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        root.add_child(l)
    var tween := create_tween()
    root.scale = Vector3.ONE * 0.25
    tween.tween_property(root, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_interval(1.5)
    tween.tween_property(root, "scale", Vector3.ONE * 1.25, 0.18)
    tween.tween_callback(root.queue_free)
    completed.emit(word)
