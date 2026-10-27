-- SmilerKeys: settings tabs and menu status line inside the Smiler window
local _, ns = ...
if not (Smiler and Smiler.RegisterSettings) then return end
local S = Smiler
local L = ns.Loot

local function set() return ns.db and ns.db.settings end

S:RegisterStatus("smilerkeys", function()
  if not ns.db then return nil end
  local n, newest = 0, 0
  for k, p in pairs(ns.db.players or {}) do
    if k ~= ns.selfKey and not p.test then
      n = n + 1
      if (p.ts or 0) > newest then newest = p.ts end
    end
  end
  if n == 0 then return "No friends synced yet", "muted" end
  return string.format("%d friend%s synced · newest %s", n, n == 1 and "" or "s", ns.Age(newest)), "muted"
end)

S:RegisterSettings("SmilerKeys", function(body, W)
  local A = W.Column(body, 0, 0, 290)
  A:Section("Share your keys with")
  local names = { { "guild", "Guild" }, { "friends", "Friends on this realm" }, { "bnet", "Battle.net friends" }, { "party", "Your group" } }
  for _, c in ipairs(names) do
    A:Switch(c[2], nil, function() return set().channels[c[1]] end, function(v)
      set().channels[c[1]] = v; if ns.UI_Refresh then ns.UI_Refresh() end
    end)
  end
  A:Note("You see everyone who shares with you, whatever you pick here.", "muted", 12)

  local B = W.Column(body, 334, 0, 290)
  B:Section("Grid")
  B:Switch("Show alts", "Characters linked to the same Battle.net account", function() return set().showAlts end,
    function(v) set().showAlts = v; if ns.UI_Refresh then ns.UI_Refresh() end end)
  B:Switch("Glow keys that are upgrades", nil, function() return set().glow end,
    function(v) set().glow = v; if ns.UI_Refresh then ns.UI_Refresh() end end)
  B:Slider("Forget players after", 7, 60, 1, function() return set().maxAgeDays or 21 end,
    function(v) set().maxAgeDays = v end, function(v) return v .. " days" end, 110)
  B:Buttons(nil, {
    { "Sync now", function() ns.Broadcast(true); ns.ScanParty(); ns.Print("Sync sent.") end, nil, 96 },
    { "Show hidden players", function() wipe(set().hidden); if ns.UI_Refresh then ns.UI_Refresh() end end, nil, 160 },
  })
  B:Note("Link an alt to a friend: /sk link <character> <account>", "muted", 12)

  return {
    note = "Changes save as you make them. /sk still works.",
    footer = { { "Open the grid", function() ns.UI_Toggle() end, "primary", 130 } },
  }
end)

S:RegisterSettings("Loot", function(body, W)
  local A = W.Column(body, 0, 0, 290)
  A:Section("Wishlist")
  A:Switch("Open with the character sheet", "Press C and it appears beside it", function() return set().lootWithChar ~= false end,
    function(v) set().lootWithChar = v; set().lootPanelClosed = nil end)
  A:Dropdown("BiS list", L.PROFILES, function() return L.Profile() end, function(k) L.SetProfile(k); if ns.LootUI_Refresh then ns.LootUI_Refresh() end end, 140)
  local v = ns.LootView
  if v then
    local tracks = {}
    for _, t in ipairs(L.TRACKS) do tracks[#tracks + 1] = { t.key, t.name } end
    A:Dropdown("Aim for track", tracks, function() return v.track end, function(k) v.track = k end, 140)
    A:Slider("Upgraded to", 1, 6, 1, function() return v.rank end, function(k) v.rank = k end, function(k) return k .. "/6" end, 110)
  end

  local B = W.Column(body, 334, 0, 290)
  B:Section("Secondary stats, best first")
  local function refreshLoot() if ns.LootUI_Refresh then ns.LootUI_Refresh() end end
  local rankOpts = { { 1, "1st" }, { 2, "2nd" }, { 3, "3rd" }, { 4, "4th" } }
  for _, ctx in ipairs(L.STAT_CONTEXTS) do
    local holder = CreateFrame("Frame", nil, body)
    holder:SetSize(290, 62)
    local lab = S.Text(holder, "body", 13, "text")
    lab:SetPoint("TOPLEFT", 0, 0)
    lab:SetText(ctx[2])
    local state = S.Text(holder, "body", 12, "muted")
    state:SetPoint("TOPRIGHT", 0, 0)
    for i, st in ipairs(L.STATS) do
      local sl = S.Text(holder, "label", 11, "muted")
      sl:SetPoint("TOPLEFT", (i - 1) * 74 + 2, -18)
      sl:SetText(st.short:upper())
      local dd = W.Dropdown(holder, 68, rankOpts,
        function()
          state:SetText(L.StatPrioText(ctx[1]) or "not set yet")
          return L.StatRankOf(ctx[1], st.key)
        end,
        function(k) L.SetStatRankOf(ctx[1], st.key, k); S.RefreshSettings(); refreshLoot() end)
      dd:SetPoint("TOPLEFT", (i - 1) * 74, -32)
    end
    B:Place(holder, 62)
  end
  B:Dropdown("Rate loot for", L.STAT_CONTEXTS, function() return L.StatContext() end,
    function(k) L.SetStatContext(k); refreshLoot() end, 120)
  B:Note("Give each stat a place, 1st to 4th. Two stats can share a place. Saved per spec. Sort by Stats in the loot list or the gear guide and the best fit at the highest item level comes first.", "soft", 12)
  B:Buttons(nil, { { "Clear raid", function() L.ClearStatPrio("raid"); S.RefreshSettings(); refreshLoot() end, nil, 100 },
                   { "Clear Mythic+", function() L.ClearStatPrio("mplus"); S.RefreshSettings(); refreshLoot() end, nil, 110 } })
  B:Note("Alt-click an item to mark it BiS. Each gear slot has a box on the wishlist bar; click + to pick, or drag from your bags.", "muted", 12)

  return {
    note = "Changes save as you make them. /sk loot still works.",
    footer = {
      { "Import…", function() if ns.ImportOpen then ns.ImportOpen() end end, nil, 90 },
      { "Open wishlist", function() ns.LootToggle() end, "primary", 130 },
    },
  }
end)
