# Decision Log

One line per significant/irreversible decision. Newest first.

- **2026-07-02** Keep the core premise (bounce+jetpack party brawler, Duck Game × Smash) and the
  6 GDD pillars; the old game's failure was execution, not design.
- **2026-07-02** Art direction = "Glossy Toybox" (see VISION.md): blob Bouncers, toy-world arenas,
  matching the v1 generated title screen. Chosen for appeal AND reliable AI generatability.
- **2026-07-02** Engine: Godot 4.7 / GDScript (installed, proven, tooling exists). Renderer:
  gl_compatibility. Physics at 120 ticks/s.
- **2026-07-02** Rebuild in fresh repo; port proven seams from old project selectively rather than
  forking it wholesale (old repo stays untouched as reference).
- **2026-07-02** Validation = rendered playtest via in-game TCP server (port 9090) + gbplay.py
  client + vision review of screenshots. The human owner is NOT in the loop.
- **2026-07-02** Levels stay JSON-driven (geometry+theme separated); UI must be .tscn+Theme;
  input goes through a proper action map (old project polled raw keys — rebuilt).
