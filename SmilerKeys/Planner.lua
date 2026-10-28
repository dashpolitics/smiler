-- SmilerKeys: Where to go – a visual planner.
-- Top: the boss map for this week (rolled / killed / open / past your Mythic farm, click to change).
-- Middle: the plan as a flow, one row per week, time running down. Each card is a decision (roll here, kill these,
-- craft that) with the reasons on it and the next-best option to swap to; swapping re-plans every later week.
-- Right: each wanted item and how likely you are to have it, by when.
-- Every item is weighted by its QE upgrade %, your priority and BiS. Items you already own drop out.
local _, ns = ...
local L = ns.Loot
local T = ns.T

---------------------------------------------------------------- settings
local DEFAULTS = {
  scope = "wish", modes = { bonus = true, drop = true, vault = false, other = true, delve = true },
  -- lair bosses are not part of the raid's kill order, so they are not covered by the farm count:
  -- each one is on or off by itself. Keyed by lowercased boss name; false means not on farm yet.
  lairFarm = {},
  farm = nil,            -- Mythic bosses on farm (nil = all)
  rollsNow = nil,        -- bonus rolls you have now (nil = read from your currency)
  rollsWeek = 2,         -- bonus rolls you get each week
  drops = true,          -- count your share of raid drops
  dropPct = 15,          -- chance a boss kill gives *you* an item (group loot)
  weeks = 12,
}
function L.PlanOpts()
  local cs = ns.CharSettings()
  if not cs.planner then
    -- First time on this character. Start from the old account-wide table so the tuning you have
    -- already done carries over once; it is left in place, so every character starts from the same
    -- point and then goes its own way.
    cs.planner = {}
    local old = ns.db.settings.planner
    if type(old) == "table" then
      for k, v in pairs(old) do
        cs.planner[k] = (k == "modes" and type(v) == "table")
          and { bonus = v.bonus, drop = v.drop, vault = v.vault, other = v.other, delve = v.delve } or v
      end
    end
  end
  local o = cs.planner
  for k, v in pairs(DEFAULTS) do
    if type(v) == "table" then
      o[k] = o[k] or {}
      for mk, mv in pairs(v) do if o[k][mk] == nil then o[k][mk] = mv end end   -- a new mode gets its default
    elseif o[k] == nil then
      o[k] = v
    end
  end
  return o
end

---------------------------------------------------------------- this week: rolled / killed (records, lockouts, your clicks)
local function weekID()
  local now = GetServerTime and GetServerTime() or (time and time()) or 0
  local left = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset and C_DateAndTime.GetSecondsUntilWeeklyReset() or 0
  return math.floor((now + left) / 86400)
end
local function weekState()
  local s = ns.db.settings
  local cs = ns.CharSettings()
  local id = weekID()
  -- Lockouts and bonus rolls are per character, so the boss map is too. The old account-wide week
  -- is handed to the first character that asks for it, if it is still this week's; the others start
  -- clean rather than inheriting someone else's kills.
  if not cs.planWeek and s.planWeek and s.planWeek.week == id and not s.planWeekClaimed then
    s.planWeekClaimed = ns.selfKey or "?"
    cs.planWeek = s.planWeek
  end
  if not cs.planWeek or cs.planWeek.week ~= id then cs.planWeek = { week = id, status = {}, rolls = {}, picks = {} } end
  local w = cs.planWeek
  w.status = w.status or {}; w.rolls = w.rolls or {}; w.picks = w.picks or {}
  if w.v ~= 2 then
    -- Status used to be keyed by boss name alone, so marking Heroic Ula'tek killed also marked it
    -- on LFR, Normal and Mythic: one value for all four. Keys are now "boss:difficulty". The old
    -- ones are dropped rather than guessed at - your raid lockout fills most of it back in by
    -- itself, and anything manual is one click to redo.
    w.status = {}
    w.v = 2
  end
  return w
end
L.WeekState = weekState
local function skey(name, diff) return (name or ""):lower() .. ":" .. tostring(diff or 16) end

-- status of a boss this week: "rolled", "killed" or "open" (your click wins, then a recorded roll, then the lockout)
function L.BossStatus(name, diff)
  local lname = (name or ""):lower()
  local w = weekState()
  local mine = w.status[skey(name, diff)]
  if mine then return mine, "you" end
  -- a recorded roll counts only on the difficulty it happened on; older records kept no difficulty,
  -- so those still count everywhere rather than being thrown away
  for _, r in ipairs(w.rolls) do
    if r.boss == lname and (r.diff == nil or diff == nil or r.diff == diff) then return "rolled", "recorded" end
  end
  L._lock = L._lock or L.KilledThisWeek()
  if L._lock[lname .. ":" .. tostring(diff or 16)] then return "killed", "lockout" end
  return "open"
end
function L.SetBossStatus(name, diff, st)
  weekState().status[skey(name, diff)] = st            -- "open" is stored, so it can beat a lockout
end
function L.CycleBossStatus(name, diff)
  local cur = L.BossStatus(name, diff)
  local nxt = (cur == "open" and "rolled") or (cur == "rolled" and "killed") or "open"
  L.SetBossStatus(name, diff, nxt)
  return nxt
end
-- kept for older callers
function L.IsKilledThisWeek(key) local name, d = key:match("^(.-):(%d+)$"); return L.BossStatus(name or key, tonumber(d)) ~= "open" end
function L.SetKilledThisWeek(key, v)
  local name, d = key:match("^(.-):(%d+)$")
  L.SetBossStatus(name or key, tonumber(d or "") or 16, v and "killed" or "open")
end

-- record bonus rolls as they happen: which boss (the last kill), what it gave, which loot spec
local lastKill
local rec = CreateFrame("Frame")
rec:RegisterEvent("ENCOUNTER_END")
rec:RegisterEvent("BONUS_ROLL_RESULT")
rec:SetScript("OnEvent", function(_, e, a1, a2, a3, a4, a5)
  if not ns.db then return end
  if e == "ENCOUNTER_END" then
    local ok = (not issecretvalue or not issecretvalue(a5)) and a5 == 1
    if ok and type(a2) == "string" and (not issecretvalue or not issecretvalue(a2)) then lastKill = { name = a2:lower(), diff = a3, t = GetTime() } end
  elseif e == "BONUS_ROLL_RESULT" then
    local w = weekState()
    local boss = lastKill and (GetTime() - lastKill.t) < 300 and lastKill.name or "?"
    w.rolls[#w.rolls + 1] = { boss = boss, diff = lastKill and lastKill.diff, kind = a1, item = type(a2) == "string" and a2 or nil, spec = a4, t = time and time() or 0 }
    if ns.Planner_Refresh then ns.Planner_Refresh() end
  end
end)

---------------------------------------------------------------- weights: QE %, priority, BiS
function L.ItemWeight(id)
  local q = L.QEScores and L.QEScores()
  local pct = q and q.scores and q.scores[id]
  local base = (pct and pct > 0) and pct or 0.2            -- no QE score: a small default
  local pr = L.Prio(id)
  local pf = pr and (1 + (L.PRIO_MAX + 1 - pr) / L.PRIO_MAX) or 1   -- priority 1 = x2, 15 = x1.07
  local bf = L.IsBiS(id) and 1.5 or 1
  return base * pf * bf, pct, pr
end

---------------------------------------------------------------- what you already own (bags + equipped), best item level per ID
local function ownedLevels()
  local out = {}
  local function note(link)
    if not link then return end
    local id = C_Item.GetItemInfoInstant(link)
    local lv = C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(link) or 0
    if id and (not out[id] or lv > out[id]) then out[id] = lv end
  end
  for inv = 1, 17 do note(GetInventoryItemLink("player", inv)) end
  if C_Container and C_Container.GetContainerNumSlots then
    for bag = 0, 4 do
      for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
        local info = C_Container.GetContainerItemInfo(bag, slot)
        note(info and info.hyperlink)
      end
    end
  end
  return out
end

---------------------------------------------------------------- loot table sizes (what a bonus roll picks from)
local sizeCache = {}
local function tableSize(it)
  local key = it.raid and ("r" .. (it.enc or 0)) or ("d" .. tostring(it.instID))
  if sizeCache[key] then return sizeCache[key] end
  local n = 0
  for _, x in ipairs(L.items or {}) do
    if not x.offspec and not x.hidden and not x.reagent then
      if it.raid and x.raid and x.enc == it.enc then n = n + 1
      elseif not it.raid and not x.raid and x.instID == it.instID and not x.crafted and not x.delve then n = n + 1 end
    end
  end
  sizeCache[key] = math.max(1, n)
  return sizeCache[key]
end

-- How many items a bonus roll there is really picking from. The checklist in /sk rolls knows what
-- you have already had from a roll, and those items are out of the pool until the table resets -
-- so a boss you have nearly cleared is far better odds than its loot table suggests, and a boss
-- with one item left is a certainty. Rolling the last one resets the table, so a complete table
-- counts as full again.
local function rollSrc(it)
  if it.raid then return { enc = it.enc, name = it.encName, boss = it.encName, raid = true } end
  return { instID = it.instID, name = it.inst }
end

local function poolSize(it, diff)
  if not (L.RollItems and L.RolledCount) then return tableSize(it) end
  local ok, items = pcall(L.RollItems, rollSrc(it))
  if not ok or type(items) ~= "table" or #items == 0 then return tableSize(it) end
  local done = select(1, L.RolledCount(rollSrc(it), items, nil, diff))
  local left = #items - (done or 0)
  if left <= 0 then return #items, true end       -- table complete: it resets, so everything is back
  return left, false, (done or 0) > 0
end

-- An item you already have at a good level drops out of the plan, which is right, but it used to
-- vanish without a word - a priority-1 pick could disappear and look like a bug. This works out the
-- best way that WOULD beat what you are wearing, and what is stopping you taking it.
local function parkedReason(it, have, opts)
  local m = opts.modes or {}
  local topLv, line = nil, nil
  for _, r in ipairs(L.Routes(it)) do
    local top = r.max or r.ilvl or 0
    if top > (have or 0) and (not topLv or top > topLv) then
      local kind = (r.kind == "delve" and "delve") or (r.kind == "crafted" and "other")
        or (r.mode == "bonus" and "bonus") or (r.mode == "vault" and "vault") or "drop"
      topLv = top
      if it.raid and not it.lair and r.diff == 16 and opts.farm and (it.encIndex or 0) > opts.farm then
        line = ("only Mythic beats it · boss %d, past your farm of %d"):format(it.encIndex or 0, opts.farm)
      elseif not m[kind] then
        line = ("%s would, but that switch is off"):format(r.label or kind)
      else
        line = ("%s gives %d, up to %d with crests"):format(r.label or "?", r.ilvl or 0, top)
      end
    end
  end
  return line or "nothing this season beats it"
end

local function bossDiff(it, opts)
  if it.raid and not it.lair and opts.farm and (it.encIndex or 0) > opts.farm then return 15 end
  return 16
end

---------------------------------------------------------------- the plan
-- Assumptions (shown in the window): a bonus roll gives one item from that boss's loot for your spec, all equally
-- likely; one roll per boss per week; Mythic+ completions take rolls too. Your share of a kill's drops: dropPct%.
function L.Simulate(opts)
  opts = opts or L.PlanOpts()
  sizeCache = {}
  local own = ownedLevels()
  local places = L.PlanFor(opts)
  local items, sources, sure, ownedList = {}, {}, {}, {}
  for _, g in ipairs(places) do
    for _, x in ipairs(g.items) do
      local it = x.it
      local w, pct, pr = L.ItemWeight(it.id)
      local r = { it = it, w = w, pct = pct, prio = pr, bis = x.bis, p = 1, route = x.route, kind = x.kind, pw = {} }
      -- What this way is worth is where the item ENDS UP, not what it drops at: a Heroic bonus roll
      -- lands at 318 and crests to 334, which beats the 321 you are wearing by a mile. Comparing the
      -- drop level parked it. The route picker next door already compared the top, so the two halves
      -- of the planner were answering the same question differently.
      local need = x.route and (x.route.max or x.route.ilvl or 0) or 0
      local ol = own[it.id]
      local rolledOut = false
      -- the difficulty of the way this item is actually coming to you. It used to be worked out
      -- separately from the route, so a boss whose best allowed route was Heroic could be labelled,
      -- pooled and tick-checked as Mythic (and the other way round). The route is the truth.
      local rdiff = it.raid and ((x.route and x.route.diff) or bossDiff(it, opts)) or nil
      if L.IsRolled and x.kind == "bonus" then
        local d = rdiff or 15
        local okR, got = pcall(L.IsRolled, rollSrc(it), { id = it.id, name = it.name }, nil, d)
        rolledOut = okR and got or false
      end
      if rolledOut then
        r.rolledOut = true; ownedList[#ownedList + 1] = r     -- a roll there cannot give it again yet
      -- You have it, and this way does not give more: park it. The old rule ALSO parked anything
      -- already on the same track, "the rest is crests" - which quietly threw away a Mythic roll at
      -- 334 because you were wearing myth-track 321. A way that gives more item level is an upgrade
      -- whatever track you are on; a way that gives the same or less is caught by ol >= need.
      elseif ol and ol >= need then
        r.ownedAt = own[it.id]
        r.why = parkedReason(it, ol, opts)      -- so the window says what would beat it, not just that it is out
        ownedList[#ownedList + 1] = r
      elseif x.kind == "bonus" or (x.kind == "drop" and it.raid) or (opts.modes.bonus and it.bonus and not it.crafted and not it.delve) then
        -- keyed by boss AND difficulty: Heroic Ula'tek and Mythic Ula'tek are separate lockouts and
        -- separate roll pools, so they are separate places to go, not one card that picks a label
        local key = it.raid and ("r" .. (it.enc or 0) .. ":" .. tostring(rdiff)) or ("d" .. tostring(it.instID))
        local s = sources[key]
        if not s then
          local diff = rdiff
          local n, reset, tracked = poolSize(it, diff or 15)
          s = { key = key, label = it.raid and (it.encName ~= "" and it.encName or g.label) or (it.inst or g.label), inst = it.inst,
                raid = it.raid, lair = it.lair, n = n, poolReset = reset, poolTracked = tracked, items = {}, diff = diff, encName = it.encName,
                bonus = opts.modes.bonus and it.bonus, drops = opts.drops and opts.modes.drop and it.raid }
          if it.raid then s.status = L.BossStatus(it.encName, diff) end
          sources[key] = s
        end
        s.items[#s.items + 1] = r
        items[#items + 1] = r
      else
        sure[#sure + 1] = r         -- crafted, vault, Labyrinth, M+ runs: not a matter of luck
      end
    end
  end
  -- items PlanFor held back on purpose (a BiS pick with no route to its best version) join the
  -- parked list, so the window can say why instead of simply not mentioning them
  for _, p in ipairs(L.planParked or {}) do
    local w, pct, pr = L.ItemWeight(p.it.id)
    ownedList[#ownedList + 1] = { it = p.it, w = w, pct = pct, prio = pr, bis = true, p = 1, pw = {}, why = p.why, held = true }
  end
  local list = {}
  for _, s in pairs(sources) do list[#list + 1] = s end
  table.sort(list, function(a, b) return a.label < b.label end)
  local totalW = 0
  for _, r in ipairs(items) do totalW = totalW + r.w end

  local function gain(s) local g = 0; for _, r in ipairs(s.items) do g = g + r.w * r.p / s.n end; return g end
  local function chanceAny(s) local c = 0; for _, r in ipairs(s.items) do c = c + r.p / s.n end; return math.min(1, c) end
  local picks = weekState().picks         -- your swaps: picks[week][n] = source key or "skip"
  local weeks = {}
  local rollsNow = opts.rollsNow or L.BonusRolls() or opts.rollsWeek
  local carry = 0
  for w = 1, opts.weeks do
    local rolls = (w == 1) and rollsNow or (opts.rollsWeek + carry)
    local week = { rolls = {}, kills = {}, n = rolls }
    local used = {}
    local function available(s)
      if w == 1 and s.raid and s.status ~= "open" then return false end    -- already rolled on or killed this week
      return true
    end
    for k = 1, rolls do
      -- options at this point, best first
      local opt = {}
      for _, s in ipairs(list) do
        if s.bonus and available(s) and not (s.raid and used[s.key]) then
          local g = gain(s)
          if g > 0 then opt[#opt + 1] = { s = s, g = g, c = chanceAny(s) } end
        end
      end
      table.sort(opt, function(a, b) return a.g > b.g end)
      if #opt == 0 then break end
      local want = picks[w] and picks[w][k]
      local choice
      if want == "skip" then choice = "skip"
      elseif want then for _, o in ipairs(opt) do if o.s.key == want then choice = o end end end
      choice = choice or opt[1]
      local card = { kind = "roll", k = k, options = opt, choice = choice, forced = want ~= nil }
      week.rolls[#week.rolls + 1] = card
      if choice ~= "skip" then
        local s = choice.s
        used[s.key] = true
        -- the items behind it, for the reasons line
        local why = {}
        for _, r in ipairs(s.items) do if r.p > 0.001 then why[#why + 1] = r end end
        table.sort(why, function(a, b) return a.w * a.p > b.w * b.p end)
        card.why = why
        card.chance = choice.c
        for _, r in ipairs(s.items) do r.p = r.p * (1 - 1 / s.n) end
      end
    end
    carry = math.max(0, rolls - #week.rolls)
    week.unused = carry
    -- your share of drops from the bosses you kill
    week.drops = 0
    for _, s in ipairs(list) do
      if s.drops and available(s) then
        local f = (opts.dropPct or 15) / 100 / s.n
        local exp = 0
        for _, r in ipairs(s.items) do exp = exp + r.p * f; r.p = r.p * (1 - f) end
        if exp > 0 then week.kills[#week.kills + 1] = { s = s, exp = exp } end
        week.drops = week.drops + exp
      end
    end
    table.sort(week.kills, function(a, b) return a.exp > b.exp end)
    local got, gotW = 0, 0
    for _, r in ipairs(items) do
      got = got + (1 - r.p); gotW = gotW + r.w * (1 - r.p)
      r.pw[w] = 1 - r.p
      if not r.w50 and r.p <= 0.5 then r.w50 = w end
      if not r.w90 and r.p <= 0.1 then r.w90 = w end
    end
    week.expected, week.share = got, totalW > 0 and gotW / totalW or 0
    weeks[w] = week
  end
  table.sort(items, function(a, b) return a.w > b.w end)
  local w50, w90
  for w, wk in ipairs(weeks) do
    if not w50 and wk.share >= 0.5 then w50 = w end
    if not w90 and wk.share >= 0.9 then w90 = w end
  end
  return { items = items, sure = sure, owned = ownedList, weeks = weeks, rollsNow = rollsNow, w50 = w50, w90 = w90, sources = list }
end

function L.SetPick(week, k, key)
  local p = weekState().picks
  p[week] = p[week] or {}
  p[week][k] = key
  -- later weeks re-plan around this: drop their swaps
  for w in pairs(p) do if w > week then p[w] = nil end end
end
function L.ClearPicks() weekState().picks = {} end

---------------------------------------------------------------- window
local W, H = 1060, 720
local MAP_Y, FLOW_Y = -74, -300
local FLOW_W, SIDE_W = 760, 250
local CARD_W, CARD_H, CARD_GAP = 182, 78, 8
-- the season grid: one row per difficulty, one column per boss, then a strip of the M+ dungeons
local GRID_LBL, GRID_CW, GRID_CH, GRID_GX, GRID_GY = 56, 86, 24, 6, 3
local win
local cards, heads, bars = {}, {}, {}
local gridCells, dungeonTiles = {}, {}
local state = { offset = 0 }
ns.PlannerState = state     -- exposed so the scroll maths can be checked in tests

local function refresh() if ns.Planner_Refresh then ns.Planner_Refresh() end; if ns.Paperdoll_Refresh then ns.Paperdoll_Refresh() end end
local function fmtPct(v) return v and string.format("%+.2f%%", v) or "" end
local function itemTag(r)
  local t = {}
  if r.prio then t[#t + 1] = "P" .. r.prio end
  if r.bis then t[#t + 1] = "BiS" end
  if r.pct then t[#t + 1] = string.format("QE %+.1f%%", r.pct) end
  return table.concat(t, " ")
end
local function shortName(n) n = n or "?"; return #n > 22 and (n:sub(1, 21) .. "…") or n end
-- grid columns are 86px, so names get the key grid's own abbreviation, then a hard trim
local function tinyName(n, w)
  n = n or "?"
  local max = math.max(4, math.floor((w or 86) / 7))   -- the grid font is about 7px a character
  if #n <= max then return n end
  local a = ns.Abbrev and ns.Abbrev(n)
  if a and #a > 0 and #a <= max then return a end
  return n:sub(1, max - 1) .. "…"
end

local function toggle(parent, label, get, set, w)
  local b = T.Button(parent, label, w or 100, 24, function() set(not get()); refresh() end)
  function b:Sync()
    local on = get()
    if self.SetBackdropColor then self:SetBackdropColor(T.RGB(on and "amethyst" or "raised", on and 1 or 0.8)) end
    if self.text then self.text:SetTextColor(T.RGB(on and "void" or "muted")) end
  end
  return b
end

-- x may be a number (absolute) or a frame to sit after: the toggles to its left grow with their
-- labels, so a fixed x put this row straight on top of them
local function stepper(parent, label, x, y, get, set, fmt, tip, gap)
  local l = T.Text(parent, "label", 11, "muted")
  if type(x) == "table" then l:SetPoint("LEFT", x, "RIGHT", gap or 20, -6) else l:SetPoint("TOPLEFT", x, y - 6) end
  l:SetText(label)
  local lw = math.max(60, math.ceil(l:GetStringWidth() or 60) + 8)
  local minus = T.Button(parent, "–", 22, 22, function() set(-1); refresh() end)
  if type(x) == "table" then minus:SetPoint("LEFT", l, "RIGHT", 6, 6) else minus:SetPoint("TOPLEFT", x + lw, y) end
  local v = T.Text(parent, "display", 14, "text", "CENTER"); v:SetPoint("LEFT", minus, "RIGHT", 2, 0); v:SetWidth(44)
  local plus = T.Button(parent, "+", 22, 22, function() set(1); refresh() end)
  plus:SetPoint("LEFT", v, "RIGHT", 2, 0)
  if tip then
    for _, f in ipairs({ minus, plus }) do
      f:HookScript("OnEnter", function(s) GameTooltip:SetOwner(s, "ANCHOR_TOP"); GameTooltip:AddLine(label, T.RGB("amethyst")); GameTooltip:AddLine(tip, 1, 1, 1, true); GameTooltip:Show() end)
      f:HookScript("OnLeave", GameTooltip_Hide)
    end
  end
  return function() v:SetText(fmt(get())) end, lw + 22 + 48 + 22, plus
end

---------------------------------------------------------------- the season grid
-- Four rows, one per raid difficulty, by this season's bosses. A row is told apart by its name and
-- by the shape in each cell as well as by colour, so it reads the same without colour.
local STATUS = {
  open    = { icon = nil,     text = "open",   color = "soft",    mark = "" },
  rolled  = { icon = "star",  text = "rolled", color = "diamond", mark = "*" },
  killed  = { icon = "tick",  text = "killed", color = "emerald", mark = "x" },
}
local DIFF_ROWS = {
  { 17, "LFR",    "muted" },
  { 14, "NORMAL", "sapphire" },
  { 15, "HEROIC", "amethyst" },
  { 16, "MYTHIC", "topaz" },
}

local function cellKey(r, c) return r * 100 + c end

local function makeCell(parent, r, c)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(GRID_CW, GRID_CH)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  T.Panel(b, "card", 0.85, 0.5)
  b.st = T.IconTex(b, "star", 11, "emerald"); b.st:SetPoint("LEFT", 6, 0)
  b.t = T.Text(b, "label", 10, "soft", "LEFT"); b.t:SetPoint("LEFT", 20, 0); b.t:SetWidth(GRID_CW - 40)
  b.n = T.Text(b, "display", 10, "topaz", "RIGHT"); b.n:SetPoint("RIGHT", -5, 0)
  b.ring = CreateFrame("Frame", nil, b, "BackdropTemplate")
  b.ring:SetPoint("TOPLEFT", -2, 2); b.ring:SetPoint("BOTTOMRIGHT", 2, -2)
  b.ring:SetBackdrop(T.BACKDROP); b.ring:SetBackdropColor(0, 0, 0, 0); b.ring:SetBackdropBorderColor(T.RGB("amethyst", 1))
  b:SetScript("OnClick", function(s, btn)
    local x = s.cell
    if not x or not x.available then return end
    if btn == "RightButton" then L.SetBossStatus(x.boss.name, x.diff, "open") else L.CycleBossStatus(x.boss.name, x.diff) end
    refresh()
  end)
  b:SetScript("OnEnter", function(s)
    local x = s.cell
    if not x then return end
    GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(x.boss.name .. "  ·  " .. (L.DIFF_NAME[x.diff] or ""), T.RGB("amethyst"))
    GameTooltip:AddLine(x.boss.inst or "", 0.8, 0.8, 0.8)
    if not x.available then
      GameTooltip:AddLine(x.why or "This boss has no loot on this difficulty.", 1, 0.6, 0.6, true)
      GameTooltip:Show(); return
    end
    local st, why = L.BossStatus(x.boss.name, x.diff)
    GameTooltip:AddLine("This week: " .. STATUS[st].text .. (why == "recorded" and " (seen by the add-on)"
      or (why == "lockout" and " (from your lockout)" or (why == "you" and " (set by you)" or ""))), 1, 1, 1)
    if x.blocked then GameTooltip:AddLine("Past your Mythic farm count, so the plan will not send you here.", 1, 0.75, 0.4, true) end
    if x.suggest then GameTooltip:AddLine("Suggested: bonus roll here this week", T.RGB("amethyst")) end
    if #(x.items or {}) > 0 then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine("What you want from here", T.RGB("amethyst"))
      for i, r in ipairs(x.items) do
        if i > 6 then GameTooltip:AddLine("   and " .. (#x.items - 6) .. " more", 0.6, 0.6, 0.6); break end
        -- a kill and a bonus roll at the same difficulty are not the same item level, and on the
        -- last two bosses they are a long way apart, so the cell shows both rather than one number
        local kill = L.DropIlvl and L.DropIlvl(r.it, x.diff) or (r.it.ilvl and r.it.ilvl[x.diff])
        local roll = r.it.bonus and L.RollIlvl and L.RollIlvl(r.it, x.diff)
        -- and each one shows where it ends up after crests, because that is what decides whether it
        -- is an upgrade: a roll that drops at 318 and crests to 334 beats the 321 you are wearing
        local function upto(base)
          if not base then return nil end
          local tr = L.TrackOf and L.TrackOf(base)
          local top = tr and L.TRACK[tr] and L.TRACK[tr].ilvl and L.TRACK[tr].ilvl[6]
          return (top and top > base) and (base .. "\226\134\146" .. top) or tostring(base)
        end
        local k, b = upto(kill), upto(roll)
        local lv = (k and ("kill " .. k) or "") .. ((k and b) and "   " or "") .. (b and ("roll " .. b) or "")
        GameTooltip:AddDoubleLine("   " .. (r.it.name or "?") .. (r.bis and "  BiS" or ""),
          lv ~= "" and lv or tostring(r.route and r.route.ilvl or "?"), 0.85, 0.78, 1, 0.8, 0.8, 0.8)
      end
    else
      GameTooltip:AddLine("Nothing here you want.", 0.7, 0.7, 0.7)
    end
    GameTooltip:AddLine("Click: open > rolled > killed  ·  right-click: open", T.RGB("muted"))
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  gridCells[cellKey(r, c)] = b
  return b
end

local function makeDungeonTile(parent, i)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(GRID_CW, GRID_CH)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  T.Panel(b, "card", 0.85, 0.5)
  b.st = T.IconTex(b, "tick", 11, "emerald"); b.st:SetPoint("LEFT", 6, 0)
  b.t = T.Text(b, "label", 10, "soft", "LEFT"); b.t:SetPoint("LEFT", 20, 0); b.t:SetWidth(GRID_CW - 40)
  b.n = T.Text(b, "display", 10, "topaz", "RIGHT"); b.n:SetPoint("RIGHT", -5, 0)
  b:SetScript("OnClick", function(s, btn)
    local d = s.dungeon
    if not d then return end
    if btn == "RightButton" then L.SetBossStatus(d.name, 0, "open") else L.CycleBossStatus(d.name, 0) end
    refresh()
  end)
  b:SetScript("OnEnter", function(s)
    local d = s.dungeon
    if not d then return end
    GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(d.name, T.RGB("amethyst"))
    local st = L.BossStatus(d.name, 0)
    GameTooltip:AddLine("This week: " .. STATUS[st].text, 1, 1, 1)
    GameTooltip:AddLine((d.wanted or 0) .. " item" .. ((d.wanted or 0) == 1 and "" or "s") .. " you want from the end-of-run chest", 1, 1, 1)
    GameTooltip:AddLine("A Mythic+ completion spends a bonus roll too.", 0.7, 0.7, 0.7, true)
    GameTooltip:AddLine("Click: open > rolled > done  ·  right-click: open", T.RGB("muted"))
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  dungeonTiles[i] = b
  return b
end

---------------------------------------------------------------- flow cards
local function makeCard(parent, i)
  local c = CreateFrame("Button", nil, parent, "BackdropTemplate")
  c:SetSize(CARD_W, CARD_H)
  c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  T.Panel(c, "card", 0.95, 0.6)
  c.icon = T.IconTex(c, "star", 13, "amethyst"); c.icon:SetPoint("TOPLEFT", 8, -8)
  c.title = T.Text(c, "strong", 12, "text"); c.title:SetPoint("TOPLEFT", 26, -7); c.title:SetPoint("RIGHT", -8, 0)
  c.l1 = T.Text(c, "body", 11, "soft"); c.l1:SetPoint("TOPLEFT", 8, -26); c.l1:SetPoint("RIGHT", -8, 0)
  c.l2 = T.Text(c, "body", 11, "amethyst"); c.l2:SetPoint("TOPLEFT", 8, -42); c.l2:SetPoint("RIGHT", -8, 0)
  c.l3 = T.Text(c, "body", 10, "muted"); c.l3:SetPoint("BOTTOMLEFT", 8, 7); c.l3:SetPoint("RIGHT", -8, 0)
  c:SetScript("OnEnter", function(s) if s.tip then GameTooltip:SetOwner(s, "ANCHOR_RIGHT"); s.tip(GameTooltip); GameTooltip:Show() end end)
  c:SetScript("OnLeave", GameTooltip_Hide)
  c:SetScript("OnClick", function(s, btn) if s.click then s.click(btn, s) end end)
  cards[i] = c
  return c
end

local function rollMenu(owner, w, card)
  if not (MenuUtil and MenuUtil.CreateContextMenu) then
    local nxt = card.options[2]; if nxt then L.SetPick(w, card.k, nxt.s.key); refresh() end
    return
  end
  MenuUtil.CreateContextMenu(owner, function(_, root)
    root:CreateTitle(string.format("Week %d, roll %d: roll on", w, card.k))
    for i, o in ipairs(card.options) do
      if i > 10 then break end
      root:CreateRadio(string.format("%s%s  ·  %d%%", o.s.label, o.s.diff and (" (" .. (L.DIFF_NAME[o.s.diff] or "") .. ")") or "", math.floor(o.c * 100 + 0.5)),
        function() return card.choice ~= "skip" and card.choice.s == o.s end,
        function() L.SetPick(w, card.k, o.s.key); refresh() end)
    end
    root:CreateRadio("Keep this roll", function() return card.choice == "skip" end, function() L.SetPick(w, card.k, "skip"); refresh() end)
    root:CreateDivider()
    root:CreateButton("Back to the suggested plan", function() L.ClearPicks(); refresh() end)
  end)
end

---------------------------------------------------------------- build
local function build()
  win = CreateFrame("Frame", "SmilerKeysPlanner", UIParent, "BackdropTemplate")
  win:SetSize(W, H); win:SetPoint("CENTER")
  win:SetFrameStrata("DIALOG"); win:SetToplevel(true); win:SetClampedToScreen(true)
  win:SetMovable(true); win:EnableMouse(true); win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", win.StartMoving); win:SetScript("OnDragStop", win.StopMovingOrSizing)
  T.Panel(win, "void", 0.97, 0.38); T.TopLine(win)
  tinsert(UISpecialFrames, "SmilerKeysPlanner")
  local opts = L.PlanOpts()

  local title = T.Text(win, "label", 14, "amethyst"); title:SetPoint("TOPLEFT", 16, -15); title:SetText("W H E R E   T O   G O")
  win.sub = T.Text(win, "body", 12, "muted"); win.sub:SetPoint("LEFT", title, "RIGHT", 12, 0)
  local close = CreateFrame("Button", nil, win); close:SetSize(22, 22); close:SetPoint("TOPRIGHT", -8, -9)
  close.icon = T.IconTex(close, "close", 13, "muted"); close.icon:SetPoint("CENTER")
  close:SetScript("OnClick", function() win:Hide() end)

  -- row 1: what to show, which ways
  win.scope = T.Segmented(win, { { "bis", "Targets" }, { "wish", "Wishlist" }, { "all", "All upgrades" } },
    function() return opts.scope end, function(k) opts.scope = k; state.offset = 0; refresh() end, 24)
  win.scope:SetPoint("TOPLEFT", 16, -42)
  win.toggles = {
    toggle(win, "Rolls", function() return opts.modes.bonus end, function(v) opts.modes.bonus = v end, 62),
    toggle(win, "Drops", function() return opts.modes.drop end, function(v) opts.modes.drop = v; opts.drops = v end, 62),
    toggle(win, "Vault", function() return opts.modes.vault end, function(v) opts.modes.vault = v end, 58),
    toggle(win, "Craft", function() return opts.modes.other end, function(v) opts.modes.other = v end, 62),
  }
  local prev
  for _, b in ipairs(win.toggles) do
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("LEFT", win.scope, "RIGHT", 16, 0) end
    prev = b
  end
  -- the three steppers live in one row frame pinned to the window's right edge, so the group is
  -- measured first and then placed: no stepper can end up past the edge however wide its label is
  win.syncs = {}
  local srow = CreateFrame("Frame", nil, win)
  srow:SetHeight(26)
  srow:SetPoint("TOPRIGHT", win, "TOPRIGHT", -14, -42)
  win.srow = srow
  local f1, w1, e1 = stepper(srow, "MYTHIC FARM", 0, 0,
    function() return opts.farm end,
    function(d) local n = L.MythicBossCount(); local v = (opts.farm or n) + d; opts.farm = (v >= n) and nil or math.max(0, v) end,
    function(v) local n = L.MythicBossCount(); return (v or n) .. "/" .. n end,
    "Mythic bosses you have on farm. Bosses past this count use Heroic loot and Heroic bonus rolls.")
  win.syncs[#win.syncs + 1] = f1
  local f2, w2, e2 = stepper(srow, "ROLLS NOW", e1, 0,
    function() return opts.rollsNow or L.BonusRolls() end,
    function(d) opts.rollsNow = math.max(0, (opts.rollsNow or L.BonusRolls() or 0) + d) end,
    function(v) return tostring(v or 0) end, "Bonus rolls you can spend this week. Starts from your Nebulous Voidcores.")
  win.syncs[#win.syncs + 1] = f2
  local f3, w3 = stepper(srow, "PER WEEK", e2, 0,
    function() return opts.rollsWeek end, function(d) opts.rollsWeek = math.max(0, math.min(10, opts.rollsWeek + d)) end,
    function(v) return tostring(v) end, "Bonus rolls you earn each week. Unused ones carry over.")
  win.syncs[#win.syncs + 1] = f3
  srow:SetWidth(w1 + w2 + w3 + 40)   -- 20px between each pair, the stepper's default gap

  -- the season grid: difficulty down the side, this season's bosses across the top
  win.mapHead = T.Text(win, "label", 11, "muted"); win.mapHead:SetPoint("TOPLEFT", 16, MAP_Y + 6)
  win.mapHead:SetWidth(W - 32); win.mapHead:SetJustifyH("LEFT"); win.mapHead:SetWordWrap(true)
  -- one line: the window is 1028 wide inside its margins and the grid starts 18px below this
  win.mapHead:SetText("THIS WEEK  ·  click a cell: open > rolled > killed  ·  right-click clears  ·  the number is what you want there")
  win.map = CreateFrame("Frame", nil, win)
  win.map:SetPoint("TOPLEFT", 16, MAP_Y - 20)
  win.map:SetSize(W - 32, 4 * GRID_CH + 3 * GRID_GY + 18)

  -- column headings and one clickable label per difficulty row
  win.colHeads, win.rowHeads = {}, {}
  -- 20 is a ceiling, not an expectation: the draw makes one per boss and hides the rest
  for i = 1, 20 do
    local h = T.Text(win.map, "label", 9, "muted", "LEFT")
    h:SetPoint("TOPLEFT", GRID_LBL + (i - 1) * (GRID_CW + GRID_GX), 0)
    h:SetWidth(GRID_CW); h:Hide()
    win.colHeads[i] = h
  end
  for r, d in ipairs(DIFF_ROWS) do
    local b = T.Button(win.map, d[2], GRID_LBL - 6, GRID_CH, function()
      -- one click sets the whole row: cleared if anything is marked, all killed if none is
      local bosses = L.SeasonBosses()
      local anyMarked = false
      for _, bs in ipairs(bosses) do if bs.diffs[d[1]] and L.BossStatus(bs.name, d[1]) ~= "open" then anyMarked = true end end
      for _, bs in ipairs(bosses) do
        if bs.diffs[d[1]] then L.SetBossStatus(bs.name, d[1], anyMarked and "open" or "killed") end
      end
      refresh()
    end)
    b:SetPoint("TOPLEFT", 0, -(18 + (r - 1) * (GRID_CH + GRID_GY)))
    if b.text then b.text:SetTextColor(T.RGB(d[3])) end
    b:HookScript("OnEnter", function(s)
      GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
      GameTooltip:AddLine(L.DIFF_NAME[d[1]] or d[2], T.RGB(d[3]))
      GameTooltip:AddLine("Click to mark the whole row killed, or to clear it.", 1, 1, 1, true)
      GameTooltip:Show()
    end)
    b:HookScript("OnLeave", GameTooltip_Hide)
    win.rowHeads[r] = b
  end

  -- the Mythic+ strip under the grid
  local dy = MAP_Y - 20 - (4 * GRID_CH + 3 * GRID_GY + 18) - 12
  win.dungeonHead = T.Text(win, "label", 9, "muted", "LEFT")
  win.dungeonHead:SetPoint("TOPLEFT", 16, dy + 2); win.dungeonHead:SetText("MYTHIC+")

  -- one Mythic-farm switch per lair boss, on the free right-hand side of this line. They are not in
  -- the raid's kill order, so the single MYTHIC FARM count cannot speak for them.
  win.lairHead = T.Text(win, "label", 9, "muted", "RIGHT")
  win.lairHead:SetPoint("TOPRIGHT", win, "TOPRIGHT", -16, dy + 2)
  win.lairHead:SetText("LAIRS ON MYTHIC FARM")
  win.lairToggles = {}
  for i = 1, 4 do
    local b = T.Button(win, "", 92, 18, function()
      local nm = win.lairToggles[i] and win.lairToggles[i].boss
      if not nm then return end
      L.SetLairOnFarm(nm, not L.LairOnFarm(nm, opts), opts)
      refresh()
    end)
    -- on the MYTHIC+ heading line, where nothing else sits: the tile row below is clear of it
    b:SetPoint("TOPRIGHT", win, "TOPRIGHT", -16 - (i - 1) * 96, dy + 3)
    function b:Sync()
      local on = self.boss and L.LairOnFarm(self.boss, opts)
      if self.SetBackdropColor then self:SetBackdropColor(T.RGB(on and "amethyst" or "raised", on and 1 or 0.8)) end
      if self.text then self.text:SetTextColor(T.RGB(on and "void" or "muted")) end
    end
    b:HookScript("OnEnter", function(s)
      if not s.boss then return end
      GameTooltip:SetOwner(s, "ANCHOR_TOP")
      GameTooltip:AddLine(s.boss, T.RGB("amethyst"))
      GameTooltip:AddLine(L.LairOnFarm(s.boss, opts) and "On Mythic farm: the plan may send you here on Mythic."
        or "Not on Mythic farm: Mythic loot from here is left out of the plan.", 1, 1, 1, true)
      GameTooltip:Show()
    end)
    b:HookScript("OnLeave", GameTooltip_Hide)
    b:Hide()
    win.lairToggles[i] = b
  end
  win.dungeons = CreateFrame("Frame", nil, win)
  win.dungeons:SetPoint("TOPLEFT", 16, dy - 24); win.dungeons:SetSize(W - 32, GRID_CH)
  win.delve = T.Button(win, "Delves", 86, GRID_CH, function()
    opts.modes.delve = not opts.modes.delve
    refresh()
  end)
  win.delve:SetPoint("TOPLEFT", 16 + GRID_LBL + 8 * (GRID_CW + GRID_GX) + 10, dy - 24)
  function win.delve:Sync()
    local on = opts.modes.delve
    if self.SetBackdropColor then self:SetBackdropColor(T.RGB(on and "amethyst" or "raised", on and 1 or 0.8)) end
    if self.text then self.text:SetTextColor(T.RGB(on and "void" or "muted")) end
  end
  win.delve:HookScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Delves", T.RGB("amethyst"))
    GameTooltip:AddLine("Count Labyrinth armaments and delve loot as a way of getting an item. They are not luck, so they show up as something to go and do rather than a roll.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  win.delve:HookScript("OnLeave", GameTooltip_Hide)

  -- flow (weeks down)
  win.flow = CreateFrame("Frame", nil, win); win.flow:SetPoint("TOPLEFT", 16, FLOW_Y); win.flow:SetSize(FLOW_W, H + FLOW_Y - 36)
  win.flow:SetClipsChildren(true)
  win.flow:EnableMouseWheel(true)
  win.flow:SetScript("OnMouseWheel", function(self, d)
    local maxOff = math.max(0, (state.contentH or 0) - self:GetHeight())
    state.offset = math.max(0, math.min(maxOff, state.offset - d * 48))
    ns.Planner_Refresh(true)
  end)
  win.summary = T.Text(win, "strong", 12, "soft"); win.summary:SetPoint("BOTTOMLEFT", win.flow, "TOPLEFT", 0, 8); win.summary:SetWidth(FLOW_W)
  win.summary:SetWordWrap(true)

  -- right: items
  local div = win:CreateTexture(nil, "ARTWORK"); div:SetColorTexture(T.RGB("edge", 0.25)); div:SetWidth(1)
  div:SetPoint("TOPLEFT", 16 + FLOW_W + 12, FLOW_Y); div:SetPoint("BOTTOMLEFT", 16 + FLOW_W + 12, 36)
  win.side = CreateFrame("Frame", nil, win); win.side:SetPoint("TOPLEFT", 16 + FLOW_W + 24, FLOW_Y); win.side:SetSize(SIDE_W, H + FLOW_Y - 36)
  -- the width is pinned to the column so a longer heading wraps instead of running off the window
  local sh = T.Text(win.side, "label", 11, "muted"); sh:SetPoint("TOPLEFT", 0, 0)
  sh:SetWidth(SIDE_W); sh:SetWordWrap(true); sh:SetText("YOUR ITEMS  ·  chance by week 4")
  win.assume = T.Text(win, "body", 10, "muted"); win.assume:SetPoint("BOTTOMLEFT", 16, 12); win.assume:SetWidth(W - 32); win.assume:SetWordWrap(true)
  win.assume:SetText("A bonus roll gives 1 item from that boss's loot for your spec, all equally likely; one roll per boss each week; Mythic+ completions take rolls too. Weight = QE upgrade % × priority (P1 ×2) × BiS ×1.5. Items you own at the target level or higher drop out. Right-click a roll card to choose another boss; later weeks re-plan.")
  win:SetScript("OnShow", function() L._lock = nil; if not L.items then L.Refresh(true) end; ns.Planner_Refresh() end)
  win:Hide()
end

---------------------------------------------------------------- draw
local function layoutFlow(sim, opts)
  -- y walks DOWN the flow in negative offsets from the frame's top-left, so a positive scroll
  -- offset has to LIFT the content (start above the top edge) to reveal what is further down.
  -- Starting at -offset pushed it the other way, which is why the wheel did nothing useful.
  local y = state.offset
  local ci, hi = 0, 0
  local function head(text, right)
    hi = hi + 1
    local h = heads[hi]
    if not h then
      h = CreateFrame("Frame", nil, win.flow); h:SetSize(FLOW_W, 22)
      h.bg = h:CreateTexture(nil, "BACKGROUND"); h.bg:SetAllPoints(); h.bg:SetColorTexture(T.RGB("raised", 0.9))
      h.t = T.Text(h, "label", 12, "amethyst"); h.t:SetPoint("LEFT", 8, 0)
      h.r = T.Text(h, "body", 11, "soft", "RIGHT"); h.r:SetPoint("RIGHT", -8, 0)
      -- spine: the line running down from one week to the next
      heads[hi] = h
    end
    h:ClearAllPoints(); h:SetPoint("TOPLEFT", 0, y); h.t:SetText(text); h.r:SetText(right or ""); h:Show()
    y = y - 28
  end
  local col = 0
  local function card(fill)
    ci = ci + 1
    local c = cards[ci] or makeCard(win.flow, ci)
    if col == 4 then col = 0; y = y - CARD_H - CARD_GAP end
    c:ClearAllPoints(); c:SetPoint("TOPLEFT", 12 + col * (CARD_W + CARD_GAP), y)
    col = col + 1
    c.tip, c.click = nil, nil
    fill(c)
    c:Show()
  end
  local function endRow() if col > 0 then y = y - CARD_H - CARD_GAP - 6; col = 0 end end

  -- sure things first: crafting, vault, Labyrinth
  if #sim.sure > 0 then
    head("ANY WEEK  ·  no luck needed", #sim.sure .. " item" .. (#sim.sure == 1 and "" or "s"))
    for _, r in ipairs(sim.sure) do
      card(function(c)
        T.Icon(c.icon, "tick"); if T.hasCore then c.icon:SetVertexColor(T.RGB("emerald")) end
        c:SetBackdropBorderColor(T.RGB("emerald", 0.6))
        c.title:SetText((r.route and r.route.label or "Get") .. "")
        c.l1:SetText(shortName(r.it.name) .. "  ·  " .. (L.slotByKey[r.it.slot] and L.slotByKey[r.it.slot].label or ""))
        c.l2:SetText(itemTag(r))
        c.l3:SetText(r.route and ("item level " .. (r.route.max or r.route.ilvl or "?")) or "")
        c.tip = function(tt) local l = L.LinkFor(r.it, 16, "drop"); if l then tt:SetHyperlink(l) else tt:AddLine(r.it.name or "?") end
          tt:AddLine(" "); tt:AddLine("Weight: " .. string.format("%.2f", r.w) .. "  (" .. (itemTag(r) ~= "" and itemTag(r) or "no QE score") .. ")", T.RGB("amethyst")) end
      end)
    end
    endRow()
  end
  for w, wk in ipairs(sim.weeks) do
    head(string.format("WEEK %d%s", w, w == 1 and "  ·  this week" or ""),
      string.format("%d roll%s · %.1f items expected · %d%% of your upgrade value", wk.n, wk.n == 1 and "" or "s", wk.expected, math.floor(wk.share * 100 + 0.5)))
    for _, rc in ipairs(wk.rolls) do
      card(function(c)
        local skip = rc.choice == "skip"
        T.Icon(c.icon, "star"); if T.hasCore then c.icon:SetVertexColor(T.RGB(skip and "muted" or "amethyst")) end
        c:SetBackdropBorderColor(T.RGB(skip and "edge" or "amethyst", skip and 0.4 or (rc.forced and 1 or 0.8)))
        if skip then
          c.title:SetText("Keep this roll"); c.l1:SetText("saved for a later week"); c.l2:SetText(""); c.l3:SetText("right-click to choose a boss")
        else
          local s = rc.choice.s
          c.title:SetText("Roll · " .. shortName(s.label) .. (s.diff and (" (" .. (L.DIFF_NAME[s.diff] or ""):sub(1, 1) .. ")") or ""))
          if s.n == 1 and #rc.why > 0 then
            c.l1:SetText("|cff00e676guaranteed|r  ·  one item left in the pool")
          else
            c.l1:SetText(string.format("%d wanted of %d%s  ·  %d%% for one", #rc.why, s.n,
              s.poolTracked and " left" or "", math.floor(rc.chance * 100 + 0.5)))
          end
          local top = rc.why[1]
          c.l2:SetText(top and (shortName(top.it.name) .. "  " .. itemTag(top)) or "")
          local alt = rc.options[2]
          c.l3:SetText((rc.forced and "your choice  ·  " or "") .. (alt and string.format("or %s %d%%  ·  right-click", shortName(alt.s.label), math.floor(alt.c * 100 + 0.5)) or "right-click for options"))
        end
        c.tip = function(tt)
          if skip then tt:AddLine("Keep this roll", T.RGB("amethyst")); tt:AddLine("Not spent this week; it carries over.", 1, 1, 1); return end
          local s = rc.choice.s
          tt:AddLine(s.label .. (s.diff and ("  ·  " .. (L.DIFF_NAME[s.diff] or "")) or ""), T.RGB("amethyst"))
          if s.n == 1 then
            tt:AddLine("One item left in this pool, so the next roll here is guaranteed to be it.", 0, 0.9, 0.46, true)
          else
            tt:AddLine(string.format("A roll here gives 1 of %d items your spec can still receive%s. %d%% that it's one you want.",
              s.n, s.poolTracked and " (what you have already rolled is ticked off in /sk rolls)" or "", math.floor(rc.chance * 100 + 0.5)), 1, 1, 1, true)
          end
          tt:AddLine(" ")
          tt:AddLine("Why here", T.RGB("amethyst"))
          for i, r in ipairs(rc.why) do
            if i > 8 then break end
            tt:AddDoubleLine(shortName(r.it.name), string.format("%s  ·  %d%% still needed", itemTag(r) ~= "" and itemTag(r) or "upgrade", math.floor(r.p * 100 + 0.5)), 1, 1, 1, 0.8, 0.8, 0.8)
          end
          if #rc.options > 1 then
            tt:AddLine(" "); tt:AddLine("Other options", T.RGB("amethyst"))
            for i = 2, math.min(4, #rc.options) do local o = rc.options[i]
              tt:AddDoubleLine(o.s.label, string.format("%d%%  ·  value %.2f vs %.2f", math.floor(o.c * 100 + 0.5), o.g, rc.options[1].g), 1, 1, 1, 0.8, 0.8, 0.8) end
          end
          tt:AddLine("Right-click to roll somewhere else; the weeks after re-plan.", T.RGB("muted"))
        end
        c.click = function(btn, self) if btn == "RightButton" or btn == "LeftButton" then rollMenu(self, w, rc) end end
      end)
    end
    if #wk.kills > 0 then
      card(function(c)
        T.Icon(c.icon, "tick"); if T.hasCore then c.icon:SetVertexColor(T.RGB("soft")) end
        c:SetBackdropBorderColor(T.RGB("edge", 0.5))
        c.title:SetText("Kills · " .. #wk.kills .. " boss" .. (#wk.kills == 1 and "" or "es"))
        c.l1:SetText(string.format("your share: ~%.2f wanted items", wk.drops))
        local names = {}
        for i, k in ipairs(wk.kills) do if i <= 3 then names[#names + 1] = shortName(k.s.label) end end
        c.l2:SetText(table.concat(names, ", ") .. (#wk.kills > 3 and "…" or ""))
        c.l3:SetText(string.format("%d%% chance per kill of an item", opts.dropPct))
        c.tip = function(tt)
          tt:AddLine("Kills this week", T.RGB("amethyst"))
          -- name the items, not just the boss: "why is it sending me here" should be answerable
          -- from the tooltip rather than by guessing
          for _, k in ipairs(wk.kills) do
            tt:AddDoubleLine(k.s.label .. (k.s.diff and ("  ·  " .. (L.DIFF_NAME[k.s.diff] or "")) or ""),
              string.format("~%.2f items", k.exp), 1, 1, 1, 0.8, 0.8, 0.8)
            local n = 0
            for _, r in ipairs(k.s.items) do
              if r.p > 0.001 and n < 4 then
                n = n + 1
                tt:AddLine("   " .. (r.it.name or "?") .. "  " .. (r.route and r.route.ilvl or "?")
                  .. (r.bis and "  BiS" or ""), 0.65, 0.6, 0.78)
              end
            end
            if n == 0 then tt:AddLine("   nothing you want - tell me, this is a bug", 1, 0.4, 0.4) end
          end
          tt:AddLine(string.format("Group loot: %d%% chance a kill gives you an item, any from the table. Change with the drop setting.", opts.dropPct), 0.7, 0.7, 0.7, true)
        end
      end)
    end
    if wk.unused > 0 then
      card(function(c)
        T.Icon(c.icon, "star"); if T.hasCore then c.icon:SetVertexColor(T.RGB("muted")) end
        c:SetBackdropBorderColor(T.RGB("edge", 0.3))
        c.title:SetText(wk.unused .. " roll" .. (wk.unused == 1 and "" or "s") .. " left over")
        c.l1:SetText(w == 1 and "nowhere left this week" or "nothing worth rolling on"); c.l2:SetText("carried to next week"); c.l3:SetText("")
      end)
    end
    if #wk.rolls == 0 and #wk.kills == 0 and wk.unused == 0 then
      card(function(c) c.title:SetText("Nothing to do"); c.l1:SetText(""); c.l2:SetText(""); c.l3:SetText(""); c:SetBackdropBorderColor(T.RGB("edge", 0.3)) end)
    end
    endRow()
    if wk.share >= 0.995 then break end
  end
  if #sim.owned > 0 then
    -- your picks that the plan deliberately left out, with what is standing in the way. Highest
    -- priority first: a priority-1 pick being parked is the most useful thing on this screen.
    local parked = {}
    for _, r in ipairs(sim.owned) do parked[#parked + 1] = r end
    table.sort(parked, function(a, b) return (a.prio or 99) < (b.prio or 99) end)
    head("NOT IN THE PLAN", #parked .. " item" .. (#parked == 1 and "" or "s") .. " you want that nothing this week improves")
    for _, r in ipairs(parked) do
      card(function(c)
        T.Icon(c.icon, "tick"); if T.hasCore then c.icon:SetVertexColor(T.RGB(r.prio and r.prio <= 3 and "topaz" or "emerald")) end
        c:SetBackdropBorderColor(T.RGB(r.prio and r.prio <= 3 and "topaz" or "emerald", 0.4))
        c.title:SetText(shortName(r.it.name))
        c.l1:SetText(r.held and "held for its best version"
          or (r.rolledOut and "already rolled there this table" or ("you have it at " .. (r.ownedAt or "?"))))
        c.l2:SetText(r.why or itemTag(r))
        c.l3:SetText(itemTag(r))
        c.tip = function(tt)
          tt:AddLine(r.it.name or "?", T.RGB("amethyst"))
          tt:AddLine(r.held and "This is a BiS pick, so the plan only sends you for the best version of it. Make it the slot's target instead if you would take a lesser one."
            or (r.rolledOut and "You have already rolled this off the table for this spec and difficulty."
            or ("You have it at " .. (r.ownedAt or "?") .. ", so nothing you can reach this week is an upgrade.")), 1, 1, 1, true)
          if r.why then tt:AddLine(r.why, 0.85, 0.78, 1, true) end
          tt:AddLine("/sk why " .. (r.it.id or "") .. " prints the whole reason in chat.", T.RGB("muted"))
        end
      end)
    end
    endRow()
  end
  for i = ci + 1, #cards do cards[i]:Hide() end
  for i = hi + 1, #heads do heads[i]:Hide() end
  -- y ends at (offset - total height), so the height is what it travelled
  state.contentH = -y + state.offset
end

function ns.Planner_Refresh(scrollOnly)
  if not win or not win:IsShown() then return end
  local opts = L.PlanOpts()
  if not L.items then win.summary:SetText("Reading the loot tables…"); return end
  if not scrollOnly or not state.sim then
    state.sim = L.Simulate(opts)
  end
  local sim = state.sim
  state.offset = math.max(0, math.min(state.offset, math.max(0, (state.contentH or 0) - win.flow:GetHeight())))
  -- controls
  if win.scope.Sync then win.scope:Sync() end
  for _, b in ipairs(win.toggles) do b:Sync() end
  for _, f in ipairs(win.syncs) do f() end
  win.sub:SetText(opts.scope == "bis" and "your targets, BiS and alternatives" or (opts.scope == "all" and "every upgrade" or "your wishlist"))
  local rolls = sim.rollsNow or 0
  if #sim.items == 0 then
    win.summary:SetText(string.format("%d bonus roll%s now. Nothing left to luck into with these settings.", rolls, rolls == 1 and "" or "s"))
  else
    win.summary:SetText(string.format("%d bonus roll%s now, %d a week. %d item%s down to luck: half your upgrade value %s, 90%% %s.",
      rolls, rolls == 1 and "" or "s", opts.rollsWeek, #sim.items, #sim.items == 1 and "" or "s",
      sim.w50 and ("by week " .. sim.w50) or ("not in " .. opts.weeks .. " weeks"), sim.w90 and ("by week " .. sim.w90) or ("not in " .. opts.weeks .. " weeks")))
  end
  ---------------------------------------------------------------- the season grid
  -- what the plan wants from each boss at each difficulty, and where it is sending you this week
  local suggest, byBossDiff, byDungeon = {}, {}, {}
  local wk1 = sim.weeks[1]
  for _, rc in ipairs(wk1 and wk1.rolls or {}) do
    if rc.choice ~= "skip" and rc.choice.s.encName then
      suggest[rc.choice.s.encName:lower() .. ":" .. tostring(rc.choice.s.diff)] = true
    end
  end
  for _, s in ipairs(sim.sources) do
    if s.encName and s.encName ~= "" then
      byBossDiff[s.encName:lower() .. ":" .. tostring(s.diff)] = s.items
    elseif s.inst then
      byDungeon[s.inst:lower()] = s.items
    end
  end

  local bosses = L.SeasonBosses()
  local farm = opts.farm
  local lastInst
  -- the columns are sized to fit the window, never the other way round: a season with more bosses
  -- than expected makes the cells narrower instead of pushing the grid off the right-hand edge
  local nb = #bosses
  local gaps = 0
  do
    local li
    for _, b in ipairs(bosses) do if li and b.inst ~= li then gaps = gaps + 1 end; li = b.inst end
  end
  local avail = (W - 32) - GRID_LBL - gaps * 10 - math.max(0, nb - 1) * GRID_GX
  local cw = math.max(40, math.min(GRID_CW, math.floor(avail / math.max(1, nb))))
  for r, d in ipairs(DIFF_ROWS) do
    local diff = d[1]
    local x, lastI = GRID_LBL, nil
    for c, b in ipairs(bosses) do
      if lastI and b.inst ~= lastI then x = x + 10 end       -- a gap between the raid and the lairs
      lastI = b.inst
      local cell = gridCells[cellKey(r, c)] or makeCell(win.map, r, c)
      cell:SetWidth(cw)
      cell.t:SetWidth(math.max(10, cw - 40))
      cell:ClearAllPoints()
      cell:SetPoint("TOPLEFT", x, -(18 + (r - 1) * (GRID_CH + GRID_GY)))
      x = x + cw + GRID_GX
      if r == 1 then
        local h = win.colHeads[c]
        if h then
          h:ClearAllPoints(); h:SetPoint("TOPLEFT", x - cw - GRID_GX, 0)
          h:SetWidth(cw)
          h:SetText(tinyName(b.name, cw)); h:Show()
        end
        if b.inst ~= lastInst then lastInst = b.inst end
      end
      local items = byBossDiff[b.name:lower() .. ":" .. tostring(diff)] or {}
      local available = b.diffs[diff] and true or false
      local blocked = available and diff == 16 and (
        (b.lair and not L.LairOnFarm(b.name, opts))
        or (not b.lair and farm and (b.index or 0) > farm))
      cell.cell = { boss = b, diff = diff, available = available, blocked = blocked, items = items,
                    suggest = suggest[b.name:lower() .. ":" .. tostring(diff)] or false,
                    why = (not available) and "This boss has no loot on this difficulty." or nil }
      if not available then
        cell.st:Hide()
        cell.t:SetText("-"); cell.t:SetTextColor(T.RGB("edge", 0.8))
        cell.n:SetText("")
        cell:SetBackdropColor(T.RGB("card", 0.3)); cell:SetBackdropBorderColor(T.RGB("edge", 0.15))
        cell:SetAlpha(0.45)
        cell.ring:Hide()
      else
        local st = L.BossStatus(b.name, diff)
        local S = STATUS[st]
        cell.st:SetShown(S.icon ~= nil)
        if S.icon then T.Icon(cell.st, S.icon); if T.hasCore then cell.st:SetVertexColor(T.RGB(S.color)) end end
        cell.t:SetText(S.text); cell.t:SetTextColor(T.RGB(S.color))
        cell.n:SetText(#items > 0 and tostring(#items) or "")
        cell:SetBackdropColor(T.RGB("card", st == "open" and 0.85 or 0.45))
        cell:SetBackdropBorderColor(T.RGB(d[3], blocked and 0.25 or 0.65))
        cell:SetAlpha(blocked and 0.5 or 1)
        cell.ring:SetShown(cell.cell.suggest)
      end
      cell:Show()
    end
    for c = #bosses + 1, (state.gridCols or 0) do
      local cell = gridCells[cellKey(r, c)]
      if cell then cell:Hide() end
    end
  end
  for c = #bosses + 1, math.max(state.gridCols or 0, 20) do if win.colHeads[c] then win.colHeads[c]:Hide() end end
  state.gridCols = math.max(state.gridCols or 0, #bosses)   -- so a shorter list hides what it leaves behind
  for _, b in ipairs(win.rowHeads or {}) do if b.Sync then b:Sync() end end
  local lairs = {}
  for _, b in ipairs(bosses) do if b.lair then lairs[#lairs + 1] = b end end
  for i, tb in ipairs(win.lairToggles or {}) do
    local b = lairs[i]
    tb.boss = b and b.name or nil
    if b then tb:SetLabel(tinyName(b.name, 92)); tb:Sync(); tb:Show() else tb:Hide() end
  end
  if win.lairHead then win.lairHead:SetShown(#lairs > 0) end

  -- the Mythic+ strip
  local dungeons = L.SeasonDungeons()
  for i, dg in ipairs(dungeons) do
    if i > 8 then break end
    local t = dungeonTiles[i] or makeDungeonTile(win.dungeons, i)
    local items = byDungeon[(dg.name or ""):lower()] or {}
    dg.wanted = #items
    t.dungeon = dg
    t:ClearAllPoints(); t:SetPoint("TOPLEFT", GRID_LBL + (i - 1) * (GRID_CW + GRID_GX), 0)
    local st = L.BossStatus(dg.name, 0)
    local S = STATUS[st]
    t.st:SetShown(S.icon ~= nil)
    if S.icon then T.Icon(t.st, S.icon); if T.hasCore then t.st:SetVertexColor(T.RGB(S.color)) end end
    t.t:SetText(dg.short or tinyName(dg.name)); t.t:SetTextColor(T.RGB(st == "open" and "soft" or S.color))
    t.n:SetText(#items > 0 and tostring(#items) or "")
    t:SetBackdropColor(T.RGB("card", st == "open" and 0.85 or 0.45))
    t:SetBackdropBorderColor(T.RGB("emerald", 0.45))
    t:Show()
  end
  for i = math.min(#dungeons, 8) + 1, #dungeonTiles do dungeonTiles[i]:Hide() end
  if win.delve and win.delve.Sync then win.delve:Sync() end
  -- flow
  layoutFlow(sim, opts)
  -- items on the right
  local y = -20
  local all = {}
  for _, r in ipairs(sim.items) do all[#all + 1] = r end
  for i, r in ipairs(all) do
    local b = bars[i]
    if not b then
      b = CreateFrame("Frame", nil, win.side); b:SetSize(SIDE_W, 30)
      b.t = T.Text(b, "body", 11, "text"); b.t:SetPoint("TOPLEFT", 0, 0); b.t:SetPoint("RIGHT", -60, 0)
      b.v = T.Text(b, "display", 11, "soft", "RIGHT"); b.v:SetPoint("TOPRIGHT", 0, 0)
      b.bg = b:CreateTexture(nil, "ARTWORK"); b.bg:SetPoint("TOPLEFT", 0, -16); b.bg:SetSize(SIDE_W, 6); b.bg:SetColorTexture(T.RGB("card", 1))
      b.fill = b:CreateTexture(nil, "ARTWORK", nil, 1); b.fill:SetPoint("TOPLEFT", b.bg, "TOPLEFT"); b.fill:SetHeight(6)
      b.when = T.Text(b, "body", 10, "muted"); b.when:SetPoint("TOPLEFT", 0, -23)
      b:EnableMouse(true)
      b:SetScript("OnEnter", function(s) if not s.r then return end
        local l = L.LinkFor(s.r.it, 16, "drop")
        GameTooltip:SetOwner(s, "ANCHOR_LEFT")
        if l then GameTooltip:SetHyperlink(l) else GameTooltip:AddLine(s.r.it.name or "?") end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format("Weight %.2f  ·  %s", s.r.w, itemTag(s.r) ~= "" and itemTag(s.r) or "no QE score (0.2)"), T.RGB("amethyst"))
        GameTooltip:AddLine((s.r.route and s.r.route.label or "") .. "  ·  " .. L.SourceText(s.r.it), 0.8, 0.8, 0.8)
        for w = 1, 6 do if s.r.pw[w] then GameTooltip:AddDoubleLine("Week " .. w, math.floor(s.r.pw[w] * 100 + 0.5) .. "%", 1, 1, 1, 1, 1, 1) end end
        GameTooltip:Show() end)
      b:SetScript("OnLeave", GameTooltip_Hide)
      bars[i] = b
    end
    b.r = r
    b:ClearAllPoints(); b:SetPoint("TOPLEFT", 0, y)
    local p4 = r.pw[4] or r.pw[#r.pw] or 0
    b.t:SetText(itemTag(r):match("^P%d+") and (itemTag(r):match("^(P%d+)") .. "  " .. shortName(r.it.name)) or shortName(r.it.name))
    b.v:SetText(math.floor(p4 * 100 + 0.5) .. "%")
    b.fill:SetWidth(math.max(1, SIDE_W * p4)); b.fill:SetColorTexture(T.RGB(p4 >= 0.9 and "emerald" or "amethyst", 0.9))
    b.when:SetText(r.w50 and (string.format("50%% week %d", r.w50) .. (r.w90 and string.format(" · 90%% week %d", r.w90) or "")) or "unlikely soon")
    b:Show()
    y = y - 36
    if -y > win.side:GetHeight() - 30 then
      for j = i + 1, #bars do bars[j]:Hide() end
      break
    end
  end
  for j = #all + 1, #bars do bars[j]:Hide() end
end

function ns.PlannerOpen()
  if not win then build() end
  win:Show(); win:Raise()
end

---------------------------------------------------------------- /sk why
-- Walks the exact chain the planner walks and says, at each gate, whether the item survived it and
-- why. Written because three separate "it isn't showing my X" reports each turned out to be a
-- different gate, and reading the code to guess which one is slower and less reliable than asking.
function ns.WhyReport(arg)
  local q = (arg or ""):match("^%s*(.-)%s*$")
  if q == "" then ns.Print("Usage: /sk why <item name or id>  – e.g. /sk why 271500"); return end
  local P = ns.Print

  -- find it: by id, then by name across the scan and the wishlist
  local id = tonumber(q)
  local it = id and L.ItemByID(id)
  if not it then
    local want = q:lower()
    for _, x in ipairs(L.items or {}) do
      if (x.name or ""):lower():find(want, 1, true) then it = x; break end
    end
    if not it then
      for slot, list in pairs(L.Wish()) do
        for _, e in ipairs(list) do
          if (e.name or ""):lower():find(want, 1, true) then it = L.ItemByID(e.id); break end
        end
        if it then break end
      end
    end
  end
  if not it then P("No item matches '" .. q .. "'. Try the item ID."); return end

  local opts = L.PlanOpts()
  P(("|cffffffff%s|r (%d)  ·  %s"):format(it.name or "?", it.id or 0, it.slot or "?"))
  P(("  from: %s%s%s"):format(it.encName and it.encName ~= "" and (it.encName .. " · ") or "",
    it.inst or "?", it.raid and (" · boss " .. (it.encIndex or 0) .. " of " .. (it.nEnc or 0)) or ""))

  -- 1. is it in scope
  local onWish, wishSlot = false, nil
  for slot, list in pairs(L.Wish()) do
    for _, e in ipairs(list) do if e.id == it.id then onWish, wishSlot = true, slot end end
  end
  local pick, pickSlot = L.PickKindOf(it.id)
  local bis = L.IsBiS(it.id)
  P(("  wishlist: %s   BiS star: %s   pick: %s   priority: %s"):format(
    onWish and ("yes (" .. wishSlot .. ")") or "|cffff6666no|r", bis and "yes" or "no",
    pick and (pick .. " for " .. (pickSlot or "?")) or "none", tostring(L.Prio and L.Prio(it.id) or "-")))
  local inScope
  if opts.scope == "all" then inScope = true
  elseif opts.scope == "bis" then inScope = bis or (pick ~= nil)
  else inScope = onWish end
  P(("  scope is '%s' -> %s"):format(opts.scope, inScope and "|cff00e676in scope|r" or "|cffff6666OUT: the plan never looks at it|r"))
  if not inScope then return end

  -- 2. is the whole slot marked done
  local done = L.slotByKey[it.slot] and it.slot ~= "emb" and it.slot ~= "other" and L.SlotState(it.slot)
  P(("  slot '%s' marked finished: %s"):format(it.slot or "?", done and "|cffff6666YES: the whole slot is skipped|r" or "no"))
  if done then return end

  -- 3. the routes, and which the planner would take
  local own = L.OwnedLevels()
  local have = own[it.id]
  P(("  you own it at: %s"):format(have and tostring(have) or "not owned"))
  local best, bestWhy
  for _, r in ipairs(L.Routes(it)) do
    local m = opts.modes or {}
    local kind = (r.kind == "delve" and "delve") or (r.kind == "crafted" and "other")
      or (r.mode == "bonus" and "bonus") or (r.mode == "vault" and "vault") or "drop"
    local why
    if not m[kind] then why = "the " .. kind .. " switch is off"
    elseif it.raid and it.lair and r.diff == 16 and not L.LairOnFarm(it.encName, opts) then
      why = "Mythic, and this lair is switched off in your Mythic farm"
    elseif it.raid and not it.lair and r.diff == 16 and opts.farm and (it.encIndex or 0) > opts.farm then
      why = "Mythic, and this boss is past your farm count of " .. opts.farm
    elseif have and (r.max or r.ilvl or 0) <= have then
      why = "tops out at " .. (r.max or r.ilvl or 0) .. ", not above the " .. have .. " you have"
    end
    if why then
      P(("    |cff888888x %s  %s -> %s|r"):format(r.label or "?", tostring(r.ilvl or "?"), why))
    else
      local mark = ""
      if not best or (r.max or r.ilvl or 0) > (best.max or best.ilvl or 0)
         or ((r.max or 0) == (best.max or 0) and (r.ilvl or 0) > (best.ilvl or 0)) then best, bestWhy = r, kind; mark = "  <- best" end
      P(("    |cff00e676v %s  ilvl %s, tops out %s|r%s"):format(r.label or "?", tostring(r.ilvl or "?"), tostring(r.max or "?"), mark))
    end
  end
  if not best then P("  |cffff6666No way to get it is allowed, so it is not in the plan.|r"); return end
  P(("  planner takes: |cffffffff%s|r (%s), item level %s"):format(best.label or "?", bestWhy, tostring(best.ilvl or "?")))

  -- 4. the gates inside the simulation
  local diff = it.raid and best.diff or nil
  if L.IsRolled and bestWhy == "bonus" then
    local src = it.raid and { enc = it.enc, name = it.encName, boss = it.encName, raid = true } or { instID = it.instID, name = it.inst }
    local okR, got = pcall(L.IsRolled, src, { id = it.id, name = it.name }, nil, diff or 15)
    if okR and got then
      P("  |cffff6666Ticked off in /sk rolls for this spec and difficulty, so a roll there cannot give it again.|r"); return
    end
    P("  not ticked off in /sk rolls")
  end
  local need = best.max or best.ilvl or 0
  if have and have >= need then
    P(("  |cffff6666Parked: you have it at %d and this way tops out at %d. It shows under NOT IN THE PLAN.|r"):format(have, need))
    P("  " .. parkedReason(it, have, opts))
    return
  end
  if have then
    P(("  |cff00e676Upgrade: drops at %d, crests to %d, against the %d you have.|r"):format(best.ilvl or 0, need, have))
  end
  P("  |cff00e676It should be in the plan.|r If it is not, tell me and paste this.")
end
