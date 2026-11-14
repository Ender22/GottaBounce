extends CanvasLayer
## Between-stage SCORE SCREEN (owner 2026-07-16: "show a brief score screen between levels before
## the next level is loaded" — the Duck Game intermission / TowerFall tally pattern; research notes
## in docs/feedback/owner_2026-07-16_night_list.md #4). Replaces the corner-card score pips as the
## score display: combat now carries NO persistent score, and the tally between stages is the
## reveal/breather beat. Shown by PartyMatch during its SCOREBOARD state (BRAWL only, via
## GameMode.wants_scoreboard) — auto-advances, skippable with accept after a short guard.
##
## Presentation: each player row = goat head + P# + a colored RACE BAR toward the kill target
## (the finish line IS the "first to N" teaching device, replacing the pips) + big tally + this
## stage's +/- delta chip. Bars animate from the pre-stage score to the new truth, staggered.

const BAR_PAD := 3.0
const ROW_STAGGER := 0.12
const FILL_TIME := 0.5
const GOLD := Color("#ffd23f")
const DANGER := Color("#ff4b3a")
const CHOCO := Color(0.231373, 0.141176, 0.105882)

@onready var _root: Control = $Root
@onready var _panel: PanelContainer = $Root/Center/Panel
@onready var _sub: Label = $Root/Center/Panel/Box/Sub
@onready var _rows_box: VBoxContainer = $Root/Center/Panel/Box/Rows
@onready var _template: HBoxContainer = $Root/Center/Panel/Box/Rows/RowTemplate

var _tw: Tween

## rows: [{pn:int, tag:String, color:Color, skin:String, score:int, delta:int}], target = kills_to_win.
## pn = 1-based player index (row identity); tag = the displayed identity ("P3" / "CPU", WK-10).
func present(rows: Array, target: int) -> void:
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
	await get_tree().process_frame
	await get_tree().process_frame
	for i in range(built.size()):
		_animate_row(built[i], float(i) * ROW_STAGGER)

func dismiss() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(_root, "modulate:a", 0.0, 0.15)
	_tw.tween_callback(func() -> void: visible = false)

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
	var name_l: Label = row.get_node("PName")
	name_l.text = str(r.get("tag", "P%d" % int(r["pn"])))   # WK-10: "P3" (lobby label) / "CPU"
	name_l.add_theme_color_override("font_color", color)
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
	if delta != 0:
		delta_l.text = "%+d" % delta
		delta_l.add_theme_color_override("font_color", GOLD if delta > 0 else Color(0.75, 0.45, 0.4))
		delta_l.modulate.a = 0.0
	else:
		delta_l.text = ""
	return {"row": row, "fill": fill, "score_l": score_l, "delta_l": delta_l,
		"from": from_score, "to": int(r["score"]), "target": maxi(1, target), "delta": delta}

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
	if int(h["delta"]) != 0:
		var delta_l: Label = h["delta_l"]
		delta_l.pivot_offset = delta_l.size * 0.5
		delta_l.scale = Vector2(1.6, 1.6)
		tw.parallel().tween_property(delta_l, "modulate:a", 1.0, 0.15)
		tw.parallel().tween_property(delta_l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
