-- Rewound: Preservation Evoker Rewind high scores.
-- Midnight gives addons no combat log, so per-cast amounts aren't visible.
-- We count your Rewind casts, then read your own per-spell healing for that fight
-- from the built-in damage meter (C_DamageMeter) once combat ends.
local ADDON, ns = ...

ns.VERSION   = "0.3.1"
ns.REWIND    = 363534
local REWIND = ns.REWIND
local PRES_SPEC = 1468
ns.FONT      = "Fonts\\FRIZQT__.TTF"
ns.NUM_FONT  = "Fonts\\ARIALN.TTF"
ns.BACKDROP  = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }

-- Crystal Ball palette (shared with Crosskeys)
ns.C = {
  bg     = { 0.050, 0.038, 0.090, 0.96 },
  panel  = { 0.095, 0.070, 0.160, 1 },
  sel    = { 0.240, 0.170, 0.420, 1 },
  border = { 0.56, 0.40, 0.96, 0.90 },
  edge   = { 0.32, 0.23, 0.55, 1 },
  accent = { 0.80, 0.69, 1.00 },
  text   = { 0.92, 0.90, 1.00 },
  dim    = { 0.56, 0.51, 0.70 },
  faint  = { 0.33, 0.30, 0.44 },
  crystal = { 1.00, 0.97, 1.00 },
}
-- with Smiler installed, use its exact Crystal Ball palette and fonts
if Smiler and Smiler.C then
  local SC = Smiler.C
  local function a(c, al) return { c[1], c[2], c[3], al or 1 } end
  ns.FONT, ns.NUM_FONT = Smiler.FONTS.label, Smiler.FONTS.body
  ns.C.bg, ns.C.panel, ns.C.sel = a(SC.void, 0.96), a(SC.raised), { 0.30, 0.18, 0.48, 1 }
  ns.C.border, ns.C.edge = a(SC.amethyst, 0.9), a(SC.edge, 0.6)
  ns.C.accent, ns.C.text, ns.C.dim = a(SC.amethyst), a(SC.text), a(SC.muted)
  ns.C.faint, ns.C.crystal = { 0.45, 0.40, 0.58, 1 }, a(SC.diamond)
end
local C = ns.C

-- "mplus" covers every dungeon, keyed or not (the key name stays for saved data)
ns.KINDS = { "mplus", "raid", "other" }
ns.KIND_LABEL = { mplus = "Dungeon", raid = "Raid", other = "Other" }

-- { key, label, SOUNDKIT name } – entries whose SOUNDKIT doesn't exist are skipped
ns.SOUNDS = {
  { "epic",  "Epic loot",    "UI_EPICLOOT_TOAST" },
  { "warn",  "Raid warning", "RAID_WARNING" },
  { "ready", "Ready check",  "READY_CHECK" },
  { "alarm", "Alarm",        "ALARM_CLOCK_WARNING_3" },
}

ns.DEFAULT_TEMPLATE = "New {kind}Rewind record: {amount}{avg} ({prev}) – {where}"

local DEFAULTS = {
  announce = { enabled = true, channel = "auto", template = ns.DEFAULT_TEMPLATE, minGain = 0, categories = false },
  toast    = { record = true, every = true, sound = true, soundKey = "epic", scale = 1, duration = 4.5 },
  track    = { mplus = true, raid = true, other = true, needGroup = false },
}

local db, S
local casts, ctx, pendingTries = 0, nil, 0
local encounterName

function ns.Print(...) print("|cffb98cffRewound|r", ...) end
local P = ns.Print
local function secret(v) return issecretvalue and issecretvalue(v) or false end

function ns.fmt(n)
  if not n then return "?" end
  if n >= 1e6 then return string.format("%.2fM", n / 1e6) end
  if n >= 1e3 then return string.format("%.0fK", n / 1e3) end
  return tostring(math.floor(n + 0.5))
end
local fmt = ns.fmt

local function isPres()
  local idx = GetSpecialization and GetSpecialization()
  return idx and GetSpecializationInfo(idx) == PRES_SPEC
end

---------------------------------------------------------------- context
local function context()
  local name, itype, _, diffName = GetInstanceInfo()
  local c = { group = IsInGroup() }
  if C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then
    local level = C_ChallengeMode.GetActiveKeystoneInfo()
    local mapID = C_ChallengeMode.GetActiveChallengeMapID()
    local mname = mapID and C_ChallengeMode.GetMapUIInfo(mapID)
    c.kind, c.where = "mplus", (mname or name) .. " +" .. (level or "?")
  elseif itype == "raid" then
    c.kind = "raid"
    c.where = encounterName and (encounterName .. " · " .. (diffName or name)) or name
  elseif itype == "party" then
    c.kind = "mplus"
    c.where = (encounterName and (encounterName .. " · ") or "") .. name .. (diffName and diffName ~= "" and (" (" .. diffName .. ")") or "")
  else
    c.kind, c.where = "other", encounterName or name or "the open world"
  end
  return c
end

---------------------------------------------------------------- message template
-- tokens: {amount} {avg} {prev} {gain} {where} {casts} {total} {kind}
function ns.FillTemplate(tpl, v)
  tpl = ((tpl and tpl ~= "") and tpl or ns.DEFAULT_TEMPLATE):gsub("|", "")
  local out = tpl:gsub("{(%a+)}", function(k)
    local x = v[k]
    if x == nil then return "{" .. k .. "}" end
    return tostring(x)
  end)
  return (out:sub(1, 255))
end

function ns.TemplateValues(per, total, n, prev, where, kindLabel)
  return {
    amount = fmt(per),
    avg    = n > 1 and string.format(" (avg of %d)", n) or "",
    casts  = n,
    total  = fmt(total),
    prev   = prev and ("prev " .. fmt(prev.amount)) or "first record",
    gain   = prev and prev.amount > 0 and string.format("+%.0f%%", (per / prev.amount - 1) * 100) or "",
    where  = where or "?",
    kind   = kindLabel and (kindLabel .. " ") or "",
  }
end

---------------------------------------------------------------- chat (held during lockdown)
local outbox = {}

local function resolveChannel()
  local ch = S.announce.channel
  local inst = IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
  if ch == "self" then return nil end
  if ch == "guild" then return IsInGuild() and "GUILD" or nil end
  if ch == "raid" then return IsInRaid() and (inst and "INSTANCE_CHAT" or "RAID") or nil end
  if ch == "party" then return (IsInGroup() and not IsInRaid()) and (inst and "INSTANCE_CHAT" or "PARTY") or nil end
  if inst then return "INSTANCE_CHAT" end
  if IsInRaid() then return "RAID" end
  if IsInGroup() then return "PARTY" end
end

local function lockdown()
  return C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
end

local function flush()
  if #outbox == 0 or lockdown() then return end
  local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
  while #outbox > 0 do
    local msg = table.remove(outbox, 1)
    local ch = resolveChannel()
    if ch then pcall(send, msg, ch) else P(msg) end
  end
end

local function announce(msg)
  if not S.announce.enabled then P(msg); return end
  outbox[#outbox + 1] = msg
  flush()
  if #outbox > 0 then P("Record saved – announcing once the key or encounter ends.") end
end

---------------------------------------------------------------- toast
local toast

local function soundID()
  for _, s in ipairs(ns.SOUNDS) do
    if s[1] == S.toast.soundKey then return SOUNDKIT and SOUNDKIT[s[3]] end
  end
end

function ns.PlayRecordSound()
  local id = soundID()
  if id then pcall(PlaySound, id) end
end

local function placeToast()
  toast:ClearAllPoints()
  local pt = S.toast.point
  if pt then toast:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4]) else toast:SetPoint("TOP", 0, -150) end
  toast:SetScale(S.toast.scale or 1)
end

local function buildToast()
  toast = CreateFrame("Frame", "RewoundToast", UIParent, "BackdropTemplate")
  toast:SetSize(340, 86)
  toast:SetFrameStrata("HIGH")
  toast:SetClampedToScreen(true)
  toast:SetMovable(true)
  toast:RegisterForDrag("LeftButton")
  toast:SetScript("OnDragStart", toast.StartMoving)
  toast:SetScript("OnDragStop", function(s)
    s:StopMovingOrSizing()
    local p, _, rp, x, y = s:GetPoint()
    S.toast.point = { p, rp, x, y }
  end)
  toast:SetBackdrop(ns.BACKDROP)
  toast:SetBackdropColor(unpack(C.bg))
  toast:SetBackdropBorderColor(unpack(C.border))
  local line = toast:CreateTexture(nil, "ARTWORK")
  line:SetPoint("TOPLEFT", 1, -1); line:SetPoint("TOPRIGHT", -1, -1); line:SetHeight(2)
  line:SetColorTexture(1, 1, 1, 1)
  line:SetGradient("HORIZONTAL", CreateColor(0.40, 0.24, 0.84, 1), CreateColor(0.92, 0.85, 1, 1))

  toast.icon = toast:CreateTexture(nil, "ARTWORK")
  toast.icon:SetPoint("LEFT", 14, 0)
  toast.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  toast.icon:SetTexture(C_Spell.GetSpellTexture(REWIND))

  toast.title = toast:CreateFontString(nil, "OVERLAY")
  toast.title:SetFont(ns.FONT, 11, "")
  toast.title:SetTextColor(unpack(C.accent))
  toast.title:SetPoint("TOPLEFT", toast.icon, "TOPRIGHT", 12, -1)

  toast.num = toast:CreateFontString(nil, "OVERLAY")
  toast.num:SetTextColor(unpack(C.crystal))
  toast.num:SetPoint("LEFT", toast.icon, "RIGHT", 12, 0)
  toast.num:SetShadowOffset(1, -1)

  toast.sub = toast:CreateFontString(nil, "OVERLAY")
  toast.sub:SetFont(ns.NUM_FONT, 12, "")
  toast.sub:SetTextColor(unpack(C.dim))
  toast.sub:SetPoint("BOTTOMLEFT", toast.icon, "BOTTOMRIGHT", 12, 1)
  toast.sub:SetPoint("RIGHT", -12, 0)
  toast.sub:SetJustifyH("LEFT")
  toast.sub:SetWordWrap(false)

  toast.anim = toast:CreateAnimationGroup()
  local fin = toast.anim:CreateAnimation("Alpha"); fin:SetFromAlpha(0); fin:SetToAlpha(1); fin:SetDuration(0.25); fin:SetOrder(1)
  toast.hold = toast.anim:CreateAnimation("Alpha"); toast.hold:SetFromAlpha(1); toast.hold:SetToAlpha(1); toast.hold:SetOrder(2)
  local fout = toast.anim:CreateAnimation("Alpha"); fout:SetFromAlpha(1); fout:SetToAlpha(0); fout:SetDuration(0.8); fout:SetOrder(3)
  toast.anim:SetScript("OnFinished", function() if not toast.unlocked then toast:Hide() end end)
  toast:Hide()
  placeToast()
end

local function fillToast(title, num, sub, big)
  toast.title:SetText(title)
  toast.num:SetFont(ns.NUM_FONT, big and 28 or 20, "")
  toast.num:SetText(num)
  toast.sub:SetText(sub)
  toast:SetHeight(big and 86 or 70)
  toast.icon:SetSize(big and 54 or 40, big and 54 or 40)
end

function ns.ShowToast(title, num, sub, big)
  if Smiler and Smiler.Toast then
    Smiler:Toast({ kind = big and "record" or "info", id = "rewound", title = title, sub = num .. "  ·  " .. sub,
      icon = C_Spell.GetSpellTexture(REWIND), glow = big, duration = S.toast.duration or 4.5 })
    if big and S.toast.sound then ns.PlayRecordSound() end
    return
  end
  if not toast then buildToast() end
  if toast.unlocked then return end
  fillToast(title, num, sub, big)
  toast.hold:SetDuration(S.toast.duration or 4.5)
  toast:SetAlpha(0)
  toast:Show()
  toast.anim:Stop(); toast.anim:Play()
  if big and S.toast.sound then ns.PlayRecordSound() end
end

function ns.TestToast()
  local fake = math.random(400000, 2600000)
  ns.ShowToast("NEW REWIND RECORD", fmt(fake), "test only – nothing saved", true)
end

function ns.ApplyToastSettings()
  if toast then placeToast() end
end

function ns.SetToastUnlocked(on)
  if not toast then buildToast() end
  toast.unlocked = on
  toast.anim:Stop()
  toast:EnableMouse(on)
  if on then
    fillToast("DRAG TO MOVE", "1.25M", "Lock it again in Rewound settings", true)
    toast:SetAlpha(1)
    toast:Show()
  else
    toast:Hide()
  end
end

function ns.IsToastUnlocked() return toast and toast.unlocked or false end
if Smiler and Smiler.UnlockToasts then
  function ns.SetToastUnlocked(on) Smiler:UnlockToasts(on) end
  function ns.IsToastUnlocked() return Smiler.ToastsUnlocked() end
  function ns.ResetToastPosition() Smiler:ResetToasts() end
end

function ns.ResetToastPosition()
  S.toast.point = nil
  ns.ApplyToastSettings()
end

---------------------------------------------------------------- reading the damage meter
-- Your own HealingDone breakdown for the last fight, sorted: { {id, amount}, ... }
function ns.ReadHealing()
  if InCombatLockdown() then return nil, "Can't read during combat." end
  if not C_DamageMeter or not C_DamageMeter.GetCombatSessionSourceFromType then
    return nil, "The game's damage meter isn't available."
  end
  local ok, src = pcall(C_DamageMeter.GetCombatSessionSourceFromType,
    Enum.DamageMeterSessionType.Current, Enum.DamageMeterType.HealingDone, UnitGUID("player"))
  if not ok or not src or secret(src) or not src.combatSpells or secret(src.combatSpells) then
    return nil, "No healing recorded for the last fight."
  end
  local list = {}
  for _, sp in ipairs(src.combatSpells) do
    local id, amt = sp.spellID, sp.totalAmount
    if id and amt and not secret(id) and not secret(amt) then
      list[#list + 1] = { id = id, amount = amt }
    end
  end
  table.sort(list, function(a, b) return a.amount > b.amount end)
  return list
end

---------------------------------------------------------------- scoring
local function record(total, n, c)
  if not S.track[c.kind] or (S.track.needGroup and not c.group) then return end

  local per = total / n
  local e = { amount = per, total = total, casts = n, when = time(), where = c.where, kind = c.kind }
  table.insert(db.history, 1, e)
  while #db.history > 30 do table.remove(db.history) end

  local kindPrev = db.bestBy[c.kind]
  local isKindBest = not kindPrev or per > kindPrev.amount
  if isKindBest then db.bestBy[c.kind] = e; e.kindBest = true end

  local prev = db.best
  local avg = n > 1 and string.format(" (avg of %d)", n) or ""

  if not prev or per > prev.amount then
    db.best = e
    e.record = true
    if S.toast.record then
      ns.ShowToast("NEW REWIND RECORD", fmt(per) .. avg,
        (prev and ("prev " .. fmt(prev.amount)) or "first record") .. "  ·  " .. c.where, true)
    end
    local gain = prev and prev.amount > 0 and (per / prev.amount - 1) * 100 or math.huge
    local msg = ns.FillTemplate(S.announce.template, ns.TemplateValues(per, total, n, prev, c.where, nil))
    if gain >= (S.announce.minGain or 0) then announce(msg) else P(msg) end
  elseif isKindBest and S.announce.categories then
    local label = ns.KIND_LABEL[c.kind]
    if S.toast.record then
      ns.ShowToast("NEW " .. label:upper() .. " BEST", fmt(per) .. avg,
        (kindPrev and ("prev " .. fmt(kindPrev.amount)) or "first " .. label .. " Rewind") .. "  ·  " .. c.where, true)
    end
    announce(ns.FillTemplate(S.announce.template, ns.TemplateValues(per, total, n, kindPrev, c.where, label)))
  else
    if S.toast.every then
      ns.ShowToast("REWIND", fmt(per) .. avg, string.format("best %s  ·  %s", fmt(prev.amount), c.where), false)
    end
    P(string.format("Rewind: %s%s – best %s", fmt(per), avg, fmt(prev.amount)))
  end
  if ns.RefreshOptions then ns.RefreshOptions() end
end

local function process()
  if InCombatLockdown() then casts = 0; return end  -- next pull started first; that fight is lost
  local list = ns.ReadHealing()
  if not list then
    pendingTries = pendingTries + 1
    if pendingTries <= 5 then C_Timer.After(2, process) else casts = 0 end
    return
  end
  pendingTries = 0
  ns.lastFight = list
  local total = 0
  for _, sp in ipairs(list) do if db.spellIDs[sp.id] then total = total + sp.amount end end
  local n = casts
  casts = 0
  local c = ctx or context()
  ctx = nil
  if total > 0 then record(total, math.max(n, 1), c) end  -- cast count can be hidden; then assume one
  if ns.RefreshOptions then ns.RefreshOptions() end
end

function ns.ResetRecords()
  db.best, db.bestBy, db.history = nil, {}, {}
  P("All records cleared.")
  if ns.RefreshOptions then ns.RefreshOptions() end
end

function ns.ClearHistory()
  db.history = {}
  if ns.RefreshOptions then ns.RefreshOptions() end
end

---------------------------------------------------------------- events
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, e, ...) if ns[e] then ns[e](...) end end)

local function merge(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      merge(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

function ns.ADDON_LOADED(name)
  if name ~= ADDON then return end
  db = RewoundDB or {}
  db.settings = db.settings or {}
  S = db.settings
  -- carry over 0.1 settings
  if type(db.announce) == "string" then S.announce = { enabled = db.announce == "group" } end
  if db.splash ~= nil or db.every ~= nil then S.toast = { record = db.splash, every = db.every } end
  db.announce, db.splash, db.every = nil, nil, nil
  merge(S, DEFAULTS)
  db.spellIDs = db.spellIDs or { [REWIND] = true }
  db.history  = db.history or {}
  db.bestBy   = db.bestBy or {}
  -- 0.3.1: dungeons without a key now count with M+ as one Dungeon category
  local d = db.bestBy.dungeon
  if d then
    d.kind = "mplus"
    if not db.bestBy.mplus or (d.amount or 0) > (db.bestBy.mplus.amount or 0) then db.bestBy.mplus = d end
    db.bestBy.dungeon = nil
  end
  for _, e in ipairs(db.history) do if e.kind == "dungeon" then e.kind = "mplus" end end
  if S.track then S.track.dungeon = nil end
  RewoundDB = db
  ns.db, ns.S = db, S
end

function ns.PLAYER_LOGIN()
  ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
  for _, e in ipairs({ "PLAYER_REGEN_ENABLED", "ENCOUNTER_START", "ENCOUNTER_END", "CHALLENGE_MODE_COMPLETED" }) do
    ev:RegisterEvent(e)
  end
  C_Timer.NewTicker(2, flush)
end

function ns.UNIT_SPELLCAST_SUCCEEDED(_, _, spellID)
  if secret(spellID) or spellID ~= REWIND then return end
  casts = casts + 1
  ctx = context()
end

function ns.PLAYER_REGEN_ENABLED()
  if not isPres() then casts = 0; return end
  pendingTries = 0
  C_Timer.After(1, process)
end

function ns.ENCOUNTER_START(_, name) if not secret(name) then encounterName = name end end
function ns.ENCOUNTER_END() C_Timer.After(3, function() encounterName = nil end) end
function ns.CHALLENGE_MODE_COMPLETED() C_Timer.After(2, flush) end

---------------------------------------------------------------- slash
function ns.PrintStats()
  local b = db.best
  if not b then P("No Rewind recorded yet."); return end
  P(string.format("Best: %s – %s, %s", fmt(b.amount), b.where or "?", date("%d %b %Y", b.when)))
  for _, k in ipairs(ns.KINDS) do
    local e = db.bestBy[k]
    if e then P(string.format("  %s best: %s – %s", ns.KIND_LABEL[k], fmt(e.amount), e.where or "?")) end
  end
end

StaticPopupDialogs.REWOUND_RESET = {
  text = "Delete all Rewind records and history?",
  button1 = YES, button2 = NO,
  OnAccept = function() ns.ResetRecords() end,
  timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
}

-- /rw is the game's raid warning, so the command is /rewound
SLASH_REWOUND1 = "/rewound"
SlashCmdList.REWOUND = function(msg)
  local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
  if cmd == "" or cmd == "options" or cmd == "config" then
    ns.OpenOptions()
  elseif cmd == "stats" then
    ns.PrintStats()
  elseif cmd == "test" then
    ns.TestToast()
  elseif cmd == "spells" then
    local list, err = ns.ReadHealing()
    if not list then P(err); return end
    P("Last fight, your healing by spell:")
    for i = 1, math.min(12, #list) do
      local sp = list[i]
      P(string.format("  %d  %s  %s%s", sp.id, C_Spell.GetSpellName(sp.id) or "?", fmt(sp.amount),
        db.spellIDs[sp.id] and "  ← counted" or ""))
    end
  elseif cmd == "addid" and tonumber(arg) then
    db.spellIDs[tonumber(arg)] = true; P("Counting spell", arg, "as Rewind healing.")
  elseif cmd == "reset" then
    StaticPopup_Show("REWOUND_RESET")
  else
    P("/rewound – settings · /rewound stats · /rewound test · /rewound spells · /rewound addid <spellID> · /rewound reset")
  end
end

function Rewound_OnAddonCompartmentClick() ns.OpenOptions() end

if Smiler and Smiler.RegisterStatus then
  Smiler:RegisterStatus("rewound", function()
    local b = ns.db and ns.db.best
    if b and b.amount and b.amount > 0 then return "Best Rewind " .. fmt(b.amount), "record" end
  end)
end
