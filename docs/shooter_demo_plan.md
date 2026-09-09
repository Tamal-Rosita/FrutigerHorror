# TPS Shooter Demo — Implementation Plan

Status: **Approved for planning** (decisions locked 2026-06, session analysis).
Goal: a fun, playable third-person-shooter demo built **on the Modular Character Controller (MCC) framework** (vendored addon `addons/character_controller`, pinned byte-identical to upstream `af45779d61f88bc48848be92a2598bc94010be1f`) and extending the project's existing character features (VRM avatars, Dialogic 3D interactions, MCC actions/controllers) — not replacing them.

---

## 0. Locked decisions (chosen by project owner)

| # | Decision | Choice |
|---|---|---|
| D1 | Venue | New standalone arena scene + scripts under `samples/shooter_demo/` |
| D2 | Fire model | **Hitscan + tracer visuals** (architecture leaves room for projectiles later) |
| D3 | Feel scope | Solid lean TPS kit: ADS zoom, recoil/spread, reload + ammo, crosshair, hitmarkers, impact/muzzle FX |
| D4 | Targets | Static + moving target props and destructible props in v1; **hostile bots guaranteed as next phase** |
| D5 | Weapon visuals | Stylized CC0/CSG gun attached to a hand/chest socket; **no new animation assets in v1**; feel comes from body-turn, camera kick, FX |
| D6 | VN coexistence | Player remains the current VRM `NovelCharacter`-style third-person character; a talkable NPC with a short Dialogic timeline sits next to the range; firing is blocked while Dialogic is active |

Hard rules:

- **Never edit `addons/character_controller/`** (upstream core, re-vendor-able). Extend via the framework's own seams: `ActionNode` subclasses, `Controller` subclasses, `MovementState` behavior.
- Never edit `addons/vrm`, `addons/dialogic`, `addons/phantom_camera`, `addons/signal_lens` (third-party).
- All gameplay code lives in `samples/shooter_demo/`; small additive hooks may touch `visual-novel/scripts/*` only where strictly needed and backward-compatible.
- Do not disturb the uncommitted WIP in the working tree (`project.godot` autoload/plugin wiring, `_scenario_prototype.tscn`, `_scenario_testground.tscn`).

---

## 1. Baseline facts the plan builds on (analysis summary)

### 1.1 Framework (MCC @ af45779)
- Repo: `PantheraDigital/Modular-Character-Controller-for-Godot`, commit `af45779…` (2025-09-24, README-only change on `main`; no releases/tags; README is the manual).
- Core = 6 scripts (`addons/character_controller/scripts/`): `ActionNode`, `ActionContainer`, `ActionContainerConfig`, `Controller`, `MovementState`, `MovementStateManager`. All **verified byte-identical** (git hash-object vs upstream tree) to the linked commit.
- Model: character body exposes only **Actions** (public API, keyed by `ACTION_ID`, layered vs non-layered, interrupt whitelists) through an **ActionContainer**; **Controllers** (external nodes with `controlled_obj`) are the only callers; **MovementStates** own physics and are swapped by a **MovementStateManager**.
- Sample content was relocated into `samples/controller_examples/` but still references upstream paths `res://controller_examples/…` / `res://character_controller/…`; scenes load via Godot 4.4+ UID remap, but `dash_pickup_trigger.gd` does a **runtime `load()` with a dead path → Dash pickup grants nothing**.

### 1.2 Project character stack
- `NovelCharacter` (`visual-novel/scripts/character/novel_character.gd`, `extends CharacterBody3D`, group `ControllableCharacter`) = unified player/NPC template; scene `visual-novel/characters/novel_character_base.tscn`; per-character packed scenes in `visual-novel/GJDDM/characters/packed/`.
- Contains: `ActionContainer/{Move,Jump}` (custom `action_move_simple.gd`, `action_jump.gd`), `MovementManager/GroundedMovement` (`movement_grounded_complex.gd` — project fork of the sample: Behavior flags, ledge step-up/down via `CharacterStep3D`, air control, **drives AnimationTree each physics frame**), `CollisionShape3D` w/ `character_collision_shape.gd` (**model yaw-turns toward velocity**; `mesh_faces_camera_direction` export already anticipates facing the camera), `ModelContainer` (VRM instance; `AnimationPlayer` auto-wired), `ThirdPersonCamera` pivot + SpringArm3D + PhantomCamera3D (FOV presets, priority API), `PortraitCamera`, `InteractionArea3D`, `Socket`, `GazeTarget`, `InteractionHUD`, custom `AnimationTree` (`CharacterAnimationTree`: pose/locomotion/facial layers, noise blinking, Dialogic mood/viseme events).
- Controllers (`visual-novel/scripts/controllers/`): `ControllerPlayer` (+`…ThirdPerson`: camera-relative MOVE with `aim_direction` param), `ControllerAi` (+`…ThirdPerson`). Actions available as code: jump, dash, fly, move, toggle movement state (flight toggle not wired in base scene).
- Dialogic 3D: interaction area → HUD prompt → timeline start/end pauses/resumes movement; socket staging; portrait/third-person/cinematic cameras by PhantomCamera priority; custom event **Character 3D** (`addons/dialogic_additions/`) drives facial moods; voiceover audio present; viseme lip-sync is a TODO.
- World: physics layers `world`=1, `player`=2; input map: move/run/jump/dash/cam_left…/interact(X)/pause/dialogic actions; renderer forced `gl_compatibility` (web-export legacy) with physics interpolation on; main scene is the VRM viewer app; the VN runs via `Title → Welcome → Metro/Teatro → Laberinto` (`SceneLoader`, quest canvas, Dialogic vars).
- Known gaps/bugs found: RUN input has no action; DashPickup stale path; flight/toggle actions unwired in base scene; dialogue interaction lacks debounce; debug prints; hardcoded Spanish HUD text; `run` FOV preset unused; per-scene pointer-capture poll loop.

---

## 2. Target architecture

New tree (files created by this plan):

```
samples/shooter_demo/
├── scenes/
│   ├── shooter_arena.tscn        # the demo level (target bays, cover, env)
│   └── shooter_hud.tscn          # CanvasLayer UI (crosshair/ammo/score/…)  [instanced by arena]
├── scripts/
│   ├── controller_player_shooter.gd   # extends ControllerPlayerThirdPerson
│   ├── shooter_character.gd           # extends NovelCharacter (combat state, aiming face-turn)
│   ├── shooter_character.tscn?         # (scene lives in scenes/; inherited from novel_character_base)
│   ├── weapon/
│   │   ├── weapon_rig.gd          # character-private node: weapon state machine (not an Action)
│   │   ├── action_shoot.gd        # ActionNode ACTION_ID "SHOOT" (layered? impulse, cooldown)
│   │   ├── action_aim.gd          # ActionNode ACTION_ID "AIM" (layered)
│   │   └── action_reload.gd       # ActionNode ACTION_ID "RELOAD" (non-layered w/ whitelist MOVE)
│   ├── combat/
│   │   ├── health.gd              # generic int health w/ signals (targets now, bots next phase)
│   │   └── target_dummy.gd        # static target (hit flash, score, respawn)
│   │   └── moving_target.gd       # rail/sine moving target (D4)
│   │   └── destructible_prop.gd   # crate/barrel that breaks (D4)
│   ├── fx/
│   │   ├── tracer.gd              # line3D fade-out tracer
│   │   └── impact_fx.gd           # spark decal/particles at hit point
│   └── ui/
│       ├── shooter_hud.gd         # crosshair spread, ammo, score, hitmarker, damage popups
│       └── score_keeper.gd        # level-side scoring/timer
├── characters/
│   └── shooter_player.tscn        # inherited from novel_character_base + WeaponRig + new Actions
├── npc/
│   └── range_npc.tscn             # inherited NPC (NovelCharacter) with intro timeline (D6)
└── dialogic/
    └── shooter_intro.dtl          # short range-intro timeline (+ project.godot dtl_directory entry)
```

Framework mapping (what plays which role in MCC terms):

| MCC concept | Shooter usage |
|---|---|
| `ActionNode` | `SHOOT`/`AIM`/`RELOAD` on the character's `ActionContainer`; they call character-private `WeaponRig` |
| `ActionContainer` | unchanged; new children added in `shooter_player.tscn` |
| `Controller` | `ControllerPlayerShooter` (extends project's `…ThirdPerson`): trigger, ADS hold, reload, respects Dialogic `is_busy`, mouse capture |
| `MovementState` | unchanged (`MovementGroundedComplex`); ADS speed handling via exported move-speed modulation (new optional layered RUN-style approach) |
| Internal nodes | `WeaponRig` (private), `Health`, HUD, targets — reachable only through actions or signals |

Core loop (framework-conformant):
1. `ControllerPlayerShooter` polls: if LMB held && !`Dialogic.current_timeline` → `play_action("SHOOT", {…})` each frame; `ActionShoot.can_play()` enforces fire rate / ammo / reload state (single clock, mirrors `action_dash.gd` cooldown pattern).
2. `ActionShoot.play()` → `WeaponRig.fire()`: computes aim ray from the **current viewport camera center** (fixed crosshair), applies spread, raycasts mask = world(1) | shootable targets (new layer), damages `Health` in group `ShootableTargets`, spawns tracer + impact FX, triggers muzzle flash, camera kick, HUD events, animation-tree "fire" cue (small pose/arms impulse only if a seam exists; else FX only — D5).
3. `AIM` (layered, while RMB): `WeaponRig`/camera enter ADS — FOV lerp toward 35–40°, optional spring-arm shorten; `ShooterCharacter` sets the collision-shape flag to face the camera (body-turn seam in `character_collision_shape.gd`: runtime setter of `mesh_faces_camera_direction`, additive change to the project script).
4. `RELOAD` (non-layered, whitelist `MOVE`): plays on R/auto at empty; interrupts firing; ammo restored after `reload_time`.
5. Everything else (walk/jump/dash, VRM blink/moods, interactions) keeps working untouched; dialogue blocks 2–4 via the existing `is_busy`/`Dialogic.current_timeline` checks.

Collision/layer changes (project settings, additive):
- New physics layer `shootable` (=4): static/moving targets and destructible props. Raycast mask `world | shootable`, `collide_with_areas = true` for Area-based targets.
- Targets: popup/paper targets = `Area3D`/`StaticBody3D` on `shootable` only (never block player, layer excluded from player mask); destructible props = `StaticBody3D` on `world | shootable` so the player collides with them (solid crates that can be destroyed); group `ShootableTargets`.
- NPC bystander: existing `ControllableCharacter` group on `player`-layer body is **explicitly excluded** from the damage ray (group check) — safe-by-construction (D6).

---

## 3. Phases

### Phase 0 — Baseline hardening (small, high-value fixes before feature work)
- [x] Fixed `DashPickup` + all stale sample refs (`res://controller_examples/…`, `res://character_controller/…` → relocated `samples/`/`addons/` paths); the runtime `load()` in `dash_pickup_trigger.gd` now resolves and the grant was verified end-to-end (headless smoke PASS). Dash is kept; wiring into the shooter container happens in Phase 1.
- [x] RUN decision: implemented layered `action_run.gd` (`samples/shooter_demo/scripts/actions/`, ACTION_ID `RUN`, grounded-only, exported `run_speed`); node wiring into the shooter character happens in Phase 1. Existing input action `run` (Shift) already drives play/stop via the controller.
- [x] Input map: added `fire` (LMB), `aim` (RMB), `reload` (R) — verified registered (1 event each); no clash with `dialogic_default_action` / pointer capture; `interact` (X) untouched. Gamepad bindings deferred to a later pass.
- [ ] Pointer/pause discipline: pattern confirmed in existing code; final capture-on-start wiring lands with the arena scene in Phase 3.
- [x] Added `shootable` physics layer name (3d_physics/layer_3) for targets in Phase 2.
- **Acceptance:** ✅ all touched scenes boot clean headless (testground, MCC Prototype, Welcome) with zero script/scene errors; no stale path references remain (grep = 0).

**Phase 0 close-out notes (session log):**
- Renderer upgraded: `renderer/rendering_method="forward_plus"` (Windows-only target; `.mobile` left as `gl_compatibility`). Requires one editor open/import pass to refresh caches — spot-check visuals in-editor.
- `visual-novel/animations/rifle-shooting-mvc.res` verified loadable (binary resource). Clips (55 tracks each): `Rifle Idle`, `Rifle Aiming Idle`, `Rifle Run`, `Walking`, `Gunplay` (0.47 s), `Firing Rifle` (2.37 s), `Reload` (8.2 s), `Reloading` (6.8 s), `X Bot`. These are for Phase 1: load as a new animation library on the player model and drive via a dedicated rifle blend/pose layer.
- Validated with Godot v4.6.3 (Godots) headless; harnesses were temporary (under `.godot/`, removed).

### Phase 1 — Combat core (D2, D3, D5)
- [x] `weapon_rig.gd` (`samples/shooter_demo/scripts/weapon/`) + `weapon_config.gd` resource: damage, fire_rate, auto/semi, mag/reserve, reload_time, spread + bloom, recoil, range, tracer color; single data-driven rifle for v1. Rig is character-private ("body"); actions are the public API.
- [x] Actions `SHOOT` (impulse, cooldown in rig) / `AIM` (layered) / `RELOAD` (non-layered, whitelists MOVE/AIM/RUN); controller `ControllerPlayerShooter` (LMB auto/semi + edge detect, RMB ADS, R reload, auto-reload on empty trigger, dry-fire click). All combat gated by `NovelCharacter.is_busy` (no firing during Dialogic).
- [x] ADS & camera: additive, back-compatible additions to `third_person_camera.gd` — `set_aim_active()` (smooth FOV + spring-arm blend) and `add_recoil()` (decaying view kick).
- [x] Body-turn while aiming/firing: `WeaponRig` drives the existing `mesh_faces_camera_direction` flag on `character_collision_shape.gd` (no script change needed there).
- [x] Gun visuals: stylized CSG rifle (`weapons/rifle_placeholder.tscn`, replaceable via `WeaponRig.gun_scene`) mounted on the rig under `CollisionShape3D` with a Muzzle marker. Hand-bone/socket polish deferred with the animation layer.
- [x] HUD v1 (`scenes/shooter_hud.tscn` + `ui/` scripts): crosshair with live spread (grows with bloom), ammo `mag / reserve`, reloading + "Press R" prompts, low-ammo color, hitmarker flash (fires on `WeaponRig.target_hit`).
- [x] Muzzle flash (`OmniLight3D` pulse) + tracer (fading additive box beam) + impact flash FX via `fx/fx_bank.gd`.
- [x] SFX: procedural PCM placeholders via `audio/sfx_bank.gd` (shot/dry/reload/hit) — no assets; swappable later.
- [x] Dev level: `scenes/shooter_range.tscn` (Natalia `shooter_player.tscn` + plank wall gallery) — boot scene for testing.
- **Acceptance:** ✅ headless combat harness PASS (26 checks: mag 30/120, cadence & cooldown, ADS zoom + body turn + tightened spread, fire-in-ADS, reload refill 30/90, busy gating, no errors in fire path w/ tracer/impact FX). ✅ range/testground/Welcome/Prototype boot clean. Visual feel (crosshair, tracer look, ADS smoothness, gun placement on Natalia's hands) needs one in-editor pass by the owner.

**Phase 1 close-out notes:**
- Rendering note: previous "GL-compatibility" bullet is obsolete — project runs Forward+ now (Phase 0), so the arena can use standard forward materials; keep FX lightweight anyway (tracers are pooling candidates later).
- Rifle animation layer (rifle-shooting-mvc clips) deliberately deferred (D5 decision); `WeaponRig` emits signals (`shot_fired`, `aim_changed`, `reload_finished`) ready to drive it in the polish pass.
- Rig muzzle/hand placement (`WeaponRig` at `CollisionShape3D` local ≈ (0.14, 0.85, 0.02)) is a first guess — adjust in-editor to Natalia's right hand pose.

### Phase 2 — Targets & damage (D4 part 1)
- [x] `combat/health.gd` (signals: damaged/died; reset) + `combat/target_dummy.gd` (group `ShootableTargets`, hit flash, knockdown/sink tween, score, timed respawn; `moving` params = sine rail target) + `destructible_prop` via same script w/ crate scene (30 hp, style CRATE); prop respawn 4 s.
- [x] `combat/score_keeper.gd` (group `ScoreKeeper`, score/shots/hits/accuracy, subscribes `WeaponRig.shot_fired`) + HUD score + hit/accuracy labels. Run timer / end-of-run banner / restart deferred to the Phase 3 arena pass.
- [x] Damage popups (`FxBank.popup`, world Label3D, damage numbers + "+points" gold) & hitmarker flash (existing) — headshot zones skipped in favor of the moving-target bonus later.
- [x] Bullet impact visibility: persistent-ish `FxBank.bullet_hole` decals on world surfaces + impact flash — "watch where bullets actually hit".
- [x] Dev course in `shooter_range.tscn`: 3 static dummies, 1 moving target, 2 crates, ScoreKeeper.
- **Acceptance:** ✅ Phase 2 harness PASS (21 checks: shoulder cam 0.55 & ADS recenter, dummy damaged/dead after 3 hits w/ popup, respawn full health, crate destroyed +50, score 150 total, accuracy 3/3, moving target oscillates; zero script errors). Range/testground/Welcome/Prototype still boot clean. Visual feel (popup size, decal look, target knockdown) needs one in-editor pass.

**Phase 2 close-out notes:**
- **Shoulder camera** (requested between phases): new derived `scripts/camera/shooter_camera.gd` (extends ThirdPersonCamera — honoring the TODO in the base file) adds lateral over-shoulder offset (0.55 m, eases to 0.3 while ADS) applied along the camera basis in `smooth_move_y`; base camera untouched (offset 0 default).
- **Recoil rewritten** in `third_person_camera.gd`: old per-frame additive+decay integration was framerate-dependent (compounded to a permanent pitch climb in high-FPS runs); new version kicks instantly and eases back to the pre-shot aim orientation (`lerp_angle`), framerate independent.
- **Recoil fixed again (post-playtest "aim locked after shooting")**: easing back to the *pre-shot aim snapshot* fought live mouse input — while firing or just after, the recovery spring dragged the view back toward where the first shot was fired, making the camera feel locked. Recoil is now modeled as a **kick offset that decays to zero** (`_recoil_offset`, capped at ±12°): only the kick is recovered, the player's own aim is never pulled. Verified by regression harness: kick + turn-away keeps the new yaw (1.196 rad held vs ~0.08 before), idle kicks still settle to the aim, 3 real shots land with zero drift.
- **FX chain bug fixed**: `impact()` and `popup()` used `set_parallel(true)` with a trailing `tween_callback`, which fired immediately (parallel, zero duration) → impact flashes and damage popups freed themselves on the same frame; callbacks now go through `chain()`.
- Owner added `weapons/rifle_colors.tscn` (+ `colors_assault_rifle/` folder) as a colored rifle variant — untouched; swap via `WeaponRig.gun_scene` if desired.
- **Rifle animation layer implemented (owner follow-up)**: the owner's quick rifle hack (filtered `Rifle` Blend2 whose filter list *excluded the whole upper body* — the cause of the "aiming orientation" mess — plus a `Rifle/blend_amount = 1.0` default that rifle-posed every VN character) was removed from `novel-character_blendtree.tres` and `novel_character_base.tscn` (VN visuals restored). New **`visual-novel/animations/rifle-locomotion_state-machine.tres`** (same `Locomotion/Motion/Jump` param contract as the basic FSM so the existing movement driver keeps working) plays `rifle-shooting-mvc` clips: Rifle Idle / Walking / Rifle Run in the Motion blend space, plus **Aim** (Rifle Aiming Idle) and Jump states crossfading on `conditions/AIM` + `conditions/NO_AIM`, driven by `ActionAim`. The shooter character now uses a dedicated **`samples/shooter_demo/animations/shooter-combat_blendtree.tres`** (copy of the novel tree with the rifle FSM swapped in; `tree_root` overridden in `shooter_player.tscn`). Verified: clips/tracks share the model naming (`%GeneralSkeleton:RightHand`, canonical humanoid bones), natalia's AnimationPlayer already loads the `rifle-shooting-mvc` library; headless checks confirm params toggle and no missing-anim/param errors on boot + firing/aiming. Visual pose/blend tuning (clip loop ranges, xfade feel, ADS walk) needs the owner's in-editor pass — no renderer here.
- **Rifle hand socket**: `WeaponRig` now lazily resolves the VRM `Skeleton3D` + `RightHand` bone (model is instantiated after the rig's `_ready`), and each frame poses the gun at the bone world position + `socket_offset` with the barrel (-Z) locked horizontally along the body aim (`_update_socket`), so the rifle follows the hand animation and always points where the crosshair shoots (verified: gun at hand ±0.14 m, follows body turns). Tune `socket_offset` / `socket_pitch_deg` exports in-editor.
- **Bullet decals fixed**: `FxBank.bullet_hole` builds an orthonormal basis from the hit normal (no `look_at` UP degeneracy) with a double-sided material — holes now lie parallel to walls/floors (verified for +Z and +Y normals).
- **Wound FX**: `TargetDummy` spawns one-shot `CPUParticles3D` (plasma_color export, red default) bursting from the wound normal then dripping with gravity, parented to the target so it follows moving dummies (verified on damage).
- **Aim-state legs fixed**: the Aim state in `rifle-locomotion_state-machine.tres` is now a blend space mirroring the Motion poles (ADS Idle at rest, Walking/Rifle Run while moving); `WeaponRig._mirror_aim_blend()` writes the same speed-derived value the movement code sends to Motion (`Locomotion/Aim/blend_position`) every frame — ADS characters now walk/run instead of gliding on frozen legs (verified: moving blend 1.37 == speed remap; idle parks at the ADS idle pole).
- **Reload animation wired**: new `Reload` state in the rifle FSM (`rifle-shooting-mvc/Reloading` clip) entered/exited through `RELOADING` / `NO_RELOAD` conditions, driven by `WeaponRig._sync_reload_state()` on the reload lifecycle; crossfades 0.12 s from Motion/Aim. Gameplay now plants the character during reload (MOVE/RUN/JUMP removed from the RELOAD whitelist — legs match the clip; AIM stays allowed). Verified 12/12: clip present, conditions toggle, ammo refills on schedule, fire/move blocked, ADS allowed, fire resumes.
- **Rifle library retimed to 30 FPS tempo**: the `rifle-shooting-mvc` clips were authored at 60 FPS while the rest of the character animations play at 30 FPS — every rifle clip ran at half speed (e.g. Walking 2.77 s, Reload 8.2 s). Fixed asset-side with the reusable tool **`samples/shooter_demo/tools/retime_rifle_library.gd`** (`godot --headless --path . -s res://samples/shooter_demo/tools/retime_rifle_library.gd`): halves every keyframe time and clip length in place (22 078 keyframes). The player model references the library file by path, so it picks the fix up automatically. Resulting lengths: Walking 1.38, Rifle Run 0.72, Rifle Idle 2.73, Aiming Idle 3.12, Gunplay 0.23, Firing Rifle 1.18, Reloading 3.4, Reload 4.1 (60 FPS key grid retained → motion stays smooth). Reload state now plays `Reloading` (3.4 s) and gameplay `reload_time` is 3.5 s (owner-tuned), so the animation completes inside the gameplay window. Rerun the tool after adding any new 60-FPS rifle clips; alternatively re-export from Blender at 30 FPS.
- **Camera distance**: `ShooterCamera` gained `default_camera_distance` (2.4 m) + `set_camera_distance()` (keeps the phantom-camera child z in sync with the spring arm); `shooter_player.tscn` spring arm now starts at 2.4 m.
- **Pause/settings menu**: new `scenes/shooter_settings.tscn` + `scripts/ui/shooter_settings.gd` (ESC toggles pause, `PROCESS_MODE_ALWAYS`), live sliders for camera distance, shoulder offset, mouse sensitivity and ADS FOV — applied to the ShooterCamera at runtime; instanced in `shooter_range.tscn`. Verification harness: 13/13 PASS; range/testground boot clean.

### Phase 3 — Jam arena: "they were never your friends" (Black Mirror / Frutiger Aero)
- [x] `scenes/shooter_arena.tscn` (boot: `shooter_arena.tscn`): dark office void arena — 46 m floor, perimeter walls, cover blocks, cyan/green Frutiger emissive wall strips and floating glass "aero bubbles", fog + cool ambient; player, HUD, ScoreKeeper, pause menu and enemy spawn root included.
- [x] Hostile enemies (`combat/enemy_agent.gd` extends `TargetDummy` → full damage/plasma/popup/score pipeline, permanent death): chase the player, face it, contact damage on cooldown. Four themed scenes in `scenes/enemies/`: **ColleagueEnemy** (navy suit + tie, 60 hp), **BsodEnemy** (`:( SYSTEM_ERROR`, 45 hp), **BlissEnemy** (WELCOME wallpaper, 90 hp tank), **ErrorEnemy** (dialog box, fast glass cannon, 35 hp). Player health: `Health` node on `ShooterPlayer` (100 hp) + red damage flash overlay.
- [x] `scripts/level/arena_director.gd`: rounds (2+2n enemies, cap 14), weighted type spawns on the perimeter ring, wave banners + round/left HUD, auto next round, player death → "TERMINATED / you were always the error message" → auto restart.
- [x] Jam theme hooks (narrative to be layered in later): banner copy leans into the hallucination angle; visuals are stylized primitives so the aesthetic direction (white-collar suits + Windows icons, Frutiger Aero glow) can be iterated fast.
- [x] Pause menu restructured (`scenes/shooter_settings.tscn` + `scripts/ui/shooter_settings.gd`): **Main menu = Resume / Restart Run / Settings / Debug (Developer) / Quit**; **Settings = Master volume** (persisted `user://shooter_menu.cfg`); **Debug = camera distance / shoulder offset / mouse sensitivity / ADS FOV** (moved out of the player-facing menu, still applied live to the ShooterCamera).
- [x] **VN coexistence pass (arena NPCs)**: 
  - **Wounded ally to defend** (`scenes/wounded_ally.tscn` + `combat/wounded_ally.gd`): builds a real VRM **Celia** (NovelCharacter runtime swap, interaction area off, animation root auto-repaired), joins group `Allies` with Health (120), and whispers dream/office dialogue lines ("It started in Excel…", "That rifle was not in my desk yesterday."…) via subtitle when the player is close (10–16 s cadence). Enemies now pick the **nearest living victim** (player or ally), so she must be defended; her death ends the run ("SHE DIDN'T WAKE UP").
  - **VRM colleague enemy** (`scenes/enemies/vrm_colleague_enemy.tscn` + `combat/vrm_colleague_enemy.gd`): a real **Georgino** driven robotically — wrapper builds the NovelCharacter, swaps in `georgino.scn` + `Georgino.dch`, leaves `ControllableCharacter` (so bullets connect), disables its VN interaction layer, disables its own physics (puppet mode: wrapper moves, collision-shape yaw faces the victim, and the rifle-tree Motion blend is mirrored so the walk cycle plays). Replaces the primitive colleague in the director spawn pool (45 %).
  - Full pipeline reuse: health/plasma/popups/scorekeeper/downed signals; kills score and are counted by the round director.
- [x] **Readability pass**: world-space **health bars** (`ui/health_bar_3d.gd`) — compact (0.6 m wide), anchored **just above the model head** by reading the character's `GazeTarget` height (the same face-height the runtime prints as "Character height"), caption kept small and hugging the bar. The bar node now **rotates toward the active camera every frame (yaw-only)** instead of relying on material billboarding (owner reported billboard unreliable); quads are double-sided. Player bar hidden at full health; ally bar always on.
- [x] **Colleague uses the working tree**: the VRM colleague now drives through the **standard NPC path** on the inner character's default working tree (novel-character_blendtree, no clone swap — clone deferred until the owner provides attack/death clips). It walks via its own physics (2.4 m/s) and stops when the victim is in range (verified). Tree root re-anchored at runtime to the actual model root; a colleague-specific clone can be created when adding the `Attack`/`Death` states (suggested Mixamo: Zombie Attack/Walking/Running/Death or Punching/Right Hook).
- [x] **Ammo power-up**: `scenes/pickups/ammo_pickup.tscn` (+`combat/ammo_pickup.gd`) — spinning "+BULLETS" crate that refills reserve via `WeaponRig.add_reserve()` (capped at 3× reserve); the arena spawns 3 at round start and replenishes to ≥4 every 12 s (group `AmmoPickups`).
- [x] **Finite waves / level win state**: `ArenaDirector.total_rounds` (default 3) — after the last round clears, the arena enters a **finished** state: "THE DREAM ENDS — you finally remembered to log off" banner, spawns stop, the cleared floor stays walkable and the pause menu offers Restart/Quit. Verified headless with a 1-round level (finished=true, running=false).
- [x] **Arena scale & pacing**: floor/walls enlarged 46 → **80 m**, enemy spawn ring moved out to **26–34 m** (verified spawn ~32.9 m), ammo pickup replenish ring widened.
- [x] **Reload is twice as fast**: `WeaponRig` bakes a runtime 2×-speed duplicate of the `Reloading` clip into the model's AnimationPlayer as library `rifle_fast_reload` (1.7 s); the rifle FSM Reload state plays that clip and `WeaponConfig.reload_time` is **1.7 s** — animation and gameplay are in sync at half the previous time (verified: reload completes ~1.7 s, ammo refilled).
- [x] **Novel-engine ally intro & combat gate**: new plain-text timeline `dialogic/timelines/arena_intro.dtl` (Celia's dream/office lines, registered in project.godot). The wounded ally is a real interactable NPC again — walk close, the "Presiona X" prompt appears, X starts the dialogue (player staged at her socket, movement/fire frozen). **Waves/rounds only start after that talk** in both levels (arena `ArenaDirector` and the new corridors level gate on `Dialogic.timeline_started`). Player and ally spawn beside each other without overlapping (ally ~4 m aside, arena + corridors).
- [x] **New corridors level** (`scenes/shooter_corridors.tscn` + `scripts/level/corridor_director.gd`): separate from the arena — 92 m office corridor divided into four rooms by doors, cover, trim lights and ammo pickups; after the Celia talk, walking into each ambush door wakes VRM **colleagues only** (2/3/4/4 default, overridable via `zone_spawn_counts`); clearing every room ends the level ("THE DREAM ENDS"). Same HUD/score/pause/health-bar stack.
- [ ] Further jam narrative beats (later rooms dialogues, victory text) deferred.
- **Acceptance (updated):** Phase-3 harness now 20/20 across waves/menus/VRM passes: ally spawns and speaks near the player; VRM colleague walks on the floor toward the player (10.4 → 7.5 m), is not in ControllableCharacter, dies and scores +150; a VRM enemy ignores the far player and attacks the closer wounded ally (120 → 66 HP). Arena + range boot with zero script errors.
- **Acceptance:** ✅ Phase 3 harness 15/15 (enemies spawn & chase, kill scores, contact damage 100→86, pause menu navigation + live volume (-20 dB on bus) + debug distance apply + resume). Arena & range boot clean, zero script errors. Visual/balance pass (enemy sizes/speeds/hp, arena mood, bubble/strip glow) needs the owner's in-editor + jam-playtest pass.

### Phase 3.5 — Spanish pass + Frutiger fonts & single-theme UI (session log)
- [x] **One UI theme to rule them all** — `samples/shooter_demo/ui/shooter_theme.tres`: downloaded Google fonts (Chakra Petch Regular/Bold/SemiBold/Light + VT323 terminal face in `samples/shooter_demo/fonts/`), Frutiger-glass button/panel StyleBoxes and **type variations** (TerminalText, ScoreDigits, StatsLine, WaveStatus, MenuTitle for Labels; HudStatusRich, BannerRich, SubtitleRich for RichTextLabel). Assigned once per UI root (HUD canvas, pause panel, director UI root, subtitle layer) instead of scattered per-node overrides.
- [x] **Plain text → RichTextLabel/BBCode** where dynamic: reloading status `[wave]RECARGANDO...[/wave]`, empty prompt, centered wave-animated round/level banners with tinted subtitle lines (`[font_size]`/`[color]`), Celia whisper subtitles with per-speaker color and `*…*`→`[i]` italics.
- [x] **Everything user-facing is Spanish**: HUD (PUNTOS / ACIERTOS / PREC, RECARGANDO…, PRESIONA R PARA RECARGAR), pause menu (PAUSA, Reanudar/Reiniciar partida/Configuración/Depuración/Salir + slider rows), arena & corridor directors (RONDA/SALA/PISO DESPEJADO/EL SUEÑO TERMINA/TERMINADO/NO DESPERTÓ…), Celia whispers + `arena_intro.dtl` rewritten in Spanish, `+BALAS` pickup popup/label, health-bar captions (TÚ), enemy world labels (COMPAÑERO / BIENVENIDO / ERROR_DEL_SISTEMA). Enemies now Label3D-fonted too (VT323/Chakra SemiBold).
- [x] **Dialogic boxes themed** without touching the addon: custom StyleBoxes (`ui/dialogic/frutiger_textbox_panel.tres` dark glass + aqua border, `frutiger_name_label_panel.tres`) wired through a new default style resource `dialogic/styles/frutiger_aero_style.tres` (textbox-layer export overrides: box/name panels, Chakra fonts, text 20 / name 21, identity modulates so the styleboxes show). Registered as Dialogic `layout/default_style` (my_new_style kept in the list as fallback).
- [x] **Verified headless**: arena / corridors / range boot with zero script errors; Dialogic harness confirms style+overrides load, `arena_intro` starts, and the runtime textbox uses the frutiger panel.

### Phase 4 — Hostile bots (D4 part 2, guaranteed next phase)
- [ ] Enemy controller (extends `ControllerAiThirdPerson`): states patrol → spot player → chase/strafing → attack (attack via same `SHOOT`-style action + hitscan w/ accuracy falloff by distance) reusing `Health`.
- [ ] Player `Health` + damage feedback (screen flash) + respawn at arena start with score penalty.
- [ ] Simple bot visual (CSG/primitive v1; NovelCharacter/VRM variant optional later) + spawn points; difficulty ramp.
- **Acceptance:** bots that threaten the player, die to hitscan, respawn; arena becomes a horde-mode variant accessible from the gallery.

---

## 4. Risks & notes
- **Renderer** is now **Forward+** (desktop/Windows target; `.mobile` stays compatibility for future web exports). Keep FX lightweight anyway — tracers/impacts are per-shot node spawns and should be pooled if the arena gets busy.
- **VRM animation**: no gun animations exist; v1 relies on existing pose/locomotion + body-turn; do not retarget Mixamo combat clips into VRM libraries in v1 (D5) — reassess in Phase 4.
- **Turn-to-aim mechanics** depend on additive hooks in `character_collision_shape.gd` (project code, safe to extend; keep default behavior for existing scenes: flag defaults preserve velocity-facing).
- **Dialogic interplay**: `NovelCharacter.is_busy`/`Dialogic.current_timeline` gates all combat input; verify socket teleport does not desync weapon rig (rig lives under CollisionShape3D, rotates with model).
- **`.dtl` authoring** for the intro timeline is done by hand-mimicking an existing `.dtl` + registering the directory entry in `project.godot`; validate in-editor.
- Keep commits staged per phase with the arena runnable at each phase end.

## 5. Out of scope (unless requested)
- Lip-sync/visemes, weapon animation imports, arsenal switching, save/load, leaderboards, online/web export of the arena (only desktop dev runs in v1).
