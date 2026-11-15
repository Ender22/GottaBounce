extends Panel
## One corner HUD card: identity (head + NAME + small sub-tag, CC-8.5) + fuel gauge. Glossy Toybox treatment: pastel card
## body tinted to the player skin, vivid fuel in the full skin color, dark-chocolate outlines from
## assets/ui/theme.tres. Dead-this-round = dim + skull over the head icon.
## SCORE PIPS REMOVED (owner 2026-07-16): the score display is now the between-stage ScoreScreen
## (Duck Game/TowerFall pattern) — combat carries no persistent score readout.
## WK-31 (R-06): a flame glyph labels the fuel gauge; set_danger() shows how close the goat is to being KO'd (its transient
## damage_level 0/1/2: a HURT! / DANGER! sticker with a draining heal bar, thicker border, crimson wash, a kick on every
## qualifying hit and a tremble at Lv2 — word + thickness + motion, never hue alone); set_stocks() shows a row of stock
## heads on a cream tab when RULES LIVES > 1. Both hang off the card's centre-facing edge (set_corner). Only MatchHUD
## (BRAWL) calls them; TrialsHUD's cards stay exactly as before.

const FUEL_PAD := 3.0           # fill inset inside the gauge background

var _color := Color.WHITE
var _fuel_was_full := true
var _was_locked := false

@onready var _name_label: Label = $Margin/VBox/IdentityRow/NameBox/NameLabel
@onready var _sub_label: Label = $Margin/VBox/IdentityRow/NameBox/SubLabel
@onready var _head: TextureRect = $Margin/VBox/IdentityRow/HeadSlot/Head
@onready var _skull: Control = $Margin/VBox/IdentityRow/HeadSlot/Skull
@onready var _fuel_bg: Panel = $Margin/VBox/FuelRow/FuelSlot/FuelBG
@onready var _fuel_fill: Panel = $Margin/VBox/FuelRow/FuelSlot/FuelFill
@onready var _fuel_icon: Control = $Margin/VBox/FuelRow/FuelIcon   # WK-31
@onready var _pu_icon: TextureRect = $Margin/VBox/IdentityRow/PowerupSlot
# WK-37 ghost head + puff ring + "SHH": its own scene, instanced into the head slot on the FIRST set_ghost(true) — with
# GHOSTS OFF it never exists, so the card's node tree is exactly the pre-WK-37 one (spec T8).
const GHOST_BADGE := preload("res://scenes/ui/GhostCardBadge.tscn")
var _badge: Control = null
var _ghost_icon: TextureRect = null
var _ghost_ring: Control = null
var _shh: Label = null
# WK-37: the ghost head + ring sit on a DIMMED card (modulate 0.55); counter-brighten them so the "you can still play"
# cue reads at full strength (brief R8: "reads as a ghost on a dimmed card").
const GHOST_LIFT := Color(1.75, 1.75, 1.75, 1.25)
var _ghost_on := false
var _is_dead := false

var _pu_id := ""

# --- WK-31 danger + stocks ---
@onready var _flush: Panel = $DangerFlush
@onready var _stock_tab: PanelContainer = $StockTab
@onready var _stock_more: Label = $StockTab/Stocks/More
@onready var _tag: PanelContainer = $DangerTag
@onready var _tag_word: Label = $DangerTag/VBox/Word
@onready var _heal_bar: Panel = $DangerTag/VBox/HealBar
@onready var _heal_fill: Panel = $DangerTag/VBox/HealBar/HealFill
var _stock_icons: Array = []        # TextureRect x3
var _corner_top := true             # the card sits in a top corner (tabs hang below it)
var _corner_left := true            # the card sits in a left corner (stocks on the left, sticker toward the centre)
var _card_sb: StyleBoxFlat = null   # this card's own copy of the PlayerCard stylebox (border reacts to danger)
var _tag_sb: StyleBoxFlat = null
var _tab_sb: StyleBoxFlat = null
var _heal_sb: StyleBoxFlat = null
var _danger_lv := 0
var _heal_frac := 0.0
var _danger_t := 0.0                # s since the current level began (wash phase)
var _kick_t := 0.0                  # s left on the hit kick
var _kick_sign := 1.0
var _stock_total := 0
var _stock_left := -1
var _tag_tw: Tween

# --- WK-99 super-ready notch + CD3-04b billed-chunk flash (fuel gauge) ---
@onready var _notch: Panel = $Margin/VBox/FuelRow/FuelSlot/SuperNotch   # WK-99
@onready var _bill_chunk: Panel = $Margin/VBox/FuelRow/FuelSlot/BillChunk   # WK-99
var _notch_lit := -1                # WK-99: -1 unknown (first set_fuel never pops), 0 unlit, 1 lit
var _notch_tw: Tween                # WK-99
var _bill_grace_prev := 0.0         # WK-99: last polled refund-grace of the goat's last bill (a jump UP = a new bill)
var _bill_tw: Tween                 # WK-99
var _fuel_r := 0.0                  # WK-99: the ratio the gauge shows now (the chunk starts at the fill's end)
# --- WK-173 sticker / stock tab dim when a goat is under them ---
var _tab_dim := {}                  # WK-173: Control instance id -> 0..1 dim

## `label` (WK-10/WK-88): the fighter's NAME (PartyMatch.player_name: "P3" / "VEX"). "" = legacy slot number
## (idx + 1) for any caller that does not know the roster (set_label can update it later).
func setup(idx: int, color: Color, skin: String, label: String = "") -> void:
	_color = color
	_name_label.text = label if label != "" else "P%d" % (idx + 1)
	# card body: player color knocked toward white so the vivid pips/fuel pop against it
	var card_sb: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
	var pastel := color.lerp(Color.WHITE, 0.58)
	pastel.a = 0.95
	card_sb.bg_color = pastel
	add_theme_stylebox_override("panel", card_sb)
	_card_sb = card_sb   # WK-31
	var head_path := "res://assets/characters/bouncer_%s_idle.png" % skin
	if ResourceLoader.exists(head_path):
		_head.texture = load(head_path)
	_fuel_fill.self_modulate = color
	# WK-31: flame label on the gauge; stock heads use this goat's own head (Smash stock icons); fresh danger/stock state
	_fuel_icon.visible = Tuning.hud_fuel_icon
	_stock_icons = [$StockTab/Stocks/Stock0, $StockTab/Stocks/Stock1, $StockTab/Stocks/Stock2]
	for s in _stock_icons:
		(s as TextureRect).texture = _head.texture
		(s as TextureRect).custom_minimum_size = Vector2.ONE * Tuning.hud_stock_icon_px
	_tag_sb = (_tag.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	_tag.add_theme_stylebox_override("panel", _tag_sb)
	_tab_sb = (_stock_tab.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	_stock_tab.add_theme_stylebox_override("panel", _tab_sb)
	_heal_sb = (_heal_fill.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	_heal_fill.add_theme_stylebox_override("panel", _heal_sb)
	_flush.add_theme_stylebox_override("panel", (_flush.get_theme_stylebox("panel") as StyleBoxFlat).duplicate())
	_danger_lv = 0
	_stock_total = 0
	_stock_left = -1
	_apply_danger_look(false)
	_stock_tab.visible = false

## WK-88 (CC-8.5): NAME on the card ("P3" / "VEX") + the small sub-tag under it (goat name / "CPU"), set by
## the HUD from PartyMatch.player_names() / player_subtags(). "" sub = name only.
func set_label(text: String, sub: String = "") -> void:
	if text != "":
		_name_label.text = text
	_sub_label.text = sub
	_sub_label.visible = sub != ""

## Fuel gauge, mapped 0..1 (GDD §10 glanceable). Flashes bright when a full tank is banked —
## the super-boost-ready tell. `locked` = Unlimited Boost: the gauge glows solid (spec 3.2).
func set_fuel(r: float, locked := false) -> void:
	r = clampf(r, 0.0, 1.0)
	var w: float = maxf(0.0, _fuel_bg.size.x - FUEL_PAD * 2.0)
	_fuel_fill.size = Vector2(w * r, maxf(0.0, _fuel_bg.size.y - FUEL_PAD * 2.0))
	_fuel_fill.visible = r > 0.02
	_fuel_r = r   # WK-99
	_wk99_notch(r, locked)   # WK-99
	if locked:
		_fuel_fill.self_modulate = Color(1.2, 2.4, 2.8)   # solid cyan glow
		_was_locked = true
		_fuel_was_full = true
		return
	if _was_locked:
		_was_locked = false
		_fuel_fill.self_modulate = _color   # drop the glow the moment the pin ends
	_fuel_icon.set("dim", r <= 0.02)   # WK-31: an empty tank greys the flame
	var full := r >= 0.999
	if full and not _fuel_was_full:
		_fuel_fill.self_modulate = Color(2.2, 2.2, 2.2)
		var tw := create_tween()
		tw.tween_property(_fuel_fill, "self_modulate", _color, 0.35)
	_fuel_was_full = full

## WK-99: the super-ready notch at super_boost_min_fuel / fuel_max. LIT = a tall cream tick that pokes past the gauge (a super
## can fire), UNLIT = a short muted tick flush inside the track (size + luminance, never hue alone). Crossing UP pops it.
func _wk99_notch(r: float, locked: bool) -> void:  # WK-99
	if _notch == null:  # WK-99
		return  # WK-99
	_notch.visible = Tuning.wk99_notch_on and _fuel_bg.size.x > 0.0  # WK-99
	if not _notch.visible:  # WK-99
		return  # WK-99
	var thr: float = clampf(Tuning.super_boost_min_fuel / maxf(Tuning.fuel_max, 0.001), 0.0, 1.0)  # WK-99
	# a hair under the line still counts (fuel is a float: 9.999 shows as 10 on the bar)  # WK-99
	var lit: int = 1 if locked or r >= thr - 0.0005 else 0  # WK-99
	var w: float = maxf(0.0, _fuel_bg.size.x - FUEL_PAD * 2.0)  # WK-99
	var nw: float = Tuning.wk99_notch_w  # WK-99
	var gh: float = _fuel_bg.size.y  # WK-99
	var h: float = gh + Tuning.wk99_notch_overhang * 2.0 if lit == 1 else maxf(4.0, gh - FUEL_PAD * 2.0 + 2.0)  # WK-99
	_notch.size = Vector2(nw, h)  # WK-99
	_notch.position = Vector2(FUEL_PAD + w * thr - nw * 0.5, (gh - h) * 0.5)  # WK-99
	_notch.pivot_offset = _notch.size * 0.5  # WK-99
	if lit == _notch_lit:  # WK-99
		return  # WK-99
	var was: int = _notch_lit  # WK-99
	_notch_lit = lit  # WK-99
	_notch.self_modulate = Color.WHITE if lit == 1 else Tuning.wk99_notch_unlit  # WK-99
	if _notch_tw != null and _notch_tw.is_valid():  # WK-99
		_notch_tw.kill()  # WK-99
	_notch.scale = Vector2.ONE  # WK-99
	if lit == 1 and was == 0 and Tuning.wk99_notch_pop_s > 0.0:  # WK-99: the tank just crossed UP -> "super ready" pop
		_notch.scale = Vector2.ONE * Tuning.wk99_notch_pop_scale  # WK-99
		_notch_tw = create_tween()  # WK-99
		_notch_tw.tween_property(_notch, "scale", Vector2.ONE, Tuning.wk99_notch_pop_s).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)  # WK-99

## WK-99 (CD3-04b): polled by MatchHUD with Player.relight_bill_state() (x = fuel the last bill took, y = refund grace left).
## A grace that jumps UP is a new billed re-light: the slice it took pops white just past the fill's end, holds, and drops
## off the gauge while fading ("tapping costs fuel" taught by the HUD).
func set_relight_bill(paid: float, grace_left: float) -> void:  # WK-99
	var fresh: bool = grace_left > _bill_grace_prev + 0.001 and paid > 0.0  # WK-99
	_bill_grace_prev = grace_left  # WK-99
	if fresh and Tuning.wk99_bill_flash_on and not _is_dead:  # WK-99
		flash_bill(paid / maxf(Tuning.fuel_max, 0.001))  # WK-99

## WK-99: show the billed chunk (`frac` of the tank) at the fill's current end. Public so QA can fire it from eval.
func flash_bill(frac: float) -> void:  # WK-99
	if _bill_chunk == null or _fuel_bg.size.x <= 0.0:  # WK-99
		return  # WK-99
	var w: float = maxf(0.0, _fuel_bg.size.x - FUEL_PAD * 2.0)  # WK-99
	var cw: float = maxf(Tuning.wk99_bill_min_px, w * clampf(frac, 0.0, 1.0))  # WK-99
	var x0: float = minf(FUEL_PAD + w * _fuel_r, _fuel_bg.size.x - cw)  # WK-99: never past the gauge's end
	var ov: float = Tuning.wk99_bill_overhang  # WK-99
	var h: float = _fuel_bg.size.y - FUEL_PAD * 2.0 + ov * 2.0  # WK-99
	var y0: float = FUEL_PAD - ov  # WK-99
	_bill_chunk.size = Vector2(cw, h)  # WK-99
	_bill_chunk.position = Vector2(x0, y0)  # WK-99
	_bill_chunk.pivot_offset = _bill_chunk.size * 0.5  # WK-99
	_bill_chunk.modulate = Color(1, 1, 1, 1)  # WK-99
	_bill_chunk.self_modulate = Color.WHITE  # WK-99: white flash first, then it turns back into a piece of THIS goat's fuel
	_bill_chunk.scale = Vector2(1.35, 1.35)  # WK-99
	_bill_chunk.rotation = 0.0  # WK-99
	_bill_chunk.visible = true  # WK-99
	if _bill_tw != null and _bill_tw.is_valid():  # WK-99
		_bill_tw.kill()  # WK-99
	_bill_tw = create_tween()  # WK-99
	_bill_tw.tween_property(_bill_chunk, "scale", Vector2.ONE, Tuning.wk99_bill_hold_s).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)  # WK-99
	var ds: float = maxf(0.05, Tuning.wk99_bill_drop_s)  # WK-99
	_bill_tw.tween_property(_bill_chunk, "position:y", y0 + Tuning.wk99_bill_drop_px, ds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)  # WK-99
	_bill_tw.parallel().tween_property(_bill_chunk, "rotation", deg_to_rad(18.0), ds)  # WK-99
	_bill_tw.parallel().tween_property(_bill_chunk, "self_modulate", _color, ds * 0.4)  # WK-99: not mistaken for the notch
	_bill_tw.parallel().tween_property(_bill_chunk, "modulate:a", 0.0, ds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)  # WK-99
	_bill_tw.tween_callback(_bill_chunk.hide)  # WK-99

## QA (gbplay eval): notch + chunk state.
func wk99_state() -> Dictionary:  # WK-99
	return {"notch_lit": _notch_lit, "notch_visible": _notch.visible, "notch_rect": [_notch.position.x, _notch.position.y,  # WK-99
		_notch.size.x, _notch.size.y], "fuel_r": snappedf(_fuel_r, 0.001), "bill_visible": _bill_chunk.visible,  # WK-99
		"bill_rect": [_bill_chunk.position.x, _bill_chunk.position.y, _bill_chunk.size.x, _bill_chunk.size.y]}  # WK-99

## Held-powerup icon slot (spec §2: pickup shows on the corner HUD card).
func set_powerup(id: String) -> void:
	if id == _pu_id:
		return
	_pu_id = id
	if id == "":
		_pu_icon.visible = false
		return
	var path := "res://assets/powerups/icon_%s.png" % id
	if ResourceLoader.exists(path):
		_pu_icon.texture = load(path)
	_pu_icon.visible = true
	_pu_icon.pivot_offset = _pu_icon.custom_minimum_size * 0.5
	_pu_icon.scale = Vector2(1.5, 1.5)
	var tw := create_tween()
	tw.tween_property(_pu_icon, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Score-display API kept as NO-OPS (MatchHUD still calls these on every kill/reset): the pips are
## gone (owner 2026-07-16) — the between-stage ScoreScreen is the score display now.
func set_score(_n: int) -> void:
	pass

func animate_score(_n: int) -> void:
	pass

## Dead this round: dim to ~40% + skull over the head icon until next ROUND_INTRO (spec §3).
func set_dead(dead: bool) -> void:
	_is_dead = dead
	_skull.visible = dead
	modulate = Color(0.55, 0.55, 0.55, 0.8) if dead else Color.WHITE
	if not dead:
		set_ghost(false, false)
	elif _danger_lv != 0:   # WK-31: an eliminated card drops the danger sticker + motion (the skull says it all)
		_danger_lv = 0
		_apply_danger_look(false)
	_refresh_stock_tab()   # WK-31

## WK-37 ghost goats: the skull becomes a ghost head (+ the puff cooldown ring when `ring`, i.e. GHOSTS ON; BAA ONLY has
## no ring). Only ever called while dead; set_dead(false) clears it.
func set_ghost(on: bool, ring: bool) -> void:
	if _badge == null:
		if not on:
			_ghost_on = false
			_skull.visible = _is_dead
			return
		_badge = GHOST_BADGE.instantiate()
		$Margin/VBox/IdentityRow/HeadSlot.add_child(_badge)
		_ghost_icon = _badge.get_node("Ghost")
		_ghost_ring = _badge.get_node("GhostRing")
		_shh = _badge.get_node("Shh")
	_ghost_on = on
	_ghost_icon.visible = on
	_ghost_icon.self_modulate = GHOST_LIFT
	_ghost_ring.visible = on and ring
	_ghost_ring.self_modulate = GHOST_LIFT
	_shh.visible = false
	_shh.self_modulate = GHOST_LIFT
	_skull.visible = _is_dead and not on
	if on:
		_ghost_icon.pivot_offset = _ghost_icon.size * 0.5
		_ghost_icon.scale = Vector2(0.4, 0.4)
		var tw := create_tween()
		tw.tween_property(_ghost_icon, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## WK-37: ring fill (1 = puff ready), hushed (grey + "SHH"), spent (stage cap used).
func set_ghost_ring(frac: float, hushed: bool, spent: bool) -> void:
	if not _ghost_on:
		return
	if _ghost_ring.visible:
		_ghost_ring.call("set_state", frac, hushed, spent, _color)
		if hushed and not _shh.visible:
			_place_shh()
		_shh.visible = hushed

## WK-146 (UX4-23): the "SHH" stamp sits UNDER the ghost head, centred on the fuel row (meaningless on a dead card), so
## it never covers the NAME / sub-tag beside the head (it used to straddle the head and the start of the name).
func _place_shh() -> void:
	var slot: Control = $Margin/VBox/IdentityRow/HeadSlot
	var fuel: Control = $Margin/VBox/FuelRow   # WK-31: the gauge now sits in a row beside the flame glyph
	var sz: Vector2 = _shh.get_combined_minimum_size()
	_shh.size = sz
	_shh.pivot_offset = sz * 0.5
	var fy: float = fuel.position.y + fuel.size.y * 0.5 - slot.position.y   # fuel-row centre in head-slot space (same VBox)
	var row_y: float = (slot.get_parent() as Control).position.y
	_shh.position = Vector2(slot.size.x * 0.5 - sz.x * 0.5, fy - row_y - sz.y * 0.5)
	_shh.z_index = 1   # the head slot comes before the fuel row in the tree: without this the gauge draws over the stamp

# ------------------------------------------------------------------ WK-31 danger level + stocks

## Which corner the card sits in (MatchHUD: 0 TL, 1 TR, 2 BL, 3 BR). The stock tab and the danger sticker hang off the
## centre-facing edge (below a top card, above a bottom one); stocks hug the screen edge, the sticker the centre side.
func set_corner(top: bool, left: bool) -> void:
	_corner_top = top
	_corner_left = left
	_layout_tabs()

## Danger = the goat's transient damage_level (0 healthy / 1 / 2, Player.gd v3 §12) and heal_frac = heal time left /
## dmg_heal_time (1 = just hit, 0 = about to heal back to 0). Polled every frame by MatchHUD; cheap when nothing changes.
func set_danger(level: int, heal_frac: float) -> void:
	if not Tuning.hud_danger_on or _is_dead:
		level = 0
	level = clampi(level, 0, 2)
	if level != _danger_lv:
		var rising := level > _danger_lv
		_danger_lv = level
		_apply_danger_look(rising)
	elif level > 0 and heal_frac > _heal_frac + Tuning.hud_danger_rehit_frac:
		_kick()   # a qualifying re-hit at the same level re-armed the heal timer
	_heal_frac = clampf(heal_frac, 0.0, 1.0)
	if _danger_lv > 0 and Tuning.hud_danger_heal_bar:
		var w: float = _heal_bar.size.x
		_heal_fill.size = Vector2(maxf(0.0, w * _heal_frac), _heal_bar.size.y)
		_heal_fill.visible = _heal_frac > 0.01

## Stocks: `total` = RULES LIVES (0 = this match shows no stock row), `left` = lives_left this stage (incl. the current one).
func set_stocks(total: int, left: int) -> void:
	if total < Tuning.hud_stocks_min_lives or total > Tuning.hud_stocks_max_lives:
		total = 0
	left = clampi(left, 0, maxi(total, 0))
	if total == _stock_total and left == _stock_left:
		return
	var lost_one: bool = total == _stock_total and _stock_left >= 0 and left < _stock_left
	var old_left := _stock_left
	_stock_total = total
	_stock_left = left
	var shown: int = mini(total, _stock_icons.size())
	var icon_px: float = Tuning.hud_stock_icon_px
	for k in range(_stock_icons.size()):
		var ic: TextureRect = _stock_icons[k]
		ic.visible = k < shown
		ic.scale = Vector2.ONE
		ic.pivot_offset = Vector2.ONE * icon_px * 0.5
		# live heads first from the screen edge; lost ones become dark silhouettes (shape + luminance, not hue)
		var slot: int = k if _corner_left else shown - 1 - k
		ic.self_modulate = Color.WHITE if slot < left else _lost_color()
	_stock_more.visible = total > _stock_icons.size()
	_stock_more.text = "x%d" % left
	if lost_one and old_left - 1 >= 0 and old_left - 1 < shown:
		var gone: int = old_left - 1 if _corner_left else shown - old_left
		_pop_lost(_stock_icons[gone])
	_refresh_stock_tab()

## The rect this card occupies on screen INCLUDING a visible stock tab / danger sticker (pip + legend avoidance).
func hud_rect() -> Rect2:
	var r: Rect2 = get_global_rect()
	for n in [_stock_tab, _tag]:
		var c: Control = n
		if c != null and c.visible:
			r = r.merge(c.get_global_rect())
	return r

## WK-173 (CD5-06): the HURT!/DANGER! sticker and the stock tab hang off the card into the playfield, and the HUD layer draws
## over the world, so a goat flying under one was hidden. Each fades to wk173_tab_dim_alpha while any rect in `goat_rects`
## (screen px; MatchHUD passes every living goat's body) overlaps it, with hysteresis, and comes back when it leaves (the
## WK-156 legend-chip rule). The card itself never dims. The tabs' own alpha is only ever set here.
func wk173_dim_tabs(goat_rects: Array, delta: float) -> void:  # WK-173
	var step: float = delta / maxf(Tuning.wk173_tab_dim_fade, 0.01)  # WK-173
	for n in [_tag, _stock_tab]:  # WK-173
		var c: Control = n  # WK-173
		if c == null:  # WK-173
			continue  # WK-173
		var id: int = c.get_instance_id()  # WK-173
		var d: float = float(_tab_dim.get(id, 0.0))  # WK-173
		var hit := false  # WK-173
		if Tuning.wk173_tab_goat_dim and c.visible:  # WK-173
			var pad: float = Tuning.wk173_tab_pad_px + (Tuning.wk173_tab_hysteresis_px if d > 0.5 else 0.0)  # WK-173
			var r: Rect2 = c.get_global_rect().grow(pad)  # WK-173
			for g in goat_rects:  # WK-173
				if r.intersects(g as Rect2):  # WK-173
					hit = true  # WK-173
					break  # WK-173
		d = move_toward(d, 1.0 if hit else 0.0, step) if c.visible else 0.0  # WK-173: a hidden tab re-shows undimmed
		_tab_dim[id] = d  # WK-173
		c.modulate.a = lerpf(1.0, Tuning.wk173_tab_dim_alpha, d)  # WK-173

## WK-173: QA readout of the tab dims (0 = full, 1 = dimmed).
func wk173_state() -> Dictionary:  # WK-173
	return {"tag_dim": snappedf(float(_tab_dim.get(_tag.get_instance_id(), 0.0)), 0.01), "tag_alpha": snappedf(_tag.modulate.a, 0.01),  # WK-173
		"tab_dim": snappedf(float(_tab_dim.get(_stock_tab.get_instance_id(), 0.0)), 0.01), "tag_visible": _tag.visible}  # WK-173

## WK-173 (CD5-06): where a KO credit chip of size `chip_px` (already at its landing scale) should land on this card: centred on
## the identity row, with its left edge clear of the NAME / sub-tag text (it used to land on the card centre = on the name). It
## may overhang the card's far end; KOCreditPop keeps it on screen.
func wk173_credit_target(chip_px: Vector2) -> Vector2:  # WK-173
	var cr: Rect2 = get_global_rect()  # WK-173
	if not Tuning.wk173_chip_clear_name:  # WK-173
		return cr.get_center()  # WK-173
	var text_w: float = _name_label.get_minimum_size().x  # WK-173: the text's width, not the label box
	if _sub_label.visible:  # WK-173
		text_w = maxf(text_w, _sub_label.get_minimum_size().x)  # WK-173
	var name_r: float = _name_label.get_global_rect().position.x + text_w  # WK-173
	var x: float = maxf(name_r + Tuning.wk173_chip_name_gap + chip_px.x * 0.5, cr.get_center().x)  # WK-173
	var row: Control = $Margin/VBox/IdentityRow  # WK-173
	return Vector2(x, row.get_global_rect().get_center().y)  # WK-173

## QA (gbplay eval): what the card is showing right now.
func wk31_state() -> Dictionary:
	return {"danger": _danger_lv, "word": _tag_word.text if _tag.visible else "", "heal": snappedf(_heal_frac, 0.01),
		"border_w": _card_sb.border_width_left if _card_sb != null else -1, "stocks": _stock_total,
		"stocks_left": _stock_left, "tab": _stock_tab.visible, "tag": _tag.visible, "rot_deg": snappedf(rad_to_deg(rotation), 0.1)}

func _lost_color() -> Color:
	return Color(0.231373, 0.141176, 0.105882, Tuning.hud_stock_lost_alpha)

func _refresh_stock_tab() -> void:
	var want: bool = _stock_total > 0 and not _is_dead
	if want != _stock_tab.visible:
		_stock_tab.visible = want
	_layout_tabs()

func _pop_lost(ic: TextureRect) -> void:
	ic.self_modulate = Color.WHITE
	ic.scale = Vector2(1.5, 1.5)
	var half: float = Tuning.hud_stock_lose_s * 0.5
	var tw := create_tween()
	tw.tween_property(ic, "scale", Vector2(0.8, 0.8), half).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(ic, "self_modulate", _lost_color(), half)
	tw.tween_property(ic, "scale", Vector2.ONE, half).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Border / sticker / wash for the current level; `rising` = the level just went UP (pop the sticker + kick the card).
func _apply_danger_look(rising: bool) -> void:
	var lv: int = _danger_lv
	if _card_sb != null:
		var bw: int = int(Tuning.hud_danger_border_w[lv])
		_card_sb.border_width_left = bw
		_card_sb.border_width_top = bw
		_card_sb.border_width_right = bw
		_card_sb.border_width_bottom = bw
		_card_sb.border_color = Tuning.hud_danger_border[lv]
	_danger_t = 0.0
	if lv == 0:
		_tag.visible = false
		_flush.modulate.a = 0.0
		_kick_t = 0.0
		rotation = 0.0
		scale = Vector2.ONE
		return
	_tag_word.text = str(Tuning.hud_danger_words[lv])
	# Lv1: chocolate word on light amber; Lv2: white word (chocolate outline) on dark crimson -> luminance flips too
	if lv == 1:
		_tag_word.add_theme_color_override("font_color", Color(0.231373, 0.141176, 0.105882))
		_tag_word.add_theme_color_override("font_outline_color", Color(1, 1, 1, 1))
		_tag_word.add_theme_constant_override("outline_size", 4)
	else:
		_tag_word.add_theme_color_override("font_color", Color.WHITE)
		_tag_word.add_theme_color_override("font_outline_color", Color(0.231373, 0.141176, 0.105882))
		_tag_word.add_theme_constant_override("outline_size", 8)
	if _tag_sb != null:
		_tag_sb.bg_color = Tuning.hud_danger_tag_fill[lv]
	if _heal_sb != null:
		_heal_sb.bg_color = Color.WHITE if lv == 2 else Color(0.231373, 0.141176, 0.105882)
	var glow: StyleBoxFlat = _flush.get_theme_stylebox("panel") as StyleBoxFlat
	if glow != null:
		var gw: int = int(Tuning.hud_danger_glow_px[lv])
		glow.border_width_left = gw
		glow.border_width_top = gw
		glow.border_width_right = gw
		glow.border_width_bottom = gw
	_heal_bar.visible = Tuning.hud_danger_heal_bar
	_tag.visible = true
	_layout_tabs()
	if rising:
		_tag.scale = Vector2(1.6, 1.6)
		if _tag_tw != null and _tag_tw.is_valid():
			_tag_tw.kill()
		_tag_tw = create_tween()
		_tag_tw.tween_property(_tag, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_kick()

func _kick() -> void:
	_kick_t = Tuning.hud_danger_kick_s
	_kick_sign = -_kick_sign

## Place the stock tab + sticker on the card's centre-facing edge (sizes come from their content).
func _layout_tabs() -> void:
	if _stock_tab == null or _tag == null:
		return
	var tuck: float = Tuning.hud_stock_tuck
	if _tab_sb != null:
		# the tucked side hides under the card, so its padding grows by the tuck
		_tab_sb.content_margin_top = 6.0 + (tuck if _corner_top else 0.0)
		_tab_sb.content_margin_bottom = 6.0 + (0.0 if _corner_top else tuck)
	var ts: Vector2 = _stock_tab.get_combined_minimum_size()
	_stock_tab.size = ts
	var sx: float = Tuning.hud_stock_inset if _corner_left else size.x - Tuning.hud_stock_inset - ts.x
	var sy: float = (size.y - tuck) if _corner_top else (tuck - ts.y)
	_stock_tab.position = Vector2(sx, sy)
	var gs: Vector2 = _tag.get_combined_minimum_size()
	_tag.size = gs
	var ov: float = Tuning.hud_danger_tag_overlap
	var gx: float = (size.x - gs.x + Tuning.hud_danger_tag_overhang) if _corner_left else -Tuning.hud_danger_tag_overhang
	if _stock_tab.visible:   # never cover a stock head: slide toward the screen centre until the sticker clears the tab
		if _corner_left:
			gx = maxf(gx, sx + ts.x + Tuning.hud_danger_tag_stock_gap)
		else:
			gx = minf(gx, sx - gs.x - Tuning.hud_danger_tag_stock_gap)
	var gy: float = (size.y - ov) if _corner_top else (ov - gs.y)
	_tag.position = Vector2(gx, gy)
	_tag.pivot_offset = gs * 0.5
	_tag.rotation = deg_to_rad(Tuning.hud_danger_tag_tilt_deg * (1.0 if _corner_left else -1.0))

func _process(delta: float) -> void:
	if _danger_lv == 0 and _kick_t <= 0.0:
		return
	_danger_t += delta
	var rot := 0.0
	var sc := 1.0
	if _kick_t > 0.0:
		_kick_t = maxf(0.0, _kick_t - delta)
		var k: float = _kick_t / maxf(0.01, Tuning.hud_danger_kick_s)   # 1 -> 0
		# damped wobble: two and a half swings that die out over the kick
		rot += deg_to_rad(Tuning.hud_danger_kick_deg) * k * k * sin((1.0 - k) * TAU * 2.5) * _kick_sign
		sc += Tuning.hud_danger_kick_scale * k * k
	if _danger_lv == 2 and Tuning.hud_danger_tremble_deg > 0.0:
		rot += deg_to_rad(Tuning.hud_danger_tremble_deg) * sin(_danger_t * TAU * Tuning.hud_danger_tremble_hz)
	pivot_offset = size * 0.5
	rotation = rot
	scale = Vector2(sc, sc)
	if _danger_lv > 0:
		var fl: Vector2 = Tuning.hud_danger_flush_lv2 if _danger_lv == 2 else Tuning.hud_danger_flush_lv1
		var hz: float = Tuning.hud_danger_lv2_hz if _danger_lv == 2 else Tuning.hud_danger_lv1_hz
		_flush.self_modulate = Tuning.hud_danger_flush
		_flush.modulate.a = clampf(fl.x + fl.y * sin(_danger_t * TAU * hz), 0.0, 1.0)
	else:
		_flush.modulate.a = 0.0
