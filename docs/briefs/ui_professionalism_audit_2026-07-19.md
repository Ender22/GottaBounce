# UI Professionalism Audit — Controller-Only Cleanup (2026-07-19)

**Author:** UI/UX Designer · **Status:** SPEC (programmer implements; designer approves from in-game shots)
**Trigger:** Owner flagged two unprofessional patterns and wants EVERY instance found and fixed.

## The two crimes being hunted

1. **Keyboard references in a controller-only game.** Any on-screen `ENTER`, `ESC`/`ESCAPE`, `SPACE`,
   `WASD`, arrow-key/"keyboard" text, or bare letter keys used as controls (`K`, `L`, `R`) must go.
   Genuine controller affordances (a pad-glyph chip, "press A") are fine where a hint is warranted.
2. **Control-hint TEXT standing in for real interactive controls.** A caption like
   `A / ENTER — REMATCH   B / ESC — QUIT` is NOT a control — it's a label telling you which key does
   what. Actionable end-states (rematch / quit / continue / retry / menu) must be **real, focusable,
   gamepad-navigable BUTTONS** with selection feel, exactly like `src/ui/VictoryScreen.gd`.

## The reference (already correct) — copy this

**`src/ui/VictoryScreen.gd` + `scenes/ui/VictoryScreen.tscn`** (BRAWL match-end). Real focusable
`BtnRematch / BtnSetup / BtnMenu` in an `HBoxContainer` (`$Root/Prompts`). Focus model:
`ui_left`/`ui_right` move; `menu_accept`/`ui_accept` activate; `menu_back` focuses-then-takes the safe
MENU option. Focused button = scale 1.12 springy (`TRANS_BACK`/`EASE_OUT`, 0.12s) + a looping
"press-me" breath (1.075↔1.12, 0.6s `TRANS_SINE`), unfocused = scale 1.0 @ 0.85 alpha. Emits three
signals the runner wires to real actions. **Every end-state below must reach this bar.**

---

## Prioritized offender table

Legend for FIX type: **[BTN]** convert caption → real focusable button row · **[KB]** strip/replace
keyboard reference · **[BIND]** feature is keyboard-only, needs a pad binding.

| # | Sev | File : location | Bad text / pattern | Why it's wrong | Fix |
|---|-----|-----------------|--------------------|----------------|-----|
| 1 | P0 | `src/modes/PartyMatch.gd:946` (`_tick_match_end`) | `_hud.show_match_prompt("A / ENTER — REMATCH      B / ESC — QUIT")` | BOTH crimes at once. Drives **every non-Brawl match-end** (Sports "X WINS!", Trials "TRIALS COMPLETE!"). A caption instead of buttons + keyboard refs `ENTER`/`ESC`. This is the owner's flagged TRIALS-COMPLETE screen. | **[BTN][KB]** Present a real focus button row (see §"End-state button rows" #A/#B). Delete the caption + the raw `Input.is_action_just_pressed` polling on lines 947-951; drive from the row's signals. |
| 2 | P0 | `src/ui/SportsHUD.gd:158` / `src/ui/TrialsHUD.gd:240` (`show_match_prompt`) | `_match_prompt.text = text; _match_prompt.visible = true` — a plain `Label` (`MatchPrompt`, `theme_type_variation="Hint"`) | The presentation half of #1. A hint Label can never be a focusable control. | **[BTN]** Replace `show_match_prompt(text)` with `show_match_buttons(specs) -> Array[Button]` that builds a real focus row inside the `MatchPanel` mirroring VictoryScreen's styling + focus juice. Remove the `MatchPrompt` label from both `.tscn`. |
| 3 | P1 | `scenes/ui/ScoreScreen.tscn:133` (node `Hint`) | `text = "A / ENTER — NEXT ARENA"` | Keyboard ref `ENTER`. This IS a between-stage interstitial that auto-advances (`SCORE_HOLD`), so a *hint* is defensible — but the keyboard half is not. | **[KB]** Drop `/ ENTER`. Replace with a pad-glyph chip + word: `Ⓐ CONTINUE` (reuse a `PadGlyph "A"` + Label, or the `HintStrip` "A\|Continue" chip). Keep it a hint (auto-advancing screen), just de-keyboard it. |
| 4 | P1 | `src/ui/CharacterSelect.gd:409` + `scenes/ui/CharacterSelect.tscn:276` | Random-pick bound to `KEY_R` **only**; footer legend advertises `"R\|Random"` | Worst keyboard offense: a **feature that is physically unreachable on a gamepad** in a controller-only game, and the legend teaches a keyboard key `R`. | **[BIND][KB]** Add an input action (e.g. `menu_random`) mapped to a pad button (recommend **Y** = joypad button_index 3, or a shoulder). Change line 409 to `e.is_action_pressed("menu_random")`. Change the legend glyph to that pad button (`"Y\|Random"`). |
| 5 | P2 | `src/ui/ControlsLegend.gd:13-16` (`CHIPS`) | `"kb": "WASD"/"SPACE"/"K"/"L"` + line 38 auto-selects the keyboard variant when no pad connected | Controller-only game; the keyboard branch can render `WASD/SPACE/K/L` on screen. Dead-but-shippable keyboard refs. | **[KB]** Delete the `kb` field + the `pad`-vs-`kb` selection (line 56); always emit the pad glyph. |
| 6 | P2 | `src/ui/PadGlyph.gd:16,39-46,62-69` | Keyboard-chip render path for `"SPACE"/"WASD"/"K"/"L"` text | Once #5 lands, no caller feeds keyboard text; the branch is dead keyboard-ref code. | **[KB]** Remove the non-pad/non-stick branch (keep A/B/X/Y + stick). Update the class doc comment (lines 4-7) that lists `"SPACE","K","L","WASD"`. |
| 7 | P3 | `src/ui/MatchHUD.gd:112` (`show_match_prompt`) + `MatchPrompt` node in `scenes/ui/MatchHUD.tscn` | Same caption Label as #2, on the BRAWL HUD | Currently **dead** for Brawl (Brawl routes to VictoryScreen, so this is never called) but it's the same anti-pattern sitting loaded. | **[BTN]** Delete `show_match_prompt` + the `MatchPrompt` node so the pattern can't be resurrected. If keeping the shared HUD interface, make it the new `show_match_buttons` from #2. |
| 8 | P3 | `src/ui/CharacterSelect.gd:310` (`_ready_prompt`) | `"P1 READY — (A) FIGHT!"` / `"ALL READY — (A) FIGHT!"` | NOT a keyboard ref and NOT a fake button (it's a live status line; the real launch affordance is the focusable hero card / footer `A\|Ready`). Acceptable. Only nit: `(A)` is ASCII text, not the drawn glyph. | **[KB-consistency, optional]** Swap `(A)` for a `PadGlyph "A"` chip for house consistency. Low priority — leave if time-boxed. |

**Non-offenders confirmed clean (no action):** `MainMenu` (real PLAY/OPTIONS/QUIT + real STAY/QUIT
confirm dialog), `PauseMenu` (real RESUME/RESTART/OPTIONS/QUIT-TO-MENU + a legitimate persistent
`A\|Select  B\|Resume` footer legend), the `< BACK` header on ModeSelect/CharacterSelect/ArenaSelect/
Options (real focusable `Button`s; `<` is decorative chevron), the persistent `HintStrip` footer
legends on ModeSelect / ArenaSelect / Options / CharacterSelect / PauseMenu (glyph-based `A/B/< >`,
no keyboard letters except the `R` in #4). Persistent bottom controls-legend strips are acceptable
per house rules — they are NOT the crime; only the `R` glyph inside CharacterSelect's needs #4.

---

## End-state button rows (the P0 fix, in full)

Both live end-states share one code path (`PartyMatch._tick_match_end`, `_victory == null` branch).
Build one reusable focus row on the shared HUD interface and feed it a spec per mode.

### New HUD API (replaces `show_match_prompt` on all three HUDs)

`show_match_buttons(specs: Array) -> void` where `specs = [{ "text": String, "id": StringName }, ...]`,
plus a signal `match_button_pressed(id: StringName)`. Presentation rules — **match VictoryScreen exactly**:

- Buttons in an `HBoxContainer` centered under the `MatchPanel` scoreline (separation 28-32).
- Each button: `theme_type_variation = &"ShellBtn"` (default focus = `&"ShellBtnPrimary"`), min size
  ~`Vector2(300, 84)`, `focus_mode = 2`, `pivot_offset = size * 0.5`.
- Focus model (copy `VictoryScreen._set_focus`): focused → tween scale `1.12` (`TRANS_BACK`/`EASE_OUT`,
  0.12s) + looping breath `1.075↔1.12` @ 0.6s `TRANS_SINE`; unfocused → scale `1.0`, alpha `0.85`.
- Input while armed: `ui_left`/`ui_right` cycle focus; `menu_accept`/`ui_accept` → emit
  `match_button_pressed(focused.id)`; `menu_back` → focus the QUIT button, second `menu_back` takes it
  (VictoryScreen's safe-back rule).
- Reuse the existing `PROMPT_GUARD` (1s) input lock before the row arms — keep the accidental-skip
  guard. Pop the row in with the panel's existing scale-in stagger so it feels authored, not dumped.

### Row #A — SPORTS match-end (banner `"RED/BLUE WINS!"`, from `SportsMode.match_end_banner`)

- Buttons, left→right: **`REMATCH`** (default focus) · **`QUIT TO MENU`**.
- `REMATCH` → the existing rematch handler: `_start_match()` (identical to VictoryScreen's
  `rematch_pressed`). `QUIT TO MENU` → `get_tree().change_scene_to_file(SHELL_SCENE)` (identical to the
  current `menu_back` branch at `PartyMatch.gd:951`).
- Optional 3rd for full parity with Brawl: **`CHANGE SETUP`** between them → `GameConfig.resume_setup =
  true; change_scene(SHELL_SCENE)` (reuse VictoryScreen's `setup_pressed` body). Recommend including it
  so all three modes' end-screens feel like one product.

### Row #B — TRIALS complete (banner `"TRIALS COMPLETE!"` / per-course `"COURSE CLEAR!"`, from `TrialsMode.match_end_banner`)

- Buttons, left→right: **`PLAY AGAIN`** (default focus) · **`QUIT TO MENU`**.
  (Use `PLAY AGAIN`, not `REMATCH` — Trials is co-op completion, not a versus rematch.)
- `PLAY AGAIN` → `_start_match()` (existing). `QUIT TO MENU` → `change_scene(SHELL_SCENE)` (existing).
- Optional 3rd **`CHANGE SETUP`** as in #A for consistency.

Both rows reuse handlers that **already exist** behind today's key hints — this is a surfacing job, not
new logic. Default focus is always the positive/continue action; QUIT is the `menu_back` safe target.

### Wiring change in `PartyMatch._tick_match_end` (lines 942-951)

Replace the caption + raw polling with: after `PROMPT_GUARD`, once, call
`_hud.show_match_buttons(specs_for_mode)` and connect `match_button_pressed` → a match on the id
(`&"rematch"`→dismiss/`_start_match`, `&"setup"`→resume-setup + shell, `&"menu"`→shell). Delete the
`Input.is_action_just_pressed(&"menu_accept"/&"menu_back")` handling here — the row owns input, exactly
as the `_victory != null` branch already returns early and lets VictoryScreen own it.

---

## Patterns — the rules to apply everywhere (put in the menu-system doc)

1. **Zero keyboard references on screen.** No `ENTER`, `ESC`, `SPACE`, `WASD`, arrow keys, or bare
   control letters (`K`/`L`/`R`). This is a controller-only couch game. If a control must be taught,
   use a drawn pad glyph (`PadGlyph` A/B/X/Y/stick or a `HintStrip "A|Label"` chip) — never a key name.
2. **Every keyboard-only feature must get a pad binding.** If an action can only fire from a key
   (e.g. Random on `KEY_R`), it does not exist on a gamepad. Add the input-map action + glyph, or cut
   the feature.
3. **Actionable choices = focusable buttons, never captions.** Any end-of-match / stage-complete /
   confirmation / continue-with-a-choice state presents real `Button`s you navigate with the stick/dpad
   and press A on, with obvious focus state (1.12 springy scale + breath, 0.85 dim on the rest). A line
   of text describing which button does what is banned for actionable states.
4. **Hints are allowed ONLY as genuine affordances, and only in two shapes:** (a) a persistent
   bottom controls-legend strip (`HintStrip`, glyph chips) that never replaces a real button; (b) a
   single auto-advancing interstitial's "Ⓐ Continue" pad-glyph nudge. Neither may carry a keyboard ref.
5. **One end-screen grammar.** All three modes' match-end screens use the same button row component,
   styling, focus juice, and back-behavior as `VictoryScreen`. Six screens, one product.

---

## Summary for the owner

**Total distinct offenders: 8**, across these screens:
- **Match-end / stage-complete (P0, the flagged crime): 2 live end-states** — SPORTS "X WINS!" and
  TRIALS "TRIALS COMPLETE!" — both driven by one caption (`PartyMatch.gd:946` +
  `SportsHUD`/`TrialsHUD.show_match_prompt`). Both need real REMATCH/PLAY-AGAIN + QUIT button rows.
  (A 3rd, `MatchHUD.show_match_prompt`, is the same anti-pattern sitting dead on the Brawl HUD — remove
  it too so it can't come back.)
- **Score / between-stage screen: 1** — `ScoreScreen` "A / ENTER — NEXT ARENA" keyboard ref.
- **Character select: 1** — `R|Random` is keyboard-only *and* advertised (worst keyboard offense).
- **Controls legend / glyph system: 2** — `ControlsLegend` keyboard variant + `PadGlyph` keyboard
  branch (dead-but-shippable keyboard text).
- **Character-select status line: 1 (cosmetic/optional)** — `(A)` ASCII instead of a drawn glyph.

**Most egregious (top 3):**
1. The shared `A / ENTER — REMATCH   B / ESC — QUIT` caption on Sports/Trials end — both crimes in one
   line, and it's the exact thing the owner flagged.
2. `Random` bound to keyboard `R` only — unreachable on a controller, yet the UI teaches the key.
3. `ScoreScreen`'s `A / ENTER — NEXT ARENA` keyboard ref on the between-arena screen.

**End-states that need real button rows: 2** (Sports match-end, Trials complete) — the handlers already
exist behind the key hints; this is surfacing them as focusable buttons at the VictoryScreen bar.
