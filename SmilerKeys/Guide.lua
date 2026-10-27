-- SmilerKeys: gear guide – walk through each slot, see every item you could get for it ranked by
-- power (or grouped by where it drops), pick a track and upgrade level, and add it to your wishlist.
local _, ns = ...
local L = ns.Loot
local T = ns.T

local W, H = 980, 702
local RAIL_Y, LEFT_W = -48, 270
local CARD_H, CARD_GAP, CARDS = 62, 6, 6

local win
local cards, chips, wishIcons = {}, {}, {}
local state = { slot = 1, sort = "power", offset = 0 }
local shown = {}

local ORDER = { "head", "neck", "shoulder", "back", "chest", "wrist", "hands", "waist",
                "legs", "feet", "finger", "trinket", "main", "off", "emb" }
local SHORT = { head = "HEAD", neck = "NECK", shoulder = "SHLD", back = "BACK", chest = "CHEST", wrist = "WRIST",
                hands = "HANDS", waist = "WAIST", legs = "LEGS", feet = "FEET", finger = "RINGS", trinket = "TRINK",
                main = "MAIN", off = "OFF", emb = "EMB" }
local KIND = {
  raid    = { "RAID",  "amethyst" }, bonus = { "RAID", "amethyst" },
  mplus   = { "M+",    "sapphire" }, vault = { "M+",   "sapphire" },
  crafted = { "CRAFT", "topaz" },    delve = { "DELVE", "emerald" },
}

local function view() return ns.LootView or { track = "hero", rank = 1, via = "any" } end
local function qeScores() local q = L.QEScores and L.QEScores(); return q and q.scores end
local function slotKey() return ORDER[state.slot] end
local function refresh() if ns.LootUI_Refresh then ns.LootUI_Refresh() elseif ns.Guide_Refresh then ns.Guide_Refresh() end end

---------------------------------------------------------------- which items, in what order
local function kindOf(it)
  if it.labyrinth or it.delve then return "delve" end
  if it.crafted or it.reagent then return "crafted" end
  if it.raid then return "raid" end
  return "mplus"
end

local function sourceKey(it)
  local k = kindOf(it)
  local order = ({ raid = 1, mplus = 2, crafted = 3, delve = 4 })[k]
  return string.format("%d%s%03d", order, it.inst or "", it.encIndex or 0)
end

local function sourceLabel(it)
  if it.raid then return (it.encName and it.encName ~= "" and (it.encName .. "  ·  ") or "") .. (it.inst or "") end
  if it.labyrinth then return it.inst .. "  ·  3 Mythical Soul Fragments" end
  if it.delveLoot then return "Delves  ·  Great Vault and top-tier chests" end
  if it.crafted then return "Crafting order" .. (it.inst and it.inst ~= "" and ("  ·  " .. it.inst) or "") end
  return (it.inst or "") .. "  ·  Mythic+"
end

local function collect()
  wipe(shown)
  local key = slotKey()
  local v = view()
  for _, it in ipairs(L.items or {}) do
    local match = (key == "emb") and (it.slot == "emb" or it.reagent) or (it.slot == key)
    if match and not it.hidden then shown[#shown + 1] = it end
  end
  local function power(it) return (L.IlvlAt(it, v.track, v.rank, v.via) or 0) * 1000 + (L.MaxIlvl(it) or 0) end
  local qe = qeScores()
  table.sort(shown, function(a, b)
    if state.sort == "qe" and qe then
      local qa, qb = qe[a.id] or -999, qe[b.id] or -999
      if qa ~= qb then return qa > qb end
    end
    if state.sort == "prio" then
      local pa, pb = L.Prio(a.id) or 99, L.Prio(b.id) or 99
      if pa ~= pb then return pa < pb end
    end
    if state.sort == "stats" then
      local va, vb = L.StatValue(a, v.track, v.rank, v.via), L.StatValue(b, v.track, v.rank, v.via)
      if va ~= vb then return va > vb end
    end
    if state.sort == "source" then
      local sa, sb = sourceKey(a), sourceKey(b)
      if sa ~= sb then return sa < sb end
    end
    local pa, pb = power(a), power(b)
    if pa ~= pb then return pa > pb end
    if (a.tier and 1 or 0) ~= (b.tier and 1 or 0) then return a.tier and true or false end
    return (a.name or "") < (b.name or "")
  end)
  state.offset = math.max(0, math.min(state.offset, #shown - CARDS))
end

---------------------------------------------------------------- a card
local function routeMenu(owner, it)
  if ns.RouteMenu then ns.RouteMenu(owner, it, slotKey() == "emb" and "emb" or it.slot); return end
  if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
  MenuUtil.CreateContextMenu(owner, function(_, root)
    root:CreateTitle(it.name or "Item")
    root:CreateTitle("Add it as")
    for _, r in ipairs(L.Routes(it)) do
      local text = r.label .. "  ·  " .. (r.fixed and tostring(r.ilvl) or (L.TrackLabel(r.track, r.rank) .. "  " .. r.ilvl .. " → " .. r.max))
      root:CreateButton(text, function()
        if L.Add(it, slotKey() == "emb" and "emb" or it.slot, L.TargetFromRoute(r, view().rank)) then
          if SOUNDKIT and SOUNDKIT.IG_ABILITY_ICON_DROP then PlaySound(SOUNDKIT.IG_ABILITY_ICON_DROP) end
        end
        refresh()
      end)
    end
    root:CreateDivider()
    L.PrioMenu(root, it.id, refresh)
  end)
end

local function makeCard(parent, i)
  local c = CreateFrame("Button", nil, parent, "BackdropTemplate")
  c:SetHeight(CARD_H)
  c:SetPoint("TOPLEFT", 0, -(i - 1) * (CARD_H + CARD_GAP))
  c:SetPoint("TOPRIGHT", 0, -(i - 1) * (CARD_H + CARD_GAP))
  c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  T.Panel(c, "card", 0.9, 0)
  c.bar = c:CreateTexture(nil, "ARTWORK"); c.bar:SetPoint("TOPLEFT"); c.bar:SetPoint("BOTTOMLEFT"); c.bar:SetWidth(3)

  c.icon = c:CreateTexture(nil, "ARTWORK"); c.icon:SetSize(40, 40); c.icon:SetPoint("LEFT", 12, 0)
  c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  c.name = T.Text(c, "strong", 14, "text"); c.name:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 12, -1)
  c.name:SetPoint("RIGHT", c, "RIGHT", -380, 0)

  -- where it comes from: kind chip + boss / dungeon
  c.kind = CreateFrame("Frame", nil, c, "BackdropTemplate")
  c.kind:SetHeight(16); c.kind:SetPoint("BOTTOMLEFT", c.icon, "BOTTOMRIGHT", 12, 1)
  c.kind:SetBackdrop(T.BACKDROP); c.kind:SetBackdropColor(0, 0, 0, 0)
  c.kind.t = T.Text(c.kind, "display", 11, "text", "CENTER"); c.kind.t:SetPoint("CENTER")
  c.where = T.Text(c, "body", 12, "soft"); c.where:SetPoint("LEFT", c.kind, "RIGHT", 8, 0)
  c.where:SetPoint("RIGHT", c, "RIGHT", -380, 0)
  c.tags = T.Text(c, "display", 12, "topaz"); c.tags:SetPoint("LEFT", c.name, "RIGHT", 8, 0)

  -- power on the chosen track
  c.ilvl = T.Text(c, "display", 24, "text", "RIGHT"); c.ilvl:SetPoint("TOPRIGHT", -136, -8); c.ilvl:SetWidth(60)
  c.gain = T.Text(c, "display", 13, "emerald", "LEFT"); c.gain:SetPoint("LEFT", c.ilvl, "RIGHT", 6, 0)
  c.route = T.Text(c, "body", 11, "muted", "RIGHT"); c.route:SetPoint("BOTTOMRIGHT", -136, 8); c.route:SetWidth(230)

  -- BiS star and add button
  c.bisBtn = CreateFrame("Button", nil, c)
  c.bisBtn:SetSize(24, 24); c.bisBtn:SetPoint("RIGHT", -104, 0)
  c.bisBtn.icon = T.IconTex(c.bisBtn, "star", 18, "muted"); c.bisBtn.icon:SetPoint("CENTER")
  c.bisBtn:SetScript("OnClick", function() if c.item then L.ToggleBiS(c.item.id); refresh() end end)
  c.bisBtn:SetScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_TOP"); GameTooltip:AddLine("Best in slot", T.RGB("diamond"))
    GameTooltip:AddLine("Click to mark or unmark this item as your BiS.", 1, 1, 1, true); GameTooltip:Show()
  end)
  c.bisBtn:SetScript("OnLeave", GameTooltip_Hide)
  c.add = T.Button(c, "Add", 62, 26, function()
    local it = c.item
    if not it then return end
    if L.IsWished(it.id) and not it.reagent then
      local list = L.Wish()[slotKey()] or L.Wish()[it.slot] or {}
      for idx, e in ipairs(list) do if e.id == it.id then L.Remove(slotKey() == "emb" and "emb" or it.slot, idx); break end end
    else
      local tgt = ns.LootTargetFor and ns.LootTargetFor(it) or {}
      local q = qeScores(); if q and q[it.id] then tgt.qe = q[it.id] end
      if L.Add(it, slotKey() == "emb" and "emb" or it.slot, tgt) and SOUNDKIT and SOUNDKIT.IG_ABILITY_ICON_DROP then
        PlaySound(SOUNDKIT.IG_ABILITY_ICON_DROP)
      end
    end
    refresh()
  end, "primary")
  c.add:SetPoint("RIGHT", -36, 0)
  c.how = CreateFrame("Button", nil, c, "BackdropTemplate")
  c.how:SetSize(22, 26); c.how:SetPoint("LEFT", c.add, "RIGHT", 2, 0)
  T.Panel(c.how, "raised", 1, 0.6)
  c.how.icon = T.IconTex(c.how, "arrow", 10, "text"); c.how.icon:SetRotation(math.pi); c.how.icon:SetPoint("CENTER")
  c.how:SetScript("OnClick", function(s) if c.item then routeMenu(s, c.item) end end)
  c.how:SetScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_TOP"); GameTooltip:AddLine("Choose how to get it", T.RGB("amethyst"))
    GameTooltip:AddLine("Pick the exact way, e.g. Heroic bonus roll or Mythic raid.", 1, 1, 1, true); GameTooltip:Show()
  end)
  c.how:SetScript("OnLeave", GameTooltip_Hide)

  c:SetScript("OnClick", function(self, btn)
    local it = self.item
    if not it then return end
    if btn == "RightButton" then routeMenu(self, it)
    elseif IsControlKeyDown() then
      local r = L.RouteOn(it, view().track); local link = L.LinkFor(it, r and r.diff or 15, r and r.mode or "drop")
      if link then DressUpItemLink(link) end
    elseif IsAltKeyDown() then L.ToggleBiS(it.id); refresh() end
  end)
  c:SetScript("OnEnter", function(self)
    self:SetBackdropColor(T.RGB("raised", 0.95))
    local it = self.item
    if not it then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local r = L.RouteOn(it, view().track)
    local link = L.LinkFor(it, r and r.diff or 15, r and r.mode or "drop")
    if it.labyrinth then GameTooltip:SetItemByID(L.SEASON.labyrinth.item)
    elseif link then GameTooltip:SetHyperlink(link) else GameTooltip:SetItemByID(it.id) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Ways to get it", T.RGB("amethyst"))
    for _, x in ipairs(L.Routes(it)) do
      local right = x.fixed and tostring(x.ilvl) or (L.TrackLabel(x.track, x.rank) .. "  " .. x.ilvl .. " → " .. x.max)
      GameTooltip:AddDoubleLine(x.label, right, 1, 1, 1, 0.85, 0.85, 0.85)
    end
    GameTooltip:AddLine("Right-click to pick how to get it · Ctrl-click: preview", T.RGB("muted"))
    GameTooltip:Show()
  end)
  c:SetScript("OnLeave", function(self) self:SetBackdropColor(T.RGB("card", 0.9)); GameTooltip:Hide() end)
  return c
end

local function fillCard(c, it, first)
  c.item = it
  c:SetShown(it ~= nil)
  if not it then return end
  local v = view()
  c.icon:SetTexture(it.icon)
  c.name:SetText(it.cname or it.name or ("item " .. it.id))
  local tags = {}
  if L.Prio(it.id) then tags[#tags + 1] = "PRIORITY " .. L.Prio(it.id) end
  if first then tags[#tags + 1] = "TOP PICK" end
  local qe = qeScores()
  if qe and qe[it.id] then tags[#tags + 1] = string.format("QE %+.2f%%", qe[it.id]) end
  do
    local _, fit, slink = L.StatValue(it, v.track, v.rank, v.via)
    local st = L.StatText(slink)
    if st then tags[#tags + 1] = st:upper() .. (fit and string.format(" %d%%", math.floor(fit * 100 + 0.5)) or "") end
  end
  if it.tier then tags[#tags + 1] = "TIER" end
  if it.bonus then tags[#tags + 1] = "BR" end
  if it.emb and not it.reagent then tags[#tags + 1] = "EMBELLISHED" end
  if it.reagent then
    local n = 0
    for _, r in ipairs(L.Wish().emb or {}) do if r.id == it.id then n = n + 1 end end
    if n > 0 then tags[#tags + 1] = n .. " PLANNED" end
    if it.fits then tags[#tags + 1] = it.fits:upper() end
  end
  c.tags:SetText(table.concat(tags, "  "))
  local k = KIND[kindOf(it)] or KIND.mplus
  c.kind.t:SetText(k[1]); c.kind.t:SetTextColor(T.RGB(k[2]))
  c.kind:SetBackdropBorderColor(T.RGB(k[2], 0.7))
  c.kind:SetWidth(math.max(36, c.kind.t:GetStringWidth() + 12))
  c.where:SetText(sourceLabel(it))

  local lv, r = L.IlvlAt(it, v.track, v.rank, v.via)
  if lv then
    c.ilvl:SetText(lv); c.ilvl:SetTextColor(T.RGB("text"))
    local gain = it.slot ~= "other" and L.Gain(it, lv)
    c.gain:SetText(gain and gain > 0 and ("+" .. gain) or "")
    c.route:SetText(r.fixed and r.label or (r.label .. "  ·  " .. L.TrackLabel(r.track, math.max(v.rank, r.rank or 1))))
    c:SetAlpha(1)
  else
    local best = L.Routes(it)[1]
    c.ilvl:SetText("—"); c.ilvl:SetTextColor(T.RGB("muted"))
    c.gain:SetText("")
    c.route:SetText(best and ("Not this way on " .. L.TRACK[v.track].name .. " · best: " .. best.label) or "")
    c:SetAlpha(0.55)
  end

  local wished, bis = L.IsWished(it.id), L.IsBiS(it.id)
  c.bar:SetColorTexture(T.RGB(bis and "diamond" or "amethyst", (wished or bis) and 1 or 0))
  T.Icon(c.bisBtn.icon, "star")
  if T.hasCore then c.bisBtn.icon:SetVertexColor(T.RGB(bis and "diamond" or "muted")) end
  c.bisBtn.icon:SetAlpha(bis and 1 or 0.45)
  local copies = 0
  if it.reagent then for _, r in ipairs(L.Wish().emb or {}) do if r.id == it.id then copies = copies + 1 end end end
  if it.reagent then wished = false end
  c.add:SetLabel(copies == 1 and "Add 2nd" or (wished and "Added" or "Add"))
  if c.add.style then c.add.style = wished and nil or "primary"; if c.add.Paint then c.add:Paint() end end
end

---------------------------------------------------------------- window
local function makeChip(parent, i, key)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(58, 40)
  b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints()
  b.under = b:CreateTexture(nil, "ARTWORK"); b.under:SetPoint("BOTTOMLEFT"); b.under:SetPoint("BOTTOMRIGHT"); b.under:SetHeight(2)
  b.under:SetColorTexture(T.RGB("amethyst"))
  b.t = T.Text(b, "label", 11, "soft", "CENTER"); b.t:SetPoint("TOP", 0, -5); b.t:SetText(SHORT[key])
  b.icon = b:CreateTexture(nil, "OVERLAY"); b.icon:SetSize(12, 12); b.icon:SetPoint("BOTTOM", -8, 7)
  b.n = T.Text(b, "display", 12, "text", "LEFT"); b.n:SetPoint("LEFT", b.icon, "RIGHT", 3, 0)
  b:SetScript("OnClick", function() state.slot = i; state.offset = 0; ns.Guide_Refresh() end)
  b:SetScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(L.slotByKey[key].label, T.RGB("amethyst"))
    local ok = key ~= "emb" and L.SlotState(key)
    GameTooltip:AddLine(ok and "BiS" or ((#(L.Wish()[key] or {})) .. " on your wishlist"), 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  return b
end

local function build()
  win = CreateFrame("Frame", "SmilerKeysGuide", UIParent, "BackdropTemplate")
  win:SetSize(W, H)
  win:SetPoint("CENTER")
  win:SetFrameStrata("DIALOG")
  win:SetToplevel(true)
  win:SetClampedToScreen(true)
  win:SetMovable(true)
  win:EnableMouse(true)
  win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", win.StartMoving)
  win:SetScript("OnDragStop", win.StopMovingOrSizing)
  T.Panel(win, "void", 0.97, 0.38)
  T.TopLine(win)
  tinsert(UISpecialFrames, "SmilerKeysGuide")

  local title = T.Text(win, "label", 14, "amethyst"); title:SetPoint("TOPLEFT", 16, -15); title:SetText("G E A R   G U I D E")
  win.sub = T.Text(win, "body", 12, "muted"); win.sub:SetPoint("LEFT", title, "RIGHT", 12, 0)
  win.profile = T.Segmented(win, L.PROFILES, function() return L.Profile() end,
    function(k) L.SetProfile(k); refresh() end, 22)
  win.profile:SetPoint("TOPRIGHT", win, "TOPRIGHT", -40, -10)
  win.statCtx = T.Segmented(win, { { "raid", "Raid stats" }, { "mplus", "M+ stats" } }, function() return L.StatContext() end,
    function(k) L.SetStatContext(k); refresh() end, 22)
  win.statCtx:SetPoint("RIGHT", win.profile, "LEFT", -10, 0)
  win.statCtx:SetScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Secondary stat priority", T.RGB("amethyst"))
    for _, c in ipairs(L.STAT_CONTEXTS) do
      GameTooltip:AddDoubleLine(c[2], L.StatPrioText(c[1]) or "not set", 1, 1, 1, 0.8, 0.8, 0.8)
    end
    GameTooltip:AddLine("Set the ranking in Smiler settings > Loot. Sort By stats to use it.", 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
  end)
  win.statCtx:SetScript("OnLeave", GameTooltip_Hide)
  local close = CreateFrame("Button", nil, win); close:SetSize(22, 22); close:SetPoint("TOPRIGHT", -8, -9)
  close.icon = T.IconTex(close, "close", 13, "muted"); close.icon:SetPoint("CENTER")
  close:SetScript("OnClick", function() win:Hide() end)

  -- slot rail
  local rail = CreateFrame("Frame", nil, win)
  rail:SetPoint("TOPLEFT", 16, RAIL_Y); rail:SetPoint("TOPRIGHT", -16, RAIL_Y); rail:SetHeight(40)
  local cw = (W - 32 - (#ORDER - 1) * 4) / #ORDER
  for i, key in ipairs(ORDER) do
    local b = makeChip(rail, i, key)
    b:SetWidth(cw)
    b:SetPoint("TOPLEFT", (i - 1) * (cw + 4), 0)
    chips[i] = b
  end

  -- left: the slot you're on
  local left = CreateFrame("Frame", nil, win)
  left:SetPoint("TOPLEFT", 16, -104); left:SetSize(LEFT_W, H - 160)
  win.slotName = T.Text(left, "display", 30, "text"); win.slotName:SetPoint("TOPLEFT", 0, 0)
  win.step = T.Text(left, "label", 12, "muted"); win.step:SetPoint("TOPLEFT", win.slotName, "BOTTOMLEFT", 0, -2)

  local wl = T.Text(left, "label", 12, "muted"); wl:SetPoint("TOPLEFT", 0, -64); wl:SetText("YOU'RE WEARING")
  win.wear = {}
  for j = 1, 2 do
    local row = CreateFrame("Button", nil, left)
    row:SetSize(LEFT_W, 34); row:SetPoint("TOPLEFT", 0, -84 - (j - 1) * 38)
    row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(30, 30); row.icon:SetPoint("LEFT")
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.name = T.Text(row, "body", 13, "text"); row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -1); row.name:SetPoint("RIGHT", -4, 0)
    row.lv = T.Text(row, "display", 12, "soft"); row.lv:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 1)
    row:SetScript("OnEnter", function(s) if s.link then GameTooltip:SetOwner(s, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink(s.link); GameTooltip:Show() end end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    win.wear[j] = row
  end

  -- BiS for this slot: a plain on/off switch
  win.bisRow = CreateFrame("Button", nil, left, "BackdropTemplate")
  win.bisRow:SetSize(LEFT_W, 36); win.bisRow:SetPoint("TOPLEFT", 0, -168)
  T.Panel(win.bisRow, "card", 0.9, 0.6)
  win.bisRow.icon = T.IconTex(win.bisRow, "tickcircle", 16, "muted"); win.bisRow.icon:SetPoint("LEFT", 10, 0)
  win.bisRow.t = T.Text(win.bisRow, "strong", 13, "text"); win.bisRow.t:SetPoint("LEFT", win.bisRow.icon, "RIGHT", 8, 0)
  win.bisRow.sw = CreateFrame("Frame", nil, win.bisRow, "BackdropTemplate")
  win.bisRow.sw:SetSize(36, 20); win.bisRow.sw:SetPoint("RIGHT", -10, 0)
  win.bisRow.knob = win.bisRow.sw:CreateTexture(nil, "OVERLAY"); win.bisRow.knob:SetSize(14, 14)
  T.Icon(win.bisRow.knob, "dot")
  win.bisRow:SetScript("OnClick", function() L.ToggleSlotDone(slotKey()); refresh() end)

  local ll = T.Text(left, "label", 12, "muted"); ll:SetPoint("TOPLEFT", 0, -222); ll:SetText("ON YOUR WISHLIST")
  for j = 1, 6 do
    local row = CreateFrame("Button", nil, left)
    row:SetSize(LEFT_W, 30); row:SetPoint("TOPLEFT", 0, -242 - (j - 1) * 34)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(26, 26); row.icon:SetPoint("LEFT")
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.star = T.IconTex(row, "star", 11, "diamond"); row.star:SetPoint("CENTER", row.icon, "TOPRIGHT", -1, -1)
    row.name = T.Text(row, "body", 12, "text"); row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 0); row.name:SetPoint("RIGHT", -26, 0)
    row.lv = T.Text(row, "body", 11, "muted"); row.lv:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 0); row.lv:SetPoint("RIGHT", -26, 0)
    row.x = CreateFrame("Button", nil, row); row.x:SetSize(18, 18); row.x:SetPoint("RIGHT", -2, 0)
    row.x.icon = T.IconTex(row.x, "close", 10, "muted"); row.x.icon:SetPoint("CENTER")
    row.x:SetScript("OnClick", function() L.Remove(row.slot, row.index); refresh() end)
    row:SetScript("OnEnter", function(s) if ns.WishIconEnter then s.entry = s.entry; ns.WishIconEnter(s) end end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnClick", function(s, btn)
      if btn == "RightButton" and ns.WishMenu then ns.WishMenu(s, s.slot, s.index)
      elseif IsAltKeyDown() and s.entry then L.ToggleBiS(s.entry.id); refresh() end
    end)
    wishIcons[j] = row
  end
  win.wishEmpty = T.Text(left, "body", 12, "muted"); win.wishEmpty:SetPoint("TOPLEFT", 0, -244)
  win.wishEmpty:SetWidth(LEFT_W); win.wishEmpty:SetWordWrap(true)
  win.wishEmpty:SetText("Nothing yet. Add items from the list on the right.")

  local divider = win:CreateTexture(nil, "ARTWORK"); divider:SetColorTexture(T.RGB("edge", 0.25)); divider:SetWidth(1)
  divider:SetPoint("TOPLEFT", 16 + LEFT_W + 14, -104); divider:SetPoint("BOTTOMLEFT", 16 + LEFT_W + 14, 56)

  -- right: controls + cards
  local rx = 16 + LEFT_W + 30
  -- one control per row, labels in a column, so nothing overlaps whatever the font width
  local CX = rx + 84
  local function rowLabel(text, y)
    local l = T.Text(win, "label", 12, "muted"); l:SetPoint("TOPLEFT", rx, y - 6); l:SetText(text); return l
  end
  rowLabel("TRACK", -104)
  local tracks = {}
  for _, t in ipairs(L.TRACKS) do tracks[#tracks + 1] = { t.key, t.name } end
  win.track = T.Segmented(win, tracks, function() return view().track end, function(k) view().track = k; refresh() end, 26)
  win.track:SetPoint("TOPLEFT", CX, -104)
  rowLabel("UPGRADED", -136)
  local rk = {}
  for r = 1, 6 do rk[r] = { r, r .. "/6" } end
  win.rank = T.Segmented(win, rk, function() return view().rank end, function(k) view().rank = k; refresh() end, 26)
  win.rank:SetPoint("TOPLEFT", CX, -136)
  rowLabel("GET IT VIA", -168)
  win.via = T.Segmented(win, { { "any", "Any" }, { "drop", "Drop" }, { "bonus", "Bonus roll" }, { "vault", "Vault" } },
    function() return view().via or "any" end, function(k) view().via = k; refresh() end, 26)
  win.via:SetPoint("TOPLEFT", CX, -168)
  rowLabel("SORT", -200)
  win.sortSeg = T.Segmented(win, { { "power", "By power" }, { "stats", "By stats" }, { "prio", "By priority" }, { "source", "By source" }, { "qe", "By QE" } },
    function() return state.sort end, function(k) state.sort = k; state.offset = 0; ns.Guide_Refresh() end, 26)
  win.sortSeg:SetPoint("TOPLEFT", CX, -200)
  win.trackInfo = T.Text(win, "body", 12, "soft", "RIGHT")

  local list = CreateFrame("Frame", nil, win)
  list:SetPoint("TOPLEFT", rx, -240); list:SetPoint("TOPRIGHT", -16, -240)
  list:SetHeight(CARDS * (CARD_H + CARD_GAP))
  list:EnableMouseWheel(true)
  list:SetScript("OnMouseWheel", function(_, d)
    state.offset = math.max(0, math.min(#shown - CARDS, state.offset - d))
    ns.Guide_Refresh(true)
  end)
  for i = 1, CARDS do cards[i] = makeCard(list, i) end
  win.empty = T.Text(list, "body", 13, "muted", "CENTER"); win.empty:SetPoint("TOP", 0, -40); win.empty:SetWidth(500)
  win.empty:SetWordWrap(true)
  win.more = T.Text(win, "body", 12, "muted"); win.more:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -4)
  win.trackInfo:SetPoint("TOPRIGHT", list, "BOTTOMRIGHT", 0, -4)

  -- footer: step through the slots
  local rule = win:CreateTexture(nil, "ARTWORK"); rule:SetColorTexture(T.RGB("edge", 0.25)); rule:SetHeight(1)
  rule:SetPoint("BOTTOMLEFT", 16, 52); rule:SetPoint("BOTTOMRIGHT", -16, 52)
  win.prev = T.Button(win, "Previous slot", 140, 30, function() state.slot = math.max(1, state.slot - 1); state.offset = 0; ns.Guide_Refresh() end)
  win.prev:SetPoint("BOTTOMLEFT", 16, 12)
  win.next = T.Button(win, "Next slot", 140, 30, function()
    if state.slot < #ORDER then state.slot = state.slot + 1; state.offset = 0; ns.Guide_Refresh() else win:Hide() end
  end, "primary")
  win.next:SetPoint("BOTTOMRIGHT", -16, 12)
  local hint = T.Text(win, "body", 12, "muted", "CENTER"); hint:SetPoint("BOTTOM", 0, 22)
  hint:SetText("Add puts it on your wishlist on the track above · right-click a card to choose how to get it · star = BiS")

  win:SetScript("OnShow", function() if not L.items then L.Refresh(true) end; ns.Guide_Refresh() end)
  win:Hide()
end

---------------------------------------------------------------- refresh
function ns.Guide_Refresh(scrollOnly)
  if not win or not win:IsShown() then return end
  local key = slotKey()
  local slot = L.slotByKey[key]
  local v = view()
  if not scrollOnly then collect() end

  win.sub:SetText(L.items and "pick what you want for each slot" or "reading the Adventure Guide…")
  for i, b in ipairs(chips) do
    local k = ORDER[i]
    local on = i == state.slot
    b.bg:SetColorTexture(T.RGB(on and "raised" or "card", on and 1 or 0.6))
    b.under:SetShown(on)
    b.t:SetTextColor(T.RGB(on and "text" or "soft"))
    local ok = k ~= "emb" and L.SlotState(k)
    local n = #(L.Wish()[k] or {})
    T.Icon(b.icon, ok and "tickcircle" or "star")
    if T.hasCore then b.icon:SetVertexColor(T.RGB(ok and "emerald" or (n > 0 and "diamond" or "muted"))) end
    b.icon:SetAlpha((ok or n > 0) and 1 or 0.35)
    b.n:SetText(ok and "" or (n > 0 and n or ""))
  end

  win.slotName:SetText(slot.label:upper())
  win.step:SetText("SLOT " .. state.slot .. " OF " .. #ORDER)

  local eq = L.Equipped(key)
  for j, row in ipairs(win.wear) do
    local e = eq[j]
    row:SetShown(e ~= nil)
    if e then
      row.link = e.link
      row.icon:SetTexture(e.icon or 136525)
      row.name:SetText(e.link or "Empty")
      local tr, rk = L.TrackOf(e.ilvl)
      row.lv:SetText(e.ilvl and (e.ilvl .. (tr and ("  ·  " .. L.TrackLabel(tr, rk)) or "")) or "")
      local c = tr and L.TRACK_COLOR[tr]
      if c then row.lv:SetTextColor(c[1], c[2], c[3]) else row.lv:SetTextColor(T.RGB("soft")) end
    end
  end
  win.bisRow:SetShown(key ~= "emb")
  if key ~= "emb" then
    local ok, auto, have, need, planned, manual = L.SlotState(key)
    local prof = L.Profile() == "mythic" and "Mythic" or "Heroic"
    win.bisRow.t:SetText(ok and ("Slot is " .. prof .. " BiS") or ("Not " .. prof .. " BiS yet"))
    T.Icon(win.bisRow.icon, ok and "tickcircle" or "star")
    if T.hasCore then win.bisRow.icon:SetVertexColor(T.RGB(ok and "emerald" or "muted")) end
    local sw = win.bisRow.sw
    T.Panel(sw, ok and "amethyst" or "raised", 1, ok and 0 or 0.6)
    sw.SetBackdropBorderColor(sw, T.RGB(ok and "amethyst" or "edge", ok and 1 or 0.6))
    win.bisRow.knob:ClearAllPoints()
    win.bisRow.knob:SetPoint(ok and "RIGHT" or "LEFT", ok and -3 or 3, 0)
    win.bisRow.knob:SetVertexColor(T.RGB(ok and "void" or "muted"))
  end

  local list = L.Wish()[key] or {}
  for j, row in ipairs(wishIcons) do
    local e = list[j]
    row.entry, row.index, row.slot = e, j, key
    row:SetShown(e ~= nil)
    if e then
      row.icon:SetTexture(e.icon or C_Item.GetItemIconByID(e.id))
      row.star:SetShown(L.IsBiS(e.id))
      row.name:SetText((L.Prio(e.id) and ("|cffb66eff" .. L.Prio(e.id) .. "|r  ") or "") .. (e.name or ("item " .. e.id)))
      local lv, label = L.EntryTarget(e)
      row.lv:SetText((lv and (lv .. "  ·  ") or "") .. (label or ""))
    end
  end
  win.wishEmpty:SetShown(#list == 0)

  if v.track and L.TRACK[v.track] then
    win.trackInfo:SetText(L.TrackLabel(v.track, v.rank) .. "  =  item level " .. L.TRACK[v.track].ilvl[v.rank])
  end
  if win.track.Sync then win.track:Sync() end
  if win.rank.Sync then win.rank:Sync() end
  if win.sortSeg.Sync then win.sortSeg:Sync() end
  if win.statCtx.Sync then win.statCtx:Sync() end
  if win.profile.Sync then win.profile:Sync() end
  if win.via.Sync then win.via:Sync() end

  for i, c in ipairs(cards) do fillCard(c, shown[state.offset + i], state.offset + i == 1 and state.sort ~= "source" and (state.sort ~= "stats" or L.HasStatPrio()) and L.IlvlAt(shown[1], v.track, v.rank, v.via) ~= nil) end
  if not L.items then win.empty:SetText(L.pending and "Close the Adventure Guide and leave combat so SmilerKeys can read the loot tables." or "Reading loot tables…")
  else win.empty:SetText("No " .. slot.label:lower() .. " found for your spec this season.") end
  win.empty:SetShown(#shown == 0)
  local rest = #shown - (state.offset + CARDS)
  win.more:SetText(rest > 0 and ("Scroll for " .. rest .. " more") or "")
  win.next:SetLabel(state.slot < #ORDER and "Next slot" or "Done")
  win.prev:SetEnabled(state.slot > 1)
end

-- open the guide, optionally on a slot key
function ns.GuideOpen(key)
  if not win then build() end
  if key then for i, k in ipairs(ORDER) do if k == key then state.slot = i end end end
  state.offset = 0
  win:Show()
  win:Raise()
  ns.Guide_Refresh()
end
