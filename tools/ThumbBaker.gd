extends Node
## OFFLINE one-shot arena thumbnail baker (docs/briefs/frontend_visual_polish.md §3b).
## Loads every arena referenced by levels/circuits.json (the ordered circuits' `levels` + the
## mayhem_mile `pool`), frames the WHOLE arena wide via a SubViewport + Camera2D (no players — a
## clean establishing shot through the real Glossy-Toybox ArenaRenderer), and saves an opaque
## 512x320 PNG to assets/ui/thumbs/<arena_id>.png. Run it, look at the PNGs, wire them into
## ArenaSelect. Re-run whenever a level changes.
##
## RUN (windowed, NOT headless -- it needs the renderer):
##   C:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe --path . res://tools/ThumbBaker.tscn
## It bakes all arenas sequentially then quits (exit code 0). Watch stdout for per-arena OK/FAIL.

const CIRCUITS_PATH := "res://levels/circuits.json"
const COURTS_PATH := "res://levels/sports_courts.json"
const OUT_DIR := "res://assets/ui/thumbs"
const OUT_W := 512
const OUT_H := 320
const SS := 2                      # supersample factor: render at 2x then downscale for clean AA
const TARGET_ASPECT := float(OUT_W) / float(OUT_H)   # 1.6

var _sv: SubViewport
var _cam: Camera2D
var _level_root: Node2D

func _ready() -> void:
	_bake_all()

func _bake_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	# --- SubViewport render target (own World2D; own camera) ---
	_sv = SubViewport.new()
	_sv.size = Vector2i(OUT_W * SS, OUT_H * SS)
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sv.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_sv.transparent_bg = false      # opaque captures are fine (§3c)
	_sv.disable_3d = true
	add_child(_sv)

	_cam = Camera2D.new()
	_sv.add_child(_cam)
	_cam.enabled = true
	_cam.make_current()

	# entries = {id, path}: circuit/pool arenas (path derived from id) + sports courts (explicit path,
	# baked UNDER THE COURT ID so the court-select thumb lookup hits directly).
	var entries: Array = []
	for id in _arena_ids():
		entries.append({"id": id, "path": "res://levels/%s.json" % id})
	entries.append_array(_court_entries())
	# WK-122: optional id-prefix filter so one family can be re-baked without touching the rest:
	#   <exe> --path . res://tools/ThumbBaker.tscn -- --only=court_
	var only := ""
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--only="):
			only = str(a).substr(7)
	if only != "":
		entries = entries.filter(func(e: Dictionary) -> bool: return str(e["id"]).begins_with(only))
	print("[ThumbBaker] baking %d arenas/courts -> %s" % [entries.size(), OUT_DIR])
	var ok := 0
	var fail: Array[String] = []
	for e in entries:
		var res := await _bake_one(str(e["id"]), str(e["path"]))
		if res:
			ok += 1
		else:
			fail.append(str(e["id"]))

	print("[ThumbBaker] DONE  ok=%d  fail=%d" % [ok, fail.size()])
	if fail.size() > 0:
		print("[ThumbBaker] FAILED: %s" % ", ".join(fail))
	get_tree().quit(0)

## Collect every arena id from circuits.json: the ordered circuits' `levels` + any `pool[].id`.
## Deduped, order-preserving. Falls back to the ArenaSelect 11 if the file can't be parsed.
func _arena_ids() -> Array[String]:
	var out: Array[String] = []
	var seen := {}
	var add := func(id: String) -> void:
		if id != "" and not seen.has(id):
			seen[id] = true
			out.append(id)
	var txt := FileAccess.get_file_as_string(CIRCUITS_PATH)
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) == TYPE_DICTIONARY:
		var circuits: Variant = (parsed as Dictionary).get("circuits", {})
		if typeof(circuits) == TYPE_DICTIONARY:
			for cid in (circuits as Dictionary).keys():
				var ed: Dictionary = (circuits as Dictionary)[cid]
				for lv in ed.get("levels", []):
					add.call(str(lv))
				for pe in ed.get("pool", []):
					if typeof(pe) == TYPE_DICTIONARY:
						add.call(str((pe as Dictionary).get("id", "")))
	return out

## Sports courts from sports_courts.json: id + explicit level path (courts live under levels/sports/).
func _court_entries() -> Array:
	var out: Array = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(COURTS_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return out
	for c in (parsed as Dictionary).get("courts", []):
		if typeof(c) == TYPE_DICTIONARY:
			var id := str((c as Dictionary).get("id", ""))
			var path := str((c as Dictionary).get("path", ""))
			if id != "" and path != "":
				# court_ prefix: the court id "minefield" collides with the BRAWL arena "minefield" —
				# an unprefixed bake overwrites the arena's thumb. ArenaSelect looks up court_<id> first.
				out.append({"id": "court_" + id, "path": path})
	return out

func _bake_one(id: String, path: String) -> bool:
	if not FileAccess.file_exists(path):
		print("[ThumbBaker]   %s  SKIP (no level file)" % id)
		return false

	# fresh level tree per arena (free the previous ArenaRenderer + colliders first)
	if _level_root != null and is_instance_valid(_level_root):
		_level_root.queue_free()
		await get_tree().process_frame
	_level_root = Node2D.new()
	_sv.add_child(_level_root)

	var data := LevelLoader.load_level(path, _level_root)
	var pr: Rect2 = data.get("play_rect", Rect2())
	if pr.size.x <= 0.0 or pr.size.y <= 0.0:
		# fall back to bounds if the level authored no platforms merge
		pr = data.get("bounds", Rect2(-960, -540, 1920, 1080))

	# --- frame: whole arena wide, platforms vertically centred, expanded to 16:10 ---
	var mx: float = maxf(pr.size.x * 0.14, 220.0)
	var my: float = maxf(pr.size.y * 0.20, 220.0)
	var view := Rect2(pr.position - Vector2(mx, my), pr.size + Vector2(mx * 2.0, my * 2.0))
	# WK-122: a sports court is framed like the game frames it (SportsMode.camera_framing = the bounds),
	# fitted to 16:10 below -- the court fills the card and the edge-to-edge stadium covers the whole shot.
	if id.begins_with("court_"):
		view = data.get("bounds", view)
	if view.size.x / view.size.y < TARGET_ASPECT:
		var nw: float = view.size.y * TARGET_ASPECT
		view.position.x -= (nw - view.size.x) * 0.5
		view.size.x = nw
	else:
		var nh: float = view.size.x / TARGET_ASPECT
		view.position.y -= (nh - view.size.y) * 0.5
		view.size.y = nh
	# camera at view centre == play_rect centre (symmetric grow) so parallax anchor delta is ~0
	_cam.position = view.get_center()
	_cam.zoom = Vector2(float(_sv.size.x) / view.size.x, float(_sv.size.y) / view.size.y)

	# let the renderer's _process place parallax layers, then capture a fully-drawn frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	var img := _sv.get_texture().get_image()
	if img == null or img.is_empty():
		print("[ThumbBaker]   %s  FAIL (empty capture)" % id)
		return false
	img.resize(OUT_W, OUT_H, Image.INTERPOLATE_LANCZOS)
	var out_path := "%s/%s.png" % [OUT_DIR, id]
	var err := img.save_png(out_path)
	if err != OK:
		print("[ThumbBaker]   %s  FAIL (save err %d)" % [id, err])
		return false
	print("[ThumbBaker]   %s  OK  view=%dx%d" % [id, int(view.size.x), int(view.size.y)])
	return true
