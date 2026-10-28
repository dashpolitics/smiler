-- SmilerKeys: loot browser + wishlist window (Crystal Ball theme)
local _, ns = ...
local L = ns.Loot

local FONT       = "Fonts\\ARIALN.TTF"
local ROW_FONT   = "Fonts\\FRIZQT__.TTF"
local TITLE_FONT = "Fonts\\FRIZQT__.TTF"
local BACKDROP   = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }

local C = {
  bg     = { 0.050, 0.038, 0.090, 0.97 },
  panel  = { 0.095, 0.070, 0.160, 1 },
  sel    = { 0.240, 0.170, 0.420, 1 },
  s0     = { 0.075, 0.055, 0.125, 0.70 },
  s1     = { 0.115, 0.085, 0.190, 0.70 },
  border = { 0.56, 0.40, 0.96, 0.90 },
  edge   = { 0.32, 0.23, 0.55, 1 },
  accent = { 0.80, 0.69, 1.00 },
  text   = { 0.92, 0.90, 1.00 },
  dim    = { 0.56, 0.51, 0.70 },
  faint  = { 0.33, 0.30, 0.44 },
  crystal = { 1.00, 0.97, 1.00 },
  gold   = { 1.00, 0.78, 0.45 },
  up     = { 0.45, 0.95, 0.55 },
}

-- with Smiler installed: exact Crystal Ball palette and the Barlow fonts
local BUMP = {}
if Smiler and Smiler.C then
  local SC = Smiler.C
  local function a(c, al) return { c[1], c[2], c[3], al or 1 } end
  FONT, ROW_FONT, TITLE_FONT = Smiler.FONTS.body, Smiler.FONTS.display, Smiler.FONTS.label
  BUMP[FONT], BUMP[ROW_FONT], BUMP[TITLE_FONT] = 1, 2, 2
  C.bg, C.panel, C.sel = a(SC.void, 0.97), a(SC.raised), a(SC.amethyst)
  C.s0, C.s1 = a(SC.card, 0.55), a(SC.card, 0.95)
  C.border, C.edge, C.frame = a(SC.amethyst, 0.9), a(SC.edge, 0.6), a(SC.edge, 0.38)
  C.accent, C.text, C.dim = a(SC.amethyst), a(SC.text), a(SC.muted)
  C.faint, C.crystal = { 0.45, 0.40, 0.58, 1 }, a(SC.diamond)
  C.gold, C.up = a(SC.topaz), a(SC.emerald)
  C.selText = a(SC.void)
end
C.frame = C.frame or C.border
C.selText = C.selText or C.crystal

-- The wishlist itself now lives beside the character sheet (Paperdoll.lua); this window is the loot list.
local SIDE = false
local LIST_W = 872
local W = LIST_W + 28
local ROW_H, VIS = 22, 19
local H = 108 + 24 + ROW_H * VIS + 40
local SIDE_X = 640
-- list columns (x, width)
local COL = {
  mark = { 4, 10 }, icon = { 18, 20 }, name = { 44, 290 }, slot = { 340, 90 },
  -- every column is { x, width } and they no longer touch: GAIN used to be derived from ILVL's
  -- width and landed on top of both its neighbours, in the header and in every row
  source = { 436, 288 }, ilvl = { 730, 46 }, gain = { 780, 34 }, bonus = { 820, 50 },
}

local frame, listRows, slotRows, farmRows = nil, {}, {}, {}
local dragIcon
local view = {
  source = "all", raidDiff = 15, key = 12, inst = nil, slot = nil,
  search = "", wishOnly = false, bonusOnly = false, upOnly = false, sort = "power", desc = true, mode = "drop",
  track = "hero", rank = 1, via = "any",
  offset = 0,
}
local shown = {}

---------------------------------------------------------------- widgets
local function fs(parent, size, color, justify, font, flags)
  local f = parent:CreateFontString(nil, "OVERLAY")
  font = font or FONT
  if not f:SetFont(font, size + (BUMP[font] or 0), flags or "") then f:SetFont("Fonts\\ARIALN.TTF", size, flags or "") end
  f:SetTextColor(unpack(color or C.text))
  f:SetJustifyH(justify or "LEFT")
  f:SetWordWrap(false)
  f:SetShadowOffset(1, -1)
  f:SetShadowColor(0, 0, 0, 0.85)
  return f
end

local function Button(parent, label, w, onClick, h)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w, h or 20)
  b:SetBackdrop(BACKDROP)
  b:SetBackdropColor(unpack(C.panel))
  b:SetBackdropBorderColor(unpack(C.edge))
  b.text = fs(b, 12, C.text, "CENTER")
  b.text:SetPoint("CENTER")
  b.text:SetText(label)
  b:SetScript("OnEnter", function(s) s:SetBackdropBorderColor(unpack(C.border)) end)
  b:SetScript("OnLeave", function(s) s:SetBackdropBorderColor(unpack(s.sel and C.border or C.edge)) end)
  b:SetScript("OnClick", onClick)
  return b
end

local function SetSel(b, on)
  b.sel = on
  b:SetBackdropColor(unpack(on and C.sel or C.panel))
  b:SetBackdropBorderColor(unpack(on and C.border or C.edge))
  b.text:SetTextColor(unpack(on and C.selText or C.dim))
end

-- A row of buttons. Anchoring every control to the one before it, rather than to a fixed x, is the
-- only way the bar cannot overlap itself when a label (a spec name, an instance name) runs long.
local function Segment(parent, opts, x, y, get, set, bw, after)
  local btns, prev = {}, nil
  for i, o in ipairs(opts) do
    local b = Button(parent, o[2], bw or 50, function() set(o[1]); ns.LootUI_Refresh() end)
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 2, 0)
    elseif after then b:SetPoint("LEFT", after, "RIGHT", x or 8, 0)
    else b:SetPoint("TOPLEFT", x, y) end
    b.value = o[1]
    btns[i], prev = b, b
  end
  return function() for _, b in ipairs(btns) do SetSel(b, b.value == get()) end end, prev
end

-- a small caps label that sits to the right of whatever came before it
local function GroupLabel(parent, text, after, gap)
  local l = fs(parent, 11, C.dim)
  l:SetPoint("LEFT", after, "RIGHT", gap or 14, 0)
  l:SetText(text)
  return l
end

local function Tip(f, title, ...)
  local lines = { ... }
  f:HookScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(title, unpack(C.accent))
    for _, l in ipairs(lines) do GameTooltip:AddLine(l, 1, 1, 1, true) end
    GameTooltip:Show()
  end)
  f:HookScript("OnLeave", GameTooltip_Hide)
end

local function Star(parent, size)
  local t = parent:CreateTexture(nil, "OVERLAY", nil, 7)
  t:SetSize(size, size)
  local ok = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("PetJournal-FavoritesIcon")
  if ok then t:SetAtlas("PetJournal-FavoritesIcon") else t:SetTexture("Interface\\COMMON\\FavoritesIcon") end
  return t
end

-- gold outline used for BiS
local function GoldOutline(parent, inset)
  local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  f:SetPoint("TOPLEFT", -inset, inset); f:SetPoint("BOTTOMRIGHT", inset, -inset)
  f:SetBackdrop(BACKDROP)
  f:SetBackdropColor(C.gold[1], C.gold[2], C.gold[3], 0.06)
  f:SetBackdropBorderColor(C.gold[1], C.gold[2], C.gold[3], 0.95)
  f:SetFrameLevel(parent:GetFrameLevel() + 3)
  f:EnableMouse(false)
  f:Hide()
  return f
end

---------------------------------------------------------------- filtering + sorting
local function sourceKey(it) return (it.raid and "1" or "2") .. it.inst .. string.format("%03d", it.encIndex or 0) end

local function rebuild()
  wipe(shown)
  local items = L.items or {}
  local q = view.search:lower()
  for _, it in ipairs(items) do
    local ok = not it.hidden
    if view.source == "raid" and not it.raid then ok = false end
    if view.source == "mplus" and (it.raid or it.crafted or it.delve) then ok = false end
    if view.source == "crafted" and not it.crafted then ok = false end
    if view.source == "delve" and not it.delve then ok = false end
    if ok and view.bisOnly and not L.IsBiS(it.id) then ok = false end
    if ok and view.inst and it.instID ~= view.inst then ok = false end
    if ok and view.slot and it.slot ~= view.slot then ok = false end
    if ok and view.bonusOnly and not it.bonus then ok = false end
    if ok and view.wishOnly and not L.IsWished(it.id) then ok = false end
    if ok and view.upOnly then
      local lv = L.IlvlAt(it, view.track, view.rank, view.via)
      local g = lv and it.slot ~= "other" and L.Gain(it, lv)
      if not (g and g > 0) then ok = false end
    end
    if ok and q ~= "" then
      local hay = ((it.name or "") .. " " .. L.SourceText(it) .. " " .. (it.slotText or "")):lower()
      if not hay:find(q, 1, true) then ok = false end
    end
    if ok then shown[#shown + 1] = it end
  end
  local s, d = view.sort, view.desc
  local function val(it)
    if s == "name" then return (it.name or ""):lower() end
    if s == "slot" then return string.format("%02d", L.slotOrder[it.slot] or 99) .. sourceKey(it) end
    if s == "source" then return sourceKey(it) end
    if s == "ilvl" then return L.IlvlAt(it, view.track, view.rank, view.via) or 0 end
    if s == "power" then return (L.IlvlAt(it, view.track, view.rank, view.via) or 0) * 1000 + (L.MaxIlvl(it) or 0) end
    if s == "gain" then
      local lv = L.IlvlAt(it, view.track, view.rank, view.via)
      return (lv and it.slot ~= "other" and L.Gain(it, lv)) or -999
    end
    if s == "stats" then return (L.StatValue(it, view.track, view.rank, view.via)) * 1000 + (L.MaxIlvl(it) or 0) end
    if s == "bonus" then return it.bonus and 0 or 1 end
    if s == "prio" then return 100 - (L.Prio(it.id) or 99) end
    if s == "wish" then return L.IsWished(it.id) and 0 or 1 end
    return 0
  end
  table.sort(shown, function(a, b)
    local va, vb = val(a), val(b)
    if va ~= vb then if d then return va > vb else return va < vb end end
    return (a.name or "") < (b.name or "")
  end)
  view.offset = math.max(0, math.min(view.offset, #shown - VIS))
end

-- what adding an item means at the chosen track and rank
local function targetFor(it)
  local r = L.RouteOn(it, view.track, view.via) or L.RouteOn(it, view.track) or L.Routes(it)[1]
  if r then return L.TargetFromRoute(r, view.rank) end
  return { mode = "drop" }
end
ns.LootTargetFor = targetFor
local function linkFor(it)
  local r = L.RouteOn(it, view.track, view.via)
  return L.LinkFor(it, r and r.diff or 15, r and r.mode or "drop")
end

---------------------------------------------------------------- drag + drop
local function slotRowUnderMouse()
  for _, r in ipairs(slotRows) do if r:IsMouseOver() then return r end end
end

local function startDrag(it)
  view.dragging = it
  dragIcon.tex:SetTexture(it.icon)
  dragIcon:Show()
  for _, r in ipairs(slotRows) do
    r.target:SetShown(r.slot.key == it.slot or (it.slot == "other"))
  end
  if ns.Paperdoll_ShowTargets then ns.Paperdoll_ShowTargets(it) end
end

local function stopDrag()
  local it = view.dragging
  view.dragging = nil
  dragIcon:Hide()
  for _, r in ipairs(slotRows) do r.target:Hide() end
  if ns.Paperdoll_ShowTargets then ns.Paperdoll_ShowTargets(nil) end
  if not it then return end
  local r = slotRowUnderMouse() or (ns.Paperdoll_BoxUnderMouse and ns.Paperdoll_BoxUnderMouse())
  if r and L.Add(it, r.slot.key, targetFor(it)) then
    if SOUNDKIT and SOUNDKIT.IG_ABILITY_ICON_DROP then PlaySound(SOUNDKIT.IG_ABILITY_ICON_DROP) end
  end
  ns.LootUI_Refresh()
end

local function addToWish(it)
  local slot = view.target
  if slot and it.slot ~= slot and it.slot ~= "other" then slot = nil end
  if L.Add(it, slot, targetFor(it)) then
    if SOUNDKIT and SOUNDKIT.IG_ABILITY_ICON_DROP then PlaySound(SOUNDKIT.IG_ABILITY_ICON_DROP) end
    ns.LootUI_Refresh()
  end
end

---------------------------------------------------------------- list rows
local function RowEnter(self)
  local it = self.item
  if not it then return end
  local link = linkFor(it)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  if it.labyrinth and link then
    GameTooltip:SetHyperlink(link)
    GameTooltip:AddLine("Venerated Loa Armament: 3 Mythical Soul Fragments from Labyrinth quests", 1, 1, 1, true)
  elseif it.labyrinth then
    GameTooltip:SetItemByID(L.SEASON.labyrinth.item)
    GameTooltip:AddLine("Pick a " .. L.SEASON.labyrinth.track .. " (" .. L.SEASON.labyrinth.ilvl .. ") " ..
      L.slotByKey[it.slot].label:lower() .. " piece. 3 Mythical Soul Fragments from Labyrinth quests make one armament.", 1, 1, 1, true)
    GameTooltip:AddLine("Open the Labyrinth vendor's shop once and the real pieces (with stats) replace this.", 0.7, 0.7, 0.7, true)
  elseif link then GameTooltip:SetHyperlink(link) else GameTooltip:SetItemByID(it.id) end
  if L.IsBiS(it.id) then GameTooltip:AddLine("Best in slot", unpack(C.gold)) end
  if L.Prio(it.id) then GameTooltip:AddLine("Priority " .. L.Prio(it.id) .. " of " .. L.PRIO_MAX .. (L.IsAutoPrio(it.id) and " (from QE)" or " (yours)"), unpack(C.accent)) end
  do local q = L.QEScores and L.QEScores(); local pct = q and q.scores and q.scores[it.id]
    if pct then GameTooltip:AddLine(string.format("QuestionablyEpic: %+.2f%%", pct), unpack(C.up)) end end
  do
    local _, fit, slink = L.StatValue(it, view.track, view.rank, view.via)
    local st = L.StatText(slink)
    if st then
      GameTooltip:AddLine(" ")
      local ctx = L.StatContext() == "raid" and "raid" or "Mythic+"
      GameTooltip:AddDoubleLine("Stats: " .. st, fit and string.format("%d%% fit for %s", math.floor(fit * 100 + 0.5), ctx) or "rank your stats to rate",
        C.accent[1], C.accent[2], C.accent[3], 0.85, 0.85, 0.85)
    end
  end
  GameTooltip:AddLine(" ")
  if it.offspec then GameTooltip:AddLine("Off-spec: the Adventure Guide lists this for another spec of your class", 0.8, 0.8, 0.8, true) end
  GameTooltip:AddLine("Drops from " .. L.SourceText(it), unpack(C.accent))
  if it.tier then
    GameTooltip:AddLine("Tier piece (" .. (it.setName or "set") .. ") from the " .. it.token .. " token", unpack(C.gold))
    local cu = L.SEASON.tier and L.SEASON.tier.curio
    if cu then GameTooltip:AddLine("Also from the " .. cu.name .. " (" .. cu.boss .. ", any tier slot)", 0.8, 0.8, 0.8) end
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Ways to get it", unpack(C.accent))
  for _, r in ipairs(L.Routes(it)) do
    local right = r.fixed and tostring(r.ilvl) or (L.TrackLabel(r.track, r.rank) .. "  " .. r.ilvl .. " → " .. r.max)
    local on = r.track == view.track
    GameTooltip:AddDoubleLine((on and "> " or "   ") .. r.label, right, 1, 1, 1, on and 1 or 0.75, on and 0.82 or 0.75, on and 0.45 or 0.75)
  end
  if it.crafted and not it.reagent and L.SEASON.crafted then
    GameTooltip:AddLine("Crafted at up to item level " .. L.SEASON.crafted.max .. " – " .. L.SEASON.crafted.text, 1, 1, 1, true)
  end
  if it.emb then
    GameTooltip:AddLine(it.reagent and "Embellishment" or "Embellished item", unpack(C.gold))
    if it.note then GameTooltip:AddLine(it.note, 1, 1, 1, true) end
    if it.fits then GameTooltip:AddLine("Goes on: " .. it.fits, 0.8, 0.8, 0.8, true) end
    GameTooltip:AddLine("You can wear 2 embellishments.", unpack(C.dim))
  end

  GameTooltip:AddLine("Click or drag to add · Right-click: choose how (e.g. Heroic bonus roll) · Ctrl-click: preview · Alt-click: BiS", unpack(C.dim))
  GameTooltip:Show()
end

-- pick exactly how you'll get it (e.g. Heroic bonus roll) and add it
function ns.RouteMenu(owner, it, slotKey)
  if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
  MenuUtil.CreateContextMenu(owner, function(_, root)
    root:CreateTitle(it.name or "Item")
    root:CreateTitle("Add it as")
    for _, r in ipairs(L.Routes(it)) do
      local text = r.label .. "  ·  " .. (r.fixed and tostring(r.ilvl) or (L.TrackLabel(r.track, r.rank) .. "  " .. r.ilvl ..
        (r.max ~= r.ilvl and (" → " .. r.max) or "")))
      root:CreateButton(text, function()
        if L.Add(it, slotKey or it.slot, L.TargetFromRoute(r, view.rank)) and SOUNDKIT and SOUNDKIT.IG_ABILITY_ICON_DROP then
          PlaySound(SOUNDKIT.IG_ABILITY_ICON_DROP)
        end
        ns.LootUI_Refresh()
      end)
    end
    root:CreateDivider()
    L.PrioMenu(root, it.id, function() ns.LootUI_Refresh() end)
  end)
end

local function RowClick(self, btn)
  local it = self.item
  if not it then return end
  if btn == "RightButton" then ns.RouteMenu(self, it, view.target); return end
  local link = linkFor(it)
  if IsAltKeyDown() then
    L.ToggleBiS(it.id); ns.LootUI_Refresh(); return
  end
  if IsControlKeyDown() and link then
    DressUpItemLink(link)
  elseif IsShiftKeyDown() then
    local eb = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
    if eb and link then ChatEdit_InsertLink(link) else addToWish(it) end
  elseif btn == "LeftButton" then
    addToWish(it)
  end
end

local function CreateListRow(parent, i)
  local r = CreateFrame("Button", nil, parent)
  r:SetSize(LIST_W, ROW_H)
  r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
  r:RegisterForDrag("LeftButton")
  r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints()
  r.hover = r:CreateTexture(nil, "HIGHLIGHT"); r.hover:SetAllPoints(); r.hover:SetColorTexture(1, 1, 1, 0.05)
  r.mark = r:CreateTexture(nil, "ARTWORK")       -- gold bar = on your wishlist
  r.mark:SetPoint("LEFT", COL.mark[1], 0); r.mark:SetSize(3, ROW_H - 6)
  r.mark:SetColorTexture(unpack(C.gold))
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetPoint("LEFT", COL.icon[1], 0); r.icon:SetSize(18, 18)
  r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.name = fs(r, 12, C.text, "LEFT", ROW_FONT, "OUTLINE")
  r.name:SetPoint("LEFT", COL.name[1], 0); r.name:SetWidth(COL.name[2])
  r.slot = fs(r, 12, C.dim)
  r.slot:SetPoint("LEFT", COL.slot[1], 0); r.slot:SetWidth(COL.slot[2])
  r.source = fs(r, 12, C.dim)
  r.source:SetPoint("LEFT", COL.source[1], 0); r.source:SetWidth(COL.source[2])
  r.ilvl = fs(r, 12, C.text, "RIGHT", ROW_FONT, "OUTLINE")
  r.ilvl:SetPoint("LEFT", COL.ilvl[1], 0); r.ilvl:SetWidth(COL.ilvl[2])
  r.gain = fs(r, 10, C.up, "LEFT")
  r.gain:SetPoint("LEFT", COL.gain[1], 0); r.gain:SetWidth(COL.gain[2])
  r.bonus = fs(r, 11, C.gold, "CENTER", TITLE_FONT)
  r.bonus:SetPoint("LEFT", COL.bonus[1], 0); r.bonus:SetWidth(COL.bonus[2])
  r.bis = GoldOutline(r, 0)
  r.star = Star(r, 14)
  r.star:SetPoint("CENTER", r.icon, "TOPLEFT", 2, -2)
  r:SetScript("OnEnter", RowEnter)
  r:SetScript("OnLeave", GameTooltip_Hide)
  r:SetScript("OnClick", RowClick)
  r:SetScript("OnDragStart", function(s) if s.item then GameTooltip:Hide(); startDrag(s.item) end end)
  r:SetScript("OnDragStop", stopDrag)
  return r
end

---------------------------------------------------------------- wishlist slot rows
local function WishIconEnter(self)
  local e = self.entry
  if not e then return end
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  local link = L.EntryLink(e)
  if e.labyrinth and not link then GameTooltip:SetItemByID(L.SEASON.labyrinth.item)
  elseif link then GameTooltip:SetHyperlink(link) else GameTooltip:SetItemByID(e.id) end
  if L.IsBiS(e.id) then GameTooltip:AddLine("Best in slot", unpack(C.gold)) end
  if L.Prio(e.id) then GameTooltip:AddLine("Priority " .. L.Prio(e.id) .. " of " .. L.PRIO_MAX .. (L.IsAutoPrio(e.id) and " (from QE)" or " (yours)"), unpack(C.accent)) end
  GameTooltip:AddLine(" ")
  local lv, label = L.EntryTarget(e)
  GameTooltip:AddDoubleLine("Target: " .. label, lv and ("item level " .. lv) or "", 1, 0.78, 0.45, 1, 1, 1)
  GameTooltip:AddLine((e.crafted and "Crafted · " or "From ") .. (e.raid and ((e.encName or "?") .. " · ") or "") .. (e.inst or "?"), unpack(C.accent))
  if e.bonus then GameTooltip:AddLine("Bonus-rollable", unpack(C.gold)) end
  if e.qe then GameTooltip:AddLine(string.format("QuestionablyEpic: %+.2f%%", e.qe), unpack(C.up)) end
  if e.reagent then
    local host, hs = L.EmbHost(e)
    if host then GameTooltip:AddLine("Goes on: " .. L.slotByKey[hs].label .. " – " .. (host.name or "crafted piece"), unpack(C.up))
    else GameTooltip:AddLine("Not on a crafted piece yet – right-click to choose", unpack(C.gold)) end
    if e.only then GameTooltip:AddLine(({ bsweapon = "Blacksmithing weapons only", enggun = "Engineering guns only",
      enggear = "Engineering gear only", engfeet = "Engineering feet only" })[e.only] or "", unpack(C.dim)) end
  elseif e.emb then
    GameTooltip:AddLine("Embellished already (counts as 1 of your 2)", unpack(C.gold))
  elseif e.crafted then
    local par = self.GetParent and self:GetParent()
    local sk = self.slotKey or (type(self.slot) == "string" and self.slot) or (par and type(par.slot) == "table" and par.slot.key) or ""
    local on = L.EmbsOn(e, sk)
    if #on > 0 then GameTooltip:AddLine("Embellished with: " .. (on[1].r.name or "?"), unpack(C.up))
    else GameTooltip:AddLine("No embellishment planned – right-click to add one", unpack(C.dim)) end
  end
  if L.EmbCount() > 0 and (e.emb or e.reagent) then
    GameTooltip:AddLine(string.format("Embellishments planned: %d/2", L.EmbCount()), unpack(C.dim))
  end
  if e.tier then GameTooltip:AddLine("Tier piece – from the " .. (e.token or "tier") .. " token", unpack(C.gold)) end
  GameTooltip:AddLine("Right-click: how to get it and upgrade rank · Alt-click: BiS · Shift-right-click: remove", unpack(C.dim))
  GameTooltip:Show()
end

local KEYS = { 2, 4, 5, 6, 7, 8, 10, 12, 14, 16, 18, 20 }

local function WishMenu(owner, slotKey, index)
  local e = (L.Wish()[slotKey] or {})[index]
  if not e then return end
  local function set(field, v) return function() e[field] = v; ns.LootUI_Refresh(); return MenuResponse and MenuResponse.Refresh end end
  if not (MenuUtil and MenuUtil.CreateContextMenu) then
    L.Remove(slotKey, index); ns.LootUI_Refresh(); return
  end
  MenuUtil.CreateContextMenu(owner, function(_, root)
    root:CreateTitle(e.name or "Item")
    local it = L.byKey and L.byKey[e.id .. ":" .. (e.enc or 0)]
    if not it then for _, x in ipairs(L.items or {}) do if x.id == e.id then it = x; break end end end
    local routes = it and L.Routes(it) or {}
    if #routes > 0 then
      root:CreateTitle("Get it from")
      for _, r in ipairs(routes) do
        local text = r.label .. "  ·  " .. (r.fixed and tostring(r.ilvl) or L.TrackLabel(r.track, r.rank))
        root:CreateRadio(text, function() return (e.route == r.label) end, function()
          local t = L.TargetFromRoute(r, e.rank)
          for k, v in pairs(t) do e[k] = v end
          e.diff, e.key = r.diff, r.key
          ns.LootUI_Refresh()
          return MenuResponse and MenuResponse.Refresh
        end)
      end
      if e.track and not e.fixed then
        root:CreateDivider()
        local up = root:CreateButton("Upgraded to: " .. (e.rank or 1) .. "/6")
        local start = 1
        for _, r in ipairs(routes) do if r.label == e.route and r.rank then start = r.rank end end
        for rank = start, 6 do
          up:CreateRadio(L.TrackLabel(e.track, rank) .. "  ·  " .. L.TRACK[e.track].ilvl[rank],
            function() return (e.rank or 1) == rank end, set("rank", rank))
        end
      end
      root:CreateDivider()
    end
    if e.reagent then
      local hosts = L.EmbHosts(e)
      local sub = root:CreateButton("Put it on" .. (L.EmbHost(e) and (": " .. L.slotByKey[select(2, L.EmbHost(e))].label) or "…"))
      if #hosts == 0 then sub:CreateTitle("Add a crafted piece it fits to your wishlist first") end
      for _, h in ipairs(hosts) do
        sub:CreateRadio(L.slotByKey[h.slot].label .. " – " .. (h.e.name or "?") .. (h.taken and "  (swap)" or ""),
          function() return h.mine end, function() L.SetEmbHost(e, h.slot, h.e.id); ns.LootUI_Refresh() end)
      end
      sub:CreateRadio("Not decided yet", function() return not L.EmbHost(e) end, function() L.SetEmbHost(e, nil); ns.LootUI_Refresh() end)
      root:CreateButton("Plan another one of these", function()
        local it
        for _, x in ipairs(L.items or {}) do if x.id == e.id and x.reagent then it = x; break end end
        if it then L.Add(it, "emb", {}) end
        ns.LootUI_Refresh()
      end)
      root:CreateDivider()
    elseif e.crafted and not e.emb then
      local on = L.EmbsOn(e, slotKey)
      local sub = root:CreateButton("Embellish with" .. (on[1] and (": " .. (on[1].r.name or "?")) or "…"))
      for _, it in ipairs(L.items or {}) do
        if it.reagent and L.EmbFits(it, e, slotKey) then
          sub:CreateRadio(it.name or ("item " .. it.id), function() return on[1] and on[1].r.id == it.id end, function()
            -- reuse a matching embellishment that isn't on anything yet, else plan a new one
            local use
            for _, r in ipairs(L.Wish().emb or {}) do if r.id == it.id and not L.EmbHost(r) then use = r; break end end
            if not use then L.Add(it, "emb", { on = { slot = slotKey, id = e.id } }); use = L.Wish().emb[#L.Wish().emb] end
            for _, x in ipairs(on) do if x.r ~= use then x.r.on = nil end end
            L.SetEmbHost(use, slotKey, e.id)
            ns.LootUI_Refresh()
          end)
        end
      end
      if on[1] then
        sub:CreateButton("No embellishment", function()
          for _, x in ipairs(on) do x.r.on = nil end
          ns.LootUI_Refresh()
        end)
      end
      root:CreateDivider()
    elseif e.emb then
      root:CreateTitle("Embellished already – can't take another")
    end
    root:CreateCheckbox("Best in slot", function() return L.IsBiS(e.id) end,
      function() L.ToggleBiS(e.id); ns.LootUI_Refresh() end)
    L.PrioMenu(root, e.id, function() ns.LootUI_Refresh() end)
    root:CreateButton("Remove from wishlist", function() L.Remove(slotKey, index); ns.LootUI_Refresh() end)
  end)
end

local function CreateSlotRow(parent, i, slot)
  local r = CreateFrame("Button", nil, parent)
  r:SetSize(W - SIDE_X - 14, 22)
  r:SetPoint("TOPLEFT", 0, -(i - 1) * 22)
  r.slot = slot
  r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints()
  r.bg:SetColorTexture(unpack(i % 2 == 0 and C.s1 or C.s0))
  r.target = CreateFrame("Frame", nil, r, "BackdropTemplate")   -- outline while a matching item is dragged
  r.target:SetAllPoints()
  r.target:SetBackdrop(BACKDROP)
  r.target:SetBackdropColor(C.gold[1], C.gold[2], C.gold[3], 0.10)
  r.target:SetBackdropBorderColor(C.gold[1], C.gold[2], C.gold[3], 0.8)
  r.target:Hide()
  r.label = fs(r, 12, C.text)
  r.label:SetPoint("LEFT", 8, 0); r.label:SetWidth(70)
  r.label:SetText(slot.label)
  r.eq = {}
  for j = 1, 2 do
    local b = CreateFrame("Button", nil, r)
    b:SetSize(20, 20)
    b:SetPoint("LEFT", 80 + (j - 1) * 40, 0)
    b.tex = b:CreateTexture(nil, "ARTWORK"); b.tex:SetAllPoints(); b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.lv = fs(b, 10, C.dim); b.lv:SetPoint("LEFT", b, "RIGHT", 2, 0)
    b:SetScript("OnEnter", function(s)
      if not s.link then return end
      GameTooltip:SetOwner(s, "ANCHOR_LEFT"); GameTooltip:SetHyperlink(s.link); GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    r.eq[j] = b
  end
  r.divider = r:CreateTexture(nil, "ARTWORK")
  r.divider:SetColorTexture(unpack(C.edge))
  r.divider:SetSize(1, 16)
  r.divider:SetPoint("LEFT", 162, 0)
  r.wish = {}
  for j = 1, 6 do
    local b = CreateFrame("Button", nil, r)
    b:SetSize(20, 20)
    b:SetPoint("LEFT", 170 + (j - 1) * 23, 0)
    b:RegisterForClicks("RightButtonUp", "LeftButtonUp")
    b.tex = b:CreateTexture(nil, "ARTWORK"); b.tex:SetAllPoints(); b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.ring = b:CreateTexture(nil, "OVERLAY")
    b.ring:SetPoint("BOTTOMLEFT", -1, -1); b.ring:SetPoint("BOTTOMRIGHT", 1, -1); b.ring:SetHeight(2)
    b.ring:SetColorTexture(unpack(C.gold))
    b.lv = fs(b, 9, C.crystal, "CENTER", ROW_FONT, "OUTLINE")
    b.lv:SetPoint("BOTTOM", 0, 1)
    b.bis = GoldOutline(b, 1)
    b.star = Star(b, 11)
    b.star:SetPoint("CENTER", b, "TOPRIGHT", -1, -1)
    b:SetScript("OnEnter", WishIconEnter)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:SetScript("OnClick", function(s, btn)
      if btn == "RightButton" then
        GameTooltip:Hide()
        if IsShiftKeyDown() then L.Remove(slot.key, s.index); ns.LootUI_Refresh()
        else WishMenu(s, slot.key, s.index) end
      elseif IsAltKeyDown() and s.entry then
        L.ToggleBiS(s.entry.id); ns.LootUI_Refresh()
      elseif IsControlKeyDown() and s.entry and s.entry.id > 0 then
        local link = L.EntryLink(s.entry) or select(2, C_Item.GetItemInfo(s.entry.id)); if link then DressUpItemLink(link) end
      end
    end)
    r.wish[j] = b
  end
  r.more = fs(r, 11, C.dim); r.more:SetPoint("LEFT", 170 + 6 * 23, 0)
  r.hint = fs(r, 11, C.faint); r.hint:SetPoint("LEFT", 172, 0); r.hint:SetText("drop items here")
  r.doneBar = r:CreateTexture(nil, "ARTWORK")       -- gold bar = BiS achieved in this slot
  r.doneBar:SetPoint("TOPLEFT"); r.doneBar:SetPoint("BOTTOMLEFT"); r.doneBar:SetWidth(3)
  r.doneBar:SetColorTexture(unpack(C.gold))
  r.done = CreateFrame("Button", nil, r)
  r.done:SetSize(18, 18)
  r.done:SetPoint("RIGHT", -4, 0)
  r.done.star = Star(r.done, 16); r.done.star:SetPoint("CENTER")
  r.done.txt = fs(r.done, 9, C.gold, "RIGHT", TITLE_FONT); r.done.txt:SetPoint("RIGHT", r.done, "LEFT", -1, 0)
  r.done:SetScript("OnClick", function() L.ToggleSlotDone(slot.key); ns.LootUI_Refresh() end)
  r.done:SetScript("OnEnter", function(s)
    local ok, auto, have, need, planned, manual = L.SlotState(slot.key)
    GameTooltip:SetOwner(s, "ANCHOR_LEFT")
    GameTooltip:AddLine(slot.label .. (ok and ": BiS achieved" or ": BiS not achieved"), unpack(ok and C.gold or C.accent))
    if #slot.inv > 0 then
      GameTooltip:AddLine(string.format("Wearing %d of %d BiS item%s here", have, need, need > 1 and "s" or ""), 1, 1, 1)
    end
    if manual then GameTooltip:AddLine("Ticked by you", 0.8, 0.8, 0.8) end
    if not planned and not ok then GameTooltip:AddLine("No BiS item marked for this slot yet – alt-click one.", 0.8, 0.8, 0.8, true) end
    GameTooltip:AddLine("Click to " .. (manual and "clear your tick" or "mark this slot done yourself") .. ". Done slots leave the plans below.", unpack(C.dim))
    GameTooltip:Show()
  end)
  r.done:SetScript("OnLeave", GameTooltip_Hide)
  r:SetScript("OnClick", function()
    view.slot = (view.slot ~= slot.key) and slot.key or nil
    view.offset = 0
    ns.LootUI_Refresh()
  end)
  r:SetScript("OnEnter", function(s)
    s.label:SetTextColor(unpack(C.crystal))
    GameTooltip:SetOwner(s, "ANCHOR_LEFT")
    GameTooltip:AddLine(slot.label, unpack(C.accent))
    GameTooltip:AddLine("Click to show only " .. slot.label:lower() .. " in the list", 1, 1, 1)
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function(s)
    s.label:SetTextColor(unpack(view.slot == slot.key and C.crystal or C.text))
    GameTooltip:Hide()
  end)
  return r
end

---------------------------------------------------------------- window
local refreshers = {}
local headerBtns = {}

local function CreateWindow()
  frame = CreateFrame("Frame", "SmilerKeysLoot", UIParent, "BackdropTemplate")
  frame:SetSize(W, H)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")   -- above ChonkyCharacterSheet and the wishlist bar
  frame:SetToplevel(true)
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetBackdrop(BACKDROP)
  frame:SetBackdropColor(unpack(C.bg))
  frame:SetBackdropBorderColor(unpack(C.frame))
  tinsert(UISpecialFrames, "SmilerKeysLoot")

  local line = frame:CreateTexture(nil, "ARTWORK")
  line:SetPoint("TOPLEFT", 1, -1); line:SetPoint("TOPRIGHT", -1, -1); line:SetHeight(2)
  line:SetColorTexture(1, 1, 1, 1)
  local g1, g2 = { 0.40, 0.24, 0.84 }, { 0.92, 0.85, 1 }
  if Smiler and Smiler.C then g1, g2 = Smiler.C.amethyst, Smiler.C.diamond end
  line:SetGradient("HORIZONTAL", CreateColor(g1[1], g1[2], g1[3], 1), CreateColor(g2[1], g2[2], g2[3], 1))

  local title = fs(frame, 13, C.accent, "LEFT", TITLE_FONT)
  title:SetPoint("TOPLEFT", 14, -13)
  title:SetText("L O O T")
  frame.target = fs(frame, 13, C.gold, "LEFT", TITLE_FONT)
  frame.sub = fs(frame, 11, C.dim)
  frame.sub:SetPoint("LEFT", title, "RIGHT", 14, 0)
  frame.target:SetPoint("LEFT", frame.sub, "RIGHT", 14, 0)

  local close = Button(frame, "×", 22, function() frame:Hide() end)
  close:SetPoint("TOPRIGHT", -8, -8)
  local rescan = Button(frame, "Rescan", 64, function() L.Refresh(true) end)
  rescan:SetPoint("RIGHT", close, "LEFT", -4, 0)
  local statsBtn = Button(frame, "Stats: Raid", 100, nil)
  statsBtn:SetPoint("RIGHT", rescan, "LEFT", -4, 0)
  statsBtn:SetScript("OnClick", function(self)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
      L.SetStatContext(L.StatContext() == "raid" and "mplus" or "raid"); ns.LootUI_Refresh(); return
    end
    MenuUtil.CreateContextMenu(self, function(_, root)
      root:CreateTitle("Rate loot for")
      for _, c in ipairs(L.STAT_CONTEXTS) do
        root:CreateRadio(c[2], function() return L.StatContext() == c[1] end,
          function() L.SetStatContext(c[1]); ns.LootUI_Refresh() end)
      end
      root:CreateDivider()
      root:CreateTitle("Your ranking (ties allowed)")
      for _, st in ipairs(L.STATS) do
        local cur = L.HasStatPrio() and L.StatRankOf(L.StatContext(), st.key) or nil
        local sub = root:CreateButton(st.name .. ":  " .. (cur and ({ "1st", "2nd", "3rd", "4th" })[cur] or "not set"))
        for rank = 1, 4 do
          sub:CreateRadio(({ "1st", "2nd", "3rd", "4th" })[rank], function() return cur == rank end,
            function() L.SetStatRankOf(L.StatContext(), st.key, rank); ns.LootUI_Refresh()
              if Smiler and Smiler.RefreshSettings then Smiler.RefreshSettings() end end)
        end
      end
      root:CreateButton("Sort by stats", function() view.sort = "stats"; view.desc = true; view.offset = 0; ns.LootUI_Refresh() end)
      if Smiler and Smiler.OpenSettings then root:CreateButton("Open stat settings…", function() Smiler:OpenSettings("Loot") end) end
    end)
  end)
  Tip(statsBtn, "Secondary stat priority", "Rank Crit, Haste, Mastery and Versatility 1-4, separately for raid and Mythic+. Sort by Stats to put the most valuable items first.")
  refreshers[#refreshers + 1] = function()
    local ctx = L.StatContext()
    local txt = L.StatPrioText(ctx, true)
    statsBtn.text:SetText((ctx == "raid" and "Raid" or "M+") .. (txt and (": " .. txt) or ": set stats"))
    SetSel(statsBtn, view.sort == "stats")
  end
  Tip(rescan, "Rescan", "Reads the loot tables again from the game's Adventure Guide.")

  -- filter bar 1
  local y1 = -40
  local srcSync, srcLast = Segment(frame, { { "all", "All" }, { "raid", "Raid" }, { "mplus", "M+" }, { "crafted", "Craft" }, { "delve", "Delve" } }, 14, y1,
    function() return view.source end, function(v) view.source = v; view.inst = nil; view.offset = 0 end, 40)
  refreshers[#refreshers + 1] = srcSync

  -- TRACK, RANK and VIA were fourteen widgets answering one question: what item level would I end
  -- up with? They are one button now, labelled with the answer ("Hero 1/6 · bonus roll").
  local levelBtn = Button(frame, "Hero 1/6", 170, nil)
  levelBtn:SetPoint("LEFT", srcLast, "RIGHT", 14, 0)
  local VIA_NAME = { any = "best way", drop = "drop", bonus = "bonus roll", vault = "Great Vault" }
  levelBtn:SetScript("OnClick", function(self)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
      local keys = {}
      for _, t in ipairs(L.TRACKS) do keys[#keys + 1] = t.key end
      local at = 1
      for i, k in ipairs(keys) do if k == view.track then at = i end end
      view.track = keys[at % #keys + 1]
      ns.LootUI_Refresh()
      return
    end
    MenuUtil.CreateContextMenu(self, function(_, root)
      root:CreateTitle("Item levels shown for")
      for _, t in ipairs(L.TRACKS) do
        local lv = t.ilvl and t.ilvl[math.min(6, view.rank or 1)]
        root:CreateRadio((t.name or t.short) .. (lv and ("   " .. lv) or ""), function() return view.track == t.key end,
          function() view.track = t.key; ns.LootUI_Refresh() end)
      end
      root:CreateDivider()
      root:CreateTitle("Upgrade rank  ·  1/6 is how it drops")
      local tr = L.TRACK[view.track]
      for r = 1, 6 do
        local lv = tr and tr.ilvl and tr.ilvl[r]
        root:CreateRadio(r .. "/6" .. (lv and ("   " .. lv) or "") .. (r == 1 and "   as it drops" or (r == 6 and "   fully upgraded" or "")),
          function() return view.rank == r end,
          function() view.rank = r; ns.LootUI_Refresh() end)
      end
      root:CreateDivider()
      root:CreateTitle("Counting which way of getting it")
      for _, v in ipairs({ "any", "drop", "bonus", "vault" }) do
        root:CreateRadio(VIA_NAME[v], function() return view.via == v end,
          function() view.via = v; ns.LootUI_Refresh() end)
      end
    end)
  end)
  refreshers[#refreshers + 1] = function()
    local short = view.track
    for _, t in ipairs(L.TRACKS) do if t.key == view.track then short = t.short end end
    levelBtn.text:SetText(("%s %d/6%s"):format(short, view.rank, view.via ~= "any" and ("  ·  " .. VIA_NAME[view.via]) or ""))
  end
  Tip(levelBtn, "Item levels shown for",
    "Every item level in the list is what that item would be on this upgrade track at this rank, got this way.",
    "1/6 is how it drops; each rank above costs crests. Adding an item to your wishlist remembers this choice.")

  local inst = Button(frame, "All instances", 130, nil)
  inst:SetPoint("LEFT", levelBtn, "RIGHT", 16, 0)
  inst:SetScript("OnClick", function(self)
    local opts = { { nil, "All instances" } }
    for _, s in ipairs(L.sources or {}) do
      local kind = s.crafted and "crafted" or (s.delve and "delve" or (s.raid and "raid" or "mplus"))
      if view.source == "all" or view.source == kind then
        opts[#opts + 1] = { s.id, (s.crafted and "Crafted: " or (s.delve and "Delve: " or (s.raid and "Raid: " or "M+: "))) .. s.name }
      end
    end
    if MenuUtil and MenuUtil.CreateContextMenu then
      MenuUtil.CreateContextMenu(self, function(_, root)
        for _, o in ipairs(opts) do
          root:CreateRadio(o[2], function() return view.inst == o[1] end,
            function() view.inst = o[1]; view.offset = 0; ns.LootUI_Refresh() end)
        end
      end)
    else
      local idx = 1
      for k, o in ipairs(opts) do if o[1] == view.inst then idx = k end end
      view.inst = opts[idx % #opts + 1][1]
      ns.LootUI_Refresh()
    end
  end)
  refreshers[#refreshers + 1] = function()
    local label = "All instances"
    for _, s in ipairs(L.sources or {}) do if s.id == view.inst then label = s.name end end
    inst.text:SetText(label)
    SetSel(inst, view.inst ~= nil)
  end

  local spec = Button(frame, "Spec", 118, function()
    -- cycle: each spec of your class, then every class
    local ids = {}
    for i = 1, GetNumSpecializations() do ids[#ids + 1] = (GetSpecializationInfo(i)) end
    local cur = L.allClasses and "all" or L.SpecID()
    local nextVal = ids[1]
    for i, id in ipairs(ids) do if id == cur then nextVal = ids[i + 1] or "all" end end
    if cur == "all" then nextVal = ids[1] end
    if nextVal == "all" then L.allClasses, L.specID = true, nil else L.allClasses, L.specID = false, nextVal end
    L.Refresh(true)
  end)
  spec:SetPoint("LEFT", inst, "RIGHT", 6, 0)
  Tip(spec, "Loot for", "Click to switch spec, or show every class's loot.")
  refreshers[#refreshers + 1] = function()
    if L.allClasses then spec.text:SetText("All classes") return end
    local _, name = GetSpecializationInfoByID(L.SpecID())
    spec.text:SetText(name and (name .. " loot") or "Your loot")
  end

  -- filter bar 2
  local y2 = -66
  local search = CreateFrame("EditBox", nil, frame, "BackdropTemplate")
  search:SetSize(160, 20)
  search:SetPoint("TOPLEFT", 14, y2)
  search:SetBackdrop(BACKDROP)
  search:SetBackdropColor(unpack(C.panel))
  search:SetBackdropBorderColor(unpack(C.edge))
  search:SetFont(FONT, 12, "")
  search:SetTextColor(unpack(C.text))
  search:SetTextInsets(6, 6, 0, 0)
  search:SetAutoFocus(false)
  search:SetScript("OnEscapePressed", function(s) s:SetText(""); s:ClearFocus() end)
  search:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
  search:SetScript("OnTextChanged", function(s) view.search = s:GetText() or ""; view.offset = 0; ns.LootUI_Refresh() end)
  local ph = fs(search, 12, C.faint); ph:SetPoint("LEFT", 6, 0); ph:SetText("Search items, bosses, dungeons")
  search:SetScript("OnEditFocusGained", function(s) ph:Hide(); s:SetBackdropBorderColor(unpack(C.border)) end)
  search:SetScript("OnEditFocusLost", function(s) ph:SetShown(s:GetText() == ""); s:SetBackdropBorderColor(unpack(C.edge)) end)

  local wishBtn = Button(frame, "Wishlist", 66, function() view.wishOnly = not view.wishOnly; view.offset = 0; ns.LootUI_Refresh() end)
  wishBtn:SetPoint("LEFT", search, "RIGHT", 8, 0)
  local bisBtn = Button(frame, "BiS", 40, function() view.bisOnly = not view.bisOnly; view.offset = 0; ns.LootUI_Refresh() end)
  bisBtn:SetPoint("LEFT", wishBtn, "RIGHT", 4, 0)
  -- the question most often being asked of this window is "what is actually better than what I am
  -- wearing", and until now the only way to answer it was to read every row's +N by eye
  local upBtn = Button(frame, "Upgrades", 72, function() view.upOnly = not view.upOnly; view.offset = 0; ns.LootUI_Refresh() end)
  upBtn:SetPoint("LEFT", bisBtn, "RIGHT", 4, 0)
  Tip(upBtn, "Upgrades only", "Hide anything that is not a higher item level than what you are wearing in that slot, at the track and rank chosen above.")
  local slotChip = Button(frame, "", 110, function() view.slot = nil; ns.LootUI_Refresh() end)
  slotChip:SetPoint("LEFT", upBtn, "RIGHT", 10, 0)
  local gl = GroupLabel(frame, "SORT", slotChip, 10)
  local sortSync = Segment(frame, { { "power", "Power" }, { "stats", "Stats" }, { "source", "Source" }, { "slot", "Slot" } }, 6, y2,
    function() return view.sort end, function(v)
      view.sort = v; view.desc = (v == "power" or v == "stats")
      if v == "stats" and not L.HasStatPrio() then
        print("|cff9d7bffSmilerKeys|r: rank your secondary stats first (Smiler settings > Loot, or the Stats button).")
      end
    end, 52, gl)
  refreshers[#refreshers + 1] = sortSync
  Tip(gl, "Sort", "Power: highest item level on the chosen track first. Stats: most valuable for your secondary stat ranking (item level x stat fit). Source: by raid boss or dungeon. Slot: like your character sheet.")

  refreshers[#refreshers + 1] = function()
    SetSel(wishBtn, view.wishOnly)
    SetSel(bisBtn, view.bisOnly)
    SetSel(upBtn, view.upOnly)
    slotChip:SetShown(view.slot ~= nil)
    if view.slot then slotChip.text:SetText(L.slotByKey[view.slot].label .. "  ×"); SetSel(slotChip, true) end
  end

  -- one line of plain English under the controls, because "Hero 1/6 via bonus" means nothing to
  -- someone opening this window for the first time
  frame.legend = fs(frame, 11, C.dim)
  frame.legend:SetPoint("TOPLEFT", 14, -90)
  frame.legend:SetWidth(LIST_W - 20)
  refreshers[#refreshers + 1] = function()
    local tr = L.TRACK[view.track]
    local lv = tr and tr.ilvl and tr.ilvl[math.min(6, view.rank or 1)]
    local via = ({ any = "however it drops best", drop = "from a kill", bonus = "from a bonus roll", vault = "from the Great Vault" })[view.via] or ""
    frame.legend:SetText(("ILVL is what each item would be at %s %d/6%s%s  ·  GAIN is next to it: how much better than what you wear"):format(
      (tr and (tr.name or tr.short)) or view.track, view.rank, lv and (" (" .. lv .. ")") or "", via ~= "" and (", " .. via) or ""))
  end

  -- list header
  local list = CreateFrame("Frame", nil, frame)
  list:SetPoint("TOPLEFT", 14, -108)
  list:SetSize(LIST_W, ROW_H * VIS + 24)
  local hb = list:CreateTexture(nil, "BACKGROUND")
  hb:SetPoint("TOPLEFT"); hb:SetPoint("TOPRIGHT"); hb:SetHeight(22)
  hb:SetColorTexture(unpack(C.panel))
  local cols = {
    { "wish", "", COL.mark[1], 14 },
    { "name", "ITEM", COL.name[1], COL.name[2] },
    { "slot", "SLOT", COL.slot[1], COL.slot[2] },
    { "source", "DROPS FROM", COL.source[1], COL.source[2] },
    { "ilvl", "ILVL", COL.ilvl[1], COL.ilvl[2] },
    { "gain", "GAIN", COL.gain[1], COL.gain[2] },
    { "bonus", "TAG", COL.bonus[1], COL.bonus[2] },
  }
  for _, c in ipairs(cols) do
    local b = CreateFrame("Button", nil, list)
    b:SetPoint("TOPLEFT", c[3], 0)
    b:SetSize(c[4], 22)
    b.text = fs(b, 10, C.dim, c[1] == "ilvl" and "RIGHT" or (c[1] == "bonus" and "CENTER" or "LEFT"))
    b.text:SetAllPoints()
    b.label = c[2]
    b.key = c[1]
    b:SetScript("OnClick", function()
      if view.sort == c[1] then view.desc = not view.desc else view.sort, view.desc = c[1], c[1] == "ilvl" end
      ns.LootUI_Refresh()
    end)
    headerBtns[#headerBtns + 1] = b
  end
  refreshers[#refreshers + 1] = function()
    for _, b in ipairs(headerBtns) do
      local active = view.sort == b.key
      local arrow = active and (view.desc and " v" or " ^") or ""
      b.text:SetText(b.label .. arrow)
      b.text:SetTextColor(unpack(active and C.crystal or C.dim))
    end
  end

  local body = CreateFrame("Frame", nil, list)
  body:SetPoint("TOPLEFT", 0, -24)
  body:SetSize(LIST_W, ROW_H * VIS)
  body:EnableMouseWheel(true)
  body:SetScript("OnMouseWheel", function(_, d)
    view.offset = math.max(0, math.min(#shown - VIS, view.offset - d * 3))
    ns.LootUI_Refresh(true)
  end)
  for i = 1, VIS do listRows[i] = CreateListRow(body, i) end
  frame.empty = fs(body, 12, C.dim, "CENTER")
  frame.empty:SetPoint("TOP", 0, -40)
  frame.empty:SetWidth(LIST_W - 40)
  frame.empty:SetWordWrap(true)

  -- scroll indicator
  frame.scroll = body:CreateTexture(nil, "OVERLAY")
  frame.scroll:SetColorTexture(unpack(C.edge))
  frame.scroll:SetWidth(3)

  -- the wishlist itself lives beside the character sheet now (Paperdoll.lua); the old side panel
  -- that used to sit here has gone rather than lingering behind an "if false".

  -- two short lines inside the window's width rather than one long one that ran off the edge
  local foot = fs(frame, 11, C.dim)
  foot:SetPoint("BOTTOMLEFT", 14, 12)
  foot:SetWidth(LIST_W - 20); foot:SetWordWrap(true); foot:SetJustifyH("LEFT")
  local gh = string.format("%02x%02x%02x", C.gold[1] * 255, C.gold[2] * 255, C.gold[3] * 255)
  foot:SetText("Click or drag an item onto your wishlist  ·  Ctrl-click to preview  ·  Alt-click for BiS\n|cff" .. gh .. "BR|r bonus-rollable   |cff" .. gh .. "EMB|r embellishment   |cff" .. gh .. "TIER|r tier piece")

  dragIcon = CreateFrame("Frame", nil, UIParent)
  dragIcon:SetSize(30, 30)
  dragIcon:SetFrameStrata("TOOLTIP")
  dragIcon.tex = dragIcon:CreateTexture(nil, "ARTWORK"); dragIcon.tex:SetAllPoints()
  dragIcon:Hide()
  dragIcon:SetScript("OnUpdate", function(s)
    local x, y = GetCursorPosition()
    local sc = UIParent:GetEffectiveScale()
    s:ClearAllPoints()
    s:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / sc + 12, y / sc - 12)
  end)

  frame:SetScript("OnShow", function()
    if not L.items then L.Refresh(true) else ns.LootUI_Refresh() end
  end)
  frame:SetScript("OnHide", function() if view.dragging then stopDrag() end; view.target = nil end)
  frame:Hide()
end

---------------------------------------------------------------- refresh
function ns.LootUI_IsShown() return frame and frame:IsShown() or false end

function ns.LootUI_Refresh(scrollOnly)
  if not scrollOnly and ns.Paperdoll_Refresh then ns.Paperdoll_Refresh() end
  if not scrollOnly and ns.Guide_Refresh then ns.Guide_Refresh() end
  if not frame or not frame:IsShown() then return end
  if not scrollOnly then rebuild() end
  for _, f in ipairs(refreshers) do f() end

  local total = L.items and #L.items or 0
  frame.sub:SetText(L.items and string.format("%d of %d items%s", #shown, total, L.incomplete and "  ·  loading…" or "") or "reading the Adventure Guide…")
  frame.target:SetText(view.target and ("click to add to " .. L.slotByKey[view.target].label:lower()) or "")

  -- list
  if not L.items or #shown == 0 then
    frame.empty:Show()
    if L.pending then
      frame.empty:SetText("Close the Adventure Guide (and leave combat) so SmilerKeys can read the loot tables.")
    elseif not L.items then
      frame.empty:SetText("Reading loot tables…")
    else
      frame.empty:SetText("Nothing matches these filters.")
    end
  else
    frame.empty:Hide()
  end
  for i, r in ipairs(listRows) do
    local it = shown[view.offset + i]
    r.item = it
    r:SetShown(it ~= nil)
    if it then
      r.bg:SetColorTexture(unpack((view.offset + i) % 2 == 0 and C.s1 or C.s0))
      r.icon:SetTexture(it.icon)
      r.name:SetText(it.cname or it.name or ("item " .. it.id))
      r.slot:SetText(L.slotByKey[it.slot].label .. (it.offspec and " ·off" or ""))
      if view.sort == "stats" then
        local _, fit, slink = L.StatValue(it, view.track, view.rank, view.via)
        local st = L.StatText(slink)
        r.slot:SetText(st and st:gsub("Mastery", "Mast"):gsub(" / ", "/") or "no stats")
        r.slot:SetTextColor(unpack(fit and fit >= 0.8 and C.up or (fit and fit < 0.5 and C.faint or C.dim)))
      else
        r.slot:SetTextColor(unpack(C.dim))
      end
      r.source:SetText(L.SourceText(it))
      local lv, route = L.IlvlAt(it, view.track, view.rank, view.via)
      r.ilvl:SetText(lv or "—")
      r:SetAlpha(lv and 1 or 0.45)
      if route and not route.fixed then
        r.source:SetText(L.SourceText(it) .. "  ·  " .. route.label)
      end
      local gain = it.slot ~= "other" and L.Gain(it, lv)
      r.gain:SetText(gain and gain > 0 and ("+" .. gain) or "")
      r.bonus:SetText(it.tier and "TIER" or (it.bonus and "BR" or (it.emb and "EMB" or (it.labyrinth and "LAB" or ""))))
      if L.Prio(it.id) then r.bonus:SetText("P" .. L.Prio(it.id) .. (r.bonus:GetText() ~= "" and (" " .. r.bonus:GetText()) or "")) end
      r.mark:SetShown(L.IsWished(it.id))
      local bis = L.IsBiS(it.id)
      r.bis:SetShown(bis); r.star:SetShown(bis)
    end
  end
  local body = listRows[1]:GetParent()
  if #shown > VIS then
    local h = body:GetHeight()
    local barH = math.max(20, h * VIS / #shown)
    local y = (h - barH) * view.offset / (#shown - VIS)
    frame.scroll:ClearAllPoints()
    frame.scroll:SetPoint("TOPRIGHT", body, "TOPRIGHT", 2, -y)
    frame.scroll:SetHeight(barH)
    frame.scroll:Show()
  else
    frame.scroll:Hide()
  end

end


-- open the loot list, optionally for one slot (opts.slot), instance (opts.inst) or source
function ns.LootBrowse(opts)
  opts = opts or {}
  if not frame then CreateWindow() end
  view.target = opts.slot
  view.slot = opts.slot
  view.inst = opts.inst
  if opts.source then view.source = opts.source elseif opts.slot then view.source = "all" end
  view.wishOnly = opts.wishOnly or false
  view.offset = 0
  frame:Show()
  frame:Raise()
  ns.LootUI_Refresh()
end
ns.LootView = view
ns.WishIconEnter = WishIconEnter
ns.WishMenu = WishMenu
