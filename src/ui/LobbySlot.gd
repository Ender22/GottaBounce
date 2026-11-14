class_name LobbySlot
extends Control
## One Herd Lobby player panel (audit §E.9 panel internals, §E.10 motion). A pure VIEW: HerdLobby owns
## the slot state machine (EMPTY / PICKING / READY) and calls these setters; nothing here reads input or
## takes focus (every control is focus NONE / mouse IGNORE — E.12).

const CHOCO := Color(0.231373, 0.141176, 0.105882)
const CREAM := Color(1.0, 0.968627, 0.921569)
const GOLD := Color("#ffd23f")

@onready var _plate: Panel = $Plate
@onready var _header: Control = $Header
@onready var _badge: Panel = $Header/PBadge
@onready var _plabel: Label = $Header/PBadge/PLabel
@onready var _dev_name: Label = $Header/DeviceName
@onready var _dev_icon: Control = $Header/DeviceIcon
@onready var _well: Control = $BustWell
@onready var _disc: Panel = $BustWell/Disc
@onready var _sil: TextureRect = $BustWell/Silhouette
@onready var _bust: TextureRect = $BustWell/Bust
@onready var _chev_l: Control = $BustWell/ChevL
@onready var _chev_r: Control = $BustWell/ChevR
@onready var _taken: Label = $BustWell/TakenChip
@onready var _banner: Panel = $NameBanner
@onready var _name: Label = $NameBanner/Name
@onready var _blurb: Label = $Blurb
@onready var _flair_row: Panel = $FlairRow
@onready var _flair_val: Label = $FlairRow/FlairValue
@onready var _fchev_l: Control = $FlairRow/FChevL
@onready var _fchev_r: Control = $FlairRow/FChevR
@onready var _status: HBoxContainer = $Status
@onready var _status_glyph: Control = $Status/StatusGlyph
@onready var _status_text: Label = $Status/StatusText
@onready var _stamp: Label = $Stamp
@onready var _join: Control = $JoinPrompt
@onready var _join_box: Control = $JoinPrompt/JoinBox
@onready var _kb_hint: Control = $JoinPrompt/KbHint

var slot_index := 0
var _color := Color("#ff5fa8")
var _joined := false
var _ready_on := false
var _bust_rest := Vector2.ZERO
var _breathe: Tween
var _idle: Tween
var _swap: Tween
var _device_key := ""

func _ready() -> void:
	_bust_rest = _bust.position
	for c in [_chev_l, _chev_r, _fchev_l, _fchev_r]:
		(c as Control).set_meta("rest_x", (c as Control).position.x)

## Identity: which P-number this panel is (slot 0 = P1). Called once by the lobby.
func setup_slot(idx: int, silhouette: Texture2D) -> void:
	slot_index = idx
	_plabel.text = "P%d" % (idx + 1)
	_sil.texture = silhouette

# ------------------------------------------------------------------ states

## EMPTY: dim plate, idle-sprite silhouette, breathing "PRESS (A) TO JOIN" (+ ENTER keycap hint if the
## keyboard is still free). `animate` = the leave motion (bust falls out, plate dims).
func show_empty(kb_free: bool, animate: bool) -> void:
	_joined = false
	_ready_on = false
	_device_key = ""
	_kill(_idle)
	_kb_hint.visible = kb_free
	_set_plate(CHOCO, 5, 0.0, 0.55)
	_set_badge(CREAM, CHOCO)
	if animate:
		var t := _bust.create_tween()
		t.set_parallel(true)
		t.tween_property(_bust, "position:y", _bust_rest.y + 260.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(_bust, "modulate:a", 0.0, 0.20)
		t.chain().tween_callback(_apply_empty_visibility)
	else:
		_apply_empty_visibility()

func _apply_empty_visibility() -> void:
	if _joined:
		return
	_bust.visible = false
	_bust.position = _bust_rest
	_bust.modulate.a = 1.0
	_sil.visible = true
	_disc.visible = false
	for n in [_chev_l, _chev_r, _taken, _banner, _blurb, _flair_row, _status, _stamp, _dev_name, _dev_icon]:
		(n as Control).visible = false
	_header.modulate.a = 0.7
	_join.visible = true
	_start_breathe()

## EMPTY -> PICKING: the join motion (panel 0.90 -> 1.06 -> 1.00, bust drops in, badge pops).
func show_join(device_key: String, hero: Dictionary, tex: Texture2D) -> void:
	_joined = true
	_ready_on = false
	set_device(device_key)
	_kill(_breathe)
	_join.visible = false
	_sil.visible = false
	_header.modulate.a = 1.0
	for n in [_bust, _disc, _chev_l, _chev_r, _banner, _blurb, _flair_row, _status, _dev_name, _dev_icon]:
		(n as Control).visible = true
	_stamp.visible = false
	_taken.visible = false
	_apply_hero(hero, tex)
	_set_status_picking()
	pivot_offset = size * 0.5
	scale = Vector2(0.90, 0.90)
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.06, 1.06), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_bust.position = _bust_rest + Vector2(0, -80)
	_bust.modulate.a = 0.0
	var tb := _bust.create_tween()
	tb.set_parallel(true)
	tb.tween_property(_bust, "position", _bust_rest, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tb.tween_property(_bust, "modulate:a", 1.0, 0.12)
	tb.chain().tween_callback(_start_idle)
	_badge.scale = Vector2(1.4, 1.4)
	var tp := _badge.create_tween()
	tp.tween_property(_badge, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Device header: icon + a short name ("KEYBOARD" / "PAD 2"), and the device-correct status glyph.
func set_device(device_key: String) -> void:
	_device_key = device_key
	var is_kb: bool = device_key == "kb"
	(_dev_icon as Object).call("setup", "kb" if is_kb else "pad")
	if is_kb:
		_dev_name.text = "KEYBOARD"
	else:
		_dev_name.text = "PAD %d" % (int(device_key.substr(4)) + 1) if device_key.begins_with("pad:") else ""

## Cycle the goat (E.10): whip the old bust out toward `dir`'s far side, bounce the new one in; the
## pressed chevron nudges; plate border + disc + banner recolour.
func show_goat(hero: Dictionary, tex: Texture2D, dir: int) -> void:
	if dir != 0:
		((_chev_r if dir > 0 else _chev_l) as Object).call("nudge")
	_kill(_idle)
	_kill(_swap)
	var off: float = -90.0 * float(dir if dir != 0 else 1)
	_swap = _bust.create_tween()
	_swap.set_parallel(true)
	_swap.tween_property(_bust, "position:x", _bust_rest.x + off, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_swap.tween_property(_bust, "rotation", deg_to_rad(-12.0 * float(dir if dir != 0 else 1)), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_swap.tween_property(_bust, "modulate:a", 0.0, 0.10)
	_swap.chain().tween_callback(func() -> void:
		_apply_hero(hero, tex)
		_bust.position = _bust_rest - Vector2(off, 0)
		_bust.rotation = 0.0
		_bust.scale = Vector2(0.7, 0.7)
		var ip := _bust.create_tween()
		_swap = ip   # a rapid next cycle kills the bounce-in too (no two tweens fighting over position)
		ip.set_parallel(true)
		ip.tween_property(_bust, "position", _bust_rest, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ip.tween_property(_bust, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ip.tween_property(_bust, "modulate:a", 1.0, 0.12)
		ip.chain().tween_callback(_start_idle))

func _apply_hero(hero: Dictionary, tex: Texture2D) -> void:
	_color = hero.get("color", _color)
	_bust.texture = tex
	_name.text = str(hero.get("name", ""))
	_blurb.text = str(hero.get("blurb", ""))
	_set_banner(_color)
	var ds := StyleBoxFlat.new()
	ds.bg_color = Color(_color.r, _color.g, _color.b, 0.28)
	ds.set_corner_radius_all(120)
	_disc.add_theme_stylebox_override("panel", ds)
	_set_badge(_color, Color.WHITE)
	if _ready_on:
		_set_plate(_color, 6, 24.0, 0.96)
	else:
		_set_plate(_color, 6, 0.0, 0.92)

## Which row the panel's stick drives: 0 = GOAT (chevrons bright), 1 = FLAIR (gold ring on the row).
func set_row(row: int) -> void:
	var on_flair: bool = row == 1
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.30) if on_flair else Color(CHOCO.r, CHOCO.g, CHOCO.b, 0.08)
	rs.border_color = GOLD if on_flair else Color(CHOCO.r, CHOCO.g, CHOCO.b, 0.0)
	rs.set_border_width_all(4)
	rs.set_corner_radius_all(12)
	_flair_row.add_theme_stylebox_override("panel", rs)
	_chev_l.modulate.a = 0.35 if on_flair else 1.0
	_chev_r.modulate.a = 0.35 if on_flair else 1.0
	_fchev_l.visible = on_flair
	_fchev_r.visible = on_flair

func set_flair(text: String, locked: bool) -> void:
	_flair_val.text = text
	_flair_val.add_theme_color_override("font_color", Color(CHOCO.r, CHOCO.g, CHOCO.b, 0.45 if locked else 1.0))
	# long item names shrink to fit the row (never spill / overlap the chevrons)
	var f: Font = _flair_val.get_theme_font("font")
	var avail: float = _flair_val.size.x - 4.0
	var fs := 26
	if f != null and avail > 10.0:
		while fs > 20 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x > avail:
			fs -= 1
	_flair_val.add_theme_font_size_override("font_size", fs)

func flair_nudge(dir: int) -> void:
	((_fchev_r if dir > 0 else _fchev_l) as Object).call("nudge")
	MenuFX.value_pop(_flair_val, 1.12)

## "TAKEN BY P2" chip over the bust when another human has LOCKED the goat this panel is showing.
func set_taken_by(label: int) -> void:
	_taken.visible = label > 0
	if label > 0:
		_taken.text = "TAKEN BY P%d" % label
	_bust.modulate = Color(1, 1, 1, 0.55) if label > 0 else Color.WHITE

## PICKING <-> READY (E.10 lock / un-ready motion).
func set_ready(on: bool, animate: bool) -> void:
	if on == _ready_on and animate:
		return
	_ready_on = on
	if on:
		_set_plate(_color, 6, 24.0, 0.96)
		_set_status_ready()
		_stamp.visible = true
		if animate:
			_kill(_idle)
			var hop := _bust.create_tween()
			hop.tween_property(_bust, "position:y", _bust_rest.y - 50.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			hop.tween_property(_bust, "position:y", _bust_rest.y, 0.28).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			hop.tween_callback(_start_idle)
			_stamp.modulate.a = 1.0
			_stamp.scale = Vector2(2.0, 2.0)
			_stamp.rotation = deg_to_rad(-14.0)
			var ts := _stamp.create_tween()
			ts.set_parallel(true)
			ts.tween_property(_stamp, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			ts.tween_property(_stamp, "rotation", deg_to_rad(-6.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			_stamp.scale = Vector2.ONE
			_stamp.rotation = deg_to_rad(-6.0)
			_stamp.modulate.a = 1.0
	else:
		_set_plate(_color, 6, 0.0, 0.92)
		_set_status_picking()
		if animate and _stamp.visible:
			var tu := _stamp.create_tween()
			tu.set_parallel(true)
			tu.tween_property(_stamp, "scale", Vector2(0.8, 0.8), 0.12)
			tu.tween_property(_stamp, "modulate:a", 0.0, 0.12)
			tu.chain().tween_callback(func() -> void:
				if not _ready_on:
					_stamp.visible = false)
		else:
			_stamp.visible = false

## Deny (E.10): reject shake on the whole panel.
func deny() -> void:
	MenuFX.reject_shake(self)

func is_joined() -> bool:
	return _joined

# ------------------------------------------------------------------ internals
func _set_status_picking() -> void:
	(_status_glyph as Object).call("setup", "key:ENTER" if _device_key == "kb" else "A")
	_status_text.text = "LOCK IN"

func _set_status_ready() -> void:
	(_status_glyph as Object).call("setup", "key:ESC" if _device_key == "kb" else "B")
	_status_text.text = "CHANGE"

func _set_plate(border: Color, bw: int, glow: float, alpha: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(CREAM.r, CREAM.g, CREAM.b, alpha)
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(22)
	if glow > 0.0:
		sb.shadow_color = Color(border.r, border.g, border.b, 0.5)
		sb.shadow_size = int(glow)
	else:
		sb.shadow_color = Color(0.12, 0.07, 0.05, 0.35)
		sb.shadow_size = 8
		sb.shadow_offset = Vector2(0, 6)
	_plate.add_theme_stylebox_override("panel", sb)

func _set_badge(bg: Color, fg: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = CHOCO
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(14)
	_badge.add_theme_stylebox_override("panel", sb)
	_plabel.add_theme_color_override("font_color", fg)
	_plabel.add_theme_constant_override("outline_size", 8 if fg == Color.WHITE else 0)

func _set_banner(c: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.border_color = CHOCO
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(16)
	_banner.add_theme_stylebox_override("panel", sb)

func _start_breathe() -> void:
	_kill(_breathe)
	_join_box.pivot_offset = _join_box.size * 0.5
	_breathe = _join_box.create_tween().set_loops()
	_breathe.tween_property(_join_box, "scale", Vector2(1.05, 1.05), 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breathe.tween_property(_join_box, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _start_idle() -> void:
	_kill(_idle)
	if not _joined:
		return
	_bust.pivot_offset = Vector2(_bust.size.x * 0.5, _bust.size.y * 0.85)
	_idle = _bust.create_tween().set_loops()
	_idle.tween_property(_bust, "scale", Vector2(0.97, 1.04), 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle.tween_property(_bust, "scale", Vector2(1.04, 0.97), 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _kill(t: Tween) -> void:
	if t != null and t.is_valid():
		t.kill()
