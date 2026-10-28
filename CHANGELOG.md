# Changelog

## 1.6.1

- SmilerKeys: an item can be a slot's **target and its BiS at once**. The same neck is a 334 from a Heroic bonus roll and a 344 on Mythic, so it is both the one you can get now and the one you are working towards; setting one used to clear the other. Only "alternative" stays exclusive with the two.
- SmilerKeys: because of that, a boss could drop out of Where to go altogether - the item was BiS only, the plan holds a BiS pick out for its best version, and so Heroic Ula'tek was never offered. An item that is also the slot's target is now planned at whatever you can reach.
- SmilerKeys: the order list shows a dual-role item once per role, tagged with the level that role means (`Tgt 334`, `BiS 344`). Both rows share one priority.

## 1.6.0

**Where to go, rebuilt.** The week map at the top is now a grid: four rows, one per raid difficulty, against this season's ten bosses, with the eight Mythic+ dungeons on their own strip below and a Delves switch beside them. Each row is named and each cell carries a shape as well as a colour (`*` rolled, `x` killed, blank open, `-` no loot on that difficulty), so it reads the same without colour. The number in a cell is how many items you want from that boss **at that difficulty**; hover for the list, with what a kill and a bonus roll each give. Left-click a cell to cycle open > rolled > killed, right-click to clear, or click a difficulty's name to set or clear the whole row.

**Difficulties are no longer muddled.**

- This week's status was stored per boss with no difficulty at all, so marking Heroic Ula'tek killed also marked it on LFR, Normal and Mythic. Status is now per boss *and* difficulty, and a recorded bonus roll only counts on the difficulty it happened on.
- A boss's difficulty in the plan was worked out separately from the route actually chosen, so a boss whose best open route was Heroic could be labelled, pooled and tick-checked as Mythic. The route now decides, and Heroic Ula'tek and Mythic Ula'tek are separate entries - they are separate lockouts and separate roll pools.
- The last two bosses drop higher on Mythic (Myth 9/6). Bonus rolls knew this; kills did not, so a Mythic kill looked like 324 against a Heroic bonus roll's 334 and the plan quietly preferred Heroic for a Mythic-only item.
- Lair bosses have their own Mythic farm switches, on the Mythic+ line. They are not in the raid's kill order, so the single farm count could never speak for them.

**Upgrades are judged by where an item ends up, not where it drops.** A Heroic bonus roll that lands at 318 and crests to 334 beats the 321 you are wearing; the planner was comparing the drop level and throwing it away. A second rule parked anything already on the same gear track - "the rest is crests" - which discarded a Mythic roll at 334 because you wore myth-track 321. Both gone.

**Your targets board now reaches the planner.** The BiS scope only looked at BiS stars, so a slot's *target* - the one you can realistically get now - never entered the plan at all. It is now called **Targets** and covers your target, BiS and alternatives. A pick marked **BiS** is only planned at its best version, since routing you to a Heroic copy of your Mythic BiS is what the target is for.

**Nothing vanishes silently.** Items the plan leaves out appear under **NOT IN THE PLAN**, priority first, each with the reason: what you have, what would beat it, and what is stopping you. `/sk why <item>` prints the whole chain in chat - scope, slot, every route with why it was allowed or rejected, and the gate the item fell out of.

**Everything else**

- SmilerKeys: settings that belong to one character - the Where to go plan, this week's boss map, the roll checklist's spec and difficulty - are per character now instead of shared across the account. Your existing tuning carries over to each character the first time it opens.
- SmilerKeys: **bonus roll checklist** (`/sk rolls`). The loot table per boss and dungeon, per spec and per difficulty, ticked off by hand; owning an item does not remove it, and a complete table resets.
- SmilerKeys: transmog is no longer offered as gear. Cosmetic pieces share an equip slot with real armour, so the journal's filter had them competing as upgrades.
- SmilerKeys: loot list tidied - an Upgrades filter, a GAIN column, one item-level control in place of three, and plain-English help. The ILVL, GAIN and TAG headers used to sit on top of each other.
- SmilerKeys: the people grid drops strangers when they leave your group; friends, guildies and Battle.net contacts stay.
- SmilerKeys: the wishlist beside the character sheet appears without toggling the setting off and on.
- Smiler: minimap button (`/smiler minimap`) - click for the add-on menu, right-click for settings, drag it round the ring. The menu scrolls and is capped to your screen height.
- DiedTo: the death window leads with the cause and the hits behind it, with a health-fall strip.
- Rewound: Boss bests opens from the Smiler menu, the difficulty tabs show counts, and an empty tab says which difficulties do have records.
- SmilerSplits: your alts' keys count too - a run is labelled with the character who holds it.
- LustReady: `/lust sound` lists the sounds by number, and `/lust sound <id|file>` takes any sound kit or file of your own.
- SmilerBeacons: no longer reports beacons as off during a Mythic+ run, where the game hides aura data.
- Fixes: buttons past the window edge and on top of each other in Where to go, the wishlist, Targets and Rewound's Boss bests; Where to go scrolled backwards and then not at all; the roll lists scrolled into empty space.

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
