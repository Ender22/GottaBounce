# Pipeline — how we validate, generate art, and test

## 1. Validation stack (our replacement for a human playtester)
| Layer | Tool | Proves |
|-------|------|--------|
| Parse gate | `godot --headless --path . --editor --quit` + grep errors | no script/scene breakage; rebuilds class cache |
| Headless sim | `scenes/Playtest.tscn` harness (physics metrics, bot wars) | numbers: speeds, ring-outs, tunneling, scores |
| **Rendered playtest** | `tools/run_game.ps1` + `python tools/gbplay.py` | what it LOOKS like and how it BEHAVES |
| Vision review | Read the captured PNGs | art quality, readability, layout, glitches |

### Rendered playtest loop (the core ritual)
```powershell
powershell -File tools/run_game.ps1 [res://scenes/X.tscn]   # kills strays, waits for port 9090
python tools/gbplay.py screenshot tools/out/a.png            # capture
python tools/gbplay.py hold D --ms 500 / key SPACE           # drive (keys or actions)
python tools/gbplay.py hold-action boost --ms 800            # input-map actions
python tools/gbplay.py eval "return $Tuning.gravity"         # live inspect/tune ANY value
python tools/gbplay.py burst tools/out/seq 12 --interval 0.25 # frame sequence for motion review
python tools/gbplay.py script tests/flight.jsonl             # scripted repeatable sequences
powershell -File tools/stop_game.ps1                         # ALWAYS stop when done
```
- Godot launches need `dangerouslyDisableSandbox: true`.
- One rendered playtest with screenshots reviewed = the minimum bar for calling anything "done."
- Screenshot bursts reviewed as a sequence = our "watching gameplay". Read 3–6 frames and judge motion.
- gbplay `eval` can set Tuning values live → tune feel without restart, then persist to Tuning.gd.

## 2. Art pipeline (bespoke, professional-quality, AI-generated)
1. **Brief** (art-director): subject, silhouette, palette, size, transparent bg, style refs attached.
2. **Generate** via ChatGPT (Chrome automation): always demand transparent background; attach
   `assets/reference/style_sheet.png` + prior sprites of the same character for consistency.
3. **Process** with `tools/art.py`: trim transparent margins, validate alpha, downscale to target,
   report dimensions. Never hand-place an untrimmed generation.
4. **Grade** (art-director reviews the processed sprite IN GAME via screenshot, not in isolation).
5. Intake convention: `assets/<category>/<name>.png` + entry in `assets/CATALOG.md` (what, prompt,
   date). CC0 Kenney placeholder use is allowed ONLY as explicitly-tagged temp with a replacement task.

## 3. Git & docs discipline
- Small commits, one per working slice/fix. No `--no-verify`.
- **After every commit: update `docs/STATUS.md`** (post-commit hook prints a reminder).
- `docs/DECISIONS.md` gets one line per irreversible/architectural choice.
- Known Godot 4 gotchas live in CLAUDE.md — check before debugging "weird" failures.

## 4. Zombie process hygiene
Stray Godot instances hog CPU, steal port 9090, and hit stale windows. `run_game.ps1` kills them
before launch; run `tools/stop_game.ps1` after every playtest session.
