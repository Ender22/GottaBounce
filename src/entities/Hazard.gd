class_name Hazard
extends Area2D
## Instakill hazard (spikes/crusher/laser). Any Killable body that touches it dies (INV-9).

func _ready() -> void:
	collision_mask = (1 << 0) | (1 << 1)   # players (1) + enemies/props (2)
	monitoring = true
	body_entered.connect(_on_body_entered)

func _on_body_entered(body) -> void:
	if body.has_method("kill"):
		body.kill(&"hazard", null)
