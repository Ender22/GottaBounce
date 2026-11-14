# Herd Lobby review gate (WK-05/06, fe2a99c)

UI/UX Designer · 2026-11-14 · Evidence: all 39 builder captures `tools/out/wk/WK-05_*.png` and `WK-06_*.png`
(1280x720), plus `src/ui/HerdLobby.gd`, `src/ui/LobbySlot.gd`, `src/ui/RosterMedallion.gd`, `scenes/ui/HerdLobby.tscn`,
and `scenes/ui/LobbySlot.tscn`. The game was not launched (the slot was taken). Graded against spec
`docs/audit/2026-11-14_controls_frontend.md` §E, `docs/COUCH_CONVENTIONS.md`, and the Smash Ultimate / MK8 / Duck Game /
Overcooked lobbies.

## Verdict: **FIX** (ship after the 8 must-fix-now items, no re-architecture)

This is the right lobby. The owner's exact complaint ("2 users using 2 controllers totally can't select their
character like a normal game") is solved. Each device joins its own panel, browses with its own stick, and locks on its
own. Taken goats are skipped and the roster medallion wiggles. Same-frame ties go to the lower slot and the loser gets
"TAKEN BY P2" plus a shake. The banner gates proceed. A solo player needs 2 presses. Devices carry into the match: 12b/c/d
show each device driving only its own goat. Per-panel glyphs follow the panel's own device (ENTER/ESC on the keyboard
panel, A/B on pad panels), which is exactly right. The motion grammar (join pop, bust bounce-in, stamp slam, banner
slide) is on-brand.

What keeps it from Ship are amateur tells that a living room sees in the first second, plus one policy mistake
(shared glyphs) that a mixed-device couch hits immediately. All of them are small.

### Builder deviations: rulings
| Deviation | Ruling |
|---|---|
| READY stamp over the portrait (banner covers panel bottoms) | **Accepted.** It is the correct call, and the stamp reads from across a room (02a/18b). Keep it at -6°. |
| No `ui_join`/`ui_ready` sounds (re-pitched samples) | **Accepted for now.** Later item L4 (sound-designer). |
| Minimal navy RULES card | **Rejected as the final look.** It is the old dev-navy language and it covers 3 of 4 panels while they are still live. Replaced by the WK-07 spec below. |
| Flair row cramped for long names | **Must-fix-now (F5).** In 18a "FLAIR◀GOLDEN JETSTREAM▶" has the chevrons touching the text, and the text is under 28 px. |
| Footer/shared glyphs follow the LAST device used | **Wrong for a multi-human lobby. Must-fix-now (F2)**, and amend CC-1.6 (see F2). |
| "PAD 1/2/3" labels | **Must-fix-now (F3).** The number is Godot's device id, not the player number, so they disagree (05_02: P2 = "PAD 1"; 06b: P2 = "PAD 2"). |

---

## MUST-FIX-NOW (before WK-05/06 are called shipped)

**F1. ROCKETBALL mode chip overflows the screen edge.** Size XS.
Where: `scenes/ui/HerdLobby.tscn` Header/ModeChip (fixed 316 px, offset -364/-48) and `src/ui/ModeContextChip.gd`.
Evidence: 17a/17b show "ROCKETBALL" clipped at x=1280.
Do: the chip sizes to its content and grows leftward (`grow_horizontal = BEGIN`; right edge pinned at 1872;
min 316, max 480). If the text still exceeds 480, shrink the font 1 px at a time down to 28 px. Check DROPSHOT and
ArenaSelect's copy of the chip as well. Why: a clipped header is the single loudest "programmer UI" tell.

**F2. Shared glyph policy for a mixed couch.** Size S.
Where: `HerdLobby._refresh_glyphs()`. Doc change: amend CC-1.6 in `docs/COUCH_CONVENTIONS.md`.
Problem: with 3 pads plus a keyboard joined, the footer, CPU tray, rules bar, banner GO glyph and back chip flip
between key caps and pad glyphs every time anyone presses anything. That flicker is a real defect when 4 people
are mashing. It also addresses the wrong person: 04a tells a solo keyboard P1 "RB ADD A CPU".
New rule (lobby and any screen with ≥1 joined human):
- **Shared chrome = pad glyphs if ANY joined device is a pad. Key caps only if the keyboard is the ONLY joined device.**
  With nobody joined, fall back to the last device (today's behaviour).
- **Banner GO prompt: dual glyph when both kinds are joined:** `[START] / [ENTER]` (a 28 px slash between them).
- **Amber hint** (it only shows with exactly 1 human): use THAT human's device glyph (kb → E, pad → RB).
- Glyphs never change while a key is held. Recompute only on join, leave, or device loss, never on every input.
Proposed CC-1.6 text: "A shared prompt shows pad glyphs if any joined player uses a pad, key caps if only the
keyboard is joined, and the last device's glyphs only when nobody has joined. The proceed prompt shows both when both
kinds are joined."

**F3. Device label: drop the arbitrary number and make "which panel is mine" physical.** Size S.
Where: `LobbySlot.set_device()`, `HerdLobby._join()`, `HerdLobby._on_press()`.
Do:
- Label = device family, not index: `Input.get_joy_name(id)` mapped to `XBOX` / `PLAYSTATION` / `SWITCH`, else
  `GAMEPAD`. Keyboard stays `KEYBOARD`. Two identical pads may both read XBOX. That is fine, because identity comes from
  the next two bullets.
- On join: `InputRouter.rumble(key, 0.4, 0.6, 0.18)` on that pad. The panel already pops.
- "That's me" ping: any press from a joined device that has no other effect (a face button with no verb, a blocked
  direction) pulses that device's own panel header (scale 1.0→1.05→1.0, 0.14 s, TRANS_BACK) and its P-badge.
  This is the Overcooked/Duck Game "wiggle to find yourself" move.
Why: a "P2 · PAD 1" panel makes a player ask "which one am I?", which is the very confusion this lobby exists to remove.

**F4. EMPTY panels ghost the backdrop's painted goats through the glass.** Size S.
Where: `LobbySlot.show_empty()` → `_set_plate(CHOCO, 5, 0.0, 0.55)`; Silhouette modulate.
Evidence: the very first lobby frame (05_00) shows a pink body plus green horns behind P1's silhouette and an orange
BILLY ghost behind P4's. These double images look like a rendering bug.
Do: EMPTY plate becomes a **dark slot well**, as in Smash/MK8 where empty slots read darker than filled ones:
bg `#3B241B` at 0.72, border cream `#FFF7EB` at 0.35 / 4 px, radius 22, no shadow. Silhouette = cream at 0.16
(not chocolate). The P-badge stays cream. "PRESS (A) TO JOIN" stays white with the 6 px chocolate outline (it reads better on
dark). Joined panels then pop by contrast with no extra work.

**F5. Flair row: legible at ≥ 28 px with chevrons that never touch the text.** Size S.
Where: `scenes/ui/LobbySlot.tscn` FlairRow (380x44; label 22 px; value 26→20 px) and `LobbySlot.set_flair()`.
Do: FlairRow 380x52. Replace the "FLAIR" word with a 36 px star/flair icon at x=12 (code-drawn or the existing
flair icon). FlairValue spans x=56..324 at 28 px fixed. Long names get **ellipsis-free abbreviation from data**
(add a `short` field to flair items, e.g. "GOLD JETSTREAM") instead of shrinking below 28. FChevL/FChevR sit at
x=328 and x=352 as a pair on the right edge ("◀▶"), not glued to the text. The gold active ring is now 6 px (CC: focus
change ≥ 6 px).

**F6. The READY banner slices EMPTY panels' "PRESS A TO JOIN" in half.** Size XS.
Where: `HerdLobby._refresh_banner()` and `LobbySlot` JoinPrompt.
Evidence: in 02b/04b/07/11b/17b, P3/P4 show "TO JOIN" cut by the band. It looks like a clipping bug.
Do: while `banner_up or hint_up`, every EMPTY panel's JoinPrompt tweens up 90 px (0.20 s TRANS_BACK out) and the
KbHint hides. Reverse it when the band leaves. Late joiners still see a whole, readable prompt above the band.

**F7. READY panels still show full-bright chevrons.** Size XS.
Where: `LobbySlot.set_ready()`.
Do: READY fades ChevL/ChevR to alpha 0 (0.12 s) and the bust idle keeps going. Un-ready fades them back in (0.12 s). Why: the
chevrons say "you can still browse", which contradicts the stamp. The locked panel should look finished.

**F8. Proceed presses during the 0.35 s banner guard are silently eaten.** Size XS.
Where: `HerdLobby._try_proceed()` (bare `return` on guard) and `_on_accept()` (bare `return` while spinning).
Do: keep the guard but answer the press. Play `_soft_tick()` and pop the banner row (`MenuFX.value_pop(_banner_row,
1.06)`). The spin case gets the soft tick only. This is the checklist rule "never silently eaten", and it already bit us
once (the ALL-READY launch eaten off-card).

---

## LATER (tracked; do not block WK-05/06)

| # | What / where | Why | Size | Owner / item |
|---|---|---|---|---|
| L1 | **RULES panel**: build the spec below. Also fix: a READY non-owner pressing Start **launches the match while the RULES card is open** (`_on_press` falls through for non-owner verbs other than `view`). | Ownership, occlusion, correctness | M | WK-07 |
| L2 | Sports carousel is still all 6 goats with no RED/BLUE ribbon (17a/17b show ZIGGY/PUFF selectable in ROCKETBALL) | E.6 not built yet; listed so nobody thinks it is done | M | WK-27 |
| L3 | Lost pad frees the slot instantly (06_19). Needs the DISCONNECTED slot (greyed bust, 10 s RECONNECT ring, "(A) ON ANY CONTROLLER TO TAKE OVER") | A cable wiggle wipes a pick | M | WK-28 |
| L4 | Real sounds: `ui_join` (slot-pitched), `ui_ready` plus a per-goat bleat on lock, `ui_all_ready` sting for the banner, `ui_deny`, `ui_hold_tick` | Re-pitched powerup/super/click samples are placeholders | S | sound-designer |
| L5 | Banner polish: band gets a 6 px chocolate top/bottom border, a white 0.22 gloss stripe over its top 30 %, and the GO glyph at 60 px tall (currently ~40 px beside 76 px text). Optional painted ribbon art (E.11) | Flattest element on screen at the screen's peak moment | S | ui + art-director |
| L6 | Roster medallion P-badges ~21 px at 1080 → 30x44 chip, 28 px text, chocolate bg, white text; locked medallion desaturates to 0.6 and shows the MenuCard check | CC-8.1 floor; "taken" should read from the sofa | XS | WK-18 |
| L7 | "Who are we waiting on": a READY player pressing A/Start before the banner makes every still-PICKING panel nudge (8 px, 0.12 s) and flash its status bar | Couch social cue, Smash-like | XS | lobby |
| L8 | Hold-B ring: 6 px stroke (now ~3 px). Count the hold only from a press that did not change a slot's state (today a READY player's B un-readies, and holding the same press exits the lobby for all 4) | Readable from the sofa; one kid holding B shouldn't eject the room | S | lobby |
| L9 | Title-safe: header chips start at y ≥ 40 and the footer bottom ≤ 1030 (1080 space). Today the footer runs to 1066 and the back chip starts at y=19 | Checklist 5 % overscan | S | lobby |
| L10 | Bundled display font (today `SystemFont`) | Typography confidence | S | WK-17 |
| L11 | In-match HUD labels the CPU "P4" (12a) | Implies a 4th human | S | WK-10 |
| L12 | ModeSelect/ArenaSelect still use old key-cap glyphs and ASCII "< >" (10a/11a) next to the lobby's new glyph chips | One product, not two | M | WK-29 |
| L13 | Re-review evidence: one **1920x1080 fullscreen** capture set, plus 10-frame bursts of join, lock, banner-in and rules-flip | Motion was graded from stills only; 1080p not captured | – | QA |

---

## WK-07 RULES PANEL: visual + interaction spec (replaces the navy card)

**Concept: the owner's panel FLIPS OVER and the rules live on its back.** This follows Duck Game, where each player's
settings sit on their own lobby card. It removes both problems with a centred modal: it no longer hides other players'
live panels, and ownership is unambiguous because the rules appear on *your* card in *your* goat's colour. Everyone else
keeps picking and readying around it.

### Back face layout (inside the same 420x530 LobbySlot, 1080 design space)
- **Plate:** identical to the joined front face, so it reads as the same card: cream `#FFF7EB` at 0.96, border = owner's goat
  colour 6 px, radius 22, glow shadow 24 px at goat colour 0.5. No navy anywhere.
- **Header strip (y 0-64):** the same P-badge (goat colour, white "P1", chocolate outline), then "RULES" at 40 px
  chocolate with a 4 px white outline at x=108. At the right is the ModeContextChip's mode icon (40 px). If the slot is READY, a 28 px
  green check sits beside the badge, so their READY status is not lost.
- **Rows (BRAWL ×4: CPUs · CPU SKILL · KOs TO WIN · LIVES):** each 380x84 at x=20, y = 76 + i·94 (last ends 440).
  - Title: left at x+16, 30 px chocolate (theme `StepTitle` metrics, chocolate fill instead of white).
  - Value pill: 150x60, right-aligned at x+214, radius 30, fill = owner's goat colour, 4 px chocolate border; value text
    40 px white with a 6 px chocolate outline (theme `StepValueBig`). Values: CPUs 0-3 (capped by humans), CPU SKILL MIX/1-5,
    KOs 5/7/8/10, LIVES 1/2/3.
  - Inactive row: bg chocolate at 0.08, radius 16, no border.
  - **Focused row:** bg gold `#FFD23F` at 0.30, **6 px gold border**, row scales 1.0→1.04 (0.16 s TRANS_BACK out). 36 px
    ◀ ▶ chevrons (the panel's own Chevron nodes) appear flanking the pill at x+176 and x+368.
  - Bound reached / locked value: pill `MenuFX.reject_shake` + `ui_deny`. SPORTS FORMAT locked to 2V2 at 3+ humans shows
    a 28 px padlock inside the pill's left edge.
- **SPORTS (×2: FORMAT · CPU SKILL):** same rows, vertically centred in the 76-440 band (y = 168, 262).
- **Footer (y 462-516):** owner-device glyphs only, 28 px: `(D-pad/◀▶) CHANGE   (A) DONE   (B) UNDO`
  (keyboard: `A/D CHANGE  ENTER DONE  ESC UNDO`).

### Interaction (one level, fast on a couch; satisfies the WK-07 acceptance "10→7 then B reverts to 10")
- **Open:** View/Tab from a joined device whose panel is not mid-spin. On open, snapshot the rule values.
- Up/Down moves the focused row (wraps). Left/Right **changes the value live**: the rules bar updates for everyone, with
  `MenuFX.value_pop` on the changed token. Values come from and go to `GameConfig.match_config` / per-mode memory; the
  panel keeps no copy.
- **A or View = DONE** (keep). **B = UNDO**: restore the snapshot and close. B never commits. This follows the C-25 grammar
  without a nested edit mode.
- **Only one RULES panel at a time.** Another joined device pressing View gets a deny shake on its own panel, `ui_deny`, and a
  1.2 s chip over its bust in TakenChip style: "P1 HAS THE RULES" (28 px, chocolate pill, white text).
- **While open:** the READY banner and amber hint slide out (the roster is treated as not valid). A Start/A from any READY
  player gets a soft deny, and **the owner's flipped panel nudges** (8 px, 0.12 s) to show who is holding things up.
  On close, recompute: if the roster is valid the banner slides in fresh, with the 0.35 s guard restarted.
- The rules bar (row 5) gets a left-side chip "EDITING · P1" in P1's goat colour, breathing 1.0↔1.05 at 0.6 s.
- Owner device lost → the panel closes keeping its values (WK-28 then handles the slot).
- TRIALS: no RULES. The View glyph is hidden and a View press gets a deny shake (as today).

### Motion
| Event | Motion | Sound |
|---|---|---|
| Open | panel `scale.x` 1→0 (0.10 s QUAD in, pivot centre), swap faces, 0→1.06→1.0 (0.18 s TRANS_BACK out); rows stagger in 0.04 s apart from y+14, alpha 0→1 (0.14 s) | `ui_card_flip` (ask sound-designer; interim `ui_click` p1.2) |
| Row focus | 1.0→1.04 scale, gold ring in (0.16 s BACK) | `ui_move` |
| Value change | pill 1.0→1.18→1.0 (0.16 s BACK), pressed chevron nudge 8 px / 0.08 s, rules-bar token pop | `ui_move` (p1.15) |
| DONE | reverse flip (0.10 s in / 0.16 s BACK out), front face idle resumes | `ui_confirm` |
| UNDO | changed pills shake (reject_shake), values roll back, then reverse flip | `ui_back` |

### Acceptance captures (`tools/out/wk/WK-07_*.png`)
P1 has rules flipped while P2/P3 keep cycling (all 4 panels visible); P2's View denied with the "P1 HAS THE RULES"
chip; KOs 10→7 shown on the panel and the bar; B → back to 10; READY P2 Start during edit → no launch, P1 panel
nudge; DONE → banner slides in. Capture both 1280x720 and 1920x1080, plus a 10-frame burst of the flip.
