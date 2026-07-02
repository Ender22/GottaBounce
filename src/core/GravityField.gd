extends Node
## Gravity as a queried field (INV-1). v0 returns global down; P8 adds gravity_source contributors
## (radial planetoids / directional walls) resolved by zone/priority. NEVER hardcode gravity elsewhere.
## Autoloaded as `GravityField`.

var _sources: Array = []  # P8: Array[GravitySource]

func get_gravity_at(pos: Vector2) -> Vector2:
	if _sources.is_empty():
		return Vector2(0.0, Tuning.gravity)
	# P8: pick highest-priority source whose area contains pos (blend in transition band); else down.
	for src in _sources:
		if src.has_method("contains") and src.contains(pos):
			return src.gravity_at(pos)
	return Vector2(0.0, Tuning.gravity)

func register(src) -> void:
	if src not in _sources:
		_sources.append(src)

func unregister(src) -> void:
	_sources.erase(src)
