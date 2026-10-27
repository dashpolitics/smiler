-- RewoundExtra: your best HPS on every boss, per character and difficulty, side by side with your alts.
-- Separate from Rewound's Rewind records (Rewound.lua is untouched): this file only adds its own events,
-- its own saved table (RewoundDB.extra) and its own window (/rewoundx).
-- Healing comes from the game's damage meter after the kill (Midnight gives addons no combat log);
-- HPS = your healing done / the encounter's length, the same way the logs count it.
local ADDON, ns = ...
local X = {}
ns.Extra = X

local DIFF = { { 17, "LFR" }, { 14, "Normal" }, { 15, "Heroic" }, { 16, "Mythic" } }
local DIFF_SHORT = { [17] = "LFR", [14] = "N", [15] = "H", [16] = "M" }
local function secret(v) return issecretvalue and issecretvalue(v) or false end
local function safe(v) if v == nil or secret(v) then return nil end return v end
local P = function(...) ns.Print(...) end
local function fmt(n) return ns.fmt(n) end

local db                          -- RewoundDB.extra
local fight                       -- { enc, name, diff, size, start }
local pending                     -- a kill waiting for combat to end before the meter can be read

---------------------------------------------------------------- who am I
local function charKey()
  local name, realm = UnitFullName("player")
  realm = realm and realm ~= "" and realm or GetNormalizedRealmName() or GetRealmName() or "?"
  return (name or "?") .. "-" .. realm
end
local function isHealer()
  local idx = GetSpecialization and GetSpecialization()
  return idx and GetSpecializationRole and GetSpecializationRole(idx) == "HEALER"
end
local function specName()
  local idx = GetSpecialization and GetSpecialization()
  if not idx then return nil end
  local _, name = GetSpecializationInfo(idx)
  return name
end

---------------------------------------------------------------- reading your healing for the fight that just ended
local function readTotal()
  if InCombatLockdown() then return nil end
  if not (C_DamageMeter and C_DamageMeter.GetCombatSessionSourceFromType and Enum.DamageMeterSessionType) then return nil end
  local ok, src = pcall(C_DamageMeter.GetCombatSessionSourceFromType,
    Enum.DamageMeterSessionType.Current, Enum.DamageMeterType.HealingDone, UnitGUID("player"))
  if not ok or type(src) ~= "table" then return nil end
  local total = safe(src.totalAmount)
  if not total and type(src.combatSpells) == "table" then
    total = 0
    for _, sp in ipairs(src.combatSpells) do total = total + (safe(sp.totalAmount) or 0) end
  end
  return total
end

---------------------------------------------------------------- recording
local function bestAlt(enc, diff, me)
  local row = db.best[enc] and db.best[enc][diff]
  local who, top
  for k, r in pairs(row or {}) do
    if k ~= me and (not top or r.hps > top.hps) then who, top = k, r end
  end
  return who, top
end

local function shortName(key) return (key:match("^([^-]+)")) or key end

local function save(p, total)
  if not total or total <= 0 or p.dur < 10 then return end
  local me = charKey()
  local hps = total / p.dur
  db.chars[me] = db.chars[me] or {}
  local c = db.chars[me]
  c.class = select(2, UnitClass("player")); c.name = UnitName("player")
  db.best[p.enc] = db.best[p.enc] or {}
  local B = db.best[p.enc]
  B.name = p.name or B.name
  B[p.diff] = B[p.diff] or {}
  local prev = B[p.diff][me]
  local rec = { hps = hps, total = total, dur = p.dur, when = time(), spec = specName(),
    ilvl = select(2, GetAverageItemLevel()), size = p.size }
  -- every kill is kept in a short history, the best stays as the record
  db.history[#db.history + 1] = { key = me, enc = p.enc, diff = p.diff, hps = hps, when = rec.when }
  while #db.history > 200 do table.remove(db.history, 1) end
  local where = (B.name or ("Boss " .. p.enc)) .. " " .. (DIFF_SHORT[p.diff] or "?")
  local altKey, alt = bestAlt(p.enc, p.diff, me)
  local altTxt = alt and string.format("  ·  %s %s", shortName(altKey), fmt(alt.hps)) or ""
  if not prev or hps > prev.hps then
    B[p.diff][me] = rec
    if db.toast ~= false then
      ns.ShowToast(prev and "NEW BOSS BEST" or "FIRST KILL RECORDED", fmt(hps) .. " HPS",
        (prev and ("prev " .. fmt(prev.hps)) or where) .. (prev and ("  ·  " .. where) or "") .. altTxt, prev ~= nil)
    end
    if db.chat ~= false then P(string.format("%s: %s HPS%s%s", where, fmt(hps), prev and (" – best was " .. fmt(prev.hps)) or " – first record",
      alt and string.format(" (best alt: %s %s)", shortName(altKey), fmt(alt.hps)) or "")) end
  elseif db.chat ~= false then
    P(string.format("%s: %s HPS – your best %s%s", where, fmt(hps), fmt(prev.hps),
      alt and string.format(", best alt %s %s", shortName(altKey), fmt(alt.hps)) or ""))
  end
  if X.Refresh then X.Refresh() end
end

local tries = 0
local function process()
  if not pending then return end
  if InCombatLockdown() then return end          -- PLAYER_REGEN_ENABLED will call again
  local total = readTotal()
  if not total then
    tries = tries + 1
    if tries <= 5 then C_Timer.After(2, process) else pending, tries = nil, 0 end
    return
  end
  local p = pending
  pending, tries = nil, 0
  save(p, total)
end

---------------------------------------------------------------- events
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(_, e, ...)
  if e == "ADDON_LOADED" then
    if ... ~= ADDON then return end
    RewoundDB = RewoundDB or {}
    RewoundDB.extra = RewoundDB.extra or {}
    db = RewoundDB.extra
    db.chars = db.chars or {}
    db.best = db.best or {}
    db.history = db.history or {}
    if db.toast == nil then db.toast = true end
    ev:RegisterEvent("ENCOUNTER_START"); ev:RegisterEvent("ENCOUNTER_END"); ev:RegisterEvent("PLAYER_REGEN_ENABLED")
  elseif e == "ENCOUNTER_START" then
    local enc, name, diff, size = ...
    enc, diff = safe(enc), safe(diff)
    if not enc then fight = nil return end
    fight = { enc = enc, name = safe(name), diff = diff, size = safe(size), start = GetTime() }
  elseif e == "ENCOUNTER_END" then
    local enc, name, diff, size, success = ...
    local f = fight
    fight = nil
    if not f or safe(enc) ~= f.enc or safe(success) ~= 1 then return end
    if not isHealer() then return end
    -- raids only by difficulty ID: LFR, Normal, Heroic, Mythic (dungeon bosses are left to Rewound's own records)
    if not DIFF_SHORT[f.diff or 0] then return end
    f.dur = GetTime() - f.start
    pending = f
    C_Timer.After(1, process)
  elseif e == "PLAYER_REGEN_ENABLED" then
    if pending then C_Timer.After(1, process) end
  end
end)

---------------------------------------------------------------- the window: bosses down, your characters across
local C = ns.C
local win, cells, rowLbl, colLbl = nil, {}, {}, {}
local curDiff = 15

local function fs(parent, size, color, justify)
  local f = parent:CreateFontString(nil, "OVERLAY")
  f:SetFont(ns.NUM_FONT, size, ""); f:SetTextColor(unpack(color or C.text)); f:SetJustifyH(justify or "LEFT")
  f:SetShadowOffset(1, -1); f:SetShadowColor(0, 0, 0, 0.85)
  return f
end
local function button(parent, label, w, onClick)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w, 20); b:SetBackdrop(ns.BACKDROP)
  b:SetBackdropColor(unpack(C.panel)); b:SetBackdropBorderColor(unpack(C.edge))
  b.text = fs(b, 12, C.text, "CENTER"); b.text:SetPoint("CENTER"); b.text:SetText(label)
  b:SetScript("OnEnter", function(s) s:SetBackdropBorderColor(unpack(C.border)) end)
  b:SetScript("OnLeave", function(s) s:SetBackdropBorderColor(unpack(s.sel and C.border or C.edge)) end)
  b:SetScript("OnClick", onClick)
  return b
end

-- boss order: the Adventure Guide's order where it can be read, else the order bosses were first killed
local ejOrder
local function bossOrder()
  if not ejOrder then
    ejOrder = {}
    if EJ_GetNumTiers and not (EncounterJournal and EncounterJournal.IsShown and EncounterJournal:IsShown()) then
      local saved = EJ_GetCurrentTier and EJ_GetCurrentTier()
      pcall(function()
        local n = 0
        for tier = EJ_GetNumTiers(), math.max(1, EJ_GetNumTiers() - 1), -1 do
          EJ_SelectTier(tier)
          local i = 1
          while i < 40 do
            local inst = EJ_GetInstanceByIndex(i, true); if not inst then break end
            EJ_SelectInstance(inst)
            local j = 1
            while j < 30 do
              local name, _, _, _, _, _, dEnc = EJ_GetEncounterInfoByIndex(j, inst); if not name then break end
              n = n + 1; if dEnc and not ejOrder[dEnc] then ejOrder[dEnc] = n end
              j = j + 1
            end
            i = i + 1
          end
        end
      end)
      if saved then pcall(EJ_SelectTier, saved) end
    end
  end
  local list = {}
  for enc, B in pairs(db.best) do
    local any = false
    for d in pairs(DIFF_SHORT) do if B[d] and next(B[d]) then any = true end end
    if any then list[#list + 1] = enc end
  end
  table.sort(list, function(a, b)
    local oa, ob = ejOrder[a], ejOrder[b]
    if oa and ob then return oa < ob end
    if oa or ob then return oa ~= nil end
    return a < b
  end)
  return list
end

local function chars()
  local me, list = charKey(), {}
  for k in pairs(db.chars) do if k ~= me then list[#list + 1] = k end end
  table.sort(list)
  table.insert(list, 1, me)
  return list
end

local CELL_W, ROW_H, NAME_W = 82, 22, 170
function X.Refresh()
  if not win or not win:IsShown() then return end
  for _, c in pairs(cells) do c:Hide() end
  for _, l in pairs(rowLbl) do l:Hide() end
  for _, l in pairs(colLbl) do l:Hide() end
  for _, b in ipairs(win.diffs) do b.sel = b.d == curDiff; b:SetBackdropBorderColor(unpack(b.sel and C.border or C.edge)); b.text:SetTextColor(unpack(b.sel and C.crystal or C.dim)) end
  local bosses, cs, me = bossOrder(), chars(), charKey()
  local body = win.body
  for j, k in ipairs(cs) do
    local l = colLbl[j] or fs(body, 12, C.text, "CENTER"); colLbl[j] = l
    l:ClearAllPoints(); l:SetPoint("TOPLEFT", body, "TOPLEFT", NAME_W + (j - 1) * CELL_W, 0); l:SetWidth(CELL_W - 4)
    local cls = db.chars[k] and db.chars[k].class
    local cc = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
    l:SetText((k == me and "> " or "") .. shortName(k))
    if cc then l:SetTextColor(cc.r, cc.g, cc.b) else l:SetTextColor(unpack(C.text)) end
    l:Show()
  end
  local shown = 0
  for i, enc in ipairs(bosses) do
    local B = db.best[enc]
    local row = B[curDiff]
    if row and next(row) then
      shown = shown + 1
      local y = -(18 + (shown - 1) * ROW_H)
      local rl = rowLbl[i] or fs(body, 12, C.text, "LEFT"); rowLbl[i] = rl
      rl:ClearAllPoints(); rl:SetPoint("TOPLEFT", body, "TOPLEFT", 0, y - 4); rl:SetWidth(NAME_W - 8); rl:SetWordWrap(false)
      rl:SetText(B.name or ("Boss " .. enc)); rl:Show()
      local top
      for _, r in pairs(row) do if not top or r.hps > top then top = r.hps end end
      for j, k in ipairs(cs) do
        local id = i .. ":" .. j
        local cell = cells[id]
        if not cell then
          cell = CreateFrame("Frame", nil, body, "BackdropTemplate")
          cell:SetSize(CELL_W - 4, ROW_H - 2); cell:SetBackdrop(ns.BACKDROP)
          cell.t = fs(cell, 12, C.text, "CENTER"); cell.t:SetPoint("CENTER")
          cell:EnableMouse(true)
          cell:SetScript("OnEnter", function(s)
            if not s.r then return end
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:AddLine(shortName(s.k) .. "  ·  " .. (s.boss or "?") .. " " .. (DIFF_SHORT[curDiff] or ""), 1, 1, 1)
            GameTooltip:AddDoubleLine("HPS", fmt(s.r.hps), 0.8, 0.8, 0.8, 1, 1, 1)
            GameTooltip:AddDoubleLine("Healing", fmt(s.r.total), 0.8, 0.8, 0.8, 1, 1, 1)
            GameTooltip:AddDoubleLine("Kill length", string.format("%d:%02d", math.floor(s.r.dur / 60), math.floor(s.r.dur % 60)), 0.8, 0.8, 0.8, 1, 1, 1)
            if s.r.spec then GameTooltip:AddDoubleLine("Spec", s.r.spec, 0.8, 0.8, 0.8, 1, 1, 1) end
            if s.r.ilvl then GameTooltip:AddDoubleLine("Item level", string.format("%.1f", s.r.ilvl), 0.8, 0.8, 0.8, 1, 1, 1) end
            GameTooltip:AddDoubleLine("When", date("%d %b %Y", s.r.when), 0.8, 0.8, 0.8, 1, 1, 1)
            if s.top and s.r.hps < s.top then GameTooltip:AddLine(string.format("%.0f%% of the best character's", s.r.hps / s.top * 100), 0.7, 0.7, 0.9) end
            GameTooltip:Show()
          end)
          cell:SetScript("OnLeave", GameTooltip_Hide)
          cells[id] = cell
        end
        local r = row[k]
        cell.r, cell.k, cell.boss, cell.top = r, k, B.name, top
        cell:ClearAllPoints(); cell:SetPoint("TOPLEFT", body, "TOPLEFT", NAME_W + (j - 1) * CELL_W, y)
        local isTop = r and r.hps >= top
        cell:SetBackdropColor(unpack(k == me and C.sel or C.panel))
        cell:SetBackdropBorderColor(unpack(isTop and C.border or C.edge))
        -- the best character on each boss is marked with a star as well as the border, not only by colour
        cell.t:SetText(r and ((isTop and #cs > 1 and "* " or "") .. fmt(r.hps)) or "-")
        cell.t:SetTextColor(unpack(r and (isTop and C.crystal or C.text) or C.faint))
        cell:Show()
      end
    end
  end
  win.empty:SetShown(shown == 0)
  win:SetSize(math.max(420, NAME_W + #cs * CELL_W + 36), math.max(180, 110 + shown * ROW_H))
end

local function build()
  win = CreateFrame("Frame", "RewoundExtraWindow", UIParent, "BackdropTemplate")
  win:SetFrameStrata("HIGH"); win:SetClampedToScreen(true); win:SetMovable(true); win:EnableMouse(true)
  win:RegisterForDrag("LeftButton"); win:SetScript("OnDragStart", win.StartMoving); win:SetScript("OnDragStop", win.StopMovingOrSizing)
  win:SetPoint("CENTER"); win:SetBackdrop(ns.BACKDROP)
  win:SetBackdropColor(unpack(C.bg)); win:SetBackdropBorderColor(unpack(C.border))
  tinsert(UISpecialFrames, "RewoundExtraWindow")
  local t = fs(win, 14, C.accent); t:SetFont(ns.FONT, 14, ""); t:SetPoint("TOPLEFT", 14, -12); t:SetText("Best HPS per boss · your characters")
  local close = button(win, "x", 22, function() win:Hide() end); close:SetPoint("TOPRIGHT", -8, -8)
  win.diffs = {}
  local prev
  for _, d in ipairs(DIFF) do
    local b = button(win, d[2], 64, function() curDiff = d[1]; X.Refresh() end)
    b.d = d[1]
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", 14, -36) end
    win.diffs[#win.diffs + 1] = b; prev = b
  end
  win.body = CreateFrame("Frame", nil, win)
  win.body:SetPoint("TOPLEFT", 14, -66); win.body:SetPoint("BOTTOMRIGHT", -14, 30)
  win.empty = fs(win.body, 12, C.dim); win.empty:SetPoint("TOPLEFT", 0, -24)
  win.empty:SetText("No kills recorded on this difficulty yet.\nKill a raid boss as a healer and your HPS is saved here.")
  local note = fs(win, 11, C.dim); note:SetPoint("BOTTOMLEFT", 14, 10)
  note:SetText("HPS = healing done / kill length. Healer specs only. * marks the best character on each boss.")
  win:SetScript("OnShow", X.Refresh)
  win:Hide()
end

function X.Open(diff)
  if not db then return end
  if not win then build() end
  if diff then curDiff = diff
  else
    local _, _, d = GetInstanceInfo()
    if DIFF_SHORT[d or 0] then curDiff = d end
  end
  if win:IsShown() then win:Hide() else win:Show() end
end

function X.Show(diff)
  if not db then return end
  if not win then build() end
  curDiff = diff or curDiff
  if win:IsShown() then X.Refresh() else win:Show() end
end

SLASH_REWOUNDX1 = "/rewoundx"
SlashCmdList.REWOUNDX = function(msg)
  msg = (msg or ""):lower()
  if msg == "lfr" then X.Open(17) elseif msg == "normal" or msg == "n" then X.Open(14)
  elseif msg == "heroic" or msg == "h" then X.Open(15) elseif msg == "mythic" or msg == "m" then X.Open(16)
  elseif msg == "toast" then db.toast = not db.toast; P("Boss-best toasts " .. (db.toast and "on." or "off."))
  elseif msg == "reset" then db.best, db.history = {}, {}; P("Boss bests cleared for all characters."); X.Refresh()
  else X.Open() end
end

---------------------------------------------------------------- Smiler settings tab ("Boss bests")
if Smiler and Smiler.RegisterSettings then
  Smiler:RegisterSettings("RewoundExtra", function(body, W)
    local A = W.Column(body, 0, 0, 290)
    A:Section("Boss bests")
    A:Switch("Alert on a new best", "A toast when you beat your HPS on a boss, or record a first kill", function() return db and db.toast ~= false end, function(v) db.toast = v end)
    A:Switch("Chat line after each kill", "Your HPS, your best and your best alt's", function() return db and db.chat ~= false end, function(v) db.chat = v end)
    A:Note("Open the window on:", "muted", 12)
    A:Buttons(nil, { { "LFR", function() X.Show(17) end, nil, 58 }, { "Normal", function() X.Show(14) end, nil, 62 },
                     { "Heroic", function() X.Show(15) end, "primary", 62 }, { "Mythic", function() X.Show(16) end, nil, 62 } })
    local B = W.Column(body, 334, 0, 290)
    B:Section("How it counts")
    B:Note("Healer specs only, kills only. HPS = your healing done / kill length, read from the game's damage meter after the fight.", "soft", 13)
    B:Note("Every character you heal on is saved; the window puts them side by side and marks the best one per boss with *.", "muted", 12)
    B:Buttons("Records", { { "Clear all boss bests", function() if db then db.best, db.history = {}, {}; P("Boss bests cleared for all characters."); if X.Refresh then X.Refresh() end end end, nil, 170 } })
    return { note = "/rewoundx · /rewoundx h (or lfr, n, m)", footer = {} }
  end)
end

if Smiler and Smiler.RegisterStatus then
  Smiler:RegisterStatus("rewoundextra", function()
    if not db then return end
    local me = charKey()
    local _, _, d = GetInstanceInfo()
    d = DIFF_SHORT[d or 0] and d or 15
    local n = 0
    for _, B in pairs(db.best) do if B[d] and B[d][me] then n = n + 1 end end
    if n > 0 then return string.format("%d boss best%s on %s", n, n == 1 and "" or "s", DIFF_SHORT[d]), "info" end
  end)
end
