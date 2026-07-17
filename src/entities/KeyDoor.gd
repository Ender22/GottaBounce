class_name KeyDoor
extends StaticBody2D
## TRIALS key door (owner 2026-07-16). A SOLID bumper-tier barrier that OPENS (collider off, tiles pop
## away) once every KeyToken with the same `door` id is collected. Never lethal — it just blocks the
## route (bumper meta, so flying into it is an honest ricochet through the existing BounceResolver
## path). Reads no Tuning constant; the void/fall stays the only killer (hazard doctrine §2.0 fence).
##
## {"type":"key_door","x","y","w","h","door":"<id>"} — x,y = TOP-LEFT (platform convention); door
## defaults "" (pairs with default-id keys).
##
## ART-DEBT: body = tiled crate sprite tinted steel-blue + a code lock emblem (telegraph). A proper
## door sprite is a next-art-pass item.

const LAYER_SURFACES := 1 << 2
const CRATE_TEX: Texture2D = preload("res://assets/objects/crate.png")
const STEEL_TINT := Color(0.62, 0.70, 0.88)
const GOLD := Color(1.0, 0.82, 0.25, 0.95)

var w: float = 120.0
var h: float = 400.0
var door_id: String = ""
var open: bool = false
var _t: float = 0.0
var _cs: CollisionShape2D
var _open_anim: float = 0.0   # 1 -> 0 while the opening pop plays

func setup_from_json(o: Dictionary) -> void:
	w = float(o.get("w", 120.0))
	h = float(o.get("h", 400.0))
	door_id = str(o.get("door", ""))
	position = Vector2(float(o.get("x", 0.0)) + w * 0.5, float(o.get("y", 0.0)) + h * 0.5)

func _ready() -> void:
	add_to_group("key_door")
	collision_layer = LAYER_SURFACES
	collision_mask = 0
	set_meta("bumper", true)   # honest ricochet off a locked door (existing bumper path, no refund rules changed)
	_cs = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	_cs.shape = rect
	add_child(_cs)
	z_index = 20

func _keys_remaining() -> int:
	var n := 0
	for k in get_tree().get_nodes_in_group("trials_key"):
		if str(k.door_id) == door_id and not bool(k.collected):
			n += 1
	return n

func _physics_process(delta: float) -> void:
	_t += delta
	if open:
		if _open_anim > 0.0:
			_open_anim = maxf(0.0, _open_anim - delta * 2.5)
			queue_redraw()
		return
	if _keys_remaining() == 0 and _has_any_key():
		_open_door()
	queue_redraw()

## Guard the zero-key vacuous open: a door with NO matching keys authored stays locked forever
## (an authoring error should read as a locked door, not a free pass).
func _has_any_key() -> bool:
	for k in get_tree().get_nodes_in_group("trials_key"):
		if str(k.door_id) == door_id:
			return true
	return false

func _open_door() -> void:
	open = true
	_open_anim = 1.0
	_cs.set_deferred("disabled", true)
	AudioManager.play_sfx("super_fire", {"pitch": 1.5, "volume_db": -8.0})

func _draw() -> void:
	if open and _open_anim <= 0.0:
		return
	var alpha := _open_anim if open else 1.0
	var spread := (1.0 - alpha) * 60.0 if open else 0.0
	# tiled crate body (sprite body per the no-code-drawn rule; tint reads "locked steel")
	var tile := minf(w, 128.0)
	var cols := maxi(1, int(ceil(w / tile)))
	var rows := maxi(1, int(ceil(h / tile)))
	var tw := w / float(cols)
	var th := h / float(rows)
	var tint := Color(STEEL_TINT.r, STEEL_TINT.g, STEEL_TINT.b, alpha)
	for cy in range(rows):
		for cx in range(cols):
			var jitter := Vector2(0, 0)
			if open:
				jitter = Vector2(sin(float(cx * 7 + cy * 13)) * spread, -spread * (0.5 + 0.5 * float(cy) / float(rows)))
			draw_texture_rect(CRATE_TEX,
				Rect2(Vector2(-w * 0.5 + cx * tw, -h * 0.5 + cy * th) + jitter, Vector2(tw, th)), false, tint)
	if not open:
		# lock emblem telegraph (code OK): pulsing gold ring + keyhole at the door center
		var pulse := 1.0 + 0.08 * sin(_t * 4.0)
		var r := minf(w, h) * 0.32 * pulse
		draw_arc(Vector2.ZERO, r + 7.0, 0.0, TAU, 48, Color(0.12, 0.09, 0.07, 0.9), 16.0, true)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, GOLD, 9.0, true)
		var dark := Color(0.12, 0.09, 0.07, 0.95)
		draw_circle(Vector2(0, -r * 0.15), r * 0.28, dark)
		draw_rect(Rect2(Vector2(-r * 0.11, -r * 0.1), Vector2(r * 0.22, r * 0.55)), dark)
