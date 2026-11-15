extends RefCounted
## WK-34 F1 / WK-35 Toybox panel kit — the shared runtime pieces of the cream-plate match flow (ScoreScreen,
## Brawl VictoryScreen, SportsVictory). Static helpers only; callers `preload` this script (no class_name, so no
## class-cache rebuild and no native-name collision). The look itself lives in assets/ui/theme.tres
## (ToyIdPill / ToyIdLabel / ToyDeltaPill / ToyDeltaLabel / ToyRowWinner / ToyNameRibbon / ToyStatLead ...).
##
## Kit grammar (ux review 2026-11-15 F1): colour is a FILL, never a thin stroke. Identity = a goat-colour pill
## with white type and a chocolate outline; a stage delta = a gold / red / cool-blue pill; on chocolate chips the
## goat colour may be the text itself (>= 3.9:1 there).
##
## Also the two end screens' shared ceremony juice that used to be copy-pasted between them: confetti bursts /
## drizzle and the rays fallback glow (the focus row is FocusRow.gd, WK-14).

const CHOCO := Color(0.231373, 0.141176, 0.105882)
const CREAM := Color(1.0, 0.968627, 0.921569)
const GOLD := Color("#ffd23f")
const DANGER := Color("#ff4b3a")
const OOPS := Color("#9ebdeb")
## Chocolate scrim behind the match-flow plates (the ScoreScreen / Pause dim; navy is retired).
const SCRIM := Color(0.14, 0.09, 0.07, 0.55)

# ------------------------------------------------------------------ fills

## Re-fill a PanelContainer's themed StyleBoxFlat with `c` (a per-node duplicate; the theme stays untouched).
static func fill_panel(panel: PanelContainer, c: Color) -> void:
	var base: StyleBox = panel.get_theme_stylebox("panel")
	if base is StyleBoxFlat:
		var sb: StyleBoxFlat = (base as StyleBoxFlat).duplicate()
		sb.bg_color = c
		panel.add_theme_stylebox_override("panel", sb)

## F1.1 identity pill: goat-colour fill (ToyIdPill), white ToyIdLabel name with the chocolate outline.
static func id_pill(pill: PanelContainer, label: Label, text: String, c: Color) -> void:
	label.text = text
	fill_panel(pill, c)

## F1.2 delta pill. "+N" gold / chocolate type; "-N" DANGER / white type + chocolate outline; OOPS! cool blue /
## chocolate type. Returns false (and hides the pill) when there is nothing to show.
static func delta_pill(pill: PanelContainer, label: Label, delta: int, oops: bool) -> bool:
	if delta == 0 and not oops:
		label.text = ""
		pill.visible = false
		return false
	pill.visible = true
	if delta > 0:
		label.text = "+%d" % delta
		fill_panel(pill, GOLD)
		label.add_theme_color_override("font_color", CHOCO)
		label.add_theme_constant_override("outline_size", 0)
	elif delta < 0:
		label.text = "−%d" % absi(delta)
		fill_panel(pill, DANGER)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_constant_override("outline_size", 8)
	else:
		label.text = "OOPS!"
		fill_panel(pill, OOPS)
		label.add_theme_color_override("font_color", CHOCO)
		label.add_theme_constant_override("outline_size", 0)
	return true

# WK-14: the end-screen focus row moved to src/ui/FocusRow.gd (one focus look for every shell button).

# ------------------------------------------------------------------ confetti

## One-shot confetti cannon at `pos` firing toward `angle_deg`; each particle picks a colour from `palette`.
## Self-cleaning (a tween bound to the particles — survives a fast dismiss that frees the parent's children).
static func burst(parent: Node, pos: Vector2, angle_deg: float, palette: Array) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 120
	p.lifetime = 2.2
	p.direction = Vector2.from_angle(deg_to_rad(angle_deg))
	p.spread = 35.0
	p.gravity = Vector2(0, 400)
	p.initial_velocity_min = 500.0
	p.initial_velocity_max = 1100.0
	p.scale_amount_min = 6.0
	p.scale_amount_max = 10.0
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	tint_confetti(p, palette)
	p.emitting = true
	parent.add_child(p)
	var life := p.create_tween()
	life.tween_interval(3.0)
	life.tween_callback(p.queue_free)

## Lazy top-edge confetti drizzle for as long as the screen lives (freed with the parent's FX children).
static func drizzle(parent: Node, palette: Array, amount: int = 28) -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(960, -20)
	p.amount = amount
	p.lifetime = 3.2
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(960, 4)
	p.direction = Vector2.DOWN
	p.spread = 12.0
	p.gravity = Vector2(0, 240)
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 160.0
	p.scale_amount_min = 5.0
	p.scale_amount_max = 8.0
	p.angular_velocity_min = -220.0
	p.angular_velocity_max = 220.0
	tint_confetti(p, palette)
	p.emitting = true
	parent.add_child(p)

## Per-particle colour from the palette (constant-step initial ramp, so no muddy in-between blends).
static func tint_confetti(p: CPUParticles2D, palette: Array) -> void:
	if palette.is_empty():
		return
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for k in range(palette.size()):
		offs.append(float(k) / float(palette.size()))
		cols.append(palette[k])
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = offs
	g.colors = cols
	p.color_initial_ramp = g

## Fallback when victory_rays.png is missing: a soft radial gold glow.
static func fallback_glow() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.86, 0.35, 0.55))
	g.set_color(1, Color(1.0, 0.86, 0.35, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 512
	t.height = 512
	return t
