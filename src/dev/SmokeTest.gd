extends Node2D

# Smoke test for the studio validation loop: proves rendering, input injection,
# physics, and the TCP interaction server all work end-to-end.

var _ball: RigidBody2D
var _label: Label
var _input_log: Array[String] = []

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.14, 0.24)
	bg.size = Vector2(1920, 1080)
	add_child(bg)

	_label = Label.new()
	_label.text = "SMOKE TEST — validation loop online"
	_label.position = Vector2(60, 40)
	_label.add_theme_font_size_override("font_size", 48)
	add_child(_label)

	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(960, 1000)
	var floor_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(1700, 60)
	floor_shape.shape = rect
	floor_body.add_child(floor_shape)
	var floor_vis := ColorRect.new()
	floor_vis.color = Color(0.35, 0.75, 0.45)
	floor_vis.size = Vector2(1700, 60)
	floor_vis.position = Vector2(-850, -30)
	floor_body.add_child(floor_vis)
	add_child(floor_body)

	_ball = RigidBody2D.new()
	_ball.position = Vector2(960, 200)
	_ball.physics_material_override = PhysicsMaterial.new()
	_ball.physics_material_override.bounce = 0.8
	var ball_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 40
	ball_shape.shape = circle
	_ball.add_child(ball_shape)
	add_child(_ball)

func _draw() -> void:
	pass

func _process(_delta: float) -> void:
	queue_redraw()
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir.length() > 0.1:
		_ball.apply_central_force(dir * 2000.0)
		_note("move %s" % dir)
	if Input.is_action_just_pressed("boost"):
		_ball.linear_velocity = Vector2(_ball.linear_velocity.x, -900)
		_note("BOOST")
	_label.text = "SMOKE TEST — ball at (%.0f, %.0f) vel (%.0f, %.0f)\ninput: %s" % [
		_ball.position.x, _ball.position.y,
		_ball.linear_velocity.x, _ball.linear_velocity.y,
		" | ".join(_input_log.slice(-3))]
	# Draw the ball via a canvas item each frame
	if not _ball.has_node("vis"):
		var vis := ColorRect.new()
		vis.name = "vis"
		vis.color = Color(1.0, 0.55, 0.2)
		vis.size = Vector2(80, 80)
		vis.position = Vector2(-40, -40)
		_ball.add_child(vis)

func _note(s: String) -> void:
	if _input_log.is_empty() or _input_log[-1] != s:
		_input_log.append(s)
		if _input_log.size() > 20:
			_input_log = _input_log.slice(-20)
