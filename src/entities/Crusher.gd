class_name Crusher
extends Area2D
## LETHAL crush-hazard (docs/specs/v6_party_gimmicks_circuits.md §2.2 + §2.0 lethal doctrine). Two
## steel heads (or a head + a fixed anvil) periodically SLAM together on a telegraphed rhythm and
## CRUSH-kill anyone caught in their path at the moment of impact; then RETRACT, leaving a clear open
## gap (the safe beat) for the rest of the cycle. It is a direct sibling of `SpinningHammer` and reuses
## the SAME plumbing: a lethal-contact Area2D on LAYER_HAZARDS whose overlap routes to
## `body.kill(&"ring_out", null)` (the EXISTING kill path spikes/Hazard.gd use — NOT a shove), a
## deterministic phase-clock oscillator with a long OPEN DWELL (the clear beat), self-rendering `_draw`
## telegraphy (hazard-stripe faces + a windup shudder/flash before each slam), and LevelLoader wiring.
##
## DOCTRINE (§2.0):
##   (1) LETHAL by default — the heads instakill on contact via kill(&"ring_out"); no new death
##       impulse/hitstun, no shove. Identical to the hammer head.
##   (2) TELEGRAPHY — a long OPEN DWELL (the clear safe beat), then a windup SHUDDER + hazard-red FLASH
##       on the closing faces for `telegraph_lead` seconds BEFORE a fast, readable close. The player
##       learns the rhythm and clears the crush lane on the open beat.
##   (3) FAIRNESS — the open dwell is long enough to cross/leave with skill; the heads only sweep their
##       own lane (refuge always exists beside/above it); symmetric — everyone faces the same threat.
##       A crusher that closes with no windup / no open beat is a DO-NOT-SHIP variant (§2.2).
##   (4) CREDIT (INV-9) — the crusher is NOT a Player, so it NEVER sets last_attacker. A kill with no
##       attacker resolves as an uncredited self-fall (killer = -1); a rival who knocked/tagged the
##       victim within kill_credit_window_ringout (6.0s) is credited by the EXISTING ring-out window.
##       No invented environment scorer.
##
## Motion is a DETERMINISTIC phase clock (no physics ODE, no randomness) — the same self-rendering,
## self-clocked entity shape SpinningHammer established. All params come from level JSON (INV-7); NO
## Tuning constant is touched — the kill pipeline is reused as-is (fence per §2.0 / §7).
##
## Collision: on LAYER_HAZARDS (layer 4, the instakill layer Hazard.gd lives on), sensing players +
## props. Overlap-only (the de-risked ship, matching the hammer): the heads clip the visual but the
## overlap kills; solid collision is an optional polish follow-up.

const LAYER_HAZARDS := 1 << 3               # 8 — layer 4, the instakill hazard layer (Hazard.gd's layer)
const MASK_TARGETS := (1 << 0) | (1 << 1)   # players (1) + enemies/props (2), matching Hazard.gd

# --- Glossy Toybox crusher-head sprite (pays down the no-code-drawn-assets debt; owner-flagged; same
# pattern as the hammer/bomb wiring). A glossy metallic toy PRESS block with a yellow/black hazard
# chevron band + rivets. Image is 774x657 (ratio ~1.178, a near-exact match for the horizontal head's
# 200x170 = ~1.176). Each head gets its OWN centered Sprite2D pinned to that head's collision-shape
# centre and scaled so the visible block == the head's collider extents (so the block's INNER edge sits
# exactly on the head's lethal contact face). The sprite's LOCAL x maps ALONG the slam axis and local y
# ACROSS it (rotated PI/2 for a vertical crusher); head2 is flipped along the axis (flip_h in local ==
# flip along the axis for BOTH orientations) so the pair MIRRORS and their striking faces point inward.
# The code-drawn head BODIES are replaced by these sprites; the windup SHUDDER + hazard-red danger band
# + guide rails stay as transient VFX (the fairness tell), and a windup FLASH tints the sprites hot. ---
const CRUSHER_TEX: Texture2D = preload("res://assets/hazards/crusher.png")
const CRUSHER_TEX_W := 774.0
const CRUSHER_TEX_H := 657.0
var _sprite1: Sprite2D
var _sprite2: Sprite2D

# --- geometry / config (from JSON; all data, no Tuning) ---
var center: Vector2 = Vector2.ZERO   # the crush point (both heads converge here)
var axis: String = "horizontal"      # "horizontal" (heads slam left<->right) | "vertical" (top<->bottom)
var head_len: float = 200.0          # head size ALONG the slam axis (the striking depth)
var head_w: float = 170.0            # head size ACROSS the slam axis (the lane width)
var open_gap: float = 560.0          # inner-face separation when fully OPEN (the passable safe gap)
var closed_gap: float = 30.0         # inner-face separation at full CLOSE (the crush gap)
var period_s: float = 2.6            # a full open->close->open cycle (owner: crusher ~2-3s)
var phase: float = 0.0               # 0..1 phase offset (multiple crushers can run offset rhythms)
var close_time: float = 0.34         # seconds of the fast, readable CLOSE ramp
var closed_time: float = 0.22        # seconds dwelling CLOSED (the lethal slam window)
var retract_time: float = 0.5        # seconds of the RETRACT (open) ramp
var telegraph_lead: float = 0.55     # windup shudder/flash lead BEFORE the close begins (fairness tell)
var anvil: bool = false              # true = head2 is a FIXED anvil (head + anvil); head1 does the travel

var _t: float = 0.0
var _c: float = 0.0                  # closedness in [0,1]: 0 = open, 1 = crushed
var _tele: float = 0.0               # telegraph intensity in [0,1] (windup shudder/flash)
var _open_dwell: float = 1.5         # derived: the OPEN safe beat (period minus the moving phases)
var _shape1: CollisionShape2D
var _shape2: CollisionShape2D
var _rng := RandomNumberGenerator.new()
# LETHAL-only-while-combat-is-live gate (shared hazard doctrine, see SpinningHammer). The heads still
# slam + telegraph during the intro/countdown so the rhythm reads, but the CRUSH-kill is suppressed
# until EventBus.combat_started and re-suppressed on EventBus.combat_ended — a player frozen at spawn
# in the crush lane during a pre-match phase is never killed (never left stuck-dead by PartyMatch).
var _lethal: bool = false

func setup_from_json(o: Dictionary) -> void:
	var cc = o.get("center", {"x": 0.0, "y": 0.0})
	center = Vector2(float(cc.get("x", 0.0)), float(cc.get("y", 0.0)))
	axis = str(o.get("axis", "horizontal"))
	head_len = float(o.get("head_len", 200.0))
	head_w = float(o.get("head_w", 170.0))
	open_gap = float(o.get("open_gap", 560.0))
	closed_gap = maxf(0.0, float(o.get("closed_gap", 30.0)))
	period_s = maxf(0.4, float(o.get("period_s", 2.6)))
	phase = float(o.get("phase", 0.0))
	close_time = maxf(0.05, float(o.get("close_time", 0.34)))
	closed_time = maxf(0.02, float(o.get("closed_time", 0.22)))
	retract_time = maxf(0.05, float(o.get("retract_time", 0.5)))
	telegraph_lead = maxf(0.0, float(o.get("telegraph_lead", 0.55)))
	anvil = bool(o.get("anvil", false))

func _ready() -> void:
	# node at world origin: local == global, so _draw / shape positions are all in world coords.
	position = Vector2.ZERO
	collision_layer = LAYER_HAZARDS
	collision_mask = MASK_TARGETS
	monitoring = true
	set_meta("hazard", true)
	set_meta("crusher", true)
	# the OPEN DWELL is whatever is left of the period after the three moving phases (the clear beat).
	_open_dwell = maxf(0.1, period_s - close_time - closed_time - retract_time)
	_shape1 = _make_head_shape()
	_shape2 = _make_head_shape()
	add_child(_shape1)
	add_child(_shape2)
	# the head-body sprites: added AFTER the shapes and rendered on top of _draw (children draw after the
	# parent's _draw), so the glossy blocks sit over the danger band / rails exactly as the old opaque
	# code-drawn heads did. head1 native, head2 flipped along the axis so the pair mirrors face-to-face.
	_sprite1 = _make_head_sprite(false)
	_sprite2 = _make_head_sprite(true)
	add_child(_sprite1)
	add_child(_sprite2)
	_update(0.0)
	z_index = 40   # over platforms/void, under HUD
	# lethal gate: enable on the starting gun, disable when the stage's combat closes.
	if not EventBus.combat_started.is_connected(_on_combat_started):
		EventBus.combat_started.connect(_on_combat_started)
	if not EventBus.combat_ended.is_connected(_on_combat_ended):
		EventBus.combat_ended.connect(_on_combat_ended)

func _on_combat_started() -> void:
	_lethal = true

func _on_combat_ended() -> void:
	_lethal = false

func _make_head_shape() -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = _head_size()
	cs.shape = rect
	return cs

# One head-body sprite: centred, scaled so the block == the head collider extents (inner block edge on
# the lethal face), local x ALONG the slam axis. Rotated PI/2 for a vertical crusher; `flip` mirrors the
# block along the axis (local-x flip == along-axis flip for both orientations) so head2 faces head1.
func _make_head_sprite(flip: bool) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = CRUSHER_TEX
	s.centered = true
	s.flip_h = flip
	# local x -> along-axis extent (head_len), local y -> across-axis extent (head_w).
	s.scale = Vector2(head_len / CRUSHER_TEX_W, head_w / CRUSHER_TEX_H)
	s.rotation = (PI * 0.5) if axis == "vertical" else 0.0
	return s

func _head_size() -> Vector2:
	# head_len is ALONG the slam axis; head_w is ACROSS it.
	if axis == "vertical":
		return Vector2(head_w, head_len)
	return Vector2(head_len, head_w)

func _along() -> Vector2:
	return Vector2(0.0, 1.0) if axis == "vertical" else Vector2(1.0, 0.0)

## Phase clock in [0,1] cycle: a long OPEN dwell (c=0, the clear beat) -> fast CLOSE ramp (0->1) ->
## brief CLOSED dwell (c=1, the lethal slam) -> RETRACT ramp (1->0). Also derives the telegraph
## intensity (windup) over the last `telegraph_lead` seconds of the open dwell. Deterministic; the
## smootherstep ramps join the flat dwells with zero velocity discontinuity (natural, readable).
func _tick(t: float) -> void:
	var u := fposmod(t / period_s + phase, 1.0) * period_s   # seconds into the cycle
	_tele = 0.0
	# 1) OPEN dwell (the safe beat) — c = 0; telegraph ramps up over its final telegraph_lead seconds.
	if u < _open_dwell:
		_c = 0.0
		if telegraph_lead > 0.0 and u > _open_dwell - telegraph_lead:
			_tele = clampf((u - (_open_dwell - telegraph_lead)) / telegraph_lead, 0.0, 1.0)
		return
	u -= _open_dwell
	# 2) CLOSE ramp (fast, readable) — telegraph stays hot through the slam.
	if u < close_time:
		_c = _smoother(u / close_time)
		_tele = 1.0
		return
	u -= close_time
	# 3) CLOSED dwell (the lethal slam window).
	if u < closed_time:
		_c = 1.0
		_tele = 1.0
		return
	u -= closed_time
	# 4) RETRACT ramp (heads pull back open).
	_c = 1.0 - _smoother(clampf(u / retract_time, 0.0, 1.0))

static func _smoother(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)

## Head CENTER for head i (dir -1 = head1, +1 = head2) at the current closedness. Inner-face gap
## lerps open_gap -> closed_gap; the head center sits half a head_len beyond its inner face.
func _head_center(dir: float, c: float) -> Vector2:
	var gap := lerpf(open_gap, closed_gap, c)
	var off := gap * 0.5 + head_len * 0.5
	return center + _along() * (dir * off)

func _update(t: float) -> void:
	_tick(t)
	# anvil mode: head2 is fixed at its CLOSED position (the immovable anvil); head1 does all the travel.
	_shape1.position = _head_center(-1.0, _c)
	_shape2.position = _head_center(1.0, 1.0 if anvil else _c)
	_position_sprites()

# Ride the head-body sprites on their colliders. During the OPEN-dwell windup the sprites SHUDDER (the
# colliders are NOT moved — the tell is display-only, matching the old code-drawn shudder) and tint hot
# toward hazard-yellow-white as the slam nears, so the pre-slam warning still reads on the art itself.
func _position_sprites() -> void:
	if _sprite1 == null:
		return
	var shudder := Vector2.ZERO
	if _tele > 0.0 and _c <= 0.0:
		_rng.seed = hash(center) + int(_t * 120.0)
		shudder = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * (4.0 * _tele)
	_sprite1.position = _shape1.position + shudder
	_sprite2.position = _shape2.position - shudder
	var hot: Color = Color.WHITE.lerp(Color(1.35, 1.15, 0.75), _tele)   # windup flash on the faces
	_sprite1.modulate = hot
	_sprite2.modulate = hot

func _physics_process(delta: float) -> void:
	_t += delta
	_update(_t)
	queue_redraw()
	_kill_overlapping()

## LETHAL contact — the whole mechanic. Any live Killable body overlapping either head dies via the
## EXISTING kill pipeline with cause &"ring_out" (§2.0#1): no new impulse, no shove, no hitstun. The
## &"ring_out" cause inherits the 6.0s ring-out credit window, so a rival who knocked the victim in
## within the window is credited and an untouched victim is an uncredited self-fall (§2.0#4). The
## crusher NEVER passes itself as attacker (it is not a Player -> no invented environment scorer).
func _kill_overlapping() -> void:
	if not _lethal:
		return   # pre-combat / post-stage: the heads still slam + telegraph, but never crush-kill.
	for body in get_overlapping_bodies():
		if not is_instance_valid(body):
			continue
		if body.has_method("is_dead") and body.is_dead():
			continue
		if body.has_method("kill"):
			body.kill(&"ring_out", null)

# ------------------------------------------------------------------ telegraphy (INV-12: display only)
# The head BODIES are now the crusher.png sprites (children, kept fresh in _position_sprites). _draw keeps
# only the transient TELEGRAPH VFX: the faint guide RAILS (structural travel track) and the hazard-red
# danger BAND that reads the lethal crush lane during the windup/slam.
func _draw() -> void:
	var along := _along()
	# 1) the guide RAILS: faint tracks showing each head's full travel (open extent -> crush point).
	var rail := Color(0.30, 0.31, 0.36, 0.35)
	var r1_open := _head_center(-1.0, 0.0)
	var r2_open := _head_center(1.0, 0.0)
	draw_line(r1_open, r2_open, rail, 6.0)
	# 2) a hazard-red danger band across the crush lane during the windup/slam (reads the lethal zone).
	if _tele > 0.0:
		var perp := along.orthogonal()
		var lane_half := head_w * 0.5
		var danger := Color(0.86, 0.16, 0.16, 0.10 + 0.28 * _tele)
		var band := PackedVector2Array([
			center - along * (open_gap * 0.5) - perp * lane_half,
			center + along * (open_gap * 0.5) - perp * lane_half,
			center + along * (open_gap * 0.5) + perp * lane_half,
			center - along * (open_gap * 0.5) + perp * lane_half,
		])
		draw_colored_polygon(band, danger)
