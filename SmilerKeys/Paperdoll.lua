-- SmilerKeys: the wishlist beside your character sheet.
-- One box per gear slot: what you're wearing, what you want (and from where), and whether the slot is BiS.
-- Everything flows into "Where to go": bosses to bonus roll, things to farm, vault picks and crafting.
local _, ns = ...
local L = ns.Loot
local T = ns.T

-- A bar docked under the character sheet (works with ChonkyCharacterSheet's wider frame too).
local MIN_W, MIN_BOX, PLAN_W = 900, 130, 280
local BOX_W, BOX_H, GAP = 160, 50, 4
local ICON, ICONS = 24, 6
local ORDER = { "head", "neck", "shoulder", "back", "chest", "wrist", "hands", "waist",
                "legs", "feet", "finger", "trinket", "main", "off", "emb" }
local TOP = 44          -- title row height
local PLAN_ROWS = 4

local panel, tab
local boxes, planRows = {}, {}
local view = { plan = "bonus" }

local function refreshAll() if ns.LootUI_Refresh then ns.LootUI_Refresh() end; ns.Paperdoll_Refresh() end

---------------------------------------------------------------- drop an item from your bags onto a box
local function findLoot(id, slotKey)
  local best
  for _, it in ipairs(L.items or {}) do
    if it.id == id then
      if it.slot == slotKey then return it end
      best = best or it
    end
  end
  return best
end

local function receive(box)
  local kind, id = GetCursorInfo()
  if kind ~= "item" or not id then return end
  ClearCursor()
  local it = findLoot(id, box.slot.key)
  if not it then
    local name = C_Item.GetItemNameByID(id) or "That item"
    ns.Print(name .. " isn't in this season's loot tables for your spec, so SmilerKeys can't tell where it comes from.")
    return
  end
  local v = ns.LootView or {}
  if L.Add(it, box.slot.key, ns.LootTargetFor and ns.LootTargetFor(it) or {}) then
    if SOUNDKIT and SOUNDKIT.IG_ABILITY_ICON_DROP then PlaySound(SOUNDKIT.IG_ABILITY_ICON_DROP) end
  end
  refreshAll()
end

-- the loot browser asks where the mouse is when you drop an item
function ns.Paperdoll_BoxUnderMouse()
  if not panel or not panel:IsShown() then return nil end
  for _, b in ipairs(boxes) do if b:IsMouseOver() then return b end end
end

function ns.Paperdoll_ShowTargets(it)
  for _, b in ipairs(boxes) do
    b.target:SetShown(it ~= nil and (b.slot.key == it.slot or it.slot == "other"))
  end
end

---------------------------------------------------------------- a slot box
local function eqEnter(self)
  local box = self:GetParent()
  local eq = L.Equipped(box.slot.key)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  local shown = false
  for _, e in ipairs(eq) do
    if e.link then
      if shown then GameTooltip:AddLine(" ") end
      GameTooltip:SetHyperlink(e.link); shown = true
      break
    end
  end
  if not shown then GameTooltip:SetText(box.slot.label .. ": nothing equipped") end
  if #eq > 1 then
    GameTooltip:AddLine(" ")
    for _, e in ipairs(eq) do
      if e.link then GameTooltip:AddDoubleLine(e.link, e.ilvl or "", 1, 1, 1, 1, 1, 1) end
    end
  end
  GameTooltip:Show()
end

local function doneEnter(self)
  local box = self:GetParent()
  local slot = box.slot
  local ok, auto, have, need, planned, manual = L.SlotState(slot.key)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  local prof = L.Profile() == "mythic" and "Mythic" or "Heroic"
  GameTooltip:AddLine(slot.label .. (ok and (": " .. prof .. " BiS achieved") or (": not " .. prof .. " BiS yet")), T.RGB(ok and "emerald" or "amethyst"))
  GameTooltip:AddLine("Counts when you wear your BiS item on the " .. (prof == "Mythic" and "Myth" or "Hero") .. " track or higher.", 0.8, 0.8, 0.8, true)
  if #slot.inv > 0 then
    GameTooltip:AddLine(string.format("Wearing %d of %d BiS item%s here", have, need, need > 1 and "s" or ""), 1, 1, 1)
  end
  if manual == true then GameTooltip:AddLine("Marked BiS by you", 0.8, 0.8, 0.8)
  elseif manual == false then GameTooltip:AddLine("Marked not BiS by you", 0.8, 0.8, 0.8) end
  if not planned and not ok then GameTooltip:AddLine("No BiS item marked for this slot yet. Alt-click one of its items to mark it.", 0.8, 0.8, 0.8, true) end
  GameTooltip:AddLine("Click to mark this slot " .. (ok and "not BiS." or "BiS.") .. " BiS slots drop out of Where to go.", T.RGB("muted"))
  GameTooltip:Show()
end

local function makeIcon(box, j)
  local b = CreateFrame("Button", nil, box, "BackdropTemplate")
  b:SetSize(ICON, ICON)
  b:SetPoint("BOTTOMLEFT", 10 + (j - 1) * (ICON + 6), 6)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b.tex = b:CreateTexture(nil, "ARTWORK"); b.tex:SetAllPoints(); b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.edge = CreateFrame("Frame", nil, b, "BackdropTemplate")    -- diamond edge = BiS
  b.edge:SetPoint("TOPLEFT", -1, 1); b.edge:SetPoint("BOTTOMRIGHT", 1, -1)
  b.edge:SetBackdrop(T.BACKDROP); b.edge:SetBackdropColor(0, 0, 0, 0)
  b.edge:SetBackdropBorderColor(T.RGB("diamond", 0.95))
  b.edge:SetFrameLevel(b:GetFrameLevel() + 2)
  b.roll = b:CreateTexture(nil, "OVERLAY")                        -- topaz underline = bonus roll
  b.roll:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -2); b.roll:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", 0, -2)
  b.roll:SetHeight(2); b.roll:SetColorTexture(T.RGB("topaz"))
  b.lv = T.Text(b, "display", 11, "text", "CENTER", "OUTLINE")
  b.lv:SetPoint("BOTTOM", 0, 1)
  b.embDot = T.IconTex(b.edge, "dot", 9, "topaz")                 -- topaz dot = embellished / embellishment
  b.embDot:SetPoint("CENTER", b, "BOTTOMRIGHT", -1, 1)
  b.prio = CreateFrame("Frame", nil, b, "BackdropTemplate")         -- your priority number
  b.prio:SetSize(14, 13); b.prio:SetPoint("CENTER", b, "TOPLEFT", 1, -1)
  b.prio:SetFrameLevel(b:GetFrameLevel() + 4)
  T.Panel(b.prio, "void", 0.92, 0.9)
  b.prio.t = T.Text(b.prio, "display", 10, "amethyst", "CENTER"); b.prio.t:SetPoint("CENTER", 0, 0)
  b.star = T.IconTex(b.edge, "star", 11, "diamond")
  b.star:SetPoint("CENTER", b, "TOPRIGHT", -1, -1)
  b.slotKey = box.slot.key
  b:SetScript("OnEnter", function(s) if ns.WishIconEnter then ns.WishIconEnter(s) end end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  b:SetScript("OnClick", function(s, btn)
    local slotKey = box.slot.key
    if btn == "RightButton" then
      GameTooltip:Hide()
      if IsShiftKeyDown() then L.Remove(slotKey, s.index); refreshAll()
      elseif ns.WishMenu then ns.WishMenu(s, slotKey, s.index) end
    elseif IsAltKeyDown() and s.entry then
      L.ToggleBiS(s.entry.id); refreshAll()
    elseif IsControlKeyDown() and s.entry and s.entry.id > 0 then
      local link = L.EntryLink(s.entry) or select(2, C_Item.GetItemInfo(s.entry.id)); if link then DressUpItemLink(link) end
    elseif IsShiftKeyDown() and s.entry then
      local link = L.EntryLink(s.entry)
      if link and ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() then ChatEdit_InsertLink(link) end
    end
  end)
  return b
end

local function makeBox(parent, slot, w)
  local box = CreateFrame("Button", nil, parent, "BackdropTemplate")
  box:SetSize(w or BOX_W, BOX_H)
  box.slot = slot
  box.bg = box:CreateTexture(nil, "BACKGROUND"); box.bg:SetAllPoints(); box.bg:SetColorTexture(T.RGB("card", 0.85))
  -- tinted by the upgrade track of what you're wearing (Myth orange, Hero purple, …); the track is also written out
  box.tint = box:CreateTexture(nil, "BACKGROUND", nil, 1); box.tint:SetAllPoints(); box.tint:Hide()
  box.tintEdge = box:CreateTexture(nil, "BORDER"); box.tintEdge:SetPoint("BOTTOMLEFT"); box.tintEdge:SetPoint("BOTTOMRIGHT")
  box.tintEdge:SetHeight(2); box.tintEdge:Hide()
  box.doneBar = box:CreateTexture(nil, "ARTWORK")
  box.doneBar:SetPoint("TOPLEFT"); box.doneBar:SetPoint("BOTTOMLEFT"); box.doneBar:SetWidth(3)
  box.doneBar:SetColorTexture(T.RGB("emerald"))

  -- what you're wearing (hover for the item); sized to its text so the slot name gets the rest
  box.eqBtn = CreateFrame("Button", nil, box)
  box.eqBtn:SetPoint("TOPRIGHT", -26, -3); box.eqBtn:SetSize(40, 16)

  box.label = T.Text(box, "label", 12, "muted")
  box.label:SetPoint("TOPLEFT", 10, -6)
  box.label:SetPoint("RIGHT", box.eqBtn, "LEFT", -4, 0)   -- too long: cut short with "…", never under the item level
  box.label:SetWordWrap(false)
  box.label:SetText(slot.label:upper())
  box.eq = T.Text(box.eqBtn, "display", 13, "soft", "RIGHT")
  box.eq:SetAllPoints()
  box.eqBtn:SetScript("OnEnter", eqEnter)
  box.eqBtn:SetScript("OnLeave", GameTooltip_Hide)

  -- BiS achieved for this slot
  box.done = CreateFrame("Button", nil, box)
  box.done:SetSize(18, 18); box.done:SetPoint("TOPRIGHT", -5, -3)
  box.done.icon = T.IconTex(box.done, "star", 14, "muted"); box.done.icon:SetPoint("CENTER")
  box.done:SetScript("OnClick", function() L.ToggleSlotDone(slot.key); refreshAll() end)
  box.done:SetScript("OnEnter", doneEnter)
  box.done:SetScript("OnLeave", GameTooltip_Hide)

  box.icons = {}
  for j = 1, ICONS do box.icons[j] = makeIcon(box, j) end
  box.more = T.Text(box, "display", 12, "muted")

  box.add = CreateFrame("Button", nil, box, "BackdropTemplate")
  box.add:SetSize(ICON, ICON)
  T.Panel(box.add, "raised", 0.6, 0.6)
  box.add.t = T.Text(box.add, "display", 16, "muted", "CENTER"); box.add.t:SetPoint("CENTER", 0, 1); box.add.t:SetText("+")
  box.add:SetScript("OnEnter", function(s)
    s:SetBackdropBorderColor(T.RGB("amethyst")); s.t:SetTextColor(T.RGB("text"))
    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Add " .. slot.label:lower(), T.RGB("amethyst"))
    GameTooltip:AddLine("Opens the gear guide on this slot: everything you can get for it, by power and where it drops. You can also drag an item from your bags onto this box.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  box.add:SetScript("OnLeave", function(s) s:SetBackdropBorderColor(T.RGB("edge", 0.6)); s.t:SetTextColor(T.RGB("muted")); GameTooltip:Hide() end)
  box.add:SetScript("OnClick", function() if ns.GuideOpen then ns.GuideOpen(slot.key) end end)

  box.target = CreateFrame("Frame", nil, box, "BackdropTemplate")   -- outline while a matching item is dragged
  box.target:SetAllPoints()
  box.target:SetBackdrop(T.BACKDROP)
  box.target:SetBackdropColor(T.RGB("amethyst", 0.10))
  box.target:SetBackdropBorderColor(T.RGB("amethyst", 0.9))
  box.target:SetFrameLevel(box:GetFrameLevel() + 6)
  box.target:EnableMouse(false)
  box.target:Hide()

  box:SetScript("OnReceiveDrag", receive)
  box:SetScript("OnMouseUp", function(s) if GetCursorInfo() == "item" then receive(s) end end)
  box:SetScript("OnEnter", function(s) s.bg:SetColorTexture(T.RGB("raised", 0.95)) end)
  box:SetScript("OnLeave", function(s) s.bg:SetColorTexture(T.RGB("card", 0.85)) end)
  return box
end

local function fillBox(box, wish)
  local key = box.slot.key
  -- equipped item levels
  local eq = L.Equipped(key)
  local parts, low = {}, nil
  for _, e in ipairs(eq) do
    local tr, rk = L.TrackOf(e.ilvl)
    if e.ilvl then
      local c = tr and L.TRACK_COLOR[tr]
      local short = tr and L.TRACK[tr].short:sub(1, 1) or ""     -- M 334: colour and letter both say the track
      local txt = (short ~= "" and (short .. " ") or "") .. e.ilvl
      parts[#parts + 1] = c and string.format("|cff%02x%02x%02x%s|r", c[1] * 255, c[2] * 255, c[3] * 255, txt) or txt
      if tr and (not low or L.TRACK[tr].order < L.TRACK[low].order) then low = tr end   -- two rings/trinkets: the weaker one
    else
      parts[#parts + 1] = "–"
    end
  end
  box.eq:SetText(#parts > 0 and table.concat(parts, " ") or "")
  box.eqBtn:SetWidth(#parts > 0 and math.ceil(box.eq:GetStringWidth()) + 2 or 1)
  box.eqBtn:SetShown(#parts > 0)
  local c = low and L.TRACK_COLOR[low]
  box.tint:SetShown(c ~= nil); box.tintEdge:SetShown(c ~= nil)
  if c then box.tint:SetColorTexture(c[1], c[2], c[3], 0.16); box.tintEdge:SetColorTexture(c[1], c[2], c[3], 0.8) end

  local list = wish[key] or {}
  local n = 0
  local fit = math.max(1, math.floor((box:GetWidth() - 10 - ICON - 28) / (ICON + 6)))
  for j, b in ipairs(box.icons) do
    local e = j <= fit and list[j] or nil
    b.entry, b.index = e, j
    b:SetShown(e ~= nil)
    if e then
      n = j
      b.tex:SetTexture(e.icon or C_Item.GetItemIconByID(e.id))
      b.roll:SetShown(e.mode == "bonus")
      local lv = L.EntryTarget(e)
      b.lv:SetText(lv or "")
      local bis = L.IsBiS(e.id)
      local embd = e.emb and not e.reagent
      if e.reagent then
        local _, hs = L.EmbHost(e)
        b.lv:SetText(hs and L.slotByKey[hs].label:sub(1, 4):upper() or "?")
        embd = hs ~= nil
      elseif e.crafted then
        embd = embd or #L.EmbsOn(e, key) > 0
      end
      b.embDot:SetShown(embd)
      local pr = L.Prio(e.id)
      b.prio:SetShown(pr ~= nil)
      if pr then
        b.prio.t:SetText(pr); b.prio:SetWidth(pr >= 10 and 18 or 14)
        b.prio.t:SetTextColor(T.RGB(L.IsAutoPrio(e.id) and "soft" or "amethyst"))   -- from QE: lighter
      end
      b.edge:SetShown(bis or embd)
      b.star:SetShown(bis)
      b.edge:SetBackdropBorderColor(T.RGB(bis and "diamond" or "topaz", bis and 0.95 or 0))
    end
  end
  local extra = #list - math.min(fit, #box.icons)
  box.more:SetText(extra > 0 and ("+" .. extra) or "")
  box.more:ClearAllPoints()
  local x = 10 + n * (ICON + 6)
  if extra > 0 then box.more:SetPoint("BOTTOMLEFT", x, 11); x = x + 22 end
  box.add:ClearAllPoints()
  box.add:SetPoint("BOTTOMLEFT", x, 6)
  box.add:SetShown(x + ICON <= box:GetWidth() - 6)

  if key == "emb" then
    local plan, problems = L.EmbPlan()
    local worn = #L.WornEmbellishments()
    box.label:SetText(string.format("EMBELLISH %d/2", #plan) .. (worn > 0 and (" · WORN " .. worn) or ""))
    box.label:SetTextColor(T.RGB(#problems > 0 and "ruby" or (#plan == 2 and "emerald" or "muted")))
    box.eq:SetText(""); box.eqBtn:SetWidth(1)
    box.problems = problems
    return
  end
  local ok, auto, have, need, planned = L.SlotState(key)
  box.doneBar:SetShown(ok)
  T.Icon(box.done.icon, ok and "tickcircle" or "star")
  if T.hasCore then box.done.icon:SetVertexColor(T.RGB(ok and "emerald" or (planned and "diamond" or "muted"))) end
  box.done.icon:SetAlpha(ok and 1 or (planned and 0.8 or 0.35))
  box.label:SetTextColor(T.RGB(ok and "emerald" or "muted"))
  -- BiS is shown by the tick, green name and bar; the count stays for two-item slots
  box.label:SetText(box.slot.label:upper() .. (not ok and need > 1 and have > 0 and (" " .. have .. "/" .. need) or ""))
end

---------------------------------------------------------------- where to go
local PLAN_EMPTY = {
  bonus = "Add bonus-rollable items to your wishlist (as Bonus roll) to see where to spend rolls.",
  farm  = "Items you add as drops show the bosses and dungeons to farm.",
  vault = "Items you add as Great Vault picks appear here.",
  craft = "Crafted gear and Labyrinth armaments on your wishlist appear here.",
}

local function makePlanRow(parent, i, y)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(PLAN_W, 22)
  b.hl = b:CreateTexture(nil, "BACKGROUND"); b.hl:SetAllPoints(); b.hl:SetColorTexture(T.RGB("raised")); b.hl:Hide()
  b.n = T.Text(b, "display", 15, "text", "RIGHT"); b.n:SetPoint("LEFT", 0, 0); b.n:SetWidth(20)
  b.star = T.IconTex(b, "star", 12, "diamond"); b.star:SetPoint("LEFT", 26, 0)
  b.t = T.Text(b, "body", 13, "text"); b.t:SetPoint("LEFT", 44, 0); b.t:SetPoint("RIGHT", -110, 0)
  b.ilvl = T.Text(b, "display", 13, "topaz", "RIGHT"); b.ilvl:SetPoint("RIGHT", -6, 0); b.ilvl:SetWidth(104)
  b:SetScript("OnClick", function(s)
    local g = s.group
    if not g or not ns.LootBrowse then return end
    ns.LootBrowse({ inst = g.instID,
      source = (g.labyrinth or g.delve) and "delve" or (g.crafted and "crafted" or (g.raid and "raid" or "mplus")) })
  end)
  b:SetScript("OnEnter", function(s)
    s.hl:Show()
    local g = s.group
    if not g then return end
    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
    GameTooltip:AddLine(g.label, T.RGB("amethyst"))
    for _, x in ipairs(g.items) do
      GameTooltip:AddDoubleLine((x.prio and ("P" .. x.prio .. "  ") or "") .. (x.bis and "★ " or "") .. (x.it.name or ("item " .. x.it.id)),
        (x.route.label or "") .. (x.ilvl and ("  " .. x.ilvl) or "") .. (x.qe and string.format("  %+.2f%%", x.qe) or ""), 1, 1, 1, 0.8, 0.8, 0.8)
    end
    if g.killed then GameTooltip:AddLine("Killed this week on that difficulty.", T.RGB("muted"))
    elseif g.kinds.bonus then GameTooltip:AddLine("Worth a bonus roll.", T.RGB("topaz")) end
    GameTooltip:AddLine("Click to list them", T.RGB("muted"))
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function(s) s.hl:Hide(); GameTooltip:Hide() end)
  return b
end

---------------------------------------------------------------- panel
local function build()
  panel = CreateFrame("Frame", "SmilerKeysWishlist", UIParent, "BackdropTemplate")
  panel:SetSize(MIN_W, 200)
  panel:SetFrameStrata("DIALOG")
  panel:SetToplevel(true)
  panel:SetClampedToScreen(true)
  panel:EnableMouse(true)
  panel:SetMovable(true)
  panel:RegisterForDrag("LeftButton")
  panel:SetScript("OnDragStart", panel.StartMoving)
  panel:SetScript("OnDragStop", function(f)
    f:StopMovingOrSizing()
    local pt, _, rp, x, y = f:GetPoint()
    ns.db.settings.wishPoint = { pt, rp, x, y }
  end)
  T.Panel(panel, "void", 0.96, 0.38)
  T.TopLine(panel)
  panel:Hide()

  -- title row: name, spec, embellishments, buttons
  local title = T.Text(panel, "label", 14, "amethyst")
  title:SetPoint("TOPLEFT", 14, -15)
  title:SetText("W I S H L I S T")
  panel.sub = T.Text(panel, "body", 12, "muted")
  panel.sub:SetPoint("LEFT", title, "RIGHT", 12, 0)
  local hint = T.Text(panel, "body", 11, "muted")
  hint:SetPoint("LEFT", panel.sub, "RIGHT", 16, 0)
  hint:SetText("drag here to move")
  panel.profile = T.Segmented(panel, L.PROFILES, function() return L.Profile() end,
    function(k) L.SetProfile(k); if ns.LootUI_Refresh then ns.LootUI_Refresh() end; ns.Paperdoll_Refresh() end, 22)
  panel.profile:SetPoint("LEFT", hint, "RIGHT", 16, 0)
  panel.embText = T.Text(panel, "display", 13, "muted")
  panel.embText:SetPoint("LEFT", panel.profile, "RIGHT", 16, 0)
  panel.hint = hint

  local close = CreateFrame("Button", nil, panel)
  close:SetSize(22, 22); close:SetPoint("TOPRIGHT", -8, -9)
  close.icon = T.IconTex(close, "close", 13, "muted"); close.icon:SetPoint("CENTER")
  close:SetScript("OnClick", function() ns.db.settings.lootPanelClosed = true; panel:Hide(); ns.Paperdoll_UpdateTab() end)
  close:SetScript("OnEnter", function(s) if T.hasCore then s.icon:SetVertexColor(T.RGB("text")) end end)
  close:SetScript("OnLeave", function(s) if T.hasCore then s.icon:SetVertexColor(T.RGB("muted")) end end)
  local import = T.Button(panel, "Import…", 84, 24, function() if ns.ImportOpen then ns.ImportOpen() end end)
  import:SetPoint("RIGHT", close, "LEFT", -8, 0)
  import:HookScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_TOP")
    GameTooltip:AddLine("Import a wishlist", T.RGB("amethyst"))
    GameTooltip:AddLine("Paste QuestionablyEpic's Upgrade Finder, a Raidbots Droptimizer report, or any list with Wowhead item links or item IDs.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  import:HookScript("OnLeave", GameTooltip_Hide)
  local browse = T.Button(panel, "Browse loot", 104, 24, function() if ns.LootBrowse then ns.LootBrowse({}) end end)
  browse:SetPoint("RIGHT", import, "LEFT", -8, 0)
  local guide = T.Button(panel, "Gear guide", 104, 24, function() if ns.GuideOpen then ns.GuideOpen() end end, "primary")
  guide:SetPoint("RIGHT", browse, "LEFT", -8, 0)
  local rule = panel:CreateTexture(nil, "ARTWORK"); rule:SetColorTexture(T.RGB("edge", 0.38)); rule:SetHeight(1)
  rule:SetPoint("TOPLEFT", 1, -(TOP - 4)); rule:SetPoint("TOPRIGHT", -1, -(TOP - 4))

  -- one box per slot, in character-sheet order
  for _, key in ipairs(ORDER) do
    local box = makeBox(panel, L.slotByKey[key])
    if key == "emb" then
      box.done:Hide(); box.eqBtn:Hide(); panel.emb = box
      local hit = CreateFrame("Frame", nil, box)
      hit:SetPoint("TOPLEFT", 4, -2); hit:SetPoint("TOPRIGHT", -4, -2); hit:SetHeight(18)
      hit:EnableMouse(true)
      hit:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_TOP")
        GameTooltip:AddLine("Embellishments", T.RGB("amethyst"))
        GameTooltip:AddLine("You can wear 2 – two of the same is fine. Each goes on one crafted piece.", 1, 1, 1, true)
        local plan, problems = L.EmbPlan()
        if #plan > 0 then GameTooltip:AddLine(" ") end
        for _, p in ipairs(plan) do
          if p.kind == "builtin" then
            GameTooltip:AddDoubleLine(p.e.name or "?", L.slotByKey[p.slot].label .. " (built in)", 1, 1, 1, 0.8, 0.8, 0.8)
          else
            GameTooltip:AddDoubleLine(p.e.name or "?", p.host and (L.slotByKey[p.hostSlot].label .. " – " .. (p.host.name or "")) or "not on a piece yet",
              1, 1, 1, p.host and 0.8 or 1, p.host and 0.8 or 0.67, p.host and 0.8 or 0)
          end
        end
        for _, w in ipairs(L.WornEmbellishments()) do
          if _ == 1 then GameTooltip:AddLine(" "); GameTooltip:AddLine("Wearing", T.RGB("muted")) end
          GameTooltip:AddLine(w.link, 1, 1, 1)
        end
        for _, pr in ipairs(problems) do GameTooltip:AddLine(pr, T.RGB("ruby")) end
        GameTooltip:AddLine("Right-click a crafted piece: Embellish with… · Right-click an embellishment: Put it on…", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
      end)
      hit:SetScript("OnLeave", GameTooltip_Hide)
    end
    boxes[#boxes + 1] = box
  end

  -- where to go (right-hand side)
  panel.planHead = T.Text(panel, "label", 13, "muted")
  panel.planHead:SetText("WHERE TO GO")
  panel.planDiv = panel:CreateTexture(nil, "ARTWORK"); panel.planDiv:SetColorTexture(T.RGB("edge", 0.25)); panel.planDiv:SetWidth(1)
  panel.seg = T.Button(panel, "Open planner", 120, 24, function() if ns.PlannerOpen then ns.PlannerOpen() end end, "primary")
  panel.seg:HookScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_TOP"); GameTooltip:AddLine("Where to go", T.RGB("amethyst"))
    GameTooltip:AddLine("Filters (BiS / wishlist / all upgrades, bonus roll / drop / vault / crafting), Mythic bosses on farm, what you've killed this week, and how many weeks and bonus rolls your gear takes.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  panel.seg:HookScript("OnLeave", GameTooltip_Hide)
  for i = 1, PLAN_ROWS do planRows[i] = makePlanRow(panel, i, 0) end
  panel.planEmpty = T.Text(panel, "body", 12, "muted")
  panel.planEmpty:SetWidth(PLAN_W); panel.planEmpty:SetWordWrap(true)

  panel:SetScript("OnShow", function()
    if not L.items then L.Refresh(true) end
    ns.Paperdoll_Refresh()
  end)

  -- small tab under the character sheet to bring the bar back
  tab = CreateFrame("Button", "SmilerKeysWishlistTab", UIParent, "BackdropTemplate")
  tab:SetSize(110, 24)
  tab:SetFrameStrata("DIALOG")
  T.Panel(tab, "void", 0.96, 0.6)
  tab.icon = T.IconTex(tab, "star", 14, "amethyst"); tab.icon:SetPoint("LEFT", 8, 0)
  tab.t = T.Text(tab, "strong", 12, "text"); tab.t:SetPoint("LEFT", tab.icon, "RIGHT", 6, 0); tab.t:SetText("Wishlist")
  tab:SetScript("OnClick", function() ns.db.settings.lootPanelClosed = nil; ns.Paperdoll_Show() end)
  tab:SetScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_BOTTOM"); GameTooltip:AddLine("Wishlist", T.RGB("amethyst"))
    GameTooltip:AddLine("Your wishlist and BiS for each slot", 1, 1, 1); GameTooltip:Show()
  end)
  tab:SetScript("OnLeave", GameTooltip_Hide)
  tab:Hide()
end

-- size the bar to the character sheet's width and lay out the boxes in as many columns as fit
local function layout(width)
  local W = math.max(MIN_W, math.floor(width or MIN_W))
  local gridW = W - 28 - PLAN_W - 25
  local cols = math.max(4, math.min(#boxes, math.floor((gridW + GAP) / (MIN_BOX + GAP))))
  local rows = math.ceil(#boxes / cols)
  local boxW = math.floor((gridW - (cols - 1) * GAP) / cols)
  for i, b in ipairs(boxes) do
    local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
    b:SetWidth(boxW)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", 14 + c * (boxW + GAP), -(TOP + 8) - r * (BOX_H + GAP))
  end
  local px = 14 + gridW + 25
  panel.planDiv:ClearAllPoints()
  panel.planDiv:SetPoint("TOPLEFT", px - 13, -(TOP + 8)); panel.planDiv:SetHeight(rows * (BOX_H + GAP) - GAP)
  panel.planHead:ClearAllPoints(); panel.planHead:SetPoint("TOPLEFT", px, -(TOP + 12))
  panel.seg:ClearAllPoints(); panel.seg:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -14, -(TOP + 32))
  for i, b in ipairs(planRows) do
    b:ClearAllPoints(); b:SetPoint("TOPLEFT", px, -(TOP + 64) - (i - 1) * 22)
  end
  panel.planEmpty:ClearAllPoints(); panel.planEmpty:SetPoint("TOPLEFT", px, -(TOP + 66))
  local bodyH = math.max(rows * (BOX_H + GAP) - GAP, 64 + PLAN_ROWS * 22)
  panel:SetSize(W, TOP + 8 + bodyH + 12)
end

-- The bar floats on its own (Chonky and other sheets reshape the character frame, so we don't size
-- or scale from it). Drag the title row to move it; the spot is remembered.
local function anchor()
  local cf = CharacterFrame
  panel:SetScale(1); tab:SetScale(1)
  panel:ClearAllPoints()
  tab:ClearAllPoints()
  local W = math.max(MIN_W, math.min(1420, math.floor(UIParent:GetWidth() - 40)))
  layout(W)
  local p = ns.db.settings.wishPoint
  if p then
    panel:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  else
    panel:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 230)
  end
  if cf then tab:SetPoint("TOPLEFT", cf, "BOTTOMLEFT", 0, -4) else tab:SetPoint("CENTER") end
end

local function safely(fn)
  local ok, err = pcall(fn)
  if not ok then
    ns.Print("Wishlist couldn't open: " .. tostring(err))
    if geterrorhandler then geterrorhandler()(err) end
  end
  return ok
end

function ns.Paperdoll_UpdateTab()
  if not tab then return end
  local cf = CharacterFrame
  tab:SetShown(cf and cf:IsShown() and not panel:IsShown() or false)
end

function ns.Paperdoll_Show()
  safely(function()
    if not panel then build() end
    anchor()
    panel:Show()
    panel:Raise()
    ns.Paperdoll_UpdateTab()
  end)
end

function ns.Paperdoll_Hide()
  if panel then panel:Hide(); ns.Paperdoll_UpdateTab() end
end

function ns.Paperdoll_IsShown() return panel and panel:IsShown() or false end

-- /sk loot: open the character sheet with the wishlist beside it (or close both)
function ns.LootToggle()
  if not panel then build() end
  if panel:IsShown() then
    panel:Hide()
    if CharacterFrame and CharacterFrame:IsShown() and not InCombatLockdown() then pcall(HideUIPanel, CharacterFrame) end
    ns.Paperdoll_UpdateTab()
    return
  end
  ns.db.settings.lootPanelClosed = nil
  if CharacterFrame and not CharacterFrame:IsShown() and ToggleCharacter then pcall(ToggleCharacter, "PaperDollFrame") end
  ns.Paperdoll_Show()
end

function ns.Paperdoll_Refresh()
  if not panel or not panel:IsShown() then return end
  local _, specName = GetSpecializationInfoByID and GetSpecializationInfoByID(L.SpecID() or 0)
  panel.sub:SetText(L.items and ((specName or "your") .. " loot" .. (L.incomplete and " · loading…" or "")) or "reading the Adventure Guide…")
  local wish = L.Wish()
  for _, b in ipairs(boxes) do fillBox(b, wish) end

  local plan, problems = L.EmbPlan()
  local unplaced = 0
  for _, p in ipairs(plan) do if p.kind == "reagent" and not p.host then unplaced = unplaced + 1 end end
  local txt = #plan > 0 and ("EMBELLISHMENTS " .. #plan .. "/2") or ""
  if problems[1] then txt = txt .. " – " .. problems[1]
  elseif unplaced > 0 then txt = txt .. " – " .. unplaced .. " not on a crafted piece yet" end
  panel.embText:SetText(txt)
  panel.embText:SetTextColor(T.RGB(problems[1] and "ruby" or (unplaced > 0 and "topaz" or "muted")))


  if panel.profile.Sync then panel.profile:Sync() end
  local plan = L.PlanFor(L.PlanOpts and L.PlanOpts() or { scope = "wish", modes = { bonus = true, drop = true, other = true } })
  panel.planEmpty:SetShown(#plan == 0)
  panel.planEmpty:SetText("Nothing to chase with the planner's filters. Add items to your wishlist, or open the planner.")
  for i, b in ipairs(planRows) do
    local g = plan[i]
    b.group = g
    b:SetShown(g ~= nil)
    if g then
      b.n:SetText(g.count)
      b.star:SetShown(g.bis > 0)
      b.t:SetText(g.label)
      local r = g.bestRoute
      local d = r and r.diff and (L.DIFF_NAME[r.diff] or "") or ""
      b.ilvl:SetText((g.killed and "done · " or "") .. (d ~= "" and (d .. " ") or "") .. (g.best or "") .. (g.kinds.bonus and " BR" or ""))
      b.ilvl:SetTextColor(T.RGB(g.killed and "muted" or (g.kinds.bonus and "topaz" or "soft")))
      b.t:SetTextColor(T.RGB(g.killed and "muted" or "text"))
    end
  end
end

---------------------------------------------------------------- follow the character sheet
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:SetScript("OnEvent", function(_, e)
  if e == "PLAYER_EQUIPMENT_CHANGED" then
    if panel and panel:IsShown() then ns.Debounce("pd-eq", 0.3, ns.Paperdoll_Refresh) end
    return
  end
  if not CharacterFrame then return end
  CharacterFrame:HookScript("OnShow", function()
    if ns.db.settings.lootWithChar ~= false and not ns.db.settings.lootPanelClosed then
      ns.Paperdoll_Show()
    else
      if not panel then build() end
      anchor(); ns.Paperdoll_UpdateTab()
    end
  end)
  -- Chonky and other sheets change the frame's size after it opens: follow it
  CharacterFrame:HookScript("OnSizeChanged", function()
    if panel and (panel:IsShown() or (tab and tab:IsShown())) then
      ns.Debounce("pd-size", 0.05, function() ns.Paperdoll_UpdateTab() end)
    end
  end)
  CharacterFrame:HookScript("OnHide", function()
    if panel then panel:Hide() end
    if tab then tab:Hide() end
  end)
end)
