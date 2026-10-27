-- SmilerStash, part 2: the loot currencies (each row can be switched off), and a heads-up when you can upgrade.
-- Upgrades: 20 Mistcrests a rank (10 on an alt with the warband discount); Myth 6/6 weapons, trinkets and
-- necklaces go further with 10 Venomstones a step. Read from your equipped items' "Upgrade Level" line.
local ADDON, ns = ...
local S = Smiler

---------------------------------------------------------------- the rows
-- id = known ID (checked against the name); name = what to look for in the game's currency names
ns.STOCK = {
  { key = "stone",    label = "Venomstones",      item = 280562, tip = "10 upgrade a Myth 6/6 weapon, trinket or necklace one step (up to 9/6)." },
  { key = "keys",     label = "Coffer keys",      cur = 3028, name = "Restored Coffer Key", shards = "Coffer Key Shard", shardsId = 3310,
    tip = "100 shards make a key. One key per Bountiful Coffer." },
  { key = "catalyst", label = "Catalyst charges", name = "Venomblight Manaflux", tip = "Crystallized Venomblight Manaflux: one charge turns a piece into its tier version at the Catalyst." },
  { key = "sparks",   label = "Sparks",           item = 274476, dust = 3509, dustName = "Tidal Spark Dust",
    tip = "Spark of Tides in your bags, and Tidal Spark Dust: how many you've earned this season against the cap (it goes up by one a week)." },
  { key = "rolls",    label = "Bonus rolls",      cur = 3418, name = "Nebulous Voidcore", tip = "Nebulous Voidcores: bonus rolls on Venomous Abyss bosses and Mythic+ completions." },
  { key = "crests",   label = "Mistcrests",       crests = { "Adventurer", "Veteran", "Champion", "Hero", "Myth" },
    tip = "20 a rank on that track (10 on alts with the warband discount). The cap goes up by 100 a week." },
  { key = "soul",     label = "Myth soul fragments", item = 285065, need = 3, tip = "Mythical Soul Fragments from delves: 3 buy a Myth item. Weekly gated." },
}
local TRACK_ORDER = { Adventurer = 1, Veteran = 2, Champion = 3, Hero = 4, Myth = 5 }
local STONE_SLOTS = { [2] = true, [13] = true, [14] = true, [16] = true, [17] = true }   -- neck, trinkets, weapons
local SLOT_NAME = { [1] = "Head", [2] = "Neck", [3] = "Shoulder", [5] = "Chest", [6] = "Waist", [7] = "Legs", [8] = "Feet",
                    [9] = "Wrist", [10] = "Hands", [11] = "Ring", [12] = "Ring", [13] = "Trinket", [14] = "Trinket",
                    [15] = "Back", [16] = "Main hand", [17] = "Off hand" }

local function secret(v) return issecretvalue and issecretvalue(v) or false end
local function itemCount(id)
  if not (C_Item and C_Item.GetItemCount) then return 0 end
  local ok, n = pcall(C_Item.GetItemCount, id, true, false, true, true)
  return (ok and type(n) == "number" and not secret(n)) and n or 0
end

---------------------------------------------------------------- currency lookup by name (once a session)
local byName
local function index()
  if byName then return byName end
  byName = {}
  if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) then return byName end
  for id = 2800, 3900 do
    local info = C_CurrencyInfo.GetCurrencyInfo(id)
    if info and info.name and info.name ~= "" then byName[#byName + 1] = { id = id, name = info.name } end
  end
  return byName
end
local function find(...)
  local want = { ... }
  for _, e in ipairs(index()) do
    local ok = true
    for _, w in ipairs(want) do if not e.name:find(w, 1, true) then ok = false; break end end
    if ok then return e.id end
  end
end
local resolved = {}
local function curId(known, ...)
  local key = (known or 0) .. "|" .. table.concat({ ... }, "|")
  if resolved[key] ~= nil then return resolved[key] or nil end
  local want = select(1, ...)
  local info = known and C_CurrencyInfo.GetCurrencyInfo(known)
  if info and info.name and (not want or info.name:find(want, 1, true)) then resolved[key] = known; return known end
  local id = want and find(...)
  resolved[key] = id or false
  return id
end
local function cur(id)
  if not id then return nil end
  local i = C_CurrencyInfo.GetCurrencyInfo(id)
  if not i or not i.name or i.name == "" then return nil end
  return i
end
-- "340 / 600 earned" style cap text, or nil when there's no cap
local function capText(i)
  if not i then return nil end
  if i.useTotalEarnedForMaxQty and (i.maxQuantity or 0) > 0 then return string.format("%d / %d earned", i.totalEarned or 0, i.maxQuantity) end
  if (i.maxWeeklyQuantity or 0) > 0 then return string.format("%d / %d this week", i.quantityEarnedThisWeek or 0, i.maxWeeklyQuantity) end
  if (i.maxQuantity or 0) > 0 then return string.format("max %d", i.maxQuantity) end
  return nil
end
ns.CurInfo = function(track) return cur(curId(nil, track, "Mistcrest")) end

---------------------------------------------------------------- reading the rows for this character
function ns.ReadStock(c)
  c.stock = c.stock or {}
  c.weekGain = c.weekGain or {}
  for _, r in ipairs(ns.STOCK) do
    local v, d, icon
    if r.key == "stone" then
      v = c.stones or itemCount(r.item)
      d = string.format("%d this week", ns.Plan and ns.Plan(c).total or 0)
      icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(r.item)
    elseif r.key == "keys" then
      local k = cur(curId(r.cur, r.name)); local sh = cur(curId(r.shardsId, r.shards))
      v = k and k.quantity or (c.keys or 0)
      local s = sh and sh.quantity or 0
      d = string.format("%d / 100 shards", s % 100) .. (s >= 100 and string.format(" (%d more key%s)", math.floor(s / 100), s >= 200 and "s" or "") or "")
      icon = k and k.iconFileID
    elseif r.key == "sparks" then
      v = itemCount(r.item)
      local du = cur(curId(r.dust, r.dustName))
      d = du and string.format("%d of %d earned", du.quantity or 0, (du.maxQuantity or 0) > 0 and du.maxQuantity or (du.quantity or 0)) or "dust not found"
      icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(r.item)
    elseif r.key == "crests" then
      local parts, total = {}, 0
      c.crests = c.crests or {}
      for _, t in ipairs(r.crests) do
        local i = cur(curId(nil, t, "Mistcrest"))
        local q = i and i.quantity or 0
        c.crests[t] = q
        total = total + q
        if i then
          parts[#parts + 1] = t:sub(1, 4) .. " " .. q
          icon = icon or i.iconFileID
        end
      end
      v = total
      d = #parts > 0 and table.concat(parts, " · ") or "not found"
    elseif r.key == "soul" then
      v = itemCount(r.item)
      local last = c.soulSeen
      if last and v > last then c.weekGain.soul = (c.weekGain.soul or 0) + (v - last) end
      c.soulSeen = v
      d = string.format("%d / %d for a Myth item · +%d this week", v % r.need, r.need, c.weekGain.soul or 0)
      if v >= r.need then d = string.format("%d ready to spend · ", math.floor(v / r.need)) .. d end
      icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(r.item)
    else
      local i = cur(curId(r.cur, r.name))
      v = i and i.quantity or 0
      d = i and capText(i) or (i and "" or "not found")
      icon = i and i.iconFileID
    end
    c.stock[r.key] = { v = v or 0, d = d or "", icon = icon }
  end
end

-- per-crest detail for the tooltip
function ns.CrestTip()
  local t = {}
  for _, tr in ipairs(ns.STOCK[6].crests) do
    local i = cur(curId(nil, tr, "Mistcrest"))
    if i then t[#t + 1] = string.format("%s: %d%s", i.name, i.quantity or 0, capText(i) and ("  (" .. capText(i) .. ")") or "") end
  end
  return t
end

---------------------------------------------------------------- equipped items: track and rank
local PAT
local function upgradePattern()
  if PAT then return PAT end
  local f = type(ITEM_UPGRADE_TOOLTIP_FORMAT_STRING) == "string" and ITEM_UPGRADE_TOOLTIP_FORMAT_STRING or "Upgrade Level: %s %d/%d"
  PAT = "^" .. f:gsub("([%(%)%.%-%+%[%]%^%$])", "%%%1"):gsub("%%s", "(.-)"):gsub("%%d", "(%%d+)") .. "$"
  return PAT
end
function ns.ScanGear()
  local out = {}
  if not (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then return out end
  local pat = upgradePattern()
  for inv = 1, 17 do
    if inv ~= 4 then
      local ok, data = pcall(C_TooltipInfo.GetInventoryItem, "player", inv)
      for _, line in ipairs(ok and data and data.lines or {}) do
        local t = line.leftText
        if type(t) == "string" and not secret(t) then
          local track, rank, max = t:match(pat)
          if track then
            out[#out + 1] = { inv = inv, track = track, rank = tonumber(rank), max = tonumber(max), link = GetInventoryItemLink("player", inv) }
            break
          end
        end
      end
    end
  end
  return out
end

---------------------------------------------------------------- main or alt (who pays 10 crests)
function ns.IsAlt(c, me)
  local db = ns.db
  if db.main then return db.main ~= me end
  -- no main picked: the character with the highest item level you've logged is the main
  local top, topKey = -1, nil
  for k, ch in pairs(db.chars) do if (ch.ilvl or 0) > top then top, topKey = ch.ilvl or 0, k end end
  return topKey ~= nil and topKey ~= me
end

---------------------------------------------------------------- can you upgrade something now?
function ns.Upgrades(c, me)
  local gear = ns.ScanGear()
  local cost = ns.IsAlt(c, me) and 10 or 20
  local out = {}
  for _, g in ipairs(gear) do
    local capRank = math.min(g.max or 6, 6)
    if g.rank and g.rank < capRank then
      local have = (c.crests or {})[g.track] or 0
      out[g.track] = out[g.track] or { have = have, cost = cost, items = {} }
      table.insert(out[g.track].items, g)
    end
    if STONE_SLOTS[g.inv] and g.track == "Myth" and g.rank and g.rank >= 6 and g.rank < 9 then
      out.stone = out.stone or { have = c.stones or 0, cost = 10, items = {}, stone = true }
      table.insert(out.stone.items, g)
    end
  end
  return out
end

function ns.CheckUpgrades(c, me, quiet)
  if not ns.db or ns.db.upgradeAlerts == false then return end
  c.canUp = c.canUp or {}
  local ups = ns.Upgrades(c, me)
  for track, u in pairs(ups) do
    local can = u.have >= u.cost
    if can and not c.canUp[track] and not quiet then
      local names = {}
      for i, g in ipairs(u.items) do if i <= 4 then names[#names + 1] = string.format("%s %d/%d", SLOT_NAME[g.inv] or "?", g.rank, g.max or 6) end end
      local what = u.stone and "Venomstones" or (track .. " Mistcrests")
      local line = string.format("%d %s: you can upgrade %s (%d crest%s a step).", u.have, what, table.concat(names, ", ") .. (#u.items > 4 and ", …" or ""),
        u.cost, u.cost == 1 and "" or "s")
      if u.stone then line = string.format("%d Venomstones: a step for %s (10 a step).", u.have, table.concat(names, ", ")) end
      if ns.Say then ns.Say(line) end
      if S and S.Toast then S:Toast({ kind = "upgrade", title = "Upgrade ready", sub = (u.stone and "Venomstones" or track .. " crests") .. " · " .. #u.items .. " item" .. (#u.items == 1 and "" or "s"), duration = 6 }) end
    end
    c.canUp[track] = can
  end
  for track in pairs(c.canUp) do if not ups[track] then c.canUp[track] = false end end
  return ups
end

---------------------------------------------------------------- drawing the rows in the window
local rows = {}
local function rgb(n, a) local C = (S and S.C) or {}; local c = C[n] or { 0.9, 0.9, 1 }; return c[1], c[2], c[3], a or 1 end
local function text(parent, role, size, color, justify)
  if S and S.Text then return S.Text(parent, role, size, color, justify) end
  local f = parent:CreateFontString(nil, "OVERLAY"); f:SetFont("Fonts\\ARIALN.TTF", size, ""); f:SetTextColor(rgb(color)); f:SetJustifyH(justify or "LEFT"); return f
end
function ns.DrawStock(win, y, c)
  local i = 0
  for _, r in ipairs(ns.STOCK) do
    if ns.db.show[r.key] ~= false then
      i = i + 1
      local row = rows[i]
      if not row then
        row = CreateFrame("Frame", nil, win); row:SetSize(532, 20)
        row.icon = row:CreateTexture(nil, "OVERLAY"); row.icon:SetSize(16, 16); row.icon:SetPoint("LEFT", 0, 0); row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.l = text(row, "strong", 13, "text"); row.l:SetPoint("LEFT", 22, 0); row.l:SetWidth(150)
        row.v = text(row, "display", 15, "text", "RIGHT"); row.v:SetPoint("LEFT", 170, 0); row.v:SetWidth(46)
        row.d = text(row, "body", 12, "soft"); row.d:SetPoint("LEFT", 228, 0); row.d:SetWidth(300)
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(s) GameTooltip:SetOwner(s, "ANCHOR_RIGHT"); GameTooltip:AddLine(s.r.label, 1, 1, 1)
          GameTooltip:AddLine(s.r.tip, 0.8, 0.8, 0.8, true)
          if s.r.key == "crests" then for _, l in ipairs(ns.CrestTip()) do GameTooltip:AddLine(l, 1, 1, 1) end end
          GameTooltip:AddLine("Right-click to hide this row (Smiler settings bring it back).", 0.6, 0.6, 0.6, true); GameTooltip:Show() end)
        row:SetScript("OnLeave", GameTooltip_Hide)
        row:SetScript("OnMouseUp", function(s, b) if b == "RightButton" then ns.db.show[s.r.key] = false; ns.Refresh() end end)
        rows[i] = row
      end
      local st = c.stock and c.stock[r.key] or { v = 0, d = "" }
      row.r = r
      row:ClearAllPoints(); row:SetPoint("TOPLEFT", 14, y)
      row.icon:SetTexture(st.icon or 134400)
      row.l:SetText(r.label); row.v:SetText(st.v); row.d:SetText(st.d)
      row:Show()
      y = y - 20
    end
  end
  for j = i + 1, #rows do rows[j]:Hide() end
  return y
end

function ns.StockSettings(B)
  for _, r in ipairs(ns.STOCK) do
    B:Switch(r.label, nil, function() return ns.db.show[r.key] ~= false end, function(v) ns.db.show[r.key] = v; if ns.win and ns.win:IsShown() then ns.Refresh() end end)
  end
end
