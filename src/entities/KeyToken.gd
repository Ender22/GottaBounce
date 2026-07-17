class_name KeyToken
extends Area2D
## TRIALS key token (owner 2026-07-16: "hard-to-reach keys then hard-to-reach doors"). A Pickup-latch
## clone in its own group ("trials_key" — NEVER "trials_pickup", so COLLECT_ALL courses that also use
## keys stay independent). A KeyDoor with the same `door` id opens when every matching key is collected.
## Never blocks the player; reads no Tuning constant.
##
## {"type":"key","x","y","r":<radius>,"door":"<door id>"} — x,y = CENTER; door defaults "" (matches
## the default-door KeyDoor).
##
## ART-DEBT: body reuses the collect-token sprite tinted key-gold (halo/flash stay code VFX). A proper
## key sprite is logged for the next art pass (assets/objects/key.png will be picked up automatically).

const MASK_PLAYERS := 1 << 0
const TOKEN_TEX: Texture2D = preload("res://assets/objects/token.png")
const KEY_TEX_PATH := "res://assets/objects/key.png"   # preferred when it exists (future art pass)
const TOKEN_TEX_W := 615.0
const TOKEN_TEX_H := 596.0
const TOKEN_COIN_DIAM := 555.0
const TOKEN_COIN_CX := 307.0
const TOKEN_COIN_CY := 290.5
const KEY_TINT := Color(1.0, 0.78, 0.35)   # warm key-gold over the coin body

var r: float = 46.0
var door_id: String = ""
var collected: bool = false
var _tex: Texture2D = TOKEN_TEX
var _is_key_art := false   # true when the bespoke key sprite exists (2026-07-17 art pass) —
                           # drawn centred by its own aspect; the tinted-coin fallback keeps the
                           # old coin-geometry pinning + code keyhole emblem
var _t: float = 0.0
var _flash: float = 0.0

func setup_from_json(o: Dictionary) -> void:
	r = float(o.get("r", 46.0))
	door_id = str(o.get("door", ""))
	position = Vector2(float(o.get("x", 0.0)), float(o.get("y", 0.0)))

func _ready() -> void:
	add_to_group("trials_key")
	collision_layer = 0
	collision_mask = MASK_PLAYERS
	monitoring = true
	if ResourceLoader.exists(KEY_TEX_PATH):
		_tex = load(KEY_TEX_PATH)
		_is_key_art = true
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = r
	cs.shape = c
	add_child(cs)
	z_index = 44

## Latch by OVERLAP POLL, only while the match is in COMBAT — never via body_entered (the GoalGate
## stale-position lesson, DECISIONS 2026-07-10: during the stage-load->respawn window the previous
## course's finisher positions can overlap THIS course's fresh key and falsely collect it; observed
## live on n2_master_vault). Current-position check guards the one-step-stale overlap list too.
func _poll_collect() -> void:
	if collected:
		return
	var runner := get_tree().current_scene
	if runner == null or str(runner.get("state")) != "COMBAT":
		return
	for body in get_overlapping_bodies():
		if body is Player and not body.is_dead() \
				and body.global_position.distance_to(global_position) <= r + 46.0:
			collected = true
			_flash = 1.0
			AudioManager.play_sfx("ui_click", {"pitch": 1.6, "volume_db": -4.0})
			return

func _physics_process(delta: float) -> void:
	_t += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 2.0)
	_poll_collect()
	queue_redraw()

func _draw() -> void:
	if collected:
		if _flash > 0.0:
			draw_circle(Vector2.ZERO, r * (1.0 + 0.8 * (1.0 - _flash)), Color(1.0, 0.85, 0.3, 0.35 * _flash))
		return
	var bob := 6.0 * sin(_t * 3.0)
	var c := Vector2(0.0, bob)
	var pulse := 1.0 + 0.06 * sin(_t * 5.0)
	draw_circle(c, (r + 10.0) * pulse, Color(1.0, 0.8, 0.3, 0.16))   # halo (code VFX)
	if _is_key_art:
		# bespoke gold key sprite: width spans ~2.6r, height by its own aspect, no tint needed
		var w := r * 2.6
		var h := w * (float(_tex.get_height()) / maxf(1.0, float(_tex.get_width())))
		draw_texture_rect(_tex, Rect2(c - Vector2(w * 0.5, h * 0.5), Vector2(w, h)), false)
		return
	var scale_u := (2.0 * r) / TOKEN_COIN_DIAM
	var tl := c - Vector2(TOKEN_COIN_CX * scale_u, TOKEN_COIN_CY * scale_u)
	draw_texture_rect(_tex, Rect2(tl, Vector2(TOKEN_TEX_W * scale_u, TOKEN_TEX_H * scale_u)), false, KEY_TINT)
	# keyhole emblem so a KEY reads differently from a collect-token at course zoom (telegraph, code OK)
	var dark := Color(0.20, 0.12, 0.08, 0.9)
	draw_circle(c + Vector2(0, -r * 0.12), r * 0.22, dark)
	draw_rect(Rect2(c + Vector2(-r * 0.09, -r * 0.05), Vector2(r * 0.18, r * 0.45)), dark)
