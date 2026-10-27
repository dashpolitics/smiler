-- LustReady: "Lust available" when you pull a raid or dungeon boss without Exhaustion,
-- and again the moment Exhaustion (or Sated etc.) wears off.
-- Uses only your own debuffs and encounter start – no combat log, nothing sent to anyone.
local ADDON, ns = ...

-- Lockout debuffs left by any lust effect
local SATED = {
  57723,   -- Exhaustion (Bloodlust)
  57724,   -- Sated (Heroism)
  80354,   -- Temporal Displacement (Time Warp)
  264689,  -- Fatigued (Primal Rage, drums)
  390435,  -- Exhaustion (Fury of the Aspects)
}
-- Lust spells, to tell whether you can cast one yourself
local LUSTS = { 2825, 32182, 80353, 390386 }
local PET_LUSTS = { 264667 }   -- Primal Rage (hunter pet)

local DEFAULTS = {
  onPull = true,           -- alert on boss pull when not Exhausted
  onExpire = true,         -- alert when Exhaustion wears off
  expireAnywhere = false,  -- false: only in raids and dungeons
  onlyMine = false,        -- only if you can cast lust yourself
  sound = true,
  soundKey = "roar",
  loud = 2,                -- copies played at once: 1 = normal, 2 = twice as loud, 3 = about three times
  scale = 1,
  duration = 3,
}
-- kit = game sound kit ID (PlaySound); file = sound file (PlaySoundFile)
local CUSTOM_FILE = "Interface\\AddOns\\LustReady\\Sounds\\lust.ogg"
local SOUNDS = {
  { "roar",   "Dragon roar",  kit = 7274 },           -- the game's "DragonRoar" sound
  { "custom", "Your own file (Sounds\\lust.ogg)", file = CUSTOM_FILE },
  { "warn",   "Raid warning", kitName = "RAID_WARNING" },
  { "ready",  "Ready check",  kitName = "READY_CHECK" },
  { "alarm",  "Alarm",        kitName = "ALARM_CLOCK_WARNING_3" },
  { "epic",   "Epic loot",    kitName = "UI_EPICLOOT_TOAST" },
}

-- Crystal Ball palette (shared with the other Smiler add-ons)
local C = {
  bg      = { 0.024, 0.012, 0.059, 0.94 },
  emerald = { 0.000, 0.902, 0.463 },
  diamond = { 0.910, 0.957, 1.000 },
  soft    = { 0.847, 0.784, 1.000 },
}
local FONT_DIR = "Interface\\AddOns\\CDTimeline\\Fonts\\"
local function setFont(fs, file, size, fallback)
  if not fs:SetFont(FONT_DIR .. file, size, "") then fs:SetFont(fallback, size, "") end
  fs:SetShadowColor(0, 0, 0, 0.9); fs:SetShadowOffset(1, -1)
end

local db
local wasSated, satedTicker, pulledAt

local function P(...) print("|cff00e676LustReady|r", ...) end
local function secret(v) return issecretvalue and issecretvalue(v) or false end

---------------------------------------------------------------- state
local function satedAura()
  if not C_UnitAuras or not C_UnitAuras.GetPlayerAuraBySpellID then return nil end
  for _, id in ipairs(SATED) do
    local ok, a = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
    if ok and a then return a, id end
  end
end

local function knowsLust()
  for _, id in ipairs(LUSTS) do if IsPlayerSpell and IsPlayerSpell(id) then return true end end
  for _, id in ipairs(PET_LUSTS) do if IsSpellKnown and IsSpellKnown(id, true) then return true end end
  return false
end

local function lustIcon()
  for _, id in ipairs(LUSTS) do
    if IsPlayerSpell and IsPlayerSpell(id) then return C_Spell.GetSpellTexture(id) end
  end
  return 136012   -- Bloodlust
end

local function inGroupContent()
  local _, itype = GetInstanceInfo()
  return itype == "party" or itype == "raid"
end

---------------------------------------------------------------- alert frame
local alert
local function buildAlert()
  alert = CreateFrame("Frame", "LustReadyAlert", UIParent, "BackdropTemplate")
  alert:SetSize(400, 72)
  alert:SetFrameStrata("HIGH")
  alert:SetClampedToScreen(true)
  alert:SetMovable(true)
  alert:RegisterForDrag("LeftButton")
  alert:SetScript("OnDragStart", alert.StartMoving)
  alert:SetScript("OnDragStop", function(s)
    s:StopMovingOrSizing()
    local p, _, rp, x, y = s:GetPoint()
    db.point = { p, rp, x, y }
  end)
  alert:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
  alert:SetBackdropColor(unpack(C.bg))
  alert:SetBackdropBorderColor(C.emerald[1], C.emerald[2], C.emerald[3], 0.6)

  -- emerald-to-diamond line along the top
  local line = alert:CreateTexture(nil, "ARTWORK")
  line:SetPoint("TOPLEFT", 1, -1); line:SetPoint("TOPRIGHT", -1, -1); line:SetHeight(2)
  line:SetColorTexture(1, 1, 1, 1)
  line:SetGradient("HORIZONTAL", CreateColor(C.emerald[1], C.emerald[2], C.emerald[3], 1), CreateColor(C.diamond[1], C.diamond[2], C.diamond[3], 1))

  alert.icon = alert:CreateTexture(nil, "ARTWORK")
  alert.icon:SetSize(46, 46)
  alert.icon:SetPoint("LEFT", 14, 0)
  alert.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  -- tick so the meaning never rests on colour alone
  alert.tick = alert:CreateTexture(nil, "OVERLAY")
  alert.tick:SetSize(18, 18)
  alert.tick:SetPoint("TOPLEFT", alert.icon, "TOPRIGHT", 14, -4)
  if not pcall(alert.tick.SetAtlas, alert.tick, "common-icon-checkmark") then
    alert.tick:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
  end
  alert.tick:SetVertexColor(C.emerald[1], C.emerald[2], C.emerald[3])

  alert.text = alert:CreateFontString(nil, "OVERLAY")
  setFont(alert.text, "BarlowCondensed-Bold.ttf", 23, "Fonts\\FRIZQT__.TTF")
  alert.text:SetTextColor(unpack(C.emerald))
  alert.text:SetPoint("LEFT", alert.tick, "RIGHT", 7, 0)
  alert.text:SetText("LUST AVAILABLE")

  alert.sub = alert:CreateFontString(nil, "OVERLAY")
  setFont(alert.sub, "Barlow-Medium.ttf", 13, "Fonts\\ARIALN.TTF")
  alert.sub:SetTextColor(unpack(C.soft))
  alert.sub:SetPoint("BOTTOMLEFT", alert.icon, "BOTTOMRIGHT", 14, 4)

  alert.anim = alert:CreateAnimationGroup()
  local fin = alert.anim:CreateAnimation("Alpha"); fin:SetFromAlpha(0); fin:SetToAlpha(1); fin:SetDuration(0.15); fin:SetOrder(1)
  alert.hold = alert.anim:CreateAnimation("Alpha"); alert.hold:SetFromAlpha(1); alert.hold:SetToAlpha(1); alert.hold:SetOrder(2)
  local fout = alert.anim:CreateAnimation("Alpha"); fout:SetFromAlpha(1); fout:SetToAlpha(0); fout:SetDuration(0.6); fout:SetOrder(3)
  alert.anim:SetScript("OnFinished", function() if not alert.unlocked then alert:Hide() end end)
  alert:Hide()
end

local function place()
  alert:ClearAllPoints()
  local p = db.point
  if p then alert:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else alert:SetPoint("TOP", 0, -190) end
  alert:SetScale(db.scale or 1)
end

local function playOne(sd)
  if not sd then return false end
  local ok, willPlay
  if sd.file then ok, willPlay = pcall(PlaySoundFile, sd.file, "Master")
  elseif sd.kit then ok, willPlay = pcall(PlaySound, sd.kit, "Master")
  elseif sd.kitName and SOUNDKIT and SOUNDKIT[sd.kitName] then ok, willPlay = pcall(PlaySound, SOUNDKIT[sd.kitName], "Master")
  end
  return ok and willPlay and true or false
end

local function findSound(key)
  for _, sd in ipairs(SOUNDS) do if sd[1] == key then return sd end end
end

-- plays the chosen sound; if the game can't play it, falls back to the raid warning
-- The game can't play a sound above your volume setting, so "louder" means playing the same
-- sound several times in the same instant: the copies line up and add together.
local function playSound()
  if not db.sound then return true end
  local n = math.max(1, math.min(3, db.loud or 2))
  local sd = findSound(db.soundKey)
  if playOne(sd) then
    for _ = 2, n do playOne(sd) end
    return true
  end
  local warn = findSound("warn")
  for _ = 1, n do playOne(warn) end
  return false
end

local function Alert(why)
  if Smiler and Smiler.Toast then
    Smiler:Toast({ kind = "ready", id = "lustready", title = "Lust available", sub = why, icon = lustIcon(), duration = db.duration or 3 })
    playSound()
    return
  end
  if not alert then buildAlert(); place() end
  if alert.unlocked then return end
  alert.icon:SetTexture(lustIcon())
  alert.sub:SetText(why)
  alert.hold:SetDuration(db.duration or 3)
  alert:SetAlpha(0)
  alert:Show()
  alert.anim:Stop(); alert.anim:Play()
  playSound()
end

---------------------------------------------------------------- triggers
local function checkPull()
  if not db.onPull or not inGroupContent() then return end
  if db.onlyMine and not knowsLust() then return end
  if satedAura() then return end
  Alert("Boss pulled · you're not Exhausted")
end

local function stopTicker()
  if satedTicker then satedTicker:Cancel(); satedTicker = nil end
end

local function updateSated(silent)
  local a = satedAura()
  local now = a ~= nil
  if wasSated and not now and not silent then
    if db.onExpire and (db.expireAnywhere or inGroupContent()) and (not db.onlyMine or knowsLust()) then
      Alert("Exhaustion has worn off")
    end
  end
  wasSated = now
  -- while Exhausted, also check once a second in case the aura event is missed
  if now and not satedTicker then
    satedTicker = C_Timer.NewTicker(1, function() updateSated(false) end)
  elseif not now then
    stopTicker()
  end
end

---------------------------------------------------------------- events
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ENCOUNTER_START")
ev:RegisterUnitEvent("UNIT_AURA", "player")
ev:SetScript("OnEvent", function(_, e, ...)
  if e == "ADDON_LOADED" then
    if ... ~= ADDON then return end
    LustReadyDB = LustReadyDB or {}
    for k, v in pairs(DEFAULTS) do if LustReadyDB[k] == nil then LustReadyDB[k] = v end end
    db = LustReadyDB
    if (db.soundVersion or 1) < 2 then db.soundKey = "roar"; db.soundVersion = 2 end   -- 0.2.0: dragon roar by default
  elseif e == "PLAYER_ENTERING_WORLD" then
    updateSated(true)                     -- learn the current state without alerting
  elseif e == "ENCOUNTER_START" then
    -- debuffs can lag a moment behind the pull; check right after
    C_Timer.After(0.3, checkPull)
  elseif e == "UNIT_AURA" then
    updateSated(false)
  end
end)

---------------------------------------------------------------- slash
local function status()
  local a = satedAura()
  local left = ""
  if a and a.expirationTime and not secret(a.expirationTime) and a.expirationTime > 0 then
    left = string.format(" (%d:%02d left)", math.floor((a.expirationTime - GetTime()) / 60), (a.expirationTime - GetTime()) % 60)
  end
  P(a and ("You're Exhausted" .. left .. ".") or "Lust available – you're not Exhausted.")
  P(string.format("Pull alert: %s · expiry alert: %s (%s) · only if I can lust: %s · sound: %s",
    db.onPull and "on" or "off", db.onExpire and "on" or "off",
    db.expireAnywhere and "anywhere" or "raids and dungeons", db.onlyMine and "on" or "off",
    db.sound and db.soundKey or "off"))
end

SLASH_LUSTREADY1, SLASH_LUSTREADY2 = "/lust", "/lustready"
SlashCmdList.LUSTREADY = function(msg)
  local cmd = (msg or ""):lower():match("^%s*(%S*)")
  if cmd == "options" or cmd == "settings" or cmd == "config" then
    if Smiler and Smiler.OpenSettings then Smiler:OpenSettings("LustReady") else P("Settings need the Smiler add-on; use the commands below.") end
  elseif cmd == "" then
    status()
    P("/lust test · pull · expire · anywhere · mine · sound · loud · nosound · move · scale <0.5-2> · reset")
  elseif cmd == "test" then
    Alert("Test – this is what a pull looks like")
  elseif cmd == "pull" then
    db.onPull = not db.onPull; P("Boss-pull alert " .. (db.onPull and "on" or "off"))
  elseif cmd == "expire" then
    db.onExpire = not db.onExpire; P("Exhaustion-expired alert " .. (db.onExpire and "on" or "off"))
  elseif cmd == "anywhere" then
    db.expireAnywhere = not db.expireAnywhere
    P("Exhaustion-expired alert: " .. (db.expireAnywhere and "anywhere" or "raids and dungeons only"))
  elseif cmd == "mine" then
    db.onlyMine = not db.onlyMine
    P(db.onlyMine and "Only alerting on characters that can cast lust." or "Alerting on every character.")
  elseif cmd == "sound" then
    -- cycle through the sounds, playing each
    local nextIdx = 1
    for i, sd in ipairs(SOUNDS) do if sd[1] == db.soundKey then nextIdx = i % #SOUNDS + 1 end end
    local sd = SOUNDS[nextIdx]
    db.soundKey = sd[1]; db.sound = true
    if playSound() then P("Sound: " .. sd[2])
    else P("Sound: " .. sd[2] .. " – couldn't play it, so you'll hear the raid warning instead.") end
  elseif cmd == "loud" then
    db.loud = (db.loud or 2) % 3 + 1
    P("Loudness: " .. ({ "normal", "loud (200%)", "very loud (300%)" })[db.loud]); playSound()
  elseif cmd == "nosound" then
    db.sound = false; P("Sound off")
  elseif cmd == "move" and Smiler and Smiler.UnlockToasts then
    P(Smiler:UnlockToasts() and "Drag the alert box, then /lust move again to lock." or "Position saved.")
  elseif cmd == "move" then
    if not alert then buildAlert(); place() end
    alert.unlocked = not alert.unlocked
    alert.anim:Stop()
    alert:EnableMouse(alert.unlocked)
    if alert.unlocked then
      alert.icon:SetTexture(lustIcon()); alert.sub:SetText("Drag me, then /lust move to lock")
      alert:SetAlpha(1); alert:Show()
    else
      alert:Hide(); P("Position saved.")
    end
  elseif cmd == "scale" then
    local v = tonumber((msg or ""):match("scale%s+([%d%.]+)"))
    if v and v >= 0.5 and v <= 2 and Smiler and Smiler.SetToastScale then Smiler:SetToastScale(v); P("Alert size " .. v)
    elseif v and v >= 0.5 and v <= 2 then db.scale = v; if alert then place() end; P("Scale " .. v) else P("Usage: /lust scale 0.5–2") end
  elseif cmd == "reset" and Smiler and Smiler.ResetToasts then
    Smiler:ResetToasts(); P("Alert position and size reset.")
  elseif cmd == "reset" then
    db.point, db.scale = nil, 1; if alert then place() end; P("Position and size reset.")
  else
    P("Unknown command. Type /lust for help.")
  end
end

function LustReady_OnAddonCompartmentClick() status() end

---------------------------------------------------------------- Smiler: menu status line and settings tab
local function exhaustedLeft()
  local a = satedAura()
  if not a then return nil end
  if a.expirationTime and not secret(a.expirationTime) and a.expirationTime > 0 then
    local left = a.expirationTime - GetTime()
    return string.format("%d:%02d", math.floor(left / 60), left % 60)
  end
  return ""
end

if Smiler and Smiler.RegisterSettings then
  local S = Smiler

  S:RegisterStatus("lust", function()
    if not db then return nil end
    local left = exhaustedLeft()
    if left then return "Exhausted" .. (left ~= "" and (" · " .. left .. " left") or ""), "muted" end
    return "Lust available", "ready"
  end)

  S:RegisterSettings("LustReady", function(body, W)
    local L = W.Column(body, 0, 0, 290)
    L:Section("When to alert")
    L:Switch("Boss pulled, not Exhausted", nil, function() return db.onPull end, function(v) db.onPull = v end)
    L:Switch("Exhaustion wears off", nil, function() return db.onExpire end, function(v) db.onExpire = v end)
    L:Switch("Also outside raids and dungeons", "Expiry alert only", function() return db.expireAnywhere end, function(v) db.expireAnywhere = v end)
    L:Switch("Only on characters that can lust", nil, function() return db.onlyMine end, function(v) db.onlyMine = v end)

    local R = W.Column(body, 334, 0, 290)
    R:Section("Sound and look")
    local opts = { { "off", "No sound" } }
    for _, sd in ipairs(SOUNDS) do opts[#opts + 1] = { sd[1], sd[2] } end
    local play = W.IconButton(body, "play", 12, "text", function()
      if db.sound and not playSound() then P("Couldn't play that one – you'll hear the raid warning instead.") end
    end, "Play it")
    S.Panel(play, "raised", 1, 0.6)
    play:SetSize(28, 26)
    R:Dropdown("Sound", opts, function() return db.sound and db.soundKey or "off" end, function(k)
      if k == "off" then db.sound = false else db.sound = true; db.soundKey = k; playSound() end
    end, 150, play)
    R:Dropdown("Loudness", { { 1, "Normal" }, { 2, "Loud (200%)" }, { 3, "Very loud (300%)" } },
      function() return db.loud or 2 end, function(k) db.loud = k; playSound() end, 150)
    R:Slider("On screen for", 1, 8, 0.5, function() return db.duration or 3 end, function(v) db.duration = v end,
      function(v) return (v % 1 == 0 and string.format("%d s", v) or string.format("%.1f s", v)) end)
    R:Slider("Size", 0.5, 2, 0.05, function() return S.db.toastScale or 1 end, function(v) S:SetToastScale(v) end,
      function(v) return math.floor(v * 100 + 0.5) .. "%" end)
    local pos = R:Buttons("Position", { { "Move", function() S:UnlockToasts() end, nil, 70 }, { "Reset", function() S:ResetToasts() end, nil, 70 } })
    local moveBtn = select(1, pos:GetChildren())
    tinsert(body.smilerSync, { Sync = function() moveBtn:SetLabel(S.ToastsUnlocked() and "Done" or "Move") end })

    -- preview, drawn like the real alert
    local y = math.min(L.y, R.y) - 8
    local sec = S.Text(body, "label", 13, "muted"); sec:SetPoint("TOPLEFT", 0, y); sec:SetText("PREVIEW")
    local pv = CreateFrame("Frame", nil, body, "BackdropTemplate")
    pv:SetSize(380, 70); pv:SetPoint("TOPLEFT", 0, y - 24)
    S.Panel(pv, "void", 0.94, 0.6); pv:SetBackdropBorderColor(S.RGB("emerald", 0.6))
    S.TopLine(pv, "emerald", "diamond")
    local ic = pv:CreateTexture(nil, "ARTWORK"); ic:SetSize(46, 46); ic:SetPoint("LEFT", 14, 0)
    ic:SetTexCoord(0.08, 0.92, 0.08, 0.92); ic:SetTexture(lustIcon())
    local k = S.IconTex(pv, "tickcircle", 18, "emerald"); k:SetPoint("TOPLEFT", ic, "TOPRIGHT", 14, -4)
    local t = S.Text(pv, "display", 23, "emerald"); t:SetPoint("LEFT", k, "RIGHT", 7, 0); t:SetText("LUST AVAILABLE")
    local sub = S.Text(pv, "body", 13, "soft"); sub:SetPoint("BOTTOMLEFT", ic, "BOTTOMRIGHT", 14, 4)
    sub:SetText("Boss pulled · you're not Exhausted")

    return {
      note = "Changes save as you make them. /lust still works.",
      footer = {
        { "Defaults", function()
          for key, v in pairs(DEFAULTS) do db[key] = v end
          W.SyncAll(body)
        end, nil, 90 },
        { "Test alert", function() Alert("Test – this is what a boss pull looks like") end, "primary", 100 },
      },
    }
  end)
end
