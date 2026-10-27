-- CD Timeline
-- Two frames that line up:
--   the plan bar  - a Viserio / NSRT note string; boss mechanics and every
--                   healer's cooldowns slide down and reach the landing line
--                   when they are due (layouts: hud, single, lanes)
--   "mine"        - one track per major cooldown of your own, driven by the
--                   real cooldowns: parked at the top with a countdown, sliding
--                   down as it comes back, docked at the bottom when ready;
--                   with the plan's scheduled casts of that spell shown above
--                   the track and as a ghost sliding down beside it.
--
-- Slash: /tl  (or /cdtimeline)
--

-- "time" is seconds since pull. Rows of a later phase (ph:N) are re-anchored
-- when the boss mod announces the stage, and a row with anchor:<spellID|text>;
-- n:<occurrence>;offset:<s>; snaps to the end of the n-th BigWigs bar for that
-- boss ability (+ offset) the moment the bar starts - so cooldowns follow the
-- real cast, not the clock.

local ADDON_NAME, ns = ...

------------------------------------------------------------------------
-- Defaults / saved variables
------------------------------------------------------------------------
local DEFAULTS = {
    notes      = {},     -- [encounterID] = { [difficultyID] = note }
    lastImport = nil,    -- { encounterID = n, difficultyID = n }
    locked     = true,
    lookahead  = 30,     -- seconds visible above the now line
    imminent   = 5,      -- the bottom zone: these last seconds get imminentFrac of the height
    imminentFrac = 0.38,
    hold       = 0.8,    -- seconds an icon lingers (fading) at the bottom
    iconSize   = 30,
    majorScale = 1.3,    -- major cooldowns drawn this much larger
    barHeight  = 480,
    layout     = "stack", -- "stack": one column - next assigned cast top-left, my cooldowns top-right, everything approaches one crosshair;
                          -- "hud": perspective tracks + next-up slots; "single": Boss + Cooldowns columns; "lanes": a column per lane
    layoutVersion = 2,
    mineVersion = 2,
    stackVersion = 1,
    stackWidth = 320,    -- stack layout footprint (/tl stacksize)
    stackHeight = 420,
    rowIcon    = 30,     -- size of the parked icons in the stack's top row (/tl rowicon)
    stackBossW = 90,     -- width of the boss lane left of the T's stalk (/tl bosslane)
    stackLinear = true,  -- stack: constant speed from the window edge to the landing line (/tl linear)
    groupGap   = 14,     -- gap between the Major and Other groups
    stackAll   = false,  -- stack: also show other players' planned casts in the column (/tl all)
    trackOther = {},     -- [specID] = { spellID, ... } : the "Other" group, overrides OTHER_DEFAULTS
    graphOn    = true,   -- the fight graph window (/tl graph)
    graphWidth = 440,
    graphHeight = 190,
    graphPoint = nil,    -- nil = top right, left of the minimap; set when you drag it
    graphAll   = false,  -- graph: rows for every healer, not just me (/tl graph all)
    phaseLearned = {},   -- [encounterID] = { [difficultyID] = { [stage] = seconds since pull } } from the last pull's stage changes
    mineOn     = true,   -- the own-cooldowns column (/tl mine)
    mineCDM    = false,  -- draw the plan's countdowns on Blizzard's Cooldown Manager icons instead of the column (/tl cdm)
    minePoint  = nil,    -- nil = attached to the right of the plan bar, landing lines aligned; set when you drag it
    mineOffset = 10,     -- gap between the plan bar and the attached column
    mineSched  = true,   -- show the plan's scheduled casts of each tracked spell (/tl sched)
    mineIcon   = 36,     -- icon size in the "mine" layout
    mineHeight = 380,    -- column height when the column is free-standing (dragged away); attached, it matches the plan bar
    mineGap    = 6,      -- gap between the per-spell tracks
    mineReady  = true,   -- keep ready spells docked at the bottom (/tl ready)
    mineCombat = false,  -- only show the "mine" column in combat (/tl combat)
    mineDesat  = true,   -- grey out spells that are parked beyond the window
    mineBorder = false,  -- class-colour border on the icons (/tl border)
    mineSwipe  = true,   -- native cooldown sweep over the icon (/tl swipe)
    mineNumbers = true,  -- native cooldown number on the icon (works in combat); off = our own text under it (/tl numbers)
    cdDur      = {},     -- [spellID] = last cooldown length seen while readable (feeds the in-combat model)
    track      = {},     -- [specID] = { spellID, ... } : your own list, overrides the defaults below
    hudWidth   = 340,
    hudHeight  = 360,
    depth      = 3,      -- perspective strength (bigger = things stay small until closer)
    slotIcon   = 40,     -- icon size in the two "next up" slots; approaching icons grow to this size
    farIcon    = 10,     -- icon size at the far end of the track
    rails      = false,  -- faint converging guide lines (/tl rails)
    crosshair  = true,   -- reticle where things arrive (/tl crosshair)
    slotPlate  = false,  -- dark backing behind the next-up slots (/tl plate)
    hudVersion = 2,
    colWidth   = 232,    -- Cooldowns column width (fits two icons + labels side by side)
    bossColWidth = 140,
    labelWidth = 76,     -- text beside each icon
    font       = "bundled", -- Barlow Condensed Bold; or condensed | barlow | dejavu | poppins | any LibSharedMedia font name (/tl fonts)
    fontOutline = false, -- outline instead of a drop shadow (/tl outline)
    themeVersion = 1,
    fontSize   = 11,
    barAlpha   = 0,
    showNames  = true,
    showTime   = true,
    showHeaders = true,
    showTicks  = true,
    onlyMine   = false,
    pullTimer  = true,   -- arm the bar from Blizzard / DBM / BigWigs pull timers
    bwLive     = true,   -- draw BigWigs' live boss timers in the Boss lane (hides static boss rows)
    anchorChat = false,  -- chat line each time anchored rows snap to a BigWigs bar (/tl anchorchat)
    links      = true,   -- draw a line from each cooldown to the boss hit it is assigned to (/tl links)
    dmgShow    = true,   -- expected raid damage on boss icons (/tl dmgshow)
    dmgScale   = false,  -- boss icons sized by expected raid damage (/tl dmgscale)
    planBoss   = true,
    follow     = true,
    graphBg    = true,
    graphFont  = 11,     -- fight graph text size (/tl graphfont)
    graphIcon  = 16,     -- fight graph cooldown icon size (/tl graphicon)
    graphAlpha = 0.85,   -- fight graph panel opacity (/tl graphalpha)
    graphTitle = true,   -- boss name + clock on the graph (/tl graphtitle)
    graphBoss  = true,   -- boss-hit tick row on the graph (/tl graphboss)
    graphLegend = true,
    graphVertical = true, -- fight graph: time runs down (/tl graphvert)
    graphTips  = true,   -- tooltips on the boss hits and cooldown icons in the vertical graph (/tl graphtips)
    vgWidth    = 420,    -- vertical graph size
    vgHeight   = 460,
    vgSpan     = 150,    -- seconds of fight visible at once
    vgNow      = 0.3,    -- where the now line sits (share of the height from the top)
    vgBlocks   = 14,     -- damage blocks across  -- "damage · 1 block = ..." on the graph (/tl graphlegend)
    mineLocked = true,   -- the cooldown row's own lock: unlock it to drag it on its own while the HUD stays locked (/tl minelock)   -- the fight graph's panel; off = blocks float over the game with no backdrop (/tl graphbg)   -- slide the plan to the real fight: each BigWigs bar re-times its boss hit, the cooldowns on it and everything after (/tl follow)   -- a plan with its own boss rows shows those (timed to the hit) instead of BigWigs bars (/tl planboss)
    hidden     = false,  -- /tl hide
    pullGrace  = 20,     -- seconds after a pull timer hits 0 to wait for ENCOUNTER_START before giving up
    armed      = nil,    -- { encounterID, difficultyID } chosen with /tl use
    lastFought = nil,    -- { encounterID, difficultyID } from the last ENCOUNTER_START
    point      = { "CENTER", "UIParent", "CENTER", 260, 0 },
}

local PULL_TEXTURE = 132337 -- Ability_Warrior_Charge
local NOTE_TEXTURE = 134327 -- INV_Misc_Note_01

local DB
local DIFF_BY_NAME = { lfr = 17, ["raid finder"] = 17, normal = 14, heroic = 15, mythic = 16 }
local DIFF_NAME    = { [17] = "LFR", [14] = "Normal", [15] = "Heroic", [16] = "Mythic" }

local function Print(msg, ...)
    print("|cffb66effCDTL|r " .. string.format(msg, ...))
end

local function CopyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

------------------------------------------------------------------------
-- Spell helpers (11.0+ C_Spell API with fallbacks)
------------------------------------------------------------------------
local function SpellTexture(id)
    if C_Spell and C_Spell.GetSpellTexture then
        return C_Spell.GetSpellTexture(id)
    elseif GetSpellTexture then
        return GetSpellTexture(id)
    end
end

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(id)
    elseif GetSpellInfo then
        return (GetSpellInfo(id))
    end
end

------------------------------------------------------------------------
-- Parser
--   Header : EncounterID:3492;Difficulty:Heroic;Name:Ula'tek;
--   Row    : ph:1;time:25.8;tag:Knols;spellid:31884;
-- Rows may be newline-separated or all on one line; we tokenise on ';'
-- and start a new entry whenever we see a "ph" key (or a "time" key with
-- no open entry).
------------------------------------------------------------------------
local CLASS_RGB = {
    Paladin = { 0.96, 0.55, 0.73 }, Druid = { 1.00, 0.49, 0.04 }, Priest = { 0.90, 0.90, 0.90 }, Shaman = { 0.00, 0.44, 0.87 },
    Monk = { 0.00, 1.00, 0.60 }, Evoker = { 0.20, 0.58, 0.50 }, ["Demon Hunter"] = { 0.64, 0.19, 0.79 }, Warrior = { 0.78, 0.61, 0.23 },
    ["Death Knight"] = { 0.77, 0.12, 0.23 }, Mage = { 0.25, 0.78, 0.92 }, Hunter = { 0.67, 0.83, 0.45 }, Rogue = { 1.00, 0.96, 0.41 }, Warlock = { 0.53, 0.53, 0.93 },
}
local CLASS_ALIAS = { dk = "Death Knight", deathknight = "Death Knight", dh = "Demon Hunter", demonhunter = "Demon Hunter" }

-- spell names that may appear inside free-text notes ("Hold Dream Breath") -> icon
local NOTE_SPELLS = {
    ["dream breath"] = 355936, ["spiritbloom"] = 367226, ["temporal anomaly"] = 373861, ["emerald communion"] = 370960,
    ["dream flight"] = 359816, ["rewind"] = 363534, ["stasis"] = 370537, ["zephyr"] = 374227, ["time spiral"] = 374968,
    ["tranquility"] = 740, ["tranq"] = 740, ["convoke"] = 391528, ["flourish"] = 197721, ["tree of life"] = 33891,
    ["healing tide"] = 108280, ["spirit link"] = 98008, ["ascendance"] = 114052, ["ancestral protection"] = 207399, ["mana tide"] = 16191,
    ["divine hymn"] = 64843, ["apotheosis"] = 200183, ["salvation"] = 265202, ["symbol of hope"] = 64901, ["guardian spirit"] = 47788,
    ["barrier"] = 62618, ["rapture"] = 47536, ["evangelism"] = 246287, ["pain suppression"] = 33206, ["power infusion"] = 10060,
    ["aura mastery"] = 31821, ["avenging wrath"] = 31884, ["divine toll"] = 375576, ["lay on hands"] = 633,
    ["revival"] = 115310, ["restoral"] = 388615, ["yu'lon"] = 322118, ["chi-ji"] = 325197, ["cocoon"] = 116849,
    ["darkness"] = 196718, ["rallying cry"] = 97462, ["anti-magic zone"] = 51052, ["amz"] = 51052, ["stampeding roar"] = 106898, ["wind rush"] = 192077,
}

local function FinishNote(note)
    -- class colour per entry, gold ring for the second (third...) player of the same class
    local classOf, firstOfClass = {}, {}
    note.ring = {}
    for _, e in ipairs(note.entries) do
        if e.class and not e.classRGB then
            local cname = CLASS_ALIAS[e.class:lower():gsub("%s", "")] or e.class
            e.classRGB = CLASS_RGB[cname]
            e.className = cname
        end
        if e.tag and e.tag ~= "" and e.className then classOf[e.tag] = e.className end
    end
    -- first appearance order = time order of first use
    for _, e in ipairs(note.entries) do
        local tag = e.tag
        if tag and tag ~= "" and classOf[tag] then
            local cls = classOf[tag]
            if not firstOfClass[cls] then firstOfClass[cls] = tag
            elseif firstOfClass[cls] ~= tag then note.ring[tag] = true end
        end
    end
    for _, e in ipairs(note.entries) do
        if e.tag and note.ring[e.tag] then e.ring = true end
        -- free-text notes that name a spell get that spell's icon
        if e.isNote and not e.spellID and e.label then
            local low = e.label:lower()
            for name, id in pairs(NOTE_SPELLS) do
                if low:find(name, 1, true) then e.spellID = id; e.noteSpell = true break end
            end
        end
    end
    return note
end

-- Extended rows from the Ramp Planner export add:
--   lanedef:<id>;name:<Lane name>;kind:boss|tank|healer|raid|util;
--   ...;lane:<id>;label:<text>;cd:<seconds>;major:0|1;
-- A plain Viserio string (no lanedefs) becomes a single "Raid CD" lane.
local function ParseNote(text)
    local note = { entries = {}, lanes = {}, curves = {} }
    local cur, curLane, curCurve, curPhase

    for pair in text:gmatch("[^;\r\n]+") do
        local k, v = pair:match("^%s*([%w_]+)%s*:%s*(.-)%s*$")
        if k then
            k = k:lower()
            if k == "encounterid" then
                note.encounterID = tonumber(v); cur = nil; curLane = nil
            elseif k == "difficulty" then
                note.difficulty = v
            elseif k == "name" then
                if curLane then curLane.name = v else note.name = v end
            elseif k == "lanedef" then
                curLane = { id = v, name = v, kind = "util" }
                note.lanes[#note.lanes + 1] = curLane
                cur = nil; curCurve = nil
            elseif k == "duration" then
                note.duration = tonumber(v)
            elseif k == "phase" then
                -- our extension: phase:2;start:95;  (seconds since pull at which stage 2 begins)
                curPhase = tonumber(v); cur = nil; curLane = nil; curCurve = nil
            elseif k == "start" and curPhase then
                note.phaseStarts = note.phaseStarts or {}
                note.phaseStarts[curPhase] = tonumber(v)
            elseif k == "curve" then
                curCurve = { id = v:lower(), step = 5, unit = "k", data = {} }
                note.curves[curCurve.id] = curCurve
                cur = nil; curLane = nil
            elseif k == "step" and curCurve then
                curCurve.step = tonumber(v) or 5
            elseif k == "unit" and curCurve then
                curCurve.unit = v
            elseif k == "data" and curCurve then
                for n in v:gmatch("[^,%s]+") do curCurve.data[#curCurve.data + 1] = tonumber(n) or 0 end
            elseif k == "kind" then
                if curLane then curLane.kind = v:lower() end
            elseif k == "color" and curLane then
                local hex = v:gsub("#", "")
                local r, g, b = hex:match("^(%x%x)(%x%x)(%x%x)$")
                if r then curLane.color = { tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255 } end
            elseif k == "ph" then
                cur = { ph = tonumber(v) or 1 }
                note.entries[#note.entries + 1] = cur
                curLane = nil
            elseif k == "time" then
                if not cur or cur.time then
                    cur = { ph = 1 }
                    note.entries[#note.entries + 1] = cur
                end
                cur.time = tonumber(v)
                curLane = nil
            elseif cur then
                if k == "tag" then cur.tag = v
                elseif k == "spellid" then cur.spellID = tonumber(v)
                elseif k == "lane" then cur.lane = v
                elseif k == "label" then cur.label = v
                elseif k == "cd" then cur.cd = tonumber(v)
                elseif k == "major" then cur.major = (v == "1" or v:lower() == "true")
                elseif k == "class" then cur.class = v
                elseif k == "win" then local a, b = v:match("^%s*(%-?[%d.]+)%s*,%s*(%-?[%d.]+)"); if a then cur.win = { tonumber(a), tonumber(b) } end
                elseif k == "anchor" then cur.anchor = tonumber(v) or v
                elseif k == "n" then cur.anchorN = tonumber(v) or 1
                elseif k == "offset" then cur.anchorOff = tonumber(v) or 0
                end
            end
        end
    end

    -- lanes: default single lane for plain Viserio strings
    if #note.lanes == 0 then
        note.lanes[1] = { id = "raid", name = "Raid CD", kind = "raid" }
    end
    local laneByID, bossLane, cdLane = {}, nil, nil
    for i, l in ipairs(note.lanes) do
        laneByID[l.id] = i
        if l.kind == "boss" and not bossLane then bossLane = i end
        if l.kind ~= "boss" and not cdLane then cdLane = i end
    end
    note.bossLane = bossLane
    cdLane = cdLane or 1

    -- drop incomplete rows, resolve lanes, sort by time
    local clean = {}
    for _, e in ipairs(note.entries) do
        local isBoss = (e.tag or ""):upper() == "BOSS"
        if e.time and (e.spellID or e.label) then
            e.tag = isBoss and "" or (e.tag or "")
            e.spellID = e.spellID or 0
            if e.spellID == 0 then e.spellID = nil end
            e.laneIndex = (e.lane and laneByID[e.lane]) or (isBoss and bossLane) or cdLane
            e.isBoss = isBoss or (note.lanes[e.laneIndex].kind == "boss")
            e.isNote = (not e.spellID) and not e.isBoss
            if e.major == nil then e.major = (e.cd or 0) >= 120 end
            clean[#clean + 1] = e
        end
    end
    -- Viserio's note strings give each row's time relative to the start of its phase (ph:N).
    -- Keep the relative time; StartEncounter anchors it when the stage actually begins.
    for _, e in ipairs(clean) do
        e.rel = e.time
        if (e.ph or 1) > 1 then note.phaseRelative = true end
        if e.anchor ~= nil and e.anchor ~= "" and e.anchor ~= 0 then
            e.anchorN = e.anchorN or 1
            e.anchorOff = e.anchorOff or 0
            note.hasAnchors = true
        else
            e.anchor = nil
        end
    end
    table.sort(clean, function(a, b) if (a.ph or 1) ~= (b.ph or 1) then return (a.ph or 1) < (b.ph or 1) end return a.time < b.time end)
    note.entries = clean

    note.difficultyID = DIFF_BY_NAME[(note.difficulty or ""):lower()] or 0
    FinishNote(note)
    -- the game's fonts draw a box for arrows and long dashes: swap them for plain characters (same as LK.Clean)
    for _, e in ipairs(note.entries) do
        if e.label then e.label = e.label:gsub("\226\134\146", ">"):gsub("\226\134\144", "<"):gsub("\226\128\148", "-"):gsub("\226\128\147", "-") end
    end
    note.cleaned = true
    return note
end

------------------------------------------------------------------------
-- Viserio plan export: base64-wrapped MessagePack
------------------------------------------------------------------------
local B64 = {}
do
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    for i = 1, 64 do B64[chars:sub(i, i)] = i - 1 end
end

local function Base64Decode(text)
    text = text:gsub("[^%w%+/=]", "")
    local out, n, bits = {}, 0, 0
    for i = 1, #text do
        local c = text:sub(i, i)
        if c == "=" then break end
        local v = B64[c]
        if v then
            n = n * 64 + v; bits = bits + 6
            if bits >= 8 then
                bits = bits - 8
                local byte = math.floor(n / 2 ^ bits)
                out[#out + 1] = string.char(byte)
                n = n - byte * 2 ^ bits
            end
        end
    end
    return table.concat(out)
end

local function MsgpackDecode(data)
    local pos = 1
    local function byte() local b = data:byte(pos); pos = pos + 1; return b end
    local function uint(n) local v = 0; for _ = 1, n do v = v * 256 + byte() end; return v end
    local function int(n)
        local v = uint(n)
        if v >= 2 ^ (8 * n - 1) then v = v - 2 ^ (8 * n) end
        return v
    end
    local function float(nbytes)
        local b = { data:byte(pos, pos + nbytes - 1) }; pos = pos + nbytes
        local sign = (b[1] >= 128) and -1 or 1
        local exp, mant, ebits, mbits
        if nbytes == 8 then
            exp = (b[1] % 128) * 16 + math.floor(b[2] / 16)
            mant = b[2] % 16
            for i = 3, 8 do mant = mant * 256 + b[i] end
            ebits, mbits = 1023, 52
        else
            exp = (b[1] % 128) * 2 + math.floor(b[2] / 128)
            mant = b[2] % 128
            for i = 3, 4 do mant = mant * 256 + b[i] end
            ebits, mbits = 127, 23
        end
        if exp == 0 and mant == 0 then return 0 * sign end
        return sign * (1 + mant / 2 ^ mbits) * 2 ^ (exp - ebits)
    end
    local function str(n) local s = data:sub(pos, pos + n - 1); pos = pos + n; return s end
    local val
    local function arr(n) local t = {}; for i = 1, n do t[i] = val() end; return t end
    local function map(n) local t = {}; for _ = 1, n do local k = val(); t[k] = val() end; return t end
    val = function()
        local b = byte()
        if not b then error("msgpack: truncated") end
        if b < 0x80 then return b end
        if b >= 0xe0 then return b - 256 end
        if b >= 0xa0 and b <= 0xbf then return str(b - 0xa0) end
        if b >= 0x90 and b <= 0x9f then return arr(b - 0x90) end
        if b >= 0x80 and b <= 0x8f then return map(b - 0x80) end
        if b == 0xc0 then return nil elseif b == 0xc2 then return false elseif b == 0xc3 then return true
        elseif b == 0xc4 then return str(uint(1)) elseif b == 0xc5 then return str(uint(2)) elseif b == 0xc6 then return str(uint(4))
        elseif b == 0xca then return float(4) elseif b == 0xcb then return float(8)
        elseif b == 0xcc then return uint(1) elseif b == 0xcd then return uint(2) elseif b == 0xce then return uint(4) elseif b == 0xcf then return uint(8)
        elseif b == 0xd0 then return int(1) elseif b == 0xd1 then return int(2) elseif b == 0xd2 then return int(4) elseif b == 0xd3 then return int(8)
        elseif b == 0xd9 then return str(uint(1)) elseif b == 0xda then return str(uint(2)) elseif b == 0xdb then return str(uint(4))
        elseif b == 0xdc then return arr(uint(2)) elseif b == 0xdd then return arr(uint(4))
        elseif b == 0xde then return map(uint(2)) elseif b == 0xdf then return map(uint(4))
        end
        error(string.format("msgpack: unsupported byte 0x%02x at %d", b, pos - 1))
    end
    return val()
end

local HEAL_SPECS = { Preservation = true, Restoration = true, Holy = true, Discipline = true, Mistweaver = true }

local function LooksLikeBlob(text)
    return not text:find("[;:]") and text:match("^%s*[%w%+/=%s]+$") ~= nil
end

-- Build a note from a Viserio plan export: Boss lane, one lane per healer, one shared lane for the rest.
local function ParseViserioBlob(text)
    local ok, plan = pcall(function() return MsgpackDecode(Base64Decode(text)) end)
    if not ok then return nil, tostring(plan) end
    if type(plan) ~= "table" or type(plan.actors) ~= "table" then return nil, "no actors in export" end

    local note = { entries = {}, lanes = { { id = "boss", name = "Boss", kind = "boss" } }, encounterID = 0, difficultyID = 0, name = "Viserio import", fromViserio = true }
    local laneIndex = {}
    local function slug(n) return (n:lower():gsub("[^%w]", "")) end
    for _, a in ipairs(plan.actors) do
        local hasStuff = (a.spells and #a.spells > 0) or (a.notes and #a.notes > 0)
        if hasStuff and HEAL_SPECS[a.playerSpec or ""] then
            local id = "p_" .. slug(a.name or "?")
            note.lanes[#note.lanes + 1] = { id = id, name = a.name, kind = "healer", color = CLASS_RGB[a.playerClass or ""] }
            laneIndex[id] = #note.lanes
        end
    end
    note.lanes[#note.lanes + 1] = { id = "raid", name = "Raid", kind = "raid" }
    local raidLane = #note.lanes

    for _, a in ipairs(plan.actors) do
        local lane = laneIndex["p_" .. slug(a.name or "?")] or raidLane
        for _, sp in ipairs(a.spells or {}) do
            local info = sp.spell or {}
            note.entries[#note.entries + 1] = {
                ph = 1, time = tonumber(sp.startTime) or 0, tag = a.name or "", spellID = tonumber(info.spellId),
                label = info.spellName, cd = tonumber(sp.cooldown) or 0, laneIndex = lane, isBoss = false,
                major = (tonumber(sp.cooldown) or 0) >= 120, class = a.playerClass,
            }
        end
        for _, nt in ipairs(a.notes or {}) do
            local everyone = (a.name == "Everyone")
            note.entries[#note.entries + 1] = {
                ph = 1, time = tonumber(nt.startTime) or 0, tag = everyone and "" or (a.name or ""), spellID = nil,
                label = nt.noteText or "", cd = 0, laneIndex = everyone and raidLane or lane, isBoss = false, major = false, isNote = true,
                class = (not everyone) and a.playerClass or nil,
            }
        end
    end
    table.sort(note.entries, function(x, y) return x.time < y.time end)
    for i, l in ipairs(note.lanes) do if l.kind == "boss" then note.bossLane = i break end end
    FinishNote(note)
    return note
end

-- notes saved by v0.1/0.2 have no lane data
local function UpgradeNote(note)
    if note.lanes then return note end
    note.lanes = { { id = "raid", name = "Raid CD", kind = "raid" } }
    for _, e in ipairs(note.entries) do e.laneIndex = 1; e.major = e.major or false end
    FinishNote(note)
    return note
end

------------------------------------------------------------------------
-- "mine" layout: my own major cooldowns from their real cooldowns.
-- Defaults per healing spec (spec ID); only spells you actually know are
-- shown, so talent swaps (Stasis <-> Dream Flight) sort themselves out.
-- /tl track add|remove <spellID> edits the list for the current spec.
------------------------------------------------------------------------
local TRACK_DEFAULTS = {
    [1468] = { 370537, 363534, 359816, 370960 },             -- Preservation: Stasis, Rewind, Dream Flight, Emerald Communion
    [65]   = { 31884, 216331, 31821, 375576, 633 },          -- Holy Paladin: Avenging Wrath / Avenging Crusader, Aura Mastery, Divine Toll, Lay on Hands
    [105]  = { 740, 391528, 197721, 33891 },                 -- Resto Druid: Tranquility, Convoke, Flourish, Tree of Life
    [264]  = { 108280, 98008, 114052, 207399, 16191 },       -- Resto Shaman: Healing Tide, Spirit Link, Ascendance, Ancestral Protection, Mana Tide
    [257]  = { 64843, 200183, 265202, 47788, 64901 },        -- Holy Priest: Divine Hymn, Apotheosis, Salvation, Guardian Spirit, Symbol of Hope
    [256]  = { 62618, 47536, 246287, 33206, 10060 },         -- Discipline: Barrier, Rapture, Evangelism, Pain Suppression, Power Infusion
    [270]  = { 115310, 388615, 322118, 325197, 116849 },     -- Mistweaver: Revival / Restoral, Yu'lon / Chi-Ji, Life Cocoon
}
-- the "Other" group: individual ability timelines beside the majors
local OTHER_DEFAULTS = {
    [1468] = { 374968 },                                     -- Preservation: Time Spiral
}
local GCD_SPELL = 61304

local function CurrentSpecID()
    if GetSpecialization and GetSpecializationInfo then
        local idx = GetSpecialization()
        if idx then return (GetSpecializationInfo(idx)) end
    end
end

local function SpellKnown(id)
    if IsPlayerSpell then local ok, r = pcall(IsPlayerSpell, id); if ok and r then return true end end
    if IsSpellKnownOrOverridesKnown then local ok, r = pcall(IsSpellKnownOrOverridesKnown, id); if ok and r then return true end end
    if C_SpellBook and C_SpellBook.IsSpellInSpellBook then local ok, r = pcall(C_SpellBook.IsSpellInSpellBook, id); if ok and r then return true end end
    if IsPlayerSpell or IsSpellKnownOrOverridesKnown or (C_SpellBook and C_SpellBook.IsSpellInSpellBook) then return false end
    return true -- no way to check on this client: show it
end

-- raw start/duration of a spell's cooldown (11.0+ table API, old-style fallback)
-- 12.0: while an encounter / combat is running the start and duration of your
-- cooldowns are "secret" - addon code can't compare them or do arithmetic on
-- them, only hand them to a Cooldown widget. isActive / isEnabled / isOnGCD
-- stay readable. So: readable values -> exact; secret -> a model driven by
-- UNIT_SPELLCAST_SUCCEEDED plus the last cooldown length we saw readable
-- (or the spell's base cooldown), corrected by isActive.
local function IsSecret(v)
    if issecretvalue then local ok, r = pcall(issecretvalue, v); if ok and r then return true end end
    return false
end

-- base cooldowns for the defaults, used until a real one has been observed
local BASE_CD = {
    [370537] = 90, [363534] = 240, [359816] = 120, [370960] = 180, [374968] = 120, [374227] = 120, [363916] = 90,
    [31884] = 120, [216331] = 120, [31821] = 180, [375576] = 60, [633] = 600,
    [740] = 180, [391528] = 120, [197721] = 60, [33891] = 180,
    [108280] = 180, [98008] = 180, [114052] = 180, [207399] = 300, [16191] = 180,
    [64843] = 180, [200183] = 120, [265202] = 720, [47788] = 180, [64901] = 180,
    [62618] = 180, [47536] = 90, [246287] = 90, [33206] = 180, [10060] = 120,
    [115310] = 180, [388615] = 180, [322118] = 180, [325197] = 180, [116849] = 120,
}

local function ModelDuration(id)
    local d = DB.cdDur and DB.cdDur[id]
    if d and d > 1.6 then return d end
    if GetSpellBaseCooldown then
        local ok, ms = pcall(GetSpellBaseCooldown, id)
        if ok and ms and not IsSecret(ms) and ms > 1600 then return ms / 1000 end
    end
    return BASE_CD[id] or 120
end

-- info table from the 11.0+ API (fields may be secret), or an old-style tuple
local function CooldownInfo(id)
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, t = pcall(C_Spell.GetSpellCooldown, id)
        if ok and t then return t.startTime, t.duration, t.isActive, t.isOnGCD, t.isEnabled end
    elseif GetSpellCooldown then
        local ok, st, d, en = pcall(GetSpellCooldown, id)
        if ok then return st, d, nil, nil, en end
    end
end

local function RawCharges(id)
    if C_Spell and C_Spell.GetSpellCharges then
        local ok, t = pcall(C_Spell.GetSpellCharges, id)
        if ok and t and t.maxCharges then return t.currentCharges, t.maxCharges, t.cooldownStartTime, t.cooldownDuration end
    elseif GetSpellCharges then
        local ok, c, m, st, d = pcall(GetSpellCharges, id)
        if ok and m then return c, m, st, d end
    end
end

-- returns: rem (nil = not readable right now), dur, active (true/false/nil), start, dur (raw, for SetCooldown)
local function ReadCooldownRaw(id)
    local start, dur, active, onGCD = CooldownInfo(id)
    if active ~= nil and IsSecret(active) then active = nil end
    local cur, max, cst, cdur = RawCharges(id)
    if max and not IsSecret(max) and not IsSecret(cur) and max > 1 then
        if cur > 0 then return 0, 0, false end
        start, dur = cst, cdur
    end
    if start == nil or dur == nil then return 0, 0, false end
    if IsSecret(start) or IsSecret(dur) then return nil, nil, active end
    if dur == 0 then return 0, 0, false end
    if onGCD == true then return 0, 0, false end
    local gStart, gDur = CooldownInfo(GCD_SPELL)
    if gDur and not IsSecret(gDur) and not IsSecret(gStart) and gDur > 0 and start == gStart and dur == gDur then return 0, 0, false end
    if dur <= 1.6 then return 0, 0, false end
    local rem = start + dur - GetTime()
    if rem < 0 then rem = 0 end
    return rem, dur, rem > 0, start, dur
end

local function ReadCooldown(id)
    local ok, rem, dur, active, st, d = pcall(ReadCooldownRaw, id)
    if not ok then return nil, nil, nil end
    return rem, dur, active, st, d
end

local function FmtClock(t)
    t = math.max(0, math.floor(t + 0.5))
    return string.format("%d:%02d", math.floor(t / 60), t % 60)
end

local function FmtRem(rem)
    if rem >= 60 then return string.format("%d:%02d", math.floor(rem / 60), math.floor(rem % 60)) end
    if rem >= 10 then return string.format("%d", rem) end
    return string.format("%.1f", rem)
end

------------------------------------------------------------------------
-- Bar frame
------------------------------------------------------------------------
local bar        = CreateFrame("Frame", "CDTimelineBar", UIParent, "BackdropTemplate")
local iconPool   = {}
local activeIcons = {}
local state      = {
    active = false, startTime = 0, note = nil, entries = nil, nextIndex = 1,
    test = false,
    awaitingPull = false, -- armed from a pull timer, ENCOUNTER_START not yet seen
    live = {},            -- BigWigs bars currently running, keyed by bar text
    liveBoss = false,     -- BigWigs has fed us at least one bar this encounter
}

local HEADER_H = 18

------------------------------------------------------------------------
-- Fonts: bundled TTFs, or any LibSharedMedia font (e.g. from Dander's Frames)
------------------------------------------------------------------------
-- Crystal Ball palette (Stormchaser's "mystic glass, gem accents" theme, from client/src/themes/crystal-ball.ts)
-- The field names are generic roles: "gold" is the primary accent, here amethyst; "goldHi" the highlight, here diamond.
local T = {
    bg      = { 0.024, 0.012, 0.059 },   -- --background #06030f, deep void
    card    = { 0.110, 0.063, 0.227 },   -- --card rgb(28,16,58)
    panel   = { 0.133, 0.078, 0.275 },   -- --secondary rgb(34,20,70)
    border  = { 0.549, 0.314, 0.863 },   -- smoke purple rgb(140,80,220); drawn at ~0.35 alpha
    border2 = { 0.549, 0.314, 0.863 },
    fg      = { 0.941, 0.922, 1.000 },   -- --foreground #f0ebff
    fg2     = { 0.847, 0.784, 1.000 },   -- --secondary-foreground #d8c8ff
    muted   = { 0.706, 0.627, 0.863 },   -- --muted-foreground rgb(180,160,220)
    gold    = { 0.714, 0.431, 1.000 },   -- --primary amethyst #b66eff
    goldHi  = { 0.910, 0.957, 1.000 },   -- diamond #e8f4ff (selected / shimmer)
    green   = { 0.000, 0.902, 0.463 },   -- emerald #00e676 (ready, NOW, healing)
    amber   = { 1.000, 0.671, 0.000 },   -- topaz #ffab00 (damage)
    red     = { 1.000, 0.176, 0.333 },   -- ruby #ff2d55 (late, boss)
    blue    = { 0.161, 0.475, 1.000 },   -- sapphire #2979ff (phases)
    shadow  = { 0.039, 0.016, 0.094 },   -- text shadow: the void, not black
}
local BORDER_A = 0.38
local function Col(fs, c, a) fs:SetTextColor(c[1], c[2], c[3], a or 1) end
local function Tex(t, c, a) t:SetColorTexture(c[1], c[2], c[3], a or 1) end
-- saved positions: only a complete point is usable (Midnight can hand back nothing from GetPoint, which saved as a broken point)
function ns.ValidPoint(p)
    return type(p) == "table" and type(p[1]) == "string" and type(p[3]) == "string" and type(p[4]) == "number" and type(p[5]) == "number"
end
function ns.SavePoint(frame)
    local ok, t = pcall(function()
        local p, _, rp, x, y = frame:GetPoint(1)
        return { p, "UIParent", rp, x + 0, y + 0 }
    end)
    if ok and ns.ValidPoint(t) then return t end
    ok, t = pcall(function()
        local k = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
        return { "BOTTOMLEFT", "UIParent", "BOTTOMLEFT", frame:GetLeft() * k, frame:GetBottom() * k }
    end)
    if ok and ns.ValidPoint(t) then return t end
    return nil
end
ns.T = T

local FONT_DIR = "Interface\\AddOns\\CDTimeline\\Fonts\\"
local BUNDLED_FONTS = {
    bundled   = FONT_DIR .. "BarlowCondensed-Bold.ttf",       -- the default: Stormchaser's display face
    condensed = FONT_DIR .. "BarlowCondensed-SemiBold.ttf",
    barlow    = FONT_DIR .. "Barlow-SemiBold.ttf",
    barlowmedium = FONT_DIR .. "Barlow-Medium.ttf",
    dejavu    = FONT_DIR .. "DejaVuSansCondensed-Bold.ttf",
    poppins   = FONT_DIR .. "Poppins-Bold.ttf",
}
local fontPath = BUNDLED_FONTS.bundled

local function GetLSM()
    return LibStub and LibStub("LibSharedMedia-3.0", true) or nil
end

local function ResolveFont()
    local want = DB.font or "bundled"
    if BUNDLED_FONTS[want:lower()] then return BUNDLED_FONTS[want:lower()] end
    local LSM = GetLSM()
    if LSM then
        local ok, path = pcall(LSM.Fetch, LSM, "font", want, true)
        if ok and path then return path end
        -- case-insensitive match against the registered list
        local okL, list = pcall(LSM.List, LSM, "font")
        if okL and list then
            for _, name in ipairs(list) do
                if name:lower() == want:lower() then
                    local ok2, p2 = pcall(LSM.Fetch, LSM, "font", name, true)
                    if ok2 and p2 then return p2 end
                end
            end
        end
    end
    return BUNDLED_FONTS.bundled
end

-- crisp text: no outline, a tight drop shadow (DB.fontOutline swaps it for an outline when the scene is busy)
local function ApplyFont(fs, size, flags)
    if flags == nil and DB and DB.fontOutline then flags = "OUTLINE" end
    fs:SetFont(fontPath, size, flags or "")
    if fs.SetShadowOffset then fs:SetShadowOffset(1, -1); fs:SetShadowColor(T.shadow[1], T.shadow[2], T.shadow[3], flags and 0.5 or 0.9) end
end
ns.ApplyFont = ApplyFont

------------------------------------------------------------------------
-- Display columns
--   layout = "single": Boss column + one column for every cooldown
--   layout = "lanes" : one column per lane from the note
------------------------------------------------------------------------
local columns = {} -- { {x=, w=, name=, kind=}, ... }

-- the inverted T: the stalk separates boss abilities (left) from mine (right)
local function StalkX() return DB.stackBossW + 8 end
ns.StalkX = StalkX
-- bottom of the next-cast slot icon: its big countdown and your name sit under it
local function SlotBottom() return 2 * DB.fontSize + 16 end
ns.SlotBottom = SlotBottom

local function BuildColumns()
    wipe(columns)
    local note = state.note
    local x = 4
    if DB.layout == "stack" then
        -- everything of mine is left-justified against the stalk and grows rightwards
        local rowW = ns.StackRowWidth and ns.StackRowWidth() or 0
        local underW = DB.slotIcon + 4 + 2 * (DB.rowIcon + 4)
        local sx = StalkX()
        local W = math.max(DB.stackWidth, sx + 6 + math.max(rowW, underW) + 8)
        columns[1] = { x = 0, w = W, name = "", kind = "all", slotX = sx + 6 + math.max(rowW, 0) + 8 + DB.rowIcon * 0.5, side = 1, slotBL = true }   -- untracked casts of mine: lane past the last column
        columns[2] = { x = 0, w = W, name = "Boss", kind = "boss", slotX = sx - 8 - DB.rowIcon * 0.5, side = -1, noSlot = true }
        return W
    end
    if DB.layout == "hud" then
        local W = DB.hudWidth
        local hasBoss = not note or note.bossLane ~= nil or note.synthetic
        local hasCD = not note or not note.synthetic
        if hasBoss and hasCD then
            columns[1] = { x = 0, w = W / 2, name = "Boss", kind = "boss", slotX = W * 0.25, side = -1 }
            columns[2] = { x = W / 2, w = W / 2, name = "Cooldowns", kind = "all", slotX = W * 0.75, side = 1 }
        elseif hasBoss then
            columns[1] = { x = 0, w = W, name = "Boss", kind = "boss", slotX = W * 0.5, side = -1 }
        else
            columns[1] = { x = 0, w = W, name = "Cooldowns", kind = "all", slotX = W * 0.5, side = 1 }
        end
        return W
    end
    if DB.layout == "lanes" and note then
        for i, l in ipairs(note.lanes) do
            local w = (l.kind == "boss") and DB.bossColWidth or DB.colWidth
            columns[i] = { x = x, w = w, name = l.name or l.id, kind = l.kind, lane = i }
            x = x + w
        end
    else
        local hasBoss = not note or note.bossLane ~= nil or note.synthetic
        if hasBoss then
            columns[#columns + 1] = { x = x, w = DB.bossColWidth, name = "Boss", kind = "boss" }
            x = x + DB.bossColWidth
        end
        if not note or not note.synthetic then
            columns[#columns + 1] = { x = x, w = DB.colWidth, name = "Cooldowns", kind = "all" }
            x = x + DB.colWidth
        end
    end
    if #columns == 0 then columns[1] = { x = 4, w = DB.colWidth, name = "Cooldowns", kind = "all" } end
    return x + 4
end

local function ColumnFor(e)
    if DB.layout == "lanes" then
        return columns[e.laneIndex or 1] or columns[1]
    end
    if e.isBoss or e.pull then
        for _, c in ipairs(columns) do if c.kind == "boss" then return c end end
    end
    for _, c in ipairs(columns) do if c.kind == "all" then return c end end
    return columns[1]
end

-- y offset (from the now line, upwards) for "rem" seconds away.
-- Piecewise: the last `imminent` seconds take `imminentFrac` of the travel,
-- the rest of the lookahead takes the remainder - so icons accelerate as they
-- close in, and the whole ramp stays readable further up.
local function YForRem(rem, travel)
    local imm, look = DB.imminent, DB.lookahead
    if imm >= look then return (rem / look) * travel end
    local immH = travel * DB.imminentFrac
    if rem <= imm then
        return (rem / imm) * immH
    end
    return immH + ((rem - imm) / (look - imm)) * (travel - immH)
end

local headerStrings, tickLines, tickStrings, colLines = {}, {}, {}, {}

local slots = {}   -- [column] = slot frame

local function NewSlot()
    local f = CreateFrame("Frame", nil, bar)
    f:EnableMouse(false)
    f.plate = f:CreateTexture(nil, "BACKGROUND", nil, -2)
    Tex(f.plate, T.card, 0.7)
    f.ring = f:CreateTexture(nil, "BACKGROUND", nil, -1)
    f.border = f:CreateTexture(nil, "BACKGROUND", nil, 0)
    f.bg = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    f.bg:SetColorTexture(0, 0, 0, 1)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.cd = f:CreateFontString(nil, "OVERLAY")     -- big countdown
    f.l1 = f:CreateFontString(nil, "OVERLAY")     -- who / mechanic
    f.l2 = f:CreateFontString(nil, "OVERLAY")     -- spell
    f.l1:SetWordWrap(false); f.l2:SetWordWrap(false)
    f:Hide()
    return f
end

local function LayoutSlot(f, col)
    local size = DB.slotIcon
    local textW = col.w - size - 12
    f:ClearAllPoints()
    f:SetSize(size, size)
    if col.slotBL then
        f:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", StalkX() + 6, SlotBottom())
        f.ring:ClearAllPoints(); f.ring:SetPoint("TOPLEFT", -3, 3); f.ring:SetPoint("BOTTOMRIGHT", 3, -3)
        f.border:ClearAllPoints(); f.border:SetPoint("TOPLEFT", -1, 1); f.border:SetPoint("BOTTOMRIGHT", 1, -1)
        f.bg:ClearAllPoints(); f.bg:SetAllPoints()
        f.tex:ClearAllPoints(); f.tex:SetAllPoints()
        ApplyFont(f.cd, DB.fontSize + 8); ApplyFont(f.l1, DB.fontSize); ApplyFont(f.l2, DB.fontSize)
        f.cd:ClearAllPoints(); f.l1:ClearAllPoints(); f.l2:ClearAllPoints()
        f.cd:SetPoint("TOP", f, "BOTTOM", 0, -1); f.cd:SetJustifyH("CENTER"); f.cd:SetWidth(size + 24)
        f.l1:SetPoint("TOP", f.cd, "BOTTOM", 0, 0); f.l1:SetJustifyH("CENTER"); f.l1:SetWidth(size + 40)
        f.l2:SetPoint("TOP", f.l1, "BOTTOM", 0, 0); f.l2:SetWidth(0); f.l2:Hide()
        f.plate:Hide()
        return
    end
    f.l2:Show()
    if col.slotBL then f:SetPoint("BOTTOM", bar, "BOTTOMLEFT", col.slotX, 4) else f:SetPoint("BOTTOM", bar, "BOTTOMLEFT", col.slotX, 6) end
    f.ring:ClearAllPoints(); f.ring:SetPoint("TOPLEFT", -3, 3); f.ring:SetPoint("BOTTOMRIGHT", 3, -3)
    f.border:ClearAllPoints(); f.border:SetPoint("TOPLEFT", -1, 1); f.border:SetPoint("BOTTOMRIGHT", 1, -1)
    f.bg:ClearAllPoints(); f.bg:SetAllPoints()
    f.tex:ClearAllPoints(); f.tex:SetAllPoints()
    ApplyFont(f.cd, DB.fontSize + 7)
    ApplyFont(f.l1, DB.fontSize + 1)
    ApplyFont(f.l2, DB.fontSize)
    f.cd:ClearAllPoints(); f.l1:ClearAllPoints(); f.l2:ClearAllPoints()
    f.plate:ClearAllPoints()
    if col.side < 0 then
        -- text to the left of the icon, right-aligned
        f.cd:SetPoint("TOPRIGHT", f, "TOPLEFT", -6, 2);   f.cd:SetJustifyH("RIGHT")
        f.l1:SetPoint("TOPRIGHT", f.cd, "BOTTOMRIGHT", 0, -1); f.l1:SetJustifyH("RIGHT")
        f.l2:SetPoint("TOPRIGHT", f.l1, "BOTTOMRIGHT", 0, -1); f.l2:SetJustifyH("RIGHT")
        f.plate:SetPoint("TOPLEFT", f, "TOPLEFT", -textW - 8, 6); f.plate:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 6, -6)
    else
        f.cd:SetPoint("TOPLEFT", f, "TOPRIGHT", 6, 2);    f.cd:SetJustifyH("LEFT")
        f.l1:SetPoint("TOPLEFT", f.cd, "BOTTOMLEFT", 0, -1); f.l1:SetJustifyH("LEFT")
        f.l2:SetPoint("TOPLEFT", f.l1, "BOTTOMLEFT", 0, -1); f.l2:SetJustifyH("LEFT")
        f.plate:SetPoint("TOPLEFT", f, "TOPLEFT", -6, 6); f.plate:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", textW + 8, -6)
    end
    f.cd:SetWidth(textW); f.l1:SetWidth(textW); f.l2:SetWidth(textW)
    if DB.slotPlate == false then f.plate:Hide() else f.plate:Show() end
end

local function ApplyBarLayout()
    fontPath = ResolveFont()
    local width = BuildColumns()
    local isHud = DB.layout == "hud"
    local isStack = DB.layout == "stack"
    local bare = isHud or isStack
    bar.vanishX = width * 0.5
    bar.width = width
    bar:SetSize(width, isStack and DB.stackHeight or (isHud and DB.hudHeight or DB.barHeight))
    bar:ClearAllPoints()
    if not ns.ValidPoint(DB.point) then DB.point = { "CENTER", "UIParent", "CENTER", 0, -40 } end
    local p = DB.point
    bar:SetPoint(p[1], UIParent, p[3], p[4], p[5])

    bar:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    local a = DB.locked and DB.barAlpha or math.max(DB.barAlpha, 0.55)
    if bare then a = DB.locked and 0 or 0.35 end
    bar:SetBackdropColor(T.card[1], T.card[2], T.card[3], a)
    local ba = (DB.locked and 0.06 or 0.6) * (bare and (DB.locked and 0 or 1) or 1)
    bar:SetBackdropBorderColor(T.gold[1], T.gold[2], T.gold[3], ba)

    -- "next up" slots (hud only)
    for _, f in pairs(slots) do f:Hide() end
    if bare then
        for i, c in ipairs(columns) do
            if not c.noSlot then
                slots[i] = slots[i] or NewSlot()
                LayoutSlot(slots[i], c)
                c.slot = slots[i]
            else
                c.slot = nil
            end
        end
    end
    -- crosshair reticles at the arrival point of each track (hud only)
    bar.cross = bar.cross or {}
    for _, t in ipairs(bar.cross) do t:Hide() end
    if isStack and DB.crosshair then
        -- the inverted T: landing bar across the frame, stalk up to the row
        local cy = DB.slotIcon + SlotBottom() + 10
        local topY = DB.stackHeight - (ns.StackTopHeight and ns.StackTopHeight() or 80) - 2
        for n, seg in ipairs({ { 4, cy - 1, width - 8, 2 }, { StalkX() - 1, cy, 2, topY - cy } }) do
            local t = bar.cross[n]
            if not t then t = bar:CreateTexture(nil, "BACKGROUND", nil, -2); bar.cross[n] = t end
            Tex(t, T.gold, 0.6)
            t:ClearAllPoints()
            t:SetSize(seg[3], seg[4])
            t:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", seg[1], seg[2])
            t:Show()
        end
    elseif bare and DB.crosshair then
        local cy = DB.slotIcon + 12 + DB.fontSize + 6   -- same line the tracks land on
        local n = 0
        for _, c in ipairs(columns) do
            local len, gap, th = 22, 5, 1
            -- four arms + centre dot, so the icon can sit inside the gap
            for _, seg in ipairs({ { -len, 0, len - gap, th }, { gap, 0, len - gap, th }, { 0, gap, th, len - gap }, { 0, -len, th, len - gap } }) do
                n = n + 1
                local t = bar.cross[n]
                if not t then t = bar:CreateTexture(nil, "BACKGROUND", nil, -2); bar.cross[n] = t end
                Tex(t, T.gold, 0.6)
                t:ClearAllPoints()
                t:SetSize(seg[3], seg[4])
                t:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", c.slotX + seg[1], cy + seg[2])
                t:Show()
            end
            n = n + 1
            local d = bar.cross[n]
            if not d then d = bar:CreateTexture(nil, "BACKGROUND", nil, -2); bar.cross[n] = d end
            Tex(d, T.goldHi, 0.9); d:ClearAllPoints(); d:SetSize(3, 3); d:SetPoint("CENTER", bar, "BOTTOMLEFT", c.slotX, cy); d:Show()
        end
    end

    -- converging guide rails (hud only)
    bar.rails = bar.rails or {}
    for _, r in ipairs(bar.rails) do r:Hide() end
    if isHud and DB.rails then
        local baseY = DB.slotIcon + 12 + DB.fontSize + 6
        local topY = DB.hudHeight - 10
        local vx = DB.hudWidth * 0.5
        for i, c in ipairs(columns) do
            local r = bar.rails[i]
            if not r then
                r = bar:CreateTexture(nil, "BACKGROUND", nil, -3); bar.rails[i] = r
                Tex(r, T.gold, 0.12)
            end
            local dx, dy = vx - c.slotX, topY - baseY
            local len = math.sqrt(dx * dx + dy * dy)
            r:ClearAllPoints()
            r:SetSize(len, 1)
            r:SetPoint("CENTER", bar, "BOTTOMLEFT", (c.slotX + vx) * 0.5, (baseY + topY) * 0.5)
            r:SetRotation(math.atan2(dy, dx))
            r:Show()
        end
    end

    local base = DB.iconSize * DB.majorScale * 0.5 + 4
    if isHud then base = DB.slotIcon + 12 + DB.fontSize + 6 end
    if isStack then base = DB.slotIcon + SlotBottom() + 10 end   -- the next-cast slot and its queue sit under the T
    bar.linear = isStack and DB.stackLinear
    bar.nowLine:ClearAllPoints()
    bar.nowLine:SetPoint("BOTTOMLEFT",  bar, "BOTTOMLEFT",  4, base - 1)
    bar.nowLine:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -4, base - 1)
    bar.nowLine:SetHeight(2)
    if bare then bar.nowLine:Hide() else bar.nowLine:Show() end

    local travel
    if isStack then
        travel = DB.stackHeight - (ns.StackTopHeight and ns.StackTopHeight() or 80) - base - DB.rowIcon * 0.5 - 4
        if travel < 60 then travel = 60 end
    elseif isHud then
        travel = DB.hudHeight - base - 12
    else
        travel = DB.barHeight - base - (DB.showHeaders and HEADER_H or 0) - DB.iconSize * DB.majorScale * 0.5 - 4
    end
    bar.travel, bar.base = travel, base

    bar.immLine:ClearAllPoints()
    bar.immLine:SetPoint("BOTTOMLEFT",  bar, "BOTTOMLEFT",  4, base + YForRem(DB.imminent, travel))
    bar.immLine:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -4, base + YForRem(DB.imminent, travel))
    bar.immLine:SetHeight(1)
    if DB.imminent < DB.lookahead and not bare then bar.immLine:Show() else bar.immLine:Hide() end

    -- column headers + separators
    for _, fs in ipairs(headerStrings) do fs:Hide() end
    for _, t in ipairs(colLines) do t:Hide() end
    for i, c in ipairs(columns) do
        if bare then break end
        local fs = headerStrings[i]
        if not fs then
            fs = bar:CreateFontString(nil, "OVERLAY")
            headerStrings[i] = fs
        end
        ApplyFont(fs, DB.fontSize + 1)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", bar, "TOPLEFT", c.x + 2, -3)
        fs:SetWidth(c.w - 4)
        fs:SetJustifyH("LEFT")
        fs:SetText((c.name or ""):upper())
        Col(fs, T.muted)
        if DB.showHeaders then fs:Show() else fs:Hide() end
        if i > 1 then
            local line = colLines[i]
            if not line then
                line = bar:CreateTexture(nil, "BACKGROUND", nil, 1); colLines[i] = line
                Tex(line, T.border, 0.3)
            end
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", bar, "TOPLEFT", c.x, -(DB.showHeaders and HEADER_H or 2))
            line:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", c.x, 2)
            line:SetWidth(1)
            line:Show()
        end
    end

    -- time ticks up the right edge
    for _, t in ipairs(tickLines) do t:Hide() end
    for _, t in ipairs(tickStrings) do t:Hide() end
    if DB.showTicks and not bare then
        local ticks = { DB.imminent, 10, 15, 20, 30, 45, 60, 90, 120 }
        local n = 0
        for _, sec in ipairs(ticks) do
            if sec > 0 and sec < DB.lookahead then
                n = n + 1
                local line = tickLines[n]; local fs = tickStrings[n]
                if not line then
                    line = bar:CreateTexture(nil, "BACKGROUND", nil, 1); tickLines[n] = line
                    Tex(line, T.border, 0.25)
                    fs = bar:CreateFontString(nil, "OVERLAY"); tickStrings[n] = fs
                    Col(fs, T.muted)
                end
                ApplyFont(fs, DB.fontSize - 1)
                local y = base + YForRem(sec, travel)
                line:ClearAllPoints()
                line:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 4, y)
                line:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -4, y)
                line:SetHeight(1)
                line:Show()
                fs:ClearAllPoints()
                fs:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -5, y + 1)
                fs:SetText(sec .. "s")
                fs:Show()
            end
        end
    end

    if DB.locked then bar.title:Hide() else bar.title:Show() end
    bar:EnableMouse(not DB.locked)
    bar:SetMovable(not DB.locked)
    if DB.hidden then bar:Hide() else bar:Show() end
    if ns.SetUpdater then ns.SetUpdater() end
    if ns.ApplyMineLayout then ns.ApplyMineLayout() end
    if ns.ApplyGraphLayout then ns.ApplyGraphLayout() end
end

bar.nowLine = bar:CreateTexture(nil, "ARTWORK")
Tex(bar.nowLine, T.gold, 0.9)
bar.immLine = bar:CreateTexture(nil, "ARTWORK")
Tex(bar.immLine, T.gold, 0.25)

bar.title = bar:CreateFontString(nil, "OVERLAY"); ApplyFont(bar.title, 11); Col(bar.title, T.gold)
bar.title:SetPoint("BOTTOM", bar, "TOP", 0, 4)
bar.title:SetText("CD Timeline - drag, /tl lock")

bar:RegisterForDrag("LeftButton")
bar:SetScript("OnDragStart", function(self) if not DB.locked then self:StartMoving() end end)
bar:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    DB.point = ns.SavePoint(self) or DB.point
end)
bar:SetClampedToScreen(true)

------------------------------------------------------------------------
-- Icon pool
------------------------------------------------------------------------
local KIND_COLOR = {
    boss   = { 0.88, 0.34, 0.31 },
    tank   = { 0.88, 0.63, 0.24 },
    healer = { 0.39, 0.78, 0.42 },
    raid   = { 0.65, 0.52, 1.00 },
    util   = { 0.34, 0.66, 1.00 },
    pull   = { 0.43, 0.83, 0.76 },
    note   = { 0.85, 0.85, 0.85 },
}
local GOLD = { 1.0, 0.82, 0.1 }

local function StyleIconFonts(f)
    ApplyFont(f.l1, DB.fontSize)
    ApplyFont(f.l2, DB.fontSize - 1)
    ApplyFont(f.cd, DB.fontSize)
end

local function NewIcon()
    local f = CreateFrame("Frame", nil, bar)
    f:EnableMouse(false)

    f.ring = f:CreateTexture(nil, "BACKGROUND", nil, -1)   -- gold ring: second player of the same class
    f.ring:SetPoint("TOPLEFT", -3, 3)
    f.ring:SetPoint("BOTTOMRIGHT", 3, -3)
    f.ring:Hide()

    f.border = f:CreateTexture(nil, "BACKGROUND", nil, 0)  -- class colour, 1 px
    f.border:SetPoint("TOPLEFT", -1, 1)
    f.border:SetPoint("BOTTOMRIGHT", 1, -1)

    f.bg = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    f.bg:SetColorTexture(0, 0, 0, 1)
    f.bg:SetAllPoints()

    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints()
    f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- native cooldown widget: Blizzard draws the sweep and the number itself, so it
    -- keeps working on secret (in-combat) cooldown values
    f.cool = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cool:SetAllPoints()
    if f.cool.SetDrawEdge then f.cool:SetDrawEdge(false) end
    if f.cool.SetDrawBling then f.cool:SetDrawBling(false) end
    if f.cool.SetSwipeColor then f.cool:SetSwipeColor(0, 0, 0, 0.65) end
    f.cool:Hide()

    f.cd = f:CreateFontString(nil, "OVERLAY")               -- countdown on the icon
    f.cd:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 1, -1)
    f.cd:SetJustifyH("RIGHT")
    Col(f.cd, T.fg)

    f.l1 = f:CreateFontString(nil, "OVERLAY")               -- player (class colour) / mechanic
    f.l1:SetPoint("TOPLEFT", f, "TOPRIGHT", 5, 1)
    f.l1:SetJustifyH("LEFT")
    f.l1:SetWordWrap(false)

    f.l2 = f:CreateFontString(nil, "OVERLAY")               -- spell / note text
    f.l2:SetPoint("TOPLEFT", f.l1, "BOTTOMLEFT", 0, -1)
    f.l2:SetJustifyH("LEFT")
    f.l2:SetWordWrap(false)
    Col(f.l2, T.fg2)

    StyleIconFonts(f)
    return f
end

local function AcquireIcon(size, parent)
    local f = table.remove(iconPool) or NewIcon()
    f:SetParent(parent or bar)
    f:SetSize(size, size)
    f:SetScale(1)
    f:SetAlpha(1)
    StyleIconFonts(f)
    f.l1:Show(); f.l2:Show()
    Col(f.l2, T.fg2)
    if f.tex.SetDesaturated then f.tex:SetDesaturated(false) end
    f.border:ClearAllPoints(); f.border:SetPoint("TOPLEFT", -1, 1); f.border:SetPoint("BOTTOMRIGHT", 1, -1)
    if f.cool then f.cool:Hide() end
    f:Show()
    return f
end

local function ReleaseIcon(f)
    f:Hide()
    f:ClearAllPoints()
    f.entry = nil
    f.needTex = nil
    iconPool[#iconPool + 1] = f
end

local function ReleaseAll()
    for e, f in pairs(activeIcons) do ReleaseIcon(f) end
    wipe(activeIcons)
end

local function RestyleAllIcons()
    for _, f in pairs(activeIcons) do StyleIconFonts(f) end
    for _, f in ipairs(iconPool) do StyleIconFonts(f) end
end

------------------------------------------------------------------------
-- Per-frame update
------------------------------------------------------------------------
local playerName = nil

local function IsMine(e)
    if not playerName then playerName = (UnitName("player") or ""):lower() end
    return (e.tag or ""):lower() == playerName
end

local function PassesFilter(e)
    if e.pull or e.isBoss then return true end
    if DB.layout == "stack" and not DB.stackAll then return IsMine(e) end
    if not DB.onlyMine then return true end
    return IsMine(e)
end

local function StopEncounter(reason)
    if ns.HideLinks then ns.HideLinks() end
    if not state.active then return end
    state.active = false
    state.note = nil
    state.entries = nil
    state.awaitingPull = false
    wipe(state.live)
    state.liveBoss = false
    ReleaseAll()
    for _, f in pairs(slots) do f:Hide(); f.entry = nil end
    ApplyBarLayout()
    if reason then Print(reason) end
end

local function EntryColor(note, e)
    if e.pull then return KIND_COLOR.pull end
    if e.classRGB then return e.classRGB end
    local laneDef = note.lanes[e.laneIndex]
    if laneDef and laneDef.color then return laneDef.color end
    if e.isBoss then return KIND_COLOR.boss end
    if e.isNote then return KIND_COLOR.note end
    return KIND_COLOR[laneDef and laneDef.kind or "util"] or KIND_COLOR.util
end

------------------------------------------------------------------------
-- Links: the boss hit each cooldown row is for; expected raid damage
------------------------------------------------------------------------
local LK = {
    linkOf     = setmetatable({}, { __mode = "k" }),  -- cooldown row -> boss row
    assignedTo = setmetatable({}, { __mode = "k" }),  -- boss row -> { cooldown rows }
    short = { [31821] = "AM", [31884] = "Wings", [375576] = "Toll", [200652] = "Tyr", [633] = "LoH", [6940] = "Sac",
        [363534] = "Rewind", [370537] = "Stasis", [370564] = "Stasis", [370553] = "Tip", [363916] = "Scales", [22812] = "Bark", [102342] = "Ironbark", [374227] = "Zephyr", [357170] = "TD", [359816] = "Flight", [370960] = "Communion",
        [740] = "Tranq", [197721] = "Flourish", [391528] = "Convoke", [33891] = "Tree", [108280] = "HTT", [98008] = "SLT", [114052] = "Asc",
        [64843] = "Hymn", [265202] = "Salv", [200183] = "Apoth", [62618] = "Barrier", [47536] = "Rapture", [246287] = "Evang",
        [115310] = "Revival", [388615] = "Restoral", [322118] = "Yu'lon", [325197] = "Chi-Ji", [196718] = "Darkness", [97462] = "Rally", [51052] = "AMZ" },
    -- seconds each cooldown's effect lasts (the band over the damage curve); 0 = instant
    effect = { [31821] = 8, [31884] = 20, [375576] = 0, [200652] = 20, [363534] = 5, [370537] = 0, [374227] = 8, [357170] = 8,
        [359816] = 0, [370960] = 5, [740] = 6, [197721] = 0, [391528] = 4, [33891] = 30, [108280] = 10, [98008] = 6, [114052] = 15,
        [64843] = 5, [265202] = 0, [200183] = 20, [62618] = 10, [47536] = 8, [246287] = 0, [115310] = 0, [388615] = 0, [322118] = 25,
        [325197] = 25, [196718] = 8, [97462] = 10, [51052] = 6,
        [498] = 8, [642] = 8, [1022] = 10, [6940] = 12, [633] = 0, [363916] = 12, [374348] = 8, [22812] = 8, [102342] = 12 },
    -- seconds before the hit a cast snaps to in the planner (negative = after)
    lead = { [31821] = 1, [31884] = 1.5, [375576] = 1, [363534] = -1.5, [62618] = 1.5, [98008] = 1, [196718] = 1.5, [97462] = 1.5, [51052] = 1.5 },
}
ns.LK = LK

-- colour-blind-safe data colours (Okabe-Ito); colour is never the only cue: patterns and words carry the meaning too
-- what a cooldown adds, measured: top-8 Mythic Holy Paladin kills per boss (Warcraft Logs healing over time, Lorrgs casts), Oct 2026.
-- ref = their throughput outside cooldowns (k/s). boost = extra healing while up, as a share of that; burst = extra healing per cast,
-- in seconds of it. Aura Mastery reduces damage instead: 12% of raid damage taken (wiki value last confirmed for 10.2; unverified for 12.x).
LK.THRU = {
    ref = { [3470] = 386, [3445] = 384, [3497] = 401, [3379] = 357 }, refDefault = 390,
    [31884]  = { kind = "boost",  dur = 20, v = { [3470] = 0.10, [3445] = 0.13, [3497] = 0.37, [3379] = 0.25 }, def = 0.15, src = "healing while up, top-8 Mythic kills" },
    [375576] = { kind = "burst",  v = { [3470] = 0.88, [3445] = 0.93, [3497] = 1.59, [3379] = 1.23 }, def = 1.0, src = "extra healing per cast, top-8 Mythic kills" },
    [31821]  = { kind = "reduce", dur = 8, pct = 0.12, src = "12% less raid damage (wiki value from 10.2, unconfirmed for this patch)" },
}
LK.CDLEN = { [31821] = 180, [31884] = 120, [375576] = 30, [498] = 60, [642] = 300, [1022] = 300, [6940] = 120, [633] = 600,
    [363534] = 180, [370537] = 90, [370553] = 120, [374227] = 120, [357170] = 60, [359816] = 120, [363916] = 90, [374348] = 90, [740] = 180, [391528] = 60, [33891] = 120, [197721] = 90, [22812] = 60, [102342] = 90 }
LK.CLASS_SPELLS = {
    Paladin = { { "Healing cooldowns", { 31821, 31884, 375576 } }, { "Defensives", { 498, 642, 6940, 1022, 633 } } },
    Druid   = { { "Healing cooldowns", { 740, 391528, 33891, 197721 } }, { "Defensives", { 22812, 102342 } } },
    Evoker  = { { "Healing cooldowns", { 363534, 370537, 374227, 359816, 357170 } }, { "Defensives", { 363916, 374348 } } },
}
-- your throughput (k/s): /tl hps, else the top-8 reference for this boss
function LK.MyHps(note)
    if DB.myHps and DB.myHps > 0 then return DB.myHps, true end
    return (note and LK.THRU.ref[note.encounterID]) or LK.THRU.refDefault, false
end
-- estimated healing a cast adds, as { from, to, rate (k/s), kind = "heal" | "prevent" }
function LK.CdGain(note, e)
    local m = LK.THRU[e.spellID or 0]
    if not m or not e.time then return nil end
    local H = LK.MyHps(note)
    if m.kind == "boost" then
        local v = m.v[note.encounterID] or m.def
        return { from = e.time, to = e.time + m.dur, rate = v * H, kind = "heal", total = v * H * m.dur }
    elseif m.kind == "burst" then
        local v = m.v[note.encounterID] or m.def
        return { from = e.time, to = e.time + 3, rate = v * H / 3, kind = "heal", total = v * H }
    elseif m.kind == "reduce" then
        local tot = (LK.CurveSum(note, "dmg", e.time, m.dur) or 0) * m.pct
        return { from = e.time, to = e.time + m.dur, rate = tot / m.dur, kind = "prevent", total = tot }
    end
end
LK.CB = { orange = { 0.902, 0.624, 0.000 }, sky = { 0.337, 0.706, 0.914 }, green = { 0.000, 0.620, 0.451 },
    yellow = { 0.941, 0.894, 0.259 }, blue = { 0.000, 0.447, 0.698 }, vermillion = { 0.835, 0.369, 0.000 },
    purple = { 0.800, 0.475, 0.655 }, ink = { 0.040, 0.016, 0.094 } }
LK.MEDIA = "Interface\\AddOns\\CDTimeline\\Media\\"
-- tile a pattern (stripes / dots) over a texture's area, tinted
function LK.Pattern(t, kind, c, a)
    t:SetTexture(LK.MEDIA .. kind, "REPEAT", "REPEAT")
    t:SetHorizTile(true); t:SetVertTile(true)
    t:SetVertexColor(c[1], c[2], c[3], a or 1)
end
-- the game's fonts have no glyph for some characters (arrows, dashes) and draw a box: swap them for plain ones
function LK.Clean(s)
    if type(s) ~= "string" then return s end
    return (s:gsub("\226\134\146", ">"):gsub("\226\134\144", "<"):gsub("\226\128\148", "-"):gsub("\226\128\147", "-"))
end
function LK.CleanNote(note)
    if not note or note.cleaned then return note end
    for _, e in ipairs(note.entries or {}) do e.label = LK.Clean(e.label) end
    note.cleaned = true
    return note
end
function LK.CastLen(e) return tonumber((e.label or ""):match("%((%d+%.?%d*) s%)")) or 0 end
-- when a boss row's damage lands: plans built from logs carry the hit; older ones the cast start + "(N s)" in the label
function LK.HitTime(e)
    if e.live then return e.expires and (e.expires - state.startTime) or nil end
    return e.time and (e.time + LK.CastLen(e)) or nil
end
-- major cooldowns (healing ones, with a duration) running at time t - a big hit landing then is covered, linked or not
function LK.ActiveAt(entries, t, skip)
    local out = {}
    if not entries or not t then return out end
    for _, x in ipairs(entries) do
        if not x.isBoss and not x.pull and x.major and x ~= skip and x.time and x.time < math.huge then
            local fx = LK.effect[x.spellID or 0] or 0
            if fx > 0 and LK.THRU[x.spellID or 0] and t >= x.time - 1.5 and t <= x.time + fx then out[#out + 1] = x end
        end
    end
    return out
end
function LK.CurveAt(note, id, t)
    local c = note and note.curves and note.curves[id]
    if not c or not c.data[1] or not t then return nil end
    return c.data[math.floor(math.max(0, t) / c.step) + 1]
end
function LK.CurvePeak(note, id)
    local c = note and note.curves and note.curves[id]
    if not c then return nil end
    if not c.peak then local m = 0; for _, v in ipairs(c.data) do if v > m then m = v end end; c.peak = m end
    return c.peak
end
-- raid damage over [t, t+d] in thousands (d = 0: the per-second rate at t)
function LK.CurveSum(note, id, t, d)
    local c = note and note.curves and note.curves[id]
    if not c or not t then return nil end
    if d <= 0 then return LK.CurveAt(note, id, t) end
    local s = 0
    for x = t, t + d - 0.5 do s = s + (LK.CurveAt(note, id, x) or 0) end
    return s
end
-- a round number >= x (1, 1.5, 2, 2.5, 3, 4, 5, 7.5 × 10^n): the size of one grid block
function LK.Nice(x)
    if not x or x <= 0 then return 1 end
    local p = 10 ^ math.floor(math.log10(x))
    for _, m in ipairs({ 1, 1.5, 2, 2.5, 3, 4, 5, 7.5, 10 }) do if m * p >= x * 0.97 then return m * p end end   -- a peak a hair over a round number clips by one block rather than doubling the scale
    return 10 * p
end
function LK.FmtK(k)
    if not k then return "" end
    if k >= 1000 then return string.format("%.1fm", k / 1000) end
    return string.format("%dk", math.floor(k + 0.5))
end
function LK.DamageMul(note, e)
    if not DB.dmgScale or not e.isBoss then return 1 end
    local v, pk = LK.CurveAt(note, "dmg", LK.HitTime(e)), LK.CurvePeak(note, "dmg")
    if not v or not pk or pk <= 0 then return 1 end
    return 0.7 + 0.8 * (v / pk)
end
function LK.HitName(b)
    local n = LK.Clean(b and b.label or ""):gsub(" %- .*$", "")
    n = n:gsub("%s*%(.-%)%s*$", ""):gsub(" ~$", "")
    return n
end
-- tie every cooldown row to the boss hit it is for: an explicit anchor (spell ID + occurrence) when it
-- matches a plan row, else the big boss hit landing within ~6 s after the press
function LK.Link(entries)
    if not entries then return end
    local linkOf, assignedTo = LK.linkOf, LK.assignedTo
    local occ, byKey, hits = {}, {}, {}
    for _, e in ipairs(entries) do assignedTo[e] = nil; linkOf[e] = nil end
    for _, e in ipairs(entries) do
        if e.isBoss and e.time and e.time < math.huge then hits[#hits + 1] = e end
    end
    table.sort(hits, function(a, b) return a.time < b.time end)
    for _, e in ipairs(hits) do
        local k = e.spellID or e.label
        occ[k] = (occ[k] or 0) + 1; e.occ = occ[k]
        byKey[k] = byKey[k] or {}; byKey[k][occ[k]] = e
    end
    for _, e in ipairs(entries) do
        if not e.isBoss and not e.pull and not e.noLink and e.time and e.time < math.huge then
            local b
            if e.anchor ~= nil and byKey[e.anchor] then b = byKey[e.anchor][e.anchorN or 1] end
            -- the plan names its target ("Divine Toll -> Pop!"): the nearest hit of that name within 12 s wins
            if not b and e.label and not e.noLink then
                local want = LK.Clean(e.label):match(">%s*(.-)%s*$")
                if want then
                    want = want:gsub("%s*%(.-%)%s*$", ""):gsub("%s*#%d+.*$", ""):gsub("%s*%+.*$", ""):lower()
                    local bd
                    for _, h in ipairs(hits) do
                        local nm = LK.HitName(h):lower()
                        if #want >= 3 and (nm:find(want, 1, true) or want:find(nm, 1, true)) then
                            local d = math.abs(LK.HitTime(h) - e.time)
                            if d <= 12 and (not bd or d < bd) then b, bd = h, d end
                        end
                    end
                end
            end
            if not b then
                local best, bd
                local reach = math.max(6, math.min(10, (LK.effect[e.spellID or 0] or 0) / 2))
                for _, h in ipairs(hits) do
                    local d = LK.HitTime(h) - e.time
                    if d >= -1 and d <= reach and (h.major or d <= 3) then
                        local score = math.abs(d - 1) - (h.major and 8 or 0)   -- a big hit in reach beats a small one right next to the press
                        if not bd or score < bd then best, bd = h, score end
                    end
                end
                b = best
            end
            if b then
                linkOf[e] = b
                assignedTo[b] = assignedTo[b] or {}
                table.insert(assignedTo[b], e)
            end
        end
    end
end

local function SetupIcon(note, e, f, isMajor)
    local tex = e.pull and PULL_TEXTURE or e.texture or (e.spellID and SpellTexture(e.spellID))
    if not tex and e.isNote then tex = NOTE_TEXTURE end
    if not tex and e.spellID then f.needTex = e.spellID; tex = 134400 end
    f.tex:SetTexture(tex or 134400)

    local c = EntryColor(note, e)
    f.border:SetColorTexture(c[1], c[2], c[3], 1)
    if e.ring then f.ring:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1); f.ring:Show() else f.ring:Hide() end

    local l1, l2
    if e.pull then l1, l2 = "PULL", ""
    elseif e.isBoss then
        l1 = LK.HitName(e)
        local parts = {}
        local cover, seenC = {}, {}
        for _, x in ipairs(LK.assignedTo[e] or {}) do if not seenC[x] then seenC[x] = true; cover[#cover + 1] = x end end
        for _, x in ipairs(LK.ActiveAt(state.entries, LK.HitTime(e))) do if not seenC[x] then seenC[x] = true; cover[#cover + 1] = x end end
        for _, x in ipairs(cover) do
            local c = x.classRGB or GOLD
            local nm = LK.short[x.spellID or 0] or ((LK.Clean(x.label) or "?"):gsub("%s*>.*$", ""))
            parts[#parts + 1] = string.format("|cff%02x%02x%02x%s|r", math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255), nm)
        end
        local who = #parts > 0 and table.concat(parts, "+") or (e.major and "|cffd55e00no CD|r" or "")
        local dmg = ""
        if DB.dmgShow then
            local v = LK.CurveAt(note, "dmg", LK.HitTime(e))
            if v then dmg = "|cffe69f00" .. LK.FmtK(v) .. "|r" end
        end
        l2 = (dmg ~= "" and who ~= "") and (dmg .. "  " .. who) or (dmg .. who)
    else
        l1 = (DB.showNames and e.tag ~= "" and e.tag) or e.label or ""
        l2 = (DB.showNames and e.tag ~= "") and (e.label or "") or ""
    end
    f.l1:SetText(l1); f.l2:SetText(l2)
    if e.pull or e.isBoss then Col(f.l1, T.fg) else f.l1:SetTextColor(c[1], c[2], c[3]) end
    if isMajor then Col(f.l2, T.goldHi) else Col(f.l2, T.fg2) end
end

-- scratch
local visible = {}   -- { {e=, rem=}, ... }
local seen = {}
local nextFree = {}  -- per column: sub-column -> next free y

local function LayoutColumn(col, list, note)
    local size, gap = DB.iconSize, 4
    local labelW = DB.showNames and DB.labelWidth or 0
    local cellW = size + gap + labelW
    local maxSub = math.max(1, math.floor((col.w - 2) / cellW))
    local travel, base = bar.travel, bar.base
    wipe(nextFree)
    for _, v in ipairs(list) do
        local e, rem, f = v.e, v.rem, v.f
        local isMajor = e.major and not e.pull
        local mySize = (isMajor and size * DB.majorScale or size) * LK.DamageMul(note, e)
        local ideal = YForRem(math.max(rem, 0), travel)
        local half = mySize * 0.5
        -- nextFree[sub] = top edge of the last icon placed in that sub-column (+ gap)
        -- sticky: keep the sub-column we used last frame if it is free
        local sub
        if e.sub and (nextFree[e.sub] or -1e9) <= ideal - half then sub = e.sub end
        if not sub then
            for s = 0, maxSub - 1 do
                if (nextFree[s] or -1e9) <= ideal - half then sub = s break end
            end
        end
        local y
        if sub then
            y = ideal
        else
            -- every sub-column is occupied at this height: push up in the freest one
            sub = 0
            for s = 1, maxSub - 1 do if (nextFree[s] or -1e9) < (nextFree[sub] or -1e9) then sub = s end end
            y = (nextFree[sub] or 0) + half
        end
        e.sub = sub
        nextFree[sub] = y + half + gap

        if y + mySize * 0.5 > travel + mySize then
            f:Hide()  -- pushed above the visible window
        else
            f:Show()
            f:SetSize(mySize, mySize)
            f:ClearAllPoints()
            f:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", col.x + 3 + sub * cellW, base + y - mySize * 0.5)
            f.l1:ClearAllPoints(); f.l1:SetPoint("TOPLEFT", f, "TOPRIGHT", 5, 1); f.l1:SetJustifyH("LEFT"); f.l1:Show()
            f.l2:ClearAllPoints(); f.l2:SetPoint("TOPLEFT", f.l1, "BOTTOMLEFT", 0, -1); f.l2:SetJustifyH("LEFT"); f.l2:Show()
            f.l1:SetWidth(labelW - 4)
            f.l2:SetWidth(labelW - 4)
            if DB.showTime then
                f.cd:SetText(rem > 0 and (rem >= 10 and string.format("%d", rem) or string.format("%.1f", rem)) or "")
            else
                f.cd:SetText("")
            end
            if rem <= 0 then
                f:SetAlpha(math.max(0, 1 + rem / DB.hold))
                f:SetScale(1.1)
            else
                local near = 1 - math.min(rem, DB.lookahead) / DB.lookahead
                f:SetAlpha(isMajor and (0.8 + 0.2 * near) or (0.55 + 0.45 * near))
                f:SetScale(1)
            end
        end
    end
end

-- Perspective: d = rem/lookahead in [0,1]; s = 1/(1+K*d) is the apparent scale.
-- y is normalised so d=1 lands at the top of the travel; x converges on the vanishing point.
local function Perspective(rem)
    local K = DB.depth
    local d = math.max(0, math.min(1, rem / DB.lookahead))
    local sc = 1 / (1 + K * d)
    local sMin = 1 / (1 + K)
    local yFrac = (1 - sc) / (1 - sMin)
    return sc, yFrac
end

local placedRects, rectCount = {}, 0

local function LayoutHud(col, list, note)
    local base, travel = bar.base, bar.travel
    local size, gap = DB.iconSize, 3
    local vanishX = bar.vanishX or DB.hudWidth * 0.5
    local labelW = DB.labelWidth
    for r = #placedRects, 1, -1 do placedRects[r] = nil end
    rectCount = 0
    for _, v in ipairs(list) do
        local e, rem, f = v.e, v.rem, v.f
        local isMajor = e.major and not e.pull
        local sc, yFrac = Perspective(math.max(rem, 0))
        local sMin = 1 / (1 + DB.depth)
        local t = (sc - sMin) / (1 - sMin)          -- 0 far .. 1 at the slot
        local nearSize = DB.slotIcon * (isMajor and 1.15 or 1)
        local mySize = DB.farIcon + (nearSize - DB.farIcon) * t
        local x = vanishX + (col.slotX - vanishX) * sc
        if bar.linear then
            -- stack: constant speed straight down the lane, constant size
            yFrac = math.min(1, math.max(rem, 0) / DB.lookahead); t = 1; mySize = DB.rowIcon; x = col.slotX
        end
        mySize = mySize * LK.DamageMul(note, e)
        local half = mySize * 0.5
        local ideal = yFrac * travel
        -- push apart: try the track position, then one step outward; if both collide, move up and retry
        local y = ideal
        local placedN = #placedRects
        local sub, cx
        for _ = 1, 60 do
            local lowestTop
            for k = 0, 1 do
                local tx = x + (k == 1 and col.side * (mySize + gap) or 0)
                local hit
                for r = 1, placedN do
                    local q = placedRects[r]
                    if tx - half < q[3] and q[1] < tx + half and y - half < q[4] and q[2] < y + half then
                        hit = q; break
                    end
                end
                if not hit then sub, cx = k, tx break end
                if not lowestTop or hit[4] < lowestTop then lowestTop = hit[4] end
            end
            if sub then break end
            y = lowestTop + half + gap
        end
        if not sub then sub, cx = 0, x end
        x = cx
        placedN = placedN + 1
        local q = placedRects[placedN] or {}
        q[1], q[2], q[3], q[4] = x - half - gap * 0.5, y - half, x + half + gap * 0.5, y + half + gap
        placedRects[placedN] = q
        rectCount = placedN

        if y - half > travel then
            f:Hide()
        else
            f:Show()
            f:SetSize(mySize, mySize)
            f:ClearAllPoints()
            f:SetPoint("BOTTOM", bar, "BOTTOMLEFT", x, base + y - half)
            -- labels only once something is close enough to read
            local showLabel = t > 0.55 and DB.showNames
            f.l1:SetWidth(labelW); f.l2:SetWidth(labelW)
            if showLabel then f.l1:Show(); f.l2:Show() else f.l1:Hide(); f.l2:Hide() end
            f.l1:ClearAllPoints(); f.l2:ClearAllPoints()
            if col.side < 0 then
                f.l1:SetPoint("TOPRIGHT", f, "TOPLEFT", -4, 0); f.l1:SetJustifyH("RIGHT")
                f.l2:SetPoint("TOPRIGHT", f.l1, "BOTTOMRIGHT", 0, -1); f.l2:SetJustifyH("RIGHT")
            else
                f.l1:SetPoint("TOPLEFT", f, "TOPRIGHT", 4, 0); f.l1:SetJustifyH("LEFT")
                f.l2:SetPoint("TOPLEFT", f.l1, "BOTTOMLEFT", 0, -1); f.l2:SetJustifyH("LEFT")
            end
            f.cd:SetText("")
            if rem <= 0 then
                f:SetAlpha(math.max(0, 1 + rem / DB.hold))
            else
                f:SetAlpha(0.3 + 0.7 * t)
            end
            f:SetScale(1)
            -- border thickness scales too, so far icons don't become all border
            local b = 1
            f.border:ClearAllPoints(); f.border:SetPoint("TOPLEFT", -b, b); f.border:SetPoint("BOTTOMRIGHT", b, -b)
            f.ring:ClearAllPoints(); f.ring:SetPoint("TOPLEFT", -b - 2, b + 2); f.ring:SetPoint("BOTTOMRIGHT", b + 2, -b - 2)
        end
    end
end

-- the two "next up" slots: nearest boss ability / nearest cooldown, even beyond the lookahead
local queueScratch = {}
local function UpdateSlots(note, elapsed)
    local nextBoss, nextBossRem, nextCD, nextCDRem
    local entries = state.entries
    local hideStaticBoss = state.liveBoss and DB.bwLive
    local isStack = DB.layout == "stack"
    local want = isStack and 3 or 1
    local queue = queueScratch; wipe(queue)
    local i = state.nextIndex
    while entries[i] and (not nextBoss or #queue < want) do
        local e = entries[i]
        local rem = e.time - elapsed
        if rem > -0.4 and e.time < math.huge and PassesFilter(e) and (not isStack or e.isBoss or e.pull or IsMine(e)) then
            if e.isBoss or e.pull then
                if not nextBoss and not (hideStaticBoss and e.isBoss) then nextBoss, nextBossRem = e, rem end
            elseif #queue < want then
                queue[#queue + 1] = { e = e, rem = rem }
                if not nextCD then nextCD, nextCDRem = e, rem end
            end
        end
        i = i + 1
    end
    if isStack and ns.UpdateQueue then ns.UpdateQueue(queue[2], queue[3]) end
    local now = GetTime()
    for _, e in pairs(state.live) do
        local rem = e.expires - now
        if rem > -0.4 and (not nextBoss or rem < nextBossRem) then nextBoss, nextBossRem = e, rem end
    end
    for _, col in ipairs(columns) do
        local f = col.slot
        if f then
            local e, rem
            if col.kind == "boss" then e, rem = nextBoss, nextBossRem else e, rem = nextCD, nextCDRem end
            if not e then
                f:Hide()
            else
                if f.entry ~= e then
                    f.entry = e
                    local tex = e.pull and PULL_TEXTURE or e.texture or (e.spellID and SpellTexture(e.spellID)) or (e.isNote and NOTE_TEXTURE) or 134400
                    f.tex:SetTexture(tex)
                    local c = EntryColor(note, e)
                    f.border:SetColorTexture(c[1], c[2], c[3], 1)
                    if e.ring then f.ring:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1); f.ring:Show() else f.ring:Hide() end
                    if e.pull then f.l1:SetText("PULL"); f.l2:SetText("")
                    elseif e.isBoss then f.l1:SetText(e.label or ""); f.l2:SetText("")
                    else f.l1:SetText(e.tag ~= "" and e.tag or (e.label or "")); f.l2:SetText(e.tag ~= "" and (e.label or "") or "") end
                    if e.pull or e.isBoss then Col(f.l1, T.fg) else f.l1:SetTextColor(c[1], c[2], c[3]) end
                    Col(f.l2, T.muted)
                end
                if rem <= 0 then f.cd:SetText("NOW"); Col(f.cd, T.green)
                elseif rem < 10 then f.cd:SetText(string.format("%.1f", rem)); Col(f.cd, T.goldHi)
                else f.cd:SetText(string.format("%d", rem)); Col(f.cd, T.gold) end
                f:Show()
            end
        end
    end
end

------------------------------------------------------------------------
-- "mine": its own frame. One vertical track per tracked spell. On cooldown and
-- further out than the window: parked at the top with its countdown. Inside
-- the window: slides down and lands at the bottom as it comes off cooldown.
-- Ready: sits at the bottom until it is used again. Above each track, the
-- plan's next scheduled cast of that spell (fight time + "in N s"); inside
-- the window the scheduled cast also slides down the track as a ghost, so
-- the ramp can be read against the real cooldown. Attached (default) the
-- column sits to the right of the plan bar with the same landing line and the
-- same vertical scale, so a cooldown and a planned cast at the same distance
-- sit at the same height.
------------------------------------------------------------------------
local mineBar = CreateFrame("Frame", "CDTimelineMine", UIParent, "BackdropTemplate")
local mine = { list = {}, icons = {}, ghosts = {}, flow = {}, tops = {}, rowTops = {}, tracked = {}, queue = {}, specID = nil, model = {}, lastWidget = 0, base = 0, travel = 0, parkY = 0, matched = false, parent = nil }
mineBar:SetClampedToScreen(true)
mineBar:RegisterForDrag("LeftButton")
mineBar:SetScript("OnDragStart", function(self) if (not DB.locked) or DB.mineLocked == false then self:StartMoving() end end)
mineBar:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    DB.minePoint = ns.SavePoint(self) or DB.minePoint
    if ns.ApplyMineLayout then ns.ApplyMineLayout() end
end)
mineBar.title = mineBar:CreateFontString(nil, "OVERLAY"); ApplyFont(mineBar.title, 11); Col(mineBar.title, T.gold)
mineBar.title:SetPoint("BOTTOM", mineBar, "TOP", 0, 4)
mineBar.title:SetText("Mine - drag, /tl lock (/tl minepos reset re-attaches)")

-- a tracked spell was cast: start the model clock (used while real values are secret)
local function OnSpellCast(spellID)
    if not spellID then return end
    for _, e in ipairs(mine.list) do
        if e.spellID == spellID then
            mine.model[spellID] = { start = GetTime(), dur = ModelDuration(spellID) }
            e.readyAt = nil
            return
        end
    end
end

-- feed Blizzard's cooldown widget; duration objects first (they carry secrets), plain numbers as fallback
local function FeedWidget(f, id, st, d)
    local cool = f.cool
    if not cool then return end
    if C_Spell and C_Spell.GetSpellCooldownDuration and cool.SetCooldownFromDurationObject then
        local ok, obj = pcall(C_Spell.GetSpellCooldownDuration, id)
        if ok and obj then pcall(cool.SetCooldownFromDurationObject, cool, obj); return end
    end
    if st and d and not IsSecret(st) and not IsSecret(d) then pcall(cool.SetCooldown, cool, st, d)
    elseif cool.Clear then pcall(cool.Clear, cool) end
end

local function ReleaseMine()
    for id, f in pairs(mine.icons) do ReleaseIcon(f); mine.icons[id] = nil end
    for id, f in pairs(mine.ghosts) do ReleaseIcon(f); mine.ghosts[id] = nil end
    for id, f in pairs(mine.flow) do ReleaseIcon(f); mine.flow[id] = nil end
    for k, f in pairs(mine.queue) do ReleaseIcon(f); mine.queue[k] = nil end
    for _, t in ipairs(mine.tops) do t.fs1:Hide(); t.fs2:Hide() end
    for _, t in ipairs(mine.rowTops) do t.fs1:Hide(); t.fs2:Hide() end
end

local function PlayerClassRGB()
    local _, class = UnitClass and UnitClass("player")
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return { c.r, c.g, c.b } end
    return { 0.9, 0.9, 0.9 }
end

-- x of track i (centre) for a given icon size, with a wider gap between the Major and Other groups
-- each spell's column can be wider than its icon (/tl track width <spellID> <px>); 0 = just the icon
local function TrackW(k, size)
    local e = mine.list[k]
    local w = e and DB.colW and DB.colW[e.spellID]
    return math.max(size, w or 0)
end
local function TrackX(i, size, gap)
    local x = 4 + TrackW(1, size) * 0.5
    for k = 2, i do
        x = x + TrackW(k - 1, size) * 0.5 + gap + TrackW(k, size) * 0.5
        if mine.list[k].group ~= mine.list[k - 1].group then x = x + DB.groupGap end
    end
    return x
end

local function TracksWidth(size, gap)
    local n = #mine.list
    if n == 0 then return 0 end
    return TrackX(n, size, gap) + TrackW(n, size) * 0.5 - 4
end

local function MineWidth()
    return math.max(DB.mineIcon, TracksWidth(DB.mineIcon, DB.mineGap)) + 8
end

-- stack layout: the top row of parked icons (right-aligned) and its height
function ns.StackRowWidth() return TracksWidth(DB.rowIcon, DB.mineGap) end
function ns.StackTopHeight() return DB.rowIcon + (DB.fontSize + 2) + (DB.fontSize + 10) + 10 end

-- the parked row at the top: scheduled-cast text (two lines) above the parked icon and its countdown
local function ParkRowHeight()
    -- hit name on top, the icon, the big countdown under it
    return DB.mineIcon + DB.fontSize + 16 + (DB.mineSched and (#mine.list * (DB.fontSize + 3) + 6) or 0)
end

local function ApplyMineLayout()
    local size = DB.mineIcon
    local wantParent = (DB.layout == "stack") and bar or mineBar
    if mine.parent ~= wantParent then ReleaseMine(); mine.parent = wantParent end
    if DB.layout == "stack" then
        -- the column lives inside the stack frame: top row + the shared column
        mineBar:Hide(); mineBar:SetScript("OnUpdate", nil)
        if ns.ApplyCDM then ns.ApplyCDM() end
        return
    end
    if DB.minePoint and not ns.ValidPoint(DB.minePoint) then DB.minePoint = nil end
    mine.matched = (DB.minePoint == nil)
    local base, travel, height
    -- with the HUD the column is just its top row (icons, hit names, countdowns): the HUD's own icons do the falling
    mine.header = (DB.layout == "hud")
    if mine.header then
        base, travel = 0, 0
        height = ParkRowHeight() + 4
    elseif mine.matched then
        -- same landing line and the same vertical scale as the plan bar
        base, travel = bar.base or (size * 0.5 + 4), bar.travel or 200
        if base < size * 0.5 + 4 then base = size * 0.5 + 4 end
        height = base + travel + ParkRowHeight() + 6
    else
        base = size * 0.5 + 4
        height = DB.mineHeight
        travel = height - 6 - ParkRowHeight() - base
        if travel < 40 then travel = 40 end
    end
    mine.base, mine.travel = base, travel
    mine.parkY = base + travel + 4 + size * 0.5 + DB.fontSize + 12   -- centre of the top-row icon (the big countdown sits under it)
    mineBar:SetSize(MineWidth(), height)
    mineBar:ClearAllPoints()
    if mine.matched and mine.header then
        mineBar:SetPoint("BOTTOM", bar, "TOP", 0, DB.mineOffset)          -- anchored: centred on top of the HUD
    elseif mine.matched then
        mineBar:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT", DB.mineOffset, 0)
    else
        local p = DB.minePoint
        mineBar:SetPoint(p[1], UIParent, p[3], p[4], p[5])
    end
    mineBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    local movable = (not DB.locked) or (DB.mineLocked == false)
    mineBar:SetBackdropColor(T.card[1], T.card[2], T.card[3], movable and 0.35 or 0)
    mineBar:SetBackdropBorderColor(T.gold[1], T.gold[2], T.gold[3], movable and 0.6 or 0)
    if movable then mineBar.title:Show() else mineBar.title:Hide() end
    mineBar:EnableMouse(movable)
    mineBar:SetMovable(movable)
    -- scheduled-cast text per track
    for i = 1, #mine.list do
        local t = mine.tops[i]
        if not t then
            t = { fs1 = mineBar:CreateFontString(nil, "OVERLAY"), fs2 = mineBar:CreateFontString(nil, "OVERLAY") }
            t.fs1:SetJustifyH("CENTER"); t.fs2:SetJustifyH("CENTER")
            mine.tops[i] = t
        end
        ApplyFont(t.fs1, DB.fontSize); ApplyFont(t.fs2, DB.fontSize)
        local x = TrackX(i, size, DB.mineGap)
        t.fs1:ClearAllPoints(); t.fs1:SetPoint("TOP", mineBar, "TOPLEFT", x, -4); t.fs1:SetWidth(size + DB.mineGap + 10)
        t.fs2:ClearAllPoints(); t.fs2:SetPoint("TOP", t.fs1, "BOTTOM", 0, -1); t.fs2:SetWidth(size + DB.mineGap + 10)
        Col(t.fs1, T.muted); Col(t.fs2, T.muted)
        t.fs1:Hide(); t.fs2:Hide()
    end
    for i = #mine.list + 1, #mine.tops do mine.tops[i].fs1:Hide(); mine.tops[i].fs2:Hide() end
    local show = DB.mineOn and not DB.hidden and #mine.list > 0 and not DB.mineCDM
    if show and DB.mineCombat and DB.locked then
        local inCombat = (UnitAffectingCombat and UnitAffectingCombat("player")) or (InCombatLockdown and InCombatLockdown())
        if not inCombat then show = false end
    end
    if show then mineBar:Show() else mineBar:Hide(); ReleaseMine() end
    mineBar:SetScript("OnUpdate", show and ns.MineUpdate or nil)
    if ns.ApplyCDM then ns.ApplyCDM() end
end
ns.ApplyMineLayout = ApplyMineLayout

local function RebuildTracked()
    ReleaseMine()
    wipe(mine.list)
    local spec = CurrentSpecID()
    mine.specID = spec
    local rgb = PlayerClassRGB()
    local function addGroup(src, group)
        for _, id in ipairs(src) do
            if SpellKnown(id) then
                local name = SpellName(id) or ("#" .. id)
                mine.list[#mine.list + 1] = { spellID = id, label = name, lname = name:lower(), mine = true, major = true, group = group, classRGB = rgb }
                if C_Spell and C_Spell.RequestLoadSpellData then pcall(C_Spell.RequestLoadSpellData, id) end
            end
        end
    end
    addGroup((spec and DB.track[spec]) or (spec and TRACK_DEFAULTS[spec]) or {}, "major")
    addGroup((spec and DB.trackOther[spec]) or (spec and OTHER_DEFAULTS[spec]) or {}, "other")
    wipe(mine.tracked)
    for _, e in ipairs(mine.list) do mine.tracked[e.spellID] = e end
    ns.mineCount = #mine.list
    ApplyMineLayout()
    if DB.layout == "stack" then ApplyBarLayout() end
end

-- vertical position for "rem" seconds away: the plan bar's own mapping when attached to a HUD, else the column mapping
local function MineY(rem)
    if mine.matched and DB.layout == "hud" then
        local _, yFrac = Perspective(rem)
        return mine.base + yFrac * mine.travel
    end
    return mine.base + YForRem(rem, mine.travel)
end

-- the plan's next cast of this spell by me: seconds until it (may be negative within the hold), and the entry
local myName
local function NextScheduled(e, elapsed)
    if not DB.mineSched or not state.active or not state.entries then return end
    if not myName then myName = (UnitName("player") or ""):lower() end
    local best, bestRem
    for _, x in ipairs(state.entries) do
        if not x.isBoss and not x.pull and (x.tag or ""):lower() == myName then
            local rem = x.time - elapsed
            if rem > -DB.hold and x.time < math.huge and (x.spellID == e.spellID or (x.spellID == nil and x.label and x.label:lower():find(e.lname, 1, true))) then
                if not best or rem < bestRem then best, bestRem = x, rem end
            end
        end
    end
    return bestRem, best
end

-- make sure the parked icon for a tracked spell exists on the right parent
local function MineIcon(e, size)
    local f = mine.icons[e.spellID]
    if f then
        if f.needTex then local t = SpellTexture(f.needTex); if t then f.tex:SetTexture(t); f.needTex = nil end end
        return f
    end
    f = AcquireIcon(size, mine.parent or mineBar)
    f.entry = e
    local tex = SpellTexture(e.spellID)
    if not tex then f.needTex = e.spellID; tex = 134400 end
    f.tex:SetTexture(tex)
    local c = e.classRGB
    f.border:SetColorTexture(c[1], c[2], c[3], DB.mineBorder and 1 or 0)
    f.border:ClearAllPoints(); f.border:SetPoint("TOPLEFT", -1, 1); f.border:SetPoint("BOTTOMRIGHT", 1, -1)
    f.ring:Hide()
    f.l1:SetText(""); f.l1:Hide()
    f.cd:SetText("")
    ApplyFont(f.l2, DB.fontSize + 2)
    Col(f.l2, T.gold)
    f.l2:ClearAllPoints()
    f.l2:SetPoint("TOP", f, "BOTTOM", 0, -2)
    f.l2:SetWidth(size + DB.mineGap + 12)
    f.l2:SetJustifyH("CENTER")
    f.l2:Show()
    f.coolFresh = true
    mine.icons[e.spellID] = f
    return f
end

-- per-frame state for every tracked spell: e.rem (seconds until usable), e.schedRem / e.sched (the plan),
-- the in-combat model, and Blizzard's cooldown widget on the parked icon
local function MineTick(now, elapsed, size)
    for i, e in ipairs(mine.list) do
        local f = MineIcon(e, size)
        local rem, dur, active, rawStart, rawDur = ReadCooldown(e.spellID)
        if rem ~= nil then
            if dur and dur > 1.6 then DB.cdDur[e.spellID] = dur end
            mine.model[e.spellID] = nil
            e.modelled = false
            if rem > 0 and rawStart and rawDur then e.lastStart, e.lastDur = rawStart, rawDur else e.lastStart, e.lastDur = nil, nil end
        else
            local m = mine.model[e.spellID]
            if active == false then
                rem = 0; mine.model[e.spellID] = nil
            else
                if not m then
                    if e.lastStart and e.lastDur then m = { start = e.lastStart, dur = e.lastDur } else m = { start = now, dur = ModelDuration(e.spellID) } end
                    e.lastStart, e.lastDur = nil, nil
                    mine.model[e.spellID] = m
                end
                rem = m.start + m.dur - now
                if rem < 0 then rem = 0 end
                if active == true and rem <= 0 then rem = 0.1 end
            end
            e.modelled = true
        end
        if DB.mineSwipe or DB.mineNumbers then
            if now - mine.lastWidget > 0.25 or f.coolFresh then FeedWidget(f, e.spellID, rawStart, rawDur); f.coolFresh = nil end
            if f.cool.SetDrawSwipe then f.cool:SetDrawSwipe(DB.mineSwipe and true or false) end
            if f.cool.SetHideCountdownNumbers then f.cool:SetHideCountdownNumbers(not DB.mineNumbers) end
            f.cool:Show()
        else
            f.cool:Hide()
        end
        e.rem = rem
        if rem <= 0 then if not e.readyAt then e.readyAt = now end else e.readyAt = nil end
        e.schedRem, e.sched = nil, nil
        if elapsed then e.schedRem, e.sched = NextScheduled(e, elapsed) end
        e.late = e.sched ~= nil and rem > 0 and e.schedRem < rem
    end
    if now - mine.lastWidget > 0.25 then mine.lastWidget = now end
end

-- the schedule text pair above / below a parked icon
local function SchedText(t, e, look)
    if not e.sched then t.fs1:Hide(); t.fs2:Hide(); return end
    t.fs1:SetText(FmtClock(e.sched.time))
    t.fs2:SetText(e.schedRem <= 0 and "NOW" or ("in " .. FmtRem(e.schedRem)))
    if e.late then Col(t.fs2, T.red) elseif e.schedRem <= look then Col(t.fs2, T.goldHi) else Col(t.fs2, T.muted) end
    t.fs1:Show(); t.fs2:Show()
end

-- the free-standing / attached column (hud, single, lanes layouts)
local function MineUpdate()
    local size, gap, look = DB.mineIcon, DB.mineGap, DB.lookahead
    local base, parkY = mine.base, mine.parkY
    local now = GetTime()
    local elapsed = state.active and (now - state.startTime) or nil
    MineTick(now, elapsed, size)
    for i, e in ipairs(mine.list) do
        local f = mine.icons[e.spellID]
        local rem = e.rem
        local x = TrackX(i, size, gap)
        -- every icon stays in the top row, with what you need to read right on it and under it:
        -- the cooldown left ON the icon, when to press it next UNDER it, the hit it's for above
        local scale = 1
        if rem <= 0 then
            local age = now - e.readyAt
            scale = age < 0.5 and (1 + 0.18 * (1 - age / 0.5)) or 1
        end
        f:Show()
        f:SetSize(size, size)
        f:SetScale(scale)
        f:ClearAllPoints()
        f:SetPoint("CENTER", mineBar, "BOTTOMLEFT", x / scale, parkY / scale)
        f:SetAlpha(rem <= 0 and 1 or 0.9)
        if f.tex.SetDesaturated then f.tex:SetDesaturated(rem > 0 and DB.mineDesat and true or false) end
        if f.cool and f.cool.SetHideCountdownNumbers then f.cool:SetHideCountdownNumbers(true) end
        f.l2:SetText("")
        f.cd:ClearAllPoints(); f.cd:SetPoint("CENTER", f, "CENTER", 0, 0); f.cd:SetWidth(size + 8); f.cd:SetJustifyH("CENTER")
        ApplyFont(f.cd, math.max(DB.fontSize + 2, math.floor(size * 0.45)), "OUTLINE")
        if rem > 0 then f.cd:SetText(rem >= 60 and string.format("%d:%02d", math.floor(rem / 60), math.floor(rem % 60)) or string.format("%d", math.ceil(rem))); Col(f.cd, T.fg); f.cd:Show()
        else f.cd:SetText("") end

        local top = mine.tops[i]
        if top then
            top.fs1:SetWordWrap(false); top.fs2:SetWordWrap(false)
            top.fs2:ClearAllPoints(); top.fs2:SetPoint("TOP", f, "BOTTOM", 0, -2); top.fs2:SetWidth(TrackW(i, size) + gap + 14)
            ApplyFont(top.fs2, DB.fontSize + 5, "OUTLINE")
            if not e.sched then top.fs1:Hide(); top.fs2:Hide(); if top.lead then top.lead:Hide() end
            else
                local hb = LK.linkOf[e.sched]
                top.fs1:SetText(hb and LK.HitName(hb) or FmtClock(e.sched.time)); Col(top.fs1, T.muted)
                -- one row per label, soonest just above the icons, the next one a row higher; each starts at its own icon
                local rank = 0
                for _, o in ipairs(mine.list) do
                    if o ~= e and o.sched and o.schedRem and (o.schedRem < e.schedRem or (o.schedRem == e.schedRem and o.spellID < e.spellID)) then rank = rank + 1 end
                end
                local rowH = DB.fontSize + 3
                local ly = parkY + size * 0.5 + 4 + rank * rowH
                local lx = x - size * 0.5
                top.fs1:ClearAllPoints(); top.fs1:SetPoint("BOTTOMLEFT", mineBar, "BOTTOMLEFT", lx, ly)
                top.fs1:SetWidth(0); top.fs1:SetJustifyH("LEFT"); ApplyFont(top.fs1, DB.fontSize - 1)
                if rank == 0 then Col(top.fs1, T.fg2) end
                if not top.lead then top.lead = mineBar:CreateTexture(nil, "ARTWORK") end
                Tex(top.lead, T.muted, 0.55); top.lead:ClearAllPoints()
                top.lead:SetSize(1, math.max(1, ly - (parkY + size * 0.5)))
                top.lead:SetPoint("BOTTOMLEFT", mineBar, "BOTTOMLEFT", lx + 1, parkY + size * 0.5); top.lead:Show()
                local sr = e.schedRem
                -- ready, but the plan needs it again sooner than its cooldown (talents included): pressing it now loses that use
                local hold = rem <= 0 and sr > 0 and sr < ModelDuration(e.spellID) - 0.5
                local num = sr < 60 and tostring(math.ceil(sr)) or string.format("%d:%02d", math.floor(sr / 60), math.floor(sr % 60))
                if rem > 0 and rem > sr + 0.5 then top.fs2:SetText(sr <= 0 and ("late " .. math.ceil(rem)) or ("late +" .. math.ceil(rem - sr))); Col(top.fs2, LK.CB.vermillion)
                elseif sr <= 0 then top.fs2:SetText("GO"); Col(top.fs2, T.fg)
                elseif hold then top.fs2:SetText("hold " .. num); Col(top.fs2, LK.CB.vermillion)
                elseif sr < 60 then top.fs2:SetText(num); if sr <= 5 then Col(top.fs2, T.fg) elseif sr <= look then Col(top.fs2, T.fg2) else Col(top.fs2, T.muted) end
                else top.fs2:SetText(num); Col(top.fs2, rem <= 0 and T.fg or T.muted) end
                if sr <= 5 and sr > 0 then ApplyFont(top.fs2, DB.fontSize + 8, "OUTLINE") end
                top.fs1:Show(); top.fs2:Show()
            end
        end
        local g = mine.ghosts[e.spellID]
        if e.sched and e.schedRem <= look and not mine.header then
            if not g then
                g = AcquireIcon(size, mineBar)
                g.tex:SetTexture(f.tex:GetTexture() or 134400)
                Tex(g.border, T.goldHi, 0.5)
                g.border:ClearAllPoints(); g.border:SetPoint("TOPLEFT", -1, 1); g.border:SetPoint("BOTTOMRIGHT", 1, -1)
                g.ring:Hide(); g.l1:Hide(); g.cd:SetText("")
                if g.cool then g.cool:Hide() end
                ApplyFont(g.l2, DB.fontSize); g.l2:ClearAllPoints(); g.l2:SetPoint("TOP", g, "BOTTOM", 0, -1); g.l2:SetWidth(size + gap + 10); g.l2:SetJustifyH("CENTER"); Col(g.l2, T.goldHi); g.l2:Show()
                if g.tex.SetDesaturated then g.tex:SetDesaturated(true) end
                mine.ghosts[e.spellID] = g
            end
            local gy = MineY(math.max(e.schedRem, 0))
            local gs = size * 0.8
            g:SetSize(gs, gs); g:SetScale(1); g:ClearAllPoints()
            g:SetPoint("CENTER", mineBar, "BOTTOMLEFT", x + 5, gy)
            g:SetAlpha(e.schedRem <= 0 and math.max(0, 0.75 + e.schedRem / DB.hold) or 0.55)
            g.l2:SetText("")   -- the number to read is under the top-row icon, not on something moving
            g:Show()
        elseif g then
            ReleaseIcon(g); mine.ghosts[e.spellID] = nil
        end
    end
end

-- Cooldown Manager mode (/tl cdm): the plan's countdown sits just above the spell's icon on Blizzard's
-- Essential / Utility cooldown viewers - red while you should hold it (plus a red cross on the icon), "GO" at 0.
local cdm = { frame = CreateFrame("Frame", "CDTimelineCDM", UIParent), map = {}, over = {}, lastScan = 0, warned = false }
cdm.frame:Hide()

local function CDMViewers()
    local v = {}
    for _, name in ipairs({ "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer" }) do
        local f = _G[name]
        if f then v[#v + 1] = f end
    end
    return v
end

-- spellID of a viewer item frame (Blizzard caches cooldownInfo on the item; fall back to the C_CooldownViewer lookup)
local function CDMItemSpell(item)
    local info = item.cooldownInfo
    if not info and item.GetCooldownID and C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo then
        local ok, id = pcall(item.GetCooldownID, item)
        if ok and id and not IsSecret(id) then
            local ok2, i2 = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, id)
            if ok2 then info = i2 end
        end
    end
    if type(info) ~= "table" then return end
    local ids = {}
    for _, k in ipairs({ "overrideSpellID", "spellID" }) do
        local id = info[k]
        if id and not IsSecret(id) and id ~= 0 then ids[#ids + 1] = id end
    end
    if type(info.linkedSpellIDs) == "table" then
        for _, id in ipairs(info.linkedSpellIDs) do if id and not IsSecret(id) then ids[#ids + 1] = id end end
    end
    return ids
end

-- spellID -> the viewer item frame showing it; rescanned every second (the viewers re-lay out on spec / talent changes)
local function CDMScan(now)
    if now - cdm.lastScan < 1 then return end
    cdm.lastScan = now
    wipe(cdm.map)
    local any = false
    for _, viewer in ipairs(CDMViewers()) do
        any = true
        local items
        if viewer.itemFramePool and viewer.itemFramePool.EnumerateActive then
            items = {}
            for item in viewer.itemFramePool:EnumerateActive() do items[#items + 1] = item end
        elseif viewer.GetItemFrames then
            local ok, r = pcall(viewer.GetItemFrames, viewer); items = ok and r or nil
        end
        if not items then items = { viewer:GetChildren() } end
        for _, item in ipairs(items) do
            if type(item) == "table" and item.IsShown then
                local ids = CDMItemSpell(item)
                if ids then for _, id in ipairs(ids) do if not cdm.map[id] then cdm.map[id] = item end end end
            end
        end
    end
    if not any and not cdm.warned then
        cdm.warned = true
        Print("Cooldown Manager frames not found - turn it on in Options > Gameplay > Cooldown Manager (or /tl cdm to go back to the column).")
    end
end

local function CDMOverlay(item)
    local o = cdm.over[item]
    if o then return o end
    o = CreateFrame("Frame", nil, item)
    o:SetAllPoints(item)
    o:SetFrameLevel(item:GetFrameLevel() + 10)
    o.num = o:CreateFontString(nil, "OVERLAY")
    o.num:SetPoint("BOTTOM", item, "TOP", 0, 1)
    o.num:SetJustifyH("CENTER"); o.num:SetWordWrap(false)
    o.cross = o:CreateTexture(nil, "OVERLAY", nil, 7)
    o.cross:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
    o.cross:SetPoint("CENTER", item, "CENTER", 0, 0)
    o.cross:SetAlpha(0.9)
    o.cross:Hide()
    cdm.over[item] = o
    return o
end

local function CDMUpdate()
    local now = GetTime()
    local elapsed = state.active and (now - state.startTime) or nil
    MineTick(now, elapsed, DB.mineIcon)
    CDMScan(now)
    local used = {}
    local look = DB.lookahead
    for _, e in ipairs(mine.list) do
        local item = cdm.map[e.spellID]
        if item then
            local o = CDMOverlay(item)
            used[item] = true
            local rem, sr = e.rem, e.schedRem
            if not e.sched then
                o.num:Hide(); o.cross:Hide()
            else
                local w = item:GetWidth() or 36
                ApplyFont(o.num, math.max(8, DB.fontSize + 1), "OUTLINE")
                o.num:SetWidth(w + 30)
                local hold = rem <= 0 and sr > 0 and sr < ModelDuration(e.spellID) - 0.5
                local num = sr < 60 and tostring(math.ceil(sr)) or string.format("%d:%02d", math.floor(sr / 60), math.floor(sr % 60))
                local red = false
                if rem > 0 and rem > sr + 0.5 then o.num:SetText(sr <= 0 and ("late " .. math.ceil(rem)) or ("+" .. math.ceil(rem - sr))); red = true
                elseif sr <= 0 then o.num:SetText("GO"); Col(o.num, T.fg)
                elseif hold then o.num:SetText(num); red = true
                else o.num:SetText(num); if sr <= 5 then Col(o.num, T.fg) elseif sr <= look then Col(o.num, T.fg2) else Col(o.num, T.muted) end end
                if red then Col(o.num, LK.CB.vermillion) end
                if sr <= 5 and sr > 0 and not hold then ApplyFont(o.num, DB.fontSize + 4, "OUTLINE") end
                o.num:Show()
                if hold then
                    local cs = math.floor(w * 0.5)
                    o.cross:SetSize(cs, cs); o.cross:Show()
                else
                    o.cross:Hide()
                end
            end
            o:Show()
        end
    end
    for item, o in pairs(cdm.over) do if not used[item] then o.num:Hide(); o.cross:Hide(); o:Hide() end end
end

local function ApplyCDM()
    local on = DB.mineCDM and not DB.hidden and #mine.list > 0
    cdm.frame:SetScript("OnUpdate", on and CDMUpdate or nil)
    if on then cdm.frame:Show(); cdm.lastScan = 0 else
        cdm.frame:Hide()
        for _, o in pairs(cdm.over) do o.num:Hide(); o.cross:Hide(); o:Hide() end
    end
end
ns.ApplyCDM = ApplyCDM

-- is this plan entry one of my tracked spells? (then it is drawn in that spell's column, not the crosshair lane)
local function TrackedEntry(e)
    if e.isBoss or e.pull or not IsMine(e) then return nil end
    if e.spellID and mine.tracked[e.spellID] then return mine.tracked[e.spellID] end
    if e.spellID == nil and e.label then
        local l = e.label:lower()
        for _, t in ipairs(mine.list) do if l:find(t.lname, 1, true) then return t end end
    end
end
ns.TrackedEntry = TrackedEntry

-- stack layout: parked icons in a right-aligned row at the top (Major group, gap, Other group) with the
-- plan's next cast above/below each. Below every row icon is that spell's own column: the cooldown
-- coming back slides down it over the last 30 s, and the plan's next cast of it slides down as a ghost.
-- Everything else (boss timers, untracked casts) uses the crosshair lane on the left.
local function StackTick(now, elapsed)
    local rs, gap, look = DB.rowIcon, DB.mineGap, DB.lookahead
    MineTick(now, elapsed, rs)
    local W = bar.width or DB.stackWidth
    local H = DB.stackHeight
    local base, travel = bar.base, bar.travel
    local x0 = StalkX() + 6
    local rowY = H - 4 - (DB.fontSize + 2) - rs * 0.5
    local sMin = 1 / (1 + DB.depth)
    local function colY(rem)
        if DB.stackLinear then return base + math.min(1, math.max(rem, 0) / look) * travel end
        local _, yFrac = Perspective(math.max(rem, 0)); return base + yFrac * travel
    end
    local function colSize(rem)
        if DB.stackLinear then return rs end
        local sc = Perspective(math.max(rem, 0)); local t = (sc - sMin) / (1 - sMin); return rs + (DB.slotIcon - rs) * t
    end
    for i, e in ipairs(mine.list) do
        local f = mine.icons[e.spellID]
        local rem = e.rem
        local x = x0 + TrackX(i, rs, gap) - 4
        local flowing = rem > 0 and rem <= look
        local alpha, desat, scale = 1, false, 1
        if rem <= 0 then
            local age = now - e.readyAt
            scale = age < 0.5 and (1 + 0.18 * (1 - age / 0.5)) or 1
        elseif flowing then
            alpha, desat = 0.45, false
        else
            alpha, desat = 0.7, DB.mineDesat
        end
        -- the top row is where you read everything: the icon always shows, its cooldown is ON it, the plan right under it
        if f:GetParent() ~= bar then f:SetParent(bar) end
        f:SetFrameLevel(bar:GetFrameLevel() + 6)
        f:Show()
        f:SetSize(rs, rs); f:SetScale(scale); f:ClearAllPoints()
        f:SetPoint("CENTER", bar, "BOTTOMLEFT", x / scale, rowY / scale)
        f:SetAlpha(rem <= 0 and 1 or 0.9)
        if f.tex.SetDesaturated then f.tex:SetDesaturated(rem > 0 and DB.mineDesat and true or false) end
        if f.cool and f.cool.SetHideCountdownNumbers then f.cool:SetHideCountdownNumbers(true) end
        f.l2:SetText("")
        f.cd:ClearAllPoints(); f.cd:SetPoint("CENTER", f, "CENTER", 0, 0); f.cd:SetWidth(rs + 8); f.cd:SetJustifyH("CENTER")
        ApplyFont(f.cd, math.max(DB.fontSize + 2, math.floor(rs * 0.45)), "OUTLINE")
        if rem > 0 then f.cd:SetText(rem >= 60 and string.format("%d:%02d", math.floor(rem / 60), math.floor(rem % 60)) or string.format("%d", math.ceil(rem))); Col(f.cd, T.fg); f.cd:Show()
        else f.cd:SetText(""); end
        -- schedule text above and below the row icon
        local t = mine.rowTops[i]
        if not t then
            t = { fs1 = bar:CreateFontString(nil, "OVERLAY"), fs2 = bar:CreateFontString(nil, "OVERLAY") }
            t.fs1:SetJustifyH("CENTER"); t.fs2:SetJustifyH("CENTER")
            t.fs1:SetWordWrap(false); t.fs2:SetWordWrap(false)
            mine.rowTops[i] = t
        end
        ApplyFont(t.fs1, DB.fontSize); ApplyFont(t.fs2, DB.fontSize)
        t.fs1:ClearAllPoints(); t.fs1:SetPoint("BOTTOM", f, "TOP", 0, 1); t.fs1:SetWidth(rs + gap + 12)
        t.fs2:ClearAllPoints(); t.fs2:SetPoint("TOP", f, "BOTTOM", 0, -1); t.fs2:SetWidth(rs + gap + 12)
        Col(t.fs1, T.muted)
        ApplyFont(t.fs2, DB.fontSize + 5, "OUTLINE")
        ApplyFont(t.fs1, DB.fontSize - 1)
        if not e.sched or DB.mineCDM then t.fs1:Hide(); t.fs2:Hide()   -- (CDM mode: the countdown lives on the Cooldown Manager icon)
        else
            -- above: the hit it's for; below, big: how long until you press it
            local hb = LK.linkOf[e.sched]
            t.fs1:SetText(hb and LK.HitName(hb) or FmtClock(e.sched.time))
            local sr = e.schedRem
            local late = sr <= 0 and rem > 0
            local hold = rem <= 0 and sr > 0 and sr < ModelDuration(e.spellID) - 0.5
            local num = sr < 60 and tostring(math.ceil(sr)) or string.format("%d:%02d", math.floor(sr / 60), math.floor(sr % 60))
            if rem > 0 and rem > sr + 0.5 then t.fs2:SetText(sr <= 0 and ("late " .. math.ceil(rem)) or ("late +" .. math.ceil(rem - sr))); Col(t.fs2, LK.CB.vermillion)
            elseif sr <= 0 then t.fs2:SetText("GO"); Col(t.fs2, T.fg)
            elseif hold then t.fs2:SetText("hold " .. num); Col(t.fs2, LK.CB.vermillion)
            elseif sr < 60 then t.fs2:SetText(num); if sr <= 5 then Col(t.fs2, T.fg) elseif sr <= look then Col(t.fs2, T.fg2) else Col(t.fs2, T.muted) end
            else t.fs2:SetText(num); Col(t.fs2, rem <= 0 and T.fg or T.muted) end
            if sr <= 5 and sr > 0 then ApplyFont(t.fs2, DB.fontSize + 8, "OUTLINE") end
            t.fs1:Show(); t.fs2:Show()
        end
        -- the cooldown coming back: slides down this spell's column
        local g = mine.flow[e.spellID]
        if flowing then
            if not g then
                g = AcquireIcon(rs, bar)
                g.entry = e
                g.tex:SetTexture(f.tex:GetTexture() or 134400)
                local c = e.classRGB
                g.border:SetColorTexture(c[1], c[2], c[3], 1)
                g.border:ClearAllPoints(); g.border:SetPoint("TOPLEFT", -1, 1); g.border:SetPoint("BOTTOMRIGHT", 1, -1)
                g.ring:Hide(); g.l1:SetText(""); g.l1:Hide(); g.l2:SetText(""); g.cd:SetText("")
                if g.cool then g.cool:Hide() end
                mine.flow[e.spellID] = g
            end
            local sz = colSize(rem)
            g:SetSize(sz, sz); g:SetScale(1); g:ClearAllPoints()
            g:SetPoint("CENTER", bar, "BOTTOMLEFT", x, colY(rem))
            g:SetAlpha(0.6 + 0.4 * (1 - rem / look))
            g:Show()
        elseif g then
            ReleaseIcon(g); mine.flow[e.spellID] = nil
        end
        -- the plan's next cast of it: a ghost down the same column
        local h = mine.ghosts[e.spellID]
        if e.sched and e.schedRem <= look then
            if not h then
                h = AcquireIcon(rs, bar)
                h.tex:SetTexture(f.tex:GetTexture() or 134400)
                Tex(h.border, T.goldHi, 0.8)
                h.border:ClearAllPoints(); h.border:SetPoint("TOPLEFT", -1, 1); h.border:SetPoint("BOTTOMRIGHT", 1, -1)
                h.ring:Hide(); h.l1:Hide(); h.cd:SetText("")
                if h.cool then h.cool:Hide() end
                ApplyFont(h.l2, DB.fontSize); h.l2:ClearAllPoints(); h.l2:SetPoint("TOP", h, "BOTTOM", 0, -1); h.l2:SetWidth(rs + gap + 10); h.l2:SetJustifyH("CENTER"); Col(h.l2, T.goldHi); h.l2:Show()
                mine.ghosts[e.spellID] = h
            end
            local sz = colSize(e.schedRem) * 0.9
            h:SetSize(sz, sz); h:SetScale(1); h:ClearAllPoints()
            h:SetPoint("CENTER", bar, "BOTTOMLEFT", x + 6, colY(e.schedRem))
            h:SetAlpha(e.schedRem <= 0 and math.max(0, 0.9 + e.schedRem / DB.hold) or 0.7)
            if h.tex.SetDesaturated then h.tex:SetDesaturated(flowing and true or false) end  -- grey while the real one is still on its way
            h.l2:SetText("")   -- the number to read lives under the top-row icon, not on something moving
            h:Show()
        elseif h then
            ReleaseIcon(h); mine.ghosts[e.spellID] = nil
        end
    end
    for i = #mine.list + 1, #mine.rowTops do mine.rowTops[i].fs1:Hide(); mine.rowTops[i].fs2:Hide() end
end
ns.StackTick = StackTick

-- the two casts after the next one: icons with timers, to the right of the slot
local function UpdateQueue(q1, q2)
    local rs, gap = DB.rowIcon, 4
    local x0 = StalkX() + 6 + DB.slotIcon + 4
    local cy = SlotBottom() + DB.slotIcon * 0.5
    for k, q in ipairs({ q1 or false, q2 or false }) do
        local f = mine.queue[k]
        if not q then
            if f then ReleaseIcon(f); mine.queue[k] = nil end
        else
            if not f then
                f = AcquireIcon(rs, bar)
                f.ring:Hide(); f.l1:SetText(""); f.l1:Hide(); f.cd:SetText("")
                if f.cool then f.cool:Hide() end
                ApplyFont(f.l2, DB.fontSize + 1); f.l2:ClearAllPoints(); f.l2:SetPoint("TOP", f, "BOTTOM", 0, -1); f.l2:SetWidth(rs + gap + 10); f.l2:SetJustifyH("CENTER"); Col(f.l2, T.gold); f.l2:Show()
                f.border:ClearAllPoints(); f.border:SetPoint("TOPLEFT", -1, 1); f.border:SetPoint("BOTTOMRIGHT", 1, -1)
                mine.queue[k] = f
            end
            local e = q.e
            if f.entry ~= e then
                f.entry = e
                local tex = e.texture or (e.spellID and SpellTexture(e.spellID)) or (e.isNote and NOTE_TEXTURE) or 134400
                f.tex:SetTexture(tex)
                local c = e.classRGB or KIND_COLOR.util
                f.border:SetColorTexture(c[1], c[2], c[3], 1)
            end
            f:SetSize(rs, rs); f:SetScale(1); f:ClearAllPoints()
            f:SetPoint("CENTER", bar, "BOTTOMLEFT", x0 + (k - 1) * (rs + gap) + rs * 0.5, cy)
            f:SetAlpha(k == 1 and 0.9 or 0.7)
            f.l2:SetText(q.rem <= 0 and "NOW" or FmtRem(q.rem)); if q.rem <= 0 then Col(f.l2, T.green) else Col(f.l2, T.gold) end
            f:Show()
        end
    end
end
ns.UpdateQueue = UpdateQueue
ns.MineUpdate     = MineUpdate
mineBar:SetScript("OnUpdate", nil)

ns.RebuildTracked = RebuildTracked
ns.mine           = mine
ns.mineBar        = mineBar

local perColumn = {}

local linkLines, linkUsed = {}, 0
local function HideLinks()
    for i = 1, linkUsed do linkLines[i]:Hide() end
    linkUsed = 0
end
ns.HideLinks = HideLinks
local function DrawLinks(note)
    HideLinks()
    if not DB.links or not note then return end
    local function line(fa, fb, c, major)
        if not (fa and fb and fa:IsShown() and fb:IsShown()) then return end
        linkUsed = linkUsed + 1
        local l = linkLines[linkUsed]
        if not l then l = bar:CreateLine(nil, "BACKGROUND", nil, 1); linkLines[linkUsed] = l end
        l:SetColorTexture(c[1], c[2], c[3], major and 0.6 or 0.4)
        l:SetThickness(1)   -- WoW draws lines without smoothing: thick diagonals show their stair-steps
        l:SetStartPoint("CENTER", fa, 0, 0)
        l:SetEndPoint("CENTER", fb, 0, 0)
        l:Show()
    end
    for e, f in pairs(activeIcons) do
        if not e.isBoss and not e.pull then
            local b = LK.linkOf[e]
            if b then line(f, activeIcons[b], e.classRGB or GOLD, e.major) end
        end
    end
    if DB.layout == "stack" then
        for _, t in ipairs(mine.list) do
            local h = mine.ghosts[t.spellID]
            local x = t.sched
            local b = x and LK.linkOf[x]
            if h and b then line(h, activeIcons[b], x.classRGB or GOLD, x.major) end
        end
    end
end

local function OnUpdate()
    local note = state.note
    local isStack = DB.layout == "stack"
    if not note and not isStack then return end

    local now = GetTime()
    local elapsed = note and (now - state.startTime) or nil
    local look, hold = DB.lookahead, DB.hold
    local entries = state.entries

    if note then
        if state.awaitingPull and elapsed > DB.pullGrace then
            StopEncounter("No encounter started after the pull timer - timeline stopped.")
            return
        end
        while entries[state.nextIndex] and (entries[state.nextIndex].time - elapsed) < -hold do
            local e = entries[state.nextIndex]
            if activeIcons[e] then ReleaseIcon(activeIcons[e]); activeIcons[e] = nil end
            state.nextIndex = state.nextIndex + 1
        end
        if not entries[state.nextIndex] and state.test and not next(state.live) then
            StopEncounter("Test run finished.")
            return
        end
    end

    -- gather everything inside the window
    wipe(visible); wipe(seen)
    if note then
        local planBoss = DB.planBoss and note.hasStaticBoss
        local hideStaticBoss = state.liveBoss and DB.bwLive and not planBoss
        local i = state.nextIndex
        while entries[i] do
            local e = entries[i]
            local rem = e.time - elapsed
            if rem > look then break end
            if PassesFilter(e) and not (hideStaticBoss and e.isBoss) and not (isStack and TrackedEntry(e)) then
                visible[#visible + 1] = { e = e, rem = rem }
                seen[e] = true
            end
            i = i + 1
        end
        for text, e in pairs(state.live) do
            local rem = e.expires - now
            if rem < -hold then
                state.live[text] = nil
            elseif rem <= look and not planBoss then
                visible[#visible + 1] = { e = e, rem = rem }
                seen[e] = true
            end
        end
    end

    -- release icons that dropped out of the window
    for e, f in pairs(activeIcons) do
        if not seen[e] then ReleaseIcon(f); activeIcons[e] = nil end
    end

    -- acquire icons, retry textures that weren't loaded yet
    for _, v in ipairs(visible) do
        local e = v.e
        local f = activeIcons[e]
        local isMajor = e.major and not e.pull
        if not f then
            f = AcquireIcon(isMajor and DB.iconSize * DB.majorScale or DB.iconSize)
            f.entry = e
            SetupIcon(note, e, f, isMajor)
            activeIcons[e] = f
        elseif f.needTex then
            local t = SpellTexture(f.needTex)
            if t then f.tex:SetTexture(t); f.needTex = nil end
        end
        v.f = f
    end

    -- stack: my own cooldowns coming back join the same column
    if isStack then StackTick(now, elapsed) end

    -- lay out per display column, nearest first
    table.sort(visible, function(a, b) return a.rem < b.rem end)
    for k in pairs(perColumn) do wipe(perColumn[k]) end
    for _, v in ipairs(visible) do
        local col = ColumnFor(v.e)
        perColumn[col] = perColumn[col] or {}
        local list = perColumn[col]
        list[#list + 1] = v
    end
    local isHud = DB.layout == "hud" or isStack
    for col, list in pairs(perColumn) do
        if #list > 0 then
            if isHud then LayoutHud(col, list, note) else LayoutColumn(col, list, note) end
        end
    end
    if isHud and note then UpdateSlots(note, elapsed)
    elseif isStack then for _, f in pairs(slots) do f:Hide(); f.entry = nil end; UpdateQueue(nil, nil) end
    DrawLinks(note)
end

-- offset: seconds already elapsed (negative = pull is that many seconds away)
-- withPullMarker: prepend a "PULL" icon at t = 0
-- the phase start times we have for a note: from the string (phase:N;start:S), else learned from the last pull
local function KnownPhaseStarts(note)
    local starts = { [1] = 0 }
    local learned = note.encounterID and DB.phaseLearned[note.encounterID] and DB.phaseLearned[note.encounterID][note.difficultyID]
    if learned then for k, v in pairs(learned) do starts[k] = v end end
    if note.phaseStarts then for k, v in pairs(note.phaseStarts) do starts[k] = v end end
    return starts
end

-- for tests and the graph: fill the gaps by stacking unknown phases after the previous one
local function EstimatePhaseStarts(note)
    local starts = KnownPhaseStarts(note)
    local maxRel = {}
    local top = 1
    for _, e in ipairs(note.entries) do local p = e.ph or 1; if p > top then top = p end; if (e.rel or e.time or 0) > (maxRel[p] or 0) then maxRel[p] = e.rel or e.time or 0 end end
    local estimated = {}
    for p = 2, top do
        if not starts[p] then
            starts[p] = (starts[p - 1] or 0) + (maxRel[p - 1] or 0) + 15
            estimated[p] = true
        end
    end
    return starts, estimated
end
ns.EstimatePhaseStarts = EstimatePhaseStarts

local function SortEntries(entries)
    table.sort(entries, function(a, b) return a.time < b.time end)
end

local function StartEncounter(note, isTest, offset, withPullMarker)
    StopEncounter()
    LK.CleanNote(note)
    local entries = {}
    if withPullMarker then
        entries[1] = { time = 0, tag = "PULL", pull = true, laneIndex = note.bossLane or 1 }
    end
    if note.phaseRelative then
        -- phase-relative rows: work on copies, anchored to the phase starts we know.
        -- Rows of a phase we have no start for stay out of sight until the boss mod says the stage began.
        local starts = isTest and EstimatePhaseStarts(note) or KnownPhaseStarts(note)
        state.phaseStart = {}
        for k, v in pairs(starts) do state.phaseStart[k] = v end
        for _, e in ipairs(note.entries) do
            local c = {}
            for k, v in pairs(e) do c[k] = v end
            local p = c.ph or 1
            c.time = starts[p] and (starts[p] + c.rel) or math.huge
            entries[#entries + 1] = c
        end
        SortEntries(entries)
    elseif note.hasAnchors or DB.follow then
        -- rows get re-timed during the pull (anchors / follow): work on copies so the stored plan keeps its planned times
        state.phaseStart = { [1] = 0 }
        for _, e in ipairs(note.entries) do
            local c = {}
            for k, v in pairs(e) do c[k] = v end
            c.anchored = nil; c.followed = nil
            entries[#entries + 1] = c
        end
    else
        state.phaseStart = { [1] = 0 }
        for _, e in ipairs(note.entries) do entries[#entries + 1] = e end
    end
    state.phase = 1
    state.anchorCount = {}
    LK.bars = {}
    note.hasStaticBoss = false
    for _, e in ipairs(entries) do if e.isBoss then note.hasStaticBoss = true break end end
    LK.Link(entries)

    state.active    = true
    state.note      = note
    state.entries   = entries
    state.startTime = GetTime() - (offset or 0)
    state.nextIndex = 1
    state.test      = isTest or false
    playerName      = nil
    wipe(state.live)
    state.liveBoss  = false
    myName          = nil
    -- ask the client to load spell data now, so icons resolve before they're needed
    if C_Spell and C_Spell.RequestLoadSpellData then
        for _, e in ipairs(entries) do if e.spellID then pcall(C_Spell.RequestLoadSpellData, e.spellID) end end
    end
    ApplyBarLayout()
end

-- which per-frame driver runs: the live-cooldown column, the note timeline, or nothing
function ns.SetUpdater()
    if state.active or DB.layout == "stack" then
        bar:SetScript("OnUpdate", OnUpdate)
    else
        bar:SetScript("OnUpdate", nil)
    end
end

-- a boss-mod stage change: anchor that phase's rows to now, remember the time for next pull
local function OnStage(stage, source)
    stage = tonumber(stage)
    if not stage or stage < 1 or not state.active or not state.note then return end
    local elapsed = GetTime() - state.startTime
    if elapsed < 0 then elapsed = 0 end
    if stage == state.phase and stage ~= 1 then return end
    state.phase = stage
    if stage == 1 and elapsed < 1 then return end -- the pull itself
    state.phaseStart[stage] = elapsed
    local note = state.note
    if note.encounterID and note.encounterID ~= 0 then
        DB.phaseLearned[note.encounterID] = DB.phaseLearned[note.encounterID] or {}
        DB.phaseLearned[note.encounterID][note.difficultyID] = DB.phaseLearned[note.encounterID][note.difficultyID] or {}
        DB.phaseLearned[note.encounterID][note.difficultyID][stage] = elapsed
    end
    if note.phaseRelative then
        local n = 0
        for _, e in ipairs(state.entries) do
            if (e.ph or 1) == stage and e.rel then
                if activeIcons[e] then ReleaseIcon(activeIcons[e]); activeIcons[e] = nil end
                e.time = elapsed + e.rel; n = n + 1
            end
        end
        SortEntries(state.entries); LK.Link(state.entries)
        local i = 1
        while state.entries[i] and (state.entries[i].time - elapsed) < -DB.hold do i = i + 1 end
        state.nextIndex = i
        Print("Stage %d at %d:%02d (%s) - %d row(s) anchored.", stage, math.floor(elapsed / 60), math.floor(elapsed % 60), source or "?", n)
        if ns.ApplyGraphLayout then ns.ApplyGraphLayout() end
    end
end
ns.OnStage = OnStage

-- a note with just a Boss lane, so BigWigs timers still show on bosses with no plan
local function SyntheticNote(encounterName)
    return { entries = {}, lanes = { { id = "boss", name = "Boss", kind = "boss" } }, bossLane = 1, encounterID = 0, difficultyID = 0, name = encounterName or "?", synthetic = true }
end

------------------------------------------------------------------------
-- BigWigs live timers
------------------------------------------------------------------------
-- does a plan row's anchor (spell ID or bar text) describe this BigWigs bar?
local function AnchorMatches(anchor, key, text)
    if type(anchor) == "number" then
        if tonumber(key) == anchor then return true end
        local nm = SpellName(anchor)
        return nm ~= nil and nm ~= "" and text:lower():find(nm:lower(), 1, true) ~= nil
    end
    return text:lower():find(tostring(anchor):lower(), 1, true) ~= nil
end

-- a BigWigs bar started (or restarted): rows anchored to this ability's n-th cast
-- move to the bar's end + their offset, so they track the real cast, not the plan's clock
local function AnchorToBar(key, text, expires, isNew)
    local note = state.note
    if not note or not note.hasAnchors or not state.entries then return end
    local counts = state.anchorCount
    if not counts then counts = {}; state.anchorCount = counts end
    local elapsed = GetTime() - state.startTime
    local matched = {}
    for _, e in ipairs(state.entries) do
        if e.anchor ~= nil and not e.isBoss then
            local ak = tostring(e.anchor)
            if matched[ak] == nil then matched[ak] = AnchorMatches(e.anchor, key, text) end
        end
    end
    local hit = false
    for ak, ok in pairs(matched) do
        if ok then
            hit = true
            if isNew then counts[ak] = (counts[ak] or 0) + 1 end
        end
    end
    if not hit then return end
    local changed, label = 0, nil
    for _, e in ipairs(state.entries) do
        if e.anchor ~= nil and not e.isBoss and matched[tostring(e.anchor)] and (e.anchorN or 1) == (counts[tostring(e.anchor)] or 0) then
            local t = (expires - state.startTime) + (e.anchorOff or 0)
            if t > elapsed - DB.hold and math.abs(t - e.time) > 0.05 then
                if activeIcons[e] then ReleaseIcon(activeIcons[e]); activeIcons[e] = nil end
                e.planned = e.planned or e.time
                e.time = t
                e.anchored = true
                changed = changed + 1
                label = label or e.label
            end
        end
    end
    if changed > 0 then
        SortEntries(state.entries); LK.Link(state.entries)
        local i = 1
        while state.entries[i] and (state.entries[i].time - elapsed) < -DB.hold do i = i + 1 end
        state.nextIndex = i
        if DB.anchorChat then Print("%s: %d row(s) moved to %s (#%d).", text, changed, label or "?", counts[next(matched)] or 0) end
        if ns.ApplyGraphLayout then ns.ApplyGraphLayout() end
    end
end

-- Follow: a BigWigs bar says when an ability is really coming. Find that ability in the plan (by spell name),
-- and if the real hit is early or late, slide it, the cooldowns assigned to it and every later row by the same amount,
-- so each cooldown keeps its gap to the hit (e.g. 1 s before) even when a stage starts sooner or later than planned.
function LK.Follow(key, text, expires)
    local note = state.note
    if not DB.follow or not note or note.phaseRelative or note.hasAnchors or not state.entries then return end
    LK.bars = LK.bars or {}
    local now = GetTime() - state.startTime
    local barHit = expires - state.startTime
    local prev = LK.bars[text]
    local row
    if prev and prev.row and prev.expires > GetTime() + 0.5 then
        row = prev.row                                   -- the same bar re-timed: keep following the same hit
    else
        local names = {}
        local kn = tonumber(key) and SpellName(tonumber(key))
        if kn and kn ~= "" then names[#names + 1] = kn:lower() end
        local tx = text:lower():gsub("%s*%(%d+%)", ""):gsub("%s*%d+$", "")
        names[#names + 1] = tx
        local bd
        for _, e in ipairs(state.entries) do
            if e.isBoss and not e.live and not e.followed and e.time and e.time < math.huge then
                local nm = LK.HitName(e):lower()
                local ok = false
                for _, n in ipairs(names) do
                    if #n >= 4 and (nm:find(n, 1, true) or n:find(nm, 1, true)) then ok = true break end
                end
                if ok then
                    local d = (barHit + LK.CastLen(e)) - LK.HitTime(e)
                    if math.abs(d) <= 45 and LK.HitTime(e) > now - 2 and (not bd or math.abs(d) < math.abs(bd)) then row, bd = e, d end
                end
            end
        end
        if not row then return end
    end
    LK.bars[text] = { expires = expires, row = row }
    row.followed = true
    local d = (barHit + LK.CastLen(row)) - LK.HitTime(row)
    -- rows timed at the hit with no cast time in the label: a bar ends at the cast START, so ignore the cast-sized gap
    if math.abs(d) < (LK.CastLen(row) > 0 and 0.75 or 4) then return end
    local from, moved = row.time, 0
    for _, e in ipairs(state.entries) do
        if not e.live and not e.pull and e.time and e.time < math.huge then
            local mine = (e == row) or (LK.linkOf[e] == row)
            local later = e.time > from and not e.followed and not (LK.linkOf[e] and LK.linkOf[e].followed and LK.linkOf[e] ~= row)
            if (mine or later) and e.time + d > now then
                if activeIcons[e] then ReleaseIcon(activeIcons[e]); activeIcons[e] = nil end
                e.planned = e.planned or e.time
                e.time = e.time + d
                moved = moved + 1
            end
        end
    end
    if moved > 0 then
        SortEntries(state.entries); LK.Link(state.entries)
        local i = 1
        while state.entries[i] and (state.entries[i].time - now) < -DB.hold do i = i + 1 end
        state.nextIndex = i
        if math.abs(d) >= 3 or DB.anchorChat then Print("%s is %.0f s %s - plan moved to match.", LK.HitName(row), math.abs(d), d < 0 and "early" or "late") end
        if ns.ApplyGraphLayout then ns.ApplyGraphLayout() end
    end
end

local function BW_StartBar(_, module, key, text, duration, icon)
    if not state.active or not state.note or not text then return end
    duration = tonumber(duration); if not duration then return end
    local isNew = state.live[text] == nil
    local expires = GetTime() + duration
    if DB.bwLive then
        local e = state.live[text]
        if not e then
            e = { label = text, isBoss = true, live = true, laneIndex = state.note.bossLane or 1, major = false, tag = "" }
            state.live[text] = e
        end
        e.expires = expires
        e.texture = icon
        state.liveBoss = true
    end
    AnchorToBar(key, text, expires, isNew)
    LK.Follow(key, text, expires)
end

local function BW_StopBar(_, module, text)
    local e = text and state.live[text]
    if e then
        if activeIcons[e] then ReleaseIcon(activeIcons[e]); activeIcons[e] = nil end
        state.live[text] = nil
    end
end

local function BW_StopAll()
    for text, e in pairs(state.live) do
        if activeIcons[e] then ReleaseIcon(activeIcons[e]); activeIcons[e] = nil end
        state.live[text] = nil
    end
end

local bwHooked = false
local function HookBigWigs()
    if bwHooked or not BigWigsLoader or not BigWigsLoader.RegisterMessage then return end
    local ok = pcall(function()
        BigWigsLoader.RegisterMessage(ns, "BigWigs_StartBar", BW_StartBar)
        BigWigsLoader.RegisterMessage(ns, "BigWigs_StopBar", BW_StopBar)
        BigWigsLoader.RegisterMessage(ns, "BigWigs_StopBars", BW_StopAll)
        BigWigsLoader.RegisterMessage(ns, "BigWigs_OnBossDisable", BW_StopAll)
        BigWigsLoader.RegisterMessage(ns, "BigWigs_OnBossWipe", BW_StopAll)
    end)
    pcall(function() BigWigsLoader.RegisterMessage(ns, "BigWigs_OnBossEnable", function(_, module) if LK.OnBossModule then LK.OnBossModule(module) end end) end)
    bwHooked = ok
    pcall(function() BigWigsLoader.RegisterMessage(ns, "BigWigs_SetStage", function(_, module, stage) ns.OnStage(stage, "BigWigs") end) end)
    -- pull timer (best effort; message name varies between BigWigs versions)
    pcall(function()
        BigWigsLoader.RegisterMessage(ns, "BigWigs_StartPull", function(_, module, seconds) ns.OnPullTimer(seconds, "BigWigs") end)
        BigWigsLoader.RegisterMessage(ns, "BigWigs_StopPull",  function() ns.OnPullTimer(0, "BigWigs") end)
    end)
end

------------------------------------------------------------------------
-- Pull timers
-- Sources: Blizzard countdown (START_TIMER - DBM and BigWigs both use it
-- when in a group), plus DBM / BigWigs addon-comm syncs as a fallback.
-- The clock is re-synced to the real pull when ENCOUNTER_START fires.
------------------------------------------------------------------------
local FindNote -- forward

local function PickArmedNote()
    local function get(ref)
        if ref and ref.encounterID then
            local n = FindNote(ref.encounterID, ref.difficultyID or 0)
            if n then return n end
        end
    end
    return get(DB.armed) or get(DB.nextUp) or get(DB.lastFought) or get(DB.lastImport)
end

local function OnPullTimer(seconds, source, isTest)
    if not DB.pullTimer and not isTest then return end
    seconds = tonumber(seconds)
    if not seconds then return end

    if seconds <= 0 then
        if state.awaitingPull then StopEncounter("Pull cancelled.") end
        return
    end
    -- already running a real encounter: ignore stray timers
    if state.active and not state.awaitingPull and not state.test then return end

    local note = PickArmedNote()
    if not note then
        Print("Pull timer seen (%s) but no note to arm - /tl import or /tl use <encounterID>.", source)
        return
    end
    StartEncounter(note, isTest, -seconds, true)
    state.awaitingPull = not isTest
    Print("Armed %s %s from %s pull timer (%ds).", note.name or "?", DIFF_NAME[note.difficultyID] or "", source, seconds)
end

-- what to show and arm next: after a kill, the next boss in raid order that has a plan; when BigWigs loads a boss module
-- (you walk up to a boss), that boss. A pin (/tl use) only lasts until the next kill.
LK.RAID_ORDER = { 3470, 3445, 3455, 3497, 3420, 3421, 3429, 3492 }
function LK.SetNextUp(encID, diffID, why)
    if not encID then return end
    local n = FindNote(encID, diffID or 0)
    if not n then return end
    local was = DB.nextUp and DB.nextUp.encounterID
    DB.nextUp = { encounterID = encID, difficultyID = n.difficultyID or diffID }
    if was ~= encID then
        Print("Next up: %s %s%s.", n.name or "?", DIFF_NAME[n.difficultyID] or "", why and (" (" .. why .. ")") or "")
        if not state.active and ns.ApplyGraphLayout then ns.ApplyGraphLayout() end
    end
end
function LK.AfterKill(encID, diffID)
    if DB.armed then DB.armed = nil end
    for i, id in ipairs(LK.RAID_ORDER) do
        if id == encID then
            for j = i + 1, #LK.RAID_ORDER do
                local nid = LK.RAID_ORDER[j]
                if FindNote(nid, diffID or 0) then LK.SetNextUp(nid, diffID, "after the kill"); return end
            end
        end
    end
    DB.nextUp = nil
end
function LK.OnBossModule(module)
    local id = module and (module.engageId or (module.GetEncounterID and module:GetEncounterID()))
    if type(id) ~= "number" then return end
    local _, _, diffID = GetInstanceInfo()
    LK.SetNextUp(id, diffID, "BigWigs")
end

local function OnEncounterStart(encounterID, encounterName, difficultyID)
    DB.lastFought = { encounterID = encounterID, difficultyID = difficultyID }
    local note, exact = FindNote(encounterID, difficultyID)

    -- armed from a pull timer: re-sync the clock to the real pull
    if state.awaitingPull and state.note then
        if state.note.encounterID == encounterID then
            state.startTime = GetTime()
            state.awaitingPull = false
            -- the pull marker is now due; let it fire naturally
            return
        end
        -- armed for the wrong boss: fall through and restart with the right note
    end

    if not note and DB.notes[0] then
        -- an imported Viserio plan with no encounter ID: use it for this boss
        for _, n in pairs(DB.notes[0]) do note = n break end
        if note then
            exact = true
            Print("Using the unassigned Viserio plan for %s. /tl assign %d to keep it bound to this boss.", encounterName or "?", encounterID)
        end
    end
    if note then
        StartEncounter(note, false)
        if not exact then
            Print("Using %s note for %s (no %s note stored).", DIFF_NAME[note.difficultyID] or "?", encounterName or "?", DIFF_NAME[difficultyID] or tostring(difficultyID))
        end
    elseif DB.bwLive and BigWigsLoader then
        StartEncounter(SyntheticNote(encounterName), false)
    elseif state.awaitingPull then
        StopEncounter("Encounter started but no note stored for it.")
    end
end

------------------------------------------------------------------------
-- Note lookup
------------------------------------------------------------------------
-- Smiler pack: built-in Heroic/Mythic fight plans (boss casts, phases, raid-damage curve) from the
-- Smiler_Fights add-on. Used when you have no plan for a boss, and laid under a plan that has no boss
-- lane or damage curve of its own (e.g. a plain NSRT note with just cooldowns).
local BUILTIN = { parsed = {} }
local MERGED = setmetatable({}, { __mode = "k" })
function BUILTIN.Load()
    if SmilerFights then return true end
    if BUILTIN.tried then return false end
    BUILTIN.tried = true
    local load = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
    if load then pcall(load, "Smiler_Fights") end
    return SmilerFights ~= nil
end
function BUILTIN.Get(encounterID, difficultyID)
    if not BUILTIN.Load() then return nil end
    local byDiff = SmilerFights[encounterID]
    if not byDiff then return nil end
    local d = (byDiff[difficultyID] and difficultyID) or (byDiff[15] and 15) or (byDiff[16] and 16)
    if not d then for k in pairs(byDiff) do d = k break end end
    if not d then return nil end
    local key = encounterID .. "/" .. d
    if not BUILTIN.parsed[key] then
        local ok, n = pcall(ParseNote, byDiff[d])
        if not ok or not n then return nil end
        n.builtin = true
        n.encounterID, n.difficultyID = encounterID, d
        BUILTIN.parsed[key] = n
    end
    return BUILTIN.parsed[key], d == difficultyID
end
function BUILTIN.Count()
    if not BUILTIN.Load() then return 0, 0 end
    local h, m = 0, 0
    for _, byDiff in pairs(SmilerFights) do if byDiff[15] then h = h + 1 end; if byDiff[16] then m = m + 1 end end
    return h, m
end
local function copyEntry(e) local c = {}; for k, v in pairs(e) do c[k] = v end; return c end
-- your plan + the built-in boss lane and damage curve, when your plan has neither
function BUILTIN.Merge(user, base)
    if not base or user.builtin or user.bossLane or (user.curves and next(user.curves)) then return user end
    local cached = MERGED[user]
    if cached and cached.base == base and cached.n == #user.entries then return cached.note end
    local m = {}
    for k, v in pairs(user) do m[k] = v end
    m.lanes = { base.lanes[base.bossLane or 1] }
    for _, l in ipairs(user.lanes or {}) do m.lanes[#m.lanes + 1] = l end
    m.entries = {}
    for _, e in ipairs(base.entries) do
        if e.isBoss then local c = copyEntry(e); c.laneIndex = 1; m.entries[#m.entries + 1] = c end
    end
    for _, e in ipairs(user.entries) do
        local c = copyEntry(e); c.laneIndex = (e.laneIndex or 1) + 1; m.entries[#m.entries + 1] = c
    end
    table.sort(m.entries, function(a, b)
        if (a.ph or 1) ~= (b.ph or 1) then return (a.ph or 1) < (b.ph or 1) end
        return (a.rel or a.time or 0) < (b.rel or b.time or 0)
    end)
    m.bossLane, m.curves = 1, base.curves
    m.duration = math.max(user.duration or 0, base.duration or 0)
    if m.duration == 0 then m.duration = nil end
    m.phaseRelative = user.phaseRelative or base.phaseRelative
    m.hasAnchors = user.hasAnchors or base.hasAnchors
    m.withBuiltin = true
    MERGED[user] = { base = base, n = #user.entries, note = m }
    return m
end
ns.Builtin = BUILTIN

function FindNote(encounterID, difficultyID)
    local byDiff = DB.notes[encounterID]
    local base, baseExact = BUILTIN.Get(encounterID, difficultyID)
    -- your plan for this difficulty, then the built-in one, then your plan for another difficulty
    if byDiff and byDiff[difficultyID] then return BUILTIN.Merge(UpgradeNote(byDiff[difficultyID]), base), true end
    if base and baseExact then return base, true end
    if byDiff then for _, n in pairs(byDiff) do return BUILTIN.Merge(UpgradeNote(n), base), false end end
    if base then return base, false end
end

------------------------------------------------------------------------
-- Plans per class: DB.notes always holds the plans of the class you're logged in on;
-- the other classes' plans wait in DB.byClass until you log in on one of them.
------------------------------------------------------------------------
local PC = { keyByToken = {} }
for name in pairs(CLASS_RGB) do PC.keyByToken[name:upper():gsub("%s", "")] = name end
function PC.PlayerClassKey()
    local _, token = UnitClass("player")
    return token and PC.keyByToken[token] or nil
end
-- the class a plan is for: every cooldown row in it is that one class (a raid-wide plan with several classes has none)
function PC.NoteClass(note)
    local cls
    for _, e in ipairs(note.entries or {}) do
        if not e.isBoss and e.className then
            if cls and cls ~= e.className then return nil end
            cls = e.className
        end
    end
    return cls
end
ns.NoteClass = PC.NoteClass
function PC.ClassSet(cls)
    DB.byClass = DB.byClass or {}
    DB.byClass[cls] = DB.byClass[cls] or { notes = {} }
    DB.byClass[cls].notes = DB.byClass[cls].notes or {}
    return DB.byClass[cls]
end
function PC.UseClassPlans()
    local cls = PC.PlayerClassKey()
    if not cls or DB.plansClass == cls then return end
    DB.byClass = DB.byClass or {}
    if DB.plansClass == nil then
        -- first run: sort the plans already stored by the class they are for
        local all = DB.notes or {}
        DB.notes = {}
        for enc, byDiff in pairs(all) do
            for diff, n in pairs(byDiff) do
                local c = PC.NoteClass(n) or cls
                local set = (c == cls) and DB.notes or PC.ClassSet(c).notes
                set[enc] = set[enc] or {}; set[enc][diff] = n
                if c ~= cls and DB.lastImport and DB.lastImport.encounterID == enc and DB.lastImport.difficultyID == diff then
                    PC.ClassSet(c).lastImport = DB.lastImport; DB.lastImport = nil
                end
            end
        end
    else
        DB.byClass[DB.plansClass] = { notes = DB.notes or {}, lastImport = DB.lastImport, armed = DB.armed }
        local mine = DB.byClass[cls] or {}
        DB.byClass[cls] = nil
        DB.notes = mine.notes or {}; DB.lastImport = mine.lastImport; DB.armed = mine.armed
    end
    DB.plansClass = cls
    local n = 0
    for _, byDiff in pairs(DB.notes) do for _ in pairs(byDiff) do n = n + 1 end end
    Print("%d %s plan%s loaded.", n, cls, n == 1 and "" or "s")
end
ns.UseClassPlans = PC.UseClassPlans

local function StoreNote(note)
    if not note.encounterID then
        return false, "no EncounterID in string"
    end
    if #note.entries == 0 then
        return false, "no cooldown rows found"
    end
    local cls, me = PC.NoteClass(note), DB.plansClass or PC.PlayerClassKey()
    if cls and me and cls ~= me then
        -- a plan for another class: keep it for when you log in on that class
        local set = PC.ClassSet(cls)
        set.notes[note.encounterID] = set.notes[note.encounterID] or {}
        set.notes[note.encounterID][note.difficultyID] = note
        set.lastImport = { encounterID = note.encounterID, difficultyID = note.difficultyID }
        Print("This is a %s plan - stored for your %s; it loads when you log in on one.", cls, cls)
        return true
    end
    DB.notes[note.encounterID] = DB.notes[note.encounterID] or {}
    DB.notes[note.encounterID][note.difficultyID] = note
    DB.lastImport = { encounterID = note.encounterID, difficultyID = note.difficultyID }
    return true
end

------------------------------------------------------------------------
-- Flat widgets (Storm Command look): panel, button, check, slider, edit box
------------------------------------------------------------------------
local function Panel(name, w, h, strata)
    local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    f:SetSize(w, h)
    f:SetPoint("CENTER")
    f:SetFrameStrata(strata or "DIALOG")
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    f:SetBackdropColor(T.card[1], T.card[2], T.card[3], 0.97)
    f:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], BORDER_A)
    -- a 2 px gold rule under the title row
    f.rule = f:CreateTexture(nil, "ARTWORK"); Tex(f.rule, T.gold, 0.9); f.rule:SetHeight(2)
    f.rule:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -38); f.rule:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -38)
    f.title = f:CreateFontString(nil, "OVERLAY"); ApplyFont(f.title, 18); Col(f.title, T.fg); f.title:SetPoint("TOPLEFT", 14, -11)
    f.sub = f:CreateFontString(nil, "OVERLAY"); ApplyFont(f.sub, 11); Col(f.sub, T.muted); f.sub:SetPoint("LEFT", f.title, "RIGHT", 10, -1)
    f:Hide()
    return f
end

local function FlatButton(parent, text, w, h, primary)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w or 80, h or 22)
    b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    b.fs = b:CreateFontString(nil, "OVERLAY"); ApplyFont(b.fs, 12); b.fs:SetPoint("CENTER", 0, 0); b.fs:SetJustifyH("CENTER")
    b.primary = primary
    b.enabled = true
    local function paint(hover)
        if b.primary then
            b:SetBackdropColor(T.gold[1], T.gold[2], T.gold[3], hover and 1 or 0.9); b:SetBackdropBorderColor(T.gold[1], T.gold[2], T.gold[3], 1); Col(b.fs, T.bg)
        else
            b:SetBackdropColor(T.panel[1], T.panel[2], T.panel[3], 1)
            if hover then b:SetBackdropBorderColor(T.gold[1], T.gold[2], T.gold[3], 0.9); Col(b.fs, T.goldHi) else b:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], BORDER_A); Col(b.fs, T.fg) end
        end
        if not b.enabled then b:SetAlpha(0.45) else b:SetAlpha(1) end
    end
    b.paint = paint
    b.SetText = function(self, t) self.fs:SetText(t) end
    b.GetText = function(self) return self.fs:GetText() end
    b.SetEnabled = function(self, on) self.enabled = on and true or false; if self.SetMouseClickEnabled then self:SetMouseClickEnabled(self.enabled) end; paint(false) end
    b:SetScript("OnEnter", function() if b.enabled then paint(true) end end)
    b:SetScript("OnLeave", function() paint(false) end)
    b:SetText(text or "")
    paint(false)
    return b
end
ns.FlatButton = FlatButton

local function FlatCheck(parent)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(16, 16)
    b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    b:SetBackdropColor(T.panel[1], T.panel[2], T.panel[3], 1)
    b:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], BORDER_A)
    b.dot = b:CreateTexture(nil, "ARTWORK"); Tex(b.dot, T.gold, 1); b.dot:SetPoint("TOPLEFT", 4, -4); b.dot:SetPoint("BOTTOMRIGHT", -4, 4); b.dot:Hide()
    b.checked = false
    b.SetChecked = function(self, v) self.checked = v and true or false; if self.checked then self.dot:Show(); self:SetBackdropBorderColor(T.gold[1], T.gold[2], T.gold[3], 0.9) else self.dot:Hide(); self:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], BORDER_A) end end
    b.GetChecked = function(self) return self.checked end
    b:SetScript("OnEnter", function() b:SetBackdropBorderColor(T.gold[1], T.gold[2], T.gold[3], 0.9) end)
    b:SetScript("OnLeave", function() b:SetChecked(b.checked) end)
    return b
end

local function FlatSlider(parent, w)
    local sl = CreateFrame("Slider", nil, parent)
    sl:SetSize(w or 300, 16)
    sl:SetOrientation("HORIZONTAL")
    sl.track = sl:CreateTexture(nil, "BACKGROUND"); Tex(sl.track, T.border, 0.5); sl.track:SetHeight(2); sl.track:SetPoint("LEFT", 0, 0); sl.track:SetPoint("RIGHT", 0, 0)
    sl:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    local th = sl:GetThumbTexture(); if th then th:SetSize(8, 16); th:SetVertexColor(T.gold[1], T.gold[2], T.gold[3], 1) end
    sl:EnableMouse(true)
    return sl
end

local function FlatEdit(parent, w, h, multi)
    local eb = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    eb:SetSize(w or 120, h or 22)
    eb:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    eb:SetBackdropColor(T.bg[1], T.bg[2], T.bg[3], 0.9)
    eb:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], BORDER_A)
    eb:SetFont(BUNDLED_FONTS.barlow, 12, "")
    eb:SetTextColor(T.fg[1], T.fg[2], T.fg[3])
    eb:SetTextInsets(6, 6, 2, 2)
    eb:SetAutoFocus(false)
    if multi then eb:SetMultiLine(true) end
    eb:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(T.gold[1], T.gold[2], T.gold[3], 0.9) end)
    eb:SetScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], BORDER_A) end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return eb
end

-- a scroll area without Blizzard's scrollbar art: mouse wheel + a thin gold indicator
local function FlatScroll(parent, name)
    local sf = CreateFrame("ScrollFrame", name, parent)
    sf:EnableMouseWheel(true)
    sf.bar = sf:CreateTexture(nil, "OVERLAY"); Tex(sf.bar, T.gold, 0.6); sf.bar:SetWidth(2); sf.bar:Hide()
    local function update()
        local child = sf:GetScrollChild(); if not child then return end
        local ch, h = child:GetHeight() or 0, sf:GetHeight() or 1
        local range = math.max(0, ch - h)
        if range <= 0 then sf.bar:Hide(); return end
        local frac = (sf:GetVerticalScroll() or 0) / range
        local len = math.max(20, h * h / ch)
        sf.bar:ClearAllPoints(); sf.bar:SetHeight(len); sf.bar:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 6, -(h - len) * frac); sf.bar:Show()
    end
    sf.update = update
    sf:SetScript("OnMouseWheel", function(self, delta)
        local child = self:GetScrollChild(); if not child then return end
        local range = math.max(0, (child:GetHeight() or 0) - (self:GetHeight() or 0))
        local v = math.max(0, math.min(range, (self:GetVerticalScroll() or 0) - delta * 40))
        self:SetVerticalScroll(v); update()
    end)
    sf:SetScript("OnSizeChanged", update)
    return sf
end

------------------------------------------------------------------------
-- Import window
------------------------------------------------------------------------
local importFrame

local function BuildImportFrame()
    local f = Panel("CDTimelineImport", 540, 380)
    tinsert(UISpecialFrames, "CDTimelineImport") -- Esc closes it
    f.title:SetText("Import")
    f.sub:SetText("a planner string, a Viserio export, or a plain NSRT note")

    local hint = f:CreateFontString(nil, "OVERLAY"); ApplyFont(hint, 11); Col(hint, T.muted)
    hint:SetPoint("TOPLEFT", 14, -46)
    hint:SetText("Paste below. A CD Timeline string carries lanes, boss casts, phases and curves; an NSRT note just the cooldowns.")

    local box = CreateFrame("Frame", nil, f, "BackdropTemplate")
    box:SetPoint("TOPLEFT", 14, -64); box:SetPoint("BOTTOMRIGHT", -14, 48)
    box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    box:SetBackdropColor(T.bg[1], T.bg[2], T.bg[3], 0.9); box:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], BORDER_A)
    local scroll = FlatScroll(box, "CDTimelineImportScroll")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -10, 6)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(0)
    edit:SetMaxBytes(0)
    edit:SetFont(BUNDLED_FONTS.barlowmedium, 12, "")
    edit:SetTextColor(T.fg[1], T.fg[2], T.fg[3])
    edit:SetWidth(scroll:GetWidth() - 8)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scroll:SetScrollChild(edit)
    -- keep the edit box at least as tall as the scroll area so clicks focus it
    scroll:SetScript("OnSizeChanged", function(self, w, h) edit:SetWidth(w - 8); if edit:GetHeight() < h then edit:SetHeight(h) end end)
    edit:SetHeight(scroll:GetHeight())
    scroll:EnableMouse(true)
    scroll:SetScript("OnMouseDown", function() edit:SetFocus() end)
    f.edit = edit

    local status = f:CreateFontString(nil, "OVERLAY"); ApplyFont(status, 11); Col(status, T.fg2)
    status:SetPoint("BOTTOMLEFT", 14, 16)
    status:SetPoint("RIGHT", f, "RIGHT", -240, 0)
    status:SetJustifyH("LEFT")
    f.status = status

    local importBtn = FlatButton(f, "Import", 90, 24, true)
    importBtn:SetPoint("BOTTOMRIGHT", -14, 12)
    importBtn:SetScript("OnClick", function()
        local text = edit:GetText() or ""
        if text:match("^%s*$") then status:SetText("|cffff2d55Nothing to import.|r"); return end
        local note, perr
        if LooksLikeBlob(text) then
            note, perr = ParseViserioBlob(text)
            if not note then status:SetText("|cffff2d55Viserio export not readable: " .. tostring(perr) .. "|r"); return end
        else
            -- several plans pasted at once (one "EncounterID:" header each): store them all
            local parts, pos = {}, 1
            while true do
                local a = text:find("EncounterID:", pos, true)
                if not a then break end
                local b = text:find("EncounterID:", a + 1, true)
                parts[#parts + 1] = text:sub(a, b and b - 1 or #text)
                if not b then break end
                pos = b
            end
            if #parts > 1 then
                local okN, names = 0, {}
                for _, part in ipairs(parts) do
                    local n = ParseNote(part)
                    local ok2 = StoreNote(n)
                    if ok2 then okN = okN + 1; names[#names + 1] = (n.name or "?") .. " " .. (DIFF_NAME[n.difficultyID] or "") end
                end
                status:SetText(string.format("|cff00e676Imported %d of %d plans.|r", okN, #parts))
                Print("Imported %d plans: %s", okN, table.concat(names, ", "))
                return
            end
            note = ParseNote(text)
        end
        local ok, err = StoreNote(note)
        if not ok then
            status:SetText("|cffff2d55Import failed: " .. err .. "|r")
            return
        end
        status:SetText(string.format("|cff00e676Imported|r %s (%s, ID %d) - %d entries, %d lane%s. /tl test to preview.",
            note.name or "?", DIFF_NAME[note.difficultyID] or note.difficulty or "?", note.encounterID, #note.entries, #note.lanes, #note.lanes == 1 and "" or "s"))
        Print("Imported %s %s - %d rows.", note.name or "?", DIFF_NAME[note.difficultyID] or "", #note.entries)
        if note.encounterID == 0 then
            Print("This plan has no encounter ID: it will be used for the next boss you pull, or bind it now with /tl assign <encounterID>.")
        end
    end)

    local closeBtn = FlatButton(f, "Close", 70, 24)
    closeBtn:SetPoint("RIGHT", importBtn, "LEFT", -6, 0)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local clearBtn = FlatButton(f, "Clear", 70, 24)
    clearBtn:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)
    clearBtn:SetScript("OnClick", function() edit:SetText(""); status:SetText("") end)

    return f
end

local function ShowImport()
    importFrame = importFrame or BuildImportFrame()
    importFrame.status:SetText("")
    importFrame:Show()
    importFrame.edit:SetFocus()
end

------------------------------------------------------------------------
-- Fight graph: the whole fight on one strip (up to 11 minutes). Boss casts
-- and your assigned cooldowns as markers on the time axis, the planner's
-- damage and healing curves underneath, and a spark that races along the
-- bottom from the pull like a fuse.
------------------------------------------------------------------------
local graph = CreateFrame("Frame", "CDTimelineGraph", UIParent, "BackdropTemplate")
graph:SetClampedToScreen(true)
graph:RegisterForDrag("LeftButton")
graph:SetScript("OnDragStart", function(self) if not DB.locked then self:StartMoving() end end)
graph:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    DB.graphPoint = ns.SavePoint(self) or DB.graphPoint
end)
graph:Hide()
local G = { note = nil, duration = 600, texPool = {}, texUsed = 0, iconPool = {}, iconUsed = 0, fsPool = {}, fsUsed = 0, rows = {} }
local GRAPH_MAX = 660 -- 11 minutes
local PAD_L, PAD_R, PAD_T, PAD_B = 8, 8, 18, 16

local function GTex(layer, sub)
    G.texUsed = G.texUsed + 1
    local t = G.texPool[G.texUsed]
    if not t then t = graph:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0); G.texPool[G.texUsed] = t end
    t:SetDrawLayer(layer or "ARTWORK", sub or 0)
    t:ClearAllPoints(); t:SetTexture(nil); t:SetAlpha(1); t:SetRotation(0); t:SetBlendMode("BLEND"); t:SetTexCoord(0, 1, 0, 1)
    t:SetHorizTile(false); t:SetVertTile(false); t:SetVertexColor(1, 1, 1, 1); t:Show()
    return t
end
local function GFS(size)
    G.fsUsed = G.fsUsed + 1
    local f = G.fsPool[G.fsUsed]
    if not f then f = graph:CreateFontString(nil, "OVERLAY"); G.fsPool[G.fsUsed] = f end
    ApplyFont(f, size or DB.fontSize - 1, (not DB.graphBg) and "OUTLINE" or nil)
    f:ClearAllPoints(); Col(f, T.muted); f:SetJustifyH("LEFT"); f:Show()
    return f
end
local function GReset()
    for i = 1, (G.lineUsed or 0) do G.linePool[i]:Hide() end
    G.lineUsed = 0
    for i = 1, G.texUsed do G.texPool[i]:Hide() end
    for i = 1, G.fsUsed do G.fsPool[i]:Hide() end
    G.texUsed, G.fsUsed = 0, 0
end

-- absolute time of a note row for the graph (phase-relative rows via known / estimated phase starts)
local function GraphTime(note, e, starts)
    if note.phaseRelative and e.rel then
        local st = starts[e.ph or 1]
        return st and (st + e.rel) or nil
    end
    return e.time
end

local function GraphDuration(note, starts)
    local d = note and note.duration
    if not d or d <= 0 then
        d = 60
        if note then
            for _, e in ipairs(note.entries) do local t = GraphTime(note, e, starts); if t and t + 20 > d then d = t + 20 end end
            for _, c in pairs(note.curves or {}) do if #c.data * c.step > d then d = #c.data * c.step end end
        end
    end
    return math.max(60, math.min(GRAPH_MAX, d))
end

-- draw everything static for this note (markers, curves, axis); the spark moves in GraphTick
local function GraphSetNote(note)
    if DB.graphVertical ~= false and ns.VG then return ns.VG.Set(note) end
    graph.vertical = false
    if ns.VG then ns.VG.Reset(); ns.VG.cell = nil; ns.VG.clip:Hide(); if ns.VG.nowTex then ns.VG.nowTex:Hide() end end
    G.note = note
    GReset()
    local GF = DB.graphFont or 11
    PAD_T = (DB.graphTitle ~= false) and (GF + 8) or 4      -- room for the title row (and the clock) only when shown
    PAD_B = GF + 5
    local W, H = DB.graphWidth, DB.graphHeight
    graph:SetSize(W, H)
    if not note then graph:Hide(); return end
    -- phase starts: the live ones during a fight, else known + estimated
    local starts, estimated = EstimatePhaseStarts(note)
    if state.active and state.note == note and state.phaseStart then for k, v in pairs(state.phaseStart) do starts[k] = v; estimated[k] = nil end end
    local dur = GraphDuration(note, starts); G.duration = dur
    local plotW = W - PAD_L - PAD_R
    local X = function(t) return PAD_L + math.max(0, math.min(1, t / dur)) * plotW end
    G.X = X
    -- title + axis
    local title = GFS(GF + 1); title:SetPoint("TOPLEFT", graph, "TOPLEFT", PAD_L, -3); Col(title, T.fg)
    if DB.graphTitle == false then title:Hide() end
    title:SetText(string.format("%s %s  ·  %d:%02d%s", note.name or "?", DIFF_NAME[note.difficultyID] or "", math.floor(dur / 60), math.floor(dur % 60), (note.phaseRelative and next(estimated)) and "  (phase starts estimated)" or ""))
    local axisY = PAD_B
    local axis = GTex("ARTWORK"); Tex(axis, T.border2, 0.6); axis:SetSize(plotW, 1); axis:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", PAD_L, axisY)
    for m = 0, math.floor(dur / 60) do
        local t = GTex("ARTWORK"); Tex(t, T.border, 0.3); t:SetSize(1, H - PAD_T - axisY); t:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", X(m * 60), axisY)
        local l = GFS(GF - 1); l:SetPoint("TOPLEFT", graph, "BOTTOMLEFT", X(m * 60) + 2, axisY - 1); l:SetText(m .. "m")
    end
    -- phase boundaries
    if note.phaseRelative then
        for p, st in pairs(starts) do
            if p > 1 and st <= dur then
                local t = GTex("ARTWORK", 1); Tex(t, T.blue, estimated[p] and 0.3 or 0.7); t:SetSize(1, H - PAD_T - axisY); t:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", X(st), axisY)
                local l = GFS(GF - 1); l:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", X(st) + 2, H - PAD_T - GF); l:SetText("P" .. p .. (estimated[p] and "?" or "")); Col(l, T.blue)
            end
        end
    end
    -- rows: a boss tick row, then ONE strip of spell icons for me (or one strip per player with /tl graph all);
    -- icons that would overlap are staggered up/down
    local rows, byKey = {}, {}
    if not playerName then playerName = (UnitName("player") or ""):lower() end
    if not note.phaseRelative then LK.Link(note.entries) end
    for _, e in ipairs(note.entries) do
        local key
        e.gt = GraphTime(note, e, starts)
        if e.gt == nil then key = nil
        elseif e.isBoss then key = (DB.graphBoss ~= false) and "boss" or nil
        elseif DB.graphAll or (e.tag or ""):lower() == playerName then key = DB.graphAll and ("p/" .. (e.tag or "")) or "me" end
        if key then
            local r = byKey[key]
            if not r then r = { key = key, isBoss = e.isBoss, tag = e.tag, color = e.classRGB, items = {} }; byKey[key] = r; rows[#rows + 1] = r end
            r.items[#r.items + 1] = e
        end
    end
    table.sort(rows, function(a, b) if a.isBoss ~= b.isBoss then return a.isBoss end return (a.tag or "") < (b.tag or "") end)
    local ICON, LEVELS = DB.graphIcon or 16, 3      -- icon size, levels
    local STEP = math.max(6, math.floor(ICON * 0.45))   -- vertical stagger per level
    local bossH, stripH = math.max(10, math.floor(GF * 0.9)), ICON + STEP * (LEVELS - 1) + 2
    local rowsH = 0
    for _, r in ipairs(rows) do if r.isBoss then rowsH = rowsH + bossH + 3 end end   -- cooldown strips sit inside the plot, on the axis
    local plotH = math.max(24, H - PAD_T - axisY - 6 - rowsH)
    local plotTop = axisY + plotH
    -- curves (damage topaz, healing emerald) on the plot area
    local maxV = 0
    for id, c in pairs(note.curves or {}) do for _, v in ipairs(c.data) do if v > maxV then maxV = v end end end
    G.colStep = nil
    if maxV > 0 then
        -- squared paper: time runs across in columns (whole curve steps, >= ~6 px), blocks of a fixed size stack up from the axis
        local any = note.curves.dmg or select(2, next(note.curves))
        local bucketW = plotW * any.step / dur
        local k = math.max(1, math.ceil(6 / bucketW))
        local colW = bucketW * k
        local cellH = math.max(4, math.floor(colW + 0.5))
        local nCells = math.max(3, math.floor((plotH - 2) / cellH))
        local unit = LK.Nice(maxV / nCells)
        G.colStep = any.step * k
        -- columns under one of my major cooldowns: those blocks are drawn striped blue instead of orange
        local covCol = {}
        for _, r in ipairs(rows) do
            if not r.isBoss then
                for _, e in ipairs(r.items) do
                    if e.major and e.gt then
                        local fx = math.max(LK.effect[e.spellID or 0] or 0, 3)
                        for ci = math.floor(e.gt / G.colStep), math.floor((e.gt + fx - 0.01) / G.colStep) do covCol[ci] = true end
                    end
                end
            end
        end
        for id, c in pairs(note.curves) do
            local isHeal = id == "heal"
            local nb = math.ceil(dur / c.step)
            for i0 = 1, nb, k do
                local sum, cnt = 0, 0
                for i = i0, math.min(nb, i0 + k - 1) do sum = sum + (c.data[i] or 0); cnt = cnt + 1 end
                local blocks = math.min(nCells, math.floor((cnt > 0 and sum / cnt or 0) / unit + 0.5))
                if blocks > 0 then
                    local w = isHeal and colW / 2 or colW
                    local x0 = X((i0 - 1) * c.step) + (isHeal and colW / 2 or 0)
                    local cov = (not isHeal) and covCol[math.floor((i0 - 1) * c.step / G.colStep)]
                    local col = isHeal and LK.CB.green or (cov and LK.CB.sky or LK.CB.orange)
                    -- with the panel on, one bar split by the grid's gutters; with it off, separate floating blocks
                    local pieces = DB.graphBg and 1 or blocks
                    local ph = DB.graphBg and blocks * cellH or cellH - 1
                    for b = 0, pieces - 1 do
                        local t = GTex("ARTWORK", isHeal and 1 or 0); Tex(t, col, DB.graphBg and 0.75 or 0.85)
                        t:SetSize(math.max(1, DB.graphBg and w or w - 1), ph)
                        t:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", x0, axisY + 1 + b * cellH)
                        if cov then
                            local h = GTex("ARTWORK", 1); LK.Pattern(h, isHeal and "dots" or "hatch", LK.CB.ink, 0.6)
                            h:SetSize(math.max(1, DB.graphBg and w or w - 1), ph); h:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", x0, axisY + 1 + b * cellH)
                        end
                    end
                end
            end
        end
        -- the grid: dark gutters split the bars into blocks, a faint line on top draws the paper (only with the panel on)
        for r = 0, DB.graphBg and nCells or -1 do
            local yy = axisY + 1 + r * cellH
            local gut = GTex("ARTWORK", 2); Tex(gut, T.shadow, 0.9); gut:SetSize(plotW, 1); gut:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", PAD_L, yy)
            local gl = GTex("ARTWORK", 3); Tex(gl, T.border, r % 5 == 0 and 0.28 or 0.13); gl:SetSize(plotW, 1); gl:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", PAD_L, yy)
        end
        for t = 0, DB.graphBg and dur or -1, G.colStep do
            local xx = X(t)
            local gut = GTex("ARTWORK", 2); Tex(gut, T.shadow, 0.9); gut:SetSize(1, nCells * cellH); gut:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", xx, axisY + 1)
            local gl = GTex("ARTWORK", 3); Tex(gl, T.border, 0.12); gl:SetSize(1, nCells * cellH); gl:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", xx, axisY + 1)
        end
        local lg = GFS(GF - 1); lg:SetPoint("BOTTOMRIGHT", graph, "BOTTOMRIGHT", -PAD_R, plotTop - GF); lg:SetJustifyH("RIGHT")
        if DB.graphLegend == false then lg:Hide() end
        local units = {}; for id, c in pairs(note.curves) do units[#units + 1] = (id == "heal" and "|cff009e73healing|r" or "|cffe69f00damage|r") end
        lg:SetText(table.concat(units, " / ") .. "  ·  1 block = " .. (any.unit == "count" and tostring(unit) or (LK.FmtK(unit) .. "/s")))
    else
        local lg = GFS(DB.fontSize - 2); lg:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", PAD_L + 4, axisY + 4); lg:SetText("no damage / healing curve in this string - export it from Fight Flow")
    end
    -- boss row above the plot; cooldown strips along the bottom of the plot, over the damage
    local y = plotTop + 4
    local stripY = axisY + 2
    for i = #rows, 1, -1 do
        local r = rows[i]
        local c = r.color or (r.isBoss and KIND_COLOR.boss) or KIND_COLOR.util
        if r.isBoss then
            local line = GTex("BACKGROUND", 1); Tex(line, T.border, 0.18); line:SetSize(plotW, 1); line:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", PAD_L, y + bossH * 0.5)
            for _, e in ipairs(r.items) do
                local m = GTex("ARTWORK", 3)
                if LK.assignedTo[e] or (not note.phaseRelative and #LK.ActiveAt(note.entries, LK.HitTime(e)) > 0) then Tex(m, LK.CB.sky, 1); m:SetSize(3, bossH + 3)
                else
                    Tex(m, LK.CB.vermillion, 1); m:SetSize(1, bossH)
                    if e.major then   -- an uncovered big hit gets a hollow box on top, not just a colour
                        local bx = GTex("ARTWORK", 3); Tex(bx, LK.CB.vermillion, 1); bx:SetSize(7, 7); bx:SetPoint("BOTTOM", graph, "BOTTOMLEFT", X(e.gt), y + bossH)
                        local hl = GTex("ARTWORK", 4); Tex(hl, T.shadow, 1); hl:SetSize(3, 3); hl:SetPoint("CENTER", bx, "CENTER", 0, 0)
                    end
                end
                m:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", X(e.gt) - 1, y); e.gx = X(e.gt); e.gy = y + bossH * 0.5
            end
            y = y + bossH + 3
        else
            local y = stripY
            table.sort(r.items, function(a, b) return a.gt < b.gt end)
            local lastRight = {}
            for _, e in ipairs(r.items) do
                local sz = e.major and ICON or math.max(8, math.floor(ICON * 0.7))
                local x = X(e.gt) - sz * 0.5
                local lvl = 0
                for k = 0, LEVELS - 1 do if (lastRight[k] or -1e9) <= x - 1 then lvl = k break end lvl = k end
                if (lastRight[lvl] or -1e9) > x - 1 then
                    -- every level taken: use the one that frees up first
                    for k = 0, LEVELS - 1 do if (lastRight[k] or -1e9) < (lastRight[lvl] or -1e9) then lvl = k end end
                end
                lastRight[lvl] = x + sz
                local ic = GTex("ARTWORK", 3)
                local tex = e.texture or (e.spellID and SpellTexture(e.spellID)) or (e.isNote and NOTE_TEXTURE)
                if tex then ic:SetTexture(tex); ic:SetTexCoord(0.08, 0.92, 0.08, 0.92) else ic:SetColorTexture(c[1], c[2], c[3], 0.9) end
                ic:SetSize(sz, sz); ic:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", x, y + lvl * STEP)
                local bd = GTex("ARTWORK", 2); Tex(bd, c, 1); bd:SetSize(sz + 2, sz + 2); bd:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", x - 1, y + lvl * STEP - 1)
                e.gx = X(e.gt); e.glvl = lvl; e.gy = y + lvl * STEP + sz * 0.5
                -- its impact: a transparent green column from the axis up to the boss row, as wide as the effect lasts
                local fx = math.max(LK.effect[e.spellID or 0] or 0, e.major and 3 or 1.5)
                local band = GTex("ARTWORK", 1); Tex(band, LK.CB.sky, (not DB.graphBg) and 0 or (e.major and 0.12 or 0.04))
                local cs = G.colStep
                local bx0 = cs and X(math.floor(e.gt / cs) * cs) or X(e.gt)
                local bx1 = cs and X(math.ceil((e.gt + fx) / cs) * cs) or X(e.gt + fx)
                band:SetSize(math.max(2, bx1 - bx0), math.max(1, H - PAD_T - axisY - 1))
                band:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", bx0, axisY + 1)
            end
            if DB.graphAll then
                local l = GFS(GF - 2); l:SetPoint("BOTTOMRIGHT", graph, "BOTTOMLEFT", PAD_L - 2, y + 2); l:SetJustifyH("RIGHT"); l:SetText((r.tag or "")); l:SetTextColor(c[1], c[2], c[3])
            end
            stripY = stripY + stripH + 2
        end
    end
    G.rows = rows
    if false then   -- cooldowns now sit under their hit with a green column; no diagonal lines needed
        G.linePool = G.linePool or {}
        for _, r in ipairs(rows) do
            if not r.isBoss then
                for _, e in ipairs(r.items) do
                    local b = LK.linkOf[e]
                    if b and b.gx and b.gy and e.gx and e.gy then
                        G.lineUsed = (G.lineUsed or 0) + 1
                        local l = G.linePool[G.lineUsed]
                        if not l then l = graph:CreateLine(nil, "ARTWORK", nil, 2); G.linePool[G.lineUsed] = l end
                        local lc = e.classRGB or T.gold
                        l:SetColorTexture(lc[1], lc[2], lc[3], 0.75); l:SetThickness(1)
                        l:SetStartPoint("BOTTOMLEFT", graph, e.gx, e.gy); l:SetEndPoint("BOTTOMLEFT", graph, b.gx, b.gy)
                        l:Show()
                    end
                end
            end
        end
    end
    -- the now line and the spark (kept at the end of the pool so they draw on top)
    G.now = GTex("OVERLAY", 2); Tex(G.now, T.fg, 0.8); G.now:SetSize(1, H - PAD_T - axisY); G.now:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", X(0), axisY); G.now:Hide()
    G.spark = GTex("OVERLAY", 3); G.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark"); G.spark:SetBlendMode("ADD"); G.spark:SetSize(20, 30); G.spark:SetPoint("CENTER", graph, "BOTTOMLEFT", X(0), axisY); G.spark:Hide()
    G.fuse = GTex("ARTWORK", 4); Tex(G.fuse, T.gold, 0.85); G.fuse:SetSize(1, 2); G.fuse:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", X(0), axisY); G.fuse:Hide()
    G.clock = GFS((DB.graphFont or 11) + 2); G.clock:SetPoint("TOPRIGHT", graph, "TOPRIGHT", -PAD_R, -3); G.clock:SetJustifyH("RIGHT"); G.clock:SetText(""); Col(G.clock, T.gold)
    graph:Show()
end
ns.GraphSetNote = GraphSetNote
ns._G = G

------------------------------------------------------------------------
-- Vertical fight graph (the default): the fight as one column, time running DOWN like /tl plan and the pull sheets.
-- Left: damage in squared blocks. Middle: the big boss hits, named, with the cooldowns that cover them.
-- Right: one column per cooldown of mine: its window (pale), its effect (solid), its cooldown rail, the icon at the ideal time.
-- During a fight the paper scrolls up under a fixed "now" line; out of a fight the mouse wheel scrolls it (unlocked).
------------------------------------------------------------------------
local VG = { tex = {}, texN = 0, fs = {}, fsN = 0, hdr = {}, hdrN = 0, off = 0, manual = 0 }
VG.clip = CreateFrame("Frame", nil, graph); VG.clip:SetClipsChildren(true)
VG.c = CreateFrame("Frame", nil, VG.clip); VG.c:SetSize(10, 10)
function VG.T(layer, sub, parent)
    local pool, n = parent and VG.hdr or VG.tex, nil
    if parent then VG.hdrN = VG.hdrN + 1; n = VG.hdrN else VG.texN = VG.texN + 1; n = VG.texN end
    local t = pool[n]
    if not t then t = (parent or VG.c):CreateTexture(nil, layer or "ARTWORK", nil, sub or 0); pool[n] = t end
    t:SetDrawLayer(layer or "ARTWORK", sub or 0)
    t:ClearAllPoints(); t:SetTexture(nil); t:SetAlpha(1); t:SetTexCoord(0, 1, 0, 1); t:SetHorizTile(false); t:SetVertTile(false); t:SetVertexColor(1, 1, 1, 1); t:Show()
    return t
end
function VG.F(size)
    VG.fsN = VG.fsN + 1
    local f = VG.fs[VG.fsN]
    if not f then f = VG.c:CreateFontString(nil, "OVERLAY"); VG.fs[VG.fsN] = f end
    ApplyFont(f, size, (not DB.graphBg) and "OUTLINE" or nil)
    f:ClearAllPoints(); Col(f, T.muted); f:SetJustifyH("LEFT"); f:SetWordWrap(false); f:Show()
    return f
end
-- hover areas for tooltips (boss hits and my cooldown icons); they pass clicks and the wheel through to the graph
VG.hits, VG.hitN = {}, 0
function VG.Hit(w, h, x, y, data)
    VG.hitN = VG.hitN + 1
    local f = VG.hits[VG.hitN]
    if not f then
        f = CreateFrame("Frame", nil, VG.c)
        f:EnableMouse(true)
        pcall(f.SetPropagateMouseClicks, f, true)
        pcall(f.SetPropagateMouseMotion, f, true)
        f:SetScript("OnEnter", function(self) VG.Tip(self) end)
        f:SetScript("OnLeave", function() GameTooltip:Hide() end)
        VG.hits[VG.hitN] = f
    end
    f:ClearAllPoints(); f:SetSize(math.max(4, w), math.max(4, h)); f:SetPoint("TOPLEFT", VG.c, "TOPLEFT", x, y)
    f.data = data; f:Show()
    return f
end
function VG.Clock(t) t = math.floor((t or 0) + 0.5); return string.format("%d:%02d", math.floor(t / 60), t % 60) end
function VG.Tip(self)
    local d = self.data
    if not d or DB.graphTips == false then return end
    -- the paper scrolls under a clip: ignore the parts that are scrolled out of sight
    local top, bot, y = VG.clip:GetTop(), VG.clip:GetBottom(), select(2, GetCursorPosition()) / UIParent:GetEffectiveScale()
    if top and bot and (y > top or y < bot) then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    local ok = d.spellID and d.spellID > 0 and pcall(GameTooltip.SetSpellByID, GameTooltip, d.spellID)
    if ok then GameTooltip:AddLine(" ") elseif d.kind ~= "boss" then GameTooltip:SetText(d.title or "?", 1, 1, 1) end
    if d.kind == "boss" then
        local ev = d.ev
        local times = {}
        for _, e in ipairs(ev.rows) do times[#times + 1] = VG.Clock(LK.HitTime(e) or e.gt) end
        GameTooltip:AddDoubleLine(d.title, table.concat(times, ", "), 1, 0.82, 0, 1, 1, 1)
        if d.dmg then GameTooltip:AddDoubleLine("Raid damage then", LK.FmtK(d.dmg) .. "/s", 0.8, 0.8, 0.8, 1, 1, 1) end
        if #d.cover > 0 then
            for _, c in ipairs(d.cover) do
                local w = c.win and string.format("  (window %s-%s)", VG.Clock(c.gt + c.win[1]), VG.Clock(c.gt + c.win[2])) or ""
                GameTooltip:AddDoubleLine((LK.short[c.spellID or 0] or SpellName(c.spellID) or "CD") .. w, VG.Clock(c.gt), 0.34, 0.71, 0.91, 1, 1, 1)
            end
        else
            GameTooltip:AddLine("No cooldown planned for this hit", 0.84, 0.37, 0)
        end
    else
        local e = d.e
        GameTooltip:AddDoubleLine("Planned", VG.Clock(e.gt), 0.8, 0.8, 0.8, 1, 1, 1)
        if e.win then GameTooltip:AddDoubleLine("Window", VG.Clock(e.gt + e.win[1]) .. " - " .. VG.Clock(e.gt + e.win[2]), 0.8, 0.8, 0.8, 1, 1, 1) end
        if e.label and e.label ~= "" then GameTooltip:AddLine(e.label, 1, 0.82, 0, true) end
        local b = LK.linkOf[e]
        if b then GameTooltip:AddDoubleLine("For", LK.HitName(b) .. "  " .. VG.Clock(LK.HitTime(b) or b.gt), 0.8, 0.8, 0.8, 1, 1, 1) end
    end
    GameTooltip:Show()
end
function VG.Reset()
    for i = 1, VG.hitN do VG.hits[i]:Hide() end
    VG.hitN = 0
    for i = 1, VG.texN do VG.tex[i]:Hide() end
    for i = 1, VG.fsN do VG.fs[i]:Hide() end
    for i = 1, VG.hdrN do VG.hdr[i]:Hide() end
    VG.texN, VG.fsN, VG.hdrN = 0, 0, 0
    if VG.hfs then for _, f in ipairs(VG.hfs) do f:Hide() end end
end
VG.hfs = {}
function VG.HF(i, size)
    local f = VG.hfs[i]
    if not f then f = graph:CreateFontString(nil, "OVERLAY"); VG.hfs[i] = f end
    ApplyFont(f, size, (not DB.graphBg) and "OUTLINE" or nil); f:ClearAllPoints(); f:SetJustifyH("LEFT"); f:SetWordWrap(false); f:Show()
    return f
end
-- which column each of my cooldowns goes in: the order they first appear in the plan, majors first
-- personal defensives never "cover" a raid hit
function VG.Personal(id)
    if not VG.pers then
        VG.pers = { [370537] = true }
        for _, groups in pairs(LK.CLASS_SPELLS) do for _, g in ipairs(groups) do if g[1] == "Defensives" then for _, x in ipairs(g[2]) do VG.pers[x] = true end end end end
    end
    return VG.pers[id or 0]
end
function VG.Has(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end
function VG.Columns(mine)
    local cols, seen = {}, {}
    for pass = 1, 2 do
        for _, e in ipairs(mine) do
            local id = e.spellID or 0
            local key = (id == 370564) and 370537 or id          -- a Stasis release shares the Stasis column
            if not seen[key] and ((pass == 1) == (e.major and true or false)) then seen[key] = true; cols[#cols + 1] = key end
        end
    end
    local idx = {}; for i, k in ipairs(cols) do idx[k] = i end
    return cols, idx
end
function VG.Set(note)
    G.note = note
    GReset(); VG.Reset()
    graph.vertical = true
    VG.clip:Show()
    local GF = DB.graphFont or 11
    local W, H = DB.vgWidth or 420, DB.vgHeight or 460
    graph:SetSize(W, H)
    if not note then graph:Hide(); return end
    local starts, estimated = EstimatePhaseStarts(note)
    if state.active and state.note == note and state.phaseStart then for k, v in pairs(state.phaseStart) do starts[k] = v; estimated[k] = nil end end
    local dur = GraphDuration(note, starts); G.duration = dur
    if not playerName then playerName = (UnitName("player") or ""):lower() end
    if not note.phaseRelative then LK.Link(note.entries) end
    local mine, boss = {}, {}
    for _, e in ipairs(note.entries) do
        e.gt = GraphTime(note, e, starts)
        if e.gt then
            if e.isBoss then boss[#boss + 1] = e
            elseif DB.graphAll or (e.tag or ""):lower() == playerName then mine[#mine + 1] = e end
        end
    end
    table.sort(mine, function(a, b) return a.gt < b.gt end)
    local cols, colIdx = VG.Columns(mine)
    -- geometry: header (title + column icons), then the scrolling paper
    local ICON = DB.graphIcon or 16
    local titleH = (DB.graphTitle ~= false) and (GF + 6) or 0
    local headH = ICON + 6
    local top = titleH + headH + 2
    local plotH = H - top - 4
    local span = math.max(30, DB.vgSpan or 150)
    local cell = math.max(4, math.floor(plotH / (span / 5)))
    local stepS = 5
    VG.cell, VG.stepS, VG.plotH, VG.dur = cell, stepS, plotH, dur
    local TL = 28                                      -- time labels
    local DC = math.max(4, math.min(DB.vgBlocks or 14, math.floor(W * 0.3 / cell)))   -- damage blocks across (about a third of the width)
    local DW = DC * cell
    local colW, colGap = ICON + 2, 3
    local CW = #cols * (colW + colGap)
    local LX = TL + DW + 6                             -- boss labels start
    local LW = W - LX - CW - 8
    local CX0 = W - CW - 4
    VG.clip:ClearAllPoints(); VG.clip:SetPoint("TOPLEFT", graph, "TOPLEFT", 0, -top); VG.clip:SetSize(W, plotH)
    local rowsN = math.ceil(dur / stepS) + 1
    VG.c:SetSize(W, rowsN * cell + plotH)
    local Y = function(t) return -(t / stepS) * cell end
    -- title
    if titleH > 0 then
        local tf = VG.HF(1, GF + 1); tf:SetPoint("TOPLEFT", graph, "TOPLEFT", 6, -3); Col(tf, T.fg)
        tf:SetText(string.format("%s %s", note.name or "?", DIFF_NAME[note.difficultyID] or ""))
    end
    G.clock = VG.HF(2, GF + 2); G.clock:SetPoint("TOPRIGHT", graph, "TOPRIGHT", -6, -3); G.clock:SetJustifyH("RIGHT"); G.clock:SetText(""); Col(G.clock, T.gold)
    if titleH == 0 then G.clock:Hide() end
    -- header: a column head per cooldown (icon + short name); damage and boss heads
    local hf = VG.HF(3, GF - 2); hf:SetPoint("BOTTOMLEFT", graph, "TOPLEFT", TL, -top + 2); hf:SetText("DAMAGE"); Col(hf, T.muted); VG.dmgHead = hf
    local hb = VG.HF(4, GF - 2); hb:SetPoint("BOTTOMLEFT", graph, "TOPLEFT", LX, -top + 2); hb:SetText("BOSS"); Col(hb, T.muted)
    for i, id in ipairs(cols) do
        local x = CX0 + (i - 1) * (colW + colGap)
        local ic = VG.T("ARTWORK", 3, graph); local tex = SpellTexture(id)
        if tex then ic:SetTexture(tex); ic:SetTexCoord(0.08, 0.92, 0.08, 0.92) else Tex(ic, T.border2, 1) end
        ic:SetSize(ICON, ICON); ic:SetPoint("TOPLEFT", graph, "TOPLEFT", x + 1, -(titleH + 2))
    end
    -- the paper: minute lines everywhere, squares only under the damage
    local maxV, c = 0, note.curves and (note.curves.dmg or select(2, next(note.curves or {})))
    if c then for _, v in ipairs(c.data) do if v > maxV then maxV = v end end end
    local unit = maxV > 0 and LK.Nice(maxV / DC) or 1
    VG.unit = unit
    for r = 0, rowsN do
        local y = Y(r * stepS); local minute = (r * stepS) % 60 == 0
        if DB.graphBg or minute then
            local g = VG.T("BACKGROUND", 1); Tex(g, T.border, minute and 0.35 or 0.12)
            if minute then g:SetSize(W - TL - 4, 1); g:SetPoint("TOPLEFT", VG.c, "TOPLEFT", TL, y)
            else g:SetSize(DW, 1); g:SetPoint("TOPLEFT", VG.c, "TOPLEFT", TL, y) end
        end
        if minute then
            local l = VG.F(GF - 2); l:SetPoint("RIGHT", VG.c, "TOPLEFT", TL - 3, y); l:SetJustifyH("RIGHT")
            l:SetText(string.format("%d:%02d", math.floor(r * stepS / 60), (r * stepS) % 60)); Col(l, T.muted)
        end
    end
    if DB.graphBg then
        for k = 0, DC do
            local g = VG.T("BACKGROUND", 1); Tex(g, T.border, k % 5 == 0 and 0.25 or 0.1); g:SetSize(1, rowsN * cell); g:SetPoint("TOPLEFT", VG.c, "TOPLEFT", TL + k * cell, 0)
        end
    end
    -- what my cooldowns cover: the rows under an effect or a heal window get hatched
    local covered = {}
    for _, e in ipairs(mine) do
        if not VG.Personal(e.spellID) then
            local fx = math.max(LK.effect[e.spellID or 0] or 0, 3)
            for k = math.floor(e.gt / stepS), math.floor((e.gt + fx - 0.01) / stepS) do covered[k] = true end
        end
    end
    if c and maxV > 0 then
        local per = math.max(1, math.floor(stepS / c.step + 0.5))
        for r = 0, rowsN - 1 do
            local sum, n = 0, 0
            for i = r * per + 1, (r + 1) * per do if c.data[i] then sum = sum + c.data[i]; n = n + 1 end end
            local blocks = n > 0 and math.min(DC, math.floor(sum / n / unit + 0.5)) or 0
            if blocks > 0 then
                local pieces = DB.graphBg and 1 or blocks
                for b = 0, pieces - 1 do
                    local t = VG.T("ARTWORK", 0); Tex(t, LK.CB.orange, DB.graphBg and 0.8 or 0.85)
                    local w = DB.graphBg and blocks * cell - 1 or cell - 1
                    t:SetSize(w, cell - 1); t:SetPoint("TOPLEFT", VG.c, "TOPLEFT", TL + 1 + b * cell, Y(r * stepS) - 1)
                    if covered[r] then
                        local h = VG.T("ARTWORK", 1); LK.Pattern(h, "hatch", LK.CB.ink, 0.6); h:SetSize(w, cell - 1); h:SetPoint("TOPLEFT", t, "TOPLEFT", 0, 0)
                    end
                end
            end
        end
        if DB.graphLegend ~= false then VG.dmgHead:SetText("DAMAGE  " .. (c.unit == "count" and tostring(unit) or (LK.FmtK(unit) .. "/s")) .. " a block") end
    end
    -- my cooldowns by the hit they're linked to (for the boss labels)
    local whoOf = {}
    for _, e in ipairs(mine) do
        local b = (not VG.Personal(e.spellID)) and LK.linkOf[e]
        if b then whoOf[b] = whoOf[b] or {}; local s = LK.short[e.spellID or 0] or "CD"; if not VG.Has(whoOf[b], s) then table.insert(whoOf[b], s) end end
    end
    -- Stasis: one window from the store to the release, and a line saying what it's for and how hard it hits
    local function avgDmg(t0, t1)
        if not c then return nil end
        local sum, n = 0, 0
        for i = math.floor(math.max(0, t0) / c.step) + 1, math.floor(math.max(t0, t1 - 0.01) / c.step) + 1 do if c.data[i] then sum = sum + c.data[i]; n = n + 1 end end
        return n > 0 and sum / n or nil
    end
    VG.stasis = {}
    for i, e in ipairs(mine) do
        if e.spellID == 370537 then
            for j = i + 1, #mine do
                local r = mine[j]
                if r.spellID == 370564 and r.tag == e.tag then
                    local hit = LK.linkOf[r]
                    VG.stasis[#VG.stasis + 1] = { store = e, rel = r, t0 = e.gt, t1 = r.gt, target = hit and LK.HitName(hit) or (r.label or ""):match(">%s*(.-)%s*$") or "?",
                        ramp = avgDmg(e.gt, r.gt), burst = avgDmg(r.gt, r.gt + 5) }
                    break
                elseif r.spellID == 370537 then break end
            end
        end
    end
    local sci = colIdx[370537]
    for _, w in ipairs(VG.stasis) do
        if sci then
            local x = CX0 + (sci - 1) * (colW + colGap)
            local bar = VG.T("BACKGROUND", 6); LK.Pattern(bar, "dots", LK.CB.purple, 0.7)
            bar:SetSize(colW - 4, math.max(3, (w.t1 - w.t0) / stepS * cell)); bar:SetPoint("TOPLEFT", VG.c, "TOPLEFT", x + 2, Y(w.t0))
            local edge = VG.T("BACKGROUND", 7); Tex(edge, LK.CB.purple, 0.8); edge:SetSize(1, math.max(3, (w.t1 - w.t0) / stepS * cell)); edge:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
        end
    end
    -- boss hits: majors grouped when the same name repeats within 10 s
    if DB.graphBoss ~= false then
        table.sort(boss, function(a, b) return a.gt < b.gt end)
        local evs = {}
        for _, e in ipairs(boss) do
            if e.major then
                local n = LK.HitName(e); local t = LK.HitTime(e) or e.gt
                local last = evs[#evs]
                if last and last.name == n and t - last.t1 <= 10 then last.t1 = t; last.n = last.n + 1; last.rows[#last.rows + 1] = e
                else evs[#evs + 1] = { name = n, t0 = t, t1 = t, n = 1, rows = { e } } end
            end
        end
        for _, w in ipairs(VG.stasis) do evs[#evs + 1] = { stasis = w, t0 = w.t0 } end
        table.sort(evs, function(a, b) return a.t0 < b.t0 end)
        local nextY = 1
        for _, ev in ipairs(evs) do
          if ev.stasis then
            local w = ev.stasis
            local y = Y(w.t0)
            local ly = math.min(y, nextY - (GF + 1))
            local l = VG.F(GF - 2); l:SetPoint("LEFT", VG.c, "TOPLEFT", LX + 10, ly); l:SetWidth(LW - 10); Col(l, LK.CB.purple)
            l:SetText("Stasis window > " .. w.target)
            local l2 = VG.F(GF - 2); l2:SetPoint("LEFT", VG.c, "TOPLEFT", LX + 10, ly - (GF - 1)); l2:SetWidth(LW - 10); Col(l2, LK.CB.purple)
            l2:SetText(string.format("ramp %s/s, release %s/s", w.ramp and LK.FmtK(w.ramp) or "?", w.burst and LK.FmtK(w.burst) or "?"))
            nextY = ly - (GF - 1)
          else
            local who = {}
            for _, e in ipairs(ev.rows) do for _, s in ipairs(whoOf[e] or {}) do if not VG.Has(who, s) then who[#who + 1] = s end end end
            for _, e in ipairs(mine) do   -- a cooldown whose heal window (or effect) takes in this hit covers it too
                if e.win and not VG.Personal(e.spellID) then
                    local fx = LK.effect[e.spellID or 0] or 0
                    if ev.t0 >= e.gt + e.win[1] - 0.5 and ev.t0 <= e.gt + e.win[2] + fx + 0.5 then
                        local s = LK.short[e.spellID or 0] or "CD"; if not VG.Has(who, s) then who[#who + 1] = s end
                    end
                end
            end
            if #who == 0 and not note.phaseRelative and #LK.ActiveAt(note.entries, ev.t0) > 0 then who[1] = "up" end
            local cov = #who > 0
            do  -- the tooltip's list: my casts linked to this hit, or whose window takes it in
                local cover, seen = {}, {}
                for _, e in ipairs(mine) do
                    if not VG.Personal(e.spellID) and not seen[e] then
                        local linked = false
                        for _, r in ipairs(ev.rows) do if LK.linkOf[e] == r then linked = true end end
                        local fx = LK.effect[e.spellID or 0] or 0
                        local inWin = e.win and ev.t0 >= e.gt + e.win[1] - 0.5 and ev.t0 <= e.gt + e.win[2] + fx + 0.5
                        if linked or inWin then cover[#cover + 1] = e; seen[e] = true end
                    end
                end
                local dmgNow
                if c then local sum, n = 0, 0; for i = math.floor(ev.t0 / c.step) + 1, math.floor((ev.t0 + 5) / c.step) + 1 do if c.data[i] then sum = sum + c.data[i]; n = n + 1 end end; dmgNow = n > 0 and sum / n or nil end
                VG.Hit(LX - TL + LW, cell * 2, TL, Y(math.floor(ev.t0 / stepS) * stepS),
                    { kind = "boss", ev = ev, title = ev.name .. (ev.n > 1 and (" x" .. ev.n) or ""), spellID = ev.rows[1].spellID, cover = cover, dmg = dmgNow })
            end
            local y = Y(ev.t0)
            local band = VG.T("BACKGROUND", 2); Tex(band, cov and LK.CB.sky or LK.CB.vermillion, DB.graphBg and 0.12 or 0.18)
            band:SetSize(LX - TL + LW, cell * 2); band:SetPoint("TOPLEFT", VG.c, "TOPLEFT", TL, Y(math.floor(ev.t0 / stepS) * stepS))
            if not cov then local h = VG.T("BACKGROUND", 3); LK.Pattern(h, "hatch", LK.CB.vermillion, 0.3); h:SetSize(LX - TL + LW, cell * 2); h:SetPoint("TOPLEFT", band, "TOPLEFT", 0, 0) end
            local m = VG.T("ARTWORK", 3); Tex(m, cov and LK.CB.sky or LK.CB.vermillion, 1); m:SetSize(7, 7); m:SetPoint("CENTER", VG.c, "TOPLEFT", LX + 3, y)
            if not cov then local hole = VG.T("ARTWORK", 4); Tex(hole, T.shadow, 1); hole:SetSize(3, 3); hole:SetPoint("CENTER", m, "CENTER", 0, 0) end
            local ly = math.min(y, nextY - (GF + 1))
            if y - ly <= 2 * GF + 6 then
                local l = VG.F(GF - 1); l:SetPoint("LEFT", VG.c, "TOPLEFT", LX + 10, ly); l:SetWidth(LW - 10)
                local nm = ev.name .. (ev.n > 1 and (" x" .. ev.n) or "")
                l:SetText(nm .. "  " .. (cov and ("|cff9fb4c8" .. table.concat(who, "+") .. "|r") or "|cffd55e00no CD|r"))
                Col(l, cov and T.fg or LK.CB.vermillion)
                nextY = ly
            end
          end
        end
    end
    -- my cooldown columns
    for _, e in ipairs(mine) do
        local id = e.spellID or 0
        local ci = colIdx[(id == 370564) and 370537 or id]
        if ci then
            local x = CX0 + (ci - 1) * (colW + colGap)
            local cc = e.classRGB or T.gold
            local cdl = LK.CDLEN[id] or e.cd or 0
            if cdl > 0 then
                local rail = VG.T("BACKGROUND", 4); Tex(rail, cc, 0.3)
                rail:SetSize(2, math.max(1, (math.min(dur, e.gt + cdl) - e.gt) / stepS * cell)); rail:SetPoint("TOP", VG.c, "TOPLEFT", x + colW / 2, Y(e.gt))
            end
            if e.win then
                local w0, w1 = e.gt + e.win[1], e.gt + e.win[2]
                local wb = VG.T("BACKGROUND", 5); Tex(wb, LK.CB.sky, 0.28)
                wb:SetSize(colW, math.max(3, (w1 - w0) / stepS * cell)); wb:SetPoint("TOPLEFT", VG.c, "TOPLEFT", x, Y(math.max(0, w0)))
            end
            local fx = LK.effect[id] or 0
            if fx > 0 then
                local fb = VG.T("ARTWORK", 1); Tex(fb, cc, 0.55); fb:SetSize(colW - 6, fx / stepS * cell); fb:SetPoint("TOPLEFT", VG.c, "TOPLEFT", x + 3, Y(e.gt))
            end
            local store = (id == 370537)
            local sz = store and math.floor(ICON * 0.6) or ICON
            local ic = VG.T("ARTWORK", 3)
            local tex = e.texture or SpellTexture(id == 370564 and 370537 or id)
            if tex then ic:SetTexture(tex); ic:SetTexCoord(0.08, 0.92, 0.08, 0.92) else Tex(ic, cc, 0.9) end
            ic:SetSize(sz, sz); ic:SetPoint("CENTER", VG.c, "TOPLEFT", x + colW / 2, Y(e.gt))
            if store then ic:SetDesaturated(true); ic:SetAlpha(0.8) else ic:SetDesaturated(false) end
            local bd = VG.T("ARTWORK", 2); Tex(bd, e.major and cc or T.border2, 1); bd:SetSize(sz + 2, sz + 2); bd:SetPoint("CENTER", ic, "CENTER", 0, 0)
            VG.Hit(sz + 2, sz + 2, x + colW / 2 - (sz + 2) / 2, Y(e.gt) + (sz + 2) / 2, { kind = "cd", e = e, spellID = (id == 370564) and 370537 or id, title = LK.short[id] or "Cooldown" })
        end
    end
    -- the now line (fixed on the frame; the paper moves under it)
    VG.nowTex = VG.nowTex or graph:CreateTexture(nil, "OVERLAY", nil, 6)
    G.now = VG.nowTex
    G.now:ClearAllPoints(); Tex(G.now, T.gold, 0.95); G.now:SetSize(W - 8, 2); G.now:Hide()
    VG.nowFrac = math.max(0.05, math.min(0.8, DB.vgNow or 0.3))
    VG.top = top
    VG.manual = 0
    VG.Scroll(0, false)
    graph:Show()
end
-- put time t at the now line (clamped so the paper never scrolls past its start)
function VG.Scroll(t, live)
    local nowY = VG.plotH * VG.nowFrac
    local ty = (t / VG.stepS) * VG.cell
    local off = live and math.max(0, ty - nowY) or math.max(0, VG.manual)
    VG.off = off
    VG.c:ClearAllPoints(); VG.c:SetPoint("TOPLEFT", VG.clip, "TOPLEFT", 0, off)
    return ty - off
end
function VG.Tick()
    if not G.note or not VG.cell then return end
    if not state.active or state.note ~= G.note then
        G.now:Hide(); if G.clock then G.clock:SetText("") end
        if VG.live then VG.live = false; VG.manual = 0; VG.Scroll(0, false) end
        return
    end
    VG.live = true
    local elapsed = GetTime() - state.startTime
    local y = VG.Scroll(math.max(0, elapsed), true)
    G.now:ClearAllPoints(); G.now:SetPoint("TOPLEFT", graph, "TOPLEFT", 4, -(VG.top + y)); G.now:Show()
    if elapsed < 0 then G.clock:SetText(string.format("pull in %.1f", -elapsed))
    else local s = math.floor(elapsed); G.clock:SetText(string.format("%d:%02d", math.floor(s / 60), s % 60)) end
end
graph:SetScript("OnMouseWheel", function(_, d)
    if not graph.vertical or VG.live or not VG.cell then return end
    local maxOff = math.max(0, (VG.dur / VG.stepS) * VG.cell - VG.plotH * 0.5)
    VG.manual = math.max(0, math.min(maxOff, VG.manual - d * VG.cell * 6))
    VG.Scroll(0, false)
end)
ns.VG = VG

local function GraphTick()
    if graph.vertical then return VG.Tick() end
    if not G.note or not G.X then return end
    if not state.active or state.note ~= G.note then
        G.now:Hide(); G.spark:Hide(); G.fuse:Hide(); G.clock:SetText(""); return
    end
    local elapsed = GetTime() - state.startTime
    local x = G.X(math.max(0, elapsed))
    G.now:ClearAllPoints(); G.now:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", x, PAD_B); G.now:Show()
    G.spark:ClearAllPoints(); G.spark:SetPoint("CENTER", graph, "BOTTOMLEFT", x, PAD_B); G.spark:Show()
    if elapsed < 0 then
        -- pull timer running: the fuse is lit but hasn't moved yet
        G.spark:SetAlpha(0.5 + 0.5 * math.abs(math.sin(GetTime() * 6)))
        G.fuse:Hide()
        G.clock:SetText(string.format("pull in %.1f", -elapsed))
    else
        G.spark:SetAlpha(1)
        G.fuse:SetSize(math.max(1, x - PAD_L), 2); G.fuse:Show()
        local t = math.floor(elapsed)
        G.clock:SetText(string.format("%d:%02d", math.floor(t / 60), t % 60))
    end
end
graph:SetScript("OnUpdate", GraphTick)

local function ApplyGraphLayout()
    graph:ClearAllPoints()
    if DB.graphPoint and not ns.ValidPoint(DB.graphPoint) then DB.graphPoint = nil end
    if DB.graphPoint then
        local p = DB.graphPoint
        graph:SetPoint(p[1], UIParent, p[3], p[4], p[5])
    elseif Minimap then
        graph:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", -12, 0)
    else
        graph:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -220, -20)
    end
    graph:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    graph:SetBackdropColor(T.card[1], T.card[2], T.card[3], (not DB.graphBg) and 0 or (DB.graphAlpha or 0.85))
    if DB.locked then graph:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], DB.graphBg and BORDER_A or 0)
    else graph:SetBackdropBorderColor(T.gold[1], T.gold[2], T.gold[3], 0.8) end   -- unlocked: always outlined, so it can be found and moved
    graph:EnableMouse(not DB.locked)
    graph:EnableMouseWheel(not DB.locked)
    graph:SetMovable(not DB.locked)
    local note = state.note
    if not note and DB.nextUp then note = FindNote(DB.nextUp.encounterID, DB.nextUp.difficultyID) end
    note = note or G.note
    if not note and DB.lastImport then
        local n = DB.notes[DB.lastImport.encounterID]; note = n and n[DB.lastImport.difficultyID]
    end
    if DB.graphOn and not DB.hidden and note then GraphSetNote(note) else G.note = nil; graph:Hide() end
end
ns.ApplyGraphLayout = ApplyGraphLayout

------------------------------------------------------------------------
-- Options window: every command, as controls. Each control just runs the
-- slash command it stands for, so the two can never disagree.
------------------------------------------------------------------------
local optFrame
local function Run(cmd) if ns.Slash then ns.Slash(cmd) end end

local OPTION_PAGES = {
    { "General", {
        { t = "text", text = "The plan bar: boss abilities, your bursts and every healer's cooldowns from a Viserio / NSRT / planner string. Pull timers arm it; ENCOUNTER_START syncs it." },
        { t = "choice", label = "Layout", get = function() return DB.layout end, options = { { "stack", "Stack (inverted T)" }, { "hud", "HUD" }, { "single", "Single" }, { "lanes", "Lanes" } }, cmd = function(v) return "layout " .. v end },
        { t = "toggle", label = "Locked (unlock to drag the bar, the column and the graph)", get = function() return DB.locked end, cmd = function(v) return v and "lock" or "unlock" end },
        { t = "toggle", label = "Hidden", get = function() return DB.hidden end, cmd = function(v) return v and "hide" or "show" end },
        { t = "num", label = "Window (seconds visible above the landing line)", get = function() return DB.lookahead end, min = 5, max = 120, step = 1, cmd = function(v) return "window " .. v end },
        { t = "num", label = "Imminent zone (s) - column layouts", get = function() return DB.imminent end, min = 1, max = 60, step = 1, cmd = function(v) return "imminent " .. v end },
        { t = "toggle", label = "Arm from pull timers (Blizzard countdown / DBM / BigWigs)", get = function() return DB.pullTimer end, cmd = function() return "pulltimer" end },
        { t = "toggle", label = "BigWigs live boss timers", get = function() return DB.bwLive end, cmd = function() return "bw" end },
        { t = "button", label = "Reset settings (keeps notes and tracking lists)", cmd = "reset" },
    } },
    { "Stack", {
        { t = "text", text = "Inverted T: boss left of the stalk, you right of it. Cooldowns parked at the top, each running down its own column; the next assigned cast and a queue under the T." },
        { t = "num", label = "Width", get = function() return DB.stackWidth end, min = 200, max = 800, step = 10, cmd = function(v) return "stacksize " .. v .. " " .. DB.stackHeight end },
        { t = "num", label = "Height", get = function() return DB.stackHeight end, min = 200, max = 900, step = 10, cmd = function(v) return "stacksize " .. DB.stackWidth .. " " .. v end },
        { t = "num", label = "Row icon size", get = function() return DB.rowIcon end, min = 16, max = 64, step = 1, cmd = function(v) return "rowicon " .. v end },
        { t = "num", label = "Next-cast / arriving icon size", get = function() return DB.slotIcon end, min = 16, max = 80, step = 1, cmd = function(v) return "slot " .. v end },
        { t = "num", label = "Boss lane width (left of the stalk)", get = function() return DB.stackBossW end, min = 30, max = 300, step = 5, cmd = function(v) return "bosslane " .. v end },
        { t = "toggle", label = "Constant speed (off = perspective)", get = function() return DB.stackLinear end, cmd = function() return "linear" end },
        { t = "toggle", label = "Show the T", get = function() return DB.crosshair end, cmd = function() return "crosshair" end },
        { t = "toggle", label = "Also show other players' planned casts", get = function() return DB.stackAll end, cmd = function() return "all" end },
        { t = "toggle", label = "Scheduled casts above / below the row", get = function() return DB.mineSched end, cmd = function() return "sched" end },
        { t = "toggle", label = "Blizzard's cooldown number on the icons (off = own text)", get = function() return DB.mineNumbers end, cmd = function() return "numbers" end },
        { t = "toggle", label = "Cooldown sweep on the icons", get = function() return DB.mineSwipe end, cmd = function() return "swipe" end },
        { t = "toggle", label = "Class-colour border on the icons", get = function() return DB.mineBorder end, cmd = function() return "border" end },
        { t = "toggle", label = "Ready spells stay docked", get = function() return DB.mineReady end, cmd = function() return "ready" end },
        { t = "toggle", label = "Column (hud/single/lanes): show in combat only", get = function() return DB.mineCombat end, cmd = function() return "combat" end },
    } },
    { "Tracking", {
        { t = "text", text = "The spells the row follows for your current spec - Major group, then Other. Only spells you know are shown; a talent swap rebuilds the row." },
        { t = "tracked" },
        { t = "input", label = "Add spell ID to Major", cmd = function(v) return "track add " .. v end },
        { t = "input", label = "Add spell ID to Other", cmd = function(v) return "track add " .. v .. " other" end },
        { t = "button", label = "Reset to the defaults for this spec", cmd = "track reset" },
    } },
    { "Plans", {
        { t = "status" },
        { t = "button", label = "Import a string / Viserio export...", cmd = "import" },
        { t = "plans" },
        { t = "text", text = "Selected plan: what Test, the phase starts and Assign act on. Armed: what a pull timer loads (pinned with Arm; otherwise the last boss fought, else the selected plan). The right difficulty is picked on pull; if only another difficulty is stored it's used and chat says so." },
        { t = "input", label = "Test the selected plan from N seconds in", cmd = function(v) return "test " .. (v ~= "" and v or "0") end },
        { t = "button", label = "Stop test", cmd = "stop" },
        { t = "input", label = "Simulate a pull timer (seconds)", cmd = function(v) return "pull " .. (v ~= "" and v or "10") end },
        { t = "input", label = "Bind the selected plan to an encounter ID", cmd = function(v) return "assign " .. v end },
        { t = "button", label = "Unpin (pull timers go back to last fought / selected)", cmd = "use clear" },
    } },
    { "Column", {
        { t = "text", text = "With the HUD, your cooldowns sit in a row on top of it (icon, the hit it's for, when to press it); the HUD's own icons do the falling. In the single / lanes layouts they keep their own column beside the plan bar." },
        { t = "toggle", label = "Show the column", get = function() return DB.mineOn end, cmd = function() return "mine" end },
        { t = "toggle", label = "Instead: put the countdowns on Blizzard's Cooldown Manager icons (red while you should hold, with a cross on the icon)", get = function() return DB.mineCDM end, cmd = function() return "cdm" end },
        { t = "toggle", label = "Unlock the cooldown row (move it on its own; the HUD stays locked)", get = function() return DB.mineLocked == false end, cmd = function() return "minelock" end },
        { t = "button", label = "Put it back in its anchored place", cmd = "minepos reset" },
        { t = "num", label = "Gap to the plan bar", get = function() return DB.mineOffset end, min = 0, max = 100, step = 1, cmd = function(v) return "mineoffset " .. v end },
        { t = "num", label = "Icon size", get = function() return DB.mineIcon end, min = 16, max = 64, step = 1, cmd = function(v) return "minesize " .. v .. " " .. DB.mineHeight end },
        { t = "num", label = "Height (free-standing only)", get = function() return DB.mineHeight end, min = 120, max = 900, step = 10, cmd = function(v) return "minesize " .. DB.mineIcon .. " " .. v end },
        { t = "toggle", label = "Only my cooldowns on the plan bar", get = function() return DB.onlyMine end, cmd = function() return "onlymine" end },
        { t = "text", text = "Columns, left to right - < > moves one, the slider sets its width (auto = just the icon):" },
        { t = "tracked" },
    } },
    { "Looks", {
        { t = "input", label = "Font (bundled | condensed | barlow | dejavu | poppins | LSM name)", get = function() return DB.font end, cmd = function(v) return "font " .. v end },
        { t = "toggle", label = "Outline text instead of a drop shadow", get = function() return DB.fontOutline end, cmd = function() return "outline" end },
        { t = "button", label = "List LibSharedMedia fonts in chat", cmd = "fonts" },
        { t = "num", label = "Font size", get = function() return DB.fontSize end, min = 6, max = 30, step = 1, cmd = function(v) return "fontsize " .. v end },
        { t = "num", label = "Icon size (column layouts)", get = function() return DB.iconSize end, min = 12, max = 80, step = 1, cmd = function(v) return "size " .. v end },
        { t = "num", label = "Major cooldown scale", get = function() return DB.majorScale end, min = 1, max = 2.5, step = 0.05, cmd = function(v) return "major " .. v end },
        { t = "num", label = "Bar height (column layouts)", get = function() return DB.barHeight end, min = 80, max = 1000, step = 10, cmd = function(v) return "height " .. v end },
        { t = "num", label = "Cooldowns column width", get = function() return DB.colWidth end, min = 40, max = 600, step = 4, cmd = function(v) return "cols " .. v end },
        { t = "num", label = "Boss column width", get = function() return DB.bossColWidth end, min = 40, max = 600, step = 4, cmd = function(v) return "bosscols " .. v end },
        { t = "num", label = "Label width beside icons (0 = icons only)", get = function() return DB.labelWidth end, min = 0, max = 200, step = 2, cmd = function(v) return "labels " .. v end },
        { t = "num", label = "Bar background opacity", get = function() return DB.barAlpha end, min = 0, max = 1, step = 0.05, cmd = function(v) return "alpha " .. v end },
        { t = "toggle", label = "Name labels", get = function() return DB.showNames end, cmd = function() return "names" end },
        { t = "toggle", label = "Countdown text", get = function() return DB.showTime end, cmd = function() return "time" end },
        { t = "toggle", label = "Lane headers", get = function() return DB.showHeaders end, cmd = function() return "headers" end },
        { t = "toggle", label = "Time tick lines", get = function() return DB.showTicks end, cmd = function() return "ticks" end },
    } },
    { "Graph", {
        { t = "text", text = "The fight graph beside the minimap: damage in blocks, your cooldowns along the bottom, boss hits along the top." },
        { t = "toggle", label = "Show the fight graph", get = function() return DB.graphOn end, cmd = function() return "graph" end },
        { t = "toggle", label = "Every healer's cooldowns (off = only mine)", get = function() return DB.graphAll end, cmd = function() return "graph all" end },
        { t = "toggle", label = "Vertical: time runs down (off = left to right)", get = function() return DB.graphVertical ~= false end, cmd = function() return "graphvert" end },
        { t = "num", label = "Vertical: seconds visible", get = function() return DB.vgSpan or 150 end, min = 30, max = 600, step = 10, cmd = function(v) return "graphspan " .. v end },
        { t = "num", label = "Vertical: now line from the top", get = function() return DB.vgNow or 0.3 end, min = 0.05, max = 0.8, step = 0.05, cmd = function(v) return "graphnow " .. v end },
        { t = "num", label = "Vertical: width", get = function() return DB.vgWidth or 380 end, min = 240, max = 900, step = 10, cmd = function(v) return "vgsize " .. v .. " " .. (DB.vgHeight or 460) end },
        { t = "num", label = "Vertical: height", get = function() return DB.vgHeight or 460 end, min = 160, max = 1200, step = 10, cmd = function(v) return "vgsize " .. (DB.vgWidth or 380) .. " " .. v end },
        { t = "num", label = "Vertical: damage blocks across", get = function() return DB.vgBlocks or 14 end, min = 4, max = 40, step = 1, cmd = function(v) return "graphblocks " .. v end },
        { t = "toggle", label = "Tooltips on boss hits and cooldown icons", get = function() return DB.graphTips ~= false end, cmd = function() return "graphtips" end },
        { t = "toggle", label = "Background panel", get = function() return DB.graphBg end, cmd = function() return "graphbg" end },
        { t = "num", label = "Background opacity", get = function() return DB.graphAlpha or 0.85 end, min = 0, max = 1, step = 0.05, cmd = function(v) return "graphalpha " .. v end },
        { t = "num", label = "Text size", get = function() return DB.graphFont or 11 end, min = 7, max = 24, step = 1, cmd = function(v) return "graphfont " .. v end },
        { t = "num", label = "Cooldown icon size", get = function() return DB.graphIcon or 16 end, min = 8, max = 40, step = 1, cmd = function(v) return "graphicon " .. v end },
        { t = "num", label = "Width", get = function() return DB.graphWidth end, min = 200, max = 1400, step = 10, cmd = function(v) return "graphsize " .. v .. " " .. DB.graphHeight end },
        { t = "num", label = "Height", get = function() return DB.graphHeight end, min = 80, max = 600, step = 10, cmd = function(v) return "graphsize " .. DB.graphWidth .. " " .. v end },
        { t = "toggle", label = "Title and clock", get = function() return DB.graphTitle ~= false end, cmd = function() return "graphtitle" end },
        { t = "toggle", label = "Boss hits row", get = function() return DB.graphBoss ~= false end, cmd = function() return "graphboss" end },
        { t = "toggle", label = "Legend (block size)", get = function() return DB.graphLegend ~= false end, cmd = function() return "graphlegend" end },
        { t = "button", label = "Put the graph back beside the minimap", cmd = "graphpos reset" },
    } },
    { "HUD", {
        { t = "text", text = "The perspective layout: two tracks converging on a vanishing point, next-up slots at the bottom." },
        { t = "num", label = "Depth (perspective strength)", get = function() return DB.depth end, min = 0.5, max = 8, step = 0.1, cmd = function(v) return "depth " .. v end },
        { t = "num", label = "Far icon size", get = function() return DB.farIcon end, min = 4, max = 40, step = 1, cmd = function(v) return "far " .. v end },
        { t = "num", label = "HUD width", get = function() return DB.hudWidth end, min = 200, max = 900, step = 10, cmd = function(v) return "hudsize " .. v .. " " .. DB.hudHeight end },
        { t = "num", label = "HUD height", get = function() return DB.hudHeight end, min = 150, max = 900, step = 10, cmd = function(v) return "hudsize " .. DB.hudWidth .. " " .. v end },
        { t = "toggle", label = "Guide rails", get = function() return DB.rails end, cmd = function() return "rails" end },
        { t = "toggle", label = "Dark plate behind the slots", get = function() return DB.slotPlate ~= false end, cmd = function() return "plate" end },
    } },
}

local function BuildOptions()
    local f = Panel("CDTimelineOptions", 620, 580)
    tinsert(UISpecialFrames, "CDTimelineOptions")
    f.title:SetText("CD Timeline")
    f.sub:SetText("every control runs the matching /tl command")
    local close = FlatButton(f, "×", 22, 22); close:SetPoint("TOPRIGHT", -8, -8); close:SetScript("OnClick", function() f:Hide() end)
    -- tabs: flat text, gold underline on the active one
    f.tabs = {}
    local x = 12
    for i, page in ipairs(OPTION_PAGES) do
        local b = CreateFrame("Button", nil, f)
        b:SetSize(74, 24); b:SetPoint("TOPLEFT", x, -44)
        b.fs = b:CreateFontString(nil, "OVERLAY"); ApplyFont(b.fs, 13); b.fs:SetPoint("CENTER", 0, 1); b.fs:SetText(page[1]); Col(b.fs, T.muted)
        b.ul = b:CreateTexture(nil, "ARTWORK"); Tex(b.ul, T.gold, 1); b.ul:SetHeight(2); b.ul:SetPoint("BOTTOMLEFT", 6, 0); b.ul:SetPoint("BOTTOMRIGHT", -6, 0); b.ul:Hide()
        b.SetEnabled = function(self, on) self.active = not on; if self.active then self.ul:Show(); Col(self.fs, T.fg) else self.ul:Hide(); Col(self.fs, T.muted) end end
        b:SetScript("OnEnter", function() if not b.active then Col(b.fs, T.goldHi) end end)
        b:SetScript("OnLeave", function() if not b.active then Col(b.fs, T.muted) end end)
        b:SetScript("OnClick", function() ns.ShowOptionsPage(i) end)
        f.tabs[i] = b; x = x + 78
    end
    -- scrolling page
    local sf = FlatScroll(f, "CDTimelineOptionsScroll")
    sf:SetPoint("TOPLEFT", 14, -76); sf:SetPoint("BOTTOMRIGHT", -20, 14)
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(560, 10)
    sf:SetScrollChild(content)
    f.scroll = sf
    f.content = content
    f.widgets = {}
    return f
end

-- lay a page out: one control per row, built from the spec
local function ShowOptionsPage(idx)
    local f = optFrame
    f.page = idx
    local content = f.content
    for _, w in ipairs(f.widgets) do w:Hide() end
    wipe(f.widgets)
    for i, b in ipairs(f.tabs) do if b.SetEnabled then b:SetEnabled(i ~= idx) end end
    local y = -4
    local function row(h) local yy = y; y = y - h; return yy end
    local function label(text, yy, w)
        local l = content:CreateFontString(nil, "OVERLAY"); ApplyFont(l, 12); Col(l, T.fg); l:SetPoint("TOPLEFT", 4, yy); l:SetWidth(w or 540); l:SetJustifyH("LEFT"); l:SetText(text); f.widgets[#f.widgets + 1] = l; return l
    end
    for _, c in ipairs(OPTION_PAGES[idx][2]) do
        if c.t == "text" then
            local l = content:CreateFontString(nil, "OVERLAY"); ApplyFont(l, 11); l:SetPoint("TOPLEFT", 4, row(40) - 2); l:SetWidth(540); l:SetJustifyH("LEFT"); Col(l, T.muted); l:SetText(c.text); f.widgets[#f.widgets + 1] = l
        elseif c.t == "toggle" then
            local yy = row(26)
            local cb = FlatCheck(content)
            cb:SetPoint("TOPLEFT", 4, yy - 4)
            cb:SetChecked(c.get() and true or false)
            cb:SetScript("OnClick", function(self) Run(c.cmd(not c.get())); ns.ShowOptionsPage(idx) end)
            f.widgets[#f.widgets + 1] = cb
            label(c.label, yy - 5, 480):SetPoint("TOPLEFT", 28, yy - 5)
        elseif c.t == "num" then
            local yy = row(44)
            label(string.format("%s  |cffb66eff%s|r", c.label, tostring(c.get())), yy)
            local sl = FlatSlider(content, 300)
            sl:SetPoint("TOPLEFT", 6, yy - 20)
            sl:SetMinMaxValues(c.min, c.max); sl:SetValueStep(c.step); if sl.SetObeyStepOnDrag then sl:SetObeyStepOnDrag(true) end
            sl.loading = true; sl:SetValue(c.get() or c.min); sl.loading = false
            sl:SetScript("OnValueChanged", function(self, v)
                if self.loading then return end
                v = math.floor(v / c.step + 0.5) * c.step
                if math.abs(v - (c.get() or 0)) < c.step * 0.5 then return end
                Run(c.cmd(v))
            end)
            sl:SetScript("OnMouseUp", function() ns.ShowOptionsPage(idx) end)
            f.widgets[#f.widgets + 1] = sl
        elseif c.t == "choice" then
            local yy = row(30)
            label(c.label, yy)
            local x = 120
            for _, o in ipairs(c.options) do
                local b = FlatButton(content, o[2], 100, 22)
                b:SetPoint("TOPLEFT", x, yy + 2)
                if c.get() == o[1] and b.SetEnabled then b:SetEnabled(false) end
                b:SetScript("OnClick", function() Run(c.cmd(o[1])); ns.ShowOptionsPage(idx) end)
                f.widgets[#f.widgets + 1] = b; x = x + 104
            end
        elseif c.t == "button" then
            local yy = row(28)
            local b = FlatButton(content, c.label, 300, 22)
            b:SetPoint("TOPLEFT", 4, yy)
            b:SetScript("OnClick", function() Run(c.cmd); ns.ShowOptionsPage(idx) end)
            f.widgets[#f.widgets + 1] = b
        elseif c.t == "input" then
            local yy = row(30)
            label(c.label, yy, 260)
            local eb = FlatEdit(content, 130, 22)
            eb:SetPoint("TOPLEFT", 270, yy + 2)
            if c.get then eb:SetText(tostring(c.get() or "")) end
            local b = FlatButton(content, "Apply", 60, 22)
            b:SetPoint("LEFT", eb, "RIGHT", 6, 0)
            local function apply() local v = (eb:GetText() or ""):match("^%s*(.-)%s*$"); Run(c.cmd(v)); ns.ShowOptionsPage(idx) end
            b:SetScript("OnClick", apply); eb:SetScript("OnEnterPressed", apply); eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            f.widgets[#f.widgets + 1] = eb; f.widgets[#f.widgets + 1] = b
        elseif c.t == "tracked" then
            for _, e in ipairs(mine.list) do
                local yy = row(24)
                local ic = content:CreateTexture(nil, "ARTWORK"); ic:SetSize(18, 18); ic:SetPoint("TOPLEFT", 4, yy - 2); ic:SetTexture(SpellTexture(e.spellID) or 134400); ic:SetTexCoord(0.08, 0.92, 0.08, 0.92); f.widgets[#f.widgets + 1] = ic
                label(string.format("%s  |cffb4a0dc%s|r", e.label, e.group == "other" and "Other" or "Major"), yy - 4, 170):SetPoint("TOPLEFT", 28, yy - 4)
                local id = e.spellID
                local lb = FlatButton(content, "<", 22, 20); lb:SetPoint("TOPLEFT", 200, yy)
                lb:SetScript("OnClick", function() Run("track move " .. id .. " left"); ns.ShowOptionsPage(idx) end)
                local rb = FlatButton(content, ">", 22, 20); rb:SetPoint("TOPLEFT", 224, yy)
                rb:SetScript("OnClick", function() Run("track move " .. id .. " right"); ns.ShowOptionsPage(idx) end)
                local cur = (DB.colW and DB.colW[id]) or 0
                local wl = content:CreateFontString(nil, "OVERLAY"); ApplyFont(wl, 11); Col(wl, T.muted); wl:SetPoint("TOPLEFT", 256, yy - 4)
                wl:SetText(cur > 0 and ("width " .. cur) or "width auto")
                local sl = FlatSlider(content, 110); sl:SetPoint("TOPLEFT", 330, yy - 2)
                sl:SetMinMaxValues(0, 160); sl:SetValueStep(2); if sl.SetObeyStepOnDrag then sl:SetObeyStepOnDrag(true) end
                sl.loading = true; sl:SetValue(cur); sl.loading = false
                sl:SetScript("OnValueChanged", function(self, v)
                    if self.loading then return end
                    v = math.floor(v / 2 + 0.5) * 2
                    Run("track width " .. id .. " " .. v); wl:SetText(v > 0 and ("width " .. v) or "width auto")
                end)
                local b = FlatButton(content, "Remove", 64, 20)
                b:SetPoint("TOPLEFT", 450, yy)
                b:SetScript("OnClick", function() Run("track remove " .. id); ns.ShowOptionsPage(idx) end)
                f.widgets[#f.widgets + 1] = lb; f.widgets[#f.widgets + 1] = rb; f.widgets[#f.widgets + 1] = wl; f.widgets[#f.widgets + 1] = sl
                f.widgets[#f.widgets + 1] = b
            end
            if #mine.list == 0 then label("Nothing tracked for this spec - add a spell ID below.", row(24)) end
        elseif c.t == "status" then
            local lines = {}
            if state.active and state.note then
                local el = GetTime() - state.startTime
                lines[#lines + 1] = string.format("|cff00e676Running:|r %s %s - %s%d:%02d%s, stage %d", state.note.name or "?", DIFF_NAME[state.note.difficultyID] or "", el < 0 and "pull in " or "", math.floor(math.abs(el) / 60), math.floor(math.abs(el) % 60), state.test and " (test)" or "", state.phase or 1)
            else
                lines[#lines + 1] = "|cffb4a0dcNothing running.|r"
            end
            local armed = PickArmedNote()
            lines[#lines + 1] = string.format("|cffb66effPull timers will load:|r %s", armed and string.format("%s %s%s", armed.name or "?", DIFF_NAME[armed.difficultyID] or "", DB.armed and " (pinned)" or (DB.lastFought and FindNote(DB.lastFought.encounterID, DB.lastFought.difficultyID) and " (last fought)" or " (selected)")) or "nothing stored")
            local li = DB.lastImport
            local sel = li and DB.notes[li.encounterID] and DB.notes[li.encounterID][li.difficultyID]
            lines[#lines + 1] = string.format("|cffe8f4ffSelected:|r %s", sel and string.format("%s %s - %d rows%s", sel.name or "?", DIFF_NAME[li.difficultyID] or "", #sel.entries, sel.phaseRelative and ", phase-relative" or "") or "none")
            do local h, m = BUILTIN.Count(); if h + m > 0 then lines[#lines + 1] = string.format("|cffb4a0dcBuilt-in (Smiler pack):|r %d Heroic and %d Mythic bosses, used when you have no plan", h, m) end end
            if DB.lastFought then local lf = FindNote(DB.lastFought.encounterID, DB.lastFought.difficultyID); lines[#lines + 1] = string.format("|cffb4a0dcLast fought:|r ID %d %s%s", DB.lastFought.encounterID, DIFF_NAME[DB.lastFought.difficultyID] or "", lf and (" - " .. (lf.name or "?")) or " (no plan stored)") end
            local l = content:CreateFontString(nil, "OVERLAY"); ApplyFont(l, 12); Col(l, T.fg); l:SetPoint("TOPLEFT", 4, row(16 * #lines + 10) - 2); l:SetWidth(540); l:SetJustifyH("LEFT"); l:SetText(table.concat(lines, "\n")); f.widgets[#f.widgets + 1] = l
        elseif c.t == "plans" then
            -- grouped by boss, one line per difficulty: Select · Arm · Test · Phases · Delete
            local ids = {}
            for encID in pairs(DB.notes) do ids[#ids + 1] = encID end
            table.sort(ids)
            if #ids == 0 then label("No plans stored yet - Import one.", row(24)) end
            for _, encID in ipairs(ids) do
                local byDiff = DB.notes[encID]
                local anyName; for _, n in pairs(byDiff) do anyName = anyName or n.name end
                local h = content:CreateFontString(nil, "OVERLAY"); ApplyFont(h, 14); Col(h, T.gold); h:SetPoint("TOPLEFT", 4, row(24) - 4); h:SetText(string.format("%s  |cffb4a0dcID %d|r", anyName or "?", encID)); f.widgets[#f.widgets + 1] = h
                local diffs = {}
                for d in pairs(byDiff) do diffs[#diffs + 1] = d end
                table.sort(diffs, function(a, b) return a > b end)
                for _, diffID in ipairs(diffs) do
                    local note = byDiff[diffID]
                    local yy = row(24)
                    local isSel = DB.lastImport and DB.lastImport.encounterID == encID and DB.lastImport.difficultyID == diffID
                    local isArmed = DB.armed and DB.armed.encounterID == encID and DB.armed.difficultyID == diffID
                    label(string.format("   %s%s%s  |cffb4a0dc%d rows%s|r", isSel and "|cff00e676*|r " or "   ", isArmed and "|cffffc450» |r" or "", DIFF_NAME[diffID] or ("diff " .. tostring(diffID)), #note.entries, note.phaseRelative and " · phases" or ""), yy - 4, 230)
                    local x = 236
                    local diffWord = (DIFF_NAME[diffID] or ""):lower():gsub(" ", "")
                    for _, bt in ipairs({ { "Select", "select " .. encID .. " " .. diffWord, isSel }, { "Arm", "use " .. encID .. " " .. diffWord, isArmed }, { "Test", "test" }, { "Phases", "phases" }, { "Delete", "delete " .. encID } }) do
                        local b = FlatButton(content, bt[1], 56, 20)
                        b:SetPoint("TOPLEFT", x, yy)
                        if bt[3] then b:SetEnabled(false) end
                        local cmd = bt[2]
                        b:SetScript("OnClick", function()
                            if cmd == "test" or cmd == "phases" then DB.lastImport = { encounterID = encID, difficultyID = diffID }; if cmd == "phases" then f.phasesFor = encID .. "/" .. diffID end end
                            Run(cmd); ns.ShowOptionsPage(idx)
                        end)
                        f.widgets[#f.widgets + 1] = b; x = x + 60
                    end
                    -- inline phase editor for the plan whose Phases button was pressed
                    if f.phasesFor == encID .. "/" .. diffID then
                        local starts, est = EstimatePhaseStarts(note)
                        local top = 0; for p in pairs(starts) do if p > top then top = p end end
                        local parts, raw = {}, {}
                        for p = 1, top do parts[#parts + 1] = string.format("P%d %d:%02d%s", p, math.floor((starts[p] or 0) / 60), math.floor((starts[p] or 0) % 60), est[p] and "?" or ""); raw[#raw + 1] = tostring(math.floor((starts[p] or 0) * 10 + 0.5) / 10) end
                        local y2 = row(26)
                        label("      phase starts: " .. table.concat(parts, "  ") .. "   |cffb4a0dc(? = estimated; learned on the next pull, or type them)|r", y2 - 4, 520)
                        local y3 = row(28)
                        local eb = FlatEdit(content, 220, 22)
                        eb:SetPoint("TOPLEFT", 40, y3 + 2); eb:SetText(table.concat(raw, ","))
                        local b = FlatButton(content, "Set", 60, 22); b:SetPoint("LEFT", eb, "RIGHT", 6, 0)
                        local function apply() DB.lastImport = { encounterID = encID, difficultyID = diffID }; Run("phases " .. (eb:GetText() or "")); ns.ShowOptionsPage(idx) end
                        b:SetScript("OnClick", apply); eb:SetScript("OnEnterPressed", apply); eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
                        local c2 = FlatButton(content, "Forget learned", 110, 22); c2:SetPoint("LEFT", b, "RIGHT", 6, 0)
                        c2:SetScript("OnClick", function() if DB.phaseLearned[encID] then DB.phaseLearned[encID][diffID] = nil end; note.phaseStarts = nil; ApplyGraphLayout(); ns.ShowOptionsPage(idx) end)
                        local c3 = FlatButton(content, "Close", 50, 22); c3:SetPoint("LEFT", c2, "RIGHT", 6, 0)
                        c3:SetScript("OnClick", function() f.phasesFor = nil; ns.ShowOptionsPage(idx) end)
                        f.widgets[#f.widgets + 1] = eb; f.widgets[#f.widgets + 1] = b; f.widgets[#f.widgets + 1] = c2; f.widgets[#f.widgets + 1] = c3
                    end
                end
            end
        elseif c.t == "notes" then
            local any = false
            for encID, byDiff in pairs(DB.notes) do
                for diffID, note in pairs(byDiff) do
                    any = true
                    local yy = row(24)
                    local armed = DB.armed and DB.armed.encounterID == encID
                    label(string.format("%s%s  |cffb4a0dc%s · ID %d · %d rows|r", armed and "|cffb66eff» |r" or "", note.name or "?", DIFF_NAME[diffID] or "?", encID, #note.entries), yy - 4, 320)
                    local x = 330
                    for _, bt in ipairs({ { "Test", "test" }, { "Use", "use " .. encID }, { "Delete", "delete " .. encID } }) do
                        local b = FlatButton(content, bt[1], 60, 20)
                        b:SetPoint("TOPLEFT", x, yy)
                        local cmd = bt[2]
                        b:SetScript("OnClick", function()
                            if cmd == "test" then DB.lastImport = { encounterID = encID, difficultyID = diffID } end
                            Run(cmd); ns.ShowOptionsPage(idx)
                        end)
                        f.widgets[#f.widgets + 1] = b; x = x + 64
                    end
                end
            end
            if not any then label("No plans stored yet - Import one.", row(24)) end
        end
    end
    content:SetHeight(math.max(10, -y + 10))
    if f.scroll and f.scroll.update then f.scroll:SetVerticalScroll(0); f.scroll.update() end
end
ns.ShowOptionsPage = ShowOptionsPage

local function ShowOptions(page)
    optFrame = optFrame or BuildOptions()
    optFrame:Show()
    ShowOptionsPage(page or optFrame.page or 1)
end
ns.ShowOptions = ShowOptions

-- a stub in the game's AddOns settings list that opens this window
pcall(function()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local panel = CreateFrame("Frame")
        local b = FlatButton(panel, "Open CD Timeline options", 220, 26, true)
        b:SetPoint("TOPLEFT", 16, -16)
        b:SetScript("OnClick", function() ShowOptions() end)
        local t = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); t:SetPoint("TOPLEFT", 16, -52); t:SetText("Or type /tl options")
        local cat = Settings.RegisterCanvasLayoutCategory(panel, "CD Timeline")
        Settings.RegisterAddOnCategory(cat)
    end
end)

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------
------------------------------------------------------------------------
-- Boss summary + planner (/tl plan): a vertical timeline, time running down.
-- Left to right: time · raid damage (bar length = how hard it hits) · boss hits · one column per healer.
-- Drag a cooldown up or down to move it (snaps to the nearest big hit; Shift = free). Drag from a column's
-- header icons to add a cast. Right-click: unlink / relink. Shift+right-click: delete. < > flips between bosses.
------------------------------------------------------------------------
local PL = { icons = {}, texs = {}, fss = {}, lines = {}, pal = {}, marks = {},
    TIME_W = 38, DMG_W = 150, EV_W = 168, COL_ROW = 26, HEAD_H = 46, TOP = 148, SIDE_W = 270, PORT_W = 64, PORT_H = 52,
    HELP = "Drag a cooldown up/down to move it - it snaps to the nearest big hit (hold Shift: free). Drag an icon from a column header to add a cast. Right-click: unlink · Shift+right-click: delete." }
PL.DMG_X = PL.TIME_W
-- one colour per cooldown, so its effect block and cooldown rail read at a glance
PL.SC = { [31821] = LK.CB.sky, [31884] = LK.CB.yellow, [375576] = LK.CB.purple, [6940] = LK.CB.vermillion,
    [498] = LK.CB.green, [642] = LK.CB.blue, [1022] = LK.CB.green, [633] = LK.CB.orange, [363916] = LK.CB.green, [374348] = LK.CB.vermillion,
    [363534] = { 0.30, 0.85, 0.75 }, [370537] = { 0.55, 0.75, 1.00 }, [374227] = { 0.70, 0.90, 0.95 }, [357170] = { 0.95, 0.85, 0.40 },
    [740] = { 0.40, 0.90, 0.45 }, [64843] = { 0.95, 0.95, 0.75 }, [62618] = { 0.85, 0.85, 1.00 }, [98008] = { 0.25, 0.65, 0.95 } }
function PL.SpellColor(note, e) return PL.SC[e.spellID or 0] or EntryColor(note, e) end
-- a pattern per cooldown, so they tell apart without colour: Aura Mastery solid, Wings striped, Divine Toll dotted
PL.SP = { [31884] = "hatch", [375576] = "dots", [363534] = "hatch", [357170] = "dots", [740] = "hatch", [64843] = "dots",
    [498] = "dots", [6940] = "hatch", [1022] = "hatch", [363916] = "dots" }
PL.EV_X = PL.DMG_X + PL.DMG_W + 12
PL.LANES_X = PL.EV_X + PL.EV_W + 8

function PL.Note()
    if state.note and not state.note.synthetic then return state.note end
    local li = DB.lastImport
    local n = li and DB.notes[li.encounterID]
    return n and (n[li.difficultyID] or select(2, next(n)))
end
function PL.Duration(note)
    local d = note.duration or 0
    for _, e in ipairs(note.entries) do if e.time and e.time < math.huge and e.time + 10 > d then d = e.time + 10 end end
    return math.max(d, 60)
end
function PL.Hex(c) return string.format("%02X%02X%02X", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5)) end
function PL.Num(v) local s_ = string.format("%.1f", v or 0); return (s_:gsub("%.0$", "")) end
-- every stored plan for the class you're on, by boss name then difficulty
function PL.List()
    local out = {}
    for _, byDiff in pairs(DB.notes) do for _, n in pairs(byDiff) do out[#out + 1] = n end end
    table.sort(out, function(a, b)
        if (a.name or "") ~= (b.name or "") then return (a.name or "") < (b.name or "") end
        return (a.difficultyID or 0) < (b.difficultyID or 0)
    end)
    return out
end

function ns.ExportNote(note)
    local L = {}
    L[#L + 1] = string.format("EncounterID:%d;Difficulty:%s;Name:%s;", note.encounterID or 0, note.difficulty or DIFF_NAME[note.difficultyID] or "Heroic", note.name or "?")
    if note.duration then L[#L + 1] = "duration:" .. PL.Num(note.duration) .. ";" end
    for id, c in pairs(note.curves or {}) do
        local d = {}
        for i, v in ipairs(c.data) do d[i] = PL.Num(v) end
        L[#L + 1] = string.format("curve:%s;step:%s;unit:%s;data:%s;", id, PL.Num(c.step), c.unit or "k", table.concat(d, ","))
    end
    for _, l in ipairs(note.lanes) do
        local x = string.format("lanedef:%s;name:%s;kind:%s;", l.id, l.name or l.id, l.kind or "raid")
        if type(l.color) == "table" then x = x .. "color:" .. PL.Hex(l.color) .. ";" end
        L[#L + 1] = x
    end
    for _, e in ipairs(note.entries) do
        if not e.pull and e.time and e.time < math.huge then
            local lane = note.lanes[e.laneIndex]
            local x = string.format("ph:%d;time:%s;tag:%s;spellid:%d;lane:%s;label:%s;cd:%s;major:%d;",
                e.ph or 1, PL.Num(e.rel or e.time), e.isBoss and "BOSS" or (e.tag or ""), e.spellID or 0, lane and lane.id or "raid",
                e.label or "", PL.Num(e.cd or 0), e.major and 1 or 0)
            if e.class then x = x .. "class:" .. e.class .. ";" end
            if e.anchor ~= nil then x = x .. string.format("anchor:%s;n:%d;offset:%s;", tostring(e.anchor), e.anchorN or 1, PL.Num(e.anchorOff)) end
            L[#L + 1] = x
        end
    end
    return table.concat(L, "\n")
end

function PL.Build()
    local f = Panel("CDTimelinePlanner", 640, 760, "HIGH")
    tinsert(UISpecialFrames, "CDTimelinePlanner")
    f.title:SetText("Boss summary")
    f.sub:SetText("")
    f.stats = f:CreateFontString(nil, "OVERLAY"); ApplyFont(f.stats, 11); Col(f.stats, T.fg2)
    f.stats:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -(PL.TOP - 18)); f.stats:SetJustifyH("LEFT")
    local nxt = FlatButton(f, ">", 26, 24); nxt:SetPoint("TOPRIGHT", -12, -8)
    local prv = FlatButton(f, "<", 26, 24); prv:SetPoint("RIGHT", nxt, "LEFT", -4, 0)
    f.count = f:CreateFontString(nil, "OVERLAY"); ApplyFont(f.count, 11); Col(f.count, T.muted); f.count:SetPoint("RIGHT", prv, "LEFT", -8, 0)
    local function flip(d)
        local list = PL.List(); if #list == 0 then return end
        local i = 1
        for k, n in ipairs(list) do if n == f.note then i = k end end
        i = (i - 1 + d) % #list + 1
        f.note = UpgradeNote(list[i])
        DB.lastImport = { encounterID = f.note.encounterID, difficultyID = f.note.difficultyID }
        PL.Draw()
        if ns.ApplyGraphLayout then ns.ApplyGraphLayout() end
    end
    prv:SetScript("OnClick", function() flip(-1) end)
    nxt:SetScript("OnClick", function() flip(1) end)
    local pf = CreateFrame("Frame", nil, f)
    pf:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -(PL.TOP + PL.HEAD_H))
    pf:SetSize(400, 400)
    f.pf = pf
    f.hint = f:CreateFontString(nil, "OVERLAY"); ApplyFont(f.hint, 10); Col(f.hint, T.muted)
    f.hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 40); f.hint:SetJustifyH("LEFT"); f.hint:SetText(PL.HELP)
    f.drag = pf:CreateFontString(nil, "OVERLAY"); ApplyFont(f.drag, 12, "OUTLINE"); Col(f.drag, T.goldHi)
    local close = FlatButton(f, "Close", 64, 24); close:SetPoint("BOTTOMRIGHT", -14, 10); close:SetScript("OnClick", function() f:Hide() end)
    local export = FlatButton(f, "Export", 72, 24); export:SetPoint("RIGHT", close, "LEFT", -6, 0)
    local reset = FlatButton(f, "Undo all", 80, 24); reset:SetPoint("RIGHT", export, "LEFT", -6, 0)
    f.exportBox = FlatEdit(f, 200, 24); f.exportBox:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 10); f.exportBox:SetPoint("RIGHT", reset, "LEFT", -8, 0); f.exportBox:Hide()
    f.exportBox:SetScript("OnEditFocusLost", function(self) self:Hide() end)
    export:SetScript("OnClick", function()
        local note = f.note; if not note then return end
        f.exportBox:SetText((ns.ExportNote(note):gsub("\n", " "))); f.exportBox:Show(); f.exportBox:SetFocus(); f.exportBox:HighlightText()
        Print("Plan string selected - Ctrl+C to copy. It imports back with /tl import.")
    end)
    reset:SetScript("OnClick", function()
        local note = f.note; if not note then return end
        local keep = {}
        for _, e in ipairs(note.entries) do
            if not e.added then
                if e.origTime then e.time = e.origTime; e.rel = e.origTime; e.origTime = nil end
                e.noLink = nil
                keep[#keep + 1] = e
            end
        end
        note.entries = keep
        ns.PlanChanged()
    end)
    f:SetScript("OnHide", function() PL.dragging = nil end)
    -- mirror: damage on one side of the line, healing on the other
    local mir = FlatButton(f, "Mirror", 64, 24); mir:SetPoint("RIGHT", f.count, "LEFT", -10, 0)
    mir:SetScript("OnClick", function() DB.plMirror = not DB.plMirror; PL.Draw() end)
    mir:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:AddLine("Mirror view")
        GameTooltip:AddLine("Incoming damage grows left from the centre line, healing grows right: your raid's everyday healing (solid), cooldown healing (striped) and damage prevented (dotted). Where damage reaches further than healing, the gap is hatched.", 0.8, 0.8, 0.8, true); GameTooltip:Show() end)
    mir:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.mirror = mir
    PL.BuildBossBar(f)
    PL.BuildSides(f)
    PL.f = f
    return f
end

function PL.Tex(layer, sub)
    PL.texUsed = PL.texUsed + 1
    local t = PL.texs[PL.texUsed]
    if not t then t = PL.f.pf:CreateTexture(nil, layer or "ARTWORK"); PL.texs[PL.texUsed] = t end
    t:SetDrawLayer(layer or "ARTWORK", sub or 0); t:ClearAllPoints(); t:SetTexCoord(0, 1, 0, 1)
    t:SetHorizTile(false); t:SetVertTile(false); t:SetVertexColor(1, 1, 1, 1); t:Show()
    return t
end
function PL.FS(size, flags)
    PL.fsUsed = PL.fsUsed + 1
    local t = PL.fss[PL.fsUsed]
    if not t then t = PL.f.pf:CreateFontString(nil, "OVERLAY"); t:SetWordWrap(false); PL.fss[PL.fsUsed] = t end
    ApplyFont(t, size or 10, flags); t:ClearAllPoints(); t:SetJustifyH("LEFT"); t:SetWidth(0); t:Show()
    return t
end
function PL.Line()
    PL.lineUsed = PL.lineUsed + 1
    local l = PL.lines[PL.lineUsed]
    if not l then l = PL.f.pf:CreateLine(nil, "ARTWORK", nil, 4); PL.lines[PL.lineUsed] = l end
    l:Show()
    return l
end

function PL.CursorTime()
    local pf = PL.f.pf
    local _, cy = GetCursorPosition()
    local y = (pf:GetTop() or 0) - cy / pf:GetEffectiveScale()
    return math.max(0, math.min(PL.dur, y / PL.PH * PL.dur))
end
function PL.Snap(e, t)
    if IsShiftKeyDown() then return t, nil end
    local lead = LK.lead[e.spellID or 0] or 1
    local best, bd
    for _, b in ipairs(PL.hits) do
        if b.major then
            local d = math.abs((LK.HitTime(b) - lead) - t)
            if d <= 7 and (not bd or d < bd) then best, bd = b, d end
        end
    end
    if best then return math.max(0, LK.HitTime(best) - lead), best end
    return t, nil
end

function PL.Icon(i)
    local b = PL.icons[i]
    if b then return b end
    b = CreateFrame("Button", nil, PL.f.pf, "BackdropTemplate")
    b:SetFrameLevel(PL.f.pf:GetFrameLevel() + 5)
    b:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
    b.tex = b:CreateTexture(nil, "ARTWORK"); b.tex:SetPoint("TOPLEFT", 2, -2); b.tex:SetPoint("BOTTOMRIGHT", -2, 2); b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b:RegisterForClicks("RightButtonUp")
    b:SetScript("OnMouseDown", function(self, btn)
        if btn ~= "LeftButton" or not self.e then return end
        local e = self.e
        if self.palette then
            local n = { time = PL.CursorTime(), spellID = e.spellID, cd = e.cd, major = e.major, class = e.class,
                classRGB = e.classRGB, className = e.className, tag = e.tag, lane = e.lane, laneIndex = e.laneIndex, ph = 1, added = true }
            n.label = SpellName(n.spellID) or e.label or "?"
            n.rel = n.time
            table.insert(PL.f.note.entries, n)
            e = n
        end
        e.origTime = e.origTime or e.time
        PL.dragging = e
        PL.dragFrame:Show()
    end)
    b:SetScript("OnClick", function(self)
        local e = self.e
        if not e or self.palette then return end
        if IsShiftKeyDown() then
            for i2, x in ipairs(PL.f.note.entries) do if x == e then table.remove(PL.f.note.entries, i2) break end end
        else
            e.noLink = not e.noLink or nil
        end
        ns.PlanChanged()
    end)
    b:SetScript("OnEnter", function(self)
        local e = self.e; if not e then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(SpellName(e.spellID or 0) or e.label or "?", 1, 0.82, 0.1)
        if self.palette then GameTooltip:AddLine("Drag down into the column to add a cast", 0.8, 0.8, 0.8)
        else
            GameTooltip:AddDoubleLine(FmtClock(e.time), e.tag or "", 1, 1, 1, 0.8, 0.8, 0.8)
            local hb = LK.linkOf[e]
            if hb then GameTooltip:AddLine("for " .. LK.HitName(hb) .. " at " .. FmtClock(LK.HitTime(hb)), 0.4, 1, 0.6)
            else GameTooltip:AddLine(e.noLink and "unlinked - right-click to relink" or "not on a big hit", 0.8, 0.8, 0.8) end
            local fx = math.max(LK.effect[e.spellID or 0] or 0, 3)
            local cov = LK.CurveSum(PL.f.note, "dmg", e.time, fx)
            if cov then GameTooltip:AddLine(string.format("raid damage in its %d s: %s", fx, LK.FmtK(cov)), 1, 0.67, 0) end
            local g = LK.CdGain(PL.f.note, e)
            local m = LK.THRU[e.spellID or 0]
            if g and m then
                GameTooltip:AddLine(string.format("estimated %s %s  (%s)", g.kind == "heal" and "extra healing" or "damage prevented", LK.FmtK(g.total), m.src), 0.34, 0.71, 0.91, true)
            elseif not m then
                GameTooltip:AddLine("no throughput estimate for this spell", 0.6, 0.6, 0.6)
            end
            if self.conflict then GameTooltip:AddLine("Still on cooldown: " .. self.conflict, 0.84, 0.37, 0) end
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    PL.icons[i] = b
    return b
end

-- one hover target per boss event (a run of the same big hit, e.g. 6 intermission coil soaks)
function PL.Mark(i)
    local m = PL.marks[i]
    if m then return m end
    m = CreateFrame("Frame", nil, PL.f.pf)
    m:SetFrameLevel(PL.f.pf:GetFrameLevel() + 3)
    m.tex = m:CreateTexture(nil, "ARTWORK"); m.tex:SetAllPoints()
    m:EnableMouse(true)
    m:SetScript("OnEnter", function(self)
        local ev = self.ev; if not ev then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(ev.name .. (#ev.hits > 1 and ("  ×" .. #ev.hits) or ""), 1, 0.82, 0.1)
        GameTooltip:AddLine(FmtClock(ev.t0) .. (ev.t1 > ev.t0 + 1 and ("-" .. FmtClock(ev.t1)) or ""), 1, 1, 1)
        if ev.peak then GameTooltip:AddLine("raid damage up to " .. LK.FmtK(ev.peak) .. "/s", 1, 0.67, 0) end
        if #ev.cds > 0 then
            for _, x in ipairs(ev.cds) do
                local c = x.classRGB or GOLD
                GameTooltip:AddLine((SpellName(x.spellID or 0) or x.label or "?") .. "  " .. (x.tag or "") .. "  " .. FmtClock(x.time), c[1], c[2], c[3])
            end
        else GameTooltip:AddLine("No cooldown assigned", 1, 0.2, 0.3) end
        GameTooltip:Show()
    end)
    m:SetScript("OnLeave", function() GameTooltip:Hide() end)
    PL.marks[i] = m
    return m
end

-- the "+" menu: the lane's class spells it doesn't have yet; picking one drops a cast at the first free spot
function PL.AddMenu(owner, L_)
    local note = PL.f and PL.f.note
    local tmpl = L_ and L_.items[1]
    if note and L_ and not tmpl then
        local cls = PC.PlayerClassKey()
        tmpl = { class = cls, className = cls, classRGB = CLASS_RGB[cls or ""], tag = UnitName("player"),
                 lane = note.lanes[L_.li] and note.lanes[L_.li].id, laneIndex = L_.li }
    end
    if not note or not tmpl then Print("Add a cast to this column first (drag one in), then use + for more spells.") return end
    local cls = tmpl.className or tmpl.class
    local groups = LK.CLASS_SPELLS[cls or ""]
    if not groups then Print("No spell list for %s yet.", tostring(cls)) return end
    local have = {}
    for _, e in ipairs(L_.items) do have[e.spellID or 0] = true end
    local function add(id)
        local n = { time = 30, spellID = id, cd = LK.CDLEN[id] or 60, major = (LK.THRU[id] ~= nil) and (LK.CDLEN[id] or 0) >= 120,
            class = tmpl.class, classRGB = tmpl.classRGB, className = tmpl.className, tag = tmpl.tag, lane = tmpl.lane,
            laneIndex = tmpl.laneIndex, ph = 1, added = true, label = SpellName(id) or tostring(id) }
        n.rel = n.time
        table.insert(note.entries, n)
        ns.PlanChanged()
        Print("Added %s - drag it to where you want it.", n.label)
    end
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(owner, function(_, root)
            for _, grp in ipairs(groups) do
                root:CreateTitle(grp[1])
                for _, id in ipairs(grp[2]) do
                    local nm = (SpellName(id) or tostring(id)) .. (have[id] and "  (has a column)" or "")
                    root:CreateButton(nm, function() add(id) end)
                end
            end
        end)
    else
        -- no menu API: add the first spell the column doesn't have yet
        for _, grp in ipairs(groups) do for _, id in ipairs(grp[2]) do if not have[id] then add(id) return end end end
    end
end

function PL.Events(note)
    local evs, last = {}, nil
    for _, b in ipairs(PL.hits) do
        if b.major then
            local ht, nm = LK.HitTime(b), LK.HitName(b)
            if last and last.name == nm and ht - last.t1 <= 10 then
                last.hits[#last.hits + 1] = b; last.t1 = ht
            else
                last = { name = nm, t0 = ht, t1 = ht, hits = { b }, cds = {} }
                evs[#evs + 1] = last
            end
        end
    end
    for _, ev in ipairs(evs) do
        local seen = {}
        for _, b in ipairs(ev.hits) do
            for _, x in ipairs(LK.assignedTo[b] or {}) do if not seen[x] then seen[x] = true; ev.cds[#ev.cds + 1] = x end end
            for _, x in ipairs(LK.ActiveAt(note.entries, LK.HitTime(b))) do if not seen[x] then seen[x] = true; ev.cds[#ev.cds + 1] = x end end
            local v = LK.CurveAt(note, "dmg", LK.HitTime(b)); if v and (not ev.peak or v > ev.peak) then ev.peak = v end
        end
        table.sort(ev.cds, function(a, b) return a.time < b.time end)
    end
    return evs
end

function PL.Draw()
    local f, note = PL.f, PL.f.note
    for i = 1, (PL.texUsed or 0) do PL.texs[i]:Hide() end
    for i = 1, (PL.fsUsed or 0) do PL.fss[i]:Hide() end
    for i = 1, (PL.lineUsed or 0) do PL.lines[i]:Hide() end
    for _, b in ipairs(PL.icons) do b:Hide(); b.e = nil end
    for _, p in ipairs(PL.pal) do p:Hide(); p.e = nil end
    for _, m in ipairs(PL.marks) do m:Hide(); m.ev = nil end
    for _, a in ipairs(PL.adds or {}) do a:Hide() end
    PL.addN = 0
    PL.palN, PL.texUsed, PL.fsUsed, PL.lineUsed = 0, 0, 0, 0
    f.drag:SetText("")
    local list = PL.List()
    local idx = 0
    for k, n in ipairs(list) do if n == note then idx = k end end
    f.count:SetText(#list > 1 and string.format("%d / %d", idx, #list) or "")
    if not note then f.title:SetText("Boss summary"); f.stats:SetText("No plan for this class yet - pick a boss above, or /tl import"); PL.SyncBossBar(); return end
    f.title:SetText((note.name or "?") .. "  ·  " .. (DIFF_NAME[note.difficultyID] or note.difficulty or ""))
    if note.phaseRelative then f.stats:SetText("This plan is timed per stage - the summary shows single-clock plans only."); return end
    SortEntries(note.entries)
    LK.Link(note.entries)
    local pf = f.pf
    -- squared paper: one row of cells per curve step (5 s); every column and lane sits on the same grid
    local step = (note.curves and note.curves.dmg and note.curves.dmg.step) or 5
    local rows = math.ceil(PL.Duration(note) / step)
    local uiH = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 768
    if type(uiH) ~= "number" then uiH = 768 end
    local maxPH = math.max(360, math.min(640, uiH - PL.TOP - PL.HEAD_H - 70 - 40))
    local cell = math.max(5, math.floor(maxPH / rows))
    local PH = cell * rows
    local dur = rows * step
    PL.dur, PL.PH, PL.cell = dur, PH, cell
    local function Y(t) return t / step * cell end
    local function Ytop(t) return math.floor(t / step + 1e-6) * cell end     -- top of the row t falls in
    local function Yend(t) return math.ceil(t / step - 1e-6) * cell end      -- bottom of the row t ends in
    local function G(px) return math.ceil(px / cell) * cell end              -- round a width up to whole cells
    local DCOLS = math.max(12, math.floor(150 / cell))
    local DMG_X = G(PL.TIME_W)
    local MIRROR = DB.plMirror and true or false
    local DMG_W = DCOLS * cell * (MIRROR and 2 or 1)
    local AXIS_X = DMG_X + DCOLS * cell              -- mirror: the line between damage (left) and healing (right)
    local EV_X = DMG_X + DMG_W + G(12)
    local LANES_X = EV_X + G(PL.EV_W)
    local ROW = G(PL.COL_ROW)
    local LOFF = cell

    -- boss hits and grouped events
    PL.hits = {}
    for _, e in ipairs(note.entries) do if e.isBoss and e.time and e.time < math.huge then PL.hits[#PL.hits + 1] = e end end
    local evs = PL.Events(note)

    -- healer columns; casts that would overlap go into a second / third sub-column
    local lanes, laneOf = {}, {}
    for i, l in ipairs(note.lanes) do if l.kind ~= "boss" then lanes[#lanes + 1] = { li = i, items = {}, cols = 1 }; laneOf[i] = lanes[#lanes] end end
    for _, e in ipairs(note.entries) do
        local L_ = laneOf[e.laneIndex]
        if L_ and not e.isBoss and not e.pull and e.time and e.time < math.huge then L_.items[#L_.items + 1] = e end
    end
    local x = LANES_X
    for _, L_ in ipairs(lanes) do
        local cdOf, order = {}, {}
        for _, e in ipairs(L_.items) do
            local k = e.spellID or 0
            if not cdOf[k] then cdOf[k] = e.cd or 0; order[#order + 1] = k end
        end
        table.sort(order, function(a, b) if cdOf[a] ~= cdOf[b] then return cdOf[a] > cdOf[b] end return a < b end)
        L_.colOf = {}
        for i, k in ipairs(order) do L_.colOf[k] = i end
        for _, e in ipairs(L_.items) do e.plCol = L_.colOf[e.spellID or 0] end
        L_.cols = math.max(1, #order)
        L_.x = x
        L_.w = G(math.max(66, 2 * LOFF + L_.cols * ROW))
        x = x + L_.w + cell
    end
    local W = x
    pf:SetSize(W, PH)
    if not PL.barW then PL.TierBosses(); PL.barW = #(PL.tier or {}) * (PL.PORT_W + 4) + 3 * 8 + 150 end
    f:SetSize(math.max(560, W + 28, PL.barW + 28), PL.TOP + PL.HEAD_H + PH + 18 + 66)
    f.hint:SetWidth(math.max(560, W + 28) - 28)

    -- column headings
    local function head(text, xx, w, justify)
        local h = PL.FS(10); Col(h, T.muted); h:SetWidth(w); h:SetJustifyH(justify or "LEFT")
        h:SetPoint("BOTTOMLEFT", pf, "TOPLEFT", xx, 9); h:SetText(text)
        return h
    end
    head("time", 0, PL.TIME_W - 4, "RIGHT")
    local peak = LK.CurvePeak(note, "dmg") or 0
    local unit = LK.Nice(peak / DCOLS)
    local H, mine = LK.MyHps(note)
    -- healers in the raid: the plan's healer columns when it has several, else /tl healers (default 4)
    local healers = (#lanes >= 2) and #lanes or (DB.plHealers or 4)
    if MIRROR then
        head("|cffe69f00<- damage|r   |   |cff56b4e9healing ->|r everyday (solid) · CDs (striped) · prevented (dotted) · gap hatched   1 block = " .. LK.FmtK(unit) .. "/s", DMG_X, DMG_W + G(12) + 200)
    else
        head("|cffe69f00damage ->|r   |cff56b4e9<- CD healing (striped) / prevented (dotted)|r   1 block = " .. LK.FmtK(unit) .. "/s", DMG_X, DMG_W + G(12) + 200)
    end
    PL.healers = healers

    -- the grid: a faint line every cell, stronger every minute; in the damage column a gutter splits the bars into blocks
    for r = 0, rows do
        local major = (r * step) % 60 == 0
        local g = PL.Tex("ARTWORK", 3); Tex(g, T.border, major and 0.42 or 0.14); g:SetSize(DMG_W, 1); g:SetPoint("TOPLEFT", pf, "TOPLEFT", DMG_X, -r * cell)
        if major then   -- outside the squared paper only a faint line per minute, to read across
            local m = PL.Tex("BACKGROUND", 3); Tex(m, T.border, 0.16); m:SetSize(W - DMG_X - DMG_W, 1); m:SetPoint("TOPLEFT", pf, "TOPLEFT", DMG_X + DMG_W, -r * cell)
        end
        if major then
            local l = PL.FS(10); Col(l, T.muted); l:SetWidth(DMG_X - 6); l:SetJustifyH("RIGHT"); l:SetPoint("RIGHT", pf, "TOPLEFT", DMG_X - 6, -r * cell); l:SetText(FmtClock(r * step))
        end
    end
    for cx = DMG_X, DMG_X + DMG_W, cell do
        local gut = PL.Tex("ARTWORK", 2); Tex(gut, T.card, 1); gut:SetSize(1, PH); gut:SetPoint("TOPLEFT", pf, "TOPLEFT", cx, 0)
        local g = PL.Tex("ARTWORK", 3); Tex(g, T.border, ((cx - DMG_X) % (5 * cell) == 0) and 0.24 or 0.11); g:SetSize(1, PH); g:SetPoint("TOPLEFT", pf, "TOPLEFT", cx, 0)
    end

    -- coverage: 5 s buckets under a major cooldown's effect
    local c = note.curves and note.curves.dmg
    local covSet = {}
    if c then
        for _, L_ in ipairs(lanes) do
            for _, e in ipairs(L_.items) do
                if e.major then
                    local fx = math.max(LK.effect[e.spellID or 0] or 0, 3)
                    for k = math.floor(e.time / c.step), math.floor((e.time + fx - 0.01) / c.step) do covSet[k] = true end
                end
            end
        end
    end
    -- damage: bar length = raid damage taken; green where a major cooldown is running
    local covDmg, allDmg = 0, 0
    local axis = PL.Tex("ARTWORK", 3); Tex(axis, T.border, 0.8); axis:SetSize(1, PH); axis:SetPoint("TOPLEFT", pf, "TOPLEFT", DMG_X, 0)
    if c and peak > 0 then
        for i, v in ipairs(c.data) do
            local t0 = (i - 1) * c.step
            if t0 < dur then
                if covSet[i - 1] then covDmg = covDmg + v * c.step end
                allDmg = allDmg + v * c.step
                local blocks = math.min(DCOLS, math.floor(v / unit + 0.5))
                if blocks > 0 then
                    local r = PL.Tex("ARTWORK", 0); Tex(r, LK.CB.orange, 0.85)
                    r:SetSize(blocks * cell, cell - 1)
                    r:SetPoint("TOPLEFT", pf, "TOPLEFT", MIRROR and (AXIS_X - blocks * cell) or DMG_X, -(i - 1) * cell - 1)
                end
            end
        end
    end

    -- cooldown healing (striped) and damage prevented (dotted), growing in from the right on the same block scale
    local healRow, prevRow, gainTotal = {}, {}, 0
    for _, L_ in ipairs(lanes) do
        for _, e in ipairs(L_.items) do
            local g = LK.CdGain(note, e)
            if g then
                gainTotal = gainTotal + g.total
                local tgt = g.kind == "heal" and healRow or prevRow
                for r = math.floor(g.from / step), math.floor((g.to - 0.01) / step) do
                    local a, b = math.max(g.from, r * step), math.min(g.to, (r + 1) * step)
                    if b > a then tgt[r] = (tgt[r] or 0) + g.rate * (b - a) / step end
                end
            end
        end
    end
    if MIRROR then
        -- everyday healing: your throughput outside cooldowns x the healers in the plan; then CDs, then prevented
        local base = H * healers
        for r = 0, rows - 1 do
            local bb = math.min(DCOLS, math.floor(base / unit + 0.5))
            local hb = math.floor((healRow[r] or 0) / unit + 0.5)
            local pb = math.floor((prevRow[r] or 0) / unit + 0.5)
            if (healRow[r] or 0) > 0 and hb == 0 then hb = 1 end
            if (prevRow[r] or 0) > 0 and pb == 0 then pb = 1 end
            hb = math.min(DCOLS - bb, hb); pb = math.min(DCOLS - bb - hb, pb)
            local function strip(n, offset, kind, a)
                if n <= 0 then return end
                local x0 = AXIS_X + offset * cell
                local b = PL.Tex("ARTWORK", 1); Tex(b, LK.CB.sky, a or 0.8); b:SetSize(n * cell, cell - 1); b:SetPoint("TOPLEFT", pf, "TOPLEFT", x0, -r * cell - 1)
                if kind then local pt = PL.Tex("ARTWORK", 1); LK.Pattern(pt, kind, LK.CB.ink, 0.7); pt:SetSize(n * cell, cell - 1); pt:SetPoint("TOPLEFT", pf, "TOPLEFT", x0, -r * cell - 1) end
            end
            strip(bb, 0, nil, 0.45)
            strip(hb, bb, "hatch")
            strip(pb, bb + hb, "dots")
            -- damage reaching past the healing on the other side: hatch the gap on the damage bar
            local v = c and c.data[r + 1] or 0
            local db_ = math.min(DCOLS, math.floor(v / unit + 0.5))
            local gap = db_ - (bb + hb + pb)
            if gap > 0 then
                local gx = AXIS_X - db_ * cell
                local gt = PL.Tex("ARTWORK", 2); LK.Pattern(gt, "hatch", LK.CB.vermillion, 0.9); gt:SetSize(gap * cell, cell - 1); gt:SetPoint("TOPLEFT", pf, "TOPLEFT", gx, -r * cell - 1)
            end
        end
        local ax = PL.Tex("ARTWORK", 3); Tex(ax, T.fg, 0.9); ax:SetSize(2, PH); ax:SetPoint("TOPLEFT", pf, "TOPLEFT", AXIS_X - 1, 0)
    end
    for r = 0, MIRROR and -1 or (rows - 1) do
        local hb = math.floor((healRow[r] or 0) / unit + 0.5)
        local pb = math.floor((prevRow[r] or 0) / unit + 0.5)
        if (healRow[r] or 0) > 0 and hb == 0 then hb = 1 end      -- any real healing shows at least one block
        if (prevRow[r] or 0) > 0 and pb == 0 then pb = 1 end
        hb = math.min(DCOLS, hb); pb = math.min(DCOLS - hb, pb)
        local function strip(n, offset, kind)
            if n <= 0 then return end
            local x0 = DMG_X + DMG_W - (offset + n) * cell
            local b = PL.Tex("ARTWORK", 1); Tex(b, LK.CB.sky, 0.8); b:SetSize(n * cell, cell - 1); b:SetPoint("TOPLEFT", pf, "TOPLEFT", x0, -r * cell - 1)
            local pt = PL.Tex("ARTWORK", 1); LK.Pattern(pt, kind, LK.CB.ink, 0.7); pt:SetSize(n * cell, cell - 1); pt:SetPoint("TOPLEFT", pf, "TOPLEFT", x0, -r * cell - 1)
        end
        strip(hb, 0, "hatch")
        strip(pb, hb, "dots")
    end
    local rule = PL.Tex("ARTWORK", 3); Tex(rule, T.border, 0.8); rule:SetSize(1, PH); rule:SetPoint("TOPLEFT", pf, "TOPLEFT", DMG_X + DMG_W, 0)

    -- small hits: short grey ticks
    for _, b in ipairs(PL.hits) do
        if not b.major then
            local m = PL.Tex("ARTWORK", 2); Tex(m, T.muted, 0.45); m:SetSize(5, 1)
            m:SetPoint("TOPLEFT", pf, "TOPLEFT", EV_X + 1, -Y(LK.HitTime(b)))
        end
    end
    -- big hits: a marker per event (purple = a cooldown is on it, red = none), a guide back across the damage, a label if it fits
    local covered, nextFree = 0, -1e9
    for i, ev in ipairs(evs) do
        local has = #ev.cds > 0
        if has then covered = covered + 1 end
        local cc = has and LK.CB.sky or LK.CB.vermillion
        local y0, y1 = Y(ev.t0), Y(ev.t1)
        -- the damage this ability causes: from its hit to ~6 s after
        local wEnd = math.min(dur, ev.t1 + 6)
        local by0, by1 = Ytop(ev.t0), Yend(wEnd)
        local band = PL.Tex("ARTWORK", 1); Tex(band, cc, has and 0.14 or 0.12)
        band:SetSize(EV_X - DMG_X, math.max(cell, by1 - by0)); band:SetPoint("TOPLEFT", pf, "TOPLEFT", DMG_X, -by0)
        if not has then   -- nothing on it: warning stripes across the damage it causes
            local wh = PL.Tex("ARTWORK", 1); LK.Pattern(wh, "hatch", cc, 0.35)
            wh:SetSize(EV_X - DMG_X, math.max(cell, by1 - by0)); wh:SetPoint("TOPLEFT", pf, "TOPLEFT", DMG_X, -by0)
        end
        local edge = PL.Tex("ARTWORK", 2); Tex(edge, cc, 0.9); edge:SetSize(2, math.max(cell, by1 - by0)); edge:SetPoint("TOPLEFT", pf, "TOPLEFT", EV_X - 3, -by0)
        if c and peak > 0 then
            local mv, mt = 0, ev.t0
            for tt = ev.t0, wEnd, c.step do local v = LK.CurveAt(note, "dmg", tt) or 0; if v > mv then mv, mt = v, tt end end
            local bx = MIRROR and (AXIS_X - math.min(DCOLS, math.floor(mv / unit + 0.5)) * cell) or (DMG_X + math.min(DCOLS, math.floor(mv / unit + 0.5)) * cell)
            local by = -(Ytop(mt) + cell / 2)
            local l = PL.Line(); l:SetColorTexture(cc[1], cc[2], cc[3], 0.7); l:SetThickness(1)
            l:SetStartPoint("TOPLEFT", pf, bx, by); l:SetEndPoint("TOPLEFT", pf, EV_X - 3, -(y0 + math.min(4, (by1 - y0) / 2)))
            local dot = PL.Tex("ARTWORK", 3); Tex(dot, cc, 1); dot:SetSize(4, 4); dot:SetPoint("CENTER", pf, "TOPLEFT", bx, by)
            ev.dmg = mv
        end
        local m = PL.Mark(i); m.ev = ev
        m:ClearAllPoints(); m:SetSize(7, math.max(7, y1 - y0 + 7)); m:SetPoint("TOPLEFT", pf, "TOPLEFT", EV_X, -(y0 - 3.5))
        Tex(m.tex, cc, 1); m:Show()
        if not m.hole then m.hole = m:CreateTexture(nil, "OVERLAY"); m.hole:SetPoint("TOPLEFT", 2, -2); m.hole:SetPoint("BOTTOMRIGHT", -2, 2) end
        Tex(m.hole, T.card, 1)
        if has then m.hole:Hide() else m.hole:Show() end           -- filled = covered, hollow = nothing on it
        ev.mx = EV_X + 7
        local lb = PL.FS(10); Col(lb, has and T.fg or LK.CB.vermillion); lb:SetWidth(PL.EV_W - 12)
        lb:SetText(ev.name .. (#ev.hits > 1 and (" ×" .. #ev.hits) or "") .. (ev.dmg and ("  |cffe69f00" .. LK.FmtK(ev.dmg) .. "|r") or "") .. (has and "" or "  no CD"))
        local top = math.max(y0 - 6, nextFree)
        if top - (y0 - 6) <= 10 then
            lb:SetPoint("TOPLEFT", pf, "TOPLEFT", EV_X + 11, -top); nextFree = top + 11
        else lb:Hide() end
    end

    -- healer columns
    local n, last = 0, {}
    for k, L_ in ipairs(lanes) do
        local bgr = PL.Tex("BACKGROUND", 2); Tex(bgr, T.bg, 0.55); bgr:SetSize(L_.w, PH); bgr:SetPoint("TOPLEFT", pf, "TOPLEFT", L_.x, 0)
        local ld = note.lanes[L_.li]
        local nm = PL.FS(12); nm:SetWidth(L_.w); nm:SetJustifyH("CENTER"); Col(nm, ld.color or T.fg)
        nm:SetPoint("BOTTOMLEFT", pf, "TOPLEFT", L_.x, 24); nm:SetText(ld.name or ld.id)
        local pal = 0
        -- "+": add a healing cooldown or defensive as a new column
        PL.addN = (PL.addN or 0) + 1
        PL.adds = PL.adds or {}
        local ab = PL.adds[PL.addN]
        if not ab then
            ab = FlatButton(pf, "+", 16, 16); PL.adds[PL.addN] = ab
            ab:SetScript("OnClick", function(self) PL.AddMenu(self, self.lane) end)
            ab:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine("Add a spell column"); GameTooltip:AddLine("healing cooldowns and personal defensives", 0.8, 0.8, 0.8); GameTooltip:Show() end)
            ab:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        ab.lane = L_; ab:ClearAllPoints(); ab:SetPoint("BOTTOMRIGHT", pf, "TOPLEFT", L_.x + L_.w, 24); ab:Show()
        for _, e in ipairs(L_.items) do
            local sc = PL.SpellColor(note, e)
            local pat = PL.SP[e.spellID or 0]
            local rx = L_.x + LOFF + (e.plCol - 0.5) * ROW
            local fx = LK.effect[e.spellID or 0] or 0
            local cdEnd = math.min(dur, e.time + (e.cd or 0))
            if cdEnd > e.time then
                local rail = PL.Tex("BACKGROUND", 4); Tex(rail, sc, 0.2); rail:SetSize(math.max(2, math.floor(cell / 2)), math.max(cell, Yend(cdEnd) - Ytop(e.time)))
                rail:SetPoint("TOP", pf, "TOPLEFT", rx, -Ytop(e.time))
            end
            if fx > 0 then
                local bh = math.max(cell, Yend(e.time + fx) - Ytop(e.time))
                local blk = PL.Tex("BACKGROUND", 5); Tex(blk, sc, pat and 0.22 or 0.45); blk:SetSize(ROW, bh)
                blk:SetPoint("TOP", pf, "TOPLEFT", rx, -Ytop(e.time))
                if pat then
                    local bp = PL.Tex("BACKGROUND", 6); LK.Pattern(bp, pat, sc, 0.9); bp:SetSize(ROW, bh); bp:SetPoint("TOP", pf, "TOPLEFT", rx, -Ytop(e.time))
                end
                -- the same window, faintly, across the damage it covers
                local ov = PL.Tex("ARTWORK", 1); Tex(ov, sc, 0.10); ov:SetSize(L_.x - DMG_X, math.max(cell, Yend(e.time + fx) - Ytop(e.time)))
                ov:SetPoint("TOPLEFT", pf, "TOPLEFT", DMG_X, -Ytop(e.time))
            end
        end
        for _, e in ipairs(L_.items) do
            local cc = EntryColor(note, e)
            if pal == 0 then Col(nm, cc) end
            n = n + 1
            local b = PL.Icon(n); b.e = e; b.palette = false; b.conflict = false
            local sz = e.major and 20 or 16
            local cx = L_.x + LOFF + (e.plCol - 0.5) * ROW
            b:SetSize(sz, sz); b:ClearAllPoints()
            b:SetPoint("CENTER", pf, "TOPLEFT", cx, -Y(e.time))
            b.tex:SetTexture(SpellTexture(e.spellID or 0) or 134400)
            local key = L_.li .. ":" .. (e.spellID or 0)
            if last[key] and (e.cd or 0) > 0 and e.time - last[key].time < e.cd - 0.5 then
                b.conflict = string.format("%d s after the last one (cooldown %d s)", math.floor(e.time - last[key].time), e.cd)
            end
            last[key] = e
            if b.conflict then b:SetBackdropBorderColor(LK.CB.vermillion[1], LK.CB.vermillion[2], LK.CB.vermillion[3], 1)
            elseif e == PL.dragging then b:SetBackdropBorderColor(1, 1, 1, 1)
            else local sc = PL.SpellColor(note, e); b:SetBackdropBorderColor(sc[1], sc[2], sc[3], 1) end
            b.tex:SetDesaturated(e.noLink and true or false)
            b:Show()
            if e == PL.dragging then f.drag:ClearAllPoints(); f.drag:SetPoint("LEFT", b, "RIGHT", 4, 0) end
            local hb = LK.linkOf[e]
            if hb then
                local l = PL.Line(); l:SetColorTexture(cc[1], cc[2], cc[3], e.major and 0.65 or 0.35); l:SetThickness(1)
                l:SetStartPoint("TOPLEFT", pf, cx - sz / 2, -Y(e.time)); l:SetEndPoint("TOPLEFT", pf, EV_X + 7, -Y(LK.HitTime(hb)))
            end
            -- header palette: up to 3 of the column's own cooldowns, drag them down to add a cast
            if e.spellID and (e.cd or 0) >= 30 then
                L_.palSeen = L_.palSeen or {}
                if not L_.palSeen[e.spellID] and pal < 8 then
                    L_.palSeen[e.spellID] = true
                    PL.palN = PL.palN + 1
                    local p = PL.pal[PL.palN]
                    if not p then p = PL.Icon(1000 + PL.palN); PL.pal[PL.palN] = p end
                    p.e = e; p.palette = true; p.conflict = false; p:SetSize(18, 18); p:ClearAllPoints()
                    p:SetPoint("BOTTOM", pf, "TOPLEFT", L_.x + LOFF + (e.plCol - 0.5) * ROW, 4)
                    p.tex:SetTexture(SpellTexture(e.spellID) or 134400); p.tex:SetDesaturated(false); local sc = PL.SpellColor(note, e); p:SetBackdropBorderColor(sc[1], sc[2], sc[3], 0.8); p:Show()
                    pal = pal + 1
                end
            end
        end
        L_.palSeen = nil
    end

    local pct = allDmg > 0 and math.floor(covDmg / allDmg * 100 + 0.5) or 0
    f.stats:SetText(string.format("Big hits covered  |cffffffff%d/%d|r     Damage under a major CD  |cffffffff%d%%|r     Cooldowns add  |cffffffff%s|r     Your HPS  |cffffffff%s|r%s",
        covered, #evs, pct, LK.FmtK(gainTotal), LK.FmtK(H), mine and "" or " (top-8 Mythic, /tl hps to set yours)"))
    PL.DrawSides(note, lanes, dur, H, mine)
    PL.SyncBossBar()
    if f.mirror and f.mirror.SetBackdropBorderColor then
        local cc = DB.plMirror and T.goldHi or T.border
        f.mirror:SetBackdropBorderColor(cc[1], cc[2], cc[3], 1)
    end
end

function ns.PlanChanged()
    local note = PL.f and PL.f.note
    if note and note.unsaved then
        note.unsaved = nil
        DB.notes[note.encounterID] = DB.notes[note.encounterID] or {}
        DB.notes[note.encounterID][note.difficultyID] = note
        DB.lastImport = { encounterID = note.encounterID, difficultyID = note.difficultyID }
        Print("Saved as your %s plan for %s.", DIFF_NAME[note.difficultyID] or "", note.name or "this boss")
    end
    if note then
        SortEntries(note.entries)
        LK.Link(note.entries)
        if note.curves and note.curves.dmg then note.curves.dmg.peak = nil end
    end
    if PL.f and PL.f:IsShown() then PL.Draw() end
    if ns.ApplyGraphLayout then ns.ApplyGraphLayout() end
end


------------------------------------------------------------------------
-- Boss bar: every boss of the tier in order (raids, then lairs). Click one: your plan for it, or the built-in
-- damage profile as a preview with a column for you to drag your cooldowns into (saved once you change it).
------------------------------------------------------------------------
local function instTag(name)
    local t = {}
    for w in (name or ""):gmatch("[%w']+") do
        if w:lower() == "of" then t[#t + 1] = "o" elseif w:lower() ~= "the" then t[#t + 1] = w:sub(1, 1):upper() end
    end
    return table.concat(t)
end
function PL.TierBosses()
    if PL.tier then return PL.tier end
    if not (EJ_GetNumTiers and EJ_SelectTier and EJ_GetInstanceByIndex) then return {} end
    if EncounterJournal and EncounterJournal.IsShown and EncounterJournal:IsShown() then return {} end   -- don't move the open guide
    local saved = EJ_GetCurrentTier and EJ_GetCurrentTier()
    local out = {}
    BUILTIN.Load()
    local ok = pcall(function()
        EJ_SelectTier(EJ_GetNumTiers())
        local i = 1
        while true do
            local instID, iname = EJ_GetInstanceByIndex(i, true)
            if not instID then break end
            EJ_SelectInstance(instID)
            local bosses, known = {}, false
            local j = 1
            while true do
                local name, _, jEnc, _, _, _, dEnc = EJ_GetEncounterInfoByIndex(j, instID)
                if not name then break end
                local icon
                if EJ_GetCreatureInfo then icon = select(5, EJ_GetCreatureInfo(1, jEnc)) end
                bosses[#bosses + 1] = { name = name, enc = dEnc, inst = iname, tag = instTag(iname), idx = j, icon = icon }
                if dEnc and ((SmilerFights and SmilerFights[dEnc]) or DB.notes[dEnc]) then known = true end
                j = j + 1
            end
            if known then for _, b in ipairs(bosses) do out[#out + 1] = b end end
            i = i + 1
        end
    end)
    if saved then pcall(EJ_SelectTier, saved) end
    if ok and #out > 0 then PL.tier = out end
    return out
end

-- a fresh copy of the built-in fight with one empty column for you
function PL.PreviewFromBuiltin(encID, diff)
    if not BUILTIN.Load() then return nil end
    local byDiff = SmilerFights[encID]
    if not byDiff then return nil end
    local d = (byDiff[diff] and diff) or (byDiff[15] and 15) or (byDiff[16] and 16)
    if not d then return nil end
    local ok, n = pcall(ParseNote, byDiff[d])
    if not ok or not n then return nil end
    n.encounterID, n.difficultyID, n.unsaved = encID, d, true
    local cls = PC.PlayerClassKey()
    n.lanes[#n.lanes + 1] = { id = "me", name = UnitName("player") or "You", kind = "raid", color = CLASS_RGB[cls or ""] }
    UpgradeNote(n); LK.CleanNote(n)
    return n
end

function PL.OpenBoss(b)
    local f = PL.f
    local diff = PL.diff or (f.note and f.note.difficultyID) or 15
    local mine = DB.notes[b.enc]
    local note = mine and (mine[diff] or (not (SmilerFights and SmilerFights[b.enc] and SmilerFights[b.enc][diff]) and select(2, next(mine))))
    if not note then note = PL.PreviewFromBuiltin(b.enc, diff) end
    if not note then Print("No plan or built-in damage profile for %s yet.", b.name) return end
    UpgradeNote(note); LK.CleanNote(note)
    f.note = note
    if not note.unsaved then DB.lastImport = { encounterID = note.encounterID, difficultyID = note.difficultyID } end
    PL.Draw()
    if ns.ApplyGraphLayout then ns.ApplyGraphLayout() end
end

function PL.BuildBossBar(f)
    local bar_ = CreateFrame("Frame", nil, f)
    bar_:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -40); bar_:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -40); bar_:SetHeight(PL.PORT_H + 18)
    bar_.btns, bar_.tags = {}, {}
    f.bossBar = bar_
    local function diffBtn(label, d)
        local b = FlatButton(bar_, label, label == "LFR" and 36 or 30, 20); b.d = d
        b:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:SetText(DIFF_NAME[d] or label, 1, 1, 1)
            local cur = f.note
            local has = cur and DB.notes[cur.encounterID] and DB.notes[cur.encounterID][d]
            GameTooltip:AddLine(has and "You have a plan for this boss on this difficulty" or "No plan of yours for this boss on this difficulty (preview or import one)", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        b:HookScript("OnLeave", function() GameTooltip:Hide() end)
        b:SetScript("OnClick", function() PL.diff = d
            local cur = f.note
            if cur and cur.encounterID then
                for _, x in ipairs(PL.TierBosses()) do if x.enc == cur.encounterID then PL.OpenBoss(x) return end end
            end
            PL.SyncBossBar()
        end)
        return b
    end
    bar_.lfr = diffBtn("LFR", 17); bar_.n = diffBtn("N", 14); bar_.h = diffBtn("H", 15); bar_.m = diffBtn("M", 16)
    bar_.m:SetPoint("TOPRIGHT", bar_, "TOPRIGHT", 0, -12); bar_.h:SetPoint("RIGHT", bar_.m, "LEFT", -3, 0)
    bar_.n:SetPoint("RIGHT", bar_.h, "LEFT", -3, 0); bar_.lfr:SetPoint("RIGHT", bar_.n, "LEFT", -3, 0)
end

function PL.SyncBossBar()
    local f = PL.f
    local bar_ = f and f.bossBar
    if not bar_ then return end
    local list = PL.TierBosses()
    local x, lastTag = 0, nil
    local cur = f.note and f.note.encounterID
    for _, t in ipairs(bar_.tags) do t:Hide() end
    local nt = 0
    for i, b in ipairs(list) do
        if b.tag ~= lastTag then
            if lastTag then x = x + 8 end
            nt = nt + 1
            local t = bar_.tags[nt]
            if not t then t = bar_:CreateFontString(nil, "OVERLAY"); ApplyFont(t, 10); Col(t, T.muted); bar_.tags[nt] = t end
            t:ClearAllPoints(); t:SetPoint("TOPLEFT", bar_, "TOPLEFT", x, 0); t:SetText(b.tag); t:Show()
            lastTag = b.tag
        end
        local btn = bar_.btns[i]
        if not btn then
            btn = CreateFrame("Button", nil, bar_, "BackdropTemplate")
            btn:SetSize(PL.PORT_W, PL.PORT_H)
            btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            btn.tex = btn:CreateTexture(nil, "ARTWORK"); btn.tex:SetPoint("TOPLEFT", 1, -1); btn.tex:SetSize(PL.PORT_W - 2, (PL.PORT_W - 2) / 2)
            btn.tex:SetTexCoord(0, 1, 0, 1)        -- the journal's boss portraits are 2:1 (128x64): shown whole, not squashed
            btn.n = btn:CreateFontString(nil, "OVERLAY"); ApplyFont(btn.n, 11, "OUTLINE"); btn.n:SetPoint("TOPRIGHT", -3, -3)
            btn.dot = btn:CreateTexture(nil, "OVERLAY"); btn.dot:SetSize(6, 6); btn.dot:SetPoint("TOPLEFT", 3, -3)
            -- status word under the portrait, like the loot planner's tiles (text, not colour alone)
            btn.t = btn:CreateFontString(nil, "OVERLAY"); ApplyFont(btn.t, 10); btn.t:SetPoint("BOTTOM", 0, 4); btn.t:SetWidth(PL.PORT_W - 2); btn.t:SetJustifyH("CENTER")
            btn:SetScript("OnClick", function(self) PL.OpenBoss(self.b) end)
            btn:SetScript("OnEnter", function(self)
                local bb = self.b
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
                GameTooltip:AddLine(bb.name); GameTooltip:AddLine(bb.inst .. "  ·  boss " .. bb.idx, 0.8, 0.8, 0.8)
                local mine = DB.notes[bb.enc]
                if mine then GameTooltip:AddLine("You have a plan (MY PLAN)", 0.4, 0.9, 0.5)
                elseif SmilerFights and SmilerFights[bb.enc] then GameTooltip:AddLine("Built-in damage profile: click to preview and add your cooldowns", 0.6, 0.8, 1, true)
                else GameTooltip:AddLine("No data yet", 0.6, 0.6, 0.6) end
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            bar_.btns[i] = btn
        end
        btn.b = b
        btn:ClearAllPoints(); btn:SetPoint("TOPLEFT", bar_, "TOPLEFT", x, -14)
        btn.tex:SetTexture(b.icon or "Interface\\EncounterJournal\\UI-EJ-BOSS-Default")
        btn.n:SetText(b.idx)
        local sel = cur == b.enc
        local cc = sel and T.goldHi or T.border
        btn:SetBackdropColor(0, 0, 0, 0.6); btn:SetBackdropBorderColor(cc[1], cc[2], cc[3], sel and 1 or 0.5)
        local mine = DB.notes[b.enc]
        btn.dot:SetShown(mine ~= nil); btn.dot:SetColorTexture(0.0, 0.9, 0.46, 1)
        local prof = SmilerFights and SmilerFights[b.enc]
        btn.tex:SetDesaturated(not mine and not prof); btn.tex:SetAlpha((mine or prof) and 1 or 0.5)
        if mine then btn.t:SetText("MY PLAN"); btn.t:SetTextColor(0.0, 0.9, 0.46)
        elseif prof then btn.t:SetText("preview"); btn.t:SetTextColor(0.6, 0.8, 1)
        else btn.t:SetText("no data"); btn.t:SetTextColor(0.55, 0.55, 0.55) end
        btn:Show()
        x = x + PL.PORT_W + 4
    end
    PL.barW = x + 150
    for i = #list + 1, #bar_.btns do bar_.btns[i]:Hide() end
    local d = PL.diff or (f.note and f.note.difficultyID) or 15
    local curEnc = f.note and f.note.encounterID
    for _, b in ipairs({ bar_.lfr, bar_.n, bar_.h, bar_.m }) do
        local on = b.d == d
        local cc = on and T.goldHi or T.border
        if b.SetBackdropBorderColor then b:SetBackdropBorderColor(cc[1], cc[2], cc[3], 1) end
        -- dimmed when neither a plan of yours nor a built-in profile exists for this boss on that difficulty
        local has = curEnc and ((DB.notes[curEnc] and DB.notes[curEnc][b.d]) or (SmilerFights and SmilerFights[curEnc] and SmilerFights[curEnc][b.d]))
        if b.fs then b.fs:SetAlpha((has or on) and 1 or 0.45) end
    end
end

------------------------------------------------------------------------
-- Side panels: boss abilities (left) and healing cooldowns (right), to plan against
------------------------------------------------------------------------
function PL.BuildSides(f)
    local function side(anchor, rel, dx)
        local p = CreateFrame("Frame", nil, f, "BackdropTemplate")
        p:SetWidth(PL.SIDE_W)
        p:SetPoint(anchor, f, rel, dx, 0)
        p:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
        p:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        p:SetBackdropColor(T.bg[1], T.bg[2], T.bg[3], 0.96); p:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], 0.6)
        p.title = p:CreateFontString(nil, "OVERLAY"); ApplyFont(p.title, 12); Col(p.title, T.goldHi); p.title:SetPoint("TOPLEFT", 12, -12)
        p.sub = p:CreateFontString(nil, "OVERLAY"); ApplyFont(p.sub, 10); Col(p.sub, T.muted); p.sub:SetPoint("TOPLEFT", 12, -30)
        p.sub:SetWidth(PL.SIDE_W - 24); p.sub:SetJustifyH("LEFT")
        p.rows = {}
        return p
    end
    f.left = side("TOPRIGHT", "TOPLEFT", -6)
    f.right = side("TOPLEFT", "TOPRIGHT", 6)
    f.left.title:SetText("BOSS ABILITIES"); f.right.title:SetText("HEALING")
end

local function sideRow(p, i)
    local r = p.rows[i]
    if not r then
        r = CreateFrame("Frame", nil, p)
        r:SetSize(PL.SIDE_W - 24, 30)
        r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(18, 18); r.icon:SetPoint("TOPLEFT", 0, -2); r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.a = r:CreateFontString(nil, "OVERLAY"); ApplyFont(r.a, 11); Col(r.a, T.fg); r.a:SetPoint("TOPLEFT", 24, 0); r.a:SetPoint("RIGHT", -70, 0); r.a:SetJustifyH("LEFT"); r.a:SetWordWrap(false)
        r.v = r:CreateFontString(nil, "OVERLAY"); ApplyFont(r.v, 11); r.v:SetPoint("TOPRIGHT", 0, 0); r.v:SetJustifyH("RIGHT")
        r.b = r:CreateFontString(nil, "OVERLAY"); ApplyFont(r.b, 10); Col(r.b, T.muted); r.b:SetPoint("TOPLEFT", 24, -14); r.b:SetPoint("RIGHT", 0, 0); r.b:SetJustifyH("LEFT"); r.b:SetWordWrap(false)
        r.hl = r:CreateTexture(nil, "BACKGROUND"); r.hl:SetAllPoints(); r.hl:SetColorTexture(1, 1, 1, 0.06); r.hl:Hide()
        r:EnableMouse(true)
        r:SetScript("OnEnter", function(self)
            self.hl:Show()
            if not self.tip then return end
            GameTooltip:SetOwner(self, p == PL.f.left and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
            self.tip(GameTooltip)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function(self) self.hl:Hide(); GameTooltip:Hide() end)
        p.rows[i] = r
    end
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -50 - (i - 1) * 34)
    return r
end

-- "1:00, then every 30 s (x6)" or the times, when they aren't regular
local function cadence(times)
    if #times == 1 then return FmtClock(times[1]) .. " (once)" end
    local gaps, sum = {}, 0
    for i = 2, #times do gaps[#gaps + 1] = times[i] - times[i - 1]; sum = sum + gaps[#gaps] end
    local mean = sum / #gaps
    local dev = 0
    for _, g in ipairs(gaps) do dev = math.max(dev, math.abs(g - mean)) end
    if dev <= math.max(3, mean * 0.15) then
        return string.format("%s, then every %d s (x%d)", FmtClock(times[1]), math.floor(mean + 0.5), #times)
    end
    local t = {}
    for i = 1, math.min(#times, 5) do t[i] = FmtClock(times[i]) end
    return table.concat(t, ", ") .. (#times > 5 and (", ... (x" .. #times .. ")") or "")
end

function PL.DrawSides(note, lanes, dur, H, mine)
    local f = PL.f
    if not f.left then return end
    for _, p in ipairs({ f.left, f.right }) do for _, r in ipairs(p.rows) do r:Hide() end end
    local maxRows = math.max(4, math.floor((f:GetHeight() - 70) / 34))
    -- boss abilities: grouped by name, hardest-hitting first
    local groups, order = {}, {}
    for _, b in ipairs(PL.hits or {}) do
        local nm = LK.HitName(b)
        local g = groups[nm]
        if not g then g = { name = nm, times = {}, peak = 0, sum = 0, spell = b.spellID, major = false }; groups[nm] = g; order[#order + 1] = g end
        local t = LK.HitTime(b)
        if t then
            g.times[#g.times + 1] = t
            local mv = 0
            for tt = t, t + 6, 1 do local v = LK.CurveAt(note, "dmg", tt) or 0; if v > mv then mv = v end end
            g.sum = g.sum + mv; g.peak = math.max(g.peak, mv)
        end
        if b.major then g.major = true end
    end
    for _, g in ipairs(order) do table.sort(g.times); g.avg = #g.times > 0 and g.sum / #g.times or 0 end
    local anyMajor = false
    for _, g in ipairs(order) do if g.major then anyMajor = true end end
    for _, g in ipairs(order) do if not anyMajor then g.major = true end end
    table.sort(order, function(a, b) if (a.major and 1 or 0) ~= (b.major and 1 or 0) then return a.major end return a.avg > b.avg end)
    f.left.sub:SetText("Raid damage in the 6 s after each cast (k/s), biggest first. Times are when it lands.")
    for i = 1, math.min(#order, maxRows) do
        local g, r = order[i], sideRow(f.left, i)
        r.icon:SetTexture(SpellTexture(g.spell or 0) or 134400)
        r.a:SetText((g.major and "" or "|cff999999") .. g.name)
        r.v:SetText(LK.FmtK(g.avg) .. "/s"); Col(r.v, g.major and LK.CB.orange or T.muted)
        r.b:SetText(cadence(g.times))
        r.tip = function(tt)
            if g.spell and g.spell > 0 and tt.SetSpellByID then tt:SetSpellByID(g.spell) else tt:AddLine(g.name, 1, 1, 1) end
            tt:AddLine(" ")
            tt:AddDoubleLine("Raid damage after it lands", LK.FmtK(g.avg) .. "/s average, " .. LK.FmtK(g.peak) .. "/s worst", 1, 0.82, 0, 1, 1, 1)
            tt:AddDoubleLine("Casts", tostring(#g.times), 1, 0.82, 0, 1, 1, 1)
            local t = {}
            for k, v in ipairs(g.times) do t[k] = FmtClock(v) end
            tt:AddLine("Lands at: " .. table.concat(t, ", "), 0.8, 0.8, 0.8, true)
            tt:AddLine("From the raid damage curve in the 6 s after each cast lands.", 0.6, 0.6, 0.6, true)
        end
        r:Show()
    end
    -- healing: everyday throughput, then each cooldown with what it adds and how often it can go
    local cls = PC.PlayerClassKey()
    local spells, seen = {}, {}
    for _, grp in ipairs(LK.CLASS_SPELLS[cls or ""] or {}) do
        if grp[1]:find("Healing") then for _, id in ipairs(grp[2]) do if not seen[id] then seen[id] = true; spells[#spells + 1] = id end end end
    end
    for _, L_ in ipairs(lanes or {}) do for _, e in ipairs(L_.items) do
        if e.major and e.spellID and not seen[e.spellID] then seen[e.spellID] = true; spells[#spells + 1] = e.spellID end end end
    local rows_ = {}
    for _, id in ipairs(spells) do
        local g = LK.CdGain(note, { spellID = id, time = math.min(60, dur / 2) })
        local planned = 0
        for _, e in ipairs(note.entries) do if e.spellID == id and not e.isBoss then planned = planned + 1 end end
        local cd = LK.CDLEN[id]
        local can = cd and (math.floor(math.max(0, dur - 5) / cd) + 1) or nil
        rows_[#rows_ + 1] = { id = id, g = g, cd = cd, planned = planned, can = can }
    end
    table.sort(rows_, function(a, b) return (a.g and a.g.total or 0) > (b.g and b.g.total or 0) end)
    f.right.sub:SetText(string.format("Everyday healing: %s/s each %s, x%d healers = %s/s (/tl healers N).",
        LK.FmtK(H), mine and "(yours)" or "(top-8 Mythic, /tl hps to set yours)", PL.healers or 1, LK.FmtK(H * (PL.healers or 1))))
    f.right.sub:SetWordWrap(true)
    local n = 0
    for _, x in ipairs(rows_) do
        n = n + 1
        if n > maxRows then break end
        local r = sideRow(f.right, n)
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", f.right, "TOPLEFT", 12, -60 - (n - 1) * 34)
        r.icon:SetTexture(SpellTexture(x.id) or 134400)
        r.a:SetText(SpellName(x.id) or tostring(x.id))
        local g = x.g
        if g then
            r.v:SetText((g.kind == "prevent" and "-" or "+") .. LK.FmtK(g.total)); Col(r.v, LK.CB.sky)
            r.b:SetText(string.format("%s%s/s for %d s  ·  CD %s  ·  planned %d%s", g.kind == "prevent" and "prevents " or "+", LK.FmtK(g.rate),
                math.floor(g.to - g.from + 0.5), x.cd and FmtClock(x.cd) or "?", x.planned, x.can and (" of " .. x.can) or ""))
        else
            r.v:SetText(""); r.b:SetText(string.format("no throughput estimate  ·  CD %s  ·  planned %d%s", x.cd and FmtClock(x.cd) or "?", x.planned, x.can and (" of " .. x.can) or ""))
        end
        r.tip = function(tt)
            if tt.SetSpellByID then tt:SetSpellByID(x.id) else tt:AddLine(SpellName(x.id) or tostring(x.id), 1, 1, 1) end
            tt:AddLine(" ")
            if g then
                tt:AddDoubleLine(g.kind == "prevent" and "Prevents" or "Adds", string.format("%s/s for %d s = %s", LK.FmtK(g.rate), math.floor(g.to - g.from + 0.5), LK.FmtK(g.total)), 1, 0.82, 0, 1, 1, 1)
                local m = LK.THRU[x.id]
                if m and m.src then tt:AddLine(m.src, 0.6, 0.6, 0.6, true) end
            else
                tt:AddLine("No throughput estimate for this spell yet.", 0.6, 0.6, 0.6)
            end
            tt:AddDoubleLine("Cooldown", x.cd and FmtClock(x.cd) or "?", 1, 0.82, 0, 1, 1, 1)
            tt:AddDoubleLine("Planned in this fight", x.planned .. (x.can and (" of " .. x.can .. " possible") or ""), 1, 0.82, 0, 1, 1, 1)
            local times = {}
            for _, e in ipairs(note.entries) do if e.spellID == x.id and not e.isBoss and e.time then times[#times + 1] = FmtClock(e.time) end end
            if #times > 0 then tt:AddLine("At: " .. table.concat(times, ", "), 0.8, 0.8, 0.8, true) end
        end
        r:Show()
    end
end

function PL.Show(arg)
    if InCombatLockdown() then Print("The boss summary opens out of combat.") return end
    local f = PL.f or PL.Build()
    local note
    arg = (arg or ""):lower()
    if arg ~= "" then
        for _, n in ipairs(PL.List()) do
            if (n.name or ""):lower():find(arg, 1, true) and (not note or n.difficultyID == 15) then note = n end
        end
        if not note then Print("No stored plan matches '%s'. /tl plans lists them.", arg) end
    end
    note = note or PL.Note() or PL.List()[1]
    if not note then local tb = PL.TierBosses()[1]; note = tb and PL.PreviewFromBuiltin(tb.enc, PL.diff or 15) end
    if note then UpgradeNote(note); LK.CleanNote(note) end
    f.note = note
    f:Show()
    PL.Draw()
    if C_Timer and C_Timer.After then C_Timer.After(0, function() if f:IsShown() and f.note == note then PL.Draw() end end) end
end
ns.ShowPlanner = PL.Show
ns.PL = PL

PL.dragFrame = CreateFrame("Frame")
PL.dragFrame:Hide()                       -- runs only while a cooldown is being dragged (see PL.Icon)
PL.dragFrame:SetScript("OnUpdate", function()
    local e = PL.dragging
    if not e or not PL.f or not PL.f:IsShown() then PL.dragFrame:Hide(); return end
    if not IsMouseButtonDown("LeftButton") then
        PL.dragging = nil
        PL.dragFrame:Hide()
        PL.f.drag:SetText("")
        if e.time <= 0.5 and e.added then
            for i, x in ipairs(PL.f.note.entries) do if x == e then table.remove(PL.f.note.entries, i) break end end
        end
        ns.PlanChanged()
        return
    end
    local t, hit = PL.Snap(e, PL.CursorTime())
    if math.abs(t - e.time) > 0.05 then
        e.time = t; e.rel = t
        e.anchor = nil
        PL.Draw()
    end
    PL.f.drag:SetText(string.format("%s%s", FmtClock(e.time), hit and ("  > " .. LK.HitName(hit)) or (IsShiftKeyDown() and "  free" or "")))
end)

local function Help()
    Print("commands:")
    print("  /tl options           the options window (every setting, click-through);  /tl plans  opens it on the Plans page")
    print("  /tl select <id> [diff]  pick a stored plan for test / phases / assign;  /tl use <id> [diff]  pin it for pull timers")
    print("  /tl graph | graph all | graphsize <w> <h> | graphpos reset   the fight graph (top right)")
    print("  /tl import            open the paste window")
    print("  /tl test [offset]     play the last-imported note (optionally starting N seconds in)")
    print("  /tl stop              stop a test run")
    print("  /tl phase <n>         mark stage n as starting now (BigWigs / DBM stage changes do this automatically)")
    print("  /tl phases [0,95,200] show or set the phase start times for the last import (Viserio strings are phase-relative)")
    print("  /tl pull [sec]        simulate a pull timer (default 10) to test arming")
    print("  /tl use <encID>       which boss pull timers arm (default: last fought, else last imported)")
    print("  /tl pulltimer         toggle arming from pull timers (Blizzard countdown / DBM / BigWigs)")
    print("  /tl assign <encID>    bind the last import (e.g. a Viserio plan) to a boss; /tl last shows the last ID")
    print("  /tl bw                toggle BigWigs live boss timers in the Boss lane")
    print("  /tl lock | unlock     lock / unlock (drag) the bar")
    print("  /tl show | hide | toggle   show or hide the bar (a hidden bar still tracks the fight)")
    print("  /tl list              stored notes")
    print("  /tl delete <encID>    remove a stored boss")
    print("  /tl window <sec>      seconds visible above the now line (default 30)")
    print("  /tl imminent <sec>    size of the fast bottom zone (default 5)")
    print("  /tl size <px>         icon size (default 28)")
    print("  /tl major <scale>     how much larger major cooldowns draw (default 1.35)")
    print("  /tl layout stack|hud|single|lanes   stack (default): inverted T - boss abilities left of the stalk, my cooldowns right, each in its own column")
    print("  /tl stacksize <w> <h>;  /tl rowicon <px>;  /tl bosslane <px>;  /tl linear;  /tl all (also show other players' casts)")
    print("  /tl track add <spellID> [other]   add to the Major (or Other) group;  /tl track remove <spellID>;  /tl track reset;  /tl track lists")
    print("  /tl mine              (hud/single/lanes) toggle the own-cooldowns column beside the plan bar; drag it when unlocked")
    print("  /tl minepos reset     re-attach the column to the plan bar;  /tl mineoffset <px>  gap when attached")
    print("  /tl sched | ready | combat | border | swipe | numbers   column: plan's scheduled casts / dock ready spells / combat only / borders / sweep / number style")
    print("  /tl debug             what the column sees right now (secret or readable cooldowns, model state)")
    print("  /tl minesize <icon px> <height px>   column sizes (default 36; height 380 only when free-standing)")
    print("  /tl depth <n>         perspective strength (default 3);  /tl far <px> far-end icon size;  /tl slot <px> near/slot size")
    print("  /tl hudsize <w> <h>;  /tl crosshair;  /tl rails (guide lines);  /tl plate (slot backing)")
    print("  /tl cols <px>         Cooldowns column width (default 232);  /tl bosscols <px>  Boss column")
    print("  /tl labels <px>       text width beside icons (default 76; 0 = icons only)")
    print("  /tl font <name>       bundled (Barlow Condensed) | condensed | barlow | dejavu | poppins | any LibSharedMedia font;  /tl fonts;  /tl fontsize <n>;  /tl outline")
    print("  /tl height <px>       bar height (default 420)")
    print("  /tl headers | ticks   toggle lane headers / time tick lines")
    print("  /tl alpha <0-1>       bar background opacity")
    print("  /tl names | time | onlymine   toggle name labels / countdown / only-my-cooldowns on the plan bar")
    print("  /tl plan              planner: damage curve, boss hits, drag cooldowns onto hits, export")
    print("  /tl hps <k>           your healing per second (e.g. 250) - scales cooldown estimates")
    print("  /tl graphbg           fight graph background on/off")
    print("  /tl follow            re-time the plan from BigWigs bars, so cooldowns stay on their hit")
    print("  /tl links | dmgshow | dmgscale | planboss   toggle CD->hit lines / damage text / icon size by damage / plan boss rows")
    print("  /tl reset             reset settings (keeps notes)")
end

local function Slash(msg)
    msg = (msg or ""):match("^%s*(.-)%s*$")
    local cmd, arg = msg:match("^(%S+)%s*(.-)$")
    cmd = (cmd or ""):lower()

    if cmd == "" or cmd == "help" then
        Help()
    elseif cmd == "import" then
        ShowImport()
    elseif cmd == "options" or cmd == "config" or cmd == "o" then
        ShowOptions(tonumber(arg))
    elseif cmd == "plans" or cmd == "loaded" then
        ShowOptions(4)
    elseif cmd == "plan" or cmd == "planner" then
        ns.ShowPlanner(arg)
    elseif cmd == "healers" then
        local n = tonumber(arg)
        if n and n >= 1 and n <= 10 then DB.plHealers = math.floor(n); Print("Planner assumes %d healers in the raid.", DB.plHealers); if PL.f and PL.f:IsShown() then PL.Draw() end
        else Print("Usage: /tl healers <1-10> - how many healers the planner's mirror view and healing summary assume (now %d).", DB.plHealers or 4) end
    elseif cmd == "links" then
        DB.links = not DB.links; if not DB.links and ns.HideLinks then ns.HideLinks() end; if ns.ApplyGraphLayout then ns.ApplyGraphLayout() end; Print("Cooldown -> boss hit lines %s.", DB.links and "on" or "off")
    elseif cmd == "dmgshow" then
        DB.dmgShow = not DB.dmgShow; Print("Expected damage on boss icons %s.", DB.dmgShow and "on" or "off")
    elseif cmd == "dmgscale" then
        DB.dmgScale = not DB.dmgScale; Print("Boss icons sized by expected damage %s.", DB.dmgScale and "on" or "off")
    elseif cmd == "hps" then
        local v = tonumber((arg or ""):match("^(%d+%.?%d*)"))
        if v then DB.myHps = v; Print("Your HPS set to %sk/s - cooldown estimates scale to it.", v); ns.PlanChanged()
        elseif arg == "clear" or arg == "reset" then DB.myHps = nil; Print("Using the top-8 Mythic reference again."); ns.PlanChanged()
        else Print("Usage: /tl hps <thousands per second>  e.g. /tl hps 250   (now %s)", DB.myHps and (DB.myHps .. "k") or "top-8 reference") end
    elseif cmd == "graphfont" or cmd == "graphicon" or cmd == "graphalpha" then
        local v = tonumber(arg)
        local key, lo, hi = ({ graphfont = { "graphFont", 7, 24 }, graphicon = { "graphIcon", 8, 40 }, graphalpha = { "graphAlpha", 0, 1 } })[cmd][1], ({ graphfont = 7, graphicon = 8, graphalpha = 0 })[cmd], ({ graphfont = 24, graphicon = 40, graphalpha = 1 })[cmd]
        if v and v >= lo and v <= hi then DB[key] = v; ApplyGraphLayout() else Print("Usage: /tl %s <%s-%s>  (now %s)", cmd, lo, hi, tostring(DB[key])) end
    elseif cmd == "graphtips" then
        DB.graphTips = (DB.graphTips == false); Print("Graph tooltips %s.", DB.graphTips and "on" or "off")
    elseif cmd == "graphvert" then
        DB.graphVertical = (DB.graphVertical == false); ApplyGraphLayout(); Print("Fight graph: %s.", DB.graphVertical and "vertical (time runs down)" or "horizontal")
    elseif cmd == "graphspan" or cmd == "graphnow" or cmd == "vgsize" or cmd == "graphblocks" then
        local a, b = arg:match("^(%S+)%s*(%S*)")
        a, b = tonumber(a), tonumber(b)
        if cmd == "graphspan" and a and a >= 30 and a <= 600 then DB.vgSpan = a
        elseif cmd == "graphnow" and a and a >= 0.05 and a <= 0.8 then DB.vgNow = a
        elseif cmd == "graphblocks" and a and a >= 4 and a <= 40 then DB.vgBlocks = a
        elseif cmd == "vgsize" and a and b then DB.vgWidth, DB.vgHeight = a, b
        else Print("Usage: /tl graphspan <30-600> | graphnow <0.05-0.8> | graphblocks <4-40> | vgsize <w> <h>"); return end
        ApplyGraphLayout()
    elseif cmd == "graphtitle" or cmd == "graphboss" or cmd == "graphlegend" then
        local key = ({ graphtitle = "graphTitle", graphboss = "graphBoss", graphlegend = "graphLegend" })[cmd]
        DB[key] = (DB[key] == false); ApplyGraphLayout(); Print("Graph %s %s.", cmd:sub(6), DB[key] and "shown" or "hidden")
    elseif cmd == "graphbg" then
        DB.graphBg = not DB.graphBg; ApplyGraphLayout(); Print("Fight graph background %s.", DB.graphBg and "on" or "off - blocks float over the game")
    elseif cmd == "follow" then
        DB.follow = not DB.follow; Print("Follow the fight (re-time the plan from BigWigs bars): %s.", DB.follow and "on" or "off")
    elseif cmd == "planboss" then
        DB.planBoss = not DB.planBoss; Print("Boss rows: %s.", DB.planBoss and "the plan's own (timed to the hit)" or "BigWigs bars when available")
    elseif cmd == "anchorchat" then
        DB.anchorChat = not DB.anchorChat; Print("Anchor chat %s.", DB.anchorChat and "on" or "off")
    elseif cmd == "graph" then
        if arg == "all" then DB.graphAll = not DB.graphAll; ApplyGraphLayout(); Print("Graph rows: %s.", DB.graphAll and "every healer" or "me (and the boss)")
        else DB.graphOn = not DB.graphOn; ApplyGraphLayout(); Print("Fight graph %s.", DB.graphOn and "on" or "off") end
    elseif cmd == "graphsize" then
        local w, h = arg:match("^(%d+)%s+(%d+)$")
        if w then DB.graphWidth = tonumber(w); DB.graphHeight = tonumber(h); ApplyGraphLayout() else Print("Usage: /tl graphsize <width> <height>  (now %d %d)", DB.graphWidth, DB.graphHeight) end
    elseif cmd == "graphpos" then
        DB.graphPoint = nil; ApplyGraphLayout(); Print("Graph back beside the minimap.")
    elseif cmd == "test" then
        local li = DB.lastImport
        local note = li and DB.notes[li.encounterID] and DB.notes[li.encounterID][li.difficultyID]
        if not note then Print("Nothing imported yet - /tl import first."); return end
        note = UpgradeNote(note)
        local offset = tonumber(arg) or 0
        StartEncounter(note, true, offset)
        Print("Test run: %s %s from %ds. /tl stop to end.", note.name or "?", DIFF_NAME[note.difficultyID] or "", offset)
    elseif cmd == "stop" then
        StopEncounter("Stopped.")
    elseif cmd == "phase" or cmd == "stage" then
        local n = tonumber(arg)
        if n then OnStage(n, "manual") else Print("Usage: /tl phase <n>  - mark that stage as starting now (boss mods do this automatically)") end
    elseif cmd == "phases" then
        local li = DB.lastImport
        local note = li and DB.notes[li.encounterID] and DB.notes[li.encounterID][li.difficultyID]
        if not note then Print("Nothing imported."); return end
        if arg ~= "" then
            local t = {}
            for v in arg:gmatch("[^,%s]+") do t[#t + 1] = tonumber(v) end
            note.phaseStarts = {}
            for i, v in ipairs(t) do if v then note.phaseStarts[i] = v end end
            Print("Phase starts for %s set: %s", note.name or "?", arg)
            ApplyGraphLayout()
        else
            local starts, est = EstimatePhaseStarts(note)
            local out = {}
            local top = 0; for p in pairs(starts) do if p > top then top = p end end
            for p = 1, top do out[#out + 1] = string.format("P%d %d:%02d%s", p, math.floor((starts[p] or 0) / 60), math.floor((starts[p] or 0) % 60), est[p] and "?" or "") end
            Print("%s: %s%s", note.name or "?", table.concat(out, "  "), note.phaseRelative and "  (times in the string are phase-relative; ? = estimated - /tl phases 0,95,200 to set them, or they are learned on the next pull)" or "  (absolute times)")
        end
    elseif cmd == "pull" then
        OnPullTimer(tonumber(arg) or 10, "simulated", true)
    elseif cmd == "use" or cmd == "select" then
        local idS, diffS = arg:match("^(%d+)%s*(%a*)$")
        local id = tonumber(idS)
        if id and DB.notes[id] then
            local diffID = DIFF_BY_NAME[(diffS or ""):lower()]
            if not diffID or not DB.notes[id][diffID] then
                diffID = nil
                if DB.lastImport and DB.lastImport.encounterID == id and DB.notes[id][DB.lastImport.difficultyID] then diffID = DB.lastImport.difficultyID end
                if not diffID then for d in pairs(DB.notes[id]) do if not diffID or d > diffID then diffID = d end end end
            end
            local n = DB.notes[id][diffID]
            if cmd == "use" then
                DB.armed = { encounterID = id, difficultyID = diffID }
                DB.lastImport = { encounterID = id, difficultyID = diffID }
                Print("Pull timers will arm %s %s (also selected for /tl test and /tl phases).", n.name or "?", DIFF_NAME[diffID] or "")
            else
                DB.lastImport = { encounterID = id, difficultyID = diffID }
                Print("Selected %s %s for /tl test, /tl phases and /tl assign.", n.name or "?", DIFF_NAME[diffID] or "")
            end
            ApplyGraphLayout()
        elseif arg == "" or arg == "clear" then
            DB.armed = nil; Print("Cleared - pull timers arm the last boss fought, else the selected plan.")
        else
            Print("Usage: /tl use <encounterID> [heroic|mythic|normal|lfr]  (see /tl list), or /tl use clear;  /tl select <id> [diff] picks without pinning")
        end
    elseif cmd == "assign" then
        local id = tonumber(arg)
        local li = DB.lastImport
        local note = li and DB.notes[li.encounterID] and DB.notes[li.encounterID][li.difficultyID]
        if not id then Print("Usage: /tl assign <encounterID>  (last fought: %s)", DB.lastFought and tostring(DB.lastFought.encounterID) or "none")
        elseif not note then Print("Nothing imported to assign.")
        else
            DB.notes[li.encounterID][li.difficultyID] = nil
            if not next(DB.notes[li.encounterID]) then DB.notes[li.encounterID] = nil end
            note.encounterID = id
            if DB.lastFought and DB.lastFought.encounterID == id then note.difficultyID = DB.lastFought.difficultyID or note.difficultyID end
            DB.notes[id] = DB.notes[id] or {}
            DB.notes[id][note.difficultyID] = note
            DB.lastImport = { encounterID = id, difficultyID = note.difficultyID }
            Print("Bound %s to encounter %d (%s).", note.name or "plan", id, DIFF_NAME[note.difficultyID] or "any difficulty")
        end
    elseif cmd == "last" then
        if DB.lastFought then Print("Last encounter: ID %d, %s.", DB.lastFought.encounterID, DIFF_NAME[DB.lastFought.difficultyID] or "?") else Print("No encounter seen yet.") end
    elseif cmd == "bw" then
        DB.bwLive = not DB.bwLive; if DB.bwLive then HookBigWigs() end
        Print("BigWigs live boss timers %s%s.", DB.bwLive and "on" or "off", (DB.bwLive and not BigWigsLoader) and " (BigWigs not detected)" or "")
    elseif cmd == "pulltimer" then
        DB.pullTimer = not DB.pullTimer; Print("Pull-timer arming %s.", DB.pullTimer and "on" or "off")
    elseif cmd == "hide" then
        DB.hidden = true; ApplyBarLayout(); Print("Hidden. /tl show to bring it back.")
    elseif cmd == "show" then
        DB.hidden = false; ApplyBarLayout(); Print("Shown.")
    elseif cmd == "toggle" then
        DB.hidden = not DB.hidden; ApplyBarLayout(); Print(DB.hidden and "Hidden." or "Shown.")
    elseif cmd == "lock" then
        DB.locked = true;  ApplyBarLayout(); Print("Bar locked.")
    elseif cmd == "unlock" then
        DB.locked = false; DB.hidden = false; ApplyBarLayout(); Print("Bar unlocked - drag it, then /tl lock.")
    elseif cmd == "list" then
        local n = 0
        for encID, byDiff in pairs(DB.notes) do
            for diffID, note in pairs(byDiff) do
                n = n + 1
                print(string.format("  %d  %s  %s  (%d rows)", encID, note.name or "?", DIFF_NAME[diffID] or "?", #note.entries))
            end
        end
        if n == 0 then Print("No notes stored.") end
    elseif cmd == "delete" then
        local id = tonumber(arg)
        if id and DB.notes[id] then DB.notes[id] = nil; Print("Deleted encounter %d.", id)
        else Print("Usage: /tl delete <encounterID>  (see /tl list)") end
    elseif cmd == "window" then
        local v = tonumber(arg); if v and v > 1 then DB.lookahead = v; if DB.imminent >= v then DB.imminent = v / 2 end; ApplyBarLayout(); Print("Lookahead %.0fs.", v) else Print("Usage: /tl window <seconds>") end
    elseif cmd == "imminent" then
        local v = tonumber(arg); if v and v > 0 and v < DB.lookahead then DB.imminent = v; ApplyBarLayout(); Print("Imminent zone %.0fs.", v) else Print("Usage: /tl imminent <seconds, less than window>") end
    elseif cmd == "cols" or cmd == "colwidth" then
        local v = tonumber(arg); if v and v >= 40 then DB.colWidth = v; ApplyBarLayout() else Print("Usage: /tl cols <px>  (Cooldowns column width; %d now)", DB.colWidth) end
    elseif cmd == "bosscols" then
        local v = tonumber(arg); if v and v >= 40 then DB.bossColWidth = v; ApplyBarLayout() else Print("Usage: /tl bosscols <px>") end
    elseif cmd == "labels" then
        local v = tonumber(arg); if v and v >= 0 then DB.labelWidth = v; ApplyBarLayout() else Print("Usage: /tl labels <px>  (text width beside icons; 0 = icons only)") end
    elseif cmd == "layout" then
        if arg == "mine" then DB.mineOn = true; ApplyBarLayout(); Print("The own-cooldowns column is now a separate frame - /tl mine toggles it. Plan bar layout stays %s.", DB.layout)
        elseif arg == "stack" or arg == "hud" or arg == "single" or arg == "lanes" then DB.layout = arg; ReleaseAll(); ReleaseMine(); ApplyBarLayout(); Print("Layout: %s.", arg)
        else Print("Usage: /tl layout stack | hud | single | lanes   (now: %s)", DB.layout) end
    elseif cmd == "stacksize" then
        local w, h = arg:match("^(%d+)%s+(%d+)$")
        if w then DB.stackWidth = tonumber(w); DB.stackHeight = tonumber(h); ApplyBarLayout() else Print("Usage: /tl stacksize <width> <height>  (now %d %d)", DB.stackWidth, DB.stackHeight) end
    elseif cmd == "bosslane" then
        local v = tonumber(arg); if v and v >= 30 then DB.stackBossW = v; ApplyBarLayout() else Print("Usage: /tl bosslane <px>  (boss lane width left of the stalk, now %d)", DB.stackBossW) end
    elseif cmd == "linear" then
        DB.stackLinear = not DB.stackLinear; ApplyBarLayout(); Print("Stack timeline: %s.", DB.stackLinear and "constant speed, 30 s to 0" or "perspective (accelerating, growing)")
    elseif cmd == "rowicon" then
        local v = tonumber(arg); if v and v >= 12 then DB.rowIcon = v; ReleaseMine(); ApplyBarLayout() else Print("Usage: /tl rowicon <px>  (now %d)", DB.rowIcon) end
    elseif cmd == "all" then
        DB.stackAll = not DB.stackAll; ReleaseAll(); Print("Stack column shows %s.", DB.stackAll and "everyone's planned casts" or "only my casts (and boss timers)")
    elseif cmd == "mine" then
        DB.mineOn = not DB.mineOn; ApplyMineLayout(); Print("Own-cooldowns column %s.", DB.mineOn and "on" or "off")
    elseif cmd == "cdm" then
        DB.mineCDM = not DB.mineCDM; ApplyMineLayout(); Print(DB.mineCDM and "Countdowns now sit on your Cooldown Manager icons (red = hold it)." or "Countdowns back on the cooldown column.")
    elseif cmd == "sched" then
        DB.mineSched = not DB.mineSched; ReleaseMine(); ApplyMineLayout(); Print("Scheduled casts on the column %s.", DB.mineSched and "on" or "off")
    elseif cmd == "minelock" then
        DB.mineLocked = not (DB.mineLocked ~= false); ApplyMineLayout()
        Print("Cooldown row %s.", DB.mineLocked and "locked" or "unlocked - drag it anywhere; the HUD stays locked. /tl minepos puts it back on top of the HUD")
    elseif cmd == "minepos" then
        DB.minePoint = nil; ApplyMineLayout(); Print(DB.layout == "hud" and "Cooldown row back on top of the HUD." or "Column re-attached to the plan bar.")
    elseif cmd == "mineoffset" then
        local v = tonumber(arg); if v then DB.mineOffset = v; ApplyMineLayout() else Print("Usage: /tl mineoffset <px>  (now %d)", DB.mineOffset) end
    elseif cmd == "track" then
        local sub, rest = arg:match("^(%S*)%s*(.-)$")
        local spec = CurrentSpecID()
        if not spec then Print("No specialisation detected yet."); return end
        if sub == "add" or sub == "remove" then
            local idS, grp = rest:match("^(%d+)%s*(%a*)$")
            local id = tonumber(idS)
            if not id then Print("Usage: /tl track %s <spellID> [other]", sub); return end
            local function own(tbl, defaults)
                local list = tbl[spec]
                if not list then list = {}; for _, v in ipairs(defaults[spec] or {}) do list[#list + 1] = v end; tbl[spec] = list end
                for k = #list, 1, -1 do if list[k] == id then table.remove(list, k) end end
                return list
            end
            local major, other = own(DB.track, TRACK_DEFAULTS), own(DB.trackOther, OTHER_DEFAULTS)
            if sub == "add" then if grp:lower() == "other" then other[#other + 1] = id else major[#major + 1] = id end end
            RebuildTracked()
            Print("%s %s (%d)%s. Now tracking %d known spell(s).", sub == "add" and "Added" or "Removed", SpellName(id) or "?", id, sub == "add" and (grp:lower() == "other" and " to Other" or " to Major") or "", #mine.list)
        elseif sub == "move" then
            local idS, dir = rest:match("^(%d+)%s*(%a*)$")
            local id = tonumber(idS)
            if not id or (dir ~= "left" and dir ~= "right") then Print("Usage: /tl track move <spellID> left|right"); return end
            for _, pair in ipairs({ { DB.track, TRACK_DEFAULTS }, { DB.trackOther, OTHER_DEFAULTS } }) do
                local tbl, defaults = pair[1], pair[2]
                local list = tbl[spec]
                if not list then list = {}; for _, v in ipairs(defaults[spec] or {}) do list[#list + 1] = v end end
                -- move past spells you don't know too, so a step always moves it one visible column
                local pos; for k, v in ipairs(list) do if v == id then pos = k end end
                if pos then
                    local step = dir == "left" and -1 or 1
                    local k = pos + step
                    while list[k] and not SpellKnown(list[k]) do k = k + step end
                    if list[k] then list[pos], list[k] = list[k], list[pos] end
                    tbl[spec] = list
                end
            end
            RebuildTracked()
        elseif sub == "width" then
            local idS, wS = rest:match("^(%d+)%s*(%d*)$")
            local id, w = tonumber(idS), tonumber(wS)
            if not id or not w then Print("Usage: /tl track width <spellID> <px>   (0 = just the icon)"); return end
            DB.colW = DB.colW or {}
            DB.colW[id] = w > 0 and w or nil
            ReleaseMine(); ApplyMineLayout(); if DB.layout == "stack" then ApplyBarLayout() end
        elseif sub == "reset" then
            DB.track[spec] = nil; DB.trackOther[spec] = nil; RebuildTracked(); Print("Tracking lists reset to the defaults for this spec (%d known).", #mine.list)
        else
            local function show(label, src, custom)
                Print("%s (%s): %d listed", label, custom and "your list" or "defaults", #src)
                for _, id in ipairs(src) do print(string.format("  %d  %s  %s", id, SpellName(id) or "?", SpellKnown(id) and "" or "(not known - hidden)")) end
            end
            show("Major", DB.track[spec] or TRACK_DEFAULTS[spec] or {}, DB.track[spec] ~= nil)
            show("Other", DB.trackOther[spec] or OTHER_DEFAULTS[spec] or {}, DB.trackOther[spec] ~= nil)
            print("  /tl track add <spellID> [other]  |  /tl track remove <spellID>  |  /tl track move <spellID> left|right  |  /tl track width <spellID> <px>  |  /tl track reset")
        end
    elseif cmd == "ready" then
        DB.mineReady = not DB.mineReady; Print("Ready spells %s.", DB.mineReady and "stay docked at the bottom" or "disappear until used")
    elseif cmd == "combat" then
        DB.mineCombat = not DB.mineCombat; ApplyMineLayout(); Print("Column shown %s.", DB.mineCombat and "in combat only" or "always")
    elseif cmd == "swipe" then
        DB.mineSwipe = not DB.mineSwipe; Print("Cooldown sweep %s.", DB.mineSwipe and "on" or "off")
    elseif cmd == "numbers" then
        DB.mineNumbers = not DB.mineNumbers; Print("Countdown: %s.", DB.mineNumbers and "Blizzard's number on the icon (works in combat; needs 'Show Numbers for Cooldowns' in Interface options, or OmniCC)" or "our own text under the icon (exact out of combat, modelled in combat)")
    elseif cmd == "debug" then
        local spec = CurrentSpecID()
        local inC = (UnitAffectingCombat and UnitAffectingCombat("player")) and "yes" or "no"
        Print("plan layout %s, column %s (%s), spec %s, in combat: %s, tracked %d, column updater %s, encounter %s", DB.layout, DB.mineOn and "on" or "off", mine.matched and "attached" or "free", tostring(spec), inC, #mine.list, mineBar:GetScript("OnUpdate") and "running" or "none", state.active and (state.note and state.note.name or "?") or "none")
        for _, e in ipairs(mine.list) do
            local rem, dur, active, st, d = ReadCooldown(e.spellID)
            local m = mine.model[e.spellID]
            print(string.format("  %d %s [%s]: %s rem=%s active=%s cached=%s model=%s sched=%s", e.spellID, e.label or "?", e.group or "?",
                rem == nil and "SECRET" or "readable", rem and string.format("%.1f", rem) or "-", tostring(active),
                tostring(DB.cdDur[e.spellID]), m and string.format("%.0fs from cast", m.dur) or "-", e.schedRem and string.format("%.0fs", e.schedRem) or "-"))
        end
    elseif cmd == "border" then
        DB.mineBorder = not DB.mineBorder; ReleaseMine(); Print("Icon borders %s.", DB.mineBorder and "on" or "off")
    elseif cmd == "minesize" then
        local a, b = arg:match("^(%d+)%s+(%d+)$")
        if a then DB.mineIcon = tonumber(a); DB.mineHeight = tonumber(b); ReleaseMine(); ApplyMineLayout() else Print("Usage: /tl minesize <icon px> <height px>  (now %d %d)", DB.mineIcon, DB.mineHeight) end
    elseif cmd == "depth" then
        local v = tonumber(arg); if v and v >= 0.5 and v <= 8 then DB.depth = v; Print("Perspective depth %.1f.", v) else Print("Usage: /tl depth <0.5-8>  (now %.1f)", DB.depth) end
    elseif cmd == "hudsize" then
        local w, h = arg:match("^(%d+)%s+(%d+)$")
        if w then DB.hudWidth = tonumber(w); DB.hudHeight = tonumber(h); ApplyBarLayout() else Print("Usage: /tl hudsize <width> <height>  (now %d %d)", DB.hudWidth, DB.hudHeight) end
    elseif cmd == "slot" then
        local v = tonumber(arg); if v and v >= 16 then DB.slotIcon = v; ApplyBarLayout() else Print("Usage: /tl slot <px>  (next-up icon size, now %d)", DB.slotIcon) end
    elseif cmd == "crosshair" then
        DB.crosshair = not DB.crosshair; ApplyBarLayout(); Print("Crosshairs %s.", DB.crosshair and "on" or "off")
    elseif cmd == "rails" then
        DB.rails = not DB.rails; ApplyBarLayout(); Print("Guide rails %s.", DB.rails and "on" or "off")
    elseif cmd == "far" then
        local v = tonumber(arg); if v and v >= 4 and v <= 40 then DB.farIcon = v; Print("Far icon size %d.", v) else Print("Usage: /tl far <px>  (icon size at the far end, now %d)", DB.farIcon) end
    elseif cmd == "plate" then
        DB.slotPlate = (DB.slotPlate == false); ApplyBarLayout(); Print("Slot backing plate %s.", DB.slotPlate == false and "off" or "on")
    elseif cmd == "font" then
        if arg == "" then Print("Font: %s. /tl font bundled (Barlow Condensed) | condensed | barlow | dejavu | poppins | <LibSharedMedia name>  (/tl fonts lists them)", DB.font)
        else DB.font = arg; ApplyBarLayout(); RestyleAllIcons(); Print("Font: %s -> %s", arg, (fontPath:match("[^\\]+$") or fontPath)) end
    elseif cmd == "outline" then
        DB.fontOutline = not DB.fontOutline; ApplyBarLayout(); RestyleAllIcons(); Print("Text %s.", DB.fontOutline and "outlined" or "with a drop shadow")
    elseif cmd == "fonts" then
        local LSM = GetLSM()
        if not LSM then Print("LibSharedMedia not found - only bundled / poppins available.")
        else
            local ok, list = pcall(LSM.List, LSM, "font")
            if ok and list then Print("%d LibSharedMedia fonts:", #list); print("  " .. table.concat(list, ", ")) end
        end
    elseif cmd == "fontsize" then
        local v = tonumber(arg); if v and v >= 6 and v <= 30 then DB.fontSize = v; ApplyBarLayout(); RestyleAllIcons() else Print("Usage: /tl fontsize <6-30>") end
    elseif cmd == "major" then
        local v = tonumber(arg); if v and v >= 1 and v <= 2.5 then DB.majorScale = v; ReleaseAll(); ApplyBarLayout() else Print("Usage: /tl major <scale 1-2.5>") end
    elseif cmd == "headers" then
        DB.showHeaders = not DB.showHeaders; ApplyBarLayout(); Print("Lane headers %s.", DB.showHeaders and "on" or "off")
    elseif cmd == "ticks" then
        DB.showTicks = not DB.showTicks; ApplyBarLayout(); Print("Time ticks %s.", DB.showTicks and "on" or "off")
    elseif cmd == "size" then
        local v = tonumber(arg); if v and v >= 12 then DB.iconSize = v; ReleaseAll(); ApplyBarLayout() else Print("Usage: /tl size <px>") end
    elseif cmd == "height" then
        local v = tonumber(arg); if v and v >= 80 then DB.barHeight = v; ApplyBarLayout() else Print("Usage: /tl height <px>") end
    elseif cmd == "alpha" then
        local v = tonumber(arg); if v and v >= 0 and v <= 1 then DB.barAlpha = v; ApplyBarLayout() else Print("Usage: /tl alpha <0-1>") end
    elseif cmd == "names" then
        DB.showNames = not DB.showNames; ApplyBarLayout(); Print("Name labels %s.", DB.showNames and "on" or "off")
    elseif cmd == "time" then
        DB.showTime = not DB.showTime; Print("Countdown %s.", DB.showTime and "on" or "off")
    elseif cmd == "onlymine" then
        DB.onlyMine = not DB.onlyMine; ReleaseAll(); Print("Only my cooldowns on the plan bar: %s.", DB.onlyMine and "on" or "off")
    elseif cmd == "reset" then
        local notes, last, track, other, byClass, plansClass = DB.notes, DB.lastImport, DB.track, DB.trackOther, DB.byClass, DB.plansClass
        wipe(DB); CopyDefaults(DB, DEFAULTS); DB.notes = notes; DB.lastImport = last; DB.track = track or {}; DB.trackOther = other or {}
        DB.byClass = byClass; DB.plansClass = plansClass
        RebuildTracked()
        ReleaseAll(); ApplyBarLayout(); Print("Settings reset.")
    else
        Help()
    end
end

SLASH_CDTIMELINE1 = "/tl"
SLASH_CDTIMELINE2 = "/cdtimeline"
SlashCmdList.CDTIMELINE = Slash
ns.Slash = Slash

-- expose internals for other addons / testing
ns.ParseNote      = ParseNote
ns.graph          = graph
ns.G              = G
ns.StoreNote      = StoreNote
ns.FindNote       = FindNote
ns.StartEncounter = StartEncounter
ns.StopEncounter  = StopEncounter
ns.OnPullTimer    = OnPullTimer
ns.ParseViserioBlob = ParseViserioBlob
ns.Base64Decode   = Base64Decode
ns.MsgpackDecode  = MsgpackDecode
ns.BW_StartBar    = BW_StartBar
ns.BW_StopBar     = BW_StopBar
ns.HookBigWigs    = HookBigWigs
ns.OnUpdate       = OnUpdate
ns.YForRem        = YForRem
ns.FinishNote     = FinishNote
ns.columns        = columns
ns.Perspective    = Perspective
ns.slots          = slots
ns.ApplyBarLayout = ApplyBarLayout
ns.state          = state
ns.activeIcons    = activeIcons
ns.ReadCooldown   = ReadCooldown
ns.OnSpellCast    = OnSpellCast
ns.KnownPhaseStarts = function(n) return KnownPhaseStarts(n) end
ns.MineY          = function(rem) return mine.base, mine.travel, mine.parkY, mine.matched end
ns.TRACK_DEFAULTS = TRACK_DEFAULTS

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
local PLAYER_COUNTDOWN = (Enum and Enum.StartTimerType and Enum.StartTimerType.PlayerCountdown) or 3

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("ENCOUNTER_START")
ev:RegisterEvent("ENCOUNTER_END")
ev:RegisterEvent("START_TIMER")
ev:RegisterEvent("CHAT_MSG_ADDON")
ev:RegisterEvent("PLAYER_LOGIN")
pcall(ev.RegisterEvent, ev, "CANCEL_PLAYER_COUNTDOWN") -- not present on every client
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED", "TRAIT_CONFIG_UPDATED", "SPELLS_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED" }) do
    pcall(ev.RegisterEvent, ev, e)
end
if ev.RegisterUnitEvent then pcall(ev.RegisterUnitEvent, ev, "UNIT_SPELLCAST_SUCCEEDED", "player") else pcall(ev.RegisterEvent, ev, "UNIT_SPELLCAST_SUCCEEDED") end
local rebuildQueued = false
local function QueueRebuild()
    if rebuildQueued then return end
    rebuildQueued = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, function() rebuildQueued = false; RebuildTracked() end)
    else
        rebuildQueued = false; RebuildTracked()
    end
end

ev:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= ADDON_NAME then return end
        CDTimelineDB = CDTimelineDB or {}
        DB = CDTimelineDB
        if DB.layout and DB.layoutVersion == nil then DB.layout = "hud" end   -- saved before the HUD existed
        if DB.layout and DB.hudVersion == nil then DB.rails = false; DB.slotPlate = false; DB.crosshair = true; DB.barAlpha = 0 end -- 0.7: bare overlay
        if DB.layout == "mine" then DB.layout = "hud"; DB.mineOn = true end -- 0.9: the column is its own frame beside the plan bar
        if DB.layout and DB.stackVersion == nil then DB.layout = "stack" end  -- 0.10: one column, cooldowns in the top row
        if DB.themeVersion == nil and DB.font == "bundled" then DB.font = "bundled" end -- 0.17: "bundled" is now Barlow Condensed
        CopyDefaults(DB, DEFAULTS)
        DB.layoutVersion = 2; DB.hudVersion = 2; DB.mineVersion = 2; DB.stackVersion = 1
        local okL, errL = pcall(ApplyBarLayout)
        if not okL then print("|cffb66effCDTL|r layout error: " .. tostring(errL)) end
        ev:UnregisterEvent("ADDON_LOADED")
        -- make sure we receive DBM / BigWigs syncs even if those addons aren't loaded here
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            for _, p in ipairs({ "D5", "D4", "BigWigs" }) do
                pcall(C_ChatInfo.RegisterAddonMessagePrefix, p)
            end
        end

    elseif event == "PLAYER_LOGIN" then
        C_Timer.After(3, BUILTIN.Load)   -- load the built-in plans out of combat
        PC.UseClassPlans()
        HookBigWigs()
        RebuildTracked()
        -- DBM stage callback, best effort
        pcall(function() if DBM and DBM.RegisterCallback then DBM:RegisterCallback("DBM_SetStage", function(_, mod, modId, stage) ns.OnStage(stage, "DBM") end) end end)

    elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "TRAIT_CONFIG_UPDATED" or event == "SPELLS_CHANGED" then
        if event ~= "PLAYER_SPECIALIZATION_CHANGED" or ... == "player" or ... == nil then QueueRebuild() end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit == "player" and not IsSecret(spellID) then OnSpellCast(spellID) end

    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
        if DB.mineOn and DB.mineCombat then ApplyMineLayout() end

    elseif event == "ENCOUNTER_START" then
        HookBigWigs()
        OnEncounterStart(...)

    elseif event == "ENCOUNTER_END" then
        StopEncounter()
        local encID, _, diffID, _, success = ...
        if success == 1 and LK.AfterKill then LK.AfterKill(encID, diffID) end

    elseif event == "START_TIMER" then
        -- Blizzard countdown: /countdown, and DBM/BigWigs pull timers in a group
        local timerType, timeRemaining = ...
        if timerType == PLAYER_COUNTDOWN then
            OnPullTimer(timeRemaining, "Blizzard")
        end

    elseif event == "CANCEL_PLAYER_COUNTDOWN" then
        OnPullTimer(0, "Blizzard")

    elseif event == "CHAT_MSG_ADDON" then
        local prefix, msg = ...
        if prefix == "D5" or prefix == "D4" then
            -- DBM: "PT\t<seconds>\t<instanceID>\t<target>"
            local secs = msg and msg:match("^PT\t([%d%.]+)")
            if secs then OnPullTimer(secs, "DBM") end
        elseif prefix == "BigWigs" then
            -- BigWigs: message contains "Pull" followed by the seconds, e.g. "BWPull^10"
            local secs = msg and msg:match("[Pp]ull%^?(%d+)")
            if secs then OnPullTimer(secs, "BigWigs") end
        end
    end
end)
