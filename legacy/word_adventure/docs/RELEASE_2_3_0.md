# Alpha Crush 2.3.0 — Crash-proof start-up and real human characters

This release answers two reports about 2.2.0:

1. **"The game crashes after I choose boy or girl."**
2. **"The boy and girl avatars are not built like real humans, and the other assets should look real too."**

> **Honest scope note.** No Godot engine, Android device or emulator was available while this was written, exactly like
> every earlier pass on this repository. Everything below was verified by reading and tracing the code, by the
> project's own static checkers (`tools/gdlint`, `tests/source_audit.py`, `tests/asset_audit.py`), by running the new
> asset pipeline and by offline renders of the generated models. The first thing to do with this build is the
> **device checklist at the end of this file**, and if the crash still happens, read the boot log (below) — it now says
> exactly which start-up step was running.

---------------------------------------------------------------------------------------------------------------------

## 1. The crash after choosing boy / girl

### What I could and could not establish
I traced everything that runs between the tap on the green play button and the first frame of the village
(`core/main.gd` → player → atmosphere → world → HUD → tutorial → `_finish_splash`). The static checkers pass, and I found
**no single line that is certain to abort the app**. What I did find is a set of conditions that — on a low-end phone,
for a first-time player only — can end in a hard kill or a start-up that silently never finishes:

| # | Finding in 2.2.0 | Why it matches the symptom |
|---|---|---|
| 1 | The character-select screen kept **two live 3D viewports** (each with its own world, light and a full avatar rig) alive, rendering every frame, *while* the whole village was built in the same frame. | Peak memory and GPU load are highest exactly at the transition; it only happens on the first run (returning players skip the screen). |
| 2 | The whole village (terrain, ~hundreds of GLB props, NPCs with full avatar rigs, animals, vegetation) was built **synchronously in one frame** inside `World._ready()`. | Multi-second frame stalls; low-end devices may be killed by the OS or the GPU watchdog. |
| 3 | The avatar was built **twice** on a new game: first as the default male, then thrown away and rebuilt as the chosen gender (`set_body_type` → `rig.free()`). | Doubles the heaviest object build, and `free()` on a live node is the riskiest call in the sequence. |
| 4 | The avatar used a **custom spatial shader** (`avatar.gdshader`) that reads `COLOR`/`UV` as region masks. A shader that fails to compile on one GPU driver is a classic cause of "crash/black screen at first draw". | The hero is first drawn in the world right after the choice. |
| 5 | Any **script error** inside the long start-up coroutine ends it silently, leaving the splash screen up for ever. In a release build that looks exactly like a crash. | There was no timeout, no log and no way to recover. |
| 6 | Procedural props could start streaming before the village had registered its buildings. | Not a crash, but props could spawn inside houses. |
| 7 | `ui_open` sound effect was requested by the HUD but never registered. | Silent failure only. |
| 8 | Camera `near=0.05` / `far=3200` gives a poor depth ratio on 16-bit depth buffers. | Z-fighting on cheap GPUs. |

### What changed
* **`core/boot_guard.gd` (new)** — every start-up stage is written to `user://boot_state.cfg` *before* it runs and
  appended to `user://boot_log.txt`. If the next launch finds a start-up that never finished, the game enters
  **safe mode**: lowest graphics tier, no animals, and a friendly message. A clean start clears the flag, and waiting
  on the character-select screen is a *resting point* that never counts as a crash. (`tests/unit/test_boot_guard.gd`)
* **Start-up watchdog** (`core/main.gd`): after 40 s the splash tells the player what to do; after 80 s it shows whatever
  has been built instead of an endless splash.
* **Character select without 3D**: the cards now show pre-rendered portraits of the real models
  (`assets/ui/portraits/boy.png`, `girl.png`) — no extra viewports, worlds or rigs at the dangerous moment.
* **The hero is built once, as the chosen character** (`player.body_type` is set before the node enters the tree).
  `set_body_type` (settings toggle) now builds the replacement first and releases the old rig with `queue_free`.
* **The world builds over several frames** (`World._ready` is now a coroutine with `built` / `build_finished`); main
  waits for it. The chunk streamer is paused until the village exists.
* **No custom avatar shader any more** — avatars use `StandardMaterial3D`, which every GPU/driver path in Godot has
  exercised. `avatar.gdshader` and `MaterialLibrary.make_avatar_material` were removed.
* Camera `near` 0.15; `ui_open` registered.
* New tests: `tests/unit/test_avatar_rig.gd`, `tests/unit/test_boot_guard.gd`.

### If it still crashes
Open the app once, let it fail, then read **`boot_log.txt`** and **`boot_state.cfg`** from the app's `user://` folder
(on Android normally `Android/data/com.chastechgroup.alphacrush/files/`). The last `stage ...` line is the step that
was running. Please send me that file — it turns a guess into a one-line fix.

---------------------------------------------------------------------------------------------------------------------

## 2. Human characters

The old avatar was a mannequin of ~20 rigid, ball-jointed pieces with a stylised, texture-less shader (the "male" even
had a bust). It was replaced by a proper pipeline:

* **Four skinned characters**: `avatar_boy`, `avatar_girl` (the playable children, ~1.3 m before the 1.2× hero
  scale) and `avatar_man`, `avatar_woman` (the villagers). One continuous skin, 16-bone skeleton (+ a ponytail bone
  for the girl), smooth joint weights, ~15–18k triangles each, 8 material slots.
* **Anatomy**: built from anthropometric landmarks (stature, shoulder/hip breadth, limb segment lengths, head
  height/breadth/depth) as a signed-distance model, then meshed at 4–6 mm and reduced with a quadric-error
  decimator that deliberately keeps faces, ears and hands detailed (`tools/assetgen/humanlib.py`).
* **Faces**: sculpted brow, nose bridge/tip/nostrils, lips with a mouth seam, ears with a hollow, chin, eyelids with an
  almond opening, and **real eyeballs** (iris, pupil, catch-light, shadowed sclera). A painted face map adds brows,
  lashes, lid creases, blush, freckles/stubble and lips that stay correct for every skin tone because the
  textures are neutral multipliers tinted by the game.
* **Hair**: sculpted shells with an irregular hairline and a strand texture (short, side-part, bob, ponytail that
  swings while running).
* **Clothes**: real garments with thickness, hems, cuffs, collar scoop, folds; sneakers with soles.
* **Hands** with separated fingers and thumb, relaxed pose.
* **Baked ambient occlusion** in vertex colours (contact shadows in armpits, under the chin, between fingers).
* **Animation** (`visuals/avatar_rig.gd`) drives the skeleton: breathing, walk/run, jump, carrying, reach.
* Regenerate everything with `python3 tools/assetgen/build_humans.py boy girl man woman` (≈5 min per character on one core).

### Limits (please read)
These are **good stylised-realistic game characters, not photo-real people**. They are procedural, have no
facial animation (no blinking or speech), simple hair (no individual strands/alpha cards) and one outfit per
character plus recolouring. Getting closer to "exactly human" means hand-sculpted/scan-based assets or a character
creator licence — it cannot be done honestly with a procedural generator. The numbers I can vouch for are in
`tests/asset_audit.py` (budgets, bones, materials, textures) and the renders in `docs/previews/`.

### Other assets
The world assets (buildings, trees, props, animals) were **not** rebuilt in this pass; the realism work for them is
still the 2.1.0 procedural PBR set (see `ASSET_PIPELINE.md`). The sensible next steps, in order: (a) run this build on
a device and confirm the start-up, (b) judge the characters in motion and in the real lighting, (c) then decide
which environment assets deserve a second pass or a licensed art pack.

---------------------------------------------------------------------------------------------------------------------

## 3. Device checklist (new)
1. Fresh install → character select appears with two portraits → pick boy → the village appears. Repeat with girl.
2. Kill the app on the splash screen once, relaunch: a "lighter graphics" message appears and the game starts in safe mode.
   Relaunch again: normal graphics return.
3. Settings → switch the hero boy ↔ girl several times: no crash, name tag stays above the head.
4. Walk, run, jump, pick up a letter: arms/legs bend at the joints without stretching the skin; ponytail swings.
5. Talk to the five villagers: they are adults (man/woman) with hats where expected (farmer, gardener, builder).
6. Watch frame time on a low-end phone; if it is poor, report the device and the boot log.
