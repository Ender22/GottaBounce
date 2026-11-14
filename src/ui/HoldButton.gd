class_name HoldButton
extends Button
## Hold-to-confirm button (WK-09 · COUCH_CONVENTIONS CC-6.1 · audit C-18 / R-09). Replaces the banned
## double-press "REALLY?" swap: hold A / Enter (or the left mouse button) for Tuning.hold_confirm_time
## (0.9 s) while focused -> `confirmed`. A radial pie fills a cream cap on the button's LEFT end in
## `ring_color` (the pause owner's goat colour), six notches mark the rising-pitch ticks (one every
## Tuning.hold_confirm_tick), and releasing early DRAINS the pie back to empty over Tuning.hold_confirm_drain
## (a re-press resumes from wherever the drain has got to). Mashing can never fill it: each release
## drains 6x faster than holding fills. Focus leaving mid-hold cancels (drains).
##
## Only `confirmed` means "do it" — `pressed` is never emitted for accept/mouse (the press is consumed in
## _gui_input before BaseButton sees it), so a stray release can't trigger the action.
## Timing runs on the wall clock (Time ticks), so it works in a paused tree and under hitstop time_scale.

signal confirmed
signal hold_started
signal hold_cancelled

@export var hold_time := -1.0              # s; < 0 -> Tuning.hold_confirm_time
@export var drain_time := -1.0             # s; < 0 -> Tuning.hold_confirm_drain
@export var ring_color := Color("#ff5fa8"):
	set(v):
		ring_color = v
		queue_redraw()

const CHOCO := Color(0.231373, 0.141176, 0.105882)
const CAP := Color(1.0, 0.97, 0.92, 1.0)
const CAP_INSET := 14.0                    # px: cap centre sits this far in from the button's left edge

var progress := 0.0                        # 0..1 (eval-readable for QA)
var confirm_count := 0                     # QA: how many times this button has confirmed
var max_frame_gap := 0.0                   # QA: longest frame gap seen while held (hitch diagnostics)
var _holding := false
var _done := false
var _last_usec := 0
var _ticks_played := 0

func _ready() -> void:
	focus_exited.connect(func() -> void:
		if _holding:
			_end_hold())
	_last_usec = Time.get_ticks_usec()

## Re-enable after a confirm (the pause menu is freed on confirm, so it normally never needs this).
func reset() -> void:
	_done = false
	_holding = false
	progress = 0.0
	_ticks_played = 0
	queue_redraw()

func is_holding() -> bool:
	return _holding

func _hold_secs() -> float:
	return hold_time if hold_time > 0.0 else Tuning.hold_confirm_time

func _drain_secs() -> float:
	return drain_time if drain_time > 0.0 else Tuning.hold_confirm_drain

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if e.is_pressed():
			if not has_focus():
				grab_focus()
			_begin_hold()
		else:
			_end_hold()
		return
	if e.is_action("ui_accept") or e.is_action("menu_accept"):
		accept_event()   # BaseButton never sees accept -> `pressed` can't fire on a stray release
		if e is InputEventKey and (e as InputEventKey).echo:
			return
		if e.is_pressed():
			_begin_hold()
		else:
			_end_hold()

func _begin_hold() -> void:
	if _done or _holding or disabled:
		return
	_holding = true
	_last_usec = Time.get_ticks_usec()
	hold_started.emit()

func _end_hold() -> void:
	if not _holding:
		return
	_holding = false
	if not _done:
		hold_cancelled.emit()

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	# wall-clock seconds the button was really held: a frame hitch must not stretch the 0.9 s (a 0.1 s clamp
	# here made a 1.0 s hold fail after one ~0.5 s hitch). 0.5 s cap only guards a resumed/unfocused window.
	var dt: float = clampf(float(now - _last_usec) / 1000000.0, 0.0, 0.5)
	_last_usec = now
	if _holding:
		max_frame_gap = maxf(max_frame_gap, dt)
	if _done:
		return
	var before := progress
	if _holding:
		progress = minf(1.0, progress + dt / _hold_secs())
		var tick_n: int = int(floor(progress * _hold_secs() / Tuning.hold_confirm_tick + 0.0001))
		while _ticks_played < tick_n:
			_ticks_played += 1
			# rising tick (CC-9.1 "hold-to-confirm (rising ticks)")
			AudioManager.play_sfx("ui_click", {"pitch": 0.85 + 0.13 * _ticks_played, "pitch_var": 0.0, "volume_db": -10.0})
		if progress >= 1.0:
			_confirm()
	elif progress > 0.0:
		progress = maxf(0.0, progress - dt / _drain_secs())
		_ticks_played = int(floor(progress * _hold_secs() / Tuning.hold_confirm_tick + 0.0001))
	if progress != before:
		queue_redraw()

func _confirm() -> void:
	_done = true
	_holding = false
	progress = 1.0
	confirm_count += 1
	queue_redraw()
	AudioManager.play_sfx("ui_click", {"pitch": 1.7, "pitch_var": 0.0, "volume_db": -2.0})
	MenuFX.press_pop(self)
	confirmed.emit()

func _draw() -> void:
	# the cap shows whenever this button is focused or has progress — the "hold me" affordance
	if not has_focus() and progress <= 0.0:
		return
	# the cap is a medallion pinned over the button's left edge (half outside it), so it never collides with a
	# long centred label ("CHANGE SETUP") at the focused scale
	var r: float = size.y * 0.36
	var c := Vector2(CAP_INSET, size.y * 0.5)
	draw_circle(c, r + 4.0, CHOCO)
	draw_circle(c, r - 1.0, CAP)
	if progress > 0.0:
		# the pie is the owner colour, slightly deepened so it still reads against a pale owner fill (PUFF)
		var pie: Color = ring_color.darkened(0.08)
		var pts := PackedVector2Array([c])
		var steps: int = maxi(2, int(56.0 * progress))
		var a0 := -PI * 0.5
		for i in range(steps + 1):
			var a: float = a0 + TAU * progress * float(i) / float(steps)
			pts.append(c + Vector2(cos(a), sin(a)) * (r - 2.0))
		draw_colored_polygon(pts, pie)
	# tick notches: one per Tuning.hold_confirm_tick; passed notches go solid
	var n: int = maxi(1, int(round(_hold_secs() / Tuning.hold_confirm_tick)))
	for i in range(n):
		var a: float = -PI * 0.5 + TAU * float(i) / float(n)
		var dir := Vector2(cos(a), sin(a))
		var lit: bool = progress * float(n) >= float(i) + 0.999 or (i == 0 and progress > 0.0)
		draw_line(c + dir * (r - 7.0), c + dir * (r + 1.0), CHOCO if lit else Color(CHOCO.r, CHOCO.g, CHOCO.b, 0.35), 3.0, true)
	draw_arc(c, r - 1.0, 0.0, TAU, 40, CHOCO, 3.0, true)
