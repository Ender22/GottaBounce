extends Node
## GottaBounce — central tuning (INV-6). ALL feel constants live here; nothing feel-related is
## hardcoded elsewhere. Starting values from FEEL_REFERENCE.md — tune freely, then record back there.
## Reference scale: character height H ≈ 110px, design space 1920x1080, 60fps, y-down.
## Autoloaded as `Tuning` — read e.g. `Tuning.gravity` from anywhere.

# --- Gravity (FEEL §2.1) ---
var gravity: float = 1600.0                  # px/s^2 (lowered from 2200 — floatier, easier to control)

# --- Bounce tier target heights, px (FEEL §2.1). Char height H ~= 110px. ---
# Tuned down 2026-06-27: a normal floor (trampoline tier) now lifts ~2.5x height, not ~5x.
var bounce_height_marshmallow: float = 120.0   # ~1.1 H
var bounce_height_bubblegum: float = 180.0     # ~1.6 H
var bounce_height_trampoline: float = 270.0    # ~2.5 H  (used by the test-level floors = the "basic" bounce)
var bounce_height_spring: float = 480.0        # ~4.4 H  (the big one)
var min_bounce_height: float = 48.0            # never settle (INV-11)
var bounce_di: float = 260.0                   # directional influence: holding a direction as you
                                               # bounce nudges your launch that way (px/s at full tilt)
var tangential_retention: float = 0.98       # momentum kept across a bounce (FEEL §2.2)
var bumper_restitution: float = 0.86         # walls: <1 so boost+wall can't pump speed forever (FEEL §2.4)

# --- Global safety speed cap (anti-runaway / anti-tunnel) ---
# Hard ceiling on a body's speed. Stops the elastic-wall + boost pump from escalating to absurd
# speeds. Set high enough for a punchy super-boost (~3200 impulse) and big Smash-style launches —
# safe now because the arenas are enclosed (no side gaps) and tiles are thick (64-128px).
var max_speed: float = 3000.0

# --- Air drift (FEEL §2.3) — more in-air steering so the player feels in control ---
var air_drift_accel: float = 1300.0
var air_drift_max_speed: float = 340.0

# --- Fuel (FEEL §3.1) ---
var fuel_max: float = 100.0
var tank_seconds: float = 3.5
var fuel_per_bounce: float = 20.0
var fuel_per_bumper: float = 20.0    # bumper walls refund fuel too — enables the miss -> wall-rebound
                                     # -> return-shot chain (lethality spec player fantasy). Same as
                                     # fuel_per_bounce for now: FLAGGED FOR DESIGNER REVIEW.

# --- Normal boost (FEEL §3.2) ---
var normal_boost_accel: float = 4600.0       # snappier thrust response
var normal_boost_max_speed: float = 760.0     # a bit more top thrust speed for control
var boost_rampup: float = 0.06

# --- Super boost v2: UN-CHARGED (docs/specs/v0_combat_lethality.md §1) ---
# Press super (fuel >= min) -> AIM state (floaty hover, stick steers the arrow), release or
# 2s auto-fire -> full-power blast that ALWAYS dumps the whole tank. Power never scales with
# fuel or hold time — aim and timing are the only skill axes. DO NOT re-introduce power
# scaling (docs/DECISIONS.md 2026-07-02).
var super_boost_impulse_full: float = 2800.0   # constant launch impulse (5 fuel fires as hard as 100)
var super_boost_min_fuel: float = 5.0          # "even 5%" — keep fuel_per_bounce >= 2x this
var super_aim_max: float = 2.0                 # aim-hover hard cap; auto-fire, never a camp (Pillar 2)
var super_aim_gravity: float = 0.25            # gravity scale while aiming — sag, don't plummet
var super_aim_damp: float = 2.5                # per-sec proportional velocity decay while aiming (§1.3)
var super_aim_velocity_keep: float = 1.0       # velocity kept on aim ENTRY — 1.0 = not a brake (§1.3)
var super_active_time: float = 0.45            # smash-license window after firing (replaces _super_recent=0.6)
var super_refire_lockout: float = 0.25         # min gap before another aim can start (buffer-spam guard)
var pu_unlimited_super_lockout: float = 1.0    # refire lockout while fuel_locked (Unlimited Boost)

# --- Aim-ring readability (§1.4 telegraphy — the fuse must read from across the couch) ---
# The ring's line width is CONSTANT in screen px (world width = screen width / camera zoom), sits
# on a dark backing ring for contrast on any background, and always shows a minimum arc from frame 1.
var super_ring_screen_width: float = 9.0     # fuse-ring line width in SCREEN px, zoom-independent
var super_ring_outline_extra: float = 6.0    # dark backing ring: this many EXTRA screen px of width
var super_ring_min_arc: float = 0.15         # min visible fuse-arc fraction (frame-1 visibility)

# --- Boost control-retake ---
var boost_enter_keep: float = 0.25             # starting a normal boost cuts momentum to this, so a
                                               # tap of boost lets you reclaim control of your trajectory

# --- Boost-bounce supercharge (FEEL §3.4) ---
var supercharge_window: float = 0.20
var supercharge_thrust_mult: float = 1.6
var supercharge_bounce_mult: float = 1.4

# --- Two-tier contact: SHOVE vs SMASH (lethality spec §2) ---
# A body contact SMASHES (knockback + hitstun + sting + kill credit) only if the attacker is a
# fired super (super_active) or a flying stunned body, AND closing speed >= smash_impact_min.
# Everything else is a SHOVE: momentum-scaled push, no hitstun, honest physics.
var smash_impact_min: float = 900.0          # min relative closing speed for an ELIGIBLE hit to smash
var smash_impulse_base: float = 500.0
var smash_impulse_from_attacker: float = 1.1 # kill-zone spec §3.3/§5: cap sets the ceiling now (was 1.35);
                                             # lower coeff = real gradient below cap + less end-of-window graze random.
                                             # First knob DOWN to 0.9 if solid chains feel too lethal; never up.
# --- Hit solidity (kill-zone recovery spec v2 §3.1/§3.2/§3.3, Lever A + C) ---
# BASELINE + BONUS model (v2, SUPERSEDES the v1 gate): every eligible smash launches a guaranteed
# baseline (launch_scale >= smash_launch_floor); solidity s adds a bonus toward the cap. No zero-launch.
var smash_launch_floor: float = 0.6          # §3.3: baseline fraction of the cap EVERY eligible smash launches
                                             # (baseline impulse = 0.6 * 2200 = 1320). FIRST tuning knob:
                                             # raise ->0.65/0.7 if kills stay rare; lower ->0.5/0.45 if rounds one-shot.
var smash_spin_max: float = 12.0             # §3.3: rad/s full-graze tumble speed, applied prop. to (1-s).
                                             # Cosmetic + readability ("you got clipped"); feel-only, tune to taste.
var smash_impulse_max: float = 2200.0        # §5: hard cap on impulse magnitude AFTER solidity, BEFORE max_speed.
                                             # Safety ceiling only — solidity does the shaping below it.
var smash_self_retain: float = 0.1           # on a landed smash you keep only this much of YOUR momentum,
                                             # so you stop on impact instead of flying off the edge with them
var smash_sting_fuel: float = 30.0           # sting: qualifying smashes chunk the victim's tank (§2.2)
var smash_sting_min_impulse: float = 1500.0  # supers/chains sting; Star (900) & Counter (1400) don't
# --- Damage system (kill-zone recovery spec v3 §12 — REPLACES the compounding sting) ---
# A qualifying smash (impulse >= smash_sting_min_impulse, same gate as sting) escalates the victim's
# transient damage_level 0->1->2 (caps at 2) and re-arms an 8s full-heal timer. A damaged victim's
# launch is multiplied (index by damage_level): Lv0 x1.0 / Lv1 x1.33 / Lv2 x1.66, applied AFTER the
# smash_impulse_max clamp and BEFORE the max_speed limit. Read ON THE BODY (red pulse), never a HUD.
var dmg_launch_mult: Array[float] = [1.0, 1.33, 1.66]  # §12.3: launch multiplier indexed by damage_level
var dmg_heal_time: float = 8.0               # §12.5: seconds with no qualifying hit -> full heal to Lv0
var dmg_pulse_slow_hz: float = 1.5           # §12.4: Lv1 red-pulse frequency
var dmg_pulse_fast_hz: float = 4.0           # §12.4: Lv2 red-pulse frequency
# Cross-skin damage flush (docs/briefs/damage_pulse_visual.md): a crimson overlay sprite lerps the
# body toward red (alpha-blend), so it reads as "hurt" on ANY skin (multiply couldn't add red to blue/green).
var dmg_tint: Color = Color(0.89, 0.125, 0.125)  # crimson #E32020 the body lerps toward
var dmg_lv1_alpha_mid: float = 0.175   # Lv1 throb centre -> range 0.00..0.35 (gentle, skin returns each cycle)
var dmg_lv1_alpha_amp: float = 0.175
var dmg_lv2_alpha_mid: float = 0.475   # Lv2 flush centre -> range 0.25..0.70 (deep, never fully returns)
var dmg_lv2_alpha_amp: float = 0.225
var hitstun_base: float = 0.15               # DO-NOT-TOUCH (GDD §4.6 recovery triad is protected)
var hitstun_per_impulse: float = 0.00025
var hitstun_max: float = 0.55

# --- The SHOVE — sub-super contact (lethality spec §2.3) ---
var soft_bump_scale: float = 0.5             # push = clamp(rel_speed * scale, min, max), mutual
var soft_bump_min: float = 250.0
var soft_bump_max: float = 700.0
var shove_credit_min_rel: float = 500.0      # shove at rel >= this sets last_attacker (body-check credit)

# --- Explosions (FEEL §4.1) ---
var explosion_radius: float = 280.0
var explosion_impulse_center: float = 1600.0
var chain_detonate_delay: float = 0.08

# --- Impact juice (FEEL §5) ---
var hitstop_timescale: float = 0.05
var hitstop_duration: float = 0.07
var hitstop_recover: float = 0.12
var shake_max_offset: float = 22.0
var trauma_decay: float = 1.4

# --- Input (FEEL §6) ---
var stick_deadzone: float = 0.22
var input_buffer: float = 0.10               # seconds

# --- v1 kill-race match / stage loop (docs/specs/v1_party_killrace.md §7) ---
var intro_pop_stagger: float = 0.35    # s between STAGE_INTRO spawn pop-ins
var countdown_beat: float = 0.35       # s per 3/2/1 countdown beat
var round_end_freeze: float = 1.8      # s of KO freeze-frame + pip animation (hard cap 2.0)
var idle_hunt_after: float = 4.0       # s of no input before the nearest bot hunts the idler (§3.2)
var double_ko_window: float = 0.50     # s — the ONLY sudden-death trigger: last two lose their last
                                       #   life within this window (v1 §5; was 0.25 in the laser era)
var kill_credit_window: float = 4.0    # s — last-attacker kill credit (kill-zone v2.1 §11.2 RULING 3:
                                       #   2.5 -> 4.0 INTERIM; covers the failed-recovery arc across the v2
                                       #   widened runway. PREFERRED end-state = persist through launch state.
var match_target_kills: int = 10       # v1 §2: first to this many CUMULATIVE kills with a strict lead wins
var match_target_score: int = 10       # RETIRED alias of match_target_kills (v0 back-compat; unused)
var lives_per_player: int = 1          # v1 §3: default 1 (dead = out for the stage). >1 enables the
                                       #   configurable mid-stage respawn path (non-default, not this slice)
var respawn_delay: float = 1.0         # s before a multi-life respawn (only used when lives_per_player > 1)
var bot_levels: Array[int] = [2, 3, 4] # P2 punchline / P3 fair fight / P4 menace (spec §4)

# --- Bot finisher: the 2-left stage closeout (v1 §5.5, session-4 stall fix) ---
# When a bot has <= finisher_opponents_left living opponents (i.e. it's down to me + 1 other), it
# OVERRIDES its profile dials with these — floors/caps/mults so they scale sanely across L2/L3/L4.
# Runtime overrides only (InputBot never mutates its BotProfile); they revert the instant a stage
# resets the alive count. Raises COMMITMENT, never accuracy (aim_error/target_lead/super_aim_time
# UNTOUCHED — bots never cheat, INV-8).
var finisher_opponents_left: int = 1        # enter finisher at <= this many living opponents (2 players total)
var finisher_aggression_floor: float = 0.95 # never idle-skip the hunt (max with profile.aggression)
var finisher_attack_range_mult: float = 1.4 # arm the super from further; close-and-blast, don't orbit
var finisher_commit_time_floor: float = 1.5 # a rolled hunt sticks through the whole approach
var finisher_refuel_floor: float = 10.0     # dive/attack-gate floor; > super_boost_min_fuel (5) so it can always fire
var finisher_dodge_super_cap: float = 0.15  # cap the counter-super dance so two high-tiers don't infinitely dodge

# --- Bot chase-the-wounded: the 3-4p melee pacing fix (v1 §5.6, session-4 finding #2) ---
# A bot chases a wounded (damage_level >= 1) opponent within _eff_attack_range() * this, so scattered
# melee hits stack on ONE victim inside the 8s heal window and compound to a kill. Deliberately WIDER
# than attack_range (chase a fleeing target across most of the stage). Per-difficulty acquire
# probability is BotProfile.wounded_focus (L1 0.0 / L2 0.35 / L3 0.6 / L4 0.85 / L5 0.95). Backoff knob
# on a bloodbath: lower this to 1.5 (or lower wounded_focus) — NEVER a lethality constant (§5.6).
var wounded_focus_range_mult: float = 1.5

# --- Level-relative bounds (kill-zone recovery spec v3 §14) ---
# Bounds are DERIVED in LevelLoader from play_rect (the merged platform AABB / walkable extent) plus
# these margins, so horizontally-long levels get horizontally-further blast lines. The side margin
# scales with walkable width (clamped); vertical margins are fixed (super/spring launch physics don't
# scale with width). An explicit "bounds" block in level JSON is an OPTIONAL OVERRIDE (back-compat for
# hand-tuned levels). Chosen to reproduce dev_arena's validated v2 bounds within ~geometry tolerance.
var bounds_side_frac: float = 0.52       # §14: fraction of walkable width per side (dev_arena: 0.52*1792=932)
var bounds_side_min: float = 700.0       # §14: floor so a short level isn't un-survivably tight
var bounds_side_max: float = 1400.0      # §14: cap so a very long level's runway stays camera/recovery-sane
var bounds_top_margin: float = 1700.0    # §14: fixed vertical headroom above walkable (dev_arena top 540 -> -1160)
var bounds_bottom_margin: float = 670.0  # §14: fixed drop below walkable (dev_arena bottom 1108 -> 1778)

# --- Powerups (docs/specs/v1_powerups.md §6) ---
# spawner pacing (spec §4 — rounds are 10-30s; powerups are a beat, not the meal)
var pu_first_spawn: float = 4.0          # s after BOUNCE! before the first telegraph
var pu_spawn_interval: float = 7.0       # s between spawns (telegraph starts this long after the previous BUBBLE went live)
var pu_spawn_telegraph: float = 1.0      # s of converging sparkle before the bubble is live
var pu_max_on_field: int = 2             # uncollected-bubble cap; spawner skips its beat at cap

# durations (spec: star 6→5, unlimited 10→8 — rebalanced for short rounds)
var pu_unlimited_boost_dur: float = 8.0
var pu_mega_bounce_dur: float = 8.0
var pu_star_dur: float = 5.0
var pu_counter_dur: float = 2.0
var pu_black_hole_dur: float = 2.0
var pu_ring_lifetime: float = 8.0

# magnitudes
var pu_mega_bounce_mult: float = 2.0
var pu_star_contact_impulse: float = 900.0    # px/s, 1.5x smash_impulse_base
var pu_counter_reflect_impulse: float = 1400.0 # px/s, half a full super
var pu_ball_count: int = 16
var pu_ball_hit_impulse: float = 500.0        # px/s along ball velocity
var pu_ball_lifetime: float = 6.0
var pu_ball_owner_grace: float = 0.5
var pu_black_hole_radius: float = 700.0
var pu_black_hole_pull: float = 2600.0        # px/s^2 constant-in-zone; must stay < normal_boost_accel
var pu_ring_max_triggers: int = 3
var pu_ring_retrigger_cd: float = 1.5
var pu_ring_owner_grace: float = 1.0

# deferred powerups (slow-mo waits — spec §1; constants kept for the future pass)
var pu_slow_mo_dur: float = 3.0
var pu_slow_mo_factor: float = 0.5

# bots (minimal v1 behavior: collect on touch, use after a beat — no seeking brain yet)
var bot_powerup_delay: float = 1.5       # s a bot sits on a pickup before using it (+ level-scaled variance)

# --- Derived helpers ---
func normal_boost_drain() -> float:
	# fuel units drained per second of normal boost
	return fuel_max / tank_seconds

func bounce_height_for(tier: StringName) -> float:
	match tier:
		&"marshmallow": return bounce_height_marshmallow
		&"bubblegum": return bounce_height_bubblegum
		&"trampoline": return bounce_height_trampoline
		&"spring": return bounce_height_spring
		_: return bounce_height_marshmallow
