# SmilerKeys 0.12.0

Everyone's best timed M+ key per dungeon, plus their current keystone, in one grid: you, your guild, friends and group.

## Install
Copy the `SmilerKeys` folder to `World of Warcraft\_retail_\Interface\AddOns\`, then restart WoW (a brand-new addon needs a restart, not just /reload).
Everyone who should show their keystone needs SmilerKeys too. Group members without it still show their scores, but not their key.

## Reading the grid
- Each cell is the highest timed key for that dungeon. Its colour says how well it was timed:
  green = in time · blue = 20% to spare · purple = 40% to spare. Hover for the exact result (`++11  20% to spare`).
- `·` = nothing timed. Over-time runs are only in the tooltip.
- RESI is each player's Resilient Keystone level (keys can't drop below it): their lowest best timed key across the season's dungeons, once that's +12 or higher. Hover it to see which dungeons they still need for the next level.
- **Friends** (guild, character friends, Battle.net friends) are listed first. Group members you don't know get their own **Group** section and drop off once they leave.
- Characters on the same Battle.net account are grouped, alts indented. Automatic for you and Battle.net friends; for others right-click a row and type their account name (or `/sk link <character> <account>`).
- A soft gold glow marks a key that would raise someone's best in that dungeon, and their cell in that column. Hover a key to see only who it upgrades.

## Loot and wishlist (`/sk loot` or the Loot button)
- Every item from this season's raids (LFR, Normal, Heroic, Mythic) and M+ dungeons, read from the game's Adventure Guide – filtered to your spec by default.
- Filter by raid or M+, instance, slot, wishlist, bonus-rollable, or search. Click column headers to sort.
- Item levels follow the raid difficulty and keystone level you pick; `+13` next to an item level is the gain over what you're wearing.
- Drag an item onto its slot on the right (or shift-click it) to put it on your wishlist. Right-click to remove.
- `BR` marks bonus-rollable sources (Nebulous Voidcores). Hover an item for what a bonus roll there gives.
- VIA (Drop · Bonus roll · Great Vault) sets which item level the list shows; wishlist items remember it with the difficulty or key level. Right-click a wishlist item to change it.
- Crafted gear (endgame epics and items embellished by default) and every embellishment reagent, under the Crafted filter. `EMB` marks embellishments; the wishlist warns past 2.
- Tier pieces for your class sit under the boss whose token gives them (Venomcast Idol and so on), at that boss's item level; `TIER` tag.
- Labyrinth of Kindo'jan: a Venerated Loa Armament option per armour/jewellery slot (Myth 1/6, 318) under the Delve filter.
- Off-spec trinkets for your class (e.g. a DPS trinket for a healer) are included and marked `·off`.
- Alt-click any item to mark it best in slot: gold outline and a star, in the list and on your wishlist; the BiS button filters to them.
- Each wishlist slot shows whether you've reached BiS: a gold star and bar when you're wearing the item(s) you marked BiS (both rings / both trinkets), or click the star to tick it yourself. Done slots drop out of the plans.
- PLAN tabs: **Bonus rolls** (bosses and dungeons to spend Nebulous Voidcores on, with the item level you'd get), **Farm** (drops), **Vault**, **Craft** (crafting orders and Labyrinth). Ranked by BiS items, then item count; hover for the items, click to list them.

## Using the grid
- Click a dungeon icon → cast its teleport, if you know it (cooldown shows on the icon; hover for the time left)
- Shift-click an icon, or click a key → highlight that dungeon · right-click an icon → sort lowest first
- The window closes when you enter combat and reopens afterwards: WoW doesn't allow teleport buttons to change mid-fight.
  `/sk` during combat queues it to open when combat ends.
- Right-click a player → set account · shift-right-click → hide

## Commands
- `/sk` or `/smilerkeys` – toggle (also the addon compartment button)
- `/sk sync` – broadcast now and ask everyone for theirs
- `/sk debug` – who SmilerKeys can reach right now, and what it has sent and received
- `/sk guild | friends | bnet | party` – sharing per channel (also in the footer)
- `/sk tp <column> <spellID|clear>` – set a dungeon's teleport by hand if it isn't found
- `/sk alts` · `/sk glow` · `/sk abbr <column> <text>` · `/sk unhide` · `/sk clear` · `/sk test`

## Privacy
Your BattleTag is only sent over Battle.net, never to guild or whispers. SmilerKeys tells you when a friend is running a newer version.
