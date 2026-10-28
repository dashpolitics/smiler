-- SmilerKeys: core, saved variables, events, slash commands
local ADDON, ns = ...

ns.VERSION = "0.13.0"
ns.PREFIX  = "SmilerKeys"
ns.PROTO   = "1"

ns.maps, ns.mapById = {}, {}
ns.season = 0

local DEFAULTS = {
  channels   = { guild = true, friends = true, bnet = true, party = true },
  maxAgeDays = 21,
  hidden     = {},
  abbr       = {},
  acct       = {},     -- manual character -> account assignments
  showAlts   = true,
  glow       = true,   -- outline keys and cells where a key is an upgrade
  tp         = {},     -- manual dungeon -> teleport spell overrides
  lootWithChar = true, -- wishlist opens beside the character sheet
}

function ns.Print(...)
  print("|cffb98cffSmilerKeys|r", ...)
end

function ns.Now() return GetServerTime() end

local myRealm
function ns.Realm()
  if not myRealm or myRealm == "" then myRealm = GetNormalizedRealmName() or "" end
  return myRealm
end

-- "Name" or "Name-Realm" -> "Name-Realm" (no spaces)
function ns.Normalize(name)
  if not name or name == "" then return nil end
  if not name:find("-", 1, true) then name = name .. "-" .. ns.Realm() end
  return (name:gsub("%s", ""))
end

function ns.NormalizeRealm(realm)
  return realm and (realm:gsub("[%s%-]", "")) or nil
end

-- Your own BattleTag (same on every character on this account)
function ns.MyTag()
  if not BNGetInfo then return nil end
  local _, tag = BNGetInfo()
  if not tag or (issecretvalue and issecretvalue(tag)) or tag == "" then return nil end
  return (tag:gsub("[~;,|]", ""))
end

-- Every WoW (retail) game account of every online Battle.net friend. A friend's "main" game
-- account can be the Battle.net app rather than WoW, so look at all of them.
-- fn(gameAccountID, battleTag, characterName, realmName, accountIndex)
function ns.ForEachBNetWoW(fn)
  if not BNGetNumFriends or not C_BattleNet then return end
  local myGuid = UnitGUID("player")
  local function sec(v) return issecretvalue and issecretvalue(v) end
  for i = 1, (BNGetNumFriends()) or 0 do
    local acc = C_BattleNet.GetFriendAccountInfo(i)
    if acc then
      local tag = acc.battleTag and not sec(acc.battleTag) and acc.battleTag or nil
      local n = C_BattleNet.GetFriendNumGameAccounts and C_BattleNet.GetFriendNumGameAccounts(i) or 0
      local seen = {}
      local function try(g)
        if g and g.gameAccountID and not seen[g.gameAccountID] and g.isOnline
          and g.clientProgram == BNET_CLIENT_WOW
          and (not g.wowProjectID or g.wowProjectID == WOW_PROJECT_MAINLINE)
          and g.playerGuid ~= myGuid then
          seen[g.gameAccountID] = true
          fn(g.gameAccountID, tag, g.characterName, g.realmName, i)
        end
      end
      for j = 1, n do try(C_BattleNet.GetFriendGameAccountInfo(i, j)) end
      try(acc.gameAccountInfo)
    end
  end
end

ns.stats = { sent = 0, recv = 0, log = {} }
function ns.LogRecv(who, channel, what)
  ns.stats.recv = ns.stats.recv + 1
  table.insert(ns.stats.log, 1, { t = GetTime(), who = who or "?", ch = channel, what = what })
  while #ns.stats.log > 8 do table.remove(ns.stats.log) end
end

function ns.Age(ts)
  if not ts or ts == 0 then return "?" end
  local d = ns.Now() - ts
  if d < 90 then return "now" end
  if d < 3600 then return math.floor(d / 60) .. "m" end
  if d < 86400 then return math.floor(d / 3600) .. "h" end
  return math.floor(d / 86400) .. "d"
end

local pending = {}
function ns.Debounce(id, delay, fn)
  if pending[id] then return end
  pending[id] = true
  C_Timer.After(delay, function() pending[id] = nil; fn() end)
end

---------------------------------------------------------------- events
local ev = CreateFrame("Frame")
ns.eventFrame = ev
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:SetScript("OnEvent", function(_, e, ...)
  local fn = ns[e]
  if fn then fn(...) end
end)

local function copyDefaults(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      copyDefaults(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

function ns.ADDON_LOADED(name)
  if name ~= ADDON then return end
  SmilerKeysDB = SmilerKeysDB or {}
  SmilerKeysDB.wish = SmilerKeysDB.wish or {}
  SmilerKeysDB.players  = SmilerKeysDB.players or {}
  SmilerKeysDB.settings = SmilerKeysDB.settings or {}
  copyDefaults(SmilerKeysDB.settings, DEFAULTS)
  SmilerKeysDB.settings.chars = SmilerKeysDB.settings.chars or {}
  ns.db = SmilerKeysDB
end

-- Settings that belong to one character rather than the whole account: the Where to go plan, this
-- week's boss map, which spec and difficulty you are ticking bonus rolls off on. These all used to
-- live in the single account-wide settings table, so Knols' plan turned up on Bearbacker. Window
-- positions, channels and the look of things stay account-wide, which is what you want there.
function ns.CharSettings()
  local s = ns.db and ns.db.settings
  if not s then return {} end
  s.chars = s.chars or {}
  local k = ns.selfKey or "?"
  s.chars[k] = s.chars[k] or {}
  return s.chars[k]
end

function ns.PLAYER_LOGIN()
  ns.selfKey = ns.Normalize(UnitName("player"))
  C_ChatInfo.RegisterAddonMessagePrefix(ns.PREFIX)
  for _, e in ipairs({
    "CHALLENGE_MODE_MAPS_UPDATE", "CHALLENGE_MODE_COMPLETED", "BAG_UPDATE_DELAYED",
    "GROUP_ROSTER_UPDATE", "CHAT_MSG_ADDON", "BN_CHAT_MSG_ADDON",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED",
    "BN_FRIEND_INFO_CHANGED", "FRIENDLIST_UPDATE",
  }) do ev:RegisterEvent(e) end

  ns.CommStart()
  if IsInGuild() and C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
  C_Timer.After(15, function() ns.PruneStrangers(); ns.UI_Refresh() end)
  C_MythicPlus.RequestMapInfo()
  C_MythicPlus.RequestCurrentAffixes()
  -- fallback if the maps event never fires
  C_Timer.After(12, function() if #ns.maps == 0 then ns.CHALLENGE_MODE_MAPS_UPDATE() end end)
end

function ns.PLAYER_LOGOUT()
  for k, p in pairs(ns.db.players) do
    if p.test then ns.db.players[k] = nil end
  end
end

function ns.CHALLENGE_MODE_MAPS_UPDATE()
  if not ns.RefreshMaps() then return end
  local s = C_MythicPlus.GetCurrentSeason()
  if s and s > 0 then ns.season = s end
  ns.Purge()
  ns.UpdateSelf()
  if not ns.announced then
    ns.announced = true
    C_Timer.After(4, function() ns.Broadcast(true); ns.ScanParty() end)
  end
  ns.UI_Rebuild()
end

-- Teleport buttons are secure, so the window can't change during combat:
-- close it as combat starts (still allowed at this point) and bring it back afterwards.
function ns.PLAYER_REGEN_DISABLED()
  if ns.UI_IsShown() then ns.reopen = true; ns.UI_Hide() end
end

function ns.PLAYER_REGEN_ENABLED()
  if ns.spellsDirty then ns.spellsDirty = false; ns.FindTeleports() end
  if ns.reopen then ns.reopen = false; ns.UI_Toggle() end
end

function ns.SPELLS_CHANGED()
  ns.Debounce("spells", 2, function()
    if InCombatLockdown() then ns.spellsDirty = true; return end
    ns.FindTeleports(); ns.UI_Rebuild()
  end)
end

-- When a friend comes into WoW, say hello so you both swap data without anyone typing /sk sync
local greeted = {}
function ns.BN_FRIEND_INFO_CHANGED()
  if not ns.announced or not ns.db.settings.channels.bnet then return end
  ns.Debounce("bngreet", 3, function()
    ns.ForEachBNetWoW(function(id)
      if not greeted[id] then
        greeted[id] = true
        ns.SendTo("BN", id)
      end
    end)
  end)
end

local greetedChar = {}
function ns.FRIENDLIST_UPDATE()
  if not ns.announced or not ns.db.settings.channels.friends then return end
  ns.Debounce("chargreet", 3, function()
    for i = 1, C_FriendList.GetNumFriends() or 0 do
      local f = C_FriendList.GetFriendInfoByIndex(i)
      if f and f.connected and f.name and f.name ~= "" and not greetedChar[f.name] then
        greetedChar[f.name] = true
        ns.SendTo("WHISPER", f.name)
      end
    end
  end)
end

function ns.CHALLENGE_MODE_COMPLETED()
  C_Timer.After(5,  function() C_MythicPlus.RequestMapInfo() end)
  C_Timer.After(25, function() C_MythicPlus.RequestMapInfo() end)
end

function ns.BAG_UPDATE_DELAYED()
  ns.Debounce("key", 1.5, function()
    local me = ns.db.players[ns.selfKey]
    local m = C_MythicPlus.GetOwnedKeystoneChallengeMapID() or 0
    local l = C_MythicPlus.GetOwnedKeystoneLevel() or 0
    if not me or me.keyMap ~= m or me.keyLevel ~= l then ns.UpdateSelf() end
  end)
end

local lastGroupSize = 0
function ns.GROUP_ROSTER_UPDATE()
  ns.Debounce("party", 2, function()
    local n = GetNumGroupMembers()
    if n > lastGroupSize and n > 1 then ns.SendToGroup() end
    lastGroupSize = n
    ns.ScanParty()
  end)
end

---------------------------------------------------------------- slash
local HELP = {
  "/sk  – toggle the grid",
  "/sk sync  – broadcast now and ask everyone for theirs",
  "/sk loot  – your wishlist beside the character sheet",
  "/sk guide  – walk through each slot · /sk browse – the loot list · /sk import – import QE / Raidbots upgrades",
  "/sk debug  – who SmilerKeys can reach, and what it has sent and received",
  "/sk guild|friends|bnet|party  – toggle sharing on a channel",
  "/sk link <character> <account>  – group a character under an account (no account = unlink)",
  "/sk alts  – show or hide alts",
  "/sk glow  – toggle upgrade glow (hovering a key always shows who it upgrades)",
  "/sk tp <column> <spellID|clear>  – set the teleport for a dungeon column by hand",
  "/sk abbr <column> <text>  – rename a dungeon column (e.g. /sk abbr 3 ARAK)",
  "/sk rolls  – a button per boss (Heroic/Mythic) and dungeon: hover for what a bonus roll can still give you",
  "/sk void [name|raw <id>]  – what a bonus roll can still give you, per boss and dungeon",
  "/sk targets  – one row per slot: your target, your BiS and alternatives, in your own order",
  "/sk why <item name or id>  – why an item is, or is not, in Where to go",
  "/sk unhide  – show players you hid",
  "/sk forget <name>  – drop one person · /sk clear – forget everyone except you",
  "/sk test  – toggle fake players for layout testing",
}

SLASH_SMILERKEYS1, SLASH_SMILERKEYS2 = "/sk", "/smilerkeys"
SlashCmdList.SMILERKEYS = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
  cmd = cmd:lower()
  if cmd == "" then
    ns.UI_Toggle()
  elseif cmd == "debug" then
    ns.Debug()
  elseif cmd == "loot" then
    ns.LootToggle()
  elseif cmd == "guide" then
    ns.GuideOpen()
  elseif cmd == "plan" or cmd == "where" then
    ns.PlannerOpen()
  elseif cmd == "targets" or cmd == "target" then
    ns.TargetsOpen()
  elseif cmd == "why" then
    ns.WhyReport(rest)
  elseif cmd == "void" or cmd == "voidcache" then
    ns.VoidcacheReport(rest)
  elseif cmd == "rolls" or cmd == "roll" then
    ns.RollsOpen()
  elseif cmd == "browse" then
    ns.LootBrowse({})
  elseif cmd == "import" then
    ns.ImportOpen()
  elseif cmd == "options" or cmd == "settings" or cmd == "config" then
    if Smiler and Smiler.OpenSettings then Smiler:OpenSettings("SmilerKeys") else ns.Print("Settings need the Smiler add-on.") end
  elseif cmd == "sync" then
    ns.Broadcast(true); ns.ScanParty(); ns.Print("Sync sent.")
  elseif ns.db.settings.channels[cmd] ~= nil then
    ns.ToggleChannel(cmd)
  elseif cmd == "link" then
    local who, acct = rest:match("^(%S+)%s*(.-)$")
    local key = who and ns.FindPlayer(who)
    if key then ns.Assign(key, acct) else ns.Print("Usage: /sk link <character> <account> – character must already be in the grid") end
  elseif cmd == "alts" then
    ns.db.settings.showAlts = not ns.db.settings.showAlts
    ns.Print("Alts", ns.db.settings.showAlts and "shown" or "hidden")
    ns.UI_Refresh()
  elseif cmd == "tp" then
    local col, val = rest:match("^(%d+)%s*(%S*)$")
    local m = col and ns.maps[tonumber(col)]
    if not m then ns.Print("Usage: /sk tp <column 1-" .. #ns.maps .. "> <spellID|clear>"); return end
    if InCombatLockdown() then ns.Print("Try again after combat."); return end
    ns.db.settings.tp[m.id] = tonumber(val)
    ns.FindTeleports(); ns.UI_Rebuild()
    ns.Print(m.name, "teleport:", m.tp and (C_Spell.GetSpellName(m.tp) or m.tp) or "none")
  elseif cmd == "glow" then
    ns.db.settings.glow = not ns.db.settings.glow
    ns.Print("Upgrade glow", ns.db.settings.glow and "on" or "off")
    ns.UI_Refresh()
  elseif cmd == "abbr" then
    local col, text = rest:match("^(%d+)%s+(.+)$")
    local m = col and ns.maps[tonumber(col)]
    if m then
      ns.db.settings.abbr[m.id] = text
      ns.RefreshMaps(); ns.UI_Rebuild()
      ns.Print(m.name, "→", text)
    else
      ns.Print("Usage: /sk abbr <column 1-" .. #ns.maps .. "> <text>")
    end
  elseif cmd == "unhide" then
    wipe(ns.db.settings.hidden); wipe(ns.tempHidden or {}); ns.UI_Refresh(); ns.Print("All players visible.")
  elseif cmd == "forget" and rest ~= "" then
    local key = ns.FindPlayer(rest)
    if key and key ~= ns.selfKey then ns.db.players[key] = nil; ns.UI_Refresh(); ns.Print("Forgot " .. key .. ".")
    else ns.Print("No one in the grid matches '" .. rest .. "'.") end
  elseif cmd == "clear" then
    local me = ns.db.players[ns.selfKey]
    wipe(ns.db.players); ns.db.players[ns.selfKey] = me
    ns.UI_Refresh(); ns.Print("Cleared.")
  elseif cmd == "test" then
    ns.ToggleTest()
  else
    for _, l in ipairs(HELP) do ns.Print(l) end
  end
end

function ns.ToggleChannel(name)
  local c = ns.db.settings.channels
  c[name] = not c[name]
  ns.Print(name, c[name] and "sharing ON" or "sharing OFF")
  ns.UI_Refresh()
end

function SmilerKeys_OnAddonCompartmentClick()
  ns.UI_Toggle()
end
