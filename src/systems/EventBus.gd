extends Node
## Decoupling signal surface (INV-12). The sim emits; presentation (Juice/HUD/audio) subscribes.
## Autoloaded as `EventBus`. (Deaths flow through KillPipeline.killed.)

signal bounced(body)
signal bounced_juicy(body, launch_speed, contact_point)
signal surface_bounced(surface, player, normal, contact_point)   # which SURFACE got hit (tier FX)
signal smashed(attacker, victim, impulse)
signal smash_landed(attacker, victim, info)   # kill-zone spec §8: hit-solidity QA feed (info Dictionary)
signal super_boosted(player)
signal super_fired(player, fuel_at_fire, aim_time, auto_fired)   # round_stats QA feed (lethality §8)
signal exploded(center, radius)
signal powerup_used(player, id)

# --- flow / feedback events (added for the audio system, 2026-07-04) ---
# The sim emits these at the exact moment the event occurs; AudioManager (and any future
# presentation) subscribes. Single-line emits at the existing trigger sites — NOT scattered
# play() calls (INV-12). See docs/feedback/owner_2026-07-04_arena_variety.md §2 for the event list.
signal countdown_tick(n)              # n = 3 / 2 / 1 during COUNTDOWN
signal combat_started()               # "BOUNCE!" — the starting gun, each stage
signal combat_ended()                 # a stage's combat closed (STAGE_END / MATCH_END). The counterpart
                                      # of combat_started: lethal hazards listen to BOTH to gate their
                                      # kill to live combat only (no pre-match/frozen-spawn or post-stage
                                      # kills). NOT emitted on the COMBAT->SUDDEN_DEATH transition (SD is
                                      # still live combat). See src/entities/SpinningHammer.gd et al.
signal match_started()                # a fresh match begins (music (re)start)
signal match_won(winner_idx)          # match-end hero moment
signal first_blood(attacker_idx)      # first credited kill of the match
signal two_left()                     # down to the final two (>=3 started)
signal player_damaged(player, level)  # transient damage escalated to Lv1 / Lv2
signal player_healed(player)          # transient damage fully healed back to Lv0
signal powerup_picked(player, id)     # a bubble was collected into the held slot

# --- moving hazard (v1_moving_hazard.md §1.4.4) --- the sim emits, Juice/audio subscribe.
# A kinematic hazard SHOVED a player (NOT a smash — no hitstun, no death). Distinct from `smashed`
# so presentation reads a chunky shove-puff, never the hitstun-gated knockback jetstream.
signal hazard_shoved(player, dir, magnitude)
# WK-96: a moving hazard's ball crossed Tuning.pendulum_whoosh_speed (one per fast pass) — audio cue only.
signal hazard_whoosh(hazard, pos, speed)

# --- SPORTS juice (WK-105 / SP-01) --- the Ball emits, AudioManager + Juice subscribe.
# A player struck the sports ball. impact_speed = |delta-v| the touch gave the ball (px/s, after the
# cap); is_power = the super-active / hitstun power shot (BALL_SMASH_MULT). One per accepted touch.
signal ball_struck(ball, player, impact_speed, is_power)
# WK-121: a DROPSHOT floor tile took a ball hit. broken = false -> it CRACKED (hit 1); true -> it BROKE open
# into a hole (hit 2). Emitted once per counted hit by DropTile._take_hit; audio subscribes.
signal drop_tile_hit(tile, broken)
# WK-106 (SP-03) — THE goal event (one place; audio/juice/HUD hook here). Emitted ONCE per goal/point by
# SportsMode at the moment the goal registers (STAGE_END entry, the tick the latched goal_zone is polled).
# team = the team AWARDED the goal (0 RED / 1 BLUE). scorer = the credited Player: the scoring team's last
# toucher (blocks/deflections by defenders don't steal it), or on an own goal the CONCEDING player who clearly
# put it in; null = team goal (no scoring-team touch). own_goal = soccer only, rare by rule (see
# SportsMode._credit_goal + Tuning.sports_own_goal_*). Assist/names via SportsMode.last_goal().
signal goal_scored(team, scorer, own_goal)
# WK-37b ghost goats — a taunt/bleat happened. player_idx = PartyMatch player index; ghost = true for an eliminated
# player's ghost (the "ghostly" variant: +3 semitones + echo/low-pass, AudioManager.last_sfx "bleat_ghost_*").
# Subscriber: AudioManager (WK-53a) plays the per-hero bleat sample (assets/sfx/bleat_<hero>.ogg / bleat_ghost_<hero>.ogg).
# The "BAAA!" word puff is drawn by the emitter (GhostDirector._try_bleat for ghosts).
signal bleated(player_idx, ghost)

# --- WK-53b living-goat taunt --- a LIVING player pressed taunt (pad Y / keyboard J), raw edge, unthrottled.
# Emitted by Player._physics_process; the presenter (src/ui/LivingCues.gd) rate-limits it (Tuning.ghost_bleat_*),
# draws the full-alpha "BAAA!" word and emits bleated(idx, false) for AudioManager. Bots never set intent.taunt.
signal living_taunt(player)

# --- WK-26 super-aim telegraph (audit D-07) --- a player ENTERED the super AIM state (the dodge window opens).
# Emitted once per aim by Player._physics_process. AudioManager plays the "super_aim" wind-up (stopped when the aim
# ends); LivingCues polls is_super_aiming() / get_super_aim_dir() for the "!" over the targeted goat.
signal super_aim_started(player)

# --- WK-20e spawn-truce feedback (spec wk20d §4.2) --- a FRESH super press was DROPPED because the goat's super is locked
# (R2 spawn truce while it blinks, or the R4 re-arm gate). Emitted by Player._wk20d_super_lock, once per press edge.
# Subscribers: AudioManager (the dry click, rate-limited per goat) and LivingCues (the padlock badge beside the head).
signal super_lock_pressed(player)

# --- WK-131 Rocketball KICKOFF GATES (docs/specs/wk131_kickoff_rule_2026-11-15.md §8). KickoffGate emits; AudioManager (and QA) subscribe.
# gate_team = the DEFENDING team of the gated goal (GoalZone.team); speed = the ball's pre-bounce speed (px/s). One per new ball contact.
signal kickoff_gate_hit(gate_team, speed)
# Both gates opened (rule 1: at Tuning.sports_gate_open_s of live ball; rule 2: when both teams touched or the fallback). Once per kickoff.
signal kickoff_gates_open()
# Presentation-only cues from the lead gate (one shared voice for both gates): the stage-intro drop-in, and each warning wind-up tick
# (n = 0, 1, 2 ... locked to the brightness swing peaks).
signal kickoff_gate_dropped()
signal kickoff_gate_tick(n)

# --- WK-116 Rocketball PRESSURE NETS (docs/specs/wk116_long_rally_2026-11-15.md §5). PressureNets emits; AudioManager subscribes.  # WK-116
# step: 0 = anticipation (t1 - warn), 1 = STEP 1 "PRESSURE!", 2 = STEP 2 "MAX PRESSURE!", -1 = over (goal latched / stage torn down).  # WK-116
signal sports_pressure(step)
