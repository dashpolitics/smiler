-- Smiler alerts: one toast shape for every add-on. The gem colour and icon say what kind it is.
local _, S = ...

local TOAST_W, TOAST_H, GAP, MAX = 400, 72, 8, 3
local anchor, active, pool = nil, {}, {}

local function savePoint()
  local p, _, rp, x, y = anchor:GetPoint()
  S.db.toastPoint = { p, rp, x, y }
end

local function placeAnchor()
  anchor:ClearAllPoints()
  local p = S.db and S.db.toastPoint
  if p then anchor:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else anchor:SetPoint("TOP", UIParent, "TOP", 0, -190) end
  anchor:SetScale(S.db and S.db.toastScale or 1)
end

local function buildAnchor()
  anchor = CreateFrame("Frame", "SmilerToastAnchor", UIParent, "BackdropTemplate")
  anchor:SetSize(TOAST_W, TOAST_H)
  anchor:SetFrameStrata("HIGH")
  anchor:SetClampedToScreen(true)
  anchor:SetMovable(true)
  anchor:RegisterForDrag("LeftButton")
  anchor:SetScript("OnDragStart", anchor.StartMoving)
  anchor:SetScript("OnDragStop", function(s) s:StopMovingOrSizing(); savePoint() end)
  S.Panel(anchor, "void", 0.6, 1)
  anchor:SetBackdropBorderColor(S.RGB("amethyst", 0.9))
  anchor.text = S.Text(anchor, "display", 18, "amethyst", "CENTER")
  anchor.text:SetPoint("CENTER", 0, 8)
  anchor.text:SetText("ALERTS APPEAR HERE")
  anchor.sub = S.Text(anchor, "body", 12, "soft", "CENTER")
  anchor.sub:SetPoint("TOP", anchor.text, "BOTTOM", 0, -4)
  anchor.sub:SetText("Drag to move · click Done in Smiler settings, or /smiler move")
  anchor:EnableMouse(false)
  anchor:SetBackdrop(nil); anchor.text:Hide(); anchor.sub:Hide()
  placeAnchor()
end

local function layout()
  for i, t in ipairs(active) do
    t:ClearAllPoints()
    t:SetPoint("TOP", anchor, "TOP", 0, -(i - 1) * (TOAST_H + GAP))
  end
end

local function release(t)
  t:Hide()
  for i, a in ipairs(active) do if a == t then tremove(active, i); break end end
  tinsert(pool, t)
  layout()
end

local function buildToast()
  local t = CreateFrame("Frame", nil, anchor, "BackdropTemplate")
  t:SetSize(TOAST_W, TOAST_H)
  t:SetFrameStrata("HIGH")
  S.Panel(t, "void", 0.94, 0.6)
  t.line = t:CreateTexture(nil, "ARTWORK", nil, 7)
  t.line:SetPoint("TOPLEFT", 1, -1); t.line:SetPoint("TOPRIGHT", -1, -1); t.line:SetHeight(2)
  t.line:SetColorTexture(1, 1, 1, 1)

  t.glow = t:CreateTexture(nil, "BACKGROUND", nil, -1)
  t.glow:SetTexture(S.Icon("glow"))
  t.glow:SetPoint("TOPLEFT", -40, 30); t.glow:SetPoint("BOTTOMRIGHT", 40, -30)
  t.glow:SetBlendMode("ADD")

  t.icon = t:CreateTexture(nil, "ARTWORK")
  t.icon:SetSize(46, 46)
  t.icon:SetPoint("LEFT", 14, 0)
  t.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  t.kindIcon = t:CreateTexture(nil, "OVERLAY")
  t.kindIcon:SetSize(18, 18)
  t.title = S.Text(t, "display", 23, "text")
  t.sub = S.Text(t, "body", 13, "soft")

  t.anim = t:CreateAnimationGroup()
  local fin = t.anim:CreateAnimation("Alpha"); fin:SetFromAlpha(0); fin:SetToAlpha(1); fin:SetDuration(0.15); fin:SetOrder(1)
  t.hold = t.anim:CreateAnimation("Alpha"); t.hold:SetFromAlpha(1); t.hold:SetToAlpha(1); t.hold:SetOrder(2)
  local fout = t.anim:CreateAnimation("Alpha"); fout:SetFromAlpha(1); fout:SetToAlpha(0); fout:SetDuration(0.6); fout:SetOrder(3)
  t.anim:SetScript("OnFinished", function() release(t) end)

  -- slow breathing glow for records
  t.breathe = t.glow:CreateAnimationGroup()
  t.breathe:SetLooping("BOUNCE")
  local b = t.breathe:CreateAnimation("Alpha"); b:SetFromAlpha(0.15); b:SetToAlpha(0.45); b:SetDuration(2)

  t:EnableMouse(true)
  t:SetScript("OnMouseUp", function(self) self.anim:Stop(); release(self) end)
  return t
end

--[[ S:Toast{
  kind = "ready" | "record" | "death" | "upgrade" | "info",
  title = "LUST AVAILABLE", sub = "Boss pulled · …", icon = texture or fileID,
  duration = 3, glow = true (records), id = "lustready" (replaces an alert with the same id),
} ]]
function S:Toast(o)
  if not anchor then buildAnchor() end
  if o.id then
    for _, a in ipairs(active) do if a.id == o.id then a.anim:Stop(); release(a); break end end
  end
  while #active >= MAX do local last = active[#active]; last.anim:Stop(); release(last) end
  local t = tremove(pool) or buildToast()
  local kind = S.KIND[o.kind] or S.KIND.info
  local c = kind.color
  t.id = o.id
  t:SetBackdropBorderColor(S.RGB(c, c == "diamond" and 0.7 or 0.6))
  local c1, c2 = S.C[c], S.C[c == "diamond" and "amethyst" or "diamond"]
  if c == "diamond" then c1, c2 = S.C.amethyst, S.C.diamond end
  if c == "ruby" then c2 = S.C.topaz end
  t.line:SetGradient("HORIZONTAL", CreateColor(c1[1], c1[2], c1[3], 1), CreateColor(c2[1], c2[2], c2[3], 1))

  t.icon:SetTexture(o.icon or 134400)
  t.kindIcon:SetTexture(S.Icon(kind.icon))
  t.kindIcon:SetVertexColor(S.RGB(c))
  t.kindIcon:ClearAllPoints()
  t.kindIcon:SetPoint("TOPLEFT", t.icon, "TOPRIGHT", 14, -4)
  t.title:ClearAllPoints()
  t.title:SetPoint("LEFT", t.kindIcon, "RIGHT", 7, 0)
  t.title:SetText((o.title or ""):upper())
  t.title:SetTextColor(S.RGB(c))
  t.sub:ClearAllPoints()
  t.sub:SetPoint("BOTTOMLEFT", t.icon, "BOTTOMRIGHT", 14, 4)
  t.sub:SetPoint("RIGHT", t, "RIGHT", -12, 0)
  t.sub:SetText(o.sub or "")

  if o.glow then
    t.glow:SetVertexColor(S.RGB("amethyst")); t.glow:Show(); t.breathe:Play()
  else
    t.glow:Hide(); t.breathe:Stop()
  end

  tinsert(active, 1, t)
  layout()
  t.hold:SetDuration(o.duration or 3)
  t:SetAlpha(0)
  t:Show()
  t.anim:Stop(); t.anim:Play()
  return t
end

---------------------------------------------------------------- small info chip (new version, sync done)
local chip
function S:Chip(text, sub)
  -- quiet notices wait until you're out of combat, a boss or a key
  if InCombatLockdown() or (IsEncounterInProgress and IsEncounterInProgress())
     or (C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive()) then
    S.chipQueue = { text, sub }
    return
  end
  if not anchor then buildAnchor() end
  if not chip then
    chip = CreateFrame("Frame", nil, anchor, "BackdropTemplate")
    chip:SetHeight(32)
    S.Panel(chip, "void", 0.94, 1)
    chip:SetBackdropBorderColor(S.RGB("sapphire", 0.6))
    chip.icon = S.IconTex(chip, "info", 16, "sapphire")
    chip.icon:SetPoint("LEFT", 12, 0)
    chip.text = S.Text(chip, "strong", 13, "sapphire")
    chip.text:SetPoint("LEFT", chip.icon, "RIGHT", 8, 0)
    chip.sub = S.Text(chip, "body", 13, "soft")
    chip.sub:SetPoint("LEFT", chip.text, "RIGHT", 6, 0)
    chip.anim = chip:CreateAnimationGroup()
    local fin = chip.anim:CreateAnimation("Alpha"); fin:SetFromAlpha(0); fin:SetToAlpha(1); fin:SetDuration(0.15); fin:SetOrder(1)
    local h = chip.anim:CreateAnimation("Alpha"); h:SetFromAlpha(1); h:SetToAlpha(1); h:SetDuration(6); h:SetOrder(2)
    local fo = chip.anim:CreateAnimation("Alpha"); fo:SetFromAlpha(1); fo:SetToAlpha(0); fo:SetDuration(0.6); fo:SetOrder(3)
    chip.anim:SetScript("OnFinished", function() chip:Hide() end)
    chip:EnableMouse(true)
    chip:SetScript("OnMouseUp", function() chip.anim:Stop(); chip:Hide() end)
  end
  chip.text:SetText(text)
  chip.sub:SetText(sub and ("· " .. sub) or "")
  chip:SetWidth(12 + 16 + 8 + chip.text:GetStringWidth() + 6 + chip.sub:GetStringWidth() + 14)
  chip:ClearAllPoints()
  chip:SetPoint("BOTTOM", anchor, "TOP", 0, 8)
  chip:SetAlpha(0); chip:Show()
  chip.anim:Stop(); chip.anim:Play()
end
local chipEv = CreateFrame("Frame")
chipEv:RegisterEvent("PLAYER_REGEN_ENABLED")
chipEv:RegisterEvent("ENCOUNTER_END")
chipEv:RegisterEvent("CHALLENGE_MODE_COMPLETED")
chipEv:SetScript("OnEvent", function()
  if S.chipQueue then
    local q = S.chipQueue; S.chipQueue = nil
    C_Timer.After(2, function() S:Chip(q[1], q[2]) end)
  end
end)

---------------------------------------------------------------- moving and testing
function S:UnlockToasts(on)
  if not anchor then buildAnchor() end
  if on == nil then on = not anchor.unlocked end
  anchor.unlocked = on
  anchor:EnableMouse(on)
  if on then
    S.Panel(anchor, "void", 0.6, 1); anchor:SetBackdropBorderColor(S.RGB("amethyst", 0.9))
    anchor.text:Show(); anchor.sub:Show()
  else
    anchor:SetBackdrop(nil); anchor.text:Hide(); anchor.sub:Hide()
  end
  if S.RefreshSettings then S.RefreshSettings() end
  return on
end
function S.ToastsUnlocked() return anchor and anchor.unlocked or false end

function S:SetToastScale(v)
  S.db.toastScale = v
  if anchor then placeAnchor() end
end

function S:ResetToasts()
  S.db.toastPoint, S.db.toastScale = nil, 1
  if anchor then placeAnchor() end
  if S.RefreshSettings then S.RefreshSettings() end
end

function S:TestToasts()
  S:Toast({ kind = "ready", title = "Lust available", sub = "Test – this is what a boss pull looks like", icon = 136012, duration = 4 })
  C_Timer.After(0.4, function()
    S:Toast({ kind = "record", title = "New Rewind record", sub = "1.48M healed · beats 1.31M · test", icon = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(363534)) or 134400, glow = true, duration = 4 })
  end)
  C_Timer.After(0.8, function() S:Chip("Smiler " .. S.VERSION, "test notice") end)
end
