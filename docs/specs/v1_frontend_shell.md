# v1 Front-End Shell + Match-Config + Mode Framework (Phase 1)

> Spec owner: Lead Game Designer. Scope: **Phase 1 of `docs/ROADMAP.md` ONLY** — the scaffolding
> every character/mode/circuit hangs off. This spec adds NO combat/feel changes. Launched via the
> shell with defaults, the versus loop must behave **byte-for-byte identically** to today's boot.
> Build as `.tscn` scenes + `assets/ui/theme.tres` (CLAUDE.md: never `Button.new()` walls). No code
> here — this is a design contract concrete enough to build without further design decisions.

## 0. Player fantasy (yes, the shell has one)
"I sat down with three friends, and in under 20 seconds we're screaming and bouncing." The shell is
the **on-ramp to chaos**, not a destination. Every screen is one glance + one press. Fewest possible
taps from cold boot to "BOUNCE!". Nobody reads; everybody recognizes. The shell must feel like the
Glossy Toybox (chunky cards, oversized type, glossy bevels) and never like OS widgets. It exercises
zero core verbs itself — its whole job is to get out of the way of them fast.

Pillar guard: the shell must never become a place to **camp** (Pillar 2 is about gameplay, but the
spirit applies — no dead-end menus, every screen has a visible way forward AND back). Readability
over prettiness (Pillar 5): a couch player reads every option from 8 feet.

---

## 1. Screen flow & states

### 1.1 The screens (minimal-but-complete)
Six screens, each its own `.tscn` under `scenes/ui/` with a script under `src/ui/`. All UI lives
under a `CanvasLayer` and uses `theme.tres`. All are keyboard- AND gamepad-navigable (see §1.4).

| Screen | Scene | Shows |
|---|---|---|
| **MainMenu** (Title) | `scenes/ui/MainMenu.tscn` | Game logo/title art (reuse the v1 title-screen art in `assets/reference/` as the backdrop), a vertical stack of chunky buttons: **PLAY**, **OPTIONS**, **QUIT**. First-focused: PLAY. |
| **ModeSelect** | `scenes/ui/ModeSelect.tscn` | A row of mode cards. Phase 1 ships exactly one enabled card: **BRAWL** ("Last one flying wins"), plus visibly **disabled/"COMING SOON"** placeholder cards (Trials / Gauntlet / Sports) so the layout already reads as a mode picker. Selecting BRAWL advances. |
| **CharacterSelect** | `scenes/ui/CharacterSelect.tscn` | Per-human "P1" panel(s). Phase 1 roster = the single **Bouncer** character shown large; the selectable axis is **color/skin** (pink / blue / green / yellow). A **match-settings strip** (see §1.3) lives here or on its own sub-panel: human count, bot count, bot difficulty, kills-to-win, lives. Ready/confirm advances. |
| **ArenaSelect** | `scenes/ui/ArenaSelect.tscn` | A grid of arena cards (the 11 pool levels, each showing its display `name` + `theme` color) plus a first card **"RANDOM ROTATION"** (selected by default). Picking one and confirming **launches the match**. |
| **Options** | `scenes/ui/Options.tscn` | Master / Music / SFX volume sliders + Fullscreen toggle (see §4). Reachable from MainMenu AND PauseMenu (same scene, instanced in both). |
| **PauseMenu** | `scenes/ui/PauseMenu.tscn` | Overlay during a match. Buttons: **RESUME**, **RESTART**, **OPTIONS**, **QUIT TO MENU**. Dark scrim behind. |

The existing in-match `MatchHUD.tscn` / `NameTag.tscn` are unchanged and are NOT front-end screens.

### 1.2 Navigation graph
Forward = `menu_accept` (Enter / gamepad A) on the focused control. Back = `menu_back` (Esc / B).

```
                         ┌──────────── menu_back ────────────┐
                         v                                    │
  [MainMenu] --PLAY--> [ModeSelect] --BRAWL--> [CharacterSelect] --READY--> [ArenaSelect] --CONFIRM--> (MATCH)
     │  ^  ^                  │ back                │ back                        │ back
     │  │  └──── back ────────┘                     │                            │
     │  └──────────── back ───────────────────────┘ (ModeSelect)  ┌── back ──────┘ (CharacterSelect)
     │
  OPTIONS │                                    (MATCH = scenes/Arena.tscn = PartyMatch)
     └──> [Options] --back--> [MainMenu]           │
                                                   │ menu_back (COMBAT) → toggle
                                             [PauseMenu overlay]
                                               ├ RESUME → unpause
                                               ├ RESTART → restart match (same GameConfig)
                                               ├ OPTIONS → [Options] --back--> [PauseMenu]
                                               └ QUIT TO MENU → [MainMenu]
```

Rules:
- **Back-nav is universal**: `menu_back` on any shell screen returns to the previous screen in the
  chain above; on MainMenu it does nothing (or opens a QUIT confirm — Phase 1: does nothing, QUIT is
  an explicit button). `menu_back` in Options returns to whoever opened it (MainMenu or PauseMenu).
- **Forward-nav carries state**: choices made on a screen are written to `GameConfig` (§2) as they
  are made, so backing out and re-entering preserves them within a session.
- **Screen transitions**: shell screens are swapped via `get_tree().change_scene_to_packed()` OR (preferred)
  a single persistent `ShellRoot.tscn` that instances one screen child at a time. **Recommendation:
  persistent `ShellRoot`** — it lets the title-music keep playing across screens and avoids reloading
  the backdrop. The MATCH itself is a real scene change to `scenes/Arena.tscn`.
- **Boot**: `project.godot` `run/main_scene` changes from `res://scenes/Arena.tscn` to
  `res://scenes/ui/ShellRoot.tscn` (starting on MainMenu). Arena.tscn is now only reached via the shell.

### 1.3 Match-settings strip (lives on CharacterSelect)
Small, glanceable steppers (left/right to change), each writing a `GameConfig` field:
- **Humans**: 1–4 (default **1**). Adds/removes P-panels on CharacterSelect.
- **Bots**: 0–7 (default **3**), clamped so humans+bots is 2–8.
- **Bot difficulty**: 1–5 (default **mixed** = the current `Tuning.bot_levels` [2,3,4] rotation; see §2).
- **Kills to win**: 5 / 7 / 8 / 10 (default **10**, matching `Tuning.match_target_kills`; owner-open).
- **Lives**: 1 / 2 / 3 (default **1**, matching `Tuning.lives_per_player`).

Keep it a strip, not a screen — it must not add a required tap for the "just start" path.

### 1.4 Input & focus (both devices, non-negotiable)
- Every screen sets an explicit initial `grab_focus()` control and a valid focus neighbor chain so
  D-pad / left-stick / arrow keys / Tab move focus and a focus ring is always visible (Pillar 5).
- `menu_accept` activates the focused control; `menu_back` = back per §1.2.
- Play `ui_click` SFX (already loaded in `AudioManager.SFX["ui_click"]`) on every activation. Wire a
  new `EventBus.ui_activated` signal OR call `AudioManager.play_sfx("ui_click")` directly from the
  shell script — **decision: call `AudioManager.play_sfx("ui_click")` directly** (the shell is
  presentation, no gameplay coupling needed; retires the STATUS "UI-click unwired" note).
- Sliders (Options volumes) respond to left/right when focused.

---

## 2. GameConfig contract

### 2.1 Recommendation: a `MatchConfig` Resource held by a thin autoload
Ship **`src/core/MatchConfig.gd` (`class_name MatchConfig extends Resource`)** with `@export` fields
below, held by a new autoload **`GameConfig`** (`src/core/GameConfig.gd`) exposing
`var match: MatchConfig`. The shell mutates `GameConfig.match.*`; `PartyMatch._ready()` reads it.

Why this hybrid (not a bare autoload, not a bare passed-Resource):
- **Resource** → serializable, `duplicate()`-able (RESTART re-uses a copy), trivially unit-testable,
  and future-proof for save-slots/presets in Phase 5 — none of which a plain autoload gives cleanly.
- **Held by an autoload** → the shell and the match are in different scene trees (scene change at
  launch), so a globally reachable holder is the simplest correct hand-off; no need to thread a
  reference through `change_scene`. `GameConfig.reset_to_defaults()` restores a fresh `MatchConfig`.

### 2.2 Fields (types + defaults) — chosen so defaults reproduce TODAY's boot exactly
| Field | Type | Default | Meaning |
|---|---|---|---|
| `mode_id` | `StringName` | `&"brawl"` | which `GameMode` to run (§3). |
| `human_count` | `int` | `1` | number of local humans (players 0..human_count-1). |
| `bot_count` | `int` | `3` | number of bots. Invariant: `2 <= human_count+bot_count <= 8`. |
| `bot_difficulty` | `int` | `0` | `0` = **mixed** (use `Tuning.bot_levels` rotation as today); `1..5` = fixed level for all bots. |
| `character_ids` | `PackedStringArray` | `["bouncer"]` | per-player character; index by player. Phase 1 has one entry ("bouncer") reused for all — scales to a roster in Phase 2. Missing index → falls back to `"bouncer"`. |
| `skin_ids` | `PackedStringArray` | `["pink","blue","green","yellow"]` | per-player color skin, index by player. Default reproduces P1=pink, bots blue/green/yellow. |
| `arena_mode` | `int` (enum) | `RANDOM_ALL (0)` | `RANDOM_ALL` = shuffle-bag over the whole pool (today's behavior); `SINGLE` = one arena. (Reserve `CIRCUIT (2)` for Phase 3 — not implemented now.) |
| `single_arena_path` | `String` | `""` | used only when `arena_mode == SINGLE`. |
| `kills_to_win` | `int` | `10` | overrides `Tuning.match_target_kills` for the match. |
| `lives_per_player` | `int` | `1` | overrides `Tuning.lives_per_player` for the match. |

Notes:
- **The match reads GameConfig, not the hardcoded constants.** `PartyMatch` must consume:
  `human_count` + `bot_count` (spawn loop, replacing `NUM_BOTS`), `bot_difficulty` (replacing the raw
  `Tuning.bot_levels` index — `0` keeps today's mixed rotation), `skin_ids` (replacing `BOT_SKINS`
  const + the pink hardcode), `arena_mode`/`single_arena_path` (feeding the level sequence — via the
  mode, §3), `kills_to_win`, `lives_per_player`. `PLAYER_COLORS` may stay a constant palette indexed
  by player for now (color = presentation), but skin identity comes from `skin_ids`.
- **Defaults are the contract for "identical behavior"**: a fresh `GameConfig` (never touched by the
  shell) MUST make `PartyMatch` spawn 1 pink human + 3 bots (blue/green/yellow, mixed L2/3/4), rotate
  the full 11-level shuffle-bag, first-to-10, 1 life — i.e. today's boot.

### 2.3 Bot difficulty mapping (concrete, so the programmer needn't decide)
`bot_difficulty == 0` → per-bot level = `Tuning.bot_levels[(i-1) % size]` (today's behavior).
`bot_difficulty == N (1..5)` → every bot spawns at level `N`. (L1/L5 profiles already exist per
STATUS; if L1 or L5 is absent, clamp to the nearest shipped profile and log — do not crash.)

---

## 3. Mode framework (the `GameMode` seam)

### 3.1 Goal
Make `PartyMatch`'s **rules** pluggable while it stays the **runner** (owns the state machine,
camera, spawning mechanics, HUD host, juice). Extract only the decision points that a second mode
would answer differently. BRAWL's behavior is the CURRENT `PartyMatch` logic moved behind the seam
verbatim — no behavior change. Do NOT build modes 2–5 now; only prove the seam with BRAWL and by
showing (in this doc) how a hypothetical **Gauntlet/Survival** mode fills the same interface.

### 3.2 The interface (smallest that expresses BRAWL + one other)
`src/modes/GameMode.gd` — `class_name GameMode extends RefCounted`. `PartyMatch` instantiates the
mode from `GameConfig.mode_id` via a tiny registry (`{"brawl": BrawlMode}`), stores it as `_mode`,
and calls it at these seams. Every method takes the `match` (the PartyMatch instance) so the mode
reads live state through the existing QA contract (`players`, `scores`, `lives_left`, `bounds`,
`round_stats`, etc.).

```
class_name GameMode extends RefCounted

# identity / presentation
func id() -> StringName                      # e.g. &"brawl"
func display_name() -> String                # "BRAWL"
func hud_scene() -> PackedScene              # which HUD variant to instance (BRAWL: MatchHUD.tscn)

# match setup
func configure(match, config: MatchConfig) -> void
    # read config into the runner: set match target/lives, build the level sequence
    # (RANDOM_ALL -> shuffle-bag of the pool; SINGLE -> [single_arena_path]).
func spawn_plan(match, config: MatchConfig) -> Array
    # returns per-slot spawn descriptors: [{human:bool, skin:String, character:String,
    #   bot_level:int, seed_damage:int, team:int}]. BRAWL: humans then bots, lives from config.

# stage lifecycle (called by the runner's state machine at existing decision points)
func next_level_path(match) -> String        # BRAWL: shuffle-bag draw (today's _next_level_path)
func is_stage_over(match) -> bool            # BRAWL: not_eliminated_count() <= 1 (last-one-standing)
func on_kill(match, killer_idx, victim_idx, cause) -> void
    # scoring hook. BRAWL: +1 credited kill / -1 self-fall floored at 0 (today's _on_killed math).
func match_winner(match) -> int              # BRAWL: strict leader >= kills_to_win, else -1 (today's _match_over_leader)
func stage_end_banner(match) -> Dictionary   # {text, color} e.g. "P2 SURVIVES!" (today's _enter_stage_end text)
func match_end_banner(match) -> Dictionary   # {text, color, subline} e.g. "P1 WINS THE MATCH!"
```

That is the whole seam: **presentation (3 methods) + setup (2) + lifecycle (6)**. Everything else in
`PartyMatch` (STAGE_INTRO pop-in, COUNTDOWN, camera, hitstop, sudden-death revive mechanics, the
double-KO window, name tags, powerup director) stays in the runner unchanged — those are shared
match plumbing, not mode rules. Sudden-death **eligibility** could later become a mode hook, but for
Phase 1 leave the double-KO SD in the runner (BRAWL owns it; a second mode simply won't trigger it
because its `is_stage_over`/`match_winner` differ).

### 3.3 BRAWL = the first mode (`src/modes/BrawlMode.gd`)
A mechanical extraction: each method returns exactly what the corresponding inlined `PartyMatch`
code does today (cited above per method). The refactor is "move, don't change." QA proves parity via
§5 criterion C7.

### 3.4 Proof the seam scales (hypothetical, DO NOT build now)
A **Gauntlet/Survival** mode would fill the SAME interface without touching the runner:
- `spawn_plan`: humans on `team 0`, N bots on `team 1` as wave 1; `configure` builds a single-arena
  sequence and sets lives high/infinite for humans.
- `next_level_path`: returns the same arena each stage (a "wave" is a stage on the fixed arena).
- `is_stage_over`: true when all `team 1` bots are eliminated (wave cleared) OR all humans dead.
- `on_kill`: score = waves survived / bots downed, not kill-race points.
- `match_winner`: -1 while humans live and waves remain; the runner ends on all-humans-dead via the
  mode's `is_stage_over` + a `match_winner` that returns the surviving human when the wave budget is
  spent. `hud_scene` returns a survival-HUD variant.
This confirms BRAWL and a second mode both express through the seam with **zero PartyMatch rewrites**
— exactly the Phase-4 requirement. (Trials/Sports/Puzzle similarly, out of scope here.)

---

## 4. Settings / options

### 4.1 Options present in Phase 1
- **Master volume** (0–100%, default 100).
- **Music volume** (0–100%, default 100).
- **SFX volume** (0–100%, default 100).
- **Fullscreen** (on/off, default **off** = windowed 1920×1080, matching today).

(Rebindable input and resolution are explicitly **out of scope** for Phase 1 — Phase 5.)

### 4.2 Persistence — `user://settings.cfg` via `ConfigFile`
New autoload **`Settings`** (`src/core/Settings.gd`), ordered in `project.godot` **before**
`AudioManager` is not required (Settings can apply to buses in its own `_ready` after AudioManager's
buses exist — buses come from `default_bus_layout.tres`, already present at engine start, so ordering
is safe). Contract:
- Keys (section `audio`): `master`, `music`, `sfx` (floats 0.0–1.0). Section `video`: `fullscreen`
  (bool).
- `load()` on `_ready()`; if the file is missing, write defaults. `save()` on every change from
  Options (write-through; no "apply" button needed — changes are live).
- **Apply on boot**: in `Settings._ready()`, after load, set each bus's volume via
  `AudioServer.set_bus_volume_db(idx, linear_to_db(value))` for buses **Master / Music / SFX**
  (map 0% → silence: below ~1% set the bus muted or -80 dB), and set
  `DisplayServer.window_set_mode(FULLSCREEN or WINDOWED)`.
- Options sliders read from `Settings` on open and call a `Settings.set_master(v)` /
  `set_music(v)` / `set_sfx(v)` / `set_fullscreen(b)` API that applies live AND persists.

### 4.3 Volume→dB mapping (concrete)
`db = -80.0 if v <= 0.01 else linear_to_db(v)` (so 100% = 0 dB = unchanged from today; 0% = silent).
Store the linear 0–1 value in the cfg; derive dB at apply time.

---

## 5. Measurable success criteria (QA drives this; keyboard AND gamepad)

A Phase-1 pass requires ALL of the following, verified by driving the rendered game
(`tools/run_game.ps1` + `tools/gbplay.py`) and reading screenshots:

- **C1 Reachability (keyboard):** From cold boot, using only keyboard, reach a live match via
  MainMenu→ModeSelect(BRAWL)→CharacterSelect(READY)→ArenaSelect(RANDOM ROTATION→CONFIRM). Screenshot
  each screen; the match reaches state `COMBAT` (gbplay `eval` on `state`).
- **C2 Reachability (gamepad):** Repeat C1 using only `menu_accept`/`menu_back`/`move_*` (simulated
  gamepad). Same result.
- **C3 Back-nav:** From ArenaSelect, `menu_back` returns to CharacterSelect → ModeSelect → MainMenu,
  one press each (screenshot the sequence). `menu_back` on MainMenu does not crash/exit.
- **C4 Focus always visible:** On every shell screen, a focus ring is on a control at entry
  (screenshot check) and D-pad/arrows move it through all controls without a dead end.
- **C5 Options persist across relaunch:** Set Master=40%, Music=0%, SFX=70%, Fullscreen=on; back
  out; **quit and relaunch**; open Options → values are 40/0/70/on AND `AudioServer` bus dB matches
  (gbplay `eval`: `AudioServer.get_bus_volume_db(get_bus_index("Master"))` ≈ `linear_to_db(0.40)`),
  and the window is fullscreen. `user://settings.cfg` exists and contains the values.
- **C6 Config drives the match:** Set Humans=2, Bots=2, Bot difficulty=5, Kills=7, Lives=2, and pick
  a SINGLE arena (e.g. `islands_void`). Launch; via gbplay `eval` confirm: `players.size()==4`, two
  are in group `human`, `Tuning`-independent match target reads 7 (`match_target_kills` override or
  the value the runner uses), `lives_left` starts `[2,2,2,2]`, and `level_name` is "Islands Void"
  every stage (no rotation in SINGLE mode).
- **C7 BRAWL parity (identical behavior on defaults):** Launch with a **fresh/default** GameConfig
  (or the shell's default path with no changes). The match must be indistinguishable from today's
  hardcoded boot: 1 pink human + 3 bots (skins blue/green/yellow), mixed bot levels [2,3,4],
  full-pool shuffle rotation, first-to-10, 1 life. Verify via gbplay `eval` on `players`, `_skins()`
  equivalent, `scores`, and a full match played to `MATCH_END` with `round_stats` shape unchanged.
  Motion-health probe (`bot_motion_health()`) shows no new pathologies vs. the pre-shell baseline.
- **C8 Pause:** During `COMBAT`, `menu_back` opens PauseMenu with `get_tree().paused == true` and the
  sim frozen (player positions unchanged across 1s, gbplay `eval`). RESUME unpauses; RESTART begins a
  new match with the SAME GameConfig; QUIT TO MENU changes scene back to MainMenu (state no longer a
  PartyMatch). OPTIONS from pause opens/closes and returns to PauseMenu.
- **C9 Match-end routing:** At `MATCH_END`, the prompt offers REMATCH (→ new match, same config) and
  QUIT (→ MainMenu, **not** app-quit — this changes today's `get_tree().quit()` behavior). Verify
  both branches.
- **C10 UI audio:** Each menu activation fires `ui_click` (gbplay `eval` on `AudioManager.last_sfx`
  == "ui_click" after a press).
- **C11 No OS widgets / looks like the game:** Screenshot every screen; each uses `theme.tres`
  (chunky rounded cards, oversized type), the title backdrop art on MainMenu, and shows NO default
  gray Godot buttons/sliders (Pillar 5 / "look like a real game from day one").
- **C12 No-crash gate:** Parse gate clean (`--headless --editor --quit`, no Parse Error / hides a
  native / Failed to load), and a full boot→shell→match→pause→menu→relaunch loop leaves zero stray
  Godot processes.

---

## 6. Build order (suggested, depth-first)
1. `MatchConfig` resource + `GameConfig` & `Settings` autoloads; `Settings` apply-on-boot. (Testable
   headlessly: C5 partial.)
2. Extract `GameMode`/`BrawlMode` seam; make `PartyMatch` read `GameConfig` (C7 parity FIRST — prove
   no behavior change before adding any screen).
3. `ShellRoot` + MainMenu + Options; wire boot main_scene. (C1 skeleton, C5, C11 begin.)
4. ModeSelect + CharacterSelect (+ settings strip) + ArenaSelect; launch flow. (C1–C4, C6.)
5. PauseMenu overlay + match-end routing to MainMenu. (C8, C9.)
6. Full keyboard+gamepad + ui_click polish pass. (C2, C4, C10.) Then rendered playtest + CD
   fantasy-fit verdict (the shell must feel like the Toybox and get you to BOUNCE! fast).
