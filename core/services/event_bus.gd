extends Node
class_name EventBus

signal toast(message: String)
signal discovery(id: String, title: String)
signal world_changed(object_id: String, state: String)
signal currency_changed(currency: String, amount: int)
signal objective_changed(objective_id: String)
signal network_status(online: bool)

func emit_toast(message: String) -> void: toast.emit(message)
