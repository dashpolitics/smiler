-- SmilerSplits: Mythic+ splits.
-- Records when each boss dies (and when enemy forces hit 100%) against the dungeon timer, and how the run ended.
-- During a run it compares you with your recorded run of the same dungeon nearest this key level
-- and says whether you're on pace to time it.
local ADDON, ns = ...
SmilerSplits = ns
ns.VERSION = "0.2.0"

local S = Smiler
local isSecret = issecretvalue or function() return false end
local function plain(v) return v ~= nil and not isSecret(v) end

local DEFAULTS = {
  auto = true,           -- show when a key starts
  compare = "closest",   -- closest | best | last
  forces = true,         -- enemy forces 100% as a checkpoint
  toast = true,
  locked = false,
  scale = 1,
  bgAlpha = 0.5,
  keep = 30,             -- runs kept per dungeon (fastest timed run per level is always kept)
}
local db
ns.COMPARE = { { "closest", "Nearest key level" }, { "best", "Your fastest timed run" }, { "last", "Your last run" } }

---------------------------------------------------------------- look (Smiler when installed)
local PAL = S and S.C or {
  void = { 0.024, 0.012, 0.059 }, card = { 0.110, 0.063, 0.227 }, edge = { 0.549, 0.314, 0.863 },
  text = { 0.941, 0.922, 1.000 }, soft = { 0.847, 0.784, 1.000 }, muted = { 0.706, 0.627, 0.863 },
  amethyst = { 0.714, 0.431, 1.000 }, diamond = { 0.910, 0.957, 1.000 }, emerald = { 0.000, 0.902, 0.463 },
  topaz = { 1.000, 0.671, 0.000 }, ruby = { 1.000, 0.176, 0.333 }, sapphire = { 0.361, 0.608, 1.000 },
}
local function RGB(name, a) local c = PAL[name] or PAL.text; return c[1], c[2], c[3], a or 1 end
local WHITE = "Interface\\Buttons\\WHITE8x8"
local function Text(parent, role, size, color, justify)
  if S and S.Text then return S.Text(parent, role, size, color, justify) end
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont((role == "display" or role == "label") and "Fonts\\FRIZQT__.TTF" or "Fonts\\ARIALN.TTF", size, "")
  fs:SetShadowOffset(1, -1); fs:SetShadowColor(0, 0, 0, 0.85)
  fs:SetTextColor(RGB(color or "text")); fs:SetJustifyH(justify or "LEFT"); fs:SetWordWrap(false)
  return fs
end
local function say(...) print("|cffb98cffSmilerSplits|r", ...) end

---------------------------------------------------------------- time
local function clock(sec)
  if not sec then return "–" end
  sec = math.floor(math.abs(sec) + 0.5)
  return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end
local function delta(sec)
  if not sec then return "" end
  if math.abs(sec) < 0.5 then return "±0:00" end
  return (sec > 0 and "+" or "-") .. clock(sec)
end
ns.clock, ns.delta = clock, delta

local cur          -- the run in progress (also saved in db.current so a /reload resumes it)
ns.last = nil      -- the run that just ended, shown until you leave the dungeon

local function worldElapsed()
  if not GetWorldElapsedTime then return nil end
  local ok, _, t = pcall(GetWorldElapsedTime, 1)
  if ok and plain(t) and t > 0 then return t end
end

function ns.Elapsed()
  if not cur then return 0 end
  if not cur.test then
    local w = worldElapsed()
    if w then return w end
  end
  return cur.clockStart and (GetTime() - cur.clockStart) or 0
end

---------------------------------------------------------------- dungeon info
local function mapInfo(mapID)
  if not (mapID and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo) then return nil end
  local name, _, limit, tex = C_ChallengeMode.GetMapUIInfo(mapID)
  return name, limit, tex
end

local function forcesPct()
  if not (C_ScenarioInfo and C_ScenarioInfo.GetScenarioStepInfo and C_ScenarioInfo.GetCriteriaInfo) then return nil end
  local ok, step = pcall(C_ScenarioInfo.GetScenarioStepInfo)
  local n = ok and step and step.numCriteria
  if not plain(n) then return nil end
  for i = 1, n do
    local ok2, ci = pcall(C_ScenarioInfo.GetCriteriaInfo, i)
    if ok2 and ci and plain(ci.isWeightedProgress) and ci.isWeightedProgress then
      if plain(ci.completed) and ci.completed then return 100 end
      local qs, total = ci.quantityString, ci.totalQuantity
      if plain(qs) and plain(total) and total > 0 then
        local count = tonumber((tostring(qs):gsub("%%", "")))
        if count then return math.min(100, count / total * 100) end
      end
      if plain(ci.quantity) then return math.min(100, ci.quantity) end
    end
  end
end

local function deaths()
  if not (C_ChallengeMode and C_ChallengeMode.GetDeathCount) then return 0, 0 end
  local ok, n, lost = pcall(C_ChallengeMode.GetDeathCount)
  if ok and plain(n) then return n, plain(lost) and lost or 0 end
  return 0, 0
end

---------------------------------------------------------------- recorded runs
-- the character this client is on, to tell your own runs from an alt's
local function meKey()
  if not UnitFullName then return nil end
  local ok, n = pcall(UnitFullName, "player")
  return ok and n or nil
end
ns.MeKey = meKey

-- "Bearbacker" when a run came from another character, nil when it is this one's
function ns.RunOwner(r)
  if not r or not r.char then return nil end
  if r.char == meKey() then return nil end
  return r.char
end

local function runsFor(mapID)
  db.runs[mapID] = db.runs[mapID] or {}
  return db.runs[mapID]
end

local function fastestTimedByLevel(list)
  local keep = {}
  for _, r in ipairs(list) do
    if r.timed and r.time then
      local b = keep[r.level]
      if not b or r.time < b.time then keep[r.level] = r end
    end
  end
  return keep
end

local function trim(list)
  local limit = db.keep or 30
  if #list <= limit then return end
  local keep = {}
  for _, r in pairs(fastestTimedByLevel(list)) do keep[r] = true end
  for i = #list, 1, -1 do
    if #list <= limit then break end
    if not keep[list[i]] then table.remove(list, i) end
  end
end

local function usable(r) return r.completed and not r.partial and r.time and r.splits and #r.splits > 0 end

-- the run to compare with
function ns.PickReference(mapID, level, mode)
  mode = mode or db.compare
  local best
  local function better(a, b)    -- is a a better reference than b?
    if not b then return true end
    if mode == "last" then return (a.date or 0) > (b.date or 0) end
    if mode == "best" then
      if (a.timed and 1 or 0) ~= (b.timed and 1 or 0) then return a.timed and true or false end
      return a.time < b.time
    end
    local da, dbb = math.abs(a.level - level), math.abs(b.level - level)
    if da ~= dbb then return da < dbb end
    if (a.timed and 1 or 0) ~= (b.timed and 1 or 0) then return a.timed and true or false end
    if a.level ~= b.level then return a.level > b.level end   -- same distance: the harder key
    return a.time < b.time
  end
  for _, r in ipairs(db.runs[mapID] or {}) do
    if usable(r) and better(r, best) then best = r end
  end
  return best
end

-- season best from the game (final time only, no splits): used when nothing is recorded yet
local function seasonBest(mapID)
  if not (C_MythicPlus and C_MythicPlus.GetSeasonBestForMap) then return nil end
  local ok, intime = pcall(C_MythicPlus.GetSeasonBestForMap, mapID)
  if ok and intime and plain(intime.durationSec) and plain(intime.level) then
    return { level = intime.level, time = intime.durationSec }
  end
end

---------------------------------------------------------------- run lifecycle
local refreshWindow, showWindow, hideWindow

local function newRun(mapID, level, affixes)
  local name, limit = mapInfo(mapID)
  local who, realm, cls
  if UnitFullName then local ok, a, b = pcall(UnitFullName, "player"); if ok then who, realm = a, b end end
  if UnitClass then local ok, _, c = pcall(UnitClass, "player"); if ok then cls = c end end
  return { mapID = mapID, level = level or 0, affixes = affixes, name = name or ("Dungeon " .. mapID),
           timeLimit = limit or 1800, started = time(), splits = {}, forces = {},
           -- whose run this was: the store is shared by every character on the account
           char = who, realm = realm, class = cls }
end

local function beginRun()
  if not (C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID) then return end
  local mapID = C_ChallengeMode.GetActiveChallengeMapID()
  if not plain(mapID) or not mapID then return end
  local level, affixes = C_ChallengeMode.GetActiveKeystoneInfo()
  if not plain(level) then level = 0 end
  local c = db.current
  if cur and not cur.test and (cur.mapID ~= mapID or cur.level ~= level) then
    finishRun({ completed = false })         -- an older run that never finished
    c = nil
  end
  if cur and cur.test then cur = nil end
  if cur and cur.mapID == mapID then
    -- already running
  elseif c and c.mapID == mapID and c.level == level and time() - (c.started or 0) < (c.timeLimit or 1800) + 3600 then
    cur = c                                  -- /reload or disconnect mid-run
  else
    cur = newRun(mapID, level, affixes)
    local w = worldElapsed()
    if w and w > 90 then cur.partial = true end   -- joined late: kept, but never used as a reference
    db.current = cur
  end
  cur.clockStart = GetTime() - (worldElapsed() or 0)
  ns.last = nil
  ns.ref = ns.PickReference(mapID, cur.level)
  ns.season = not ns.ref and seasonBest(mapID) or nil
  if db.auto then showWindow() end
  refreshWindow()
end

local function addCheckpoint(id, name)
  if not cur then return end
  for _, s in ipairs(cur.splits) do if s.id == id then return end end
  cur.splits[#cur.splits + 1] = { id = id, name = name, t = math.floor(ns.Elapsed() + 0.5) }
  refreshWindow()
end

local function finishRun(result)
  local r = cur
  if not r then return end
  cur, db.current = nil, nil
  if r.test then ns.last = nil; refreshWindow(); return end
  r.completed = result.completed
  r.timed = result.timed and true or false
  r.time = result.time or (r.splits[#r.splits] and r.splits[#r.splits].t)
  r.remaining = r.time and (r.timeLimit - r.time)
  r.upgrades = result.upgrades
  r.deaths, r.timeLost = deaths()
  r.date = time()
  r.clockStart = nil
  local ref = ns.ref
  if r.completed or #r.splits > 0 then
    local list = runsFor(r.mapID)
    table.insert(list, 1, r)
    trim(list)
  end
  ns.last, ns.lastRef = r, ref
  refreshWindow()

  if r.completed and db.toast and S and S.Toast then
    local sub = r.timed and (clock(r.remaining) .. " left") or (clock(-r.remaining) .. " over")
    if ref and ref.time then
      local d = r.time - ref.time
      sub = sub .. "  ·  " .. clock(d) .. (d <= 0 and " faster" or " slower") .. " than your +" .. ref.level
    end
    S:Toast({ kind = r.timed and "ready" or "death", title = (r.timed and "Timed +" or "Out of time +") .. r.level .. " " .. r.name,
              sub = sub, duration = 8, id = "splits" })
  end
end

local function completionInfo()
  local CM = C_ChallengeMode
  if CM.GetChallengeCompletionInfo then
    local ok, info = pcall(CM.GetChallengeCompletionInfo)
    if ok and type(info) == "table" then
      return info.mapChallengeModeID, info.level, info.time, info.onTime, info.keystoneUpgradeLevels
    end
  end
  if CM.GetCompletionInfo then
    local ok, mapID, level, ms, onTime, upgrades = pcall(CM.GetCompletionInfo)
    if ok then return mapID, level, ms, onTime, upgrades end
  end
end

local function onCompleted()
  if not cur then return end
  local _, _, ms, onTime, upgrades = completionInfo()
  local total = plain(ms) and ms and ms / 1000 or ns.Elapsed()
  if not plain(onTime) then onTime = total <= cur.timeLimit end
  -- forces may tick to 100 on the last pull
  if db.forces and not cur.forces[100] then
    local p = forcesPct(); if p and p >= 100 then cur.forces[100] = math.floor(total + 0.5) end
  end
  finishRun({ completed = true, timed = onTime, time = math.floor(total + 0.5), upgrades = plain(upgrades) and upgrades or nil })
end

local function abandon()
  if cur and not cur.test then finishRun({ completed = false }) end
end

---------------------------------------------------------------- the comparison
-- rows in reference order: { name, ref, t, d, live, pending }
function ns.Compute(run, ref, now)
  local out = { rows = {}, now = now }
  local mine, byName = {}, {}
  for _, s in ipairs(run.splits) do mine[s.id] = s; if s.name then byName[s.name:lower()] = s end end
  if db.forces and run.forces and run.forces[100] then mine.forces = { id = "forces", name = "Enemy forces", t = run.forces[100] } end

  local checkpoints = {}
  if ref then
    for _, s in ipairs(ref.splits) do checkpoints[#checkpoints + 1] = s end
    if db.forces and ref.forces and ref.forces[100] then checkpoints[#checkpoints + 1] = { id = "forces", name = "Enemy forces", t = ref.forces[100] } end
    table.sort(checkpoints, function(a, b) return a.t < b.t end)
  end
  local seen, lastT, lastD, nextRef = {}, nil, nil, nil
  for _, c in ipairs(checkpoints) do
    seen[c.id] = true
    local m = mine[c.id] or (c.name and byName[c.name:lower()])
    local row = { id = c.id, name = c.name, ref = c.t }
    if m then
      row.t, row.d = m.t, m.t - c.t
      if not lastT or m.t > lastT then lastT, lastD = m.t, row.d end
    else
      row.pending = true
      if not nextRef or c.t < nextRef then nextRef = c.t end
      if now and now > c.t then row.live = now - c.t end
    end
    out.rows[#out.rows + 1] = row
  end
  local seenName = {}
  for _, c in ipairs(checkpoints) do if c.name then seenName[c.name:lower()] = true end end
  for _, s in ipairs(run.splits) do
    if not seen[s.id] and not (s.name and seenName[s.name:lower()]) then out.rows[#out.rows + 1] = { id = s.id, name = s.name, t = s.t } end
  end
  if mine.forces and not seen.forces then out.rows[#out.rows + 1] = { id = "forces", name = "Enemy forces", t = mine.forces.t } end

  if ref and ref.time then
    local d = lastD or 0
    if now and nextRef and now - nextRef > d then d = now - nextRef end
    if run.time then d = run.time - ref.time end     -- finished: the real difference
    out.pace = d
    out.projected = run.time or (ref.time + d)
    out.spare = run.timeLimit - out.projected
    out.onPace = out.projected <= run.timeLimit
    out.plus = out.projected <= run.timeLimit * 0.6 and 3 or (out.projected <= run.timeLimit * 0.8 and 2 or (out.onPace and 1 or 0))
  end
  return out
end

---------------------------------------------------------------- window
local win
local ROW_H, W_W, MAX_ROWS = 17, 270, 9

local function savePoint()
  local p, _, rp, x, y = win:GetPoint()
  db.point = { p, rp, x, y }
end

local function applyLook()
  if not win then return end
  win:SetScale(db.scale or 1)
  win:SetBackdropColor(RGB("void", db.bgAlpha or 0.5))
  win:SetBackdropBorderColor(RGB("edge", math.min(0.5, (db.bgAlpha or 0.5) + 0.1)))
  win:EnableMouse(true)
end
ns.ApplyLook = applyLook

local function compareMenu(owner)
  if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
  MenuUtil.CreateContextMenu(owner, function(_, root)
    root:CreateTitle("Compare with")
    for _, o in ipairs(ns.COMPARE) do
      root:CreateRadio(o[2], function() return db.compare == o[1] end, function()
        db.compare = o[1]
        local run = cur or ns.last
        if run and not run.test then ns.ref = ns.PickReference(run.mapID, run.level) end
        refreshWindow()
      end)
    end
    root:CreateDivider()
    root:CreateCheckbox("Lock position", function() return db.locked end, function() db.locked = not db.locked end)
    root:CreateCheckbox("Enemy forces checkpoint", function() return db.forces end, function() db.forces = not db.forces; refreshWindow() end)
    root:CreateButton("Settings", function() ns.OpenSettings() end)
    root:CreateButton("Hide", function() hideWindow() end)
  end)
end

local function build()
  win = CreateFrame("Frame", "SmilerSplitsFrame", UIParent, "BackdropTemplate")
  win:SetSize(W_W, 80)
  win:SetFrameStrata("MEDIUM")
  win:SetClampedToScreen(true)
  win:SetMovable(true)
  win:RegisterForDrag("LeftButton")
  win:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  win:SetScript("OnDragStart", function(s) if not db.locked then s:StartMoving() end end)
  win:SetScript("OnDragStop", function(s) s:StopMovingOrSizing(); savePoint() end)
  win:SetScript("OnMouseUp", function(s, b) if b == "RightButton" then compareMenu(s) end end)
  if db.point then win:SetPoint(db.point[1], UIParent, db.point[2], db.point[3], db.point[4])
  else win:SetPoint("RIGHT", UIParent, "RIGHT", -260, 120) end
  if S and S.TopLine then S.TopLine(win) end

  win.title = Text(win, "label", 13, "amethyst"); win.title:SetPoint("TOPLEFT", 8, -6)
  win.title:SetWidth(W_W - 16)
  win.vs = Text(win, "body", 11, "muted"); win.vs:SetPoint("TOPLEFT", 8, -21); win.vs:SetWidth(W_W - 16)

  win.rows = {}
  for i = 1, MAX_ROWS do
    local r = CreateFrame("Frame", nil, win)
    r:SetSize(W_W - 16, ROW_H)
    r:SetPoint("TOPLEFT", 8, -38 - (i - 1) * ROW_H)
    r.name = Text(r, "body", 12, "soft"); r.name:SetPoint("LEFT"); r.name:SetWidth(112)
    r.ref = Text(r, "body", 11, "muted", "RIGHT"); r.ref:SetPoint("LEFT", 112, 0); r.ref:SetWidth(42)
    r.t = Text(r, "display", 13, "text", "RIGHT"); r.t:SetPoint("LEFT", 156, 0); r.t:SetWidth(44)
    r.d = Text(r, "display", 13, "text", "RIGHT"); r.d:SetPoint("RIGHT"); r.d:SetWidth(52)
    r:Hide()
    win.rows[i] = r
  end
  win.timer = Text(win, "display", 20, "text"); win.timer:SetPoint("BOTTOMLEFT", 8, 22)
  win.limit = Text(win, "body", 12, "muted"); win.limit:SetPoint("BOTTOMLEFT", win.timer, "BOTTOMRIGHT", 4, 2)
  win.deaths = Text(win, "body", 11, "muted", "RIGHT"); win.deaths:SetPoint("BOTTOMRIGHT", -8, 26)
  win.status = Text(win, "label", 13, "text"); win.status:SetPoint("BOTTOMLEFT", 8, 6); win.status:SetWidth(W_W - 16)

  win:SetScript("OnUpdate", function(s, dt)
    s.acc = (s.acc or 0) + dt
    if s.acc < 0.5 then return end
    s.acc = 0
    if cur then
      if db.forces and not cur.forces[100] and not cur.test then
        local p = forcesPct()
        if p and p >= 100 then cur.forces[100] = math.floor(ns.Elapsed() + 0.5) end
      end
      refreshWindow()
    end
  end)
  win:Hide()
  applyLook()
end

local function paintDelta(fs, d, live)
  if not d then fs:SetText(""); return end
  fs:SetText(delta(d))
  local good = d <= 0
  fs:SetTextColor(RGB(good and "emerald" or "ruby", live and 0.75 or 1))
end

function refreshWindow()
  if not win or not win:IsShown() then return end
  local run = cur or ns.last
  if not run then
    win.title:SetText("SPLITS")
    win.vs:SetText("Start a key and your boss splits appear here.")
    for _, r in ipairs(win.rows) do r:Hide() end
    win.timer:SetText(""); win.limit:SetText(""); win.deaths:SetText(""); win.status:SetText("")
    win:SetHeight(64)
    return
  end
  local ref = cur and ns.ref or ns.lastRef
  local now = cur and ns.Elapsed() or nil
  local c = ns.Compute(run, ref, now)

  win.title:SetText(string.format("+%d  %s", run.level or 0, (run.name or ""):upper()))
  if ref then
    -- say whose run you are being measured against: the store is shared across your characters,
    -- so the best run here is often an alt's
    local owner = ns.RunOwner(ref)
    win.vs:SetText(string.format("vs %s +%d · %s · %s", owner and (owner .. "'s") or "your", ref.level,
      ref.timed and (clock(ref.remaining) .. " left") or (clock(-(ref.remaining or 0)) .. " over"), date("%d %b", ref.date or 0)))
  elseif ns.season and cur then
    win.vs:SetText(string.format("No splits yet · season best +%d in %s", ns.season.level, clock(ns.season.time)))
  else
    win.vs:SetText(run.partial and "Joined late: this run won't be used to compare" or "First recorded run here: it becomes your reference")
  end

  local n = math.min(#c.rows, MAX_ROWS)
  for i, r in ipairs(win.rows) do
    local row = c.rows[i]
    r:SetShown(row ~= nil and i <= n)
    if row then
      r.name:SetText(row.name or "?")
      r.ref:SetText(row.ref and clock(row.ref) or "")
      if row.t then
        r.t:SetText(clock(row.t)); r.t:SetTextColor(RGB("text"))
        r.name:SetTextColor(RGB("soft"))
        paintDelta(r.d, row.d)
      else
        r.t:SetText(row.live and "…" or ""); r.t:SetTextColor(RGB("muted"))
        r.name:SetTextColor(RGB("muted"))
        paintDelta(r.d, row.live, true)
      end
    end
  end

  local elapsed = run.time or now or 0
  win.timer:SetText(clock(elapsed))
  win.limit:SetText("/ " .. clock(run.timeLimit))
  local dn, lost = run.deaths, run.timeLost
  if cur then dn, lost = deaths() end
  win.deaths:SetText((dn and dn > 0) and string.format("%d death%s  -%s", dn, dn == 1 and "" or "s", clock(lost or 0)) or "")

  if run.time and run.completed then
    win.status:SetText(run.timed and string.format("TIMED%s  ·  %s left", (run.upgrades and run.upgrades > 1) and (" +" .. run.upgrades) or "", clock(run.remaining))
      or string.format("OUT OF TIME  ·  %s over", clock(-run.remaining)))
    win.status:SetTextColor(RGB(run.timed and "emerald" or "ruby"))
  elseif c.projected then
    local plus = c.plus >= 2 and ("  ·  +" .. c.plus .. " pace") or ""
    if c.onPace then
      win.status:SetText(string.format("ON PACE  ·  finish %s, %s spare%s", clock(c.projected), clock(c.spare), plus))
      win.status:SetTextColor(RGB("emerald"))
    else
      win.status:SetText(string.format("BEHIND  ·  finish %s, %s over", clock(c.projected), clock(-c.spare)))
      win.status:SetTextColor(RGB("ruby"))
    end
  else
    local left = run.timeLimit - elapsed
    win.status:SetText(left >= 0 and (clock(left) .. " left on the timer") or (clock(-left) .. " over the timer"))
    win.status:SetTextColor(RGB(left >= 0 and "soft" or "ruby"))
  end
  win:SetHeight(38 + n * ROW_H + 52)
end

function showWindow() if not win then build() end; win:Show(); refreshWindow() end
function hideWindow() if win then win:Hide() end end
ns.Show, ns.Hide, ns.Refresh = showWindow, hideWindow, function() refreshWindow() end
function ns.Toggle() if win and win:IsShown() then hideWindow() else showWindow() end end
function ns.IsShown() return win and win:IsShown() or false end
function ns.ResetPosition() db.point = nil; if win then win:ClearAllPoints(); win:SetPoint("RIGHT", UIParent, "RIGHT", -260, 120) end end
function ns.Current() return cur end

---------------------------------------------------------------- preview
function ns.Test()
  if cur and not cur.test then say("a key is running – no preview now"); return end
  local ref = { level = 12, timed = true, time = 1690, timeLimit = 1980, remaining = 290, date = time() - 86400 * 3, completed = true,
    splits = { { id = 1, name = "First Boss", t = 312 }, { id = 2, name = "Second Boss", t = 755 },
               { id = 3, name = "Third Boss", t = 1190 }, { id = 4, name = "Last Boss", t = 1650 } }, forces = { [100] = 1420 } }
  cur = { test = true, mapID = 0, level = 13, name = "Preview Dungeon", timeLimit = 1980, splits = {
            { id = 1, name = "First Boss", t = 298 }, { id = 2, name = "Second Boss", t = 781 } }, forces = {} }
  cur.clockStart = GetTime() - 1215
  ns.ref = ref
  showWindow()
  C_Timer.After(30, function() if cur and cur.test then cur = nil; ns.ref = nil; refreshWindow() end end)
end

---------------------------------------------------------------- share / import
-- SKSPLIT1;map=375;name=Kings' Rest;lvl=17;time=1756;limit=1980;timed=1;date=1761232499;forces=1156;boss=2139:The Golden Serpent:339|2142:...
local function esc(x) return (tostring(x or ""):gsub("[;|:=]", " ")) end
function ns.Export(r)
  if not r or not r.splits then return nil end
  local b = {}
  for _, sp in ipairs(r.splits) do b[#b + 1] = string.format("%s:%s:%d", tostring(sp.id or 0), esc(sp.name), math.floor(sp.t or 0)) end
  return string.format("SKSPLIT1;map=%d;name=%s;lvl=%d;time=%d;limit=%d;timed=%d;date=%d;forces=%d;boss=%s",
    r.mapID or 0, esc(r.name), r.level or 0, math.floor(r.time or 0), math.floor(r.timeLimit or 0), r.timed and 1 or 0,
    r.date or 0, math.floor(r.forces and r.forces[100] or 0), table.concat(b, "|"))
end

local function mapByName(name)
  if not (name and C_ChallengeMode and C_ChallengeMode.GetMapTable) then return nil end
  for _, id in ipairs(C_ChallengeMode.GetMapTable() or {}) do
    local n, _, limit = C_ChallengeMode.GetMapUIInfo(id)
    if n and n:lower() == name:lower() then return id, limit end
  end
end

function ns.Import(text)
  text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if not text:find("^SKSPLIT1;") then return nil, "not a splits string (it starts with SKSPLIT1)" end
  local f = {}
  for k, v in text:gmatch(";([%w_]+)=([^;]*)") do f[k] = v end
  local mapID = tonumber(f.map) or 0
  local name, limit = mapInfo(mapID)
  if not name then
    local id, lim = mapByName(f.name)
    if id then mapID, name, limit = id, f.name, lim end
  end
  if not name or mapID == 0 then return nil, "unknown dungeon '" .. tostring(f.name) .. "'" end
  local r = { mapID = mapID, level = tonumber(f.lvl) or 0, name = name, timeLimit = limit or tonumber(f.limit) or 1800,
              time = tonumber(f.time), timed = f.timed == "1", date = tonumber(f.date) or (time and time()) or 0,
              completed = true, imported = true, splits = {}, forces = {} }
  r.remaining = r.time and (r.timeLimit - r.time)
  local fo = tonumber(f.forces); if fo and fo > 0 then r.forces[100] = fo end
  for piece in (f.boss or ""):gmatch("[^|]+") do
    local id, bname, t = piece:match("^([^:]*):([^:]*):(%d+)$")
    if t then r.splits[#r.splits + 1] = { id = tonumber(id) or bname, name = bname, t = tonumber(t) } end
  end
  table.sort(r.splits, function(a, b) return a.t < b.t end)
  if #r.splits == 0 or not r.time then return nil, "no boss times in it" end
  local list = runsFor(mapID)
  for i = #list, 1, -1 do local x = list[i]; if x.imported and x.level == r.level and x.time == r.time then table.remove(list, i) end end
  table.insert(list, 1, r)
  trim(list)
  return r
end

local shareBox
function ns.ShareBox(text)
  if not shareBox then
    shareBox = CreateFrame("Frame", "SmilerSplitsShare", UIParent, "BackdropTemplate")
    shareBox:SetSize(520, 92); shareBox:SetPoint("CENTER"); shareBox:SetFrameStrata("DIALOG")
    if S and S.Panel then S.Panel(shareBox, "void", 0.97, 0.5) else shareBox:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 }); shareBox:SetBackdropColor(0, 0, 0, 0.9) end
    shareBox.t = Text(shareBox, "label", 12, "amethyst"); shareBox.t:SetPoint("TOPLEFT", 12, -10)
    shareBox.eb = CreateFrame("EditBox", nil, shareBox); shareBox.eb:SetPoint("TOPLEFT", 12, -30); shareBox.eb:SetPoint("TOPRIGHT", -12, -30); shareBox.eb:SetHeight(24)
    shareBox.eb:SetFontObject(ChatFontNormal); shareBox.eb:SetAutoFocus(true)
    shareBox.eb:SetScript("OnEscapePressed", function() shareBox:Hide() end)
    shareBox.eb:SetScript("OnEnterPressed", function(e)
      if shareBox.mode == "import" then
        local r, err = ns.Import(e:GetText())
        if r then say(string.format("Imported +%d %s, %s%s.", r.level, r.name, clock(r.time), r.timed and " timed" or "")); shareBox:Hide(); refreshWindow()
        else say("Couldn't import: " .. err) end
      else shareBox:Hide() end
    end)
    shareBox.h = Text(shareBox, "body", 11, "muted"); shareBox.h:SetPoint("BOTTOMLEFT", 12, 10)
    tinsert(UISpecialFrames, "SmilerSplitsShare")
  end
  if text then
    shareBox.mode = "share"; shareBox.t:SetText("SHARE THIS RUN"); shareBox.eb:SetText(text); shareBox.h:SetText("Ctrl-C to copy · a friend pastes it with /splits import")
    shareBox:Show(); shareBox.eb:HighlightText()
  else
    shareBox.mode = "import"; shareBox.t:SetText("IMPORT A RUN"); shareBox.eb:SetText(""); shareBox.h:SetText("Paste a SKSPLIT1 string and press Enter")
    shareBox:Show()
  end
end

---------------------------------------------------------------- settings
function ns.OpenSettings()
  if S and S.OpenSettings then S:OpenSettings("Splits") else
    say("/splits  toggle · /splits test · /splits lock · /splits compare closest|best|last · /splits reset · /splits clear")
  end
end

function ns.Summary()
  local maps, total = 0, 0
  for _, list in pairs(db.runs) do if #list > 0 then maps = maps + 1; total = total + #list end end
  return total, maps
end

-- per dungeon: name, runs, fastest timed run, best key timed
function ns.History()
  local out = {}
  for mapID, list in pairs(db.runs) do
    if #list > 0 then
      local fastest, highest
      for _, r in ipairs(list) do
        if r.timed then
          if not highest or r.level > highest.level or (r.level == highest.level and r.time < highest.time) then highest = r end
        end
      end
      out[#out + 1] = { mapID = mapID, name = list[1].name or mapInfo(mapID) or ("Dungeon " .. mapID), runs = #list, highest = highest }
    end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

if S and S.RegisterSettings then
  S:RegisterSettings("Splits", function(body, W)
    local A = W.Column(body, 0, 0, 290)
    A:Section("Window")
    A:Switch("Show when a key starts", "Stays up until you leave the dungeon", function() return db.auto end, function(v) db.auto = v end)
    A:Switch("Lock position", "Unlocked: drag it anywhere", function() return db.locked end, function(v) db.locked = v end)
    A:Slider("Size", 0.7, 1.5, 0.05, function() return db.scale end, function(v) db.scale = v; applyLook() end,
      function(v) return math.floor(v * 100 + 0.5) .. "%" end, 120)
    A:Slider("Background", 0, 1, 0.05, function() return db.bgAlpha end, function(v) db.bgAlpha = v; applyLook() end,
      function(v) return math.floor(v * 100 + 0.5) .. "%" end, 120)
    A:Section("Splits")
    A:Dropdown("Compare with", ns.COMPARE, function() return db.compare end, function(k) db.compare = k
      local run = cur or ns.last
      if run and not run.test then ns.ref = ns.PickReference(run.mapID, run.level) end
      refreshWindow() end, 170)
    A:Switch("Enemy forces checkpoint", "When the count reaches 100%", function() return db.forces end, function(v) db.forces = v; refreshWindow() end)
    A:Switch("Alert at the end", "Timed or not, and against your reference", function() return db.toast end, function(v) db.toast = v end)

    local B = W.Column(body, 334, 0, 290)
    B:Section("Your runs")
    local hist = ns.History()
    if #hist == 0 then
      B:Note("Nothing recorded yet. Every key you run from now on is saved with its boss splits.", "soft", 13)
    else
      for i, h in ipairs(hist) do
        if i > 8 then B:Note("…and " .. (#hist - 8) .. " more", "muted", 12); break end
        B:Note(string.format("%s  ·  %d run%s%s", h.name, h.runs, h.runs == 1 and "" or "s",
          h.highest and string.format("  ·  best +%d in %s", h.highest.level, clock(h.highest.time)) or ""), "soft", 12)
      end
    end
    B:Note("Compares with your run of the same dungeon nearest this key level (a timed run wins a tie). Finish = that run's time plus how far ahead or behind you are at the latest boss.", "muted", 12)
    return {
      note = "/splits shows or hides the window. Right-click it for options.",
      footer = {
        { "Preview", function() ns.Test() end, nil, 90 },
        { "Share", function() SlashCmdList.SMILERSPLITS("share") end, nil, 80 },
        { "Import", function() ns.ShareBox(nil) end, nil, 80 },
        { "Reset position", function() ns.ResetPosition() end, nil, 120 },
        { "Show window", function() showWindow() end, "primary", 120 },
      },
    }
  end)
  if S.RegisterStatus then
    S:RegisterStatus("splits", function()
      if not db then return nil end
      if cur and not cur.test and ns.ref then
        local c = ns.Compute(cur, ns.ref, ns.Elapsed())
        if c.projected then return (c.onPace and "On pace · " .. clock(c.spare) .. " spare") or ("Behind · " .. clock(-c.spare) .. " over"), c.onPace and "ready" or "death" end
      end
      local total, maps = ns.Summary()
      if total == 0 then return "No keys recorded yet", "muted" end
      return string.format("%d run%s recorded in %d dungeon%s", total, total == 1 and "" or "s", maps, maps == 1 and "" or "s"), "muted"
    end)
  end
end

---------------------------------------------------------------- events
local ev = CreateFrame("Frame")
ns.ev = ev
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED",
                     "CHALLENGE_MODE_RESET", "ENCOUNTER_END", "WORLD_STATE_TIMER_START" }) do ev:RegisterEvent(e) end

local function active()
  return C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive()
end

ev:SetScript("OnEvent", function(_, e, a1, a2, _, _, a5)
  if e == "ADDON_LOADED" then
    if a1 ~= ADDON then return end
    SmilerSplitsDB = SmilerSplitsDB or {}
    db = SmilerSplitsDB
    for k, v in pairs(DEFAULTS) do if db[k] == nil then db[k] = v end end
    db.runs = db.runs or {}
    ns.db = db
  elseif not db then
    return
  elseif e == "CHALLENGE_MODE_START" or e == "WORLD_STATE_TIMER_START" then
    if active() then beginRun() end
  elseif e == "PLAYER_ENTERING_WORLD" then
    if active() then
      beginRun()
    else
      if db.current and not cur then cur = db.current end
      -- stepped out mid-key (repair, disconnect): keep it; only give up on runs that are long over
      if cur and not cur.test and time() - (cur.started or 0) > (cur.timeLimit or 1800) * 2 + 1800 then abandon() end
      local _, itype = GetInstanceInfo()
      if itype ~= "party" and not (cur and cur.test) then ns.last, ns.lastRef = nil, nil; hideWindow() end
    end
  elseif e == "ENCOUNTER_END" then
    if cur and not cur.test and plain(a5) and a5 == 1 and plain(a1) then addCheckpoint(a1, plain(a2) and a2 or "Boss") end
  elseif e == "CHALLENGE_MODE_COMPLETED" then
    onCompleted()
  elseif e == "CHALLENGE_MODE_RESET" then
    abandon()
  end
end)

---------------------------------------------------------------- slash
SLASH_SMILERSPLITS1 = "/splits"
SlashCmdList.SMILERSPLITS = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  local cmd, arg = msg:match("^(%S*)%s*(.*)$")
  if cmd == "" then ns.Toggle()
  elseif cmd == "test" or cmd == "preview" then ns.Test()
  elseif cmd == "lock" then db.locked = not db.locked; say(db.locked and "locked" or "unlocked – drag to move")
  elseif cmd == "reset" then ns.ResetPosition(); say("position reset")
  elseif cmd == "compare" and (arg == "closest" or arg == "best" or arg == "last") then db.compare = arg; say("comparing with: " .. arg)
  elseif cmd == "options" or cmd == "settings" then ns.OpenSettings()
  elseif cmd == "share" then
    local run = ns.last or (cur and not cur.test and cur)
    if not run then
      -- most recent recorded run anywhere
      for _, list in pairs(db.runs) do for _, r in ipairs(list) do if not run or (r.date or 0) > (run.date or 0) then run = r end end end
    end
    local s = run and ns.Export(run)
    if s then ns.ShareBox(s) else say("no run to share yet") end
  elseif cmd == "import" then
    if arg ~= "" then
      local r, err = ns.Import(arg)
      if r then say(string.format("Imported +%d %s, %s%s.", r.level, r.name, clock(r.time), r.timed and " timed" or "")); refreshWindow() else say("Couldn't import: " .. err) end
    else ns.ShareBox(nil) end
  elseif cmd == "clear" then
    if arg == "yes" then db.runs = {}; say("all recorded runs cleared") else say("this deletes every recorded run: type /splits clear yes") end
  else
    say("/splits  show/hide · test · lock · reset · compare closest|best|last · share · import · settings · clear")
  end
end
