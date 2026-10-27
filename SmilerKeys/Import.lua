-- SmilerKeys: import a wishlist from QuestionablyEpic's Upgrade Finder, a Raidbots Droptimizer report,
-- or anything else with Wowhead item links or item IDs in it.
local _, ns = ...
local L = ns.Loot
local T = ns.T

---------------------------------------------------------------- reading the text
-- Returns item IDs in the order they appear (QE and Raidbots list the biggest upgrades first).
local PATTERNS = {
  "item=(%d+)",              -- wowhead.com/item=12345
  "item:(%d+)",              -- in-game links, |Hitem:12345:…
  "items?/(%d+)",            -- …/item/12345 style URLs
  "[^%w_]id=(%d+)",          -- SimC lines: trinket1=,id=12345
  "\"[iI]tem_?[iI][dD]\"%s*:%s*\"?(%d+)",   -- JSON: "itemId": 12345
  "\"id\"%s*:%s*\"?(%d+)",   -- JSON: "id": 12345
}

function L.ParseImport(text)
  local found = {}
  text = " " .. (text or "")
  for _, pat in ipairs(PATTERNS) do
    local pos = 1
    while true do
      local s, e, id = text:find(pat, pos)
      if not s then break end
      id = tonumber(id)
      if id and id >= 1000 and id < 10000000 then found[#found + 1] = { pos = s, id = id } end
      pos = e + 1
    end
  end
  -- nothing recognisable: fall back to bare 5–7 digit numbers, one per line or separated by commas
  if #found == 0 then
    local pos = 1
    while true do
      local s, e, id = text:find("%f[%d](%d%d%d%d%d%d?%d?)%f[%D]", pos)
      if not s then break end
      found[#found + 1] = { pos = s, id = tonumber(id) }
      pos = e + 1
    end
  end
  table.sort(found, function(a, b) return a.pos < b.pos end)
  local ids, seen = {}, {}
  for _, f in ipairs(found) do
    if not seen[f.id] then seen[f.id] = true; ids[#ids + 1] = f.id end
  end
  return ids
end

-- QuestionablyEpic Upgrade Finder report (the JSON behind questionablyepic.com/live/upgradereport/<code>,
-- from questionablyepic.com/api/getUpgradeReport.php?reportID=<code>). Each result looks like
-- {"item":12345,"dropLoc":…,"dropType":…,"dropDifficulty":…,"level":318,"score":…,"rawDiff":…,"percDiff":1.234}
-- Returns { {id, level, pct}, … } best first (one entry per item, its best score), or nil if it isn't a QE report.
function L.ParseQE(text)
  if not text then return nil end
  -- compact form: "SKQE1 Name-Realm id:pct:level,id:pct:level,…" (made from a QE report)
  if text:find("SKQE1", 1, true) then
    local list = {}
    for id, pct, lv in text:gmatch("(%d+):(%-?[%d%.]+):(%d+)") do
      list[#list + 1] = { id = tonumber(id), pct = tonumber(pct), level = tonumber(lv) }
    end
    if #list > 0 then table.sort(list, function(x, y) return x.pct > y.pct end); return list end
  end
  if not text:find("percDiff", 1, true) then return nil end
  text = text:gsub('\\"', '"')                       -- the API sends the report as an escaped JSON string
  local rs = text:find('"results"%s*:%s*%[')
  if not rs then return nil end
  local stop = text:find('"equippedItems"', rs, true) or #text
  local best = {}
  local pos = rs
  while true do
    local a, b, obj = text:find("(%b{})", pos)
    if not a or a > stop then break end
    local id = tonumber(obj:match('"item"%s*:%s*"?(%d+)'))
    local pct = tonumber(obj:match('"percDiff"%s*:%s*"?(%-?[%d%.]+)'))
    local lv = tonumber(obj:match('"level"%s*:%s*"?(%d+)'))
    if id and pct and (not best[id] or pct > best[id].pct) then best[id] = { id = id, pct = pct, level = lv } end
    pos = b + 1
  end
  local list = {}
  for _, r in pairs(best) do list[#list + 1] = r end
  if #list == 0 then return nil end
  table.sort(list, function(x, y) return x.pct > y.pct end)
  return list
end

-- QE scores for this character (kept so the gear guide can rank by them)
function L.QEScores()
  ns.db.qe = ns.db.qe or {}
  return ns.db.qe[ns.selfKey]
end

-- Best matching loot entry for an item ID: prefer real gear slots, and bonus-rollable raid drops
-- when importing as bonus rolls.
local function pick(id, mode)
  local best, score = nil, -1
  for _, it in ipairs(L.items or {}) do
    if it.id == id then
      local s = 0
      if it.slot ~= "other" then s = s + 4 end
      if mode and L.RouteOn(it, mode) then s = s + 2 end
      if not it.offspec then s = s + 1 end
      if s > score then best, score = it, s end
    end
  end
  return best
end

local PER_SLOT = { finger = 4, trinket = 4 }   -- how many QE upgrades go on the wishlist per slot (3 elsewhere)

local function importQE(list, target, markBiS)
  local scores = {}
  for _, r in ipairs(list) do scores[r.id] = r.pct end
  ns.db.qe = ns.db.qe or {}
  ns.db.qe[ns.selfKey] = { scores = scores, at = time and time() or 0 }
  local added, already, missing, perSlot, upgrades = 0, 0, {}, {}, 0
  for _, r in ipairs(list) do
    if r.pct > 0 then
      upgrades = upgrades + 1
      local it = pick(r.id, target.track)
      if not it then
        missing[#missing + 1] = r.id
      else
        local slot = it.slot
        perSlot[slot] = (perSlot[slot] or 0)
        if L.IsWished(r.id) then
          already = already + 1
        elseif perSlot[slot] < (PER_SLOT[slot] or 3) then
          -- QE's item level says which track it simmed; fall back to the track picked in the window
          local tr = r.level and L.TrackOf(r.level)
          local route = (tr and L.RouteOn(it, tr)) or L.RouteOn(it, target.track) or L.Routes(it)[1]
          local t = route and L.TargetFromRoute(route, target.rank) or {}
          if r.level and route and not route.fixed and route.track == tr then
            local _, rank = L.TrackOf(r.level, tr); t.rank = math.max(t.rank or 1, rank or 1)
          end
          t.qe = r.pct
          if L.Add(it, slot, t) then added = added + 1; perSlot[slot] = perSlot[slot] + 1 end
        end
        if markBiS and perSlot[slot] == 1 and not L.IsBiS(r.id) then L.ToggleBiS(r.id) end
      end
    end
  end
  if target.autoPrio ~= false then L.AutoPrioFromQE() end
  return upgrades, added, already, missing, true
end

-- target: { track, rank }, markBiS: boolean
function L.Import(text, target, markBiS)
  local qe = L.ParseQE(text)
  if qe then return importQE(qe, target, markBiS) end
  local ids = L.ParseImport(text)
  local added, already, missing, names = 0, 0, {}, {}
  for _, id in ipairs(ids) do
    local it = pick(id, target.track)
    if not it then
      missing[#missing + 1] = id
    else
      local r = L.RouteOn(it, target.track) or L.Routes(it)[1]
      local t = r and L.TargetFromRoute(r, target.rank) or {}
      if L.IsWished(id) then already = already + 1
      elseif L.Add(it, it.slot, t) then added = added + 1; names[#names + 1] = it.name end
      if markBiS and not L.IsBiS(id) then L.ToggleBiS(id) end
    end
  end
  return #ids, added, already, missing
end

---------------------------------------------------------------- window
local win
local opts = { track = "myth", rank = 1, bis = false, autoPrio = true }

local function build()
  win = CreateFrame("Frame", "SmilerKeysImport", UIParent, "BackdropTemplate")
  win:SetSize(560, 440)
  win:SetPoint("CENTER")
  win:SetFrameStrata("FULLSCREEN")
  win:SetToplevel(true)
  win:SetClampedToScreen(true)
  win:SetMovable(true)
  win:EnableMouse(true)
  win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", win.StartMoving)
  win:SetScript("OnDragStop", win.StopMovingOrSizing)
  T.Panel(win, "void", 0.97, 0.38)
  T.TopLine(win)
  tinsert(UISpecialFrames, "SmilerKeysImport")

  local title = T.Text(win, "label", 14, "amethyst"); title:SetPoint("TOPLEFT", 16, -14); title:SetText("I M P O R T")
  local close = CreateFrame("Button", nil, win); close:SetSize(22, 22); close:SetPoint("TOPRIGHT", -8, -8)
  close.icon = T.IconTex(close, "close", 13, "muted"); close.icon:SetPoint("CENTER")
  close:SetScript("OnClick", function() win:Hide() end)

  local how = T.Text(win, "body", 13, "soft")
  how:SetPoint("TOPLEFT", 16, -46); how:SetWidth(528); how:SetWordWrap(true); how:SetJustifyV("TOP")
  how:SetText("QE Live: paste your upgrade report link here. It turns into the report's data address: copy it (Ctrl-C), open it in your browser, select everything there (Ctrl-A, Ctrl-C) and paste it back here. " ..
    "Also works with a Raidbots Droptimizer report, or any list of Wowhead item links or item IDs.")

  -- paste box
  local box = CreateFrame("Frame", nil, win, "BackdropTemplate")
  box:SetPoint("TOPLEFT", 16, -92); box:SetPoint("TOPRIGHT", -16, -92); box:SetHeight(170)
  T.Panel(box, "card", 0.9, 0.6)
  local sf = CreateFrame("ScrollFrame", nil, box)
  sf:SetPoint("TOPLEFT", 8, -8); sf:SetPoint("BOTTOMRIGHT", -8, 8)
  local eb = CreateFrame("EditBox", nil, sf)
  eb:SetMultiLine(true); eb:SetAutoFocus(false); eb:SetWidth(510); eb:SetMaxLetters(0)
  T.Font(eb, "body", 12)
  eb:SetTextColor(T.RGB("text"))
  eb:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
  eb:SetScript("OnTextChanged", function(s, user)
    local text = s:GetText()
    -- a QE Live link on its own: swap in the address of its data, selected and ready to copy
    local code = not text:find("percDiff", 1, true) and text:match("^%s*%S*questionablyepic%.com/live/upgradereport/(%w+)%S*%s*$")
    if code and user then
      local api = "https://questionablyepic.com/api/getUpgradeReport.php?reportID=" .. code
      s:SetText(api)
      s:HighlightText()
      s:SetCursorPosition(#api)
      s:HighlightText(0, #api)
      win.steps:SetText("1  Ctrl-C to copy this address\n2  Open it in your browser\n3  Ctrl-A, Ctrl-C on that page\n4  Click here and Ctrl-V (it replaces the address)")
      win.steps:Show()
      win.count:SetText("")
      win.waitingQE = true
      return
    end
    if win.waitingQE and text:find("^%s*https://questionablyepic%.com/api/") then return end
    win.waitingQE = nil
    win.steps:Hide()
    win.result:SetText("")
    local qe = L.ParseQE(text)
    if qe then
      local up = 0
      for _, r in ipairs(qe) do if r.pct > 0 then up = up + 1 end end
      win.count:SetText("QE report: " .. up .. " upgrades found")
    else
      local n = #L.ParseImport(text)
      win.count:SetText(n > 0 and (n .. " item" .. (n == 1 and "" or "s") .. " found") or "")
    end
  end)
  sf:SetScrollChild(eb)
  sf:EnableMouseWheel(true)
  sf:SetScript("OnMouseWheel", function(s, d)
    s:SetVerticalScroll(math.max(0, math.min(s:GetVerticalScrollRange(), s:GetVerticalScroll() - d * 40)))
  end)
  box:EnableMouse(true)
  box:SetScript("OnMouseDown", function() eb:SetFocus() end)
  local ph = T.Text(box, "body", 12, "muted"); ph:SetPoint("TOPLEFT", 10, -10); ph:SetText("Ctrl-V to paste")
  eb:SetScript("OnEditFocusGained", function() ph:Hide() end)
  eb:SetScript("OnEditFocusLost", function(s) ph:SetShown(s:GetText() == "") end)
  win.eb = eb
  win.steps = T.Text(box, "strong", 13, "topaz")
  win.steps:SetPoint("BOTTOMLEFT", 10, 10); win.steps:SetWidth(500); win.steps:SetWordWrap(true); win.steps:SetJustifyH("LEFT")
  win.steps:SetSpacing(3)
  win.steps:Hide()

  -- how to add them
  local y = -276
  local l1 = T.Text(win, "label", 13, "muted"); l1:SetPoint("TOPLEFT", 16, y - 5); l1:SetText("TRACK")
  local tracks = {}
  for _, t in ipairs(L.TRACKS) do tracks[#tracks + 1] = { t.key, t.name } end
  local tr = T.Segmented(win, tracks, function() return opts.track end, function(v) opts.track = v end, 24)
  tr:SetPoint("TOPLEFT", 90, y)
  y = y - 32
  local l3 = T.Text(win, "label", 13, "muted"); l3:SetPoint("TOPLEFT", 16, y - 5); l3:SetText("RANK")
  local minus = T.Button(win, "–", 24, 24, function() opts.rank = math.max(1, opts.rank - 1); win.key:SetText(opts.rank .. "/6") end)
  minus:SetPoint("TOPLEFT", 90, y)
  win.key = T.Text(win, "display", 15, "text", "CENTER"); win.key:SetPoint("LEFT", minus, "RIGHT", 2, 0); win.key:SetWidth(40)
  win.key:SetText(opts.rank .. "/6")
  local plus = T.Button(win, "+", 24, 24, function() opts.rank = math.min(6, opts.rank + 1); win.key:SetText(opts.rank .. "/6") end)
  plus:SetPoint("LEFT", win.key, "RIGHT", 2, 0)
  local hint = T.Text(win, "body", 12, "muted"); hint:SetPoint("LEFT", plus, "RIGHT", 12, 0)
  hint:SetText("Items that can't drop on that track use their best way instead.")
  y = y - 34
  local bis = CreateFrame("Button", nil, win, "BackdropTemplate")
  bis:SetSize(18, 18); bis:SetPoint("TOPLEFT", 16, y)
  T.Panel(bis, "raised", 1, 0.6)
  bis.tick = T.IconTex(bis, "tick", 14, "void"); bis.tick:SetPoint("CENTER")
  local bl = T.Text(win, "body", 13, "text"); bl:SetPoint("LEFT", bis, "RIGHT", 10, 0)
  bl:SetText("Mark everything imported as best in slot")
  local function syncBis()
    bis:SetBackdropColor(T.RGB(opts.bis and "amethyst" or "raised"))
    bis.tick:SetShown(opts.bis)
  end
  bis:SetScript("OnClick", function() opts.bis = not opts.bis; syncBis() end)
  syncBis()
  local ap = CreateFrame("Button", nil, win, "BackdropTemplate")
  ap:SetSize(18, 18); ap:SetPoint("TOPLEFT", 300, y)
  T.Panel(ap, "raised", 1, 0.6)
  ap.tick = T.IconTex(ap, "tick", 14, "void"); ap.tick:SetPoint("CENTER")
  local al = T.Text(win, "body", 13, "text"); al:SetPoint("LEFT", ap, "RIGHT", 10, 0)
  al:SetText("QE report: set priorities 1–15")
  local function syncAp()
    ap:SetBackdropColor(T.RGB(opts.autoPrio and "amethyst" or "raised"))
    ap.tick:SetShown(opts.autoPrio)
  end
  ap:SetScript("OnClick", function() opts.autoPrio = not opts.autoPrio; syncAp() end)
  ap:SetScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_TOP")
    GameTooltip:AddLine("Priorities from QE", T.RGB("amethyst"))
    GameTooltip:AddLine("Your wishlist items with the biggest QE upgrade % get priority 1, 2, 3… up to 15. Priorities you set yourself are kept, and re-importing updates only the ones QE set.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  ap:SetScript("OnLeave", GameTooltip_Hide)
  syncAp()

  -- footer
  win.count = T.Text(win, "display", 14, "soft"); win.count:SetPoint("BOTTOMLEFT", 16, 22)
  win.result = T.Text(win, "body", 12, "muted"); win.result:SetPoint("BOTTOMLEFT", 16, 8)
  win.result:SetWidth(340); win.result:SetWordWrap(true)
  local go = T.Button(win, "Add to wishlist", 140, 28, nil, "primary")
  go:SetPoint("BOTTOMRIGHT", -16, 14)
  local cancel = T.Button(win, "Close", 80, 28, function() win:Hide() end)
  cancel:SetPoint("RIGHT", go, "LEFT", -8, 0)

  local tries = 0
  local function run()
    if not L.items then
      if tries < 6 then
        tries = tries + 1
        win.result:SetText("Reading the loot tables first…")
        L.Refresh(true)
        C_Timer.After(2, run)
      else
        win.result:SetText("Couldn't read the loot tables. Close the Adventure Guide, leave combat and try again.")
      end
      return
    end
    tries = 0
    local total, added, already, missing, isQE = L.Import(eb:GetText(), { track = opts.track, rank = opts.rank, autoPrio = opts.autoPrio }, opts.bis)
    local code = eb:GetText():match("questionablyepic%.com/live/upgradereport/(%w+)")
    if total == 0 and code then
      win.result:SetText("Add-ons can't open web pages. In your browser open questionablyepic.com/api/getUpgradeReport.php?reportID=" .. code .. ", press Ctrl+A, Ctrl+C, and paste that here.")
      win.result:SetTextColor(T.RGB("topaz"))
      return
    end
    if total == 0 then
      win.result:SetText("No item IDs or Wowhead links found in that text.")
      win.result:SetTextColor(T.RGB("ruby"))
      return
    end
    win.count:SetText("")                      -- the result line takes its place
    local parts = { added .. " added" .. (isQE and " (top 3 per slot, 4 for rings and trinkets)" or "") }
    if already > 0 then parts[#parts + 1] = already .. " already on your list" end
    if #missing > 0 then parts[#parts + 1] = #missing .. " not in this season's loot for your spec" end
    win.result:SetText(table.concat(parts, " · "))
    win.result:SetTextColor(T.RGB(added > 0 and "emerald" or "muted"))
    if #missing > 0 then ns.Print("Import: not in the loot tables: " .. table.concat(missing, ", ", 1, math.min(#missing, 12))) end
    if ns.LootUI_Refresh then ns.LootUI_Refresh() end
  end
  go:SetScript("OnClick", run)
  win:Hide()
end

function ns.ImportOpen()
  if not win then build() end
  win.result:SetText("")
  win:Show()
  win:Raise()
  win.eb:SetFocus()
end
