# Alpha Crush — Game Design (Battle Edition 3.0)

> *Crush the opposition.* A stylised third-person action shooter for phones that fuses **gun play and kung-fu in one thumb**.
> No blood: knocked-out fighters fall over and vanish in a puff of stars.

## 1. Pillars

1. **One thumb fights, one thumb moves.** The right thumb drives a floating move stick. The left thumb owns the big ATTACK button
   and swipes to aim. Everything else is a big, picture-only button (the old game's rule: pictures before words).
2. **Smart Stance (the signature idea).** One ATTACK button, two games: with an enemy inside arm's reach it throws a four-hit
   kung-fu chain (punch, punch, kick, flying kick); at range it fires the equipped gun at the enemy the aim assist has locked.
   No weapon-switch fiddling in the middle of a brawl.
3. **CRUSH meter.** Every landed hit fills it (kung-fu fastest). A full meter unleashes a crush move that clears the crowd:
   QUAKE (ground slam), DRAGON KICK (dash + flying kick) or BULLET STORM (4 s of endless ammo and auto-aim).
4. **Fair crowds.** Only a few enemies may attack at once (attack tokens), every swing, grenade, slam and sniper shot is telegraphed,
   and shooters fire in bursts with pauses. A crowd can always be read and dodged.
5. **Perfect dodge = bullet time.** Getting "hit" during the roll's i-frames slows time for 1.3 s and gives crush energy.
6. **Big-game structure on a small screen.** Ranks, loadouts (two guns, fighting style, crush move, three killstreaks, outfit),
   killstreaks (Supply Drop, Air Strike, Guardian Drone), four modes, eight maps and a 26-operation campaign.

## 2. The campaign: ALPHA to ZULU

26 operations named with the NATO phonetic alphabet (the old game's A-Z identity lives on as the mission letters).
Operations rotate Team Crush / Last Stand / Domination; every fifth one (E, J, O, T, Y) and the finale Z is a **Commander Hunt**.
Threat rises from 100% (ALPHA) to 325% (ZULU). Stars: 1 for winning, +1 for losing at most one life, +1 for no lives lost with a
style combo of 9+. Completing an operation opens the next.

| Mode | Goal | Notes |
|---|---|---|
| Team Crush | Crush N opponents (18 + 2/op, capped at 60) | They keep arriving from their bases |
| Last Stand | Survive W waves (4 + op/4, capped at 10) | Supply pause between waves; heavies from wave 3 |
| Domination | First to 200 points | Hold flags A/B/C (1 point/s each); the enemy defends flags and gains 0.4/s |
| Commander Hunt | Defeat the boss | Reinforcements at 60% and 25% health; ground-slam telegraph |

## 3. Combat numbers

### Guns

| Gun | Kind | Rank | Price | Damage | Shots/s | Mag / reserve | Reload | Range | Notes |
|---|---|---|---|---|---|---|---|---|---|
| VIPER | pistol | 1 | 0 | 24.0 | 4.2 | 12 / 96 | 1.1s | 52.0 m |  |
| HORNET | smg | 2 | 400 | 11.0 | 12.0 | 32 / 192 | 1.5s | 40.0 m |  |
| FALCON | rifle | 4 | 900 | 21.0 | 8.0 | 30 / 180 | 1.9s | 75.0 m |  |
| BOOMER | shotgun | 6 | 1200 | 10.0 | 1.25 | 6 / 48 | 2.3s | 28.0 m | 9 pellets |
| EAGLE | sniper | 9 | 1800 | 120.0 | 0.85 | 5 / 30 | 2.5s | 140.0 m |  |
| BISON | lmg | 12 | 2400 | 16.0 | 10.0 | 75 / 300 | 3.6s | 70.0 m |  |
| COMET | launcher | 15 | 3200 | 150.0 | 0.6 | 1 / 9 | 2.6s | 120.0 m | rocket, blast 4.6 m |

Upgrades: 5 levels per gun, +8% damage and +10% magazine per level; cost = 120 x tier x (level + 1) coins.
Damage fades with distance between each gun's fall-off band down to 35%. Headshots do x1.6.

### Kung-fu chain (Smart Stance, enemy within 2.7 m)

| Hit | Move | Damage | Reach | Knock-back | Stun |
|---|---|---|---|---|---|
| 1 | Right punch | 14 | 2.2 m | 2.2 | 0.20 s |
| 2 | Left punch | 16 | 2.2 m | 2.2 | 0.20 s |
| 3 | Roundhouse kick | 24 | 2.5 m | 5.0 | 0.45 s |
| 4 | Flying kick | 42 | 3.0 m | 9.5 | 0.85 s |

Styles scale these: TIGER x1.25 kung-fu damage, CRANE x1.3 speed and x1.2 reach, HAWK x1.2 gun damage and faster reloads,
TURTLE +40 armour, +20% health. Hit-stop (35-90 ms) and screen shake make every hit land.

### Fighters

| Type | Role | Health | Armour | Speed | Weapon | Special | Score |
|---|---|---|---|---|---|---|---|
| GRUNT | gunner | 60.0 | 0.0 | 3.5 | falcon | - | 100 |
| RUSHER | melee | 55.0 | 0.0 | 5.6 | melee | - | 110 |
| BLASTER | gunner | 80.0 | 0.0 | 3.9 | boomer | - | 140 |
| SNIPER | gunner | 45.0 | 0.0 | 2.8 | eagle | - | 180 |
| HEAVY | gunner | 220.0 | 80.0 | 2.6 | bison | - | 320 |
| BOMBER | gunner | 70.0 | 0.0 | 3.6 | hornet | grenade | 200 |
| NINJA | melee | 85.0 | 0.0 | 6.2 | melee | dash | 220 |
| COMMANDER | gunner | 900.0 | 150.0 | 3.3 | falcon | slam | 1500 |
| ALLY (rifle) | gunner | 160.0 | 0.0 | 4.2 | falcon | - | 0 |
| ALLY (SMG) | gunner | 160.0 | 0.0 | 4.6 | hornet | - | 0 |

Enemy damage is scaled well below the player's guns (enemies are many). Four opposition sides tint their uniforms and favour
different mixes: IRON JACKALS (gunners), SHADOW FISTS (kung-fu rushers and ninjas), RED VIPERS (SMGs and bombers),
STEEL BULLS (armoured heavies).

### Maps

| Arena | Ground | Time of day | Weather |
|---|---|---|---|
| OLD FARMSTEAD | farmland | morning | clear |
| DUSTLINE | desert | noon | clear |
| FROSTGATE | snow | morning | cloudy |
| IRONWORKS | industrial | afternoon | cloudy |
| OLD TOWN | ruins | dusk | clear |
| GREENLINE | forest | afternoon | rain |
| HARBOR YARD | harbor | noon | cloudy |
| HIGH CAMP | highlands | dusk | clear |

Each map has a flat fighting floor ringed by hills, an ALPHA base with sandbag walls, 13-18 cover clusters (sandbags, shipping
containers, crates, explosive barrels, concrete barriers, ruined walls), real buildings from the old village and trees/rocks.
Layouts are seeded: the same operation always plays on the same map.

## 4. Controls

| Control | Action |
|---|---|
| Right thumb (floating stick) | Move |
| Swipe anywhere else | Look / aim |
| ATTACK (hold) | Kung-fu chain up close, gun at range (auto-aim locks the enemy nearest the crosshair) |
| DODGE | Roll with 0.42 s of i-frames; a "hit" during it triggers bullet time |
| JUMP, GRENADE, RELOAD, SWAP | As labelled by their icons |
| CRUSH | Glows when the meter is full |
| Streak buttons (top centre) | Light up after 3 / 5 / 7 kills in a row |

Settings: left-handed layout, Simple mode (the gun fires only at enemies you face) vs full manual, aim-assist strength,
camera sensitivity, bullet time on/off, damage numbers. Desktop keys for testing: WASD move, F attack, Space jump, Shift dodge,
R reload, Q swap, G grenade, C crush, 1-3 streaks, right-mouse-drag look, Esc pause.

## 5. Progression and economy

Rank 1-40 (RECRUIT to ALPHA LEGEND) from XP (kills, stars, style points). Rank unlocks the right to buy guns, styles, crush moves,
streaks and outfits with coins earned in battle. Coins also pay for gun upgrades. IAP packs and the ad-removal product are wired
through the existing, parent-gated purchase service.

## 6. Performance budget (low-end Android first)

* GL Compatibility renderer. No dynamic shadow-casting lights; muzzle/explosion lights are unshadowed, <= 3 alive, and off on
  low tiers. Particles are CPU particles with tiny counts.
* 4-10 active enemies depending on the graphics tier (5 on "lowest", 6 on "low").
* Pooled effects (flashes, tracers, impacts, numbers, rings, explosions), pooled audio voices, no per-shot allocation.
* Enemy AI thinks every 0.13 s (0.28 s when far); far enemies animate every third frame.
* Terrain: 56 x 56 cells (6 k triangles); far scenery uses one MultiMesh per model.
* The existing frame-rate governor and automatic quality tiers still apply.
