extends Node
## WK-187 ux FIX 4 (CD6-10, the other half): the frozen in-world goats showed through the victory ceremony (a goat
## perched on the WINNER! plate, the winner's world sprite poking out behind the rays as a twin of the bust, a ram
## under the stats panel). The Brawl VictoryScreen and SportsVictory fade every goat body, its top_level children
## (knockback streak, contact shadow, rings - top_level items don't inherit the body's modulate), the identity pips,
## the off-screen chevrons and the sports fuel arcs to alpha 0 over Tuning.end_screen_goat_fade, in step with the scrim.
## The scrim strength is untouched (the bright world behind stays on-brand; only the goats were the tell).
##
## Presentation only (INV-12): nothing here is read by gameplay. Player._update_visual rewrites the body's modulate.a
## every frame (spawn blink), so a tween on the body alone gets overwritten. This node therefore runs LATE
## (process_priority) and clamps each target's alpha down to the fade value every frame, then restores the alpha each
## target had when the fade began on restore() (dismiss / REMATCH; _start_match respawns everyone at alpha 1 anyway).
## Created by the screen with preload(...).new() (no class_name: no class-cache rebuild).

var _k := 1.0            # current fade factor (1 = untouched, 0 = gone)
var _active := false
var _targets: Array = [] # CanvasItems we clamp
var _orig := {}          # instance_id -> alpha at fade start
var _tw: Tween

func _ready() -> void:
	process_priority = 1000   # after the goats' own _process / _physics_process writes, before the frame draws

## Fade the goats of `runner` (PartyMatch) out over `secs`.
func fade_out(runner: Node, secs: float) -> void:
	restore()
	if runner == null or not is_instance_valid(runner):
		return
	_targets = _collect(runner)
	for t in _targets:
		_orig[(t as Object).get_instance_id()] = (t as CanvasItem).modulate.a
	_active = true
	_k = 1.0
	_tw = create_tween()
	_tw.tween_property(self, "_k", 0.0, maxf(0.01, secs))

## Put every faded target back to the alpha it had when the fade began.
func restore() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	if _active:
		for t in _targets:
			if t != null and is_instance_valid(t):
				var id: int = (t as Object).get_instance_id()
				(t as CanvasItem).modulate.a = float(_orig.get(id, 1.0))
	_active = false
	_k = 1.0
	_targets.clear()
	_orig.clear()

## QA: the current fade factor and how many items it holds.
func state() -> Dictionary:
	return {"active": _active, "k": snappedf(_k, 0.01), "targets": _targets.size()}

func _process(_delta: float) -> void:
	if not _active:
		return
	for t in _targets:
		if t != null and is_instance_valid(t):
			var ci := t as CanvasItem
			var cap: float = float(_orig.get(ci.get_instance_id(), 1.0)) * _k
			if ci.modulate.a > cap:
				ci.modulate.a = cap

func _collect(runner: Node) -> Array:
	var out: Array = []
	var seen := {}
	var ps: Variant = runner.get("players")
	if ps is Array:
		for p in (ps as Array):
			if p == null or not is_instance_valid(p) or not (p is CanvasItem):
				continue
			_add(out, seen, p)
			_add_top_level(out, seen, p as Node)
			if (p as Object).has_meta("wk183_arc"):   # sports fuel arc: fade its shared layer
				var arc: Variant = (p as Object).get_meta("wk183_arc")
				if arc != null and is_instance_valid(arc) and (arc as Node).get_parent() is CanvasItem:
					_add(out, seen, (arc as Node).get_parent())
	for key in ["_pips", "_edge_indicators"]:
		var n: Variant = runner.get(key)
		if n != null and is_instance_valid(n) and n is CanvasItem:
			_add(out, seen, n)
	return out

func _add_top_level(out: Array, seen: Dictionary, n: Node) -> void:
	for c in n.get_children():
		if c is CanvasItem and (c as CanvasItem).top_level:
			_add(out, seen, c)
		_add_top_level(out, seen, c)

func _add(out: Array, seen: Dictionary, n: Variant) -> void:
	var id: int = (n as Object).get_instance_id()
	if seen.has(id):
		return
	seen[id] = true
	out.append(n)
