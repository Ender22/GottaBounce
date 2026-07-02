extends Node
## Decoupling signal surface (INV-12). The sim emits; presentation (Juice/HUD/audio) subscribes.
## Autoloaded as `EventBus`. (Deaths flow through KillPipeline.killed.)

signal bounced(body)
signal bounced_juicy(body, launch_speed, contact_point)
signal surface_bounced(surface, player, normal, contact_point)   # which SURFACE got hit (tier FX)
signal smashed(attacker, victim, impulse)
signal super_boosted(player)
signal exploded(center, radius)
signal powerup_used(player, id)
