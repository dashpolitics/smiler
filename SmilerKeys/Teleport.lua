-- SmilerKeys: find the dungeon teleport ("Path of ...") you know for each season dungeon.
-- No hardcoded IDs: scan your spellbook (including the Hero's Path flyouts) and match each
-- spell's description against the dungeon name, so it works for any season and client language.
local _, ns = ...

local function secret(v) return issecretvalue and issecretvalue(v) or false end

local function knownSpells()
  local out, seen = {}, {}
  local function add(id)
    if id and not secret(id) and not seen[id] then seen[id] = true; out[#out + 1] = id end
  end
  local SB = C_SpellBook
  if not (SB and SB.GetNumSpellBookSkillLines and Enum.SpellBookSpellBank) then return out end
  local bank = Enum.SpellBookSpellBank.Player
  for line = 1, SB.GetNumSpellBookSkillLines() or 0 do
    local info = SB.GetSpellBookSkillLineInfo(line)
    if info and info.itemIndexOffset and info.numSpellBookItems then
      for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
        local item = SB.GetSpellBookItemInfo(i, bank)
        if item then
          if item.itemType == Enum.SpellBookItemType.Flyout and item.actionID then
            local _, _, slots = GetFlyoutInfo(item.actionID)
            for s = 1, slots or 0 do
              local sid, _, isKnown = GetFlyoutSlotInfo(item.actionID, s)
              if isKnown then add(sid) end
            end
          elseif item.itemType == Enum.SpellBookItemType.Spell then
            add(item.spellID)
          end
        end
      end
    end
  end
  return out
end

local function variants(name)
  local l = name:lower()
  local v = { l }
  local head = l:match("^([^,:]+)")           -- "ara-kara, city of echoes" -> "ara-kara"
  if head and head ~= l and #head >= 5 then v[#v + 1] = head end
  local noThe = l:gsub("^the%s+", "")
  if noThe ~= l then v[#v + 1] = noThe end
  return v
end

-- Sets m.tp (spellID) on each season map; returns how many were found.
function ns.FindTeleports()
  if #ns.maps == 0 then return 0 end
  local cands, waiting = {}, false
  for _, id in ipairs(knownSpells()) do
    local desc = C_Spell.GetSpellDescription(id)
    if desc and desc ~= "" and not secret(desc) then
      cands[#cands + 1] = { id = id, desc = desc:lower() }
    elseif C_Spell.RequestLoadSpellData then
      C_Spell.RequestLoadSpellData(id); waiting = true
    end
  end
  local found = 0
  for _, m in ipairs(ns.maps) do
    m.tp = nil
    local override = ns.db.settings.tp[m.id]
    if override then
      m.tp = override
    else
      for _, v in ipairs(variants(m.name)) do
        for _, c in ipairs(cands) do
          if c.desc:find(v, 1, true) then m.tp = c.id; break end
        end
        if m.tp then break end
      end
    end
    if m.tp then found = found + 1 end
  end
  -- some descriptions load lazily; look again shortly
  if waiting and not ns.tpRetried then
    ns.tpRetried = true
    C_Timer.After(5, function() ns.FindTeleports(); ns.UI_Rebuild() end)
  end
  return found
end

-- Seconds left on the teleport's cooldown, or 0
function ns.TeleportCooldown(id)
  if not id or not C_Spell.GetSpellCooldown then return 0 end
  local ok, info = pcall(C_Spell.GetSpellCooldown, id)
  if not ok or not info or secret(info.startTime) or secret(info.duration) then return 0 end
  if (info.duration or 0) <= 1.5 then return 0 end
  return math.max(0, info.startTime + info.duration - GetTime()), info.startTime, info.duration
end

function ns.TeleportKnown(id)
  return id and IsSpellKnown and (IsSpellKnown(id) or IsPlayerSpell(id)) or false
end
