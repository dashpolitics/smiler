-- SmilerKeys: the bonus-roll checklist (/sk rolls).
-- The game only shows what you have left while you are standing in the instance, and there is no
-- API for it, so this keeps its own record: every boss and dungeon with its loot table, and a tick
-- against anything you have already had from a bonus roll there.
--
-- Three things this has to get right, because they are easy to get wrong:
--   · Owning an item does NOT take it out of the pool. A vault piece or a drop you already wear can
--     still come from a bonus roll, so nothing is ever ticked just because you have it.
--   · The record is per loot spec AND per difficulty: Heroic Preservation is its own list.
--   · Rolling the whole table resets it. When every item is ticked the table is offered back empty.
local _, ns = ...
local L = ns.Loot
local T = ns.T
local V = L.Void

local W, H = 880, 700
local LEFT_W, ROW_H, ITEM_H = 280, 22, 24
local TOP = 108

local win, srcRows, itemRows = nil, {}, {}
local sel, offset, itemOffset = nil, 0, 0

---------------------------------------------------------------- the record
local DIFFS = { { 17, "LFR" }, { 14, "Normal" }, { 15, "Heroic" }, { 16, "Mythic" } }

local function specList()
  local out = {}
  if GetNumSpecializations and GetSpecializationInfo then
    for i = 1, (GetNumSpecializations() or 0) do
      local id, name = GetSpecializationInfo(i)
      if id then out[#out + 1] = { id = id, name = name } end
    end
  end
  if #out == 0 then out[1] = { id = 0, name = "This spec" } end
  return out
end

-- the spec and difficulty you are ticking off follow the character, not the account: a paladin
-- should not open on the evoker's loot spec
function L.RollSpec()
  local s = ns.CharSettings()
  if not s.rollSpec then
    local id = V and V.LootSpec and select(1, V.LootSpec())
    s.rollSpec = id or (specList()[1] and specList()[1].id) or 0
  end
  return s.rollSpec
end
function L.SetRollSpec(id) ns.CharSettings().rollSpec = id; if ns.Rolls_Refresh then ns.Rolls_Refresh() end end
function L.RollDiff()
  local s = ns.CharSettings()
  s.rollDiff = s.rollDiff or 15
  return s.rollDiff
end
function L.SetRollDiff(d) ns.CharSettings().rollDiff = d; if ns.Rolls_Refresh then ns.Rolls_Refresh() end end

-- where a source's ticks live: per character, per loot spec, per difficulty
local function book(spec, diff)
  ns.db.rolled = ns.db.rolled or {}
  local me = ns.db.rolled[ns.selfKey]
  if not me then me = {}; ns.db.rolled[ns.selfKey] = me end
  local k = tostring(spec or 0) .. ":" .. tostring(diff or 0)
  me[k] = me[k] or {}
  return me[k]
end

function L.RollKey(src)
  if not src then return nil end
  if src.enc then return "r" .. src.enc end
  return "d" .. tostring(src.instID or src.name or "?")
end

-- Everything a bonus roll there can actually give you. The Adventure Journal lists far more than
-- that for a boss, so three things are dropped:
--   · filter 14 ("other"): cosmetics, furniture, mounts, patterns - none of it is rollable
--   · off-spec items: the loot scan deliberately adds trinkets for every spec of your class so they
--     show in the gear guide, but a roll only ever pays out for your loot spec
--   · crafting reagents, Labyrinth armaments and delve loot, which come from elsewhere entirely
local function rollable(it)
  if not it or (it.id or 0) <= 0 then return false end
  if it.hidden or it.reagent or it.offspec then return false end
  if it.slot == "other" or it.filter == 14 then return false end
  if it.crafted or it.labyrinth or it.delveLoot or it.delve then return false end
  return true
end

function L.RollItems(src)
  local out, seen = {}, {}
  for _, it in ipairs(L.items or {}) do
    if rollable(it) then
      local mine = (src.enc and it.enc == src.enc) or (not src.enc and not it.raid and it.inst == src.name)
      if mine and not seen[it.id] then
        seen[it.id] = true
        out[#out + 1] = { id = it.id, name = it.name, icon = it.icon, it = it }
      end
    end
  end
  local cacheID = V and V.FindByName and V.FindByName(src.boss or src.name)
  local c = cacheID and V.Read and V.Read(cacheID)
  if c then
    for _, nm in ipairs(c.list or {}) do
      local known
      for _, o in ipairs(out) do if o.name and o.name:lower() == nm:lower() then known = true break end end
      if not known then out[#out + 1] = { id = nil, name = nm, fromCache = true } end   -- the game named it, so it is real
    end
  end
  table.sort(out, function(a, b) return (a.name or "") < (b.name or "") end)
  return out
end

function L.IsRolled(src, item, spec, diff)
  local b = book(spec or L.RollSpec(), diff or L.RollDiff())[L.RollKey(src)]
  if not b then return false end
  return b[tostring(item.id or item.name)] == true
end

function L.ToggleRolled(src, item, spec, diff)
  spec, diff = spec or L.RollSpec(), diff or L.RollDiff()
  local bk = book(spec, diff)
  local key = L.RollKey(src)
  bk[key] = bk[key] or {}
  local k = tostring(item.id or item.name)
  bk[key][k] = (not bk[key][k]) or nil
  return bk[key][k] == true
end

function L.RolledCount(src, items, spec, diff)
  local bk = book(spec or L.RollSpec(), diff or L.RollDiff())[L.RollKey(src)] or {}
  local n = 0
  for _, it in ipairs(items) do if bk[tostring(it.id or it.name)] then n = n + 1 end end
  return n
end

-- rolling the whole table resets it, so clearing is a first-class action, not a mistake-fixer
function L.ResetRolls(src, spec, diff)
  local bk = book(spec or L.RollSpec(), diff or L.RollDiff())
  bk[L.RollKey(src)] = nil
end

-- what a roll there is still worth: how many are left, and your wishlist items among them
function L.RollLeft(src, spec, diff)
  local items = L.RollItems(src)
  local done = L.RolledCount(src, items, spec, diff)
  local left, wanted = #items - done, 0
  for _, it in ipairs(items) do
    if not L.IsRolled(src, it, spec, diff) and it.id and L.IsWished(it.id) then wanted = wanted + 1 end
  end
  return left, #items, wanted
end

---------------------------------------------------------------- sources
local function isSeasonRaid(inst)
  local t = L.SEASON and L.SEASON.tier
  return inst and t and t.raid and inst:lower() == t.raid:lower()
end
local function isLair(inst)
  if not (inst and L.SEASON and L.SEASON.lairs) then return false end
  local n = inst:lower():gsub("^the%s+", "")
  for k in pairs(L.SEASON.lairs) do
    local kb = k:gsub("^the%s+", "")
    if kb == n or n:find(kb, 1, true) then return true end
  end
  return false
end

local function sources()
  local out, seen = {}, {}
  local bosses, lairs = {}, {}
  for _, it in ipairs(L.items or {}) do
    if it.raid and it.inst then
      local nm = (it.encName and it.encName ~= "" and it.encName) or it.inst
      if isSeasonRaid(it.inst) and not seen["b" .. nm] then
        seen["b" .. nm] = true
        bosses[#bosses + 1] = { name = nm, boss = nm, enc = it.enc, index = it.encIndex or 99, raid = true }
      elseif isLair(it.inst) and not seen["l" .. it.inst] then
        seen["l" .. it.inst] = true
        lairs[#lairs + 1] = { name = nm, boss = nm, enc = it.enc, index = 1, raid = true, lair = true }
      end
    end
  end
  table.sort(bosses, function(a, b) return a.index < b.index end)
  table.sort(lairs, function(a, b) return a.name < b.name end)
  out[#out + 1] = { head = ((L.SEASON and L.SEASON.tier and L.SEASON.tier.raid) or "Raid"):upper() }
  for _, b in ipairs(bosses) do out[#out + 1] = b end
  if #lairs > 0 then
    out[#out + 1] = { head = "LAIRS" }
    for _, b in ipairs(lairs) do out[#out + 1] = b end
  end
  out[#out + 1] = { head = "MYTHIC+" }
  for _, m in ipairs(ns.maps or {}) do out[#out + 1] = { name = m.name, instID = m.id } end
  return out
end

---------------------------------------------------------------- rows
local function makeSrcRow(i)
  local r = CreateFrame("Button", nil, win.left)
  r:SetSize(LEFT_W - 8, ROW_H)
  r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints(); r.bg:SetColorTexture(T.RGB("card", 0))
  r.mark = r:CreateTexture(nil, "ARTWORK"); r.mark:SetColorTexture(T.RGB("amethyst")); r.mark:SetWidth(2)
  r.mark:SetPoint("TOPLEFT"); r.mark:SetPoint("BOTTOMLEFT"); r.mark:Hide()
  r.label = T.Text(r, "body", 12, "text"); r.label:SetPoint("LEFT", 8, 0); r.label:SetWidth(LEFT_W - 90)
  r.count = T.Text(r, "body", 11, "muted", "RIGHT"); r.count:SetPoint("RIGHT", -6, 0); r.count:SetWidth(70)
  r:SetScript("OnEnter", function(s) if s.src then s.bg:SetColorTexture(T.RGB("raised", 0.6)) end end)
  r:SetScript("OnLeave", function(s) s.bg:SetColorTexture(T.RGB("card", s.selected and 0.5 or 0)) end)
  r:SetScript("OnClick", function(s) if s.src then sel = s.src; itemOffset = 0; ns.Rolls_Refresh() end end)
  srcRows[i] = r
  return r
end

local function makeItemRow(i)
  local r = CreateFrame("Button", nil, win.right)
  r:SetSize(W - LEFT_W - 48, ITEM_H)
  r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints(); r.bg:SetColorTexture(T.RGB("card", 0))
  r.box = CreateFrame("Frame", nil, r, "BackdropTemplate")
  r.box:SetSize(16, 16); r.box:SetPoint("LEFT", 2, 0)
  T.Panel(r.box, "void", 0.8, 0.5)
  r.tick = T.IconTex(r.box, "tick", 12, "emerald"); r.tick:SetPoint("CENTER")
  r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(16, 16); r.icon:SetPoint("LEFT", 26, 0)
  r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.name = T.Text(r, "body", 12, "text"); r.name:SetPoint("LEFT", 48, 0); r.name:SetWidth(W - LEFT_W - 200)
  r.tag = T.Text(r, "body", 10, "muted", "RIGHT"); r.tag:SetPoint("RIGHT", -6, 0); r.tag:SetWidth(120)
  r:SetScript("OnEnter", function(s)
    s.bg:SetColorTexture(T.RGB("raised", 0.5))
    if s.item and s.item.it then
      local link = L.LinkFor and L.LinkFor(s.item.it)
      if link then GameTooltip:SetOwner(s, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink(link); GameTooltip:Show() end
    end
  end)
  r:SetScript("OnLeave", function(s) s.bg:SetColorTexture(T.RGB("card", 0)); GameTooltip:Hide() end)
  r:SetScript("OnClick", function(s)
    if not (s.item and sel) then return end
    L.ToggleRolled(sel, s.item)
    ns.Rolls_Refresh()
  end)
  itemRows[i] = r
  return r
end

---------------------------------------------------------------- window
local function build()
  win = CreateFrame("Frame", "SmilerKeysRolls", UIParent, "BackdropTemplate")
  win:SetSize(W, H); win:SetPoint("CENTER")
  win:SetFrameStrata("DIALOG"); win:SetToplevel(true); win:SetClampedToScreen(true)
  win:SetMovable(true); win:EnableMouse(true); win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", win.StartMoving); win:SetScript("OnDragStop", win.StopMovingOrSizing)
  T.Panel(win, "void", 0.97, 0.38); T.TopLine(win)
  tinsert(UISpecialFrames, "SmilerKeysRolls")

  local title = T.Text(win, "label", 14, "amethyst"); title:SetPoint("TOPLEFT", 16, -15)
  title:SetText("B O N U S   R O L L S")
  win.sub = T.Text(win, "body", 11, "muted"); win.sub:SetPoint("LEFT", title, "RIGHT", 12, 0)
  local close = CreateFrame("Button", nil, win); close:SetSize(22, 22); close:SetPoint("TOPRIGHT", -8, -9)
  close.icon = T.IconTex(close, "close", 13, "muted"); close.icon:SetPoint("CENTER")
  close:SetScript("OnClick", function() win:Hide() end)

  -- loot spec
  local specs, opts = specList(), {}
  for _, sp in ipairs(specs) do opts[#opts + 1] = { sp.id, sp.name } end
  win.spec = T.Segmented(win, opts, function() return L.RollSpec() end, function(k) L.SetRollSpec(k) end, 22)
  win.spec:SetPoint("TOPLEFT", 16, -44)
  local sl = T.Text(win, "label", 10, "muted"); sl:SetPoint("BOTTOMLEFT", win.spec, "TOPLEFT", 2, 2); sl:SetText("LOOT SPEC")

  -- difficulty
  local dopts = {}
  for _, d in ipairs(DIFFS) do dopts[#dopts + 1] = { d[1], d[2] } end
  win.diff = T.Segmented(win, dopts, function() return L.RollDiff() end, function(k) L.SetRollDiff(k) end, 22)
  win.diff:SetPoint("TOPLEFT", win.spec, "BOTTOMLEFT", 0, -22)
  local dl = T.Text(win, "label", 10, "muted"); dl:SetPoint("BOTTOMLEFT", win.diff, "TOPLEFT", 2, 2); dl:SetText("DIFFICULTY")

  win.left = CreateFrame("Frame", nil, win)
  win.left:SetPoint("TOPLEFT", 16, -TOP); win.left:SetSize(LEFT_W, H - TOP - 50)
  win.left:SetClipsChildren(true)
  win.left:EnableMouseWheel(true)
  win.left:SetScript("OnMouseWheel", function(self, d)
    local maxOff = math.max(0, (self.contentH or 0) - self:GetHeight())
    offset = math.max(0, math.min(maxOff, offset - d * ROW_H * 2)); ns.Rolls_Refresh()
  end)

  local div = win:CreateTexture(nil, "ARTWORK"); div:SetColorTexture(T.RGB("edge", 0.25)); div:SetWidth(1)
  div:SetPoint("TOPLEFT", 16 + LEFT_W + 10, -TOP + 16); div:SetPoint("BOTTOMLEFT", 16 + LEFT_W + 10, 46)

  win.right = CreateFrame("Frame", nil, win)
  win.right:SetPoint("TOPLEFT", 16 + LEFT_W + 24, -TOP); win.right:SetSize(W - LEFT_W - 48, H - TOP - 50)
  win.right:SetClipsChildren(true)
  win.right:EnableMouseWheel(true)
  win.right:SetScript("OnMouseWheel", function(self, d)
    local maxOff = math.max(0, (self.contentH or 0) - self:GetHeight())
    itemOffset = math.max(0, math.min(maxOff, itemOffset - d * ITEM_H * 2)); ns.Rolls_Refresh()
  end)

  win.head = T.Text(win, "label", 12, "soft"); win.head:SetPoint("BOTTOMLEFT", win.right, "TOPLEFT", 0, 6)
  win.head:SetWidth(W - LEFT_W - 48)

  win.reset = T.Button(win, "Table complete - reset", 180, 22, function()
    if not sel then return end
    L.ResetRolls(sel)
    ns.Rolls_Refresh()
  end)
  win.reset:SetPoint("BOTTOMRIGHT", -16, 14)

  win.fill = T.Button(win, "Read from the game", 150, 22, function()
    if not sel then return end
    local id = V and V.FindByName and V.FindByName(sel.boss or sel.name)
    if not id then ns.Print("No voidcache known for that one."); return end
    local list = V.ReadLink and V.ReadLink(id)
    if not list or #list == 0 then
      ns.Print("The game isn't showing that cache's list right now - it only does inside the instance. Tick them by hand instead.")
      return
    end
    -- anything the game no longer offers you has been received: tick it
    local have, n = {}, 0
    for _, nm in ipairs(list) do have[nm:lower()] = true end
    for _, it in ipairs(L.RollItems(sel)) do
      if it.name and not have[it.name:lower()] and not L.IsRolled(sel, it) then
        L.ToggleRolled(sel, it); n = n + 1
      end
    end
    ns.Print(("Ticked %d item%s %s no longer offers you."):format(n, n == 1 and "" or "s", sel.name))
    ns.Rolls_Refresh()
  end)
  win.fill:SetPoint("BOTTOMRIGHT", win.reset, "BOTTOMLEFT", -8, 0)

  win.foot = T.Text(win, "body", 10, "muted"); win.foot:SetPoint("BOTTOMLEFT", 16, 18); win.foot:SetWidth(W - 380)
  win.foot:SetWordWrap(true)
  win.foot:SetText("Click an item to tick it off once a bonus roll has given it to you. Owning an item doesn't count - the vault and ordinary drops leave it in the pool. Roll the whole table and it resets: the button on the right clears it.")

  win:SetScript("OnShow", function() if not L.items then L.Refresh(true) end; ns.Rolls_Refresh() end)
  win:Hide()
end

---------------------------------------------------------------- draw
function ns.Rolls_Refresh()
  if not win or not win:IsShown() then return end
  if win.spec.Sync then win.spec:Sync() end
  if win.diff.Sync then win.diff:Sync() end
  local list = sources()
  local y, i = -offset, 0
  local firstSrc
  for _, s in ipairs(list) do
    i = i + 1
    local r = srcRows[i] or makeSrcRow(i)
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y)
    if s.head then
      r.src = nil
      r.label:SetText("|cff8f7fb8" .. s.head .. "|r"); r.count:SetText("")
      r.mark:Hide(); r.bg:SetColorTexture(T.RGB("card", 0)); r.selected = false
    else
      firstSrc = firstSrc or s
      r.src = s
      local left, total, wanted = L.RollLeft(s)
      r.label:SetText(s.name)
      r.count:SetText(("%d/%d%s"):format(total - left, total, wanted > 0 and ("  |cff00e676" .. wanted .. "★|r") or ""))
      r.selected = (sel and (L.RollKey(sel) == L.RollKey(s))) or false
      r.mark:SetShown(r.selected)
      r.bg:SetColorTexture(T.RGB("card", r.selected and 0.5 or 0))
      if left == 0 and total > 0 then r.label:SetTextColor(T.RGB("topaz")) else r.label:SetTextColor(T.RGB("text")) end
    end
    r:Show()
    y = y + ROW_H
  end
  for k = i + 1, #srcRows do srcRows[k]:Hide() end
  win.left.contentH = i * ROW_H     -- so the wheel can stop at the last row instead of empty space
  if not sel then sel = firstSrc end

  -- the selected source's items
  local items = sel and L.RollItems(sel) or {}
  local done = sel and L.RolledCount(sel, items) or 0
  local specName = "?"
  for _, sp in ipairs(specList()) do if sp.id == L.RollSpec() then specName = sp.name end end
  local diffName = "?"
  for _, d in ipairs(DIFFS) do if d[1] == L.RollDiff() then diffName = d[2] end end
  win.sub:SetText(("%s · %s"):format(diffName, specName))
  if sel then
    win.head:SetText(("|cffffffff%s|r   |cff8f7fb8%d of %d rolled|r%s"):format(sel.name, done, #items,
      (#items > 0 and done >= #items) and "   |cffffab00table complete - it resets|r" or ""))
  else
    win.head:SetText("")
  end
  win.reset:SetShown(sel ~= nil)
  win.fill:SetShown(sel ~= nil)
  if sel and #items > 0 and done >= #items then win.reset:SetLabel("Table complete - reset") else win.reset:SetLabel("Clear ticks") end

  local iy, n = -itemOffset, 0
  for _, it in ipairs(items) do
    n = n + 1
    local r = itemRows[n] or makeItemRow(n)
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -iy)
    r.item = it
    local on = L.IsRolled(sel, it)
    r.tick:SetShown(on)
    r.box:SetBackdropBorderColor(T.RGB(on and "emerald" or "edge", on and 0.8 or 0.4))
    r.icon:SetTexture(it.icon or (it.it and it.it.icon) or 134400)
    r.name:SetText(on and ("|cff6f6090" .. (it.name or "?") .. "|r") or (it.name or "?"))
    local tags = {}
    if it.id and L.IsWished(it.id) then tags[#tags + 1] = "|cff00e676wishlist|r" end
    if it.fromCache then tags[#tags + 1] = "|cff8f7fb8from cache|r" end
    r.tag:SetText(table.concat(tags, " "))
    r:Show()
    iy = iy + ITEM_H
  end
  for k = n + 1, #itemRows do itemRows[k]:Hide(); itemRows[k].item = nil end
  win.right.contentH = n * ITEM_H
  if n == 0 then win.head:SetText(win.head:GetText() .. "   |cff8f7fb8no loot scanned - open /sk loot once|r") end
end

function ns.RollsOpen()
  if not win then build() end
  if win:IsShown() then win:Hide() else win:Show() end
end
