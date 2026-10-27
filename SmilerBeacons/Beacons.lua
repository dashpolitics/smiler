-- SmilerBeacons: Holy Paladin beacon check.
-- In a group, with the Beacon of Faith talent: two small icons (Light, Faith). Each shows who it's on, or turns into
-- a warning when it's on nobody. Optional Smiler alert when one drops. Does nothing on other specs or talents.
local ADDON, ns = ...
SmilerBeacons = ns
local S = Smiler
local isSecret = issecretvalue or function() return false end

local LIGHT, FAITH = 53563, 156910
local DEFAULTS = { size = 34, locked = false, alert = true, sound = true, onlyGroup = true, hideWhenFine = false }
local db, frame, icons = nil, nil, {}
local WHITE = "Interface\\Buttons\\WHITE8x8"
local function say(...) print("|cffb98cffSmilerBeacons|r", ...) end
local function RGB(name, a)
  if S and S.RGB then return S.RGB(name, a) end
  local c = ({ emerald = { 0, 0.9, 0.46 }, ruby = { 1, 0.18, 0.33 }, edge = { 0.55, 0.31, 0.86 }, text = { 0.94, 0.92, 1 }, muted = { 0.7, 0.63, 0.86 } })[name] or { 1, 1, 1 }
  return c[1], c[2], c[3], a or 1
end
local function spellName(id) return (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or ("Spell " .. id) end
local function spellIcon(id) return (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)) or 134400 end

-- active only for a Holy Paladin with Beacon of Faith talented
local function active()
  local _, cls = UnitClass("player")
  if cls ~= "PALADIN" then return false end
  local known = (IsPlayerSpell and IsPlayerSpell(FAITH)) or (C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(FAITH))
  return known and true or false
end
local function inGroup() return IsInGroup() or IsInRaid() end

local function units()
  local out = { "player" }
  if IsInRaid() then for i = 1, GetNumGroupMembers() do out[#out + 1] = "raid" .. i end
  elseif IsInGroup() then for i = 1, GetNumSubgroupMembers() do out[#out + 1] = "party" .. i end end
  return out
end

-- who has my beacon: name, or nil; "?" when the game hides auras from add-ons right now
local function whoHas(id)
  local name = spellName(id)
  local hidden = false
  for _, u in ipairs(units()) do
    if UnitExists(u) and not (u ~= "player" and UnitIsUnit(u, "player")) then
      local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, u, name, "HELPFUL|PLAYER")
      if ok and aura then
        if isSecret(aura) or isSecret(aura.spellId) then hidden = true
        else return UnitName(u) or u end
      end
    end
  end
  return hidden and "?" or nil
end

---------------------------------------------------------------- display
local function savePoint()
  local p, _, rp, x, y = frame:GetPoint()
  db.point = { p, rp, x, y }
end
local function makeIcon(i, id)
  local b = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  b:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 2 })
  b:SetBackdropColor(0, 0, 0, 0.6)
  b.tex = b:CreateTexture(nil, "ARTWORK"); b.tex:SetPoint("TOPLEFT", 2, -2); b.tex:SetPoint("BOTTOMRIGHT", -2, 2)
  b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92); b.tex:SetTexture(spellIcon(id))
  b.warn = b:CreateFontString(nil, "OVERLAY"); b.warn:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE"); b.warn:SetPoint("CENTER"); b.warn:SetText("!")
  b.who = b:CreateFontString(nil, "OVERLAY"); b.who:SetFont("Fonts\\ARIALN.TTF", 11, "OUTLINE"); b.who:SetPoint("TOP", b, "BOTTOM", 0, -2)
  b.id = id
  b:EnableMouse(true)
  b:RegisterForDrag("LeftButton")
  b:SetScript("OnDragStart", function() if not db.locked then frame:StartMoving() end end)
  b:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); savePoint() end)
  b:SetScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
    GameTooltip:AddLine(spellName(s.id), 1, 0.82, 0)
    GameTooltip:AddLine(s.on == "?" and "The game is hiding auras from add-ons right now (in combat)." or (s.on and ("On " .. s.on) or "Not on anyone"), 1, 1, 1, true)
    GameTooltip:AddLine(db.locked and "/beacons lock to move" or "Drag to move · /beacons lock", 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  icons[i] = b
  return b
end

local lastState = {}
function ns.Update()
  if not frame then return end
  local on = active() and (not db.onlyGroup or inGroup())
  if not on then frame:Hide(); return end
  local anyMissing = false
  for i, b in ipairs(icons) do
    local who = whoHas(b.id)
    b.on = who
    local missing = who == nil
    if missing then anyMissing = true end
    b:SetSize(db.size, db.size)
    b:ClearAllPoints(); b:SetPoint("LEFT", frame, "LEFT", (i - 1) * (db.size + 8), 0)
    b.tex:SetDesaturated(missing)
    b.warn:SetShown(missing)
    b:SetBackdropBorderColor(RGB(missing and "ruby" or (who == "?" and "edge" or "emerald"), 1))
    b.who:SetText(missing and "|cffff2d55missing|r" or (who == "?" and "?" or who))
    -- alert once when a beacon drops off (not on login / when it was never up)
    if missing and lastState[b.id] and lastState[b.id] ~= "?" then
      if db.alert and S and S.Toast then
        S:Toast({ kind = "death", title = spellName(b.id) .. " is off", sub = "Not on anyone in your group", duration = 5, id = "beacon" .. b.id })
      elseif db.alert then
        RaidNotice_AddMessage(RaidWarningFrame, spellName(b.id) .. " is off", ChatTypeInfo["RAID_WARNING"])
      end
      if db.sound and PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.RAID_WARNING or 8959) end
    end
    lastState[b.id] = who
  end
  frame:SetSize(2 * db.size + 8, db.size + 16)
  frame:SetShown(anyMissing or not db.hideWhenFine or not db.locked)
end

local function build()
  frame = CreateFrame("Frame", "SmilerBeaconsFrame", UIParent)
  frame:SetMovable(true); frame:SetClampedToScreen(true)
  if db.point then frame:SetPoint(db.point[1], UIParent, db.point[2], db.point[3], db.point[4])
  else frame:SetPoint("CENTER", UIParent, "CENTER", 0, -220) end
  makeIcon(1, LIGHT); makeIcon(2, FAITH)
  frame:Hide()
  -- a light poll covers range/death/aura changes the events miss
  local acc = 0
  frame:SetScript("OnUpdate", function(_, dt) acc = acc + dt; if acc > 1 then acc = 0; ns.Update() end end)
end

---------------------------------------------------------------- Smiler settings
if S and S.RegisterSettings then
  S:RegisterSettings("Beacons", function(body, W)
    local A = W.Column(body, 0, 0, 290)
    A:Section("Beacons")
    A:Switch("Alert when a beacon drops", "A Smiler alert, plus a sound", function() return db.alert end, function(v) db.alert = v end)
    A:Switch("Sound", nil, function() return db.sound end, function(v) db.sound = v end)
    A:Switch("Hide when both are up", "Only shows when one is missing (once locked)", function() return db.hideWhenFine end, function(v) db.hideWhenFine = v; ns.Update() end)
    A:Switch("Lock position", "Unlocked: drag the icons", function() return db.locked end, function(v) db.locked = v; ns.Update() end)
    A:Slider("Size", 24, 64, 1, function() return db.size end, function(v) db.size = v; ns.Update() end, function(v) return v .. " px" end, 120)
    local B = W.Column(body, 334, 0, 290)
    B:Section("When it's on")
    B:Note("Holy Paladin with the Beacon of Faith talent, in a party or raid. On any other spec or talent build it does nothing.", "soft", 13)
    B:Note("In combat the game may hide other players' auras from add-ons; the icons then show ? rather than a false warning.", "muted", 12)
    return { note = "/beacons lock · /beacons test", footer = {} }
  end)
  if S.RegisterStatus then
    S:RegisterStatus("beacons", function()
      if not db then return nil end
      if not active() then return "Needs Holy with Beacon of Faith", "muted" end
      return inGroup() and "Watching your beacons" or "Waiting for a group", "muted"
    end)
  end
end

---------------------------------------------------------------- events
local ev = CreateFrame("Frame")
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED",
                     "PLAYER_SPECIALIZATION_CHANGED", "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_REGEN_ENABLED" }) do ev:RegisterEvent(e) end
ev:SetScript("OnEvent", function(_, e, a1)
  if e == "ADDON_LOADED" then
    if a1 ~= ADDON then return end
    SmilerBeaconsDB = SmilerBeaconsDB or {}
    db = SmilerBeaconsDB
    for k, v in pairs(DEFAULTS) do if db[k] == nil then db[k] = v end end
    ns.db = db
    build()
    return
  end
  if not db then return end
  ns.Update()
end)

SLASH_SMILERBEACONS1 = "/beacons"
SlashCmdList.SMILERBEACONS = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "lock" then db.locked = not db.locked; say(db.locked and "locked" or "unlocked - drag the icons"); ns.Update()
  elseif msg == "test" then
    if not active() then say("needs a Holy Paladin with Beacon of Faith talented") return end
    lastState[LIGHT] = "Test"; frame:Show(); ns.Update()
    if S and S.Toast then S:Toast({ kind = "death", title = spellName(LIGHT) .. " is off", sub = "Not on anyone in your group (test)", duration = 4 }) end
  elseif msg == "reset" then db.point = nil; frame:ClearAllPoints(); frame:SetPoint("CENTER", UIParent, "CENTER", 0, -220)
  else
    if S and S.OpenSettings then S:OpenSettings("Beacons") else say("/beacons lock · test · reset") end
  end
end
