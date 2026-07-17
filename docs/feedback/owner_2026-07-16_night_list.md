# Owner feedback — 2026-07-16 (night list, free-rein session)

Owner message (paraphrased, order preserved; delivered as "going to bed, free reign, go nuts"):

1. **Remove GAUNTLET mode.** "It doesn't really work at all and I don't understand what the idea
   is for it, it doesn't seem to fit the overall plans." → DONE (DECISIONS 2026-07-16).
2. **Player head-bounce.** "You can bounce off of other players (i.e. if you hit them from above)
   like in those super mario coop games." → Tuning.player_bounce_* + Player._handle_smashes.
3. **3+ circuits at launch.** "At least 3 of the party mode circuits available at launch with only
   4+ ones locked." → Settings.FREE_CIRCUITS = 3 (DECISIONS 2026-07-16).
4. **Between-level score screen.** Research how Duck Game / TowerFall score their party modes —
   "they don't have dots that fill up next to each player, but instead they show a brief score
   screen between levels before the next level is loaded, let's do that."
5. **Trials circuit 1 = tutorials.** New first levels teaching: fly with jetpack to reach a spot;
   super boost to reach a spot; fly THEN super boost (only reachable with both); recharge boost
   along the way.
6. **Trials circuit 2 = hard navigation.** Boosting up 2 tall vertical walls; blasting through tiny
   hard-to-aim holes; super-precision jump refills; hard-to-reach keys then hard-to-reach doors.
7. **Trials circuit 3 = soccer.** Many hit-the-ball-into-the-goal challenges.
8. **Trials circuit 4 = physics.** Destructible elements, cannons you can ride in, physics puzzles
   solved by knocking over / exploding things to forge new paths.

## Mid-session additions (same night, while playtesting)

9. **Flight feel (movement = the product):** "When trying to fly, the players should feel like they
   have a bit less gravity on them — it's easy to fly left and right, but not so easy to fly
   upwards, so players tend to avoid flying up and just super boost. Only like a 20% change is
   needed — maybe just lower the weight of flying players so that upwards boosts affect more."
   → `Tuning.boost_gravity_scale = 0.8` (gravity while thrusting). NOTE for owner: sustained climb
   SPEED is pinned at `normal_boost_max_speed` (760) by the INV-1 anti-smash cap — the change makes
   the climb RAMP/turnaround ~11% quicker and removes 20% of the droop; if climbing still feels
   slow the next lever is the vertical thrust cap, which needs a designer pass against INV-1
   (760×1.12=851 < 900 margin).
10. **CharacterSelect settings tray:** screenshot of the HUMANS/BOTS/BOT SKILL/KILLS/LIVES strip —
    "what is this terrible looking UI, and how would someone with a controller use it?" (Confirmed
    live: focus sits invisibly on a stepper and eats accept presses.)
11. **Bot colors:** "Ensure in party mode bots are not the same colors as the players."
