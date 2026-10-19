extends RefCounted
class_name TestSupport

## Tiny helpers so a failing suite says WHICH check failed (the runner only prints PASS / FAIL per suite).
static func expect(condition: bool, label: String) -> bool:
    if not condition:
        print("    FAIL: " + label)
    return condition

static func approx(a: float, b: float, tolerance: float = 0.001) -> bool:
    return absf(a - b) <= tolerance

static func tree_root() -> Node:
    return (Engine.get_main_loop() as SceneTree).root
