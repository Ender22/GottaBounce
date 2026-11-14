class_name CharacterProfile
extends Resource
## Phase-2 character feel deltas (docs/specs/v2_character_feel_deltas.md §1). A THIN, additive,
## per-instance multiplier layer attached to each Player at spawn. Effective feel = base Tuning
## value x the profile multiplier, computed IN the Player at read time. NO base Tuning constant is
## edited by this layer — it only scales computed values at the Player's read sites.
##
## Every lever defaults to the IDENTITY value 1.0 (Standard). A fresh CharacterProfile (all fields
## untouched) reproduces today's feel byte-for-byte. Each getter DEFENSIVELY CLAMPS to the proven-
## safe per-lever range from the spec, so no authoring typo can push a value past a cap that an
## invariant depends on (INV-1, the super-still-kills floor, the flight-required traverse cap).

# --- the six levers (spec §1). All identity = 1.0. ---
@export var size_scale: float = 1.0          # scales BODY_RADIUS (collider) AND the sprite/body draw scale, together
@export var bounce_apex_mult: float = 1.0    # scales the tier TARGET HEIGHT passed to BounceResolver.resolve()
@export var air_control_mult: float = 1.0    # scales air_drift_accel AND air_drift_max_speed, together
@export var boost_power_mult: float = 1.0    # scales normal_boost_accel AND normal_boost_max_speed, together
@export var knockback_dealt_mult: float = 1.0  # scales the smash impulse THIS player APPLIES, before the smash_impulse_max clamp
@export var knockback_taken_mult: float = 1.0  # scales the smash impulse THIS player RECEIVES, before the max_speed clamp

# --- hard clamps (spec §1). Enforced on READ so no data typo can breach an invariant. ---
const SIZE_MIN := 0.90
const SIZE_MAX := 1.10
const APEX_MIN := 0.95
const APEX_MAX := 1.08          # touches flight-required traversal — never higher (Puff ships 1.08, not 1.10)
const AIR_MIN := 0.85
const AIR_MAX := 1.20
const BOOST_MIN := 0.90
const BOOST_MAX := 1.12         # INV-1: 800 * 1.12 = 896 < smash_impact_min (900) — at the limit (WK-95). Never higher.
const KB_DEALT_MIN := 0.90
const KB_DEALT_MAX := 1.12
const KB_TAKEN_MIN := 0.90      # the "a clean super still kills" floor — never lower (spec §1.1 proof)
const KB_TAKEN_MAX := 1.12

func eff_size() -> float:
	return clampf(size_scale, SIZE_MIN, SIZE_MAX)

func eff_bounce_apex() -> float:
	return clampf(bounce_apex_mult, APEX_MIN, APEX_MAX)

func eff_air_control() -> float:
	return clampf(air_control_mult, AIR_MIN, AIR_MAX)

func eff_boost_power() -> float:
	return clampf(boost_power_mult, BOOST_MIN, BOOST_MAX)

func eff_knockback_dealt() -> float:
	return clampf(knockback_dealt_mult, KB_DEALT_MIN, KB_DEALT_MAX)

func eff_knockback_taken() -> float:
	return clampf(knockback_taken_mult, KB_TAKEN_MIN, KB_TAKEN_MAX)
