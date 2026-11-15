extends CanvasLayer
## WK-28b in-match controller-disconnect overlay (COUCH_CONVENTIONS CC-3.4 · audit C-07 · BACKLOG WK-28 match half).
## Opened by DeviceWatch when a pad that drives a human seat is lost during a live match: the match auto-pauses
## (get_tree().paused) and this cream plate shows "P2 · CONTROLLER · DISCONNECTED" in P2's goat colour with their
## portrait (greyed while the pad is gone). Look = the PauseMenu / WK-28a lobby kit (ToyPanel plate, ToyRibbon owner
## band, the lobby's red DISCONNECTED chip).
##
## Ways out (CC-3.4):
##   * A on the LOST pad (reconnected, same id)        -> that seat plays on, unchanged ("reclaim").
##   * A on any device that drives no seat (a spare pad, the keyboard, the same pad back under a new id)
##                                                      -> that device takes the seat over ("takeover").
##   * RESUME WITHOUT P2 (HOLD, any remaining joined device) -> the seat plays on as a CPU; the pad (or any free
##     device) can take it back mid-play with A (DeviceWatch). Hidden when no other human would be left playing.
##   * QUIT TO MENU (HOLD) -> mode select, like the pause menu's.
## Who drives the buttons: "any remaining joined device" = every device still driving a human seat (CC-3.4). If no
## such device is left, any device can move focus (A on a free device still means TAKE OVER; the mouse can click).
## Both buttons are hold-to-confirm, so a player still mashing boost-A when the overlay pops can't fire either, and
## nothing counts for Tuning.disconnect_input_arm s after it opens. Several lost seats queue: one plate at a time,
## "P3 IS DISCONNECTED TOO" underneath. A pause menu that was open underneath is suspended (hidden, inert) and comes
## back, still owned by whoever paused, when the last lost seat is resolved; otherwise the match resumes with the
## usual held-button swallow (CC-5.7, PartyMatch.on_pause_resumed).
##
## This node only routes input and draws; the seat rebinding lives in DeviceWatch (rebind / make_cpu).

const PORTRAIT := "res://assets/ui/portraits/portrait_%s.png"
const FOCUS_FILL := Color("#ffd23f")   # neutral gold (no single owner) — the PauseMenu's no-owner colour

@onready var _menu: Control = $Root/Menu
@onready var _panel: PanelContainer = $Root/Menu/Panel
@onready var _band: PanelContainer = $Root/Menu/Panel/VBox/OwnerBand
@onready var _medallion: Control = $Root/Menu/Panel/VBox/OwnerBand/Header/Medallion
@onready var _portrait: TextureRect = $Root/Menu/Panel/VBox/OwnerBand/Header/Medallion/Portrait
@onready var _owner_label: Label = $Root/Menu/Panel/VBox/OwnerBand/Header/OwnerPill/OwnerLabel
@onready var _disc_chip: Label = $Root/Menu/Panel/VBox/OwnerBand/Header/Words/DiscChip
@onready var _back_chip: Label = $Root/Menu/Panel/VBox/OwnerBand/Header/Words/BackChip
@onready var _status: Label = $Root/Menu/Panel/VBox/Status
@onready var _resume_text: Label = $Root/Menu/Panel/VBox/ResumeRow/Text
@onready var _take_slash: Label = $Root/Menu/Panel/VBox/TakeRow/Slash
@onready var _take_glyph2: Control = $Root/Menu/Panel/VBox/TakeRow/Glyph2
@onready var _take_text: Label = $Root/Menu/Panel/VBox/TakeRow/Text
@onready var _also: HBoxContainer = $Root/Menu/Panel/VBox/Also   # WK-166 (F5): P# tokens in identity colour + red tail
@onready var _also_toks: Array = [$Root/Menu/Panel/VBox/Also/Tok0, $Root/Menu/Panel/VBox/Also/Tok1, $Root/Menu/Panel/VBox/Also/Tok2]
@onready var _also_amps: Array = [$Root/Menu/Panel/VBox/Also/Amp0, $Root/Menu/Panel/VBox/Also/Amp1]
@onready var _also_tail: Label = $Root/Menu/Panel/VBox/Also/Tail
@onready var _without: HoldButton = $Root/Menu/Panel/VBox/Buttons/WithoutBtn
@onready var _without_note: Label = $Root/Menu/Panel/VBox/Buttons/WithoutNote
@onready var _quit: HoldButton = $Root/Menu/Panel/VBox/Buttons/QuitBtn
@onready var _note_gap: Control = $Root/Menu/Panel/VBox/Buttons/NoteGap     # WK-166 (F2)
@onready var _note_gap2: Control = $Root/Menu/Panel/VBox/Buttons/NoteGap2   # WK-166 (F2)
@onready var _quit_note: Label = $Root/Menu/Panel/VBox/Buttons/QuitNote     # WK-166 (F4)
@onready var _hints: HBoxContainer = $Root/Menu/Panel/VBox/HintBox
@onready var _rule2: Control = $Root/Menu/Panel/VBox/Rule2

var watch            # DeviceWatch (seat rebinding)
var match_ref        # the PartyMatch
var pause_under = null   # a PauseMenu suspended underneath, or null
## Lost seats waiting, current = [0]: {h: player index, key: lost pad key, back: reconnected since}.
var queue: Array = []
# QA readouts (eval)
var last_action := ""    # "reclaim" / "takeover" / "without" / "quit"
var resolved: Array = [] # [{h, how, key}] newest last
var deny_count := 0      # WK-166: deny ticks played for a driver's B / Esc (QA readout)
var also_text := ""      # WK-166: the "P3 IS DISCONNECTED TOO" line as plain text (QA readout)
var drivers_left := true # WK-166 (F4): false = no joined device can drive the buttons (QUIT drawn unfocused + caption)
var _open_msec := 0
var _closing := false

func setup(w, m, under) -> void:
	watch = w
	match_ref = m
	pause_under = under

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_open_msec = Time.get_ticks_msec()
	for b: Button in [_without, _quit]:
		_reg(b)
	_without.confirmed.connect(_do_without)
	_quit.confirmed.connect(_do_quit)
	_wire()
	_refresh()
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.85, 0.85)
	_menu.modulate.a = 0.0
	var t := _panel.create_tween()
	t.tween_property(_menu, "modulate:a", 1.0, Tuning.disconnect_pop_time)
	t.parallel().tween_property(_panel, "scale", Vector2.ONE, Tuning.disconnect_pop_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioManager.play_sfx("ui_click", {"pitch": 0.55, "pitch_var": 0.0, "volume_db": -2.0})
	call_deferred("_grab_default")

# ------------------------------------------------------------------ queue (DeviceWatch calls these)

func add_lost(h: int, key: String) -> void:
	if seat_index(h) >= 0:
		return
	queue.append({"h": h, "key": key, "back": false})
	if is_node_ready():
		_refresh()

func seat_index(h: int) -> int:
	for i in range(queue.size()):
		if int(queue[i]["h"]) == h:
			return i
	return -1

## Player index whose lost pad is `key`, -1 if none waiting.
func lost_seat_of(key: String) -> int:
	for e in queue:
		if str(e["key"]) == key:
			return int(e["h"])
	return -1

func current_seat() -> int:
	return int(queue[0]["h"]) if not queue.is_empty() else -1

## The lost pad was plugged back in: the plate says so (it still has to press A — CC-3.5's "a newly connected pad
## does nothing until it presses A").
func on_found(key: String) -> void:
	for e in queue:
		if str(e["key"]) == key:
			e["back"] = true
	_refresh()
	AudioManager.play_sfx("powerup_pickup", {"pitch": 1.2, "pitch_var": 0.0, "volume_db": -6.0})

func on_lost_again(key: String) -> void:
	for e in queue:
		if str(e["key"]) == key:
			e["back"] = false
	_refresh()

# ------------------------------------------------------------------ view

func _refresh() -> void:
	if queue.is_empty() or match_ref == null or not is_instance_valid(match_ref):
		return
	var e: Dictionary = queue[0]
	var h: int = int(e["h"])
	var back: bool = bool(e["back"])
	var tag: String = _tag(h)
	var col: Color = match_ref.player_color(h)
	var band_sb: StyleBoxFlat = (_band.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	band_sb.bg_color = col
	_band.add_theme_stylebox_override("panel", band_sb)
	_owner_label.text = tag
	_owner_label.add_theme_color_override("font_color", col)
	var skin: String = str(match_ref.players[h].skin)
	var tex_path: String = PORTRAIT % PlayerIdentity.name_for_skin(skin).to_lower()
	_medallion.visible = ResourceLoader.exists(tex_path)
	if _medallion.visible:
		_portrait.texture = load(tex_path)
	_portrait.modulate = Color.WHITE if back else Tuning.disconnect_portrait_tint
	_disc_chip.visible = not back
	_back_chip.visible = back
	_status.text = ("WELCOME BACK, %s!" % tag) if back else "PLUG IT BACK IN"
	_resume_text.text = "ON %s'S CONTROLLER TO PLAY ON" % tag
	var kb_free: bool = watch != null and watch.is_free_device(match_ref, InputRouter.KB)
	_take_slash.visible = kb_free
	_take_glyph2.visible = kb_free
	# WK-166 (F7): with the ENTER twin on show, the line names the keyboard too
	_take_text.text = "ON ANOTHER CONTROLLER OR KEYBOARD TO TAKE OVER" if kb_free else "ON ANOTHER CONTROLLER TO TAKE OVER"
	# WK-166 (F5, CC-8.3): "P3 & P4 ARE DISCONNECTED TOO" - each P# token in that player's identity colour
	var others: Array = []
	for i in range(1, queue.size()):
		others.append(int(queue[i]["h"]))
	_also.visible = not others.is_empty()
	var names: Array[String] = []
	for t in range(_also_toks.size()):
		var lbl: Label = _also_toks[t]
		lbl.visible = t < others.size()
		if t < others.size():
			lbl.text = _tag(int(others[t]))
			lbl.add_theme_color_override("font_color", match_ref.player_color(int(others[t])))
			names.append(lbl.text)
	for a in range(_also_amps.size()):
		(_also_amps[a] as Label).visible = a + 1 < others.size()
	_also_tail.text = "%s DISCONNECTED TOO" % ("IS" if others.size() == 1 else "ARE")
	also_text = ("%s %s" % [" & ".join(names), _also_tail.text]) if not others.is_empty() else ""
	_without.text = "RESUME WITHOUT %s" % tag
	_without_note.text = "%s'S GOAT PLAYS ON AS A CPU" % tag
	var can_without: bool = watch != null and watch.others_playing(match_ref, _lost_seats())
	# "A Hold to confirm" is only true while some joined device is left to drive the buttons; with nobody left, A on
	# any device means TAKE OVER (CC-1.7: prompts name the real binding), so the strip goes (the mouse can still click).
	_hints.visible = can_without
	_rule2.visible = can_without
	_without.visible = can_without
	_without_note.visible = can_without
	_note_gap.visible = can_without
	_note_gap2.visible = can_without
	for b: Button in [_without, _quit]:
		(b as HoldButton).ring_color = FOCUS_FILL.darkened(0.25)
	# WK-166 (F4, CC-1.7 / CC-5.1): with no driver left nothing on a pad / key can fire QUIT (A = TAKE OVER), so it is
	# not drawn focused (gold + hold ring); a caption says what to do. The mouse can still hold it.
	drivers_left = can_without
	_quit_note.visible = not can_without
	if not can_without:
		if _without.has_focus() or _quit.has_focus():
			get_viewport().gui_release_focus()

func _tag(h: int) -> String:
	var n: int = match_ref.player_label(h)
	return ("P%d" % n) if n > 0 else str(match_ref.player_name(h))

func _lost_seats() -> Array:
	var out: Array = []
	for e in queue:
		out.append(int(e["h"]))
	return out

# ------------------------------------------------------------------ focus (CC-5.1 full style swap, like PauseMenu)

func _reg(b: Button) -> void:
	b.set_meta("focus_scale", 1.08)
	b.focus_entered.connect(func() -> void:
		MenuFX.focus_in(b)
		_style_focus(b, true)
		AudioManager.play_sfx("ui_click", {"pitch": 1.26, "volume_db": -12.0}))
	b.focus_exited.connect(func() -> void:
		MenuFX.focus_out(b)
		_style_focus(b, false))
	b.mouse_entered.connect(func() -> void:
		if InputRouter.cursor_shown and not b.has_focus():
			b.grab_focus())

func _style_focus(b: Button, on: bool) -> void:
	for s in ["normal", "hover", "focus", "pressed"]:
		b.remove_theme_stylebox_override(s)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_outline_color"]:
		b.remove_theme_color_override(c)
	b.remove_theme_constant_override("outline_size")
	if not on:
		return
	var base: StyleBox = b.get_theme_stylebox("hover")
	if base is StyleBoxFlat:
		var sb: StyleBoxFlat = (base as StyleBoxFlat).duplicate()
		sb.bg_color = FOCUS_FILL
		for s in ["normal", "hover", "focus"]:
			b.add_theme_stylebox_override(s, sb)
		var pr: StyleBoxFlat = sb.duplicate()
		pr.bg_color = FOCUS_FILL.darkened(0.12)
		b.add_theme_stylebox_override("pressed", pr)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_color_override("font_outline_color", MenuFX.CHOCO)
	b.add_theme_constant_override("outline_size", 12)

## Two-item column that wraps (CC-5.2); left / right stay put so focus can never wander into a suspended pause menu.
func _wire() -> void:
	for b: Button in [_without, _quit]:
		var other: Button = _quit if b == _without else _without
		b.focus_neighbor_top = b.get_path_to(other)
		b.focus_neighbor_bottom = b.get_path_to(other)
		b.focus_neighbor_left = b.get_path_to(b)
		b.focus_neighbor_right = b.get_path_to(b)
		b.focus_previous = b.get_path_to(other)
		b.focus_next = b.get_path_to(other)

func _grab_default() -> void:
	if _without.visible:
		_without.grab_focus()
	elif drivers_left:
		_quit.grab_focus()
	# WK-166 (F4): no driver left -> nothing focused (QUIT is mouse-only until someone takes a seat over)

# ------------------------------------------------------------------ input routing

func _armed() -> bool:
	return Time.get_ticks_msec() - _open_msec >= int(Tuning.disconnect_input_arm * 1000.0)

func _is_a(e: InputEvent) -> bool:
	return (e.is_action_pressed("ui_accept") or e.is_action_pressed("menu_accept")) and not e.is_echo()

func _is_menu_nav(e: InputEvent) -> bool:
	for a in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept", "menu_accept"]:
		if e.is_action(a):
			return true
	return false

## Runs before GUI focus navigation and before the suspended pause menu / PartyMatch's pause action, so every
## keyboard / pad event is decided here. Mouse events pass straight through to the buttons (CC-2.4).
func _input(e: InputEvent) -> void:
	if _closing:
		get_viewport().set_input_as_handled()
		return
	var k: String = InputRouter.device_key(e)
	if k == "":
		return
	if not _armed():
		get_viewport().set_input_as_handled()
		return
	# 1) a lost pad: A gives its own seat back to it
	var lost_h: int = lost_seat_of(k)
	if lost_h >= 0:
		get_viewport().set_input_as_handled()
		if _is_a(e):
			_reclaim(lost_h, k)
		return
	# 2) a device still driving a seat: drives the two buttons (focus nav + hold A), nothing else
	if watch != null and watch.is_driver(match_ref, k, _lost_seats()):
		if not _is_menu_nav(e):
			get_viewport().set_input_as_handled()
			# WK-166 (CC-5.2 "nothing silently dead"): a driver's B / Esc does nothing here, so it says so
			if (e.is_action_pressed("ui_cancel") or e.is_action_pressed("menu_back")) and not e.is_echo():
				AudioManager.play_sfx("ui_click", {"pitch": 0.55, "pitch_var": 0.0, "volume_db": -4.0})
				deny_count += 1
		return
	# 3) a free device: A takes the current seat over. WK-166 (F4): with nobody left to drive, nothing else is
	# actionable (QUIT is not focusable from a pad / key then), so focus moves are swallowed too.
	if _is_a(e):
		get_viewport().set_input_as_handled()
		_takeover(current_seat(), k)
		return
	get_viewport().set_input_as_handled()

# ------------------------------------------------------------------ actions

func _reclaim(h: int, key: String) -> void:
	last_action = "reclaim"
	watch.rebind(match_ref, h, key)
	watch.seat_toast(match_ref, h, true, key)   # WK-166 (F3): "P2 · IS BACK!" - visible confirmation, not only a sound
	_resolve(h, "reclaim", key)

func _takeover(h: int, key: String) -> void:
	if h < 0:
		return
	last_action = "takeover"
	watch.rebind(match_ref, h, key)
	watch.seat_toast(match_ref, h, false, key)   # WK-166 (F3): "P2 · TAKEN OVER" with the new device's icon
	_resolve(h, "takeover", key)

func _do_without() -> void:
	if queue.is_empty():
		return
	var h: int = current_seat()
	last_action = "without"
	watch.make_cpu(match_ref, h)
	_resolve(h, "without", str(queue[0]["key"]))

func _do_quit() -> void:
	last_action = "quit"
	_closing = true
	if watch != null:
		watch.overlay_closed(self)
	get_tree().paused = false
	GameConfig.quit_to_modes = true   # WK-144: lands on mode select, lobby cleared (same as the pause menu's QUIT)
	get_tree().change_scene_to_file("res://scenes/ui/ShellRoot.tscn")

func _resolve(h: int, how: String, key: String) -> void:
	resolved.append({"h": h, "how": how, "key": key})
	var i: int = seat_index(h)
	# a pause menu underneath whose OWNER was this seat's pad follows the seat to its new device (CC-1.5)
	if how != "without" and i >= 0 and pause_under != null and is_instance_valid(pause_under) and pause_under.has_method("on_seat_rebound"):
		pause_under.on_seat_rebound(str(queue[i]["key"]), key)
	if i >= 0:
		queue.remove_at(i)
	AudioManager.play_sfx("powerup_pickup", {"pitch": 1.35 if how != "without" else 0.9, "pitch_var": 0.0, "volume_db": -4.0})
	if not queue.is_empty():
		_open_msec = Time.get_ticks_msec()   # re-arm: the press that solved P2 must not also solve P3
		_refresh()
		_grab_default()
		return
	_close()

## Last lost seat solved: give the screen back — to the pause menu that was open underneath (still paused, still
## owned by whoever paused), or straight to play with the held-button swallow.
func _close() -> void:
	_closing = true
	if watch != null:
		watch.overlay_closed(self)
	if pause_under != null and is_instance_valid(pause_under) and pause_under.has_method("set_suspended"):
		pause_under.set_suspended(false)
	else:
		get_tree().paused = false
		if match_ref != null and is_instance_valid(match_ref):
			if match_ref.has_method("set_match_overlays_hidden"):
				match_ref.set_match_overlays_hidden(false)
			if match_ref.has_method("on_pause_resumed"):
				match_ref.on_pause_resumed()
	queue_free()
