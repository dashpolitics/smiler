-- Smiler: the minimap button.
-- One button on the minimap that opens the same menu as /smiler, so every add-on in the pack is a
-- click away without hunting through the add-on compartment. Drag it anywhere around the ring.
-- No LibDBIcon: the pack has no library dependencies and the maths here is six lines.
local _, S = ...

local RADIUS = 80          -- distance from the minimap's centre to the button, in minimap units
local btn

local function pos()
  S.db = S.db or {}
  S.db.minimap = S.db.minimap or {}
  if S.db.minimap.angle == nil then S.db.minimap.angle = 204 end   -- lower-left, out of the way of the clock
  return S.db.minimap
end

local function place()
  if not (btn and Minimap) then return end
  local a = math.rad(pos().angle or 204)
  -- the ring is round on the default minimap and square on some UIs; the round placement reads
  -- fine on both, and dragging lets the player correct it either way
  local r = (Minimap:GetWidth() / 2) + 10
  btn:ClearAllPoints()
  btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end
S.MinimapPlace = place

local function dragging(self)
  local mx, my = Minimap:GetCenter()
  local cx, cy = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  cx, cy = cx / scale, cy / scale
  pos().angle = math.deg(math.atan2(cy - my, cx - mx)) % 360
  place()
end

function S.BuildMinimapButton()
  if btn or not Minimap then return btn end
  btn = CreateFrame("Button", "SmilerMinimapButton", Minimap)
  btn:SetSize(31, 31)
  btn:SetFrameStrata("MEDIUM")
  btn:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  btn:RegisterForDrag("LeftButton")
  btn:SetMovable(true)

  -- the ring Blizzard uses for every other minimap button, so it does not look like an intruder
  local ring = btn:CreateTexture(nil, "OVERLAY")
  ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  ring:SetSize(53, 53)
  ring:SetPoint("TOPLEFT")

  local bg = btn:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  bg:SetAllPoints()
  bg:SetAlpha(0.7)

  local icon = btn:CreateTexture(nil, "ARTWORK")
  icon:SetSize(19, 19)
  icon:SetPoint("CENTER", -1, 1)
  if S.Icon then icon:SetTexture(S.Icon("logo")) end
  if not icon:GetTexture() then icon:SetTexture("Interface\\Icons\\INV_Misc_Key_03") end
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  btn.icon = icon

  btn:SetScript("OnDragStart", function(self)
    self.dragging = true
    self:SetScript("OnUpdate", dragging)
    GameTooltip:Hide()
  end)
  btn:SetScript("OnDragStop", function(self)
    self.dragging = nil
    self:SetScript("OnUpdate", nil)
    place()
  end)
  btn:SetScript("OnClick", function(self, button)
    if button == "RightButton" then S:OpenSettings() else S:ToggleMenu(self) end
  end)
  btn:SetScript("OnEnter", function(self)
    if self.dragging then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Smiler")
    GameTooltip:AddLine("Click for your add-ons.", 0.85, 0.78, 1)
    GameTooltip:AddLine("Right-click for settings.", 0.85, 0.78, 1)
    GameTooltip:AddLine("Drag to move it round the minimap.", 0.6, 0.55, 0.75)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  place()
  return btn
end

function S.MinimapShown() return pos().hide ~= true end

function S.SetMinimapShown(show)
  pos().hide = (not show) or nil
  if show then
    S.BuildMinimapButton()
    if btn then btn:Show() end
  elseif btn then
    btn:Hide()
  end
end

function S.ToggleMinimap()
  local want = not S.MinimapShown()
  S.SetMinimapShown(want)
  S.Print(want and "Minimap button on." or "Minimap button off. /smiler minimap brings it back.")
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  if not S.db then return end
  if S.MinimapShown() then S.BuildMinimapButton() end
end)
