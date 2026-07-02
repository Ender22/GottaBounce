extends Node
## Unified death pipeline (INV-9). Everything that kills a body routes through here so scoring,
## lives, sudden-death, and juice can all subscribe to one signal. Only bosses ever have HP;
## players die instantly from a cause. Autoloaded as `KillPipeline`.

signal killed(victim, cause, attacker)

func kill(victim, cause: StringName, attacker = null) -> void:
	if victim == null or not is_instance_valid(victim):
		return
	if victim.has_method("is_dead") and victim.is_dead():
		return
	if victim.has_method("mark_dead"):
		victim.mark_dead()
	killed.emit(victim, cause, attacker)
