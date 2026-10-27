-- Smiler widgets: buttons, switches, sliders, drop-downs, segmented controls and a column layout.
local _, S = ...
local W = {}
S.W = W

-- controls register a Sync() on the nearest ancestor that keeps a sync list
local function track(parent, ctl)
  local p = parent
  while p do
    if p.smilerSync then tinsert(p.smilerSync, ctl); return end
    p = p.GetParent and p:GetParent()
  end
end
function W.SyncAll(root)
  if not root or not root.smilerSync then return end
  root.syncing = true
  for _, c in ipairs(root.smilerSync) do if c.Sync then c:Sync() end end
  root.syncing = false
end

local function tip(frame, text)
  if not text then return end
  frame:HookScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
    GameTooltip:SetText(text, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end
W.Tip = tip

---------------------------------------------------------------- button
-- style: nil (normal), "primary" (amethyst), "ghost" (text only)
function W.Button(parent, label, w, h, onClick, style)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w or 100, h or 26)
  b.text = S.Text(b, "strong", 13, "text", "CENTER")
  b.text:SetPoint("CENTER", 0, 0)
  b.text:SetText(label or "")
  b.style = style
  function b:Paint(hover)
    if self.style == "primary" then
      S.Panel(self, "amethyst", hover and 0.85 or 1, 0)
      self:SetBackdropBorderColor(S.RGB("amethyst", 1))
      self.text:SetTextColor(S.RGB("void"))
    elseif self.style == "ghost" then
      self:SetBackdrop(nil)
      self.text:SetTextColor(S.RGB(hover and "text" or "muted"))
    else
      S.Panel(self, hover and "card" or "raised", 1, hover and 1 or 0.6)
      if hover then self:SetBackdropBorderColor(S.RGB("amethyst", 0.9)) end
      self.text:SetTextColor(S.RGB(self:IsEnabled() and "text" or "muted"))
    end
  end
  b:Paint()
  b:SetScript("OnEnter", function(s) s:Paint(true) end)
  b:SetScript("OnLeave", function(s) s:Paint(false) end)
  b:SetScript("OnClick", function(s, ...) if onClick then onClick(s, ...) end end)
  function b:SetLabel(t) self.text:SetText(t) end
  return b
end

function W.IconButton(parent, icon, size, color, onClick, tipText)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(size + 8, size + 8)
  b.icon = S.IconTex(b, icon, size, color or "muted")
  b.icon:SetPoint("CENTER")
  b:SetScript("OnEnter", function(s) s.icon:SetVertexColor(S.RGB("text")) end)
  b:SetScript("OnLeave", function(s) s.icon:SetVertexColor(S.RGB(color or "muted")) end)
  b:SetScript("OnClick", onClick)
  tip(b, tipText)
  return b
end

---------------------------------------------------------------- switch
function W.Switch(parent, get, set)
  local s = CreateFrame("Button", nil, parent, "BackdropTemplate")
  s:SetSize(36, 20)
  s.knob = s:CreateTexture(nil, "OVERLAY")
  s.knob:SetTexture(S.Icon("dot"))
  s.knob:SetSize(14, 14)
  function s:Sync()
    local on = get() and true or false
    self.on = on
    if on then
      S.Panel(self, "amethyst", 1, 0); self:SetBackdropBorderColor(S.RGB("amethyst"))
      self.knob:SetVertexColor(S.RGB("void"))
      self.knob:ClearAllPoints(); self.knob:SetPoint("RIGHT", -3, 0)
    else
      S.Panel(self, "raised", 1, 0.6)
      self.knob:SetVertexColor(S.RGB("muted"))
      self.knob:ClearAllPoints(); self.knob:SetPoint("LEFT", 3, 0)
    end
  end
  s:SetScript("OnClick", function(self)
    set(not self.on); self:Sync()
    PlaySound(self.on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
  end)
  s:Sync()
  track(parent, s)
  return s
end

---------------------------------------------------------------- slider
function W.Slider(parent, width, minV, maxV, step, get, set, fmt)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(width + 48, 20)
  local sl = CreateFrame("Slider", nil, f)
  sl:SetOrientation("HORIZONTAL")
  sl:SetSize(width, 16)
  sl:SetPoint("LEFT")
  sl:SetMinMaxValues(minV, maxV)
  sl:SetValueStep(step)
  sl:SetObeyStepOnDrag(true)
  local track_ = sl:CreateTexture(nil, "BACKGROUND")
  track_:SetColorTexture(S.RGB("raised"))
  track_:SetPoint("LEFT"); track_:SetPoint("RIGHT"); track_:SetHeight(4)
  local fill = sl:CreateTexture(nil, "ARTWORK")
  fill:SetColorTexture(S.RGB("amethyst"))
  fill:SetPoint("LEFT"); fill:SetHeight(4)
  sl:SetThumbTexture(S.Icon("dot"))
  local thumb = sl:GetThumbTexture()
  thumb:SetSize(14, 14); thumb:SetVertexColor(S.RGB("diamond"))
  f.value = S.Text(f, "display", 15, "text", "LEFT")
  f.value:SetPoint("LEFT", sl, "RIGHT", 10, 0)
  local function show(v)
    f.value:SetText(fmt and fmt(v) or tostring(v))
    fill:SetWidth(math.max(1, (v - minV) / (maxV - minV) * width))
  end
  sl:SetScript("OnValueChanged", function(_, v)
    v = math.floor(v / step + 0.5) * step
    show(v)
    if not f.syncing then set(v) end
  end)
  function f:Sync()
    self.syncing = true
    local v = get(); sl:SetValue(v); show(v)
    self.syncing = false
  end
  f.slider = sl
  f:Sync()
  track(parent, f)
  return f
end

---------------------------------------------------------------- drop-down
local popup
local function closePopup() if popup then popup:Hide() end end
local function openPopup(owner, options, current, pick)
  if not popup then
    popup = CreateFrame("Frame", "SmilerDropDown", UIParent, "BackdropTemplate")
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetClampedToScreen(true)
    S.Panel(popup, "void", 0.98, 0.6)
    popup.rows = {}
    popup:RegisterEvent("GLOBAL_MOUSE_DOWN")
    popup:SetScript("OnEvent", function(self)
      if self:IsShown() and not self:IsMouseOver() and not (self.owner and self.owner:IsMouseOver()) then self:Hide() end
    end)
    tinsert(UISpecialFrames, "SmilerDropDown")
  end
  popup.owner = owner
  for _, r in ipairs(popup.rows) do r:Hide() end
  local w = owner:GetWidth()
  for i, o in ipairs(options) do
    local r = popup.rows[i]
    if not r then
      r = CreateFrame("Button", nil, popup)
      r:SetHeight(24)
      r.hl = r:CreateTexture(nil, "BACKGROUND"); r.hl:SetAllPoints(); r.hl:SetColorTexture(S.RGB("raised")); r.hl:Hide()
      r.text = S.Text(r, "body", 13, "text"); r.text:SetPoint("LEFT", 10, 0)
      r:SetScript("OnEnter", function(s) s.hl:Show() end)
      r:SetScript("OnLeave", function(s) s.hl:Hide() end)
      popup.rows[i] = r
    end
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", 1, -1 - (i - 1) * 24); r:SetPoint("TOPRIGHT", -1, -1 - (i - 1) * 24)
    r.text:SetText(o[2])
    r.text:SetTextColor(S.RGB(o[1] == current and "amethyst" or "text"))
    r:SetScript("OnClick", function() popup:Hide(); pick(o[1]) end)
    r:Show()
  end
  popup:SetSize(math.max(w, 140), #options * 24 + 2)
  popup:ClearAllPoints()
  popup:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
  popup:Show()
end
W.ClosePopup = closePopup

-- options: { {key, label}, ... }
function W.Dropdown(parent, width, options, get, set)
  local b = W.Button(parent, "", width, 26)
  b.text:ClearAllPoints(); b.text:SetPoint("LEFT", 10, 0); b.text:SetPoint("RIGHT", -22, 0)
  b.text:SetJustifyH("LEFT")
  local caret = S.IconTex(b, "arrow", 10, "muted")
  caret:SetRotation(math.pi)
  caret:SetPoint("RIGHT", -9, 0)
  function b:Sync()
    local cur = get()
    local opts = type(options) == "function" and options() or options
    for _, o in ipairs(opts) do if o[1] == cur then self.text:SetText(o[2]) end end
  end
  b:SetScript("OnClick", function(self)
    if popup and popup:IsShown() and popup.owner == self then popup:Hide(); return end
    local opts = type(options) == "function" and options() or options
    openPopup(self, opts, get(), function(k) set(k); self:Sync() end)
  end)
  b:Sync()
  track(parent, b)
  return b
end

---------------------------------------------------------------- segmented control
-- options: { {key, label}, ... }; widths fit the labels
function W.Segmented(parent, options, get, set, h)
  local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  S.Panel(f, "raised", 1, 0.6)
  f.buttons = {}
  local x = 1
  for i, o in ipairs(options) do
    local b = CreateFrame("Button", nil, f)
    b.key = o[1]
    b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints()
    b.text = S.Text(b, "strong", 13, "soft", "CENTER"); b.text:SetPoint("CENTER")
    b.text:SetText(o[2])
    local w = math.max(48, math.ceil(b.text:GetStringWidth()) + 26)
    b:SetSize(w, (h or 26) - 2)
    b:SetPoint("LEFT", x, 0)
    if i > 1 then
      local sep = f:CreateTexture(nil, "ARTWORK"); sep:SetColorTexture(S.RGB("edge", 0.38))
      sep:SetWidth(1); sep:SetPoint("TOP", b, "TOPLEFT", 0, 0); sep:SetPoint("BOTTOM", b, "BOTTOMLEFT", 0, 0)
    end
    x = x + w
    b:SetScript("OnClick", function() set(o[1]); f:Sync() end)
    b:SetScript("OnEnter", function(s) if not s.on then s.bg:SetColorTexture(S.RGB("card")) end end)
    b:SetScript("OnLeave", function(s) if not s.on then s.bg:SetColorTexture(0, 0, 0, 0) end end)
    f.buttons[i] = b
  end
  f:SetSize(x + 1, h or 26)
  function f:Sync()
    local cur = get()
    for _, b in ipairs(self.buttons) do
      b.on = b.key == cur
      if b.on then b.bg:SetColorTexture(S.RGB("amethyst")); b.text:SetTextColor(S.RGB("void"))
      else b.bg:SetColorTexture(0, 0, 0, 0); b.text:SetTextColor(S.RGB("soft")) end
    end
  end
  f:Sync()
  track(parent, f)
  return f
end

---------------------------------------------------------------- tag (BR, EMB, TIER, BIS, READY)
-- kind: a gem name; icon optional
function W.Tag(parent, text, color, icon)
  local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  f:SetBackdrop(S.BACKDROP)
  f:SetBackdropColor(0, 0, 0, 0)
  local x = 5
  if icon then
    f.icon = S.IconTex(f, icon, 9, color)
    f.icon:SetPoint("LEFT", 4, 0)
    x = 15
  end
  f.text = S.Text(f, "display", 11, color)
  f.text:SetPoint("LEFT", x, 0)
  function f:Set(t, c, ic)
    color = c or color
    self.text:SetText(t)
    self.text:SetTextColor(S.RGB(color))
    self:SetBackdropBorderColor(S.RGB(color, 0.6))
    if self.icon then self.icon:SetVertexColor(S.RGB(color)); if ic then self.icon:SetTexture(S.Icon(ic)) end end
    self:SetSize(math.ceil(self.text:GetStringWidth()) + x + 5, 16)
  end
  f:Set(text, color)
  return f
end

---------------------------------------------------------------- column layout for settings tabs
local Col = {}
Col.__index = Col

function W.Column(parent, x, y, width)
  return setmetatable({ parent = parent, x = x, y = y or 0, w = width }, Col)
end

function Col:Gap(n) self.y = self.y - (n or 10) end

function Col:Section(text)
  local t = S.Text(self.parent, "label", 13, "muted")
  t:SetPoint("TOPLEFT", self.x, self.y)
  t:SetText(text:upper())
  self.y = self.y - 24
  return t
end

-- a row: label (and hint) on the left, control on the right
function Col:Row(label, hint, control, h)
  h = h or (hint and 42 or 34)
  local l = S.Text(self.parent, "body", 14, "text")
  l:SetPoint("TOPLEFT", self.x, self.y - (hint and 6 or (h - 14) / 2))
  l:SetText(label)
  if hint then
    local hn = S.Text(self.parent, "body", 12, "muted")
    hn:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -3)
    hn:SetText(hint)
  end
  if control then
    control:SetPoint("RIGHT", self.parent, "TOPLEFT", self.x + self.w, self.y - h / 2)
  end
  self.y = self.y - h
  return l, control
end

function Col:Switch(label, hint, get, set)
  local sw = W.Switch(self.parent, get, set)
  self:Row(label, hint, sw)
  return sw
end

function Col:Slider(label, minV, maxV, step, get, set, fmt, width)
  local sl = W.Slider(self.parent, width or 120, minV, maxV, step, get, set, fmt)
  self:Row(label, nil, sl)
  return sl
end

function Col:Dropdown(label, options, get, set, width, extra)
  local holder = CreateFrame("Frame", nil, self.parent)
  local dd = W.Dropdown(holder, width or 150, options, get, set)
  local w = width or 150
  dd:SetPoint("LEFT")
  if extra then extra:SetParent(holder); extra:ClearAllPoints(); extra:SetPoint("LEFT", dd, "RIGHT", 8, 0); w = w + 8 + extra:GetWidth() end
  holder:SetSize(w, 26)
  self:Row(label, nil, holder)
  return dd
end

-- buttons: { {label, fn, style, width}, ... }
function Col:Buttons(label, buttons)
  local holder = CreateFrame("Frame", nil, self.parent)
  local w, prev = 0, nil
  for _, def in ipairs(buttons) do
    local b = W.Button(holder, def[1], def[4] or 80, 26, def[2], def[3])
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 8, 0); w = w + 8 else b:SetPoint("LEFT") end
    w = w + b:GetWidth(); prev = b
  end
  holder:SetSize(w, 26)
  if label then self:Row(label, nil, holder)
  else holder:SetPoint("TOPLEFT", self.x, self.y - 4); self.y = self.y - 34 end
  return holder
end

function Col:Note(text, color, size)
  local t = S.Text(self.parent, "body", size or 13, color or "soft")
  t:SetWordWrap(true)
  t:SetWidth(self.w)
  t:SetPoint("TOPLEFT", self.x, self.y)
  t:SetText(text)
  self.y = self.y - math.ceil(t:GetStringHeight()) - 8
  return t
end

-- something custom: frame of given height placed at the cursor
function Col:Place(frame, h)
  frame:SetPoint("TOPLEFT", self.x, self.y)
  self.y = self.y - (h or frame:GetHeight()) - 8
  return frame
end
