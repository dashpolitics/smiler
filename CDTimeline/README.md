# CD Timeline (v0.26.0)

## Look

Crystal Ball — Stormchaser's "mystic glass, gem accents" theme, lifted from
its design tokens: deep void and smoke-purple panels with low-alpha borders,
amethyst for every number, the T and anything "next"; diamond for the
selected / ghost shimmer; the gem set for meaning — emerald for ready, NOW and
healing, ruby for late and boss, topaz for damage, sapphire for phases.
Barlow Condensed Bold for all text with a void-coloured drop shadow instead of
an outline (`/tl outline` switches to an outline for busy scenes). No Blizzard
templates: buttons, checks, sliders, inputs and scroll areas in the options
and import windows are flat and drawn by the addon.

## Options window and fight graph

- `/tl options` opens a window with every setting as a control, in pages:
  General, Stack, Tracking, Plans, Column, Looks, HUD. Each control runs the
  matching slash command, so the two never disagree. It's also listed under
  the game's AddOns settings.
- **Plans** (`/tl plans`) shows what's loaded: what's running and at which
  stage, what a pull timer will load and why (pinned / last fought /
  selected), and the selected plan. Below it, every stored boss with a line
  per difficulty and buttons: **Select** (what Test, Phases and Assign act
  on), **Arm** (pin it for pull timers; `/tl use <id> [heroic|mythic]`),
  **Test**, **Phases** (an inline editor showing known / learned / estimated
  phase starts, a box to type them, and Forget learned), **Delete**.
- **Fight graph** (`/tl graph`): a strip in the top right, left of the
  minimap, showing the whole fight — up to 11 minutes, condensed to the plan's
  length. A row of ruby ticks for boss casts, one strip of spell icons for
  every cast you're assigned (icons that would overlap stagger up a step;
  `/tl graph all` adds a strip per healer), and underneath the planners' curves:
  amber = healing required (Fight Flow's damage model), green = healing
  placed (or, from the Ramp Planner, cooldowns active). A spark sits lit at 0
  during the pull timer and races along the axis once the fight starts, with
  the fight clock top right. The curves come from the `curve:` lines both
  planners now put in their CD Timeline export; a string without them still
  draws the markers. `/tl graphsize <w> <h>`, `/tl graphpos reset`; drag it
  when unlocked.

## Stack (default)

One frame built around an **inverted T**: a landing bar across the bottom and
a stalk up the middle. Left of the stalk is the boss; right of it is you.

- **Top, right of the stalk: your cooldowns**, left-justified against the
  stalk and growing rightwards, in two groups: **Major** (Preservation:
  Stasis, Rewind, Dream Flight, Emerald Communion — whichever you've talented)
  and, after a gap, **Other** (Preservation: Time Spiral). Blizzard's cooldown
  number sits on each icon (exact, also in combat); greyed = on cooldown,
  full colour = ready. While a plan runs, each icon shows the plan's next
  cast of it: fight time above (`3:09`), `in 2:06` below — red if the
  cooldown won't be back in time.
- **Under each row icon, that spell's own column.** From 30 s out a copy
  leaves the row (the row copy dims) and runs straight down its column at
  constant speed to the landing bar. The plan's next cast of that spell runs
  down the same column as a ghost — grey while the real cooldown is still on
  its way, in colour once it's ready — and says `GO` as it lands. A planned
  cast of something not in the row uses a lane just past the last column.
- **Left of the stalk: the boss.** BigWigs timers drop down the boss lane
  onto the landing bar (`/tl bosslane <px>` sets its width, 90).
- **Under the T, right of the stalk: the next assigned cast and a queue.**
  Your next planned cast from the string — icon aligned with the first
  cooldown above, big countdown and your name beneath it — then the two casts
  after it, tight against it, icons with timers only.
- `/tl linear` switches the stack between constant speed (default: 30 s to 0
  at a steady pace, constant size) and the HUD-style perspective.
- `/tl stacksize <w> <h>` (320×420; grows to fit the row), `/tl rowicon <px>`
  (30), `/tl slot <px>` for the arriving / slot size (40), `/tl window <s>` (30), `/tl crosshair` toggles the T.
- `/tl track add <spellID>` adds to Major, `/tl track add <spellID> other` to
  Other, `/tl track remove <spellID>`, `/tl track reset`, `/tl track` lists.
  Zephyr 374227, Obsidian Scales 363916, Emerald Blossom… Wowhead's URL has
  the ID.

The other layouts are still there — `/tl layout hud | single | lanes` — and
with those the cooldowns live in a separate column beside the plan bar:

## Mine

No box, no lines, no headers, no names — just icons and numbers.

- One vertical track per spell. On cooldown and more than 30 s away: the icon
  sits **parked at the top**, greyed, with its countdown. Inside the last
  30 s it **slides down** the track, in colour, and **lands at the bottom** as
  it comes off cooldown (a small pop). Ready spells stay **docked at the
  bottom** until you use them, then go straight back to the top. `/tl ready`
  makes ready spells disappear instead.
- **Scheduled casts.** While a plan is running, each track shows above it the
  plan's next cast of that spell by you: the fight time (`2:35`) and `in 47`.
  Inside the window a dimmed **ghost** of the planned cast slides down the
  same track and says `GO` as it lands. If the real cooldown won't be back by
  the time the plan wants it, both the `in N` and the cooldown's countdown turn
  **red** — that's the "move the ramp" signal. `/tl sched` turns this off.
  (Matching is by spell ID, or by the spell's name inside a note like
  "Hold Dream Breath".)
- Attached to a HUD, the column uses the HUD's perspective mapping (icons grow
  on the way in) so a cooldown 10 s out sits level with a planned cast 10 s
  out. Attached to `single` / `lanes`, it uses their linear scale. Dragged
  away, it stands on its own with `/tl minesize <icon> <height>`.
- The spells come from your spec, filtered to what you actually know — so the
  Stasis / Dream Flight choice node sorts itself out, and a talent swap
  rebuilds the column. Defaults:
  - Preservation: Stasis, Rewind, Dream Flight, Emerald Communion
  - Holy Paladin: Avenging Wrath / Avenging Crusader, Aura Mastery, Divine Toll, Lay on Hands
  - Resto Druid: Tranquility, Convoke, Flourish, Tree of Life
  - Resto Shaman: Healing Tide, Spirit Link, Ascendance, Ancestral Protection, Mana Tide
  - Holy Priest: Divine Hymn, Apotheosis, Salvation, Guardian Spirit, Symbol of Hope
  - Discipline: Barrier, Rapture, Evangelism, Pain Suppression, Power Infusion
  - Mistweaver: Revival / Restoral, Yu'lon / Chi-Ji, Life Cocoon
- `/tl track` lists them; `/tl track add <spellID>` / `remove <spellID>` edits
  the list for the current spec (Wowhead's URL has the ID); `/tl track reset`
  goes back to the defaults. Zephyr is 374227, Time Spiral 374968, Obsidian
  Scales 363916 if you want them.
- `/tl combat` shows the column in combat only. `/tl border` adds a thin
  class-colour border to the icons. `/tl minesize <icon> <height>` sizes it
  (36 px icons; the height only applies when it's free-standing);
  `/tl mineoffset <px>` sets the gap to the plan bar; `/tl window <s>` sets how
  far out things start sliding (30 s, shared with the plan bar).
- The global cooldown is ignored: a spell that's only on the GCD counts as
  ready. Charge spells show ready while a charge is left.
- **In combat (12.0 "secret values").** Once an encounter or combat starts,
  the game hides the numbers behind your cooldowns from addons: it will say
  *whether* a spell is on cooldown, but not for how long. So in combat the
  countdown number on the icon is drawn by Blizzard's own cooldown widget
  (exact; it needs "Show Numbers for Cooldowns" in Interface > Action Bars,
  or OmniCC — `/tl swipe` toggles the dark sweep), and the icon's **position**
  on the track comes from the addon's own clock: started from the last exact
  value it saw before the pull, or from the moment you cast the spell, using
  the cooldown length it last saw out of combat (falling back to the base
  cooldown). Ready / not-ready is always exact. `/tl numbers` swaps the
  Blizzard number for the addon's own text under the icon (exact out of
  combat, modelled in combat). `/tl debug` prints what it can see right now.

## The plan bar (`/tl layout hud`)

- No box, no backing, no lines — just a crosshair where each track lands
  (`/tl crosshair` toggles it; `/tl rails` adds faint guide lines, `/tl plate`
  a dark backing behind the slots). Two tracks converge on a vanishing point: boss abilities on
  the left, cooldowns on the right. Things start small and faint in the
  distance and grow as they close in; near ones get their label.
- Two "next up" slots sit at the bottom: the next boss ability and the next
  cooldown, each with a big countdown, name and class-coloured icon — shown
  even when they're further away than the 30 s track.
- `/tl depth <n>` sets how strong the perspective is (3 default), `/tl far <px>` the far-end icon size (10) — icons grow from that to the slot size (40) as they arrive,
  `/tl hudsize <w> <h>` the footprint (340×360), `/tl slot <px>` the slot icon
  size.
- `/tl layout single` gives the flat two-column view; `/tl layout lanes` a
  column per lane.

## Column views

- Two columns: **Boss** (BigWigs live timers, or planner rows) and
  **Cooldowns** (every healer and external, one stream). Each icon is bordered
  in the player's class colour with their name in that colour; a second player
  of the same class gets an extra gold ring. `/tl layout lanes` switches to a
  column per lane instead.
- Icons never overlap: simultaneous casts sit side by side, sequential ones
  stack, and anything that would run past the top waits until there's room.
- Free-text notes that name a spell ("Hold Dream Breath") use that spell's
  icon.
- Font: a bundled bold condensed face by default. `/tl font <name>` takes any
  LibSharedMedia font (Dander's Frames registers its fonts there — `/tl fonts`
  lists what's available), `/tl fontsize <n>` sizes it.
- 30 s visible by default. The bottom 5 s ("imminent" zone, marked by a faint
  line) takes ~40% of the height, so icons accelerate as they close in while
  the whole upcoming ramp stays readable above.
- Major cooldowns (planner flag, or anything ≥ 2 min) draw larger with a
  bright border and stay visible far up the column; minor ones sit back and
  brighten as they near.
- Boss lane always shows; `/tl onlymine` filters only the cooldown lanes.

## Raid night quick start

1. `/tl import` → paste your **Viserio plan export** (the long base64 blob from
   Viserio's export button). You get a Boss lane, one lane per healer (class
   coloured), and a Raid lane for externals/utility. Notes ("Hold Dream
   Breath") show as note icons in that healer's lane.
2. `/tl unlock`, drag, `/tl lock`. `/tl test 180` previews the 3-minute stack.
3. Pull. The plan has no encounter ID, so it's used for the first boss you
   pull and chat tells you `/tl assign <id>` to bind it permanently.
4. With BigWigs loaded, its live timers appear in the Boss lane automatically
   (`/tl bw` toggles). Static boss rows from the planner are hidden while
   BigWigs is feeding bars, so there are no duplicates.

## Install

1. Copy the `CDTimeline` folder into `World of Warcraft\_retail_\Interface\AddOns\`.
2. `/reload` or restart the game.
3. If the game marks it out of date, tick "Load out of date AddOns" or bump
   `## Interface:` in `CDTimeline.toc` to your client's version.

## Use

    /tl import        paste the note string, click Import
    /tl unlock        drag the bar where you want it, then /tl lock
    /tl test          plays the last-imported note from 0s
    /tl test 300      ...or starting 300 s in, to check a specific window
    /tl pull 10       simulates a 10 s pull timer to check arming

## When the clock starts

Two triggers, both on by default:

- **Pull timer** (Blizzard `/countdown`, which DBM and BigWigs both use in a
  group; DBM / BigWigs addon syncs as a fallback). The bar arms immediately, a
  "PULL" marker slides in and hits the line at zero, and anything due in the
  first few seconds has room to appear. It arms the boss you last fought, or
  failing that the last note you imported — `/tl use <encounterID>` pins a
  specific one. If no encounter starts within 20 s of the timer ending, the
  bar clears itself. A cancelled countdown clears it too.
- **`ENCOUNTER_START`** — the game's own "boss pulled" event, which is the
  zero point Viserio's times are measured from. If the bar was armed from a
  pull timer, the clock is re-synced to this moment so an early/late pull
  doesn't drift the rest of the fight. If it wasn't armed, it just starts here.

The addon looks up a note by encounter ID and difficulty. If it has the boss
but not that difficulty (e.g. you imported Heroic and pull Mythic), it uses
what it has and says so in chat.

## Settings

    /tl window <sec>   seconds visible above the now line (default 30)
    /tl imminent <sec> the fast bottom zone (default 5)
    /tl size <px>      icon size (default 28)
    /tl major <scale>  how much larger major cooldowns draw (default 1.35)
    /tl options           every setting in a window
    /tl graph | graph all | graphsize <w> <h> | graphpos reset   the fight graph
    /tl layout stack|hud|single|lanes   stack (default): one column, cooldowns in the top row
    /tl stacksize <w> <h> | rowicon <px> | bosslane <px> | linear | all   stack sizes / boss lane / speed / everyone's casts
    /tl mine              (hud/single/lanes) toggle the own-cooldowns column
    /tl minepos reset     re-attach the column to the plan bar;  /tl mineoffset <px>  gap when attached
    /tl track add <id> [other] | remove <id> | reset   the Major / Other spell lists (per spec)
    /tl sched | ready | combat | border | swipe | numbers   column toggles
    /tl debug             what the column sees (secret vs readable cooldowns, model, schedule)
    /tl minesize <icon> <height>  column sizes (height only when free-standing)
    /tl cols <px>      Cooldowns column width (default 232)
    /tl bosscols <px>  Boss column width (default 140)
    /tl labels <px>    text width beside icons (default 76; 0 = icons only)
    /tl font <name>    bundled | poppins | LibSharedMedia font name; /tl fonts lists
    /tl fontsize <n>   font size (default 11)
    /tl height <px>    bar height (default 420)
    /tl headers        toggle lane headers
    /tl ticks          toggle time tick lines
    /tl alpha <0-1>    bar background opacity
    /tl names          toggle the player-name label
    /tl time           toggle the countdown text
    /tl onlymine       plan bar: show only cooldowns tagged with your character name
    /tl pulltimer      toggle arming from pull timers
    /tl bw             toggle BigWigs live boss timers
    /tl assign <id>    bind the last import to an encounter ID
    /tl last           show the last encounter ID fought
    /tl use <id> [diff]   pin a boss (and difficulty) for pull timers (/tl use clear to unpin)
    /tl select <id> [diff]   pick a stored plan for test / phases / assign without pinning
    /tl plans          the Plans page: what's loaded, switch boss / difficulty / phase timers
    /tl list           stored bosses
    /tl delete <id>    remove a stored boss
    /tl reset          reset settings (keeps stored notes)

## Formats that line up

- **Viserio plan export** (base64 blob) → `/tl import` directly, or through either planner.
- **CD Timeline string** → what both planners export; `/tl import` reads it. Boss lane + a lane per healer.
- **NSRT / MRT note** → what Viserio's own import and NSRT read; the planners export it too.

## Note formats

Viserio plan export (base64 MessagePack) — pasted as-is; lanes per healer.


Plain Viserio / NSRT (single Raid CD lane):

    EncounterID:3492;Difficulty:Heroic;Name:Ula'tek;
    ph:1;time:25.8;tag:Knols;spellid:31884;

Ramp Planner export (lanes, boss mechanics, cooldown lengths, major flags):

    EncounterID:3492;Difficulty:Mythic;Name:Ula'tek;
    lanedef:boss;name:Boss mechanic;kind:boss;
    lanedef:raid;name:Raid CD;kind:raid;
    ph:1;time:27;tag:BOSS;spellid:0;lane:boss;label:Venom Breath;cd:0;major:0;
    ph:1;time:25.8;tag:Knols;spellid:31884;lane:raid;label:Avenging Wrath;cd:120;major:1;

Rows may be one per line or all on one line.

## Phases

Viserio's note strings give each row's time **relative to the start of its
phase** (`ph:2;time:27.5;` = 27.5 s into phase 2) and say nothing about when
the phases begin. The addon handles that in three layers:

1. **Live.** Phase 1 rows are anchored at the pull. Rows of a later phase stay
   out of sight until the boss mod reports that stage (BigWigs
   `BigWigs_SetStage`, DBM `DBM_SetStage`), then they're anchored to that
   moment and slide in normally. `/tl phase 3` marks a stage by hand.
2. **Learned.** Every stage change is remembered per boss and difficulty, so
   on the next pull all phases are placed from the start (and re-anchored if
   the stage comes early or late).
3. **Given.** `/tl phases 0,95,200,300` sets the starts for the last import,
   or the string can carry them as `phase:2;start:95;` lines (the planners
   read and write these). `/tl phases` shows what's known, learned or
   estimated.

`/tl test` and the graph use the known starts and estimate the rest by
stacking each unknown phase after the previous phase's last row (marked
`P3?`). A real pull never uses an estimate.

## Cooldown healing and defensives (v0.24)

- Boss summary: damage grows from the left; each cooldown's estimated contribution grows in from the right on the same block scale —
  **striped** = extra healing, **dotted** = damage prevented. Estimates are measured, not guessed: top-8 Mythic Holy Paladin kills per boss
  (Warcraft Logs healing over time + Lorrgs casts, Oct 2026). Wings = extra healing while up (+10% Nek'zali, +13% Sentinels, +37% Lost Explorers
  of normal throughput); Divine Toll = extra healing per cast (≈0.9 / 0.9 / 1.6 s of normal throughput); Aura Mastery = 12% of raid damage
  for 8 s (wiki value last confirmed for 10.2). Hover a cooldown for its estimate and source.
- `/tl hps <k>` sets your own healing per second (e.g. `/tl hps 250`); until then the top-8 reference (~385–400k) is used and the header says so.
- **+** on a healer column adds a spell column: healing cooldowns or personal defensives (Paladin: Divine Protection 8 s / 1 min,
  Divine Shield 8 s / 5 min, Blessing of Sacrifice 12 s / 2 min, Blessing of Protection 10 s / 5 min, Lay on Hands).
  It drops a cast at 0:30 — drag it into place; the block shows its duration, the rail its cooldown.

## Colour-blind-safe (v0.23)

- Data colours are Okabe–Ito (safe for red–green colour blindness), and colour is never the only cue:
  damage under a major cooldown is **striped blue**, uncovered damage **solid orange**; an uncovered big hit gets a **hollow marker**,
  **warning stripes** over its damage and the words **"no CD"**; cooldown effects have their own pattern (Aura Mastery solid, Wings striped, Divine Toll dotted).
- `/tl graphbg` turns the fight graph's panel off: blocks float over the game, text is outlined, no grid lines.
- Patterns live in `Media/` (hatch.tga, dots.tga). New files need a full game restart, not just /reload.

## Squared paper (v0.22)

- Boss summary and fight graph are drawn on a grid. Damage (and healing, where the plan has it) builds up in whole blocks of a fixed size
  (the scale, e.g. "1 block = 100k/s", is in the heading/legend). Cooldown effect blocks, cooldown rails and ability bands snap to the grid;
  cooldown icons stay on their exact second. On the fight graph only lasting cooldowns (Aura Mastery, Wings…) get a strong green column.

## Follow the fight (v0.21)

- On by default (`/tl follow` toggles). Each BigWigs bar is matched to the plan's boss ability by spell name. If the real hit is early or late,
  that hit, the cooldowns assigned to it and everything after it slide by the same amount, so each cooldown keeps its gap to its hit
  (e.g. 1 s before) even when a health-gated stage starts sooner. Shifts of 3 s or more are reported in chat. The saved plan is never changed.
- Boss summary: each spell has its own column; a faded block under each cast shows how long it lasts, a thin rail how long it's on cooldown.
  Each big ability has a faded band over the damage that follows it, a dot on its peak and the peak on its label.

## Boss summary, per-class plans, fight graph (v0.20)

- **Plans per class.** Each class keeps its own plans: log in on your Paladin and only Paladin plans load (chat says how many).
  Importing a plan written for another class (every cooldown row that class) files it under that class instead.
- **`/tl plan`** (or `/tl plan ula`) opens the boss summary: a vertical timeline, time running down. Left to right: time ·
  raid damage (bar length = how hard it hits; amber, green where a major cooldown runs) · boss hits (purple = covered, red = nothing on it;
  repeats grouped "×6"; hover for details) · one column per healer. `<` `>` flip through your bosses.
  Drag a cooldown up/down to move it (snaps to the nearest big hit; Shift = free); drag an icon from a column header to add a cast;
  right-click unlinks, Shift+right-click deletes; red border = still on cooldown. Saves at once; Undo all / Export.
- **Fight graph:** your cooldowns sit along the bottom over the damage, each with a transparent green column for as long as it lasts.
- Falling views: a line from each cooldown to its boss hit; boss icons read the short name, then `2.3m  AM+Wings` or `2.3m  no CD`.
  `/tl links`, `/tl dmgshow`, `/tl dmgscale`, `/tl planboss`.

## Anchors (v0.18)

A cooldown row can follow a boss ability instead of the clock:

    ph:1;time:177;tag:Knols;spellid:31821;lane:p_knols;label:Aura Mastery → Contaminate #4;cd:180;major:1;class:Paladin;anchor:1284257;n:4;offset:-2;

`anchor` is the ability's spell ID (or a piece of its BigWigs bar text), `n` the
occurrence, `offset` seconds relative to the end of that bar (negative = before
the hit). The row sits at its planned `time` until BigWigs starts the n-th bar
for that ability; then it snaps to bar end + offset, re-sorts, and slides in from
there. Health-based phases that come late in a slow pug no longer pull the
cooldowns early. A restarted bar re-times the same rows; a row that is already
past is left alone. `/tl anchorchat` prints a line each time rows move.
Anchored rows are re-timed on per-pull copies, so the stored plan keeps its
planned times. Rows without `anchor` behave exactly as before.

## Not yet

- Reading the note directly from NSRT's saved variables

## Fonts

`Fonts/BarlowCondensed-Bold.ttf`, `BarlowCondensed-SemiBold.ttf`,
`Barlow-SemiBold.ttf`, `Barlow-Medium.ttf` (SIL OFL, `Fonts/OFL-Barlow.txt`),
`DejaVuSansCondensed-Bold.ttf` (DejaVu licence) and `Poppins-Bold.ttf` (SIL
OFL) are bundled. `/tl font bundled | condensed | barlow | dejavu | poppins`. Any font another addon registers with LibSharedMedia
(Dander's Frames, ElvUI, SharedMedia packs) can be selected by name.

## 0.27.0
- New **Graph** options tab: text size, cooldown icon size, background on/off + opacity, width/height, title/clock, boss-hit row and legend toggles, reset position. Slash: `/tl graphfont <7-24>`, `/tl graphicon <8-40>`, `/tl graphalpha <0-1>`, `/tl graphtitle`, `/tl graphboss`, `/tl graphlegend`.
- Arrows and long dashes (which the game font draws as a box) are replaced with `>` and `-` everywhere, including plans you already imported.
- The column now warns `late +N` ahead of time when a cooldown won't be back before its planned use.

## 0.28.0
- The fight graph is now **vertical** by default, like `/tl plan` and the pull sheets: time runs down, damage in blocks on the left, the big boss hits named in the middle (with the cooldowns that cover them, or "no CD"), one column per cooldown of yours on the right with its heal window (pale), effect (solid), cooldown rail and icon. In a fight the paper scrolls under a fixed now line; out of a fight, unlock and use the mouse wheel to scroll. `/tl graphvert` switches back to left-to-right.
- **Stasis windows** (Evoker): each store is joined to its release by a dotted bar, with a note naming the hit it's for and the damage while you ramp and when you release.
- Plan rows can carry `win:<open>,<close>;` (seconds around the ideal time).
- Graph tab: seconds visible, now-line position, size, damage blocks across.
