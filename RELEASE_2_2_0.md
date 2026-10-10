# Alpha Crush 2.2.0 — Kid-friendly, low-end-ready release

Goal of this pass: a child of five can pick up the phone, understand what to do **without reading**,
and the game still runs on a 2–3 GB Android phone. Changes are grouped by what you asked for, then the
audit findings, then exactly what was and was **not** verified.

## 1. What changed (your requests)

| Request | What was done |
|---|---|
| Use the supplied art as the game icon | `icon.png`, Android launcher icons (legacy 192, adaptive foreground/background 432, **monochrome themed icon**) wired in `export_presets.cfg`. Play Console 512 px icon and the 1024 master are in `store/`. |
| Remove the Godot splash | `application/boot_splash/image` now shows the game art on the exact colour the in-game splash uses, so hand-over is seamless. The in-game `SplashScreen` covers world building and fills five tiles (A-L-P-H-A) as it loads. Note: Android 12+ always shows its own system icon splash for a moment before any game code; that is the OS, not Godot. |
| Understand by pictures, not words | Picture HUD (`ui/hud.gd`): goal bubble = a **picture of what you are building** + letter slots that light up; the big action button changes picture (hand, basket, market, hammer, …) or shows the **letter** it will pick up; icon toasts; picture inventory/daily/craft; pictorial map with a facing arrow; letter gems have tall light beams; bouncing guide arrow/edge arrow to the next target; a wordless tutorial hand (drag the stick → follow the arrow → tap the pulsing button). 59 hand-drawn icons + 8 item icons (`tools/assetgen/ui_icons.py`). |
| Move controller to the right; other controls middle/left | Floating move stick in the right ~46 % of the screen (appears where the thumb lands, base follows if it drifts, ghost ring with arrows shows where to touch). Action + jump buttons bottom-left, swipe-to-look everywhere else. Left-handed mirror in the parent settings. Controls are kept away from the bottom edge where small hands rest. |
| Bigger human, boy and girl choice | Hero drawn 1.2× larger, camera 5.2 m (was 7.5 m) and FOV 58, so the hero fills ~35 % of screen height (was ~15 %). First launch shows **"Who is playing?"** with the real 3D boy and girl turning, tap one then the green play button. Switchable later in settings (portrait buttons). Collision capsule is unchanged so doors and the footbridge still fit. |
| Low-end phones | Auto tier from RAM/CPU/GPU on first run + a frame-rate governor that steps graphics down if the phone cannot keep up (never up, max 3 steps). Tiers now control 3D render scale (0.55–1.0), MSAA, shadow atlas/filter, anisotropy, texture mip bias and a 30 fps cap on low tiers. 44 textures changed from lossless-uncompressed/no-mipmaps to VRAM-compressed with mipmaps. 32-bit ARM re-enabled (many Android Go phones are armeabi-v7a only). |
| Full system audit | See section 2. |

## 2. Audit findings (all fixed unless marked)

**Blockers**
1. **Multi-touch was broken by design.** ACT/JUMP/RUN were `Button`s and the stick/camera used GUI input. Godot only turns the *first* finger into a mouse and routes later drags by position, so "hold the stick and tap a button" fails on real phones. Replaced by `TouchRouter` (raw touches owned per finger).
2. **Play Store target API.** Since 2026-08-31 new apps and updates must target Android 16 (API 36). Export had no `target_sdk`, CI built API 35. Now `target_sdk=36`, build-tools 36.1.0. (Godot 4.7.2-stable, used by CI, exists.)
3. **No 32-bit ARM** → would not install on many low-end phones. Enabled.
4. **Godot logo splash and default icon** → replaced (above).
5. **Children's-app compliance risks reachable by a child:** LAN host/join, personalised-ads consent, purchases and rewarded ads were all one tap from the settings button. Now behind a **parental gate** (simple sum). `GameConfig.CHILD_DIRECTED = true`: personalised ads can never be enabled (even from an old save), interstitials are off, `AdService.child_directed` is ready to be passed to the real ad SDK's child-directed flag.
6. **Android back button quit the game.** Now closes panels / opens settings; never quits.

**Performance / correctness**
7. 3D textures were imported lossless, uncompressed, no mipmaps (shimmer + bandwidth). Fixed. (Textures are procedurally generated sources; if you regenerate `.import` files with the asset tools, keep `compress/mode=2`, `mipmaps/generate=true`.)
8. Fixed 4096 shadow atlas, 2× MSAA, 4× anisotropy for everyone → now per tier.
9. Stretch aspect `keep` → black bars on 20:9 phones and a HUD hard-coded to 1280×720. Now `expand`, safe-area aware layout.
10. No orientation set → `sensor landscape`.
11. Player physics started before terrain collision existed. The player is now held until a ray finds ground (max 1.5 s).
12. The old "icons" (`assets/ui/*.svg`, `assets/resources/*.svg`, …) are SVGs containing only `<text>`, which Godot's SVG importer does not draw. The HUD no longer uses them. **Not removed** (other legacy placeholders such as `assets/characters/*.svg` may still be referenced by tools); delete them if you confirm nothing in-game loads them.
13. Context prompts said "E INTERACT / Q DROP" (keyboard). Now picture + optional small caption. There is still no mobile "drop" button (not needed by the current word flow).

## 3. What I could and could not verify  (read this)

There is **no Godot runtime in my environment**, so nothing was run or rendered in-engine.
* Verified statically: the project's own gdlint (undefined calls, `:=` on Variant, scope, returns, signal/arity), `tests/source_audit.py` (now with 2.2.0 release gates: splash, icon, API 36, 32-bit, TouchRouter-only controls, every icon name exists, no tab indentation) and `tests/asset_audit.py` all pass.
* Assets (icons, splash, adaptive icon layers) were rendered and visually checked on my side.
* New unit tests added (device tier, quality ladder, picture coverage for **every** word/item/context, stick maths, guide director) — they have **not been executed**.

Please do this once before shipping:
1. Open the project in Godot 4.7.x (lets it import the new PNGs and compress textures), then run `godot --headless --path . -s tests/run_tests.gd`.
2. On a real low-end phone (2–3 GB RAM, ideally Android Go): first launch → boy/girl screen → play. Check: (a) cards show the 3D hero (if blank, the 2D face fallback should show), (b) hold the stick *and* tap ACT/JUMP together, (c) hand tutorial → first gem, (d) Android back button, (e) rotate the phone 180°, (f) 10 minutes of play with `Engine.get_frames_per_second()` visible in the profiler.
3. If something is visibly off, the usual suspects are: `Viewport.texture_mipmap_bias` (guarded), `scaling_3d_scale` in the Compatibility renderer (Godot ≥ 4.3 supports bilinear), `Button.expand_icon` icons in panels, and SubViewport transparency in the character select.

## 4. Recommended next steps (not done here)
* Google Play: enrol the app in the **Families** programme, publish a privacy policy, complete the Data-safety form, and keep the ad SDK on certified family settings. Sign with your upload key (CI already reads keystore secrets).
* Replace placeholder audio/music with child-tested sound; add short spoken cues (voice-over) for the goal bubble — a recorded "find the A!" is the single biggest upgrade for pre-readers.
* Localise the remaining English toast strings; keep picture-first.
* Playtest with 4–6-year-olds; watch where thumbs go and whether they find the first gem within 60 s.

## 5. Research that shaped the design
Google *Building for Kids* (icons for non-readers, big targets, sound + visual feedback), Sesame Workshop tablet guidance (kids rest wrists on the bottom edge, expect instant response), Interaction Design Foundation (larger targets and forgiving gestures for ages 4-7), mobile-onboarding "interact, don't tell" and Roblox onboarding docs (in-world arrows/highlights beat text), floating-stick usability notes and the Carleton virtual-controls study (thumbs slide off fixed sticks), Godot docs (Compatibility renderer, 3D resolution scaling, boot splash, Android export options), Google Play target-API policy.
