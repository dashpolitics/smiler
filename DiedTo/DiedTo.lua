-- DiedTo: death reports in chat — killing blow, damage by ability, and a hit-by-hit timeline.
-- Primary source: Details! death logs. Fallback: Blizzard damage meter Deaths view + C_DeathRecap.
-- Midnight makes combat values secret during pulls; anything secret is retried after the pull.

local _, ns = ...
local PREFIX = "|cffb48cff[DiedTo]|r "
local INDENT = "     "
local frame = CreateFrame("Frame")
local seen, attempts = {}, {}
local lastDump
local MAX_ATTEMPTS = 3
local DEFAULTS = {
  enabled = true, frame = 1, output = "self", groupMax = 5, alsoSelf = false,
  timeline = true, showHeals = true, rows = 16, logLimit = 16, autoOpen = true, textSize = 10,
}

local isSecret = issecretvalue or function() return false end
local function safe(v)
  if v == nil or isSecret(v) then return nil end
  return v
end

-- AddMessage only draws text in your own client; nothing is sent to other players.
local function outFrame()
  local f = DiedToDB and DiedToDB.frame and _G["ChatFrame" .. DiedToDB.frame]
  return f or DEFAULT_CHAT_FRAME
end
local function say(msg, noPrefix) outFrame():AddMessage((noPrefix and "" or PREFIX) .. msg) end

local function short(n)
  n = safe(n)
  if type(n) ~= "number" then return "?" end
  n = math.abs(n)
  if n >= 1e6 then return string.format("%.1fm", n / 1e6) end
  if n >= 1e3 then return string.format("%.1fk", n / 1e3) end
  return tostring(math.floor(n))
end

local function clock(sec)
  sec = safe(sec)
  if type(sec) ~= "number" or sec < 0 or sec > 6 * 3600 then return nil end
  return string.format("%d:%02d", math.floor(sec / 60), math.floor(sec % 60))
end

local function colorName(name, classFile)
  if type(classFile) == "string" and C_ClassColor and C_ClassColor.GetClassColor then
    local c = C_ClassColor.GetClassColor(classFile)
    if c then return c:WrapTextInColorCode(name) end
  end
  return name
end

local function isMelee(id) return id == 1 or id == 6603 end

-- Spell link where possible (hover = tooltip, Alt-click = Wowhead copy box).
local function spellText(id, fallback)
  id = safe(id)
  if type(id) == "number" then
    if isMelee(id) then return "Melee" end
    if C_Spell and C_Spell.GetSpellLink then
      local link = C_Spell.GetSpellLink(id)
      if link then return link end
    end
    local n = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
    if n then return n end
  end
  return fallback or "?"
end

---------------------------------------------------------------- avoidable damage
-- Blizzard's damage meter classifies avoidable damage per spell. Readable outside combat only.
local function avoidableFor(guid)
  if not (guid and C_DamageMeter and C_DamageMeter.GetCombatSessionSourceFromType) then return nil end
  local st = Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Overall or 0
  local mt = Enum.DamageMeterType and Enum.DamageMeterType.AvoidableDamageTaken or 8
  local ok, src = pcall(C_DamageMeter.GetCombatSessionSourceFromType, st, mt, guid)
  if not ok or type(src) ~= "table" or type(src.combatSpells) ~= "table" then return nil end
  local set = {}
  for _, sp in ipairs(src.combatSpells) do
    local id = safe(sp.spellID)
    if id then set[id] = true end
  end
  return set
end

local function guidFor(name)
  if not name then return nil end
  local ok, g = pcall(UnitGUID, name)
  return ok and safe(g) or nil
end

---------------------------------------------------------------- rendering
-- death = { name, class, when, events = { {kind="dmg"|"heal"|"cd", id, label, amount, time, hp, source, overkill} } }
local AVOID = " |cffff5050AVOIDABLE|r"
local KICK = " |cff5c9bffINTERRUPTIBLE|r"

---------------------------------------------------------------- interruptible casts
-- No game API says whether a spell can be interrupted, so DiedTo learns it: whenever an enemy starts
-- casting and the game lets us read the cast, it remembers whether that spell was interruptible.
-- The list is saved, so it fills in as you play (it can't learn casts the game keeps hidden).
function ns.isKickable(id)
  id = safe(id)
  return id ~= nil and DiedToDB and DiedToDB.kicks and DiedToDB.kicks[id] == true
end

local castWatch = CreateFrame("Frame")
castWatch:RegisterEvent("UNIT_SPELLCAST_START")
castWatch:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
castWatch:SetScript("OnEvent", function(_, event, unit)
  if not DiedToDB or type(unit) ~= "string" then return end
  if not (unit:find("^nameplate") or unit:find("^boss") or unit == "target" or unit == "focus") then return end
  local r = { pcall(event == "UNIT_SPELLCAST_START" and UnitCastingInfo or UnitChannelInfo, unit) }
  if not r[1] then return end
  -- UnitCastingInfo: …, castID, notInterruptible, spellID · UnitChannelInfo: …, notInterruptible, spellID
  local notInt, id
  if event == "UNIT_SPELLCAST_START" then notInt, id = r[9], r[10] else notInt, id = r[8], r[9] end
  id, notInt = safe(id), safe(notInt)
  if type(id) ~= "number" or notInt == nil then return end
  DiedToDB.kicks = DiedToDB.kicks or {}
  if not notInt then DiedToDB.kicks[id] = true          -- seen interruptible once: it's interruptible
  elseif DiedToDB.kicks[id] == nil then DiedToDB.kicks[id] = false end
end)

local function render(death, force)
  local events = death.events
  local dmg = {}
  for _, e in ipairs(events) do if e.kind == "dmg" then dmg[#dmg + 1] = e end end
  local who = colorName(death.name, death.class)
  local whenTxt = clock(death.when)
  local head = (whenTxt and ("|cff888888" .. whenTxt .. "|r ") or "") .. who
  if #dmg == 0 then
    if not force then return nil end
    return { head .. " died |cff888888(no damage logged)|r" }, { (head .. " died (no damage logged)") }
  end

  local kb
  for i = #dmg, 1, -1 do if dmg[i].overkill and dmg[i].overkill > 0 then kb = dmg[i]; break end end
  kb = kb or dmg[#dmg]
  if not (kb.id or kb.label) and not force then return nil end
  local avoid = death.avoid or {}
  local function tag(id) return ((id and avoid[id]) and AVOID or "") .. (ns.isKickable(id) and KICK or "") end

  -- Line 1: killing blow
  local l1 = head .. " died to " .. spellText(kb.id, kb.label) .. tag(kb.id)
  if kb.source and kb.source ~= "" then l1 = l1 .. " |cff888888(" .. kb.source .. ")|r" end
  l1 = l1 .. " " .. short(kb.amount)
  if kb.overkill and kb.overkill > 0 then l1 = l1 .. " |cffff9b9b(" .. short(kb.overkill) .. " overkill)|r" end

  -- Line 2: damage by ability over the whole logged window
  local by, order, total, first, last = {}, {}, 0, nil, nil
  for _, e in ipairs(dmg) do
    local key = e.id or e.label or "?"
    if not by[key] then by[key] = { id = e.id, label = e.label, amount = 0, n = 0 }; order[#order + 1] = key end
    by[key].amount, by[key].n = by[key].amount + e.amount, by[key].n + 1
    total = total + e.amount
    if e.time then first = first and math.min(first, e.time) or e.time; last = last and math.max(last, e.time) or e.time end
  end
  table.sort(order, function(a, b) return by[a].amount > by[b].amount end)
  local parts = {}
  for i = 1, math.min(5, #order) do
    local b = by[order[i]]
    parts[i] = spellText(b.id, b.label) .. " " .. short(b.amount) .. (b.n > 1 and ("|cff888888 x" .. b.n .. "|r") or "") .. tag(b.id)
  end
  if #order > 5 then parts[#parts + 1] = "|cff888888+" .. (#order - 5) .. " more|r" end
  local span = (first and last and last > first) and string.format(" in %.1fs", last - first) or ""
  local l2 = INDENT .. "|cff888888taken:|r " .. table.concat(parts, "|cff888888 · |r") ..
    " |cff888888= " .. short(total) .. " from " .. #dmg .. " hits" .. span .. "|r"

  local localLines, groupLines = { l1, l2 }, { l1, l2 }

  -- Rows: hit-by-hit timeline, oldest first, relative to the killing blow
  if DiedToDB.timeline then
    local rows = {}
    for _, e in ipairs(events) do
      if e.kind == "dmg" or DiedToDB.showHeals then rows[#rows + 1] = e end
    end
    local maxRows = DiedToDB.rows
    local startAt = math.max(1, #rows - maxRows + 1)
    if startAt > 1 then
      localLines[#localLines + 1] = INDENT .. "|cff666666… " .. (startAt - 1) .. " earlier events not shown (raise Timeline rows)|r"
    end
    local t0 = kb.time
    for i = startAt, #rows do
      local e = rows[i]
      local t = (e.time and t0) and string.format("%+5.1fs", e.time - t0) or "     "
      local hp = e.hp and string.format("%3d%%", math.floor(math.max(0, math.min(1, e.hp)) * 100 + 0.5)) or "    "
      local hpColor = (e.hp and e.hp < 0.3) and "|cffff7070" or "|cffaaaaaa"
      local body
      if e.kind == "dmg" then
        body = spellText(e.id, e.label) .. " |cffff9b9b-" .. short(e.amount) .. "|r" .. tag(e.id)
        if e.overkill and e.overkill > 0 then body = body .. " |cffff5050(" .. short(e.overkill) .. " overkill)|r" end
      elseif e.kind == "heal" then
        body = "|cff60ff80+" .. short(e.amount) .. "|r " .. spellText(e.id, e.label)
      else
        body = "|cff7fd1ffused|r " .. spellText(e.id, e.label)
      end
      local src = (e.source and e.source ~= "") and (" |cff888888" .. e.source .. "|r") or ""
      localLines[#localLines + 1] = INDENT .. "|cff666666" .. t .. "|r  " .. hpColor .. hp .. "|r  " .. body .. src
    end
  end
  return localLines, groupLines
end

---------------------------------------------------------------- Details source
-- Details death-log event: [1] true=damage / false=heal / 1=cooldown, [2] spellId, [3] amount,
-- [4] time, [5] health ratio, [6] source, [10] overkill
local function detailsEvents(raw)
  local events = {}
  for _, ev in ipairs(type(raw) == "table" and raw or {}) do
    if type(ev) == "table" then
      local kindFlag = safe(ev[1])
      local kind = (kindFlag == true and "dmg") or (kindFlag == false and "heal") or (kindFlag == 1 and "cd") or nil
      local amt = safe(ev[3])
      if kind and (kind == "cd" or (type(amt) == "number" and amt > 0)) then
        local over, hp = safe(ev[10]), safe(ev[5])
        events[#events + 1] = {
          kind = kind, id = safe(ev[2]), amount = type(amt) == "number" and amt or 0,
          time = safe(ev[4]), hp = type(hp) == "number" and hp or nil, source = safe(ev[6]),
          overkill = (kind == "dmg" and type(over) == "number") and over or nil,
        }
      end
    end
  end
  table.sort(events, function(a, b) return (a.time or 0) < (b.time or 0) end)
  return events
end

local function detailsDeaths()
  local D = _G.Details
  if not (D and D.GetCurrentCombat and D.UnpackDeathTable) then return nil end
  local ok, combat = pcall(D.GetCurrentCombat, D)
  if not ok or not combat or not combat.GetDeaths then return nil end
  local ok2, deaths = pcall(combat.GetDeaths, combat)
  if not ok2 or type(deaths) ~= "table" then return nil end
  local out = {}
  for _, d in ipairs(deaths) do
    local ok3, name, class, deathTime, combatTime, _, _, raw = pcall(D.UnpackDeathTable, D, d)
    if ok3 then
      name = safe(name)
      out[#out + 1] = {
        key = "D:" .. tostring(d),
        load = function()
          if not name then return nil end
          return { name = name, class = safe(class), when = combatTime, events = detailsEvents(raw),
                   avoid = avoidableFor(guidFor(name)) }
        end,
        dump = function()
          local ev = type(raw) == "table" and raw[#raw]
          if type(ev) ~= "table" then say("no events in last death") return end
          local f = {}
          for i = 1, 12 do f[i] = i .. "=" .. (ev[i] == nil and "nil" or tostring(safe(ev[i]) or "<secret>")) end
          say("Details death " .. tostring(name) .. " (" .. #raw .. " events), last: " .. table.concat(f, "  "))
        end,
      }
    end
  end
  return out
end

---------------------------------------------------------------- Blizzard fallback (last 5 hits only)
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

local function nativeDeaths()
  if not (C_DamageMeter and C_DamageMeter.GetCombatSessionFromType and C_DeathRecap) then return nil end
  local st = Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Overall or 0
  local mt = Enum.DamageMeterType and Enum.DamageMeterType.Deaths or 9
  local ok, session = pcall(C_DamageMeter.GetCombatSessionFromType, st, mt)
  if not ok or type(session) ~= "table" or type(session.combatSources) ~= "table" then return nil end
  local out = {}
  for _, src in ipairs(session.combatSources) do
    local recapID, guid = safe(src.deathRecapID), safe(src.sourceGUID)
    out[#out + 1] = {
      key = (recapID or guid) and ("N:" .. tostring(recapID) .. ":" .. tostring(guid) .. ":" .. tostring(safe(src.deathTimeSeconds))),
      load = function()
        local name = safe(src.name)
        if not name then return nil end
        local okE, raw = false, nil
        if recapID then okE, raw = pcall(C_DeathRecap.GetRecapEvents, recapID) end
        local events = {}
        for _, ev in ipairs((okE and type(raw) == "table") and raw or {}) do
          local amt = safe(ev.amount)
          if type(amt) == "number" and amt > 0 then
            local id = safe(ev.spellId) or safe(ev.spellID)
            local e = safe(ev.event)
            local label = safe(ev.spellName) or ((type(e) == "string" and e:find("^SWING")) and "Melee") or nil
            local over = safe(ev.overkill)
            events[#events + 1] = { kind = "dmg", id = id, label = label, amount = amt, time = safe(ev.timestamp),
              source = safe(ev.sourceName), overkill = type(over) == "number" and over or nil, hp = recapHP(ev, name) }
          end
        end
        table.sort(events, function(a, b) return (a.time or 0) < (b.time or 0) end)
        return { name = name, class = safe(src.classFilename), when = src.deathTimeSeconds, events = events,
                 avoid = avoidableFor(guid) }
      end,
      dump = function()
        local okE, raw = pcall(C_DeathRecap.GetRecapEvents, recapID)
        if not okE or type(raw) ~= "table" or not raw[1] then say("recap unreadable") return end
        local keys = {}
        for k, v in pairs(raw[1]) do keys[#keys + 1] = k .. "=" .. tostring(safe(v) or "<secret>") end
        table.sort(keys)
        say("recap #" .. tostring(recapID) .. " event[1]: " .. table.concat(keys, "  "))
      end,
    }
  end
  return out
end

-- Blizzard's meter first: Details' addon API returns no deaths on Midnight.
local function getDeaths()
  local n = nativeDeaths()
  if n then return n end
  return detailsDeaths()
end

-- Midnight restricts values for the whole of a boss pull or an M+ run.
local function restricted()
  if IsEncounterInProgress and IsEncounterInProgress() then return true end
  if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive then
    local ok, active = pcall(C_ChallengeMode.IsChallengeModeActive)
    if ok and active then return true end
  end
  return InCombatLockdown()
end

local pending = {} -- key -> entry still unreadable; kept even after Details moves to a new segment

local function applyLogLimit()
  local D = _G.Details
  if D and D.SetDeathLogLimit and DiedToDB.logLimit then pcall(D.SetDeathLogLimit, D, DiedToDB.logLimit) end
end

---------------------------------------------------------------- output
-- Group chat refuses colour codes from addons: strip colours, turn links into [Name].
local function plain(line)
  return (line:gsub("|H.-|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s+", ""))
end

local function groupChannel()
  local mode = DiedToDB.output
  if mode == "self" or not IsInGroup() then return nil end
  if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and (mode == "group" or not IsInGroup(LE_PARTY_CATEGORY_HOME)) then
    return "INSTANCE_CHAT"
  end
  if mode == "group" and IsInRaid() then return "RAID" end
  return "PARTY"
end

local queue, sentThisPull, sending = {}, 0, false
local function flush()
  if sending or #queue == 0 then return end
  if IsEncounterInProgress and IsEncounterInProgress() then return end -- send after the pull
  sending = true
  local function step()
    local item = table.remove(queue, 1)
    if not item then sending = false return end
    local ok = pcall(SendChatMessage, item.text, item.channel)
    if not ok then say(item.text .. " |cffff6060(group send blocked)|r") end
    C_Timer.After(0.4, step)
  end
  step()
end

local function emit(localLines, groupLines, isTest)
  local channel = groupChannel()
  if channel and (isTest or sentThisPull < DiedToDB.groupMax) then
    if not isTest then sentThisPull = sentThisPull + 1 end
    for i, l in ipairs(groupLines) do
      queue[#queue + 1] = { text = (i == 1 and "DiedTo: " or "  ") .. plain(l), channel = channel }
    end
    flush()
    if not DiedToDB.alsoSelf then return end
  end
  for i, l in ipairs(localLines) do say(l, i > 1) end
end

---------------------------------------------------------------- chat reports (from the shared death list)
-- Values are hidden during pulls and keys, so a death is reported once it's readable. After the
-- pull/key ends it gets a few more tries, then prints whatever is known.
local reported, tries = {}, {}

function ns.markReported()
  for _, entry in ipairs(ns.deathList or {}) do reported[entry] = true end
end

function ns.reportNew(reprintLast)
  local list = ns.deathList or {}
  if reprintLast then
    local entry = list[#list]
    if not entry then say("no death read yet") return end
    local d, info = ns.getDeath(entry)
    if d and info and not info.hidden then d.avoid = info.avoid; local l = render(d, true); if l then for i, x in ipairs(l) do say(x, i > 1) end end
    else say("that death's details are still hidden – try again after the pull or key") end
    return
  end
  local free = not restricted()
  for _, entry in ipairs(list) do
    if not reported[entry] and entry.src ~= "T" then
      local d, info = ns.getDeath(entry)
      if free then tries[entry] = (tries[entry] or 0) + 1 end
      local force = (tries[entry] or 0) >= MAX_ATTEMPTS
      if d and info and not info.hidden then
        d.avoid = info.avoid
        local localLines, groupLines = render(d, force)
        if localLines then
          reported[entry], tries[entry] = true, nil
          if DiedToDB.enabled then emit(localLines, groupLines) end
        elseif force then
          reported[entry] = true
        end
      elseif force then
        reported[entry] = true   -- still hidden after the pull: the death window has it, chat skips it
      end
    end
  end
end

local function scan(_, reprint)
  if ns.tick then ns.tick() end
  if reprint then ns.reportNew(true) end
end

---------------------------------------------------------------- test
local function testDeath()
  local now = GetTime()
  local function ev(flag, id, amount, ago, source, hp, overkill)
    return { flag, id, amount, now - ago, hp, source, 0, 1, false, overkill or 0 }
  end
  local _, classFile = UnitClass("player")
  local raw = {
    ev(true, 1, 99800, 4.2, "Underbrush Stalker", 1.00),
    ev(true, 116, 168700, 3.6, "Sporeblight Belcher", 0.92),
    ev(false, 774, 140000, 3.0, "Your Healer", 0.78),
    ev(true, 116, 222700, 2.3, "Lasher", 0.85),
    ev(1, 48707, 0, 1.8, UnitName("player"), 0.66),
    ev(true, 1, 143400, 1.0, "Radiant Spellsower", 0.62),
    ev(true, 133, 296400, 0.3, "Lasher", 0.48),
    ev(true, 133, 129600, 0.0, "Lightgorged Lasher", 0.12, 94900),
  }
  return { name = UnitName("player"), class = classFile, when = 109, events = detailsEvents(raw), avoid = { [133] = true } }
end

local function runTest(toGroup)
  local localLines, groupLines = render(testDeath(), true)
  localLines[1] = "|cff888888(test)|r " .. localLines[1]
  groupLines[1] = "(test) " .. groupLines[1]
  if toGroup then
    if groupChannel() then emit(localLines, groupLines, true)
    else say("not sending: output is 'Only me' or you're not in a group. Local preview:"); for _, l in ipairs(localLines) do say(l, true) end end
  else
    for i, l in ipairs(localLines) do say(l, i > 1) end
    say("|cff888888frame " .. DiedToDB.frame .. " · output " .. DiedToDB.output .. " · " .. (DiedToDB.enabled and "on" or "off") ..
      " · source " .. (_G.Details and ("Details! (log " .. DiedToDB.logLimit .. ")") or "Blizzard recap, last 5 hits") ..
      " · Alt-click a spell for Wowhead|r")
  end
end

---------------------------------------------------------------- UI helpers
local PAL = { bg = {0.024, 0.012, 0.059, 0.95}, edge = {0.549, 0.314, 0.863, 0.38}, accent = "|cffb66eff" }

local function makeLabel(parent, text, size, x, y)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  if size then fs:SetFont(STANDARD_TEXT_FONT, size, "") end
  fs:SetPoint("TOPLEFT", x, y); fs:SetJustifyH("LEFT"); fs:SetText(text)
  return fs
end

local function styleBox(f)
  f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
  f:SetBackdropColor(unpack(PAL.bg)); f:SetBackdropBorderColor(unpack(PAL.edge))
  f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton"); f:SetClampedToScreen(true)
  f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetFrameStrata("DIALOG")
end

---------------------------------------------------------------- Wowhead copy box (Alt-click any spell link)
local copyBox
local function showURL(spellId)
  if not copyBox then
    copyBox = CreateFrame("Frame", "DiedToCopyBox", UIParent, "BackdropTemplate")
    copyBox:SetSize(380, 78); copyBox:SetPoint("CENTER", 0, 120); styleBox(copyBox)
    tinsert(UISpecialFrames, "DiedToCopyBox")
    copyBox.title = makeLabel(copyBox, "", 12, 12, -10)
    local close = CreateFrame("Button", nil, copyBox, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", 2, 2)
    local eb = CreateFrame("EditBox", nil, copyBox, "InputBoxTemplate")
    eb:SetSize(350, 22); eb:SetPoint("BOTTOMLEFT", 18, 14); eb:SetAutoFocus(false)
    eb:SetScript("OnEscapePressed", function() copyBox:Hide() end)
    eb:SetScript("OnEnterPressed", function() copyBox:Hide() end)
    eb:SetScript("OnTextChanged", function(self, user) if user then self:SetText(copyBox.url); self:HighlightText() end end)
    eb:SetScript("OnMouseUp", function(self) self:HighlightText() end)
    copyBox.eb = eb
  end
  local name = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellId)) or ("spell " .. spellId)
  copyBox.url = "https://www.wowhead.com/spell=" .. spellId
  copyBox.title:SetText(PAL.accent .. name .. "|r  |cff888888Ctrl+C, then paste in your browser|r")
  copyBox:Show()
  copyBox.eb:SetText(copyBox.url); copyBox.eb:SetFocus(); copyBox.eb:HighlightText()
end

local function onLink(link)
  if type(link) ~= "string" or not IsAltKeyDown() then return end
  local id = link:match("^spell:(%d+)")
  if id then showURL(tonumber(id)) end
end
if hooksecurefunc and SetItemRef then hooksecurefunc("SetItemRef", onLink) end

---------------------------------------------------------------- settings window
local win

local function makeCheck(parent, text, x, y, get, set)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(24, 24); cb:SetPoint("TOPLEFT", x, y)
  makeLabel(parent, text, 12, x + 28, y - 5)
  cb:SetScript("OnClick", function(self) set(self:GetChecked()) end)
  cb.refresh = function() cb:SetChecked(get()) end
  return cb
end

local function makeStepper(parent, text, x, y, min, max, step, get, set)
  makeLabel(parent, text, 12, x, y - 4)
  local val = makeLabel(parent, "", 12, x + 222, y - 4)
  local function btn(label, dx, delta)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(22, 20); b:SetPoint("TOPLEFT", x + dx, y); b:SetText(label)
    b:SetScript("OnClick", function() set(math.max(min, math.min(max, get() + delta))); val:SetText(get()) end)
  end
  btn("-", 194, -step); btn("+", 250, step)
  return { refresh = function() val:SetText(get()) end }
end

local function section(parent, text, y) makeLabel(parent, "|cff888888" .. text .. "|r", 11, 14, y) end

local function buildWindow()
  win = CreateFrame("Frame", "DiedToSettings", UIParent, "BackdropTemplate")
  win:SetSize(320, 604); win:SetPoint("CENTER"); styleBox(win)
  tinsert(UISpecialFrames, "DiedToSettings")
  makeLabel(win, PAL.accent .. "DiedTo|r  |cff888888settings|r", 15, 14, -12)
  local close = CreateFrame("Button", nil, win, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", 2, 2)

  local c, y = {}, -40
  local function add(ctrl) c[#c + 1] = ctrl; return ctrl end
  add(makeCheck(win, "Open death window when someone dies", 12, y, function() return DiedToDB.autoOpen end, function(v) DiedToDB.autoOpen = v end))
  y = y - 24
  add(makeCheck(win, "Also print deaths to chat", 12, y, function() return DiedToDB.enabled end, function(v) DiedToDB.enabled = v end))

  y = y - 34; section(win, "SEND TO", y)
  local radios = {}
  for i, o in ipairs({ { "self", "Only me (local chat frame)" }, { "party", "Party chat" },
                       { "group", "Group: raid / party / instance (auto)" } }) do
    radios[i] = add(makeCheck(win, o[2], 12, y - 14 - (i - 1) * 24,
      function() return DiedToDB.output == o[1] end,
      function() DiedToDB.output = o[1]; for _, r in ipairs(radios) do r.refresh() end end))
  end
  y = y - 14 - 3 * 24
  add(makeCheck(win, "Also show my local copy when sending", 12, y, function() return DiedToDB.alsoSelf end, function(v) DiedToDB.alsoSelf = v end))
  y = y - 30
  add(makeStepper(win, "Max group deaths per pull", 14, y, 1, 40, 1, function() return DiedToDB.groupMax end, function(v) DiedToDB.groupMax = v end))
  makeLabel(win, "|cff888888Group gets the two summary lines, not the timeline.|r", 10, 14, y - 24)

  y = y - 50; section(win, "LOCAL DETAIL", y)
  add(makeCheck(win, "Hit-by-hit timeline under each death", 12, y - 14, function() return DiedToDB.timeline end, function(v) DiedToDB.timeline = v end))
  add(makeCheck(win, "Include heals and cooldowns in timeline", 12, y - 38, function() return DiedToDB.showHeals end, function(v) DiedToDB.showHeals = v end))
  y = y - 70
  add(makeStepper(win, "Timeline rows", 14, y, 4, 60, 2, function() return DiedToDB.rows end, function(v) DiedToDB.rows = v end))
  y = y - 28
  add(makeStepper(win, "Details death log size", 14, y, 16, 64, 8, function() return DiedToDB.logLimit end,
    function(v) DiedToDB.logLimit = v; applyLogLimit() end))
  y = y - 28
  add(makeStepper(win, "Local chat frame (1 = General)", 14, y, 1, NUM_CHAT_WINDOWS or 10, 1,
    function() return DiedToDB.frame end, function(v) DiedToDB.frame = v end))
  y = y - 28
  add(makeStepper(win, "Death window text size", 14, y, 8, 14, 1, function() return DiedToDB.textSize end,
    function(v) DiedToDB.textSize = v; if ns.applyTextSize then ns.applyTextSize() end end))
  y = y - 28
  add(makeStepper(win, "Death window background %", 14, y, 0, 100, 10, function() return math.floor(((DiedToDB.bgAlpha or 0.45) * 100) + 0.5) end,
    function(v) DiedToDB.bgAlpha = v / 100; if ns.applyBg then ns.applyBg() end end))
  makeLabel(win, "|cff888888Hover a spell for its tooltip. Alt-click it for the Wowhead link.|r", 10, 14, y - 30)

  local function button(text, x, w, fn)
    local b = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    b:SetSize(w, 22); b:SetPoint("BOTTOMLEFT", x, 14); b:SetText(text); b:SetScript("OnClick", fn)
  end
  button("Test (me)", 12, 92, function() runTest(false) end)
  button("Test (group)", 110, 100, function() runTest(true) end)
  button("Reprint", 216, 92, function() scan(false, true) end)
  local dw = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
  dw:SetSize(296, 22); dw:SetPoint("BOTTOMLEFT", 12, 42); dw:SetText("Open death window")
  dw:SetScript("OnClick", function() if ns.toggleDeaths then ns.toggleDeaths(true) end end)

  win.refresh = function() for _, ctrl in ipairs(c) do ctrl.refresh() end end
  win:SetScript("OnShow", win.refresh)
  win:Hide()
end

local function toggleWindow()
  if not win then buildWindow() end
  if win:IsShown() then win:Hide() else win:Show() end
end

local function registerOptions()
  if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
  local panel = CreateFrame("Frame")
  makeLabel(panel, PAL.accent .. "DiedTo|r", 16, 16, -16)
  local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  b:SetSize(160, 24); b:SetPoint("TOPLEFT", 16, -48); b:SetText("Open settings window")
  b:SetScript("OnClick", function() if SettingsPanel then HideUIPanel(SettingsPanel) end; toggleWindow() end)
  pcall(function() Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(panel, "DiedTo")) end)
end

---------------------------------------------------------------- events
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "ENCOUNTER_START",
                     "ENCOUNTER_END", "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED" }) do
  frame:RegisterEvent(e)
end
frame:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    DiedToDB = DiedToDB or {}
    for k, v in pairs(DEFAULTS) do if DiedToDB[k] == nil then DiedToDB[k] = v end end
    registerOptions()
    C_Timer.After(2, function() applyLogLimit() end)
  elseif event == "ENCOUNTER_START" or event == "CHALLENGE_MODE_START" then
    sentThisPull = 0
  elseif event == "PLAYER_REGEN_DISABLED" then
    if not (IsEncounterInProgress and IsEncounterInProgress()) then sentThisPull = 0 end
  elseif event == "CHALLENGE_MODE_COMPLETED" then
    C_Timer.After(3, function() scan(); flush() end)
  else
    C_Timer.After(1.5, function() scan(); flush() end)
  end
end)

---------------------------------------------------------------- slash
SLASH_DIEDTO1 = "/diedto"
SlashCmdList.DIEDTO = function(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")
  if msg == "" then if ns.toggleDeaths then ns.toggleDeaths() end
  elseif msg == "config" or msg == "options" or msg == "settings" then toggleWindow()
  elseif msg == "on" or msg == "off" then DiedToDB.enabled = (msg == "on"); say("reporting " .. msg)
  elseif msg == "me" or msg == "party" or msg == "group" then
    DiedToDB.output = (msg == "me") and "self" or msg; say("output: " .. DiedToDB.output)
  elseif msg == "test" then runTest(false); if ns.addTestDeath then ns.addTestDeath() end
  elseif msg == "test group" then runTest(true)
  elseif msg == "last" then scan(false, true)
  elseif msg == "dump" then say("use /diedto probe")
  elseif msg == "probe" then
    local function st(v) if v == nil then return "nil" end; return isSecret(v) and "SECRET" or ("ok:" .. tostring(v):sub(1, 24)) end
    local mplus = C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive()
    say("probe: encounter=" .. tostring(IsEncounterInProgress and IsEncounterInProgress()) .. " mplus=" .. tostring(mplus) ..
      " combat=" .. tostring(InCombatLockdown()) .. " pending=" .. (function() local n = 0; for _ in pairs(pending) do n = n + 1 end; return n end)())
    local D = _G.Details
    if D and D.GetCurrentCombat then
      local ok, combat = pcall(D.GetCurrentCombat, D)
      local ok2, deaths = false, nil
      if ok and combat and combat.GetDeaths then ok2, deaths = pcall(combat.GetDeaths, combat) end
      say("Details: combat=" .. tostring(ok and combat ~= nil) .. " deaths=" .. (ok2 and type(deaths) == "table" and #deaths or "unreadable"))
      local d = ok2 and type(deaths) == "table" and deaths[#deaths]
      if d then
        local ok3, name, class, dt, ct, _, _, raw = pcall(D.UnpackDeathTable, D, d)
        say("  last death: unpack=" .. tostring(ok3) .. " name=" .. st(name) .. " class=" .. st(class) .. " combatTime=" .. st(ct) ..
          " events=" .. (type(raw) == "table" and #raw or st(raw)))
        local ev = type(raw) == "table" and raw[#raw]
        if type(ev) == "table" then
          say("  last event: [1]=" .. st(ev[1]) .. " [2]=" .. st(ev[2]) .. " [3]=" .. st(ev[3]) .. " [4]=" .. st(ev[4]) ..
            " [5]=" .. st(ev[5]) .. " [6]=" .. st(ev[6]) .. " [10]=" .. st(ev[10]))
        end
      end
    else
      say("Details: not loaded")
    end
    if C_DamageMeter and C_DamageMeter.GetCombatSessionFromType then
      local stp = Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Overall or 0
      local mt = Enum.DamageMeterType and Enum.DamageMeterType.Deaths or 9
      local ok, session = pcall(C_DamageMeter.GetCombatSessionFromType, stp, mt)
      local srcs = ok and type(session) == "table" and session.combatSources
      say("Blizzard meter: call=" .. tostring(ok) .. " sources=" .. (type(srcs) == "table" and #srcs or "unreadable"))
      local s1 = type(srcs) == "table" and srcs[#srcs]
      if s1 then
        say("  last: name=" .. st(s1.name) .. " recapID=" .. st(s1.deathRecapID) .. " time=" .. st(s1.deathTimeSeconds))
        local okE, ev = pcall(C_DeathRecap.GetRecapEvents, safe(s1.deathRecapID))
        local e1 = okE and type(ev) == "table" and ev[1]
        if e1 then
          local keys = {}
          for k, v in pairs(e1) do keys[#keys + 1] = k .. "=" .. st(v) end
          table.sort(keys)
          say("  recap fields: " .. table.concat(keys, "  "))
        end
        say("  recap: call=" .. tostring(okE) .. " events=" .. (okE and type(ev) == "table" and #ev or "unreadable") ..
          (e1 and (" spellId=" .. st(e1.spellId) .. " amount=" .. st(e1.amount) .. " source=" .. st(e1.sourceName)) or ""))
      end
    end
  elseif msg == "source" then
    say("reading from " .. (nativeDeaths() and "Blizzard damage meter + death recap" or (detailsDeaths() and "Details!" or "nothing (no data yet)")))
  elseif msg:match("^frame") then
    local n = tonumber(msg:match("^frame%s+(%d+)"))
    if n and _G["ChatFrame" .. n] then DiedToDB.frame = n; say("local output now in chat frame " .. n)
    else say("usage: /diedto frame <n> (1 = General)") end
  else
    say("/diedto — death window | config — settings | on|off | me|party|group | test | test group | frame <n> | last | dump | source")
  end
end

---------------------------------------------------------------- shared with DiedToWindow.lua
ns.isSecret, ns.safe, ns.say, ns.short, ns.clock = isSecret, safe, say, short, clock
ns.avoidableFor, ns.guidFor, ns.showURL, ns.PAL = avoidableFor, guidFor, showURL, PAL
ns.styleBox, ns.makeLabel, ns.openSettings, ns.testDeathRaw = styleBox, makeLabel, toggleWindow, function()
  return testDeath()
end
