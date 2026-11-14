extends Control
## WK-25 KO CREDIT POP (audit D-02 part 1; BACKLOG WK-25). At the moment of a BRAWL KO a chip pops out of the
## WK-23 screen-edge blast and flies into a corner card, so the score change is SEEN when it happens:
##   credited KO          -> "+1" in the KILLER's colour flies into the killer's card; the card bumps.
##   self-KO (default Ra) -> "OOPS!" in the VICTIM's colour flies to the victim's card, which wobbles, and the chip
##                           falls off it (non-scoring, WK-20c rule).
##   self-KO, SELF-KO −1  -> same as OOPS but the chip reads "−1" (only when a point was really taken: a −1
##                           floored at 0 shows "OOPS!", because nothing was subtracted).
## Owner ruling 2026-07-16 (no persistent combat score): the chip shows only the CHANGE, never a total, and is gone
## within Tuning's ~1.2-1.3 s. Nothing lingers on the card.
##
## Sequencing (reads as ONE event with the blast): the chip spawns on the blast's starburst (KOEdgeBlast.locate —
## the same edge/anchor the blast used) a beat after the blast core peaks, holds, then flies. The flight is a
## quadratic curve whose control point is the screen-border corner between the KO edge and the card, so it runs
## along the border instead of across the middle 60% (MatchHUD prime directive). A death still on screen (an
## in-view hazard: no edge blast) spawns at the victim and flies straight.
##
## Real time: the same hitch-proof clock as KOEdgeBlast (ignores Engine.time_scale so the KO hit-stop never
## stretches it; per-frame step clamped; the KO frame itself never counts).
## Lives in MatchHUD.tscn ($Root/CreditPops, last child = drawn over the cards). The chip is a .tscn
## (KOCreditChip) dressed from the theme; only its motion is code. No class_name.

const CHIP_SCENE := preload("res://scenes/ui/KOCreditChip.tscn")
const QA_LOG_MAX := 64
const MAX_STEP := 0.1   # 10 fps floor (same as KOEdgeBlast)

## QA feed (gbplay eval): one dict per pop — {kind, text, card, color:"#rrggbb", edge, from:[x,y], to:[x,y],
## spawn_msec, arrive_msec (-1 until it lands), arrive_s (real s from KO to landing), + the caller's meta}.
var pops: Array = []
var pop_count := 0

var _live: Array = []
var _bumps: Dictionary = {}   # card instance id -> {card, t, kind, fresh}
var _last_us := 0
var _movie: bool = Engine.get_write_movie_path() != ""   # WK-93 Movie Maker run -> frame clock

## kind: "plus" | "oops" | "minus". card: the target PlayerCard. loc: KOEdgeBlast.locate(victim)
## ({edge, anchor, inward, sp}; edge "" = died on screen). meta: QA fields copied into the log entry.
func pop(kind: String, card: Control, text: String, color: Color, loc: Dictionary, meta: Dictionary = {}) -> void:
	if card == null or not is_instance_valid(card):
		return
	var vp: Vector2 = get_viewport_rect().size
	var k: float = vp.y / Tuning.ko_blast_ref_height
	var chip = CHIP_SCENE.instantiate()   # KOCreditChip.gd (untyped: dress() is a script method)
	chip.visible = false
	add_child(chip)
	var sz: Vector2 = chip.dress(text, color)
	var edge: String = str(loc.get("edge", ""))
	var from: Vector2 = vp * 0.5
	if edge != "" and loc.has("anchor") and loc.has("inward"):
		var anchor: Vector2 = loc["anchor"]
		var inward: Vector2 = loc["inward"]
		from = anchor + inward * Tuning.ko_pop_start_inset_px * k
	elif loc.has("sp"):
		from = loc["sp"]
	var half: Vector2 = sz * 0.5 + Vector2(12.0, 12.0) * k
	from = Vector2(clampf(from.x, half.x, vp.x - half.x), clampf(from.y, half.y, vp.y - half.y))
	var to: Vector2 = card.get_global_rect().get_center()
	# border-hugging control point: travel ALONG the KO edge first, then along the card's side
	var ctrl: Vector2 = from.lerp(to, 0.5)
	if edge == "left" or edge == "right":
		ctrl = Vector2(from.x, to.y)
	elif edge == "top" or edge == "bottom":
		ctrl = Vector2(to.x, from.y)
	var entry := {"kind": kind, "text": text, "color": "#" + color.to_html(false), "edge": edge,
		"from": [from.x, from.y], "to": [to.x, to.y], "spawn_msec": Time.get_ticks_msec(),
		"arrive_msec": -1, "arrive_s": -1.0}
	for key in meta:
		entry[key] = meta[key]
	pops.append(entry)
	pop_count += 1
	if pops.size() > QA_LOG_MAX:
		pops.remove_at(0)
	var t_fly0: float = Tuning.ko_pop_delay + Tuning.ko_pop_in_time + Tuning.ko_pop_hold
	_live.append({"chip": chip, "card": card, "kind": kind, "from": from, "ctrl": ctrl, "to": to, "k": k,
		"t": 0.0, "fresh": true, "t_fly0": t_fly0, "t_land": t_fly0 + Tuning.ko_pop_fly_time,
		"landed": false, "log": entry, "spin": (1.0 if randf() < 0.5 else -1.0)})
	_apply(_live[_live.size() - 1])

## Drop every live chip and reset card transforms (rematch / match reset).
func clear() -> void:
	for b in _live:
		if is_instance_valid(b["chip"]):
			(b["chip"] as Node).queue_free()
	_live.clear()
	for id in _bumps:
		var c = _bumps[id]["card"]
		if is_instance_valid(c):
			c.scale = Vector2.ONE
			c.rotation = 0.0
	_bumps.clear()

## True while any chip is on screen (QA overlay audit).
func is_showing() -> bool:
	return not _live.is_empty()

func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt: float = clampf(float(now - _last_us) / 1000000.0, 0.0, MAX_STEP)
	_last_us = now
	if _movie:
		# WK-25: under Movie Maker (WK-93 recordings) wall time runs ~4x slower than the fixed-fps game clock, so
		# the wall clock would play this ~3x too fast on film. Use the frame's UNSCALED delta (hit-stop excluded).
		dt = delta / maxf(Engine.time_scale, 0.05)
	for i in range(_live.size() - 1, -1, -1):
		var b: Dictionary = _live[i]
		if not is_instance_valid(b["chip"]):
			_live.remove_at(i)
			continue
		if bool(b["fresh"]):
			b["fresh"] = false   # the KO frame's own duration never counts (KOEdgeBlast rule)
		else:
			b["t"] = float(b["t"]) + dt
		var out_t: float = Tuning.ko_pop_absorb_time if str(b["kind"]) == "plus" else Tuning.ko_pop_drop_time
		if float(b["t"]) >= float(b["t_land"]) + out_t:
			(b["chip"] as Node).queue_free()
			_live.remove_at(i)
			continue
		_apply(b)
	_tick_bumps(dt)

## Pose one chip at its pop time t.
func _apply(b: Dictionary) -> void:
	var chip: Control = b["chip"]
	var t: float = b["t"]
	var sz: Vector2 = chip.size
	if t < Tuning.ko_pop_delay:
		chip.visible = false
		return
	chip.visible = true
	var from: Vector2 = b["from"]
	var to: Vector2 = b["to"]
	var t_fly0: float = b["t_fly0"]
	var t_land: float = b["t_land"]
	var pos: Vector2 = from
	var s := 1.0
	var a := 1.0
	var rot := 0.0
	if t < t_fly0:
		# pop-in on the blast, then a short readable hold
		var u: float = (t - Tuning.ko_pop_delay) / maxf(0.01, Tuning.ko_pop_in_time)
		if u < 0.6:
			s = lerpf(0.3, 1.15, _out_quad(u / 0.6))
		elif u < 1.0:
			s = lerpf(1.15, 1.0, smoothstep(0.0, 1.0, (u - 0.6) / 0.4))
	elif t < t_land:
		var e: float = _in_out_cubic((t - t_fly0) / maxf(0.01, t_land - t_fly0))
		pos = _bezier(from, b["ctrl"], to, e)
		s = lerpf(1.0, Tuning.ko_pop_fly_scale, e)
	else:
		if not bool(b["landed"]):
			b["landed"] = true
			var entry: Dictionary = b["log"]
			entry["arrive_msec"] = Time.get_ticks_msec()
			entry["arrive_s"] = t
			_start_bump(b["card"], str(b["kind"]))
		var k: float = b["k"]
		if str(b["kind"]) == "plus":
			# swallowed by the killer's card
			var u2: float = _clamp01((t - t_land) / maxf(0.01, Tuning.ko_pop_absorb_time))
			pos = to
			s = lerpf(Tuning.ko_pop_fly_scale, 0.25, _in_quad(u2))
			a = 1.0 - _in_quad(u2)
		else:
			# falls off the victim's card: a small hop, then gravity, a lazy tumble and a fade
			var u3: float = _clamp01((t - t_land) / maxf(0.01, Tuning.ko_pop_drop_time))
			var hop: float = 60.0 * k
			pos = to + Vector2(float(b["spin"]) * 26.0 * k * u3, -hop * u3 + (Tuning.ko_pop_drop_px * k + hop) * u3 * u3)
			s = Tuning.ko_pop_fly_scale
			rot = float(b["spin"]) * deg_to_rad(28.0) * u3
			a = 1.0 - _clamp01((u3 - 0.35) / 0.65)
	chip.position = pos - sz * 0.5
	chip.scale = Vector2.ONE * s
	chip.rotation = rot
	chip.modulate.a = a

## Card reaction on landing: "+1" bumps the killer's card (scale overshoot + undershoot); "OOPS!" / "−1" wobbles
## the victim's card. A newer landing on the same card restarts its reaction.
func _start_bump(card, kind: String) -> void:
	if card == null or not is_instance_valid(card):
		return
	(card as Control).pivot_offset = (card as Control).size * 0.5
	_bumps[card.get_instance_id()] = {"card": card, "t": 0.0, "kind": kind}

func _tick_bumps(dt: float) -> void:
	for id in _bumps.keys():
		var bm: Dictionary = _bumps[id]
		var card = bm["card"]
		if not is_instance_valid(card):
			_bumps.erase(id)
			continue
		bm["t"] = float(bm["t"]) + dt
		var t: float = bm["t"]
		if str(bm["kind"]) == "plus":
			var u: float = t / maxf(0.01, Tuning.ko_pop_card_bump_time)
			if u >= 1.0:
				card.scale = Vector2.ONE
				_bumps.erase(id)
				continue
			var s: float
			if u < 0.3:
				s = 1.0 + Tuning.ko_pop_card_bump * _out_quad(u / 0.3)
			else:
				var v: float = (u - 0.3) / 0.7
				s = 1.0 + Tuning.ko_pop_card_bump * (1.0 - v) * cos(v * PI * 1.5)
			card.scale = Vector2.ONE * s
		else:
			var w: float = t / maxf(0.01, Tuning.ko_pop_card_wobble_time)
			if w >= 1.0:
				card.rotation = 0.0
				card.scale = Vector2.ONE
				_bumps.erase(id)
				continue
			card.rotation = deg_to_rad(Tuning.ko_pop_card_wobble_deg) * (1.0 - w) * sin(w * TAU * 2.5)
			card.scale = Vector2.ONE * (1.0 - 0.06 * sin(PI * w))

static func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, e: float) -> Vector2:
	var q0: Vector2 = p0.lerp(p1, e)
	var q1: Vector2 = p1.lerp(p2, e)
	return q0.lerp(q1, e)

static func _clamp01(x: float) -> float:
	return clampf(x, 0.0, 1.0)

static func _out_quad(x: float) -> float:
	var u := _clamp01(x)
	return 1.0 - (1.0 - u) * (1.0 - u)

static func _in_quad(x: float) -> float:
	var u := _clamp01(x)
	return u * u

static func _in_out_cubic(x: float) -> float:
	var u := _clamp01(x)
	return 4.0 * u * u * u if u < 0.5 else 1.0 - pow(-2.0 * u + 2.0, 3.0) / 2.0
