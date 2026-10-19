extends RefCounted
class_name Teams

## Two sides fight in every match: ALPHA (the player's squad) and OPPOSITION (whoever must be crushed).
## Physics layers are fixed here so bullets, bodies and pickups never have to guess who they may touch.
const ALPHA := 0
const OPPOSITION := 1

const LAYER_WORLD := 1
const LAYER_ALPHA := 2
const LAYER_OPPOSITION := 4
const LAYER_BREAKABLE := 8
const LAYER_PICKUP := 16

static func layer_for(team: int) -> int:
    return LAYER_ALPHA if team == ALPHA else LAYER_OPPOSITION

static func hostile_of(team: int) -> int:
    return OPPOSITION if team == ALPHA else ALPHA

## What a fighter physically bumps into: the ground, props and every fighter (bodies never overlap).
static func body_mask() -> int:
    return LAYER_WORLD | LAYER_ALPHA | LAYER_OPPOSITION | LAYER_BREAKABLE

## What a bullet fired by `team` can hit: the ground, breakable props and the hostile side only.
static func bullet_mask_for(team: int) -> int:
    return LAYER_WORLD | LAYER_BREAKABLE | layer_for(hostile_of(team))

static func name_of(team: int) -> String:
    return "ALPHA" if team == ALPHA else "OPPOSITION"
