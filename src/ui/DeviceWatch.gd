extends Node
## WK-28b DeviceWatch — what a controller hot-plug MEANS for the screen you are on (COUCH_CONVENTIONS CC-3.4 / CC-3.5,
## audit C-07 / R-32). InputRouter answers "which device?" and emits device_lost / device_found; this node (a child
## of the InputRouter autoload, created by it, no class_name, no autoload entry) decides what happens:
##
##   * a pad driving a human seat is lost in a LIVE match (any PartyMatch state but BOOT / MATCH_END)
##       -> the match auto-pauses under a DisconnectOverlay (scenes/ui/DisconnectOverlay.tscn) for that seat.
##   * the same pad comes back while the overlay waits -> the overlay says so ("IS BACK!"); it still has to press A.
##   * RESUME WITHOUT P# -> make_cpu(): the seat keeps its goat, colour and P# but an InputBot drives it (HUD card
##     sub-tag "CPU"). Mid-play, A on that seat's old pad or on any device that drives no seat takes it back
##     (rebind()), with a toast. On a RESTART / REMATCH, a seat still bound to a pad that is gone starts as a CPU.
##   * every other hot-plug -> a small toast (DeviceToast): "CONTROLLER CONNECTED" / "CONTROLLER DISCONNECTED". A pad
##     lost from a seat in the Herd Lobby gets no toast (the slot's own DISCONNECTED face says it, WK-28a).
##
## Rebinding a seat (takeover / reclaim / back from CPU) goes through the existing public seams only: Player.set_provider
## with InputHuman.for_device / InputBot.new, PartyMatch.human_device_keys, MatchConfig.human_devices (so a rematch
## keeps the new device), InputRouter.join / leave and GameConfig.lobby (so CHANGE SETUP keeps it, CC-4.7).
## No edits to PartyMatch / Player / InputBot (held by another lane).

const OVERLAY_SCENE := "res://scenes/ui/DisconnectOverlay.tscn"
const TOAST_SCENE := "res://scenes/ui/DeviceToast.tscn"
const GHOST_BOT := "res://src/core/GhostBot.gd"
const NEUTRAL := Color("#ffd23f")
const RED := Color("#ff4b3a")

var toast = null          # DeviceToast (CanvasLayer child)
var overlay = null        # the open DisconnectOverlay, or null
var cpu_seats := {}       # player index -> the pad key it had when it went CPU (for _cpu_match only)
var _cpu_match = null     # the match instance cpu_seats belongs to
var _gone := {}           # pad key -> true: lost and not heard from since (found / any press clears it)
var _seen_match = null    # last live match checked for seats bound to gone pads
# QA feed (eval): what happened, newest last.
var log_lines: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var router: Node = get_parent()
	router.connect("device_lost", _on_lost)
	router.connect("device_found", _on_found)
	get_tree().root.window_input.connect(_on_window_input)
	toast = load(TOAST_SCENE).instantiate()
	add_child(toast)

func _log(s: String) -> void:
	log_lines.append(s)
	if log_lines.size() > 40:
		log_lines.pop_front()

# ------------------------------------------------------------------ match helpers (duck-typed, no class refs)

func _any_match() -> Node:
	var sc := get_tree().current_scene
	if sc == null or not sc.has_method("human_index_for_device") or not ("players" in sc):
		return null
	return sc

func _is_live(m: Node) -> bool:
	if m == null or not is_instance_valid(m):
		return false
	var st: String = str(m.get("state"))
	return st != "BOOT" and st != "MATCH_END"

func _live_match() -> Node:
	var m := _any_match()
	return m if _is_live(m) else null

## Device key driving player h ("kb" / "pad:N" / "" legacy any-device / "none"); "" for a bot.
func seat_key(m, h: int) -> String:
	if not m.is_human_player(h):
		return ""
	var prov = m.players[h].provider
	if prov == null or not ("device_key" in prov):
		return ""
	return str(prov.device_key)

func _seat_for_key(m, key: String) -> int:
	if key == "":
		return -1
	for h in range(m.players.size()):
		if m.is_human_player(h) and not _is_cpu_seat(m, h) and seat_key(m, h) == key:
			return h
	return -1

func _is_cpu_seat(m, h: int) -> bool:
	return m == _cpu_match and cpu_seats.has(h)

## True when `key` drives a human seat that is neither lost (in `lost`) nor CPU-driven.
func is_driver(m, key: String, lost: Array) -> bool:
	var h: int = _seat_for_key(m, key)
	return h >= 0 and not lost.has(h)

func has_active_driver(m, lost: Array) -> bool:
	for h in range(m.players.size()):
		if m.is_human_player(h) and not lost.has(h) and not _is_cpu_seat(m, h):
			var k: String = seat_key(m, h)
			if k != "" and k != "none":
				return true
	return false

## A device that drives no seat (and is not one of the overlay's lost pads) — it may take a seat over.
func is_free_device(m, key: String) -> bool:
	if _seat_for_key(m, key) >= 0:
		return false
	if overlay != null and is_instance_valid(overlay) and overlay.lost_seat_of(key) >= 0:
		return false
	return true

## RESUME WITHOUT only makes sense if some other human keeps playing (else it is a bots-only match).
func others_playing(m, lost: Array) -> bool:
	return has_active_driver(m, lost)

func _tag(m, h: int) -> String:
	var n: int = m.player_label(h)
	return ("P%d" % n) if n > 0 else str(m.player_name(h))

# ------------------------------------------------------------------ hot-plug

func _on_lost(key: String) -> void:
	if InputRouter.is_pad(key):
		_gone[key] = true
	if overlay != null and is_instance_valid(overlay) and overlay.lost_seat_of(key) >= 0:
		overlay.on_lost_again(key)
		return
	var m := _any_match()
	if m != null:
		var h: int = _seat_for_key(m, key)
		if h >= 0:
			if _is_live(m):
				_open_overlay(m, h, key)
			else:
				_toast("CONTROLLER DISCONNECTED", _tag(m, h), m.player_color(h))
			return
		_toast("CONTROLLER DISCONNECTED")
		return
	if InputRouter.is_joined(key) and _lobby_visible():
		return   # WK-28a: the lobby slot shows DISCONNECTED itself
	_toast("CONTROLLER DISCONNECTED")

func _on_found(key: String) -> void:
	_gone.erase(key)
	if overlay != null and is_instance_valid(overlay) and overlay.lost_seat_of(key) >= 0:
		overlay.on_found(key)
		return
	var m := _any_match()
	if m != null and m == _cpu_match:
		for h in cpu_seats.keys():
			if str(cpu_seats[h]) == key:
				_toast("TO PLAY AGAIN", _tag(m, int(h)), m.player_color(int(h)), "A")
				return
	_toast("CONTROLLER CONNECTED")

func _lobby_visible() -> bool:
	var sc := get_tree().current_scene
	if sc == null:
		return false
	var lobby := sc.find_child("HerdLobby", true, false)
	return lobby is CanvasItem and (lobby as CanvasItem).is_visible_in_tree()

func _toast(text: String, tag: String = "", col: Color = NEUTRAL, icon: String = "pad") -> void:
	_log("toast %s %s" % [tag, text])
	if toast != null and is_instance_valid(toast):
		toast.show_toast(text, tag, col, icon)

# ------------------------------------------------------------------ overlay

func _open_overlay(m, h: int, key: String) -> void:
	_log("lost %s -> seat %d" % [key, h])
	if overlay == null or not is_instance_valid(overlay):
		var under = m.get("_pause_overlay")
		if under != null and is_instance_valid(under) and under.has_method("set_suspended"):
			under.set_suspended(true)
		else:
			under = null
			if m.has_method("set_match_overlays_hidden"):
				m.set_match_overlays_hidden(true)
		overlay = load(OVERLAY_SCENE).instantiate()
		overlay.setup(self, m, under)
		overlay.add_lost(h, key)
		m.add_child(overlay)
		get_tree().paused = true
		return
	overlay.add_lost(h, key)

func overlay_closed(o) -> void:
	if overlay == o:
		overlay = null

# ------------------------------------------------------------------ seat rebinding

## Player h is now driven by device `key` (the lost pad reclaiming, a free device taking over, or a CPU seat being
## taken back). Every record of "who drives h" follows, so rematch / CHANGE SETUP keep the new device.
func rebind(m, h: int, key: String) -> void:
	var old: String = seat_key(m, h)
	if cpu_seats.has(h) and m == _cpu_match:
		old = str(cpu_seats[h])
	var prov = InputHuman.for_device(key)
	prov.swallow_until_release()   # CC-5.7: the A that took the seat must not also boost
	m.players[h].set_provider(prov)
	var hk: PackedStringArray = m.human_device_keys
	if h < hk.size():
		hk[h] = key
		m.human_device_keys = hk
	var cfg = m.get("_config")
	if cfg != null and h < cfg.human_devices.size():
		var devs: PackedStringArray = cfg.human_devices
		devs[h] = key
		cfg.human_devices = devs
	var label: int = m.player_label(h)
	if old != key and old != "":
		InputRouter.leave(old)
	if label > 0:
		InputRouter.join(key, label - 1)
		if label - 1 < GameConfig.lobby.size() and typeof(GameConfig.lobby[label - 1]) == TYPE_DICTIONARY:
			(GameConfig.lobby[label - 1] as Dictionary)["device"] = key
	var gd = m.get("_ghost_dir")
	if gd != null and is_instance_valid(gd) and (gd.ghosts as Dictionary).has(h):
		gd.ghosts[h].provider = prov
	_gone.erase(key)
	var was_cpu: bool = cpu_seats.erase(h) and m == _cpu_match
	if was_cpu:
		_push_cpu_tags(m)
	InputRouter.rumble(key, 0.4, 0.6, 0.18)
	_log("rebind seat %d %s -> %s" % [h, old, key])

## RESUME WITHOUT P#: the seat plays on as a CPU at the match's CPU difficulty (MIXED -> Tuning.disconnect_cpu_level).
func make_cpu(m, h: int) -> void:
	var key: String = seat_key(m, h)
	var cfg = m.get("_config")
	var lvl: int = Tuning.disconnect_cpu_level
	if cfg != null and int(cfg.bot_difficulty) > 0:
		lvl = int(cfg.bot_difficulty)
	var p = m.players[h]
	p.set_provider(InputBot.new(p, m, lvl))
	if _cpu_match != m:
		cpu_seats = {}
		_cpu_match = m
	cpu_seats[h] = key
	var gd = m.get("_ghost_dir")
	if gd != null and is_instance_valid(gd) and (gd.ghosts as Dictionary).has(h):
		var g = gd.ghosts[h]
		g.provider = load(GHOST_BOT).new(g, gd, m, g.global_position)
	_push_cpu_tags(m)
	_log("cpu seat %d (was %s, level %d)" % [h, key, lvl])

## HUD cards: a CPU-driven human seat keeps its NAME (P2) but its sub-tag reads "CPU" (CC-8.5 / CC-8.3 honesty).
func _push_cpu_tags(m) -> void:
	var hud = m.get("_hud")
	if hud == null or not is_instance_valid(hud) or not hud.has_method("set_labels"):
		return
	var subs: Array = m.player_subtags()
	if m == _cpu_match:
		for h in cpu_seats.keys():
			if int(h) < subs.size():
				subs[int(h)] = "CPU"
	hud.set_labels(m.player_names(), subs)

# ------------------------------------------------------------------ mid-play take-back + rematch

func _on_window_input(e: InputEvent) -> void:
	if not e.is_pressed() or e.is_echo():
		return
	var k: String = InputRouter.device_key(e)
	if k == "":
		return
	if e is InputEventJoypadMotion:
		return
	_gone.erase(k)   # a device that presses something is here (a simulated "lost" pad can still send)
	if cpu_seats.is_empty() or (overlay != null and is_instance_valid(overlay)) or get_tree().paused:
		return
	var m := _live_match()
	if m == null or m != _cpu_match:
		return
	if not (e.is_action_pressed("boost") or e.is_action_pressed("ui_accept")):
		return
	if _seat_for_key(m, k) >= 0:
		return   # already drives a seat
	var pick := -1
	for h in cpu_seats.keys():
		if str(cpu_seats[h]) == k:
			pick = int(h)
	if pick < 0:
		for h in cpu_seats.keys():
			if pick < 0 or int(h) < pick:
				pick = int(h)
	var own: bool = str(cpu_seats[pick]) == k
	rebind(m, pick, k)
	_toast("IS BACK!" if own else "TAKEN OVER", _tag(m, pick), m.player_color(pick), "kb" if k == InputRouter.KB else "pad")

func _process(_dt: float) -> void:
	var m := _live_match()
	if m != null and m == _cpu_match and not cpu_seats.is_empty():
		_ghost_bots(m)
	if m == null or m == _seen_match:
		return
	_seen_match = m
	if _gone.is_empty():
		return
	# RESTART / REMATCH with a seat still bound to a pad that is gone: it starts as a CPU (not an idle goat)
	for h in range(m.players.size()):
		if m.is_human_player(h) and _gone.has(seat_key(m, h)):
			make_cpu(m, h)
			_toast("CONTROLLER STILL OUT · PLAYING AS CPU", _tag(m, h), m.player_color(h))

## A CPU seat that gets eliminated becomes a ghost driven by the provider it had (GhostDirector: "human -> own
## provider"), i.e. the InputBot, which steers a living goat. Give such a ghost a GhostBot instead.
func _ghost_bots(m) -> void:
	var gd = m.get("_ghost_dir")
	if gd == null or not is_instance_valid(gd):
		return
	for h in cpu_seats.keys():
		var gh: Dictionary = gd.ghosts
		if not gh.has(h):
			continue
		var g = gh[h]
		if is_instance_valid(g) and g.provider is InputBot:
			g.provider = load(GHOST_BOT).new(g, gd, m, g.global_position)
