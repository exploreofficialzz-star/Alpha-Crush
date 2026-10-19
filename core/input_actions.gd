extends RefCounted
class_name InputActions

## Keyboard shortcuts so the game can be tried on a computer. On phones everything comes from the on-screen controls, so
## these only matter for desktop testing. Safe to call any number of times.
const ACTIONS := {
    "move_forward": [KEY_W, KEY_UP],
    "move_back": [KEY_S, KEY_DOWN],
    "move_left": [KEY_A, KEY_LEFT],
    "move_right": [KEY_D, KEY_RIGHT],
    "attack": [KEY_F, KEY_J],
    "jump": [KEY_SPACE],
    "dodge": [KEY_SHIFT, KEY_K],
    "reload": [KEY_R],
    "swap": [KEY_Q],
    "grenade": [KEY_G],
    "crush": [KEY_C, KEY_E],
    "streak_1": [KEY_1],
    "streak_2": [KEY_2],
    "streak_3": [KEY_3],
    "pause": [KEY_ESCAPE, KEY_P]
}

static func ensure() -> void:
    for action in ACTIONS.keys():
        var action_name := str(action)
        if not InputMap.has_action(action_name):
            InputMap.add_action(action_name)
        for code in ACTIONS[action]:
            var event := InputEventKey.new()
            event.physical_keycode = code
            if not InputMap.action_has_event(action_name, event):
                InputMap.action_add_event(action_name, event)
