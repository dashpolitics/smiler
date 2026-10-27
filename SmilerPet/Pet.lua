-- SmilerPet: one small movable icon per pet ability, with the cooldown sweep and countdown.
-- Default: Felhunter's Devour Magic. Reads the cooldown from your pet's spellbook.
local ADDON, ns = ...
SmilerPet = ns
local S = Smiler
local isSecret = issecretvalue or function() return false end
local function plain(v) return v ~= nil and not isSecret(v) end

local DEVOUR, SPELL_LOCK = 19505, 19647
local DEFAULTS = { spells = { DEVOUR }, size = 38, gap = 4, locked = false, hideNoPet = true, border = true, desat = true }
local db
local holder, icons = nil, {}
local WHITE = "Interface\\Buttons\\WHITE8x8"
local function say(...) print("|cffb98cffSmilerPet|r", ...) end
local function RGB(name, a)
  if S and S.RGB then return S.RGB(name, a) end
  local c = ({ emerald = { 0, 0.9, 0.46 }, edge = { 0.55, 0.31, 0.86 }, muted = { 0.7, 0.63, 0.86 }, void = { 0.02, 0.01, 0.06 } })[name] or { 1, 1, 1 }
  return c[1], c[2], c[3], a or 1
end

local function spellName(id)
  return (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or (GetSpellInfo and GetSpellInfo(id)) or ("Spell " .. id)
end
local function spellIcon(id)
  return (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)) or 134400
end

---------------------------------------------------------------- the pet's spellbook
local PET_BANK = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet or 1

-- slot of a pet spell (matched by id, or by name for ranks/variants), nil when the pet doesn't have it
local function petSlot(id)
  if not (C_SpellBook and C_SpellBook.HasPetSpells and C_SpellBook.GetSpellBookItemInfo) then return nil end
  local n = C_SpellBook.HasPetSpells()
  if not plain(n) or not n then return nil end
  local want = spellName(id)
  for i = 1, n do
    local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, i, PET_BANK)
    if ok and info then
      local sid = info.spellID or info.actionID
      if (plain(sid) and sid == id) or (plain(info.name) and info.name == want) then return i, sid end
    end
  end
end

-- start, duration, modRate (may be secret in combat: they only go to the cooldown widget)
local function cooldown(id, slot)
  if slot and C_SpellBook and C_SpellBook.GetSpellBookItemCooldown then
    local ok, cd = pcall(C_SpellBook.GetSpellBookItemCooldown, slot, PET_BANK)
    if ok and cd then return cd.startTime, cd.duration, cd.modRate end
  end
  if C_Spell and C_Spell.GetSpellCooldown then
    local ok, cd = pcall(C_Spell.GetSpellCooldown, id)
    if ok and cd then return cd.startTime, cd.duration, cd.modRate end
  end
end

---------------------------------------------------------------- icons
local function savePoint()
  local p, _, rp, x, y = holder:GetPoint()
  db.point = { p, rp, x, y }
end

local function makeIcon(i)
  local b = CreateFrame("Frame", nil, holder, "BackdropTemplate")
  b:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  b:SetBackdropColor(0, 0, 0, 0.6)
  b.tex = b:CreateTexture(nil, "ARTWORK")
  b.tex:SetPoint("TOPLEFT", 1, -1); b.tex:SetPoint("BOTTOMRIGHT", -1, 1)
  b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
  b.cd:SetPoint("TOPLEFT", 1, -1); b.cd:SetPoint("BOTTOMRIGHT", -1, 1)
  b.cd:SetDrawEdge(false)
  if b.cd.SetHideCountdownNumbers then b.cd:SetHideCountdownNumbers(false) end
  b.cd:SetScript("OnCooldownDone", function() ns.Update() end)
  b:EnableMouse(true)
  b:RegisterForDrag("LeftButton")
  b:SetScript("OnDragStart", function() if not db.locked then holder:StartMoving() end end)
  b:SetScript("OnDragStop", function() holder:StopMovingOrSizing(); savePoint() end)
  b:SetScript("OnEnter", function(s)
    if not s.spell then return end
    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
    if GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(s.spell) else GameTooltip:AddLine(spellName(s.spell)) end
    GameTooltip:AddLine(db.locked and "Locked · /petcd lock to move" or "Drag to move · /petcd lock to lock", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  icons[i] = b
  return b
end

local function layout()
  local shown = 0
  for i, b in ipairs(icons) do
    if b:IsShown() then
      b:ClearAllPoints()
      b:SetPoint("LEFT", holder, "LEFT", shown * (db.size + db.gap), 0)
      shown = shown + 1
    end
  end
  holder:SetSize(math.max(1, shown * (db.size + db.gap) - db.gap), db.size)
end

local PET_CLASS = { WARLOCK = true, HUNTER = true, DEATHKNIGHT = true, MAGE = true }
function ns.PetClass() local _, c = UnitClass("player"); return PET_CLASS[c or ""] or false end

function ns.Update()
  if not holder then return end
  if not ns.PetClass() then holder:Hide(); return end     -- nothing to track on this class: stay out of the way
  local any = false
  for i, id in ipairs(db.spells) do
    local b = icons[i] or makeIcon(i)
    b.spell = id
    b:SetSize(db.size, db.size)
    b.tex:SetTexture(spellIcon(id))
    local slot = petSlot(id)
    local has = slot ~= nil
    local placeholder = not has and not db.locked       -- unlocked: always show so you can place it
    b:SetShown(has or placeholder or not db.hideNoPet)
    if b:IsShown() then any = true end
    if has then
      local start, dur, rate = cooldown(id, slot)
      local onCD = false
      if start and dur then
        if plain(start) and plain(dur) then
          onCD = dur > 1.5 and start > 0                -- ignore the pet's global cooldown
          if onCD then b.cd:SetCooldown(start, dur, plain(rate) and rate or 1) else b.cd:Clear() end
        else
          b.cd:SetCooldown(start, dur, rate)            -- secret in combat: the widget can still draw it
          onCD = nil
        end
      else
        b.cd:Clear()
      end
      b.tex:SetDesaturated(db.desat and onCD == true)
      b.tex:SetAlpha(1)
      if db.border then
        if onCD == false then b:SetBackdropBorderColor(RGB("emerald", 0.9)) else b:SetBackdropBorderColor(RGB("edge", 0.5)) end
      else
        b:SetBackdropBorderColor(0, 0, 0, 1)
      end
    else
      b.cd:Clear()
      b.tex:SetDesaturated(true); b.tex:SetAlpha(0.4)
      b:SetBackdropBorderColor(RGB("muted", 0.6))
    end
  end
  for i = #db.spells + 1, #icons do icons[i]:Hide() end
  holder:SetShown(any)
  layout()
end

local function build()
  holder = CreateFrame("Frame", "SmilerPetFrame", UIParent)
  holder:SetMovable(true)
  holder:SetClampedToScreen(true)
  holder:SetFrameStrata("MEDIUM")
  if db.point then holder:SetPoint(db.point[1], UIParent, db.point[2], db.point[3], db.point[4])
  else holder:SetPoint("CENTER", UIParent, "CENTER", 0, -160) end
end

---------------------------------------------------------------- spells list
local function resolve(arg)
  local id = tonumber(arg)
  if id then return id end
  if C_Spell and C_Spell.GetSpellIDForSpellIdentifier then
    local ok, r = pcall(C_Spell.GetSpellIDForSpellIdentifier, arg)
    if ok and r then return r end
  end
  -- by name from the pet's spellbook
  if C_SpellBook and C_SpellBook.HasPetSpells then
    local n = C_SpellBook.HasPetSpells() or 0
    for i = 1, (plain(n) and n or 0) do
      local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, i, PET_BANK)
      if ok and info and plain(info.name) and info.name:lower() == arg:lower() then return info.spellID or info.actionID end
    end
  end
end

function ns.Add(id)
  for _, s in ipairs(db.spells) do if s == id then return false end end
  db.spells[#db.spells + 1] = id
  ns.Update()
  return true
end
function ns.Remove(id)
  for i, s in ipairs(db.spells) do if s == id then table.remove(db.spells, i); ns.Update(); return true end end
end
function ns.Has(id) for _, s in ipairs(db.spells) do if s == id then return true end end end
function ns.ResetPosition() db.point = nil; holder:ClearAllPoints(); holder:SetPoint("CENTER", UIParent, "CENTER", 0, -160) end

---------------------------------------------------------------- Smiler settings
if S and S.RegisterSettings then
  S:RegisterSettings("PetCD", function(body, W)
    local A = W.Column(body, 0, 0, 290)
    A:Section("Icon")
    A:Switch("Lock position", "Unlocked: drag the icon; it shows even without your pet", function() return db.locked end, function(v) db.locked = v; ns.Update() end)
    A:Slider("Size", 24, 64, 1, function() return db.size end, function(v) db.size = v; ns.Update() end, function(v) return v .. " px" end, 120)
    A:Switch("Hide without the pet", "e.g. Felguard out, or no pet", function() return db.hideNoPet end, function(v) db.hideNoPet = v; ns.Update() end)
    A:Switch("Grey while on cooldown", nil, function() return db.desat end, function(v) db.desat = v; ns.Update() end)
    A:Switch("Green border when ready", nil, function() return db.border end, function(v) db.border = v; ns.Update() end)
    local B = W.Column(body, 334, 0, 290)
    B:Section("Abilities")
    B:Switch("Devour Magic", "Felhunter dispel", function() return ns.Has(DEVOUR) end, function(v) if v then ns.Add(DEVOUR) else ns.Remove(DEVOUR) end end)
    B:Switch("Spell Lock", "Felhunter interrupt", function() return ns.Has(SPELL_LOCK) end, function(v) if v then ns.Add(SPELL_LOCK) else ns.Remove(SPELL_LOCK) end end)
    B:Note("Any other pet ability: /petcd add <name or spell ID>, /petcd remove <name or ID>.", "muted", 12)
    return { note = "/petcd lock toggles moving. In combat the game may hide the exact numbers from add-ons; the sweep still shows.",
             footer = { { "Reset position", function() ns.ResetPosition() end, nil, 120 } } }
  end)
  if S.RegisterStatus then
    S:RegisterStatus("petcd", function()
      if not db then return nil end
      local names = {}
      for _, id in ipairs(db.spells) do names[#names + 1] = spellName(id) end
      if not ns.PetClass() then return "Not a pet class – nothing to show here", "muted" end
      if #names == 0 then return "No pet abilities tracked", "muted" end
      return "Tracking " .. table.concat(names, ", ") .. (db.locked and "" or " · unlocked"), "muted"
    end)
  end
end

---------------------------------------------------------------- events
local ev = CreateFrame("Frame")
ns.ev = ev
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "SPELL_UPDATE_COOLDOWN",
                     "PET_BAR_UPDATE", "PET_BAR_UPDATE_COOLDOWN", "UNIT_PET" }) do ev:RegisterEvent(e) end
if ev.RegisterUnitEvent then ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "pet") end
ev:SetScript("OnEvent", function(_, e, a1)
  if e == "ADDON_LOADED" then
    if a1 ~= ADDON then return end
    SmilerPetDB = SmilerPetDB or {}
    db = SmilerPetDB
    for k, v in pairs(DEFAULTS) do if db[k] == nil then db[k] = type(v) == "table" and { unpack(v) } or v end end
    ns.db = db
    build()
    return
  end
  if not db then return end
  if e == "UNIT_PET" and a1 ~= "player" then return end
  ns.Update()
  if e == "UNIT_PET" or e == "PLAYER_ENTERING_WORLD" or e == "SPELLS_CHANGED" then
    C_Timer.After(1, ns.Update)               -- the pet's spellbook fills in a moment after it appears
  end
end)

---------------------------------------------------------------- slash
SLASH_SMILERPET1 = "/petcd"
SlashCmdList.SMILERPET = function(msg)
  msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local cmd, arg = msg:match("^(%S*)%s*(.*)$")
  cmd = cmd:lower()
  if cmd == "lock" then
    db.locked = not db.locked; ns.Update(); say(db.locked and "locked" or "unlocked – drag the icon")
  elseif cmd == "add" and arg ~= "" then
    local id = resolve(arg)
    if not id then say("couldn't find '" .. arg .. "' – summon the pet, or use the spell ID") return end
    say(ns.Add(id) and ("tracking " .. spellName(id)) or (spellName(id) .. " is already tracked"))
  elseif (cmd == "remove" or cmd == "del") and arg ~= "" then
    local id = resolve(arg)
    say(id and ns.Remove(id) and ("stopped tracking " .. spellName(id)) or "not tracked")
  elseif cmd == "size" and tonumber(arg) then
    db.size = math.max(16, math.min(96, tonumber(arg))); ns.Update()
  elseif cmd == "reset" then ns.ResetPosition()
  elseif cmd == "" or cmd == "settings" or cmd == "options" then
    if S and S.OpenSettings then S:OpenSettings("PetCD") else
      db.locked = not db.locked; ns.Update(); say(db.locked and "locked" or "unlocked – drag the icon")
    end
  else
    say("/petcd  settings · lock · add <name|id> · remove <name|id> · size <px> · reset")
  end
end
