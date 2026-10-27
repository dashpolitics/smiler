-- RampNotes: plain on-screen notes with draggable spell rows.
local ADDON = ...
local RN = { blocks = {}, activeSlots = {}, bankButtons = {}, bankHeaders = {}, libRows = {} }
_G.RampNotes = RN

local MAX_SLOTS = 10
local FONT = STANDARD_TEXT_FONT
local WHITE = "Interface\\Buttons\\WHITE8x8"
local QUESTION_ICON = 134400
local ACCENT = { 0.75, 0.65, 1.0 }
-- with Smiler installed: Crystal Ball colours and fonts shared by all the add-ons
local BG, EDGE, TXT, EDGE_MUL = { 0.04, 0.04, 0.06 }, { 1, 1, 1 }, { 0.92, 0.9, 0.96 }, 1
local TITLE_FONT
if Smiler and Smiler.C then
  local SC = Smiler.C
  BG, EDGE, TXT, EDGE_MUL = SC.void, SC.edge, SC.text, 3.2
  ACCENT = SC.amethyst
  FONT, TITLE_FONT = Smiler.FONTS.body, Smiler.FONTS.label
end
local function EA(a) return math.min(1, a * EDGE_MUL) end

local DEFAULTS = {
  visible = true,
  locked = false,
  scale = 1.0,
  bgAlpha = 0.35,
  iconSize = 32,
  spacing = 4,
  showNumbers = true,
  numberAlpha = 0.3,
  titleSize = 12,
  textSize = 12,
  showTitlesLocked = true,
  lockedTooltips = true,
  sortKey = "edited",
  sortAsc = false,
  libThisChar = false,
}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function Print(msg)
  print("|cffbfa6ffRampNotes|r: " .. msg)
end

local function SpellData(id)
  if not id then return nil end
  local ok, info = pcall(C_Spell.GetSpellInfo, id)
  if ok and info then return info.name, info.iconID, info.spellID end
  return nil
end

local function CharKey()
  local name = UnitName("player") or "?"
  local realm = GetRealmName() or ""
  return name .. "-" .. realm
end

local function ClassColored(text, classFile)
  if classFile and C_ClassColor and C_ClassColor.GetClassColor then
    local c = C_ClassColor.GetClassColor(classFile)
    if c then return c:WrapTextInColorCode(text) end
  end
  return text
end

local function Skin(f, alpha, borderAlpha)
  f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  f:SetBackdropColor(BG[1], BG[2], BG[3], alpha or 0.9)
  f:SetBackdropBorderColor(EDGE[1], EDGE[2], EDGE[3], EA(borderAlpha or 0.12))
end

local function Btn(parent, text, w, h, onClick)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w, h or 18)
  Skin(b, 0.6, 0.15)
  b.t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.t:SetPoint("CENTER")
  b.t:SetText(text)
  b:SetScript("OnEnter", function(s) s:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.7) end)
  b:SetScript("OnLeave", function(s) s:SetBackdropBorderColor(EDGE[1], EDGE[2], EDGE[3], EA(0.15)) end)
  b:SetScript("OnClick", onClick)
  return b
end

local function PlainEdit(parent, multi, size)
  local e = CreateFrame("EditBox", nil, parent)
  e:SetAutoFocus(false)
  e:SetFont(FONT, size or 12, "")
  e:SetTextColor(TXT[1], TXT[2], TXT[3])
  e:SetTextInsets(4, 4, 2, 2)
  if multi then e:SetMultiLine(true); e:SetMaxLetters(4000) else e:SetMaxLetters(120) end
  e.bg = e:CreateTexture(nil, "BACKGROUND")
  e.bg:SetAllPoints()
  e.bg:SetColorTexture(1, 1, 1, 0.05)
  e.ph = e:CreateFontString(nil, "OVERLAY")
  e.ph:SetFont(FONT, size or 12, "")
  e.ph:SetTextColor(1, 1, 1, 0.3)
  e.ph:SetPoint("TOPLEFT", 4, -2)
  e:SetScript("OnEscapePressed", e.ClearFocus)
  if not multi then e:SetScript("OnEnterPressed", e.ClearFocus) end
  e.UpdatePlaceholder = function(self) self.ph:SetShown(self:GetText() == "" and not self:HasFocus()) end
  e:SetScript("OnEditFocusLost", function(self) self:UpdatePlaceholder() end)
  return e
end

local function SavePoint(frame, key)
  local p, _, rp, x, y = frame:GetPoint()
  RN.db[key] = { p, rp, x, y }
end

local function RestorePoint(frame, key, fallback)
  frame:ClearAllPoints()
  local pt = RN.db[key]
  if pt then
    frame:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4])
  else
    fallback(frame)
  end
end

local function Window(name, title, w, h, key)
  local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
  f:SetSize(w, h)
  Skin(f, 0.92, 0.18)
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(s) s:StopMovingOrSizing(); SavePoint(s, key) end)
  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.title:SetPoint("TOPLEFT", 10, -8)
  f.title:SetText(title)
  f.title:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
  if TITLE_FONT then f.title:SetFont(TITLE_FONT, 14, "") end
  f.close = Btn(f, "x", 18, 18, function() f:Hide() end)
  f.close:SetPoint("TOPRIGHT", -6, -6)
  f.key = key
  f:Hide()
  tinsert(UISpecialFrames, name)
  return f
end

local function Scroller(parent, top, bottom, width)
  local sf = CreateFrame("ScrollFrame", nil, parent)
  sf:SetPoint("TOPLEFT", 10, top)
  sf:SetPoint("BOTTOMRIGHT", -10, bottom)
  local child = CreateFrame("Frame", nil, sf)
  child:SetSize(width, 10)
  sf:SetScrollChild(child)
  sf:EnableMouseWheel(true)
  sf.Clamp = function(self)
    local max = math.max(0, child:GetHeight() - self:GetHeight())
    if self:GetVerticalScroll() > max then self:SetVerticalScroll(max) end
  end
  sf:SetScript("OnMouseWheel", function(self, delta)
    local max = math.max(0, child:GetHeight() - self:GetHeight())
    local v = math.min(max, math.max(0, self:GetVerticalScroll() - delta * 30))
    self:SetVerticalScroll(v)
  end)
  sf.child = child
  return sf
end

local function SpellTooltip(owner, spellID, extra)
  if not spellID then return end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  local ok = pcall(GameTooltip.SetSpellByID, GameTooltip, spellID)
  if not ok then GameTooltip:SetText(SpellData(spellID) or ("Spell " .. spellID)) end
  if extra then
    for _, line in ipairs(extra) do GameTooltip:AddLine(line, 0.6, 0.6, 0.65, true) end
  end
  GameTooltip:Show()
end

-- ---------------------------------------------------------------------------
-- Data
-- ---------------------------------------------------------------------------
function RN:InitDB()
  RampNotesDB = RampNotesDB or {}
  local db = RampNotesDB
  for k, v in pairs(DEFAULTS) do if db[k] == nil then db[k] = v end end
  db.notes = db.notes or {}
  db.custom = db.custom or {}
  db.nextID = db.nextID or 1
  db.nextOrder = db.nextOrder or 1
  self.db = db
end

function RN:Touch(note)
  if note then note.edited = time() end
  self:Refresh()
  self:RefreshLibrary()
end

function RN:NewNote(kind, silent)
  local db = self.db
  local id = db.nextID
  db.nextID = id + 1
  local note = {
    id = id,
    title = (kind == "text") and "New note" or "New rotation",
    char = CharKey(),
    class = select(2, UnitClass("player")),
    created = time(),
    edited = time(),
    shown = true,
    order = db.nextOrder,
    hasSpells = (kind ~= "text"),
    hasText = (kind == "text"),
    spells = {},
    text = "",
  }
  db.nextOrder = db.nextOrder + 1
  db.notes[id] = note
  self.lastNote = note
  db.visible = true
  if db.locked then db.locked = false end
  self:Touch(note)
  if not silent then Print("Created \"" .. note.title .. "\". Click its title to rename it.") end
  return note
end

function RN:Duplicate(note)
  local copy = self:NewNote(note.hasSpells and "spells" or "text", true)
  copy.title = (note.title or "") .. " (copy)"
  copy.hasSpells, copy.hasText, copy.text = note.hasSpells, note.hasText, note.text
  for i, s in ipairs(note.spells) do copy.spells[i] = s end
  self:Touch(copy)
end

function RN:DeleteNote(id)
  local note = self.db.notes[id]
  if not note then return end
  if self.lastNote == note then self.lastNote = nil end
  self.db.notes[id] = nil
  self:Touch()
end

function RN:PanelNotes()
  local t = {}
  for _, n in pairs(self.db.notes) do if n.shown then t[#t + 1] = n end end
  table.sort(t, function(a, b) return (a.order or 0) < (b.order or 0) end)
  return t
end

function RN:MoveNote(note, dir)
  local list = self:PanelNotes()
  for i, n in ipairs(list) do
    if n == note then
      local other = list[i + dir]
      if other then note.order, other.order = other.order, note.order end
      break
    end
  end
  self:Refresh()
end

local function InsertSpell(spells, idx, id)
  if idx > #spells then spells[#spells + 1] = id else table.insert(spells, idx, id) end
  while #spells > MAX_SLOTS do table.remove(spells) end
end

function RN:DropOnSlot(d, note, idx)
  if d.srcNote == note then
    local id = table.remove(note.spells, d.srcIndex)
    InsertSpell(note.spells, idx, id)
  else
    if d.srcNote then table.remove(d.srcNote.spells, d.srcIndex); d.srcNote.edited = time() end
    InsertSpell(note.spells, idx, d.spell)
  end
  self.lastNote = note
  self:Touch(note)
end

function RN:AddToLast(spellID)
  local target = self.lastNote
  if not (target and self.db.notes[target.id] and target.hasSpells and #target.spells < MAX_SLOTS) then
    target = nil
    for _, n in ipairs(self:PanelNotes()) do
      if n.hasSpells and #n.spells < MAX_SLOTS then target = n; break end
    end
  end
  if not target then Print("No spell row with a free slot. Create one with + Spells."); return end
  target.spells[#target.spells + 1] = spellID
  self.lastNote = target
  self:Touch(target)
end

-- ---------------------------------------------------------------------------
-- Drag and drop (addon-owned, works for any spell ID incl. passives/talents)
-- ---------------------------------------------------------------------------
local dragIcon = CreateFrame("Frame", nil, UIParent)
dragIcon:SetSize(30, 30)
dragIcon:SetFrameStrata("TOOLTIP")
dragIcon.tex = dragIcon:CreateTexture(nil, "OVERLAY")
dragIcon.tex:SetAllPoints()
dragIcon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
dragIcon:Hide()
dragIcon:SetScript("OnUpdate", function(self)
  local x, y = GetCursorPosition()
  local s = UIParent:GetEffectiveScale()
  self:ClearAllPoints()
  self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s, y / s)
end)

function RN:BeginDrag(spellID, srcNote, srcIndex)
  if not spellID then return end
  self.dragging = { spell = spellID, srcNote = srcNote, srcIndex = srcIndex }
  local _, icon = SpellData(spellID)
  dragIcon.tex:SetTexture(icon or QUESTION_ICON)
  dragIcon:Show()
  GameTooltip:Hide()
end

function RN:EndDrag()
  local d = self.dragging
  self.dragging = nil
  dragIcon:Hide()
  if not d then return end
  local target
  for _, s in ipairs(self.activeSlots) do
    if s:IsVisible() and s:IsMouseOver() then target = s; break end
  end
  if target then
    self:DropOnSlot(d, target.note, target.index)
  elseif d.srcNote then
    table.remove(d.srcNote.spells, d.srcIndex)
    self:Touch(d.srcNote)
  end
end

-- ---------------------------------------------------------------------------
-- Menus
-- ---------------------------------------------------------------------------
function RN:MainMenu(owner)
  if not MenuUtil then self:ToggleWindow(self.settings, true); return end
  MenuUtil.CreateContextMenu(owner or UIParent, function(_, root)
    root:CreateTitle("RampNotes")
    root:CreateButton("New spell note", function() RN:NewNote("spells") end)
    root:CreateButton("New text note", function() RN:NewNote("text") end)
    root:CreateDivider()
    root:CreateButton("Spell bank", function() RN:ToggleWindow(RN.bank) end)
    root:CreateButton("Library", function() RN:ToggleWindow(RN.library) end)
    root:CreateButton("Settings", function() RN:ToggleWindow(RN.settings) end)
    root:CreateDivider()
    root:CreateCheckbox("Locked", function() return RN.db.locked end, function() RN:SetLocked(not RN.db.locked) end)
    root:CreateCheckbox("Show panel", function() return RN.db.visible end, function() RN.db.visible = not RN.db.visible; RN:Refresh() end)
  end)
end

function RN:NoteMenu(owner, note)
  if not MenuUtil then return end
  MenuUtil.CreateContextMenu(owner, function(_, root)
    root:CreateTitle(note.title ~= "" and note.title or "Note")
    root:CreateButton("Move up", function() RN:MoveNote(note, -1) end)
    root:CreateButton("Move down", function() RN:MoveNote(note, 1) end)
    root:CreateDivider()
    root:CreateCheckbox("Spell row", function() return note.hasSpells end, function() note.hasSpells = not note.hasSpells; RN:Touch(note) end)
    root:CreateCheckbox("Text block below", function() return note.hasText end, function() note.hasText = not note.hasText; RN:Touch(note) end)
    root:CreateButton("Clear spells", function() wipe(note.spells); RN:Touch(note) end)
    root:CreateDivider()
    root:CreateButton("Hide from panel", function() note.shown = false; RN:Touch() end)
    root:CreateButton("Duplicate", function() RN:Duplicate(note) end)
    root:CreateButton("Delete", function() StaticPopup_Show("RAMPNOTES_DELETE", note.title, nil, note.id) end)
  end)
end

StaticPopupDialogs["RAMPNOTES_DELETE"] = {
  text = "Delete \"%s\"?",
  button1 = YES,
  button2 = NO,
  OnAccept = function(_, data) RN:DeleteNote(data) end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
}

-- ---------------------------------------------------------------------------
-- Panel
-- ---------------------------------------------------------------------------
local function NewSlot(block)
  local s = CreateFrame("Button", nil, block)
  s.bg = s:CreateTexture(nil, "BACKGROUND")
  s.bg:SetAllPoints()
  s.bg:SetColorTexture(1, 1, 1, 0.07)
  s.icon = s:CreateTexture(nil, "ARTWORK")
  s.icon:SetAllPoints()
  s.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  s.hl = s:CreateTexture(nil, "HIGHLIGHT")
  s.hl:SetAllPoints()
  s.hl:SetColorTexture(1, 1, 1, 0.12)
  s.num = s:CreateFontString(nil, "OVERLAY")
  s.num:SetFont(FONT, 9, "")
  s.num:SetPoint("TOP", s, "BOTTOM", 0, -1)
  s:RegisterForDrag("LeftButton")
  s:RegisterForClicks("RightButtonUp")
  s:SetScript("OnDragStart", function(self)
    if RN.db.locked or not self.spell then return end
    RN:BeginDrag(self.spell, self.note, self.index)
  end)
  s:SetScript("OnDragStop", function() RN:EndDrag() end)
  s:SetScript("OnClick", function(self, button)
    if RN.db.locked then return end
    if button == "RightButton" and self.spell then
      table.remove(self.note.spells, self.index)
      RN:Touch(self.note)
    end
  end)
  s:SetScript("OnEnter", function(self)
    if RN.dragging then return end
    if self.spell then
      SpellTooltip(self, self.spell, (not RN.db.locked) and { "Drag to move, drag off to remove, right-click to clear." } or nil)
    end
  end)
  s:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return s
end

local function NewBlock()
  local panel = RN.panel
  local b = CreateFrame("Frame", nil, panel)
  b:SetSize(10, 10)
  b.title = b:CreateFontString(nil, "OVERLAY")
  b.title:SetJustifyH("LEFT")
  b.title:SetTextColor(TXT[1], TXT[2], TXT[3])
  b.title:SetShadowOffset(1, -1)

  b.titleEdit = PlainEdit(b, false, 12)
  b.titleEdit.ph:SetText("Title")
  b.titleEdit:SetScript("OnTextChanged", function(self, user)
    self:UpdatePlaceholder()
    if user and b.note then b.note.title = self:GetText(); b.note.edited = time(); RN:RefreshLibrary() end
  end)
  b.titleEdit:SetScript("OnEditFocusGained", function(self) self.ph:Hide(); RN.lastNote = b.note end)

  b.menu = Btn(b, "...", 24, 16, function(self) RN:NoteMenu(self, b.note) end)

  b.slots = {}
  for i = 1, MAX_SLOTS do b.slots[i] = NewSlot(b) end

  b.text = b:CreateFontString(nil, "OVERLAY")
  b.text:SetJustifyH("LEFT")
  b.text:SetJustifyV("TOP")
  b.text:SetWordWrap(true)
  b.text:SetTextColor(TXT[1], TXT[2], TXT[3])
  b.text:SetShadowOffset(1, -1)

  b.textEdit = PlainEdit(b, true, 12)
  b.textEdit.ph:SetText("Add notes")
  b.textEdit:SetScript("OnTextChanged", function(self, user)
    self:UpdatePlaceholder()
    if user and b.note then b.note.text = self:GetText(); b.note.edited = time(); RN:Refresh(); RN:RefreshLibrary() end
  end)
  b.textEdit:SetScript("OnEditFocusGained", function(self) self.ph:Hide(); RN.lastNote = b.note end)
  return b
end

local function MeasureText(text, width, size)
  local m = RN.measure
  m:SetFont(FONT, size, "")
  m:SetWidth(width)
  if text == "" then text = " " end
  if text:sub(-1) == "\n" then text = text .. " " end
  m:SetText(text)
  return m:GetStringHeight()
end

function RN:CreatePanel()
  local db = self.db
  local p = CreateFrame("Frame", "RampNotesPanel", UIParent, "BackdropTemplate")
  self.panel = p
  p:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  p:SetMovable(true)
  p:SetClampedToScreen(true)
  p:SetFrameStrata("MEDIUM")
  RestorePoint(p, "point", function(f) f:SetPoint("CENTER", UIParent, "CENTER", 0, 150) end)

  self.measure = p:CreateFontString(nil, "OVERLAY")
  self.measure:SetWordWrap(true)
  self.measure:Hide()

  local h = CreateFrame("Frame", nil, p)
  p.header = h
  h:SetPoint("TOPLEFT", 6, -4)
  h:SetPoint("TOPRIGHT", -6, -4)
  h:SetHeight(18)
  h:EnableMouse(true)
  h:RegisterForDrag("LeftButton")
  h:SetScript("OnDragStart", function() p:StartMoving() end)
  h:SetScript("OnDragStop", function() p:StopMovingOrSizing(); SavePoint(p, "point") end)
  h.label = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  h.label:SetPoint("LEFT", 2, 0)
  h.label:SetText("RampNotes")
  h.label:SetTextColor(1, 1, 1, 0.45)

  local lock = Btn(h, "Lock", 38, 16, function() RN:SetLocked(true) end)
  lock:SetPoint("RIGHT", 0, 0)
  local menu = Btn(h, "Menu", 40, 16, function(self) RN:MainMenu(self) end)
  menu:SetPoint("RIGHT", lock, "LEFT", -4, 0)
  local bank = Btn(h, "Bank", 38, 16, function() RN:ToggleWindow(RN.bank) end)
  bank:SetPoint("RIGHT", menu, "LEFT", -4, 0)
  local addText = Btn(h, "+ Text", 46, 16, function() RN:NewNote("text") end)
  addText:SetPoint("RIGHT", bank, "LEFT", -4, 0)
  local addSpells = Btn(h, "+ Spells", 54, 16, function() RN:NewNote("spells") end)
  addSpells:SetPoint("RIGHT", addText, "LEFT", -4, 0)

  p.hint = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  p.hint:SetText("Add a note with + Spells or + Text.")
end

function RN:Refresh()
  local p = self.panel
  if not p then return end
  local db = self.db
  local locked = db.locked
  local icon, gap = db.iconSize, db.spacing
  local pad = 8
  local rowW = MAX_SLOTS * icon + (MAX_SLOTS - 1) * gap
  local innerW = math.max(rowW, 300)
  local list = self:PanelNotes()

  p:SetScale(db.scale)
  p:SetWidth(innerW + pad * 2)
  p:SetBackdropColor(BG[1], BG[2], BG[3], db.bgAlpha)
  p:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], locked and 0 or 0.35)
  p:EnableMouse(not locked)
  p.header:SetShown(not locked)
  wipe(self.activeSlots)

  local y = -pad - (locked and 0 or 20)
  for i, note in ipairs(list) do
    local b = self.blocks[i]
    if not b then b = NewBlock(); self.blocks[i] = b end
    b.note = note
    b:Show()
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", p, "TOPLEFT", pad, y)
    b:SetWidth(innerW)
    local by = 0

    -- Title
    b.title:SetFont(FONT, db.titleSize, "")
    b.titleEdit:SetFont(FONT, db.titleSize, "")
    b.titleEdit.ph:SetFont(FONT, db.titleSize, "")
    if not locked then
      b.title:Hide()
      b.titleEdit:Show()
      b.menu:Show()
      b.titleEdit:ClearAllPoints()
      b.titleEdit:SetPoint("TOPLEFT", b, "TOPLEFT", 0, by)
      b.titleEdit:SetPoint("TOPRIGHT", b, "TOPRIGHT", -28, by)
      b.titleEdit:SetHeight(db.titleSize + 8)
      if not b.titleEdit:HasFocus() then b.titleEdit:SetText(note.title or "") end
      b.titleEdit:UpdatePlaceholder()
      b.menu:ClearAllPoints()
      b.menu:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, by - 1)
      by = by - (db.titleSize + 12)
    else
      b.titleEdit:Hide()
      b.menu:Hide()
      if db.showTitlesLocked and (note.title or "") ~= "" then
        b.title:Show()
        b.title:ClearAllPoints()
        b.title:SetPoint("TOPLEFT", b, "TOPLEFT", 0, by)
        b.title:SetWidth(innerW)
        b.title:SetText(note.title)
        by = by - (b.title:GetStringHeight() + 4)
      else
        b.title:Hide()
      end
    end

    -- Spell row
    local count = #note.spells
    for s = 1, MAX_SLOTS do
      local sl = b.slots[s]
      local show = note.hasSpells and ((not locked) or s <= count)
      sl:SetShown(show)
      if show then
        sl:SetSize(icon, icon)
        sl:ClearAllPoints()
        sl:SetPoint("TOPLEFT", b, "TOPLEFT", (s - 1) * (icon + gap), by)
        sl.note, sl.index, sl.spell = note, s, note.spells[s]
        if sl.spell then
          local _, tex = SpellData(sl.spell)
          sl.icon:SetTexture(tex or QUESTION_ICON)
          sl.icon:Show()
        else
          sl.icon:Hide()
        end
        sl.num:SetText(s)
        sl.num:SetShown(db.showNumbers)
        sl.num:SetTextColor(1, 1, 1, db.numberAlpha)
        if locked then
          if db.lockedTooltips and sl.spell and sl.SetMouseClickEnabled then
            sl:EnableMouse(true)
            sl:SetMouseClickEnabled(false)
          else
            sl:EnableMouse(false)
          end
        else
          sl:EnableMouse(true)
          if sl.SetMouseClickEnabled then sl:SetMouseClickEnabled(true) end
        end
        self.activeSlots[#self.activeSlots + 1] = sl
      end
    end
    if note.hasSpells and ((not locked) or count > 0) then
      by = by - icon - (db.showNumbers and 13 or 3)
    end

    -- Text block
    b.text:SetFont(FONT, db.textSize, "")
    b.textEdit:SetFont(FONT, db.textSize, "")
    b.textEdit.ph:SetFont(FONT, db.textSize, "")
    if (not locked) and note.hasText then
      b.text:Hide()
      b.textEdit:Show()
      b.textEdit:ClearAllPoints()
      b.textEdit:SetPoint("TOPLEFT", b, "TOPLEFT", 0, by)
      b.textEdit:SetWidth(innerW)
      if not b.textEdit:HasFocus() then b.textEdit:SetText(note.text or "") end
      b.textEdit:UpdatePlaceholder()
      local th = math.max(MeasureText(note.text or "", innerW - 8, db.textSize) + 6, db.textSize + 10)
      b.textEdit:SetHeight(th)
      by = by - th - 4
    elseif locked and note.hasText and (note.text or "") ~= "" then
      b.textEdit:Hide()
      b.text:Show()
      b.text:ClearAllPoints()
      b.text:SetPoint("TOPLEFT", b, "TOPLEFT", 0, by)
      b.text:SetWidth(innerW)
      b.text:SetText(note.text)
      by = by - b.text:GetStringHeight() - 4
    else
      b.text:Hide()
      b.textEdit:Hide()
    end

    b:SetHeight(math.max(1, -by))
    if by ~= 0 then y = y + by - 8 end
  end
  for i = #list + 1, #self.blocks do self.blocks[i]:Hide() end

  local empty = (#list == 0)
  p.hint:SetShown(empty and not locked)
  if empty and not locked then
    p.hint:ClearAllPoints()
    p.hint:SetPoint("TOPLEFT", p, "TOPLEFT", pad, y)
    y = y - 20
  end
  p:SetHeight(math.max(-y + pad - 8, locked and 1 or 40))
  p:SetShown(db.visible and not (locked and empty))
end

function RN:SetLocked(v)
  self.db.locked = v and true or false
  if v then
    for _, b in ipairs(self.blocks) do b.titleEdit:ClearFocus(); b.textEdit:ClearFocus() end
    if self.bank then self.bank:Hide() end
  end
  self:Refresh()
  if self.settings and self.settings:IsShown() then self.settings:Sync() end
  Print(v and "Locked. /rn unlock to edit." or "Unlocked.")
end

-- ---------------------------------------------------------------------------
-- Spell bank
-- ---------------------------------------------------------------------------
function RN:BuildBankData()
  local seen = {}
  local groups = { { name = "Talents", ids = {} }, { name = "Active", ids = {} }, { name = "Passive", ids = {} } }
  local byName = { Talents = groups[1].ids, Active = groups[2].ids, Passive = groups[3].ids }
  local function add(g, id)
    if id and id > 0 and not seen[id] and SpellData(id) then
      seen[id] = true
      local list = byName[g]
      list[#list + 1] = id
    end
  end

  -- Talent nodes from the class tree, current spec tree and hero trees (learned or not)
  pcall(function()
    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then return end
    local cfg = C_Traits.GetConfigInfo(configID)
    for _, treeID in ipairs(cfg and cfg.treeIDs or {}) do
      for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
        local node = C_Traits.GetNodeInfo(configID, nodeID)
        if node and node.isVisible then
          for _, entryID in ipairs(node.entryIDs or {}) do
            local e = C_Traits.GetEntryInfo(configID, entryID)
            if e and e.definitionID then
              local def = C_Traits.GetDefinitionInfo(e.definitionID)
              if def then add("Talents", def.spellID) end
            end
          end
        end
      end
    end
  end)

  -- Baseline spellbook (actives and passives) not already covered by talents
  pcall(function()
    local bank = Enum.SpellBookSpellBank.Player
    for i = 1, C_SpellBook.GetNumSpellBookSkillLines() do
      local line = C_SpellBook.GetSpellBookSkillLineInfo(i)
      if line and not line.isGuild and not line.shouldHide and (line.offSpecID == nil or line.offSpecID == 0) then
        for j = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
          local item = C_SpellBook.GetSpellBookItemInfo(j, bank)
          if item and item.spellID and (item.itemType == Enum.SpellBookItemType.Spell or item.itemType == Enum.SpellBookItemType.FutureSpell) then
            add(item.isPassive and "Passive" or "Active", item.spellID)
          end
        end
      end
    end
  end)

  local custom = { name = "Custom", ids = {}, custom = true }
  for _, id in ipairs(self.db.custom) do custom.ids[#custom.ids + 1] = id end
  table.insert(groups, 1, custom)

  for _, g in ipairs(groups) do
    if not g.custom then
      table.sort(g.ids, function(a, b) return (SpellData(a) or "") < (SpellData(b) or "") end)
    end
  end
  self.bankData = groups
  self.bankDirty = false
end

local function BankButton(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(28, 28)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints()
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.hl = b:CreateTexture(nil, "HIGHLIGHT")
  b.hl:SetAllPoints()
  b.hl:SetColorTexture(1, 1, 1, 0.15)
  b:RegisterForDrag("LeftButton")
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnDragStart", function(self) RN:BeginDrag(self.spell) end)
  b:SetScript("OnDragStop", function() RN:EndDrag() end)
  b:SetScript("OnClick", function(self, button)
    if button == "RightButton" and self.custom then
      for i, id in ipairs(RN.db.custom) do if id == self.spell then table.remove(RN.db.custom, i); break end end
      RN.bankDirty = true
      RN:RefreshBank()
    elseif button == "LeftButton" then
      RN:AddToLast(self.spell)
    end
  end)
  b:SetScript("OnEnter", function(self)
    if RN.dragging then return end
    local extra = { "Drag onto a slot, or click to add to the last note you edited." }
    if self.custom then extra[2] = "Right-click to remove from Custom." end
    SpellTooltip(self, self.spell, extra)
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

function RN:CreateBank()
  local f = Window("RampNotesBank", "Spell bank", 300, 420, "bankPoint")
  self.bank = f

  f.search = PlainEdit(f, false, 12)
  f.search:SetPoint("TOPLEFT", 10, -30)
  f.search:SetPoint("TOPRIGHT", -10, -30)
  f.search:SetHeight(20)
  f.search.ph:SetText("Search spells and talents")
  f.search:UpdatePlaceholder()
  f.search:SetScript("OnTextChanged", function(self) self:UpdatePlaceholder(); RN:RefreshBank() end)
  f.search:SetScript("OnEditFocusGained", function(self) self.ph:Hide() end)

  f.sf = Scroller(f, -56, 36, 280)

  f.addBox = PlainEdit(f, false, 12)
  f.addBox:SetPoint("BOTTOMLEFT", 10, 10)
  f.addBox:SetSize(200, 20)
  f.addBox.ph:SetText("Spell ID or name")
  f.addBox:UpdatePlaceholder()
  f.addBox:SetScript("OnEditFocusGained", function(self) self.ph:Hide() end)
  f.addBox:SetScript("OnTextChanged", function(self) self:UpdatePlaceholder() end)
  local function addCustom()
    local txt = strtrim(f.addBox:GetText() or "")
    if txt == "" then return end
    local id = tonumber(txt)
    local name, _, realID = SpellData(id or txt)
    if not name then Print("Couldn't find a spell for \"" .. txt .. "\". Spell IDs always work; names only for spells you know."); return end
    id = realID or id
    for _, c in ipairs(RN.db.custom) do if c == id then Print(name .. " is already in Custom."); return end end
    tinsert(RN.db.custom, id)
    f.addBox:SetText("")
    f.addBox:ClearFocus()
    RN.bankDirty = true
    RN:RefreshBank()
    Print("Added " .. name .. " (" .. id .. ") to Custom.")
  end
  f.addBox:SetScript("OnEnterPressed", addCustom)
  local addBtn = Btn(f, "Add to custom", 70, 20, addCustom)
  addBtn:SetPoint("BOTTOMRIGHT", -10, 10)
  addBtn.t:SetText("Add")

  f:SetScript("OnShow", function()
    if not RN.db.bankPoint then
      f:ClearAllPoints()
      f:SetPoint("TOPLEFT", RN.panel, "TOPRIGHT", 6, 0)
    end
    RN:RefreshBank()
  end)
  RestorePoint(f, "bankPoint", function(w) w:SetPoint("CENTER", UIParent, "CENTER", 260, 100) end)
end

function RN:RefreshBank()
  local f = self.bank
  if not (f and f:IsShown()) then return end
  if self.bankDirty or not self.bankData then self:BuildBankData() end
  local filter = strlower(strtrim(f.search:GetText() or ""))
  local child = f.sf.child
  local cols, size, gap = 8, 28, 4
  local y, bi, hi = 0, 0, 0
  for _, g in ipairs(self.bankData) do
    local ids = {}
    for _, id in ipairs(g.ids) do
      local name = SpellData(id)
      if filter == "" or (name and strlower(name):find(filter, 1, true)) or tostring(id) == filter then
        ids[#ids + 1] = id
      end
    end
    if #ids > 0 or (g.custom and filter == "") then
      hi = hi + 1
      local h = self.bankHeaders[hi]
      if not h then
        h = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self.bankHeaders[hi] = h
      end
      h:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.9)
      h:ClearAllPoints()
      h:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
      if g.custom and #ids == 0 then
        h:SetText("Custom  |cff888888(add spell IDs below)|r")
      else
        h:SetText(g.name .. "  |cff888888" .. #ids .. "|r")
      end
      h:Show()
      y = y - 16
      for k, id in ipairs(ids) do
        bi = bi + 1
        local b = self.bankButtons[bi]
        if not b then b = BankButton(child); self.bankButtons[bi] = b end
        local col = (k - 1) % cols
        if k > 1 and col == 0 then y = y - (size + gap) end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", child, "TOPLEFT", col * (size + gap), y)
        local _, icon = SpellData(id)
        b.icon:SetTexture(icon or QUESTION_ICON)
        b.spell, b.custom = id, g.custom
        b:Show()
      end
      if #ids > 0 then y = y - (size + gap) end
      y = y - 6
    end
  end
  for i = bi + 1, #self.bankButtons do self.bankButtons[i]:Hide() end
  for i = hi + 1, #self.bankHeaders do self.bankHeaders[i]:Hide() end
  child:SetHeight(math.max(10, -y))
  f.sf:Clamp()
end

-- ---------------------------------------------------------------------------
-- Library
-- ---------------------------------------------------------------------------
local LIB_COLS = { { key = "title", label = "Title", x = 30, w = 180 }, { key = "char", label = "Character", x = 214, w = 130 }, { key = "edited", label = "Edited", x = 348, w = 58 } }

function RN:LibraryList()
  local db = self.db
  local me = CharKey()
  local t = {}
  for _, n in pairs(db.notes) do
    if not db.libThisChar or n.char == me then t[#t + 1] = n end
  end
  local k, asc = db.sortKey, db.sortAsc
  table.sort(t, function(a, b)
    local va, vb
    if k == "title" then
      va, vb = strlower(a.title or ""), strlower(b.title or "")
    elseif k == "char" then
      va, vb = a.char or "", b.char or ""
      if va == vb then
        va, vb = strlower(a.title or ""), strlower(b.title or "")
        if va ~= vb then return va < vb end
      end
    else
      va, vb = a.edited or 0, b.edited or 0
    end
    if va == vb then return a.id < b.id end
    if asc then return va < vb end
    return va > vb
  end)
  return t
end

local function LibRow(parent)
  local r = CreateFrame("Frame", nil, parent)
  r:SetSize(470, 22)
  r.bg = r:CreateTexture(nil, "BACKGROUND")
  r.bg:SetAllPoints()
  r.bg:SetColorTexture(1, 1, 1, 0.03)
  r.check = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
  r.check:SetSize(20, 20)
  r.check:SetPoint("LEFT", 4, 0)
  r.check:SetScript("OnClick", function(self) r.note.shown = self:GetChecked() and true or false; RN:Refresh() end)
  r.check:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText("Show on panel"); GameTooltip:Show() end)
  r.check:SetScript("OnLeave", function() GameTooltip:Hide() end)
  r.cells = {}
  for i, c in ipairs(LIB_COLS) do
    local fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", c.x, 0)
    fs:SetWidth(c.w)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    r.cells[i] = fs
  end
  r.dup = Btn(r, "Copy", 34, 16, function() RN:Duplicate(r.note) end)
  r.dup:SetPoint("LEFT", 410, 0)
  r.del = Btn(r, "Del", 26, 16, function() StaticPopup_Show("RAMPNOTES_DELETE", r.note.title, nil, r.note.id) end)
  r.del:SetPoint("LEFT", 446, 0)
  return r
end

function RN:CreateLibrary()
  local f = Window("RampNotesLibrary", "Library", 494, 400, "libPoint")
  self.library = f

  local newS = Btn(f, "New spell note", 96, 18, function() RN:NewNote("spells") end)
  newS:SetPoint("TOPLEFT", 10, -30)
  local newT = Btn(f, "New text note", 90, 18, function() RN:NewNote("text") end)
  newT:SetPoint("LEFT", newS, "RIGHT", 6, 0)

  f.mine = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
  f.mine:SetSize(20, 20)
  f.mine:SetPoint("TOPRIGHT", -140, -29)
  f.mine:SetScript("OnClick", function(self) RN.db.libThisChar = self:GetChecked() and true or false; RN:RefreshLibrary() end)
  local mineL = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  mineL:SetPoint("LEFT", f.mine, "RIGHT", 2, 0)
  mineL:SetText("This character only")

  f.heads = {}
  for i, c in ipairs(LIB_COLS) do
    local h = CreateFrame("Button", nil, f)
    h:SetSize(c.w, 16)
    h:SetPoint("TOPLEFT", 10 + c.x, -56)
    h.t = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    h.t:SetPoint("LEFT")
    h:SetScript("OnClick", function()
      if RN.db.sortKey == c.key then RN.db.sortAsc = not RN.db.sortAsc
      else RN.db.sortKey = c.key; RN.db.sortAsc = (c.key ~= "edited") end
      RN:RefreshLibrary()
    end)
    f.heads[i] = h
  end
  local showL = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  showL:SetPoint("TOPLEFT", 14, -58)
  showL:SetText("Show")
  showL:SetTextColor(1, 1, 1, 0.5)

  f.sf = Scroller(f, -76, 10, 474)
  f.empty = f.sf.child:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.empty:SetPoint("TOPLEFT", 4, -6)
  f.empty:SetText("No notes yet.")

  f:SetScript("OnShow", function() RN:RefreshLibrary() end)
  RestorePoint(f, "libPoint", function(w) w:SetPoint("CENTER") end)
end

function RN:RefreshLibrary()
  local f = self.library
  if not (f and f:IsShown()) then return end
  local db = self.db
  f.mine:SetChecked(db.libThisChar)
  for i, c in ipairs(LIB_COLS) do
    local arrow = ""
    if db.sortKey == c.key then arrow = db.sortAsc and " ^" or " v" end
    f.heads[i].t:SetText(c.label .. arrow)
    f.heads[i].t:SetTextColor(1, 1, 1, db.sortKey == c.key and 0.9 or 0.5)
  end
  local list = self:LibraryList()
  local child = f.sf.child
  for i, note in ipairs(list) do
    local r = self.libRows[i]
    if not r then r = LibRow(child); self.libRows[i] = r end
    r.note = note
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -(i - 1) * 24)
    r.bg:SetShown(i % 2 == 1)
    r.check:SetChecked(note.shown)
    local kind = note.hasSpells and (note.hasText and "spells + text" or (#note.spells .. " spells")) or "text"
    r.cells[1]:SetText((note.title ~= "" and note.title or "|cff888888Untitled|r") .. "  |cff777777" .. kind .. "|r")
    r.cells[2]:SetText(ClassColored(note.char or "?", note.class))
    r.cells[3]:SetText(date("%d %b", note.edited or 0))
    r:Show()
  end
  for i = #list + 1, #self.libRows do self.libRows[i]:Hide() end
  f.empty:SetShown(#list == 0)
  child:SetHeight(math.max(10, #list * 24))
  f.sf:Clamp()
end

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------
function RN:CreateSettings()
  local f = Window("RampNotesSettings", "Settings", 300, 540, "setPoint")
  self.settings = f
  f.controls = {}
  local y = -34

  local function Slider(label, minv, maxv, step, key, fmt)
    local l = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    l:SetPoint("TOPLEFT", 14, y)
    l:SetText(label)
    local v = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    v:SetPoint("TOPRIGHT", -14, y)
    local s = CreateFrame("Slider", nil, f, "BackdropTemplate")
    s:SetOrientation("HORIZONTAL")
    s:SetPoint("TOPLEFT", 14, y - 16)
    s:SetPoint("TOPRIGHT", -14, y - 16)
    s:SetHeight(10)
    Skin(s, 0.6, 0.15)
    s:SetThumbTexture(WHITE)
    local th = s:GetThumbTexture()
    th:SetSize(8, 14)
    th:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.9)
    s:SetMinMaxValues(minv, maxv)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:EnableMouseWheel(true)
    s:SetScript("OnMouseWheel", function(self, d) self:SetValue(self:GetValue() + d * step) end)
    s:SetScript("OnValueChanged", function(_, val)
      if f.syncing then return end
      val = math.floor(val / step + 0.5) * step
      RN.db[key] = val
      v:SetText(fmt(val))
      RN:Refresh()
    end)
    s.Sync = function()
      s:SetValue(RN.db[key])
      v:SetText(fmt(RN.db[key]))
    end
    f.controls[#f.controls + 1] = s
    y = y - 38
  end

  local function Check(label, key, onChange)
    local c = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    c:SetSize(22, 22)
    c:SetPoint("TOPLEFT", 10, y)
    local t = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t:SetPoint("LEFT", c, "RIGHT", 2, 0)
    t:SetText(label)
    c:SetScript("OnClick", function(self)
      local val = self:GetChecked() and true or false
      if onChange then onChange(val) else RN.db[key] = val; RN:Refresh() end
    end)
    c.Sync = function() c:SetChecked(RN.db[key]) end
    f.controls[#f.controls + 1] = c
    y = y - 24
  end

  local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end
  local px = function(v) return math.floor(v + 0.5) .. "px" end

  Slider("Scale", 0.5, 2, 0.05, "scale", pct)
  Slider("Background opacity", 0, 1, 0.05, "bgAlpha", pct)
  Slider("Icon size", 20, 56, 1, "iconSize", px)
  Slider("Icon spacing", 0, 12, 1, "spacing", px)
  Slider("Title font size", 8, 24, 1, "titleSize", px)
  Slider("Text font size", 8, 24, 1, "textSize", px)
  Slider("Slot number opacity", 0, 1, 0.05, "numberAlpha", pct)
  y = y + 4
  Check("Show slot numbers", "showNumbers")
  Check("Show titles when locked", "showTitlesLocked")
  Check("Spell tooltips when locked", "lockedTooltips")
  Check("Show panel", "visible")
  Check("Lock panel", "locked", function(v) RN:SetLocked(v) end)

  local resetPos = Btn(f, "Reset position", 110, 20, function()
    RN.db.point = nil
    RestorePoint(RN.panel, "point", function(w) w:SetPoint("CENTER", UIParent, "CENTER", 0, 150) end)
  end)
  resetPos:SetPoint("BOTTOMLEFT", 10, 10)
  local resetAll = Btn(f, "Reset settings", 110, 20, function()
    for k, v in pairs(DEFAULTS) do
      if k ~= "sortKey" and k ~= "sortAsc" and k ~= "libThisChar" then RN.db[k] = v end
    end
    f:Sync()
    RN:Refresh()
  end)
  resetAll:SetPoint("BOTTOMRIGHT", -10, 10)

  f:SetHeight(-y + 44)
  f.Sync = function()
    f.syncing = true
    for _, c in ipairs(f.controls) do c.Sync() end
    f.syncing = false
  end
  f:SetScript("OnShow", function() f:Sync() end)
  RestorePoint(f, "setPoint", function(w) w:SetPoint("CENTER", UIParent, "CENTER", -200, 0) end)
end

function RN:RegisterBlizzardOptions()
  if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
  pcall(function()
    local canvas = CreateFrame("Frame")
    local info = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    info:SetPoint("TOPLEFT", 16, -16)
    info:SetText("RampNotes uses its own settings window. Type /rn for commands.")
    local btn = Btn(canvas, "Open RampNotes settings", 180, 22, function()
      if SettingsPanel then pcall(HideUIPanel, SettingsPanel) end
      RN:ToggleWindow(RN.settings, true)
    end)
    btn:SetPoint("TOPLEFT", 16, -44)
    local cat = Settings.RegisterCanvasLayoutCategory(canvas, "RampNotes")
    Settings.RegisterAddOnCategory(cat)
  end)
end

-- ---------------------------------------------------------------------------
-- Windows, slash, compartment, events
-- ---------------------------------------------------------------------------
function RN:ToggleWindow(f, force)
  if not f then return end
  local show
  if force == nil then show = not f:IsShown() else show = force end
  f:SetShown(show)
end

function RampNotes_OnCompartmentClick(_, button)
  if button == "RightButton" then
    RN.db.visible = not RN.db.visible
    RN:Refresh()
  else
    RN:MainMenu(UIParent)
  end
end

function RampNotes_OnCompartmentEnter(_, frame)
  GameTooltip:SetOwner(frame or UIParent, "ANCHOR_LEFT")
  GameTooltip:SetText("RampNotes")
  GameTooltip:AddLine("Left-click for the menu, right-click to show or hide the panel.", 0.7, 0.7, 0.7, true)
  GameTooltip:Show()
end

function RampNotes_OnCompartmentLeave()
  GameTooltip:Hide()
end

SLASH_RAMPNOTES1 = "/rn"
SLASH_RAMPNOTES2 = "/rampnotes"
SlashCmdList.RAMPNOTES = function(msg)
  local cmd = strlower(strtrim(msg or ""))
  if cmd == "" then
    RN.db.visible = not RN.db.visible
    RN:Refresh()
  elseif cmd == "lock" then RN:SetLocked(true)
  elseif cmd == "unlock" then RN.db.visible = true; RN:SetLocked(false)
  elseif cmd == "menu" then RN:MainMenu(UIParent)
  elseif cmd == "bank" then RN.db.visible = true; RN:SetLocked(false); RN:ToggleWindow(RN.bank, true)
  elseif cmd == "list" or cmd == "library" then RN:ToggleWindow(RN.library)
  elseif cmd == "settings" or cmd == "config" or cmd == "options" then RN:ToggleWindow(RN.settings)
  elseif cmd == "new" then RN:NewNote("spells")
  elseif cmd == "text" then RN:NewNote("text")
  elseif cmd == "reset" then
    RN.db.point = nil
    RestorePoint(RN.panel, "point", function(w) w:SetPoint("CENTER", UIParent, "CENTER", 0, 150) end)
    Print("Panel position reset.")
  else
    Print("/rn (show/hide), lock, unlock, menu, bank, list, settings, new, text, reset")
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("SPELLS_CHANGED")
ev:RegisterEvent("TRAIT_CONFIG_UPDATED")
ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ev:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    RN:InitDB()
  elseif event == "PLAYER_LOGIN" then
    RN:CreatePanel()
    RN:CreateBank()
    RN:CreateLibrary()
    RN:CreateSettings()
    RN:RegisterBlizzardOptions()
    RN:Refresh()
  elseif RN.db then
    RN.bankDirty = true
    if RN.bank and RN.bank:IsShown() then RN:RefreshBank() end
    if event == "SPELLS_CHANGED" and RN.panel then RN:Refresh() end
  end
end)
