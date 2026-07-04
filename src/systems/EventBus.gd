extends Node
## Decoupling signal surface (INV-12). The sim emits; presentation (Juice/HUD/audio) subscribes.
## Autoloaded as `EventBus`. (Deaths flow through KillPipeline.killed.)

signal bounced(body)
signal bounced_juicy(body, launch_speed, contact_point)
signal surface_bounced(surface, player, normal, contact_point)   # which SURFACE got hit (tier FX)
signal smashed(attacker, victim, impulse)
signal smash_landed(attacker, victim, info)   # kill-zone spec §8: hit-solidity QA feed (info Dictionary)
signal super_boosted(player)
signal super_fired(player, fuel_at_fire, aim_time, auto_fired)   # round_stats QA feed (lethality §8)
signal exploded(center, radius)
signal powerup_used(player, id)

# --- flow / feedback events (added for the audio system, 2026-07-04) ---
# The sim emits these at the exact moment the event occurs; AudioManager (and any future
# presentation) subscribes. Single-line emits at the existing trigger sites — NOT scattered
# play() calls (INV-12). See docs/feedback/owner_2026-07-04_arena_variety.md §2 for the event list.
signal countdown_tick(n)              # n = 3 / 2 / 1 during COUNTDOWN
signal combat_started()               # "BOUNCE!" — the starting gun, each stage
signal match_started()                # a fresh match begins (music (re)start)
signal match_won(winner_idx)          # match-end hero moment
signal first_blood(attacker_idx)      # first credited kill of the match
signal two_left()                     # down to the final two (>=3 started)
signal player_damaged(player, level)  # transient damage escalated to Lv1 / Lv2
signal player_healed(player)          # transient damage fully healed back to Lv0
signal powerup_picked(player, id)     # a bubble was collected into the held slot
