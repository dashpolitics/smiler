-- SmilerVault: your Great Vault across characters, kept simple.
-- Aim per character: full Heroic raid (some Mythic), 8 dungeons at +10 or higher, at least 3 slots.
-- World / delve slots are shown but don't count towards the aim after the season's first week.
-- On Tuesdays (the day before the EU reset) it flags anyone under 3 slots and says the quickest way there.
-- /vault
local ADDON, ns = ...
local S = Smiler

local DEFAULTS = { tuesday = true, minSlots = 3, mplusLevel = 10 }
local db, me
local TYPES = {   -- vault rows: thresholds come from the game; these are the fallbacks
  { key = "raid",  label = "Raid",    enum = "Raid",       thr = { 2, 4, 6 }, unit = "boss", units = "bosses" },
  { key = "mplus", label = "Dungeons", enum = "Activities", thr = { 1, 4, 8 }, unit = "dungeon", units = "dungeons" },
  { key = "world", label = "World",   enum = "World",      thr = { 2, 4, 8 }, unit = "delve or world activity", units = "delves or world activities" },
}
local DIFF = { [17] = "LFR", [14] = "N", [15] = "H", [16] = "M" }

local function secret(v) return issecretvalue and issecretvalue(v) or false end
local function say(...) if S and S.Print then S.Print("|cffb66effVault|r", ...) else print("|cffb66effVault|r", ...) end end
local function charKey()
  local n, r = UnitFullName("player")
  r = (r and r ~= "") and r or (GetNormalizedRealmName and GetNormalizedRealmName()) or GetRealmName() or "?"
  return (n or "?") .. "-" .. r
end
local function untilWeekly() return (C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset and C_DateAndTime.GetSecondsUntilWeeklyReset()) or 0 end
local function weekId() return math.floor((time() + untilWeekly() + 30) / 60) end
local function isTuesday() return date("*t").wday == 3 end

---------------------------------------------------------------- reading this character
local function read()
  local c = db.chars[me] or {}
  db.chars[me] = c
  local _, cls = UnitClass("player")
  c.class, c.name, c.week, c.at = cls, UnitName("player"), weekId(), time()
  c.rows = {}
  if C_WeeklyRewards and C_WeeklyRewards.GetActivities and Enum.WeeklyRewardChestThresholdType then
    for _, t in ipairs(TYPES) do
      local acts = C_WeeklyRewards.GetActivities(Enum.WeeklyRewardChestThresholdType[t.enum]) or {}
      table.sort(acts, function(a, b) return (a.index or 0) < (b.index or 0) end)
      local row = { progress = 0, thr = {}, level = {} }
      for i, a in ipairs(acts) do
        if i > 3 then break end
        row.thr[i] = a.threshold or t.thr[i]
        row.level[i] = a.level or 0
        row.progress = math.max(row.progress, a.progress or 0)
      end
      c.rows[t.key] = row
    end
  end
  -- dungeons this week at your target level or higher
  c.runsHigh, c.runs = 0, 0
  if C_MythicPlus and C_MythicPlus.GetRunHistory then
    for _, r in ipairs(C_MythicPlus.GetRunHistory(false, true) or {}) do
      c.runs = c.runs + 1
      if (r.level or 0) >= db.mplusLevel then c.runsHigh = c.runsHigh + 1 end
    end
  end
  return c
end

---------------------------------------------------------------- what a character has, and what it's missing
local function rowOf(c, key)
  local t; for _, x in ipairs(TYPES) do if x.key == key then t = x end end
  local r = c.rows and c.rows[key] or {}
  local thr = {}
  for i = 1, 3 do thr[i] = (r.thr and r.thr[i]) or t.thr[i] end
  return r.progress or 0, thr, r.level or {}, t
end
local function slots(c, key)
  local p, thr = rowOf(c, key)
  local n = 0
  for i = 1, 3 do if p >= thr[i] then n = n + 1 end end
  return n
end
function ns.Count(c)
  local current = c.week == weekId()
  if not current then return 0, 0, 0, 0 end
  local r, d, w = slots(c, "raid"), slots(c, "mplus"), slots(c, "world")
  return r + d + w, r, d, w
end

-- cheapest way to n slots: take the next slot that needs the fewest more runs / kills, again and again
local function cheapest(c, want, keys)
  local have, plan, extra = 0, {}, {}
  for _, k in ipairs(keys) do extra[k] = 0; have = have + slots(c, k) end
  while have < want do
    local best, bestCost
    for _, k in ipairs(keys) do
      local p, thr = rowOf(c, k)
      local got = p + extra[k]
      for i = 1, 3 do
        if got < thr[i] then
          local cost = thr[i] - got
          if not bestCost or cost < bestCost then best, bestCost = k, cost end
          break
        end
      end
    end
    if not best then break end
    extra[best] = extra[best] + bestCost; plan[best] = (plan[best] or 0) + bestCost
    have = have + 1
  end
  return plan, have >= want
end
local function planText(plan)
  local parts = {}
  for _, t in ipairs(TYPES) do
    local n = plan[t.key]
    if n and n > 0 then parts[#parts + 1] = n .. " " .. (n == 1 and t.unit or t.units) end
  end
  return #parts > 0 and table.concat(parts, " + ") or "nothing"
end

-- the four suggestions: 3 slots / 3 dungeon slots / 3 raid slots / 6 slots (raid and dungeons)
function ns.Suggest(c)
  local out = {}
  local total = ns.Count(c)
  local p3 = cheapest(c, db.minSlots, { "raid", "mplus", "world" })
  if total < db.minSlots then out[#out + 1] = string.format("%d slots: %s", db.minSlots, planText(p3)) end
  local dp, dthr = rowOf(c, "mplus")
  if dp < dthr[3] then
    local hi = c.runsHigh or 0
    out[#out + 1] = string.format("3 dungeon slots: %d more dungeon%s (%d of %d at +%d so far)", dthr[3] - dp, dthr[3] - dp == 1 and "" or "s", hi, dthr[3], db.mplusLevel)
  elseif (c.runsHigh or 0) < dthr[3] then
    out[#out + 1] = string.format("Dungeon slots open; %d more at +%d to make all three +%d", dthr[3] - (c.runsHigh or 0), db.mplusLevel, db.mplusLevel)
  end
  local rp, rthr = rowOf(c, "raid")
  if rp < rthr[3] then out[#out + 1] = string.format("3 raid slots: %d more Heroic boss%s", rthr[3] - rp, rthr[3] - rp == 1 and "" or "es") end
  local p6, ok6 = cheapest(c, 6, { "raid", "mplus" })
  if ok6 and (slots(c, "raid") + slots(c, "mplus")) < 6 then out[#out + 1] = "6 slots (raid + dungeons): " .. planText(p6) end
  return out
end

---------------------------------------------------------------- window
local C = (S and S.C) or {}
local function rgb(n, a) local c = C[n] or { 0.9, 0.9, 1 }; return c[1], c[2], c[3], a or 1 end
local function text(parent, role, size, color, justify)
  if S and S.Text then return S.Text(parent, role, size, color, justify) end
  local f = parent:CreateFontString(nil, "OVERLAY"); f:SetFont("Fonts\\ARIALN.TTF", size, ""); f:SetTextColor(rgb(color)); f:SetJustifyH(justify or "LEFT"); return f
end
local win
local pool, used = {}, 0
local function fs() used = used + 1; local f = pool[used]; if not f then f = text(win, "body", 12, "text"); pool[used] = f end; f:Show(); return f end
local boxes, bused = {}, 0
local function box()
  bused = bused + 1
  local b = boxes[bused]
  if not b then
    b = CreateFrame("Frame", nil, win, "BackdropTemplate"); b:SetSize(40, 18)
    if S and S.Panel then S.Panel(b, "card", 0.9, 0.5) else b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }) end
    b.t = text(b, "label", 11, "text", "CENTER"); b.t:SetPoint("CENTER")
    boxes[bused] = b
  end
  b:Show(); return b
end

-- one vault cell: done = filled with what it pays (H, +12, T8) and a border; not yet = "3/4"
local function cellText(t, p, thr, lvl)
  if p < thr then return string.format("%d/%d", p, thr), false end
  if t.key == "raid" then return DIFF[lvl] or "done", true end
  if t.key == "mplus" then return lvl and lvl > 0 and ("+" .. lvl) or "M0", true end
  return lvl and lvl > 0 and ("T" .. lvl) or "done", true
end

function ns.Refresh()
  if not win or not win:IsShown() then return end
  if me then read() end
  used, bused = 0, 0
  local y = -52
  local list = {}
  for k, c in pairs(db.chars) do list[#list + 1] = { key = k, c = c } end
  table.sort(list, function(a, b) if a.key == me then return true elseif b.key == me then return false end return (a.c.at or 0) > (b.c.at or 0) end)
  -- header
  local x0 = 150
  for ti, t in ipairs(TYPES) do
    local h = fs()
    h:ClearAllPoints(); h:SetPoint("TOPLEFT", x0 + (ti - 1) * 138, y); h:SetWidth(130); h:SetText(t.label:upper()); h:SetTextColor(rgb("muted"))
  end
  local hs = fs(); hs:ClearAllPoints(); hs:SetPoint("TOPLEFT", x0 + 3 * 138, y); hs:SetWidth(60); hs:SetText("SLOTS"); hs:SetTextColor(rgb("muted"))
  y = y - 18
  for n, it in ipairs(list) do
    if n > 14 then break end
    local c = it.c
    local current = c.week == weekId()
    local total = ns.Count(c)
    local nm = fs(); nm:ClearAllPoints(); nm:SetPoint("TOPLEFT", 14, y - 2); nm:SetWidth(132)
    nm:SetText((it.key == me and "> " or "") .. (c.name or it.key))
    local cc = c.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class]
    if cc then nm:SetTextColor(cc.r, cc.g, cc.b) else nm:SetTextColor(rgb("text")) end
    for ti, t in ipairs(TYPES) do
      local p, thr, lvl = rowOf(c, t.key)
      for i = 1, 3 do
        local b = box(); b:ClearAllPoints(); b:SetPoint("TOPLEFT", x0 + (ti - 1) * 138 + (i - 1) * 44, y)
        local s, done = cellText(t, current and p or 0, thr[i], lvl[i])
        if not current then s = "?" end
        b.t:SetText(s)
        b.t:SetTextColor(rgb(done and "text" or "muted"))
        b:SetBackdropBorderColor(rgb(done and "emerald" or "edge", done and 0.9 or 0.35))
        b:SetBackdropColor(rgb(done and "raised" or "card", done and 0.95 or 0.6))
      end
    end
    local sl = fs(); sl:ClearAllPoints(); sl:SetPoint("TOPLEFT", x0 + 3 * 138, y - 2); sl:SetWidth(90)
    if not current then sl:SetText("not seen"); sl:SetTextColor(rgb("muted"))
    elseif total < db.minSlots then sl:SetText(total .. "  UNDER " .. db.minSlots); sl:SetTextColor(rgb("ruby"))
    else sl:SetText(total .. "  ok"); sl:SetTextColor(rgb("emerald")) end
    y = y - 22
    -- suggestions under the current character, or under anyone short on a Tuesday
    if current and (it.key == me or (isTuesday() and total < db.minSlots)) then
      for _, line in ipairs(ns.Suggest(c)) do
        local f = fs(); f:ClearAllPoints(); f:SetPoint("TOPLEFT", 30, y); f:SetWidth(560); f:SetText("- " .. line); f:SetTextColor(rgb("soft"))
        y = y - 16
      end
      y = y - 4
    end
  end
  for i = used + 1, #pool do pool[i]:Hide() end
  for i = bused + 1, #boxes do boxes[i]:Hide() end
  win.foot:SetText(string.format("Aim: full Heroic raid, 8 dungeons at +%d, at least %d slots. A ticked box shows what it pays: H/M raid, +key level, delve tier.", db.mplusLevel, db.minSlots))
  win:SetHeight(-y + 40)
end

local function build()
  win = CreateFrame("Frame", "SmilerVaultWindow", UIParent, "BackdropTemplate")
  win:SetSize(620, 300); win:SetFrameStrata("HIGH"); win:SetClampedToScreen(true); win:SetMovable(true); win:EnableMouse(true)
  win:RegisterForDrag("LeftButton"); win:SetScript("OnDragStart", win.StartMoving)
  win:SetScript("OnDragStop", function(s) s:StopMovingOrSizing(); local a, _, r, x, y = s:GetPoint(); if type(x) == "number" and not secret(x) then db.point = { a, r, x, y } end end)
  if S and S.Panel then S.Panel(win, "void", 0.96, 0.6) else win:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" }); win:SetBackdropColor(0.03, 0.01, 0.06, 0.95) end
  if S and S.TopLine then S.TopLine(win) end
  tinsert(UISpecialFrames, "SmilerVaultWindow")
  local t = text(win, "display", 18, "amethyst"); t:SetPoint("TOPLEFT", 14, -10); t:SetText(S and S.Spaced and S.Spaced("Vault") or "VAULT")
  win.sub = text(win, "body", 11, "muted"); win.sub:SetPoint("TOPLEFT", 14, -32)
  win.sub:SetText("Great Vault progress on every character you've logged in this week")
  local close = CreateFrame("Button", nil, win); close:SetSize(18, 18); close:SetPoint("TOPRIGHT", -8, -8)
  local ct = close:CreateTexture(nil, "OVERLAY"); ct:SetAllPoints()
  if S and S.Icon then ct:SetTexture(S.Icon("close")); ct:SetVertexColor(rgb("muted")) else ct:SetColorTexture(0.5, 0.3, 0.6, 1) end
  close:SetScript("OnClick", function() win:Hide() end)
  win.foot = text(win, "body", 10, "muted"); win.foot:SetPoint("BOTTOMLEFT", 14, 10); win.foot:SetWidth(590); win.foot:SetWordWrap(true)
  if db.point then win:SetPoint(db.point[1], UIParent, db.point[2], db.point[3], db.point[4]) else win:SetPoint("CENTER") end
  win:SetScript("OnShow", ns.Refresh)
  win:Hide()
end
function ns.Toggle() if not db then return end if not win then build() end win:SetShown(not win:IsShown()) end

---------------------------------------------------------------- Tuesday check
local function tuesdayCheck()
  if not (db.tuesday and isTuesday()) then return end
  local short = {}
  for k, c in pairs(db.chars) do
    if c.week == weekId() and ns.Count(c) < db.minSlots then short[#short + 1] = { k = k, c = c } end
  end
  if #short == 0 then return end
  table.sort(short, function(a, b) return (a.k == me and 0 or 1) < (b.k == me and 0 or 1) end)
  say(string.format("Vault closes tomorrow: %d character%s under %d slots.", #short, #short == 1 and "" or "s", db.minSlots))
  for _, s in ipairs(short) do
    local sug = ns.Suggest(s.c)
    say(string.format("  %s: %d slot%s. %s", s.c.name or s.k, ns.Count(s.c), ns.Count(s.c) == 1 and "" or "s", sug[1] or ""))
  end
  if S and S.Toast then S:Toast({ kind = "death", title = "Vault short", sub = #short .. " character" .. (#short == 1 and "" or "s") .. " under " .. db.minSlots .. " slots · /vault", duration = 8 }) end
end

---------------------------------------------------------------- Smiler
if S and S.RegisterSettings then
  S:RegisterSettings("Vault", function(body, W)
    local A = W.Column(body, 0, 0, 290)
    A:Section("Vault")
    A:Switch("Tuesday warning", "On Tuesdays, flag characters under the minimum and say how to get there", function() return db.tuesday end, function(v) db.tuesday = v end)
    A:Slider("Minimum slots", 1, 9, 1, function() return db.minSlots end, function(v) db.minSlots = v; ns.Refresh() end, function(v) return v .. " slots" end, 120)
    A:Slider("Dungeon target", 2, 20, 1, function() return db.mplusLevel end, function(v) db.mplusLevel = v; ns.Refresh() end, function(v) return "+" .. v end, 120)
    local B = W.Column(body, 334, 0, 290)
    B:Section("How it reads")
    B:Note("From the game's Great Vault, each time you log a character in. Alts show as they were when you last played them.", "soft", 13)
    return { note = "/vault", footer = {} }
  end)
  if S.RegisterStatus then
    S:RegisterStatus("vault", function()
      if not db or not me or not db.chars[me] then return nil end
      local n = ns.Count(db.chars[me])
      return n .. " vault slot" .. (n == 1 and "" or "s") .. " this week", n < db.minSlots and "ruby" or "muted"
    end)
  end
end

---------------------------------------------------------------- events
local ev = CreateFrame("Frame")
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "WEEKLY_REWARDS_UPDATE", "CHALLENGE_MODE_COMPLETED", "BOSS_KILL", "CHALLENGE_MODE_MAPS_UPDATE" }) do pcall(ev.RegisterEvent, ev, e) end
local checked
ev:SetScript("OnEvent", function(_, e, a1)
  if e == "ADDON_LOADED" then
    if a1 ~= ADDON then return end
    SmilerVaultDB = SmilerVaultDB or {}
    db = SmilerVaultDB
    for k, v in pairs(DEFAULTS) do if db[k] == nil then db[k] = v end end
    db.chars = db.chars or {}
    return
  end
  if not db then return end
  if e == "PLAYER_ENTERING_WORLD" then
    me = charKey()
    if C_MythicPlus and C_MythicPlus.RequestMapInfo then C_MythicPlus.RequestMapInfo() end
    C_Timer.After(4, function()
      read(); ns.Refresh()
      if not checked then checked = true; tuesdayCheck() end
    end)
  elseif me then
    C_Timer.After(1, function() read(); ns.Refresh() end)
  end
end)

SLASH_SMILERVAULT1 = "/vault"
SlashCmdList.SMILERVAULT = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "check" then checked = false; local wd = isTuesday; isTuesday = function() return true end; tuesdayCheck(); isTuesday = wd
  elseif msg == "settings" and S and S.OpenSettings then S:OpenSettings("Vault")
  else ns.Toggle() end
end
