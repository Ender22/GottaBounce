class_name BotProfile
extends RefCounted
## Bot difficulty dials (lethality spec §3.1). L1 = funny/flailing (self-rings-out a lot),
## L5 = scary/precise (reserved for campaign/hard mode — table ships so bot_levels stays
## hot-swappable). Difficulty is execution quality only — bots never cheat (INV-8).
## The v2 rhythm the dials serve: bounce -> hunt -> AIM -> BLAST -> dive to refuel -> repeat.

var aim_error := 0.3        # radians of random aim jitter
var reaction_time := 0.28   # seconds between decisions
var recovery_skill := 0.6   # 0..1 recovery-super aim/timing quality (low -> panic-boosts off the map)
var aggression := 0.6       # 0..1 hunt-roll probability
var target_lead := 0.5      # 0..1 lead the target by dist/super_impulse * this (the hit-rate dial)
var commit_time := 0.8      # s a rolled hunt stays TRUE (no re-rolling every tick)
var attack_range := 340.0   # px: enter AIM when hunting inside this
var refuel_floor := 25.0    # below this fuel: dive to a bounce surface; also gates attack runs
var super_aim_time := 0.6   # s max spent in AIM before firing at the best current solution
var edge_guard := 0.0       # 0..1 pursue off-stage victims and smash them outward
var leader_focus := 0.0     # 0..1 chance to target the score leader (within 1.5x attack_range)
var dodge_super := 0.0      # 0..1 per-reaction-tick chance to counter-super an incoming aim
var wounded_focus := 0.0    # 0..1 (§5.6) chance to ACQUIRE the most-damaged opponent in chase range;
                            # chase-the-wounded melee-pacing dial. Commit clause holds it once acquired.
var flee_skill := 0.0       # 0..1 (v1_kill_economy §2c) chance, on a reaction tick where the flee
                            # trigger holds, to enter the RETREAT (flee-to-heal) state. L1/L2 barely
                            # flee (brawl on, comedy preserved); high tiers gamble a heal.
# --- v1_vfx_telegraphy §5: super-aim DWELL. Commitment/telegraph ONLY (never accuracy — aim_error /
# target_lead / super_aim_time stay untouched, INV-8). On super_aim_min_chance of OFFENSIVE aims the
# bot must hold the AIM state a sampled floor of [super_aim_min, super_aim_min + 0.4] s before it may
# release, so the §3 charge tell has time to read and supers feel like decisions. Capped below the 2s
# auto-fire ceiling (super_aim_max) so a bot can never camp the aim. Dodge/recovery supers are exempt.
var super_aim_min := 0.0        # dwell floor low-bound (s); 0 = never dwell
var super_aim_min_chance := 0.0 # 0..1 fraction of offensive aims that get the dwell floor

static func for_level(level: int) -> BotProfile:
	var p := BotProfile.new()
	match clampi(level, 1, 5):
		1:
			p.aim_error = 0.70; p.reaction_time = 0.50; p.recovery_skill = 0.20; p.aggression = 0.25
			p.target_lead = 0.0; p.commit_time = 0.0; p.attack_range = 240.0; p.refuel_floor = 15.0
			p.super_aim_time = 1.4; p.edge_guard = 0.0; p.leader_focus = 0.0; p.dodge_super = 0.0
			p.wounded_focus = 0.0    # §5.6: oblivious flailer — never coordinates a finish (comedy)
			p.flee_skill = 0.0       # §2c: never flees — brawls on (comedy)
			p.super_aim_min = 0.6; p.super_aim_min_chance = 0.90   # §5: winds up hugely — "here it comes"
		2:
			p.aim_error = 0.50; p.reaction_time = 0.38; p.recovery_skill = 0.40; p.aggression = 0.45
			p.target_lead = 0.15; p.commit_time = 0.4; p.attack_range = 280.0; p.refuel_floor = 20.0
			p.super_aim_time = 1.0; p.edge_guard = 0.0; p.leader_focus = 0.0; p.dodge_super = 0.0
			p.wounded_focus = 0.25   # §5.6 (crit-21 backoff): notices sometimes; sloppy follow-up
			p.flee_skill = 0.15      # §2c: rarely flees
			p.super_aim_min = 0.55; p.super_aim_min_chance = 0.90  # §5: the beat IS the read (punchline)
		3:
			p.aim_error = 0.32; p.reaction_time = 0.28; p.recovery_skill = 0.60; p.aggression = 0.65
			p.target_lead = 0.5; p.commit_time = 0.8; p.attack_range = 340.0; p.refuel_floor = 25.0
			p.super_aim_time = 0.6; p.edge_guard = 0.3; p.leader_focus = 0.25; p.dodge_super = 0.0
			p.wounded_focus = 0.6    # §5.6 -> v1_kill_economy §3: restored wide-arena start (0.45->0.6)
			p.flee_skill = 0.5       # §2c: gambles a heal about half the time
			p.super_aim_min = 0.45; p.super_aim_min_chance = 0.75  # §5: reads as committed, still crisp
		4:
			p.aim_error = 0.16; p.reaction_time = 0.16; p.recovery_skill = 0.82; p.aggression = 0.85
			p.target_lead = 0.85; p.commit_time = 1.3; p.attack_range = 460.0; p.refuel_floor = 35.0
			p.super_aim_time = 0.3; p.edge_guard = 0.7; p.leader_focus = 0.6; p.dodge_super = 0.5
			p.wounded_focus = 0.85   # §5.6 -> v1_kill_economy §3: restored wide-arena start (0.6->0.85)
			p.flee_skill = 0.8       # §2c: disciplined — retreats to heal when hurt
			p.super_aim_min = 0.3; p.super_aim_min_chance = 0.45   # §5: mostly snappy, occasionally telegraphs
		5:
			p.aim_error = 0.06; p.reaction_time = 0.10; p.recovery_skill = 0.95; p.aggression = 0.95
			p.target_lead = 1.0; p.commit_time = 1.5; p.attack_range = 520.0; p.refuel_floor = 35.0
			p.super_aim_time = 0.18; p.edge_guard = 0.9; p.leader_focus = 0.8; p.dodge_super = 0.8
			p.wounded_focus = 0.75   # §5.6 (crit-21 backoff): (hard-mode) near-certain finisher
			p.flee_skill = 0.9       # §2c: (hard-mode) reliably retreats to heal
			p.super_aim_min = 0.25; p.super_aim_min_chance = 0.20  # §5: scary-fast; only a minority telegraphs
	return p
