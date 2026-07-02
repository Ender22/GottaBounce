class_name Forces
## Unified radial impulse (INV-3): one function that pushes ALL impulsable bodies (players + props)
## away from a center, stronger closer in. Bodies opt in via the "impulsable" group and an
## apply_impulse_vector(Vector2) method. Used by bombs/explosions (FEEL §4.1).

static func apply_radial_impulse(from_node: Node, center: Vector2, radius: float, impulse_center: float) -> void:
	if from_node == null or not is_instance_valid(from_node):
		return
	for b in from_node.get_tree().get_nodes_in_group("impulsable"):
		if not is_instance_valid(b) or not b.has_method("apply_impulse_vector"):
			continue
		var to_body: Vector2 = b.global_position - center
		var dist := to_body.length()
		if dist > radius:
			continue
		var falloff := 1.0 - dist / radius          # linear falloff (FEEL §4.1)
		var dir := to_body.normalized() if dist > 0.001 else Vector2.UP
		b.apply_impulse_vector(dir * impulse_center * falloff)
