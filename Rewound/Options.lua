-- Rewound: settings window (Crystal Ball theme) + entry in the game's AddOns settings
local _, ns = ...
local C = ns.C

local W, H = 500, 500
local PAGE_W = W - 40
local LABEL_W = 120

local win
local tabs, pages, refreshers = {}, {}, {}
local currentTab = "records"

---------------------------------------------------------------- widgets
local function fs(parent, size, color, justify, font)
  local f = parent:CreateFontString(nil, "OVERLAY")
  f:SetFont(font or ns.NUM_FONT, size, "")
  f:SetTextColor(unpack(color or C.text))
  f:SetJustifyH(justify or "LEFT")
  f:SetShadowOffset(1, -1)
  f:SetShadowColor(0, 0, 0, 0.85)
  return f
end

local function Button(parent, label, w, onClick, h)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w, h or 20)
  b:SetBackdrop(ns.BACKDROP)
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

local function Tip(frame, text)
  frame:HookScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
    GameTooltip:AddLine(text, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  frame:HookScript("OnLeave", GameTooltip_Hide)
end

local function changed()
  ns.ApplyToastSettings()
  ns.RefreshOptions()
end

local function Header(page, text, y)
  local f = fs(page, 11, C.accent, "LEFT", ns.FONT)
  f:SetPoint("TOPLEFT", 0, y)
  f:SetText(text)
  local line = page:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(unpack(C.edge))
  line:SetHeight(1)
  line:SetPoint("LEFT", f, "RIGHT", 8, 0)
  line:SetPoint("RIGHT", page, "RIGHT")
  return f
end

local function Note(page, text, x, y, w)
  local f = fs(page, 11, C.dim)
  f:SetPoint("TOPLEFT", x, y)
  f:SetWidth(w or PAGE_W - x)
  f:SetWordWrap(true)
  f:SetText(text)
  return f
end

-- Checkbox: filled inner square when on (shape, not just colour)
local function Check(page, label, x, y, get, set, tip)
  local b = CreateFrame("Button", nil, page, "BackdropTemplate")
  b:SetSize(16, 16)
  b:SetPoint("TOPLEFT", x, y)
  b:SetBackdrop(ns.BACKDROP)
  b:SetBackdropColor(unpack(C.panel))
  b:SetBackdropBorderColor(unpack(C.edge))
  b.mark = b:CreateTexture(nil, "ARTWORK")
  b.mark:SetPoint("TOPLEFT", 3, -3)
  b.mark:SetPoint("BOTTOMRIGHT", -3, 3)
  b.mark:SetColorTexture(unpack(C.accent))
  b.label = fs(page, 12, C.text)
  b.label:SetPoint("LEFT", b, "RIGHT", 8, 0)
  b.label:SetText(label)
  local function sync()
    local v = get() and true or false
    b.mark:SetShown(v)
    b.label:SetTextColor(unpack(v and C.text or C.dim))
    b:SetHitRectInsets(0, -(b.label:GetStringWidth() + 10), 0, 0)
  end
  b:SetScript("OnClick", function() set(not get()); changed() end)
  b:SetScript("OnEnter", function(s) s:SetBackdropBorderColor(unpack(C.border)) end)
  b:SetScript("OnLeave", function(s) s:SetBackdropBorderColor(unpack(C.edge)) end)
  if tip then Tip(b, tip) end
  refreshers[#refreshers + 1] = sync
  return b
end

-- Segmented choice: selected button is filled and outlined
local function Choice(page, label, x, y, options, get, set, bw, onPick)
  local l = fs(page, 12, C.dim)
  l:SetPoint("TOPLEFT", x, y - 3)
  l:SetText(label)
  local btns, prev = {}, nil
  for i, o in ipairs(options) do
    local b = Button(page, o[2], bw or 64, function()
      set(o[1]); if onPick then onPick(o[1]) end; changed()
    end)
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", x + LABEL_W, y) end
    b.value = o[1]
    btns[i], prev = b, b
  end
  refreshers[#refreshers + 1] = function()
    local v = get()
    for _, b in ipairs(btns) do
      b.sel = b.value == v
      b:SetBackdropColor(unpack(b.sel and C.sel or C.panel))
      b:SetBackdropBorderColor(unpack(b.sel and C.border or C.edge))
      b.text:SetTextColor(unpack(b.sel and C.crystal or C.dim))
    end
  end
  return btns
end

local function Slider(page, label, x, y, minV, maxV, step, get, set, show)
  local l = fs(page, 12, C.dim)
  l:SetPoint("TOPLEFT", x, y - 2)
  l:SetText(label)
  local s = CreateFrame("Slider", nil, page, "BackdropTemplate")
  s:SetOrientation("HORIZONTAL")
  s:SetSize(220, 10)
  s:SetPoint("TOPLEFT", x + LABEL_W, y - 4)
  s:SetBackdrop(ns.BACKDROP)
  s:SetBackdropColor(unpack(C.panel))
  s:SetBackdropBorderColor(unpack(C.edge))
  s:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
  local th = s:GetThumbTexture()
  th:SetSize(8, 16)
  th:SetVertexColor(unpack(C.accent))
  s:SetMinMaxValues(minV, maxV)
  s:SetValueStep(step)
  s:SetObeyStepOnDrag(true)
  local v = fs(page, 12, C.text)
  v:SetPoint("LEFT", s, "RIGHT", 10, 0)
  local lock = false
  local function snap(val) return math.floor(val / step + 0.5) * step end
  s:SetScript("OnValueChanged", function(_, val)
    if lock then return end
    val = snap(val)
    set(val)
    v:SetText(show(val))
    ns.ApplyToastSettings()
  end)
  s:EnableMouseWheel(true)
  s:SetScript("OnMouseWheel", function(self, d)
    self:SetValue(math.max(minV, math.min(maxV, self:GetValue() + d * step)))
  end)
  refreshers[#refreshers + 1] = function()
    lock = true
    s:SetValue(get())
    v:SetText(show(get()))
    lock = false
  end
  return s
end

local function Edit(page, x, y, w, get, set, onType)
  local e = CreateFrame("EditBox", nil, page, "BackdropTemplate")
  e:SetSize(w, 22)
  e:SetPoint("TOPLEFT", x, y)
  e:SetBackdrop(ns.BACKDROP)
  e:SetBackdropColor(unpack(C.panel))
  e:SetBackdropBorderColor(unpack(C.edge))
  e:SetFont(ns.NUM_FONT, 13, "")
  e:SetTextColor(unpack(C.text))
  e:SetTextInsets(6, 6, 0, 0)
  e:SetAutoFocus(false)
  e:SetMaxLetters(200)
  if get then
    e:SetScript("OnEnterPressed", function(s) set(s:GetText()); s:ClearFocus(); changed() end)
    e:SetScript("OnEscapePressed", function(s) s:SetText(get() or ""); s:ClearFocus() end)
    e:SetScript("OnEditFocusLost", function(s) set(s:GetText()); s:SetBackdropBorderColor(unpack(C.edge)) end)
    refreshers[#refreshers + 1] = function() if not e:HasFocus() then e:SetText(get() or "") end end
  else
    e:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    e:SetScript("OnEditFocusLost", function(s) s:SetBackdropBorderColor(unpack(C.edge)) end)
  end
  e:SetScript("OnEditFocusGained", function(s) s:SetBackdropBorderColor(unpack(C.border)) end)
  if onType then e:SetScript("OnTextChanged", function(s) onType(s:GetText()) end) end
  return e
end

---------------------------------------------------------------- page: records
local function BuildRecords(page)
  local icon = page:CreateTexture(nil, "ARTWORK")
  icon:SetSize(52, 52)
  icon:SetPoint("TOPLEFT", 0, -2)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  icon:SetTexture(C_Spell.GetSpellTexture(ns.REWIND))
  local cap = fs(page, 11, C.accent, "LEFT", ns.FONT)
  cap:SetPoint("TOPLEFT", icon, "TOPRIGHT", 14, 0)
  cap:SetText("BEST REWIND")
  local big = fs(page, 30, C.crystal)
  big:SetPoint("LEFT", icon, "RIGHT", 14, -2)
  local sub = fs(page, 12, C.dim)
  sub:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 14, 0)
  sub:SetWidth(PAGE_W - 70)
  sub:SetWordWrap(false)

  Header(page, "BY CONTENT", -72)
  local kindRows = {}
  for i, k in ipairs(ns.KINDS) do
    local y = -92 - (i - 1) * 18
    local l = fs(page, 12, C.dim); l:SetPoint("TOPLEFT", 0, y); l:SetText(ns.KIND_LABEL[k])
    local a = fs(page, 13, C.text, "RIGHT"); a:SetPoint("TOPLEFT", 70, y); a:SetWidth(60)
    local w = fs(page, 12, C.dim); w:SetPoint("TOPLEFT", 146, y); w:SetWidth(PAGE_W - 146); w:SetWordWrap(false)
    kindRows[k] = { a = a, w = w }
  end

  Header(page, "RECENT", -172)
  local hist = {}
  for i = 1, 10 do
    local y = -192 - (i - 1) * 17
    local a = fs(page, 13, C.text, "RIGHT"); a:SetPoint("TOPLEFT", 0, y); a:SetWidth(56)
    local n = fs(page, 11, C.dim); n:SetPoint("TOPLEFT", 64, y - 1); n:SetWidth(60)
    local tag = fs(page, 11, C.accent); tag:SetPoint("TOPLEFT", 124, y - 1); tag:SetWidth(66)
    local w = fs(page, 12, C.dim); w:SetPoint("TOPLEFT", 194, y); w:SetWidth(PAGE_W - 250); w:SetWordWrap(false)
    local d = fs(page, 11, C.faint, "RIGHT"); d:SetPoint("TOPRIGHT", 0, y - 1); d:SetWidth(54)
    hist[i] = { a = a, n = n, tag = tag, w = w, d = d }
  end
  local empty = fs(page, 12, C.dim)
  empty:SetPoint("TOPLEFT", 0, -194)
  empty:SetText("Nothing yet – cast Rewind in Preservation spec and finish the fight.")

  local reset = Button(page, "Reset all records", 130, function() StaticPopup_Show("REWOUND_RESET") end)
  reset:SetPoint("BOTTOMRIGHT", 0, 0)
  local clear = Button(page, "Clear history", 110, function() ns.ClearHistory() end)
  clear:SetPoint("RIGHT", reset, "LEFT", -6, 0)
  local chat = Button(page, "Print to chat", 110, function() ns.PrintStats() end)
  chat:SetPoint("BOTTOMLEFT", 0, 0)

  refreshers[#refreshers + 1] = function()
    local db = ns.db
    local b = db.best
    if b then
      big:SetText(ns.fmt(b.amount) .. (b.casts > 1 and ("  |cff8f82b3avg of " .. b.casts .. "|r") or ""))
      sub:SetText((b.where or "?") .. "  ·  " .. date("%d %b %Y", b.when))
    else
      big:SetText("—")
      sub:SetText("No Rewind recorded yet")
    end
    for _, k in ipairs(ns.KINDS) do
      local e, r = db.bestBy[k], kindRows[k]
      r.a:SetText(e and ns.fmt(e.amount) or "—")
      r.w:SetText(e and e.where or "")
    end
    empty:SetShown(#db.history == 0)
    for i, h in ipairs(hist) do
      local e = db.history[i]
      for _, f in pairs(h) do f:SetShown(e ~= nil) end
      if e then
        h.a:SetText(ns.fmt(e.amount))
        h.n:SetText(e.casts > 1 and ("avg of " .. e.casts) or "")
        h.tag:SetText(e.record and "RECORD" or (e.kindBest and (ns.KIND_LABEL[e.kind]:upper() .. " BEST")) or "")
        h.w:SetText(e.where or "?")
        h.d:SetText(date("%d %b", e.when))
      end
    end
  end
end

---------------------------------------------------------------- page: announce
local SAMPLE = function()
  return ns.TemplateValues(1480000, 1480000, 1, { amount = 1250000 }, "Ara-Kara, City of Echoes +12", nil)
end

local function BuildAnnounce(page)
  local S = function() return ns.S.announce end
  Check(page, "Announce new records in chat", 0, 0,
    function() return S().enabled end, function(v) S().enabled = v end,
    "Off: records are still saved and shown on screen, and the message only prints to you.")

  Choice(page, "Channel", 0, -30,
    { { "auto", "Auto" }, { "party", "Party" }, { "raid", "Raid" }, { "guild", "Guild" }, { "self", "Only me" } },
    function() return S().channel end, function(v) S().channel = v end, 60)
  Note(page, "Auto uses instance, raid or party chat, whichever you're in. Messages wait until an active key or boss ends, then send. If the channel isn't available, the message prints to you.",
    LABEL_W, -56, PAGE_W - LABEL_W)

  local ml = fs(page, 12, C.dim); ml:SetPoint("TOPLEFT", 0, -102); ml:SetText("Message")
  local preview = fs(page, 12, C.text)
  local function renderPreview(text)
    preview:SetText(ns.FillTemplate(text, SAMPLE()))
  end
  local edit = Edit(page, 0, -120, PAGE_W,
    function() return S().template end,
    function(v) S().template = (v and v ~= "") and v or ns.DEFAULT_TEMPLATE end,
    renderPreview)
  local def = Button(page, "Default", 70, function()
    S().template = ns.DEFAULT_TEMPLATE; edit:ClearFocus(); changed()
  end, 18)
  def:SetPoint("TOPRIGHT", 0, -100)
  Note(page, "{amount}  {avg}  {prev}  {gain}  {where}  {casts}  {total}  {kind}", 0, -148)
  local pl = fs(page, 12, C.dim); pl:SetPoint("TOPLEFT", 0, -170); pl:SetText("Preview")
  preview:SetPoint("TOPLEFT", LABEL_W, -170)
  preview:SetWidth(PAGE_W - LABEL_W)
  preview:SetWordWrap(true)
  refreshers[#refreshers + 1] = function() renderPreview(S().template) end

  Slider(page, "Min. improvement", 0, -214, 0, 50, 1,
    function() return S().minGain or 0 end, function(v) S().minGain = v end,
    function(v) return v == 0 and "any" or ("+" .. v .. "%") end)
  Note(page, "Smaller records are still saved and shown, just not announced.", LABEL_W, -232, PAGE_W - LABEL_W)

  Check(page, "Also announce dungeon and raid bests", 0, -262,
    function() return S().categories end, function(v) S().categories = v end,
    "Announces a new best for that type of content even when it isn't your overall record. {kind} becomes \"Dungeon \" or \"Raid \".")

  local test = Button(page, "Preview in chat", 130, function()
    ns.Print(ns.FillTemplate(S().template, SAMPLE()))
  end)
  test:SetPoint("BOTTOMLEFT", 0, 0)
  Tip(test, "Prints the message to you only.")
end

---------------------------------------------------------------- page: display
local function BuildDisplay(page)
  local T = function() return ns.S.toast end
  Header(page, "TOAST", 0)
  Check(page, "Show a toast for a new record", 0, -20,
    function() return T().record end, function(v) T().record = v end)
  Check(page, "Show a small toast for every Rewind", 0, -44,
    function() return T().every end, function(v) T().every = v end,
    "Shows the result of each Rewind that isn't a record.")
  Check(page, "Play a sound for a new record", 0, -68,
    function() return T().sound end, function(v) T().sound = v end)

  local opts = {}
  for _, s in ipairs(ns.SOUNDS) do
    if SOUNDKIT and SOUNDKIT[s[3]] then opts[#opts + 1] = { s[1], s[2] } end
  end
  if #opts > 0 then
    Choice(page, "Sound", 0, -96, opts,
      function() return T().soundKey end, function(v) T().soundKey = v end, 78,
      function() ns.PlayRecordSound() end)
  end

  Slider(page, "Size", 0, -132, 0.6, 1.6, 0.05,
    function() if Smiler and Smiler.db then return Smiler.db.toastScale or 1 end return T().scale or 1 end,
    function(v) if Smiler and Smiler.SetToastScale then Smiler:SetToastScale(v) else T().scale = v end end,
    function(v) return string.format("%d%%", v * 100 + 0.5) end)
  Slider(page, "Stays for", 0, -160, 2, 12, 0.5,
    function() return T().duration or 4.5 end, function(v) T().duration = v end,
    function(v) return string.format("%.1f s", v) end)

  Header(page, "POSITION", -196)
  local move
  move = Button(page, "Move toast", 110, function()
    ns.SetToastUnlocked(not ns.IsToastUnlocked())
    changed()
  end)
  move:SetPoint("TOPLEFT", 0, -218)
  local reset = Button(page, "Reset position", 120, function() ns.ResetToastPosition() end)
  reset:SetPoint("LEFT", move, "RIGHT", 6, 0)
  Note(page, "Move toast shows it where it will appear. Drag it, then press Lock toast.", 0, -246)
  refreshers[#refreshers + 1] = function()
    local on = ns.IsToastUnlocked()
    move.text:SetText(on and "Lock toast" or "Move toast")
    move.sel = on
    move:SetBackdropColor(unpack(on and C.sel or C.panel))
    move:SetBackdropBorderColor(unpack(on and C.border or C.edge))
  end

  local test = Button(page, "Test toast", 110, function()
    if ns.IsToastUnlocked() then ns.SetToastUnlocked(false) end
    ns.TestToast(); changed()
  end)
  test:SetPoint("BOTTOMLEFT", 0, 0)
end

---------------------------------------------------------------- page: tracking
local function BuildTracking(page)
  local K = function() return ns.S.track end
  Header(page, "TRACK IN", 0)
  local spots = { mplus = { 0, -20 }, raid = { 230, -20 }, other = { 0, -44 } }
  local names = { mplus = "Dungeons (M+ and others)", raid = "Raids", other = "Everything else" }
  for _, k in ipairs(ns.KINDS) do
    Check(page, names[k], spots[k][1], spots[k][2],
      function() return K()[k] end, function(v) K()[k] = v end)
  end
  Check(page, "Only while I'm in a group", 0, -70,
    function() return K().needGroup end, function(v) K().needGroup = v end,
    "Skips solo play, such as testing on a dummy.")

  Header(page, "COUNTED SPELLS", -104)
  Note(page, "Healing from these spell IDs counts as Rewind.", 0, -122)
  local spellRows = {}
  for i = 1, 4 do
    local y = -142 - (i - 1) * 22
    local r = CreateFrame("Frame", nil, page)
    r:SetSize(PAGE_W, 20)
    r:SetPoint("TOPLEFT", 0, y)
    r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(18, 18); r.icon:SetPoint("LEFT")
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.name = fs(r, 12, C.text); r.name:SetPoint("LEFT", 26, 0); r.name:SetWidth(240); r.name:SetWordWrap(false)
    r.id = fs(r, 11, C.dim); r.id:SetPoint("LEFT", 272, 0)
    r.del = Button(r, "Remove", 70, function()
      ns.db.spellIDs[r.spellID] = nil; changed()
    end, 18)
    r.del:SetPoint("RIGHT")
    spellRows[i] = r
  end
  local addBox = Edit(page, 0, -234, 110)
  addBox:SetNumeric(true)
  local add = Button(page, "Add spell ID", 110, function()
    local id = tonumber(addBox:GetText())
    if id and id > 0 then ns.db.spellIDs[id] = true; addBox:SetText(""); addBox:ClearFocus(); changed() end
  end, 22)
  add:SetPoint("LEFT", addBox, "RIGHT", 6, 0)
  addBox:SetScript("OnEnterPressed", function() add:Click() end)

  Header(page, "LAST FIGHT", -270)
  local status = fs(page, 11, C.dim)
  status:SetPoint("TOPLEFT", 0, -288)
  status:SetWidth(PAGE_W - 90)
  local refresh = Button(page, "Refresh", 80, function()
    local list, err = ns.ReadHealing()
    if list then ns.lastFight = list; ns.lastFightErr = nil else ns.lastFightErr = err end
    changed()
  end, 18)
  refresh:SetPoint("TOPRIGHT", 0, -284)
  local fightRows = {}
  for i = 1, 5 do
    local y = -306 - (i - 1) * 20
    local r = CreateFrame("Frame", nil, page)
    r:SetSize(PAGE_W, 18)
    r:SetPoint("TOPLEFT", 0, y)
    r.amt = fs(r, 12, C.text, "RIGHT"); r.amt:SetPoint("LEFT"); r.amt:SetWidth(56)
    r.name = fs(r, 12, C.text); r.name:SetPoint("LEFT", 66, 0); r.name:SetWidth(220); r.name:SetWordWrap(false)
    r.id = fs(r, 11, C.dim); r.id:SetPoint("LEFT", 292, 0)
    r.toggle = Button(r, "Count", 70, function()
      local ids = ns.db.spellIDs
      ids[r.spellID] = (not ids[r.spellID]) or nil
      changed()
    end, 18)
    r.toggle:SetPoint("RIGHT")
    fightRows[i] = r
  end

  refreshers[#refreshers + 1] = function()
    local ids = {}
    for id in pairs(ns.db.spellIDs) do ids[#ids + 1] = id end
    table.sort(ids)
    for i, r in ipairs(spellRows) do
      local id = ids[i]
      r:SetShown(id ~= nil)
      if id then
        r.spellID = id
        r.icon:SetTexture(C_Spell.GetSpellTexture(id) or 134400)
        r.name:SetText(C_Spell.GetSpellName(id) or "Unknown spell")
        r.id:SetText(id)
      end
    end
    local list = ns.lastFight
    if list and #list > 0 then
      status:SetText("Your healing by spell. Count anything that's really Rewind.")
    else
      status:SetText(ns.lastFightErr or "Finish a fight, then press Refresh.")
    end
    for i, r in ipairs(fightRows) do
      local sp = list and list[i]
      r:SetShown(sp ~= nil)
      if sp then
        r.spellID = sp.id
        r.amt:SetText(ns.fmt(sp.amount))
        r.name:SetText(C_Spell.GetSpellName(sp.id) or "Unknown spell")
        r.id:SetText(sp.id)
        local on = ns.db.spellIDs[sp.id]
        r.toggle.text:SetText(on and "Counted" or "Count")
        r.toggle.sel = on
        r.toggle:SetBackdropColor(unpack(on and C.sel or C.panel))
        r.toggle:SetBackdropBorderColor(unpack(on and C.border or C.edge))
        r.toggle.text:SetTextColor(unpack(on and C.crystal or C.text))
      end
    end
  end
end

---------------------------------------------------------------- window
local TABS = {
  { "records",  "Records",  BuildRecords },
  { "announce", "Announce", BuildAnnounce },
  { "display",  "Display",  BuildDisplay },
  { "tracking", "Tracking", BuildTracking },
}

local function SelectTab(key)
  currentTab = key
  for k, p in pairs(pages) do p:SetShown(k == key) end
  for k, t in pairs(tabs) do
    local on = k == key
    t.sel = on
    t:SetBackdropColor(unpack(on and C.sel or C.panel))
    t:SetBackdropBorderColor(unpack(on and C.border or C.edge))
    t.text:SetTextColor(unpack(on and C.crystal or C.dim))
  end
end

local function CreateWindow()
  win = CreateFrame("Frame", "RewoundOptions", UIParent, "BackdropTemplate")
  win:SetSize(W, H)
  win:SetPoint("CENTER")
  win:SetFrameStrata("DIALOG")
  win:SetClampedToScreen(true)
  win:SetMovable(true)
  win:EnableMouse(true)
  win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", win.StartMoving)
  win:SetScript("OnDragStop", win.StopMovingOrSizing)
  win:SetBackdrop(ns.BACKDROP)
  win:SetBackdropColor(unpack(C.bg))
  win:SetBackdropBorderColor(unpack(C.border))
  tinsert(UISpecialFrames, "RewoundOptions")

  local line = win:CreateTexture(nil, "ARTWORK")
  line:SetPoint("TOPLEFT", 1, -1); line:SetPoint("TOPRIGHT", -1, -1); line:SetHeight(2)
  line:SetColorTexture(1, 1, 1, 1)
  line:SetGradient("HORIZONTAL", CreateColor(0.40, 0.24, 0.84, 1), CreateColor(0.92, 0.85, 1, 1))

  local title = fs(win, 13, C.accent, "LEFT", ns.FONT)
  title:SetPoint("TOPLEFT", 14, -13)
  title:SetText("R E W O U N D")
  local ver = fs(win, 11, C.faint)
  ver:SetPoint("LEFT", title, "RIGHT", 10, 0)
  ver:SetText("v" .. ns.VERSION)
  local close = Button(win, "×", 22, function() win:Hide() end, 20)
  close:SetPoint("TOPRIGHT", -8, -8)

  local prev
  for _, t in ipairs(TABS) do
    local b = Button(win, t[2], 100, function() SelectTab(t[1]) end, 22)
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", 14, -38) end
    tabs[t[1]], prev = b, b
    local page = CreateFrame("Frame", nil, win)
    page:SetPoint("TOPLEFT", 20, -76)
    page:SetPoint("BOTTOMRIGHT", -20, 16)
    page:Hide()
    pages[t[1]] = page
    t[3](page)
  end
  local rule = win:CreateTexture(nil, "ARTWORK")
  rule:SetColorTexture(unpack(C.edge))
  rule:SetHeight(1)
  rule:SetPoint("TOPLEFT", 14, -64)
  rule:SetPoint("TOPRIGHT", -14, -64)

  win:SetScript("OnShow", function() ns.RefreshOptions() end)
  SelectTab(currentTab)
  win:Hide()
end

function ns.RefreshOptions()
  if not win or not win:IsShown() then return end
  for _, f in ipairs(refreshers) do f() end
end

-- inside the Smiler settings window: the same four pages behind a segmented control
local function BuildInto(body, Wd)
  local holder = CreateFrame("Frame", nil, body)
  holder:SetPoint("TOPLEFT", 0, 0); holder:SetPoint("BOTTOMRIGHT", 0, 0)
  local seg = Wd.Segmented(holder, { { "records", "Records" }, { "announce", "Announce" }, { "display", "Display" }, { "tracking", "Tracking" } },
    function() return currentTab end,
    function(k) currentTab = k; for key, p in pairs(pages) do p:SetShown(key == k) end; ns.RefreshOptions() end)
  seg:SetPoint("TOPLEFT", 0, 0)
  for _, t in ipairs(TABS) do
    local page = CreateFrame("Frame", nil, holder)
    page:SetPoint("TOPLEFT", 0, -42)
    page:SetSize(PAGE_W, 360)
    page:SetShown(t[1] == currentTab)
    pages[t[1]] = page
    t[3](page)
  end
  win = holder   -- RefreshOptions checks win:IsShown()
  holder:SetScript("OnShow", function() ns.RefreshOptions() end)
  return { note = "Changes save as you make them. /rewound still works.",
           footer = {
             { "Boss bests", function() if ns.Extra and ns.Extra.Open then ns.Extra.Open() end end, nil, 110 },
             { "Test toast", function() ns.TestToast() end, "primary", 110 },
           } }
end

if Smiler and Smiler.RegisterSettings then
  Smiler:RegisterSettings("Rewound", BuildInto)
end

function ns.OpenOptions(tab)
  if Smiler and Smiler.OpenSettings then
    if tab then currentTab = tab end
    Smiler:OpenSettings("Rewound")
    if tab and pages[tab] then for k, p in pairs(pages) do p:SetShown(k == tab) end end
    return
  end
  if not win then CreateWindow() end
  if tab then SelectTab(tab) end
  if win:IsShown() and not tab then win:Hide() else win:Show(); ns.RefreshOptions() end
end

---------------------------------------------------------------- game Settings > AddOns entry
do
  local panel = CreateFrame("Frame")
  panel.name = "Rewound"
  local t = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  t:SetPoint("TOPLEFT", 16, -16)
  t:SetText("Rewound")
  local d = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -8)
  d:SetText("Preservation Evoker Rewind records. Settings open in their own window.")
  local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  b:SetSize(220, 26)
  b:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -14)
  b:SetText("Open Rewound settings")
  b:SetScript("OnClick", function()
    if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    ns.OpenOptions("records")
  end)
  if Settings and Settings.RegisterCanvasLayoutCategory then
    pcall(function()
      local cat = Settings.RegisterCanvasLayoutCategory(panel, "Rewound")
      Settings.RegisterAddOnCategory(cat)
    end)
  end
end
