-- SmilerKeys: Voidcaches - what a bonus roll can still give you.
-- Each boss and dungeon has a hidden "voidcache" item whose tooltip lists the items you have not
-- received yet for your current loot spec (the same list you see hovering the bonus-roll icon).
-- Reading it turns the planner's odds from a guess ("one item out of the whole loot table") into
-- the real thing: the pool shrinks as you collect, and anything already received drops out.
--
-- The tooltip follows your LOOT spec, and the client only refreshes a cache after another one has
-- been shown, so everything here is re-read when the loot spec changes or a roll happens.
local _, ns = ...
local L = ns.Loot

local V = {}
L.Void = V

---------------------------------------------------------------- season data
-- Hints only. The IDs that float around on forums belong to other builds (272128, for instance, is
-- a Soggy Lynx Toy on 12.1.5), so nothing here is trusted until a tooltip with the item-list header
-- has actually been seen. What the add-on learns by watching your tooltips wins over this table.
V.BOSS = {
  ["nek'zali the soulcoiler"] = 272121,
  ["entombed sentinels"]      = 272122,
  ["the lost explorers"]      = 272123,
  ["vashnik the malignant"]   = 272124,
  ["sszorak"]                 = 272125,
  ["the twin fangs"]          = 272126,
  ["the coiled altar"]        = 272127,
  ["ula'tek"]                 = 272128,
  ["nymrissa wavecaller"]     = 272135,
  ["kith'ix"]                 = 272140,
}
V.INSTANCE = {
  ["altar of fangs"]            = 272101,
  ["den of nalorakk"]           = 272102,
  ["kings' rest"]               = 272103,
  ["murder row"]                = 272104,
  ["ruby life pools"]           = 272105,
  ["temple of sethraliss"]      = 272106,
  ["the tidebound grotto"]      = 272107,
  ["the unbinding of kith'ix"]  = 272108,
  ["the venomous abyss"]        = 272109,
  ["voidscar arena"]            = 272110,
}

-- Confirmed cache item IDs for Midnight Season 2 (12.1.5), found by sweeping item IDs in game.
-- Seeded on login so every button works straight away; the real names replace these once the
-- server sends the items, and anything learned from a tooltip wins over the lot.
V.SEEDS = {
  -- The Venomous Abyss
  { 278285, "Nebulous Voidcache: Soulcoiler Nek'zali" },
  { 278283, "Nebulous Voidcache: Entombed Sentinels" },
  { 278286, "Nebulous Voidcache: Tortollan Explorers" },
  { 278287, "Nebulous Voidcache: Vashnik" },
  { 278288, "Nebulous Voidcache: Sszorak" },
  { 278289, "Nebulous Voidcache: The Twin Fangs" },
  { 278290, "Nebulous Voidcache: The Coiled Altar" },
  { 278284, "Nebulous Voidcache: Ula'tek" },
  -- lairs
  { 274708, "Nebulous Voidcache: Nymrissa Wavecaller" },
  { 286019, "Nebulous Voidcache: Kith'ix" },
  -- Mythic+
  { 279618, "Nebulous Voidcache: Altar of Fangs" },
  { 279619, "Nebulous Voidcache: The Blinding Vale" },
  { 279620, "Nebulous Voidcache: Den of Nalorakk" },
  { 279621, "Nebulous Voidcache: Kings' Rest" },
  { 279622, "Nebulous Voidcache: Murder Row" },
  { 279623, "Nebulous Voidcache: Ruby Life Pools" },
  { 279624, "Nebulous Voidcache: Temple of Sethraliss" },
  { 279625, "Nebulous Voidcache: Voidscar Arena" },
  -- other
  { 280131, "Nebulous Voidcache: Prey" },
}

function V.Seed()
  local st = V.Store()
  local added = 0
  for _, sd in ipairs(V.SEEDS) do
    local id, label = sd[1], sd[2]
    local key = tostring(id)
    local e = st[key]
    if not e then
      st[key] = { id = id, name = label, seeded = true, at = 0 }
      added = added + 1
    elseif e.seeded then
      e.name = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or e.name or label
    end
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
  end
  return added
end

---------------------------------------------------------------- matching
-- names vary between the journal and the cache ("The Twin Fangs (Vexhul & Ithraz)"), so compare on
-- a normalised head: lower case, nothing after a comma / colon / bracket, no leading "the ".
local function norm(s)
  if type(s) ~= "string" then return nil end
  s = s:lower():gsub("%s*[,:%(].*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
  return s ~= "" and s or nil
end
local function lookup(tbl, name)
  local n = norm(name)
  if not n then return nil end
  if tbl[n] then return tbl[n] end
  for k, id in pairs(tbl) do
    if k == n or k:find(n, 1, true) == 1 or n:find(k, 1, true) == 1 then return id end
  end
end

local learnedFor   -- set further down, once the learning store exists

-- the voidcache that covers where this item comes from
function V.IDFor(it)
  if not it then return nil end
  -- a cache names where it belongs ("Nebulous Voidcache - Kings' Rest"), which beats any guesswork
  if it.raid and it.encName and it.encName ~= "" then
    local id = V.FindByName and V.FindByName(it.encName)
    if id then return id, "boss" end
  end
  if it.inst then
    local id = V.FindByName and V.FindByName(it.inst)
    if id then return id, "instance" end
  end
  if it.raid and it.encName and it.encName ~= "" then
    local e = learnedFor(it.encName, "boss")
    if e then return e.id, "boss" end
  end
  if it.inst then
    local e = learnedFor(it.inst, "instance")
    if e then return e.id, "instance" end
  end
  -- fall back to the hint tables, but only if that ID really does carry an item list
  if it.raid and it.encName and it.encName ~= "" then
    local id = lookup(V.BOSS, it.encName)
    if id and V.Read(id) then return id, "boss" end
  end
  if it.inst then
    local id = lookup(V.INSTANCE, it.inst)
    if id and V.Read(id) then return id, "instance" end
  end
end

---------------------------------------------------------------- reading a cache
local cache, asked = {}, {}        -- [cacheID] = { names = {set}, list = {}, n = 0, at = time }
local STALE = 600
-- what a voidcache item is called. A boss you have fully rolled has a cache with NO item list at
-- all, so the name is the only way to tell "nothing left" apart from "not loaded yet".
V.NAME_HINT = "voidcache"
function V.IsCacheName(id)
  local n = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
  return (n and n:lower():find(V.NAME_HINT, 1, true)) and n or nil
end

local function strip(s)
  if type(s) ~= "string" then return nil end
  s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  -- the list is bulleted ("- Grips of Swirling Fury"); without stripping that, no name ever
  -- matches an item you own
  s = s:gsub("^[%-•%*%s]+", "")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  return s ~= "" and s or nil
end

-- nil = not readable yet (the item is on its way from the server, or this client has no header
-- string to anchor on); otherwise { list = { name, ... }, names = { [name] = true }, n = count }
function V.Read(id, force)
  if not id or not C_TooltipInfo or not C_TooltipInfo.GetItemByID then return nil end
  local now = GetTime and GetTime() or 0
  local c = cache[id]
  if c and not force and (now - c.at) < STALE then return c end
  local ok, data = pcall(C_TooltipInfo.GetItemByID, id)
  if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then
    if not asked[id] and C_Item and C_Item.RequestLoadItemDataByID then
      asked[id] = true
      pcall(C_Item.RequestLoadItemDataByID, id)
    end
    return nil
  end
  local list = V.ListFrom(data)
  if not list then
    -- C_TooltipInfo.GetItemByID builds a tooltip with no player data in it, so the knockout list is
    -- usually absent. That means "not known", never "nothing left" - only a tooltip drawn by the
    -- game (hovering the cache, or the bonus-roll icon) carries your own list.
    return nil
  end
  local names = {}
  for _, x in ipairs(list) do names[x:lower()] = true end
  c = { list = list, names = names, n = #list, at = now }
  cache[id] = c
  return c
end

function V.Forget() wipe(cache); wipe(asked) end

---------------------------------------------------------------- what the rest of the add-on asks
-- How many items a bonus roll here is picking from, and the names. nil when we cannot read it yet,
-- so callers fall back to counting the loot table.
function L.RollRemaining(it)
  local id = V.IDFor(it)
  if not id then return nil end
  local c = V.Read(id)
  if not c then return nil end
  return c.list, c.n, id
end

-- true / false / nil (unknown): can a bonus roll here still give you this item?
function L.StillRollable(it)
  if not it or not it.name then return nil end
  local id = V.IDFor(it)
  if not id then return nil end
  local c = V.Read(id)
  if not c then return nil end
  return c.names[it.name:lower()] == true
end

-- a line for the UI: "7 items left for you" / nil
-- the best reading for a difficulty: your own list first, newest wins, current loot spec preferred
function V.Reading(id, diff, anySpec)
  local e = id and V.Store()[tostring(id)]
  if not (e and e.readings) then return nil end
  local _, specName = V.LootSpec()
  local best
  for _, r in pairs(e.readings) do
    local diffOK = (not diff) or r.diff == diff or r.diff == "any"
    local specOK = anySpec or not specName or r.spec == specName or r.spec == "current spec"
    if diffOK and specOK then
      if not best
        or (r.personal and not best.personal)
        or (r.personal == best.personal and (r.at or 0) > (best.at or 0)) then best = r end
    end
  end
  return best
end

-- every reading we hold for a cache, newest first (for the tooltip)
function V.Readings(id)
  local e = id and V.Store()[tostring(id)]
  local out = {}
  for _, r in pairs((e and e.readings) or {}) do out[#out + 1] = r end
  table.sort(out, function(a, b) return (a.at or 0) > (b.at or 0) end)
  return out
end

-- Items you already hold, by name. A cache's knockout list is not readable from an item tooltip,
-- but what you own is - and a bonus roll cannot give you something you have already received.
function V.OwnedNames()
  local out = {}
  for id in pairs(L.OwnedLevels() or {}) do
    local n = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
    if n then out[n:lower()] = true end
  end
  return out
end

-- NOTE: an earlier version subtracted items you own. That was wrong - a bonus roll can still give
-- you something you already have from the vault or an ordinary drop. What you have received from a
-- ROLL is tracked by hand in /sk rolls instead.
function V.Estimate(id, diff)
  -- a difficulty variant we can ask for directly beats everything else
  -- your own list, read inside the instance, beats any estimate
  local r = V.Reading(id, diff)
  if r and r.personal then
    return { total = r.n, left = r.list, n = r.n, have = 0, personal = true, diff = r.diff, spec = r.spec, at = r.at }
  end
  local c = V.Read(id)
  if not c then return nil end
  return { total = c.n, left = c.list, n = c.n, have = 0 }
end

function L.RollPoolText(it)
  local _, n = L.RollRemaining(it)
  if not n then return nil end
  if n == 0 then return "nothing left here for you" end
  return n .. (n == 1 and " item left for you" or " items left for you")
end

---------------------------------------------------------------- keeping it fresh
-- The caches are per loot spec, and the client is lazy about refreshing them, so drop everything we
-- know whenever the spec changes or a roll lands, and warm them again on the next question.
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOOT_SPEC_UPDATED", "PLAYER_SPECIALIZATION_CHANGED", "BONUS_ROLL_RESULT", "PLAYER_ENTERING_WORLD" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, e, unit)
  if e == "PLAYER_ENTERING_WORLD" then
    V.Watch()
    if not V.seeded then V.seeded = true; V.Seed() end
  end
  if e == "PLAYER_SPECIALIZATION_CHANGED" and unit ~= "player" then return end
  V.Forget()
  if ns.Planner_Refresh then ns.Debounce("voidcache", 1, function()
    if ns.Planner_Refresh then ns.Planner_Refresh() end
    if ns.Targets_Refresh then ns.Targets_Refresh() end
  end) end
end)

-- ask the server for every cache we might need, so the first look at the planner has real numbers
function V.Warm()
  if not (C_Item and C_Item.RequestLoadItemDataByID) then return end
  for _, id in pairs(V.BOSS) do pcall(C_Item.RequestLoadItemDataByID, id) end
  for _, id in pairs(V.INSTANCE) do pcall(C_Item.RequestLoadItemDataByID, id) end
end

---------------------------------------------------------------- bonus IDs (difficulty variants)
-- The same cache item appears with different bonus IDs:
--   item:274708::::::::90::::1:13335:   vs   item:274708::::::::90::::1:12833:
-- The bonus ID picks the variant, which is how one item can carry a Heroic list and a Mythic one.
-- Reading a built link instead of the bare item ID lets us ask for a specific difficulty from
-- anywhere, rather than hoping the game shows the one we want.
function V.Link(id, bonus)
  if bonus then return ("item:%d::::::::90::::1:%d:"):format(id, bonus) end
  return ("item:%d"):format(id)
end

-- the item list behind one link. Second return says whether the tooltip came back at all, so
-- "the server hasn't sent this item" can be told apart from "this tooltip carries no list".
function V.ReadLink(id, bonus)
  if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return nil, false end
  local link = V.Link(id, bonus)
  local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
  if not ok or type(data) ~= "table" or type(data.lines) ~= "table" or #data.lines == 0 then return nil, false end
  return V.ListFrom(data), true, link
end

-- which bonus ID means which difficulty (shared across every cache once we know it)
function V.Bonus(diff)
  ns.db.voidBonus = ns.db.voidBonus or {}
  return diff and ns.db.voidBonus[diff] or nil
end
function V.SetBonus(diff, bonus)
  ns.db.voidBonus = ns.db.voidBonus or {}
  ns.db.voidBonus[diff] = bonus
  if ns.VoidUI_Refresh then ns.VoidUI_Refresh() end
end
function V.KnownBonuses()
  ns.db.voidBonus = ns.db.voidBonus or {}
  return ns.db.voidBonus
end

-- /sk void bonus <itemID> <b1> [b2 ...]: read the same cache through several bonus IDs and show
-- what each one lists, so the difficulty each represents can be told apart.
function V.CompareBonuses(id, list)
  id = tonumber(id)
  if not id or #list == 0 then
    ns.Print("Usage: /sk void bonus <itemID> <bonusID> [bonusID ...]")
    return
  end
  pcall(C_Item.RequestLoadItemDataByID, id)
  local plain = V.ReadLink(id)
  ns.Print(("|cffb98cff%s|r (%d)"):format((C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or "?", id))
  ns.Print(("  no bonus ID: %s"):format(plain and (#plain .. " items: " .. table.concat(plain, ", ")) or "no list"))
  for _, b in ipairs(list) do
    local l = V.ReadLink(id, b)
    ns.Print(("  bonus |cffffab00%d|r: %s"):format(b, l and (#l .. " items: " .. table.concat(l, ", ")) or "no list (try again in a second)"))
  end
  ns.Print("If two bonus IDs give different lists, they are different difficulties - tell the add-on which is which with /sk void setbonus Heroic <id> and /sk void setbonus Mythic <id>.")
end

---------------------------------------------------------------- what the variants are
-- A cache appears with different bonus IDs and nobody outside Blizzard knows what they encode.
-- Rather than guess: read many variants, group them by the list they produce, and the number of
-- distinct groups is the number of real variants. If difficulty is what the bonus ID selects,
-- there will be one group per difficulty, each with its own item list.
local function sig(list)
  if not list then return nil end
  local c = {}
  for _, n in ipairs(list) do c[#c + 1] = n end
  table.sort(c)
  return table.concat(c, "|"), #list
end

-- every voidcache in your bags, with its full link: the links you actually hold are the best
-- evidence of what a variant is
function V.Mine()
  if not (C_Container and C_Container.GetContainerNumSlots) then ns.Print("No container API."); return end
  local found = 0
  for bag = 0, 5 do
    for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      local link = info and info.hyperlink
      local name = link and link:match("%[(.-)%]")
      if name and name:lower():find(V.NAME_HINT, 1, true) then
        found = found + 1
        local id = link:match("item:(%d+)")
        local bonuses = {}
        local body = link:match("|Hitem:([^|]+)")
        if body then
          local f = {}
          for part in (body .. ":"):gmatch("([^:]*):") do f[#f + 1] = part end
          local n = tonumber(f[13]) or 0
          for k = 14, 13 + n do bonuses[#bonuses + 1] = f[k] end
        end
        local list = V.ReadLink(tonumber(id), tonumber(bonuses[1]))
        ns.Print(("|cffb98cff%s|r  item %s  bonus %s  -  %s"):format(name, id or "?",
          #bonuses > 0 and table.concat(bonuses, ",") or "none",
          list and (#list .. " items: " .. table.concat(list, ", ")) or "no list"))
        ns.Print("    " .. (link:gsub("|", "||")))
      end
    end
  end
  if found == 0 then ns.Print("No voidcache in your bags.") end
end

-- try every bonus ID in a range and group by the list it produces
local sweep
function V.Sweep(id, from, to)
  id, from, to = tonumber(id), tonumber(from), tonumber(to)
  if not (id and from and to) or to < from then
    ns.Print("Usage: /sk void sweep <itemID> <from> <to>   e.g. /sk void sweep 274708 12800 13400")
    return
  end
  if to - from > 4000 then ns.Print("Keep the bonus range under 4000."); return end
  if sweep then ns.Print("A sweep is already running."); return end
  pcall(C_Item.RequestLoadItemDataByID, id)
  sweep = { id = id, b = from, to = to, groups = {}, order = {}, n = 0 }
  ns.Print(("Reading %s through bonus IDs %d-%d..."):format((C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or id, from, to))
  local function chunk()
    if not sweep then return end
    local last = math.min(sweep.b + 299, sweep.to)
    for b = sweep.b, last do
      local list = V.ReadLink(id, b)
      if list then
        local k, count = sig(list)
        local g = sweep.groups[k]
        if not g then
          g = { n = count, list = list, ids = {}, count = 0 }
          sweep.groups[k] = g; sweep.order[#sweep.order + 1] = g
        end
        g.count = g.count + 1
        if #g.ids < 6 then g.ids[#g.ids + 1] = b end
      end
      sweep.n = sweep.n + 1
    end
    sweep.b = last + 1
    if sweep.b > sweep.to then
      table.sort(sweep.order, function(a, b2) return a.n > b2.n end)
      ns.Print(("Done: %d bonus IDs read, %d distinct list%s."):format(sweep.n, #sweep.order, #sweep.order == 1 and "" or "s"))
      for i, g in ipairs(sweep.order) do
        ns.Print(("  |cffffab00list %d|r: %d items, from %d bonus ID%s (e.g. %s)"):format(i, g.n, g.count,
          g.count == 1 and "" or "s", table.concat(g.ids, ", ")))
        ns.Print("     " .. table.concat(g.list, ", "))
      end
      if #sweep.order > 1 then
        ns.Print("Different lists = different variants. Label them with /sk void setbonus <difficulty> <bonusID>.")
      elseif #sweep.order == 1 then
        ns.Print("Every bonus ID gives the same list, so the bonus ID is not what picks the difficulty.")
      end
      sweep = nil
      return
    end
    C_Timer.After(0.05, chunk)
  end
  chunk()
end

---------------------------------------------------------------- learning the real caches
-- There is no API that lists voidcaches, and the IDs differ between builds. So: watch every item
-- tooltip you look at. Any tooltip carrying the "contains one of the following items" header is a
-- cache, and it is recorded with what it listed and where you were at the time. Hover the bonus-roll
-- icon once per boss and the add-on knows that boss's cache for good.
function V.Store()
  ns.db.void = ns.db.void or {}
  return ns.db.void
end

-- the loot spec a reading belongs to: a cache lists what THAT spec can still receive
function V.LootSpec()
  local id
  if GetLootSpecialization then local ok, v = pcall(GetLootSpecialization); if ok then id = v end end
  if (not id or id == 0) and GetSpecialization and GetSpecializationInfo then
    local ok, idx = pcall(GetSpecialization)
    if ok and idx then local ok2, sid = pcall(GetSpecializationInfo, idx); if ok2 then id = sid end end
  end
  if not id or id == 0 then return nil, "current spec" end
  local name
  if GetSpecializationInfoByID then
    local ok, _, n = pcall(GetSpecializationInfoByID, id)
    if ok then name = n end
  end
  return id, name or tostring(id)
end

local function context()
  local where, diff, diffName, inside
  if GetInstanceInfo then
    local ok, name, itype, dID, dName = pcall(GetInstanceInfo)
    if ok then where, diff, diffName = name, dID, dName; inside = (itype == "raid" or itype == "party") end
  end
  local spec, specName = V.LootSpec()
  return { where = where, diff = diff, diffName = diffName, inside = inside, spec = spec, specName = specName,
           boss = V.lastBoss, bossDiff = V.lastBossDiff }
end

-- record a cache we have just seen in a tooltip
function V.Learn(id, lines, src)
  if not id or type(lines) ~= "table" then return end
  local known = #lines > 0
  local st = V.Store()
  local key = tostring(id)
  local e = st[key] or {}
  e.id = id
  e.name = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or e.name
  if known or not e.list then e.list = lines end
  e.n = known and #lines or e.n
  e.listKnown = known or e.listKnown
  -- there is one cache per boss, and the game decides which difficulty's list it shows. So every
  -- reading is filed under the difficulty you were looking at when it was taken.
  if known then
    local ctx = context()          -- where we are NOW, not whatever was stored on a previous read
    local diff = V.pendingDiff or ctx.diffName or "any"
    local spec = ctx.specName or "current spec"
    e.readings = e.readings or {}
    -- a reading taken inside the instance is your own list (the server sends what you have left);
    -- one taken anywhere else is the cache's full contents.
    e.readings[diff .. " / " .. spec] = { list = lines, n = #lines, diff = diff, spec = spec,
      personal = ctx.inside and true or false, at = (GetServerTime and GetServerTime()) or 0 }
    if ctx.inside then e.sawPersonal = true end
  end
  e.at = (GetServerTime and GetServerTime()) or (time and time()) or 0
  e.ctx = context()
  e.src = src or e.src
  st[key] = e
  if known then
    cache[id] = { list = lines, names = (function() local m = {} for _, x in ipairs(lines) do m[x:lower()] = true end return m end)(), n = #lines, at = GetTime and GetTime() or 0 }
  end
  if not V.quiet and known then
    ns.Print(("|cff00e676Voidcache learned|r: %s (%d) - %d item%s%s"):format(e.name or "?", id, e.n or 0, (e.n or 0) == 1 and "" or "s",
      e.ctx.boss and ("  ·  last boss: " .. e.ctx.boss .. (e.ctx.bossDiff and (" " .. e.ctx.bossDiff) or "")) or
      (e.ctx.where and ("  ·  " .. e.ctx.where .. (e.ctx.diffName and (" " .. e.ctx.diffName) or "")) or "")))
  end
  return e
end

-- pull the item list out of tooltip data, if it is a cache tooltip
function V.ListFrom(data)
  local head = PUNCH_LIST_ITEM_CACHE_TOOLTIP
  if type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
  local out, started = {}, false
  for _, line in ipairs(data.lines) do
    if line.leftText == nil and TooltipUtil and TooltipUtil.SurfaceArgs then pcall(TooltipUtil.SurfaceArgs, line) end
    local x = line.leftText
    if not started then
      -- the header string when the client has it; otherwise anything shaped like "... following items:"
      if x and ((head and x == head) or x:lower():find("following items", 1, true)) then started = true end
    else
      local name = strip(x)
      if name then out[#out + 1] = name end
    end
  end
  if not started then return nil end
  return out
end

-- watch tooltips (the modern data API, with a hook on the old path as a fallback)
local watched = false
function V.Watch()
  if watched then return end
  watched = true
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Item, function(tip, data)
      if not data or not data.id then return end
      local list = V.ListFrom(data)
      if list then
        local st = V.Store()[tostring(data.id)]
        if not st or st.n ~= #list then V.Learn(data.id, list, "tooltip") end
      end
    end)
  end
end

-- remember which boss you last fought, so a learned cache can be tied to one
local bev = CreateFrame("Frame")
bev:RegisterEvent("ENCOUNTER_END")
bev:RegisterEvent("BOSS_KILL")
bev:SetScript("OnEvent", function(_, e, a, b, c)
  if e == "ENCOUNTER_END" then V.lastBoss, V.lastBossDiff = b, (L.DIFF_NAME and L.DIFF_NAME[c]) or tostring(c)
  elseif e == "BOSS_KILL" then V.lastBoss = b end
end)

-- a cache whose own name carries this boss / dungeon ("Nebulous Voidcache: Kings' Rest").
-- The cache's wording often differs from the Adventure Journal's ("Soulcoiler Nek'zali" vs
-- "Nek'zali the Soulcoiler", "Tortollan Explorers" vs "The Lost Explorers"), so after trying the
-- whole string we match on a shared distinctive word.
local STOP = { the = true, of = true, and_ = true, ["and"] = true, a = true, lord = true }
local function words(s)
  local out = {}
  for w in s:gmatch("[%a']+") do
    w = w:gsub("'", ""):lower()
    if #w >= 5 and not STOP[w] then out[w] = true end
  end
  return out
end
function V.CacheSubject(e)
  local en = e and e.name and e.name:lower()
  if not en then return nil end
  return en:match("voidcache%s*[-–:]%s*(.+)$") or en
end
function V.FindByName(name)
  local n = name and name:lower()
  if not n then return nil end
  local best
  for _, e in pairs(V.Store()) do
    local after = V.CacheSubject(e)
    if after then
      if after == n then return e.id end
      if after:find(n, 1, true) or n:find(after, 1, true) then best = best or e.id end
    end
  end
  if best then return best end
  local want = words(n)
  for _, e in pairs(V.Store()) do
    local after = V.CacheSubject(e)
    if after then
      for w in pairs(words(after)) do if want[w] then return e.id end end
    end
  end
end

-- a learned cache for a boss / instance name, if we have one
function learnedFor(name, kind)
  if not name then return nil end
  local n = norm(name)
  if not n then return nil end
  for _, e in pairs(V.Store()) do
    local c = e.ctx or {}
    local hay = kind == "boss" and c.boss or c.where
    if hay and norm(hay) == n then return e end
  end
end

---------------------------------------------------------------- finding them by scanning
-- No API lists voidcaches and the IDs move between builds, so when hovering one isn't an option we
-- sweep a range of item IDs and keep the ones whose tooltip carries the item-list header.
-- Three phases, because the client only has a tooltip once the server has sent the item:
--   1. ask for every ID in the range   2. wait, then read   3. ask again for the ones that never
--      answered, wait longer, read once more.
-- It reports how many actually resolved, so a fruitless scan can be told apart from a broken one.
local scan = nil
local function scanRead(ids, hits)
  local resolved, sample = 0, {}
  local missing = {}
  for _, id in ipairs(ids) do
    local ok, data = pcall(C_TooltipInfo.GetItemByID, id)
    if ok and type(data) == "table" and type(data.lines) == "table" and #data.lines > 0 then
      resolved = resolved + 1
      if #sample < 3 then
        local l1 = data.lines[1]
        if l1 and l1.leftText == nil and TooltipUtil and TooltipUtil.SurfaceArgs then pcall(TooltipUtil.SurfaceArgs, l1) end
        sample[#sample + 1] = id .. "=" .. ((l1 and l1.leftText) or "?")
      end
      local list = V.ListFrom(data)
      local nm = V.IsCacheName(id)
      if (list and #list > 0) or nm then hits[#hits + 1] = { id = id, list = list or {}, name = nm } end
    else
      missing[#missing + 1] = id
    end
  end
  return resolved, missing, sample
end

function V.Scan(from, to)
  if scan then ns.Print("A scan is already running - /sk void stop to end it."); return end
  from, to = tonumber(from), tonumber(to)
  if not (from and to) or to < from then ns.Print("Usage: /sk void scan <from> <to>   e.g. /sk void scan 270000 276000"); return end
  if to - from > 20000 then ns.Print("Keep it to 20000 IDs at a time."); return end
  if not (C_TooltipInfo and C_TooltipInfo.GetItemByID and C_Item and C_Item.RequestLoadItemDataByID) then
    ns.Print("This client is missing C_TooltipInfo / item loading, so scanning can't work.")
    return
  end
  scan = { from = from, to = to, hits = {}, ids = {} }
  for id = from, to do scan.ids[#scan.ids + 1] = id end
  V.quiet = true
  ns.Print(("Scanning %d items (%d-%d). Asking the server first..."):format(#scan.ids, from, to))

  local function ask(list, done)
    local i = 1
    local function step()
      if not scan then return end
      local last = math.min(i + 399, #list)
      for k = i, last do pcall(C_Item.RequestLoadItemDataByID, list[k]) end
      i = last + 1
      if i > #list then done() else C_Timer.After(0.2, step) end
    end
    step()
  end

  ask(scan.ids, function()
    C_Timer.After(3, function()
      if not scan then return end
      local resolved, missing, sample = scanRead(scan.ids, scan.hits)
      ns.Print(("  pass 1: %d of %d items answered%s"):format(resolved, #scan.ids,
        #sample > 0 and ("  ·  e.g. " .. table.concat(sample, ", ")) or ""))
      if #missing == 0 or resolved == 0 then
        V.ScanFinish(resolved, #scan.ids)
        return
      end
      ns.Print(("  asking again for the %d that didn't answer..."):format(#missing))
      ask(missing, function()
        C_Timer.After(5, function()
          if not scan then return end
          local r2 = scanRead(missing, scan.hits)
          V.ScanFinish(resolved + r2, #scan.ids)
        end)
      end)
    end)
  end)
end

function V.ScanFinish(resolved, total)
  if not scan then return end
  table.sort(scan.hits, function(a, b) return a.id < b.id end)
  for _, h in ipairs(scan.hits) do
    local e = V.Learn(h.id, h.list, "scan")
    ns.Print(("  |cff00e676%d|r  %s  -  %s"):format(h.id, (e and e.name) or h.name or "?",
      #h.list > 0 and (#h.list .. " left: " .. table.concat(h.list, ", ")) or "|cff9a8fb0found - hover it in /sk rolls to read your list|r"))
  end
  ns.Print(("Scan done: %d of %d items readable, %d with an item list."):format(resolved, total, #scan.hits))
  if resolved == 0 then
    ns.Print("|cffff5050Nothing was readable at all|r - the server didn't answer for this range, so these IDs probably don't exist. Try another range.")
  elseif #scan.hits == 0 then
    ns.Print("Readable, but none were a voidcache (no item list, and no name containing \"" .. V.NAME_HINT .. "\") - not in this range.")
  end
  scan = nil; V.quiet = nil
end

function V.StopScan()
  if not scan then ns.Print("No scan running."); return end
  ns.Print("Scan stopped.")
  scan = nil; V.quiet = nil
end

-- /sk void check <id>: prove the reading path works on an item you know exists
function V.Check(id)
  id = tonumber(id)
  if not id then ns.Print("Usage: /sk void check <itemID>"); return end
  pcall(C_Item.RequestLoadItemDataByID, id)
  C_Timer.After(1, function()
    local ok, data = pcall(C_TooltipInfo.GetItemByID, id)
    local n = (ok and type(data) == "table" and type(data.lines) == "table") and #data.lines or 0
    local nm = C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
    ns.Print(("check %d: name=%s, tooltip lines=%d, item list=%s"):format(id, tostring(nm), n,
      (ok and data and V.ListFrom(data)) and "yes" or "no"))
  end)
end

---------------------------------------------------------------- /sk void
-- Diagnostics first: print the tooltip exactly as the client has it, so the parser can be written
-- against the real thing (including however it separates difficulties) rather than a guess.
local function nameOf(id)
  for n, v in pairs(V.BOSS) do if v == id then return n end end
  for n, v in pairs(V.INSTANCE) do if v == id then return n end end
  return "unknown"
end

function ns.VoidcacheRaw(id)
  id = tonumber(id)
  if not id then ns.Print("Usage: /sk void raw <cache item ID>"); return end
  if not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then ns.Print("No C_TooltipInfo on this client."); return end
  local ok, data = pcall(C_TooltipInfo.GetItemByID, id)
  if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    ns.Print(("%d (%s): not in the client cache yet - asked the server, run it again in a second."):format(id, nameOf(id)))
    return
  end
  local head = PUNCH_LIST_ITEM_CACHE_TOOLTIP
  ns.Print(("|cffb98cff%d  %s|r  ·  %d lines  ·  header string: %s"):format(id, nameOf(id), #data.lines,
    head and ('"' .. head .. '"') or "|cffff5050missing on this client|r"))
  for i, line in ipairs(data.lines) do
    if line.leftText == nil and TooltipUtil and TooltipUtil.SurfaceArgs then pcall(TooltipUtil.SurfaceArgs, line) end
    local lt, rt = line.leftText, line.rightText
    local extra = ""
    if line.type ~= nil then extra = extra .. " |cff6f6090type=" .. tostring(line.type) .. "|r" end
    ns.Print(("  |cff8f7fb8%2d|r %s%s%s"):format(i, lt and ("|cffffffff" .. lt .. "|r") or "|cff6f6090(no text)|r",
      rt and ("   |cffb4a0dc→ " .. rt .. "|r") or "", extra))
  end
end

function ns.VoidcacheReport(what)
  what = what and what:match("^%s*(.-)%s*$") or ""
  local first = what:match("^(%S+)")
  if first == "raw" then ns.VoidcacheRaw(what:match("^%S+%s+(%S+)")) return end
  if tonumber(first) then ns.VoidcacheRaw(first) return end
  if first == "scan" then
    local a, b = what:match("^%S+%s+(%d+)%s+(%d+)")
    V.Scan(a, b); return
  end
  if first == "stop" then V.StopScan(); return end
  if first == "check" then V.Check(what:match("^%S+%s+(%d+)")); return end
  if first == "warm" then V.Warm(); ns.Print("Asked the server for every voidcache; try /sk void in a second.") return end
  if first == "forget" then V.Forget(); ns.Print("Voidcache memory cleared."); return end
  if first == "mine" then V.Mine(); return end
  if first == "readall" then
    -- A cache's first tooltip often arrives without its item list; the list shows up on a later
    -- read. So: ask for every one, wait, read, ask again for the ones still bare, wait longer,
    -- read once more. Then file each under the current loot spec.
    local _, specName = V.LootSpec()
    local ids = {}
    for _, sd in ipairs(V.SEEDS) do
      ids[#ids + 1] = sd[1]
      pcall(C_Item.RequestLoadItemDataByID, sd[1])
    end
    ns.Print(("Reading %d caches as |cffffab00%s|r..."):format(#ids, specName or "?"))
    local function pass(final)
      local rows, got, bare = {}, 0, {}
      for _, sd in ipairs(V.SEEDS) do
        local id = sd[1]
        local list = V.ReadLink(id)
        local name = ((C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or sd[2]):gsub("^Nebulous Voidcache:%s*", "")
        if list and #list > 0 then
          V.quiet = true; V.Learn(id, list, "readall"); V.quiet = nil
          got = got + 1
          rows[#rows + 1] = { id = id, name = name, n = #list, list = list }
        else
          bare[#bare + 1] = id
          rows[#rows + 1] = { id = id, name = name }
        end
      end
      if not final and #bare > 0 then
        for _, id in ipairs(bare) do pcall(C_Item.RequestLoadItemDataByID, id) end
        C_Timer.After(3, function() pass(true) end)
        if got > 0 then ns.Print(("  %d read so far, asking again for %d..."):format(got, #bare)) end
        return
      end
      ns.Print(("|cffb98cffAs %s|r: %d with a list, %d without"):format(specName or "?", got, #bare))
      for _, r in ipairs(rows) do
        local others = {}
        for _, rd in ipairs(V.Readings(r.id)) do
          if rd.spec and rd.spec ~= specName then others[#others + 1] = rd.spec .. " " .. rd.n end
        end
        ns.Print(("   %-40s %s%s"):format(r.name, r.n and tostring(r.n) or "|cff9a8fb0-|r",
          #others > 0 and ("   |cffffab00(" .. table.concat(others, ", ") .. ")|r") or ""))
      end
      ns.Print("Switch loot spec and run /sk void readall again to compare; /sk void <name> shows one cache's items.")
    end
    C_Timer.After(2, function() pass(false) end)
    return
  end
  if first == "sweep" then
    local a, b, c = what:match("^%S+%s+(%d+)%s+(%d+)%s+(%d+)")
    V.Sweep(a, b, c); return
  end
  if first == "bonus" then
    local id = what:match("^%S+%s+(%d+)")
    local list = {}
    for b in what:gmatch("%s(%d+)") do list[#list + 1] = tonumber(b) end
    table.remove(list, 1)
    V.CompareBonuses(id, list); return
  end
  if first == "setbonus" then
    local diff, b = what:match("^%S+%s+(%a+)%s+(%d+)")
    if not diff then ns.Print("Usage: /sk void setbonus <Heroic|Mythic|Normal|LFR> <bonusID>"); return end
    diff = diff:sub(1, 1):upper() .. diff:sub(2):lower()
    V.SetBonus(diff, tonumber(b))
    ns.Print(("%s now reads through bonus ID %s."):format(diff, b))
    return
  end
  if first == "bonuses" then
    local any
    for d, b in pairs(V.KnownBonuses()) do any = true; ns.Print(("  %s = %d"):format(d, b)) end
    if not any then ns.Print("No difficulty bonus IDs set yet - find them with /sk void bonus <itemID> <b1> <b2>.") end
    return
  end
  if first == "seed" then ns.Print(("Seeded %d known caches."):format(V.Seed())); if ns.VoidUI_Refresh then ns.VoidUI_Refresh() end; return end

  if first == "clear" then ns.db.void = {}; V.Forget(); ns.Print("Forgot every learned voidcache."); return end
  local st = V.Store()
  local learned = {}
  for _, e in pairs(st) do learned[#learned + 1] = e end
  table.sort(learned, function(a, b) return (a.at or 0) > (b.at or 0) end)
  if #learned > 0 then
    ns.Print(("|cffb98cffVoidcaches learned|r (%d). Header on this client: %s"):format(#learned,
      PUNCH_LIST_ITEM_CACHE_TOOLTIP and ('"' .. PUNCH_LIST_ITEM_CACHE_TOOLTIP .. '"') or "none, matching on \"following items\" instead"))
    for _, e in ipairs(learned) do
      local c = e.ctx or {}
      local tag = c.boss and (c.boss .. (c.bossDiff and (" " .. c.bossDiff) or "")) or
                  (c.where and (c.where .. (c.diffName and (" " .. c.diffName) or "")) or "?")
      if what == "" or (e.name or ""):lower():find(what:lower(), 1, true) or tag:lower():find(what:lower(), 1, true) then
        ns.Print(("  |cffb98cff%s|r (%d) · %s · %s"):format(e.name or "?", e.id, tag,
          e.listKnown and ((e.n or 0) .. " left - " .. table.concat(e.list or {}, ", "))
          or "|cff9a8fb0list not read yet - hover it in /sk rolls|r"))
      end
    end
    return
  end
  ns.Print("No voidcache seen yet. Hover the bonus-roll icon at the end of a boss or key (or any cache item) and it is recorded automatically - then /sk void lists it.")
  ns.Print("You can also check a specific item: |cffb98cff/sk void raw <itemID>|r")
end
