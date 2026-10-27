# Rewound 0.2.0

Tracks your Preservation Evoker Rewind healing and announces a new record.

Install: unzip so the folder sits at `World of Warcraft/_retail_/Interface/AddOns/Rewound/`.

## Commands
`/rw` is the game's raid warning, so the command is `/rewound`.
- `/rewound` – settings window (also the addon compartment button, and Options → AddOns → Rewound)
- `/rewound stats` · `/rewound test` · `/rewound spells` · `/rewound addid <spellID>` · `/rewound reset`

## Settings
- Records – best overall, best per content type, last 10 Rewinds; clear history, reset all
- Announce – on/off; channel (Auto, Party, Raid, Guild, Only me); your own message with
  {amount} {avg} {prev} {gain} {where} {casts} {total} {kind}; live preview; minimum improvement
  before announcing; optional M+ / raid / dungeon bests
- Display – record toast, small toast per Rewind, sound and which one, size, how long it stays, move/lock, reset position
- Tracking – M+, raids, dungeons, everything else; only in a group; counted spell IDs; last fight's healing by spell with Count buttons

## How it measures
Midnight gives addons no combat log. Rewound counts your Rewind casts and reads your own healing per spell
from the game's damage meter when combat ends. One Rewind in a fight = that cast's exact healing;
two or more = the average, labelled "avg of N". Chat messages wait until an active key or boss ends.
