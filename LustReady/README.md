# LustReady 0.1.0

Shows **LUST AVAILABLE** and plays a sound:
- when you pull a raid or dungeon boss (M+ included) and you don't have Exhaustion, Sated, Temporal Displacement or Fatigued
- the moment that debuff wears off (raids and dungeons by default)

It only reads your own debuffs and the boss pull – nothing is sent to anyone.

## Commands (`/lust` or `/lustready`)
- `/lust` – status (are you Exhausted, how long left) and settings
- `/lust test` – preview the alert
- `/lust pull` · `/lust expire` – turn either alert on or off
- `/lust anywhere` – expiry alert everywhere, not just raids and dungeons
- `/lust mine` – only alert on characters that can cast lust themselves
- `/lust sound` – cycle the sound and hear it: dragon roar (default), your own Sounds\lust.ogg, raid warning, ready check, alarm, epic loot · `/lust nosound`
- `/lust move` – drag the alert, `/lust move` again to lock · `/lust scale 1.2` · `/lust reset`
