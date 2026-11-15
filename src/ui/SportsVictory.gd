extends CanvasLayer
## WK-111 (WK-98 SP-09) SPORTS END SCREEN — the Rocketball / Dropshot sibling of the Brawl VictoryScreen, built
## from the same parts so both modes read as one game: the scrim, the gold victory rays (team-tinted here), the
## goat bust slam + chocolate name ribbon, the MatchEndPanel tray with the row recipe, confetti (team palette),
## and the same REMATCH / CHANGE SETUP / QUIT TO MENU focus row behind a MenuInputGate (WK-11 / CC-10.2: fresh
## presses only, arm >= Tuning.end_screen_arm; an early accept fast-forwards the choreography and never arms).
## No hold-to-confirm: Pause is the only screen that holds (CC-7.1); here first B focuses QUIT, second B takes it.
##
## Layout (1080p): the WINNING TEAM's goats hop on the left over team-tinted rays, "RED WINS!" above them, an MVP
## chip on the MVP's bust; the right tray has the final score plate, a per-player stat table (winners first; the
## column leader in gold; zeros dimmed) and two match facts (longest rally, winning goal). Data comes from
## SportsMode.match_stats(); SportsHUD presents it at match end and relays the three signals.
##
## WK-35 Toybox panel kit B: the tray is the match flow's cream ToyPanel (no navy), headed by the final score as two
## team-colour halves (ToyIdPill fills, white type); rows are ToyRow wells — the winning team's in a team-tinted well,
## the MVP's in the gold ToyRowWinner well — with goat-colour identity pills (WK-34 F1), chocolate stat numbers and
## the column leader on a gold ToyStatLead pill (gold TEXT on cream would be ~1.1:1). Chocolate scrim; confetti and
## the focus-row pulse come from ToyKit (shared with the Brawl VictoryScreen).

signal rematch_pressed
signal setup_pressed
signal menu_pressed

const ToyKit := preload("res://src/ui/ToyKit.gd")
const FocusRow := preload("res://src/ui/FocusRow.gd")   # WK-14: one focus look (CC-5.1)
const GOLD := Color("#ffd23f")
const CREAM := Color(1.0, 0.97, 0.9)
const ARM_TIME := 1.1          # s from present() to the prompt row fading in (VictoryScreen's beat)
const ROW_STAGGER := 0.10
const COUNT_TIME := 0.45
const HOP_HEIGHT := 46.0       # px the celebrating busts jump
const RAYS_PATH := "res://assets/ui/victory_rays.png"
const ZERO_ALPHA := 0.4        # a 0 stat recedes so the real numbers pop
const BUST_REST_Y := 0.0       # the Bust's y inside its slot (scene offset_top)
const COL_MIN_W := 92.0        # stat column floor (px); a wider header widens its column
# 2V2: two busts side by side; 1V1: one bigger bust. [position, scale] of the slots by winner count.
const SLOT_LAYOUT := {
	1: [[Vector2(205.0, 250.0), 1.18]],
	2: [[Vector2(30.0, 290.0), 1.0], [Vector2(450.0, 290.0), 1.0]],
}

@onready var _root: Control = $Root
@onready var _scrim: ColorRect = $Root/Scrim
@onready var _fx: Node2D = $Root/FX
@onready var _rays: TextureRect = $Root/Rays
@onready var _team: Control = $Root/Team
@onready var _slot_tpl: Control = $Root/Team/Slot0
@onready var _winner_l: Label = $Root/WinnerL
@onready var _tray: PanelContainer = $Root/TrayArea/TrayCenter/Tray
@onready var _half_a: PanelContainer = $Root/TrayArea/TrayCenter/Tray/Box/ScoreC/ScoreLine/HalfA
@onready var _half_b: PanelContainer = $Root/TrayArea/TrayCenter/Tray/Box/ScoreC/ScoreLine/HalfB
@onready var _name_a: Label = $Root/TrayArea/TrayCenter/Tray/Box/ScoreC/ScoreLine/HalfA/Box/NameA
@onready var _score_a: Label = $Root/TrayArea/TrayCenter/Tray/Box/ScoreC/ScoreLine/HalfA/Box/ScoreA
@onready var _score_b: Label = $Root/TrayArea/TrayCenter/Tray/Box/ScoreC/ScoreLine/HalfB/Box/ScoreB
@onready var _name_b: Label = $Root/TrayArea/TrayCenter/Tray/Box/ScoreC/ScoreLine/HalfB/Box/NameB
@onready var _headers: Array = [
	$Root/TrayArea/TrayCenter/Tray/Box/Header/HeadBox/H0, $Root/TrayArea/TrayCenter/Tray/Box/Header/HeadBox/H1,
	$Root/TrayArea/TrayCenter/Tray/Box/Header/HeadBox/H2, $Root/TrayArea/TrayCenter/Tray/Box/Header/HeadBox/H3,
	$Root/TrayArea/TrayCenter/Tray/Box/Header/HeadBox/H4]
@onready var _rows_box: VBoxContainer = $Root/TrayArea/TrayCenter/Tray/Box/Rows
@onready var _row_tpl: PanelContainer = $Root/TrayArea/TrayCenter/Tray/Box/Rows/RowTemplate
@onready var _rally_p: PanelContainer = $Root/TrayArea/TrayCenter/Tray/Box/Facts/RallyP
@onready var _rally_l: Label = $Root/TrayArea/TrayCenter/Tray/Box/Facts/RallyP/RallyL
@onready var _wingoal_p: PanelContainer = $Root/TrayArea/TrayCenter/Tray/Box/Facts/WinGoalP
@onready var _wingoal_l: Label = $Root/TrayArea/TrayCenter/Tray/Box/Facts/WinGoalP/WinGoalL
@onready var _prompts: HBoxContainer = $Root/Prompts
@onready var _btns: Array = [$Root/Prompts/BtnRematch, $Root/Prompts/BtnSetup, $Root/Prompts/BtnQuit]

var _live := false
var _armed := false
var _t := 0.0
var _focus := 0
var _tweens: Array = []
var _slots: Array = []         # [{root, bust, shadow, name_l, mvp, rest_y}] for the winners on show
var _counts: Array = []        # [{label, to}] stat cells to count up (and land on fast-forward)
var _rows: Array = []          # built row PanelContainers (slide-in + fast-forward)
var _tray_rest_x := 0.0
var _pulse: Tween
var _ff_done := false
var _palette: Array = [GOLD]
var _col_w: Array = []         # per visible stat column width (px), header-driven
var _gate: MenuInputGate

func _ready() -> void:
	visible = false
	_gate = MenuInputGate.new()
	_gate.name = "InputGate"
	add_child(_gate)
	_gate.verb.connect(_on_verb)
	_gate.early.connect(_on_early)
	for i in range(_btns.size()):
		var idx := i
		(_btns[i] as Button).pressed.connect(func() -> void:
			if _armed and _gate.mouse_may_act():
				_activate(idx))
	_slot_tpl.visible = false

func is_live() -> bool:
	return _live

## QA: true once the button row accepts presses.
func is_armed() -> bool:
	return _armed

## data = SportsMode.match_stats(): {sport, scores:[a,b], win_team, team_names, team_colors, rows:[{idx, team, name,
## sub, color, skin, human, goals, assists, own_goals, saves, touches, power, rating}], mvp, longest_rally:{secs,
## touches}, winning_goal:{scorer_name, assist_name, own_goal}, goal_word}.
func present(data: Dictionary) -> void:
	visible = true
	_live = true
	_armed = false
	_ff_done = false
	_t = 0.0
	_focus = 0
	_gate.open(maxf(Tuning.end_screen_arm, ARM_TIME + 0.15))
	_kill_tweens()
	_counts.clear()
	_rows.clear()
	var win: int = clampi(int(data.get("win_team", 0)), 0, 1)
	var names: Array = data.get("team_names", ["RED", "BLUE"])
	var cols: Array = data.get("team_colors", [Color("#ff4b6a"), Color("#3fa9ff")])
	var tcol: Color = cols[win]
	var sport: String = str(data.get("sport", "soccer"))
	var rows: Array = data.get("rows", [])
	var mvp: int = int(data.get("mvp", -1))
	_palette = [tcol, tcol.lightened(0.35), tcol.lightened(0.6), GOLD, CREAM]
	# --- headline + team-tinted rays ---
	_winner_l.text = "%s WINS!" % str(names[win])
	_winner_l.add_theme_color_override("font_color", tcol.lerp(Color.WHITE, 0.08))
	if ResourceLoader.exists(RAYS_PATH):
		_rays.texture = load(RAYS_PATH)
	# team-colour rays via the scene's luminance-tint shader (a modulate turns gold x blue into olive)
	var rm := _rays.material as ShaderMaterial
	if rm != null:
		rm.set_shader_parameter("team", tcol)
	_rays.rotation = 0.0
	# --- the winning team's goats (MVP first) ---
	var winners: Array = []
	for r in rows:
		if int((r as Dictionary).get("team", -1)) == win:
			winners.append(r)
	winners.sort_custom(func(a, b) -> bool:
		var am: bool = int(a["idx"]) == mvp
		var bm: bool = int(b["idx"]) == mvp
		if am != bm:
			return am
		return int(a["rating"]) > int(b["rating"]))
	_build_slots(winners, mvp, tcol)
	# --- score header: [RED 6] — [4 BLUE] as two team-colour halves (WK-35: colour is the fill, white type) ---
	var sc: Array = data.get("scores", [0, 0])
	_name_a.text = str(names[0])
	_name_b.text = str(names[1])
	_score_a.text = str(int(sc[0]))
	_score_b.text = str(int(sc[1]))
	ToyKit.fill_panel(_half_a, cols[0])
	ToyKit.fill_panel(_half_b, cols[1])
	_score_a.add_theme_font_size_override("font_size", 72 if win == 0 else 56)
	_score_b.add_theme_font_size_override("font_size", 72 if win == 1 else 56)
	# --- stat table ---
	var team_size: int = maxi(winners.size(), rows.size() - winners.size())
	var columns: Array = _columns(sport, team_size, str(data.get("goal_word", "GOAL!")))
	_col_w.clear()
	for i in range(_headers.size()):
		var h: Label = _headers[i]
		h.visible = i < columns.size()
		if h.visible:
			h.text = str((columns[i] as Dictionary)["title"])
			# each column is as wide as its header (TOUCHES is wider than the cell floor), header + cells alike
			h.custom_minimum_size.x = 0.0
			_col_w.append(maxf(COL_MIN_W, ceilf(h.get_combined_minimum_size().x)))
			h.custom_minimum_size.x = float(_col_w[i])
	var leaders: Array = []
	for c in columns:
		var best := 0
		for r in rows:
			best = maxi(best, int((r as Dictionary).get(str((c as Dictionary)["key"]), 0)))
		leaders.append(best)
	for c in _rows_box.get_children():
		if c != _row_tpl:
			c.queue_free()
	var ordered: Array = rows.duplicate()
	ordered.sort_custom(func(a, b):
		var aw: int = int(int(a["team"]) == win)
		var bw: int = int(int(b["team"]) == win)
		if aw != bw:
			return aw > bw
		if int(a["rating"]) != int(b["rating"]):
			return int(a["rating"]) > int(b["rating"])
		return int(a["idx"]) < int(b["idx"]))
	for r in ordered:
		_rows.append(_build_row(r, columns, leaders, win, tcol, int(r["idx"]) == mvp))
	# --- match facts ---
	var rally: Dictionary = data.get("longest_rally", {})
	_rally_p.visible = not rally.is_empty()
	if _rally_p.visible:
		_rally_l.text = "LONGEST RALLY   %.1f s  ·  %d TOUCHES" % [float(rally.get("secs", 0.0)), int(rally.get("touches", 0))]
	var wg: Dictionary = data.get("winning_goal", {})
	var word: String = "WINNING POINT" if sport == "dropshot" else "WINNING GOAL"
	var who: String = str(wg.get("scorer_name", ""))
	if who == "":
		_wingoal_l.text = "%s   %s TEAM GOAL" % [word, str(names[win])] if sport != "dropshot" else "%s   %s" % [word, str(names[win])]
	elif bool(wg.get("own_goal", false)):
		_wingoal_l.text = "%s   OWN GOAL BY %s" % [word, who]
	else:
		var line := "%s   %s" % [word, who]
		if str(wg.get("assist_name", "")) != "":
			line += "  ·  ASSIST %s" % str(wg["assist_name"])
		_wingoal_l.text = line
	_wingoal_p.visible = not wg.is_empty()
	# --- start states ---
	_scrim.modulate.a = 0.0
	for n: Control in [_rays, _winner_l, _tray, _prompts]:
		n.modulate.a = 0.0
	_winner_l.scale = Vector2(0.3, 0.3)
	for s in _slots:
		var sl: Dictionary = s
		(sl["bust"] as Control).modulate.a = 0.0
		(sl["shadow"] as Control).modulate.a = 0.0
		(sl["bust"] as Control).position.y = float(sl["rest_y"]) + 300.0
		(sl["shadow"] as Control).position.y = float(sl["rest_y"]) + 310.0
		(sl["name_l"] as Control).modulate.a = 0.0
		(sl["name_l"] as Control).scale = Vector2(0.3, 0.3)
		(sl["mvp"] as Control).modulate.a = 0.0
	for row: Control in _rows:
		row.modulate.a = 0.0
	await get_tree().process_frame   # layout before slide offsets
	if not _live:
		return
	_tray_rest_x = _tray.position.x
	_tray.position.x = _tray_rest_x + 320.0
	for b: Button in _btns:
		b.pivot_offset = b.size * 0.5
	for s in _slots:
		var mv: Control = (s as Dictionary)["mvp"]
		mv.pivot_offset = mv.size * 0.5
	# --- choreography (VictoryScreen's beats; t=0 here is ~0.9 s after the winning goal) ---
	var sc_tw := _tw()
	sc_tw.tween_property(_scrim, "modulate:a", 1.0, 0.25)
	for i in range(_slots.size()):
		var sl: Dictionary = _slots[i]
		var bust: Control = sl["bust"]
		var shadow: Control = sl["shadow"]
		var rest: float = sl["rest_y"]
		var slam := _tw()
		slam.tween_interval(0.10 + 0.09 * float(i))
		if i == 0:
			slam.tween_callback(func() -> void:
				AudioManager.play_sfx("smash_heavy")
				AudioManager.play_sfx("goal_crowd")
				ToyKit.burst(_fx, Vector2(120, 100), 55.0, _palette)
				ToyKit.burst(_fx, Vector2(1800, 100), 125.0, _palette)
				_rays_spin())
		slam.tween_property(bust, "modulate:a", 1.0, 0.08)
		slam.parallel().tween_property(shadow, "modulate:a", 0.85, 0.08)
		slam.parallel().tween_property(bust, "position:y", rest, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		slam.parallel().tween_property(shadow, "position:y", rest + 10.0, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if i == 0:
			slam.parallel().tween_property(_rays, "modulate:a", 1.0, 0.35)
		slam.tween_property(bust, "scale", Vector2(1.08, 0.90), 0.08)
		slam.tween_property(bust, "scale", Vector2(0.96, 1.05), 0.06)
		slam.tween_property(bust, "scale", Vector2.ONE, 0.06)
		slam.tween_callback(_start_hop.bind(i))
		var nl := _tw()
		nl.tween_interval(0.40 + 0.09 * float(i))
		nl.tween_property(sl["name_l"], "modulate:a", 1.0, 0.10)
		nl.parallel().tween_property(sl["name_l"], "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var wl := _tw()
	wl.tween_interval(0.25)
	wl.tween_callback(func() -> void: AudioManager.play_sfx("ui_click"))
	wl.tween_property(_winner_l, "modulate:a", 1.0, 0.10)
	wl.parallel().tween_property(_winner_l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var tr := _tw()
	tr.tween_interval(0.50)
	tr.tween_property(_tray, "modulate:a", 1.0, 0.15)
	tr.parallel().tween_property(_tray, "position:x", _tray_rest_x, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tr.tween_callback(_animate_rows)
	# MVP stamp lands after the rows have counted up
	var mv_tw := _tw()
	mv_tw.tween_interval(0.80 + ROW_STAGGER * float(_rows.size()))
	mv_tw.tween_callback(_stamp_mvp)
	var pr := _tw()
	pr.tween_interval(ARM_TIME)
	pr.tween_property(_prompts, "modulate:a", 1.0, 0.15)
	ToyKit.drizzle(_fx, _palette, 30)

# ------------------------------------------------------------------ build

## The stat columns for this sport (<= 5, matching the scene's H0..H4 / S0..S4). 1V1 drops ASSISTS (no teammate).
func _columns(sport: String, team_size: int, goal_word: String) -> Array:
	var out: Array = []
	if sport == "dropshot":
		out.append({"key": "goals", "title": "POINTS"})
		if team_size > 1:
			out.append({"key": "assists", "title": "ASSISTS"})
		out.append({"key": "power", "title": "SPIKES"})
		out.append({"key": "touches", "title": "TOUCHES"})
		return out
	out.append({"key": "goals", "title": "GOALS" if goal_word == "GOAL!" else "POINTS"})
	if team_size > 1:
		out.append({"key": "assists", "title": "ASSISTS"})
	out.append({"key": "saves", "title": "SAVES"})
	out.append({"key": "touches", "title": "TOUCHES"})
	out.append({"key": "own_goals", "title": "OWN\nGOALS"})
	return out

func _build_slots(winners: Array, mvp: int, tcol: Color) -> void:
	for s in _slots:
		var root: Control = (s as Dictionary)["root"]
		if root != _slot_tpl:
			root.queue_free()
	_slots.clear()
	_slot_tpl.visible = false
	var n: int = clampi(winners.size(), 1, 2)
	var layout: Array = SLOT_LAYOUT[n]
	for i in range(mini(winners.size(), 2)):
		var w: Dictionary = winners[i]
		var root: Control = _slot_tpl if i == 0 else _slot_tpl.duplicate()
		if i > 0:
			_team.add_child(root)
		root.visible = true
		root.position = layout[i][0]
		root.scale = Vector2.ONE * float(layout[i][1])
		var bust: TextureRect = root.get_node("Bust")
		var shadow: TextureRect = root.get_node("Shadow")
		var tex_path := "res://assets/characters/bouncer_%s_idle.png" % str(w.get("skin", "pink"))
		if ResourceLoader.exists(tex_path):
			var tex: Texture2D = load(tex_path)
			bust.texture = tex
			shadow.texture = tex
		# the right-hand goat faces the left one (they celebrate together)
		bust.flip_h = i == 1
		shadow.flip_h = i == 1
		bust.scale = Vector2.ONE
		bust.position.y = BUST_REST_Y     # a dismissed screen may have frozen mid-hop
		shadow.position.y = BUST_REST_Y + 10.0
		var name_l: Control = root.get_node("NameL")
		var ribbon: PanelContainer = root.get_node("NameL/Ribbon")
		var nt: Label = root.get_node("NameL/Ribbon/Box/NameText")
		var st: Label = root.get_node("NameL/Ribbon/Box/SubText")
		var wcol: Color = w.get("color", tcol)
		# CC-8.5 NAME — WK-35: white on a goat-colour ribbon (kit F1 grammar)
		ToyKit.id_pill(ribbon, nt, str(w.get("name", "P1")), wcol)
		st.text = str(w.get("sub", ""))                            # + the small sub-tag
		st.visible = st.text != ""
		var mv: Control = root.get_node("Mvp")
		mv.visible = int(w.get("idx", -1)) == mvp
		_slots.append({"root": root, "bust": bust, "shadow": shadow, "name_l": name_l, "mvp": mv,
			"rest_y": BUST_REST_Y})

func _build_row(r: Dictionary, columns: Array, leaders: Array, win: int, tcol: Color, is_mvp: bool) -> Control:
	var row: PanelContainer = _row_tpl.duplicate()
	row.visible = true
	var won: bool = int(r.get("team", -1)) == win
	if is_mvp or won:
		row.theme_type_variation = &"ToyRowWinner"     # WK-35: the MVP's gold well (chocolate rim)
	_rows_box.add_child(row)   # in the tree first: the themed stylebox only resolves under Root's theme
	if won and not is_mvp:
		# the rest of the winning team: the same rimmed well, tinted in the team colour
		ToyKit.fill_panel(row, Color(tcol.r, tcol.g, tcol.b, 0.28))
	var head: TextureRect = row.get_node("RowBox/Head")
	var head_path := "res://assets/characters/bouncer_%s_idle.png" % str(r.get("skin", "pink"))
	if ResourceLoader.exists(head_path):
		head.texture = load(head_path)
	# WK-35: the WK-34 F1 identity pill (goat-colour fill, white type)
	ToyKit.id_pill(row.get_node("RowBox/NameBox/NamePill"), row.get_node("RowBox/NameBox/NamePill/PName"),
		str(r.get("name", "P1")), r.get("color", Color.WHITE))
	var sub_l: Label = row.get_node("RowBox/NameBox/PSub")
	sub_l.text = str(r.get("sub", ""))
	sub_l.visible = sub_l.text != ""
	var chip: Control = row.get_node("RowBox/MvpSlot/Chip")
	chip.modulate.a = 1.0 if is_mvp else 0.0     # keeps its width either way (column alignment)
	# the losing side reads a step back by its plain well (no tint); a modulate dim would grey the cream
	for i in range(5):
		var cell: Label = row.get_node("RowBox/S%d" % i)
		cell.visible = i < columns.size()
		if not cell.visible:
			continue
		cell.custom_minimum_size.x = float(_col_w[i])
		var v: int = int(r.get(str((columns[i] as Dictionary)["key"]), 0))
		cell.text = "0"
		if v == 0:
			cell.modulate.a = ZERO_ALPHA
		elif v == int(leaders[i]):
			cell.theme_type_variation = &"ToyStatLead"   # WK-35: the column leader on a gold pill
		_counts.append({"label": cell, "to": v, "row": _rows.size()})
	return row

# ------------------------------------------------------------------ animation pieces

func _animate_rows() -> void:
	# rows fade in one by one (no slide: a counting label re-sorts the VBox and would snap a sliding row)
	for i in range(_rows.size()):
		var row: Control = _rows[i]
		var tw := _tw()
		tw.tween_interval(float(i) * ROW_STAGGER + 0.01)
		tw.tween_property(row, "modulate:a", 1.0, 0.14)
	for c in _counts:
		var cd: Dictionary = c
		var lbl: Label = cd["label"]
		var to_v: int = int(cd["to"])
		if to_v == 0:
			continue
		var tw := _tw()
		tw.tween_interval(float(int(cd["row"])) * ROW_STAGGER + 0.08)
		tw.tween_method(func(v: float) -> void: lbl.text = str(int(round(v))), 0.0, float(to_v), COUNT_TIME)

func _stamp_mvp() -> void:
	for s in _slots:
		var mv: Control = (s as Dictionary)["mvp"]
		if not mv.visible:
			continue
		AudioManager.play_sfx("smash")
		mv.scale = Vector2(2.2, 2.2)
		var tw := _tw()
		tw.tween_property(mv, "modulate:a", 1.0, 0.06)
		tw.parallel().tween_property(mv, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## The celebrating hop: jump, land with a squash, breathe, repeat (the two goats are out of phase).
func _start_hop(i: int) -> void:
	if not _live or i >= _slots.size():
		return
	var sl: Dictionary = _slots[i]
	var bust: Control = sl["bust"]
	var shadow: Control = sl["shadow"]
	var rest: float = sl["rest_y"]
	var tw := _tw()
	tw.set_loops()
	tw.tween_interval(0.25 + 0.3 * float(i))
	tw.tween_property(bust, "scale", Vector2(1.06, 0.92), 0.08)
	tw.tween_property(bust, "position:y", rest - HOP_HEIGHT, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(bust, "scale", Vector2(0.96, 1.05), 0.12)
	tw.parallel().tween_property(shadow, "position:y", rest + 10.0 - HOP_HEIGHT, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(bust, "position:y", rest, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(shadow, "position:y", rest + 10.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(bust, "scale", Vector2.ONE, 0.22)
	tw.tween_property(bust, "scale", Vector2(1.08, 0.9), 0.06)
	tw.tween_property(bust, "scale", Vector2.ONE, 0.10)
	tw.tween_interval(0.35 - 0.3 * float(i))

func _rays_spin() -> void:
	if _rays.rotation != 0.0:
		return
	var tw := _tw()
	tw.set_loops()
	tw.tween_property(_rays, "rotation", TAU, 24.0).from(0.0)

func _tw() -> Tween:
	var t := create_tween()
	_tweens.append(t)
	return t

func _kill_tweens() -> void:
	for tw in _tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	_tweens.clear()

# ------------------------------------------------------------------ input (VictoryScreen model)

func _process(delta: float) -> void:
	if not _live:
		return
	_t += delta
	if not _armed and _gate.is_armed():
		_arm()

## Pre-arm press (fresh, joined device): accept FAST-FORWARDS the choreography — it never arms the row.
func _on_early(v: String, _key: String) -> void:
	if _live and not _armed and v == "accept" and _t > 0.05 and not _ff_done:
		_fast_forward()

func _on_verb(v: String, _key: String) -> void:
	if not _live or not _armed:
		return
	match v:
		"left":
			_set_focus((_focus + _btns.size() - 1) % _btns.size())
		"right":
			_set_focus((_focus + 1) % _btns.size())
		"accept":
			_activate(_focus)
		"back":
			# first back = focus the safe QUIT option; second back = take it (CC-10.1)
			if _focus == _btns.size() - 1:
				_activate(_focus)
			else:
				_set_focus(_btns.size() - 1)

func _arm() -> void:
	_armed = true
	_set_focus(0)

func _set_focus(i: int) -> void:
	_focus = i
	_pulse = FocusRow.row(self, _btns, i, _pulse)

## One activation per screen life: a second accept in the same frame (two pads) can't double-fire.
func _activate(i: int) -> void:
	if not _armed:
		return
	_armed = false
	AudioManager.play_sfx("ui_click")
	match i:
		0: rematch_pressed.emit()
		1: setup_pressed.emit()
		2: menu_pressed.emit()

## Accept during the choreography: land every element instantly (never a black cut). WK-11: it does NOT arm the
## row — the gate still waits (>= Tuning.end_screen_ff_rearm after this, >= end_screen_arm overall).
func _fast_forward() -> void:
	_ff_done = true
	_kill_tweens()
	_scrim.modulate.a = 1.0
	for n: Control in [_rays, _winner_l, _tray, _prompts]:
		n.modulate.a = 1.0
	_winner_l.scale = Vector2.ONE
	_tray.position.x = _tray_rest_x
	for s in _slots:
		var sl: Dictionary = s
		(sl["bust"] as Control).modulate.a = 1.0
		(sl["shadow"] as Control).modulate.a = 0.85
		(sl["bust"] as Control).position.y = float(sl["rest_y"])
		(sl["shadow"] as Control).position.y = float(sl["rest_y"]) + 10.0
		(sl["bust"] as Control).scale = Vector2.ONE
		(sl["name_l"] as Control).modulate.a = 1.0
		(sl["name_l"] as Control).scale = Vector2.ONE
		(sl["mvp"] as Control).modulate.a = 1.0
		(sl["mvp"] as Control).scale = Vector2.ONE
	for row: Control in _rows:
		row.modulate.a = 1.0
	for c in _counts:
		((c as Dictionary)["label"] as Label).text = str(int((c as Dictionary)["to"]))
	_rays.rotation = 0.0
	_rays_spin()
	for i in range(_slots.size()):
		_start_hop(i)
	_gate.delay_arm(Tuning.end_screen_ff_rearm)

func dismiss() -> void:
	_live = false
	_armed = false
	_gate.close()
	_kill_tweens()
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	for c in _fx.get_children():
		c.queue_free()
	visible = false
