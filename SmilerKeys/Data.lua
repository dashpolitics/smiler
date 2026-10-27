-- SmilerKeys: season maps, own snapshot, party scan, storage
local _, ns = ...

-- Upgrade level from run duration vs timer (+ / ++ / +++)
function ns.Chevrons(durationSec, timeLimit)
  if not durationSec or not timeLimit or timeLimit <= 0 or durationSec <= 0 then return 0 end
  if durationSec <= timeLimit * 0.6 then return 3 end
  if durationSec <= timeLimit * 0.8 then return 2 end
  if durationSec <= timeLimit then return 1 end
  return 0
end

---------------------------------------------------------------- abbreviations
local UTF8CHAR = "[%z\1-\127\194-\244][\128-\191]*"
local SKIP = {
  ["the"] = true, ["of"] = true, ["and"] = true, ["a"] = true, ["an"] = true,
  ["der"] = true, ["die"] = true, ["das"] = true, ["des"] = true, ["von"] = true,
  ["und"] = true, ["la"] = true, ["le"] = true, ["de"] = true, ["du"] = true, ["el"] = true,
}

local function firstN(w, n)
  local out = {}
  for ch in w:gmatch(UTF8CHAR) do
    out[#out + 1] = ch
    if #out >= n then break end
  end
  return table.concat(out)
end

function ns.Abbrev(name)
  local head = name:match("^([^,:]+)") or name
  local words = {}
  for w in head:gmatch("[^%s%-]+") do
    if not SKIP[w:lower()] then words[#words + 1] = w end
  end
  if #words == 0 then return firstN(head, 4):upper() end
  if #words == 1 then return firstN(words[1], 4):upper() end
  local s = ""
  for i = 1, math.min(#words, 4) do s = s .. firstN(words[i], 1):upper() end
  return s
end

---------------------------------------------------------------- maps
function ns.RefreshMaps()
  local ids = C_ChallengeMode.GetMapTable()
  if not ids or #ids == 0 then return false end
  local maps, byId = {}, {}
  for _, id in ipairs(ids) do
    local name, _, timeLimit, texture = C_ChallengeMode.GetMapUIInfo(id)
    if name then
      local m = {
        id = id, name = name, timeLimit = timeLimit, texture = texture,
        short = ns.db.settings.abbr[id] or ns.Abbrev(name),
      }
      maps[#maps + 1] = m
      byId[id] = m
    end
  end
  if #maps == 0 then return false end
  table.sort(maps, function(a, b) return a.name < b.name end)
  ns.maps, ns.mapById = maps, byId
  if not InCombatLockdown() then ns.FindTeleports() else ns.spellsDirty = true end
  return true
end

---------------------------------------------------------------- own data
local function round(x) return math.floor((x or 0) + 0.5) end

function ns.BuildSelf()
  if #ns.maps == 0 then return nil end
  local s = {
    key = ns.selfKey, name = UnitName("player"), class = select(2, UnitClass("player")),
    runs = {}, season = ns.season, ts = ns.Now(), src = "self", hasAddon = true,
    acct = ns.MyTag(),
  }
  local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player")
  s.score = round(summary and summary.currentSeasonScore)

  for _, m in ipairs(ns.maps) do
    local r = { tl = 0, ch = 0, ol = 0, sc = 0 }
    local intime, overtime = C_MythicPlus.GetSeasonBestForMap(m.id)
    if intime and intime.level then
      r.tl = intime.level
      r.ch = math.max(1, ns.Chevrons(intime.durationSec, m.timeLimit))
    end
    if overtime and overtime.level and overtime.level > r.tl then r.ol = overtime.level end
    s.runs[m.id] = r
  end
  if summary and summary.runs then
    for _, run in ipairs(summary.runs) do
      local r = s.runs[run.challengeModeID]
      if r then r.sc = round(run.mapScore) end
    end
  end

  s.keyMap   = C_MythicPlus.GetOwnedKeystoneChallengeMapID() or 0
  s.keyLevel = C_MythicPlus.GetOwnedKeystoneLevel() or 0
  return s
end

-- Rebuild own snapshot; rebroadcast if anything changed since last send.
function ns.UpdateSelf(noBroadcast)
  local s = ns.BuildSelf()
  if not s then return nil end
  ns.db.players[ns.selfKey] = s
  ns.UI_Refresh()
  if not noBroadcast and ns.announced and ns.Serialize(s, true) ~= ns.lastSent then
    ns.Debounce("broadcast", 3, function() ns.Broadcast(false) end)
  end
  return s
end

---------------------------------------------------------------- party scan (works without the addon)
local function scanUnit(unit)
  if not UnitExists(unit) or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then return end
  local name, realm = UnitFullName(unit)
  if not name then return end
  local key = ns.Normalize(realm and realm ~= "" and (name .. "-" .. realm) or name)
  local existing = ns.db.players[key]
  if existing and existing.hasAddon then return end -- their broadcast is richer

  local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)
  if not summary or not summary.runs then return end
  local s = {
    key = key, name = name, class = select(2, UnitClass(unit)), runs = {},
    score = round(summary.currentSeasonScore), season = ns.season, ts = ns.Now(),
    keyMap = 0, keyLevel = 0, src = "group", hasAddon = false,
    acct = existing and existing.acct,
  }
  for _, run in ipairs(summary.runs) do
    local m = ns.mapById[run.challengeModeID]
    if m then
      local r = { tl = 0, ch = 0, ol = 0, sc = round(run.mapScore) }
      if run.finishedSuccess then
        r.tl = run.bestRunLevel or 0
        r.ch = math.max(1, ns.Chevrons((run.bestRunDurationMS or 0) / 1000, m.timeLimit))
      else
        r.ol = run.bestRunLevel or 0
      end
      s.runs[m.id] = r
    end
  end
  ns.db.players[key] = s
end

function ns.ScanParty()
  if #ns.maps == 0 then return end
  if not IsInGroup() then ns.PruneStrangers(); ns.UI_Refresh(); return end
  local prefix, n = "party", 4
  if IsInRaid() then prefix, n = "raid", GetNumGroupMembers() end
  for i = 1, n do scanUnit(prefix .. i) end
  ns.PruneStrangers()
  ns.UI_Refresh()
end

---------------------------------------------------------------- storage
-- Store a snapshot from someone else. Newest timestamp wins.
function ns.Store(s)
  if not s.key or s.key == ns.selfKey then return false end
  if ns.season > 0 and s.season and s.season > 0 and s.season ~= ns.season then return false end
  local cur = ns.db.players[s.key]
  if cur and cur.hasAddon and (cur.ts or 0) >= (s.ts or 0) then return false end
  s.seen = ns.Now()
  if not s.acct and cur and cur.acct then s.acct = cur.acct end
  ns.db.players[s.key] = s
  ns.UI_Refresh()
  return true
end

function ns.Purge()
  local maxAge = (ns.db.settings.maxAgeDays or 21) * 86400
  local now = ns.Now()
  for key, p in pairs(ns.db.players) do
    if key ~= ns.selfKey and not p.test then
      local wrongSeason = ns.season > 0 and p.season and p.season > 0 and p.season ~= ns.season
      if wrongSeason or now - (p.ts or 0) > maxAge then ns.db.players[key] = nil end
    end
  end
end

---------------------------------------------------------------- friends vs strangers
local function secret(v) return issecretvalue and issecretvalue(v) or false end
local FRIENDLY_SRC = { self = true, guild = true, friend = true, bnet = true, relay = true }

-- Who you know: character friends, Battle.net friends (and the character they're on), guildmates
function ns.BuildSocial()
  local names, tags = {}, {}
  for i = 1, C_FriendList.GetNumFriends() or 0 do
    local f = C_FriendList.GetFriendInfoByIndex(i)
    -- friends whose data hasn't loaded have a blank name: skip them
    local key = f and f.name and not secret(f.name) and f.name ~= "" and ns.Normalize(f.name)
    if key then names[key] = true end
  end
  for i = 1, (BNGetNumFriends()) or 0 do
    local a = C_BattleNet.GetFriendAccountInfo(i)
    if a and a.battleTag and not secret(a.battleTag) then tags[a.battleTag:lower()] = true end
  end
  ns.ForEachBNetWoW(function(_, _, char, realm)
    if char and realm and char ~= "" and not secret(char) then
      local key = ns.Normalize(char .. "-" .. ns.NormalizeRealm(realm))
      if key then names[key] = true end
    end
  end)
  if IsInGuild() and GetNumGuildMembers then
    for i = 1, GetNumGuildMembers() or 0 do
      local n = GetGuildRosterInfo(i)
      local key = n and not secret(n) and n ~= "" and ns.Normalize(n)
      if key then names[key] = true end
    end
  end
  ns.social = { names = names, tags = tags, t = GetTime() }
end

function ns.IsFriend(p)
  if not ns.social or GetTime() - ns.social.t > 20 then ns.BuildSocial() end
  if p.key == ns.selfKey or FRIENDLY_SRC[p.src] or p.test then return true end
  if ns.social.names[p.key] or ns.db.settings.acct[p.key] then return true end
  return p.acct and ns.social.tags[p.acct:lower()] or false
end

local function groupKeys()
  local set = {}
  if not IsInGroup() then return set end
  local prefix, n = "party", 4
  if IsInRaid() then prefix, n = "raid", GetNumGroupMembers() end
  for i = 1, n do
    local unit = prefix .. i
    if UnitExists(unit) then
      local name, realm = UnitFullName(unit)
      if name and not secret(name) then
        set[ns.Normalize(realm and realm ~= "" and (name .. "-" .. realm) or name)] = true
      end
    end
  end
  return set
end

-- Everyone you've synced with stays (friend or not) until the usual age purge; /sk forget <name> drops one
function ns.PruneStrangers() end

---------------------------------------------------------------- accounts
local function tagName(tag) return tag and (tag:match("^([^#]+)") or tag) end

-- Display name for a player's account, or nil
function ns.AcctLabel(p)
  if not p then return nil end
  return tagName(ns.db.settings.acct[p.key] or p.acct)
end

-- Grouping key: full BattleTag when known; a manual name matches a known tag by its name part
function ns.GroupKey(p)
  local a = ns.db.settings.acct[p.key] or p.acct
  if not a then return "c:" .. p.key end
  if not a:find("#", 1, true) then
    local want = a:lower()
    for _, q in pairs(ns.db.players) do
      if q.acct and tagName(q.acct):lower() == want then return "a:" .. q.acct:lower() end
    end
  end
  return "a:" .. a:lower()
end

function ns.Assign(key, name)
  name = (name or ""):match("^%s*(.-)%s*$")
  if name == "" then
    ns.db.settings.acct[key] = nil
    ns.Print(key, "unlinked.")
  else
    name = name:gsub("[~;,|]", "")
    ns.db.settings.acct[key] = name
    ns.Print(key, "→ account", name)
  end
  ns.UI_Refresh()
end

-- "Name" or "Name-Realm" -> stored key (case-insensitive, must be unique)
function ns.FindPlayer(who)
  local lw = who:lower()
  if ns.db.players[ns.Normalize(who)] then return ns.Normalize(who) end
  local hit
  for key, p in pairs(ns.db.players) do
    if key:lower() == lw or (p.name and p.name:lower() == lw) then
      if hit then return nil end
      hit = key
    end
  end
  return hit
end

-- Rows grouped by account: { p, first, alt, gi, hiddenAlts }, plus number of groups
-- ns.sortBy = { col = <mapID> | "score" | "resi" | "key", desc = true|false } (nil = default order)
ns.tempHidden = ns.tempHidden or {}   -- right-click > Hide for now: until you reload or log out
function ns.SortValue(p, col)
  if col == "score" then return p.score or 0 end
  if col == "resi" then return (ns.Resi(p)) or 0 end
  if col == "key" then return p.keyLevel or 0 end
  local r = p.runs and p.runs[col]
  return r and r.tl or 0
end
function ns.SortedPlayers()
  local hidden = ns.db.settings.hidden
  local sb = ns.sortBy
  local sm = sb and sb.col
  local function lv(p) return ns.SortValue(p, sm) end
  local function before(a, b) if sb.desc then return a > b end return a < b end

  local groups, byKey = {}, {}
  for key, p in pairs(ns.db.players) do
    if not hidden[key] and not ns.tempHidden[key] then
      local gk = ns.GroupKey(p)
      local g = byKey[gk]
      if not g then g = { key = gk, m = {}, best = 0 }; byKey[gk] = g; groups[#groups + 1] = g end
      g.m[#g.m + 1] = p
      g.best = math.max(g.best, p.score or 0)
      if key == ns.selfKey then g.self = true end
      if ns.IsFriend(p) then g.friend = true end
    end
  end

  for _, g in ipairs(groups) do
    table.sort(g.m, function(a, b)
      if not sm then
        if a.key == ns.selfKey then return true end
        if b.key == ns.selfKey then return false end
      elseif lv(a) ~= lv(b) then
        return before(lv(a), lv(b))
      end
      if (a.score or 0) ~= (b.score or 0) then return (a.score or 0) > (b.score or 0) end
      return a.key < b.key
    end)
  end
  table.sort(groups, function(a, b)
    if sm then
      local la, lb = lv(a.m[1]), lv(b.m[1])
      if la ~= lb then return before(la, lb) end
    else
      if a.self ~= b.self then return a.self == true end
    end
    if a.best ~= b.best then return a.best > b.best end
    return a.key < b.key
  end)

  -- sections: people you know, your current group, then everyone else you've synced with
  local friends, strangers, others = {}, {}, {}
  local inGroup = groupKeys()
  for _, g in ipairs(groups) do
    local grouped = false
    for _, p in ipairs(g.m) do if inGroup[p.key] then grouped = true end end
    if g.friend then friends[#friends + 1] = g elseif grouped then strangers[#strangers + 1] = g else others[#others + 1] = g end
  end
  local rows, showAlts, gi = {}, ns.db.settings.showAlts, 0
  local function add(list)
    for _, g in ipairs(list) do
      gi = gi + 1
      for i, p in ipairs(g.m) do
        if i == 1 or showAlts then
          rows[#rows + 1] = { p = p, first = i == 1, alt = i > 1, gi = gi, gk = g.key,
                              hiddenAlts = (i == 1 and not showAlts) and (#g.m - 1) or 0 }
        end
      end
    end
  end
  if #strangers > 0 or #others > 0 then rows[#rows + 1] = { header = "FRIENDS" } end
  add(friends)
  if #strangers > 0 then rows[#rows + 1] = { header = "GROUP" } end
  add(strangers)
  if #others > 0 then rows[#rows + 1] = { header = "OTHERS" } end
  add(others)
  return rows, #groups
end

---------------------------------------------------------------- resilient keystones
-- Timing every season dungeon at +12 or higher unlocks Resilient Keystones (keys can't drop below
-- that level); timing all of them at the next level raises it. So: lowest best timed key, if >= 12.
ns.RESI_MIN = 12

function ns.Resi(p)
  if #ns.maps == 0 then return nil, 0 end
  local lowest
  for _, m in ipairs(ns.maps) do
    local r = p.runs and p.runs[m.id]
    local t = r and r.tl or 0
    lowest = lowest and math.min(lowest, t) or t
  end
  return (lowest >= ns.RESI_MIN) and lowest or nil, lowest
end

-- Dungeons still below the next resilient level: { {map, best}, ... }
function ns.ResiMissing(p, target)
  local out = {}
  for _, m in ipairs(ns.maps) do
    local r = p.runs and p.runs[m.id]
    local t = r and r.tl or 0
    if t < target then out[#out + 1] = { m = m, best = t } end
  end
  table.sort(out, function(a, b) return a.best < b.best end)
  return out
end

---------------------------------------------------------------- upgrades
function ns.LastReset()
  local f = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset
  local s = f and f()
  if not s then return 0 end
  return ns.Now() + s - 7 * 86400
end

-- A key counts only if it was reported after this week's reset
function ns.KeyFresh(p)
  if not p.keyMap or p.keyMap == 0 or not ns.mapById[p.keyMap] then return false end
  return p.key == ns.selfKey or (p.ts or 0) >= ns.LastReset()
end

-- cell[targetKey][mapId] = { holder, ... }   key[holderKey] = { {p = target, from = bestTimed}, ... }
-- A key is an upgrade for anyone on another account whose highest timed level there is lower.
function ns.ComputeUpgrades(rows)
  local cell, key = {}, {}
  for _, h in ipairs(rows) do
    local hp = h.p
    if hp and ns.KeyFresh(hp) then
      for _, t in ipairs(rows) do
        if t.p and t.gk ~= h.gk then
          local r = t.p.runs and t.p.runs[hp.keyMap]
          local best = r and r.tl or 0
          if (hp.keyLevel or 0) > best then
            local tk = t.p.key
            cell[tk] = cell[tk] or {}
            cell[tk][hp.keyMap] = cell[tk][hp.keyMap] or {}
            table.insert(cell[tk][hp.keyMap], hp)
            key[hp.key] = key[hp.key] or {}
            table.insert(key[hp.key], { p = t.p, from = best })
          end
        end
      end
    end
  end
  return cell, key
end

---------------------------------------------------------------- test data
function ns.ToggleTest()
  local had = false
  for k, p in pairs(ns.db.players) do
    if p.test then ns.db.players[k] = nil; had = true end
  end
  if not had then
    local names = { { "Kaelira", "PRIEST", "Shaz#2201" }, { "Velmoor", "MAGE", "Shaz#2201" },
                    { "Brumgar", "WARRIOR", "Grim#1120" }, { "Ysolde", "EVOKER", "Nyx#3310" },
                    { "Thornvik", "DEMONHUNTER" }, { "Mossa", "DRUID", "Grim#1120" } }
    for idx, n in ipairs(names) do
      local p = { key = n[1] .. "-TestRealm", name = n[1], class = n[2], runs = {},
                  ts = ns.Now() - idx * 2400, season = ns.season, test = true,
                  acct = n[3], hasAddon = idx ~= 5, src = idx == 5 and "group" or (idx % 2 == 0 and "bnet" or "guild"),
                  keyMap = 0, keyLevel = 0 }
      local total = 0
      for _, m in ipairs(ns.maps) do
        local r, roll = { tl = 0, ch = 0, ol = 0, sc = 0 }, math.random(10)
        if roll > 2 then
          r.tl = math.random(6, 16); r.ch = math.random(3); r.sc = 120 + r.tl * 15
        elseif roll == 2 then
          r.ol = math.random(8, 15); r.sc = 90
        end
        total = total + r.sc
        p.runs[m.id] = r
      end
      p.score = total
      if p.hasAddon and #ns.maps > 0 then
        p.keyMap = ns.maps[math.random(#ns.maps)].id; p.keyLevel = math.random(8, 15)
      end
      ns.db.players[p.key] = p
    end
  end
  ns.Print(had and "Test players removed." or "Test players added (removed on logout).")
  ns.UI_Refresh()
end
