class_name Hazard
extends Area2D
## Instakill hazard (spikes/laser). Any Killable body that touches it dies (INV-9).
## Lethal only while combat is live (the shared hazard doctrine — see Crusher/SpinningHammer/Bomb/
## FallingDebris): suppressed until EventBus.combat_started and re-suppressed on combat_ended, so a
## player at spawn during intro/countdown can never be killed pre-gun and left stuck-dead. Because
## this hazard kills via body_entered (not an overlap poll), combat-start also re-scans bodies
## already touching it so a pre-combat overlap still dies the instant the gun fires.

var _lethal := false

func _ready() -> void:
	collision_mask = (1 << 0) | (1 << 1)   # players (1) + enemies/props (2)
	monitoring = true
	body_entered.connect(_on_body_entered)
	if not EventBus.combat_started.is_connected(_on_combat_started):
		EventBus.combat_started.connect(_on_combat_started)
	if not EventBus.combat_ended.is_connected(_on_combat_ended):
		EventBus.combat_ended.connect(_on_combat_ended)

func _on_combat_started() -> void:
	_lethal = true
	for body in get_overlapping_bodies():
		_on_body_entered(body)

func _on_combat_ended() -> void:
	_lethal = false

func _on_body_entered(body) -> void:
	if _lethal and is_instance_valid(body) and body.has_method("kill"):
		body.kill(&"hazard", null)
