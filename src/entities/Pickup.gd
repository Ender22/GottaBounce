class_name Pickup
extends Area2D
## TRIALS COLLECT_ALL token (docs/specs/v7_trials_challenge_types.md §1.3). A thin GoalGate-latch clone:
## a display-only Area2D that senses the player, latches `collected` on the FIRST overlap, and is read
## via the group "trials_pickup" (TrialsMode.is_stage_over clears the course when every member is
## collected). It never blocks the player and reads no Tuning constant. Drawn as a glossy floating token.
##
## {"type":"pickup","x","y","r":<radius>} — x,y = CENTER.

const MASK_PLAYERS := 1 << 0   # senses Player bodies (matches GoalGate)

# --- Glossy Toybox collect-token sprite (no-code-drawn-assets paydown; same pattern as the hazard/ball
# wirings). A glossy gold coin with an embossed star + glow. Image 615x596; the bright coin body spans
# ~555px (bright bbox 555x544, centred at image ~307,290.5). The token BODY (chocolate rim + gold body +
# inner ring + shine) is replaced by this sprite, coin-centre pinned to the pickup origin (+ the bob) and
# scaled so the coin DIAMETER == 2*r. The soft halo PULSE and the collect-flash stay as code VFX (juice). ---
const TOKEN_TEX: Texture2D = preload("res://assets/objects/token.png")
const TOKEN_TEX_W := 615.0
const TOKEN_TEX_H := 596.0
const TOKEN_COIN_DIAM := 555.0   # bright coin diameter in image px
const TOKEN_COIN_CX := 307.0     # bright coin centre x in image px
const TOKEN_COIN_CY := 290.5     # bright coin centre y in image px

var r: float = 46.0
var collected: bool = false
var _t: float = 0.0
var _flash: float = 0.0

func setup_from_json(o: Dictionary) -> void:
	r = float(o.get("r", 46.0))
	position = Vector2(float(o.get("x", 0.0)), float(o.get("y", 0.0)))

func _ready() -> void:
	add_to_group("trials_pickup")
	collision_layer = 0
	collision_mask = MASK_PLAYERS
	monitoring = true
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = r
	cs.shape = c
	add_child(cs)
	z_index = 44   # over platforms/void, under HUD
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if collected:
		return
	if body is Player:
		collected = true
		_flash = 1.0

func _physics_process(delta: float) -> void:
	_t += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 2.0)
	queue_redraw()

# ------------------------------------------------------------------ display (glossy token)
func _draw() -> void:
	if collected:
		# a fading collected pop (still drawn briefly so the grab reads), then nothing.
		if _flash > 0.0:
			draw_circle(Vector2.ZERO, r * (1.0 + 0.8 * (1.0 - _flash)), Color(1.0, 0.9, 0.4, 0.35 * _flash))
		return
	var bob := 6.0 * sin(_t * 3.0)
	var c := Vector2(0.0, bob)
	var pulse := 1.0 + 0.06 * sin(_t * 5.0)
	draw_circle(c, (r + 8.0) * pulse, Color(1.0, 0.9, 0.4, 0.14))   # soft halo (kept code VFX juice)
	# token BODY: the coin sprite, coin-centre pinned to c, scaled so the coin DIAMETER == 2*r.
	var scale_u := (2.0 * r) / TOKEN_COIN_DIAM
	var tl := c - Vector2(TOKEN_COIN_CX * scale_u, TOKEN_COIN_CY * scale_u)
	draw_texture_rect(TOKEN_TEX, Rect2(tl, Vector2(TOKEN_TEX_W * scale_u, TOKEN_TEX_H * scale_u)), false)
