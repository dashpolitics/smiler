-- SmilerStash: your loot currencies at a glance, upgrade heads-ups, and where this week's Ascendant Venomstones can still come from, and what you've already done.
-- Tracks by itself, per character: Restored Coffer Keys, Afflicted / Tormented Souls (bags and warband bank),
-- bountiful delves still up today, Dundun, the Labyrinth of Kindo'jan, Nightmare Prey, and Heroic / Mythic
-- raid kills from your lockouts. Every Venomstone you pick up is booked to where you were when it landed.
-- /stash (or /venom). The currency rows and upgrade checks live in Stash.lua.
local ADDON, ns = ...
local S = Smiler

---------------------------------------------------------------- what we look at
local ID = {
  stone     = 280562,   -- Ascendant Venomstone (item)
  afflicted = 276547,   -- Afflicted Soul (item)
  tormented = 276548,   -- Tormented Soul (item)
  keys      = 3028,     -- Restored Coffer Key (currency)
}
local NAME = { stone = "Venomstone", keys = "Restored Coffer Key" }
-- the season's raids that drop a Venomstone per Heroic / Mythic boss (matched against journal and lockout names)
-- The Venomous Abyss, plus the two lairs (one boss each, flexible Mythic): Kith'ix and Nymrissa's Tidebound Grotto
local SEASON_RAIDS = { "Venomous Abyss", "Kith'ix", "Tidebound Grotto", "Nymrissa" }
local LABYRINTH = "Kindo'jan"
local NOT_MIDNIGHT = { [2274] = true, [2346] = true, [2371] = true }   -- Khaz Algar, Undermine, K'aresh: older delves
local PREY_WEEK = 4                                                     -- 2 hunts + 2 soul chests
-- Gilded Stash: after a Tier 11 delve, 4 a week (Delver's Journey rank 4), 5 Myth Mistcrests each.
-- Counted from Myth crests landing in a delve in steps of 5. Venomfall Deeps is skipped: its Nemesis also pays Myth crests.
local GILDED_WEEK, GILDED_CRESTS, NEMESIS_DELVE = 4, 5, "Venomfall"
local SOURCES = { { "raid", "Raid" }, { "mplus", "Mythic+" }, { "delve", "Delves" }, { "lab", "Labyrinth" },
                  { "world", "Prey & world" }, { "other", "Other" } }

local DEFAULTS = { chat = true, toast = true, loginLine = true, upgradeAlerts = true }
local db, me

---------------------------------------------------------------- small helpers
local function secret(v) return issecretvalue and issecretvalue(v) or false end
local function say(...) if S and S.Print then S.Print("|cffb66effStash|r", ...) else print("|cffb66effStash|r", ...) end end
ns.Say = say
local function charKey()
  local n, r = UnitFullName("player")
  r = (r and r ~= "") and r or (GetNormalizedRealmName and GetNormalizedRealmName()) or GetRealmName() or "?"
  return (n or "?") .. "-" .. r
end
local function untilWeekly() return (C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset and C_DateAndTime.GetSecondsUntilWeeklyReset()) or 0 end
local function untilDaily() return (C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset and C_DateAndTime.GetSecondsUntilDailyReset()) or 0 end
-- a reset is identified by the minute it happens, so every character agrees on it
local function weekId() return math.floor((time() + untilWeekly() + 30) / 60) end
local function dayId() return math.floor((time() + untilDaily() + 30) / 60) end
local function dur(s)
  s = math.max(0, math.floor(s or 0))
  local d, h, m = math.floor(s / 86400), math.floor(s % 86400 / 3600), math.floor(s % 3600 / 60)
  if d > 0 then return d .. "d " .. h .. "h" elseif h > 0 then return h .. "h " .. m .. "m" end
  return m .. "m"
end
local function itemCount(id, bank, warband)
  if not (C_Item and C_Item.GetItemCount) then return GetItemCount and GetItemCount(id, bank) or 0 end
  local ok, n = pcall(C_Item.GetItemCount, id, bank or false, false, bank or false, warband or false)
  return (ok and type(n) == "number" and not secret(n)) and n or 0
end
local currencyIdByName = {}
local function currencyByName(want)
  if currencyIdByName[want] ~= nil then return currencyIdByName[want] end
  currencyIdByName[want] = false
  if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListSize then
    for i = 1, C_CurrencyInfo.GetCurrencyListSize() do
      local info = C_CurrencyInfo.GetCurrencyListInfo(i)
      if info and not info.isHeader and info.name and info.name:find(want, 1, true) then
        local link = C_CurrencyInfo.GetCurrencyListLink and C_CurrencyInfo.GetCurrencyListLink(i)
        local id = link and tonumber(link:match("currency:(%d+)"))
        if id then currencyIdByName[want] = id; break end
      end
    end
  end
  return currencyIdByName[want]
end
local function currencyQty(id)
  if not (id and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) then return nil, nil end
  local info = C_CurrencyInfo.GetCurrencyInfo(id)
  if not info or not info.name or info.name == "" then return nil, nil end
  return info.quantity or 0, info.name
end

---------------------------------------------------------------- stocks
local function readKeys()
  local q, name = currencyQty(ID.keys)
  if q and name and name:find("Key") then return q end
  q = currencyQty(currencyByName(NAME.keys))
  return q or 0
end
local function readStones()
  local n = itemCount(ID.stone, true, true)
  if n == 0 then n = currencyQty(currencyByName(NAME.stone)) or 0 end
  return n
end
-- souls: bags (always right) and the warband bank (remembered from the last time the game could read it)
local function readSouls(c, key, id)
  local bags = itemCount(id, false, false)
  local withBank = itemCount(id, true, false)
  local all = itemCount(id, true, true)
  c[key] = withBank
  local wb = all - withBank
  if wb > 0 or db.bankOpen then db.warband[key] = wb end
  return withBank + (db.warband[key] or 0), bags
end

---------------------------------------------------------------- where you are
local lastKeyDone = 0
local function context()
  local inInst, kind = IsInInstance()
  local name = GetInstanceInfo()
  if not inInst then return "world" end
  if kind == "raid" then return "raid" end
  if kind == "party" then
    local active = C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive()
    if active or GetTime() - lastKeyDone < 600 then return "mplus" end
    return "other"
  end
  if kind == "scenario" or (C_PartyInfo and C_PartyInfo.IsDelveInProgress and C_PartyInfo.IsDelveInProgress()) then
    if name and name:find(LABYRINTH, 1, true) then return "lab" end
    return "delve"
  end
  return "other"
end

---------------------------------------------------------------- this character's week
local function freshWeek(c)
  c.week = weekId()
  c.gained = {}
  for _, s in ipairs(SOURCES) do c.gained[s[1]] = 0 end
  c.soulsUsed, c.labClears, c.labVisits, c.delvesDone, c.dundun = 0, 0, 0, 0, false
  c.raid = {}
  c.gilded = 0
end
local function meRow()
  local c = db.chars[me]
  if not c then c = {}; db.chars[me] = c; freshWeek(c) end
  if c.week ~= weekId() then freshWeek(c) end
  local _, cls = UnitClass("player"); c.class = cls
  c.name = UnitName("player")
  return c
end

---------------------------------------------------------------- raid lockouts
local raidTotals          -- [raid name] = bosses, from the Adventure Guide
local function seasonRaid(name)
  if not name then return false end
  for _, p in ipairs(SEASON_RAIDS) do if name:find(p, 1, true) then return true end end
  return false
end
local function readRaidTotals()
  if raidTotals then return raidTotals end
  if not EJ_GetNumTiers or (EncounterJournal and EncounterJournal.IsShown and EncounterJournal:IsShown()) then return {} end
  local t = {}
  local saved = EJ_GetCurrentTier and EJ_GetCurrentTier()
  pcall(function()
    EJ_SelectTier(EJ_GetNumTiers())
    local i = 1
    while i < 30 do
      local inst, name = EJ_GetInstanceByIndex(i, true); if not inst then break end
      if seasonRaid(name) then
        EJ_SelectInstance(inst)
        local n = 0
        while EJ_GetEncounterInfoByIndex(n + 1, inst) and n < 30 do n = n + 1 end
        t[name] = n
      end
      i = i + 1
    end
  end)
  if saved then pcall(EJ_SelectTier, saved) end
  if next(t) then raidTotals = t end
  return t
end
local function readLockouts(c)
  c.raid = {}
  local totals = readRaidTotals()
  for name, n in pairs(totals) do c.raid[name] = { [15] = { 0, n }, [16] = { 0, n } } end
  for i = 1, (GetNumSavedInstances and GetNumSavedInstances() or 0) do
    local name, _, reset, diff, locked, _, _, isRaid, _, _, numEnc, progress = GetSavedInstanceInfo(i)
    if isRaid and (diff == 15 or diff == 16) and reset and reset > 0 and seasonRaid(name) then
      c.raid[name] = c.raid[name] or { [15] = { 0, numEnc }, [16] = { 0, numEnc } }
      c.raid[name][diff] = { progress or 0, numEnc or (totals[name] or 0) }
    end
  end
end
local function raidSum(c, diff)
  local k, n = 0, 0
  for _, r in pairs(c.raid or {}) do local x = r[diff]; if x then k = k + x[1]; n = n + x[2] end end
  return k, n
end

---------------------------------------------------------------- bountiful delves up today
local delveMaps            -- maps that have any delves at all, found once
local function ancestors(mapID)
  local seen, id = {}, mapID
  for _ = 1, 10 do
    local info = id and C_Map.GetMapInfo(id); if not info then break end
    seen[id] = true; id = info.parentMapID
    if not id or id == 0 then break end
  end
  return seen
end
local function midnightMap(mapID)
  for a in pairs(ancestors(mapID)) do if NOT_MIDNIGHT[a] then return false end end
  return true
end
local function findDelveMaps()
  delveMaps = {}
  if not (C_Map and C_Map.GetMapChildrenInfo and C_AreaPoiInfo and C_AreaPoiInfo.GetDelvesForMap) then return end
  local kids = C_Map.GetMapChildrenInfo(946, Enum.UIMapType.Zone, true) or {}
  for _, m in ipairs(kids) do
    local ok, list = pcall(C_AreaPoiInfo.GetDelvesForMap, m.mapID)
    if ok and list and #list > 0 and midnightMap(m.mapID) then delveMaps[#delveMaps + 1] = m.mapID end
  end
end
local function readBountiful(c)
  if not delveMaps then findDelveMaps() end
  local up, seen = {}, {}
  for _, mapID in ipairs(delveMaps or {}) do
    for _, poi in ipairs(C_AreaPoiInfo.GetDelvesForMap(mapID) or {}) do
      if not seen[poi] then
        seen[poi] = true
        local info = C_AreaPoiInfo.GetAreaPOIInfo(mapID, poi)
        if info and info.atlasName and info.atlasName:lower():find("bountiful")
           and not (info.name and info.name:find(LABYRINTH, 1, true)) then
          up[#up + 1] = info.name or "?"
        end
      end
    end
  end
  table.sort(up)
  c.bountiful, c.bountifulDay = up, dayId()
end

---------------------------------------------------------------- the snapshot
local baseStones, baseSouls
local function update(quiet)
  if not db then return end
  local c = meRow()
  c.keys = readKeys()
  c.stones = readStones()
  local aff = readSouls(c, "afflicted", ID.afflicted)
  local tor = readSouls(c, "tormented", ID.tormented)
  local souls = aff + tor
  c.at = time()
  -- stones picked up since the last look, booked to where you are now
  if baseStones and c.stones > baseStones then
    local got, where = c.stones - baseStones, context()
    c.gained[where] = (c.gained[where] or 0) + got
    if not quiet then
      local total = 0; for _, v in pairs(c.gained) do total = total + v end
      if db.chat then say(string.format("+%d Venomstone (%s). %d this week, %d in stock.", got, ns.SourceName(where), total, c.stones)) end
      if db.toast and S and S.Toast then S:Toast({ kind = "upgrade", title = "+" .. got .. " Venomstone", sub = ns.SourceName(where) .. " · " .. total .. " this week", duration = 4 }) end
    end
  end
  baseStones = c.stones
  -- a soul gone from bags and warband bank together has been spent on a Prey hunt
  if baseSouls and souls < baseSouls and not db.bankOpen then c.soulsUsed = c.soulsUsed + (baseSouls - souls) end
  baseSouls = souls
  local _, eq = GetAverageItemLevel(); if type(eq) == "number" and not secret(eq) then c.ilvl = eq end
  local mythBefore = c.crests and c.crests.Myth
  if ns.ReadStock then pcall(ns.ReadStock, c) end
  local mythNow = c.crests and c.crests.Myth
  if mythBefore and mythNow and mythNow > mythBefore and context() == "delve" then
    local iname = GetInstanceInfo() or ""
    local gain = mythNow - mythBefore
    if not iname:find(NEMESIS_DELVE, 1, true) and gain % GILDED_CRESTS == 0 then
      c.gilded = math.min(GILDED_WEEK, (c.gilded or 0) + gain / GILDED_CRESTS)
      if not quiet and db.chat then say(string.format("Gilded Stash: %d of %d this week.", c.gilded, GILDED_WEEK)) end
    end
  end
  if ns.CheckUpgrades and not InCombatLockdown() then local ok, err = pcall(ns.CheckUpgrades, c, me, false); if not ok and db.debug then say(err) end end
  if ns.win and ns.win:IsShown() then ns.Refresh() end
end
function ns.Count(t) local n = 0; for _ in pairs(t or {}) do n = n + 1 end return n end
function ns.SourceName(k) for _, s in ipairs(SOURCES) do if s[1] == k then return s[2] end end return k end

---------------------------------------------------------------- the week, worked out
-- what's still out there for one character this week (M+ isn't counted: it has no cap)
function ns.Plan(c)
  local p = {}
  p.hK, p.hN = raidSum(c, 15)
  p.mK, p.mN = raidSum(c, 16)
  local today = c.bountifulDay == dayId()
  p.bountiful = today and #(c.bountiful or {}) or nil
  p.dundun = c.dundun and true or false
  p.prey = c.gained and c.gained.world or 0
  p.preyLeft = math.max(0, PREY_WEEK - p.prey)
  local keysWanted = (p.bountiful or 0) + (p.dundun and 0 or 1)
  p.keysShort = math.max(0, keysWanted - (c.keys or 0))
  p.delveStones = math.min(p.bountiful or 0, c.keys or 0)
  p.left = (p.hN - p.hK) + (p.mN - p.mK) + p.delveStones + p.preyLeft + (p.dundun and 0 or 1)
  p.total = 0
  for _, v in pairs(c.gained or {}) do p.total = p.total + v end
  return p
end

---------------------------------------------------------------- window
local C = (S and S.C) or {
  void = { 0.024, 0.012, 0.059 }, card = { 0.11, 0.063, 0.227 }, edge = { 0.549, 0.314, 0.863 },
  text = { 0.94, 0.92, 1 }, soft = { 0.85, 0.78, 1 }, muted = { 0.71, 0.63, 0.86 }, amethyst = { 0.71, 0.43, 1 },
  emerald = { 0, 0.9, 0.46 }, topaz = { 1, 0.67, 0 }, ruby = { 1, 0.18, 0.33 }, sapphire = { 0.36, 0.61, 1 }, diamond = { 0.91, 0.96, 1 },
}
local function rgb(n, a) local c = C[n] or C.text; return c[1], c[2], c[3], a or 1 end
local function text(parent, role, size, color, justify)
  if S and S.Text then return S.Text(parent, role, size, color, justify) end
  local f = parent:CreateFontString(nil, "OVERLAY"); f:SetFont("Fonts\\ARIALN.TTF", size, ""); f:SetTextColor(rgb(color))
  f:SetJustifyH(justify or "LEFT"); f:SetShadowOffset(1, -1); return f
end
local function panel(f, bg, a, e)
  if S and S.Panel then return S.Panel(f, bg, a, e) end
  if not f.SetBackdrop then Mixin(f, BackdropTemplateMixin) end
  f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
  f:SetBackdropColor(rgb(bg or "void", a or 0.96)); f:SetBackdropBorderColor(rgb("edge", e or 0.38))
end
-- status mark: a word and a shape, never colour alone
local MARK = { done = { "DONE", "emerald", "tick" }, left = { "LEFT", "topaz", "arrow" }, none = { "-", "muted", "dot" }, info = { "", "sapphire", "info" } }
local function setMark(row, kind)
  local m = MARK[kind]
  row.tag:SetText(m[1]); row.tag:SetTextColor(rgb(m[2]))
  if S and S.Icon then row.icon:SetTexture(S.Icon(m[3])); row.icon:SetVertexColor(rgb(m[2])); row.icon:Show() else row.icon:Hide() end
end

local W_ = 560
local rows, tiles, cells = {}, {}, {}
local function tile(i, x, y)
  local t = tiles[i]
  if not t then
    t = CreateFrame("Frame", nil, ns.win, "BackdropTemplate"); t:SetSize(126, 54); panel(t, "card", 0.9, 0.5)
    t.v = text(t, "display", 22, "text"); t.v:SetPoint("TOPLEFT", 8, -6)
    t.l = text(t, "label", 11, "muted"); t.l:SetPoint("BOTTOMLEFT", 8, 6); t.l:SetWidth(112)
    t:EnableMouse(true)
    t:SetScript("OnEnter", function(s) if not s.tip then return end GameTooltip:SetOwner(s, "ANCHOR_BOTTOM"); for _, l in ipairs(s.tip) do GameTooltip:AddLine(l, 1, 1, 1, true) end GameTooltip:Show() end)
    t:SetScript("OnLeave", GameTooltip_Hide)
    tiles[i] = t
  end
  t:ClearAllPoints(); t:SetPoint("TOPLEFT", x, y)
  return t
end
local function row(i, y)
  local r = rows[i]
  if not r then
    r = CreateFrame("Frame", nil, ns.win); r:SetSize(W_ - 28, 22)
    r.icon = r:CreateTexture(nil, "OVERLAY"); r.icon:SetSize(12, 12); r.icon:SetPoint("LEFT", 0, 0)
    r.tag = text(r, "label", 11, "muted"); r.tag:SetPoint("LEFT", 16, 0); r.tag:SetWidth(36)
    r.l = text(r, "strong", 13, "text"); r.l:SetPoint("LEFT", 56, 0); r.l:SetWidth(150)
    r.v = text(r, "body", 12, "soft"); r.v:SetPoint("LEFT", 210, 0); r.v:SetWidth(240)
    r.n = text(r, "display", 14, "text", "RIGHT"); r.n:SetPoint("RIGHT", 0, 0); r.n:SetWidth(70)
    r:EnableMouse(true)
    r:SetScript("OnEnter", function(s) if not s.tip then return end GameTooltip:SetOwner(s, "ANCHOR_RIGHT"); for _, l in ipairs(s.tip) do GameTooltip:AddLine(l, 1, 1, 1, true) end GameTooltip:Show() end)
    r:SetScript("OnLeave", GameTooltip_Hide)
    rows[i] = r
  end
  r:ClearAllPoints(); r:SetPoint("TOPLEFT", 14, y); r.tip = nil; r:Show()
  return r
end
local function cell(i, parent, x, y, w, s, color, justify)
  local f = cells[i]
  if not f then f = text(ns.win, "body", 12, "text"); cells[i] = f end
  f:ClearAllPoints(); f:SetPoint("TOPLEFT", x, y); f:SetWidth(w); f:SetJustifyH(justify or "LEFT")
  f:SetText(s); f:SetTextColor(rgb(color or "text")); f:Show()
  return f
end

function ns.Refresh()
  local win = ns.win
  if not win or not db then return end
  local c = meRow()
  local p = ns.Plan(c)
  win.sub:SetText(string.format("%s · resets in %s · daily reset in %s", c.name or "?", dur(untilWeekly()), dur(untilDaily())))
  local y = -52
  local aw, tw = db.warband.afflicted or 0, db.warband.tormented or 0
  win.stockH:ClearAllPoints(); win.stockH:SetPoint("TOPLEFT", 14, y); y = y - 20
  if ns.DrawStock then y = ns.DrawStock(win, y, c) end
  y = y - 10
  win.weekH:ClearAllPoints(); win.weekH:SetPoint("TOPLEFT", 14, y)
  win.weekH:SetText(string.format("VENOMSTONES THIS WEEK  ·  %d gained  ·  up to %d more, plus Mythic+", p.total, p.left))
  y = y - 20
  local i = 0
  local function line(kind, label, value, num, tip)
    i = i + 1; local r = row(i, y); setMark(r, kind); r.l:SetText(label); r.v:SetText(value or ""); r.n:SetText(num or ""); r.tip = tip
    y = y - 22
  end
  local hl, ml = p.hN - p.hK, p.mN - p.mK
  local function raidTip(diff)
    local t = {}
    for name, r in pairs(c.raid or {}) do local x = r[diff]; if x then t[#t + 1] = string.format("%s: %d / %d", name, x[1], x[2]) end end
    if #t == 0 then t[1] = "No lockout read yet. Open the raid info panel or zone once." end
    t[#t + 1] = "One Venomstone per boss, from your loot lockout. The Kith'ix and Nymrissa lairs count like raid bosses (Mythic is flexible size there)."
    return t
  end
  line(p.hN > 0 and (hl == 0 and "done" or "left") or "none", "Heroic raid", p.hN > 0 and string.format("%d of %d bosses killed", p.hK, p.hN) or "no lockout read yet", hl > 0 and ("+" .. hl) or "", raidTip(15))
  line(p.mN > 0 and (ml == 0 and "done" or "left") or "none", "Mythic raid", p.mN > 0 and string.format("%d of %d bosses killed", p.mK, p.mN) or "no lockout read yet", ml > 0 and ("+" .. ml) or "", raidTip(16))
  local b = p.bountiful
  local bTip = { "Tier 11 bountiful delves still marked bountiful for you today (the Labyrinth isn't counted)." }
  for _, n in ipairs(c.bountiful or {}) do bTip[#bTip + 1] = "  " .. n end
  bTip[#bTip + 1] = string.format("Delves done this week: %d", c.delvesDone or 0)
  line(b == nil and "none" or (b == 0 and "done" or "left"), "Bountiful delves", b == nil and "open your map to read them" or string.format("%d up today · %d key%s", b, c.keys or 0, (c.keys or 0) == 1 and "" or "s"),
       (b and b > 0) and ("+" .. p.delveStones) or "", bTip)
  line(p.dundun and "done" or "left", "Dundun", p.dundun and "abundant delve done this week" or "not used this week", p.dundun and "" or "+1",
       { "Dundun's shrine (delver's journey rank 3) makes a bountiful delve abundant: a second chest, which needs another key.",
         "Once a week. After that he only offers small rewards, so it isn't counted.", "/tar Dundun helps find him." })
  local lab = c.labClears or 0
  line(lab > 0 and "done" or "left", "Labyrinth of Kindo'jan", lab > 0 and string.format("cleared %dx this week", lab) or ((c.labVisits or 0) > 0 and "visited, not cleared" or "not cleared this week"),
       "", { "Full clear (9 rooms) = 3 Bountiful Coffers, a key and a Venomstone each.", "Repeatable while you have keys.", string.format("Venomstones from it this week: %d", c.gained.lab or 0) })
  line(p.preyLeft == 0 and "done" or "left", "Nightmare Prey", string.format("%d of %d · %d soul%s used", math.min(p.prey, PREY_WEEK), PREY_WEEK, c.soulsUsed or 0, (c.soulsUsed or 0) == 1 and "" or "s"),
       p.preyLeft > 0 and ("+" .. p.preyLeft) or "", { "2 hunts a week give a Champion Box with a Venomstone; an Afflicted or Tormented Soul adds a bonus chest for 2 more.",
         "Counted from Venomstones picked up in the open world, so a stray world one counts here too." })
  local g = c.gilded or 0
  line(g >= GILDED_WEEK and "done" or "left", "Gilded Stash", string.format("%d of %d opened · %d Myth crests left", g, GILDED_WEEK, (GILDED_WEEK - g) * GILDED_CRESTS), "",
       { "Appears after a Tier 11 delve, 4 times a week (Delver's Journey rank 4). 5 Myth Mistcrests each, no key needed.",
         "Counted when Myth crests land in a delve in steps of 5. Wrong? /stash gilded <0-4> sets it." })
  line("info", "Mythic+ 10 and up", string.format("%d this week", c.gained.mplus or 0), "no cap", { "One per +10 or higher end chest. Not counted in 'up to N more'." })
  line((c.afflicted or 0) + aw + (c.tormented or 0) + tw > 0 and "info" or "none", "Souls", string.format("%d Afflicted, %d Tormented (warband bank %d / %d)", c.afflicted or 0, c.tormented or 0, aw, tw), "",
       { "Each one instantly completes a Nightmare Prey hunt for a bonus Venomstone chest.", "Counted in bags and bank; the warband bank number is from the last time the game could read it." })
  if p.keysShort > 0 then line("left", "Keys", string.format("%d short for today's bountiful delves%s", p.keysShort, p.dundun and "" or " and Dundun"), "") end
  for j = i + 1, #rows do rows[j]:Hide() end
  -- gained by source
  y = y - 8
  local parts = {}
  for _, s in ipairs(SOURCES) do local v = c.gained[s[1]] or 0; if v > 0 then parts[#parts + 1] = s[2] .. " " .. v end end
  win.src:ClearAllPoints(); win.src:SetPoint("TOPLEFT", 14, y)
  win.src:SetText("Gained: " .. (#parts > 0 and table.concat(parts, "  ·  ") or "nothing yet this week"))
  y = y - 26
  -- characters
  win.charH:ClearAllPoints(); win.charH:SetPoint("TOPLEFT", 14, y); y = y - 20
  local COLS = { { "Character", 120 }, { "Stones", 46 }, { "Keys", 38 }, { "Souls", 42 }, { "H", 40 }, { "M", 40 }, { "Lab", 30 }, { "Prey", 38 }, { "Gilded", 40 }, { "Week", 44 } }
  local k, x = 0, 14
  for _, col in ipairs(COLS) do k = k + 1; cell(k, win, x, y, col[2], col[1], "muted", col[1] == "Character" and "LEFT" or "RIGHT"); x = x + col[2] + 6 end
  y = y - 18
  local list = {}
  for key, ch in pairs(db.chars) do list[#list + 1] = { key = key, c = ch } end
  table.sort(list, function(a, b2) if a.key == me then return true elseif b2.key == me then return false end return (a.c.at or 0) > (b2.c.at or 0) end)
  local wk = weekId()
  for n, it in ipairs(list) do
    if n > 12 then break end
    local ch, cur = it.c, it.c.week == wk
    local pp = cur and ns.Plan(ch) or nil
    local cc = ch.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[ch.class]
    local vals = {
      (it.key == me and "> " or "") .. (ch.name or it.key),
      ch.stones or 0, ch.keys or 0, (ch.afflicted or 0) + (ch.tormented or 0),
      pp and (pp.hN > 0 and (pp.hK .. "/" .. pp.hN) or "-") or "?", pp and (pp.mN > 0 and (pp.mK .. "/" .. pp.mN) or "-") or "?",
      cur and (ch.labClears or 0) or "?", pp and (math.min(pp.prey, PREY_WEEK) .. "/" .. PREY_WEEK) or "?", cur and ((ch.gilded or 0) .. "/" .. GILDED_WEEK) or "?", cur and pp.total or "old",
    }
    x = 14
    for j, col in ipairs(COLS) do
      k = k + 1
      local f = cell(k, win, x, y, col[2], tostring(vals[j]), j == 1 and "text" or (cur and "soft" or "muted"), j == 1 and "LEFT" or "RIGHT")
      if j == 1 and cc then f:SetTextColor(cc.r, cc.g, cc.b) end
      x = x + col[2] + 6
    end
    y = y - 18
  end
  for j = k + 1, #cells do cells[j]:Hide() end
  win.foot:SetText("Alts update when you log them in. '?' = not seen since the weekly reset.")
  win:SetHeight(-y + 36)
end

local function build()
  local win = CreateFrame("Frame", "SmilerStashWindow", UIParent, "BackdropTemplate")
  ns.win = win
  win:SetSize(W_, 420); win:SetFrameStrata("HIGH"); win:SetClampedToScreen(true); win:SetMovable(true); win:EnableMouse(true)
  win:RegisterForDrag("LeftButton"); win:SetScript("OnDragStart", win.StartMoving)
  win:SetScript("OnDragStop", function(s) s:StopMovingOrSizing(); local a, _, r, x, y2 = s:GetPoint(); if type(x) == "number" and not secret(x) then db.point = { a, r, x, y2 } end end)
  panel(win, "void", 0.96, 0.6)
  if S and S.TopLine then S.TopLine(win) end
  tinsert(UISpecialFrames, "SmilerStashWindow")
  local t = text(win, "display", 18, "amethyst"); t:SetPoint("TOPLEFT", 14, -10); t:SetText(S and S.Spaced and S.Spaced("Stash") or "STASH")
  win.sub = text(win, "body", 11, "muted"); win.sub:SetPoint("TOPLEFT", 14, -32)
  local close = CreateFrame("Button", nil, win); close:SetSize(18, 18); close:SetPoint("TOPRIGHT", -8, -8)
  local ct = close:CreateTexture(nil, "OVERLAY"); ct:SetAllPoints()
  if S and S.Icon then ct:SetTexture(S.Icon("close")); ct:SetVertexColor(rgb("muted")) else ct:SetColorTexture(0.5, 0.3, 0.6, 1) end
  close:SetScript("OnClick", function() win:Hide() end)
  win.weekH = text(win, "label", 12, "amethyst")
  win.stockH = text(win, "label", 12, "amethyst"); win.stockH:SetText("IN YOUR BAGS  ·  right-click a row to hide it")
  win.src = text(win, "body", 12, "soft")
  win.charH = text(win, "label", 12, "amethyst"); win.charH:SetText("YOUR CHARACTERS")
  win.foot = text(win, "body", 10, "muted"); win.foot:SetPoint("BOTTOMLEFT", 14, 10)
  if db.point then win:SetPoint(db.point[1], UIParent, db.point[2], db.point[3], db.point[4]) else win:SetPoint("CENTER") end
  win:SetScript("OnShow", function() if RequestRaidInfo then RequestRaidInfo() end; local c = meRow(); readBountiful(c); update(true); ns.Refresh() end)
  win:Hide()
end
function ns.Toggle()
  if not db then return end
  if not ns.win then build() end
  ns.win:SetShown(not ns.win:IsShown())
end

---------------------------------------------------------------- Smiler settings and status
if S and S.RegisterSettings then
  S:RegisterSettings("Stash", function(body, W)
    local A = W.Column(body, 0, 0, 290)
    A:Section("Venomstones")
    A:Switch("Chat line for each Venomstone", "Where it came from, and this week's total", function() return db.chat end, function(v) db.chat = v end)
    A:Switch("Alert for each Venomstone", "A Smiler alert", function() return db.toast end, function(v) db.toast = v end)
    A:Switch("Summary when you log in", "Stones and keys, and what's left this week", function() return db.loginLine end, function(v) db.loginLine = v end)
    local B = W.Column(body, 334, 0, 290)
    B:Section("What it reads")
    B:Note("Bags, bank and warband bank; raid kills from your lockouts; bountiful delves from the map. Dundun counts when you talk to him.", "muted", 12)
    B:Gap(6)
    B:Section("Upgrades")
    B:Switch("Tell me when I can upgrade", "20 crests for a track you're wearing unfinished (10 on alts), or 10 Venomstones for a Myth 6/6 weapon, trinket or neck", function() return db.upgradeAlerts end, function(v) db.upgradeAlerts = v end)
    B:Switch("This character is my main", "Mains pay 20 crests a rank, alts 10. If none is set, your highest item level character counts", function() return db.main == me end, function(v) db.main = v and me or nil end)
    A:Gap(8)
    A:Section("Rows to show")
    if ns.StockSettings then ns.StockSettings(A) end
    return { note = "/stash · /stash reset · /stash main", footer = {} }
  end)
  if S.RegisterStatus then
    S:RegisterStatus("stash", function()
      if not db or not me then return nil end
      local c = db.chars[me]; if not c or c.week ~= weekId() then return "Nothing yet this week", "muted" end
      local p = ns.Plan(c)
      return string.format("%d this week · up to %d more", p.total, p.left), "muted"
    end)
  end
end

---------------------------------------------------------------- events
local ev = CreateFrame("Frame")
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "CURRENCY_DISPLAY_UPDATE", "UPDATE_INSTANCE_INFO",
                     "BOSS_KILL", "CHALLENGE_MODE_COMPLETED", "SCENARIO_COMPLETED", "GOSSIP_SHOW", "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
                     "AREA_POIS_UPDATED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LOGOUT" }) do pcall(ev.RegisterEvent, ev, e) end
local pend
local function soon(fn, delay) if pend then return end pend = true; C_Timer.After(delay or 0.5, function() pend = false; fn() end) end
ev:SetScript("OnEvent", function(_, e, a1)
  if e == "ADDON_LOADED" then
    if a1 ~= ADDON then return end
    SmilerStashDB = SmilerStashDB or {}
    db = SmilerStashDB
    for k, v in pairs(DEFAULTS) do if db[k] == nil then db[k] = v end end
    db.chars = db.chars or {}; db.warband = db.warband or {}; db.show = db.show or {}
    ns.db = db
    return
  end
  if not db then return end
  if e == "PLAYER_ENTERING_WORLD" then
    local first = not me
    me = charKey(); meRow()
    if context() == "lab" then local c = meRow(); c.labVisits = (c.labVisits or 0) + 1 end
    if RequestRaidInfo then RequestRaidInfo() end
    C_Timer.After(3, function()
      local c = meRow(); readBountiful(c); update(true)
      if first and db.loginLine then
        local p = ns.Plan(c)
        say(string.format("%d Venomstones, %d coffer key%s. Venomstones this week: %d gained, up to %d more plus Mythic+. /stash",
          c.stones or 0, c.keys or 0, (c.keys or 0) == 1 and "" or "s", p.total, p.left))
      end
    end)
  elseif e == "BAG_UPDATE_DELAYED" or e == "CURRENCY_DISPLAY_UPDATE" or e == "PLAYER_EQUIPMENT_CHANGED" then
    if me then soon(update) end
  elseif e == "UPDATE_INSTANCE_INFO" then
    if me then readLockouts(meRow()); if ns.win and ns.win:IsShown() then ns.Refresh() end end
  elseif e == "BOSS_KILL" then
    C_Timer.After(5, function() if RequestRaidInfo then RequestRaidInfo() end end)
  elseif e == "CHALLENGE_MODE_COMPLETED" then
    lastKeyDone = GetTime()
  elseif e == "SCENARIO_COMPLETED" then
    local c = meRow()
    local where = context()
    if where == "lab" then c.labClears = (c.labClears or 0) + 1; say("Labyrinth of Kindo'jan cleared.")
    elseif where == "delve" then c.delvesDone = (c.delvesDone or 0) + 1 end
    C_Timer.After(2, function() readBountiful(meRow()); update() end)
  elseif e == "GOSSIP_SHOW" then
    local n = UnitName("npc")
    if n and not secret(n) and n:find("Dundun", 1, true) then
      local c = meRow()
      if not c.dundun then c.dundun = true; say("Dundun found: this delve gets a second chest (bring a key). That's this week's.") end
      if ns.win and ns.win:IsShown() then ns.Refresh() end
    end
  elseif e == "BANKFRAME_OPENED" then
    db.bankOpen = true; soon(update, 1)
  elseif e == "BANKFRAME_CLOSED" then
    update(true); db.bankOpen = false
  elseif e == "AREA_POIS_UPDATED" then
    if ns.win and ns.win:IsShown() then soon(function() readBountiful(meRow()); ns.Refresh() end, 1) end
  end
end)

SLASH_SMILERSTASH1 = "/stash"
SLASH_SMILERSTASH2 = "/venom"
SlashCmdList.SMILERSTASH = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "reset" then
    if me and db.chars[me] then freshWeek(db.chars[me]); say("This character's week cleared.") end
    if ns.win and ns.win:IsShown() then ns.Refresh() end
  elseif msg:match("^gilded") then
    local n = tonumber(msg:match("(%d+)"))
    if me and n then local c = meRow(); c.gilded = math.max(0, math.min(GILDED_WEEK, n)); say("Gilded Stash set to " .. c.gilded .. " of " .. GILDED_WEEK .. " this week.") end
    if ns.win and ns.win:IsShown() then ns.Refresh() end
  elseif msg == "main" then
    db.main = (db.main ~= me) and me or nil
    say(db.main and "This character is your main: upgrade alerts at 20 crests." or "Main cleared: the highest item level character counts as the main.")
  elseif msg == "settings" and S and S.OpenSettings then S:OpenSettings("Stash")
  else ns.Toggle() end
end
