extends PanelContainer
## WK-37 GHOST LEGEND (spec §5): one line by the eliminated human's HUD card for Tuning.ghost_legend_time —
## "GHOST!  (stick) FLOAT · (X) PUFF · (Y) BAA" with device-aware glyphs (pad: stick / X / Y; keyboard: WASD / K / J —
## the action map's KB-L bindings + the WK-37b taunt key). BAA ONLY drops the PUFF item. Cream chip + chocolate rim like
## the stage-1 ControlsLegend chips (LegendChip.tscn family). Presentation only; frees itself.

const GAP := 10.0   # px between the card and the legend

@onready var _title: Label = $Box/Title
@onready var _move: PadGlyph = $Box/MoveGlyph
@onready var _puff_g: PadGlyph = $Box/PuffGlyph
@onready var _puff_l: Label = $Box/PuffLabel
@onready var _baa: PadGlyph = $Box/BaaGlyph

## color = the player's identity colour (title); kb = keyboard glyphs; puff = show the PUFF item; card = the HUD card's
## screen rect (the legend sits just inside the screen from it, below a top card / above a bottom card).
func present(color: Color, kb: bool, puff: bool, card: Rect2, hold: float) -> void:
	if _title == null:
		await ready
	_title.add_theme_color_override("font_color", color)
	_move.setup("key:WASD" if kb else "stick")
	_puff_g.setup("key:K" if kb else "X")
	_baa.setup("key:J" if kb else "Y")
	_puff_g.visible = puff
	_puff_l.visible = puff
	reset_size()
	await get_tree().process_frame
	reset_size()
	var vp: Vector2 = get_viewport_rect().size
	var top: bool = card.get_center().y < vp.y * 0.5
	var left: bool = card.get_center().x < vp.x * 0.5
	var x: float = card.position.x if left else card.end.x - size.x
	var y: float = (card.end.y + GAP) if top else (card.position.y - GAP - size.y)
	position = Vector2(clampf(x, 8.0, vp.x - size.x - 8.0), y).round()
	pivot_offset = size * 0.5
	scale = Vector2(0.3, 0.3)
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.1)
	tw.parallel().tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.1, hold))
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)
