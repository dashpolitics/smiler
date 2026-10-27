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
  scope = "wish", modes = { bonus = true, drop = true, vault = false, other = true },
  farm = nil,            -- Mythic bosses on farm (nil = all)
  rollsNow = nil,        -- bonus rolls you have now (nil = read from your currency)
  rollsWeek = 2,         -- bonus rolls you get each week
  drops = true,          -- count your share of raid drops
  dropPct = 15,          -- chance a boss kill gives *you* an item (group loot)
  weeks = 12,
}
function L.PlanOpts()
  local s = ns.db.settings
  s.planner = s.planner or {}
  local o = s.planner
  for k, v in pairs(DEFAULTS) do
    if o[k] == nil then o[k] = type(v) == "table" and { bonus = v.bonus, drop = v.drop, vault = v.vault, other = v.other } or v end
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
  local id = weekID()
  if not s.planWeek or s.planWeek.week ~= id then s.planWeek = { week = id, status = {}, rolls = {}, picks = {} } end
  local w = s.planWeek
  w.status = w.status or {}; w.rolls = w.rolls or {}; w.picks = w.picks or {}
  return w
end
L.WeekState = weekState

-- status of a boss this week: "rolled", "killed" or "open" (your click wins, then a recorded roll, then the lockout)
function L.BossStatus(name, diff)
  local key = (name or ""):lower()
  local w = weekState()
  if w.status[key] then return w.status[key], "you" end
  for _, r in ipairs(w.rolls) do if r.boss == key then return "rolled", "recorded" end end
  L._lock = L._lock or L.KilledThisWeek()
  if L._lock[key .. ":" .. tostring(diff or 16)] then return "killed", "lockout" end
  return "open"
end
function L.CycleBossStatus(name, diff)
  local key = (name or ""):lower()
  local cur = L.BossStatus(name, diff)
  local nxt = (cur == "open" and "rolled") or (cur == "rolled" and "killed") or "open"
  weekState().status[key] = nxt
end
-- kept for older callers
function L.IsKilledThisWeek(key) local name, d = key:match("^(.-):(%d+)$"); return L.BossStatus(name or key, tonumber(d)) ~= "open" end
function L.SetKilledThisWeek(key, v) local name = key:match("^(.-):%d+$") or key; weekState().status[name] = v and "killed" or "open" end

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
      -- you own it already: at the level this way gives, or on the same track or better (the rest is crests)
      local need = x.route and (x.route.ilvl or 0) or 0
      local ol = own[it.id]
      local ot = ol and L.TrackOf(ol)
      local rt = x.route and x.route.track
      if ol and (ol >= need or (ot and rt and L.TRACK[ot] and L.TRACK[rt] and L.TRACK[ot].order >= L.TRACK[rt].order)) then
        r.ownedAt = own[it.id]; ownedList[#ownedList + 1] = r
      elseif x.kind == "bonus" or (x.kind == "drop" and it.raid) or (opts.modes.bonus and it.bonus and not it.crafted and not it.delve) then
        local key = it.raid and ("r" .. (it.enc or 0)) or ("d" .. tostring(it.instID))
        local s = sources[key]
        if not s then
          local diff = it.raid and bossDiff(it, opts) or nil
          s = { key = key, label = it.raid and (it.encName ~= "" and it.encName or g.label) or (it.inst or g.label), inst = it.inst,
                raid = it.raid, lair = it.lair, n = tableSize(it), items = {}, diff = diff, encName = it.encName,
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
local MAP_Y, FLOW_Y = -78, -168
local FLOW_W, SIDE_W = 760, 250
local CARD_W, CARD_H, CARD_GAP = 182, 78, 8
local win
local cards, heads, tiles, bars = {}, {}, {}, {}
local state = { offset = 0 }

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

local function toggle(parent, label, get, set, w)
  local b = T.Button(parent, label, w or 100, 24, function() set(not get()); refresh() end)
  function b:Sync()
    local on = get()
    if self.SetBackdropColor then self:SetBackdropColor(T.RGB(on and "amethyst" or "raised", on and 1 or 0.8)) end
    if self.text then self.text:SetTextColor(T.RGB(on and "void" or "muted")) end
  end
  return b
end

local function stepper(parent, label, x, y, get, set, fmt, tip)
  local l = T.Text(parent, "label", 11, "muted"); l:SetPoint("TOPLEFT", x, y - 6); l:SetText(label)
  local lw = math.max(60, math.ceil(l:GetStringWidth() or 60) + 8)
  local minus = T.Button(parent, "–", 22, 22, function() set(-1); refresh() end)
  minus:SetPoint("TOPLEFT", x + lw, y)
  local v = T.Text(parent, "display", 14, "text", "CENTER"); v:SetPoint("LEFT", minus, "RIGHT", 2, 0); v:SetWidth(44)
  local plus = T.Button(parent, "+", 22, 22, function() set(1); refresh() end)
  plus:SetPoint("LEFT", v, "RIGHT", 2, 0)
  if tip then
    for _, f in ipairs({ minus, plus }) do
      f:HookScript("OnEnter", function(s) GameTooltip:SetOwner(s, "ANCHOR_TOP"); GameTooltip:AddLine(label, T.RGB("amethyst")); GameTooltip:AddLine(tip, 1, 1, 1, true); GameTooltip:Show() end)
      f:HookScript("OnLeave", GameTooltip_Hide)
    end
  end
  return function() v:SetText(fmt(get())) end, lw + 22 + 48 + 22
end

---------------------------------------------------------------- boss map tiles
local STATUS = {
  open    = { icon = nil,     text = "open",   color = "soft" },
  rolled  = { icon = "star",  text = "rolled", color = "emerald" },
  killed  = { icon = "tick",  text = "killed", color = "muted" },
}
local function makeTile(parent, i)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(64, 52)
  T.Panel(b, "card", 0.9, 0.6)
  b.tex = b:CreateTexture(nil, "ARTWORK"); b.tex:SetPoint("TOPLEFT", 1, -1); b.tex:SetSize(62, 31)
  b.n = T.Text(b, "display", 11, "text", "RIGHT", "OUTLINE"); b.n:SetPoint("TOPRIGHT", -3, -3)
  b.st = T.IconTex(b, "star", 12, "emerald"); b.st:SetPoint("TOPLEFT", 3, -3)
  b.t = T.Text(b, "label", 10, "soft", "CENTER"); b.t:SetPoint("BOTTOM", 0, 4); b.t:SetWidth(62)
  b.ring = CreateFrame("Frame", nil, b, "BackdropTemplate"); b.ring:SetPoint("TOPLEFT", -2, 2); b.ring:SetPoint("BOTTOMRIGHT", 2, -2)
  b.ring:SetBackdrop(T.BACKDROP); b.ring:SetBackdropColor(0, 0, 0, 0); b.ring:SetBackdropBorderColor(T.RGB("amethyst", 1))
  b:SetScript("OnClick", function(s) if s.boss then L.CycleBossStatus(s.boss.name, s.boss.diff); refresh() end end)
  b:SetScript("OnEnter", function(s)
    local x = s.boss
    if not x then return end
    local st, why = L.BossStatus(x.name, x.diff)
    GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(x.name, T.RGB("amethyst"))
    GameTooltip:AddLine(x.inst .. "  ·  " .. (L.DIFF_NAME[x.diff] or ""), 0.8, 0.8, 0.8)
    GameTooltip:AddLine("This week: " .. STATUS[st].text .. (why == "recorded" and " (seen by the add-on)" or (why == "lockout" and " (from your lockout)" or (why == "you" and " (set by you)" or ""))), 1, 1, 1)
    if s.suggest then GameTooltip:AddLine("Suggested: bonus roll here this week", T.RGB("amethyst")) end
    if x.wanted and x.wanted > 0 then GameTooltip:AddLine(x.wanted .. " item" .. (x.wanted == 1 and "" or "s") .. " you want", 1, 1, 1) end
    GameTooltip:AddLine("Click: open > rolled > killed", T.RGB("muted"))
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  tiles[i] = b
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
  win.scope = T.Segmented(win, { { "bis", "BiS" }, { "wish", "Wishlist" }, { "all", "All upgrades" } },
    function() return opts.scope end, function(k) opts.scope = k; state.offset = 0; refresh() end, 24)
  win.scope:SetPoint("TOPLEFT", 16, -42)
  win.toggles = {
    toggle(win, "Bonus roll", function() return opts.modes.bonus end, function(v) opts.modes.bonus = v end, 90),
    toggle(win, "Kill drops", function() return opts.modes.drop end, function(v) opts.modes.drop = v; opts.drops = v end, 90),
    toggle(win, "Vault", function() return opts.modes.vault end, function(v) opts.modes.vault = v end, 70),
    toggle(win, "Craft & delves", function() return opts.modes.other end, function(v) opts.modes.other = v end, 110),
  }
  local prev
  for _, b in ipairs(win.toggles) do
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("LEFT", win.scope, "RIGHT", 16, 0) end
    prev = b
  end
  -- steppers on the right of row 1
  win.syncs = {}
  local sx = 16 + 540
  local f1, w1 = stepper(win, "MYTHIC FARM", sx, -42,
    function() return opts.farm end,
    function(d) local n = L.MythicBossCount(); local v = (opts.farm or n) + d; opts.farm = (v >= n) and nil or math.max(0, v) end,
    function(v) local n = L.MythicBossCount(); return (v or n) .. "/" .. n end,
    "Mythic bosses you have on farm. Bosses past this count use Heroic loot and Heroic bonus rolls.")
  win.syncs[#win.syncs + 1] = f1
  local f2, w2 = stepper(win, "ROLLS NOW", sx + w1 + 12, -42,
    function() return opts.rollsNow or L.BonusRolls() end,
    function(d) opts.rollsNow = math.max(0, (opts.rollsNow or L.BonusRolls() or 0) + d) end,
    function(v) return tostring(v or 0) end, "Bonus rolls you can spend this week. Starts from your Nebulous Voidcores.")
  win.syncs[#win.syncs + 1] = f2
  local f3 = stepper(win, "PER WEEK", sx + w1 + w2 + 24, -42,
    function() return opts.rollsWeek end, function(d) opts.rollsWeek = math.max(0, math.min(10, opts.rollsWeek + d)) end,
    function(v) return tostring(v) end, "Bonus rolls you earn each week. Unused ones carry over.")
  win.syncs[#win.syncs + 1] = f3

  -- boss map
  win.mapHead = T.Text(win, "label", 11, "muted"); win.mapHead:SetPoint("TOPLEFT", 16, MAP_Y + 6)
  win.mapHead:SetText("THIS WEEK  ·  click a boss: open > rolled > killed  ·  star = rolled, tick = killed, ring = suggested, faded = past your Mythic farm")
  win.map = CreateFrame("Frame", nil, win); win.map:SetPoint("TOPLEFT", 16, MAP_Y - 8); win.map:SetSize(W - 32, 56)

  -- flow (weeks down)
  win.flow = CreateFrame("Frame", nil, win); win.flow:SetPoint("TOPLEFT", 16, FLOW_Y); win.flow:SetSize(FLOW_W, H + FLOW_Y - 36)
  win.flow:SetClipsChildren(true)
  win.flow:EnableMouseWheel(true)
  win.flow:SetScript("OnMouseWheel", function(_, d) state.offset = math.max(0, state.offset - d * 40); ns.Planner_Refresh(true) end)
  win.summary = T.Text(win, "strong", 12, "soft"); win.summary:SetPoint("BOTTOMLEFT", win.flow, "TOPLEFT", 0, 8); win.summary:SetWidth(FLOW_W)
  win.summary:SetWordWrap(true)

  -- right: items
  local div = win:CreateTexture(nil, "ARTWORK"); div:SetColorTexture(T.RGB("edge", 0.25)); div:SetWidth(1)
  div:SetPoint("TOPLEFT", 16 + FLOW_W + 12, FLOW_Y); div:SetPoint("BOTTOMLEFT", 16 + FLOW_W + 12, 36)
  win.side = CreateFrame("Frame", nil, win); win.side:SetPoint("TOPLEFT", 16 + FLOW_W + 24, FLOW_Y); win.side:SetSize(SIDE_W, H + FLOW_Y - 36)
  local sh = T.Text(win.side, "label", 11, "muted"); sh:SetPoint("TOPLEFT", 0, 0); sh:SetText("YOUR ITEMS  ·  chance you have it by week 4")
  win.assume = T.Text(win, "body", 10, "muted"); win.assume:SetPoint("BOTTOMLEFT", 16, 12); win.assume:SetWidth(W - 32); win.assume:SetWordWrap(true)
  win.assume:SetText("A bonus roll gives 1 item from that boss's loot for your spec, all equally likely; one roll per boss each week; Mythic+ completions take rolls too. Weight = QE upgrade % × priority (P1 ×2) × BiS ×1.5. Items you own at the target level or higher drop out. Right-click a roll card to choose another boss; later weeks re-plan.")
  win:SetScript("OnShow", function() L._lock = nil; if not L.items then L.Refresh(true) end; ns.Planner_Refresh() end)
  win:Hide()
end

---------------------------------------------------------------- draw
local function layoutFlow(sim, opts)
  local y = -state.offset
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
          c.l1:SetText(string.format("%d wanted of %d  ·  %d%% for one", #rc.why, s.n, math.floor(rc.chance * 100 + 0.5)))
          local top = rc.why[1]
          c.l2:SetText(top and (shortName(top.it.name) .. "  " .. itemTag(top)) or "")
          local alt = rc.options[2]
          c.l3:SetText((rc.forced and "your choice  ·  " or "") .. (alt and string.format("or %s %d%%  ·  right-click", shortName(alt.s.label), math.floor(alt.c * 100 + 0.5)) or "right-click for options"))
        end
        c.tip = function(tt)
          if skip then tt:AddLine("Keep this roll", T.RGB("amethyst")); tt:AddLine("Not spent this week; it carries over.", 1, 1, 1); return end
          local s = rc.choice.s
          tt:AddLine(s.label .. (s.diff and ("  ·  " .. (L.DIFF_NAME[s.diff] or "")) or ""), T.RGB("amethyst"))
          tt:AddLine(string.format("A roll here gives 1 of %d items your spec can get. %d%% that it's one you want.", s.n, math.floor(rc.chance * 100 + 0.5)), 1, 1, 1, true)
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
          for _, k in ipairs(wk.kills) do tt:AddDoubleLine(k.s.label, string.format("~%.2f items", k.exp), 1, 1, 1, 0.8, 0.8, 0.8) end
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
    head("ALREADY YOURS", #sim.owned .. " item" .. (#sim.owned == 1 and "" or "s") .. " in your bags or equipped")
    for _, r in ipairs(sim.owned) do
      card(function(c)
        T.Icon(c.icon, "tick"); if T.hasCore then c.icon:SetVertexColor(T.RGB("emerald")) end
        c:SetBackdropBorderColor(T.RGB("emerald", 0.4))
        c.title:SetText(shortName(r.it.name)); c.l1:SetText("you have it at " .. (r.ownedAt or "?")); c.l2:SetText(itemTag(r)); c.l3:SetText("not in the plan")
      end)
    end
    endRow()
  end
  for i = ci + 1, #cards do cards[i]:Hide() end
  for i = hi + 1, #heads do heads[i]:Hide() end
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
  win.sub:SetText(opts.scope == "bis" and "your BiS" or (opts.scope == "all" and "every upgrade" or "your wishlist"))
  local rolls = sim.rollsNow or 0
  if #sim.items == 0 then
    win.summary:SetText(string.format("%d bonus roll%s now. Nothing left to luck into with these settings.", rolls, rolls == 1 and "" or "s"))
  else
    win.summary:SetText(string.format("%d bonus roll%s now, %d a week. %d item%s down to luck: half your upgrade value %s, 90%% %s.",
      rolls, rolls == 1 and "" or "s", opts.rollsWeek, #sim.items, #sim.items == 1 and "" or "s",
      sim.w50 and ("by week " .. sim.w50) or ("not in " .. opts.weeks .. " weeks"), sim.w90 and ("by week " .. sim.w90) or ("not in " .. opts.weeks .. " weeks")))
  end
  -- boss map
  local suggest = {}
  local wk1 = sim.weeks[1]
  for _, rc in ipairs(wk1 and wk1.rolls or {}) do if rc.choice ~= "skip" and rc.choice.s.encName then suggest[rc.choice.s.encName:lower()] = true end end
  local wanted = {}
  for _, s in ipairs(sim.sources) do if s.encName then wanted[s.encName:lower()] = #s.items end end
  local bosses, seen = {}, {}
  for _, it in ipairs(L.items or {}) do
    if it.raid and it.bonus and it.encName and it.encName ~= "" and not seen[it.encName] then
      seen[it.encName] = true
      bosses[#bosses + 1] = { name = it.encName, inst = it.inst or "", idx = (it.lair and 100 or 0) + (it.encIndex or 0), n = it.encIndex or 0,
                              diff = bossDiff(it, opts), icon = it.encIcon, lair = it.lair, wanted = wanted[it.encName:lower()] }
    end
  end
  table.sort(bosses, function(a, b) return a.idx < b.idx end)
  local x = 0
  local lastInst
  for i, bdata in ipairs(bosses) do
    if lastInst and bdata.inst ~= lastInst then x = x + 12 end
    lastInst = bdata.inst
    local t = tiles[i] or makeTile(win.map, i)
    t.boss = bdata
    t:ClearAllPoints(); t:SetPoint("TOPLEFT", x, 0)
    x = x + 68
    local st = L.BossStatus(bdata.name, bdata.diff)
    t.tex:SetTexture(bdata.icon or "Interface\\EncounterJournal\\UI-EJ-BOSS-Default")
    t.tex:SetDesaturated(st ~= "open"); t.tex:SetAlpha(st ~= "open" and 0.5 or 1)
    t.n:SetText(bdata.lair and "" or bdata.n)
    local S = STATUS[st]
    t.st:SetShown(S.icon ~= nil)
    if S.icon then T.Icon(t.st, S.icon); if T.hasCore then t.st:SetVertexColor(T.RGB(S.color)) end end
    local pastFarm = bdata.diff == 15 and not bdata.lair
    t.t:SetText(S.text .. (pastFarm and " · H" or "") .. ((bdata.wanted or 0) > 0 and ("  " .. bdata.wanted) or ""))
    t.t:SetTextColor(T.RGB(S.color))
    t:SetAlpha(pastFarm and 0.6 or 1)
    t.suggest = suggest[bdata.name:lower()] or false
    t.ring:SetShown(t.suggest)
    t:Show()
  end
  for i = #bosses + 1, #tiles do tiles[i]:Hide() end
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
