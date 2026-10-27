-- DiedTo death window: list of deaths on the left, the selected death hit-by-hit on the right.
-- Midnight hides combat values from addon code during pulls and M+ runs, but labels, textures
-- and bars can still display them. So every value goes straight to the UI, and anything that
-- needs maths (totals, timings, overkill, sorting) only appears once the values are readable.

local _, ns = ...
local isSecret, safe, short = ns.isSecret, ns.safe, ns.short
local MELEE_ICON = 132147 -- Interface\Icons\INV_Sword_04

local deaths, known = {}, {}  -- deaths: { src="D"|"N"|"T", ref=..., addedAt=GetTime() }
local selected, listOffset, rowOffset, follow = nil, 0, 0, true
local mode = "time"   -- "time": hit by hit, oldest first · "hits": by ability, biggest single hit first
local win

---------------------------------------------------------------- secret-tolerant helpers
local function setText(fs, text)
  if not pcall(fs.SetText, fs, text) then fs:SetText("") end
end

local function cat(...) -- concatenation works on hidden values (the result is hidden too)
  local ok, s = pcall(function(...) local out = ""; for i = 1, select("#", ...) do local v = select(i, ...); if v ~= nil then out = out .. v end end; return out end, ...)
  return ok and s or ""
end

local function num(v)
  if v == nil then return "" end
  if not isSecret(v) then return short(v) end
  if AbbreviateLargeNumbers then
    local ok, s = pcall(AbbreviateLargeNumbers, v)
    if ok and s then return s end
  end
  local ok, s = pcall(tostring, v)
  return ok and s or ""
end

local function readable(...)
  for i = 1, select("#", ...) do if isSecret((select(i, ...))) then return false end end
  return true
end

local function isMelee(id) return id ~= nil and not isSecret(id) and (id == 1 or id == 6603) end

local function spellNameOf(e)
  if isMelee(e.id) then return "Melee" end
  if e.id ~= nil and C_Spell and C_Spell.GetSpellName then
    local ok, n = pcall(C_Spell.GetSpellName, e.id)
    if ok and n then return n end
  end
  return e.label or "?"
end

local function iconOf(e)
  if isMelee(e.id) then return MELEE_ICON end
  if e.id ~= nil and C_Spell and C_Spell.GetSpellTexture then
    local ok, t = pcall(C_Spell.GetSpellTexture, e.id)
    if ok and t then return t end
  end
  return 134400 -- question mark
end

local function classColor(class)
  local c = class and not isSecret(class) and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  return c and c.colorStr or "ffffffff"
end

---------------------------------------------------------------- collecting deaths
local function normDetails(d)
  local D = _G.Details
  local ok, name, class, _, combatTime, _, _, raw = pcall(D.UnpackDeathTable, D, d)
  if not ok then return nil end
  local events = {}
  for _, ev in ipairs(type(raw) == "table" and raw or {}) do
    if type(ev) == "table" then
      local flag = ev[1]
      local kind
      if isSecret(flag) then kind = "dmg"
      elseif flag == true then kind = "dmg" elseif flag == false then kind = "heal" elseif flag == 1 then kind = "cd" end
      if kind then
        events[#events + 1] = { kind = kind, id = ev[2], amount = ev[3], time = ev[4], hp = ev[5],
          source = ev[6], overkill = (kind == "dmg") and ev[10] or nil }
      end
    end
  end
  return { name = name, class = class, when = combatTime, events = events }
end

-- Blizzard recap events carry absolute health; turn it into a ratio when a max is known.
local function recapHP(ev, name)
  local cur = safe(ev.currentHP) or safe(ev.currentHealth)
  if type(cur) ~= "number" then return nil end
  local max = safe(ev.maxHP) or safe(ev.maxHealth)
  if type(max) ~= "number" and name and UnitHealthMax then
    local ok, m = pcall(UnitHealthMax, name)
    max = ok and safe(m) or nil
  end
  if type(max) == "number" and max > 0 then return cur / max end
end

-- Values captured mid-key stay hidden forever, so always re-read the death from the
-- current meter session by its recap ID (recap IDs are never hidden).
local sessionCache, sessionAt = nil, -1
local function freshSource(recapID)
  if GetTime() - sessionAt > 0.25 then
    sessionAt = GetTime()
    local st = Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Overall or 0
    local mt = Enum.DamageMeterType and Enum.DamageMeterType.Deaths or 9
    local ok, session = pcall(C_DamageMeter.GetCombatSessionFromType, st, mt)
    sessionCache = (ok and type(session) == "table") and session.combatSources or nil
  end
  for _, src in ipairs(sessionCache or {}) do
    if safe(src.deathRecapID) == recapID then return src end
  end
end

local function normNative(entry)
  local recapID = entry.id
  local src = freshSource(recapID) or entry.ref
  local events = {}
  local okE, raw = false, nil
  if recapID and C_DeathRecap then okE, raw = pcall(C_DeathRecap.GetRecapEvents, recapID) end
  raw = (okE and type(raw) == "table") and raw or {}
  -- Recap lists newest first (event 1 = killing blow); walk it backwards so rows read oldest to newest.
  for i = #raw, 1, -1 do
    local ev = raw[i]
    local e = safe(ev.event)
    events[#events + 1] = { kind = "dmg", id = ev.spellId or ev.spellID, amount = ev.amount, time = ev.timestamp,
      source = ev.sourceName, overkill = ev.overkill, hp = recapHP(ev, safe(src.name)),
      label = safe(ev.spellName) or ((type(e) == "string" and e:find("^SWING")) and "Melee") or nil }
  end
  return { name = src.name, class = src.classFilename, when = src.deathTimeSeconds, events = events, guid = src.sourceGUID }
end

local function load(entry)
  if entry.src == "D" then return normDetails(entry.ref)
  elseif entry.src == "N" then return normNative(entry)
  else return entry.ref end
end

-- Blizzard's damage meter is the primary source: on Midnight it holds every death of the run,
-- and its recap keeps ~10 events. Details is only used if the Blizzard meter is unavailable.
local nativeHasData = false
local firstSeen = {}
local function recapCount(id)
  if not (C_DeathRecap and C_DeathRecap.GetRecapEvents) then return 0 end
  local ok, raw = pcall(C_DeathRecap.GetRecapEvents, id)
  return (ok and type(raw) == "table") and #raw or 0
end
local function collectNative()
  if not (C_DamageMeter and C_DamageMeter.GetCombatSessionFromType and C_DeathRecap) then return nil end
  local st = Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Overall or 0
  local mt = Enum.DamageMeterType and Enum.DamageMeterType.Deaths or 9
  local ok, session = pcall(C_DamageMeter.GetCombatSessionFromType, st, mt)
  if not ok or type(session) ~= "table" or type(session.combatSources) ~= "table" then return nil end
  if #session.combatSources > 0 then nativeHasData = true end
  local new = {}
  for _, src in ipairs(session.combatSources) do
    local id = safe(src.deathRecapID)
    if id and not known["N" .. id] then
      -- a death whose recap has no hits (an old one) isn't worth listing; give a fresh one a few seconds
      if recapCount(id) > 0 then
        known["N" .. id] = true
        new[#new + 1] = { src = "N", ref = src, id = id, addedAt = GetTime() }
      else
        firstSeen[id] = firstSeen[id] or GetTime()
        if GetTime() - firstSeen[id] > 10 then known["N" .. id] = true end
      end
    end
  end
  table.sort(new, function(a, b) return a.id < b.id end) -- recap IDs count up, so this is death order
  for _, e in ipairs(new) do deaths[#deaths + 1] = e end
  return #new > 0
end

local function collect()
  local added = collectNative()
  -- Blizzard's meter can be empty (e.g. when it's switched off in favour of Details): then use Details
  if added then nativeHasData = true end
  if added ~= nil and (nativeHasData or not _G.Details) then
    while #deaths > 100 do table.remove(deaths, 1) end
    return added
  end
  added = false
  local D = _G.Details
  if D and D.GetCurrentCombat and D.UnpackDeathTable then
    local ok, combat = pcall(D.GetCurrentCombat, D)
    local ok2, list = false, nil
    if ok and combat and combat.GetDeaths then ok2, list = pcall(combat.GetDeaths, combat) end
    if ok2 and type(list) == "table" then
      for _, d in ipairs(list) do
        if type(d) == "table" and not known[d] then
          known[d] = true
          deaths[#deaths + 1] = { src = "D", ref = d, addedAt = GetTime() }
          added = true
        end
      end
    end
  elseif C_DamageMeter and C_DamageMeter.GetCombatSessionFromType then
    local st = Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Overall or 0
    local mt = Enum.DamageMeterType and Enum.DamageMeterType.Deaths or 9
    local ok, session = pcall(C_DamageMeter.GetCombatSessionFromType, st, mt)
    if ok and type(session) == "table" and type(session.combatSources) == "table" then
      for _, src in ipairs(session.combatSources) do
        local id = safe(src.deathRecapID)
        local key = id and ("N" .. id)
        if key and not known[key] then
          known[key] = true
          deaths[#deaths + 1] = { src = "N", ref = src, addedAt = GetTime() }
          added = true
        end
      end
    end
  end
  while #deaths > 100 do table.remove(deaths, 1) end
  return added
end

---------------------------------------------------------------- analysis (readable values only)
local function analyse(death)
  local dmg = {}
  for _, e in ipairs(death.events) do if e.kind == "dmg" then dmg[#dmg + 1] = e end end
  local info = { dmg = dmg, hidden = false }
  for _, e in ipairs(death.events) do
    if not readable(e.id, e.amount, e.time, e.hp, e.overkill) then info.hidden = true; break end
  end
  if not readable(death.name) then info.hidden = true end

  if not info.hidden then
    table.sort(death.events, function(a, b) return (a.time or 0) < (b.time or 0) end)
    dmg = {}
    for _, e in ipairs(death.events) do if e.kind == "dmg" then dmg[#dmg + 1] = e end end
    info.dmg = dmg
    for i = #dmg, 1, -1 do
      if type(dmg[i].overkill) == "number" and dmg[i].overkill > 0 then info.kb = dmg[i]; break end
    end
  end
  info.kb = info.kb or dmg[#dmg]

  if not info.hidden and #dmg > 0 then
    local by, order, total, first, last = {}, {}, 0, nil, nil
    for _, e in ipairs(dmg) do
      local key = e.id or e.label or "?"
      if not by[key] then by[key] = { e = e, amount = 0, n = 0, max = 0 }; order[#order + 1] = key end
      by[key].amount, by[key].n = by[key].amount + (e.amount or 0), by[key].n + 1
      if (e.amount or 0) > by[key].max then by[key].max = e.amount; by[key].maxE = e end
      total = total + (e.amount or 0)
      if e.time then first = first and math.min(first, e.time) or e.time; last = last and math.max(last, e.time) or e.time end
    end
    table.sort(order, function(a, b) return by[a].amount > by[b].amount end)
    info.by, info.order, info.total = by, order, total
    info.byMax = {}
    for i, k in ipairs(order) do info.byMax[i] = k end
    table.sort(info.byMax, function(a, b) return by[a].max > by[b].max end)
    info.span = (first and last and last > first) and (last - first) or nil
    info.avoid = death.avoid or ns.avoidableFor(death.guid and safe(death.guid) or ns.guidFor(death.name)) or {}
  end
  info.avoid = info.avoid or {}
  return info
end

-- Once a death's values are readable they don't change, so analyse once and keep it.
local function get(entry)
  if entry.cache then return entry.cache.d, entry.cache.info end
  local d = load(entry)
  if not d then return nil end
  local info = analyse(d)
  if not info.hidden then entry.cache = { d = d, info = info } end
  return d, info
end

---------------------------------------------------------------- UI: Crystal Ball (Stormchaser) styling
local T = {
  bg     = { 0.024, 0.012, 0.059 },  -- void #06030f
  card   = { 0.110, 0.063, 0.227 },
  panel  = { 0.133, 0.078, 0.275 },
  border = { 0.549, 0.314, 0.863 },  -- smoke purple, drawn at low alpha
  fg     = { 0.941, 0.922, 1.000 },  -- #f0ebff
  muted  = { 0.706, 0.627, 0.863 },
  amethyst = { 0.714, 0.431, 1.000 }, -- #b66eff
  diamond  = { 0.910, 0.957, 1.000 },
  emerald  = { 0.000, 0.902, 0.463 }, -- heals
  topaz    = { 1.000, 0.671, 0.000 }, -- damage
  ruby     = { 1.000, 0.176, 0.333 }, -- killing blow, avoidable, low health
  sapphire = { 0.361, 0.608, 1.000 }, -- cooldowns, interruptible
}
local function hex(c) return string.format("|cff%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5)) end
local C = {}
for k, v in pairs(T) do C[k] = hex(v) end
local BORDER_A = 0.38

local FONT_DIR = "Interface\\AddOns\\DiedTo\\Fonts\\"
local FONT_BODY = FONT_DIR .. "Barlow-Medium.ttf"
local FONT_HEAD = FONT_DIR .. "BarlowCondensed-SemiBold.ttf"

local TITLE_H, LIST_ROW_H, ROW_H, HEAD_H = 18, 24, 14, 32
local MIN_W, MIN_H = 240, 110
local fonts = {} -- { fs, face, delta } re-applied when text size changes

local function textSize() return (DiedToDB and DiedToDB.textSize) or 10 end

local function applyFont(f)
  local size = math.max(7, textSize() + f.delta)
  if not f.fs:SetFont(f.face, size, "") then f.fs:SetFont(STANDARD_TEXT_FONT, size, "") end
end

local function fs(parent, delta, color, head)
  local f = parent:CreateFontString(nil, "OVERLAY")
  local rec = { fs = f, face = head and FONT_HEAD or FONT_BODY, delta = delta or 0 }
  fonts[#fonts + 1] = rec; applyFont(rec)
  f:SetJustifyH("LEFT"); f:SetWordWrap(false)
  f:SetShadowColor(T.bg[1], T.bg[2], T.bg[3], 0.9); f:SetShadowOffset(1, -1)
  local c = color or T.fg
  f:SetTextColor(c[1], c[2], c[3], 1)
  return f
end

local function tex(parent, color, a, layer)
  local t = parent:CreateTexture(nil, layer or "ARTWORK")
  t:SetColorTexture(color[1], color[2], color[3], a or 1)
  return t
end

local function textButton(parent, label, onClick)
  local b = CreateFrame("Button", nil, parent)
  b.fs = fs(b, -1, T.muted, true); b.fs:SetPoint("CENTER"); b.fs:SetText(label)
  b:SetSize(math.max(14, b.fs:GetStringWidth() + 8), TITLE_H)
  b:SetScript("OnEnter", function() b.fs:SetTextColor(T.diamond[1], T.diamond[2], T.diamond[3]) end)
  b:SetScript("OnLeave", function() b.fs:SetTextColor(T.muted[1], T.muted[2], T.muted[3]) end)
  b:SetScript("OnClick", onClick)
  return b
end

local refresh, layout
local listRows, detailRows = {}, {}

local function savePos()
  if not (win and DiedToDB) then return end
  local x, y = win:GetLeft(), win:GetTop()
  DiedToDB.win = { x = x, y = y, w = win:GetWidth(), h = win:GetHeight() }
end

local function listWidth() return 0 end   -- compact: no list column; flick through deaths with < >

local function makeListRow(i)
  local b = CreateFrame("Button", nil, win)
  b:SetHeight(LIST_ROW_H)
  b.bg = tex(b, T.panel, 0, "BACKGROUND"); b.bg:SetAllPoints()
  b.mark = tex(b, T.amethyst, 1); b.mark:SetPoint("TOPLEFT"); b.mark:SetPoint("BOTTOMLEFT"); b.mark:SetWidth(2)
  b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(14, 14); b.icon:SetPoint("LEFT", 6, 0)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.name = fs(b, 0); b.name:SetPoint("TOPLEFT", 25, -3); b.name:SetPoint("RIGHT", -4, 0)
  b.sub = fs(b, -1, T.muted); b.sub:SetPoint("TOPLEFT", 25, -13); b.sub:SetPoint("RIGHT", -4, 0)
  b:SetScript("OnClick", function(self) selected = self.index; follow = (selected == #deaths); rowOffset = 0; refresh() end)
  b:SetScript("OnEnter", function(self) if self.index ~= selected then self.bg:SetAlpha(0.5) end end)
  b:SetScript("OnLeave", function(self) if self.index ~= selected then self.bg:SetAlpha(0) end end)
  listRows[i] = b
  return b
end

local function makeDetailRow(i)
  local r = CreateFrame("Frame", nil, win)
  r:SetHeight(ROW_H); r:EnableMouse(true)
  -- health at the time of the hit, drawn as a faint fill behind the row
  r.hp = CreateFrame("StatusBar", nil, r); r.hp:SetAllPoints(); r.hp:SetFrameLevel(r:GetFrameLevel())
  r.hp:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8"); r.hp:SetMinMaxValues(0, 1); r.hp:SetAlpha(0.13)
  r.hover = tex(r, T.diamond, 0, "BACKGROUND"); r.hover:SetAllPoints()
  r.flag = tex(r, T.ruby, 0.10, "BACKGROUND"); r.flag:SetAllPoints(); r.flag:Hide()
  r.mark = tex(r, T.ruby, 1); r.mark:SetPoint("TOPLEFT"); r.mark:SetPoint("BOTTOMLEFT"); r.mark:SetWidth(2)
  r.time = fs(r, -1, T.muted); r.time:SetPoint("LEFT", 2, 0); r.time:SetWidth(34); r.time:SetJustifyH("RIGHT")
  r.pct = fs(r, -1, T.muted); r.pct:SetPoint("LEFT", 38, 0); r.pct:SetWidth(28); r.pct:SetJustifyH("RIGHT")
  r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(12, 12); r.icon:SetPoint("LEFT", 72, 0)
  r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.spell = fs(r, 0); r.spell:SetPoint("LEFT", 88, 0)
  r.amount = fs(r, 0); r.amount:SetJustifyH("RIGHT"); r.amount:SetWidth(52)
  r.src = fs(r, -1, T.muted); r.src:SetPoint("RIGHT", -4, 0); r.src:SetJustifyH("RIGHT")
  r:SetScript("OnEnter", function(self)
    self.hover:SetAlpha(0.05)
    local id = self.e and self.e.id
    if id ~= nil and not isSecret(id) and not isMelee(id) then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      if not pcall(GameTooltip.SetSpellByID, GameTooltip, id) then GameTooltip:Hide() return end
      GameTooltip:AddLine("Alt-click: Wowhead link", T.muted[1], T.muted[2], T.muted[3])
      GameTooltip:Show()
    end
  end)
  r:SetScript("OnLeave", function(self) self.hover:SetAlpha(0); GameTooltip:Hide() end)
  r:SetScript("OnMouseUp", function(self)
    if IsAltKeyDown() and self.e and type(safe(self.e.id)) == "number" and not isMelee(self.e.id) then ns.showURL(self.e.id) end
  end)
  detailRows[i] = r
  return r
end

local function build()
  win = CreateFrame("Frame", "DiedToDeaths", UIParent, "BackdropTemplate")
  win:SetFrameStrata("MEDIUM"); win:SetClampedToScreen(true)
  win:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
  win:SetBackdropColor(T.bg[1], T.bg[2], T.bg[3], (DiedToDB and DiedToDB.bgAlpha) or 0.45)
  win:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], BORDER_A)
  win:SetMovable(true); win:SetResizable(true); win:EnableMouse(true)
  if win.SetResizeBounds then win:SetResizeBounds(MIN_W, MIN_H, 1400, 1000) elseif win.SetMinResize then win:SetMinResize(MIN_W, MIN_H) end
  local p = DiedToDB and DiedToDB.win
  if p and p.x and p.y then
    if not DiedToDB.compact then   -- 0.9: the window got much smaller; shrink an old saved size once
      DiedToDB.compact = true
      p.w, p.h = math.min(p.w or 320, 320), math.min(p.h or 180, 180)
    end
    win:SetSize(math.max(MIN_W, p.w or 320), math.max(MIN_H, p.h or 180))
    win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.x, p.y)
  else
    DiedToDB.compact = true
    win:SetSize(320, 180); win:SetPoint("CENTER", 0, 160)
  end
  tinsert(UISpecialFrames, "DiedToDeaths")

  -- title bar (drag handle)
  local bar = CreateFrame("Frame", nil, win)
  bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT"); bar:SetHeight(TITLE_H)
  bar:EnableMouse(true); bar:RegisterForDrag("LeftButton")
  bar:SetScript("OnDragStart", function() win:StartMoving() end)
  bar:SetScript("OnDragStop", function() win:StopMovingOrSizing(); savePos() end)
  local rule = tex(win, T.amethyst, 0.55); rule:SetHeight(1)
  rule:SetPoint("TOPLEFT", 1, -TITLE_H); rule:SetPoint("TOPRIGHT", -1, -TITLE_H)
  local title = fs(bar, 1, T.amethyst, true); title:SetPoint("LEFT", 8, 0); title:SetText("DEATHS")
  local prev = textButton(bar, "<", function()
    if selected and selected > 1 then selected = selected - 1; follow = false; rowOffset = 0; refresh() end
  end)
  prev:SetPoint("LEFT", title, "RIGHT", 8, 0)
  win.count = fs(bar, -1, T.fg); win.count:SetPoint("LEFT", prev, "RIGHT", 2, 0)
  local nxt = textButton(bar, ">", function()
    if selected and selected < #deaths then selected = selected + 1; follow = (selected == #deaths); rowOffset = 0; refresh() end
  end)
  nxt:SetPoint("LEFT", win.count, "RIGHT", 2, 0)
  win.modeTime = textButton(bar, "time", function() mode = "time"; rowOffset = 0; refresh() end)
  win.modeHits = textButton(bar, "hits", function() mode = "hits"; rowOffset = 0; refresh() end)
  win.modeTime:SetPoint("LEFT", nxt, "RIGHT", 8, 0)
  win.modeHits:SetPoint("LEFT", win.modeTime, "RIGHT", 4, 0)
  local close = textButton(bar, "x", function() win:Hide() end); close:SetPoint("RIGHT", -2, 0)
  local settings = textButton(bar, "opts", function() ns.openSettings() end); settings:SetPoint("RIGHT", close, "LEFT", -2, 0)
  local clear = textButton(bar, "clear", function() wipe(deaths); selected = nil; rowOffset = 0; refresh() end)
  clear:SetPoint("RIGHT", settings, "LEFT", -2, 0)

  win.div = tex(win, T.border, BORDER_A); win.div:SetWidth(1)

  -- detail header
  win.h1 = fs(win, 2, T.fg, true)
  win.h2 = fs(win, -1, T.fg)
  win.h3 = fs(win, -1, T.muted)
  win.more = fs(win, -2, T.muted)

  -- resize grip
  local grip = CreateFrame("Button", nil, win)
  grip:SetSize(12, 12); grip:SetPoint("BOTTOMRIGHT", -1, 1)
  for i = 0, 2 do
    local d = tex(grip, T.amethyst, 0.6); d:SetSize(2, 2); d:SetPoint("BOTTOMRIGHT", -2 - i * 3, 2)
    if i < 2 then local e = tex(grip, T.amethyst, 0.6); e:SetSize(2, 2); e:SetPoint("BOTTOMRIGHT", -2, 2 + (i + 1) * 3) end
  end
  local mid = tex(grip, T.amethyst, 0.6); mid:SetSize(2, 2); mid:SetPoint("BOTTOMRIGHT", -5, 5)
  grip:SetScript("OnMouseDown", function() win:StartSizing("BOTTOMRIGHT") end)
  grip:SetScript("OnMouseUp", function() win:StopMovingOrSizing(); savePos() end)
  win:SetScript("OnSizeChanged", function() if layout then layout(); refresh() end end)

  win:EnableMouseWheel(true)
  win:SetScript("OnMouseWheel", function(self, delta)
    local y = select(2, GetCursorPosition()) / self:GetEffectiveScale()
    if y > self:GetTop() - TITLE_H then
      if #deaths > 0 then
        selected = math.max(1, math.min(#deaths, (selected or #deaths) - delta)); follow = (selected == #deaths); rowOffset = 0
      end
    elseif false then
      listOffset = math.max(0, math.min(math.max(0, #deaths - #listRows), listOffset - delta)); follow = false
    else
      rowOffset = math.max(0, rowOffset + (mode == "hits" and -delta or delta))
    end
    refresh()
  end)

  local t = 0
  win:SetScript("OnUpdate", function(_, el)   -- redraw only; the watcher below does the collecting
    t = t + el
    if t < 1 then return end
    t = 0
    refresh()
  end)
  layout()
  win:Hide()
end

layout = function()
  local w, h = win:GetWidth(), win:GetHeight()
  local lw = listWidth()
  win.div:ClearAllPoints(); win.div:SetPoint("TOPLEFT", lw, -TITLE_H - 1); win.div:SetPoint("BOTTOMLEFT", lw, 1)

  win.div:Hide()
  local nList = 0
  for i = 1, #listRows do
    local b = listRows[i] or makeListRow(i)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", 1, -TITLE_H - 3 - (i - 1) * LIST_ROW_H); b:SetWidth(lw - 2)
    b.active = i <= nList
    if not b.active then b:Hide() end
  end
  win.nList = nList

  local x0, rw = 7, w - 12
  win.h1:ClearAllPoints(); win.h1:SetPoint("TOPLEFT", x0, -TITLE_H - 6); win.h1:SetWidth(rw)
  win.h2:ClearAllPoints(); win.h2:SetPoint("TOPLEFT", x0, -TITLE_H - 19); win.h2:SetWidth(rw)
  win.h3:ClearAllPoints(); win.h3:SetPoint("TOPLEFT", x0, -TITLE_H - 35); win.h3:SetWidth(rw); win.h3:Hide()
  win.more:ClearAllPoints(); win.more:SetPoint("BOTTOMLEFT", x0, 3); win.more:SetWidth(rw - 14)

  local top = TITLE_H + HEAD_H + 4
  local nRows = math.max(1, math.floor((h - top - 14) / (ROW_H + 1)))
  local srcW = rw >= 360 and math.floor(rw * 0.26) or 1   -- source column only when there's room
  for i = 1, math.max(nRows, #detailRows) do
    local r = detailRows[i] or makeDetailRow(i)
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", x0 - 4, -top - (i - 1) * (ROW_H + 1)); r:SetWidth(rw + 4)
    r.src:SetWidth(srcW); r.src:SetAlpha(srcW > 1 and 1 or 0)
    r.amount:ClearAllPoints(); r.amount:SetPoint("RIGHT", r.src, "LEFT", -6, 0)
    r.spell:SetPoint("RIGHT", r.amount, "LEFT", -4, 0)
    r.active = i <= nRows
    if not r.active then r:Hide() end
  end
  win.nRows = nRows
end

local function hpColor(bar, hp)
  if hp == nil or isSecret(hp) then bar:SetStatusBarColor(T.amethyst[1], T.amethyst[2], T.amethyst[3]); return end
  local c = (hp < 0.3 and T.ruby) or (hp < 0.6 and T.topaz) or T.emerald
  bar:SetStatusBarColor(c[1], c[2], c[3])
end

local function shortName(n)
  if n == nil or isSecret(n) then return n end
  return (n:gsub("%-.*$", "")) -- drop realm
end

refresh = function()
  if not win or not win:IsShown() then return end
  win.count:SetText(#deaths == 0 and "none yet" or ((selected or #deaths) .. " of " .. #deaths))
  local onC, offC = T.diamond, T.muted
  win.modeTime.fs:SetTextColor(unpack(mode == "time" and onC or offC))
  win.modeHits.fs:SetTextColor(unpack(mode == "hits" and onC or offC))
  if selected and selected > #deaths then selected = #deaths end
  if not selected and #deaths > 0 then selected = #deaths end
  if follow then listOffset = math.max(0, #deaths - win.nList) end
  listOffset = math.max(0, math.min(listOffset, math.max(0, #deaths - win.nList)))

  for i = 1, win.nList do
    local b, idx = listRows[i], listOffset + i
    local entry = deaths[idx]
    b.index = idx
    if entry then
      local d, info = get(entry)
      local kb = info and info.kb
      setText(b.name, cat("|c", classColor(d and d.class), shortName(d and d.name) or "?", "|r"))
      setText(b.sub, kb and cat(spellNameOf(kb)) or "no damage logged")
      if kb then pcall(b.icon.SetTexture, b.icon, iconOf(kb)) else b.icon:SetTexture(134400) end
      local sel = (idx == selected)
      b.bg:SetAlpha(sel and 1 or 0); b.mark:SetShown(sel)
      b:Show()
    else
      b:Hide()
    end
  end

  for i = 1, #detailRows do detailRows[i]:Hide(); detailRows[i].e = nil; detailRows[i].flag:Hide() end
  win.more:SetText("")
  local entry = selected and deaths[selected]
  local d, info
  if entry then d, info = get(entry) end
  if not d then
    win.h1:SetText(#deaths == 0 and (C.muted .. "No deaths yet|r") or "")
    win.h2:SetText(#deaths == 0 and (C.muted .. "They appear here as they happen.|r") or ""); win.h3:SetText("")
    return
  end
  local kb = info.kb
  local function avoid(e)
    if not e or e.id == nil or isSecret(e.id) then return "" end
    return ((info.avoid[e.id]) and ("  " .. C.ruby .. "AVOIDABLE|r") or "") ..
           (ns.isKickable and ns.isKickable(e.id) and ("  " .. C.sapphire .. "INTERRUPTIBLE|r") or "")
  end

  -- header 1: who died to what
  local who = cat("|c", classColor(d.class), shortName(d.name) or "?", "|r")
  if kb then
    local over = ""
    if not info.hidden and type(kb.overkill) == "number" and kb.overkill > 0 then over = "  " .. C.ruby .. short(kb.overkill) .. " over|r" end
    setText(win.h1, cat(who, C.muted, "  died to  |r", C.diamond, spellNameOf(kb), "|r", avoid(kb), "  ", C.topaz, num(kb.amount), "|r", over))
  else
    setText(win.h1, cat(who, C.muted, "  died|r"))
  end

  -- header 2: damage taken by ability; header 3: totals
  if info.hidden then
    win.h2:SetText(C.amethyst .. "Values hidden until the pull or key ends|r")
    win.h3:SetText("Totals, timings and overkill fill in afterwards.")
  elseif info.order and #info.order > 0 then
    local parts = {}
    for i = 1, math.min(4, #info.order) do
      local b = info.by[info.order[i]]
      parts[i] = spellNameOf(b.e) .. " " .. C.topaz .. short(b.amount) .. "|r" .. (b.n > 1 and (C.muted .. " x" .. b.n .. "|r") or "") .. avoid(b.e)
    end
    if #info.order > 4 then parts[#parts + 1] = C.muted .. "+" .. (#info.order - 4) .. "|r" end
    win.h2:SetText(table.concat(parts, C.muted .. "  ·  |r"))
    local when = ns.clock(d.when)
    setText(win.h3, cat(short(info.total), " in ", #info.dmg, " hits", info.span and string.format(" over %.1fs", info.span) or "",
      kb and kb.source and "  ·  " or "", kb and kb.source or "", when and ("  ·  " .. when .. " into the fight") or ""))
  else
    win.h2:SetText(""); win.h3:SetText("")
  end

  if mode == "hits" then
    local n = win.nRows
    if info.hidden or not info.byMax then
      win.more:SetText("Biggest hits fill in once the pull or key ends.")
      return
    end
    local keys = info.byMax
    rowOffset = math.min(rowOffset, math.max(0, #keys - n))
    for i = 1, n do
      local k, r = keys[rowOffset + i], detailRows[i]
      if k then
        local b = info.by[k]
        r.e = b.maxE or b.e
        r.mark:SetShown(kb and (b.e.id == kb.id))
        r.time:SetText(b.n > 1 and ("x" .. b.n) or "")
        r.pct:SetText("")
        r.hp:Hide()
        pcall(r.icon.SetTexture, r.icon, iconOf(b.e))
        setText(r.spell, cat(spellNameOf(b.e), avoid(b.e)))
        setText(r.amount, cat(C.topaz, short(b.max), "|r"))
        setText(r.src, cat(C.muted, "total ", "|r", short(b.amount)))
        r:Show()
      end
    end
    win.more:SetText(#keys > n and string.format("%d of %d abilities · scroll for more", math.min(n, #keys - rowOffset), #keys) or
      "sorted by biggest single hit · x = number of hits")
    return
  end

  -- rows: oldest at the top, killing blow at the bottom; wheel scrolls back in time
  local list = {}
  for _, e in ipairs(d.events) do if e.kind == "dmg" or DiedToDB.showHeals then list[#list + 1] = e end end
  local n = win.nRows
  rowOffset = math.min(rowOffset, math.max(0, #list - n))
  local first = math.max(1, #list - n + 1 - rowOffset)
  local t0 = (not info.hidden and kb) and kb.time or nil
  for i = 1, n do
    local e, r = list[first + i - 1], detailRows[i]
    if e then
      r.e = e
      r.mark:SetShown(e == kb)
      r.time:SetText((t0 and type(e.time) == "number") and string.format("%.1f", e.time - t0) or "")
      if e.hp ~= nil then
        r.hp:Show(); pcall(r.hp.SetValue, r.hp, e.hp); hpColor(r.hp, e.hp)
        r.pct:SetText(isSecret(e.hp) and "" or string.format("%d%%", math.floor(math.max(0, math.min(1, e.hp)) * 100 + 0.5)))
      else
        r.hp:Hide(); r.pct:SetText("")
      end
      pcall(r.icon.SetTexture, r.icon, iconOf(e))
      if e.kind == "cd" then
        setText(r.spell, cat(C.sapphire, spellNameOf(e), "|r")); r.amount:SetText(C.sapphire .. "used|r")
      elseif e.kind == "heal" then
        setText(r.spell, cat(C.emerald, spellNameOf(e), "|r")); setText(r.amount, cat(C.emerald, "+", num(e.amount), "|r"))
      else
        setText(r.spell, cat(spellNameOf(e), avoid(e)))
        local flagged = e.id ~= nil and not isSecret(e.id) and (info.avoid[e.id] or (ns.isKickable and ns.isKickable(e.id)))
        r.flag:SetShown(flagged and true or false)
        if flagged then local c = info.avoid[e.id] and T.ruby or T.sapphire; r.flag:SetColorTexture(c[1], c[2], c[3], 0.10) end
        setText(r.amount, cat(e == kb and C.ruby or C.topaz, num(e.amount), "|r"))
      end
      setText(r.src, cat(shortName(e.source) or ""))
      r:Show()
    end
  end
  if #list > n then
    win.more:SetText(string.format("%d–%d of %d  ·  scroll for earlier", first, first + n - 1, #list))
  elseif #list == 0 then
    win.more:SetText("no events logged")
  end
end

function ns.applyBg()
  if win then win:SetBackdropColor(T.bg[1], T.bg[2], T.bg[3], (DiedToDB and DiedToDB.bgAlpha) or 0.45) end
end

function ns.applyTextSize()
  for _, f in ipairs(fonts) do applyFont(f) end
  if win then layout(); refresh() end
end

---------------------------------------------------------------- public
function ns.toggleDeaths(forceShow)
  if not win then build() end
  if forceShow or not win:IsShown() then
    collect(); follow = true; selected = #deaths > 0 and #deaths or nil; rowOffset = 0
    win:Show(); refresh()
  else
    win:Hide()
  end
end

function ns.addTestDeath()
  if not win then build() end
  deaths[#deaths + 1] = { src = "T", ref = ns.testDeathRaw(), addedAt = GetTime() }
  follow, selected, rowOffset = true, #deaths, 0
  win:Show(); refresh()
end

-- The one place deaths are collected (window and chat reports share it).
-- Once a second in groups and instances, every 4 seconds solo in the open world.
function ns.tick()
  if not DiedToDB then return end
  local added = collect()
  if added then
    if win and win:IsShown() then
      if follow then selected = #deaths; rowOffset = 0 end
      refresh()
    elseif DiedToDB.autoOpen then
      if not win then build() end
      follow, selected, rowOffset = true, #deaths, 0
      win:Show(); refresh()
    end
  end
  if ns.reportNew then ns.reportNew() end
end
ns.deathList, ns.getDeath = deaths, get

local watcher = CreateFrame("Frame")
local acc, ready = 0, false
watcher:SetScript("OnUpdate", function(_, el)
  acc = acc + el
  if not ready then return end
  local busy = IsInGroup() or IsInInstance()
  if acc < (busy and 1 or 4) then return end
  acc = 0
  ns.tick()
end)
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:SetScript("OnEvent", function()
  -- deaths already in Details' current segment at login are listed but don't pop the window
  C_Timer.After(2.5, function()
    collect()
    if ns.markReported then ns.markReported() end   -- deaths from before login aren't reported again
    ready = true
  end)
end)
