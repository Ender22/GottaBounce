class_name BounceResolver
## Body-agnostic bounce (INV-2). Pure function: given an incoming velocity, the surface normal
## (pointing AWAY from the surface), and the tier's target height, return the post-bounce velocity.
## Caller applies it. Works along the LOCAL gravity vector (pass its magnitude) so it's gravity-field
## correct (INV-1). Used by players now, props later — same math.

## `normal`      : surface outward normal (unit-ish; will be normalized)
## `tier_height` : target bounce height in px (Tuning.bounce_height_*)
## `gravity_mag` : magnitude of local gravity at the body (GravityField.get_gravity_at().length())
## `supercharged`: boost-bounce supercharge active (FEEL §3.4)
static func resolve(velocity: Vector2, normal: Vector2, tier_height: float, gravity_mag: float, supercharged: bool = false) -> Vector2:
	normal = normal.normalized()
	var launch_height: float = tier_height
	if supercharged:
		launch_height *= Tuning.supercharge_bounce_mult
	# min-bounce floor — always kick back up, never settle (INV-11)
	launch_height = max(launch_height, Tuning.min_bounce_height)
	var launch_speed: float = sqrt(2.0 * gravity_mag * launch_height)
	# split incoming velocity into normal + tangential components
	var v_normal: Vector2 = velocity.dot(normal) * normal
	var v_tangential: Vector2 = velocity - v_normal
	# tangential preserved (damped); normal REPLACED by launch along +normal (FEEL §2.2)
	return v_tangential * Tuning.tangential_retention + normal * launch_speed

## Elastic ricochet for bumper walls (FEEL §2.4): reflect, preserving speed * restitution.
static func resolve_bumper(velocity: Vector2, normal: Vector2) -> Vector2:
	normal = normal.normalized()
	return velocity.bounce(normal) * Tuning.bumper_restitution
