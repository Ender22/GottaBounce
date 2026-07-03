# Creative Director verdict — 2026-07-03 — first fantasy-fit pass (kill-race on grassy_expanse)

> First run of the creative-director / player-advocate role, on the INTEGRATED build (kill-race +
> damage + flagship 2x arena). Verdict: **FIX**. Evidence: tools/out/cd_boot.png, cd_midflight.png,
> cd_match/frame_003.png+frame_007.png, cd_stall.png. This role exists because component QA passed
> while the game didn't deliver its fantasy — and this pass proved that gap is real.

## Verdict: FIX (bones right, integrated experience not yet delivering the fantasy)

## Findings (with owners), critical path first

**§2/§3 KILL ECONOMY DOESN'T FIRE AT SCALE (P0, critical path — game-designer + gameplay-programmer).**
On grassy_expanse, kills barely land: a 4-bot stage ran 60+s unresolved; the deaths that happened were
UNCREDITED SELF-DESTRUCTS — bodies fired supers upward and flew off the top/bottom bounds (dead bodies
pinned at y-1562 / y2036, scores still [0,0,0,0]). A 2800 super from an elevated pad (shoulder y430 →
apex ~y-2020; throne y140 → ~-2310) exceeds the top bound (-1560) → routine upward supers = suicide,
uncredited, advancing no one's kill-race. Endgame STALL: the 2 finalists parked ~2400px apart and never
engaged (the dev-arena finisher's 4.9s closeout does NOT scale to a 2x arena — finalists can't/ won't
close the distance). Net: no super-smash kill, no edge kill, no readable damage escalation in real play.
Against a passive idle target pace collapses to "instant" (10-1-1-1); against competent bots, "never" —
no healthy middle. **THE core verb (super-smash as the kill) is not being exercised in integrated play.**
This is the make-or-break fix.

**§1 HORIZONTAL TRAVERSAL DOESN'T REQUIRE FLIGHT (P1 — level-designer).** Vertical flight IS required
(the founding-miss fix LANDED — natural bounce apex falls ~260px short of the lowest upper pad, so you
must boost to reach platforms — do NOT touch this). But horizontally, holding only the direction key
(zero boost, fuel pinned 100) crossed the whole 3760px map including the central pit (~575px/s), because
air-drift + 98% tangential retention over the long spring hangtime + the mid-pit spring platform acting
as a BRIDGE defeats the 720px gap. Contradicts the arena's own design_intent. Fix: remove/reposition the
mid-pit spring bridge, widen the pit beyond drift+spring reach, or reconcile air-drift retention.

**§4 CAMERA ZOOMS TO ~0.42 → CHARACTERS ~40px (P1 — art-director + gameplay-programmer).** The follow-cam
fits the whole 3760px arena when players spread (which this arena encourages), shrinking bouncers to
~40px — faces, the crimson damage-pulse, and the super aim-fuse (all the readability/juice the pillars
depend on) get tiny. A 2x arena needs a tighter floor zoom, or dynamic/split framing, or it's too wide
for one screen. (Note: this trades against arena width — a real design tension to resolve, not just a knob.)

**AUDIO ENTIRELY ABSENT (P0 for "feels like a real game" — owner dependency + programmer).** Master bus
peak -200 dB, ONE default bus (no Music/SFX architecture), zero AudioStreamPlayers. A frantic party
brawler with no bounce/boost/smash/impact/announcer sound feels dead to any first-time player. The
single biggest "this isn't a real game yet" gap. STATUS step 5 lists the AudioManager/MusicManager port
but nothing is wired; owner provided a music library in session 1 (assets/music) but SFX sourcing is
unresolved. Needs owner input on how SFX get sourced (generate / CC0 / provided).

**Positive / low-priority:** dead-player HUD cards gray out correctly; Glossy Toybox reads well; the
owner-flagged floating bush/fence props look acceptably grounded at this camera distance (lower priority
than its STATUS entry implies).

## The systemic theme (Director note)
Four of these (self-destruct-off-top, endgame stall, camera shrink, horizontal drift-cross) share ONE
root: **the arena went 2x but combat/camera/bounds were tuned+validated on the small arena and don't
scale.** The lesson generalizes to the whole circuit: every combat/pacing/camera constant must be
validated as scale-aware, on representative geometry, not on one hand-tuned box. And the "match structure
ALL WORKS" STATUS claim (now corrected) was true of the state machine but masked that the kill economy it
depends on wasn't firing at scale — exactly the component-vs-integrated blind spot GAME_ESSENCE targets.
