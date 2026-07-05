class_name CharacterProfiles
## Phase-2 character registry (docs/specs/v2_character_feel_deltas.md §3). Maps a character_id to a
## fresh CharacterProfile carrying that hero's feel deltas. ANY unknown id, "" , "bouncer", "billy",
## or "standard" resolves to the all-identity Standard profile — so absence == today's feel.
##
## Data table (not one .tres per character) is the cleaner shape here: 6 heroes x 6 floats is a
## single greppable source of truth, avoids hand-authoring .tres/uid files, and still yields typed
## CharacterProfile Resource instances with the spec's on-read clamps. Every profile returned is a
## FRESH instance (per-Player mutation safety); levers unlisted for a hero stay at identity 1.0.

## Standard / baseline (Billy) — all levers identity. Byte-for-byte today's feel.
static func standard() -> CharacterProfile:
	return CharacterProfile.new()

## id -> profile. Fresh instance every call. Unknown id -> Standard.
static func for_id(id: String) -> CharacterProfile:
	var p := CharacterProfile.new()
	match id:
		"pogo":   # featherweight mobility glass-cannon: springiest, small, flies furthest when caught
			p.size_scale = 0.92
			p.bounce_apex_mult = 1.08
			p.knockback_taken_mult = 1.10
		"butch":  # heavyweight smash bro: hits hardest (sub-cap), shrugs grazes, biggest target
			p.knockback_dealt_mult = 1.12
			p.knockback_taken_mult = 0.90
			p.size_scale = 1.08
		"ziggy":  # technician pilot: tightest steering + best boost/glide, zero combat edge
			p.air_control_mult = 1.18
			p.boost_power_mult = 1.08
		"puff":   # floaty comic: highest/hangiest air, but drifty (hard to aim that big air)
			p.bounce_apex_mult = 1.08   # spec §2: ship Puff at 1.08 (the APEX cap), NOT the aspirational 1.10
			p.air_control_mult = 0.88
		"vex":    # slippery trickster (near-baseline): small + slippery, no offensive buff
			p.size_scale = 0.96
			p.air_control_mult = 1.08
		"billy", "bouncer", "standard", "":
			pass   # THE baseline — all identity
		_:
			pass   # unknown id -> Standard (absence == today's feel)
	return p
