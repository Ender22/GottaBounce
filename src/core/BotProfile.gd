class_name BotProfile
extends RefCounted
## The 4 difficulty dials (GAME_DESIGN §8). L1 = funny/flailing (self-rings-out a lot),
## L5 = scary/precise. Difficulty is execution quality only — bots never cheat (INV-8).

var aim_error := 0.3        # radians of random aim jitter
var reaction_time := 0.28   # seconds between decisions
var recovery_skill := 0.6   # 0..1 chance of a clean edge recovery (low → panic-boosts off the map)
var aggression := 0.6       # 0..1 hunt vs passive + super-boost eagerness

static func for_level(level: int) -> BotProfile:
	var p := BotProfile.new()
	match clampi(level, 1, 5):
		1: p.aim_error = 0.70; p.reaction_time = 0.50; p.recovery_skill = 0.20; p.aggression = 0.25
		2: p.aim_error = 0.50; p.reaction_time = 0.38; p.recovery_skill = 0.40; p.aggression = 0.45
		3: p.aim_error = 0.32; p.reaction_time = 0.28; p.recovery_skill = 0.60; p.aggression = 0.60
		4: p.aim_error = 0.18; p.reaction_time = 0.18; p.recovery_skill = 0.80; p.aggression = 0.78
		5: p.aim_error = 0.06; p.reaction_time = 0.10; p.recovery_skill = 0.95; p.aggression = 0.95
	return p
