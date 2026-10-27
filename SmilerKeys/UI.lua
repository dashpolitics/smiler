-- SmilerKeys: grid window, Crystal Ball theme
local _, ns = ...

local FONT       = "Fonts\\ARIALN.TTF"
local FONT_TITLE = "Fonts\\FRIZQT__.TTF"
local ROW_FONT   = "Fonts\\FRIZQT__.TTF"   -- rounder than Arial Narrow; drawn with an outline
local BACKDROP   = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }

-- Crystal Ball: deep indigo glass, amethyst edges, crystal-white highlights.
-- Upgrade tiers step in brightness AND carry +/++/+++ in the text, so nothing relies on hue.
local C = {
  bg      = { 0.050, 0.038, 0.090, 0.96 },
  panel   = { 0.095, 0.070, 0.160, 1 },
  stripe0 = { 0.075, 0.055, 0.125, 0.70 },
  stripe1 = { 0.115, 0.085, 0.190, 0.70 },
  border  = { 0.56, 0.40, 0.96, 0.90 },
  edge    = { 0.32, 0.23, 0.55, 1 },
  accent  = { 0.80, 0.69, 1.00 },
  text    = { 0.92, 0.90, 1.00 },
  dim     = { 0.56, 0.51, 0.70 },
  faint   = { 0.33, 0.30, 0.44 },
  ch3     = { 1.00, 0.97, 1.00 },   -- +++  crystal white
  ch2     = { 0.82, 0.66, 1.00 },   -- ++   amethyst
  ch1     = { 0.63, 0.57, 0.82 },   -- +    lavender
  dep     = { 0.47, 0.43, 0.54 },   -- -N   over time
  hlFill  = { 0.62, 0.45, 1.00, 0.16 },
  -- best timed key, coloured by how well it was timed (Raider.IO green / blue / purple, lifted for the dark panel)
  rio1    = { 0.12, 1.00, 0.00 },   -- in time
  rio2    = { 0.24, 0.61, 1.00 },   -- 20% spare
  rio3    = { 0.69, 0.36, 1.00 },   -- 40% spare
  glow    = { 1.00, 0.78, 0.45 },   -- warm gold
}

-- with Smiler installed: exact Crystal Ball palette and the Barlow fonts
local BUMP = {}
if Smiler and Smiler.C then
  local SC = Smiler.C
  local function a(c, al) return { c[1], c[2], c[3], al or 1 } end
  FONT, FONT_TITLE, ROW_FONT = Smiler.FONTS.body, Smiler.FONTS.label, Smiler.FONTS.display
  BUMP[FONT_TITLE], BUMP[ROW_FONT], BUMP[FONT] = 2, 3, 1
  C.bg, C.panel = a(SC.void, 0.96), a(SC.raised)
  C.stripe0, C.stripe1 = a(SC.card, 0.55), a(SC.card, 0.95)
  C.border, C.edge, C.frame = a(SC.amethyst, 0.9), a(SC.edge, 0.38), a(SC.edge, 0.38)
  C.accent, C.text, C.dim = a(SC.amethyst), a(SC.text), a(SC.muted)
  C.faint, C.ch3 = { 0.45, 0.40, 0.58, 1 }, a(SC.diamond)
  C.hlFill = a(SC.amethyst, 0.14)
  C.glow = a(SC.topaz)
  ns.GRADIENT = { SC.amethyst, SC.diamond }
end
C.frame = C.frame or C.border
local function hex(c) return string.format("%02x%02x%02x", c[1] * 255 + 0.5, c[2] * 255 + 0.5, c[3] * 255 + 0.5) end

local PAD = 10
local W_NAME, W_KEY, W_SCORE, W_RESI, W_CELL = 158, 72, 54, 44, 48
local ROW_H, TITLE_H, HEAD_H, FOOT_H = 22, 36, 48, 30
local MAX_ROWS = 14
local MIN_W = 600

local frame, scroll, child
local headerCells, colHL, rows, glows = {}, {}, {}, {}
ns.upCell, ns.upKey = {}, {}

local function fs(parent, size, color, justify, font, flags)
  local f = parent:CreateFontString(nil, "OVERLAY")
  font = font or FONT
  if not f:SetFont(font, size + (BUMP[font] or 0), flags or "") then f:SetFont("Fonts\\FRIZQT__.TTF", size, flags or "") end
  f:SetTextColor(unpack(color or C.text))
  f:SetJustifyH(justify or "LEFT")
  f:SetWordWrap(false)
  f:SetShadowOffset(1, -1)
  f:SetShadowColor(0, 0, 0, 0.85)
  return f
end

local function FlatButton(parent, label, w, onClick)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w, 18)
  b:SetBackdrop(BACKDROP)
  b:SetBackdropColor(unpack(C.panel))
  b:SetBackdropBorderColor(unpack(C.edge))
  b.text = fs(b, 11, C.text, "CENTER")
  b.text:SetPoint("CENTER", 0, 0)
  b.text:SetText(label)
  b:SetScript("OnEnter", function(s) s:SetBackdropBorderColor(unpack(C.border)) end)
  b:SetScript("OnLeave", function(s) s:SetBackdropBorderColor(unpack(C.edge)) end)
  b:SetScript("OnClick", onClick)
  return b
end

-- Soft warm glow: a gentle gold wash rising from the bottom of the cell, with a faint gold outline
-- (the outline keeps it readable without colour). One shared clock keeps every glow in step.
local function AddGlow(f)
  local g = CreateFrame("Frame", nil, f)
  g:SetPoint("TOPLEFT", 2, 0); g:SetPoint("BOTTOMRIGHT", -2, 0)
  g:SetFrameLevel(f:GetFrameLevel() + 2)
  g:EnableMouse(false)
  local r, gg, b = unpack(C.glow)
  g.fill = g:CreateTexture(nil, "BACKGROUND")
  g.fill:SetAllPoints()
  g.fill:SetColorTexture(1, 1, 1, 1)
  g.fill:SetGradient("VERTICAL", CreateColor(r, gg, b, 0.24), CreateColor(r, gg, b, 0.04))
  local function edge(p1, p2, w, h, alpha)
    local t = g:CreateTexture(nil, "BORDER")
    t:SetColorTexture(r, gg, b, alpha)
    t:SetPoint(p1); t:SetPoint(p2)
    if w then t:SetWidth(w) else t:SetHeight(h) end
  end
  edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1, 0.55)
  edge("TOPLEFT", "TOPRIGHT", nil, 1, 0.20)
  edge("TOPLEFT", "BOTTOMLEFT", 1, nil, 0.30)
  edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil, 0.30)
  g:Hide()
  glows[#glows + 1] = g
  f.glow = g
end

local function colX(i) return W_NAME + W_KEY + W_SCORE + W_RESI + (i - 1) * W_CELL end

local function classColor(class)
  local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if c then return c.r, c.g, c.b end
  return unpack(C.text)
end

local SRC_LABEL = { self = "you", guild = "guild", group = "group scan", friend = "friend",
                    bnet = "Battle.net", relay = "relayed", ["?"] = "unknown" }

---------------------------------------------------------------- cell text
-- Colour by key level: every level its own hue, walking green → cyan → blue → purple → pink → red → gold
-- (the number always shows the level too; how fast it was timed is in the tooltip)
local LEVEL_COLORS = {
  [2]  = { 0.37, 0.95, 0.37 }, [3]  = { 0.37, 0.95, 0.53 }, [4]  = { 0.37, 0.95, 0.68 }, [5]  = { 0.37, 0.95, 0.84 },
  [6]  = { 0.37, 0.91, 0.95 }, [7]  = { 0.48, 0.79, 0.96 }, [8]  = { 0.48, 0.67, 0.96 }, [9]  = { 0.48, 0.54, 0.96 },
  [10] = { 0.55, 0.48, 0.96 }, [11] = { 0.68, 0.48, 0.96 }, [12] = { 0.77, 0.37, 0.95 }, [13] = { 0.92, 0.37, 0.95 },
  [14] = { 0.95, 0.37, 0.82 }, [15] = { 0.95, 0.37, 0.67 }, [16] = { 0.95, 0.37, 0.51 }, [17] = { 0.95, 0.39, 0.37 },
  [18] = { 0.95, 0.54, 0.37 }, [19] = { 0.95, 0.70, 0.37 }, [20] = { 0.95, 0.85, 0.37 },
}
function ns.LevelColor(level)
  level = level or 0
  if level < 2 then return LEVEL_COLORS[2] end
  return LEVEL_COLORS[math.min(20, level)]
end

function ns.CellText(r)
  -- highest timed key only; over-time runs stay in the tooltip
  if r and (r.tl or 0) > 0 then
    return tostring(r.tl), ns.LevelColor(r.tl)
  end
  return "·", C.faint
end

local function fmtTime(sec)
  if not sec or sec <= 0 then return "?" end
  return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

---------------------------------------------------------------- highlight / sort
function ns.ToggleHighlight(mapId)
  ns.highlightMap = (ns.highlightMap ~= mapId) and mapId or nil
  ns.UI_Refresh()
end

-- click a column: highest first → lowest first → back to normal
function ns.ToggleSort(col)
  local sb = ns.sortBy
  if not sb or sb.col ~= col then ns.sortBy = { col = col, desc = true }
  elseif sb.desc then sb.desc = false
  else ns.sortBy = nil end
  ns.sortMap = ns.sortBy and type(ns.sortBy.col) == "number" and ns.sortBy.col or nil
  ns.UI_Refresh()
end

---------------------------------------------------------------- tooltips
local function HeaderEnter(self)
  local m = ns.mapById[self.mapId]
  if not m then return end
  GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
  GameTooltip:AddLine(m.name, unpack(C.accent))
  GameTooltip:AddDoubleLine("Timer", fmtTime(m.timeLimit), 0.8, 0.8, 0.8, 1, 1, 1)
  GameTooltip:AddDoubleLine("++ / +++ under", fmtTime(math.floor(m.timeLimit * 0.8)) .. " / " ..
    fmtTime(math.floor(m.timeLimit * 0.6)), 0.8, 0.8, 0.8, 1, 1, 1)
  GameTooltip:AddLine(" ")
  if m.tp then
    local left = ns.TeleportCooldown(m.tp)
    if left > 0 then
      GameTooltip:AddDoubleLine("Teleport", SecondsToTime and SecondsToTime(left, true) or (math.ceil(left / 60) .. " min"),
        0.8, 0.8, 0.8, 1, 0.5, 0.5)
    else
      GameTooltip:AddLine("Click: teleport", unpack(C.text))
    end
    GameTooltip:AddLine("  " .. (C_Spell.GetSpellName(m.tp) or ("spell " .. m.tp)), unpack(C.dim))
  else
    GameTooltip:AddLine("You don't know this dungeon's teleport", unpack(C.dim))
  end
  GameTooltip:AddLine("Shift-click: highlight column", unpack(C.dim))
  GameTooltip:AddLine("Right-click: sort highest first, again: lowest first, again: normal", unpack(C.dim))
  GameTooltip:Show()
end

local function CellEnter(self)
  local p, m = self.player, ns.mapById[self.mapId]
  if not p or not m then return end
  local r = p.runs and p.runs[m.id]
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(m.name, unpack(C.accent))
  GameTooltip:AddLine(p.key, classColor(p.class))
  if r and (r.tl or 0) > 0 then
    local ch = math.max(1, math.min(3, r.ch or 1))
    local _, col = ns.CellText(r)
    GameTooltip:AddDoubleLine("Best timed", string.rep("+", ch) .. r.tl .. "  " ..
      ({ "in time", "20% to spare", "40% to spare" })[ch], 0.8, 0.8, 0.8, col[1], col[2], col[3])
  end
  if r and (r.ol or 0) > 0 then
    GameTooltip:AddDoubleLine("Best over time", r.ol, 0.8, 0.8, 0.8, 1, 1, 1)
  end
  if r and (r.sc or 0) > 0 then
    GameTooltip:AddDoubleLine("Dungeon score", r.sc, 0.8, 0.8, 0.8, 1, 1, 1)
  end
  local holders = ns.upCell[p.key] and ns.upCell[p.key][m.id]
  if holders then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Upgrade available", unpack(C.text))
    for _, h in ipairs(holders) do
      GameTooltip:AddDoubleLine("  " .. (h.name or h.key) .. "'s key", "+" .. (h.keyLevel or 0),
        classColor(h.class))
    end
  end
  if not r or (r.tl or 0) == 0 then
    GameTooltip:AddLine("No timed run this season", unpack(C.dim))
    if r and (r.ol or 0) > 0 and not p.hasAddon then
      GameTooltip:AddLine("Read from the group: a lower timed run may be hidden", unpack(C.dim))
    end
  end
  GameTooltip:Show()
end

local function RowEnter(self)
  local p = self.player
  if not p then return end
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:AddLine(p.key, classColor(p.class))
  local acct = ns.AcctLabel(p)
  GameTooltip:AddDoubleLine("Account", acct or "not linked", 0.8, 0.8, 0.8, 1, 1, 1)
  GameTooltip:AddDoubleLine("Score", p.score or 0, 0.8, 0.8, 0.8, 1, 1, 1)
  GameTooltip:AddDoubleLine("Source", SRC_LABEL[p.src] or p.src or "?", 0.8, 0.8, 0.8, 1, 1, 1)
  GameTooltip:AddDoubleLine("Updated", ns.Age(p.ts) .. (ns.Age(p.ts) == "now" and "" or " ago"), 0.8, 0.8, 0.8, 1, 1, 1)
  if not p.hasAddon then
    GameTooltip:AddLine("Read from your group – no SmilerKeys, so no key shown", unpack(C.dim))
  end
  GameTooltip:AddLine("Right-click: hide for now, hide for good, or link to an account", unpack(C.dim))
  if p.key ~= ns.selfKey then
    GameTooltip:AddLine("Shift-right-click: hide for good", unpack(C.dim))
  end
  GameTooltip:Show()
end

local function KeyEnter(self)
  local p = self:GetParent().player
  if not p or not p.keyMap or p.keyMap == 0 then return end
  local m = ns.mapById[p.keyMap]
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine((m and m.name or "Keystone") .. " +" .. (p.keyLevel or 0), unpack(C.accent))
  if not ns.KeyFresh(p) then
    GameTooltip:AddLine("Reported before this week's reset – may have changed", unpack(C.dim))
  else
    local ups = ns.upKey[p.key]
    if ups then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine("Upgrade for " .. #ups .. (#ups == 1 and " player" or " players"), unpack(C.text))
      for _, t in ipairs(ups) do
        GameTooltip:AddDoubleLine("  " .. (t.p.name or t.p.key),
          (t.from > 0 and ("+" .. t.from) or "none") .. "  →  +" .. p.keyLevel,
          classColor(t.p.class), 1, 1, 1)
      end
    else
      GameTooltip:AddLine("Not an upgrade for anyone in the grid", unpack(C.dim))
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click: highlight this dungeon", unpack(C.dim))
  end
  GameTooltip:Show()
  ns.focusKey = p.key
  ns.ApplyGlows()
end

local function KeyLeave()
  GameTooltip:Hide()
  ns.focusKey = nil
  ns.ApplyGlows()
end

local function ResiEnter(self)
  local p = self:GetParent().player
  if not p then return end
  local level, lowest = ns.Resi(p)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(p.name or p.key, classColor(p.class))
  local target
  if level then
    GameTooltip:AddLine("Resilient Keystone " .. level, unpack(C.accent))
    GameTooltip:AddLine("Keys won't drop below +" .. level .. ".", 1, 1, 1)
    target = level + 1
  else
    GameTooltip:AddLine("No Resilient Keystone yet", unpack(C.accent))
    target = ns.RESI_MIN
  end
  local missing = ns.ResiMissing(p, target)
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("For Resilient " .. target .. ", time at +" .. target .. ":", unpack(C.text))
  for _, x in ipairs(missing) do
    GameTooltip:AddDoubleLine("  " .. x.m.name, x.best > 0 and ("best " .. x.best) or "not timed",
      0.8, 0.8, 0.8, unpack(C.dim))
  end
  if not p.hasAddon then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Read from the group: their real level may be higher.", unpack(C.dim))
  end
  GameTooltip:Show()
end

---------------------------------------------------------------- window
local function SavePos()
  local p, _, rp, x, y = frame:GetPoint()
  ns.db.settings.point = { p, rp, x, y }
end

local CHANNELS = { { "guild", "Guild" }, { "friends", "Friends" }, { "bnet", "BNet" }, { "party", "Group" } }

local function CreateMain()
  frame = CreateFrame("Frame", "SmilerKeysFrame", UIParent, "BackdropTemplate")
  frame:SetFrameStrata("HIGH")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(s) s:StopMovingOrSizing(); SavePos() end)
  frame:SetBackdrop(BACKDROP)
  frame:SetBackdropColor(unpack(C.bg))
  frame:SetBackdropBorderColor(unpack(C.frame))
  frame:SetSize(MIN_W, 200)
  local pt = ns.db.settings.point
  if pt then frame:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4]) else frame:SetPoint("CENTER") end
  tinsert(UISpecialFrames, "SmilerKeysFrame")
  frame:Hide()

  -- amethyst-to-crystal edge along the top
  local line = frame:CreateTexture(nil, "ARTWORK")
  line:SetPoint("TOPLEFT", 1, -1)
  line:SetPoint("TOPRIGHT", -1, -1)
  line:SetHeight(2)
  line:SetColorTexture(1, 1, 1, 1)
  local g1, g2 = { 0.40, 0.24, 0.84 }, { 0.92, 0.85, 1 }
  if ns.GRADIENT then g1, g2 = ns.GRADIENT[1], ns.GRADIENT[2] end
  line:SetGradient("HORIZONTAL", CreateColor(g1[1], g1[2], g1[3], 1), CreateColor(g2[1], g2[2], g2[3], 1))

  local title = fs(frame, 13, C.accent, "LEFT", FONT_TITLE)
  title:SetPoint("TOPLEFT", PAD + 2, -12)
  title:SetText("S M I L E R K E Y S")
  frame.sub = fs(frame, 11, C.dim)
  frame.sub:SetPoint("LEFT", title, "RIGHT", 12, 0)

  local close = FlatButton(frame, "×", 20, function() frame:Hide() end)
  close:SetPoint("TOPRIGHT", -8, -9)
  local sync = FlatButton(frame, "Sync", 46, function()
    ns.Broadcast(true); ns.ScanParty(); ns.Print("Sync sent.")
  end)
  sync:SetPoint("RIGHT", close, "LEFT", -4, 0)
  local loot = FlatButton(frame, "Loot", 46, function() ns.LootToggle() end)
  loot:SetPoint("RIGHT", sync, "LEFT", -4, 0)

  -- header strip
  local head = CreateFrame("Frame", nil, frame)
  head:SetPoint("TOPLEFT", PAD, -TITLE_H)
  head:SetPoint("TOPRIGHT", -PAD, -TITLE_H)
  head:SetHeight(HEAD_H)
  local hb = head:CreateTexture(nil, "BACKGROUND")
  hb:SetAllPoints()
  hb:SetColorTexture(unpack(C.panel))
  local hl = head:CreateTexture(nil, "ARTWORK")
  hl:SetPoint("BOTTOMLEFT"); hl:SetPoint("BOTTOMRIGHT"); hl:SetHeight(1)
  hl:SetColorTexture(unpack(C.edge))
  frame.head = head

  local function hlabel(text, x, w)
    local f = fs(head, 10, C.dim, "CENTER")
    f:SetPoint("BOTTOMLEFT", x, 7)
    f:SetWidth(w)
    f:SetText(text)
    return f
  end
  hlabel("PLAYER", 8, W_NAME - 8):SetJustifyH("LEFT")
  frame.sortLabels = {}
  local function sortable(text, col, x, w)
    local f = hlabel(text, x, w)
    local b = CreateFrame("Button", nil, head)
    b:SetPoint("BOTTOMLEFT", x, 0); b:SetSize(w, HEAD_H)
    b:SetScript("OnClick", function() ns.ToggleSort(col) end)
    b:SetScript("OnEnter", function(s)
      f:SetTextColor(unpack(C.text))
      GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
      GameTooltip:AddLine("Sort by " .. text:lower(), unpack(C.accent))
      GameTooltip:AddLine("Click: highest first, again: lowest first, again: normal order", 1, 1, 1, true)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide(); if ns.UI_SortLabels then ns.UI_SortLabels() end end)
    frame.sortLabels[col] = { fs = f, text = text, btn = b }
    return f, b
  end
  sortable("KEY", "key", W_NAME, W_KEY)
  sortable("SCORE", "score", W_NAME + W_KEY, W_SCORE)
  local rh, rhb = sortable("RESI", "resi", W_NAME + W_KEY + W_SCORE, W_RESI)
  rhb:SetPoint("BOTTOMLEFT", W_NAME + W_KEY + W_SCORE, 0)
  rhb:SetSize(W_RESI, HEAD_H)
  rhb:SetScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Resilient Keystone", unpack(C.accent))
    GameTooltip:AddLine("Keys can't drop below this level for the rest of the season. Unlocked by timing every season dungeon at +" ..
      ns.RESI_MIN .. " or higher; each level after that needs every dungeon timed at that level.", 1, 1, 1, true)
    GameTooltip:AddLine("Click to sort: highest first, again: lowest first, again: normal order", unpack(C.dim))
    GameTooltip:Show()
  end)

  -- rows
  scroll = CreateFrame("ScrollFrame", nil, frame)
  scroll:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -1)
  scroll:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", 0, -1)
  scroll:SetHeight(ROW_H)
  child = CreateFrame("Frame", nil, scroll)
  child:SetSize(1, 1)
  scroll:SetScrollChild(child)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(s, d)
    local max = math.max(0, child:GetHeight() - s:GetHeight())
    s:SetVerticalScroll(math.min(max, math.max(0, s:GetVerticalScroll() - d * ROW_H * 2)))
  end)

  frame.empty = fs(frame, 12, C.dim, "CENTER")
  frame.empty:SetPoint("TOP", head, "BOTTOM", 0, -4)
  frame.empty:SetText("Waiting for this season's dungeon list…")

  -- footer: sharing toggles

  frame.toggles = {}
  local prev
  for i = #CHANNELS, 1, -1 do
    local key, label = CHANNELS[i][1], CHANNELS[i][2]
    local b = FlatButton(frame, label, 64, function() ns.ToggleChannel(key) end)
    b.key, b.label = key, label
    if prev then b:SetPoint("RIGHT", prev, "LEFT", -4, 0) else b:SetPoint("BOTTOMRIGHT", -PAD, 7) end
    b:HookScript("OnEnter", function(s)
      GameTooltip:SetOwner(s, "ANCHOR_TOP")
      GameTooltip:AddLine("Share your keys and scores with: " .. s.label)
      GameTooltip:Show()
    end)
    b:HookScript("OnLeave", GameTooltip_Hide)
    frame.toggles[key] = b
    prev = b
  end
  local share = fs(frame, 10, C.dim, "RIGHT")
  share:SetPoint("RIGHT", prev, "LEFT", -6, 0)
  share:SetText("SHARE")

  frame:SetScript("OnShow", function() ns.UI_Rebuild() end)

  local t = 0
  frame:SetScript("OnUpdate", function(_, el)
    t = t + el
    local a = ns.focusKey and 0.95 or (0.70 + 0.25 * math.sin(t * 1.6))   -- slow breathe, ~4 s
    for _, g in ipairs(glows) do if g:IsShown() then g:SetAlpha(a) end end
  end)
end

---------------------------------------------------------------- header + column highlights
local function BuildHeader()
  for _, h in ipairs(headerCells) do h:Hide() end
  for _, o in ipairs(colHL) do o:Hide() end

  for i, m in ipairs(ns.maps) do
    local h = headerCells[i]
    if not h then
      -- secure, so a left-click can cast the dungeon teleport
      h = CreateFrame("Button", nil, frame.head, "SecureActionButtonTemplate")
      h:SetSize(W_CELL, HEAD_H)
      h:RegisterForClicks("AnyUp", "AnyDown")
      h:SetAttribute("shift-type1", "")          -- shift-click: highlight only, never cast
      h.icon = h:CreateTexture(nil, "ARTWORK")
      h.icon:SetSize(22, 22)
      h.icon:SetPoint("TOP", 0, -5)
      h.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      h.label = fs(h, 11, C.text, "CENTER")
      h.label:SetPoint("BOTTOM", 0, 6)
      h.label:SetWidth(W_CELL - 2)
      h:SetScript("OnEnter", HeaderEnter)
      h:SetScript("OnLeave", GameTooltip_Hide)
      h:HookScript("OnClick", function(s, btn, down)
        if down then return end
        if btn == "RightButton" then ns.ToggleSort(s.mapId)
        elseif IsShiftKeyDown() or not s.tp then ns.ToggleHighlight(s.mapId) end
      end)
      h.cd = CreateFrame("Cooldown", nil, h, "CooldownFrameTemplate")
      h.cd:SetAllPoints(h.icon)
      h.cd:SetDrawEdge(false)
      h.cd:SetHideCountdownNumbers(true)
      headerCells[i] = h

      -- column overlay: soft fill + crisp side rules (visible without colour)
      local o = CreateFrame("Frame", nil, frame)
      o:SetFrameLevel(frame:GetFrameLevel() + 20)
      o:EnableMouse(false)
      o.fill = o:CreateTexture(nil, "OVERLAY"); o.fill:SetAllPoints(); o.fill:SetColorTexture(unpack(C.hlFill))
      o.l = o:CreateTexture(nil, "OVERLAY"); o.l:SetPoint("TOPLEFT"); o.l:SetPoint("BOTTOMLEFT"); o.l:SetWidth(1)
      o.r = o:CreateTexture(nil, "OVERLAY"); o.r:SetPoint("TOPRIGHT"); o.r:SetPoint("BOTTOMRIGHT"); o.r:SetWidth(1)
      o.l:SetColorTexture(unpack(C.border)); o.r:SetColorTexture(unpack(C.border))
      colHL[i] = o
    end
    h.mapId = m.id
    h.tp = m.tp
    if m.tp then
      h:SetAttribute("type1", "spell")
      h:SetAttribute("spell1", m.tp)
    else
      h:SetAttribute("type1", nil)
      h:SetAttribute("spell1", nil)
    end
    local _, start, dur = ns.TeleportCooldown(m.tp)
    if start then h.cd:SetCooldown(start, dur) else h.cd:Clear() end
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", colX(i), 0)
    h.icon:SetTexture(m.texture)
    h.label:SetText(m.short)
    h:Show()

    local o = colHL[i]
    o.mapId = m.id
    o:ClearAllPoints()
    o:SetPoint("TOPLEFT", frame.head, "TOPLEFT", colX(i), 0)
    o:SetPoint("BOTTOMLEFT", scroll, "BOTTOMLEFT", colX(i), 0)
    o:SetWidth(W_CELL)
  end

  local w = PAD * 2 + colX(#ns.maps + 1)
  frame:SetWidth(math.max(w, MIN_W))
end

---------------------------------------------------------------- rows
local function editBox(popup) return popup.GetEditBox and popup:GetEditBox() or popup.editBox or popup.EditBox end

StaticPopupDialogs.SMILERKEYS_ACCOUNT = {
  text = "Battle.net account for %s\n|cff8f82b3Characters with the same account are grouped. Leave blank to unlink.|r",
  button1 = ACCEPT, button2 = CANCEL, hasEditBox = 1, maxLetters = 40,
  OnShow = function(self, key)
    local eb = editBox(self)
    eb:SetText(ns.db.settings.acct[key] or ns.AcctLabel(ns.db.players[key]) or "")
    eb:HighlightText()
  end,
  OnAccept = function(self, key) ns.Assign(key, editBox(self):GetText()) end,
  EditBoxOnEnterPressed = function(eb)
    local p = eb:GetParent(); ns.Assign(p.data, eb:GetText()); p:Hide()
  end,
  EditBoxOnEscapePressed = function(eb) eb:GetParent():Hide() end,
  timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
}

function ns.UI_SortLabels()
  if not frame or not frame.sortLabels then return end
  local sb = ns.sortBy
  for col, l in pairs(frame.sortLabels) do
    local on = sb and sb.col == col
    l.fs:SetText(l.text .. (on and (sb.desc and " v" or " ^") or ""))
    l.fs:SetTextColor(unpack(on and C.text or C.dim))
  end
end

function ns.ShowAllHidden()
  wipe(ns.tempHidden)
  ns.UI_Refresh()
end

-- right-click a player: hide them for now (until you reload or log out), hide for good, or link to an account
local function RowClick(self, btn)
  local p = self.player
  if btn ~= "RightButton" or not p then return end
  GameTooltip:Hide()
  local isMe = p.key == ns.selfKey
  local function hideNow() if not isMe then ns.tempHidden[p.key] = true; ns.UI_Refresh() end end
  local function hideForGood()
    if isMe then return end
    ns.db.settings.hidden[p.key] = true
    ns.Print("Hid", p.key, "– /sk unhide to bring back.")
    ns.UI_Refresh()
  end
  if IsShiftKeyDown() then hideForGood(); return end
  if not (MenuUtil and MenuUtil.CreateContextMenu) then hideNow(); return end
  MenuUtil.CreateContextMenu(self, function(_, root)
    root:CreateTitle((p.key or "?"):gsub("%-.*$", ""))
    if not isMe then
      root:CreateButton("Hide for now", hideNow)
      root:CreateButton("Hide for good", hideForGood)
    end
    if next(ns.tempHidden) then root:CreateButton("Show everyone hidden for now", ns.ShowAllHidden) end
    root:CreateDivider()
    root:CreateButton("Link to an account (alts)...", function() StaticPopup_Show("SMILERKEYS_ACCOUNT", p.key, nil, p.key) end)
  end)
end

local function CreateRow(i)
  local r = CreateFrame("Button", nil, child)
  r:SetHeight(ROW_H)
  r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
  r:SetPoint("RIGHT", child, "RIGHT")
  r:RegisterForClicks("RightButtonUp")
  r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints()
  r.hover = r:CreateTexture(nil, "HIGHLIGHT"); r.hover:SetAllPoints(); r.hover:SetColorTexture(1, 1, 1, 0.05)
  r.selfBar = r:CreateTexture(nil, "ARTWORK")
  r.selfBar:SetPoint("TOPLEFT"); r.selfBar:SetPoint("BOTTOMLEFT"); r.selfBar:SetWidth(2)
  r.selfBar:SetColorTexture(unpack(C.accent))
  r.sep = r:CreateTexture(nil, "ARTWORK")      -- rule between accounts
  r.sep:SetPoint("TOPLEFT"); r.sep:SetPoint("TOPRIGHT"); r.sep:SetHeight(1)
  r.sep:SetColorTexture(unpack(C.edge))
  r.altMark = r:CreateTexture(nil, "ARTWORK")  -- tree line for alts
  r.altMark:SetPoint("TOPLEFT", 11, 0); r.altMark:SetPoint("BOTTOMLEFT", 11, 0); r.altMark:SetWidth(1)
  r.altMark:SetColorTexture(unpack(C.edge))
  r.header = fs(r, 10, C.accent, "LEFT", FONT_TITLE)     -- section title (FRIENDS / GROUP)
  r.header:SetPoint("BOTTOMLEFT", 8, 4)
  r.headerRule = r:CreateTexture(nil, "ARTWORK")
  r.headerRule:SetHeight(1)
  r.headerRule:SetPoint("LEFT", r.header, "RIGHT", 8, 0)
  r.headerRule:SetPoint("RIGHT", -8, 0)
  r.headerRule:SetColorTexture(unpack(C.edge))

  r.name = fs(r, 12, nil, nil, ROW_FONT, "OUTLINE"); r.name:SetPoint("LEFT", 8, 0); r.name:SetWidth(W_NAME - 50)
  r.age = fs(r, 10, C.dim, "RIGHT"); r.age:SetPoint("RIGHT", r, "LEFT", W_NAME - 6, 0)

  r.key = CreateFrame("Button", nil, r)
  r.key:SetSize(W_KEY, ROW_H)
  r.key:SetPoint("LEFT", W_NAME, 0)
  r.key.text = fs(r.key, 12, C.text, "CENTER", ROW_FONT, "OUTLINE"); r.key.text:SetAllPoints()
  r.key:SetScript("OnEnter", KeyEnter)
  r.key:SetScript("OnLeave", KeyLeave)
  r.key:SetScript("OnClick", function(s)
    local p = s:GetParent().player
    if p and ns.KeyFresh(p) then ns.ToggleHighlight(p.keyMap) end
  end)
  AddGlow(r.key)

  r.score = fs(r, 12, C.text, "CENTER", ROW_FONT, "OUTLINE")
  r.score:SetSize(W_SCORE, ROW_H)
  r.score:SetPoint("LEFT", W_NAME + W_KEY, 0)

  r.resi = CreateFrame("Button", nil, r)
  r.resi:SetSize(W_RESI, ROW_H)
  r.resi:SetPoint("LEFT", W_NAME + W_KEY + W_SCORE, 0)
  r.resi.text = fs(r.resi, 12, C.text, "CENTER", ROW_FONT, "OUTLINE"); r.resi.text:SetAllPoints()
  r.resi:SetScript("OnEnter", ResiEnter)
  r.resi:SetScript("OnLeave", GameTooltip_Hide)

  r.cells = {}
  r:SetScript("OnClick", RowClick)
  r:SetScript("OnEnter", RowEnter)
  r:SetScript("OnLeave", GameTooltip_Hide)
  return r
end

local function GetCell(r, i)
  local c = r.cells[i]
  if not c then
    c = CreateFrame("Button", nil, r)
    c:SetSize(W_CELL, ROW_H)
    c.text = fs(c, 13, C.text, "CENTER", ROW_FONT, "OUTLINE"); c.text:SetAllPoints()
    c:SetScript("OnEnter", CellEnter)
    c:SetScript("OnLeave", GameTooltip_Hide)
    c:SetScript("OnClick", function(s) ns.ToggleHighlight(s.mapId) end)
    AddGlow(c)
    r.cells[i] = c
  end
  c:ClearAllPoints()
  c:SetPoint("LEFT", colX(i), 0)
  return c
end

local function scoreColor(sc)
  if C_ChallengeMode.GetDungeonScoreRarityColor and sc > 0 then
    local col = C_ChallengeMode.GetDungeonScoreRarityColor(sc)
    if col then return col.r, col.g, col.b end
  end
  return unpack(C.dim)
end

---------------------------------------------------------------- refresh
function ns.UI_Refresh()
  if not frame or not frame:IsShown() then return end
  local list, ngroups = ns.SortedPlayers()
  local hasMaps = #ns.maps > 0
  frame.empty:SetShown(not hasMaps)

  -- subtitle
  local sub = ngroups .. (ngroups == 1 and " player" or " players")
  if ngroups ~= #list then sub = sub .. " · " .. #list .. " characters" end
  local hm = ns.highlightMap and ns.mapById[ns.highlightMap]
  if hm then sub = sub .. "  ·  showing " .. hm.name end
  local sb = ns.sortBy
  if sb then
    local m = type(sb.col) == "number" and ns.mapById[sb.col]
    local name = m and m.short or ({ score = "score", resi = "Resilient level", key = "key level" })[sb.col] or "?"
    sub = sub .. "  ·  sorted by " .. name .. (sb.desc and ", highest first" or ", lowest first")
  end
  local nTemp = 0
  for _ in pairs(ns.tempHidden or {}) do nTemp = nTemp + 1 end
  if nTemp > 0 then sub = sub .. "  ·  " .. nTemp .. " hidden for now" end
  frame.sub:SetText(sub)
  if ns.UI_SortLabels then ns.UI_SortLabels() end

  -- sharing toggles: ● on / ○ off
  for key, b in pairs(frame.toggles) do
    local on = ns.db.settings.channels[key]
    b.text:SetText((on and "● " or "○ ") .. b.label)
    b.text:SetTextColor(unpack(on and C.text or C.faint))
  end

  -- column states
  for i, h in ipairs(headerCells) do
    if h:IsShown() then
      local active = h.mapId == ns.highlightMap
      colHL[i]:SetShown(active)
      h.label:SetTextColor(unpack(active and C.ch3 or C.text))
      h.icon:SetDesaturated(ns.highlightMap ~= nil and not active)
      h.icon:SetAlpha((ns.highlightMap ~= nil and not active) and 0.55 or 1)
    end
  end

  local headW = colX(#ns.maps + 1)
  child:SetSize(headW, math.max(1, #list * ROW_H))

  for i, e in ipairs(list) do
    local p = e.p
    local r = rows[i]
    if not r then r = CreateRow(i); rows[i] = r end
    r.player = p
    r:Show()
    local isHeader = e.header ~= nil
    for _, f in ipairs({ r.name, r.age, r.key, r.score, r.resi }) do f:SetShown(not isHeader) end
    r.header:SetShown(isHeader); r.headerRule:SetShown(isHeader)
    if isHeader then
      r.header:SetText(e.header)
      r.bg:SetColorTexture(unpack(C.bg))
      r.selfBar:Hide(); r.sep:Hide(); r.altMark:Hide(); r.key.glow:Hide()
      for _, c in ipairs(r.cells) do c:Hide() end
    else
    r.bg:SetColorTexture(unpack(e.gi % 2 == 0 and C.stripe1 or C.stripe0))  -- one band per account
    r.selfBar:SetShown(p.key == ns.selfKey)
    r.sep:SetShown(e.first and i > 1)
    r.altMark:SetShown(e.alt)

    r.name:ClearAllPoints()
    r.name:SetPoint("LEFT", e.alt and 20 or 8, 0)
    r.name:SetWidth(W_NAME - (e.alt and 62 or 50))
    local nm = p.name or p.key
    if e.hiddenAlts > 0 then nm = nm .. "  |cff8f82b3+" .. e.hiddenAlts .. "|r" end
    r.name:SetText(nm)
    r.name:SetTextColor(classColor(p.class))
    r.age:SetText(p.key == ns.selfKey and "you" or ns.Age(p.ts))

    if p.keyMap and p.keyMap > 0 and not ns.KeyFresh(p) then
      r.key.text:SetText("—")                 -- last week's key
      r.key.text:SetTextColor(unpack(C.faint))
    elseif p.keyMap and p.keyMap > 0 then
      local m = ns.mapById[p.keyMap]
      r.key.text:SetText((m and m.short or "?") .. " " .. (p.keyLevel or 0))
      r.key.text:SetTextColor(unpack(ns.LevelColor(p.keyLevel)))
    elseif not p.hasAddon then
      r.key.text:SetText("?")
      r.key.text:SetTextColor(unpack(C.faint))
    else
      r.key.text:SetText("—")
      r.key.text:SetTextColor(unpack(C.faint))
    end

    local sc = p.score or 0
    r.score:SetText(sc > 0 and sc or "—")
    r.score:SetTextColor(scoreColor(sc))

    local resi = ns.Resi(p)
    r.resi.text:SetText(resi and resi or "—")
    r.resi.text:SetTextColor(unpack(resi and C.accent or C.faint))

    for j, m in ipairs(ns.maps) do
      local c = GetCell(r, j)
      c.mapId, c.player = m.id, p
      local t, col = ns.CellText(p.runs and p.runs[m.id])
      c.text:SetText(t)
      c.text:SetTextColor(unpack(col))
      c:Show()
    end
    for j = #ns.maps + 1, #r.cells do r.cells[j]:Hide() end
    end
  end
  for i = #list + 1, #rows do rows[i]:Hide() end
  ns.upCell, ns.upKey = ns.ComputeUpgrades(list)
  ns.ApplyGlows()

  local vis = math.max(1, math.min(#list, MAX_ROWS))
  scroll:SetHeight(vis * ROW_H)
  frame:SetHeight(TITLE_H + HEAD_H + 1 + vis * ROW_H + FOOT_H + 4)
end

-- Always-on: every upgrade key and target cell. While hovering a key: only that key and its targets.
function ns.ApplyGlows()
  if not frame then return end
  local on, fk = ns.db.settings.glow, ns.focusKey
  local fp = fk and ns.db.players[fk]
  local targets = {}
  if fk and ns.upKey[fk] then for _, t in ipairs(ns.upKey[fk]) do targets[t.p.key] = true end end
  for _, r in ipairs(rows) do
    local p = r.player
    if r:IsShown() and p then
      local hasUp = ns.upKey[p.key] ~= nil
      r.key.glow:SetShown(hasUp and ((fk and fk == p.key) or (not fk and on)) or false)
      for _, c in ipairs(r.cells) do
        local show = false
        if c:IsShown() then
          if fk then
            show = targets[p.key] and fp and c.mapId == fp.keyMap or false
          else
            show = on and ns.upCell[p.key] and ns.upCell[p.key][c.mapId] and true or false
          end
        end
        c.glow:SetShown(show)
      end
    end
  end
end

function ns.UI_IsShown() return frame and frame:IsShown() or false end
function ns.UI_Hide() if frame then frame:Hide() end end

function ns.UI_Rebuild()
  if not frame or not frame:IsShown() or InCombatLockdown() then return end
  BuildHeader()
  ns.UI_Refresh()
end

function ns.UI_Toggle()
  if InCombatLockdown() then
    ns.reopen = not ns.reopen
    ns.Print(ns.reopen and "SmilerKeys will open when combat ends." or "SmilerKeys won't open after combat.")
    return
  end
  if not frame then CreateMain() end
  if frame:IsShown() then
    frame:Hide()
  else
    if #ns.maps == 0 then ns.RefreshMaps() end
    ns.UpdateSelf(true)
    ns.ScanParty()
    frame:Show()
  end
end
