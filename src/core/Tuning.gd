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

# --- Normal boost (FEEL §3.2) ---
var normal_boost_accel: float = 4600.0       # snappier thrust response
var normal_boost_max_speed: float = 760.0     # a bit more top thrust speed for control
var boost_rampup: float = 0.06

# --- Super boost (FEEL §3.3) — now CHARGEABLE: press to nearly freeze + aim, hold to charge, release to blast ---
var super_boost_impulse_full: float = 2800.0   # full-charge launch (committal, telegraphed)
var super_boost_duration: float = 0.30
var super_boost_min_fuel: float = 15.0
var super_charge_time: float = 1.0             # full power after 1s; holding longer just buys aim time
var super_charge_min_frac: float = 0.7         # power floor if released instantly — punchy even on a quick release (fuel ratio remains the power knob)
var super_charge_freeze: float = 0.25          # momentum kept the instant you start charging (cut to 25%)
var super_charge_glide_damp: float = 3.0       # per-sec proportional damping while charging — eases your
                                               # speed but NEVER to a dead stop, so you keep drifting as you
                                               # aim (gravity still nudges you). Higher = stops sooner.

# --- Boost control-retake ---
var boost_enter_keep: float = 0.25             # starting a normal boost cuts momentum to this, so a
                                               # tap of boost lets you reclaim control of your trajectory

# --- Boost-bounce supercharge (FEEL §3.4) ---
var supercharge_window: float = 0.20
var supercharge_thrust_mult: float = 1.6
var supercharge_bounce_mult: float = 1.4

# --- Knockback & hitstun (FEEL §4) ---
var smash_impulse_base: float = 600.0
var smash_impulse_from_attacker: float = 1.1
var smash_self_retain: float = 0.1           # on a landed smash you keep only this much of YOUR momentum,
                                             # so you stop on impact instead of flying off the edge with them
var hitstun_base: float = 0.15
var hitstun_per_impulse: float = 0.00025
var hitstun_max: float = 0.55

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

# --- v0 round loop (docs/specs/v0_round_loop.md §6) ---
var intro_pop_stagger: float = 0.35    # s between ROUND_INTRO spawn pop-ins
var countdown_beat: float = 0.35       # s per 3/2/1 countdown beat
var round_end_freeze: float = 1.8      # s of KO freeze-frame + pip animation (hard cap 2.0)
var sudden_death_time: float = 20.0    # s of combat before the laser walls activate
var laser_close_time: float = 10.0     # s for the laser walls to fully meet at stage center
var double_ko_window: float = 0.25     # s — simultaneous-death tiebreak window (GDD §7)
var kill_credit_window: float = 2.5    # s — last-attacker kill credit (replaces Player.gd's 2.0)
var match_target_score: int = 10       # first to this with a strict lead wins the match
var bot_levels: Array[int] = [2, 3, 4] # P2 punchline / P3 fair fight / P4 menace (spec §4)

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
