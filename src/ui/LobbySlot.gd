class_name LobbySlot
extends Control
## One Herd Lobby player panel (audit §E.9 panel internals, §E.10 motion; lobby review WK-81 + WK-07 RULES
## flip). A pure VIEW: HerdLobby owns the slot state machine (EMPTY / PICKING / READY / RULES-open) and calls
## these setters; nothing here reads input or takes focus (every control is focus NONE / mouse IGNORE — E.12).
##
## Faces: FRONT = goat picker (bust, name, blurb, flair row, status). BACK = the owner's RULES card (WK-07,
## docs/audit/2026-11-14_lobby_review.md "RULES PANEL"): the panel flips over and the rules live on its back.

const CHOCO := Color(0.231373, 0.141176, 0.105882)
const CREAM := Color(1.0, 0.968627, 0.921569)
const GOLD := Color("#ffd23f")
const WELL := Color("#3b241b")          # WK-81 F4: EMPTY = dark slot well (Smash / MK8), not see-through glass

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
@onready var _taken: Label = $TakenChip
@onready var _banner: Panel = $NameBanner
@onready var _name: Label = $NameBanner/Name
@onready var _blurb: Label = $Blurb
@onready var _ribbon: Panel = $TeamRibbon
@onready var _ribbon_text: Label = $TeamRibbon/TeamText
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
@onready var _rules_face: Control = $RulesFace
@onready var _rules_icon: TextureRect = $RulesFace/ModeIcon
@onready var _rules_check: Control = $RulesFace/ReadyCheck
@onready var _rule_rows: Array = [$RulesFace/Row0, $RulesFace/Row1, $RulesFace/Row2, $RulesFace/Row3]
@onready var _rules_done_glyph: Control = $RulesFace/Footer/DoneGlyph
@onready var _rules_undo_glyph: Control = $RulesFace/Footer/UndoGlyph

var slot_index := 0
var _color := Color("#ff5fa8")
var _joined := false
var _ready_on := false
var _row := 0
var _on_back := false
var _bust_rest := Vector2.ZERO
var _join_rest_y := 0.0
var _rest_x := 0.0
var _lifted := false
var _kb_wanted := false
var _taken_text := ""                  # the chip's standing text ("TAKEN BY P2" / "RED IS FULL"); "" = hidden
var _sports := false                    # WK-27: SPORTS layout (team ribbon under the name, no FLAIR row)
var _team := -1                         # WK-27: team of the goat shown (-1 = none / not sports)
var _rules_focus := -1
var _breathe: Tween
var _idle: Tween
var _swap: Tween
var _flip_tw: Tween
var _lift_tw: Tween
var _chev_tw: Tween
var _stamp_tw: Tween                    # one stamp tween at a time: a fast un-ready -> re-ready can't fade the new stamp
var _flash_gen := 0
var _device_key := ""
var device_label := ""                  # eval-readable ("KEYBOARD" / "XBOX" / "PLAYSTATION" / "SWITCH" / "GAMEPAD")

func _ready() -> void:
	_bust_rest = _bust.position
	_blurb.set_meta("rest_top", _blurb.offset_top)
	_blurb.set_meta("rest_bottom", _blurb.offset_bottom)
	_join_rest_y = _join_box.position.y
	_rest_x = position.x
	for c in [_chev_l, _chev_r, _fchev_l, _fchev_r]:
		(c as Control).set_meta("rest_x", (c as Control).position.x)

## Identity: which P-number this panel is (slot 0 = P1). Called once by the lobby.
func setup_slot(idx: int, silhouette: Texture2D) -> void:
	slot_index = idx
	_plabel.text = "P%d" % (idx + 1)
	_sil.texture = silhouette
	_rest_x = position.x

## WK-27 (audit §E.6/§E.9 "SPORTS adds a team ribbon"): SPORTS panels show a RED/BLUE team ribbon under the
## goat's name, and drop the FLAIR row (flair is never worn in Sports — team-read is sacred, PartyMatch
## suppresses it), so the blurb slides down into the freed space. Called once by the lobby.
func set_sports_layout(on: bool) -> void:
	_sports = on
	_blurb.offset_top = (408.0 if on else float(_blurb.get_meta("rest_top", 354.0)))
	_blurb.offset_bottom = (474.0 if on else float(_blurb.get_meta("rest_bottom", 418.0)))
	_apply_mode_rows(_joined and not _on_back)

# ------------------------------------------------------------------ states

## EMPTY: dark slot well, faint cream silhouette, breathing "PRESS (A) TO JOIN". `animate` = the leave
## motion (bust falls out, plate darkens).
func show_empty(kb_free: bool, animate: bool) -> void:
	_joined = false
	_ready_on = false
	_device_key = ""
	device_label = ""
	_kill(_idle)
	if _on_back:
		_set_face(false)
	_kb_wanted = kb_free
	_apply_kb_hint()
	_set_empty_plate()
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
	for n in [_chev_l, _chev_r, _taken, _banner, _blurb, _flair_row, _ribbon, _status, _stamp, _dev_name, _dev_icon]:
		(n as Control).visible = false
	_header.modulate.a = 1.0
	_join.visible = true
	_start_breathe()

## EMPTY -> PICKING: the join motion (panel 0.90 -> 1.06 -> 1.00, bust drops in, badge pops).
func show_join(device_key: String, hero: Dictionary, tex: Texture2D) -> void:
	_joined = true
	_ready_on = false
	if _on_back:
		_set_face(false)
	set_device(device_key)
	_kill(_breathe)
	_join.visible = false
	_sil.visible = false
	_header.modulate.a = 1.0
	for n in [_bust, _disc, _chev_l, _chev_r, _banner, _blurb, _flair_row, _status, _dev_name, _dev_icon]:
		(n as Control).visible = true
	_team = -1   # the ribbon pops only on a team CHANGE while cycling, not on the join itself
	_apply_mode_rows(true)
	for c in [_chev_l, _chev_r]:
		(c as Control).modulate.a = 1.0
	_stamp.visible = false
	_taken.visible = false
	_taken_text = ""
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

## Device header (WK-81 F3): the device FAMILY, never Godot's device number ("P2 · PAD 1" made players ask
## "which one am I?"). Keyboard = KEYBOARD; pads map Input.get_joy_name() to XBOX / PLAYSTATION / SWITCH,
## else GAMEPAD. Identity comes from the join rumble + the "that's me" ping, not from a number.
func set_device(device_key: String) -> void:
	_device_key = device_key
	var is_kb: bool = device_key == "kb"
	(_dev_icon as Object).call("setup", "kb" if is_kb else "pad")
	device_label = "KEYBOARD" if is_kb else pad_family(InputRouter.pad_id(device_key))
	_dev_name.text = device_label

static func pad_family(id: int) -> String:
	var n: String = Input.get_joy_name(id).to_lower() if id >= 0 else ""
	if n.contains("xbox") or n.contains("xinput") or n.contains("x-box"):
		return "XBOX"
	if n.contains("playstation") or n.contains("dualshock") or n.contains("dualsense") or n.contains("ps4") \
			or n.contains("ps5") or n.contains("sony"):
		return "PLAYSTATION"
	if n.contains("switch") or n.contains("nintendo") or n.contains("joy-con") or n.contains("pro controller"):
		return "SWITCH"
	return "GAMEPAD"

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
	_set_joined_plate()
	_apply_team(int(hero.get("team", -1)), str(hero.get("team_name", "")), hero.get("team_color", Color.WHITE))

## WK-27 team ribbon: "RED TEAM" / "BLUE TEAM" on the team colour. Cycling across the RED/BLUE boundary pops
## it (1.25 -> 1.0, TRANS_BACK) so "you just switched sides" reads at a glance from the couch.
func _apply_team(team: int, team_name: String, team_color: Color) -> void:
	var changed: bool = team != _team and _team >= 0
	_team = team
	if team < 0:
		_ribbon.visible = false
		return
	_ribbon_text.text = "%s TEAM" % team_name
	var sb := StyleBoxFlat.new()
	var base: StyleBoxFlat = _ribbon.get_theme_stylebox("panel") as StyleBoxFlat
	if base != null:
		sb = base.duplicate() as StyleBoxFlat
	sb.bg_color = team_color
	_ribbon.add_theme_stylebox_override("panel", sb)
	_apply_mode_rows(_joined and not _on_back)
	if changed:
		_ribbon.pivot_offset = _ribbon.size * 0.5
		_ribbon.scale = Vector2(1.25, 1.25)
		var t := _ribbon.create_tween()
		t.tween_property(_ribbon, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Front-face rows that depend on the mode: FLAIR row (not in SPORTS) vs team ribbon (SPORTS only).
func _apply_mode_rows(front: bool) -> void:
	_flair_row.visible = front and not _sports
	_ribbon.visible = front and _sports and _team >= 0

## Which row the panel's stick drives: 0 = GOAT (chevrons bright), 1 = FLAIR (6 px gold ring on the row).
func set_row(row: int) -> void:
	_row = row
	var on_flair: bool = row == 1
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.30) if on_flair else Color(CHOCO.r, CHOCO.g, CHOCO.b, 0.08)
	rs.border_color = GOLD if on_flair else Color(CHOCO.r, CHOCO.g, CHOCO.b, 0.0)
	rs.set_border_width_all(6)
	rs.set_corner_radius_all(12)
	_flair_row.add_theme_stylebox_override("panel", rs)
	_apply_chev_alpha(false)
	_fchev_l.visible = on_flair
	_fchev_r.visible = on_flair

## WK-81 F5: flair label at a fixed 28 px (names come pre-shortened from flair.json "short"); a safety
## shrink to 24 px only if a future name still overflows.
func set_flair(text: String, locked: bool) -> void:
	_flair_val.text = text
	_flair_val.add_theme_color_override("font_color", Color(CHOCO.r, CHOCO.g, CHOCO.b, 0.45 if locked else 1.0))
	var f: Font = _flair_val.get_theme_font("font")
	var avail: float = _flair_val.size.x - 4.0
	var fs := 28
	if f != null and avail > 10.0:
		while fs > 24 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x > avail:
			fs -= 1
	_flair_val.add_theme_font_size_override("font_size", fs)

func flair_nudge(dir: int) -> void:
	((_fchev_r if dir > 0 else _fchev_l) as Object).call("nudge")
	MenuFX.value_pop(_flair_val, 1.12)

## "TAKEN BY P2" chip over the bust when another human has LOCKED the goat this panel is showing.
func set_taken_by(label: int) -> void:
	set_taken_text("TAKEN BY P%d" % label if label > 0 else "")

## WK-27: the same chip with any blocking reason ("RED IS FULL" in SPORTS 1V1). "" = not blocked.
func set_taken_text(text: String) -> void:
	_taken_text = text
	_taken.visible = text != "" and not _on_back
	if text != "":
		_taken.text = text
	_bust.modulate = Color(1, 1, 1, 0.55) if text != "" else Color.WHITE

## A short-lived chip in the TakenChip style ("P1 HAS THE RULES", 1.2 s), then the real taken state returns.
func flash_chip(text: String, secs: float) -> void:
	_flash_gen += 1
	var gen := _flash_gen
	_taken.text = text
	_taken.visible = true
	_taken.pivot_offset = _taken.size * 0.5
	MenuFX.value_pop(_taken, 1.12)
	get_tree().create_timer(secs).timeout.connect(func() -> void:
		if gen != _flash_gen or not is_instance_valid(self):
			return
		set_taken_text(_taken_text))

## PICKING <-> READY (E.10 lock / un-ready motion). WK-81 F7: READY fades the carousel chevrons out —
## the locked panel looks finished; un-ready fades them back.
func set_ready(on: bool, animate: bool) -> void:
	if on == _ready_on and animate:
		return
	_ready_on = on
	_kill(_stamp_tw)
	_apply_chev_alpha(animate)
	_rules_check.visible = on
	if on:
		_set_joined_plate()
		_set_status_ready()
		_stamp.visible = not _on_back
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
			_stamp_tw = ts
			ts.set_parallel(true)
			ts.tween_property(_stamp, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			ts.tween_property(_stamp, "rotation", deg_to_rad(-6.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			_stamp.scale = Vector2.ONE
			_stamp.rotation = deg_to_rad(-6.0)
			_stamp.modulate.a = 1.0
	else:
		_set_joined_plate()
		_set_status_picking()
		if animate and _stamp.visible:
			var tu := _stamp.create_tween()
			_stamp_tw = tu
			tu.set_parallel(true)
			tu.tween_property(_stamp, "scale", Vector2(0.8, 0.8), 0.12)
			tu.tween_property(_stamp, "modulate:a", 0.0, 0.12)
			tu.chain().tween_callback(func() -> void:
				if not _ready_on:
					_stamp.visible = false)
		else:
			_stamp.visible = false

func _apply_chev_alpha(animate: bool) -> void:
	var a: float = 0.0 if _ready_on else (0.35 if _row == 1 else 1.0)
	_kill(_chev_tw)
	if animate:
		_chev_tw = create_tween()
		_chev_tw.set_parallel(true)
		_chev_tw.tween_property(_chev_l, "modulate:a", a, 0.12)
		_chev_tw.tween_property(_chev_r, "modulate:a", a, 0.12)
	else:
		_chev_l.modulate.a = a
		_chev_r.modulate.a = a

## WK-81 F6: while the READY banner / amber hint crosses the panel bottoms, an EMPTY panel lifts its
## "PRESS A TO JOIN" 90 px above the band (and hides the KEYBOARD hint) so it is never sliced in half.
func set_join_lift(on: bool) -> void:
	if on == _lifted:
		return
	_lifted = on
	_kill(_lift_tw)
	_lift_tw = _join_box.create_tween()
	_lift_tw.tween_property(_join_box, "position:y", _join_rest_y - (90.0 if on else 0.0), 0.20) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_apply_kb_hint()

func set_kb_hint(on: bool) -> void:
	_kb_wanted = on
	_apply_kb_hint()

func _apply_kb_hint() -> void:
	_kb_hint.visible = _kb_wanted and not _lifted

## Deny (E.10): reject shake on the whole panel.
func deny() -> void:
	MenuFX.reject_shake(self)

## WK-81 F3 "that's me" ping: a press with no other effect pulses this panel's header + P-badge
## (1.0 -> 1.05 -> 1.0, 0.14 s, TRANS_BACK) — the Overcooked / Duck Game "wiggle to find yourself".
func ping() -> void:
	_header.pivot_offset = _header.size * 0.5
	var t := _header.create_tween()
	t.tween_property(_header, "scale", Vector2(1.05, 1.05), 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_header, "scale", Vector2.ONE, 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_badge.pivot_offset = _badge.size * 0.5
	MenuFX.value_pop(_badge, 1.15)

## "Who is holding things up" nudge (8 px, 0.12 s) — the RULES owner's flipped panel when someone presses GO.
func nudge() -> void:
	var t := create_tween()
	t.tween_property(self, "position:x", _rest_x + 8.0, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position:x", _rest_x, 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func is_joined() -> bool:
	return _joined

func is_flipped() -> bool:
	return _on_back

# ------------------------------------------------------------------ RULES back face (WK-07)

## Flip to the RULES back face. `data` = {rows: [{title, label, locked}], focus: int, kb: bool, icon: Texture2D}.
func show_rules(data: Dictionary) -> void:
	_rules_focus = -1
	_rules_icon.texture = data.get("icon", null)
	(_rules_done_glyph as Object).call("setup", "key:ENTER" if bool(data.get("kb", false)) else "A")
	(_rules_undo_glyph as Object).call("setup", "key:ESC" if bool(data.get("kb", false)) else "B")
	_rules_check.visible = _ready_on
	var rows: Array = data.get("rows", [])
	var n: int = rows.size()
	for i in range(_rule_rows.size()):
		var row: Panel = _rule_rows[i]
		row.visible = i < n
		if i >= n:
			continue
		# BRAWL x4 rows from y=76 (94 apart); SPORTS x2 centred in the 76-440 band (y = 168, 262)
		row.position.y = (76.0 + 94.0 * i) if n > 2 else (168.0 + 94.0 * i)
		var ps := StyleBoxFlat.new()
		ps.bg_color = _color
		ps.border_color = CHOCO
		ps.set_border_width_all(4)
		ps.set_corner_radius_all(30)
		(row.get_node("Pill") as Panel).add_theme_stylebox_override("panel", ps)
	refresh_rules(data, -1, 0)
	_flip(true)

## Re-render the rows. `changed` = row whose value just moved (pill pop + chevron nudge), `dir` = which way.
func refresh_rules(data: Dictionary, changed: int, dir: int) -> void:
	var rows: Array = data.get("rows", [])
	var focus: int = int(data.get("focus", 0))
	for i in range(mini(rows.size(), _rule_rows.size())):
		var r: Dictionary = rows[i]
		var row: Panel = _rule_rows[i]
		(row.get_node("Title") as Label).text = str(r.get("title", ""))
		(row.get_node("Pill/Value") as Label).text = str(r.get("label", ""))
		var on: bool = i == focus
		var locked: bool = bool(r.get("locked", false))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.30) if on else Color(CHOCO.r, CHOCO.g, CHOCO.b, 0.08)
		sb.border_color = GOLD
		sb.set_border_width_all(6 if on else 0)
		sb.set_corner_radius_all(16)
		row.add_theme_stylebox_override("panel", sb)
		(row.get_node("Pill/ChevL") as Control).visible = on and not locked
		(row.get_node("Pill/ChevR") as Control).visible = on and not locked
		(row.get_node("Pill/Lock") as Control).visible = locked
		(row.get_node("Pill/Value") as Label).offset_left = 30.0 if locked else 0.0   # padlock sits in the pill's left edge
		if on and _rules_focus != i:
			var t := row.create_tween()
			t.tween_property(row, "scale", Vector2(1.04, 1.04), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		elif not on and _rules_focus == i:
			var t2 := row.create_tween()
			t2.tween_property(row, "scale", Vector2.ONE, 0.10)
		if i == changed:
			var pill: Control = row.get_node("Pill")
			var tp := pill.create_tween()
			tp.tween_property(pill, "scale", Vector2(1.18, 1.18), 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tp.tween_property(pill, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			if dir != 0:
				(row.get_node("Pill/ChevR" if dir > 0 else "Pill/ChevL") as Object).call("nudge")
	_rules_focus = focus

## Shake a row's pill (bound reached / locked value, or UNDO rolling a change back).
func shake_rule(i: int) -> void:
	if i >= 0 and i < _rule_rows.size():
		MenuFX.reject_shake((_rule_rows[i] as Control).get_node("Pill") as Control)

## Flip back to the front. UNDO first shakes the rows that were rolled back, then flips.
func hide_rules(undo_rows: Array) -> void:
	if not _on_back:
		return
	if undo_rows.is_empty():
		_flip(false)
		return
	for i in undo_rows:
		shake_rule(int(i))
	get_tree().create_timer(0.22).timeout.connect(func() -> void:
		if is_instance_valid(self) and _on_back:
			_flip(false))

func _flip(to_back: bool) -> void:
	_kill(_flip_tw)
	pivot_offset = size * 0.5
	_flip_tw = create_tween()
	_flip_tw.tween_property(self, "scale:x", 0.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_flip_tw.tween_callback(func() -> void: _set_face(to_back))
	_flip_tw.tween_property(self, "scale:x", 1.06, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flip_tw.tween_property(self, "scale:x", 1.0, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _set_face(back: bool) -> void:
	_on_back = back
	_rules_face.visible = back
	for n in [_well, _banner, _blurb, _flair_row, _status, _dev_name, _dev_icon]:
		(n as Control).visible = not back and _joined
	_apply_mode_rows(not back and _joined)
	_stamp.visible = not back and _ready_on
	_taken.visible = not back and _taken_text != ""
	_set_joined_plate()
	if back:
		# rows stagger in 0.04 s apart from y+14, alpha 0 -> 1 (0.14 s)
		var k := 0
		for row in _rule_rows:
			var r: Control = row
			if not r.visible:
				continue
			var y: float = r.position.y
			r.position.y = y + 14.0
			r.modulate.a = 0.0
			var t := r.create_tween()
			t.set_parallel(true)
			t.tween_property(r, "position:y", y, 0.14).set_delay(0.04 * k).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.tween_property(r, "modulate:a", 1.0, 0.14).set_delay(0.04 * k)
			k += 1
	else:
		_start_idle()

# ------------------------------------------------------------------ internals
func _set_status_picking() -> void:
	(_status_glyph as Object).call("setup", "key:ENTER" if _device_key == "kb" else "A")
	_status_text.text = "LOCK IN"

func _set_status_ready() -> void:
	(_status_glyph as Object).call("setup", "key:ESC" if _device_key == "kb" else "B")
	_status_text.text = "CHANGE"

## Joined plate (front + back face share it): cream glass, goat-colour border; READY / RULES add the glow.
func _set_joined_plate() -> void:
	if not _joined:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(CREAM.r, CREAM.g, CREAM.b, 0.96 if (_ready_on or _on_back) else 0.92)
	sb.border_color = _color
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(22)
	if _ready_on or _on_back:
		sb.shadow_color = Color(_color.r, _color.g, _color.b, 0.5)
		sb.shadow_size = 24
	else:
		sb.shadow_color = Color(0.12, 0.07, 0.05, 0.35)
		sb.shadow_size = 8
		sb.shadow_offset = Vector2(0, 6)
	_plate.add_theme_stylebox_override("panel", sb)

## WK-81 F4: EMPTY = dark slot well (bg #3B241B, cream 0.35 / 4 px rim, no shadow) so the backdrop's
## painted goats never ghost through, and joined panels pop by contrast. Alpha is Tuning.lobby_empty_well_alpha:
## the review's 0.72 (and 0.86) still let the backdrop bobbers (BILLY behind P4) show at 1080p, so it is 0.94.
func _set_empty_plate() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(WELL.r, WELL.g, WELL.b, Tuning.lobby_empty_well_alpha)
	sb.border_color = Color(CREAM.r, CREAM.g, CREAM.b, 0.35)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(22)
	sb.shadow_size = 0
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
	if not _joined or _on_back:
		return
	_bust.pivot_offset = Vector2(_bust.size.x * 0.5, _bust.size.y * 0.85)
	_idle = _bust.create_tween().set_loops()
	_idle.tween_property(_bust, "scale", Vector2(0.97, 1.04), 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle.tween_property(_bust, "scale", Vector2(1.04, 0.97), 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _kill(t: Tween) -> void:
	if t != null and t.is_valid():
		t.kill()
