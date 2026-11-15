extends CanvasLayer
## WK-148 (UX4-27): the match-start cover. ShellRoot's iris fills the screen with cream-white and then changes scene;
## the new PartyMatch snaps its camera to CAM_MAX_ZOOM and only then eases out to the court framing, so the first
## ~10 frames of a sports match showed a zoomed-in court with no walls or goals. This layer is parented to the tree
## ROOT (it survives change_scene), starts as the same full white the iris ends on, holds while the court camera is
## still easing, and fades out once the camera is within Tuning.match_cover_zoom_tol of the mode's fixed framing.
## Pure presentation: it only READS the runner + camera, never moves the camera or changes its rules
## (docs/feedback/owner_2026-07-10_camera_rules.md).

const SCENE_PATH := "res://scenes/ui/MatchCover.tscn"
const SHOW_STATES := ["STAGE_INTRO", "COUNTDOWN", "COMBAT", "SUDDEN_DEATH"]

@onready var _fill: ColorRect = $Fill

var _armed_msec := 0
var _match_msec := 0           # first frame a PartyMatch was current (0 = not yet)
var _settled_frames := 0
var _match_frames := 0         # frames seen with the match current
var _fading := false
## QA readout: why the cover lifted ("settled" / "timeout" / "no_match") and after how many ms of match time.
var lift_reason := ""
var lift_after_ms := -1

## Put a cover on the tree root (call in the same frame as the scene change, while the iris covers the screen).
static func arm(tree: SceneTree) -> void:
	var old: Node = tree.root.get_node_or_null("MatchCover")
	if old != null:
		old.queue_free()
		old.name = "MatchCoverOld"
	var scene: PackedScene = load(SCENE_PATH)
	var cover: Node = scene.instantiate()
	cover.name = "MatchCover"
	tree.root.add_child(cover)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_armed_msec = Time.get_ticks_msec()

func _process(_delta: float) -> void:
	if _fading:
		return
	var now: int = Time.get_ticks_msec()
	var m: Node = get_tree().current_scene
	var cam = m.get("_camera") if m != null else null
	var is_match: bool = m is PartyMatch and cam != null and is_instance_valid(cam)
	if not is_match:
		if float(now - _armed_msec) / 1000.0 > Tuning.match_cover_load_timeout:
			_lift("no_match", 0)   # never strand a white screen (scene failed / went elsewhere)
		return
	if _match_msec == 0:
		_match_msec = now
	_match_frames += 1
	var held: float = float(now - _match_msec) / 1000.0
	if held >= Tuning.match_cover_max_hold:
		_lift("timeout", now - _match_msec)
		return
	if not SHOW_STATES.has(str(m.get("state"))):
		return
	if _camera_settled(m, cam):
		_settled_frames += 1
		if _settled_frames >= Tuning.match_cover_settle_frames:
			_lift("settled", now - _match_msec)
	else:
		_settled_frames = 0

## Settled = the camera's zoom is within match_cover_zoom_tol (relative) of the mode's fixed framing zoom and its
## centre within match_cover_pos_tol px of the framing centre. Modes without fixed framing: zoom vs the camera's
## own target (after the first few frames, so the pre-update snap target can't read as "settled").
func _camera_settled(m: Node, cam) -> bool:
	var mode = m.get("_mode")
	var framing: Variant = mode.camera_framing(m) if mode != null and mode.has_method("camera_framing") else null
	var tz: float
	var tp: Vector2
	if framing is Rect2:
		var fr: Rect2 = framing
		tz = clampf(minf(1920.0 / maxf(fr.size.x, 1.0), 1080.0 / maxf(fr.size.y, 1.0)),
			PartyMatch.CAM_MIN_ZOOM, PartyMatch.CAM_MAX_ZOOM)   # same fit PartyMatch._update_camera uses
		tp = fr.get_center()
	else:
		if _match_frames <= 3:
			return false
		tz = float(cam.get("_target_zoom"))
		tp = cam.get("_target_pos")
	var z: float = float(cam.zoom.x)
	if absf(z / maxf(tz, 0.01) - 1.0) > Tuning.match_cover_zoom_tol:
		return false
	return (cam.position as Vector2).distance_to(tp) <= Tuning.match_cover_pos_tol

func _lift(reason: String, after_ms: int) -> void:
	_fading = true
	lift_reason = reason
	lift_after_ms = after_ms
	var t := create_tween()
	t.tween_property(_fill, "modulate:a", 0.0, Tuning.match_cover_fade).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(queue_free)
