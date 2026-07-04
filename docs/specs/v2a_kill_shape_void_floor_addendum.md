# Addendum: v2a — KILL-SHAPE metric for VOID-IS-FLOOR arenas (K1 reinterpretation)

> **Owner:** Lead Game Designer. **Status:** RULING (metric-interpretation rule now; small code task
> flagged for later). **v2a — 2026-07-04.**
>
> **Amends:** `docs/specs/v2_kill_shape_edges.md` §5 K1 (the "edges >= 60% / pit <= 30%" target) and its
> §6 `_classify_blast_edge` instrumentation. **Companion to** `docs/specs/v1_level_circuit.md` (the
> circuit declares each level's kill-shape class; this addendum defines how QA reads the metric per class).
>
> **Why this exists:** the level-designer flagged (STATUS follow-ups) that on islands-over-void arenas
> `_classify_blast_edge` labels almost every void death "pit", so the K1 target — written to DEMOTE
> grassy_expanse's central pit — would misread the flagship's fantasy-correct void kills as a regression.
> This addendum stops that misdiagnosis before the circuit rotation QA runs.

---

## 1. What the code actually does (grounding — `src/modes/PartyMatch.gd`)

`_classify_blast_edge(victim)` (lines ~511-531) returns which bound the victim crossed at death, using
the victim's last-frame position vs the arena `bounds`, and — for a BOTTOM crossing — splits on the
walkable x-span (`_stage_rect` = the level's `play_rect`, the merged platform AABB):

```
if m == out_bottom:
    if pos.x >= _stage_rect.position.x and pos.x <= _stage_rect.end.x:
        return "pit"     # bottom crossing INSIDE the walkable x-span
    return "bottom"      # bottom crossing OUTSIDE it
```

Result is recorded per kill as `kills[].blast_edge` (line ~458) in `round_stats`. K1 (v2 §5) then reads
those labels: **edges (left/right/top) >= 60%, pit (bottom-inside-span) <= 30%.**

**The load-bearing fact:** on an islands-over-void arena the walkable x-span (`_stage_rect`) covers the
whole archipelago (islands_void: platforms span x ~ 0..4320), and the void runs UNDER that entire span.
So **every fall into the void — whether a whiffed gap-hop OR a clean smash off an island edge — crosses
the bottom bound at an x INSIDE the walkable span, and is labelled `"pit"`.** The classifier only knows
the ARENA bounds; it does not know about the gaps BETWEEN islands, so it cannot tell a fantasy-correct
"smashed off the edge into the void" from a solo whiff. On these arenas **`"pit"` means "off-screen via
the void floor" — which IS the intended primary kill**, not a demoted minority hazard.

---

## 2. The problem with applying K1 uniformly

K1 was authored for the CENTRAL-PIT shape (`grassy_expanse`): a single mid-map hole in an otherwise
solid floor, where the pit was DEMOTED to a minority traversal hazard and the SIDE blast lines were
made the intended majority killer (v2 Rulings 1+2). There, "pit <= 30%" is the correct success signal:
a high pit share means the demotion failed.

On a **void-is-floor** arena the situation is inverted by design:
- The void IS the floor; there are no interior "safe" floors to fall off of into a separate pit.
- Knocking a rival off an island edge into the void is the CORE fantasy ("smash rivals off the screen"),
  and it lands in the `"pit"` bucket.
- A clean side-blast (left/right bound) is comparatively RARE, because the outer island edges are the
  only places a launch exits sideways rather than dropping into the void first.

So on islands_void a HEALTHY, fantasy-correct match would show something like **~85-95% `pit`, ~5-15%
side/top** — which K1 (pit <= 30%) would score as a catastrophic FAIL. That is a **false regression**:
the metric would demote the flagship for doing exactly what the owner directed.

The `drop_chamber` (owner-seed cylinder) is the extreme case: its side + ceiling are NON-lethal bumpers,
so the ONLY exit is the central floor-hole -> **~100% `pit` by construction**. K1 as written would rate
the most on-identity level in the circuit as the worst.

---

## 3. RULING — per-class metric selection (the interpretation rule)

**Each level declares a `kill-shape class`** (in `v1_level_circuit.md` §2 and in its `design_intent`).
QA applies the target for that class — K1 is NOT uniform:

### Class `central_pit` (e.g. `grassy_expanse`)
- Apply **v2 K1 UNCHANGED:** edges (left/right/top) >= 60%, pit <= 30%. The pit is a demoted minority
  hazard; a high pit share is a real regression here. `blast_edge = "pit"` keeps its "demoted-hazard"
  meaning.

### Class `void_is_floor` (islands_void, twin_chasms, the_spine, wrecking_yard, the_cliff, bumper_gauntlet, spires)
- **K1 does NOT apply.** A high `"pit"`/`"bottom"` share is EXPECTED and CORRECT (the void is the floor).
- **Replace with K1' — the off-screen-kill target:**
  - **K1'a — off-screen identity:** credited **off-screen kills >= 88%** of deaths (any bound crossing:
    pit + bottom + left + right + top all count as "off the screen"). This is the real fantasy signal on
    these arenas — that deaths happen by leaving the frame, not by anything else.
  - **K1'b — uncredited share:** uncredited self-falls (no qualifying hit within
    `kill_credit_window_ringout = 6.0s`) **<= 12%** of deaths (slightly looser than central-pit's <= 10%,
    v2 K3, because gap-whiff falls are inherent to island traversal; per-level specs tighten this where
    tops are tiny, e.g. `spires` SPR1 <= 12% or enlarge tops).
  - **DROP the edge-vs-pit RATIO target entirely** for this class. Do NOT require side kills to be the
    majority — on a void-is-floor arena side kills are naturally the minority and that is fine.
  - **Per-level shape checks stay** where the LAYOUT implies a distribution (e.g. twin_chasms TC1 "deaths
    split across BOTH voids", atoll AT1 "both well and rim") — those are level-specific, not the global K1.

### Class `dual_blast` (the_ascent)
- **K1 reinterpreted:** TOP blast is INTENTIONALLY common here (per-level bounds override, `v1_level_
  circuit` §L-7). Target: **top kills >= 20%** AND bottom/void kills present AND combined off-screen
  >= 90% (AS1). Do NOT apply the generic "top rare" expectation (v2 §1d) to this ONE level.

### Class `enclosed_hole` (drop_chamber)
- **K1 replaced by DC1:** >= 90% of kills are bottom/pit (the centre hole); side + top ~= 0 (walls are
  non-lethal). A ~100% pit share is a PASS, not a fail. Uncredited self-falls <= 12%.

**QA obligation (added to the fantasy-fit gate):** before scoring K1 on any level, read the level's
declared kill-shape class and select the matching target above. Scoring a `void_is_floor` level against
the `central_pit` K1 is a QA error, not a level regression. This is `v1_level_circuit` criterion C6.

---

## 4. Does `_classify_blast_edge` need a CODE change?

**Short answer: not required to un-block the circuit QA — a metric-interpretation rule (§3) is enough
right now. But a small code change is RECOMMENDED to make the per-class selection machine-readable and
to stop the label being misleading. Flagged for a future gameplay-programmer task; not blocking.**

### 4a — Why the interpretation rule suffices for now
`round_stats` already records `level_name` per stage, and `v1_level_circuit` declares each level's class.
QA can branch on the class (via a small lookup keyed by level name) and apply K1 vs K1'/DC1/AS1 by hand.
No engine change is needed to run the circuit QA correctly TODAY.

### 4b — Why a code change is worth doing (future task, LOW effort)
Branching by level_name in the QA harness is brittle across 11+ levels and invisible to anyone reading
raw `round_stats`. Two small, independent improvements (either/both):

1. **Add a per-level `kill_shape` field (or a `void_is_floor: bool`) to level JSON**, load it in
   `LevelLoader` / `PartyMatch._load_stage`, and stamp it into each stage's `_cur_stats` (so
   `round_stats[i].kill_shape` is present). Then the QA aggregator auto-selects K1 vs K1' from the DATA,
   not a hard-coded name list. This is the load-bearing change — it makes the §3 ruling machine-checkable.
   - Recommended values: `"central_pit"`, `"void_is_floor"`, `"dual_blast"`, `"enclosed_hole"` (matching
     `v1_level_circuit` §2). Default (absent) = `"central_pit"` for back-compat with grassy/dev.

2. **(Optional, cosmetic) Relabel the bottom-inside-span crossing on void-is-floor levels** so raw stats
   aren't misleading: e.g. return `"void"` instead of `"pit"` when the level's `kill_shape` is a
   void-floor class. This is a READABILITY fix only — it does NOT change any target by itself (the target
   selection in #1 is what matters). Do NOT do #2 without #1, or the label just moves the confusion.
   - Guidance if implemented: keep `"pit"` reserved for the `central_pit` class (a demoted mid-map hole);
     use `"void"` for the void-floor floor-fall so the two are never conflated in analysis.

**What a code change must NOT do:** it must not attempt to distinguish "smashed off an island edge into
the void" from "whiffed a gap-hop into the void" by geometry — both are legitimately off-screen kills,
and the credited/uncredited split (K1'b, via `last_attacker` within the credit window) ALREADY captures
the only distinction that matters for the kill economy (was it a kill or a self-fall). Do not add
per-island-edge classification; it adds complexity for a distinction the credit system already makes.

### 4c — Recommendation
- **NOW:** adopt the §3 interpretation rule; QA cites it (C6) and does not flag high pit/void shares on
  void-is-floor levels as regressions.
- **SOON (future gameplay-programmer task, low effort, non-blocking):** implement 4b#1 (the `kill_shape`
  field into `round_stats`) so the aggregator auto-selects the target; optionally 4b#2 (relabel to
  `"void"`) for stat readability. Neither touches lethality, movement feel, or the fence.

---

## 5. Fence

Pure measurement/interpretation. NO change to any lethality constant, movement-feel constant, the
drain-all super, the hitstun triad, `max_speed`, credit windows, or the kill economy. The only sanctioned
code follow-up is a per-level `kill_shape` data field surfaced into `round_stats` (instrumentation), plus
an optional cosmetic relabel — both flagged for a future gameplay-programmer task, neither blocking the
circuit build or its QA.
