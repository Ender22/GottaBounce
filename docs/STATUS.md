# STATUS — current state & next steps

> The single always-current handoff doc. Update after EVERY commit. A fresh context reads this first.

**Last updated:** 2026-07-02 (session 1)

## Where we are
Session 1: studio foundation. Repo initialized, validation tooling built and **proven end-to-end**
(rendered game driven via `tools/gbplay.py` → input injection moved a physics ball, screenshots
captured and visually reviewed). Old project surveyed (see below). Vision set (`docs/VISION.md`).

## Key facts
- Old project at `D:\Dropbox\MyGames\GottaBounce` = well-architected but unpolished prototype.
  Survey verdict: **keep** design docs, Tuning pattern, physics seams (BounceResolver/GravityField/
  Forces/InputIntent/EventBus/KillPipeline), JSON level pipeline, Player.gd physics logic, InputBot,
  owner's Hoptron music. **Rebuild:** all UI (as .tscn+Theme), all art, input action map, feel, content.
- Godot 4.7 console exe: `C:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe`.
- `tools/run_game.ps1` quoting bug fixed (spaces in path → launched the OLD project; now quoted).
- PS1 files must be ASCII-only (PowerShell 5.1 reads them as ANSI → em-dashes break parsing).
- Smoke test scene `scenes/SmokeTest.tscn` proves the loop; replace as main scene when game exists.

## In flight
- [x] Studio foundation (repo, docs, roles, hooks)
- [x] Validation tooling core (gbplay + run/stop scripts) — proven
- [ ] Port core seams from old project (headless Playtest harness port still pending)
- [ ] v0 vertical slice: movement feel + one polished arena + round loop
- [ ] Art pipeline (ChatGPT + tools/art.py trim tool)

## Next actions
1. Port core seams (`Tuning`, `BounceResolver`, `GravityField`, `Forces`, `InputIntent`,
   `InputHuman`→action map, `InputBot`, `KillPipeline`, `EventBus`) + JSON level loader.
2. Build v0 arena + player, tune feel via live gbplay eval loop.
3. Art pipeline + first bespoke character sprite set.

## Watch out for
- Always `tools/stop_game.ps1` after playtests (zombies steal port 9090).
- Godot shell calls need `dangerouslyDisableSandbox: true`; prefer Bash tool for Godot invocations
  (PowerShell 2>&1 wrapping breaks exit codes).
- Rebuild class cache (`--editor --quit`) after adding any `class_name` script.
