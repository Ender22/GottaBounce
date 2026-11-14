extends CanvasLayer
## Between-stage SCORE SCREEN (owner 2026-07-16: "show a brief score screen between levels before
## the next level is loaded" — the Duck Game intermission / TowerFall tally pattern; research notes
## in docs/feedback/owner_2026-07-16_night_list.md #4). Replaces the corner-card score pips as the
## score display: combat now carries NO persistent score, and the tally between stages is the
## reveal/breather beat. Shown by PartyMatch during its SCOREBOARD state (BRAWL only, via
## GameMode.wants_scoreboard) — auto-advances, skippable with accept after a short guard.
##
## Presentation: each player row = goat head + NAME (+ small sub-tag, CC-8.5) + a colored RACE BAR toward the kill target
## (the finish line IS the "first to N" teaching device, replacing the pips) + big tally + this
## stage's +/- delta chip (WK-20c: or a non-scoring "OOPS!" chip for a self-KO that cost nothing).
## Bars animate from the pre-stage score to the new truth, staggered.

const BAR_PAD := 3.0
const ROW_STAGGER := 0.12
const FILL_TIME := 0.5
const GOLD := Color("#ffd23f")
const DANGER := Color("#ff4b3a")
const CHOCO := Color(0.231373, 0.141176, 0.105882)
## WK-20c: the non-scoring "OOPS!" chip (self-KO under the default rule) — a cool neutral, never the -1 red.
const OOPS_COLOR := Color(0.62, 0.74, 0.92)

@onready var _root: Control = $Root
@onready var _panel: PanelContainer = $Root/Center/Panel
@onready var _sub: Label = $Root/Center/Panel/Box/Sub
@onready var _rows_box: VBoxContainer = $Root/Center/Panel/Box/Rows
@onready var _template: HBoxContainer = $Root/Center/Panel/Box/Rows/RowTemplate
# WK-41 (R-27): ONE prompt — a countdown ring, because the screen auto-advances. The old "(A) CONTINUE" hint
# promised a wait that never happened. A (or FLY) still skips after the guard; it is just not advertised.
@onready var _ring: Control = $Root/Center/Panel/Box/Prompt/Ring
# WK-25 (audit D-02 part 3): this stage's kill list under the race bars — one compact chip per KO, in order.
@onready var _kill_list: HFlowContainer = $Root/Center/Panel/Box/KillList
@onready var _kill_template: PanelContainer = $Root/Center/Panel/Box/KillList/KillTemplate
const KILL_LIST_MAX := 8          # more KOs than this (multi-life rules) collapse into a "+N MORE" chip
const KILL_STAGGER := 0.07

var _tw: Tween
var _present_gen := 0   # bumps per present(); a superseded call stops after its layout wait

## rows: [{pn:int, name:String, sub:String, color:Color, skin:String, score:int, delta:int, oops:bool}],
## target = kills_to_win. `oops` (WK-20c, optional) = a self-KO this stage that cost nothing.
## pn = 1-based player index (row identity); name/sub = CC-8.5 identity (WK-88): "P3"+"POGO" / "VEX"+"CPU".
## kills (WK-25, optional): this stage's KOs in order — {kind:"ko"|"oops"|"minus", v_name, v_color, v_skin,
## k_name, k_color, k_skin (kind "ko" only), cost (kind "minus")} — shown as "P2 ▶ P3" / "P4 OOPS!" chips.
func present(rows: Array, target: int, kills: Array = []) -> void:
	visible = true
	_root.modulate.a = 1.0
	for c in _rows_box.get_children():
		if c != _template:
			c.queue_free()
	# match-point staging (TowerFall pattern): the sub-line turns red the moment someone sits 1 away
	var match_point := false
	var leader := -1
	var best := -1
	for r in rows:
		if int(r["score"]) >= target - 1:
			match_point = true
		if int(r["score"]) > best:
			best = int(r["score"])
			leader = int(r["pn"])
	if match_point and leader > 0:
		_sub.text = "MATCH POINT — FIRST TO %d" % target
		_sub.add_theme_color_override("font_color", DANGER)
	else:
		_sub.text = "FIRST TO %d KOs" % target
		_sub.add_theme_color_override("font_color", Color.WHITE)
	var built: Array = []
	for r in rows:
		built.append(_build_row(r, target))
	var kill_chips: Array = _build_kill_list(kills)
	if _tw != null and _tw.is_valid():
		_tw.kill()
	# pop the panel, then let the bars race
	_panel.reset_size()
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.35, 0.35)
	_panel.modulate.a = 1.0
	_tw = create_tween()
	_tw.tween_property(_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# bars animate AFTER layout has sized the row slots (one frame)
	_present_gen += 1
	var gen: int = _present_gen
	await get_tree().process_frame
	await get_tree().process_frame
	if gen != _present_gen:
		return   # WK-25: a newer present() replaced these rows/chips during the wait (they are freed)
	for i in range(built.size()):
		_animate_row(built[i], float(i) * ROW_STAGGER)
	# the kill list lands right after the bars start racing (it explains the deltas they show)
	var k0: float = float(built.size()) * ROW_STAGGER + 0.1
	for j in range(kill_chips.size()):
		var chip: Control = kill_chips[j]
		var tw := create_tween()
		tw.tween_interval(k0 + float(j) * KILL_STAGGER)
		tw.tween_property(chip, "modulate:a", 1.0, 0.14)

## Fade out over Tuning.scoreboard_fade_out. PartyMatch starts this INSIDE the hold and only loads the next stage
## (and its intro card) once the fade has finished — WK-41: the overlays run in sequence, never on top of each other.
func dismiss() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(_root, "modulate:a", 0.0, Tuning.scoreboard_fade_out)
	_tw.tween_callback(func() -> void: visible = false)

## WK-41 single prompt: the countdown ring's remaining fraction (1 = full hold left, 0 = advancing now).
## Driven by PartyMatch's authoritative SCOREBOARD timer so the ring empties exactly when the screen leaves.
func set_countdown(remaining: float) -> void:
	if _ring != null:
		_ring.remaining = remaining

## True while any part of the screen is actually on screen (QA overlay audit; a finished fade = false).
func is_showing() -> bool:
	return visible and _root.modulate.a > 0.02

## WK-25: rebuild the kill-list chips from the template (hidden when the stage had no KOs). Chips start
## transparent and are faded in by present(). Returns the chip nodes.
func _build_kill_list(kills: Array) -> Array:
	for c in _kill_list.get_children():
		if c != _kill_template:
			c.queue_free()
	var out: Array = []
	var n: int = kills.size()
	var shown: int = n if n <= KILL_LIST_MAX else KILL_LIST_MAX - 1
	for i in range(shown):
		out.append(_build_kill_chip(kills[i]))
	if n > shown:
		var more: PanelContainer = _kill_template.duplicate()
		more.visible = true
		_kill_list.add_child(more)
		for nm in ["KHead", "Arrow", "VHead", "VName", "Tag"]:
			(more.get_node("H/" + nm) as CanvasItem).visible = false
		var ml: Label = more.get_node("H/KName")
		ml.text = "+%d MORE" % (n - shown)
		more.modulate.a = 0.0
		out.append(more)
	_kill_list.visible = n > 0
	return out

func _build_kill_chip(e: Dictionary) -> Control:
	var chip: PanelContainer = _kill_template.duplicate()
	chip.visible = true
	_kill_list.add_child(chip)
	var kind: String = str(e.get("kind", "ko"))
	var k_head: TextureRect = chip.get_node("H/KHead")
	var k_name: Label = chip.get_node("H/KName")
	var arrow: Control = chip.get_node("H/Arrow")
	var v_head: TextureRect = chip.get_node("H/VHead")
	var v_name: Label = chip.get_node("H/VName")
	var tag: Label = chip.get_node("H/Tag")
	if kind == "ko":
		_set_head(k_head, str(e.get("k_skin", "")))
		k_name.text = str(e.get("k_name", "?"))
		k_name.add_theme_color_override("font_color", e.get("k_color", Color.WHITE))
		_set_head(v_head, str(e.get("v_skin", "")))
		v_name.text = str(e.get("v_name", "?"))
		v_name.add_theme_color_override("font_color", e.get("v_color", Color.WHITE))
		tag.visible = false
	else:
		# self-KO: the faller's head + name, then the WK-20c chip text ("OOPS!" costs nothing; "SELF-KO −1" did)
		_set_head(k_head, str(e.get("v_skin", "")))
		k_name.text = str(e.get("v_name", "?"))
		k_name.add_theme_color_override("font_color", e.get("v_color", Color.WHITE))
		arrow.visible = false
		v_head.visible = false
		v_name.visible = false
		tag.visible = true
		if kind == "minus":
			tag.text = "SELF-KO −%d" % maxi(1, int(e.get("cost", 1)))
			tag.add_theme_color_override("font_color", Color(0.95, 0.55, 0.5))
		else:
			tag.text = "OOPS!"
			tag.add_theme_color_override("font_color", OOPS_COLOR)
	chip.modulate.a = 0.0
	return chip

func _set_head(tr: TextureRect, skin: String) -> void:
	var path := "res://assets/characters/bouncer_%s_idle.png" % skin
	if skin != "" and ResourceLoader.exists(path):
		tr.texture = load(path)

## Duplicate the hidden template row and fill its identity slots. Returns the animation handles.
func _build_row(r: Dictionary, target: int) -> Dictionary:
	var row: HBoxContainer = _template.duplicate()
	row.visible = true
	_rows_box.add_child(row)
	var color: Color = r["color"]
	var head: TextureRect = row.get_node("Head")
	var head_path := "res://assets/characters/bouncer_%s_idle.png" % str(r["skin"])
	if ResourceLoader.exists(head_path):
		head.texture = load(head_path)
	var name_l: Label = row.get_node("NameBox/PName")
	name_l.text = str(r.get("name", "P%d" % int(r["pn"])))   # WK-88 (CC-8.5): "P3" / "VEX"
	name_l.add_theme_color_override("font_color", color)
	var sub_l: Label = row.get_node("NameBox/PSub")
	sub_l.text = str(r.get("sub", ""))                          # small tag: goat name / "CPU"
	sub_l.visible = sub_l.text != ""
	var fill: Panel = row.get_node("BarSlot/BarFill")
	var fill_sb: StyleBoxFlat = StyleBoxFlat.new()
	fill_sb.bg_color = color
	fill_sb.set_corner_radius_all(7)
	fill.add_theme_stylebox_override("panel", fill_sb)
	var score_l: Label = row.get_node("Score")
	var delta: int = int(r["delta"])
	var from_score: int = maxi(0, int(r["score"]) - delta)
	score_l.text = str(from_score)
	var delta_l: Label = row.get_node("Delta")
	var oops: bool = delta == 0 and bool(r.get("oops", false))
	if delta != 0:
		delta_l.text = "%+d" % delta
		delta_l.add_theme_color_override("font_color", GOLD if delta > 0 else Color(0.75, 0.45, 0.4))
		delta_l.modulate.a = 0.0
	elif oops:
		# WK-20c (Ra): a self-KO that cost nothing — a non-scoring reaction chip, never a number
		delta_l.text = "OOPS!"
		delta_l.add_theme_color_override("font_color", OOPS_COLOR)
		delta_l.modulate.a = 0.0
	else:
		delta_l.text = ""
	return {"row": row, "fill": fill, "score_l": score_l, "delta_l": delta_l,
		"from": from_score, "to": int(r["score"]), "target": maxi(1, target), "delta": delta, "oops": oops}

func _animate_row(h: Dictionary, delay: float) -> void:
	var slot: Control = (h["row"] as Control).get_node("BarSlot")
	var inner_w: float = maxf(0.0, slot.size.x - BAR_PAD * 2.0)
	var inner_h: float = maxf(0.0, slot.size.y - BAR_PAD * 2.0)
	var fill: Panel = h["fill"]
	var w_from: float = inner_w * clampf(float(h["from"]) / float(h["target"]), 0.0, 1.0)
	var w_to: float = inner_w * clampf(float(h["to"]) / float(h["target"]), 0.0, 1.0)
	fill.position = Vector2(BAR_PAD, BAR_PAD)
	fill.size = Vector2(w_from, inner_h)
	fill.visible = true
	var tw := create_tween()
	tw.tween_interval(maxf(0.01, delay))
	if w_to != w_from:
		tw.tween_property(fill, "size:x", w_to, FILL_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var score_l: Label = h["score_l"]
	tw.parallel().tween_method(func(v: float) -> void: score_l.text = str(int(round(v))),
		float(h["from"]), float(h["to"]), FILL_TIME if h["to"] != h["from"] else 0.01)
	if int(h["delta"]) != 0 or bool(h.get("oops", false)):
		var delta_l: Label = h["delta_l"]
		delta_l.pivot_offset = delta_l.size * 0.5
		delta_l.scale = Vector2(1.6, 1.6)
		tw.parallel().tween_property(delta_l, "modulate:a", 1.0, 0.15)
		tw.parallel().tween_property(delta_l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
