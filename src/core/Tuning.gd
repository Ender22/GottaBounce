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
                                     # -> return-shot chain (lethality spec player fantasy). VALUE RULED
                                     # 2026-07-03 (DECISIONS: keep 20, DO-NOT-TOUCH — "the number was never the
                                     # bug; the state condition was"). WK-128 adds a refund GATE (once per real
                                     # bounce / hard hits only), switched by refund_gates_on (WK-135 phase 3).  # WK-135

# --- Fuel integrity (WK-128, docs/specs/wk128_fuel_exploits_2026-11-14.md §4.3) — state conditions on the existing
# fuel sources/sinks; NO physics or protected constant changes. Every lever has an OFF value for A/B (§4.4).
# (a) RELIGHT BILL: re-lighting the jetpack mid-air bills the coast since release, capped. The first light after a
#     paying bounce, respawn, hitstun end or super fire is free; a billed re-light followed by a paying contact
#     within boost_relight_grace is refunded (supercharge "tap into the bounce" stays free).
# (b) REFUND GATE: "one refund per real bounce" (a face re-arms only after the body moves E off it: tier max(min_px,
#     frac x launch height) re-based on each blocked contact; bumper bumper_px; round colliders by altitude) + the bumper
#     hard-hit gate + the Alt B 1 s cap. Shipped OFF 2026-11-15 (a 0-fuel goat resting on a bumper, e.g. the Singularity
#     core, was locked forever; sports bots lived on bumper refunds). WK-135 phase 3 (spec wk135 §4.4) holds the SPEC  # WK-135
#     values below behind ONE master switch, Tuning.refund_gates_on (WK-135 block): false = every contact pays exactly as  # WK-135
#     pre-WK-128 (the values below are then ignored). Player reads them ONLY through gate_rearm_frac() etc. Alt B (not  # WK-135
#     adopted): bumper_px 400 / min_speed 0 / cooldown 1.0. Evidence: tools/out/wk/WK-128_*, WK-135_*.  # WK-135
# INVARIANTS (re-check if ANY side moves; #12/#13 are live while refund_gates_on, #14 is always live):  # WK-135
#   #12 bumper_refund_min_speed (900) > normal_boost_max_speed x CharacterProfile.BOOST_MAX (800 x 1.12 = 896) —
#       plain flight never pays off a bumper. If either side moves, the bumper fuel pump reopens.
#   #13 min_bounce_height (48) < refund_rearm_min_px (60) < bounce_height_marshmallow x APEX_MIN (0.95) x
#       refund_rearm_frac (0.9) = 103 — micro-bounces never pay twice, every natural bounce pays.
#   #14 boost_relight_bill_max x normal_boost_drain() (0.20 x 28.57 = 5.71) >= the pulse parity fee (5.14 vertical /
#       >= 4.7 horizontal at 10%). RE-DERIVE if gravity, boost_gravity_scale, normal_boost_accel/max_speed or
#       tank_seconds change (the fee scales with 1600 / (accel - 1280 + 1600)).
var boost_relight_bill_max: float = 0.20      # s of coast billed on a mid-air re-light (5.71 fuel). Band 0.15-0.25.
                                              # 0.0 = OFF (pre-WK-128 tapping). Invariant #14
var boost_relight_grace: float = 0.20         # s: a paying contact this soon after a billed re-light refunds the bill.
                                              # Keep == supercharge_window (the FEEL §3.4 "pop" beat)
var boost_relight_min_left: float = 1.0       # fuel a near-empty re-light always leaves (~4 ticks of thrust: a sputter,
                                              # never a dead button)
var refund_rearm_frac: float = 0.9            # x the paying bounce's launch height to travel off a TIER (or FLOOR-class  # WK-135
                                              # bumper) face before it pays again (spec 0.9). 0 with min_px 0 = OFF. Invariant #13
var refund_rearm_min_px: float = 60.0         # px floor of the tier re-arm distance (spec 60). Invariants #13, #15  # WK-135
var refund_rearm_bumper_px: float = 200.0     # px off a WALL-class bumper face before it pays again (spec 200, Alt B 400)  # WK-135
var bumper_refund_min_speed: float = 900.0    # px/s incoming normal speed for a WALL-class bumper contact to pay (spec  # WK-135
                                              # 900 = smash_impact_min; invariant #12: > 800 x BOOST_MAX 1.12 = 896)
var bumper_refund_cooldown: float = 0.0       # s between wall-rule bumper refunds per player (Alt B 1.0; NOT adopted: 0)  # WK-135

# --- Normal boost (FEEL §3.2) ---
var normal_boost_accel: float = 5400.0       # WK-95 (owner ruling 2026-11-14): 4600 -> 5400, snappier start/
                                             # reversal. Invariant: pu_black_hole_pull (2600) < this (escapable).
var normal_boost_max_speed: float = 800.0     # WK-95: 760 -> 800 (+5%, the most INV-1 allows). INVARIANT (INV-1):
                                             # this x CharacterProfile.BOOST_MAX (1.12) = 896 < smash_impact_min
                                             # (900) — plain boost never reaches the smash gate. Never raise past 800.
var boost_rampup: float = 0.06
var boost_gravity_scale: float = 0.8         # owner 2026-07-16: flying players are ~20% "lighter"
                                             # WHILE THRUSTING (gravity scaled only when boost is
                                             # firing), so climbing has more authority — players were
                                             # avoiding upward flight and defaulting to supers. Does
                                             # not touch the thrust cap (INV-1 untouched: plain
                                             # boost still can never reach smash_impact_min).

# --- Player head-bounce (owner 2026-07-16, "Mario coop" bounce off other players) ---
# Falling onto another player from above relaunches YOU upward like a surface bounce; the player you
# hit takes a small squash-nudge. NO fuel refund (a head is not a refuel station — prevents hover-
# farming an opponent's head) and NEVER granted while stunned (hitstun ends by TIME — the dry-reflect
# doctrine, DECISIONS 2026-07-03, applies to heads exactly like walls). Shove kill-credit rule reused.
var player_bounce_speed: float = 1150.0        # upward exit speed (≈ sqrt(2*g*h) for a ~415px hop —
                                               # between the trampoline and spring tiers; feels earned)
var player_bounce_min_closing: float = 220.0   # min downward closing speed (px/s) to count as a stomp
                                               # (grazing overlaps stay SHOVEs)
var player_bounce_victim_push: float = 240.0   # downward/outward nudge on the bounced-on player (px/s)

# --- Super boost v2: UN-CHARGED (docs/specs/v0_combat_lethality.md §1) ---
# Press super (fuel >= min) -> AIM state (floaty hover, stick steers the arrow), release or
# 2s auto-fire -> full-power blast that ALWAYS dumps the whole tank. Power never scales with
# fuel or hold time — aim and timing are the only skill axes. DO NOT re-introduce power
# scaling (docs/DECISIONS.md 2026-07-02).
var super_boost_impulse_full: float = 2800.0   # constant launch impulse (5 fuel fires as hard as 100)
var super_boost_min_fuel: float = 10.0         # WK-95 (owner ruling 2026-11-14, supersedes the 2026-07-02 "even 5%"
                                               # clause): 5 -> 10 kills the fumes-super taxi. INVARIANT: fuel_per_bounce
                                               # (20) >= 2x this — now at EQUALITY: never raise again without a
                                               # fuel_per_bounce ruling. Also #7 sting-starve: 34 - 30 = 4 < this.
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
                                               # (with boost_enter_keep_directional: only the part NOT
                                               # along the thrust is cut — see the WK-95 block below)

# --- Flight steering (WK-95, docs/specs/wk95_flight_responsiveness_2026-11-14.md §3.1/§3.2) ---
# OWNER RULING 2026-11-14: normal flight must steer well enough to get around; the super is the ATTACK.
# While THRUSTING with the stick held, velocity perpendicular to the thrust bleeds away (grip) so a held
# boost holds a line: level flight at ~11 deg up / ~815 px/s, a ~0.34 s 90-degree turn. Guards (Player.gd):
# never removes height while rising (bounce lift / supercharge pop survive), never adds speed, off with
# the stick centred (neutral boost = pure lift), off above boost_grip_speed_max and while black-hole-pulled.
var boost_grip_rate: float = 8.0               # 1/s perpendicular-velocity decay (time constant 0.125 s; level-
                                               # flight sag 1280/8 = 160 px/s). 0.0 = grip OFF (pre-WK-95). Band 6-12
var boost_grip_decel_max: float = 3000.0       # px/s^2 ceiling on the grip decel: > the largest gravity share it
                                               # fights (0.8 g = 1280) and < normal_boost_accel. Band 2000-4000
var boost_grip_speed_max: float = 1300.0       # px/s: grip OFF above this — supers (2800), smash launches and
                                               # supercharged springs (~1736) belong to physics. > supercharged
                                               # thrust cap (800 x 1.6 = 1280)
var boost_enter_keep_directional: bool = true  # a fresh boost keeps the velocity ALONG the thrust and cuts only the
                                               # rest to boost_enter_keep (bounce + boost-up keeps the bounce; aiming
                                               # back/across still brakes 75%). false = pre-WK-95 flat chop

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
# launch is multiplied (index by damage_level): Lv0 x1.25 / Lv1 x1.66 / Lv2 x2.08, applied AFTER the
# smash_impulse_max clamp and BEFORE the max_speed limit. Read ON THE BODY (red pulse), never a HUD.
# OWNER 2026-07-19: every level +25% over the v3 spec values [1.0, 1.33, 1.66] — smash knockback
# ("how far you get knocked when someone super boosts into you") reads too soft.
var dmg_launch_mult: Array[float] = [1.25, 1.66, 2.08]  # §12.3: launch multiplier indexed by damage_level
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

# --- Attacker-colour hits (WK-24 · audit D-06 / D-02 part 2) — presentation only, no sim value ---
# A landed smash carries the CREDITED attacker's identity colour (PartyMatch.player_color): an impact
# starburst + sparks at the contact, the victim's knockback streak, and a thin "last-touch" ring around a
# victim who is in the credit window AND (in hitstun OR off-stage). Chain hits = the credited launcher.
var hit_burst_screen_px: float = 84.0        # impact starburst size in SCREEN px (world size = px / zoom).
                                             #   120 hid the victim in rendered QA (WK-24 sheet) — keep it small
var hit_burst_offset: float = 0.45           # burst centre sits (body radius + this * burst size) behind the
                                             #   victim along the impact, i.e. on the attacker side, so the
                                             #   victim's flash/tumble stays readable on top of the hit
var hit_burst_time: float = 0.24             # s starburst pop + fade on the REAL clock (hitstop can't hold it
                                             #   over the victim)
var hit_burst_sparks: int = 18               # attacker-tinted sparks sprayed along the impulse
var hit_burst_spark_speed: float = 900.0     # px/s max spark speed (min = 40% of this)
var streak_tint_value_floor: float = 0.8     # knockback streak HSV value floor (flair rule: launch read kept)
var streak_tint_head_white: float = 0.30     # head stop = attacker colour lerped this far toward white
var streak_tint_mid_alpha: float = 0.80      # mid-stop alpha of the tinted streak (stock white = 0.65)
var touch_ring_screen_width: float = 4.0     # last-touch ring line width, SCREEN px
var touch_ring_outline_extra: float = 3.0    # dark chocolate backing ring = width + this (contrast on any bg)
var touch_ring_gap: float = 10.0             # ring radius = body radius + this (world px)
var touch_ring_alpha: float = 0.90

# --- Screen-edge KO blast (WK-23 · audit D-01 · brief docs/briefs/ko_blast_2026-11-14.md) ---
# Presentation only (INV-12): a CanvasLayer pinned to the viewport edge where the victim left the screen,
# in the VICTIM's colour. Never moves the camera (owner camera rules). Sizes are SCREEN px at a 1080p
# reference and scale with viewport height. Nothing may reach into the middle 60% (MatchHUD prime directive).
var ko_blast_duration: float = 0.6           # s (real time — ignores hitstop) whole blast lifetime cap
var ko_blast_core_px: float = 300.0          # starburst diameter at its settled scale (pops 0.4 -> 1.15 -> 1.0)
var ko_blast_ring_px: float = 260.0          # shockwave base diameter; expands 0.3 -> 1.6 of this (~420 max)
var ko_blast_column_width_px: float = 300.0  # plume width across the edge
var ko_blast_column_depth_px: float = 420.0  # plume depth into the screen (also capped by the frac below)
var ko_blast_column_depth_frac: float = 0.19 # ... and by this fraction of the viewport axis (outer-20% band)
var ko_blast_star_px: float = 110.0          # top-edge star-KO twinkle size
var ko_blast_star_inset_px: float = 90.0     # star centre sits this far inside the top edge
var ko_blast_star_white: float = 0.55        # star tint = victim colour lerped this far to white (pops on the core)
var ko_blast_edge_margin_x_px: float = 330.0 # along-edge clamp on TOP/BOTTOM edges: clear the HUD corner cards
var ko_blast_edge_margin_y_px: float = 200.0 # along-edge clamp on LEFT/RIGHT edges (cards are ~265x125 px)
var ko_blast_edge_band_px: float = 80.0      # a death this close to (or past) a screen edge counts as an edge KO.
                                             #   Rendered QA: on void-floor arenas the zoomed-out camera puts the
                                             #   bottom kill line just INSIDE the frame — the in-world burst got cut
                                             #   off at the edge and no edge blast fired. Mid-screen deaths keep the
                                             #   in-world burst.
var ko_blast_ref_height: float = 1080.0      # px sizes above are authored at this viewport height

# --- Camera (OWNER RULES 2026-07-10 — docs/feedback/owner_2026-07-10_camera_rules.md) ---
# Camera bounds per level = the platform-union AABB (LevelLoader play_rect) grown by this pad on
# every side. An in-bounds living player is on-screen 100% of frames (the camera zooms out as far
# as needed); the frame targets the midpoint of the extreme players' bounds-clamped positions.
var cam_bounds_pad: float = 200.0
# Zoom-in cap (owner rule 6): at the CLOSEST allowed zoom, this fraction of the camera-bounds
# extent must still be visible — even with 2 clustered players the camera never dives in tight.
var cam_close_fraction: float = 0.75

# --- Input (FEEL §6) ---
var stick_deadzone: float = 0.22
var input_buffer: float = 0.10               # seconds
# InputRouter (WK-03): a joypad stick/trigger motion only counts as "this device is active" (last_device_key,
# seen-order) at |axis| >= this. Keeps resting-stick drift on an idle couch pad from flipping glyphs/ownership.
var input_activity_axis: float = 0.5

# --- Herd Lobby (WK-05/06 · audit §E.4/E.5/E.10 · CC-4.x/5.3) — menu feel, not player feel ---
var lobby_repeat_delay: float = 0.40       # s a held D-pad/stick direction waits before auto-repeat (per device)
var lobby_repeat_rate: float = 0.09        # s between auto-repeat steps once repeating
var lobby_stick_press: float = 0.5         # LS strength that counts as a direction press (hysteresis high)
var lobby_stick_release: float = 0.3       # LS strength below which the direction is released (hysteresis low)
var lobby_banner_guard: float = 0.35       # READY banner must be visible this long before a proceed press counts
var lobby_hold_exit: float = 1.0           # s of held B / Esc that exits the lobby (fill ring)
var lobby_hold_ring_show: float = 0.12     # s of hold before the ring appears (taps never flash it)
var lobby_entry_grace: float = 0.30        # s after the lobby appears before input counts (= shell transition lock)
var lobby_random_spin: float = 0.6         # s the Y/R random portrait spin runs before landing
var lobby_empty_well_alpha: float = 0.94   # EMPTY panel dark-well opacity (review said 0.72; 0.72 and 0.86 both still ghosted the backdrop at 1080p)

# --- Hold-to-confirm + end-screen input gate (WK-09 / WK-11 · CC-6.1 / CC-10.2 · audit C-14/C-18) — menu feel ---
var hold_confirm_time: float = 0.9         # s of held A/Enter on a HoldButton (pause RESTART / CHANGE SETUP / QUIT)
var hold_confirm_drain: float = 0.15       # s for a released (unfinished) ring to drain back to empty
var hold_confirm_tick: float = 0.15        # s of hold progress between rising-pitch ticks
var end_screen_arm: float = 1.0            # s after an end screen appears before its buttons accept a press
var end_screen_ff_rearm: float = 0.6       # s minimum after a fast-forward (Victory) before the row arms
var scoreboard_skip_guard: float = 1.2     # s after the between-stage score screen appears before A skips it
# WK-187 (CD6-05 / CC-10.2) results mash guard on the Brawl VictoryScreen + SportsVictory: the row goes live only after  # WK-187
# the screen has SETTLED (the score tally finished, or a deliberate fast-forward landed it) and then stayed up for the  # WK-187
# read time; until then the REMATCH row + footer are hidden, and they pop in as the row arms (the visible "ready" beat).  # WK-187
var end_screen_read_time: float = 1.5      # s the settled results stay up before REMATCH / SETUP / QUIT accept a press  # WK-187
var end_screen_quiet_gap: float = 0.3      # s a button must have been UP before its accept counts (a mash never has it: no tally skip, no REMATCH)  # WK-187
var end_screen_live_pop: float = 0.22      # s the row's pop-in takes; it starts this long BEFORE the arm so it is fully shown when live  # WK-187
var end_screen_live_pop_from: float = 0.8  # row scale at the start of the pop (springs to 1.0, TRANS_BACK)  # WK-187

# --- Between-stage budget (WK-21/WK-41 · audit D-09 · DECISIONS 2026-07-16 names the score hold as THE knob) ---
# The ScoreScreen hold is ADAPTIVE: quiet stages get the short hold, dramatic stages (lead change / a player newly
# at match point / tiebreaker next) keep the owner's original 3.4 s. round_end_freeze + the countdown are owner-ruled
# and are NOT part of this block. Budget: STAGE_END -> COMBAT <= 6 s normal, <= 8 s dramatic (wall clock).
var score_hold_normal: float = 2.0         # s ScoreScreen auto-advance on a non-dramatic stage
var score_hold_dramatic: float = 3.4       # s on a lead change / newly-reached match point / tiebreaker (ex PartyMatch.SCORE_HOLD)
var scoreboard_fade_out: float = 0.15      # s ScoreScreen fade; runs INSIDE the hold so the intro card never overlaps it

# --- Player identity pips (WK-10 · CC-8.3 · audit C-09/R-05/R-17) — presentation timing, not player feel ---
var pip_idle_alpha: float = 0.70        # a human's P# pip alpha once settled in combat (never 0 — never gone)
var pip_full_hold: float = 1.0          # s a human's pip stays at FULL alpha after a (re)spawn / pop-in
var pip_intro_linger: float = 1.0       # s into COMBAT the intro read holds full alpha (ex NAME_TAG_LINGER)
var pip_fade: float = 0.4               # s alpha fade: human full -> idle, CPU intro tag -> gone (ex NAME_TAG_FADE)
var pip_head_clearance: float = 1.25    # pip tip sits this many body radii above the goat's centre (world space)
var pip_screen_gap: float = 6.0         # extra screen px between the head and the pip tip

# --- Off-screen magnifier bubbles (WK-36 · audit D-05 / R-30) — presentation only; camera framing UNTOUCHED ---
# A living goat outside the frame (the PlayerPips / EdgeIndicators frame) is shown LIVE in a Smash-style bubble pinned
# to the screen edge: cream window, goat-colour rim, fuel ring, pointer at the true position. px values are authored
# at bubble_ref_height and scale with viewport height. Everything stays in the outer-20% edge band.
var bubble_ref_height: float = 1080.0
var bubble_radius_max_px: float = 75.0        # 150 px bubble while the goat is just past the frame (closer = bigger)
var bubble_radius_min_px: float = 60.0        # 120 px once the goat is bubble_far_world_px (or more) past it
var bubble_far_world_px: float = 1600.0       # WORLD px past the viewport where the bubble bottoms out. The top kill
                                              #   line is bounds_top_margin (2650) above the top platform and the frame
                                              #   already shows ~850 of that, so a LIVING goat tops out near ~1800 past:
                                              #   the full size range plays out over a recovery arc. Sides/bottom kill
                                              #   lines sit ~500 past, so side bubbles stay near max (just off = big).
var bubble_edge_gap_px: float = 28.0          # rim -> screen edge clearance (room for the pointer tip)
var bubble_pointer_px: float = 22.0           # pointer (the old chevron) tip length beyond the rim
var bubble_corner_keepout_x_px: float = 276.0 # top/bottom bubbles stay clear of the HUD corner cards (x 24..264)
var bubble_corner_keepout_y_px: float = 136.0 # left/right bubbles stay clear of the HUD corner cards (y 24..124)
var bubble_separation_px: float = 10.0        # min gap between two bubbles on the same stretch of edge
var bubble_outline_px: float = 4.0            # chocolate outer outline
var bubble_rim_px: float = 8.0                # goat-colour identity rim
var bubble_band_gap_px: float = 2.5           # chocolate separators between rim / fuel ring / window
var bubble_fuel_px: float = 9.0               # fuel ring width (fill = get_fuel_ratio(), clockwise from 12 o'clock)
var bubble_goat_fill: float = 0.6             # goat BALL radius as a fraction of the cream window radius (rendered QA:
                                              #   0.5 left the goat small in a sea of cream; at 0.6 the jetpack just
                                              #   tucks under the frame band, by design)
var bubble_pop_time: float = 0.14             # s (real time) pop-in when a goat leaves the frame
var bubble_hide_delay: float = 0.15           # s a bubbled goat must be back IN view before the bubble drops (WK-93
                                              #   recording: a goat grazing the frame line flickered the bubble every
                                              #   frame). The pip stays hidden while bubbled. A bubble only APPEARS once
                                              #   the goat's body is fully past the viewport edge (rendered QA: at the old
                                              #   inset-40 rule the 150 px bubble sat on top of the half-visible goat).
var bubble_repop_grace: float = 0.35          # s after a bubble drops in which a re-exit shows it at full size (no re-pop)
var bubble_fuel_color: Color = Color(1.0, 0.80, 0.22)        # jetpack-gold fuel arc
var bubble_fuel_alt_color: Color = Color(1.0, 0.99, 0.94)    # used instead when the goat's rim colour clashes with gold
var bubble_fuel_hue_clash: float = 0.09       # hue distance (0..0.5) under which rim + gold fuel merge (rendered QA:
                                              #   yellow/orange goats read as one thick yellow band) -> alt colour
var bubble_fuel_low_color: Color = Color(1.0, 0.30, 0.22)    # below bubble_fuel_low: red, pulsing
var bubble_fuel_locked_color: Color = Color(0.45, 0.92, 1.0) # Unlimited Boost (fuel_locked): cyan, like the HUD
var bubble_fuel_track: Color = Color(0.43, 0.30, 0.24)       # empty part of the fuel ring
var bubble_fuel_low: float = 0.25             # fuel ratio under which the ring turns red and pulses
var bubble_fuel_low_hz: float = 5.0
var bubble_aim_tip: float = 1.38              # super-aim arrow tip, in bubble radii from the centre (pokes past the rim)
var bubble_aim_flash_hz: float = 8.0          # aim arrow white-flash rate (never fully off: visible from frame 1)

# --- v1 kill-race match / stage loop (docs/specs/v1_party_killrace.md §7) ---
var intro_pop_stagger: float = 0.20    # s between STAGE_INTRO spawn pop-ins (pacing6: 0.35->0.20, 4 pops in 0.8s)
var countdown_beat: float = 0.35       # s per 3/2/1 countdown beat (LEAVE — the 3-2-1 is iconic/tight)
var round_end_freeze: float = 1.4      # s of KO freeze-frame + pip animation (pacing6: 1.8->1.4, hard cap 2.0)
var idle_hunt_after: float = 4.0       # s of no input before the nearest bot hunts the idler (§3.2)
var double_ko_window: float = 0.50     # s — the ONLY sudden-death trigger: last two lose their last
                                       #   life within this window (v1 §5; was 0.25 in the laser era)
var kill_credit_window: float = 4.0    # s — last-attacker kill credit (kill-zone v2.1 §11.2 RULING 3:
                                       #   2.5 -> 4.0 INTERIM; covers the failed-recovery arc across the v2
                                       #   widened runway. PREFERRED end-state = persist through launch state.
var kill_credit_window_ringout: float = 6.0  # v2_kill_shape §3 RULING 3: EXTENDED window for ring-out/pit
                                       #   deaths only. A failed-recovery arc into a side/pit blast takes 3-5s
                                       #   (launch + doomed boost attempts); the 4.0 standard expires mid-arc and
                                       #   mis-logs the kill as an uncredited self-fall. 6.0 captures the full arc.
                                       #   §1b reconciliation: within 6.0 of a qualifying hit = CREDITED; no
                                       #   qualifying hit in the window = genuine self-fall (-1 self-floor, kept).
var match_target_kills: int = 10       # v1 §2: first to this many CUMULATIVE kills with a strict lead wins
                                       #   (BRAWL kill target — OWNER-SET at 10; do NOT retune here for pacing).
var sports_goal_target: int = 6        # SPORTS goal cap — split from the BRAWL kill target so Sports can hold
                                       #   the "10-30s one-more-round" cadence (~6 goals) without moving Brawl off 10.
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
var finisher_refuel_floor: float = 15.0     # dive/attack-gate floor; must stay > super_boost_min_fuel (10, WK-95) so it can always fire
var finisher_dodge_super_cap: float = 0.15  # cap the counter-super dance so two high-tiers don't infinitely dodge
# v1_kill_economy §2b: scale the finisher AIM-entry range with arena width so a bot arms its super
# from proportionally further on a huge map (close-then-blast like a human) instead of needing to get
# pixel-close. factor = clampf(bounds.size.x / ref, 1.0, max). grassy width 5680 -> ~1.55; dev -> 1.0.
var finisher_range_width_ref: float = 3660.0  # dev_arena blast-bounds width (the no-regression baseline)
var finisher_range_width_max: float = 1.6     # cap on the width multiplier
# v1_kill_economy §2c: flee-to-heal RETREAT anti-permanent-evasion caps. A wounded bot cannot flee
# forever (Pillar 2); after the cap it MUST re-engage so the finisher PURSUE always resolves the closeout.
var flee_max: float = 8.0            # s cap on RETREAT outside finisher (= the heal window; then force re-engage)
var finisher_flee_max: float = 3.0   # s cap on RETREAT in the 2-left endgame (guarantees the closeout resolves)

# --- Bot chase-the-wounded: the 3-4p melee pacing fix (v1 §5.6, session-4 finding #2) ---
# A bot chases a wounded (damage_level >= 1) opponent within _eff_attack_range() * this, so scattered
# melee hits stack on ONE victim inside the 8s heal window and compound to a kill. Deliberately WIDER
# than attack_range (chase a fleeing target across most of the stage). Per-difficulty acquire
# probability is BotProfile.wounded_focus (L1 0.0 / L2 0.35 / L3 0.6 / L4 0.85 / L5 0.95). Backoff knob
# on a bloodbath: lower this to 1.5 (or lower wounded_focus) — NEVER a lethality constant (§5.6).
var wounded_focus_range_mult: float = 1.5
# v1_kill_economy §3: the chase-the-wounded radius must SCALE with arena width, else on a 3760px-walkable
# arena players spread 1500-2400px apart are never inside the ~510px attack-range term and melee kills
# don't land. reach = clampf(maxf(attack_range*mult, frac*bounds.width), 0, max). grassy -> ~1988px.
# Backoff knob on a bloodbath: lower wounded_focus_frac (0.35 -> 0.25) — NEVER a lethality constant.
var wounded_focus_frac: float = 0.35       # fraction of blast-bounds width a bot will chase a wounded target across
var wounded_focus_range_max: float = 2600.0  # camera/sanity cap on the width-scaled chase radius

# --- Level-relative bounds (kill-zone recovery spec v3 §14) ---
# Bounds are DERIVED in LevelLoader from play_rect (the merged platform AABB / walkable extent) plus
# these margins, so horizontally-long levels get horizontally-further blast lines. The side margin
# scales with walkable width (clamped); vertical margins are fixed (super/spring launch physics don't
# scale with width). An explicit "bounds" block in level JSON is an OPTIONAL OVERRIDE (back-compat for
# hand-tuned levels). Chosen to reproduce dev_arena's validated v2 bounds within ~geometry tolerance.
# v2_kill_shape §1b CORRECTION: the runway must track the FIXED launch band, not scale with level
# width (0.52-frac blew the walkable edge OUTSIDE blast range on wide levels -> off_stage_kills=0).
# Small width component only; clamped to the Lv0 band so the walkable OUTER edge is ALWAYS inside
# blast range on every circuit level. Grassy(3760)->clamp(564,480,720)=564 (~560 runway, matches the
# explicit -560/4320 override); dev_arena(1792)->480 floor; a 5000-wide level->720 cap.
var bounds_side_frac: float = 0.15       # §1b: small width component only (was 0.52 = scaled with width)
var bounds_side_min: float = 480.0       # §1b: floor (was 700) — tightest runway, still a survivable mid-stage arc
var bounds_side_max: float = 720.0       # §1b: cap (was 1400) — never exceeds Lv0 band top (~900) minus margin
var bounds_top_margin: float = 2650.0    # v1_kill_economy §1: 1700->2650 = self_super_rise(2450)+200 clearance,
                                         # so a straight-up self-super arcs back from the highest platform on
                                         # EVERY circuit level (no routine upward self-destruct). (dev_arena top 540 -> -2110)
var bounds_bottom_margin: float = 670.0  # §14: fixed drop below walkable (dev_arena bottom 1108 -> 1778)

# --- Powerups (docs/specs/v1_powerups.md §6) ---
# spawner pacing (spec §4 — rounds are 10-30s; powerups are a beat, not the meal)
var pu_first_spawn: float = 2.5          # s after BOUNCE! before the first telegraph (pacing6: 4.0->2.5, bubble live ~3.5s for short stages)
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

# --- Bot gravity-frame sense (bot brains v2 slice 1 — orbital arenas, see STATUS "ORBITAL GRAVITY") ---
# The bot expresses up/down/fall in the LOCAL gravity frame (GravityField.get_gravity_at, INV-1).
# In a flat arena the field returns exactly global down, so every gravity-relative branch reduces to
# the legacy screen-down behavior. Bot SPATIAL-REASONING dials — NOT game-feel constants.
var bot_radial_down_dot: float = 0.999      # local down.y >= this = the FLAT frame (legacy code paths run)
var bot_radial_dive_fallback: float = 400.0 # px along the local pull to aim when no floor reads along it (defensive)

# --- SPORTS owner list 2026-07-18 (append-only; NOT fenced player-feel constants) ---
# CRUSHER fairness (owner item 2): a crusher only kills when a body is truly SQUEEZED between the
# two inner faces (or face + anvil) — i.e. the face-to-face gap has closed to at most this many px
# (player diameter ~88 at Standard size, + a small pinch margin). Side/back/resting contact with a
# head is harmless. Read by Crusher._kill_overlapping.
var crusher_crush_gap: float = 100.0

# DROPSHOT beach-ball variant (owner item 5): the floaty volleyball. Applied by Ball.configure_dropshot
# on courts whose JSON declares "sport": "dropshot"; the soccer ball keeps Ball.gd's mode-owned consts.
var dropshot_ball_gravity_mult: float = 0.35   # fraction of field gravity (floaty hang-time)
var dropshot_ball_restitution: float = 0.93    # bouncier than the soccer ball's 0.85
var dropshot_ball_radius: float = 84.0         # bigger, reads "beach ball" (soccer = 60)
var dropshot_ball_max_speed: float = 1900.0    # slower cap: rallies stay readable/chaseable
var dropshot_serve_offset_frac: float = 0.25   # kickoff x offset from court centre (fraction of bounds width)

# --- WK-104 (SP-02/SP-05) ROCKETBALL kickoff. The ball is GHOSTED (frozen, no player/hazard contact) through
# STAGE_INTRO/COUNTDOWN and released on GO at the court's JSON "kickoff.ball" spot; every seat spawns at the same
# distance from it (JSON "kickoff" slots, team 1 mirrored). Release = an upward ref-drop toss (random in
# [min, max] px/s) with gravity scaled by hang_gravity until the first touch or hang_s elapses, so the ball
# stays near the spot while both teams converge (contested first touch, no free run). Read by SportsMode. ---
# A/B (headless, 4 L3 bots, CENTER PITCH 2v2): held ball (toss 0, hang_gravity 0) 22.5% goals <4 s after GO;
# this TIP-OFF (toss 700-900, normal gravity: ball rises ~150-250 px, players meet it on the way down) 10-17%;
# legacy 30%. Contact from below sends the ball UP, not straight at a goal mouth.
var sports_kickoff_toss_min: float = 700.0     # px/s upward release speed (low end of the random toss)
var sports_kickoff_toss_max: float = 900.0     # px/s upward release speed (high end)
var sports_kickoff_hang_gravity: float = 1.0   # gravity fraction until the first touch (0 = RL-style held ball)
var sports_kickoff_hang_s: float = 2.0         # s: an untouched hang drops to normal gravity after this
var sports_assist_window: float = 3.0          # s: a teammate's touch this soon before the scorer's = ASSIST
# WK-124 goal -> GO restart (WK-98 PROTECT: <= 2.8 s game time). Was round_end_freeze 1.4 + intro 0.2 x players
# (0.8 in 2v2) + countdown 1.05 = 3.25 s in 2v2 (2.85 s in 1v1, where the 2.8 s was first measured). Now a sports-only
# freeze + a fixed-width pop-in window: 1.2 + 0.4 + 1.05 = 2.65 s for any team size. The countdown is untouched.
# The goal banner is NOT shortened: SportsHUD keeps it up across the freeze AND the pop-in (1.6 s on screen, was
# 1.4 s), popping out as the "3" lands. A match-winning goal keeps the full round_end_freeze (no restart follows).
var sports_goal_freeze: float = 1.2            # s STAGE_END freeze after a goal/point (BRAWL keeps round_end_freeze)
var sports_intro_pop_window: float = 0.4       # s the whole kickoff pop-in takes (stagger = min(intro_pop_stagger, this / n))
# WK-106 goal credit (sound-designer/coordinator ruling: OWN GOAL must be rare + earned, not the raw last touch,
# which read OWN GOAL on 54% of bot goals). A defender's last touch is an OWN GOAL only if it came within
# own_goal_window s of the goal, ADDED >= own_goal_push px/s of velocity toward their own goal, and no attacker
# touched it in the deflect_window s before it. Anything else (a block/failed save, a deflection, a stale
# touch) credits the scoring team's last toucher (Rocket League / FIFA). Headless 2v2 L3: OWN 54% -> ~25%; the
# rest are bots driving it into their own net at ~1900 px/s (SP-06 bot pathing, not a credit problem).
var sports_deflect_window: float = 0.35        # s: a defender touch this soon after an attacker's = deflection
var sports_own_goal_push: float = 700.0        # px/s goalward velocity the defender's touch must ADD
var sports_own_goal_window: float = 1.0        # s: the defender's touch must be this close to the goal

# --- WK-94 bot super-aim sweep (owner 2026-11-14: "the aiming mechanic looks crazy when the bots use it,
# it spins like nuts"). A bot's aim is a human stick: the emitted super-aim direction rotates toward the
# solution at no more than this many rad/s, and all aim error is a slow drift (never per-frame re-rolls).
# Read by InputBot._tick_aiming / _tick_panic. Bot INPUT quality only — no physics constant (INV-8). ---
var bot_aim_turn_rate: Array[float] = [3.0, 4.0, 5.5, 7.5, 10.0]  # rad/s by bot level L1..L5 (L1 ~170 deg/s readable wind-up)
var bot_aim_noise_drift: float = 1.6     # rad/s the aim-error / panic offset drifts toward its re-rolled target
var bot_aim_fire_tol: float = 0.22       # rad: offensive/dodge releases wait until the swept arrow is this close
var bot_aim_dodge_max: float = 0.40      # s: a dodge super fires by this even if the sweep hasn't arrived
var bot_aim_settle_max: float = 0.30     # s past the recovery fire time: a recovery super fires even mid-sweep
var bot_panic_reroll: float = 0.35       # s between panic-offset re-rolls (low recovery_skill flail = slow wander)
# WK-95 (folds in the WK-103 finding: the bot NORMAL-boost arrow flicked >30 deg per 30 fps frame on 7-13% of
# frames). The bot's flight stick is a human stick too: the emitted boost/drift aim rotates toward the wanted
# heading at <= this rate (rad/s, L1..L5), and the flight aim error drifts (bot_aim_noise_drift) instead of
# re-rolling as an instant jump. Neutral (stick released) stays instant. Recovery uses the same rate.
var bot_flight_turn_rate: Array[float] = [6.0, 7.0, 8.0, 10.0, 12.0]   # rad/s by bot level (12 rad/s = 23 deg/frame @30)
var bot_brake_turn_mult: float = 3.0     # WK-127: x bot_flight_turn_rate while the recovery BRAKES before a blast line
                                         # (a reflex yank: the 0.4 s L3 flip let trampoline launches reach the_ascent lid)
var bot_ceiling_lookahead: float = 0.35  # WK-108 enclosed courts: s of climb speed probed for an oncoming ceiling...
var bot_ceiling_margin: float = 120.0    # ...plus this many px; inside it a bot stops thrusting up and skims under

# --- WK-96 moving-hazard SMASH (owner 2026-11-14: pendulums "went right through a player and didnt smash
# them"). A pendulum ball moving at >= pendulum_smash_min_speed SMASHES on contact: knockback + hitstun +
# tumble via Player.receive_hazard_smash. NO fuel sting, NO damage escalation, NO kill credit (the hazard is
# not a Player; last_attacker untouched — a ring-out still credits whoever tagged you within the window).
# Contact is swept (capsule prev->current ball pos) so a fast ball can never skip a body between ticks.
# Below the speed gate (apex graze) contact stays the soft shove. Read by MovingHazard.gd. ---
var pendulum_smash_min_speed: float = 450.0    # px/s ball speed: at/above = SMASH, below = shove (apex hang)
var pendulum_smash_scale: float = 0.8          # impulse = ball speed * this, clamped to [min, max] below
var pendulum_smash_impulse_min: float = 1100.0
var pendulum_smash_impulse_max: float = 2200.0 # == smash_impulse_max: a wrecking ball hits like a centred super, never harder
var pendulum_smash_carry: float = 0.6          # weight of the ball's travel dir blended into the radial contact normal
var pendulum_sep_margin: float = 240.0         # victim leaves >= ball normal speed + this (never visibly passes through)
var pendulum_rehit_cd: float = 0.5             # s per-victim re-hit gate (one swing = one smash)
var pendulum_spin: float = 7.0                 # rad/s tumble kick on a pendulum smash (clip-spin readability)
# --- WK-96 pendulum presentation (owner: motion looked "very stiff and like poor quality") ---
var pendulum_trail_speed: float = 1300.0       # px/s: motion smear draws above this ball speed
var pendulum_trail_len: int = 9                # samples kept for the smear (one per physics tick pair)
var pendulum_whoosh_speed: float = 2100.0      # px/s: one whoosh cue per swing when the ball crosses this
var pendulum_hit_squash_time: float = 0.22     # s ball squash/recoil on a smash

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

# ==================================================================================================
# --- WK-25 KO CREDIT POP (gameplay-programmer, 2026-11-14 · audit D-02 parts 1+3) — separate block, kept at
# the END of the file so it never collides with other in-flight Tuning edits. A transient (<= 1.5 s) credit
# chip: it pops out of the WK-23 edge blast and flies into a corner card, which bumps. Owner ruling 2026-07-16
# (no persistent combat score) holds: the chip shows only the change ("+1" / "OOPS!" / "−1"), never a total,
# and nothing lingers. All times are REAL seconds (the KO hit-stop never stretches them). Read by
# src/ui/KOCreditPop.gd. Arrival = delay + in + hold + fly (0.82 s; the WK-25 accept bar is <= 1.0 s). ---
var ko_pop_delay: float = 0.10            # s after the KO before the chip appears (the blast core peaks at 0.07 s)
var ko_pop_in_time: float = 0.16          # s chip pop-in on the blast (scale 0.3 -> 1.15 -> 1.0)
var ko_pop_hold: float = 0.14             # s the chip sits on the blast before it flies
var ko_pop_fly_time: float = 0.42         # s flight to the card (eased, routed along the screen border)
var ko_pop_absorb_time: float = 0.12      # s a "+1" shrinks into the killer's card
var ko_pop_drop_time: float = 0.45        # s an "OOPS!" / "−1" falls off the victim's card
var ko_pop_drop_px: float = 150.0         # px (at 1080p) that fall travels
var ko_pop_start_inset_px: float = 112.0  # px (at 1080p) inside the KO edge where the chip spawns (on the starburst)
var ko_pop_fly_scale: float = 0.78        # chip scale on arrival at the card (shrinks in flight)
var ko_pop_card_bump: float = 0.16        # killer card scale overshoot when a "+1" lands
var ko_pop_card_bump_time: float = 0.30   # s
var ko_pop_card_wobble_deg: float = 7.0   # victim card wobble when an "OOPS!" / "−1" lands
var ko_pop_card_wobble_time: float = 0.40 # s

# ==================================================================================================
# --- WK-37 ghost goats (gameplay-programmer, 2026-11-14 · spec docs/specs/wk37a_ghost_goats_2026-11-14.md §8.1,
# art brief docs/briefs/ghost_goats_2026-11-14.md) — separate block at the END of the file. Eliminated BRAWL players
# become steerable ghosts (float / bleat / one telegraphed marshmallow puff cloud). Read by src/systems/GhostDirector.gd,
# src/entities/GhostGoat.gd, src/entities/GhostPuff.gd, src/core/GhostBot.gd. The rules option (ON / BAA ONLY / OFF) is
# MatchConfig.ghosts, not Tuning. ---
var ghost_spawn_delay: float = 0.6            # s elimination -> ghost (REAL s; > double_ko_window so an SD revive never un-ghosts)
var ghost_pop_in_time: float = 0.3            # s pop-in; controllable from its first frame
var ghost_max_speed: float = 600.0            # px/s float (> air drift 340; ~280-370 screen px/s at play zoom)
var ghost_hurry_mult: float = 1.5             # x speed while FLY is held (900 px/s)
var ghost_accel: float = 2400.0               # px/s^2 (full speed in 0.25 s)
var ghost_damp: float = 4.0                   # /s exponential settle with the stick released (~0.5 s)
var ghost_bob_amp: float = 6.0                # px visual bob (never a bounce, never squash)
var ghost_bob_hz: float = 0.8                 # Hz
var ghost_view_inset: float = 60.0            # SCREEN px the ghost stays inside the visible rect (divided by zoom)
var ghost_alpha: float = 0.40                 # root modulate.a
var ghost_alpha_near: float = 0.25            # within ghost_near_radius of any living goat (recede near fights)
var ghost_near_radius: float = 250.0          # px
var ghost_alpha_ease: float = 0.2             # s the 0.40 <-> 0.25 change eases over (never snaps; brief §3.5)
var ghost_scale: float = 0.85                 # x a living goat's body size
var ghost_puff_arm_delay: float = 1.0         # s after the ghost appears before the first puff arms
var ghost_puff_cooldown: float = 7.0          # s between puffs (one charge held at most)
var ghost_puff_max_per_stage: int = 3         # cap per ghost per stage
var ghost_puff_telegraph: float = 0.5         # s dotted, non-solid warning
var ghost_puff_life: float = 2.0              # s solid
var ghost_puff_fade: float = 0.25             # s non-solid exit
var ghost_puff_size: Vector2 = Vector2(180, 64)   # px collider (art bleeds a little, colliders stay exact)
var ghost_puff_sink_speed: float = 120.0      # px/s while solid / fading
var ghost_puff_tier: StringName = &"marshmallow"  # bounce tier (120 px apex, ~620 px/s, +13.3 fuel)
var ghost_puff_spawn_offset: Vector2 = Vector2(0, 70)  # px below the ghost body
var ghost_puff_fence_s: float = 2.0           # s K-2 HAUNTED window (last surface contact was a cloud)
var ghost_puff_refuels: bool = true           # §8.5 knob: false = cloud top still launches but refunds 0 fuel
var ghost_puff_nudge_max: float = 120.0       # px a cloud blocked by static geometry may be nudged upward before it duds
var ghost_puff_hush_pop: float = 0.2          # s max: a live cloud pops within this after a hush starts (K-5)
var ghost_bleat_min_interval: float = 0.4     # s between bleats (shared with WK-53)
var ghost_bleat_max_per_s: int = 3            # bleats per rolling second (D-15 rate limit)
var ghost_hush_at_match_point: bool = true    # K-5 switch
var ghost_legend_time: float = 3.0            # s the "GHOST! FLOAT · PUFF · BAA" line stays by the HUD card
var ghost_pip_full_time: float = 2.0          # s pip at full alpha after spawn
var ghost_pip_idle_after: float = 1.5         # s idle after which moving again brings the pip back to full alpha
var ghost_pip_dim_alpha: float = 0.5          # pip alpha otherwise
var ghost_orbit_radius: float = 60.0          # px puff-ready mini cloud orbit (world)
var ghost_orbit_period: float = 2.0           # s
var ghost_orbit_size: float = 44.0            # px mini cloud width (world)
var ghost_rim_scale: float = 1.08             # rim layer scale behind the body (brief E2)
var ghost_tail_sway_deg: float = 8.0          # tail sway at ghost_bob_hz (brief §3)
var ghost_tail_lean_deg: float = 25.0         # max tail lean opposite velocity.x
var ghost_word_rise: float = 40.0             # screen px the "BAAA!" puff rises over its life
var ghost_word_life: float = 0.7              # s
var ghost_word_alpha: float = 0.6             # ghost variant alpha
var bot_ghost_puff_rate_mult: float = 0.5     # bot ghosts puff at cooldown / this (14 s)
var bot_ghost_bleat_mean_interval: float = 8.0  # s Poisson mean, ambient bleats
var bot_ghost_react_bleat_p: float = 0.5      # chance to bleat 0.3-0.8 s after any KO
var bot_ghost_hover_dist: float = 500.0       # px from the living centroid
var bot_ghost_repick_min: float = 3.0         # s hover spot re-pick (uniform min..max)
var bot_ghost_repick_max: float = 5.0
var bot_ghost_spacing: float = 200.0          # px min distance between ghosts
var bot_ghost_drift_mult: float = 0.6         # x ghost speed (no hurry)
var bot_ghost_puff_lead_min: float = 250.0    # px ahead of the target's velocity
var bot_ghost_puff_lead_max: float = 350.0
var bot_ghost_puff_dy: float = 100.0          # px +- target height
var bot_ghost_puff_give_up: float = 3.0       # s chasing a placement before abandoning that puff
var bot_ghost_puff_lead_time: float = 1.5     # s before the charge is back that a bot ghost starts flying to its placement
var bot_ghost_puff_press_dist: float = 120.0  # px: a bot ghost presses PUFF within this of its placement (x2.5 after half the chase)
var ghost_stuck_secs: float = 6.0             # s zero displacement (away from a hover spot) = a stuck bot ghost (QA)

# --- WK-37d ghost goats follow-ups (gameplay-programmer, 2026-11-15 · moved out of the Ghost*.gd files) ---  # WK-37d
# Rim = a screen-space OUTLINE band (ghost.gdshader flat_mode), constant px at any zoom.  # WK-37d
var ghost_rim_quad_pad: float = 1.30          # rim quad vs the art (idle art is trimmed to its edges)  # WK-37d
var ghost_rim_px: float = 2.5                 # pale rim band, px at 1080p  # WK-37d
var ghost_rim_px_wide: float = 3.5            # ... on the widest camera  # WK-37d
var ghost_rim_gain: float = 2.0               # band alpha = root alpha x this (0.40 -> 0.80)  # WK-37d
var ghost_deep_px: float = 1.0                # thin outer line in the ghost's deep hue, px at 1080p  # WK-37d
var ghost_deep_gain: float = 0.8              # its alpha vs the band  # WK-37d
# Wide-camera compensation: 0 at zoom >= *_full, 1 at ghost_wide_zoom_max and below.  # WK-37d
var ghost_wide_zoom_full: float = 0.55        # size / rim / fill / flatten start here (WK-37d: was 0.46)  # WK-37d
var ghost_wide_alpha_zoom_full: float = 0.46  # ALPHA starts here: T9 holds 0.40 / 0.25 at the 0.46 reference zoom  # WK-37d
var ghost_wide_zoom_max: float = 0.30         # full compensation at / below this zoom  # WK-37d
var ghost_wide_ease: float = 2.0              # /s the wide factor eases at (no snap on a zoom jump)  # WK-37d
var ghost_max_vis_step: float = 0.0333        # s cap on the real-time visual step per frame (no alpha snap in slow-mo)  # WK-37d
var ghost_wide_alpha_mult: float = 1.3        # 0.40 -> 0.52 / 0.25 -> 0.325 at the widest  # WK-37d
var ghost_wide_scale: float = 0.95            # ghost body scale at the widest (living = 1.0)  # WK-37d
var ghost_flatten: float = 0.40               # body colour pulled toward the flat ghost hue  # WK-37d
var ghost_flatten_wide: float = 0.65          # ... on the widest camera  # WK-37d
var ghost_off_hue_flatten: float = 0.85       # saturated off-hue pixels (baked jetpack) pulled to the ghost hue  # WK-37d
var ghost_fill_sat: float = 0.3               # flat-fill target toward the saturated living colour  # WK-37d
var ghost_fill_sat_wide: float = 0.75         # ... on the widest camera  # WK-37d
# Bright-backdrop lift: the shader reads the backdrop luminance behind the ghost (mipmapped screen texture).  # WK-37d
var ghost_bright_alpha_max: float = 0.50      # pale backdrop: alpha lifted toward this (never above it)  # WK-37d
var ghost_bright_lum_lo: float = 0.62         # backdrop luma where the lift starts (mid backdrops: no lift)  # WK-37d
var ghost_bright_lum_hi: float = 0.82         # backdrop luma for the full lift  # WK-37d
var ghost_bright_lod: float = 4.0             # screen-texture mip level sampled (~16 px average)  # WK-37d
# Bot ghost spacing (T11), spawn spread, blocked-puff marker.  # WK-37d
var ghost_sep_radius_mult: float = 1.4        # separation push reaches spacing x this  # WK-37d
var ghost_pick_spacing_mult: float = 1.3      # hover / spawn spots keep spacing x this  # WK-37d
var ghost_spawn_spread_step: float = 130.0    # px spawn spread search ring step  # WK-37d
var ghost_blocked_color: Color = Color("#ff4a3d")   # blocked-puff outline colour  # WK-37d
var ghost_blocked_time: float = 0.5           # s the blocked marker shows  # WK-37d
var ghost_blocked_blink_hz: float = 8.0       # its blink rate  # WK-37d
var ghost_blocked_shake_px: float = 10.0      # world px "no" shake amplitude (decays)  # WK-37d
var ghost_blocked_shake_hz: float = 9.0       # shake rate  # WK-37d
var bot_ghost_chase_sep_weight: float = 4.0   # separation weight while a bot ghost chases a puff placement  # WK-37d
var bot_ghost_bleat_min_gap: float = 2.0      # s min gap between one bot ghost's bleats (WK-37d: was 3)  # WK-37d
# Ghost identity tag (R3): every ghost carries its P# / NAME+CPU pip, smaller and fainter than a living pip.  # WK-37d
var ghost_pip_scale: float = 0.9333           # 30 px label -> 28 px (the WK-18 floor; can't go smaller)  # WK-37d
var ghost_pip_full_alpha: float = 0.65        # spawn / moved-again alpha (< a living human's idle 0.70)  # WK-37d
var ghost_pip_near_alpha: float = 0.25        # when no placement keeps it off a living goat  # WK-37d

# --- WK-66a sports nets (docs/briefs/sports_nets_2026-11-15.md sections 3-5 + 8). Presentation only: none of  # WK-66a
# these touch a collider, the goal latch or the ball. Art facts (slice fractions, measured rows) live in  # WK-66a
# src/systems/SportsNetArt.gd next to the textures; these are the look/feel knobs.  # WK-66a
var net_mesh_tile_wpx: float = 128.0          # world px per 256 px mesh tile (= 32 wpx diamond cell)  # WK-66a
var net_dropshot_draw_w: float = 80.0         # Dropshot frame draw width (88 in the brief; 80 keeps the post bleed at 17 px)  # WK-66a
var net_tape_rise: float = 12.0               # top-tape top edge this far above the collider top  # WK-66a
var net_veil_alpha: float = 0.10              # Dropshot hole veil (white)  # WK-66a
var net_ripple_amp_px: float = 11.0           # ripple amplitude at full speed (wpx; AD F4: was 7)  # WK-66a
var net_ripple_speed_ref: float = 1900.0      # ball speed that gives the full amplitude  # WK-66a
var net_ripple_amp_min_frac: float = 0.15     # amplitude floor (fraction of full) for any counted contact  # WK-66a
var net_ripple_min_speed: float = 120.0       # contacts slower than this (resting / rolling) make no ripple  # WK-66a
var net_ripple_wavelength: float = 70.0       # wpx (AD F4: was 90)  # WK-66a
var net_ripple_time: float = 0.35             # s to decay to 0  # WK-66a
var net_ripple_travel: float = 900.0          # wpx/s the wave front runs along the net from the contact  # WK-66a
var net_ripple_falloff: float = 260.0         # wpx e-fold of the wave away from the contact  # WK-66a
var net_ripple_player_mult: float = 0.4       # goat body contact vs ball  # WK-66a
var net_ripple_goal_mult: float = 0.5         # goal near-miss (back post / tubes) vs Dropshot net  # WK-66a
var net_ripple_cooldown: float = 0.06         # s between ripples from the same net (resting contact guard)  # WK-66a
var net_tape_dip_px: float = 3.0              # top-tape dip on a top contact (frame offset, never a stretch)  # WK-66a
var net_tape_dip_time: float = 0.1            # s  # WK-66a
var net_tape_zone_px: float = 34.0            # contact within this of the collider top = a tape contact  # WK-66a
var net_tint_default: Color = Color("#FFFFFF")  # Dropshot per-court modulate when the court JSON has none  # WK-66a
var goal_frame_back_tuck: float = 6.0         # goal frame starts this far behind the back post inner face  # WK-66a
var goal_frame_mouth_bleed: float = 8.0       # mouth post cap reaches this far past the wall face  # WK-66a
var goal_net_depth_default: float = 150.0     # net depth when a goal_zone has no net_back_x  # WK-66a
var goal_mesh_white_mix: float = 0.30         # goal mesh = lerp(team, white, this)  # WK-66a
var goal_mesh_alpha: float = 0.95             # WK-66a
var goal_veil_alpha: float = 0.18             # team-colour hole veil  # WK-66a
var goal_front_veil_alpha: float = 0.22       # cords-only veil drawn over the ball (z 42)  # WK-66a
var goal_bulge_radius: float = 90.0           # wpx (Gaussian 2-sigma)  # WK-66a
var goal_bulge_peak: float = 20.0             # wpx peak push toward the back post  # WK-66a
var goal_bulge_freq_hz: float = 3.4           # damped spring: ~2 visible wobbles ...  # WK-66a
var goal_bulge_decay: float = 6.0             # ... settled (< 3 %) by goal_bulge_time  # WK-66a
var goal_bulge_time: float = 0.6              # s  # WK-66a
var goal_flash_hold: float = 0.08             # s the goal frame holds white on a score  # WK-66a
var goal_flash_fade: float = 0.4              # s back to team colour  # WK-66a
var dome_gap_glow_min: float = 88.0           # under-net gap (wpx) that lights the hem (a goat fits)  # WK-66a
var dome_gap_glow_color: Color = Color("#7FF6FF")   # additive, team-neutral  # WK-66a
var dome_gap_glow_hz: float = 2.0             # hem pulse rate  # WK-66a
var dome_gap_glow_a_min: float = 0.55         # WK-66a
var dome_gap_glow_a_max: float = 0.9          # WK-66a
var dome_gap_pool_size: Vector2 = Vector2(200.0, 56.0)   # floor light pool under the slot (puff_soft, NORMAL blend; AD F3)  # WK-66a
var dome_gap_pool_alpha: float = 0.6          # AD F3: was 0.35 additive (invisible on beige tiles)  # WK-66a
var dome_gap_fade: float = 0.15               # s glow fade in / out  # WK-66a
var net_tape_scale: float = 1.45              # AD F1: knobs+tape band redrawn at this x the body scale (uniform; range 1.35-1.6)  # WK-66a
var net_dropshot_tile_wpx: float = 80.0       # AD F2: Dropshot-only mesh tile (20 wpx cell, ~2.8 diamonds across; goals keep 128)  # WK-66a
var goal_hud_flash_alpha: float = 0.25        # AD follow-up 1: SportsHUD full-screen goal wash peak (was 0.45)  # WK-66a
var goal_hud_flash_in: float = 0.05           # s rise  # WK-66a
var goal_hud_flash_hold: float = 0.05         # s hold (was 0.5)  # WK-66a
var goal_hud_flash_out: float = 0.15          # s fade (total 0.25 s, was 0.9)  # WK-66a
var dome_gap_pool_drop: float = 0.4           # pool centre this x its height BELOW the floor top (lands on the tiles, not the gap)  # WK-66a

# WK-53b living-goat taunt (pad Y / keyboard J). Rate limit = the ghost numbers above (ghost_bleat_min_interval /
# ghost_bleat_max_per_s, shared per D-15). Read by src/ui/LivingCues.gd.  # WK-53b
var living_word_alpha: float = 1.0            # the living "BAAA!" puff draws at full alpha (ghosts: ghost_word_alpha)  # WK-53b

# WK-26 super-aim target "!" (audit D-07). Read by src/ui/LivingCues.gd.  # WK-26
var super_aim_target_corridor: float = 140.0  # wpx: a goat whose centre is this close to the aim ray is "targeted"  # WK-26
var super_aim_target_range: float = 1400.0    # wpx: ... and at most this far ahead of the aimer along it  # WK-26
var super_aim_target_keep: float = 1.25       # the marked goat keeps its "!" out to this x corridor / range (no strobing)  # WK-26

# --- WK-66b TRIALS ball goals (docs/briefs/trials_goal_2026-11-15.md sections 3, 5, 6). Display only: the trigger  # WK-66b
# rect, scoring and colliders are untouched. The gold cage reuses the WK-66a goal kit (SportsNetArt.setup_trials_goal).  # WK-66b
var trials_goal_color: Color = Color("#FFB21E")        # frame gold (gradient-map target) + confetti layer 0  # WK-66b
var trials_goal_mesh_white_mix: float = 0.55           # mesh = lerp(gold, white, this) ~ #FFDC9A  # WK-66b
var trials_goal_mesh_alpha: float = 0.95               # WK-66b
var trials_goal_shade_color: Color = Color("#3B241B")  # pocket shade (mesh hole veil), chocolate not navy  # WK-66b
var trials_goal_shade_alpha: float = 0.45              # WK-66c: was 0.16 (sky/hills showed through; now reads as a pocket)  # WK-66b
var trials_goal_snap_max: float = 80.0                 # DOC value: max platform-face gap a display edge may snap across (level-designer rule)  # WK-66b
var trials_goal_floor_sink: float = 10.0               # DOC value: net_bottom_y = floor top - this (tube rests on the turf)  # WK-66b
var trials_goal_mouth_bleed: float = 0.0               # mouth cap outer edge vs the mouth plane (Rocketball uses 8; 0 keeps caps off a pit edge)  # WK-66b
var trials_goal_glow_color: Color = Color("#FFD86B")   # solved glow (additive puff behind the cage)  # WK-66b
var trials_goal_glow_a_min: float = 0.35               # WK-66b
var trials_goal_glow_a_max: float = 0.50               # WK-66b
var trials_goal_glow_hz: float = 1.0                   # alpha breathing rate (never scale)  # WK-66b
var trials_goal_glow_fade_in: float = 0.2              # s  # WK-66b
var trials_goal_glow_pad: float = 320.0                # glow = frame size + this, both axes (WK-66c: was 120)  # WK-66b
var trials_goal_idle_period: float = 2.6               # s between idle "the net breathes" ripples (attract cue)  # WK-66b
var trials_goal_idle_amp: float = 3.0                  # wpx idle ripple amplitude (mesh only)  # WK-66b

# --- WK-39 mouse cursor policy (CC-2.4 / CC-12.2). Read by src/core/InputRouter.gd.  # WK-39
var cursor_show_motion: float = 4.0           # px of real mouse motion (accumulated) before a hidden cursor comes back  # WK-39

# --- WK-120 sports FORMAT auto default. Read by src/ui/HerdLobby.gd (_sports_format).  # WK-120
var sports_auto_2v2_humans: int = 2           # joined humans at which an AUTO FORMAT (never set in RULES) reads 2V2  # WK-120

# --- CD4-01 Brawl circuit rotation = a SESSION DECK per circuit. Read by src/modes/BrawlMode.gd; decks live in  # CD4-01
# GameConfig.circuit_decks (process lifetime: survive REMATCH / RESTART / quit-to-menu, gone on app restart).  # CD4-01
# OFF (false) = legacy: ordered circuits replay their authored order from arena 1 every match, RANDOM ROTATION  # CD4-01
# reshuffles its bag every match, draw circuits draw a fresh subset every play.  # CD4-01
var circuit_session_deck: bool = true         # CD4-01 master switch (false = legacy, see above)  # CD4-01
var circuit_deck_interleave: bool = true      # CD4-01 ordered circuits: alternate authored MILD half / WILD half  # CD4-01
var circuit_deck_opener: bool = true          # CD4-01 the session's FIRST deck of a circuit opens on authored arena 1  # CD4-01

# --- WK-85a Trials SKY DROP (ArenaRenderer meadow stack, mode "trials" / level knob "sky_drop"). Display only.  # WK-85a
# Below the painted horizon: hills' own bottom colour -> haze -> sky -> deep, px below the hills ramp start.  # WK-85a
var trials_drop_haze: Color = Color("#EAF8FF")     # cloud-level mist (hills dissolve into it)  # WK-85a
var trials_drop_sky: Color = Color("#5ED0FB")      # open air below the islands (sky_grass_day ~0.8 row)  # WK-85a
var trials_drop_deep: Color = Color("#159CF0")     # deep blue far below (sky_grass_day mid-sky tone)  # WK-85a
var trials_drop_haze_px: float = 100.0             # WK-85a (WK-162: 160 -> 100, bluer air right under the islands)
var trials_drop_sky_px: float = 300.0              # WK-85a (WK-162: 650 -> 300, open-sky blue reads under the lowest decks)
var trials_drop_deep_px: float = 1300.0            # WK-85a
var trials_drop_bank_y: float = 0.0                # front cloud row centre, px below the ramp start  # WK-85a
# WK-162: 150 -> 0 (UP, at the hills' base): the bank sat flush under the decks on Islands Void ("soft floor"); lowering it  # WK-162
# instead parked it ON Flight School 4's pads (parallax 0.18 layer: deck-vs-bank height depends on each level's camera).  # WK-162
var trials_drop_bank_row_gap: float = 40.0         # back row sits this much higher  # WK-85a (WK-162: 70 -> 40, thinner)
var trials_drop_bank_y_jitter: float = 60.0        # WK-85a (WK-162: 80 -> 60)
var trials_drop_bank_spacing: float = 420.0        # px between bank clouds (per row)  # WK-85a (WK-162: 300 -> 420, broken row)
var trials_drop_bank_scale_min: float = 0.26       # cloud art is 854x515  # WK-85a (WK-162: 0.36 -> 0.26)
var trials_drop_bank_scale_max: float = 0.46       # WK-85a (WK-162: 0.72 -> 0.46)
var trials_drop_bank_back_tint: Color = Color("#CFE6F7")  # WK-85a
var trials_drop_deep_clouds: int = 7               # small faint clouds deeper in the drop (depth cue)  # WK-85a
var trials_drop_deep_cloud_y_min: float = 500.0    # WK-85a
var trials_drop_deep_cloud_y_max: float = 1100.0   # WK-85a
var trials_drop_deep_cloud_alpha: float = 0.55     # WK-85a

# --- WK-52 flair-unlock banner card (CD3-07). Read by src/ui/HerdLobby.gd (_play_flair_celebration).  # WK-52
var unlock_card_delay: float = 0.5            # s after lobby entry before the card drops in  # WK-52
var unlock_card_in: float = 0.35              # s drop-in from above the screen (TRANS_BACK)  # WK-52
var unlock_card_hold: float = 3.2             # s fully shown (was a ~1.4 s outline-text toast)  # WK-52
var unlock_card_out: float = 0.3              # s slide back up  # WK-52
# --- WK-113 sports controls legend docked top-centre (SP-11). Read by src/ui/ControlsLegend.gd (_dock_top).  # WK-113
var sports_legend_top: float = 128.0          # px from the screen top to the gold rule chip (just under the score bug)  # WK-113
var sports_legend_goal_h: float = 62.0        # px gold rule row height  # WK-113
var sports_legend_gap: float = 12.0           # px between the rule row and the chip strip  # WK-113
var sports_legend_strip_h: float = 64.0       # px chip strip height  # WK-113

# --- WK-85 tall arenas (ArenaRenderer). Display only.  # WK-85
var themed_body_full_height: bool = true       # themed (rock/steel/stone) bodies draw >= collider height (no art-less band)  # WK-85
var painting_horizon_min_off: float = -350.0   # painted horizon sits at most this far ABOVE the play-rect centre (wpx, negative = up)  # WK-85
var themed_body_stretch_max: float = 1.6     # taller than this x canonical (64/128) -> canonical strip + tinted tiled fill  # WK-85
var themed_fill_brightness: float = 2.0      # grey earth tile brightness (its mean luma is ~0.25) before the theme tint  # WK-85
var themed_fill_contrast: float = 1.0        # WK-85

# --- WK-29 device-aware glyphs (CC-1.6). Read by src/ui/ControlsLegend.gd (_fit_rows).  # WK-29
var legend_edge_margin: float = 80.0          # px kept clear at each screen edge; a wider chip strip moves SUPER to a second row  # WK-29
var legend_bottom_edge_margin: float = 290.0  # px each side for the BOTTOM-docked strip: clear of the 240 px corner HUD cards  # WK-29

# --- WK-37f ghosts never rest hidden inside terrain (CD3-08). Read by src/systems/GhostDirector.gd + src/core/GhostBot.gd.  # WK-37f
var ghost_terrain_clear: bool = true           # master switch (false = pre-WK-37f: ghosts may park inside platforms)  # WK-37f
var ghost_terrain_clear_mult: float = 0.9      # x the drawn ghost body radius that must sit clear of solid geometry  # WK-37f
var ghost_terrain_push_speed: float = 520.0    # px/s ease out to the nearest clear spot (< ghost_max_speed: a held stick still passes through)  # WK-37f
var ghost_terrain_steer_in_dot: float = -0.3   # stick . exit-dir below this = "driving into the platform" -> no push (intangible while steered)  # WK-37f
var ghost_terrain_search_step: float = 16.0    # px ring step of the nearest-clear-spot search  # WK-37f
var ghost_terrain_search_max: float = 420.0    # px search radius; nothing clear inside the view within it -> leave the ghost be  # WK-37f

# --- WK-28a lobby disconnect grace (CC-3.5). Read by src/ui/HerdLobby.gd + src/ui/LobbySlot.gd.  # WK-28a
var lobby_disconnect_grace: float = 10.0      # s a lost pad's seat stays DISCONNECTED (goat + colour kept) before it empties  # WK-28a
var lobby_disc_bust_tint: Color = Color(0.42, 0.40, 0.40, 0.85)  # greyed bust modulate on a DISCONNECTED panel  # WK-28a
# --- WK-83 lobby "who are we waiting on" nudge + TV safe area. Read by HerdLobby.gd / LobbySlot.gd / MenuScreen.gd.  # WK-83
var lobby_wait_flash: float = 0.45            # s a still-PICKING panel's gold status-bar plate takes to fade out after a READY player presses GO early  # WK-83
var lobby_wait_flash_color: Color = Color(1.0, 0.82, 0.25)  # DISCONNECTED panel's countdown-text flash tint when a READY player presses GO early (PICKING panels light a gold plate)  # WK-83
var tv_safe_margin: float = 0.05              # share of screen height kept clear top + bottom (TV overscan): header chips >= 54 px, footers <= 1026 px at 1080p  # WK-83

# --- WK-139 end screens share one button kit (UX4-06 / UX4-21). Read by src/ui/FocusRow.gd + src/ui/SportsVictory.gd.  # WK-139
var end_btn_unfocused_alpha: float = 1.0      # modulate alpha of unfocused end-screen buttons (was 0.8: grey "disabled" over the scrim)  # WK-139
var sports_victory_scrim_alpha: float = 0.7   # SportsVictory chocolate scrim alpha (Brawl's 0.55 left dark courts' goats readable)  # WK-139
var sports_victory_win_tint_alpha: float = 0.28   # winning team's non-MVP rows: team-colour well tint  # WK-139
var sports_victory_lose_tint_alpha: float = 0.14  # losing team's rows: lighter team-colour well tint (was untinted)  # WK-139

# --- WK-145 lobby nits: unlock-card flair icon (UX4-26). Read by src/ui/FlairSwatch.gd (HerdLobby unlock card).  # WK-145
var unlock_icon_sky: Color = Color("#3A2F5B")  # the icon disc's backdrop: twilight sky, so the glowing flair (streak / flame / pop / banner) pops on it  # WK-145
var unlock_icon_goat_px: float = 66.0         # px the tiny goat wearing the flair is drawn at inside the 128 px disc  # WK-145

# --- WK-149 horizontal TV safe area for header corner chips. Read by src/ui/MenuScreen.gd (_fit_safe_area).  # WK-149
var tv_safe_margin_x: float = 0.05            # share of screen WIDTH kept clear left + right: corner chips x >= 96, <= 1824 at 1920  # WK-149

# --- WK-141 controls legend: first frame + sports legend out of the ball's band (UX4-10/11). Read by src/ui/ControlsLegend.gd.  # WK-141
var sports_legend_touch_alpha: float = 0.4    # sports legend alpha after the first live ball touch (removed at the first goal)  # WK-141
var sports_legend_touch_fade: float = 0.3     # s the dip to sports_legend_touch_alpha takes  # WK-141

# --- WK-44 Options RUMBLE + SCREEN SHAKE (CC-3.6). Read by src/core/Settings.gd, src/core/InputRouter.gd, src/ui/OptionsScreen.gd.  # WK-44
var screen_shake_low_mult: float = 0.45       # SCREEN SHAKE LOW: x every camera trauma add (OFF = 0, FULL = 1)  # WK-44
var rumble_attacker_mult: float = 0.5         # a smash's attacker feels this share of the victim's rumble (the victim gets it full)  # WK-44
var rumble_blast_reach: float = 1.25          # an explosion rumbles human pads within this x its blast radius  # WK-44
var rumble_test_pulse: Vector3 = Vector3(0.5, 0.6, 0.18)   # weak, strong, seconds: the pulse when RUMBLE is switched ON in Options  # WK-44
# --- WK-142 Trials end celebration (UX4-08). Read by src/ui/TrialsVictory.gd.  # WK-142
var trials_victory_arm: float = 1.3           # s from present() until the row accepts a press (never below end_screen_arm)  # WK-142
var trials_victory_scrim_alpha: float = 0.8   # chocolate scrim alpha behind the celebration  # WK-142
var trials_victory_hop: float = 46.0          # px each cheering goat hops  # WK-142
var trials_victory_next_iris: float = 0.24    # s the cream iris takes to cover before NEXT CIRCUIT loads  # WK-142
# --- WK-119 sports team identity on the in-world tags (UX4-09 / CC-8.3). Read by src/ui/PlayerPip.gd + src/ui/PlayerPips.gd.  # WK-119
var sports_pip_team_dress: bool = true         # sports tags wear a team-colour rim + home-side cap (false = pre-WK-119 goat-colour tags)  # WK-119
var sports_pip_rim_px: float = 5.0             # px team-colour band around the tab (inside the rim's own chocolate outline)  # WK-119
var sports_pip_cap_px: float = 14.0            # px extra rim on the team's home side (RED left, BLUE right): the colour-blind-safe shape cue  # WK-119
var sports_cpu_pip_persist: bool = true        # a sports CPU's "NAME CPU" tag stays all match (Brawl keeps the intro-only CPU tag)  # WK-119
var sports_cpu_pip_alpha: float = 0.70         # a sports CPU tag's settled alpha in play (= pip_idle_alpha for humans)  # WK-119
var sports_pip_cpu_gap: int = 6                # px between a sports CPU tag's NAME and its small "CPU" (one row)  # WK-119
# --- WK-146 / WK-147 tags keep clear of HUD cards + off-screen bubbles (UX4-23 / UX4-24). Read by src/ui/PlayerPips.gd.  # WK-146
var pip_card_gap: float = 6.0                  # px a living pip / ghost tag keeps from a HUD corner card  # WK-146
var pip_bubble_gap: float = 6.0                # px a living pip keeps from an off-screen bubble's rim  # WK-147
var pip_avoid_hysteresis_px: float = 12.0      # px the top side must clear by before a card/bubble-flipped pip flips back up  # WK-146
# --- WK-60 / WK-60b arena / court / circuit select: focused-card preview region (UX4-12 / UX4-25). Read by src/ui/ArenaSelect.gd.  # WK-60
var arena_preview_swap_time: float = 0.16       # s the preview art + name pop takes when focus moves to another card  # WK-60
var arena_preview_art_pop: float = 0.92         # scale the preview art pops up from on a focus move (1 = no pop)  # WK-60
var arena_preview_rays_alpha: float = 0.45      # alpha of the slow-turning warm rays behind the preview art  # WK-60
var arena_preview_rays_spin: float = 5.0        # deg/s the rays turn (0 = still)  # WK-60
var arena_preview_locked_tint: Color = Color(0.55, 0.53, 0.58, 1.0)  # preview art modulate while a LOCKED card is focused  # WK-60
var arena_select_card_size: Vector2 = Vector2(400, 300)  # px shelf card size under the preview (was 460x340 with no preview)  # WK-60
# --- WK-148 sports match start: hold the iris white until the court camera settles (UX4-27). Read by src/ui/MatchCover.gd + src/ui/ShellRoot.gd.  # WK-148
var match_cover_on: bool = false               # court confirm -> the iris white holds over the new match until the camera has eased out  # WK-148
                                              # OFF since WK-148b: the camera now snaps to the court framing, nothing to hide (code kept)  # WK-148b
var match_cover_sports_only: bool = true       # only sports modes (their camera snaps to CAM_MAX_ZOOM, then eases out to the court)  # WK-148
var match_cover_zoom_tol: float = 0.015        # camera zoom within this share of the court-framing zoom counts as settled (1.5 % = ~14 px at a 1080p edge)  # WK-148
var match_cover_pos_tol: float = 6.0           # world px the camera centre may be off the framing centre and still count as settled  # WK-148
var match_cover_settle_frames: int = 2         # consecutive settled frames before the cover lifts  # WK-148
var match_cover_fade: float = 0.16             # s the white fades out once the camera is settled  # WK-148
var match_cover_max_hold: float = 1.2          # s of match time after which the cover lifts regardless (never strands a white screen)  # WK-148
var match_cover_load_timeout: float = 20.0     # s after the iris with no match scene current -> the cover gives up  # WK-148
# --- WK-150 living tags avoid each other when goats bunch (sports 4P tags). Read by src/ui/PlayerPips.gd.  # WK-150
var pip_tag_avoid: bool = true                 # a living tag whose side overlaps an earlier-placed living tag tries the other side of its goat, else dims  # WK-150
var pip_tag_gap: float = 4.0                   # px two living tags keep between them  # WK-150
var pip_tag_hysteresis_px: float = 16.0        # px the preferred (above) side must clear by before an avoiding tag returns to it  # WK-150
var pip_tag_hold: float = 0.4                  # s a tag keeps its side after switching (no flip-flop while goats jostle)  # WK-150
var pip_tag_overlap_alpha: float = 0.4         # alpha cap of a tag that cannot clear an earlier tag on either side (it also draws behind)  # WK-150
var pip_tag_dim_fade: float = 0.12             # s the dim in / out takes  # WK-150
var pip_tag_claim_alpha: float = 0.25          # a living tag fainter than this (a fading CPU intro tag) claims no room  # WK-150

# --- WK-135 phase 1: bumpers kick, never cradle (docs/specs/wk135_bumper_min_bounce_2026-11-15.md §4.1/§4.4). INV-11 on  # WK-135
# EVERY surface: a bumper contact leaves at >= max(sqrt(2|g| x bumper_min_rebound_height), bumper_min_rebound_floor) along  # WK-135
# the face normal (392 px/s flat, 310 in Singularity's well); above that the x0.86 ricochet is untouched. Read by  # WK-135
# BounceResolver.resolve_bumper(). Phase 3 (WK-128 (b) refund gates ON + sports ball refuel) is the block below.  # WK-135
# INVARIANT #9 still holds: bumper_restitution < 1; the kick adds energy only below 456 px/s incoming (bounded at 392), never  # WK-135
# a speed pump.  # WK-135
var bumper_min_rebound_height: float = 48.0   # px kick floor on every bumper face (= min_bounce_height, own constant). 0 = OFF  # WK-135
var bumper_min_rebound_floor: float = 250.0   # px/s absolute kick floor for weak / zero fields (= soft_bump_min)  # WK-135
# --- WK-135 phase 2 (spec §4.2 C1-C6, §5 BR-135). Read by Player._wk128_contact_pays / _wk128_track_faces and InputBot.  # WK-135
# Bumper faces are classed by LOCAL gravity at the contact (up = -g): n.up > bumper_floor_dot = FLOOR (block tops, every  # WK-135
# round core), n.up < -0.5 = CEILING (no refund, unchanged), else WALL. FLOOR bumper faces pay under the TIER rules (re-arm  # WK-135
# max(refund_rearm_min_px, refund_rearm_frac x launch h), no hard-hit gate); WALL faces keep WK-128 F2 + bumper_px. A face  # WK-135
# that paid >= refund_rearm_timeout ago re-arms however little you moved (liveness valve: no goat stranded at 0 fuel).  # WK-135
# NOTE: with the WK-128 (b) gates OFF (refund_gates_on = false) every contact pays, so C1-C4 are inert; only the  # WK-135
# refunds_bumper_floor/_wall telemetry split shows. OFF values (= phase 1 exactly):  # WK-135
# bumper_floor_pays_as_tier = false, refund_rearm_timeout = 0.0, InputBot.wk135_no_pin = false.  # WK-135
# INVARIANTS: #15 bumper_min_rebound_height (48) < refund_rearm_min_px (60): kick hops never pay twice by distance (only  # WK-135
#       through the valve).  # WK-135
#   #16 fuel_per_bumper / refund_rearm_timeout = fuel_per_bounce / refund_rearm_timeout = 13.3 < natural trampoline income  # WK-135
#       (20 / 1.16 = 17.2) < normal_boost_drain() (28.6). Re-check if the timeout, refund amounts, gravity or trampoline move.  # WK-135
var bumper_floor_dot: float = 0.5             # n.up above this = FLOOR-class bumper face (= the underside test's 0.5)  # WK-135
var bumper_floor_pays_as_tier: bool = true    # C2: FLOOR bumper faces pay under tier rules. false = all bumper faces use the wall rules  # WK-135
var refund_rearm_timeout: float = 1.5         # C4 s: a face that paid this long ago re-arms (liveness valve). 0.0 = OFF. Invariant #16  # WK-135
# BR-135b bot pin breaker (spec §5): >= bot_pin_contacts contacts with ONE bumper face within bot_pin_window while thrusting  # WK-135
# into it (aim.n < bot_pin_into_dot) -> release boost for one reaction tick and re-plan with that face excluded for  # WK-135
# bot_pin_exclude_s (no refuel target, no thrust into it: the boost aim slides along it). Switch: InputBot.wk135_no_pin.  # WK-135
var bot_pin_contacts: int = 4                 # contacts with one bumper face (spec 4; fallback ladder 3)  # WK-135
var bot_pin_window: float = 0.5               # s window for those contacts  # WK-135
var bot_pin_into_dot: float = -0.5            # aim . face normal below this = thrusting into the face  # WK-135
var bot_pin_exclude_s: float = 1.0            # s the pinned face stays excluded (no target, no thrust into it)  # WK-135
var bot_pin_avoid_px: float = 260.0           # px off the excluded face inside which a boost aim into it is slid along it  # WK-135
var bot_pin_turn_mult: float = 3.0            # x bot_flight_turn_rate while that slide redirects the stick (= bot_brake_turn_mult)  # WK-135
# --- WK-135 phase 3 (spec §4.3 S1-S4, §4.4, §9 phase 3): the WK-128 (b) refund gates ON with the spec values (WK-128 block:  # WK-135
# refund_rearm_frac 0.9, refund_rearm_min_px 60, refund_rearm_bumper_px 200, bumper_refund_min_speed 900 on WALL-class faces,  # WK-135
# bumper_refund_cooldown 0) behind ONE master switch, plus the sports BALL refuel. Read by Player (gate_* helpers below,  # WK-135
# grant_fuel) and SportsMode (_on_ball_touched). QA arm without a Tuning edit: env GB_WK135_GATES=1/0 and GB_WK135_BALL=1/0  # WK-135
# (read once at startup in _ready below; headless runs and record_match.ps1 inherit the env).  # WK-135
# S1-S3 BALL REFUEL: each ACCEPTED live touch (Ball.touched: 0.12 s ball cooldown, live only) grants the toucher  # WK-135
# sports_touch_fuel through Player.grant_fuel(amount, &"ball"), at most once per player per sports_touch_fuel_cd. A touch made  # WK-135
# in hitstun pays nothing (dry-reflect doctrine). No supercharge, relight or arm-state effect. SportsMode only (Trials puzzle  # WK-135
# balls never refuel). Telemetry (Player.wk128): refunds_ball, ball_fuel, ball_fuel_blocked_cd, ball_fuel_blocked_stun.  # WK-135
# INVARIANT #17: sports_touch_fuel / sports_touch_fuel_cd (20 / 1.0 = 20 fuel/s) < normal_boost_drain() (28.6): the ball  # WK-135
#       source can't be farmed; the only "farm" is hitting the ball, which is the game. Invariant #2 holds: one touch re-arms a super.  # WK-135
# WK-175: the master now means "the wk175_gate_set scope" (1 WR walls only / 2 WS / 3 FULL = this phase-3 block + deck fix);  # WK-175
# Player reads the gates ONLY through Tuning.gate_rules() (WK-175 block at the end of the file); the gate_* helpers below are legacy.  # WK-175
var refund_gates_on: bool = false             # OFF until the phase-3 A/B (director). MASTER: WK-128 (b) gates at the spec values. false = every contact pays (pre-phase-3)  # WK-135
var sports_touch_refuel: bool = true          # ON (phase-3 A/B: human starved share 0.27 -> 0.14; gates stay OFF). S1 switch: ball touches refuel in Sports. false (or sports_touch_fuel 0) = OFF  # WK-135
var sports_touch_fuel: float = 20.0           # S1 fuel per accepted live touch (= one trampoline bounce). 0 = OFF  # WK-135
var sports_touch_fuel_cd: float = 1.0         # S1 s per player between paying touches (caps the source at 20/s < drain 28.6). Inv. #17  # WK-135

func _ready() -> void:  # WK-135: QA arm overrides from the environment ("1" ON, "0" OFF, unset = the values above)
	var g: String = OS.get_environment("GB_WK135_GATES")  # WK-135
	if g != "":  # WK-135
		refund_gates_on = g == "1"  # WK-135
	var b: String = OS.get_environment("GB_WK135_BALL")  # WK-135
	if b != "":  # WK-135
		sports_touch_refuel = b == "1"  # WK-135
	var w109: String = OS.get_environment("GB_WK109")  # WK-109: QA arm override for wk109_power_shot (record_match.ps1 inherits the env)
	if w109 != "":  # WK-109
		wk109_power_shot = w109 == "1"  # WK-109
	var w167: String = OS.get_environment("GB_WK167")  # WK-167: QA arm override for wk167_spend_last_fuel
	if w167 != "":  # WK-167
		wk167_spend_last_fuel = w167 == "1"  # WK-167
	var w164: String = OS.get_environment("GB_WK164")  # WK-164: QA arm override for wk164_guard_hold_s
	if w164 != "":  # WK-164
		wk164_guard_hold_s = wk164_guard_hold_on if w164 == "1" else 0.0  # WK-164
	var w161b: String = OS.get_environment("GB_WK161B")  # WK-161b: QA arm override for wk161b_chase_route
	if w161b != "":  # WK-161b
		wk161b_chase_route = w161b == "1"  # WK-161b
	_wk169_env(OS.get_environment("GB_WK169"))  # WK-169: SHOWDOWN QA arms (see the WK-169 block at the end of the file)
	if g == "1" and OS.get_environment("GB_WK175").strip_edges() == "":  # WK-175: the old phase-3 arm keeps meaning "gates on every face" (FULL)
		wk175_gate_set = 3  # WK-175
	_wk175_env(OS.get_environment("GB_WK175"))  # WK-175: wins over GB_WK135_GATES (see the WK-175 block at the end of the file)
	_wk175c_env_modes(g, OS.get_environment("GB_WK175"), OS.get_environment("GB_WK175_MODES"))  # WK-175c: an env-armed gate covers every mode (QA arms)

## WK-169: apply a GB_WK169 arm string (comma list; see the WK-169 block). "" = leave every switch as authored.  # WK-169
func _wk169_env(v: String) -> void:  # WK-169
	if v.strip_edges() == "":  # WK-169
		return  # WK-169
	showdown_telemetry = true  # WK-169: any arm (incl. the A0 control) logs the spectator telemetry
	for raw in v.to_lower().split(",", false):  # WK-169
		var tok: String = raw.strip_edges()  # WK-169
		if tok == "drop" or tok == "a1" or tok == "a4" or tok == "all" or tok == "1":  # WK-169
			showdown_drop = true  # WK-169
		if tok == "ghost" or tok == "a2" or tok == "a4" or tok == "all" or tok == "1":  # WK-169
			showdown_ghost_boost = true  # WK-169
		if tok == "rowdy" or tok == "a3" or tok == "all" or tok == "1":  # WK-169
			showdown_rowdy = true  # WK-169
	var frame_only: bool = v.to_lower().split(",", false).has("frame")  # WK-169: "frame" = the state + dim / rim, no lever
	showdown_enabled = frame_only or showdown_drop or showdown_ghost_boost or showdown_rowdy  # WK-169: 0 / a0 / tel = telemetry only

## WK-135 phase 3: the EFFECTIVE WK-128 (b) gate values (0 = that gate OFF), with the master switch folded in.  # WK-135
func gate_rearm_frac() -> float:  # WK-135
	return refund_rearm_frac if refund_gates_on else 0.0  # WK-135
func gate_rearm_min_px() -> float:  # WK-135
	return refund_rearm_min_px if refund_gates_on else 0.0  # WK-135
func gate_rearm_bumper_px() -> float:  # WK-135
	return refund_rearm_bumper_px if refund_gates_on else 0.0  # WK-135
func gate_bumper_min_speed() -> float:  # WK-135
	return bumper_refund_min_speed if refund_gates_on else 0.0  # WK-135
func gate_bumper_cooldown() -> float:  # WK-135
	return bumper_refund_cooldown if refund_gates_on else 0.0  # WK-135
## WK-135 S1: fuel a sports ball touch grants (0 = the source is OFF).  # WK-135
func ball_touch_fuel() -> float:  # WK-135
	return sports_touch_fuel if sports_touch_refuel else 0.0  # WK-135

# --- WK-28b in-match controller disconnect (CC-3.4) + connect / disconnect toasts. Read by src/ui/DeviceWatch.gd,  # WK-28b
# src/ui/DisconnectOverlay.gd and src/ui/DeviceToast.gd.  # WK-28b
var disconnect_cpu_level: int = 3             # bot level a seat plays at after RESUME WITHOUT P# when the match's CPU difficulty is MIXED (else that difficulty)  # WK-28b
var disconnect_input_arm: float = 0.45        # s after the overlay opens before any press counts (a mashed boost A can't take over / start a hold)  # WK-28b
var disconnect_pop_time: float = 0.18         # s the overlay's drop-pop takes  # WK-28b
var disconnect_portrait_tint: Color = Color(0.50, 0.48, 0.48, 1.0)  # lost player's portrait modulate while their pad is gone (white again once it is back)  # WK-28b
var device_toast_hold: float = 2.6            # s a connect / disconnect toast stays fully shown  # WK-28b
var device_toast_fade: float = 0.22           # s a toast takes to drop in / fade out  # WK-28b
var device_toast_max: int = 3                 # toasts stacked at once (the oldest leaves early)  # WK-28b

# --- WK-131 Rocketball KICKOFF GATES (spec docs/specs/wk131_kickoff_rule_2026-11-15.md §7, brief docs/briefs/kickoff_gate_2026-11-15.md §9).  # WK-131
# Each soccer goal mouth gets a ball-only candy-stripe gate from the stage load until sports_gate_open_s of live-ball time  # WK-131
# after GO. Read ONLY by src/modes/SportsMode.gd and src/entities/KickoffGate.gd (+ AudioManager cue levels). Brawl never reads it.  # WK-131
var sports_kickoff_rule: int = 1              # 0 = legacy (no gates: exactly the pre-WK-131 kickoff), 1 = KICKOFF GATES, 2 = LIVE BALL (open when both teams touched)  # WK-131
var sports_gate_open_s: float = 3.5           # s of live ball after GO when both gates open (rule 1). 3.5 = the spec's pre-registered step, adopted after the A/B (docs/audit/2026-11-15_wk131_ab.md)  # WK-131
var sports_gate_warn_s: float = 0.6           # s of warning before the open (badge/ring swing, pole lift, wind-up ticks)  # WK-131
var sports_gate_retract_s: float = 0.2        # s the pole slides up into the top socket, ENDING at the open (visual; collision drops at the open)  # WK-131
var sports_gate_bounce: float = 0.6           # ball-vs-gate restitution (a dead thud keeps a blocked shot in the attacking third)  # WK-131
var sports_gate_spit_speed: float = 450.0     # px/s outward pop for a ball resting on the gate at the open (< the 833 px/s touch floor, 583 with WK-109 ON; not a touch)  # WK-131 # WK-109
var sports_gate_spit_reach: float = 40.0      # px ball surface to gate face that counts as "resting on it" at the open  # WK-131
var sports_gate_thickness: float = 48.0       # px gate collider thickness (> 2 ticks of ball travel at the 2400 cap; CCD is the main guard)  # WK-131
var sports_gate_pop_cooldown: float = 0.5     # s between "NOT YET!" pops on one gate  # WK-131
var sports_gate_ooh_speed: float = 1500.0     # px/s ball impact that also cues the crowd "ooh" (a real shot)  # WK-131
var sports_live_fallback_s: float = 3.0       # rule 2: s after GO the gates open anyway if both teams have not touched  # WK-131
# visual knobs (brief §9)  # WK-131
var sports_gate_bar_w: float = 52.0           # wpx drawn pole width (the collider is sports_gate_thickness; 2 wpx bleed each face)  # WK-131
var sports_gate_stripe_period: float = 44.0   # wpx candy-stripe period, measured across the 45 deg stripes (band = half)  # WK-131
var sports_gate_badge_wpx: float = 64.0       # wpx padlock badge diameter  # WK-131
var sports_gate_ring_r: float = 44.0          # wpx drain ring centreline radius  # WK-131
var sports_gate_ring_band: float = 12.0       # wpx drain ring gold band (plus a 3 wpx chocolate outline each side)  # WK-131
var sports_gate_flex_amp: float = 12.0        # wpx peak bow of the pole on a full-speed (>= 2000 px/s) hit  # WK-131
var sports_gate_flex_sigma: float = 70.0      # wpx Gaussian width of the bow around the contact point  # WK-131
var sports_gate_flex_time: float = 0.25       # s the bow's damped spring takes to settle (first half-wobble 0.12 s)  # WK-131
var sports_gate_flash_time: float = 0.06      # s the pole holds white on a hit (badge: x sports_gate_badge_flash)  # WK-131
var sports_gate_flash_fade: float = 0.12      # s the hit flash fades back  # WK-131
var sports_gate_fx_min_speed: float = 150.0   # px/s contact speed below which a gate touch makes no FX / sound  # WK-131
var sports_gate_warn_hz_from: float = 3.0     # Hz warning brightness swing (and wind-up ticks) at the start of the warning  # WK-131
var sports_gate_warn_hz_to: float = 8.0       # Hz ... accelerating to this at the open (flash-safety cap 8 Hz)  # WK-131
var sports_gate_warn_lift: float = 10.0       # wpx the pole lifts out of the bottom socket during the warning (collider unchanged)  # WK-131
var sports_gate_warn_shake: float = 3.0       # wpx badge shake during the warning  # WK-131
var sports_gate_scroll_max: float = 2.5       # stripe periods/s the barber-pole scroll reaches at the open  # WK-131
var sports_gate_drop_in: bool = true          # the pole drops out of the top socket at stage intro (visual only)  # WK-131
var sports_gate_drop_time: float = 0.15       # s the drop-in takes  # WK-131
var sports_gate_pop_wpx: float = 34.0         # wpx cap height of the "NOT YET!" pop  # WK-131

# --- WK-136 near-empty re-light (CD3-04a, docs/audit/2026-11-15_cd3_playthrough.md §5 G2). A billed mid-air re-light (WK-128 R2)  # WK-136
# always leaves at least this much THRUST TIME in the tank: fuel = max(fuel - bill, min(fuel, max(boost_relight_min_left,  # WK-136
# normal_boost_drain() x this))). 0.105 s = 3.0 fuel = 12.6 ticks at 120 tps (Accept: 0 billed re-lights under 12 ticks). A press  # WK-136
# with less than 3.0 fuel in the tank is not billed at all (it burns what is there, as before). Feather check: the cap only bites  # WK-136
# below 8.7 fuel (bill 5.71 + 3.0), so the whole saving is ~1 bill per episode inside the last 9 % of a tank; tut_02/03 feather  # WK-136
# still fails (verified rendered 2026-11-15). Invariant #14 untouched (bill_max x drain still 5.71 above the floor). Read by  # WK-136
# Player._wk128_fresh_press only.  # WK-136
var boost_relight_min_thrust: float = 0.105   # s of thrust a billed re-light always leaves. 0.0 = OFF (WK-128's 1.0 fuel floor alone)  # WK-136

# --- WK-20d Brawl pacing rungs R2-R4 (docs/specs/wk20d_brawl_pacing_2026-11-15.md §4.2-4.4). BRAWL ONLY (Player checks the  # WK-20d
# runner's GameMode id; Sports / Trials / Flight School never see them). Each is an independent A/B switch, OFF by default:  # WK-20d
# OFF = exactly the pre-WK-20d game. Counters (Player.wk128 dict, wk20d_*): supers, supers_fired_protected, truce_locked_presses,  # WK-20d
# truce_unlock_buffered_arms (must be 0), whiffs, fumbles, whiff_brakes, whiff_brake_reached750, whiff_brake_aborted, reserves,  # WK-20d
# reserve_fuel, reserve_over_fire (must be 0), reserve_locked_presses, reserve_gate_violations (must be 0).  # WK-20d
# NOT BUILT (spec: required before ADOPTION, not before measurement): the sputter puff + "pfft" (R3), the HUD reserve sliver (R4).  # WK-20d
# The padlock / dry click (R2, R4) shipped with WK-20e (block at the END of this file).  # WK-20e
# INVARIANT (§4.4): super_whiff_reserve < fuel_per_bounce (15 < 20). Because it is >= super_boost_min_fuel (10) the re-arm gate is  # WK-20d
# REQUIRED; Player turns it on whenever super_whiff_reserve > 0, so the two can never be split.  # WK-20d
var brawl_spawn_super_lock: bool = true       # R2 SPAWN TRUCE: no super arms while you blink (spawn-protected); a press is dropped,  # WK-20d
                                              # never buffered. ADOPTED ON (WK-20e, DECISIONS 2026-11-15 ladder ruling); false = legacy  # WK-20e
var super_whiff_brake_speed: float = 0.0      # R3 WHIFF BRAKE: px/s a super that touched nothing (no smash branch, no surface)  # WK-20d
                                              # bleeds to when its super_active_time window ends. 0 = OFF; test 700 (< boost cap 800)  # WK-20d
var super_whiff_brake_time: float = 0.15      # R3: s the bleed takes (linear |v| cap v0 -> brake speed; scales only, never reverses)  # WK-20d
var super_whiff_reserve: float = 0.0          # R4 FUMBLE RESERVE: a super that landed no smash returns min(this, fuel at fire) when its  # WK-20d
                                              # window ends; that fuel can't arm a super until the next paying contact. 0 = OFF; test 15  # WK-20d

# --- WK-65 painted court cards (docs/briefs/court_cards_2026-11-15.md §7). The 1280x800 badges' frame opening came out  # WK-65
# ~2.13:1 (the brief planned ~1.90), so the card's plain cover crop shows a cut-off top rim and the bottom rim around a small  # WK-65
# interior. ArenaSelect._court_card_tex crops toward the badge centre by this factor before the card's COVERED stretch, so  # WK-65
# the ~352x160 art slot lands on the painted interior plus thin red / blue side rims. The preview always shows the whole badge.  # WK-65
var court_card_zoom: float = 1.16             # x crop toward the badge centre on court shelf cards (1.0 = plain cover crop)  # WK-65
var court_card_dy: float = 0.0                # fraction of badge height the card crop shifts down (+) / up (-) after the zoom  # WK-65

# --- WK-148b sports stage-start camera snap (replaces the WK-148 white MatchCover). Read by PartyMatch._snap_camera_stage_start.  # WK-148b
# true: a mode with fixed framing (SPORTS court) snaps straight to its settled court zoom/centre at every stage start (match  # WK-148b
# start, each goal's STAGE_INTRO, Pause->RESTART, REMATCH). false: the old CAM_MAX_ZOOM snap + ease-out. Brawl/Trials never read it.  # WK-148b
var cam_sports_start_snap: bool = true        # WK-148b

# --- WK-131 kickoff gate hit flash vs the padlock badge (blind read: the badge ghosted out for 2-3 frames under the 0.06 s white).  # WK-131
var sports_gate_badge_flash: float = 0.0      # share of the pole's hit flash the badge takes (0 = pole only, badge stays readable; 1 = old)  # WK-131

# --- WK-20e R2 spawn-truce FEEDBACK (spec docs/specs/wk20d_brawl_pacing_2026-11-15.md §4.2: "the aim arrow shows locked (greyed,  # WK-20e
# with a small padlock glyph) and a soft dry click plays"). A super press DROPPED by the truce (or the R4 re-arm gate) emits  # WK-20e
# EventBus.super_lock_pressed; LivingCues hangs the padlock badge (assets/world/sports/gate_badge_locked.png, screen space so it  # WK-20e
# keeps its size at any zoom and does not blink with the goat) beside the head, AudioManager plays the dry click, and Player greys  # WK-20e
# its aim arrow while the button is held. The badge stays while the press is held (plus a short hold after a tap) and vanishes  # WK-20e
# the frame the lock ends. No HUD change (spec names none). Presentation only: nothing here touches the sim.  # WK-20e
var super_lock_cue: bool = true               # false = the truce still drops the press, but silently (no badge / click / grey arrow)  # WK-20e
var super_lock_badge_px: float = 48.0         # badge diameter in canvas px at 1080p (the goat is ~40-80 px across at play zoom)  # WK-20e
var super_lock_badge_hold: float = 0.45       # s the badge stays after a tapped (released) locked press  # WK-20e
var super_lock_click_db: float = -11.0        # dry click volume (a soft tick: under the bounce, far under a smash)  # WK-20e
var super_lock_click_pitch: float = 1.6       # pitch on the Kenney impactPlank crack (2.2 kHz centroid, 40 ms) -> a small dry "tk"  # WK-20e
var super_lock_click_gap: float = 0.09        # s per-goat rate limit on the click (a mash can't machine-gun it)  # WK-20e
var super_lock_arrow_color: Color = Color(0.60, 0.60, 0.66, 0.80)   # the greyed aim arrow while a locked press is held  # WK-20e

# --- WK-20e Meadow Carousel soft-lock (audit docs/audit/2026-11-15_wk20d_r1.md bug 1, INV-11 "no standable ground"). A moving  # WK-20e
# deck authored WITHOUT a bounce tier ("" / "firm" / "none": every vehicle cart + the carousel hay deck) used to be a solid deck you  # WK-20e
# simply rested on: no bounce, no fuel, so an empty-tank goat was stranded and two stranded goats never ended the stage. true: such a  # WK-20e
# deck bounces at min_bounce_height (48 px) and pays the matching bounce refund (fuel_per_bounce x sqrt(48 / 270) = 8.4). 48 px keeps  # WK-20e
# the goat's centre inside MovingPlatform's 118 px rider band, so the sticky carry still holds it (a marshmallow 120 px hop would  # WK-20e
# leave the band and drop riders off a fast cart mid-swing). Tiered decks are unchanged. false = the legacy firm deck.  # WK-20e
var moving_deck_min_bounce: bool = true       # WK-20e

# --- WK-108b sports bots round 2 (BACKLOG WK-108b + CD3-03 + WK-131 QA-131-2). Read ONLY by SportsMode.gd (bot hooks) and  # WK-108b
# InputBot.gd (objective re-plan + strike-guard reflex). Brawl / Trials never read it. Every switch OFF = the WK-108 / WK-131  # WK-108b
# bots exactly. SportsMode.wk108b_arm(true) (or env GB_WK108B=1 at match configure) turns on the whole ON arm.  # WK-108b
# K1 sticky keeper: one keeper per team, designated when a threat starts (all-bot team: the bot nearest its mouth; with a human  # WK-108b
# teammate: the bot, while the human is nearer the ball), held until the threat has been gone release_s; its teammate stays chaser.  # WK-108b
var wk108b_sticky_keeper: bool = false        # K1 (A/B switch)  # WK-108b
var wk108b_keeper_release_s: float = 0.9      # K1: s the threat must stay gone before the keeper steps out to cover  # WK-108b
var wk108b_keeper_third_hyst: float = 0.12    # K1: while a keeper is held, "own third" widens by this share of the axis  # WK-108b
var wk108b_keeper_stray_px: float = 1100.0    # K1: a keeper this far from its mouth (knocked away) loses the role  # WK-108b
var wk108b_keeper_challenge: float = 300.0    # K1: the keeper leaves the mouth only for a ball this close (WK-108: 400)  # WK-108b
var wk108b_keeper_early_frac: float = 0.5     # K1: a keeper is also designated / held while the ball is inside this share of the  # WK-108b
var wk108b_keeper_early_speed: float = 250.0  # K1: ... axis AND moving at my goal at >= this px/s (gets home before the third)  # WK-108b
# K1b QA-131-2 (supporter home when the WK-131 gates open, bar >= 50 % within 300 px): s BEFORE the open that the kickoff keeper  # WK-108b
# window starts. 0 = WK-131's BOT_GATE_RETURN_LEAD_S 0.8. Coherent with sports_gate_open_s (window = open - lead .. open + 1.0).  # WK-108b
var wk108b_gate_return_lead: float = 0.0      # K1b (0 = today)  # WK-108b
var wk108b_gate_return_lead_on: float = 2.5   # K1b: the value wk108b_arm(true) sets (gates 3.5 s -> home from 1.0 s after GO)  # WK-108b
# K2 fast-ball re-plan: InputBot re-plans the sports objective every replan_s while the ball is fast or near (no extra dodge rolls).  # WK-108b
var wk108b_fast_replan: bool = false          # K2 (A/B switch)  # WK-108b
var wk108b_replan_s: float = 0.08             # K2  # WK-108b
var wk108b_replan_ball_speed: float = 450.0   # K2: px/s ball speed that counts as fast  # WK-108b
var wk108b_replan_near_px: float = 450.0      # K2: ... or the ball within this of the bot  # WK-108b
# K3 GOAL-MOUTH CLEAR RULE (CD3-03): per-frame reflex - a bot never drives into the ball toward its own goal while the ball is in  # WK-108b
# its own half; it swerves to the ball's goal side and brakes (a graze clears it away, the next plan lines up from the goal side).  # WK-108b
var wk108b_strike_guard: bool = true          # K3 ON (A/B: all-bot CPU own goals 25.9 -> 17.9 %, final-2 own goals 10 -> 4)  # WK-108b
var wk108b_guard_frac: float = 1.0            # K3: active while the ball is within this share of the axis from my goal (1.0 = whole  # WK-108b
                                              # pitch: a trackback overtaking a ball already running at my goal hit it in from 2000 px)  # WK-108b
var wk108b_guard_horizon_s: float = 0.30      # K3: s to contact at the current closing speed that trips it (L3 turns ~0.2 s / 90 deg)  # WK-108b
var wk108b_guard_cos: float = 0.30            # K3: contact normal . (ball -> own goal) at or above this = an own-goal push  # WK-108b
var wk108b_guard_turn_mult: float = 3.0       # K3/K5: x bot_flight_turn_rate while the guard steers (= bot_pin_turn_mult; a human yanks)  # WK-108b
var wk108b_guard_brake: float = 0.5           # K3: escape aim = perpendicular - this x max(1, closing / boost cap) x the contact normal  # WK-108b
# K4 no goal-mouth stacking: with a home keeper, the chaser's track-back point stays mouth_gap from the mouth.  # WK-108b
var wk108b_mouth_spacing: bool = false        # K4 (A/B switch; needs K1)  # WK-108b
var wk108b_mouth_gap: float = 420.0           # K4  # WK-108b
# K5 Dropshot side discipline: targets never past the net (net_margin from the line), the chaser waits ready_back into its half  # WK-108b
# while the ball is over there, and a bot brakes before the net (stopping time net_brake_s) / flies home if across.  # WK-108b
var wk108b_dropshot_side: bool = true         # K5 ON (director: net crossings 34 -> 0 unforced in recording)  # WK-108b
var wk108b_net_margin: float = 110.0          # K5  # WK-108b
var wk108b_ready_back: float = 380.0          # K5  # WK-108b
var wk108b_back_court: float = 200.0          # K5: with the ball over the net the supporter covers this far behind its half's centre...  # WK-108b
var wk108b_back_court_up: float = 520.0       # K5: ...this far above the court bottom (front/back split, no shared spot)  # WK-108b
var wk108b_net_brake_s: float = 0.30          # K5  # WK-108b
var wk108b_net_recover_clear: float = 400.0   # K5: during a danger recovery the net brake applies only this far above the court bottom  # WK-108b
# --- WK-154 Brawl spawn padlock wears the kickoff gate's draining ring (CD4-04: it said "locked", not for how long) ---  # WK-154
var super_lock_ring_hold: bool = true         # a dropped truce press keeps the badge up until the ring empties (false = WK-20e held / tap-hold only)  # WK-154
var super_lock_ring_r: float = 27.0           # canvas px ring centreline radius at 1080p (gate ring 44 wpx around a 64 wpx badge, scaled)  # WK-154
var super_lock_ring_band: float = 7.0         # canvas px gold band  # WK-154
var super_lock_ring_outline: float = 2.0      # canvas px chocolate outline each side of the band  # WK-154
var super_lock_ring_badge_px: float = 40.0    # padlock disc size inside the ring (0 = keep super_lock_badge_px); whole badge ~65 px  # WK-154
var super_lock_open_time: float = 0.22        # s the unlock beat (open padlock pops 1.3x, flies up, fades) takes; 0 = just vanish  # WK-154
var super_lock_open_fly: float = 22.0         # canvas px the open padlock rises over the beat  # WK-154
# --- WK-155 kickoff-gate cues stay visible when they matter (CD4-05) ---  # WK-155
var sports_gate_open_call: bool = true        # (a) each gate pops "OPEN!" (open padlock glyph) at full alpha at the open, every kickoff  # WK-155
var sports_gate_open_call_wpx: float = 46.0   # (a) wpx cap height of the OPEN! call (the hit's NOT YET! is sports_gate_pop_wpx 34)  # WK-155
var sports_gate_open_call_life: float = 1.0   # (a) s the OPEN! call stays (rise, hold, 0.16 s fade)  # WK-155
var sports_gate_open_call_y: float = -0.2     # (a) call height as a share of the mouth span from its centre (- = up)  # WK-155
var sports_gate_open_call_layer: int = 2      # (a) CanvasLayer of the OPEN! call (world-following): over the name tags (1), under KO blast (5) / HUD (10)  # WK-155
var sports_gate_badge_anchor: float = 1.0     # (b) badge + ring along the mouth: -1 top, 0 centre (WK-131), +1 bottom (on the bottom socket)  # WK-155
var sports_gate_badge_margin: float = 6.0     # (b) wpx kept between the ring's outer edge and the mouth end  # WK-155
var sports_gate_badge_z: int = 39             # (b) badge + ring z: above goats, under the ball (40); WK-131 drew them at the gate's -1  # WK-155
var sports_gate_stripe_a: Color = Color("#FFF6EA")   # (c) pole stripe A: warm white (was cream #FFF3D6)  # WK-155
var sports_gate_stripe_b: Color = Color("#D9262E")   # (c) pole stripe B: barrier red (was honey gold #F2B33D, read as the gold goal trim)  # WK-155

# --- WK-161 BR-135 pin breaker inside a radial gravity well (Singularity). Read by src/core/InputBot.gd.  # WK-161
# Source: docs/audit/2026-11-15_wk135_p2_ab.md (BR-135 ON raised Singularity stuck episodes 1.46x, p = 0.002).  # WK-161
# ON: while the bot / the pinned contact is inside a GravitySource radius, the pin breaker neither EXCLUDES the pinned  # WK-161
# face (BR-135b) nor SLIDE-STEERS off it (_pin_avoid, BR-135c), so wells revert to the BR-135-OFF brain; flat arenas  # WK-161
# are unchanged (no gravity source there). OFF (false) = current (BR-135 everywhere). QA arm: env GB_WK161=1 / 0  # WK-161
# overrides this at bot creation (record_match.ps1 / headless runs inherit the env; no Tuning edit needed).  # WK-161
var wk161_radial_pin_skip: bool = false       # WK-161 master switch  # WK-161
var wk161_radial_keep_release: bool = true    # WK-161 (ON only): a well pin still drops boost for one reaction tick  # WK-161
var wk161_radial_skip_target: bool = false    # WK-161 (ON only): also skip BR-135a (refuel target class) in a well  # WK-161
var wk161_dump_max: int = 24                  # WK-161 per-bot per-stage episode dump cap (motion_health.wk161_dump)  # WK-161

# --- WK-116 PRESSURE NETS (docs/specs/wk116_long_rally_2026-11-15.md). Rocketball (soccer courts) only; read by  # WK-116
# src/systems/PressureNets.gd (spawned per stage by SportsMode, freed with the level on the next kickoff reload, so every  # WK-116
# kickoff starts with base mouths), GoalZone, SportsNetArt, SportsHUD and AudioManager. Clock = Ball.ball_clock() (live ball,  # WK-116
# game time: pauses with hit-stop / pause / the disconnect overlay).  # WK-116
# INVARIANTS (spec §6): t1 - warn > sports_gate_open_s (3.5): pressure and gates never overlap (runtime also holds pressure until  # WK-116
# every gate is open); t2 > t1; the grown mouth's bottom edge stays above the court's floor-bouncer apex centre (floor top -  # WK-116
# apex_body_r - the floor tier's bounce height, measured per court at runtime; growth below it moves to the top edge).  # WK-116
var sports_pressure_rule: int = 1             # 0 = OFF (exactly today's game: no node is ever made), 1 = PRESSURE NETS (ON: DECISIONS 2026-11-16 A/B ruling)  # WK-116
var sports_pressure_t1_s: float = 30.0        # s of live ball with no goal -> STEP 1 "PRESSURE!" (mouths x (1 + grow1))  # WK-116
var sports_pressure_t2_s: float = 40.0        # s -> STEP 2 "MAX PRESSURE!" (mouths x (1 + grow2)) + the crowd clap-chant until the goal  # WK-116
var sports_pressure_warn_s: float = 3.0       # s of anticipation before t1 (trim pulse + crowd swell; no geometry change)  # WK-116
var sports_pressure_grow1_frac: float = 0.25  # mouth height growth at step 1 (CENTER 300 -> 375 px)  # WK-116
var sports_pressure_grow2_frac: float = 0.75  # mouth height growth at step 2 (CENTER 300 -> 525 px, bottom clamped at the apex). A/B: +50 % missed, +75 % shipped  # WK-116
var sports_pressure_slide_s: float = 0.30     # s the posts take to retract (ease-out); colliders move with the art  # WK-116
var sports_pressure_back_margin: float = 100.0   # wpx the back post spans past each mouth edge (WK-122: the 60 px slot stays sealed)  # WK-116
var sports_pressure_min_post_px: float = 80.0    # wpx: a post never retracts shorter than this (it slides into the ceiling / floor)  # WK-116
var sports_pressure_apex_body_r: float = 44.0    # wpx goat radius in the floor-bouncer apex check (Player.BODY_RADIUS)  # WK-116
var sports_pressure_art_bleed: float = 4.0       # wpx the post art overhangs its collider ends (ArenaRenderer h + 8): kept when cropping  # WK-116
# feedback (spec §5)  # WK-116
var sports_pressure_trim_warn_a: Color = Color("#FFF3D6")   # anticipation pulse: cream ...  # WK-116
var sports_pressure_trim_warn_b: Color = Color("#FF8A1F")   # ... -> orange (also the step-1 trim)  # WK-116
var sports_pressure_trim_hot_a: Color = Color("#E3261B")    # step 2: red ...  # WK-116
var sports_pressure_trim_hot_b: Color = Color("#FFB23A")    # ... flickering to hot amber (the heat shimmer)  # WK-116
var sports_pressure_trim_alpha: float = 0.85  # max alpha of the trim overlay on the team-tinted cage tubes (outline + gloss survive)  # WK-116
var sports_pressure_warn_hz: float = 1.5      # anticipation pulse rate  # WK-116
var sports_pressure_hot_hz: float = 3.0       # step-2 pulse rate  # WK-116
var sports_pressure_heat_alpha: float = 0.32  # step-2 additive heat glow over each cage (puff_soft), flickering  # WK-116
var sports_pressure_word_hold: float = 0.9    # s the PRESSURE! / MAX PRESSURE! word holds (top-centre, over neither mouth)  # WK-116
var sports_pressure_word1_color: Color = Color("#FFC93C")   # team-neutral gold  # WK-116
var sports_pressure_word2_color: Color = Color("#FF6A2A")   # red-gold  # WK-116
var sports_pressure_word2_size: int = 76      # px MAX PRESSURE! font size (BannerTop is 58)  # WK-116
var sports_pressure_word_stack_wait: float = 0.5   # s the word waits after another top banner (spec: never overlap)  # WK-116
var sports_pressure_chevron_s: float = 1.0    # s the up/down chevrons flash on each post  # WK-116
var sports_pressure_chevron_wpx: float = 64.0 # wpx chevron width  # WK-116
var sports_pressure_shake: float = 0.25       # camera trauma per step (FEEL §5.2 Light), x Options SCREEN SHAKE  # WK-116
var sports_pressure_rumble_weak: float = 0.2  # per pulse, every human pad (InputRouter.rumble_player; Options RUMBLE gates it)  # WK-116
var sports_pressure_rumble_strong: float = 0.35   # WK-116
var sports_pressure_rumble_dur: float = 0.08  # s per pulse  # WK-116
var sports_pressure_rumble_gap: float = 0.12  # s between the two pulses (the "ka-CHUNK")  # WK-116
# audio (AudioManager; levels sit in the WK-79b mix: goal stinger +4, crowd +2, whistle -2, clonk -12..-3, thrust -12)  # WK-116
var sports_pressure_bed_db_lo: float = -16.0  # dB crowd murmur bed at the start of the anticipation (file -18 LUFS)  # WK-116
var sports_pressure_bed_db_hi: float = -10.0  # dB after the +6 dB swell over warn_s; held until the goal  # WK-116
var sports_pressure_chant_db: float = -4.0    # dB crowd clap-chant loop from step 2 until the goal (-9 measured barely detectable in the WK-93 audio.wav)  # WK-116
var sports_pressure_clunk_db: float = -4.0    # dB step-1 ka-CHUNK (per mouth; step 2 is +3 dB and lower)  # WK-116
var sports_pressure_ooh_db: float = -9.0      # dB step-1 crowd "OOOH" (rewardCheer slowed)  # WK-116
var sports_pressure_fade_out_s: float = 0.25  # s bed + chant fade at the goal (the normal goal roar takes over)  # WK-116

# --- WK-156 controls legend never hides a goat (CD4-06). Read by src/ui/ControlsLegend.gd (_dim_under_goats).  # WK-156
var legend_goat_dim: bool = true              # a legend chip a living goat / its tag overlaps fades out of the way (false = pre-WK-156)  # WK-156
var legend_goat_overlap_alpha: float = 0.15   # alpha of a chip with a goat or tag under it (the goat reads through)  # WK-156
var legend_goat_overlap_fade: float = 0.12    # s the dim in / out takes  # WK-156
var legend_goat_pad_px: float = 6.0           # px the chip rect is grown by for the overlap test  # WK-156
var legend_goat_hysteresis_px: float = 14.0   # extra px a DIMMED chip tests with (no flicker on the edge)  # WK-156
# --- WK-158 Trials nits (CD4-07 c / e). Read by src/ui/TrialsHUD.gd.  # WK-158
var trials_panel_split_movers: bool = true    # the objective panel treats a focus point with no goal node on it (the puzzle ball) as a mover  # WK-158
var trials_panel_mover_cost: float = 0.0      # per px^2 slot cost of covering a mover (0 = the panel never chases the ball; goals keep COST_GOAL 20)  # WK-158
var trials_victory_hide_goats: bool = true    # the in-world goats hide while the TrialsVictory celebration is up (back on PLAY AGAIN)  # WK-158
# --- WK-159 Trials net catches the ball on SOLVED! (CD4-08). Read by src/entities/GoalZone.gd (style "trials" zones only).  # WK-159
var trials_net_catch: bool = true             # false = pre-WK-159 (the ball keeps its speed and can ricochet out of the cage)  # WK-159
var trials_net_catch_keep: float = 0.4        # x the ball's velocity at the latch  # WK-159
var trials_net_catch_damp: float = 3.5        # 1/s velocity decay while caught  # WK-159
var trials_net_catch_gravity: float = 0.5     # x the ball's gravity while caught (it sinks into the net, not drops through)  # WK-159
var trials_net_catch_wall_keep: float = 0.3   # x speed a ball heading out through a net side keeps when it turns back in  # WK-159
var trials_net_catch_push: float = 6.0        # 1/s ease back inside for a ball already past a net side (velocity = gap x this)  # WK-159
var trials_net_catch_s: float = 4.0           # s the catch lasts (the course change frees the ball first; gravity restored after)  # WK-159
# --- WK-31 HUD card danger + stocks + labelled fuel (R-06). Read by src/ui/PlayerCard.gd / MatchHUD.gd / FuelIcon.gd.  # WK-31
# Danger = Player.damage_level (0 / 1 / 2; launch x dmg_launch_mult, full heal after dmg_heal_time). Three distinct card  # WK-31
# states that never rely on hue alone: a WORD sticker (HURT! / DANGER!) with a draining heal bar, a thicker border, and  # WK-31
# motion (a kick on every qualifying hit, a sustained tremble only at Lv2). BRAWL only: MatchHUD drives it; TrialsHUD's  # WK-31
# cards never call it and Sports has no cards.  # WK-31
var hud_danger_on: bool = true                # false = the pre-WK-31 card (no danger state)  # WK-31
var hud_danger_words: PackedStringArray = PackedStringArray(["", "HURT!", "DANGER!"])   # sticker text by damage_level  # WK-31
var hud_danger_tag_fill: Array[Color] = [Color(0, 0, 0, 0), Color("#ffc93f"), Color("#e32020")]   # sticker fill: light amber / dark crimson (luminance differs too)  # WK-31
var hud_danger_border: Array[Color] = [Color(0.231373, 0.141176, 0.105882), Color("#ff8a1f"), Color("#e32020")]   # card border colour by level  # WK-31
var hud_danger_border_w: Array[int] = [4, 6, 8]   # px card border width by level (the non-hue thickness cue)  # WK-31
var hud_danger_flush: Color = Color("#e32020")    # the crimson glow that bleeds in from the card edge (a full wash muddied green/yellow cards to brown)  # WK-31
var hud_danger_flush_lv1: Vector2 = Vector2(0.45, 0.20)   # (mid, amp) alpha of the edge glow at Lv1 (gentle throb)  # WK-31
var hud_danger_flush_lv2: Vector2 = Vector2(0.75, 0.25)   # (mid, amp) alpha at Lv2 (deep, never clears)  # WK-31
var hud_danger_glow_px: Array[int] = [0, 12, 22]   # px how far the edge glow bleeds in, by level (Lv2 reaches further: a non-hue size cue)  # WK-31
var hud_danger_lv1_hz: float = 1.5            # wash throb at Lv1 (= dmg_pulse_slow_hz, the goat's own pulse rate)  # WK-31
var hud_danger_lv2_hz: float = 2.5            # wash throb at Lv2 (slower than the goat's 4 Hz: a card-sized 4 Hz flash reads as flicker)  # WK-31
var hud_danger_kick_deg: float = 7.0          # deg peak card rotation of the hit kick (decays over kick_s)  # WK-31
var hud_danger_kick_s: float = 0.4            # s the kick lasts  # WK-31
var hud_danger_kick_scale: float = 0.10       # +x scale punch at the start of a kick  # WK-31
var hud_danger_tremble_deg: float = 1.4       # deg sustained card tremble while at Lv2 (0 = none)  # WK-31
var hud_danger_tremble_hz: float = 7.0        # tremble rate  # WK-31
var hud_danger_tag_tilt_deg: float = -4.0     # deg the sticker sits tilted (mirrored on right-hand cards)  # WK-31
var hud_danger_tag_overlap: float = 10.0      # px the sticker overlaps the card's inner edge (clear of the fuel gauge)  # WK-31
var hud_danger_tag_overhang: float = 10.0     # px the sticker pokes past the card's centre-facing side (more when it has to clear the stock tab)  # WK-31
var hud_danger_tag_stock_gap: float = 2.0     # px min gap between the stock tab and the sticker when both show  # WK-31
var hud_danger_heal_bar: bool = true          # the sticker's bar drains as the 8 s heal runs out (re-fills on a re-hit)  # WK-31
var hud_danger_rehit_frac: float = 0.05       # heal-frac jump that counts as a re-hit at the same level (kick again)  # WK-31
var hud_stocks_min_lives: int = 2             # stock heads show when RULES LIVES >= this  # WK-31
var hud_stocks_max_lives: int = 9             # ...and <= this (Sports / Trials run 99 lives: never a stock row)  # WK-31
var hud_stock_icon_px: float = 36.0           # px each stock head  # WK-31
var hud_stock_lost_alpha: float = 0.35        # lost stock = dark silhouette at this alpha (shape + luminance, not hue)  # WK-31
var hud_stock_tuck: float = 8.0               # px the stock tab tucks under the card's inner edge  # WK-31
var hud_stock_inset: float = 14.0             # px from the card's screen-edge side  # WK-31
var hud_stock_lose_s: float = 0.45            # s the lost head's pop-and-darken takes  # WK-31
var hud_fuel_icon: bool = true                # flame glyph at the left of the fuel gauge  # WK-31
var hud_fuel_icon_px: float = 28.0            # px flame height (overhangs the 16 px gauge row)  # WK-31
# --- WK-109 Rocketball power shot dynamic range (SP-07; spec docs/specs/wk109_power_shot_2026-11-15.md). Read by  # WK-109
# src/entities/Ball.gd (only on a ball SportsMode enabled: the soccer ball; Trials / Dropshot balls never), and by  # WK-109
# src/systems/AudioManager.gd (power cue routing). OFF = today, byte-identical (impulse 500, no knee, cap 2400, SFX bus).  # WK-109
# QA arm without a Tuning edit: env GB_WK109=1/0 (read once in _ready above; headless runs and record_match.ps1 inherit it).  # WK-109
var wk109_power_shot: bool = false            # MASTER. true = soft floor + DRIVE knee + POWER SHOT tier on the soccer ball  # WK-109
var wk109_touch_impulse: float = 350.0        # touch floor impulse when ON (legacy Ball.BALL_TOUCH_IMPULSE 500): 583 px/s from rest  # WK-109
var wk109_touch_knee: float = 1600.0          # px/s soft-knee start for non-power touches (tanh squeeze up to the 2400 cap); 0 = no knee (arm A1)  # WK-109
var wk109_power_speed: float = 2800.0         # px/s POWER exit speed = ball cap in the window. Keep < 48 px x 120 Hz / 2 ticks = 2880 (gate margin)  # WK-109
var wk109_power_hold_s: float = 0.8           # s at the power cap after a POWER touch  # WK-109
var wk109_power_decay_s: float = 0.3          # s the cap eases power_speed -> 2400 after the hold  # WK-109
var wk109_trail_min_speed: float = 2450.0     # px/s streak shows only above this, inside the power window (normal cap + 50)  # WK-109
var wk109_pop_cooldown_s: float = 1.5         # s match-wide minimum gap between "POWER SHOT!" pops  # WK-109
var wk109_pop_cap_wpx: float = 40.0           # wpx cap height of the POWER SHOT! word (NOT YET! 34 < this < OPEN! 46)  # WK-109
var wk109_trail_len_s: float = 0.06           # s of travel the streak covers (length = speed x this, ~170 wpx at 2800)  # WK-109
var wk109_trail_fade_s: float = 0.1           # s the streak fades when it switches off on its own (a blunting touch kills it on the frame)  # WK-109
var wk109_power_duck_db: float = -3.0         # dB SFX-bed duck under the power cue (KO duck is -4 for 0.3 s)  # WK-109
var wk109_power_duck_s: float = 0.15          # s the power duck holds  # WK-109
# --- WK-166 disconnect follow-ups (docs/audit/2026-11-16_wk160_recheck.md). Read by src/systems/Juice.gd (bounce  # WK-166
# rumble) and src/ui/DeviceToast.gd (lobby toast placement).  # WK-166
var wk166_bounce_rumble_min_speed: float = 1100.0   # px/s launch a bounce needs before it rumbles the bouncer's pad (was 310 = t > 0.25 of 1240; idle floor bounces launch 758-929)  # WK-166
var wk166_lobby_toast_pos: Vector2 = Vector2(40.0, 814.0)   # px top-left of the toast stack in the Herd Lobby (low-left, beside the CPU tray; top-centre covered the roster)  # WK-166
var wk166_lobby_toast_width: float = 560.0    # px width of the lobby toast stack (toasts left-align inside it)  # WK-166
# --- WK-167 bots spend their last fuel in a recovery (docs/audit/2026-11-16_wk135_p3_ab.md finding 4: 56 of 106 bot self-KOs  # WK-167
# fell with 3.5-4.1 fuel). Cause: InputBot._danger_recover only held boost while fuel > 4.0 (drain 0.238/tick -> it let go at  # WK-167
# 3.76-4.0 = ~0.13 s of thrust unspent), and _flight_recovers modelled the same cut-off. A HELD boost is never billed (WK-128 bills  # WK-167
# only re-lights, and WK-136 always leaves >= 3.0 of it), so the reserve is free thrust. Read ONLY by InputBot.gd.  # WK-167
# QA arm without a Tuning edit: env GB_WK167=1/0 (read in _ready; headless runs and record_match.ps1 inherit it).  # WK-167
var wk167_spend_last_fuel: bool = true        # ON (director: bug fix - recovery boost used to stop at 4.0 fuel). false = old  # WK-167
var wk167_recover_boost_floor: float = 0.0    # fuel a recovering bot keeps boosting down to when ON (and the WK-127 predictor's cut-off)  # WK-167
# --- WK-164 K3 strike-guard swerve hold (docs/audit/2026-11-15_wk108b_ab.md: 41 sharp 30-46 deg turns + 20 direction flips per  # WK-164
# 20 s in goal-mouth scrums). Read ONLY by SportsMode.bot_strike_guard. Once the guard picks a swerve side (the ball's own-goal  # WK-164
# side of the perpendicular, which flips whenever the goat crosses the ball->own-goal line) it keeps that side for hold_s while the  # WK-164
# guard stays tripped. A release is never held: steering a held escape after the guard let go measured 1.7x the sharp turns.  # WK-164
# QA arm without a Tuning edit: env GB_WK164=1/0 (1 = wk164_guard_hold_on, 0 = 0.0).  # WK-164
var wk164_guard_hold_s: float = 0.2           # s the K3 swerve SIDE is held once picked (ON 0.2: flips -13 %). 0.0 = OFF  # WK-164
var wk164_guard_hold_on: float = 0.2          # s the GB_WK164=1 arm sets (brief: 0.15-0.25; L3 turns ~0.2 s / 90 deg)  # WK-164
# --- WK-161b bot chase routing round obstacles inside a radial gravity well (docs/audit/2026-11-16_wk161_ab.md spec: 84 % of  # WK-161b
# Singularity pins = a bot thrusting at a target THROUGH a pylon / the core / a corner block). Read ONLY by src/core/InputBot.gd.  # WK-161b
# ON: when the bot is inside a GravitySource radius and the ray to its chase target (hunt / finisher / plan land point) hits a  # WK-161b
# collider, it flies to the tangent point round a round body (core) or past the nearer clear end of the hit rect face  # WK-161b
# (pylon / block / shell), holding the chosen side while the line stays blocked. No steering once the line clears.  # WK-161b
# QA arm without a Tuning edit: env GB_WK161B=1/0 (read in _ready; headless runs and record_match.ps1 inherit it).  # WK-161b
var wk161b_chase_route: bool = false          # MASTER (default OFF until the acceptance batch). true = route round blockers in wells  # WK-161b
var wk161b_route_margin: float = 60.0         # px clearance past body radius / face end + goat radius (spec bot_route_margin)  # WK-161b
var wk161b_commit_s: float = 0.6              # s a picked side is held before a cheaper side may win (spec bot_route_commit_s)  # WK-161b
var wk161b_repick_deg: float = 35.0           # deg the target must swing to the OTHER side (round the blocker's centre) to re-pick at once  # WK-161b
var wk161b_repick_margin_px: float = 60.0     # px shorter the other side must be to win a re-pick once commit_s ran out (anti-dither)  # WK-161b
var wk161b_inside_lean: float = 0.25          # outward lean added to the tangent aim when already inside the core's clearance band  # WK-161b
var wk161b_bounds_inset: float = 150.0        # px inside the blast bounds a rect-end waypoint must sit (else that end is not a candidate)  # WK-161b
var wk161b_episode_gap_s: float = 0.6         # s of clear line before a route episode closes (a re-block sooner keeps the side + episode)  # WK-161b
var wk161b_los_halfwidth: float = 1.0         # x goat radius: side rays either side of the line-of-sight ray (0 = the spec's single centre ray; a point ray clears corners the body clips)  # WK-161b
var wk161b_pinned_speed: float = 400.0        # px/s telemetry: an in-well stuck window below this mean speed = "pinned", else "ping-pong"  # WK-161b
# --- WK-172 (CD5-05) session-deck reshuffle never repeats this match's arenas early. Read ONLY by src/modes/BrawlMode.gd.  # WK-172
# When a CD4-01 deck runs dry, the new deck holds back (to the end of its MILD / WILD half; interleave + no-back-to-back  # WK-172
# kept) every arena drawn in the current match plus the session's last wk172_deck_recent_n draws for that deck.  # WK-172
var wk172_deck_avoid_recent: bool = true      # ON (bug fix). false = the CD4-01 build (only the single last arena is avoided)  # WK-172
var wk172_deck_recent_n: int = 5              # session draws remembered across matches (a REMATCH whose stage 1 reshuffles)  # WK-172
# --- WK-171 (CD5-04) RULES panel helper line: one sentence explaining the FOCUSED rules row, shown in the lobby's rules bar  # WK-171
# (under the panels) while a RULES card is open. Read ONLY by src/ui/HerdLobby.gd. Texts live in HerdLobby._rules_defs.  # WK-171
var wk171_rules_helper: bool = true           # ON. false = the bar keeps the rules summary while editing (pre-WK-171)  # WK-171
# --- WK-169 SHOWDOWN (CD5-01 Brawl spectator time; spec docs/specs/wk169_spectator_time_2026-11-16.md §5-§9). The 169b-prep  # WK-169
# prototype: every lever behind its OWN switch, all default OFF = today (no ShowdownDirector node, no showdown / spectator  # WK-169
# keys in round_stats). Read by src/systems/ShowdownDirector.gd (state, L1 drop, dim + rim), GhostDirector.gd (L2),  # WK-169
# Player.gd (L3 launch multiplier only; the hitstun triad / knockback array / protected constants are untouched),  # WK-169
# PowerupSystem.gd + PowerupBubble.gd (golden tank), InputBot.gd (golden seek). NEVER ends a stage: no timer, no boundary.  # WK-169
# QA arm without a Tuning edit: env GB_WK169 = comma list (read in _ready): drop / ghost / rowdy (one lever each, implies  # WK-169
# showdown_enabled), a1 (=drop) a2 (=ghost) a3 (=rowdy) a4 (=drop,ghost), all / 1 (every lever), frame (state + dim / rim,  # WK-169
# no lever), 0 / a0 / tel (telemetry only, the A0 control). Any non-empty value turns showdown_telemetry on. Headless arms can also use tune_<name>=<v>.  # WK-169
var showdown_enabled: bool = true             # ON (WK-169b-2 ruling: A1 shipped). MASTER. false = no state, no node, no showdown telemetry (spec §8)  # WK-169
var showdown_telemetry: bool = false          # spectator / tail / ghost-dry telemetry without any lever (A0 control). Implied by showdown_enabled  # WK-169
var showdown_delay: float = 6.0               # s of 2-alive (stage started >= 3) COMBAT before SHOWDOWN (game time)  # WK-169
var showdown_step_s: float = 8.0              # s between escalation steps (step 1 = entry)  # WK-169
var showdown_max_steps: int = 3               # escalation holds after this step (tail 6 / 14 / 22 s). Never an end  # WK-169
var showdown_drop: bool = true                # ON (WK-169b-2). L1 GOLDEN DROP switch  # WK-169
var showdown_drop_interval: float = 8.0       # s between golden drops (telegraph start to telegraph start)  # WK-169
var showdown_drop_telegraph: float = 1.0      # s of gold converging sparkle before the bubble is live (= pu_spawn_telegraph)  # WK-169
var showdown_drop_life: float = 7.0           # s a live golden bubble waits, then pops uncollected  # WK-169
var showdown_drop_dur: float = 6.0            # s of Unlimited Boost the golden tank grants (re-grab refreshes)  # WK-169
var showdown_drop_view_inset: float = 120.0   # SCREEN px: only spawners inside the view inset by this qualify (none -> all)  # WK-169
var showdown_drop_tank_lock: float = 1.0      # s after a golden tank ends before the next drop may telegraph  # WK-169
var showdown_drop_live_wait: float = 1.5      # s max a drop waits for a respawning fighter (LIVES > 1), then drops anyway  # WK-169
var showdown_drop_scale: float = 1.2          # golden bubble size vs a normal powerup bubble  # WK-169
var showdown_drop_tel_radius: float = 1.3     # golden telegraph sparkle radius vs the normal telegraph  # WK-169
var bot_golden_seek_p: float = 0.5            # CPU: p per decision to go for a golden bubble when d_me <= ratio x d_rival  # WK-169
var bot_golden_seek_ratio: float = 1.25       # CPU: the "I can win this race" distance ratio (spec §6.1 / §10.3)  # WK-169
var bot_golden_boost_dist: float = 180.0      # px: the seek boosts beyond this distance (with fuel > bot_golden_boost_fuel)  # WK-169
var bot_golden_boost_fuel: float = 8.0        # fuel the seek needs to boost  # WK-169
var showdown_ghost_boost: bool = false        # L2 RESTLESS GHOSTS switch  # WK-169
var showdown_ghost_cd_mult: float = 0.5       # x puff cooldown in the showdown (7.0 -> 3.5 s; bot ghosts 14 -> 7 s)  # WK-169
var showdown_ghost_cap_per_step: int = 3      # + per-stage puff cap per step (3 -> 6 -> 9 -> 12)  # WK-169
var showdown_rowdy: bool = false              # L3 ROWDY ARENA switch  # WK-169
var showdown_bounce_mult_per_step: float = 1.07   # x tier bounce launch speed per step (apex x1.14 / 1.31 / 1.50)  # WK-169
var showdown_dim: float = 0.10                # backdrop multiply-dim at step 1 (backdrop layers only, never goats / decks / ghosts)  # WK-169
var showdown_dim_step: float = 0.03           # + dim per later step  # WK-169
var showdown_dim_max: float = 0.16            # dim cap  # WK-169
var showdown_dim_ease: float = 1.0            # s the dim eases in (static afterwards: no edge, no inward motion)  # WK-169
var showdown_dim_z: int = -79                 # z of the dim plate: above the backdrop stack (-100..-80), below void paint / decks  # WK-169
var showdown_rim_alpha: float = 0.9           # gold rim ring alpha (spec 0.6 read as a faint green disc on bright skies, rendered 2026-11-16)  # WK-169
var showdown_rim_color: Color = Color("#ffd23f")   # rim gold (= PartyMatch GOLD)  # WK-169
var showdown_rim_px: float = 4.0              # SCREEN px width of the gold rim ring (zoom-compensated)  # WK-169
var showdown_rim_radius_mult: float = 1.25   # x body (collider) radius where the rim starts: the goat art overhangs the collider  # WK-169
var showdown_rim_gap_px: float = 3.0          # SCREEN px past that radius before the ring  # WK-169
var showdown_rim_halo_px: float = 7.0         # SCREEN px the soft gold halo extends past the ring  # WK-169
var showdown_banner_time: float = 1.0         # s the "SHOWDOWN!" top band holds (= TWO LEFT!)  # WK-169
var showdown_long_wait_s: float = 15.0        # telemetry: a human wait longer than this counts as a long wait (S3)  # WK-169
# --- WK-191 SD inherits the SHOWDOWN (spec docs/specs/wk190_dead_share_2026-11-16.md §5). Read by ShowdownDirector.gd (+ the  # WK-191
# PartyMatch SD hooks). With sd_showdown ON a BRAWL sudden death (stage started >= 3, both revived goats alive) enters the shipped  # WK-191
# SHOWDOWN sd_showdown_delay s (game time) after the SD revive lock ends, so the first golden bubble goes live when the Lv2  # WK-191
# pre-damage would heal. false = today byte for byte (the showdown clears on SD entry and never re-enters). Built OFF for 190b.  # WK-191
var sd_showdown: bool = false                 # WK-191 switch (default OFF until the 190b A/B rules; ship value true if R1)  # WK-191
var sd_showdown_delay: float = 7.0            # s from the SD unlock = dmg_heal_time - showdown_drop_telegraph. Re-derive if either changes  # WK-191
# --- WK-99 fuel gauge super-ready notch + CD3-04b billed re-light chunk flash (brawl half). Read by src/ui/PlayerCard.gd  # WK-99
# (corner card gauge) and src/ui/EdgeIndicators.gd (WK-36 off-screen bubble fuel ring). The notch sits at super_boost_min_fuel  # WK-99
# / fuel_max (10 %): LIT (tall cream tick, chocolate outline) when the tank can fire a super, UNLIT (short dark tick) below it,  # WK-99
# so the read is size + luminance, never hue. The chunk flash: when a mid-air re-light is billed (WK-128 R2) the slice of the  # WK-99
# gauge the bill took pops white just past the fill end and drops away. Sports has no per-player cards: its widget is not built.  # WK-99
var wk99_notch_on: bool = true                # card gauge notch. false = the pre-WK-99 gauge  # WK-99
var wk99_notch_w: float = 8.0                 # px notch width (incl. its 2 px chocolate outline)  # WK-99
var wk99_notch_overhang: float = 4.0          # px a LIT notch pokes above and below the gauge (unlit: flush with the gauge, inset by the fill pad)  # WK-99
var wk99_notch_unlit: Color = Color(0.62, 0.56, 0.52, 1.0)   # modulate on the cream notch below the threshold (muted taupe tick, flush with the track)  # WK-99
var wk99_notch_pop_s: float = 0.22            # s the notch's pop takes when the tank crosses UP through the threshold  # WK-99
var wk99_notch_pop_scale: float = 1.6         # notch scale at the start of that pop  # WK-99
var wk99_bill_flash_on: bool = true           # CD3-04b billed-chunk flash. false = no flash  # WK-99
var wk99_bill_min_px: float = 12.0           # px min chunk width (a 1-3 fuel bill is ~2-5 px on the gauge: unreadable at 3 m)  # WK-99
var wk99_bill_overhang: float = 3.0           # px the chunk pokes above / below the fill  # WK-99
var wk99_bill_hold_s: float = 0.10            # s the chunk holds bright before dropping  # WK-99
var wk99_bill_drop_s: float = 0.45            # s it falls and fades  # WK-99
var wk99_bill_drop_px: float = 16.0           # px it falls  # WK-99
var wk99_bubble_notch: bool = true            # WK-36 bubble fuel ring tick at the same threshold (lit cream / unlit chocolate)  # WK-99
var wk99_bubble_notch_deg: float = 7.0        # deg the bubble tick spans across the ring  # WK-99
# --- WK-173 (CD5-06) corner-card stickers and the KO "+1" chip stay out of the way. Read by src/ui/PlayerCard.gd /  # WK-173
# src/ui/MatchHUD.gd (sticker + stock-tab dim, same rule as WK-156's legend chips) and src/ui/KOCreditPop.gd (+1 landing point).  # WK-173
var wk173_tab_goat_dim: bool = true           # a HURT!/DANGER! sticker (and the stock tab) a living goat overlaps fades out of the way  # WK-173
var wk173_tab_dim_alpha: float = 0.18         # alpha of a sticker / stock tab with a goat under it (the goat reads through)  # WK-173
var wk173_tab_dim_fade: float = 0.12          # s the dim in / out takes  # WK-173
var wk173_tab_pad_px: float = 6.0             # px the sticker rect is grown by for the overlap test  # WK-173
var wk173_tab_hysteresis_px: float = 14.0     # extra px a DIMMED sticker tests with (no flicker on the edge)  # WK-173
var wk173_chip_clear_name: bool = true        # the "+1" / OOPS chip lands beside the card NAME (its far end), never on it  # WK-173
var wk173_chip_name_gap: float = 6.0          # px between the name's right edge and the landed chip's left edge  # WK-173
# --- WK-178 ghost rise delay on GAME time (WK-37 ghost_spawn_delay was REAL s: under KO hit-stop a ghost rose ~0.15 game-s after  # WK-178
# its death, before a double-KO sudden-death revive at +0.16 s). Read ONLY by src/systems/GhostDirector.gd.  # WK-178
var wk178_ghost_game_time: bool = true        # ghost_spawn_delay counts scaled (game) seconds. false = real seconds (WK-37)  # WK-178
var wk178_hold_while_revivable: bool = true   # a due ghost waits while its goat could still be revived (double-KO window open / stage decision pending)  # WK-178
# --- WK-179 soak findings (docs/audit/2026-11-16_wk176_soak.md). F1: an unlock celebration (lobby NEW FLAIR card, arena-select  # WK-179
# CIRCUIT UNLOCKED) plays its own fanfare via EventBus.unlock_celebrated and never touches the music (it used match_won, which  # WK-179
# swapped the front-end loop to scoreboard.mp3 until the next match). Read ONLY by src/systems/AudioManager.gd.  # WK-179
var wk179_unlock_sting_db: float = -3.0        # dB of the unlock fanfare (the match_win sample) on the Stingers bus; the match win plays it at -1  # WK-179
# --- WK-46 menu auto-repeat on a held D-pad / left stick / arrow-or-WASD key (CC-5.3), for every focus-driven menu (title, mode  # WK-46
# select, arena select, Options, pause, disconnect overlay). src/core/InputRouter.gd sends the repeats as synthetic copies of  # WK-46
# the held press (same device, tagged); the Herd Lobby keeps its own per-device repeat (lobby_repeat_*). Auto-repeat never wraps  # WK-46
# past the end of a list (a fresh press still wraps where the screen wraps). Stick hysteresis = lobby_stick_press / _release.  # WK-46
var wk46_menu_repeat: bool = true              # false = the pre-WK-46 behaviour (pads never repeat, keyboard rides the OS key echo)  # WK-46
var wk46_repeat_delay: float = 0.40            # s a held direction waits before the first repeat (CC-5.3)  # WK-46
var wk46_repeat_rate: float = 0.09             # s between repeats once repeating (CC-5.3; = lobby_repeat_rate)  # WK-46
var wk46_repeat_wraps: bool = false            # true = auto-repeat may wrap like a fresh press (the WK-174 "lands back on the start row" bug)  # WK-46
# --- WK-110 (SP-08) sports tension. (a) a MATCH POINT / GOLDEN GOAL plate in the top band at every kickoff whose score is one goal  # WK-110
# (point) from the cap: MATCH POINT = one team at cap-1, GOLDEN GOAL = both (a cap-1 tie; first-to-N has no clock, so "golden goal"  # WK-110
# just names the next-goal-wins kickoff). Shown on the countdown "3" (the goal banner has just left), gone ~0.4 s after KICK OFF!,  # WK-110
# long before the gates open (3.5 s) or a PRESSURE! word (t1 30 s). Read by src/ui/SportsHUD.gd + src/systems/AudioManager.gd.  # WK-110
# (b) the RULES "GOALS" (Rocketball) / "POINTS" (Dropshot) stepper. Read by src/ui/HerdLobby.gd + src/core/GameConfig.gd.  # WK-110
var wk110_tension_banner: bool = true          # false = no kickoff MATCH POINT / GOLDEN GOAL plate (pre-WK-110)  # WK-110
var wk110_banner_hold: float = 1.45            # s the plate holds after its 0.15 s pop-in (countdown is 3 x countdown_beat = 1.05 s)  # WK-110
var wk110_golden_color: Color = Color("#FFC93C")   # GOLDEN GOAL title (team-neutral gold, the PRESSURE! gold)  # WK-110
var wk110_mp_sting_db: float = -5.5            # dB MATCH POINT sting (the two_left combo_preBreak sample) on the Stingers bus  # WK-110
var wk110_gg_whistle_db: float = -4.0          # dB GOLDEN GOAL referee double whistle (whistle_double) on the Stingers bus  # WK-110
var wk110_gg_sting_db: float = -4.0            # dB GOLDEN GOAL sting (two_left, pitched down) on the Stingers bus  # WK-110
var wk110_crowd_db: float = -13.0              # dB crowd swell under the sting (the WK-105 goal crowd, slowed); GOLDEN GOAL plays it +4 dB  # WK-110
var wk110_goal_choices: Array[int] = [3, 5, 6, 7, 10]   # RULES GOALS / POINTS values; the default is sports_goal_target (6)  # WK-110
# --- WK-180 (docs/briefs/wk180_decals_bumpers_2026-11-16.md) bumper art + grass decals. Read ONLY by src/systems/ArenaRenderer.gd  # WK-180
# (+ src/systems/ThreeSlice.gd via its `units` arg). Bumpers: vertical = bumper_post 3-sliced, horizontal w/h >= rail_min_aspect =  # WK-180
# bumper_rail (the post transposed), squarer horizontal = bumper_block drawn whole. Pearl runs are tiled in WHOLE pearls (no seam or  # WK-180
# crop ever cuts a stud). Decals: grass bodies only, never on mat-only slabs, never above mat_top + 8 (R0 landing line).  # WK-180
var wk180_post_cap_frac: float = 0.20          # bumper_post / bumper_rail cap fraction: both cuts land in a pearl gap (was 0.22 = half-pearl seams)  # WK-180
var wk180_bumper_pearl_units: int = 5          # pearls in the post/rail centre slice at cap 0.20 (tiling quantum; 0 = classic ThreeSlice rules)  # WK-180
var wk180_rail_min_aspect: float = 1.6         # horizontal bumper w/h at or above this draws the rail; below = the block (rail if the block can't fit)  # WK-180
var wk180_block_pad: float = 8.0               # px the whole-drawn block exceeds its collider on each axis (total)  # WK-180
var wk180_fringe_daisies: bool = true          # R4 small daisies in the grass fringe below the mat (false = none)  # WK-180
var wk180_end_tufts: bool = true               # R5 one outward-leaning tuft per platform end (false = none; R6 "dark blob" escape hatch)  # WK-180
var wk180_fringe_frac: float = 0.60            # where the grass blades end in body_std.png, as a fraction of the drawn strip height  # WK-180
var wk180_daisy_min_w: float = 400.0           # platforms narrower than this get no daisies  # WK-180
var wk180_daisy_px_per: float = 320.0          # one daisy (cluster) per this many px of platform width  # WK-180
var wk180_daisy_max: int = 8                   # daisy clusters per platform cap  # WK-180
var wk180_daisy_end_inset: float = 70.0        # px the daisy span stays in from each platform end  # WK-180
var wk180_daisy_jitter: float = 0.35           # stratified jitter, +- fraction of a cell (never metronome spacing)  # WK-180
var wk180_daisy_h_min: float = 18.0            # daisy height, world px (min)  # WK-180
var wk180_daisy_h_max: float = 22.0            # daisy height, world px (max)  # WK-180
var wk180_daisy_base_off: float = 3.0          # px the daisy stem base sits below fringe_bottom  # WK-180
var wk180_daisy_buddy_chance: float = 0.35     # chance a daisy gets a smaller buddy beside it  # WK-180
var wk180_daisy_buddy_dx_min: float = 14.0     # buddy x offset, px (min)  # WK-180
var wk180_daisy_buddy_dx_max: float = 20.0     # buddy x offset, px (max)  # WK-180
var wk180_daisy_buddy_scale: float = 0.8       # buddy height vs its daisy  # WK-180
var wk180_daisy_tuck_px: float = 4.0           # daisy top may tuck at most this far under the mat's bottom edge  # WK-180
var wk180_decal_min_h: float = 14.0            # a decal shrunk below this height (to fit under the mat) is skipped  # WK-180
var wk180_daisy_lip_clear: float = 60.0        # no daisy within this many px of a suppressed (void-lip) end  # WK-180
var wk180_tuft_min_w: float = 160.0            # platforms narrower than this get no end tufts  # WK-180
var wk180_tuft_h_min: float = 34.0             # end tuft height, world px (min)  # WK-180
var wk180_tuft_h_max: float = 40.0             # end tuft height, world px (max)  # WK-180
var wk180_tuft_base_off: float = 6.0           # px the tuft stem base sits below fringe_bottom  # WK-180
var wk180_tuft_inset: float = 8.0              # tuft x = side * (w/2 + BODY_BLEED_SIDE - this): straddles the body's side outline  # WK-180
var wk180_decal_max_rise: float = 8.0          # R0: no decal pixel above mat_top + this (tufts are clamped / shrunk to fit)  # WK-180
# --- WK-182 (docs/audit/2026-11-16_wk180_artgrade.md §1, §4, §5) bumper routing + pearl-run fix + corner tufts. Read ONLY by  # WK-182
# src/systems/ArenaRenderer.gd (units_min_cap_k is passed on to ThreeSlice.build).  # WK-182
var wk182_units_min_cap_k: float = 0.85        # B-F1: units-mode posts/rails crop their caps only below this x (2 x cap length); above it caps + whole pearls share one scale k  # WK-182
var wk182_sq_min_aspect: float = 0.85          # bumper w/h below this draws the vertical post  # WK-182
var wk182_sq_max_aspect: float = 1.05          # w/h in [sq_min, sq_max) draws the square block (bumper_block_sq.png whole; post if it can't fit)  # WK-182
var wk182_sq_interim_squash: bool = false      # only if bumper_block_sq.png is missing: true = bumper_block squashed to w+pad x h+pad (interim, NOT ship); false = post. OFF: the sprite landed (8c08752)  # WK-182
var wk182_void_lip_suppress: bool = false      # true = suppress end tufts/daisies within 50 px of a void-rect edge (turn back ON if paint_void ever draws pit art again)  # WK-182
# --- WK-175 refund-gate scope (docs/specs/wk175_refund_gates_retune_2026-11-16.md §4). The master refund_gates_on (WK-135 block)  # WK-175
# now turns on the SCOPE chosen by wk175_gate_set; false = every contact pays exactly as today and every knob below is ignored.  # WK-175
# Every non-stunned, non-underside contact is classed by LOCAL gravity (up = -g): n.up > bumper_floor_dot = FLOOR, else WALL  # WK-175
# (tier faces too, not only bumpers; round colliders are always FLOOR; decided PER CONTACT). Sets:  # WK-175
#   1 WR (ship candidate): FLOOR faces always pay (never read/write arm state). WALL faces pay once, then only after the body  # WK-175
#     centre moved wk175_wall_rearm_px along the face normal (tier walls: max(that, refund_rearm_frac x launch h)); a blocked  # WK-175
#     wall contact re-bases the paying position. No speed gate (F2), no Alt B cap, valve only if wk175_wall_valve.  # WK-175
#   2 WS: FLOOR faces always pay; WALL faces keep the WK-135 phase-3 rules (tier max(60, 0.9 h) + valve; bumper 200 + F2 900 + valve).  # WK-175
#   3 FULL: WK-135 phase 3 on every face + the deck fix (wk175_deck_exempt).  # WK-175
# F3 (supers always pay), F4 (stunned / underside never pay), F5, F7, the relight bill, the kick floor and the ball refuel are  # WK-175
# unchanged in every set. QA arm without a Tuning edit: env GB_WK175=off|0, wr|1, ws|2, full|3 (wins over GB_WK135_GATES).  # WK-175
# INVARIANTS: #18 (WR) wk175_wall_rearm_px >= fuel_per_bumper x normal_boost_max_speed x BOOST_MAX / (natural trampoline income  # WK-175
#       + normal_boost_drain()) = 20 x 896 / (17.2 + 28.57) = 391: a cruise ping-pong between two walls never out-earns natural  # WK-175
#       bouncing. Re-derive if refunds, cruise cap, profile boost, trampoline height or tank change.  # WK-175
#   #18b (residual, accepted): with supercharged exits (cap 1280 for 0.2 s after a paying wall hit) the same bound is 559; a  # WK-175
#       frame-perfect stick flip at every wall across an exposed lane is skill + constant motion (spec probe P4, ladder §10).  # WK-175
#   #12, #13, #15, #16 are live only in WS / FULL. #16 per face: qa_valve_over_natural_face counts per face key.  # WK-175
var wk175_gate_set: int = 1                    # which scope the master turns on: 1 WR (candidate), 2 WS, 3 FULL  # WK-175
var wk175_wall_rearm_px: float = 400.0         # px a WALL face needs before it pays again under WR. Invariant #18 (>= 391; < 350 breaks it)  # WK-175
var wk175_wall_valve: bool = false             # WR: C4 liveness valve on WALL faces (false: gravity frees you; on walls the valve was income). WS/FULL keep P3's valve  # WK-175
var wk175_deck_exempt: bool = true             # FULL only: tier-less moving-deck FLOOR faces re-arm at refund_rearm_frac x h without refund_rearm_min_px  # WK-175
const WK175_SET_NAMES: Array[String] = ["OFF", "WR", "WS", "FULL"]   # index = effective set (0 = master off)  # WK-175

## WK-175: apply a GB_WK175 arm string. off/0 -> master false; wr/1, ws/2, full/3 -> master true + that set. Else untouched.  # WK-175
func _wk175_env(v: String) -> void:  # WK-175
	var s: String = v.strip_edges().to_lower()  # WK-175
	if s == "":  # WK-175
		return  # WK-175
	if s == "off" or s == "0":  # WK-175
		refund_gates_on = false  # WK-175
		return  # WK-175
	var sets := {"wr": 1, "1": 1, "ws": 2, "2": 2, "full": 3, "3": 3}  # WK-175
	if sets.has(s):  # WK-175
		refund_gates_on = true  # WK-175
		wk175_gate_set = int(sets[s])  # WK-175
	else:  # WK-175
		push_warning("GB_WK175='%s' not recognised (off|wr|ws|full); gates left as authored" % v)  # WK-175

## WK-175: the effective gate set (0 = OFF, 1 WR, 2 WS, 3 FULL) with the master folded in.  # WK-175
func wk175_effective_set(mode: StringName = &"") -> int:  # WK-175. WK-175c: + mode (the goat's mode family; "" = in scope)
	return clampi(wk175_gate_set, 1, 3) if (refund_gates_on and wk175c_mode_in_scope(mode)) else 0  # WK-175c: per-mode scope folded in

## WK-175: class-aware refund-gate rules for ONE contact. cls: 0 FLOOR, 1 WALL, 2 CEILING (never reaches the gate; treated as  # WK-175
## WALL). Returns {gate: false = this contact always pays and never reads/writes arm state; e_min / e_frac: re-arm distance  # WK-175
## max(e_min, e_frac x launch h) (0 = no arm, pays every contact); min_speed: F2 hard-hit gate (0 = off); cooldown: Alt B cap  # WK-175
## (0 = off); valve: C4 time re-arm applies; rebase: a blocked contact re-bases the paying position and E}. Master off = all 0.  # WK-175
func gate_rules(cls: int, is_bumper: bool, is_deck: bool, mode: StringName = &"") -> Dictionary:  # WK-175. WK-175c: + mode (per-mode scope)
	var r := {"gate": true, "e_min": 0.0, "e_frac": 0.0, "min_speed": 0.0, "cooldown": 0.0, "valve": false, "rebase": false}  # WK-175
	var gs: int = wk175_effective_set(mode)  # WK-175. WK-175c: a mode outside wk175_gate_modes = OFF (every contact pays)
	if gs == 0:  # WK-175: OFF = today (every contact pays)
		return r  # WK-175
	var floor_cls: bool = cls == 0  # WK-175
	if floor_cls and gs != 3:  # WK-175 G2: WR / WS floors always pay, exactly like OFF
		r["gate"] = false  # WK-175
		return r  # WK-175
	if gs == 1:  # WK-175 G3/G4: WR wall (tier or bumper)
		r["e_min"] = wk175_wall_rearm_px  # WK-175
		r["e_frac"] = 0.0 if is_bumper else refund_rearm_frac  # WK-175: the frac term matters only for supercharged spring sides
		r["valve"] = wk175_wall_valve  # WK-175
		r["rebase"] = true  # WK-175: a blocked wall touch re-bases (creeping away never re-arms)
		return r  # WK-175
	# WS walls / FULL every face: WK-135 phase 3 exactly (+ the deck fix in FULL).  # WK-175
	var tier_rules: bool = not is_bumper or (floor_cls and bumper_floor_pays_as_tier)  # WK-175 (= WK-135 C2)
	r["valve"] = true  # WK-175: P3 valve (acts only while refund_rearm_timeout > 0)
	if tier_rules:  # WK-175
		r["e_min"] = 0.0 if (gs == 3 and floor_cls and is_deck and wk175_deck_exempt) else refund_rearm_min_px  # WK-175 deck fix
		r["e_frac"] = refund_rearm_frac  # WK-175
		r["rebase"] = true  # WK-175
	else:  # WK-175: WK-128 bumper wall rules
		r["e_min"] = refund_rearm_bumper_px  # WK-175
		r["min_speed"] = bumper_refund_min_speed  # WK-175
		r["cooldown"] = bumper_refund_cooldown  # WK-175
	return r  # WK-175

## WK-175 §4.5: what a run's meta.tuning should log (the set and the effective rules per class).  # WK-175
func wk175_meta() -> Dictionary:  # WK-175
	var gs: int = wk175_effective_set()  # WK-175
	return {"refund_gates_on": refund_gates_on, "wk175_gate_set": wk175_gate_set, "effective_set": WK175_SET_NAMES[gs],  # WK-175
		"wk175_gate_modes": wk175_gate_modes.duplicate(),  # WK-175c
		"wk175_wall_rearm_px": wk175_wall_rearm_px, "wk175_wall_valve": wk175_wall_valve, "wk175_deck_exempt": wk175_deck_exempt,  # WK-175
		"refund_rearm_timeout": refund_rearm_timeout,  # WK-175
		"rules": {"floor_tier": gate_rules(0, false, false), "floor_bumper": gate_rules(0, true, false),  # WK-175
			"floor_deck": gate_rules(0, false, true), "wall_tier": gate_rules(1, false, false),  # WK-175
			"wall_bumper": gate_rules(1, true, false)}}  # WK-175
# --- WK-169c SHOWDOWN polish (spec docs/specs/wk169c_showdown_polish_2026-11-16.md §1.4, §2.2-§2.9). Every default keeps  # WK-169c
# today's gameplay except bot_golden_lowfuel_seek (ON, §2.8 a). GOLD SURGE is OFF (0.0 = the 169b-2 tank byte for byte) until  # WK-169c
# the lane-TG re-check rules. Read by ShowdownDirector.gd, PowerupSystem.gd, PowerupBubble.gd, PowerupSpawnDirector.gd,  # WK-169c
# AudioManager.gd (hush + stings), PlayerCard.gd / MatchHUD.gd (gold card frame), InputBot.gd (low-fuel seek).  # WK-169c
var showdown_drop_arm_s: float = 0.0          # GOLD SURGE: s after a golden grab before the holder's SUPER arms (boost works at once). 0 = today; re-check 1.0. Clamped to dur - 1  # WK-169c
var showdown_music_duck_db: float = -4.5      # Music-bus duck in the showdown (director ruling: -5 measured -6.55 dB at step 1 with the LPF; the spec band is -4..-6)  # WK-169c
var showdown_music_lpf_hz: Array = [1600.0, 1100.0, 800.0]   # Music low-pass cutoff per showdown step (never below 600 Hz)  # WK-169c
var showdown_music_ease_in: float = 1.0       # s the duck + LPF ease in at entry (= the dim ease)  # WK-169c
var showdown_music_step_glide: float = 0.4    # s the LPF glides to the next step's cutoff  # WK-169c
var showdown_music_ease_out: float = 0.4      # s the duck + LPF release at stage / match end (SD releases at once)  # WK-169c
var showdown_sting_db: float = -9.0           # ka-CHUNK entry: the "CHUNK" level on Stingers (the "ka" sits 3 dB under). Rise <= KO - 2 LU  # WK-169c
var showdown_step_sting_db: float = -12.0     # steps 2 / 3: a single CHUNK, -3 dB vs the entry pair  # WK-169c
var showdown_bell_db: float = -12.0           # golden telegraph "ding-ding" (golden_bell.ogg) on Stingers. Rise <= KO - 3 LU  # WK-169c
var showdown_collect_db: float = -8.0         # gold collect sting (golden_collect.ogg) on Stingers. Rise <= KO - 2 LU  # WK-169c
var showdown_pfff_db: float = -10.0           # tank-end deflate (golden_pfff.ogg) on SFX  # WK-169c
var showdown_drop_body_mult: float = 1.25     # golden bubble VISUAL body / collider radius (goat-art convention). Visual only  # WK-169c
var showdown_drop_halo_px: float = 120.0      # SCREEN px halo diameter floor at 1080p (world = px / zoom)  # WK-169c
var showdown_drop_halo_body_mult: float = 1.8 # halo diameter >= this x the visual body diameter (close zooms)  # WK-169c
var showdown_drop_icon_px: float = 64.0       # WORLD px of the golden icon (the normal icon is 48)  # WK-169c
var showdown_drop_glint_s: float = 1.2        # s between white glint sweeps across the golden body (= PowerupBubble.BOB_PERIOD)  # WK-169c
var showdown_drop_sparkle_rev_s: float = 2.4  # s per revolution of the six halo-edge star sparkles  # WK-169c
var showdown_drop_claim_r: float = 100.0      # WORLD px: regular bubbles / telegraphs within this of the golden point upgrade-pop at its telegraph start  # WK-169c
var bot_golden_lowfuel_seek: bool = true      # CPU under its refuel floor may race a REACHABLE golden bubble before diving. false = the 169b-2 bot exactly  # WK-169c
var bot_golden_lowfuel_reach: float = 480.0   # px cap on a low-fuel golden seek  # WK-169c
var bot_golden_lowfuel_seek_p: float = 0.8   # p per low-fuel decision to race a reachable golden bubble (spec rule p 0.5 measured 6/10 collects: a lost roll leads into a refuel dive that burns the fuel the race needed)  # WK-169c
var bot_golden_lowfuel_latch_s: float = 1.5   # s a picked low-fuel golden seek stays committed (until collect / bubble gone / void guard). 0 = re-roll every decision  # WK-169c
var bot_golden_seek_reach_guard: bool = true   # the normal (above-floor) golden seek also needs the reach / void fuel rule (a fuel-20 CPU flew at a bubble 450 px over the void and self-KO'd). false = the WK-169 seek  # WK-169c
var showdown_drop_stroke_px: float = 2.0      # SCREEN px umber stroke outside the golden bubble's rim (separates it from pale skies, T-G3)  # WK-169c
var showdown_holder_rim_mult: float = 1.5     # holder's rim width while a golden tank runs (+ shimmer + star trail)  # WK-169c
var showdown_holder_trail_rate: float = 8.0   # star sparkles / s from the holder while a golden tank runs  # WK-169c
var showdown_frame_glint_s: float = 0.8       # s between glint sweeps on the HOLDER's gold card frame  # WK-169c
var showdown_frame_fade_s: float = 0.2        # s the gold card frame fades out on exit (real time)  # WK-169c
# --- WK-183 sports per-player fuel arc (WK-99 SP-14, the sports half). Read by src/ui/SportsFuelArc.gd (built per goat by  # WK-183
# src/ui/SportsHUD.gd setup). A team-coloured arc hugs the LOWER half of each goat (screen-px widths, zoom-compensated), fills  # WK-183
# left -> right through 6 o'clock, carries the WK-99 super-ready notch (same threshold + lit / unlit look + pop), pulses when low,  # WK-183
# flashes the gained slice white on a refund, and fades out once full and steady. Drawn under the aim arrow, the ball and goal fronts.  # WK-183
var wk183_arc_on: bool = true                 # false = no sports fuel arcs (the pre-WK-183 sports HUD)  # WK-183
var wk183_span_deg: float = 130.0             # arc span, centred on 6 o'clock (65 deg each side; 150 ran up into the jetpack / arms)  # WK-183
var wk183_radius_mult: float = 1.1            # arc centre-line radius = this x collider radius (the round body art is 1.1 x)  # WK-183
var wk183_gap_px: float = 19.0                # SCREEN px between the body art and the arc centre-line (9 / 15 crossed the feet at sports zoom)  # WK-183
var wk183_width_px: float = 11.0              # SCREEN px fill width (1080p reference; UX FIX 3: 9 -> 11, band 16 px with the outline; ~9 mm at 3 m is the shape-read floor)  # WK-183
var wk183_outline_px: float = 2.5             # SCREEN px chocolate outline on each side of the track  # WK-183
var wk183_track_darken: float = 0.70          # empty part of the arc = the team colour darkened by this (flat chocolate vanished on the night courts; 0.62 read as a FULL arc)  # WK-183
var wk183_track_alpha: float = 1.0            # alpha of that empty track (opaque: the round end caps overlap the arc, a translucent track showed darker half-discs)  # WK-183
var wk183_alpha: float = 1.0                  # arc alpha when shown  # WK-183
var wk183_z: int = 0                          # z of the shared arc layer (= the goats' z). The layer sits in the runner's tree AFTER the level and BEFORE the goats, so every goat body / aim arrow / ring draws over every arc (re-grade item 1) while arcs stay over the floor (z -1 sank grounded arcs under it); ball (40), goal fronts (42), tags on top  # WK-183
var wk183_full_hide: bool = true              # fade the arc out once the tank is full and steady (4 full arcs at kickoff = clutter)  # WK-183
var wk183_full_hold_s: float = 0.9            # s a full arc stays up before fading (a refund that tops up still shows)  # WK-183
var wk183_fade_in_s: float = 0.08             # s the arc takes to appear (fuel starts moving / a refund lands)  # WK-183
var wk183_fade_out_s: float = 0.35            # s the arc takes to fade (full and steady / goat dies / stage ends)  # WK-183
var wk183_aim_alpha: float = 0.0              # arc alpha while the goat super-aims (the fuse ring owns that read)  # WK-183
var wk183_low_ratio: float = 0.25             # fuel ratio under which the arc pulses (= bubble_fuel_low, the WK-36 bubble ring)  # WK-183
var wk183_low_hz: float = 2.5                 # low pulse rate (Hz)  # WK-183
var wk183_low_rim_floor: float = 0.45         # low pulse TROUGH: the outline band is at least this far toward cream below wk183_low_ratio, 0 fuel included (UX FIX 1: it never returns to chocolate)  # WK-183
var wk183_low_rim_flash: float = 0.95         # low pulse PEAK: outline mix toward cream (rim = floor + (flash - floor) x pulse). Never the track, which would read full  # WK-183
var wk183_low_fill_white: float = 0.45        # low pulse: the fill brightens toward white by up to this (luminance, never hue)  # WK-183
var wk183_tick_min: float = 1.0               # fuel a single frame must gain to count as a refund tick (drain never rises)  # WK-183
var wk183_tick_s: float = 0.40                # s the refund tick takes (gained slice white -> team colour, width pop -> 1)  # WK-183
var wk183_tick_min_deg: float = 10.0          # deg min span of the flashed slice (a small top-up must still read at 3 m)  # WK-183
var wk183_tick_width_pop: float = 1.7         # x fill width at the tick's start  # WK-183
var wk183_tick_glow: float = 0.55             # whole-arc brighten toward white at the tick's start  # WK-183
var wk183_notch_deg: float = 6.0              # deg the LIT super-ready notch spans along the arc (~5.5 px at sports zoom; UX FIX 4)  # WK-183
var wk183_notch_overhang_px: float = 5.0      # SCREEN px a LIT notch pokes past the band on each side, chocolate keyline at every pulse phase (UX FIX 4)  # WK-183
var wk183_notch_unlit_alpha: float = 0.7      # UNLIT notch = a chocolate groove inside the track at this alpha ("absent", not a grey sibling of the lit bar)  # WK-183
var wk183_tag_clear_px: float = 6.0           # SCREEN px a living name tag flipped BELOW its goat keeps clear of the arc's outer edge (whenever arcs are on, visible or not). Read by PlayerPips  # WK-183
# WK-183 refuel ding (UX FIX 5): EventBus.refuel_ticked (emitted on the arc's refund-tick trigger, sports only) -> AudioManager "refuel_ding"  # WK-183
# (assets/sfx/refuel_ding.ogg, synthesized by tools/audio/render_wk183_refuel_ding.py), SFX bus.  # WK-183
var wk183_ding_on: bool = true                # false = the silent WK-183 tick  # WK-183
var wk183_ding_cpu_db: float = -22.5          # volume_db of a CPU-owned goat's ding (6 dB under a human's: three CPUs dinging is noise, the human's own refund is the lesson)  # WK-183
var wk183_ding_db: float = -16.5              # volume_db: 10 dB under a mid ball touch (both files -14.3 dBFS active RMS; mid touch -6.5 dB; render script prints it)  # WK-183
var wk183_ding_gap_s: float = 0.15            # min s between two dings of the SAME goat (real time; a wall ping-pong never machine-guns)  # WK-183
var wk183_ding_amt_lo: float = 10.0           # fuel gained at (and under) which the ding plays at its base pitch  # WK-183
var wk183_ding_amt_hi: float = 40.0           # fuel gained at (and over) which it plays wk183_ding_st_max higher  # WK-183
var wk183_ding_st_max: float = 5.0            # semitones the ding rises across amt_lo -> amt_hi  # WK-183
# --- WK-175c (CD6 "WK-175 feel check" FIX 1; spec docs/specs/wk175_refund_gates_retune_2026-11-16.md §10 rung 1) wall refund  # WK-175c
# feedback + the per-mode scope of the WK-175 master. Read by src/entities/Player.gd (emit + flame flare), src/systems/AudioManager.gd  # WK-175c
# (ding / tok) and src/systems/Juice.gd (tok puff). Player emits EventBus.wall_refund_cue(player, paid, amount, contact, normal) on  # WK-175c
# a WALL-class contact judged by the refund gate ONLY while WR (effective set 1) is live for that goat's mode; floors never cue.  # WK-175c
#   paid    -> "refuel_ding" (WK-183 asset; shares AudioManager's per-goat WK-183 ding throttle, so the sports fuel arc's own  # WK-175c
#              refund-tick ding in the same frame is swallowed: one ding per pay) + a warm jetpack flare on the goat.  # WK-175c
#   blocked -> "wall_tok" (Kenney impactWood, CC0, pitched down: a dull wood knock) + a slate-grey dud puff at the contact.  # WK-175c
# PER-MODE SCOPE: the master refund_gates_on applies ONLY in the mode families listed in wk175_gate_modes ("brawl", "trials",  # WK-175c
# "sports" = every SportsMode court). A goat whose mode can't be resolved (dev scenes) follows the master alone. Today the master is  # WK-175c
# false, so this list changes nothing. THE BRAWL FLIP is the one line refund_gates_on = true (list default = brawl only); the  # WK-175c
# sports flip later is adding "sports" here. QA arms: env GB_WK175=wr (or GB_WK135_GATES=1) widens the list to every mode unless  # WK-175c
# env GB_WK175_MODES=brawl,sports,... names it.  # WK-175c
var wk175_gate_modes: Array[String] = ["brawl"]   # mode families the WK-175 master applies in (brawl / trials / sports). Inert while refund_gates_on = false  # WK-175c
const WK175C_ALL_MODES: Array[String] = ["brawl", "trials", "sports"]   # what an env-armed QA run covers  # WK-175c
var wk175c_cues_on: bool = true               # false = no wall ding / tok / flare / puff (WR stays silent, as pre-WK-175c)  # WK-175c
var wk175c_ding_db: float = -14.5             # volume_db of a HUMAN goat's paying-wall ding (2 dB over the sports arc tick: brawl's bounce bed is 4 dB louder)  # WK-175c
var wk175c_ding_cpu_db: float = -20.5         # CPU goat's ding: 6 dB under (the wk183_ding_cpu_db pattern)  # WK-175c
var wk175c_ding_gap_s: float = 0.25           # min GAME s between two wall cues of the same goat that both PAY  # WK-175c
var wk175c_tok_db: float = -12.0              # volume_db of a HUMAN goat's blocked-wall tok (impactWood active RMS -17.4 dBFS vs the ding's -14.3)  # WK-175c
var wk175c_tok_cpu_db: float = -18.0          # CPU goat's tok: 6 dB under  # WK-175c
var wk175c_tok_pitch: float = 0.8             # tok pitch scale: the ~150 Hz wood knock dropped to ~120 Hz (dull; gate_clonk sits at x1.25)  # WK-175c
var wk175c_tok_gap_s: float = 0.35            # min GAME s between two toks of the same goat (a FLY-held wall hug knocks ~3/s, never buzzes)  # WK-175c
var wk175c_flare_s: float = 0.35              # s the paying-wall jetpack flare lasts (decays linearly)  # WK-175c
var wk175c_flare_scale: float = 1.7           # x flame size at the flare's start (on top of the live thrust / supercharge size)  # WK-175c
var wk175c_flare_tint: Color = Color(1.9, 1.7, 1.15, 1.0)   # flame modulate at the flare's start (warm over-bright; never cyan = Unlimited Boost)  # WK-175c
var wk175c_glow_color: Color = Color(1.0, 0.82, 0.32, 1.0)  # additive nozzle glow at the flare's start (also shows when coasting, flame off)  # WK-175c
var wk175c_glow_scale: float = 1.5            # glow_01 (128 px) scale at the flare's start (shrinks to 0.6 x this)  # WK-175c
var wk175c_burst_amount: int = 14            # fire licks in the paying-wall flare burst out of the nozzle (Juice; shows even when coasting)  # WK-175c
var wk175c_burst_speed: float = 420.0         # px/s max of that burst (out of the nozzle, opposite the aim)  # WK-175c
var wk175c_puff_color: Color = Color(0.52, 0.52, 0.56, 1.0)   # tok dud puff at the CONTACT: mid-grey soft smoke (lighter than night skies, darker than the pale posts / day skies; the bounce dust is white sparks)  # WK-175c
var wk175c_puff_amount: int = 6               # soft smoke blobs in the tok puff  # WK-175c
var wk175c_puff_scale: float = 1.2            # puff_soft (128 px; its opaque core is ~36 px) blob scale (max; min = 0.7 x), grows 0.6 -> 1.0 over its life  # WK-175c
var wk175c_sputter_color: Color = Color(0.74, 0.74, 0.78, 1.0)  # tok jetpack SPUTTER: a light-grey smoke cough out of the nozzle (reads on night skies; the mirror of the paid fire flare)  # WK-175c
var wk175c_sputter_amount: int = 6            # smoke blobs in the sputter  # WK-175c
var wk175c_sputter_scale: float = 1.8          # puff_soft (128 px; ~36 px core) sputter blob scale (max; min = 0.6 x)  # WK-175c
var wk175c_puff_speed: float = 110.0          # px/s the blobs leave the contact (normal +/- 80 deg; they sag under gravity: a fizzle)  # WK-175c
var wk175c_puff_s: float = 0.6                # s the tok puff + sputter live  # WK-175c

## WK-175c: is the WK-175 master in scope for a goat in mode family `mode` ("" = unresolved -> follows the master alone)?  # WK-175c
func wk175c_mode_in_scope(mode: StringName) -> bool:  # WK-175c
	return mode == &"" or wk175_gate_modes.has(String(mode))  # WK-175c

## WK-175c: env-armed gate runs (GB_WK175 on, or the legacy GB_WK135_GATES=1) cover every mode, as the WK-175 A/B did;  # WK-175c
## GB_WK175_MODES (comma list) names the modes instead. Called last in _ready.  # WK-175c
func _wk175c_env_modes(g135: String, g175: String, modes: String) -> void:  # WK-175c
	var armed: bool = g135 == "1" or (g175.strip_edges() != "" and refund_gates_on)  # WK-175c
	if armed:  # WK-175c
		wk175_gate_modes = WK175C_ALL_MODES.duplicate()  # WK-175c
	if modes.strip_edges() != "":  # WK-175c
		var out: Array[String] = []  # WK-175c
		for raw in modes.to_lower().split(",", false):  # WK-175c
			out.append(raw.strip_edges())  # WK-175c
		wk175_gate_modes = out  # WK-175c
