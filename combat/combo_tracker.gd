extends RefCounted
class_name ComboTracker

## Counts back-to-back hits and turns them into a style rank (D..SS) and a score multiplier.
## Landing a hit within TIMEOUT seconds of the last one keeps the chain alive; getting hit or waiting breaks it.
signal rank_changed(rank: String)
signal chain_broken(final_count: int)

const RANKS: Array[String] = ["D", "C", "B", "A", "S", "SS"]
const THRESHOLDS: Array[int] = [0, 4, 9, 16, 26, 40]
const MULTIPLIERS: Array[float] = [1.0, 1.15, 1.3, 1.5, 1.8, 2.2]
const TIMEOUT := 3.2

var count := 0
var best := 0
var points := 0
var timer := 0.0
var _last_rank := 0

## Registers a landed hit and returns the style points it earned (already multiplied by the current rank).
func hit(base_points: int = 10) -> int:
    count += 1
    best = maxi(best, count)
    timer = TIMEOUT
    var earned := int(round(float(base_points) * multiplier()))
    points += earned
    var now := rank_index()
    if now != _last_rank:
        _last_rank = now
        rank_changed.emit(RANKS[now])
    return earned

func tick(delta: float) -> void:
    if count <= 0:
        return
    timer -= delta
    if timer <= 0.0:
        reset()

func reset() -> void:
    if count > 0:
        chain_broken.emit(count)
    count = 0
    timer = 0.0
    if _last_rank != 0:
        _last_rank = 0
        rank_changed.emit(RANKS[0])

func rank_index() -> int:
    var index := 0
    for i in THRESHOLDS.size():
        if count >= THRESHOLDS[i]:
            index = i
    return index

func rank() -> String:
    return RANKS[rank_index()]

func multiplier() -> float:
    return MULTIPLIERS[rank_index()]

## 1.0 right after a hit, falling to 0.0 as the chain is about to break (drives the HUD bar).
func time_fraction() -> float:
    if count <= 0:
        return 0.0
    return clampf(timer / TIMEOUT, 0.0, 1.0)
