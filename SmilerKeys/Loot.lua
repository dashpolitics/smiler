-- SmilerKeys: loot tables from the game's Encounter Journal (current raids at every difficulty,
-- this season's M+ dungeons), bonus-roll info, and a per-character wishlist.
local _, ns = ...

local L = {}
ns.Loot = L

local function secret(v) return issecretvalue and issecretvalue(v) or false end

L.RAID_DIFFS   = { { 17, "LFR" }, { 14, "Normal" }, { 15, "Heroic" }, { 16, "Mythic" } }
L.DUNGEON_DIFF = 23   -- Mythic; keystone item levels come from C_MythicPlus

-- filter = Enum.ItemSlotFilterType, inv = equipped slot IDs to compare against
L.SLOTS = {
  { key = "head",     label = "Head",      filter = 0,  inv = { 1 } },
  { key = "neck",     label = "Neck",      filter = 1,  inv = { 2 } },
  { key = "shoulder", label = "Shoulders", filter = 2,  inv = { 3 } },
  { key = "back",     label = "Back",      filter = 3,  inv = { 15 } },
  { key = "chest",    label = "Chest",     filter = 4,  inv = { 5 } },
  { key = "wrist",    label = "Wrists",    filter = 5,  inv = { 9 } },
  { key = "hands",    label = "Hands",     filter = 6,  inv = { 10 } },
  { key = "waist",    label = "Waist",     filter = 7,  inv = { 6 } },
  { key = "legs",     label = "Legs",      filter = 8,  inv = { 7 } },
  { key = "feet",     label = "Feet",      filter = 9,  inv = { 8 } },
  { key = "finger",   label = "Rings",     filter = 12, inv = { 11, 12 } },
  { key = "trinket",  label = "Trinkets",  filter = 13, inv = { 13, 14 } },
  { key = "main",     label = "Main hand", filter = 10, inv = { 16 } },
  { key = "off",      label = "Off hand",  filter = 11, inv = { 17 } },
  { key = "emb",      label = "Embellish", filter = 98, inv = {} },   -- embellishment reagents (max 2 worn)
  { key = "other",    label = "Other",     filter = 14, inv = {} },
}
L.slotByFilter, L.slotByKey, L.slotOrder = {}, {}, {}
for i, s in ipairs(L.SLOTS) do
  L.slotByFilter[s.filter], L.slotByKey[s.key], L.slotOrder[s.key] = s, s, i
end

---------------------------------------------------------------- season config
-- Midnight Season 2 (patch 12.1.5). Bonus rolls are Nebulous Voidcores (currency 3418): usable on
-- Venomous Abyss bosses at any difficulty and on M+ completions, paying out at Great Vault level.
-- Update this block each season.
L.SEASON = {
  bonusRaids = { ["the venomous abyss"] = true },   -- if no listed raid matches, every current raid counts
  -- Lairs: one-boss instanced world bosses, bonus-rollable. A raid with one boss in the Adventure Guide counts too.
  -- Assumed: a lair bonus roll pays out at the lair's drop level for that difficulty.
  lairs = { ["tidebound grotto"] = true, ["the unbinding of kith'ix"] = true },
  raidBonus  = { [17] = "Champion · 292", [14] = "Hero 1/6 · 305", [15] = "Myth 1/6 · 318", [16] = "Myth 6/6 · 334" },
  -- bonus roll / Great Vault item level by raid difficulty (Icy Veins, Method, Conquest Capped)
  raidRoll   = { [17] = 292, [14] = 305, [15] = 318, [16] = 334 },
  raidBonusLast = { count = 2, text = "Myth 9/6 · 344", ilvl = 344 },   -- Mythic, last two bosses
  -- bonus rolls on the last two bosses (Coiled Altar, Ula'tek) pay out higher, by difficulty
  raidBonusLastBy = { [15] = { ilvl = 334, text = "Myth 6/6 · 334" }, [16] = { ilvl = 344, text = "Myth 9/6 · 344" } },
  -- tier tokens: which boss drops which slot, and the token names (Venomcast Idol = mail hands, …)
  tier = {
    raid  = "the venomous abyss",
    slots = { hands = "Entombed Sentinels", shoulder = "The Lost Explorers", chest = "Vashnik the Malignant",
              legs = "Sszorak", head = "The Twin Fangs" },
    tokenArmor = { [1] = "Venomwoven", [2] = "Venomcured", [3] = "Venomcast", [4] = "Venomforged" },
    tokenSlot  = { hands = "Idol", shoulder = "Remnant", chest = "Icon", legs = "Relic", head = "Effigy" },
    curio = { name = "Slumbering Coil Curio", boss = "Ula'tek" },   -- any tier slot, any class
    -- this season's class tier sets (item set IDs, from QuestionablyEpic's item data); preferred over
    -- whatever else the loot journal lists (older seasons, PvP)
    setIDs = { [2055] = true, [2056] = true, [2057] = true, [2058] = true, [2059] = true, [2060] = true, [2061] = true,
               [2062] = true, [2063] = true, [2064] = true, [2065] = true, [2066] = true, [2067] = true },
  },
  -- Labyrinth of Kindo'jan (delve, 12.1.5): 3 Mythical Soul Fragments (285065) make a Venerated Loa
  -- Armament (285044) – pick a Myth 1/6 armour or jewellery piece for the slot you need.
  labyrinth = {
    name = "Labyrinth of Kindo'jan", item = 285044, ilvl = 318, track = "Myth 1/6",
    slots = { "head", "neck", "shoulder", "back", "chest", "wrist", "hands", "waist", "legs", "feet", "finger" },
  },
}

L.DIFF_NAME = { [17] = "LFR", [14] = "Normal", [15] = "Heroic", [16] = "Mythic" }
L.MODES = { { "drop", "Drop" }, { "bonus", "Bonus roll" }, { "vault", "Great Vault" } }
L.MODE_NAME = { drop = "drop", bonus = "bonus roll", vault = "Great Vault" }

---------------------------------------------------------------- helpers
local function plain(s) return s and (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) or s end

local function itemLevel(link)
  if not link then return nil end
  local lv = C_Item.GetDetailedItemLevelInfo(link)
  if lv and not secret(lv) and lv > 0 then return lv end
end

function L.MPlusLevels(key)
  if C_MythicPlus.GetRewardLevelForDifficultyLevel then
    local weekly, eor = C_MythicPlus.GetRewardLevelForDifficultyLevel(key)
    if weekly and not secret(weekly) then return eor, weekly end
  end
end

function L.SpecID()
  if L.allClasses then return 0 end
  if L.specID then return L.specID end
  local idx = GetSpecialization and GetSpecialization()
  return idx and GetSpecializationInfo(idx) or 0
end

---------------------------------------------------------------- Encounter Journal scan
local function saveEJ()
  local s = {}
  s.tier = EJ_GetCurrentTier and EJ_GetCurrentTier()
  s.diff = EJ_GetDifficulty and EJ_GetDifficulty()
  if EJ_GetLootFilter then s.cls, s.spec = EJ_GetLootFilter() end
  if C_EncounterJournal.GetSlotFilter then s.slot = C_EncounterJournal.GetSlotFilter() end
  return s
end

local function restoreEJ(s)
  pcall(function()
    if s.tier then EJ_SelectTier(s.tier) end
    if s.diff then EJ_SetDifficulty(s.diff) end
    if s.cls then EJ_SetLootFilter(s.cls, s.spec or 0) end
    if s.slot and C_EncounterJournal.SetSlotFilter then C_EncounterJournal.SetSlotFilter(s.slot) end
  end)
end

local function headOf(n) return (n:lower():match("^([^,:]+)") or n:lower()):gsub("%s+$", "") end

local function matchMap(name)
  local l, h = name:lower(), headOf(name)
  for _, m in ipairs(ns.maps) do
    local ml = m.name:lower()
    if ml == l or headOf(m.name) == h then return m end
  end
end

-- Returns true when complete; false when some items are still loading (a rescan follows).
function L.Scan()
  if InCombatLockdown() then L.pending = true; return false end
  if EncounterJournal and EncounterJournal:IsShown() then L.pending = true; return false end
  if not EJ_GetNumTiers or #ns.maps == 0 then L.pending = true; return false end
  L.pending = false

  local classID = L.allClasses and 0 or select(3, UnitClass("player"))
  local specID = L.SpecID()
  local saved = saveEJ()
  local items, byKey, sources, donors = {}, {}, {}, {}
  local bossLinks, encInfo, nEncByInst = {}, {}, {}
  local incomplete = false
  local encName, encIcon = {}, {}

  local function scanInstance(instanceID, iname, isRaid, diffs)
    EJ_SelectInstance(instanceID)
    local order, n = {}, 0
    while true do
      local name, _, encID = EJ_GetEncounterInfoByIndex(n + 1, instanceID)
      if not name then break end
      n = n + 1
      order[encID], encName[encID] = n, name
      if isRaid and EJ_GetCreatureInfo then encIcon[encID] = select(5, EJ_GetCreatureInfo(1, encID)) end
      if isRaid then encInfo[#encInfo + 1] = { name = name:lower(), enc = encID, index = n, inst = instanceID, iname = iname } end
    end
    nEncByInst[instanceID] = n
    sources[#sources + 1] = { id = instanceID, name = iname, raid = isRaid }
    for _, d in ipairs(diffs) do
      if not EJ_IsValidInstanceDifficulty or EJ_IsValidInstanceDifficulty(d) then
        EJ_SetDifficulty(d)
        -- pass 1: your spec's loot. pass 2: trinkets for any spec of your class (off-spec),
        -- so e.g. a DPS trinket still shows for a healer.
        for pass = 1, ((classID ~= 0 and specID ~= 0) and 2 or 1) do
        if pass == 1 then
          EJ_SetLootFilter(classID, specID)
          if C_EncounterJournal.SetSlotFilter then C_EncounterJournal.SetSlotFilter(Enum.ItemSlotFilterType.NoFilter) end
        else
          EJ_SetLootFilter(classID, 0)
          if C_EncounterJournal.SetSlotFilter then C_EncounterJournal.SetSlotFilter(Enum.ItemSlotFilterType.Trinket) end
        end
        for i = 1, EJ_GetNumLoot() or 0 do
          local info = C_EncounterJournal.GetLootInfoByIndex(i)
          local key = info and info.itemID and (info.itemID .. ":" .. (info.encounterID or 0))
          local prior = key and byKey[key]
          local wanted = pass == 1 or (info and info.filterType == 13 and (not prior or prior.offspec))
          if wanted and info and info.itemID and not secret(info.itemID) then
            local it = prior
            if not it then
              it = { id = info.itemID, enc = info.encounterID, instID = instanceID, inst = iname, raid = isRaid,
                     encIndex = order[info.encounterID] or 0, nEnc = n, ilvl = {}, link = {}, offspec = pass == 2 }
              byKey[key] = it
              items[#items + 1] = it
            end
            if info.name then it.cname, it.name = info.name, plain(info.name) else incomplete = true end
            it.icon = info.icon or it.icon or C_Item.GetItemIconByID(info.itemID)
            it.filter = info.filterType or it.filter or 14
            it.slotText = info.slot or it.slotText
            it.armor = info.armorType or it.armor
            if info.link then
              it.link[d] = info.link
              it.ilvl[d] = itemLevel(info.link)
              if not it.ilvl[d] then incomplete = true end
              -- first-boss gear at each difficulty: its upgrade-track bonus IDs are what a bonus roll
              -- from the difficulty below pays out at (e.g. Heroic bonus roll = Mythic first boss, Myth 1/6)
              if isRaid and (info.filterType or 14) < 14 and info.encounterID then
                bossLinks[info.encounterID] = bossLinks[info.encounterID] or {}
                bossLinks[info.encounterID][d] = bossLinks[info.encounterID][d] or info.link
              end
              if isRaid and order[info.encounterID] == 1 and (info.filterType or 14) < 14 then
                donors[instanceID] = donors[instanceID] or {}
                donors[instanceID][d] = donors[instanceID][d] or info.link
              end
            else
              incomplete = true
            end
          end
        end
        end -- pass
      end
    end
  end

  local raidDiffs = {}
  for _, d in ipairs(L.RAID_DIFFS) do raidDiffs[#raidDiffs + 1] = d[1] end
  local seen, raidsDone = {}, false
  for t = EJ_GetNumTiers(), 1, -1 do
    EJ_SelectTier(t)
    -- season M+ dungeons may come from any tier
    local i = 1
    while true do
      local id, name = EJ_GetInstanceByIndex(i, false)
      if not id then break end
      if not seen[id] and name and matchMap(name) then
        seen[id] = true
        scanInstance(id, name, false, { L.DUNGEON_DIFF })
      end
      i = i + 1
    end
    -- raids: the newest tier that has any
    if not raidsDone then
      local list, j = {}, 1
      while true do
        local id, name = EJ_GetInstanceByIndex(j, true)
        if not id then break end
        list[#list + 1] = { id = id, name = name }
        j = j + 1
      end
      if #list > 0 then
        raidsDone = true
        for _, r in ipairs(list) do
          if not seen[r.id] then seen[r.id] = true; scanInstance(r.id, r.name, true, raidDiffs) end
        end
      end
    end
  end
  restoreEJ(saved)

  -- which raids take bonus rolls this season
  local anyListed = false
  for _, s in ipairs(sources) do if s.raid and L.SEASON.bonusRaids[s.name:lower()] then anyListed = true end end
  local lairByInst = {}
  for _, s in ipairs(sources) do
    s.lair = s.raid and (((L.SEASON.lairs or {})[s.name:lower()]) or (nEncByInst[s.id] or 9) <= 1) or nil
    lairByInst[s.id] = s.lair
    s.bonus = (not s.raid) or (not anyListed) or L.SEASON.bonusRaids[s.name:lower()] or s.lair or false
  end
  local bonusByInst = {}
  for _, s in ipairs(sources) do bonusByInst[s.id] = s.bonus end

  if L.AddTier(items, byKey, bossLinks, encInfo, nEncByInst) then incomplete = true end
  local tokenNames = L.TokenNames()
  for _, it in ipairs(items) do
    it.encName = encName[it.enc] or ""
    it.encIcon = encIcon[it.enc]
    it.bonus = bonusByInst[it.instID]
    it.lair = lairByInst[it.instID]
    it.slot = (L.slotByFilter[it.filter] or L.slotByKey.other).key
    if it.name and tokenNames[it.name] then it.hidden = true end   -- tokens: shown as your tier piece instead
  end

  if L.AddCrafted(items, sources, classID, specID) then incomplete = true end
  L.AddLabyrinth(items, sources)
  if L.AddDelveLoot(items, sources) then incomplete = true end

  L.items, L.sources, L.incomplete, L.donors, L.byKey = items, sources, incomplete, donors, byKey
  L.scannedSpec = specID
  return not incomplete
end

---------------------------------------------------------------- crafted gear + embellishments
-- Data lives in CraftedData.lua (L.CRAFTED, L.EMBELLISHMENTS, L.SEASON.crafted); refresh it each season.
L.EQUIPLOC = {
  INVTYPE_HEAD = "head", INVTYPE_NECK = "neck", INVTYPE_SHOULDER = "shoulder", INVTYPE_CLOAK = "back",
  INVTYPE_CHEST = "chest", INVTYPE_ROBE = "chest", INVTYPE_WRIST = "wrist", INVTYPE_HAND = "hands",
  INVTYPE_WAIST = "waist", INVTYPE_LEGS = "legs", INVTYPE_FEET = "feet", INVTYPE_FINGER = "finger",
  INVTYPE_TRINKET = "trinket", INVTYPE_WEAPON = "main", INVTYPE_2HWEAPON = "main",
  INVTYPE_WEAPONMAINHAND = "main", INVTYPE_RANGED = "main", INVTYPE_RANGEDRIGHT = "main",
  INVTYPE_WEAPONOFFHAND = "off", INVTYPE_SHIELD = "off", INVTYPE_HOLDABLE = "off",
}
local ARMOR_FOR_CLASS = { WARRIOR = 4, PALADIN = 4, DEATHKNIGHT = 4, HUNTER = 3, SHAMAN = 3, EVOKER = 3,
  ROGUE = 2, DRUID = 2, MONK = 2, DEMONHUNTER = 2, PRIEST = 1, MAGE = 1, WARLOCK = 1 }
local PRIMARY_KEY = { [1] = "ITEM_MOD_STRENGTH_SHORT", [2] = "ITEM_MOD_AGILITY_SHORT", [4] = "ITEM_MOD_INTELLECT_SHORT" }

local function specPrimary(specID)
  for i = 1, GetNumSpecializations() do
    local id, _, _, _, _, primary = GetSpecializationInfo(i)
    if id == specID then return primary end
  end
end

local function usableCrafted(equipLoc, itemClass, subClass, link, classID, specID)
  if classID == 0 then return true end
  local _, classFile = UnitClass("player")
  if itemClass == 4 and equipLoc ~= "INVTYPE_CLOAK" and subClass >= 1 and subClass <= 4 then
    if subClass ~= ARMOR_FOR_CLASS[classFile] then return false end
  end
  if itemClass == 2 and C_PlayerInfo and C_PlayerInfo.CanUseItem then
    local id = link and C_Item.GetItemInfoInstant(link)
    if id and not C_PlayerInfo.CanUseItem(id) then return false end
  end
  local want = PRIMARY_KEY[specPrimary(specID) or 0]
  if want and link and C_Item.GetItemStats then
    local stats = C_Item.GetItemStats(link)
    if stats then
      local any = stats.ITEM_MOD_STRENGTH_SHORT or stats.ITEM_MOD_AGILITY_SHORT or stats.ITEM_MOD_INTELLECT_SHORT
      if any and not stats[want] then return false end
    end
  end
  return true
end

local function qualityName(id)
  local name, link, quality = C_Item.GetItemInfo(id)
  if not name then return nil end
  local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 1]
  return name, link, c and (c.hex .. name .. "|r") or name
end

-- Adds crafted gear and embellishment reagents to the scan; returns true if any item info is still loading.
function L.AddCrafted(items, sources, classID, specID)
  local loading, seenProf = false, {}
  local function source(prof)
    if not seenProf[prof] then
      seenProf[prof] = true
      sources[#sources + 1] = { id = "craft:" .. prof, name = prof, crafted = true }
    end
    return "craft:" .. prof
  end
  for _, c in ipairs(L.CRAFTED or {}) do
    local _, _, _, equipLoc, icon, itemClass, subClass = C_Item.GetItemInfoInstant(c.id)
    if equipLoc then
      local name, link, cname = qualityName(c.id)
      if not name then loading = true end
      if not link or usableCrafted(equipLoc, itemClass, subClass, link, classID, specID) then
        items[#items + 1] = {
          id = c.id, crafted = true, raid = false, inst = c.prof, instID = source(c.prof),
          encName = "", encIndex = 0, nEnc = 0, ilvl = {}, link = { c = link },
          name = name or c.name, cname = cname or c.name, icon = icon,
          slot = L.EQUIPLOC[equipLoc] or "other", emb = c.emb, note = c.note,
        }
      end
    end
  end
  for _, e in ipairs(L.EMBELLISHMENTS or {}) do
    local _, _, _, _, icon = C_Item.GetItemInfoInstant(e.id)
    local name, link, cname = qualityName(e.id)
    if not name then loading = true end
    items[#items + 1] = {
      id = e.id, crafted = true, reagent = true, raid = false, inst = e.prof, instID = source(e.prof),
      encName = "", encIndex = 0, nEnc = 0, ilvl = {}, link = { c = link },
      name = name or e.name, cname = cname or e.name, icon = icon, slot = "emb", emb = true,
      note = e.effect, fits = e.slots, only = e.only, outdoor = e.outdoor,
    }
  end
  return loading
end

---------------------------------------------------------------- tier pieces (from tokens)
function L.TokenNames()
  local T, out = L.SEASON.tier, {}
  if not T then return out end
  for _, a in pairs(T.tokenArmor) do
    for _, s in pairs(T.tokenSlot) do out[a .. " " .. s] = true end
  end
  if T.curio then out[T.curio.name] = true end
  return out
end

local function findEnc(encInfo, name)
  local want = name:lower()
  for _, e in ipairs(encInfo) do
    if e.name == want or e.name:find(want, 1, true) or want:find(e.name, 1, true) then return e end
  end
end

-- Your class's current tier set, each piece placed under the boss whose token gives it.
-- Item level per difficulty = that boss's loot level (the piece takes the boss's upgrade-track bonus IDs).
function L.AddTier(items, byKey, bossLinks, encInfo, nEncByInst)
  local T = L.SEASON.tier
  if not T or not C_LootJournal or not C_LootJournal.GetItemSets then return false end
  local _, classFile, classID = UnitClass("player")
  local specID = L.allClasses and 0 or L.SpecID()
  local sets = C_LootJournal.GetItemSets(classID, specID ~= 0 and specID or nil) or {}
  local best
  local want = T.setIDs or {}
  for _, s in ipairs(sets) do
    local sw, bw = want[s.setID] and 1 or 0, best and (want[best.setID] and 1 or 0) or -1
    if not best or sw > bw or (sw == bw and ((s.itemLevel or 0) > (best.itemLevel or 0)
       or ((s.itemLevel or 0) == (best.itemLevel or 0) and s.setID > best.setID))) then best = s end
  end
  if not best then return false end
  local loading = false
  local armor = T.tokenArmor[ARMOR_FOR_CLASS[classFile] or 0] or "?"
  for _, si in ipairs(C_LootJournal.GetItemSetItems(best.setID) or {}) do
    local _, _, _, equipLoc, icon = C_Item.GetItemInfoInstant(si.itemID)
    local slot = equipLoc and L.EQUIPLOC[equipLoc]
    local boss = slot and T.slots[slot]
    local e = boss and findEnc(encInfo, boss)
    if e and not byKey[si.itemID .. ":" .. e.enc] then
      local name, baseLink, quality = C_Item.GetItemInfo(si.itemID)
      if not name then loading = true end
      local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 4]
      local it = {
        id = si.itemID, enc = e.enc, instID = e.inst, inst = e.iname, raid = true, tier = true,
        encIndex = e.index, nEnc = nEncByInst[e.inst] or 0, ilvl = {}, link = {},
        filter = L.slotByKey[slot].filter, icon = si.icon or icon,
        name = name, cname = name and c and (c.hex .. name .. "|r") or name,
        token = armor .. " " .. (T.tokenSlot[slot] or "?"), setName = best.name,
      }
      for d, dl in pairs(bossLinks[e.enc] or {}) do
        local l = baseLink and L.Rebase(baseLink, dl)
        it.link[d] = l or baseLink
        it.ilvl[d] = (l and itemLevel(l)) or itemLevel(dl)
      end
      byKey[si.itemID .. ":" .. e.enc] = it
      items[#items + 1] = it
    end
  end
  return loading
end

---------------------------------------------------------------- Labyrinth armaments (one choice per slot)
function L.AddLabyrinth(items, sources)
  local Y = L.SEASON.labyrinth
  if not Y then return end
  sources[#sources + 1] = { id = "labyrinth", name = Y.name, delve = true }
  local icon = C_Item.GetItemIconByID(Y.item) or 134400
  -- the actual pieces, if you've opened the Labyrinth vendor's shop (secondary stats included)
  local _, classFile = UnitClass("player")
  local rec = ns.db and ns.db.loa and ns.db.loa[classFile]
  local have = {}
  local pieces = rec and rec.pieces
  if not pieces then
    pieces = {}
    local mine = ARMOR_FOR_CLASS[classFile] or 0
    for _, p in ipairs(L.LOA_PIECES or {}) do
      if p.armor == 0 or p.armor == mine then
        local _, link = C_Item.GetItemInfo(p.id)
        pieces[#pieces + 1] = { id = p.id, slot = p.slot, name = p.name, link = link, ilvl = Y.ilvl,
                                icon = C_Item.GetItemIconByID(p.id) }
      end
    end
  end
  for _, p in ipairs(pieces) do
    if L.slotByKey[p.slot] then
      have[p.slot] = true
      local name, _, cname = qualityName(p.id)
      items[#items + 1] = {
        id = p.id, labyrinth = true, delve = true, raid = false, loaIlvl = p.ilvl,
        inst = Y.name, instID = "labyrinth", encName = "", encIndex = 0, nEnc = 0, ilvl = {}, link = { c = p.link },
        name = name or p.name or ("item " .. p.id), cname = cname or p.name, icon = p.icon or icon, slot = p.slot,
      }
    end
  end
  for _, slot in ipairs(Y.slots) do
    local s = L.slotByKey[slot]
    if not have[slot] then items[#items + 1] = {
      id = -(1000 + L.slotOrder[slot]), labyrinth = true, delve = true, raid = false,
      inst = Y.name, instID = "labyrinth", encName = "", encIndex = 0, nEnc = 0, ilvl = {}, link = {},
      name = "Venerated Loa Armament: " .. s.label, cname = "|cffa335eeVenerated Loa Armament: " .. s.label .. "|r",
      icon = icon, slot = slot,
    } end
  end
end

-- Delve trinkets: not in the Adventure Guide, so from a built-in list
function L.AddDelveLoot(items, sources)
  local D = L.SEASON.delveLoot
  if not (D and L.DELVE_TRINKETS) then return false end
  sources[#sources + 1] = { id = "delves", name = D.name, delve = true }
  local classID = select(3, UnitClass("player"))
  local loading = false
  for _, id in ipairs(L.DELVE_TRINKETS) do
    local _, _, _, equipLoc, icon, itemClass, subClass = C_Item.GetItemInfoInstant(id)
    local name, link, cname = qualityName(id)
    if not name then loading = true end
    if equipLoc and (not link or usableCrafted(equipLoc, itemClass, subClass, link, classID, L.SpecID())) then
      items[#items + 1] = {
        id = id, delve = true, delveLoot = true, raid = false, inst = D.name, instID = "delves",
        encName = "", encIndex = 0, nEnc = 0, ilvl = {}, link = { c = link },
        name = name or ("item " .. id), cname = cname, icon = icon, slot = L.EQUIPLOC[equipLoc] or "trinket",
      }
    end
  end
  return loading
end

-- Read the Venerated Loa Armament pieces from the vendor that takes Mythical Soul Fragments.
local FRAGMENT = 285065
local function costsFragment(i)
  if not (GetMerchantItemCostInfo and GetMerchantItemCostItem) then return false end
  for j = 1, (GetMerchantItemCostInfo(i) or 0) do
    local _, _, link, name = GetMerchantItemCostItem(i, j)
    if (link and tostring(link):find("item:" .. FRAGMENT, 1, true)) or (name and name:find("Mythical Soul Fragment", 1, true)) then return true end
  end
  return false
end
function L.ScanLoaVendor()
  if not GetMerchantNumItems then return end
  local found = {}
  local classID = select(3, UnitClass("player"))
  for i = 1, GetMerchantNumItems() or 0 do
    if costsFragment(i) then
      local link = GetMerchantItemLink(i)
      local id, equipLoc, icon, itemClass, subClass
      if link then id, _, _, equipLoc, icon, itemClass, subClass = C_Item.GetItemInfoInstant(link) end
      local slot = equipLoc and L.EQUIPLOC[equipLoc]
      if slot and usableCrafted(equipLoc, itemClass, subClass, link, classID, L.SpecID()) then
        found[#found + 1] = { id = id, link = link, slot = slot, icon = icon, ilvl = itemLevel(link), name = C_Item.GetItemInfo(link) }
      end
    end
  end
  if #found == 0 then return end
  local _, classFile = UnitClass("player")
  ns.db.loa = ns.db.loa or {}
  ns.db.loa[classFile] = { pieces = found, ts = time() }
  ns.Print("Read " .. #found .. " Venerated Loa Armament pieces and their stats from the shop.")
  L.Refresh(true)
end
local loaEv = CreateFrame("Frame")
loaEv:RegisterEvent("MERCHANT_SHOW")
loaEv:SetScript("OnEvent", function()
  C_Timer.After(0.5, function() pcall(L.ScanLoaVendor) end)   -- item info streams in a moment later
  C_Timer.After(2.5, function() pcall(L.ScanLoaVendor) end)
end)

---------------------------------------------------------------- best in slot (per character)
-- Two BiS lists per character: Heroic (aim for Hero track) and Mythic (aim for Myth track).
-- The Heroic list is the one you had before; the Mythic list starts as a copy of it.
L.PROFILES = { { "heroic", "Heroic BiS" }, { "mythic", "Mythic BiS" } }
L.PROFILE_TRACK = { heroic = "hero", mythic = "myth" }
function L.Profile() return (ns.db and ns.db.settings and ns.db.settings.bisProfile == "mythic") and "mythic" or "heroic" end
function L.SetProfile(p) ns.db.settings.bisProfile = (p == "mythic") and "mythic" or "heroic" end
local function profKey(tbl)
  if L.Profile() == "heroic" then return ns.selfKey end
  local k = ns.selfKey .. "#mythic"
  if tbl[k] == nil and tbl[ns.selfKey] then
    local c = {}; for id, v in pairs(tbl[ns.selfKey]) do c[id] = v end; tbl[k] = c
  end
  return k
end
function L.BiS()
  ns.db.bis = ns.db.bis or {}
  local k = profKey(ns.db.bis)
  local b = ns.db.bis[k]
  if not b then b = {}; ns.db.bis[k] = b end
  return b
end
function L.IsBiS(id) return L.BiS()[id] == true end
function L.ToggleBiS(id)
  local b = L.BiS()
  b[id] = (not b[id]) or nil
  return b[id] == true
end

---------------------------------------------------------------- your own priority, 1 (most wanted) to 15
L.PRIO_MAX = 15
function L.Prios()
  ns.db.prio = ns.db.prio or {}
  local p = ns.db.prio[ns.selfKey]
  if not p then p = {}; ns.db.prio[ns.selfKey] = p end
  return p
end
function L.Prio(id) return id and L.Prios()[id] end
-- priorities set from QE scores (re-importing replaces these; ones you set yourself are never touched)
function L.PrioAuto()
  ns.db.prioAuto = ns.db.prioAuto or {}
  local p = ns.db.prioAuto[ns.selfKey]
  if not p then p = {}; ns.db.prioAuto[ns.selfKey] = p end
  return p
end
function L.IsAutoPrio(id) return id and L.PrioAuto()[id] == true end
function L.SetPrio(id, n)
  L.Prios()[id] = (n and n >= 1 and n <= L.PRIO_MAX) and n or nil
  L.PrioAuto()[id] = nil                       -- you chose it: QE won't change it
end

-- Rank wishlist items by QE upgrade % and give the best 15 priority 1-15 (biggest upgrade = 1).
-- Your own priorities stay; returns how many were set.
function L.AutoPrioFromQE()
  local q = L.QEScores and L.QEScores()
  local scores = q and q.scores
  if not scores then return 0 end
  local prios, auto = L.Prios(), L.PrioAuto()
  for id in pairs(auto) do prios[id] = nil; auto[id] = nil end
  local list, seen = {}, {}
  for _, entries in pairs(L.Wish()) do
    for _, e in ipairs(entries) do
      local pct = scores[e.id]
      if pct and pct > 0 and not seen[e.id] and not prios[e.id] then seen[e.id] = true; list[#list + 1] = { id = e.id, pct = pct } end
    end
  end
  table.sort(list, function(a, b) return a.pct > b.pct end)
  local used = {}
  for _, n in pairs(prios) do used[n] = true end      -- numbers you've given out yourself stay yours
  local n, set = 1, 0
  for _, r in ipairs(list) do
    while used[n] do n = n + 1 end
    if n > L.PRIO_MAX then break end
    prios[r.id] = n; auto[r.id] = true; used[n] = true; set = set + 1
  end
  return set
end

-- "Priority" submenu for any context menu
function L.PrioMenu(root, id, after)
  local cur = L.Prio(id)
  local sub = root:CreateButton("Priority" .. (cur and (": " .. cur) or "…"))
  for n = 1, L.PRIO_MAX do
    sub:CreateRadio(tostring(n) .. (n == 1 and "  (most wanted)" or ""), function() return L.Prio(id) == n end,
      function() L.SetPrio(id, n); if after then after() end end)
  end
  if cur then sub:CreateButton("Clear priority", function() L.SetPrio(id, nil); if after then after() end end) end
  if L.IsAutoPrio(id) then sub:CreateTitle("Set from your QE scores – pick a number to keep your own") end
end

---------------------------------------------------------------- embellishments
-- You can wear 2 (two of the same is fine). An embellishment goes on one crafted piece, and a piece takes one.
-- Items embellished by default count as one and can't take another. Engineering outdoor ones: 1 at most.
local CRAFTED_PROF = {}
local function craftedProf(id)
  if not next(CRAFTED_PROF) then for _, c in ipairs(L.CRAFTED or {}) do CRAFTED_PROF[c.id] = c.prof end end
  return CRAFTED_PROF[id]
end

-- can reagent r go on crafted wishlist entry e (in slot)?
function L.EmbFits(r, e, slot)
  if not e or not e.crafted or e.reagent or e.emb then return false end
  local prof = e.inst or craftedProf(e.id)
  local only = r.only
  if only == "bsweapon" then return prof == "Blacksmithing" and (slot == "main" or slot == "off") end
  if only == "enggun" then return prof == "Engineering" and slot == "main" end
  if only == "enggear" then return prof == "Engineering" end
  if only == "engfeet" then return prof == "Engineering" and slot == "feet" end
  return true
end

-- the crafted wishlist entry an embellishment is planned on, or nil
function L.EmbHost(r)
  if not r.on then return nil end
  for _, e in ipairs(L.Wish()[r.on.slot] or {}) do
    if e.id == r.on.id and e.crafted and not e.reagent then return e, r.on.slot end
  end
end

-- embellishment entries planned on crafted entry e
function L.EmbsOn(e, slot)
  local out = {}
  for i, r in ipairs(L.Wish().emb or {}) do
    if r.on and r.on.slot == slot and r.on.id == e.id and L.EmbHost(r) then out[#out + 1] = { r = r, index = i } end
  end
  return out
end

-- crafted wishlist entries reagent r could go on: { slot, index, e, taken, fits }
function L.EmbHosts(r)
  local out = {}
  for slot, list in pairs(L.Wish()) do
    if slot ~= "emb" then
      for i, e in ipairs(list) do
        if e.crafted and not e.reagent and not e.emb then
          local on = L.EmbsOn(e, slot)
          local mine = false
          for _, x in ipairs(on) do if x.r == r then mine = true end end
          if L.EmbFits(r, e, slot) then
            out[#out + 1] = { slot = slot, index = i, e = e, taken = (#on > 0 and not mine), mine = mine }
          end
        end
      end
    end
  end
  table.sort(out, function(a, b) return (L.slotOrder[a.slot] or 99) < (L.slotOrder[b.slot] or 99) end)
  return out
end

function L.SetEmbHost(r, slot, id)
  if slot and id then
    for _, x in ipairs(L.EmbsOn({ id = id }, slot)) do if x.r ~= r then x.r.on = nil end end   -- one per piece
    r.on = { slot = slot, id = id }
  else
    r.on = nil
  end
end

-- the plan: { { kind = "builtin"|"reagent", e, slot, host, hostSlot, index } ... }, problems
function L.EmbPlan()
  local plan, problems = {}, {}
  local w = L.Wish()
  for slot, list in pairs(w) do
    if slot ~= "emb" then
      for _, e in ipairs(list) do if e.emb and not e.reagent then plan[#plan + 1] = { kind = "builtin", e = e, slot = slot } end end
    end
  end
  table.sort(plan, function(a, b) return (L.slotOrder[a.slot] or 99) < (L.slotOrder[b.slot] or 99) end)
  local outdoor = 0
  for i, r in ipairs(w.emb or {}) do
    local host, hs = L.EmbHost(r)
    plan[#plan + 1] = { kind = "reagent", e = r, index = i, host = host, hostSlot = hs }
    if r.outdoor then outdoor = outdoor + 1 end
  end
  if #plan > 2 then problems[#problems + 1] = #plan .. " planned – you can only wear 2" end
  if outdoor > 1 then problems[#problems + 1] = "only 1 outdoor Engineering embellishment counts" end
  return plan, problems
end

function L.EmbCount() return #(L.EmbPlan()) end

-- embellishments you're wearing now: built-in pieces by ID, others by the "Embellished" tooltip line (best effort)
local BUILTIN = {}
function L.WornEmbellishments()
  if not next(BUILTIN) then for _, c in ipairs(L.CRAFTED or {}) do if c.emb then BUILTIN[c.id] = true end end end
  local out = {}
  for inv = 1, 17 do
    local link = GetInventoryItemLink("player", inv)
    if link then
      local id = C_Item.GetItemInfoInstant(link)
      local hit = id and BUILTIN[id]
      if not hit and C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
        local ok, data = pcall(C_TooltipInfo.GetInventoryItem, "player", inv)
        for _, line in ipairs(ok and data and data.lines or {}) do
          local t = line.leftText
          if type(t) == "string" and not (issecretvalue and issecretvalue(t)) and t:find("^Embellished") then hit = true; break end
        end
      end
      if hit then out[#out + 1] = { inv = inv, link = link } end
    end
  end
  return out
end

-- Rescan while item data streams in (a few passes at most)
local tries = 0
function L.Refresh(force)
  if force then tries = 0 end
  local done = L.Scan()
  if ns.LootUI_Refresh then ns.LootUI_Refresh() end
  if not done and not L.pending and tries < 6 then
    tries = tries + 1
    C_Timer.After(1.5, function() L.Refresh() end)
  end
end

---------------------------------------------------------------- per-item values for the current view
---------------------------------------------------------------- bonus-roll item links
-- Item string fields: item:id:enchant:gem1:gem2:gem3:gem4:suffix:unique:level:spec:modMask:context:numBonus:bonus...:rest
local function itemString(link) return link and link:match("|H(item:[^|]+)|h") end
local function split(s)
  local t = {}
  for f in (s .. ":"):gmatch("([^:]*):") do t[#t + 1] = f end
  return t
end

-- Gives `link`'s item the context and bonus IDs (upgrade track/rank) of `donor`
function L.Rebase(link, donor)
  local a, b = itemString(link), itemString(donor)
  if not a or not b then return nil end
  local A, B = split(a), split(b)
  local na, nb = tonumber(A[14]) or 0, tonumber(B[14]) or 0
  local out = {}
  for i = 1, 12 do out[i] = A[i] or "" end
  out[13], out[14] = B[13] or "", B[14] or "0"
  for i = 1, nb do out[#out + 1] = B[14 + i] end
  for i = 15 + na, #A do out[#out + 1] = A[i] end
  local s = table.concat(out, ":")
  return (link:gsub("|Hitem:[^|]+|h", function() return "|H" .. s .. "|h" end))
end

local NEXT_DIFF = { [17] = 14, [14] = 15, [15] = 16 }

-- The item as a bonus roll / vault pick at `diff` would give it, or nil
function L.RollLink(it, diff)
  if not it or not it.raid then return nil end
  if it.lair then return it.link[diff] end
  local up = NEXT_DIFF[diff]
  if not up then return it.link[16] end                  -- Mythic: Myth 6/6 (9/6 last bosses); best effort
  local base = it.link[up]
  local donor = L.donors and L.donors[it.instID] and L.donors[it.instID][up]
  local link = base and donor and L.Rebase(base, donor)
  if link then
    local want = L.RollIlvl(it, diff)
    local got = itemLevel(link)
    if want and got and got ~= want then return nil end   -- didn't come out at the expected level
  end
  return link
end

local function lastBoss(it)
  if it.lair then return false end
  local n = L.SEASON.raidBonusLast.count
  return it.encIndex and it.nEnc and it.nEnc > 0 and it.encIndex > it.nEnc - n
end
function L.RollIlvl(it, diff)
  if it.lair then return it.ilvl and it.ilvl[diff] end
  local by = L.SEASON.raidBonusLastBy and L.SEASON.raidBonusLastBy[diff]
  if by and lastBoss(it) then return by.ilvl end
  return L.SEASON.raidRoll[diff]
end

-- mode: "drop" (from the boss / end of the key), "bonus" (bonus roll) or "vault" (Great Vault)
function L.Ilvl(it, raidDiff, key, mode)
  mode = mode or "drop"
  if it.reagent then return nil end
  if it.labyrinth then return it.loaIlvl or L.SEASON.labyrinth.ilvl end
  if it.delveLoot then return L.SEASON.delveLoot.ilvl end
  if it.crafted then return L.SEASON.crafted and L.SEASON.crafted.max end
  if it.raid then
    if mode == "drop" then return it.ilvl[raidDiff] end
    return L.RollIlvl(it, raidDiff)
  end
  local eor, weekly = L.MPlusLevels(key)
  if mode == "drop" then return eor or it.ilvl[L.DUNGEON_DIFF] end
  return weekly
end

-- What a wishlist entry is aiming for: item level and a label like "Heroic bonus roll"
function L.EntryTarget(e)
  if e.reagent then return nil, "Embellishment" end
  if e.track and L.TRACK[e.track] then
    local lv = e.fixedIlvl or L.TRACK[e.track].ilvl[math.min(6, e.rank or 1)]
    return lv, (e.fixed and (e.route or "") or (L.TrackLabel(e.track, e.rank) .. (e.route and (" · " .. e.route) or "")))
  end
  if e.labyrinth then return L.SEASON.labyrinth.ilvl, "Labyrinth armament (" .. L.SEASON.labyrinth.track .. ")" end
  if e.crafted then return L.SEASON.crafted and L.SEASON.crafted.max, "Crafted" end
  local stub = { raid = e.raid, ilvl = e.ilvls or {}, encIndex = e.encIndex, nEnc = e.nEnc }
  local lv = L.Ilvl(stub, e.diff or 15, e.key or 10, e.mode or "drop")
  local where = e.raid and (L.DIFF_NAME[e.diff] or "?") or ("+" .. (e.key or "?"))
  return lv, where .. " " .. L.MODE_NAME[e.mode or "drop"]
end

function L.EntryLink(e)
  local links = e.links or {}
  if e.crafted or e.labyrinth or e.delveLoot then return links.c end
  if e.raid and e.mode and e.mode ~= "drop" and L.byKey then
    local it = L.byKey[e.id .. ":" .. (e.enc or 0)]
    local l = it and L.RollLink(it, e.diff)
    if l then return l end
  end
  if e.raid then return links[e.diff] or links[15] end
  return links[L.DUNGEON_DIFF]
end

function L.BonusText(it, raidDiff, key)
  if not it.bonus then return nil end
  if it.lair then return "lair drop level" end
  if it.raid then
    local by = L.SEASON.raidBonusLastBy and L.SEASON.raidBonusLastBy[raidDiff]
    if by and lastBoss(it) then return by.text end
    return L.SEASON.raidBonus[raidDiff]
  end
  local _, weekly = L.MPlusLevels(key)
  return weekly and ("item level " .. weekly .. " (vault level for +" .. key .. ")") or "vault level"
end

function L.SourceText(it)
  if it.labyrinth then return "Delve · " .. it.inst end
  if it.delveLoot then return "Delves" end
  if it.reagent then return "Embellishment · " .. it.inst end
  if it.crafted then return "Crafted · " .. it.inst end
  if it.raid then return (it.encName ~= "" and (it.encName .. " · ") or "") .. it.inst end
  return it.inst
end

function L.LinkFor(it, raidDiff, mode)
  if it.raid and mode and mode ~= "drop" then
    local l = L.RollLink(it, raidDiff)
    if l then return l end
  end
  if it.crafted then return it.link.c or select(2, C_Item.GetItemInfo(it.id)) end
  if it.delveLoot then return it.link.c or select(2, C_Item.GetItemInfo(it.id)) end
  if it.labyrinth then return it.link.c or (it.id > 0 and select(2, C_Item.GetItemInfo(it.id))) or nil end
  if it.raid then return it.link[raidDiff] or next(it.link) and select(2, next(it.link)) end
  return it.link[L.DUNGEON_DIFF]
end

---------------------------------------------------------------- upgrade tracks (Midnight Season 2)
-- Each track has 6 ranks; every rank above 1/6 costs 20 crests. Source: Icy Veins gear upgrading guide.
-- Update each season.
L.TRACKS = {
  { key = "adv",   name = "Adventurer", short = "Adv",   ilvl = { 266, 269, 272, 276, 279, 282 } },
  { key = "vet",   name = "Veteran",    short = "Vet",   ilvl = { 279, 282, 285, 289, 292, 295 } },
  { key = "champ", name = "Champion",   short = "Champ", ilvl = { 292, 295, 298, 302, 305, 308 } },
  { key = "hero",  name = "Hero",       short = "Hero",  ilvl = { 305, 308, 311, 315, 318, 321 } },
  { key = "myth",  name = "Myth",       short = "Myth",  ilvl = { 318, 321, 324, 328, 331, 334 } },
}
L.TRACK = {}
for i, t in ipairs(L.TRACKS) do t.order = i; L.TRACK[t.key] = t end
L.RAID_TRACK = { [17] = "vet", [14] = "champ", [15] = "hero", [16] = "myth" }

-- colour per track, like item quality: Myth orange, Hero purple, Champion blue, Veteran green, Adventurer white
L.TRACK_COLOR = { myth = { 1.00, 0.50, 0.00 }, hero = { 0.64, 0.21, 0.93 }, champ = { 0.00, 0.44, 0.87 },
                  vet = { 0.12, 1.00, 0.00 }, adv = { 0.85, 0.85, 0.85 } }

-- item level -> track key, rank. Drops start low on a track, so the lowest-rank match wins (292 = Champion 1/6).
function L.TrackOf(ilvl, hint)
  if not ilvl then return nil end
  if hint and L.TRACK[hint] then
    for r, v in ipairs(L.TRACK[hint].ilvl) do if v == ilvl then return hint, r end end
  end
  local best, bestRank
  for _, t in ipairs(L.TRACKS) do
    for r, v in ipairs(t.ilvl) do
      if v == ilvl and (not bestRank or r < bestRank or (r == bestRank and t.order > L.TRACK[best].order)) then
        best, bestRank = t.key, r
      end
    end
  end
  if best then return best, bestRank end
  if ilvl > L.TRACKS[#L.TRACKS].ilvl[6] then return "myth", 9 end   -- above Myth 6/6 (last raid bosses): fixed
  for _, t in ipairs(L.TRACKS) do                                     -- nearest rank at or below
    for r = 6, 1, -1 do if t.ilvl[r] <= ilvl and (r == 6 or t.ilvl[r + 1] > ilvl) then best, bestRank = t.key, r end end
  end
  return best, bestRank
end

function L.TrackLabel(track, rank)
  local t = L.TRACK[track]
  if not t then return "" end
  if rank and rank > 6 then return t.name .. " (max)" end
  return t.name .. " " .. (rank or 1) .. "/6"
end

-- Every way to get an item, with the track it comes on. Route:
-- { kind, label, where, track, rank, ilvl, max, fixed, mode, diff, key }
local KEY_STEPS = { 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }
function L.Routes(it)
  if it._routes then return it._routes end
  local out = {}
  local function add(r)
    if r.ilvl and not r.track then r.track, r.rank = L.TrackOf(r.ilvl, r.hint) end
    local t = r.track and L.TRACK[r.track]
    r.fixed = r.fixed or (r.rank and r.rank > 6)
    r.max = r.fixed and r.ilvl or (t and t.ilvl[6]) or r.ilvl
    out[#out + 1] = r
  end
  if it.reagent then
    -- embellishment reagents have no item level of their own
  elseif it.labyrinth then
    local Y = L.SEASON.labyrinth
    add({ kind = "delve", label = "Labyrinth armament", where = Y.name, ilvl = it.loaIlvl or Y.ilvl, hint = "myth", mode = "drop" })
  elseif it.delveLoot then
    local D = L.SEASON.delveLoot
    add({ kind = "delve", label = D.label, where = D.name, ilvl = D.ilvl, hint = "hero", mode = "drop" })
  elseif it.crafted then
    local cmax = L.SEASON.crafted and L.SEASON.crafted.max
    if cmax then add({ kind = "crafted", label = "Crafted", where = "Crafting order", ilvl = cmax, fixed = true, mode = "drop" }) end
  elseif it.raid then
    local boss = (it.encName and it.encName ~= "" and (it.encName .. " · ") or "") .. (it.inst or "")
    for _, d in ipairs(L.RAID_DIFFS) do
      local diff, dname = d[1], d[2]
      local lv = it.ilvl and it.ilvl[diff]
      if lv then
        add({ kind = "raid", label = dname .. " raid", where = boss, ilvl = lv, hint = L.RAID_TRACK[diff], mode = "drop", diff = diff })
      end
      if it.bonus then
        local bl = L.RollIlvl(it, diff)
        if bl then add({ kind = "bonus", label = dname .. " bonus roll", where = boss, ilvl = bl, mode = "bonus", diff = diff }) end
      end
    end
  else
    -- M+ end of run: group key levels that give the same item level
    local lastLv, from
    local function flush(to)
      if lastLv then
        add({ kind = "mplus", label = "+" .. from .. (to ~= from and ("–" .. to) or "") .. " end of run",
              where = it.inst, ilvl = lastLv, mode = "drop", key = to })
      end
    end
    local prevK
    for _, k in ipairs(KEY_STEPS) do
      local eor = L.MPlusLevels(k)
      if eor ~= lastLv then flush(prevK); lastLv, from = eor, k end
      prevK = k
    end
    flush(prevK)
    local _, weekly = L.MPlusLevels(10)
    if weekly then add({ kind = "vault", label = "Great Vault (+10)", where = it.inst, ilvl = weekly, mode = "vault", key = 10 }) end
    if weekly and it.bonus then add({ kind = "bonus", label = "+10 bonus roll", where = it.inst, ilvl = weekly, mode = "bonus", key = 10 }) end
    if not lastLv and it.ilvl and it.ilvl[L.DUNGEON_DIFF] then
      add({ kind = "mplus", label = "Mythic dungeon", where = it.inst, ilvl = it.ilvl[L.DUNGEON_DIFF], mode = "drop", key = 0 })
    end
  end
  table.sort(out, function(a, b) if (a.max or 0) ~= (b.max or 0) then return (a.max or 0) > (b.max or 0) end return (a.ilvl or 0) > (b.ilvl or 0) end)
  it._routes = out
  return out
end

-- Highest item level the item can reach by any route (after upgrading)
function L.MaxIlvl(it)
  local m = 0
  for _, r in ipairs(L.Routes(it)) do if (r.max or 0) > m then m = r.max end end
  return m > 0 and m or nil
end

-- The best route that gives the item on a track (drops before bonus rolls, then the highest start)
-- via: nil/"any", "drop", "bonus" or "vault" – limits which kind of route counts
function L.RouteOn(it, track, via)
  local best
  for _, r in ipairs(L.Routes(it)) do
    if via and via ~= "any" and r.mode ~= via and r.kind ~= "crafted" then
      -- not this way
    elseif r.fixed and r.kind == "crafted" then
      best = best or r
    elseif r.track == track then
      if not best or (best.kind == "bonus" and r.kind ~= "bonus") or ((r.kind == "bonus") == (best.kind == "bonus") and (r.ilvl or 0) > (best.ilvl or 0)) then
        best = r
      end
    end
  end
  return best
end

-- Item level on a track at a rank, or nil if no route gives it on that track
function L.IlvlAt(it, track, rank, via)
  local r = L.RouteOn(it, track, via)
  if not r then return nil end
  if r.fixed then return r.ilvl, r end
  local t = L.TRACK[r.track]
  return t.ilvl[math.max(rank or 1, r.rank or 1)], r
end

-- The target for a wishlist entry made from a route
function L.TargetFromRoute(r, rank)
  return { mode = r.mode, diff = r.diff, key = r.key, track = r.track, rank = r.fixed and r.rank or math.max(rank or 1, r.rank or 1), qe = nil,
           fixed = r.fixed, route = r.label, fixedIlvl = r.fixed and r.ilvl or nil }
end

---------------------------------------------------------------- equipped comparison
function L.Equipped(slotKey)
  local s = L.slotByKey[slotKey]
  local out = {}
  for _, inv in ipairs(s and s.inv or {}) do
    local link = GetInventoryItemLink("player", inv)
    out[#out + 1] = { inv = inv, link = link, ilvl = itemLevel(link),
                      icon = link and C_Item.GetItemIconByID(link) or GetInventoryItemTexture("player", inv) }
  end
  return out
end

-- Item level gain over the weakest equipped item in that slot, or nil
function L.Gain(it, ilvl)
  if not ilvl then return nil end
  local eq = L.Equipped(it.slot)
  if #eq == 0 then return nil end
  local low
  for _, e in ipairs(eq) do
    local v = e.ilvl or 0
    low = low and math.min(low, v) or v
  end
  return ilvl - low
end

---------------------------------------------------------------- wishlist (per character)
function L.Wish()
  ns.db.wish = ns.db.wish or {}
  local w = ns.db.wish[ns.selfKey]
  if not w then w = {}; ns.db.wish[ns.selfKey] = w end
  return w
end

function L.IsWished(id)
  for _, list in pairs(L.Wish()) do
    for _, e in ipairs(list) do if e.id == id then return true end end
  end
  return false
end

-- target = { mode = "drop"|"bonus"|"vault", diff = raid difficulty, key = keystone level }
function L.Add(it, slotKey, target)
  slotKey = slotKey or it.slot
  target = target or {}
  if slotKey ~= it.slot and it.slot ~= "other" then
    ns.Print((it.name or "That item") .. " goes in " .. L.slotByKey[it.slot].label .. ", not " .. L.slotByKey[slotKey].label .. ".")
    return false
  end
  local w = L.Wish()
  w[slotKey] = w[slotKey] or {}
  if not it.reagent then           -- the same embellishment twice is fine
    for _, e in ipairs(w[slotKey]) do if e.id == it.id then return false end end
  end
  local mode = target.mode or "drop"
  if it.crafted or it.labyrinth then mode = "drop" end
  if mode == "bonus" and not it.bonus then
    ns.Print((it.name or "That item") .. " isn't bonus-rollable – added as a drop.")
    mode = "drop"
  end
  local ilvls, links = {}, {}
  for k, v in pairs(it.ilvl or {}) do ilvls[k] = v end
  for k, v in pairs(it.link or {}) do links[k] = v end
  table.insert(w[slotKey], {
    mode = mode, diff = target.diff or 15, key = target.key or 10, ilvls = ilvls, links = links,
    id = it.id, name = it.name, icon = it.icon, raid = it.raid, inst = it.inst, instID = it.instID,
    enc = it.enc, encName = it.encName, encIndex = it.encIndex, nEnc = it.nEnc, bonus = it.bonus,
    crafted = it.crafted, reagent = it.reagent, emb = it.emb, tier = it.tier, token = it.token,
    labyrinth = it.labyrinth, delve = it.delve, delveLoot = it.delveLoot,
    track = target.track, rank = target.rank, fixed = target.fixed, route = target.route, fixedIlvl = target.fixedIlvl,
    qe = target.qe, only = it.only, outdoor = it.outdoor, on = target.on,
  })
  local new = w[slotKey][#w[slotKey]]
  if it.reagent and not new.on then
    -- one crafted piece waiting for an embellishment it can take: put it there
    local free = {}
    for _, h in ipairs(L.EmbHosts(new)) do if not h.taken then free[#free + 1] = h end end
    if #free == 1 then new.on = { slot = free[1].slot, id = free[1].e.id } end
  elseif it.crafted and not it.reagent and not it.emb then
    -- a crafted piece: an embellishment waiting for an item goes on it
    for _, r in ipairs(w.emb or {}) do
      if not L.EmbHost(r) and L.EmbFits(r, new, slotKey) then r.on = { slot = slotKey, id = new.id }; break end
    end
  end
  local n = L.EmbCount()
  if it.emb and n > 2 then
    ns.Print("That's " .. n .. " embellishments on your wishlist – you can only wear 2.")
  end
  return true
end

function L.Remove(slotKey, idx)
  local list = L.Wish()[slotKey]
  if list then table.remove(list, idx) end
end

---------------------------------------------------------------- BiS per slot
-- A slot is "BiS achieved" when you're wearing items you've marked BiS there (both rings / both
-- trinkets for those slots), or when you tick it yourself.
function L.SlotState(slotKey)
  local s = L.slotByKey[slotKey]
  local need = math.max(1, #s.inv)
  ns.db.bisSlot = ns.db.bisSlot or {}
  local manual = (ns.db.bisSlot[profKey(ns.db.bisSlot)] or {})[slotKey]
  -- wearing a BiS item counts once it's on the profile's track or higher (Hero for Heroic, Myth for Mythic)
  local want = L.TRACK[L.PROFILE_TRACK[L.Profile()]].order
  local have = 0
  for _, inv in ipairs(s.inv) do
    local link = GetInventoryItemLink("player", inv)
    local id = link and C_Item.GetItemInfoInstant(link)
    if id and L.IsBiS(id) then
      local tr = L.TrackOf(itemLevel(link))
      if not tr or L.TRACK[tr].order >= want then have = have + 1 end
    end
  end
  local planned = false
  for _, e in ipairs(L.Wish()[slotKey] or {}) do if L.IsBiS(e.id) then planned = true end end
  local auto = #s.inv > 0 and have >= need
  local ok
  if manual ~= nil then ok = manual else ok = auto end
  return ok and true or false, auto, have, need, planned, manual
end

-- Click flips the slot between BiS and not BiS, whatever the automatic check says.
-- If the flip lands back on what the automatic check says, the slot goes back to automatic.
function L.ToggleSlotDone(slotKey)
  ns.db.bisSlot = ns.db.bisSlot or {}
  local k = profKey(ns.db.bisSlot)
  local m = ns.db.bisSlot[k] or {}
  ns.db.bisSlot[k] = m
  local ok, auto = L.SlotState(slotKey)
  local want = not ok
  if want == (auto and true or false) then m[slotKey] = nil else m[slotKey] = want end
end

---------------------------------------------------------------- plans: where to spend what
-- kind: "bonus" = bosses/dungeons to spend bonus rolls on (wishlist items from rollable sources)
--       "farm"  = items you're after as drops · "vault" = Great Vault picks · "craft" = crafting + Labyrinth
-- Slots you've marked BiS-achieved are left out. Sorted by BiS items, then item count.
L.PLAN_MODE = { bonus = "bonus", farm = "drop", vault = "vault" }

function L.Plan(kind)
  local groups, list = {}, {}
  for slot, items in pairs(L.Wish()) do
    local done = L.slotByKey[slot] and L.SlotState(slot)
    for _, e in ipairs(items) do
      local mode = e.mode or "drop"
      local take
      if kind == "bonus" then take = e.bonus and not e.crafted and not e.labyrinth
      elseif kind == "farm" then take = mode == "drop" and not e.crafted and not e.labyrinth
      elseif kind == "vault" then take = mode == "vault" and not e.crafted and not e.labyrinth
      else take = e.crafted or e.labyrinth end
      if take and not done then
        local key = e.raid and ("r" .. (e.enc or 0)) or ("d" .. tostring(e.instID or 0))
        local g = groups[key]
        if not g then
          local label = e.raid and ((e.encName or "?") .. " · " .. (e.inst or "?"))
            or (e.crafted and ("Crafting order · " .. (e.inst or "?")))
            or (e.labyrinth and ((e.inst or "?") .. " · Soul Fragments")) or (e.inst or "?")
          g = { label = label, count = 0, bis = 0, items = {}, instID = e.instID, raid = e.raid,
                crafted = e.crafted, labyrinth = e.labyrinth, best = nil, bestLabel = nil }
          groups[key] = g
          list[#list + 1] = g
        end
        -- what you'd get this way (bonus tab uses the item's difficulty/key with a bonus roll)
        local view = e
        if L.PLAN_MODE[kind] and kind ~= "farm" or kind == "bonus" then
          view = setmetatable({ mode = L.PLAN_MODE[kind] }, { __index = e })
        end
        local lv, label = L.EntryTarget(view)
        g.count = g.count + 1
        if L.IsBiS(e.id) then g.bis = g.bis + 1 end
        g.items[#g.items + 1] = { e = e, ilvl = lv, label = label, bis = L.IsBiS(e.id) }
        local pr = L.Prio(e.id)
        if pr and (not g.prio or pr < g.prio) then g.prio = pr end
        if lv and (not g.best or lv > g.best) then g.best, g.bestLabel = lv, label end
      end
    end
  end
  table.sort(list, function(a, b)
    if (a.prio or 99) ~= (b.prio or 99) then return (a.prio or 99) < (b.prio or 99) end   -- your priority first
    if a.bis ~= b.bis then return a.bis > b.bis end
    if a.count ~= b.count then return a.count > b.count end
    return a.label < b.label
  end)
  return list
end


---------------------------------------------------------------- secondary stat priority
-- Rank Crit / Haste / Mastery / Versatility 1-4, once for raid and once for Mythic+, per spec.
-- An item's value = item level on the chosen track x how well its secondaries fit your ranking.
L.STATS = {
  { key = "crit",    name = "Critical Strike", short = "Crit",    mod = "ITEM_MOD_CRIT_RATING_SHORT" },
  { key = "haste",   name = "Haste",           short = "Haste",   mod = "ITEM_MOD_HASTE_RATING_SHORT" },
  { key = "mastery", name = "Mastery",         short = "Mastery", mod = "ITEM_MOD_MASTERY_RATING_SHORT" },
  { key = "vers",    name = "Versatility",     short = "Vers",    mod = "ITEM_MOD_VERSATILITY" },
}
L.STAT = {}
for i, st in ipairs(L.STATS) do st.order = i; L.STAT[st.key] = st end
L.STAT_WEIGHT = { 1.0, 0.75, 0.5, 0.25 }
L.STAT_NEUTRAL = 0.625          -- items with no secondaries (on-use trinkets etc.) sit in the middle
L.STAT_CONTEXTS = { { "raid", "Raid" }, { "mplus", "Mythic+" } }

local function playerSpec()
  local idx = GetSpecialization and GetSpecialization()
  return (idx and GetSpecializationInfo(idx)) or 0
end

local function prioStore()
  ns.db.statPrio = ns.db.statPrio or {}
  local spec = playerSpec()
  ns.db.statPrio[spec] = ns.db.statPrio[spec] or {}
  return ns.db.statPrio[spec]
end

function L.StatContext()
  local c = ns.db and ns.db.settings and ns.db.settings.statCtx
  return c == "mplus" and "mplus" or "raid"
end
function L.SetStatContext(c) ns.db.settings = ns.db.settings or {}; ns.db.settings.statCtx = (c == "mplus") and "mplus" or "raid" end

-- ranks per stat, 1 (best) to 4; ties allowed (e.g. Haste 1, Crit 2, Mastery 2, Vers 4). nil if not set yet
function L.StatRanks(ctx)
  local store = prioStore()
  ctx = ctx or L.StatContext()
  local v = store[ctx]
  if type(v) ~= "table" then return nil end
  if v[1] then                                   -- older saves: an ordered list
    local m = {}
    for i, k in ipairs(v) do m[k] = i end
    store[ctx] = m; v = m
  end
  for _, st in ipairs(L.STATS) do if not v[st.key] then return nil end end
  return v
end
function L.HasStatPrio(ctx) return L.StatRanks(ctx) ~= nil end

-- stat keys best first (ties keep the default order)
function L.StatPrio(ctx)
  local r = L.StatRanks(ctx)
  if not r then return nil end
  local list = {}
  for i, st in ipairs(L.STATS) do list[i] = st.key end
  table.sort(list, function(a, b) if r[a] ~= r[b] then return r[a] < r[b] end return L.STAT[a].order < L.STAT[b].order end)
  return list
end

-- "Haste > Crit = Mastery > Vers"
function L.StatPrioText(ctx, short)
  local r = L.StatRanks(ctx)
  local list = L.StatPrio(ctx)
  if not list then return nil end
  local out = ""
  for i, k in ipairs(list) do
    local name = short and L.STAT[k].short:sub(1, 1) or L.STAT[k].short
    out = out .. (i == 1 and "" or (r[k] == r[list[i - 1]] and " = " or " > ")) .. name
  end
  return short and out:gsub(" ", "") or out
end

function L.StatRankOf(ctx, stat)
  local r = L.StatRanks(ctx)
  return r and r[stat] or L.STAT[stat].order
end

-- give one stat a rank; others keep theirs (so two can share a rank)
function L.SetStatRankOf(ctx, stat, rank)
  local store = prioStore()
  local m = L.StatRanks(ctx)
  if not m then
    m = {}
    for _, st in ipairs(L.STATS) do m[st.key] = st.order end
  end
  m[stat] = math.max(1, math.min(4, rank))
  store[ctx] = m
end
function L.ClearStatPrio(ctx) prioStore()[ctx] = nil end

-- secondary amounts on a link: { crit = n, ... }, total; nil while item info loads
local secCache = {}
local LOA_BY_ID
function L.Secondaries(link)
  if not link then return nil end
  local c = secCache[link]
  if c then return c.s, c.total end
  local loa = type(link) == "string" and tonumber(link:match("^loa:(%d+)$"))
  if loa then
    if not LOA_BY_ID then LOA_BY_ID = {}; for _, p in ipairs(L.LOA_PIECES or {}) do LOA_BY_ID[p.id] = p end end
    local p = LOA_BY_ID[loa]
    if not p then return nil end
    local s, total = {}, 0
    for k, v in pairs(p.stats) do s[k] = v; total = total + v end
    secCache[link] = { s = s, total = total }
    return s, total
  end
  if not C_Item.GetItemStats then return nil end
  local stats = C_Item.GetItemStats(link)
  if not stats then return nil end
  local s, total = {}, 0
  for _, st in ipairs(L.STATS) do
    local v = stats[st.mod] or 0
    if v > 0 then s[st.key] = v; total = total + v end
  end
  secCache[link] = { s = s, total = total }
  return s, total
end

-- 0.25..1: share of the item's secondaries weighted by your ranking; nil = no secondaries / unknown
function L.StatFit(link, ctx)
  local ranks = L.StatRanks(ctx)
  if not ranks then return nil end
  local s, total = L.Secondaries(link)
  if not s or total <= 0 then return nil end
  local sum = 0
  for k, v in pairs(s) do sum = sum + v * L.STAT_WEIGHT[ranks[k] or 4] end
  return sum / total
end

-- stats on the item, biggest first, as "Haste / Mastery"
function L.StatText(link)
  local s = L.Secondaries(link)
  if not s then return nil end
  local list = {}
  for k, v in pairs(s) do list[#list + 1] = { k, v } end
  if #list == 0 then return nil end
  table.sort(list, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end return a[1] < b[1] end)
  local out = {}
  for i, e in ipairs(list) do out[i] = L.STAT[e[1]].short end
  return table.concat(out, " / ")
end

-- the number the "By stats" sort uses: item level on the view's track x stat fit
function L.StatValue(it, track, rank, via, ctx)
  local lv, r = L.IlvlAt(it, track, rank, via)
  local base = lv or 0
  local link = L.LinkFor(it, r and r.diff or 15, r and r.mode or "drop")
  -- Loa armament pieces: stats from the built-in table until the game has the item loaded
  if it.labyrinth and it.id > 0 and (not link or not L.Secondaries(link)) then link = "loa:" .. it.id end
  local fit = L.StatFit(link, ctx)
  return base * (fit or L.STAT_NEUTRAL), fit, link
end

---------------------------------------------------------------- where to go (v2)
-- opts: scope = "bis" | "wish" | "all" (every upgrade over what you wear), modes = { bonus, drop, vault, other },
--       farm = Mythic raid bosses you have on farm (nil = all); bosses past it count at Heroic.
function L.MythicBossCount()
  local n = 0
  for _, it in ipairs(L.items or {}) do
    if it.raid and not it.lair and it.bonus and (it.nEnc or 0) > n then n = it.nEnc end
  end
  return n
end

-- bosses killed this week, by "name:difficulty" (lockouts)
function L.KilledThisWeek()
  local out = {}
  if not GetNumSavedInstances then return out end
  for i = 1, GetNumSavedInstances() or 0 do
    local _, _, _, diff, locked, _, _, isRaid, _, _, numEnc = GetSavedInstanceInfo(i)
    if locked and isRaid then
      for j = 1, numEnc or 0 do
        local boss, _, killed = GetSavedInstanceEncounterInfo(i, j)
        if killed and boss then out[boss:lower() .. ":" .. tostring(diff)] = true end
      end
    end
  end
  return out
end

function L.BonusRolls()
  if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) then return nil end
  local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, 3418)   -- Nebulous Voidcore
  return ok and info and info.quantity or nil
end

local function routeAllowed(it, r, opts)
  local m = opts.modes or {}
  local kind
  if r.kind == "crafted" or r.kind == "delve" then kind = "other"
  elseif r.mode == "bonus" then kind = "bonus"
  elseif r.mode == "vault" then kind = "vault"
  else kind = "drop" end
  if not m[kind] then return false end
  if it.raid and not it.lair and r.diff == 16 and opts.farm and (it.encIndex or 0) > opts.farm then return false end
  return true, kind
end

function L.PlanFor(opts)
  opts = opts or {}
  local groups, list = {}, {}
  local killed = L.KilledThisWeek()
  local qe = L.QEScores and L.QEScores()
  qe = qe and qe.scores or {}
  -- candidates
  local cands, seen = {}, {}
  local function consider(it, entry)
    if not it or seen[it.id .. ":" .. (it.enc or 0)] then return end
    local slotDone = L.slotByKey[it.slot] and it.slot ~= "emb" and it.slot ~= "other" and L.SlotState(it.slot)
    if slotDone then return end
    seen[it.id .. ":" .. (it.enc or 0)] = true
    cands[#cands + 1] = { it = it, e = entry }
  end
  if opts.scope == "all" then
    for _, it in ipairs(L.items or {}) do
      if not it.hidden and not it.reagent and it.slot ~= "other" and it.id > 0 then
        local g = L.Gain(it, L.MaxIlvl(it))
        if g and g > 0 then consider(it) end
      end
    end
  else
    for slot, entries in pairs(L.Wish()) do
      for _, e in ipairs(entries) do
        if opts.scope ~= "bis" or L.IsBiS(e.id) then
          local it = L.byKey and L.byKey[e.id .. ":" .. (e.enc or 0)]
          if not it then for _, x in ipairs(L.items or {}) do if x.id == e.id then it = x; break end end end
          consider(it, e)
        end
      end
    end
    if opts.scope == "bis" then   -- BiS items not on the wishlist yet
      for _, it in ipairs(L.items or {}) do if L.IsBiS(it.id) then consider(it) end end
    end
  end
  -- best allowed way per item, grouped by where you go
  for _, c in ipairs(cands) do
    local it = c.it
    local best, bestKind
    for _, r in ipairs(L.Routes(it)) do
      local ok, kind = routeAllowed(it, r, opts)
      if ok and (not best or (r.max or r.ilvl or 0) > (best.max or best.ilvl or 0)
         or ((r.max or 0) == (best.max or 0) and (r.ilvl or 0) > (best.ilvl or 0))) then best, bestKind = r, kind end
    end
    if best then
      local key = it.raid and ("r" .. (it.enc or 0)) or ("d" .. tostring(it.instID or 0))
      local g = groups[key]
      if not g then
        local label = it.raid and ((it.encName ~= "" and it.encName or "?") .. " · " .. (it.inst or "?"))
          or (it.crafted and ("Crafting order · " .. (it.inst or "?")))
          or (it.labyrinth and ((it.inst or "?") .. " · Soul Fragments")) or (it.inst or "?")
        g = { label = label, count = 0, bis = 0, qe = 0, items = {}, instID = it.instID, raid = it.raid, lair = it.lair,
              crafted = it.crafted, labyrinth = it.labyrinth, delve = it.delve, encName = it.encName, kinds = {} }
        groups[key] = g
        list[#list + 1] = g
      end
      local bis = L.IsBiS(it.id)
      g.count = g.count + 1
      if bis then g.bis = g.bis + 1 end
      g.qe = g.qe + math.max(0, qe[it.id] or 0)
      g.kinds[bestKind] = true
      local pr = L.Prio(it.id)
      if pr and (not g.prio or pr < g.prio) then g.prio = pr end
      local lv = best.max or best.ilvl
      g.items[#g.items + 1] = { it = it, route = best, kind = bestKind, ilvl = lv, bis = bis, qe = qe[it.id], prio = pr }
      if not g.best or lv > g.best then g.best, g.bestRoute = lv, best end
      if it.raid and best.diff and it.encName and killed[it.encName:lower() .. ":" .. best.diff] then g.killed = true end
    end
  end
  for _, g in ipairs(list) do
    table.sort(g.items, function(a, b) if (a.prio or 99) ~= (b.prio or 99) then return (a.prio or 99) < (b.prio or 99) end return (a.qe or 0) > (b.qe or 0) end)
  end
  table.sort(list, function(a, b)
    if (a.killed and 1 or 0) ~= (b.killed and 1 or 0) then return not a.killed end   -- done this week last
    if (a.prio or 99) ~= (b.prio or 99) then return (a.prio or 99) < (b.prio or 99) end
    if a.bis ~= b.bis then return a.bis > b.bis end
    if math.abs(a.qe - b.qe) > 0.001 then return a.qe > b.qe end
    if a.count ~= b.count then return a.count > b.count end
    return a.label < b.label
  end)
  return list
end

-- kept for older callers
function L.Farm() return L.Plan("farm") end

---------------------------------------------------------------- events
local ev = CreateFrame("Frame")
ev:RegisterEvent("EJ_LOOT_DATA_RECIEVED")
ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, e, unit)
  if not ns.LootUI_IsShown or not ns.LootUI_IsShown() then return end
  if e == "PLAYER_EQUIPMENT_CHANGED" then
    ns.LootUI_Refresh()
  elseif e == "PLAYER_SPECIALIZATION_CHANGED" then
    if unit == "player" and not L.specID and not L.allClasses then
      ns.Debounce("lootspec", 1, function() L.Refresh(true) end)
    end
  elseif e == "PLAYER_REGEN_ENABLED" then
    if L.pending then L.Refresh(true) end
  elseif L.incomplete then
    ns.Debounce("lootdata", 1, function() L.Refresh() end)
  end
end)
