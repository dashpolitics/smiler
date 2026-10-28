-- Smiler menu: one button in the add-on menu (by the minimap) replaces one per add-on.
local _, S = ...

local menu
local ROW_H = 30

local function build()
  menu = CreateFrame("Frame", "SmilerMenu", UIParent, "BackdropTemplate")
  menu:SetWidth(280)
  menu:SetFrameStrata("DIALOG")
  menu:SetClampedToScreen(true)
  S.Panel(menu, "void", 0.97, 0.38)
  S.TopLine(menu)
  menu.title = S.Text(menu, "label", 13, "amethyst")
  menu.title:SetPoint("TOPLEFT", 14, -14)
  menu.title:SetText(S.Spaced("Smiler"))
  menu.rows, menu.lines, menu.rules = {}, {}, {}
  menu:RegisterEvent("GLOBAL_MOUSE_DOWN")
  menu:SetScript("OnEvent", function(self)
    if self:IsShown() and not self:IsMouseOver() then
      C_Timer.After(0, function() if not self.justOpened and self:IsShown() then self:Hide(); self.closedAt = GetTime() end end)
    end
  end)
  tinsert(UISpecialFrames, "SmilerMenu")
  menu:Hide()
end

local function row(i)
  local r = menu.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, menu)
  r:SetHeight(ROW_H)
  r.hl = r:CreateTexture(nil, "BACKGROUND"); r.hl:SetAllPoints(); r.hl:SetColorTexture(S.RGB("raised")); r.hl:Hide()
  r.text = S.Text(r, "body", 14, "text"); r.text:SetPoint("LEFT", 14, 0)
  r.key = S.Text(r, "label", 13, "muted", "RIGHT"); r.key:SetPoint("RIGHT", -14, 0)
  r:SetScript("OnEnter", function(s) s.hl:Show() end)
  r:SetScript("OnLeave", function(s) s.hl:Hide() end)
  menu.rows[i] = r
  return r
end

local function line(i)
  local l = menu.lines[i]
  if l then return l end
  l = CreateFrame("Frame", nil, menu)
  l:SetHeight(22)
  l.icon = l:CreateTexture(nil, "OVERLAY"); l.icon:SetSize(14, 14); l.icon:SetPoint("LEFT", 14, 0)
  l.text = S.Text(l, "body", 13, "soft"); l.text:SetPoint("LEFT", l.icon, "RIGHT", 8, 0)
  l.text:SetPoint("RIGHT", -12, 0)
  menu.lines[i] = l
  return l
end

local function rule(i, y)
  local t = menu.rules[i]
  if not t then t = menu:CreateTexture(nil, "ARTWORK"); t:SetColorTexture(S.RGB("edge", 0.25)); t:SetHeight(1); menu.rules[i] = t end
  t:ClearAllPoints(); t:SetPoint("TOPLEFT", 14, y); t:SetPoint("TOPRIGHT", -14, y); t:Show()
end

local KIND_ICON = { ready = { "tick", "emerald" }, record = { "star", "diamond" }, upgrade = { "arrow", "topaz" },
                    death = { "warn", "ruby" }, info = { "info", "sapphire" }, muted = { "dot", "muted" } }

-- The menu grows with the pack: thirteen add-ons plus status lines is taller than some screens, so
-- it lays out into a capped height and scrolls with the wheel rather than running off the top.
local function layoutMenu()
  for _, r in ipairs(menu.rows) do r:Hide() end
  for _, l in ipairs(menu.lines) do l:Hide() end
  for _, t in ipairs(menu.rules) do t:Hide() end

  local y, n = -36 + (menu.offset or 0), 0
  for _, m in ipairs(S.MODULES) do
    local _, loaded = S.ModuleState(m)
    if loaded and m.open and m.menu then
      n = n + 1
      local r = row(n)
      r:ClearAllPoints(); r:SetPoint("TOPLEFT", 1, y); r:SetPoint("TOPRIGHT", -1, y)
      r.text:SetText(m.menu); r.key:SetText(m.slash or "")
      r:SetScript("OnClick", function() menu:Hide(); m.open() end)
      r:Show()
      y = y - ROW_H
    end
  end

  local lines = 0
  for _, st in ipairs(S.status) do
    local ok, text, kind = pcall(st.fn)
    if ok and text then
      if lines == 0 then rule(1, y - 6); y = y - 12 end
      lines = lines + 1
      local l = line(lines)
      local ic = KIND_ICON[kind or "muted"] or KIND_ICON.muted
      l.icon:SetTexture(S.Icon(ic[1])); l.icon:SetVertexColor(S.RGB(ic[2]))
      l.icon:SetSize(ic[1] == "dot" and 8 or 14, ic[1] == "dot" and 8 or 14)
      l.text:SetText(text); l.text:SetTextColor(S.RGB(kind == "ready" and "emerald" or "soft"))
      l:ClearAllPoints(); l:SetPoint("TOPLEFT", 1, y); l:SetPoint("TOPRIGHT", -1, y); l:Show()
      y = y - 22
    end
  end

  rule(2, y - 6); y = y - 12
  local r = row(n + 1)
  r:ClearAllPoints(); r:SetPoint("TOPLEFT", 1, y); r:SetPoint("TOPRIGHT", -1, y)
  r.text:SetText("Settings…"); r.key:SetText("/smiler")
  r:SetScript("OnClick", function() menu:Hide(); S:OpenSettings() end)
  r:Show()
  y = y - ROW_H - 6

  local content = -y + (menu.offset or 0)
  local maxH = math.max(220, (UIParent:GetHeight() or 800) * 0.75)
  menu.contentH = content
  menu.maxOffset = math.max(0, content - maxH)
  menu:SetHeight(math.min(content, maxH))
  if menu.hint then menu.hint:SetShown((menu.maxOffset or 0) > 0) end
  return content
end

function S:ToggleMenu(owner)
  if not menu then build() end
  if menu:IsShown() then menu:Hide(); return end
  if menu.closedAt and GetTime() - menu.closedAt < 0.3 then return end   -- the click that just closed it
  menu.offset = 0
  menu:SetClampedToScreen(true)
  menu:EnableMouseWheel(true)
  menu:SetScript("OnMouseWheel", function(self, d)
    if (self.maxOffset or 0) <= 0 then return end
    -- a positive offset lifts the rows, revealing what is further down the list, so the wheel
    -- subtracts: wheel down (d = -1) moves down the menu, which is what every other list does
    self.offset = math.max(0, math.min(self.maxOffset, (self.offset or 0) - d * ROW_H * 2))
    layoutMenu()
  end)
  layoutMenu()
  menu:ClearAllPoints()

  if owner and owner.GetCenter then
    menu:SetPoint("TOPRIGHT", owner, "BOTTOMLEFT", 0, -4)
  else
    local x, cy = GetCursorPosition()
    local sc = UIParent:GetEffectiveScale()
    menu:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", x / sc, cy / sc)
  end
  menu.justOpened = true
  menu:Show()
  C_Timer.After(0.1, function() menu.justOpened = false end)
end

---------------------------------------------------------------- add-on menu (compartment) entry
function Smiler_OnCompartmentClick(_, button)
  if button == "RightButton" then S:OpenSettings() else S:ToggleMenu() end
end

function Smiler_OnCompartmentEnter(_, frame)
  GameTooltip:SetOwner(frame or UIParent, "ANCHOR_LEFT")
  GameTooltip:SetText("Smiler")
  GameTooltip:AddLine("Click for your add-ons, right-click for settings.", 0.85, 0.78, 1, true)
  GameTooltip:Show()
end

function Smiler_OnCompartmentLeave() GameTooltip:Hide() end
