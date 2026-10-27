# Changelog

## 1.2.1

- CDTimeline 0.31.0: new option to put the plan's countdowns on Blizzard's Cooldown Manager icons instead of the cooldown column (`/tl cdm`, or Settings > Column). The number sits just above each icon, turns red while you should hold the spell (with a red cross over the icon), and shows GO at the planned time.

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
