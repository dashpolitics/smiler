-- SmilerKeys: Targets - one row per slot that still has an upgrade in it.
-- Each row holds three picks: the TARGET you can realistically get now, the BIS you are working
-- towards, and any ALTERNATIVES worth taking on the way. Picking something puts it on the wishlist.
-- The list on the right is every pick in one order: drag it into the order you care about and the
-- "Where to go" planner re-weights around it (the order is written back as priorities 1..15).
local _, ns = ...
local L = ns.Loot
local T = ns.T

local W, H = 1000, 620
local ROW_H, PICK_W, SIDE_W = 44, 196, 300
local TOP = 92

local win, rows, sideRows = nil, {}, {}
local drag = nil       -- { id = itemID, row = frame, from = index }

local function refresh() if ns.Targets_Refresh then ns.Targets_Refresh() end end

local function shortName(n, max)
  n = n or "?"
  max = max or 20
  return #n > max and (n:sub(1, max - 1) .. "…") or n
end

local function qeText(q) return q and string.format("%+.1f%%", q) or "" end

---------------------------------------------------------------- picking an item
-- the menu of everything that would be an upgrade in this slot
local function pickMenu(owner, slotKey, kind)
  local cands = L.SlotCandidates(slotKey)
  if #cands == 0 then ns.Print("Nothing in " .. L.slotByKey[slotKey].label .. " would be an upgrade right now.") return end
  local function choose(c) L.SetTarget(slotKey, kind, c.it); refresh() end
  if MenuUtil and MenuUtil.CreateContextMenu then
    MenuUtil.CreateContextMenu(owner, function(_, root)
      root:CreateTitle(L.PICK_LABEL[kind] .. "  ·  " .. L.slotByKey[slotKey].label)
      local nNow, nLater = 0, 0
      for _, c in ipairs(cands) do if c.now then nNow = nNow + 1 else nLater = nLater + 1 end end
      local function section(title, want)
        local first = true
        for _, c in ipairs(cands) do
          if c.now == want then
            if first then root:CreateTitle(title); first = false end
            local tag = {}
            if c.qe then tag[#tag + 1] = qeText(c.qe) end
            if c.max then tag[#tag + 1] = c.max end
            if c.kind then tag[#tag + 1] = L.PICK_LABEL[c.kind]:lower() end
            root:CreateButton(shortName(c.it.name, 34) .. "  |cff8f7fb8" .. table.concat(tag, " · ") .. "|r", function() choose(c) end)
          end
        end
      end
      if nNow > 0 then section("Can get now", true) end
      if nLater > 0 then section("Not yet (Mythic past your farm)", false) end
      local p = L.SlotPicks(slotKey)
      if (kind == "alt" and #p.alts > 0) or p[kind] then
        root:CreateDivider()
        root:CreateButton("Clear", function() L.ClearTarget(slotKey, kind); refresh() end)
      end
    end)
  else
    choose(cands[1])
  end
end

-- right-click an existing pick: move it between the three roles, or drop it
local function pickActions(owner, slotKey, kind, id)
  if not (MenuUtil and MenuUtil.CreateContextMenu) then L.ClearTarget(slotKey, kind, id); refresh(); return end
  MenuUtil.CreateContextMenu(owner, function(_, root)
    local it = L.ItemByID(id)
    root:CreateTitle(shortName(it and it.name or "?", 34))
    for _, k in ipairs(L.PICK_KINDS) do
      if k ~= kind then root:CreateButton("Make " .. L.PICK_LABEL[k]:lower(), function() L.SetTarget(slotKey, k, id); refresh() end) end
    end
    root:CreateDivider()
    root:CreateButton("Remove", function() L.ClearTarget(slotKey, kind, id); refresh() end)
  end)
end

---------------------------------------------------------------- one pick box inside a row
local function makePick(parent)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(PICK_W, ROW_H - 10)
  T.Panel(b, "card", 0.55, 0.22)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(22, 22); b.icon:SetPoint("LEFT", 5, 0)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.name = T.Text(b, "strong", 12, "text"); b.name:SetPoint("TOPLEFT", 32, -5); b.name:SetWidth(PICK_W - 38)
  b.sub = T.Text(b, "body", 10, "muted"); b.sub:SetPoint("TOPLEFT", 32, -20); b.sub:SetWidth(PICK_W - 38)
  b:SetScript("OnEnter", function(self)
    self:SetBackdropColor(T.RGB("raised", 0.9))
    if self.id then
      local it = L.ItemByID(self.id)
      local link = it and L.LinkFor and L.LinkFor(it)
      if link then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink(link); GameTooltip:Show() end
    end
  end)
  b:SetScript("OnLeave", function(self) self:SetBackdropColor(T.RGB("card", 0.55)); GameTooltip:Hide() end)
  b:SetScript("OnClick", function(self, button)
    if not self.slot then return end
    if button == "RightButton" and self.id then pickActions(self, self.slot, self.kind, self.id)
    else pickMenu(self, self.slot, self.kind) end
  end)
  return b
end

local function setPick(b, slotKey, kind, id, extra)
  b.slot, b.kind, b.id = slotKey, kind, id
  local it = id and L.ItemByID(id)
  if it then
    b.icon:SetTexture(it.icon or 134400); b.icon:Show()
    b.name:SetText(shortName(it.name, 22)); b.name:SetTextColor(T.RGB("text"))
    local bits = {}
    local q = L.QEScores and L.QEScores()
    q = (q and q.scores) or {}
    if q[id] then bits[#bits + 1] = qeText(q[id]) end
    local max = L.MaxIlvl(it)
    if max then bits[#bits + 1] = max end
    if not L.Achievable(it) then bits[#bits + 1] = "|cffffab00not yet|r" end
    local pr = L.Prio(id)
    if pr then bits[#bits + 1] = "P" .. pr end
    b.sub:SetText(table.concat(bits, " · "))
    b:SetBackdropBorderColor(T.RGB(kind == "bis" and "topaz" or kind == "target" and "emerald" or "edge", 0.55))
  else
    b.icon:Hide()
    b.name:SetText("|cff6f6090+  " .. (extra or L.PICK_LABEL[kind]) .. "|r")
    b.sub:SetText(kind == "alt" and "|cff6f6090other options|r" or "")
    b:SetBackdropBorderColor(T.RGB("edge", 0.18))
  end
  b:Show()
end

---------------------------------------------------------------- slot row
local function makeRow(parent, i)
  local r = CreateFrame("Frame", nil, parent)
  r:SetSize(W - SIDE_W - 48, ROW_H)
  r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints(); r.bg:SetColorTexture(T.RGB("card", 0.22))
  r.label = T.Text(r, "label", 12, "soft"); r.label:SetPoint("TOPLEFT", 6, -6); r.label:SetWidth(78)
  r.eq = T.Text(r, "body", 10, "muted"); r.eq:SetPoint("TOPLEFT", 6, -22); r.eq:SetWidth(78)
  r.target = makePick(r); r.target:SetPoint("TOPLEFT", 88, -5)
  r.bis = makePick(r); r.bis:SetPoint("TOPLEFT", 88 + PICK_W + 6, -5)
  r.alt = makePick(r); r.alt:SetPoint("TOPLEFT", 88 + (PICK_W + 6) * 2, -5)
  r.altMore = T.Text(r, "body", 10, "muted"); r.altMore:SetPoint("TOPLEFT", 88 + (PICK_W + 6) * 2, -ROW_H + 8)
  rows[i] = r
  return r
end

---------------------------------------------------------------- priority list (drag to reorder)
local function makeSideRow(parent, i)
  local r = CreateFrame("Button", nil, parent, "BackdropTemplate")
  r:SetSize(SIDE_W, 26)
  T.Panel(r, "card", 0.4, 0.2)
  r:RegisterForDrag("LeftButton")
  r.num = T.Text(r, "strong", 11, "amethyst", "RIGHT"); r.num:SetPoint("LEFT", 2, 0); r.num:SetWidth(18)
  r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(16, 16); r.icon:SetPoint("LEFT", 24, 0)
  r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.name = T.Text(r, "body", 11, "text"); r.name:SetPoint("LEFT", 44, 0); r.name:SetWidth(SIDE_W - 110)
  r.tag = T.Text(r, "body", 10, "muted", "RIGHT"); r.tag:SetPoint("RIGHT", -6, 0)
  r:SetScript("OnDragStart", function(self)
    if not self.id then return end
    drag = { id = self.id, from = self.index }
    self:SetBackdropColor(T.RGB("amethyst", 0.45))
  end)
  r:SetScript("OnDragStop", function(self)
    self:SetBackdropColor(T.RGB("card", 0.4))
    if not drag then return end
    -- where did it land? the row under the cursor
    local _, cy = GetCursorPosition()
    cy = cy / UIParent:GetEffectiveScale()
    local to
    for _, o in ipairs(sideRows) do
      if o:IsShown() and o.index and cy <= o:GetTop() and cy >= o:GetBottom() then to = o.index break end
    end
    local id = drag.id
    drag = nil
    if to and to ~= self.index then
      local list = L.TargetList()
      local at
      for k, e in ipairs(list) do if e.id == id then at = k break end end
      if at then
        local e = table.remove(list, at)
        table.insert(list, math.min(to, #list + 1), e)
        local ids = {}
        for k, x in ipairs(list) do ids[k] = x.id end
        L.ApplyTargetOrder(ids)
      end
    end
    refresh()
  end)
  r:SetScript("OnEnter", function(self)
    self:SetBackdropColor(T.RGB("raised", 0.7))
    if self.id then
      local it = L.ItemByID(self.id)
      local link = it and L.LinkFor and L.LinkFor(it)
      if link then GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetHyperlink(link) end
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine("Drag to move it up or down. Mouse wheel over the list also works.", 0.7, 0.63, 0.86)
      GameTooltip:Show()
    end
  end)
  r:SetScript("OnLeave", function(self) self:SetBackdropColor(T.RGB("card", 0.4)); GameTooltip:Hide() end)
  r:EnableMouseWheel(true)
  r:SetScript("OnMouseWheel", function(self, d) if self.id then L.MoveTarget(self.id, -d); refresh() end end)
  sideRows[i] = r
  return r
end

---------------------------------------------------------------- window
local function build()
  win = CreateFrame("Frame", "SmilerKeysTargets", UIParent, "BackdropTemplate")
  win:SetSize(W, H); win:SetPoint("CENTER")
  win:SetFrameStrata("DIALOG"); win:SetToplevel(true); win:SetClampedToScreen(true)
  win:SetMovable(true); win:EnableMouse(true); win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", win.StartMoving); win:SetScript("OnDragStop", win.StopMovingOrSizing)
  T.Panel(win, "void", 0.97, 0.38); T.TopLine(win)
  tinsert(UISpecialFrames, "SmilerKeysTargets")

  local title = T.Text(win, "label", 14, "amethyst"); title:SetPoint("TOPLEFT", 16, -15); title:SetText("T A R G E T S")
  win.sub = T.Text(win, "body", 12, "muted"); win.sub:SetPoint("LEFT", title, "RIGHT", 12, 0)
  local close = CreateFrame("Button", nil, win); close:SetSize(22, 22); close:SetPoint("TOPRIGHT", -8, -9)
  close.icon = T.IconTex(close, "close", 13, "muted"); close.icon:SetPoint("CENTER")
  close:SetScript("OnClick", function() win:Hide() end)

  win.profile = T.Segmented(win, { { "heroic", "Heroic" }, { "mythic", "Mythic" } },
    function() return L.Profile() end, function(k) L.SetProfile(k); refresh() end, 22)
  win.profile:SetPoint("TOPLEFT", 16, -42)
  win.plan = T.Button(win, "Where to go", 110, 22, function() if ns.PlannerOpen then ns.PlannerOpen() end end)
  win.plan:SetPoint("LEFT", win.profile, "RIGHT", 12, 0)
  win.help = T.Text(win, "body", 11, "muted"); win.help:SetPoint("LEFT", win.plan, "RIGHT", 14, 0)
  win.help:SetText("Click a box to pick · right-click one to move it between target / BiS / alternative")

  -- column headings
  local function head(text, x, color)
    local h = T.Text(win, "label", 11, color or "muted"); h:SetPoint("TOPLEFT", x, -TOP + 16); h:SetText(text); return h
  end
  head("SLOT", 16)
  head("TARGET  ·  can get now", 16 + 88, "emerald")
  head("BIS  ·  working towards", 16 + 88 + PICK_W + 6, "topaz")
  head("ALTERNATIVES", 16 + 88 + (PICK_W + 6) * 2)

  win.list = CreateFrame("Frame", nil, win)
  win.list:SetPoint("TOPLEFT", 16, -TOP)
  win.list:SetSize(W - SIDE_W - 48, H - TOP - 44)
  win.list:SetClipsChildren(true)
  win.empty = T.Text(win.list, "body", 12, "muted"); win.empty:SetPoint("TOPLEFT", 6, -8); win.empty:SetWidth(W - SIDE_W - 60)
  win.empty:SetWordWrap(true)

  local div = win:CreateTexture(nil, "ARTWORK"); div:SetColorTexture(T.RGB("edge", 0.25)); div:SetWidth(1)
  div:SetPoint("TOPLEFT", W - SIDE_W - 24, -TOP + 10); div:SetPoint("BOTTOMLEFT", W - SIDE_W - 24, 36)

  win.side = CreateFrame("Frame", nil, win)
  win.side:SetPoint("TOPLEFT", W - SIDE_W - 12, -TOP)
  win.side:SetSize(SIDE_W, H - TOP - 44)
  win.side:SetClipsChildren(true)
  win.sideHead = T.Text(win, "label", 11, "muted"); win.sideHead:SetPoint("TOPLEFT", W - SIDE_W - 12, -TOP + 16)
  win.sideHead:SetText("MY ORDER  ·  drag to reorder")
  win.sideNote = T.Text(win, "body", 10, "muted"); win.sideNote:SetPoint("BOTTOMLEFT", W - SIDE_W - 12, 12)
  win.sideNote:SetWidth(SIDE_W); win.sideNote:SetWordWrap(true)

  win.foot = T.Text(win, "body", 10, "muted"); win.foot:SetPoint("BOTTOMLEFT", 16, 12); win.foot:SetWidth(W - SIDE_W - 48)
  win.foot:SetWordWrap(true)
  win.foot:SetText("Every pick goes on your wishlist, so \"Where to go\" plans bonus rolls, kills and crafts around it. The order on the right is written back as priorities, which is what weights the plan.")

  win:SetScript("OnShow", function() if not L.items then L.Refresh(true) end; refresh() end)
  win:Hide()
end

---------------------------------------------------------------- draw
function ns.Targets_Refresh()
  if not win or not win:IsShown() then return end
  if win.profile and win.profile.Sync then win.profile:Sync() end
  local slots = L.SlotsWithUpgrades()
  local y = 0
  local used = 0
  for i, s in ipairs(slots) do
    used = used + 1
    local r = rows[i] or makeRow(win.list, i)
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y)
    r.bg:SetColorTexture(T.RGB("card", (i % 2 == 0) and 0.22 or 0.10))
    r.label:SetText(s.slot.label)
    local eq = L.Equipped(s.slot.key)
    local lv = {}
    for _, e in ipairs(eq) do lv[#lv + 1] = e.ilvl or "-" end
    r.eq:SetText(#lv > 0 and ("wearing " .. table.concat(lv, "/")) or "")
    if s.done then r.label:SetTextColor(T.RGB("emerald")) else r.label:SetTextColor(T.RGB("soft")) end
    setPick(r.target, s.slot.key, "target", s.picks.target)
    setPick(r.bis, s.slot.key, "bis", s.picks.bis)
    setPick(r.alt, s.slot.key, "alt", s.picks.alts[1], #s.picks.alts > 0 and "Add another" or nil)
    r.altMore:SetText(#s.picks.alts > 1 and ("+" .. (#s.picks.alts - 1) .. " more · right-click to manage") or "")
    r:Show()
    y = y + ROW_H + 1
  end
  for i = used + 1, #rows do rows[i]:Hide() end
  win.empty:SetText(used == 0 and "No upgrades found for this character yet. Open the gear guide (/sk loot) and scan, or lower the profile to Heroic." or "")
  win.sub:SetText(used .. (used == 1 and " slot" or " slots") .. " with an upgrade available")

  -- the order list
  local list = L.TargetList()
  local sy, n = 0, 0
  for i, e in ipairs(list) do
    n = i
    local r = sideRows[i] or makeSideRow(win.side, i)
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -sy)
    r.index, r.id = i, e.id
    r.num:SetText(i)
    r.icon:SetTexture(e.it.icon or 134400)
    local kindC = e.kind == "bis" and "topaz" or e.kind == "target" and "emerald" or "muted"
    r.name:SetText("|cff" .. T.Hex(kindC) .. "·|r " .. shortName(e.it.name, 24))
    local bits = {}
    if e.qe then bits[#bits + 1] = qeText(e.qe) end
    if not e.now then bits[#bits + 1] = "|cffffab00!|r" end
    r.tag:SetText(table.concat(bits, " "))
    r:Show()
    sy = sy + 27
  end
  for i = n + 1, #sideRows do sideRows[i]:Hide() end
  win.sideNote:SetText(n == 0 and "Pick a target or a BiS on the left and it appears here."
    or ("Drag a row to move it. " .. n .. " picks; the top " .. math.min(n, L.PRIO_MAX) .. " become priorities 1-" .. math.min(n, L.PRIO_MAX) .. "."))
end

function ns.TargetsOpen()
  if not win then build() end
  if win:IsShown() then win:Hide() else win:Show() end
end
