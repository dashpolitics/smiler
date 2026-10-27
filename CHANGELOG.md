# Changelog

## 1.4.0

- SmilerKeys: **Targets** (`/sk targets`, or the button beside Where to go). One row per slot that still has an upgrade in it, with three picks: the **target** you can realistically get now, the **BiS** you are working towards, and **alternatives** worth taking on the way. Items you cannot reach yet (Mythic bosses past your farm count) are marked "not yet".
- Every pick goes on the wishlist, and the list on the right holds all of them in one order: drag a row to move it, and the order is written back as priorities 1-15, which is what weights "Where to go". So re-ordering your targets re-plans your bonus rolls, kills and crafts.

## 1.3.0

- CD Timeline: new compact row (`/tl cdm`) — each cooldown's icon with the countdown to its planned cast above it, red with a red cross while you should hold it, GO at the planned moment. It is CD Timeline's own frame, so it works with any Cooldown Manager skin: `/tl cdmlock` to drag it over your icons, `/tl cdmsize <px>`, `/tl cdmall`, `/tl cdmpos`.
- CD Timeline: on-use trinkets are tracked like cooldowns. Equipped trinkets get their own group on the column, and any trinket you have worn can be added to a plan from a column's + menu (Trinkets).
- DiedTo: end-of-fight summary. One line per death with a probable cause (one-shot, stood in it, interruptible, burst, ticked down, low health), in chat and on a new "fight" tab in the death window. Click a line for the hit-by-hit. Settings > End of fight; `/diedto fight` reprints it, `/diedto test fight` fakes one.
- Fixes: the planner's + menu errored instead of opening (a stray internal name from the trinket work).

## 1.2.1

- CDTimeline 0.31.0: first attempt at countdowns on Blizzard's Cooldown Manager icons (replaced in 1.3.0 by the compact row, which works with reskinned Cooldown Managers too).

## 1.2.0 – 2026-10-27

- **New: SmilerStash 0.1.0** – loot currencies for all your characters, upgrade heads-ups, this week's Venomstone sources. `/stash`
- **New: SmilerVault 0.1.0** – Great Vault progress across characters with a Tuesday warning. `/vault`
- **Rewound 0.4.0** – Boss bests: best HPS per raid boss, character and difficulty. `/rewoundx`
- **Smiler 1.2.0** – Blizzard UI tab (hide the raid manager and the objective tracker); settings window grows with the pack; hints wrap instead of running under controls.
- **CD Timeline 0.30.4** – boss bar: LFR/N/H/M switches with tooltips, bigger portraits with a status word under each.
- **SmilerPet 0.1.2** – remembers the pet's spells when the game hides its spellbook (combat, keys); cooldown sweep from the game's duration object when the numbers are hidden.

## 1.1.2 – 2026-10-27

- **SmilerSplits 0.2.0**: `/splits share` and `/splits import` – pass a run's boss splits to a friend as a string; imported runs match by boss name too.
- **SmilerBeacons 0.2.1**: works in instanced combat: counts a beacon as present even when the game hides its details, and otherwise falls back to where you last cast it (`~Name`) instead of a false "missing".
- Releases now build from a version bump in `Smiler.toc`.

## 1.1.0 – 2026-10-27

First release of the pack as one download.

- **Smiler 1.1.0**: first-run welcome and a General tab that says what's active on this character; every module's tab shows who it's for; module on/off switches.
- **SmilerKeys 0.22.2**: sort the grid by any column; hide a player for now; secondary stat ranking (ties allowed) for raid and Mythic+; priority markers 1–15, set by you or from QE scores; QE Live import from the report's data; lairs bonus-rollable; Loa armament pieces with stats; delve trinkets; embellishment planning (two allowed, placed on crafted pieces); the "Where to go" planner: boss map for the week, week-by-week roll and kill cards with reasons, swaps that re-plan later weeks, item progress; non-friends stay in the grid under GROUP / OTHERS.
- **CD Timeline 0.30.2**: boss bar for the whole tier with portraits; preview any boss from the built-in damage profile and add your cooldowns; boss ability and healing cooldown summaries with tooltips; mirror view (damage left, healing right, shortfall hatched); `/tl healers`.
- **DiedTo 0.9.0**: compact transparent window, flick through deaths, chronological and by-ability views, avoidable and interruptible marks.
- **LustReady 0.2.1**: dragon roar, loudness setting.
- **Rewound 0.3.1**: Mythic+ and dungeons share one category.
- **New**: SmilerSplits 0.1.0, SmilerPet 0.1.1, SmilerBeacons 0.1.0, Smiler_Fights 1.1.0 (Heroic and Mythic profiles for all ten bosses).
