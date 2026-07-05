class_name FallingDebris
extends Node2D
## LETHAL falling-debris spawner (docs/specs/v6_party_gimmicks_circuits.md §2.3 + §2.0 lethal doctrine).
## Periodically DROPS giant balls/weights from the top on a cadence; each falling chunk is LETHAL on
## contact and despawns on landing / off-screen. Every drop is TELEGRAPHED by a ground shadow + hazard
## warning marker that grows at the impact column for `telegraph_lead` seconds BEFORE the chunk falls,
## so it is dodgeable. Sibling of `SpinningHammer` / `Crusher`: it reuses the SAME plumbing — the lethal
## contact is an Area2D on LAYER_HAZARDS whose overlap routes to `body.kill(&"ring_out", null)` (the
## EXISTING kill path spikes/Hazard.gd use — NOT a shove), a deterministic clock (cadence, no physics
## ODE), self-rendering `_draw` telegraphy (the spawner draws every shadow + chunk itself), and
## LevelLoader wiring. The chunk Area2Ds are lightweight invisible colliders the spawner drives.
##
## DOCTRINE (§2.0):
##   (1) LETHAL by default — a chunk overlap instakills via kill(&"ring_out"); no new impulse/hitstun.
##   (2) TELEGRAPHY — a growing shadow + a pulsing hazard-red reticle marks each impact column for
##       `telegraph_lead` seconds before the chunk exists; a drop line hints the fall path. Read it, step off.
##   (3) FAIRNESS — a CADENCE (one chunk every `cadence` s) with a hard `max_concurrent` cap, so debris
##       NEVER fills all footing at once — a safe column always exists each beat. Columns are spread so
##       no single spot is a guaranteed kill; symmetric (everyone under a marked column faces it equally).
##   (4) CREDIT (INV-9) — a chunk is NOT a Player, so it NEVER sets last_attacker. A kill with no
##       attacker resolves as an uncredited self-fall (killer = -1); a rival who knocked/tagged the
##       victim within kill_credit_window_ringout (6.0s) is credited by the EXISTING ring-out window.
##       No invented environment scorer.
##
## All params come from level JSON (INV-7); NO Tuning constant is touched (fence per §2.0 / §7).

const LAYER_HAZARDS := 1 << 3               # 8 — layer 4, the instakill hazard layer (Hazard.gd's layer)
const MASK_TARGETS := (1 << 0) | (1 << 1)   # players (1) + enemies/props (2), matching Hazard.gd

# --- Glossy Toybox wrecking-ball sprite (pays down the no-code-drawn-assets debt; owner-flagged; same
# pattern as the hammer/bomb/crusher wiring). A charcoal iron SPHERE with a rivet ring + a small eyelet
# loop on top. Image is 689x772: the SPHERE fills the bottom (diameter == the 689px image width) and the
# top ~83px is the decorative eyelet. Sphere CENTRE in image coords = (W/2, H - W/2) = (344.5, 427.5)
# (verified from the alpha silhouette: bbox bottom y=769 matches a circle of r=344.5 centred at y=427.5).
# Each falling chunk's grey code circle BODY is replaced by this sprite via draw_texture_rect, scaled so
# the visible sphere == 2*chunk_radius (with a small OVERSCALE so the metal always covers the lethal
# circle — fairness) and the sphere centre pinned to the chunk's physics position (eyelet sticks up). The
# ground shadow, the drop/warning line, the motion streak and the red hazard-rim danger arc stay as code
# telegraph. ---
const WBALL_TEX: Texture2D = preload("res://assets/hazards/wrecking_ball.png")
const WBALL_TEX_W := 689.0
const WBALL_TEX_H := 772.0
const WBALL_SPHERE_DIAM := 689.0            # sphere diameter in image px (== image width)
const WBALL_SPHERE_CX := 344.5              # sphere centre x in image px (W/2)
const WBALL_SPHERE_CY := 427.5              # sphere centre y in image px (H - diam/2; eyelet above)
const WBALL_OVERSCALE := 1.05               # metal slightly overhangs the lethal circle (fair reads)

# --- config (from JSON; all data, no Tuning) ---
var columns: Array = []              # explicit impact x's; if empty, random within [x_min, x_max]
var x_min: float = 0.0
var x_max: float = 0.0
var floor_y: float = 1080.0          # the impact/land line (where the shadow is drawn; chunk despawns here)
var spawn_y: float = -400.0          # y a chunk appears at (above the view) once its telegraph completes
var fall_speed: float = 1400.0       # px/s downward fall speed
var chunk_radius: float = 60.0       # the lethal ball radius
var cadence: float = 1.4             # seconds between drop STARTS (telegraph beginnings)
var cadence_variance: float = 0.0    # +/- random jitter on the cadence (0 = perfectly steady)
var telegraph_lead: float = 0.7      # shadow/warning lead before a chunk falls (fairness tell)
var max_concurrent: int = 2          # hard cap on live chunks + pending telegraphs (never a wall)
var start_delay: float = 0.6         # grace before the first drop begins telegraphing

var _t: float = 0.0
var _next_drop: float = 0.6          # time of the next telegraph start
var _col_i: int = 0                  # round-robins explicit columns for even spread
var _rng := RandomNumberGenerator.new()
# LETHAL-only-while-combat-is-live gate (shared hazard doctrine, see SpinningHammer). Chunks still
# telegraph + fall during the intro/countdown so the cadence reads, but a chunk's KILL is suppressed
# until EventBus.combat_started and re-suppressed on EventBus.combat_ended — a player frozen at spawn
# under a drop column during a pre-match phase is never killed (never left stuck-dead by PartyMatch).
var _lethal: bool = false
# pending telegraphs: [{ "x": float, "t": float (elapsed), "lead": float }]
var _telegraphs: Array = []
# live chunks: [{ "area": Area2D, "x": float, "y": float, "land_y": float }]
var _chunks: Array = []

func setup_from_json(o: Dictionary) -> void:
	if o.has("columns") and typeof(o["columns"]) == TYPE_ARRAY:
		for cx in o["columns"]:
			columns.append(float(cx))
	x_min = float(o.get("x_min", 0.0))
	x_max = float(o.get("x_max", 0.0))
	floor_y = float(o.get("floor_y", 1080.0))
	spawn_y = float(o.get("spawn_y", floor_y - 1400.0))
	fall_speed = maxf(50.0, float(o.get("fall_speed", 1400.0)))
	chunk_radius = maxf(4.0, float(o.get("chunk_radius", 60.0)))
	cadence = maxf(0.15, float(o.get("cadence", 1.4)))
	cadence_variance = maxf(0.0, float(o.get("cadence_variance", 0.0)))
	telegraph_lead = maxf(0.0, float(o.get("telegraph_lead", 0.7)))
	max_concurrent = maxi(1, int(o.get("max_concurrent", 2)))
	start_delay = maxf(0.0, float(o.get("start_delay", 0.6)))

func _ready() -> void:
	position = Vector2.ZERO   # world coords: _draw + chunk positions are all global
	set_meta("hazard", true)
	set_meta("falling_debris", true)
	_rng.seed = hash(Vector2(x_min + x_max, floor_y)) + columns.size()
	_next_drop = start_delay
	z_index = 41   # over platforms/void, under HUD; chunks + shadows self-drawn here
	# lethal gate: enable on the starting gun, disable when the stage's combat closes.
	if not EventBus.combat_started.is_connected(_on_combat_started):
		EventBus.combat_started.connect(_on_combat_started)
	if not EventBus.combat_ended.is_connected(_on_combat_ended):
		EventBus.combat_ended.connect(_on_combat_ended)

func _on_combat_started() -> void:
	_lethal = true

func _on_combat_ended() -> void:
	_lethal = false

func _physics_process(delta: float) -> void:
	_t += delta
	# --- schedule new drops on the cadence, capped by max_concurrent (fairness: never a wall) ---
	if _t >= _next_drop and (_telegraphs.size() + _chunks.size()) < max_concurrent:
		_begin_telegraph(_pick_column())
		var jitter := 0.0
		if cadence_variance > 0.0:
			jitter = _rng.randf_range(-cadence_variance, cadence_variance)
		_next_drop = _t + maxf(0.15, cadence + jitter)
	# --- advance telegraphs; a completed telegraph SPAWNS its chunk ---
	var i := _telegraphs.size() - 1
	while i >= 0:
		var tg: Dictionary = _telegraphs[i]
		tg["t"] = float(tg["t"]) + delta
		if float(tg["t"]) >= float(tg["lead"]):
			_spawn_chunk(float(tg["x"]))
			_telegraphs.remove_at(i)
		i -= 1
	# --- advance chunks; kill on overlap; despawn on landing / off the bottom ---
	var j := _chunks.size() - 1
	while j >= 0:
		var ch: Dictionary = _chunks[j]
		ch["y"] = float(ch["y"]) + fall_speed * delta
		var area: Area2D = ch["area"]
		if not is_instance_valid(area):
			_chunks.remove_at(j)
			j -= 1
			continue
		area.position = Vector2(float(ch["x"]), float(ch["y"]))
		_kill_overlapping(area)
		if float(ch["y"]) >= float(ch["land_y"]):
			_land_chunk(ch)
			_chunks.remove_at(j)
		j -= 1
	queue_redraw()

func _pick_column() -> float:
	if columns.size() > 0:
		var x := float(columns[_col_i % columns.size()])
		_col_i += 1
		return x
	if x_max > x_min:
		return _rng.randf_range(x_min, x_max)
	return x_min

func _begin_telegraph(x: float) -> void:
	_telegraphs.append({ "x": x, "t": 0.0, "lead": telegraph_lead })

## Spawn a lightweight lethal chunk collider (Area2D on LAYER_HAZARDS). It has NO visual child — the
## spawner draws it in _draw — and the spawner drives its position + overlap kills each frame.
func _spawn_chunk(x: float) -> void:
	var area := Area2D.new()
	area.collision_layer = LAYER_HAZARDS
	area.collision_mask = MASK_TARGETS
	area.monitoring = true
	area.set_meta("hazard", true)
	var cs := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = chunk_radius
	cs.shape = circ
	area.add_child(cs)
	area.position = Vector2(x, spawn_y)
	add_child(area)
	_chunks.append({ "area": area, "x": x, "y": spawn_y, "land_y": floor_y })

## LETHAL contact — the whole mechanic. Any live Killable body overlapping a chunk dies via the
## EXISTING kill pipeline with cause &"ring_out" (§2.0#1): no new impulse, no shove, no hitstun. The
## chunk NEVER passes itself as attacker (it is not a Player -> no invented environment scorer); a
## rival who knocked the victim under the chunk within the 6.0s ring-out window is credited, else the
## death is an uncredited self-fall (§2.0#4).
func _kill_overlapping(area: Area2D) -> void:
	if not _lethal:
		return   # pre-combat / post-stage: chunks still fall + telegraph, but never kill.
	for body in area.get_overlapping_bodies():
		if not is_instance_valid(body):
			continue
		if body.has_method("is_dead") and body.is_dead():
			continue
		if body.has_method("kill"):
			body.kill(&"ring_out", null)

## A chunk reached its land line: a one-shot dust puff (pure VFX, no collider), then free the chunk.
func _land_chunk(ch: Dictionary) -> void:
	var area: Area2D = ch["area"]
	_spawn_impact_puff(Vector2(float(ch["x"]), float(ch["land_y"])))
	if is_instance_valid(area):
		area.queue_free()

func _spawn_impact_puff(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 1.0
	p.amount = 16
	p.lifetime = 0.5
	p.position = at
	p.direction = Vector2.UP
	p.spread = 120.0
	p.gravity = Vector2(0, 900)
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 380.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0
	var grad := Gradient.new()
	grad.set_color(0, Color(0.55, 0.53, 0.50, 0.9))
	grad.set_color(1, Color(0.35, 0.33, 0.30, 0.0))
	p.color_ramp = grad
	p.z_index = 6
	add_child(p)
	get_tree().create_timer(0.9).timeout.connect(p.queue_free)

# ------------------------------------------------------------------ telegraphy (INV-12: display only)
func _draw() -> void:
	# 1) each pending telegraph: a growing ground shadow + a pulsing hazard-red reticle + a drop line.
	for tg in _telegraphs:
		var x := float(tg["x"])
		var prog: float = clampf(float(tg["t"]) / maxf(0.001, float(tg["lead"])), 0.0, 1.0)
		var at := Vector2(x, floor_y)
		# ground shadow ellipse (grows toward impact) — the "something is coming down HERE" read.
		var rx := chunk_radius * (0.5 + 0.9 * prog)
		var ry := rx * 0.34
		_draw_ellipse(at, rx, ry, Color(0.03, 0.04, 0.06, 0.30 + 0.30 * prog))
		# pulsing hazard reticle ring
		var pulse := 0.55 + 0.45 * sin(_t * 22.0)
		var ring := Color(0.90, 0.18, 0.16, 0.35 + 0.45 * prog * pulse)
		draw_arc(at, rx * 1.15, 0.0, TAU, 40, ring, 4.0)
		# faint drop line from above hinting the fall path
		draw_line(Vector2(x, spawn_y * 0.5 + floor_y * 0.5), at, Color(0.90, 0.18, 0.16, 0.10 + 0.18 * prog), 3.0)
	# 2) each live chunk: the wrecking_ball sprite BODY + a short motion streak + a red hazard rim.
	for ch in _chunks:
		var c := Vector2(float(ch["x"]), float(ch["y"]))
		# motion streak (reads speed/direction) — kept transient telegraph VFX
		draw_line(c - Vector2(0, chunk_radius * 1.6), c, Color(0.10, 0.11, 0.14, 0.35), chunk_radius * 0.9)
		# BODY: the wrecking_ball sprite (sphere == 2*chunk_radius, centred on the chunk, eyelet up)
		_draw_wrecking_ball(c, chunk_radius)
		# hazard rim (red danger arc) — kept transient telegraph, drawn over the sphere edge
		draw_arc(c, chunk_radius * 0.92, 0.0, TAU, 32, Color(0.86, 0.16, 0.16, 0.85), 5.0)

# Draw the wrecking_ball sprite so its metal SPHERE (image bottom, diameter WBALL_SPHERE_DIAM) is
# centred on `c` with a visible diameter of 2*r*OVERSCALE, and the eyelet sticks up ABOVE it. The full
# image (sphere + eyelet) is stretched into a rect via draw_texture_rect; the top-left is derived so the
# sphere centre image point (WBALL_SPHERE_CX, WBALL_SPHERE_CY) lands exactly on `c`.
func _draw_wrecking_ball(c: Vector2, r: float) -> void:
	var s := (2.0 * r * WBALL_OVERSCALE) / WBALL_SPHERE_DIAM
	var top_left := Vector2(c.x - WBALL_SPHERE_CX * s, c.y - WBALL_SPHERE_CY * s)
	draw_texture_rect(WBALL_TEX, Rect2(top_left, Vector2(WBALL_TEX_W * s, WBALL_TEX_H * s)), false)

func _draw_ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var n := 24
	for k in range(n):
		var a := TAU * float(k) / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)
