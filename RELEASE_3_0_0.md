# Alpha Crush 3.0.0 — Battle Edition

The word-adventure game has been rebuilt as a **war / fighting game**: third-person gun play fused with kung-fu, Call-of-Duty-style
loadouts and killstreaks, four battle modes, eight maps and a 26-operation campaign (ALPHA to ZULU). The old game is archived
untouched in `legacy/word_adventure/` (a `.gdignore` keeps it out of the build). `GAME_DESIGN.md` has the full design and every
stat table.

## What is new

| Area | Highlights |
|---|---|
| Combat | Smart Stance (one ATTACK button: kung-fu chain up close, gun at range), aim assist with target-priority formula and lock hold, 7 guns with upgrades, grenades and rockets, headshots, damage fall-off, hit-stop, screen shake |
| CRUSH | Meter filled by hits; QUAKE, DRAGON KICK, BULLET STORM crush moves |
| Dodge | Roll with i-frames; "perfect dodge" triggers 1.3 s of bullet time |
| Enemies | 8 fighter types in 4 opposition sides; a boss with a telegraphed slam and reinforcements; squad-mates (BRAVO, CHARLIE) who fight beside you |
| Fairness | Attack tokens limit simultaneous attackers; every special is telegraphed; shooters fire in bursts |
| Modes | Team Crush, Last Stand (waves), Domination (flags), Commander Hunt (boss) |
| Maps | 8 seeded battlefields (farmstead, desert, snow, industrial, old town, forest, harbour, highlands) with cover, explosive barrels and breakable crates |
| Meta | Rank 1-40, coins, gun upgrades, fighting styles, outfits, three killstreaks (Supply Drop, Air Strike, Guardian Drone), stars per operation, results screen with rank-up banner |
| HUD | Thumb-first layout (move stick under the right thumb, mirrored for left-handed), radar, health/armour, objective + boss bar, kill feed, damage arrows, lock marker, announcer, picture-only first-battle coach |
| Audio | 37 new procedural sound effects, 3 music loops (menu, battle, boss), war-rumble ambience; pooled voices with distance attenuation |
| Safety | Everything from 2.3.0 stays: crash-loop guard / safe mode, staged loading, automatic quality tiers, frame-rate governor, parental gate, consent |

No blood or gore: defeated fighters fall over and vanish in a puff of stars.

## Controls (touch)

Right thumb: floating move stick. Left thumb: big ATTACK button (hold) and swipe-to-aim. DODGE, JUMP, CRUSH, GRENADE, RELOAD, SWAP and
three streak buttons are picture-only. Settings: left-handed layout, Simple mode, aim assist, bullet time, damage numbers.

## Code map (new / rewritten)

```
combat/      Teams, DamageInfo, ComboTracker, CrushMeter, AimAssist, CombatDirector (attack tokens), Explosion, LoadoutCatalog
weapons/     WeaponCatalog, WeaponController (ammo/reload/bloom), WeaponModel (procedural guns), Projectile (rockets, grenades)
fighters/    Fighter (shared body), PlayerFighter (Smart Stance, dodge, crush, camera), EnemyFighter (AI), EnemyCatalog
modes/       MatchDirector (rules of the 4 modes), OperationCatalog (A-Z), CaptureZone, Pickup, SupplyDrop, AirStrike, GuardianDrone
world/       BattleWorld (arena builder), ArenaCatalog, ArenaTerrain, props/BreakableProp
progression/ PlayerProgress (career, save snapshot)
vfx/         CombatFX (pooled effects, hit-stop, bullet time)
ui/battle/   BattleHUD, HudLayout (pure layout maths), RadarView, CrosshairView, DamageArrows, CrushRing, LockMarker
ui/menus/    MainMenu, ArmoryScreen, ResultScreen, MenuKit
core/main.gd New application root (boot -> menu -> battle lifecycle)
```

Reused unchanged from 2.x: BootGuard, DeviceProfile, QualityManager/AdaptiveQuality, TouchRouter + joystick + buttons + camera drag,
AvatarRig (extended with gun stance, punch, kick, hit, slam, cheer poses), terrain material/vegetation helpers, Atmosphere (sky, sun,
fog, weather), ads/consent/purchases services, SaveSystem (now save v14 with automatic migration from 2.x saves).

## Verification status — please read

**This environment has no Godot editor, so the game has never been launched.** What *was* verified:

* `python3 tools/gdlint/run_all.py` — the project's static checks (undefined calls, Variant inference, member/arity/signal checks,
  duplicate locals, missing returns) pass on all 100+ scripts, including the new code.
* `python3 tests/source_audit.py` (includes the asset audit) passes: no missing preloads or icons, spaces-only indentation,
  every test registered, versions synchronised (3.0.0 / code 18).
* Extra checks run for this release: bracket balance in every script, no duplicate `class_name`, no cyclic class dependencies,
  every signal-connection target exists, and a mirror of the HUD layout maths proves no two touch circles overlap and everything is
  on screen for 9 screen shapes x 3 safe-area sets x both hands.
* All new audio and icons were generated, checked for silence/NaN, and the icons were inspected visually.

What was **not** verified and needs a human with Godot 4.7:

1. `godot --headless --path . --editor --quit` (import + parse) and `--script res://tests/run_tests.gd` — 26 suites. 11 of them are
   new this release and test real code paths (fighter damage, attack tokens, progression, operations, layout, terrain winding).
   They were written but never executed; if one fails it is as likely a test mistake as a game bug.
2. The hero/enemy **poses** (gun stance, punch, kick, hit, slam) are procedural bone rotations tuned blind; expect to tweak angles.
3. **Balance and feel** (damage, enemy accuracy, aim-assist cone, hit-stop lengths) are first-pass numbers.
4. **Performance on a real low-end phone**; the budget in `GAME_DESIGN.md` is a plan, not a measurement.
5. Camera framing, HUD positions on a physical notch device, and audio mix.

### First-run checklist

1. `godot --headless --path . --import`, then open the project in Godot 4.7.x.
2. Run the test runner (above). Fix any red suite first.
3. Play ALPHA on desktop (keys listed in `GAME_DESIGN.md`) and check: hero spawns at the base facing the enemy arc, enemies arrive,
   ATTACK punches when close and shoots when far, DODGE rolls, CRUSH glows after ~12 hits, pause works, result screen appears.
4. On a phone: left- and right-handed layouts, safe-area margins, 30 fps on a low-end device, thermal behaviour over 10 minutes.

## Store, age rating and ads — decision needed

The 2.x game was built for pre-readers and ships with `GameConfig.CHILD_DIRECTED := true` (no personalised ads, parent gate on
purchases/links). The 3.0 game is a **stylised shooter**. This release deliberately leaves the flag as it was (it is the more
restrictive, safer setting), but the **store listing, target audience and content rating must be reviewed before release** — a
guns-and-fighting game generally cannot stay in a children's / Families programme. Decide the audience, complete the content-rating
questionnaire honestly (cartoon violence, no blood), then change the flag and the Data-safety answers together. The rewarded
"x2 coins" button only appears when the ad SDK is present **and** `CHILD_DIRECTED` is false.

## Migration from 2.x

Saves are migrated automatically (save v14): the combat career starts fresh, up to 1,500 coins from the old inventory become a
welcome bonus, and all word-game keys are dropped. Settings (sound, hero choice, quality) carry over.

## Known limitations / next steps

* No online multiplayer yet. The team model (`Teams`, `CombatDirector`) keeps it possible; the old LAN code is archived.
* Enemy AI strafes and uses attack tokens but does not yet seek cover; allies follow and shoot but cannot revive.
* One hero model scale (child, x1.2); an adult "veteran" outfit set and weapon skins are natural next steps.
* More crush moves, perks and attachments; daily challenges and a battle pass can reuse `PlayerProgress`.
