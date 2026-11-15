extends Control
## ShelfRail — one horizontally-scrolling card shelf (frontend_ui_audit_2026-07-10 §3.1/§3.2).
## Anatomy: shelf label (top-left) + "i / n" position readout (top-right) + a clipping band holding
## an HBox rail the code translates on X + edge chevrons that appear only when cards exist off that
## edge. The clip band means cards can NEVER occlude the header/footer — occlusion is structural,
## not a discipline problem. The screen (ArenaSelect today, SPORTS court select later) owns the
## cards/data; this component owns only the scroll motion + edge affordances (§3.8: data-in, one
## reusable shelf class).

signal wheel_moved(dir: int)   # mouse wheel over the shelf background (screen moves focus)

const RAIL_INSET := 96.0       # left inset, aligns with the HintStrip (§3.1)
const SCREEN_W := 1920.0       # design-res width (shell renders at design res, canvas_items stretch)
const SCROLL_TIME := 0.26      # §3.6 scroll-to-focused: QUINT/OUT glide, retargetable

@onready var _label: Label = $ShelfLabel
@onready var _counter: Label = $Counter
@onready var _rail: HBoxContainer = $Clip/Rail
@onready var _chev_l: Control = $ChevL
@onready var _chev_r: Control = $ChevR

var _scroll_tween: Tween
var _nudge_tween: Tween
var _rail_rest_x := RAIL_INSET   # rail X the scroll tween is heading to (rest between nudges)
var _placed := false             # WK-60b: has scroll_to placed the rail once yet

func _ready() -> void:
	_idle_bob(_chev_l)
	_idle_bob(_chev_r)
	_update_chevrons.call_deferred()

# ------------------------------------------------------------------ content API (screen-driven)
func set_label(text: String) -> void:
	_label.text = text

func set_separation(px: int) -> void:
	_rail.add_theme_constant_override("separation", px)

func add_card(card: Control) -> void:
	_rail.add_child(card)

func set_counter(index: int, total: int) -> void:
	_counter.text = "%d / %d" % [index + 1, total]

## Focused-shelf emphasis (§3.6): the unfocused shelf dims to 82% so one shelf owns the eye.
func set_shelf_focused(on: bool) -> void:
	var t := create_tween()
	t.tween_property(self, "modulate", Color(1, 1, 1, 1.0 if on else 0.82), 0.15)

# ------------------------------------------------------------------ scroll-to-focused (§3.6)
## Tween the rail so `card`'s center lands at screen center, clamped so the rail never shows dead
## space past its ends. Rapid focus moves retarget the same motion (kill + retween).
func scroll_to(card: Control, instant := false) -> void:
	if card == null or card.get_parent() != _rail:
		return
	var rail_w: float = _rail.get_combined_minimum_size().x
	var target: float = SCREEN_W * 0.5 - (card.position.x + card.custom_minimum_size.x * 0.5)
	var min_x: float = minf(RAIL_INSET, SCREEN_W - RAIL_INSET - rail_w)
	target = clampf(target, min_x, RAIL_INSET)
	# WK-60b: a rail shorter than the band (DROPSHOT's 3 courts) sits centred under the preview, not hard-left
	if rail_w < SCREEN_W - 2.0 * RAIL_INSET:
		target = (SCREEN_W - rail_w) * 0.5
	_rail_rest_x = target
	if _scroll_tween != null and _scroll_tween.is_valid():
		_scroll_tween.kill()
	# WK-60b: the first placement snaps (no whole-rail slide on screen entry / focus restore)
	if not _placed:
		instant = true
		_placed = true
	if instant:
		_rail.position.x = target
	else:
		_scroll_tween = create_tween()
		_scroll_tween.tween_property(_rail, "position:x", target, SCROLL_TIME) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_update_chevrons()

## End-of-shelf feedback (§3.5): a 6px rail nudge (the screen plays the low tick).
func edge_nudge(dir: int) -> void:
	if _nudge_tween != null and _nudge_tween.is_valid():
		_nudge_tween.kill()
	_nudge_tween = create_tween()
	_nudge_tween.tween_property(_rail, "position:x", _rail_rest_x - 6.0 * float(dir), 0.05) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_nudge_tween.tween_property(_rail, "position:x", _rail_rest_x, 0.10) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ------------------------------------------------------------------ edge chevrons (§3.2)
## Visible only when more cards exist off that edge (judged at the scroll target, not mid-tween).
func _update_chevrons() -> void:
	var rail_w: float = _rail.get_combined_minimum_size().x
	_chev_l.visible = _rail_rest_x < RAIL_INSET - 1.0
	_chev_r.visible = _rail_rest_x + rail_w > SCREEN_W - RAIL_INSET + 1.0

func _idle_bob(c: Control) -> void:
	var rest := c.position.y
	var t := c.create_tween().set_loops()
	t.tween_property(c, "position:y", rest - 4.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(c, "position:y", rest + 4.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ------------------------------------------------------------------ mouse wheel (§3.5)
func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		var btn := (e as InputEventMouseButton).button_index
		if btn == MOUSE_BUTTON_WHEEL_DOWN:
			wheel_moved.emit(1)
			accept_event()
		elif btn == MOUSE_BUTTON_WHEEL_UP:
			wheel_moved.emit(-1)
			accept_event()
