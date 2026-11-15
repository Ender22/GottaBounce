# UX verdict: lobby pass 6e57111 (WK-28a, WK-138, WK-83)

ui-ux-designer, 2026-11-15. Graded from the builder's 1080p captures in `tools/out/wk/` (WK-28a_01..11, WK-138_*, WK-83_*).
I did not launch Godot (the machine is at its agent cap). Checked against COUCH_CONVENTIONS CC-1.6/1.7, 3.5, 4.3, 4.4, 6.2, and
UX4-02/03/04/05/17.

| Item | Verdict |
|---|---|
| WK-28a lobby disconnect grace | **Ship** |
| WK-138 honest lobby prompts | **Fix** (2 cheap items, below) |
| WK-83 nudge + TV safe area | **Ship** (one non-blocking follow-up) |

## WK-28a: Ship
- The DISCONNECTED panel reads from across the room. A tilted red DISCONNECTED ribbon over a greyed bust, the P-colour frame and
  goat name kept, "PLUG IT BACK IN · N", and an A glyph whose ring drains (`_01`, `_02`). Colour is never the only cue: there is a word,
  a number and a ring.
- The take-over glyph is truthful. "A / ENTER TAKE OVER" shows only while the keyboard is free (`_04`, `_08`, `_11`). It shows A alone
  when the keyboard is seated (`_01`, `_10`). The P4 "ENTER KEYBOARD" join hint is withheld while a seat is DISCONNECTED, so Enter
  never offers two jobs.
- The goat is held: the other panel shows "TAKEN BY P2" while P2 is DISCONNECTED (`_01`). When the window expires, the seat goes back
  to PRESS A TO JOIN (`_03`). Sports keeps the team (`_11`). Losing the RULES owner closes the flip and keeps the values (FIRST TO 8
  survives, `_08`).
- `_01`/`_02` show the device label dark on the dark well (unreadable). `_04` onward show it cream, and `show_disconnected` now sets
  CREAM. Those two shots were taken before that fix. No action needed.
- Evidence gap (not blocking): `_06_other_pad_takes_over` shows P2 **READY**. The code starts a different device in PICKING. That
  frame was probably taken after a second A. On the next rendered pass, capture the frame straight after the take-over A, showing
  PICKING.

## WK-138: Fix
What passes:
- The footer has 4 verbs, and no key carries two meanings (keyboard-only `kb_only_final`, pad-only `pad_only`).
- GO appears only on the READY TO FIGHT! banner, with dual "≡ / ENTER" glyphs on a mixed couch (`banner_mixed_go_only_here`).
- A taken goat reads TAKEN in grey on the prompt row (`mixed_taken`).
- The chip shows ESC for keyboard-only and B for any pad, matching CC-1.6.
- The WK-82 ruling holds in code: a seated B never arms the ring.

Fixes:
1. **Chip copy (choice 4).** "NOT IN? HOLD: EXIT" reads like a config key. "HOLD: EXIT" with a colon is a programmer tell, and
   "NOT IN" is not a word the lobby uses anywhere else (the panels say JOIN).
   - Change `HerdLobby._refresh_back_chip` to `"NOT JOINED? HOLD TO EXIT"`. Keep font size 30 (above the 28 floor). The chip grows
     about 90 px, to x ≈ 500, still well clear of the title at x ≈ 670.
2. **The empty lobby has two exit prompts (choice 5).** Chip "B BACK" plus footer "B BACK OUT" fails the WK-138 Accept line "exactly
   one exit prompt". RANDOM and GOAT/FLAIR are also untrue when nobody is seated (CC-1.7).
   - When `_joined_count() == 0`, hide the footer BACK OUT, RANDOM and GOAT/FLAIR chips, and relabel JOIN / READY to `JOIN`.
   - Restore them all when the first seat fills. This goes in the same refresh as the chip.
   - `_joined_count` already counts DISCONNECTED seats, so a lobby holding only a DISCONNECTED seat keeps the full footer and the
     hold-exit chip. That is correct.
   - Accept: a re-shot of `nobody_joined_back_chip` shows exactly one B prompt.

## WK-83: Ship
- Nudge (`nudge_waiting`): the PICKING panel's status bar lights a gold plate, and the DISCONNECTED panel's countdown flashes gold.
  The room sees who it is waiting on, and a DISCONNECTED seat counts as "waiting on". That is the right call.
- Safe area: the header chips start at y ≈ 58 and the footers end at y ≈ 1005-1020 on the lobby, arena select and Options. All of
  them sit inside the 54-1026 band UX4-04 asked for.
- Non-blocking follow-up (file it as P3, do not hold this commit): horizontally, the BACK chip (x ≈ 50) and the mode chip (to
  x ≈ 1870) still sit inside the outer 5 % (96 px). Move the `MenuScreen` header chips to x ≥ 96 / ≤ 1824. My UX4-04 spec only
  named the vertical band, so this is new scope, not a miss.
- Noticed, out of scope: the arena select footer ("Back", "Choose") and Options ("Open") use title case, while the lobby uses all
  caps. Fold this into WK-139 / the end-screen kit consistency pass.

## Builder's open choices
1. **The same pad reclaims its old state, and a different device starts PICKING: APPROVED.** A new pair of hands must confirm the
   goat themselves, or someone could launch a pick they never made. Keeping the goat, flair and colour on take-over is the right
   convenience. One A press re-readies.
2. **A DISCONNECTED seat blocks the READY banner: APPROVED.** During grace the seat is still a joined player (CC-4.4). Launching
   during a 10 s cable wiggle would drop a goat with no hands into the match, which is exactly what the grace exists to stop. The
   worst-case wait is 10 s, the seat then empties on its own, and the nudge points at the culprit.
3. **DISCONNECTED seats are dropped when the lobby is left: APPROVED.** The grace window is a promise scoped to the lobby. Carrying a
   ghost seat across screens is UI owning state. A returning pad just presses A. Leaving needs a hold anyway, because
   `_joined_count` counts DISC seats (CC-6.2 holds).
4. **Chip wording: FIX.** Use "NOT JOINED? HOLD TO EXIT" (Fix 1).
5. **The empty lobby shows chip "B BACK" plus footer "B BACK OUT": FIX.** Show one exit prompt only (Fix 2).

Producer ruling respected: a seated hold-B does not arm the exit (WK-82). Fix 1 only changes the words.
Re-verdict: after Fix 1 and Fix 2 land, I need three re-shots at 1080p: any populated lobby (chip copy), `nobody_joined_back_chip`,
and the take-over PICKING frame. Then WK-138 is Ship.
