class_name DestructibleBlock
extends StaticBody2D
## A SURFACE that BREAKS and disappears when destroyed (docs/specs/v6_party_gimmicks_circuits.md
## §2.5 destructible_block + §2.8 COLLAPSING ARENA). A bounce-tier StaticBody2D (identical bounce
## contract to a normal platform — the body-agnostic BounceResolver reads its tier via meta) that
## erodes on a TELEGRAPHED trigger, then removes its collider so footing is lost (players standing
## on it must FLY). Modelled on the SpinningHammer self-rendering / self-clocked entity pattern
## (LevelLoader constructs + configures; the entity owns its motion/telegraphy/_draw).
##
## DOCTRINE (§2.5): a destructible is a SURFACE, NOT a hazard — it never contact-kills. It is pure
## GEOMETRY; the LETHALITY is the void/fall once the ground is gone. A resulting ring-out resolves
## through the EXISTING credit path unchanged (kill(&"ring_out") in PartyMatch's bounds check): an
## untagged fall is an uncredited self-fall (killer = -1); a rival who knocked the victim into the
## now-open void within kill_credit_window_ringout (6.0s) is credited. This entity NEVER sets
## last_attacker and invents NO scorer (INV-9). NO Tuning/lethality/feel constant is touched.
##
## BREAK TRIGGERS (data-driven, additive — a block breaks by WHICHEVER fires first):
##   break_on = "timed"  — erodes at `break_time` seconds after COMBAT starts (the collapsing-arena
##                         cascade driver). A telegraph (cracks + shudder + flash) runs for
##                         `telegraph_s` BEFORE it vanishes (fairness: the player sees it going).
##   break_on = "smash"  — a super-active OR high-speed (>= smash_impact_min) player contact costs 1
##                         hp; at hp<=0 a short telegraph plays, then it breaks ("breaks when hit").
##   break_on = "hit"    — any real bounce (>= HIT_SPEED_GATE) costs 1 hp (breaks after N bounces).
## `break_time` and `hp` are independent: a block may have BOTH (timed cascade AND smash-breakable).
##
## COUNT-REMAINING (for Trials DESTROY_ALL, §5): every live block is in group `group` (default
## "destructible") AND the umbrella group "destructible". A mode/level queries
## get_tree().get_nodes_in_group(group).size() for "how many left"; a broken block leaves both.

const LAYER_SURFACES := 1 << 2       # 4 — bounce_surfaces layer (matches LevelLoader platforms)
const LAYER_PLAYERS := 1 << 0        # 1 — detection area senses players
const HIT_SPEED_GATE := 300.0        # "hit" mode: a contact this fast or faster counts as a bounce hit
const DMG_TELEGRAPH := 0.28          # damage-triggered break: brief crack/flash lead before it goes
const SHARD_TEX := ""                # (code shards; no asset needed)

# --- geometry / config (from JSON; all data, no Tuning) ---
var w: float = 300.0
var h: float = 140.0
var tier: String = "trampoline"
var break_on: String = "timed"       # "timed" | "smash" | "hit"
var break_time: float = -1.0         # seconds after combat start (>=0 arms the timed cascade)
var telegraph_s: float = 1.0         # timed telegraph lead (cracks/shudder before break)
var hp: int = 0                      # damage hits to break (0 = not damage-breakable)
var group: String = "destructible"   # count-remaining group (Trials DESTROY_ALL)
var mode: String = ""                # "erode" marker (informational; the collapsing-arena pattern)
var on_break: Dictionary = {}        # optional composed effect (spawn_debris / open_void) — reserved

# --- palette (self-render; matches the tier-readability + industrial-steel look) ---
const TIER_PRIMARY := {
	"marshmallow": Color("#FFF6EC"), "bubblegum": Color("#FF4FA3"),
	"trampoline": Color("#2F6BD8"), "spring": Color("#FF6A2A"), "bumper": Color("#98A1AF"),
}
const STEEL := Color(0.20, 0.22, 0.27)
const STEEL_HI := Color(0.36, 0.39, 0.46)
const STEEL_LO := Color(0.11, 0.12, 0.16)
const HAZARD := Color(0.90, 0.20, 0.16)

enum { INTACT, TELEGRAPH, BROKEN }
var _state: int = INTACT
var _armed: bool = false             # timed clock runs only after combat_started
var _clock: float = 0.0              # seconds since combat start
var _tele_t: float = 0.0
var _tele_dur: float = 1.0
var _hp_left: int = 0
var _hit_cd: float = 0.0
var _shape: CollisionShape2D
var _det_area: Area2D                # smash/hit detection (only if damage-breakable)
var _rng := RandomNumberGenerator.new()
var _crack_seed: int = 0

func setup_from_json(o: Dictionary) -> void:
	w = float(o.get("w", 300.0))
	h = float(o.get("h", 140.0))
	tier = str(o.get("tier", "trampoline"))
	break_on = str(o.get("break_on", "timed"))
	break_time = float(o.get("break_time", -1.0))
	telegraph_s = maxf(0.05, float(o.get("telegraph_s", 1.0)))
	hp = int(o.get("hp", 0))
	group = str(o.get("group", "destructible"))
	mode = str(o.get("mode", ""))
	if o.has("on_break") and typeof(o["on_break"]) == TYPE_DICTIONARY:
		on_break = o["on_break"]
	# sensible defaults for the damage modes when hp is unspecified
	if hp <= 0:
		if break_on == "smash":
			hp = 1        # one super-strength impact breaks it (§2.5)
		elif break_on == "hit":
			hp = 3        # a few bounces break it
	# position is the RECT CENTER (matches LevelLoader._build_platform); x/y in JSON are top-left
	position = Vector2(float(o.get("x", 0.0)) + w * 0.5, float(o.get("y", 0.0)) + h * 0.5)

func _ready() -> void:
	_crack_seed = hash(position)
	_hp_left = hp
	collision_layer = LAYER_SURFACES
	collision_mask = 0
	# bounce contract — identical to LevelLoader._build_platform: bumper meta OR a tier launch height.
	if tier == "bumper":
		set_meta("bumper", true)
	else:
		set_meta("bounce_tier_height", Tuning.bounce_height_for(StringName(tier)))
	set_meta("destructible", true)
	add_to_group(group)
	add_to_group("destructible")
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	_shape.shape = rect
	add_child(_shape)
	z_index = 5   # over the void render, under HUD / players

	# damage detection area (only when damage-breakable) — senses player bodies overlapping the block.
	if break_on == "smash" or break_on == "hit" or hp > 0:
		_det_area = Area2D.new()
		_det_area.collision_layer = 0
		_det_area.collision_mask = LAYER_PLAYERS
		_det_area.monitoring = true
		var dcs := CollisionShape2D.new()
		var drect := RectangleShape2D.new()
		drect.size = Vector2(w + 12.0, h + 12.0)
		dcs.shape = drect
		_det_area.add_child(dcs)
		add_child(_det_area)

	# timed cascade arms on the starting gun (so the countdown/intro never erodes the box early).
	if break_time >= 0.0:
		if not EventBus.combat_started.is_connected(_on_combat_started):
			EventBus.combat_started.connect(_on_combat_started)

func _on_combat_started() -> void:
	_armed = true
	_clock = 0.0

func _physics_process(delta: float) -> void:
	_hit_cd = maxf(0.0, _hit_cd - delta)
	if _state == BROKEN:
		return
	# --- timed cascade clock (the collapsing-arena erosion driver) ---
	if _armed and break_time >= 0.0 and _state == INTACT:
		_clock += delta
		if _clock >= break_time - telegraph_s:
			_enter_telegraph(telegraph_s)
	# --- damage triggers (smash / hit) ---
	if _det_area != null and _state == INTACT and _hit_cd <= 0.0:
		_check_damage_contacts()
	# --- telegraph -> break ---
	if _state == TELEGRAPH:
		_tele_t += delta
		queue_redraw()   # animate cracks / shudder / flash
		if _tele_t >= _tele_dur:
			_break()

func _check_damage_contacts() -> void:
	for body in _det_area.get_overlapping_bodies():
		if not is_instance_valid(body) or not (body is Player):
			continue
		if body.has_method("is_dead") and body.is_dead():
			continue
		var spd: float = 0.0
		if "velocity" in body:
			spd = (body.velocity as Vector2).length()
		var qualifies := false
		if break_on == "smash":
			# a super-strength impact: a fired super OR a genuine high-speed launch (anti-graze gate).
			var supering: bool = body.has_method("is_super_active") and body.is_super_active()
			qualifies = supering or spd >= Tuning.smash_impact_min
		else:   # "hit": any real bounce contact
			qualifies = spd >= HIT_SPEED_GATE
		if qualifies:
			_hit_cd = 0.3   # one hit per pass (mirrors Player._smash_cd cadence)
			_hp_left -= 1
			if _hp_left <= 0:
				_enter_telegraph(DMG_TELEGRAPH)
			else:
				_tele_t = 0.0   # a non-fatal hit flashes a crack pulse via _draw
				queue_redraw()
			return

func _enter_telegraph(dur: float) -> void:
	if _state != INTACT:
		return
	_state = TELEGRAPH
	_tele_t = 0.0
	_tele_dur = maxf(0.05, dur)
	queue_redraw()

func _break() -> void:
	if _state == BROKEN:
		return
	_state = BROKEN
	remove_from_group(group)
	remove_from_group("destructible")
	if _det_area != null:
		_det_area.monitoring = false
	if _shape != null:
		_shape.set_deferred("disabled", true)   # footing lost THIS frame — resting players fall
	_spawn_shards()
	visible = false
	queue_free()

## Code-drawn debris burst (no asset): a one-shot spray of block-colored shards, parented to the
## arena so it outlives the freed block. Pure VFX — no collider, never lethal (the void kills).
func _spawn_shards() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 1.0
	p.amount = 20
	p.lifetime = 0.7
	p.position = global_position
	p.direction = Vector2.DOWN
	p.spread = 180.0
	p.gravity = Vector2(0, 1400)
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 460.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(w * 0.5, h * 0.5)
	var grad := Gradient.new()
	grad.set_color(0, STEEL_HI)
	grad.set_color(1, Color(STEEL_LO.r, STEEL_LO.g, STEEL_LO.b, 0.0))
	p.color_ramp = grad
	p.z_index = 6
	parent.add_child(p)
	parent.get_tree().create_timer(1.2).timeout.connect(p.queue_free)

# ------------------------------------------------------------------ telegraphy (INV-12: display only)
func _draw() -> void:
	var hw := w * 0.5
	var hh := h * 0.5
	# shudder: jitter the DRAWN art only (collider untouched) — grows with telegraph progress.
	var off := Vector2.ZERO
	var flash := 0.0
	if _state == TELEGRAPH:
		var p: float = clampf(_tele_t / _tele_dur, 0.0, 1.0)
		_rng.seed = _crack_seed + int(_tele_t * 120.0)
		off = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * (2.0 + 5.0 * p)
		flash = 0.18 + 0.30 * absf(sin(_tele_t * 34.0)) * p

	var top := Vector2(-hw, -hh) + off
	# 1) drop shadow (subtle, under the block)
	draw_rect(Rect2(top + Vector2(0, 10), Vector2(w, h)), Color(0.04, 0.06, 0.10, 0.30))
	# 2) steel body (bevelled: light top, dark bottom via two rects)
	draw_rect(Rect2(top, Vector2(w, h)), STEEL)
	draw_rect(Rect2(top + Vector2(0, h * 0.62), Vector2(w, h * 0.38)), STEEL_LO)
	# 3) rivets in the corners (industrial read)
	for cx in [-hw + 16.0, hw - 16.0]:
		for cy in [-hh + 16.0, hh - 16.0]:
			draw_circle(Vector2(cx, cy) + off, 5.0, STEEL_HI)
	# 4) tier-colored bounce MAT strip along the TOP (the surface line players bounce on)
	var mat_col: Color = TIER_PRIMARY.get(tier, TIER_PRIMARY["trampoline"])
	draw_rect(Rect2(top, Vector2(w, 16.0)), mat_col)
	draw_rect(Rect2(top, Vector2(w, 4.0)), mat_col.lightened(0.35))
	# 5) rim highlight
	draw_rect(Rect2(top, Vector2(w, h)), STEEL_HI, false, 2.0)
	# 6) telegraph: growing cracks + hazard flash overlay (fairness — you SEE it going)
	if _state == TELEGRAPH:
		_draw_cracks(off)
		draw_rect(Rect2(top, Vector2(w, h)), Color(HAZARD.r, HAZARD.g, HAZARD.b, flash))
	elif _tele_t > 0.0 and _hp_left < hp and hp > 0:
		# damaged-but-alive: static cracks proportional to hp lost (progressive break telegraph)
		_draw_cracks(off)

## Jagged crack lines fanning from the block center; count/opacity scale with telegraph progress
## (or with hp lost for the damage modes). Deterministic per block (stable seed) so cracks don't jump.
func _draw_cracks(off: Vector2) -> void:
	var prog: float
	if _state == TELEGRAPH:
		prog = clampf(_tele_t / _tele_dur, 0.0, 1.0)
	else:
		prog = 1.0 - float(_hp_left) / float(maxi(1, hp))
	var n := 2 + int(prog * 5.0)
	_rng.seed = _crack_seed
	var col := Color(0.02, 0.02, 0.03, 0.35 + 0.55 * prog)
	for i in range(n):
		var a := _rng.randf_range(0.0, TAU)
		var reach: float = minf(w, h) * (0.28 + 0.30 * prog)
		var start := Vector2(cos(a), sin(a)) * _rng.randf_range(4.0, 12.0) + off
		var mid := start + Vector2(cos(a), sin(a)) * reach * 0.6 + Vector2(_rng.randf_range(-14, 14), _rng.randf_range(-14, 14))
		var end := start + Vector2(cos(a), sin(a)) * reach
		draw_polyline(PackedVector2Array([start, mid, end]), col, 2.5)
