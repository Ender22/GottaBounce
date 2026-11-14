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
