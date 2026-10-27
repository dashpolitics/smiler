-- Smiler: the shared look, settings window, menu and alerts for Tom's add-ons.
-- Each add-on works on its own; with Smiler installed they share one style and one place for settings.
local ADDON, S = ...
Smiler = S

S.VERSION = "1.1.0"

---------------------------------------------------------------- Crystal Ball palette
-- One meaning per gem colour, and each one always comes with a shape or a word.
S.C = {
  void     = { 0.024, 0.012, 0.059 },  -- window ground
  card     = { 0.110, 0.063, 0.227 },  -- panels, rows
  raised   = { 0.133, 0.078, 0.275 },  -- buttons, hover
  edge     = { 0.549, 0.314, 0.863 },  -- smoke border (use at 0.38 alpha, 0.6 on controls)
  text     = { 0.941, 0.922, 1.000 },  -- names, numbers
  soft     = { 0.847, 0.784, 1.000 },  -- body text
  muted    = { 0.706, 0.627, 0.863 },  -- labels, hints
  amethyst = { 0.714, 0.431, 1.000 },  -- brand, selected, focus
  diamond  = { 0.910, 0.957, 1.000 },  -- records, BiS · star
  emerald  = { 0.000, 0.902, 0.463 },  -- ready, done · tick
  topaz    = { 1.000, 0.671, 0.000 },  -- upgrade, bonus roll · arrow up
  ruby     = { 1.000, 0.176, 0.333 },  -- death, danger · warning
  sapphire = { 0.361, 0.608, 1.000 },  -- info, phases · i (lightened #2979FF for text on dark)
}
S.HEX = {}
for k, c in pairs(S.C) do S.HEX[k] = string.format("%02x%02x%02x", c[1] * 255 + 0.5, c[2] * 255 + 0.5, c[3] * 255 + 0.5) end

function S.RGB(name, a)
  local c = S.C[name] or S.C.text
  return c[1], c[2], c[3], a or 1
end
function S.Color(name, text) return "|cff" .. (S.HEX[name] or "ffffff") .. text .. "|r" end

-- gem kinds: colour + icon
S.KIND = {
  ready   = { color = "emerald",  icon = "tickcircle" },
  record  = { color = "diamond",  icon = "star" },
  death   = { color = "ruby",     icon = "warn" },
  upgrade = { color = "topaz",    icon = "arrow" },
  info    = { color = "sapphire", icon = "info" },
  brand   = { color = "amethyst", icon = "ball" },
}

---------------------------------------------------------------- fonts and media
local MEDIA = "Interface\\AddOns\\Smiler\\Media\\"
local FD = "Interface\\AddOns\\Smiler\\Fonts\\"
S.FONTS = {
  display = FD .. "BarlowCondensed-Bold.ttf",      -- titles, big numbers, grid cells
  label   = FD .. "BarlowCondensed-SemiBold.ttf",  -- section labels, tags
  body    = FD .. "Barlow-Medium.ttf",             -- body text
  strong  = FD .. "Barlow-SemiBold.ttf",           -- emphasised body, buttons
}
local FALLBACK = {
  display = "Fonts\\FRIZQT__.TTF", label = "Fonts\\FRIZQT__.TTF",
  body = "Fonts\\ARIALN.TTF", strong = "Fonts\\ARIALN.TTF",
}

function S.Icon(name) return MEDIA .. name end
S.WHITE = "Interface\\Buttons\\WHITE8x8"
S.BACKDROP = { bgFile = S.WHITE, edgeFile = S.WHITE, edgeSize = 1 }

function S.Font(fs, role, size, flags)
  role = S.FONTS[role] and role or "body"
  if not fs:SetFont(S.FONTS[role], size, flags or "") then
    fs:SetFont(FALLBACK[role], size, flags or "")
  end
  if not flags or flags == "" then
    fs:SetShadowColor(0, 0, 0, 0.85); fs:SetShadowOffset(1, -1)
  end
end

function S.Text(parent, role, size, color, justify, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY")
  S.Font(fs, role, size)
  fs:SetTextColor(S.RGB(color or "text"))
  fs:SetJustifyH(justify or "LEFT")
  fs:SetWordWrap(false)
  return fs
end

-- spaced-out window title: "SMILER" -> "S M I L E R"
function S.Spaced(text) return (text:upper():gsub("(.)", "%1 "):gsub(" $", "")) end

function S.Panel(f, bgName, bgAlpha, edgeAlpha)
  if not f.SetBackdrop then Mixin(f, BackdropTemplateMixin) end
  f:SetBackdrop(S.BACKDROP)
  f:SetBackdropColor(S.RGB(bgName or "void", bgAlpha or 0.96))
  f:SetBackdropBorderColor(S.RGB("edge", edgeAlpha or 0.38))
end

-- 2px gradient line along a frame's top edge
function S.TopLine(f, from, to)
  local t = f:CreateTexture(nil, "ARTWORK", nil, 7)
  t:SetPoint("TOPLEFT", 1, -1); t:SetPoint("TOPRIGHT", -1, -1); t:SetHeight(2)
  t:SetColorTexture(1, 1, 1, 1)
  local a, b = S.C[from or "amethyst"], S.C[to or "diamond"]
  t:SetGradient("HORIZONTAL", CreateColor(a[1], a[2], a[3], 1), CreateColor(b[1], b[2], b[3], 1))
  f.topLine = t
  return t
end

function S.IconTex(parent, name, size, color, layer)
  local t = parent:CreateTexture(nil, layer or "OVERLAY")
  t:SetTexture(S.Icon(name))
  t:SetSize(size, size)
  t:SetVertexColor(S.RGB(color or "text"))
  return t
end

function S.Print(...) print("|cff" .. S.HEX.amethyst .. "Smiler|r", ...) end

---------------------------------------------------------------- modules
-- Every add-on in the pack. Settings tabs appear in this order.
local function slash(key, arg)
  return function()
    local f = SlashCmdList and SlashCmdList[key]
    if f then f(arg or "") end
  end
end

S.MODULES = {
  { key = "SmilerKeys", addon = "SmilerKeys", title = "SmilerKeys", slash = "/sk",
    desc = "Your friends' best timed keys, current keystones and Resilient levels in one grid.",
    menu = "SmilerKeys", open = slash("SMILERKEYS", "") },
  { key = "Loot", addon = "SmilerKeys", partOf = "SmilerKeys", title = "Loot & wishlist", slash = "/sk loot",
    desc = "A wishlist box for every gear slot beside your character sheet, and where to bonus roll or farm.",
    menu = "Loot & wishlist", open = slash("SMILERKEYS", "loot") },
  { key = "CDTimeline", addon = "CDTimeline", title = "CD Timeline", slash = "/tl",
    desc = "Boss mechanics and healer cooldowns sliding towards a now line.",
    needs = "a healer (throughput numbers so far for Holy Paladin; other healers get the boss timeline)",
    fits = function() return S.Role() == "HEALER" end,
    menu = "CD Timeline planner", open = slash("CDTIMELINE", "plan"),
    settingsLabel = "Open CD Timeline settings", settings = slash("CDTIMELINE", "options") },
  { key = "RampNotes", addon = "RampNotes", title = "RampNotes", slash = "/rn",
    desc = "Plain on-screen notes with draggable spell rows for ramps and rotations.",
    menu = "RampNotes", open = slash("RAMPNOTES", ""),
    settingsLabel = "Open RampNotes settings", settings = slash("RAMPNOTES", "settings") },
  { key = "DiedTo", addon = "DiedTo", title = "DiedTo", slash = "/diedto",
    desc = "What killed each group member, and the hits leading up to it.",
    menu = "DiedTo deaths", open = slash("DIEDTO", ""),
    settingsLabel = "Open DiedTo settings", settings = slash("DIEDTO", "settings") },
  { key = "Rewound", addon = "Rewound", title = "Rewound", slash = "/rewound",
    desc = "Records your Preservation Evoker Rewinds and announces a new best.",
    menu = "Rewound records", open = function() S:OpenSettings("Rewound") end,
    needs = "Preservation Evoker", fits = function() return S.Spec() == 1468 end },
  { key = "Splits", addon = "SmilerSplits", title = "SmilerSplits", slash = "/splits",
    desc = "Mythic+ boss splits against your run nearest this key level, and whether you're on pace to time it.",
    menu = "M+ splits", open = slash("SMILERSPLITS", "") },
  { key = "PetCD", addon = "SmilerPet", title = "Pet cooldowns", slash = "/petcd",
    desc = "A small movable icon for your pet's abilities, like Felhunter Devour Magic.",
    open = function() S:OpenSettings("PetCD") end,
    needs = "a class with a pet (Warlock, Hunter, Death Knight, Mage)",
    fits = function() local c = S.Class(); return c == "WARLOCK" or c == "HUNTER" or c == "DEATHKNIGHT" or c == "MAGE" end },
  { key = "Beacons", addon = "SmilerBeacons", title = "Beacons", slash = "/beacons",
    desc = "Holy Paladin: warns when Beacon of Light or Faith isn't on anyone in your group.",
    open = function() S:OpenSettings("Beacons") end,
    needs = "Holy Paladin with the Beacon of Faith talent", fits = function() return S.Class() == "PALADIN" end },
  { key = "LustReady", addon = "LustReady", title = "LustReady", slash = "/lust",
    desc = "Tells you lust is up when a boss is pulled, and when Exhaustion wears off." },
}
S.byKey = {}
for _, m in ipairs(S.MODULES) do S.byKey[m.key] = m end

-- this character
function S.Class() local _, c = UnitClass("player"); return c end
function S.Spec() local i = GetSpecialization and GetSpecialization(); return i and GetSpecializationInfo(i) or 0 end
function S.Role() local i = GetSpecialization and GetSpecialization(); return i and select(5, GetSpecializationInfo(i)) or nil end
-- true = useful on this character, false = stays quiet here, nil = for everyone
function S.Fits(m) if not m.fits then return nil end local ok, v = pcall(m.fits); return ok and v or false end

-- an add-on fills its own settings tab: builder(body, W) -> optional { footer = { {label, fn, primary}, ... }, note = "..." }
function S:RegisterSettings(key, builder)
  local m = S.byKey[key]
  if m then m.builder = builder end
end

-- status lines in the menu: fn() -> text, kind ("ready", "muted", ...)
S.status = {}
function S:RegisterStatus(id, fn) S.status[#S.status + 1] = { id = id, fn = fn } end

local function addonInfo(name)
  if not C_AddOns or not C_AddOns.GetAddOnInfo then return true, true end
  local ok, _, _, _, _, reason = pcall(C_AddOns.GetAddOnInfo, name)
  local installed = ok and reason ~= "MISSING"
  return installed, C_AddOns.IsAddOnLoaded(name)
end

-- installed, loaded, enabledNextReload
function S.ModuleState(m)
  local installed, loaded = addonInfo(m.addon)
  local enabled = loaded
  if installed and C_AddOns.GetAddOnEnableState then
    enabled = (C_AddOns.GetAddOnEnableState(m.addon, UnitName("player")) or 0) > 0
  end
  return installed, loaded, enabled
end

S.pendingReload = false
function S.SetModuleEnabled(m, on)
  if on then C_AddOns.EnableAddOn(m.addon) else C_AddOns.DisableAddOn(m.addon) end
  local _, loaded = addonInfo(m.addon)
  S.pendingReload = (on ~= loaded) or S.pendingReload
  if S.RefreshSettings then S.RefreshSettings() end
end

---------------------------------------------------------------- saved settings
local DEFAULTS = {
  toastScale = 1,
  toastPoint = nil,
  tab = "General",
}

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(_, e, name)
  if name ~= ADDON then return end
  SmilerDB = SmilerDB or {}
  for k, v in pairs(DEFAULTS) do if SmilerDB[k] == nil then SmilerDB[k] = v end end
  S.db = SmilerDB
  ev:UnregisterEvent("ADDON_LOADED")
end)

-- first login with the pack: one chat line, and the settings window once things have settled
local hello = CreateFrame("Frame")
hello:RegisterEvent("PLAYER_LOGIN")
hello:SetScript("OnEvent", function()
  if not S.db then return end
  local have, quiet = {}, {}
  for _, m in ipairs(S.MODULES) do
    if not m.partOf then
      local installed, loaded = S.ModuleState(m)
      if installed and loaded then
        if S.Fits(m) == false then quiet[#quiet + 1] = m.title else have[#have + 1] = m.title end
      end
    end
  end
  if S.db.welcomed ~= S.VERSION then
    S.db.welcomed = S.VERSION
    S.Print("v" .. S.VERSION .. " – " .. #have .. " add-on" .. (#have == 1 and "" or "s") .. " on: " .. table.concat(have, ", ") .. ". /smiler opens the menu.")
    if #quiet > 0 then S.Print("Not for this character, so they stay quiet: " .. table.concat(quiet, ", ") .. ".") end
    C_Timer.After(4, function() if not InCombatLockdown() then S:OpenSettings("General") end end)
  end
end)

---------------------------------------------------------------- slash
SLASH_SMILER1 = "/smiler"
SlashCmdList.SMILER = function(msg)
  local cmd = (msg or ""):lower():match("^%s*(%S*)")
  if cmd == "" then S:OpenSettings()
  elseif cmd == "menu" then S:ToggleMenu()
  elseif cmd == "move" then S:UnlockToasts()
  elseif cmd == "test" then S:TestToasts()
  else
    local m = S.byKey[cmd] or S.byKey[msg]
    for _, mm in ipairs(S.MODULES) do if mm.key:lower() == cmd then m = mm end end
    if m then S:OpenSettings(m.key) else S.Print("/smiler · /smiler menu · /smiler move · /smiler test") end
  end
end
