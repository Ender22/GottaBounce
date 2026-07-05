class_name Bomb
extends Area2D
## LETHAL BOMB / LANDMINE — a radial-blast hazard (docs/specs/v6_party_gimmicks_circuits.md §2.4 +
## §2.0 lethal doctrine; ball-punt per docs/specs/v8_sports_courts.md §3.2). It sits, telegraphs, and
## DETONATES: at the detonation instant everyone in its INNER kill radius DIES via the EXISTING kill
## pipeline (`body.kill(&"ring_out", null)` — the SAME path spikes/SpinningHammer/Crusher use, NOT a
## shove, NO new death path), and every impulsable body (players + StormBall props) AND the sports Ball
## in the OUTER blast radius takes a radial KNOCKBACK/PUNT away from the epicentre — the shipped
## `Forces.apply_radial_impulse` (FEEL §4.1) for players/props, and `Ball.receive_hazard_impulse` (the
## one mode-owned ball hook, same falloff) for the ball. It is a direct sibling of SpinningHammer /
## Crusher / FallingDebris and reuses their plumbing: a lethal-contact Area2D on LAYER_HAZARDS whose
## overlaps are read at the detonation frame, a deterministic clock, self-rendering `_draw` telegraphy,
## and LevelLoader wiring.
##
## DOCTRINE (§2.0):
##   (1) LETHAL by default — detonation routes overlapping bodies to kill(&"ring_out"); no new impulse
##       KILLS (the blast impulse is knockback only; the off-screen result is the killer). The ONLY new
##       force is a radial KNOCKBACK, which reuses the shipped explosion form (Forces / the ball hook).
##   (2) TELEGRAPHY — a fuse that BEEPS + BLINKS at an accelerating rate, plus an expanding warning ring
##       that shows the EXACT lethal radius, for `telegraph_lead` seconds before it blows. You see
##       precisely where + when it is lethal and clear the ring. A landmine also draws its trigger ring.
##   (3) FAIRNESS — the blast radius is finite + telegraphed; the fuse/telegraph lead gives time to
##       escape; the safe standoff is outside a visible ring. Placement (symmetry, clear of goal mouths)
##       is a level-design constraint, not code.
##   (4) CREDIT (INV-9) — the bomb is NOT a Player, so it NEVER sets last_attacker. A blast kill with no
##       attacker resolves as an uncredited self-fall (killer = -1); a rival who knocked/tagged the
##       victim into the blast within kill_credit_window_ringout (6.0s) is credited by the EXISTING
##       ring-out window. No invented environment scorer.
##
## TRIGGER MODES (JSON "trigger"):
##   "fuse"      — arms on combat_started (after `arm_delay`), counts down `fuse_s`, then detonates.
##                 The final `telegraph_lead` seconds are the fast-blink warning. Recurs on `recur`.
##   "proximity" — a LANDMINE: arms, then sits dormant (idle blink + a visible trigger ring) until a
##                 live player enters `trigger_radius`, then telegraphs for `telegraph_lead` and blows.
##
## All params come from level JSON (INV-7). The blast is MODE-OWNED: the KILL reuses the fenced
## kill(&"ring_out") path untouched, and the KNOCKBACK reuses the shipped explosion impulse (Forces +
## the ball hook) — NO player-feel Tuning constant is written (fence per §2.0 / §7).

const LAYER_HAZARDS := 1 << 3               # 8 — layer 4, the instakill hazard layer (Hazard.gd's layer)
const MASK_TARGETS := (1 << 0) | (1 << 1)   # players (1) + enemies/props (2), matching Hazard.gd

# --- Glossy Toybox bomb sprite (pays down the no-code-drawn-assets debt; owner-flagged). A glossy black
# round cartoon bomb with a lit fuse spark baked in. The image is 591x695; the BOMB BALL centre sits at
# image (297,435), so offsetting by (0, -88) from the texture centre (295,347) lands the ball centre on
# the node origin, which is placed at `center`. Scaled so the ball reads ~140px across (body size, well
# inside the telegraphed kill_radius). Since the fuse spark is IN the sprite, the code fuse-spark/LED is
# dropped; state now reads purely from the (kept) warning rings + detonation flash. ---
const BOMB_TEX: Texture2D = preload("res://assets/hazards/bomb.png")
const BOMB_BODY_SCALE := 0.26               # image ball radius ~265px -> ~69px visible body radius
const BOMB_BALL_OFFSET_Y := -88.0           # texture-centre -> ball-centre shift (px, pre-scale)
var _body: Sprite2D

# --- config (from JSON; all data, no player-feel Tuning) ---
var center: Vector2 = Vector2.ZERO
var blast_radius: float = 320.0        # OUTER radius: the knockback/punt extent (impulse falloff to 0 here)
var kill_radius: float = 0.0           # INNER radius: instakill zone (default = blast_radius * 0.6)
var trigger: String = "fuse"           # "fuse" | "proximity"
var fuse_s: float = 1.6                # fuse mode: seconds from arm to detonation
var trigger_radius: float = 200.0      # proximity mode: a live player inside this arms the countdown
var telegraph_lead: float = 1.1        # seconds of accelerating fast-blink warning before the blast
var knockback_only: bool = false       # true = never lethal (pure punt/knockback bumper); default false
var recur: float = -1.0                # seconds to RE-ARM after a blast; < 0 = one-shot (never recurs)
var arm_delay: float = 0.0             # grace before the FIRST arm (added to the combat_started gate)
var impulse_center: float = -1.0       # blast knockback magnitude at epicentre; < 0 = use Tuning default

enum { UNARMED, ARMED, TELEGRAPH, SPENT }
var _state: int = UNARMED
var _t: float = 0.0                    # global clock (seconds; drives blink/flash phase)
var _fuse_left: float = 0.0            # fuse mode: seconds remaining until detonation (once armed)
var _tele_left: float = 0.0            # seconds remaining in the active telegraph window
var _cool_left: float = 0.0            # SPENT mode: seconds until re-arm (recur)
var _flash_t: float = 0.0              # >0 for a short window right after a blast (detonation VFX)
var _armed_started := false            # has combat_started fired (or we armed immediately)?
var _lethal := false                   # combat-live gate (shared hazard doctrine): arming + detonation
                                       # are inert until EventBus.combat_started and re-inert on
                                       # EventBus.combat_ended, so a mine can never kill a player frozen
                                       # at spawn during STAGE_INTRO/COUNTDOWN (or during a STAGE_END freeze).
var _shape: CollisionShape2D
var _last_beep := -1                   # accelerating-tick bookkeeping (one sfx per blink)

func setup_from_json(o: Dictionary) -> void:
	var cc = o.get("center", null)
	if cc == null:
		center = Vector2(float(o.get("x", 0.0)), float(o.get("y", 0.0)))
	else:
		center = Vector2(float(cc.get("x", 0.0)), float(cc.get("y", 0.0)))
	blast_radius = maxf(20.0, float(o.get("blast_radius", 320.0)))
	kill_radius = float(o.get("kill_radius", blast_radius * 0.6))
	kill_radius = clampf(kill_radius, 0.0, blast_radius)
	trigger = str(o.get("trigger", "fuse"))
	fuse_s = maxf(0.15, float(o.get("fuse_s", 1.6)))
	trigger_radius = maxf(20.0, float(o.get("trigger_radius", 200.0)))
	telegraph_lead = clampf(float(o.get("telegraph_lead", 1.1)), 0.15, fuse_s)
	knockback_only = bool(o.get("knockback_only", false))
	recur = float(o.get("recur", -1.0))
	arm_delay = maxf(0.0, float(o.get("arm_delay", 0.0)))
	impulse_center = float(o.get("impulse_center", -1.0))

func _ready() -> void:
	# node at world origin: local == global, so _draw + the kill-shape are all in world coords.
	position = Vector2.ZERO
	collision_layer = LAYER_HAZARDS
	collision_mask = MASK_TARGETS
	monitoring = true
	set_meta("hazard", true)
	set_meta("bomb", true)
	# the lethal-check Area2D shape IS the inner kill radius — overlaps are tracked continuously and
	# read only at the detonation frame (the SpinningHammer pattern, fired once instead of every frame).
	_shape = CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = maxf(1.0, kill_radius)
	_shape.shape = circ
	_shape.position = center
	add_child(_shape)
	z_index = 40   # over platforms/void, under HUD
	# the bomb-body sprite: ball centre pinned to `center`, added AFTER _draw so the opaque body renders
	# on top of the (kept) ground warning rings, exactly as the old code-drawn casing did.
	_body = Sprite2D.new()
	_body.texture = BOMB_TEX
	_body.centered = true
	_body.offset = Vector2(0.0, BOMB_BALL_OFFSET_Y)
	_body.scale = Vector2(BOMB_BODY_SCALE, BOMB_BODY_SCALE)
	_body.position = center
	add_child(_body)
	# arm on the starting gun (so the countdown/intro never detonates a fuse early); if combat has
	# already started (e.g. late add) we arm immediately on the first frame via the fallback below.
	if not EventBus.combat_started.is_connected(_on_combat_started):
		EventBus.combat_started.connect(_on_combat_started)
	if not EventBus.combat_ended.is_connected(_on_combat_ended):
		EventBus.combat_ended.connect(_on_combat_ended)

func _on_combat_started() -> void:
	_armed_started = true
	_lethal = true

## Stage's combat closed: go inert. Cancel any in-flight fuse/telegraph so a STAGE_END freeze never
## detonates on a frozen player; a one-shot SPENT husk stays spent. Re-arms fresh next combat_started.
func _on_combat_ended() -> void:
	_lethal = false
	if _state == ARMED or _state == TELEGRAPH:
		_state = UNARMED

## Enter the ARMED state fresh (initial arm and every re-arm on recur).
func _arm() -> void:
	_state = ARMED
	_fuse_left = fuse_s
	_tele_left = 0.0
	_last_beep = -1

func _physics_process(delta: float) -> void:
	_t += delta
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - delta)
	# fallback: if combat_started never fires in this context (e.g. a placed-ball sports dev test with no
	# match state machine), self-arm anyway so the bomb stays functional there. The wait (arm_delay + 6s)
	# is DELIBERATELY longer than any real intro+countdown (~2-3s), so in a live match combat_started
	# always latches _armed_started/_lethal first and this fallback NEVER pre-empts the pre-match gate.
	if not _armed_started and _t >= maxf(arm_delay, 0.0) + 6.0:
		_armed_started = true
		_lethal = true
	match _state:
		UNARMED:
			# arming requires combat to be live (the gate): never arm during STAGE_INTRO/COUNTDOWN.
			if _armed_started and _lethal and _t >= arm_delay:
				_arm()
		ARMED:
			_tick_armed(delta)
		TELEGRAPH:
			_tick_telegraph(delta)
		SPENT:
			_cool_left -= delta
			if recur >= 0.0 and _cool_left <= 0.0:
				_arm()
	_update_body()
	queue_redraw()

# Dim the bomb-body sprite for the spent states (the old casing read scorched/regenerating there).
func _update_body() -> void:
	if _body == null:
		return
	if _state == SPENT and _cool_left == INF:
		_body.modulate = Color(0.30, 0.28, 0.28, 0.95)                 # scorched, inert husk
	elif _state == SPENT:
		var regen := 1.0 - clampf(_cool_left / maxf(0.001, recur), 0.0, 1.0)
		_body.modulate = Color(0.34, 0.34, 0.38).lerp(Color.WHITE, regen)  # regenerating on recur
	else:
		_body.modulate = Color.WHITE

## ARMED: fuse mode counts the fuse down (entering TELEGRAPH for its final lead); proximity mode waits
## for a live player inside trigger_radius, then enters TELEGRAPH.
func _tick_armed(delta: float) -> void:
	if trigger == "proximity":
		if _player_within(trigger_radius):
			_enter_telegraph()
		return
	# fuse mode
	_fuse_left -= delta
	if _fuse_left <= telegraph_lead:
		_enter_telegraph()

func _enter_telegraph() -> void:
	_state = TELEGRAPH
	_tele_left = telegraph_lead
	_last_beep = -1

func _tick_telegraph(delta: float) -> void:
	_tele_left -= delta
	# accelerating beep: blink frequency ramps from ~4 Hz to ~14 Hz as the blast nears.
	var prog := 1.0 - clampf(_tele_left / maxf(0.001, telegraph_lead), 0.0, 1.0)
	var freq := lerpf(4.0, 14.0, prog)
	var beep := int(_t * freq)
	if beep != _last_beep:
		_last_beep = beep
		AudioManager.play_sfx("countdown", {"volume_db": -10.0, "pitch": 1.4 + 0.6 * prog})
	if _tele_left <= 0.0:
		_detonate()

## The blast. (1) KILL every live body currently overlapping the inner kill-radius Area2D via the
## EXISTING kill pipeline (unless knockback_only). (2) Radial KNOCKBACK on all impulsable bodies
## (players + StormBall props) in the outer blast_radius via the shipped Forces path. (3) PUNT the
## sports Ball (not in the impulsable group) via its one mode-owned hook, with the SAME linear falloff.
func _detonate() -> void:
	var mag := impulse_center if impulse_center >= 0.0 else Tuning.explosion_impulse_center
	if not knockback_only:
		_kill_in_radius()
	# (2) players + props knockback (Star/shield-immune bodies self-ignore; dead bodies self-ignore).
	Forces.apply_radial_impulse(self, center, blast_radius, mag)
	# (3) the sports ball — a prop that is NOT in the "impulsable" group, so punt it explicitly with
	# the identical linear-falloff radial impulse (FEEL §4.1) via its mode-owned hook.
	_punt_balls(mag)
	# VFX + audio: our own expanding blast flash (self-drawn) + the shipped explosion feedback
	# (shockwave ring + shake + rumble + hitstop via Juice, explode sfx via AudioManager) — both
	# listen to EventBus.exploded, so one emit drives the whole shared explosion presentation.
	_flash_t = 0.4
	EventBus.exploded.emit(center, blast_radius)
	# recur / one-shot bookkeeping.
	if recur >= 0.0:
		_state = SPENT
		_cool_left = recur
	else:
		_state = SPENT
		_cool_left = INF   # one-shot: stays inert forever (drawn scorched)

## Read the continuously-tracked overlaps of the inner kill-radius Area2D at THIS instant and kill each
## live body via the EXISTING pipeline with cause &"ring_out" (§2.0#1). No attacker is passed (the bomb
## is not a Player); the 6.0s ring-out window credits a rival who knocked the victim in, else self-fall.
func _kill_in_radius() -> void:
	if not _lethal:
		return   # belt-and-suspenders: never kill outside live combat (arming is already gated).
	for body in get_overlapping_bodies():
		if not is_instance_valid(body):
			continue
		if body.has_method("is_dead") and body.is_dead():
			continue
		if body.has_method("kill"):
			body.kill(&"ring_out", null)

func _punt_balls(mag: float) -> void:
	for b in get_tree().get_nodes_in_group("sports_ball"):
		if not is_instance_valid(b) or not b.has_method("receive_hazard_impulse"):
			continue
		var to_body: Vector2 = b.global_position - center
		var dist := to_body.length()
		if dist > blast_radius:
			continue
		var falloff := 1.0 - dist / blast_radius            # linear falloff (FEEL §4.1)
		var dir := to_body.normalized() if dist > 0.001 else Vector2.UP
		b.receive_hazard_impulse(dir * mag * falloff)

## Is a LIVE player within `r` of the bomb centre? (proximity trigger.)
func _player_within(r: float) -> bool:
	for p in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(p):
			continue
		if p.has_method("is_dead") and p.is_dead():
			continue
		if (p.global_position - center).length() <= r:
			return true
	return false

# ------------------------------------------------------------------ telegraphy (INV-12: display only)
func _draw() -> void:
	# 1) proximity trigger ring (armed + waiting): a faint dashed danger-zone read so it is dodgeable.
	if trigger == "proximity" and _state == ARMED:
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		draw_arc(center, trigger_radius, 0.0, TAU, 48, Color(0.90, 0.18, 0.16, 0.10 + 0.10 * pulse), 3.0)
	# 2) the active telegraph: an expanding ring that grows to the EXACT lethal radius + a blast-extent
	#    ring, both getting hotter as the blast nears (Pillar 5 — you see where/when it is lethal).
	if _state == TELEGRAPH:
		var prog := 1.0 - clampf(_tele_left / maxf(0.001, telegraph_lead), 0.0, 1.0)
		var kr := maxf(1.0, kill_radius)
		# expanding fill toward the kill radius (the lethal footprint filling in)
		draw_circle(center, kr * prog, Color(0.90, 0.18, 0.16, 0.16 + 0.20 * prog))
		# the exact lethal-radius ring (bold)
		draw_arc(center, kr, 0.0, TAU, 56, Color(0.95, 0.20, 0.16, 0.55 + 0.40 * prog), 6.0)
		# the outer blast/knockback-extent ring (fainter)
		draw_arc(center, blast_radius, 0.0, TAU, 64, Color(0.95, 0.55, 0.20, 0.30 + 0.25 * prog), 4.0)
	# 3) the detonation flash: a bright expanding shockwave ring for a short window post-blast.
	if _flash_t > 0.0:
		var f := _flash_t / 0.4                              # 1 -> 0
		var rr := lerpf(kill_radius * 0.4, blast_radius, 1.0 - f)
		draw_circle(center, rr, Color(1.0, 0.85, 0.4, 0.35 * f))
		draw_arc(center, rr, 0.0, TAU, 64, Color(1.0, 0.95, 0.7, 0.9 * f), 10.0 * f + 2.0)
	# 4) the bomb body itself is now the bomb.png sprite (child, kept fresh in _update_body).
