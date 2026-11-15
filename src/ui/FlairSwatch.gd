extends Control
## WK-145 (UX4-26): the flair-unlock card's icon shows THE FLAIR, worn by a tiny goat, instead of a generic star.
## Lives inside the card's ToyDisc (HerdLobby.tscn UnlockCard/.../Icon/Swatch) over an open-sky fill
## (Tuning.unlock_icon_sky, a twilight sky: every flair is a glow, so it reads best on dark) so every channel reads:
##   streak -> the knockback jetstream trailing the goat (flair.json tail/mid/head ramp, or the rainbow marquee)
##   flame  -> the jetpack exhaust under the goat in the flair's three stops (the in-game fire blob texture)
##   kopop  -> a KO-pop star burst behind the goat in the flair's stops
##   title  -> a gold name ribbon under the goat (titles are worn as a banner)
## Same colour params the match uses (Player._apply_flair / Juice.flair_ko_pop), so the icon is the real thing.
## Pure _draw over shipped textures; no input (mouse IGNORE).

const CHOCO := Color(0.231373, 0.141176, 0.105882)
const GOLD := Color("#ffd23f")
const FIRE_TEX := preload("res://assets/particles/fire_01.png")
const STAR_TEX := preload("res://assets/fx/star_sparkle.png")
const SPARK_TEX := preload("res://assets/particles/spark_01.png")

var _channel := ""
var _params: Dictionary = {}
var _goat: Texture2D = null

## item = one flair.json entry; goat = a portrait texture to wear it (null = effect only).
func setup(item: Dictionary, goat: Texture2D) -> void:
	_channel = str(item.get("channel", ""))
	_params = item.get("params", {}) as Dictionary
	_goat = goat
	queue_redraw()

func _draw() -> void:
	var s := size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	var k: float = minf(s.x, s.y) / 128.0   # authored on the 128 px disc
	var o := (s - Vector2(128.0, 128.0) * k) * 0.5
	match _channel:
		"streak":
			_draw_streak(o, k)
		"flame":
			_draw_flame(o, k)
		"kopop":
			_draw_pop(o, k)
	_draw_goat(o, k)
	if _channel == "title":
		_draw_ribbon(o, k)

func _p(o: Vector2, k: float, x: float, y: float) -> Vector2:
	return o + Vector2(x, y) * k

# ------------------------------------------------------------------ goat
func _draw_goat(o: Vector2, k: float) -> void:
	if _goat == null:
		return
	var gs: Vector2 = _goat.get_size()
	if gs.x <= 0.0 or gs.y <= 0.0:
		return
	var px: float = Tuning.unlock_icon_goat_px * k
	var sc: float = px / maxf(gs.x, gs.y)
	var sz := gs * sc
	var cy: float = 52.0 if _channel == "title" else 56.0   # a title ribbon sits under the goat
	var cx: float = 64.0 if _channel == "title" or _channel == "kopop" else 76.0   # streak / flame trail off to the left
	var c := _p(o, k, cx, cy)
	draw_texture_rect(_goat, Rect2(c - sz * 0.5, sz), false)

# ------------------------------------------------------------------ streak (knockback jetstream)
## The match ramp (tail -> mid at 0.55 -> head); the icon keeps an alpha floor so the whole ribbon reads at 128 px.
func _streak_col(t: float, i: int, n: int) -> Color:
	var a: float = lerpf(0.25, 1.0, clampf(t / 0.55, 0.0, 1.0))
	if bool(_params.get("rainbow", false)):
		return Color.from_hsv(float(i) / float(maxi(1, n)) * 0.85, 0.7, 1.0, a)
	var tail := _c3(_params.get("tail", []), 1.0)
	var mid := _c3(_params.get("mid", []), 1.0)
	var head := _c3(_params.get("head", []), 1.0)
	var c: Color = tail.lerp(mid, t / 0.55) if t < 0.55 else mid.lerp(head, (t - 0.55) / 0.45)
	c.a = a
	return c

func _draw_streak(o: Vector2, k: float) -> void:
	var p0 := _p(o, k, 14.0, 98.0)
	var p1 := _p(o, k, 34.0, 60.0)
	var p2 := _p(o, k, 74.0, 58.0)
	var n := 18
	var pts: Array = []
	for i in range(n + 1):
		var t := float(i) / float(n)
		pts.append(p0.lerp(p1, t).lerp(p1.lerp(p2, t), t))
	# a tapered ribbon, one quad per segment so the colour ramp follows the length
	for i in range(n):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var ta := float(i) / float(n)
		var tb := float(i + 1) / float(n)
		var dir := (b - a).normalized()
		var nrm := Vector2(-dir.y, dir.x)
		var wa: float = lerpf(6.0, 34.0, ta) * k * 0.5
		var wb: float = lerpf(6.0, 34.0, tb) * k * 0.5
		var ca := _streak_col(ta, i, n)
		var cb := _streak_col(tb, i + 1, n)
		draw_polygon(PackedVector2Array([a + nrm * wa, b + nrm * wb, b - nrm * wb, a - nrm * wa]),
			PackedColorArray([ca, cb, cb, ca]))
	# head cap (round) so the streak meets the goat cleanly
	draw_circle(p2, 17.0 * k, _streak_col(1.0, n, n))
	# a bright core line down the middle: the in-game streak's white-hot centre
	for i in range(floori(n / 3.0), n):
		var c := Color(1, 1, 1, 0.55 * float(i) / float(n))
		draw_line(pts[i], pts[i + 1], c, lerpf(2.0, 8.0, float(i) / float(n)) * k, true)

# ------------------------------------------------------------------ flame (jetpack exhaust)
func _draw_flame(o: Vector2, k: float) -> void:
	var stops: Array = _params.get("stops", []) as Array
	if stops.size() < 3:
		return
	var c0 := _c4(stops[0])
	var c1 := _c4(stops[1])
	var c2 := _c4(stops[2])
	c2.a = maxf(c2.a, 0.55)   # the far stop fades out in play; keep a readable tip on the icon
	# from the far tip (outer colour, small) to the nozzle (core colour, big), drawn far-to-near
	# the goat's jetpack sits on its left (screen) side; the burner fires down-left out of it
	var nozzle := _p(o, k, 52.0, 70.0)
	var tip := _p(o, k, 18.0, 112.0)
	var blobs := 9
	for pass_i in range(2):   # two passes: the glow builds up like the additive in-game exhaust
		for i in range(blobs):
			var t := 1.0 - float(i) / float(blobs - 1)   # 1 = tip, 0 = nozzle
			var col: Color = c1.lerp(c2, (t - 0.45) / 0.55) if t > 0.45 else c0.lerp(c1, t / 0.45)
			var r: float = lerpf(26.0, 11.0, t) * k * (1.0 if pass_i == 0 else 0.6)
			var c := nozzle.lerp(tip, t)
			draw_texture_rect(FIRE_TEX, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, col)
	# hot core at the nozzle
	draw_texture_rect(FIRE_TEX, Rect2(nozzle - Vector2(13, 13) * k, Vector2(26, 26) * k), false, Color(1, 1, 1, 0.95))

# ------------------------------------------------------------------ KO pop (star burst)
func _draw_pop(o: Vector2, k: float) -> void:
	var stops: Array = _params.get("stops", []) as Array
	var cols: Array = []
	for st in stops:
		var c := _c4(st)
		c.a = 1.0
		cols.append(c)
	if cols.is_empty():
		cols = [GOLD]
	var hv: float = float(_params.get("hue_variation", 0.0))
	var ctr := _p(o, k, 66.0, 62.0)
	var rays := 10
	for i in range(rays):
		var ang := TAU * float(i) / float(rays) - PI * 0.5
		var col: Color = cols[i % mini(2, cols.size())]
		if hv > 0.0:
			col = Color.from_hsv(fposmod(col.h + hv * (float(i) / float(rays) - 0.5), 1.0), col.s, col.v)
		var rr: float = (50.0 if i % 2 == 0 else 40.0) * k
		var st_r: float = (13.0 if i % 2 == 0 else 9.0) * k
		var p := ctr + Vector2(cos(ang), sin(ang)) * rr
		draw_texture_rect(STAR_TEX, Rect2(p - Vector2(st_r, st_r), Vector2(st_r, st_r) * 2.0), false, col)
		var sp := ctr + Vector2(cos(ang + 0.31), sin(ang + 0.31)) * rr * 0.72
		draw_texture_rect(SPARK_TEX, Rect2(sp - Vector2(5, 5) * k, Vector2(10, 10) * k), false, col)

# ------------------------------------------------------------------ title (name ribbon)
func _draw_ribbon(o: Vector2, k: float) -> void:
	var y0 := 90.0
	var y1 := 112.0
	var tail_l := PackedVector2Array([_p(o, k, 8, y0 + 6), _p(o, k, 26, y0 + 6), _p(o, k, 26, y1 + 6), _p(o, k, 8, y1 + 6), _p(o, k, 15, (y0 + y1) * 0.5 + 6)])
	var tail_r := PackedVector2Array([_p(o, k, 120, y0 + 6), _p(o, k, 102, y0 + 6), _p(o, k, 102, y1 + 6), _p(o, k, 120, y1 + 6), _p(o, k, 113, (y0 + y1) * 0.5 + 6)])
	var dark := GOLD.darkened(0.25)
	for tl in [tail_l, tail_r]:
		draw_colored_polygon(tl, dark)
		var loop: PackedVector2Array = (tl as PackedVector2Array).duplicate()
		loop.append(tl[0])
		draw_polyline(loop, CHOCO, 3.0 * k, true)
	var band := PackedVector2Array([_p(o, k, 20, y0), _p(o, k, 108, y0), _p(o, k, 108, y1), _p(o, k, 20, y1)])
	draw_colored_polygon(band, GOLD)
	var bl := band.duplicate()
	bl.append(band[0])
	draw_polyline(bl, CHOCO, 3.5 * k, true)
	# a highlight stripe so it reads as a satin ribbon, not a bar
	draw_line(_p(o, k, 26, y0 + 5), _p(o, k, 102, y0 + 5), Color(1, 1, 1, 0.55), 2.5 * k, true)

# ------------------------------------------------------------------ colour helpers (flair.json arrays)
func _c3(v: Variant, a: float) -> Color:
	var arr: Array = v if v is Array else []
	if arr.size() < 3:
		return Color(1.0, 1.0, 1.0, a)
	return Color(float(arr[0]), float(arr[1]), float(arr[2]), a)

func _c4(v: Variant) -> Color:
	var arr: Array = v if v is Array else []
	if arr.size() < 4:
		return Color.WHITE
	return Color(float(arr[0]), float(arr[1]), float(arr[2]), float(arr[3]))
