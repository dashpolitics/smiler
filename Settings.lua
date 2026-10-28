-- Smiler settings: one window, a tab per add-on.
local _, S = ...
local W = S.W

local WIN_W, WIN_H, NAV_W = 880, 580, 200
-- tall enough for every tab in the list plus the note at the bottom of the nav (grows as add-ons join the pack)
local TAB_STEP = 30
WIN_H = math.max(WIN_H, 46 + 12 + 2 * TAB_STEP + 12 + #S.MODULES * TAB_STEP + 64)
local win, main, current
local tabs, pages = {}, {}

local function moduleNote(m)
  return "Changes save as you make them. " .. (m and m.slash and (m.slash .. " still works.") or "")
end

---------------------------------------------------------------- General tab
local function buildGeneral(body)
  local left = W.Column(body, 0, 0, 300)
  left:Section("Start here")
  left:Note("Each add-on has a tab on the left and a slash command. Turn any off in the list on the right. Alerts from all of them share one spot on screen.", "soft", 13)
  left:Gap(6)
  left:Section("On this character")
  local _, cls = UnitClass("player")
  local specName = select(2, GetSpecializationInfo(GetSpecialization() or 0))
  left:Note((specName and (specName .. " ") or "") .. (UnitClass("player") or "") .. ": ", "muted", 12)
  local any = false
  for _, m in ipairs(S.MODULES) do
    if not m.partOf and m.needs then
      local installed, loaded = S.ModuleState(m)
      if installed and loaded then
        local fits = S.Fits(m)
        left:Note((fits == false and "– " or "+ ") .. m.title .. (fits == false and (" stays quiet (needs " .. m.needs .. ")") or " is active"), fits == false and "muted" or "emerald", 12)
        any = true
      end
    end
  end
  if not any then left:Note("Everything installed works on every class.", "muted", 12) end
  left:Gap(6)
  left:Section("Alerts")
  left:Note("Every add-on's alerts share one place on screen and one size.", "muted", 12)
  left:Slider("Size", 0.5, 2, 0.05, function() return S.db.toastScale or 1 end,
    function(v) S:SetToastScale(v) end, function(v) return math.floor(v * 100 + 0.5) .. "%" end)
  local moveBtn
  local holder = left:Buttons("Position", {
    { "Move", function() S:UnlockToasts() end, nil, 80 },
    { "Reset", function() S:ResetToasts() end, nil, 70 },
  })
  moveBtn = select(1, holder:GetChildren())
  holder.Sync = function() moveBtn:SetLabel(S.ToastsUnlocked() and "Done" or "Move") end
  tinsert(body.smilerSync, holder)
  left:Buttons("Try them", { { "Test alerts", function() S:TestToasts() end, nil, 110 } })
  left:Gap(6)
  left:Section("Minimap")
  left:Note("One button on the minimap opens this menu. Drag it round the ring to move it.", "muted", 12)
  left:Switch("Minimap button", "Click it for your add-ons, right-click for settings",
    function() return S.MinimapShown and S.MinimapShown() end,
    function(v) if S.SetMinimapShown then S.SetMinimapShown(v) end end)

  local right = W.Column(body, 340, 0, 290)
  right:Section("Add-ons")
  right:Note("Turning one off stops it loading at all, which is what saves memory and CPU. It takes effect after a reload.", "muted", 12)
  for _, m in ipairs(S.MODULES) do
    if not m.partOf then
      local installed = S.ModuleState(m)
      if installed then
        local hint = function()
          local _, loaded, enabled = S.ModuleState(m)
          if loaded and not enabled then return "Off after reload" end
          if not loaded and enabled then return "On after reload" end
          return nil
        end
        local sw = W.Switch(body, function() return select(3, S.ModuleState(m)) end,
          function(v) S.SetModuleEnabled(m, v) end)
        local l = right:Row(m.title, nil, sw)
        local h = S.Text(body, "body", 12, "topaz")
        h:SetPoint("LEFT", l, "RIGHT", 10, 0)
        local syncer = { Sync = function() h:SetText(hint() or "") end }
        tinsert(body.smilerSync, syncer)
      else
        local t = S.Text(body, "body", 12, "muted")
        right:Row(m.title, nil, t)
        t:SetText("Not installed")
      end
    end
  end
  return { footer = { { "Test alerts", function() S:TestToasts() end, "primary", 110 } } }
end

---------------------------------------------------------------- Blizzard UI tab: hide bits of the default interface
local function buildBlizz(body)
  local col = W.Column(body, 0, 0, 420)
  col:Section("Raid manager")
  col:Switch("Hide the raid manager", "The tab on the left edge: markers, ready check, raid frame options", function() return S.db.hideRaidManager end,
    function(v) S.Tidy.Set("hideRaidManager", v) end)
  col:Gap(6)
  col:Section("Objective tracker")
  col:Dropdown("Quests and objectives", { { "show", "Show" }, { "instance", "Hide in instances" }, { "always", "Always hide" } },
    function() return S.db.hideTracker or "show" end, function(k) S.Tidy.Set("hideTracker", k) end, 160)
  col:Gap(6)
  col:Note("Both hold buttons Blizzard protects in combat, so if you change this during a fight they turn invisible straight away and are fully hidden as soon as combat ends. Turning an option off brings the frame back.", "muted", 12)
  col:Note("/readycheck and your raid marker keybinds still work while the raid manager is hidden.", "muted", 12)
  return { note = "Changes save as you make them and apply straight away." }
end

---------------------------------------------------------------- module tab without its own builder
local function buildDefault(body, m)
  local col = W.Column(body, 0, 0, 600)
  col:Note(m.title .. " keeps its own settings window for now. Everything in it still uses the shared look.", "soft")
  col:Gap(4)
  col:Buttons(nil, { { m.settingsLabel or ("Open " .. m.title .. " settings"), function()
    if win then win:Hide() end
    if m.settings then m.settings() end
  end, "primary", 220 } })
  if m.open and m.menu then
    col:Buttons(nil, { { "Open " .. m.menu, function() if win then win:Hide() end; m.open() end, nil, 220 } })
  end
end

---------------------------------------------------------------- page
local function buildPage(key)
  local page = CreateFrame("Frame", nil, main)
  page:SetAllPoints()
  page:Hide()
  page.smilerSync = {}
  local m = S.byKey[key]

  local title = S.Text(page, "display", 28, "text")
  title:SetPoint("TOPLEFT", 28, -20)
  title:SetText(m and m.title or (key == "BlizzUI" and "Blizzard UI") or "Smiler")
  local desc = S.Text(page, "body", 13, "soft")
  desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  desc:SetPoint("RIGHT", page, "RIGHT", -200, 0)
  desc:SetWordWrap(true); desc:SetMaxLines(2)
  desc:SetText(m and m.desc or (key == "BlizzUI" and "Hide parts of the default interface you don't use.") or "One look, one settings window and one place for alerts, shared by all your add-ons.")
  -- who it's for, when it isn't everyone
  if m and m.needs then
    local fits = S.Fits(m)
    local tag = S.Text(page, "strong", 12, fits == false and "topaz" or "muted")
    tag:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -4)
    tag:SetPoint("RIGHT", page, "RIGHT", -200, 0)
    tag:SetWordWrap(true); tag:SetMaxLines(2)
    tag:SetText((fits == false and "Not for this character – it stays quiet here. Needs " or "For ") .. m.needs .. ".")
  end

  local installed, loaded = true, true
  if m then
    installed, loaded = S.ModuleState(m)
    if not m.partOf and installed then
      local sw = W.Switch(page, function() return select(3, S.ModuleState(m)) end, function(v) S.SetModuleEnabled(m, v) end)
      sw:SetPoint("TOPRIGHT", -28, -26)
      local stIcon = page:CreateTexture(nil, "OVERLAY"); stIcon:SetSize(14, 14)
      local st = S.Text(page, "strong", 13, "emerald", "RIGHT")
      st:SetPoint("RIGHT", sw, "LEFT", -10, 0)
      stIcon:SetPoint("RIGHT", st, "LEFT", -6, 0)
      tinsert(page.smilerSync, { Sync = function()
        local on = select(3, S.ModuleState(m))
        st:SetText(on and "Module on" or "Module off")
        st:SetTextColor(S.RGB(on and "emerald" or "muted"))
        stIcon:SetTexture(S.Icon(on and "tick" or "close"))
        stIcon:SetVertexColor(S.RGB(on and "emerald" or "muted"))
      end })
    end
  end

  local body = CreateFrame("Frame", nil, page)
  body:SetPoint("TOPLEFT", 28, -(m and m.needs and 118 or 100))
  body:SetPoint("BOTTOMRIGHT", -28, 56)
  body.smilerSync = page.smilerSync

  local result
  if key == "BlizzUI" then
    result = buildBlizz(body)
  elseif not m then
    result = buildGeneral(body)
  elseif m.partOf and not loaded then
    W.Column(body, 0, 0, 600):Note("Part of " .. m.partOf .. ", which is turned off. Turn it on in its tab, then reload.", "muted")
  elseif not installed then
    W.Column(body, 0, 0, 600):Note(m.title .. " isn't installed. It comes with the Smiler pack.", "muted")
  elseif not loaded then
    W.Column(body, 0, 0, 600):Note(m.title .. " is turned off. Switch it on above and reload to change its settings.", "muted")
  elseif m.builder then
    local ok, r = pcall(m.builder, body, W)
    if ok then result = r else
      W.Column(body, 0, 0, 600):Note("This tab couldn't be drawn: " .. tostring(r), "ruby")
    end
  else
    buildDefault(body, m)
  end
  result = result or {}

  -- footer
  local rule = page:CreateTexture(nil, "ARTWORK")
  rule:SetColorTexture(S.RGB("edge", 0.25)); rule:SetHeight(1)
  rule:SetPoint("BOTTOMLEFT", 28, 48); rule:SetPoint("BOTTOMRIGHT", -28, 48)
  local note = S.Text(page, "body", 12, "muted")
  note:SetPoint("BOTTOMLEFT", 28, 20)
  note:SetText(result.note or moduleNote(m))
  local prev
  for i = #(result.footer or {}), 1, -1 do
    local def = result.footer[i]
    local b = W.Button(page, def[1], def[4] or 90, 28, def[2], def[3])
    if prev then b:SetPoint("RIGHT", prev, "LEFT", -8, 0) else b:SetPoint("BOTTOMRIGHT", -28, 14) end
    prev = b
  end

  page:SetScript("OnShow", function(p) W.SyncAll(p) end)
  return page
end

---------------------------------------------------------------- window
local function paintTab(t)
  local on = t.key == current
  t.bar:SetShown(on)
  t.bg:SetColorTexture(S.RGB("amethyst", on and 0.14 or 0))
  S.Font(t.text, on and "strong" or "body", 14)
  t.text:SetTextColor(S.RGB(on and "text" or "soft"))
  if t.m then
    local installed, loaded, enabled = S.ModuleState(t.m)
    t.dot:SetShown(installed)
    t.dot:SetVertexColor(S.RGB((loaded and enabled) and "emerald" or (enabled and "topaz" or "muted")))
    if not installed then t.text:SetTextColor(S.RGB("muted", 0.6)) end
  end
end

local function select_(key)
  if not pages[key] then pages[key] = buildPage(key) end
  current = key
  S.db.tab = key
  for k, p in pairs(pages) do p:SetShown(k == key) end
  for _, t in pairs(tabs) do paintTab(t) end
end

local function makeTab(nav, key, label, m, y)
  local t = CreateFrame("Button", nil, nav)
  t.key, t.m = key, m
  t:SetHeight(TAB_STEP - 2)
  t:SetPoint("TOPLEFT", 0, y); t:SetPoint("TOPRIGHT", 0, y)
  t.bg = t:CreateTexture(nil, "BACKGROUND"); t.bg:SetAllPoints()
  t.hover = t:CreateTexture(nil, "BACKGROUND", nil, 1); t.hover:SetAllPoints(); t.hover:SetColorTexture(S.RGB("raised")); t.hover:Hide()
  t.bar = t:CreateTexture(nil, "ARTWORK"); t.bar:SetColorTexture(S.RGB("amethyst"))
  t.bar:SetWidth(2); t.bar:SetPoint("TOPLEFT"); t.bar:SetPoint("BOTTOMLEFT")
  local x = 14
  if m then
    t.dot = S.IconTex(t, "dot", 8, "emerald")
    t.dot:SetPoint("LEFT", 14, 0)
    x = 30
  end
  t.text = S.Text(t, "body", 13, "soft")
  t.text:SetPoint("LEFT", x, 0)
  t.text:SetText(label)
  t:SetScript("OnEnter", function(s) if s.key ~= current then s.hover:Show() end end)
  t:SetScript("OnLeave", function(s) s.hover:Hide() end)
  t:SetScript("OnClick", function(s) s.hover:Hide(); select_(s.key) end)
  tabs[key] = t
  return t
end

local function build()
  win = CreateFrame("Frame", "SmilerSettings", UIParent, "BackdropTemplate")
  local maxH = (UIParent:GetHeight() or 768) - 40
  win:SetSize(WIN_W, math.min(WIN_H, math.max(580, maxH)))
  win:SetPoint("CENTER")
  win:SetFrameStrata("DIALOG")
  win:SetToplevel(true)
  win:SetClampedToScreen(true)
  win:SetMovable(true)
  win:EnableMouse(true)
  S.Panel(win, "void", 0.96, 0.38)
  S.TopLine(win, "amethyst", "diamond")
  tinsert(UISpecialFrames, "SmilerSettings")

  -- title bar (drag to move)
  local bar = CreateFrame("Frame", nil, win)
  bar:SetPoint("TOPLEFT", 1, -3); bar:SetPoint("TOPRIGHT", -1, -3); bar:SetHeight(42)
  bar:EnableMouse(true)
  bar:RegisterForDrag("LeftButton")
  bar:SetScript("OnDragStart", function() win:StartMoving() end)
  bar:SetScript("OnDragStop", function() win:StopMovingOrSizing() end)
  local ball = S.IconTex(bar, "ball", 20, "amethyst")
  ball:SetPoint("LEFT", 18, 0)
  local title = S.Text(bar, "label", 15, "amethyst")
  title:SetPoint("LEFT", ball, "RIGHT", 10, 0)
  title:SetText(S.Spaced("Smiler"))
  local ver = S.Text(bar, "body", 12, "muted")
  ver:SetPoint("LEFT", title, "RIGHT", 12, 0)
  ver:SetText("v" .. S.VERSION .. " · /smiler")
  local close = W.IconButton(bar, "close", 14, "muted", function() win:Hide() end, nil)
  close:SetPoint("RIGHT", -10, 0)
  local rule = win:CreateTexture(nil, "ARTWORK")
  rule:SetColorTexture(S.RGB("edge", 0.38)); rule:SetHeight(1)
  rule:SetPoint("TOPLEFT", 1, -45); rule:SetPoint("TOPRIGHT", -1, -45)

  -- tabs
  local nav = CreateFrame("Frame", nil, win, "BackdropTemplate")
  nav:SetPoint("TOPLEFT", 1, -46); nav:SetPoint("BOTTOMLEFT", 1, 1); nav:SetWidth(NAV_W)
  local navBg = nav:CreateTexture(nil, "BACKGROUND"); navBg:SetAllPoints(); navBg:SetColorTexture(S.RGB("card", 0.45))
  local navEdge = nav:CreateTexture(nil, "ARTWORK"); navEdge:SetColorTexture(S.RGB("edge", 0.38))
  navEdge:SetWidth(1); navEdge:SetPoint("TOPRIGHT"); navEdge:SetPoint("BOTTOMRIGHT")
  local y = -12
  makeTab(nav, "General", "General", nil, y); y = y - TAB_STEP
  makeTab(nav, "BlizzUI", "Blizzard UI", nil, y); y = y - TAB_STEP
  local sep = nav:CreateTexture(nil, "ARTWORK"); sep:SetColorTexture(S.RGB("edge", 0.25)); sep:SetHeight(1)
  sep:SetPoint("TOPLEFT", 14, y - 4); sep:SetPoint("TOPRIGHT", -14, y - 4); y = y - 12
  for _, m in ipairs(S.MODULES) do makeTab(nav, m.key, m.title, m, y); y = y - TAB_STEP end

  local navNote = S.Text(nav, "body", 12, "muted")
  navNote:SetWordWrap(true); navNote:SetWidth(NAV_W - 28)
  navNote:SetPoint("BOTTOMLEFT", 14, 16)
  navNote:SetText("Green dot: on.\nTurn one off on its tab.")
  local reload = W.Button(nav, "Reload to apply", NAV_W - 28, 28, function() ReloadUI() end, "primary")
  reload:SetPoint("BOTTOMLEFT", 14, 14)
  win.syncNav = function()
    reload:SetShown(S.pendingReload); navNote:SetShown(not S.pendingReload)
    for _, t in pairs(tabs) do paintTab(t) end
  end

  main = CreateFrame("Frame", nil, win)
  main:SetPoint("TOPLEFT", nav, "TOPRIGHT", 0, 0)
  main:SetPoint("BOTTOMRIGHT", -1, 1)

  win:SetScript("OnShow", function() win.syncNav(); if pages[current] then W.SyncAll(pages[current]) end end)
  win:SetScript("OnHide", function() W.ClosePopup() end)
  win:Hide()
end

function S.RefreshSettings()
  if not win or not win:IsShown() then return end
  win.syncNav()
  if pages[current] then W.SyncAll(pages[current]) end
end

function S:OpenSettings(key)
  if not win then build() end
  if not key and win:IsShown() then win:Hide(); return end
  key = key or (S.db and S.db.tab) or "General"
  if key ~= "General" and key ~= "BlizzUI" and not S.byKey[key] then key = "General" end
  select_(key)
  win:Show()
  win:Raise()
end

-- game Options > AddOns entry that points here
local reg = CreateFrame("Frame")
reg:RegisterEvent("PLAYER_LOGIN")
reg:SetScript("OnEvent", function()
  if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
  pcall(function()
    local panel = CreateFrame("Frame")
    local t = S.Text(panel, "display", 22, "amethyst"); t:SetPoint("TOPLEFT", 16, -16); t:SetText("Smiler")
    local n = S.Text(panel, "body", 13, "soft"); n:SetPoint("TOPLEFT", 16, -48)
    n:SetText("All the settings for the Smiler add-ons (SmilerKeys, CD Timeline, DiedTo, Splits and the rest) are in one window.")
    local b = W.Button(panel, "Open Smiler settings", 180, 28, function()
      if SettingsPanel then pcall(HideUIPanel, SettingsPanel) end
      S:OpenSettings()
    end, "primary")
    b:SetPoint("TOPLEFT", 16, -76)
    Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(panel, "Smiler"))
  end)
end)
