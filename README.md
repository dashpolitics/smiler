# Smiler

A pack of World of Warcraft add-ons for Midnight, sharing one look (Crystal Ball), one settings window and one place for alerts. Install the pack, then turn off whatever you don't want in `/smiler` › General; a module that's off doesn't load at all.

| Add-on | What it does | Command |
|---|---|---|
| **Smiler** | The shared settings window, menu button and alerts. Everything else works without it, with slash commands only. | `/smiler` |
| **SmilerKeys** | Your friends' best timed keys, keystones and Resilient levels in one grid; a wishlist for every gear slot beside your character sheet; a gear guide, QE Live import, embellishment planning and a week-by-week "where to go" planner for bonus rolls and kills. | `/sk`, `/sk loot`, `/sk plan` |
| **CD Timeline** | Boss mechanics and healer cooldowns sliding towards a now line, a fight graph, and a planner with built-in Heroic and Mythic damage profiles for every boss of the tier. | `/tl`, `/tl plan` |
| **Smiler_Fights** | The damage profiles CD Timeline loads on demand. | – |
| **RampNotes** | Plain on-screen notes with draggable spell rows for ramps and rotations. | `/rn` |
| **DiedTo** | What killed each group member and the hits leading up to it, with avoidable damage and interruptible casts marked. | `/diedto` |
| **Rewound** | Preservation Evoker: records your Rewinds and announces a new best. Boss bests: your best HPS on every raid boss, per character and difficulty. | `/rewound`, `/rewoundx` |
| **LustReady** | Tells you lust is up when a boss is pulled, and when Exhaustion wears off. | `/lust` |
| **SmilerSplits** | Mythic+ boss splits against your run nearest this key level, and whether you're on pace to time it. | `/splits` |
| **SmilerPet** | A small movable icon for a pet ability's cooldown (Felhunter Devour Magic by default). | `/petcd` |
| **SmilerStash** | Your loot currencies in one place (Venomstones, keys and shards, catalyst, sparks, bonus rolls, crests, soul fragments) for all your characters, upgrade heads-ups, and where this week's Venomstones can still come from. | `/stash` |
| **SmilerVault** | Great Vault progress across your characters, with a Tuesday warning for anyone under 3 slots and the quickest way there. | `/vault` |
| **SmilerBeacons** | Holy Paladin with Beacon of Faith: warns when a beacon isn't on anyone in your group. | `/beacons` |

Some modules are for one class or role (Rewound, Beacons, Pet cooldowns, CD Timeline's healing numbers). They say so on their tab and stay quiet elsewhere.

## Installing

From Wago or the release zip: unzip into `World of Warcraft/_retail_/Interface/AddOns/` so that each folder above sits directly in `AddOns`. Restart the game the first time (a `/reload` doesn't pick up new add-ons).

## Building a release

Releases are built by the [BigWigs packager](https://github.com/BigWigsMods/packager) from a git tag and uploaded to Wago by the workflow in `.github/workflows/release.yml`. Tag with `git tag v1.2.0 && git push --tags`.

## Licence

MIT, see `LICENSE`. Fonts: Barlow (SIL OFL, `*/Fonts/OFL-Barlow.txt`), DejaVu Sans Condensed (Bitstream Vera licence) and Poppins (SIL OFL) in CD Timeline.
