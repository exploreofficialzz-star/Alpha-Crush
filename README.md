# Alpha Crush — Battle Edition (Godot 4.7, Android-first)

**Crush the opposition.** A stylised third-person action shooter for phones where **one button is both a gun and a kung-fu chain**:
up close it punches and kicks, at range it fires at the enemy you are facing. Fill the CRUSH meter, roll through bullets for bullet
time, call in killstreaks, and fight your way from operation ALPHA to ZULU.

* 4 modes: Team Crush, Last Stand (waves), Domination (flags), Commander Hunt (boss)
* 26 campaign operations on 8 seeded maps, plus Quick Battle
* 7 guns with upgrades, 4 fighting styles, 3 crush moves, 3 killstreaks, outfits, rank 1-40
* Squad-mates, 8 enemy types in 4 opposition sides, fair-fight attack tokens, telegraphed specials
* No blood: defeated fighters are knocked out in a puff of stars
* Low-end-phone friendly: GL Compatibility renderer, pooled effects, automatic quality tiers, crash-loop safe mode

Start with **`GAME_DESIGN.md`** (design + every stat table) and **`RELEASE_3_0_0.md`** (what changed, what is verified and what is
not, first-run checklist, store/age-rating decision).

## Layout

| Folder | Contents |
|---|---|
| `core/` | `main.gd` application root, boot guard, device profile, save system, configuration |
| `combat/` `weapons/` `fighters/` | the battle engine: teams, damage, aim assist, attack tokens, guns, player controller, enemy AI |
| `modes/` | match rules for the four modes, the A-Z operation catalog, flags, pickups, killstreaks |
| `world/` | battlefield builder, arena catalog, terrain, breakable props |
| `progression/` | `PlayerProgress` (rank, coins, loadout, stars) |
| `ui/` | battle HUD (`ui/battle`), menus (`ui/menus`), touch controls (`ui/mobile`), settings, theme |
| `vfx/` `audio/` `visuals/` | pooled combat effects, sound, avatar rig / materials / sky |
| `ads/` `economy/` `analytics/` `security/` | consent-aware ads, parent-gated purchases, analytics boundary |
| `tests/` `tools/` | unit suites, Python audits, static GDScript lint, procedural asset generators |
| `legacy/word_adventure/` | the archived 2.x word game (ignored by Godot) |

## Working with the project

```bash
godot --headless --path . --import                         # first run on a fresh clone
godot --headless --path . --script res://tests/run_tests.gd   # 26 unit/integration suites
python3 tests/source_audit.py                              # source + asset audit
python3 tools/gdlint/run_all.py                            # project's static GDScript checks
python3 tools/assetgen/build_combat_audio.py               # regenerate combat sound + music
python3 tools/assetgen/build_combat_icons.py               # regenerate combat icons
python3 tools/assetgen/write_combat_imports.py             # .import sidecars for the generated assets
```

Desktop keys for testing: WASD move, F attack, Space jump, Shift dodge, R reload, Q swap, G grenade, C crush, 1-3 streaks,
right-mouse-drag to look, Esc to pause.

## Honest status

The project was written and statically checked without a Godot runtime. It has **not been launched yet**; see the verification
section of `RELEASE_3_0_0.md` before trusting any behaviour, and run the first-run checklist there. `ASSET_PIPELINE.md` describes how
the procedural art and audio are produced and their limits.
