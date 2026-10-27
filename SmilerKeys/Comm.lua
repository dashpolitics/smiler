-- SmilerKeys: serialisation, chunking, send queue, receive, relay
local _, ns = ...

---------------------------------------------------------------- serialise
-- 1~S~Name-Realm~CLASS~score~season~ts~keyMap~keyLevel~id,tl,ch,ol,sc;id,...
-- optional 12th field: BattleTag, only ever sent over Battle.net (the recipient already knows it)
-- 1~H                    hello: "send me yours"
function ns.Serialize(s, contentOnly, withTag)
  local runs = {}
  for id, r in pairs(s.runs or {}) do
    if (r.tl or 0) > 0 or (r.ol or 0) > 0 or (r.sc or 0) > 0 then
      runs[#runs + 1] = string.format("%d,%d,%d,%d,%d", id, r.tl or 0, r.ch or 0, r.ol or 0, r.sc or 0)
    end
  end
  table.sort(runs)
  local msg = table.concat({
    ns.PROTO, "S", s.key, s.class or "", math.floor(s.score or 0), s.season or 0,
    contentOnly and 0 or (s.ts or 0), s.keyMap or 0, s.keyLevel or 0, table.concat(runs, ";"),
  }, "~")
  if withTag and s.acct then msg = msg .. "~" .. s.acct end
  return msg
end

local function split(str, sep)
  local t = {}
  for piece in (str .. sep):gmatch("(.-)" .. sep) do t[#t + 1] = piece end
  return t
end

function ns.Deserialize(msg)
  local f = split(msg, "~")
  if f[1] ~= ns.PROTO then return nil end
  if f[2] == "H" then return { kind = "H", ver = f[3] } end
  if f[2] ~= "S" or #f < 10 then return nil end
  local key = f[3]
  if not key or not key:find("-", 1, true) then return nil end
  local s = {
    kind = "S", key = key, name = key:match("^(.-)%-"), class = f[4] ~= "" and f[4] or nil,
    score = tonumber(f[5]) or 0, season = tonumber(f[6]) or 0, ts = tonumber(f[7]) or 0,
    keyMap = tonumber(f[8]) or 0, keyLevel = tonumber(f[9]) or 0, runs = {}, hasAddon = true,
    acct = f[11] and f[11]:match("^[^~;,|#]+#%d+$") or nil,
  }
  if f[10] ~= "" then
    for _, e in ipairs(split(f[10], ";")) do
      local id, tl, ch, ol, sc = e:match("^(%d+),(%d+),(%d+),(%d+),(%d+)$")
      if id then
        s.runs[tonumber(id)] = { tl = tonumber(tl), ch = tonumber(ch), ol = tonumber(ol), sc = tonumber(sc) }
      end
    end
  end
  return s
end

---------------------------------------------------------------- chunking
local CHUNK, counter = 230, 0

local function chunks(msg)
  counter = counter % 999 + 1
  local pieces, pos, len = {}, 1, #msg
  while pos <= len do
    local stop = math.min(pos + CHUNK - 1, len)
    -- never split inside a UTF-8 character
    while stop < len and stop > pos do
      local b = msg:byte(stop + 1)
      if b >= 0x80 and b < 0xC0 then stop = stop - 1 else break end
    end
    pieces[#pieces + 1] = msg:sub(pos, stop)
    pos = stop + 1
  end
  local n = #pieces
  for i = 1, n do pieces[i] = counter .. ":" .. i .. "/" .. n .. ":" .. pieces[i] end
  return pieces
end
ns._chunks = chunks

local buffers = {}
local function reassemble(text, senderId)
  local id, i, n, body = text:match("^(%d+):(%d+)/(%d+):(.*)$")
  if not id then return nil end
  i, n = tonumber(i), tonumber(n)
  if n < 1 or n > 20 or i < 1 or i > n then return nil end
  if n == 1 then return body end
  local k = senderId .. "#" .. id
  local b = buffers[k]
  if not b or b.n ~= n then b = { n = n, got = 0, parts = {}, t = GetTime() }; buffers[k] = b end
  if not b.parts[i] then b.parts[i] = body; b.got = b.got + 1 end
  if b.got == n then buffers[k] = nil; return table.concat(b.parts) end
  return nil
end
ns._reassemble = reassemble

---------------------------------------------------------------- send queue
local queue, backoff = {}, 0

local function enqueue(channel, target, msg)
  for _, c in ipairs(chunks(msg)) do queue[#queue + 1] = { channel, target, c } end
end

local function lockedDown()
  return C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
end

local function isThrottled(ok, res)
  if not ok then return false end
  local E = Enum.SendAddonMessageResult
  return type(res) == "number" and E and (res == E.AddonMessageThrottle or res == E.ChannelThrottle)
end

local function pump()
  if backoff > 0 then backoff = backoff - 1; return end
  if #queue == 0 or lockedDown() then return end  -- held until the encounter / key ends
  local item = table.remove(queue, 1)
  local ch, target, text = item[1], item[2], item[3]
  ns.stats.sent = ns.stats.sent + 1
  if ch == "BN" then
    pcall(BNSendGameData, target, ns.PREFIX, text)
  else
    local ok, res = pcall(C_ChatInfo.SendAddonMessage, ns.PREFIX, text, ch, target)
    if isThrottled(ok, res) then table.insert(queue, 1, item); backoff = 4 end
  end
  -- drop stale partial messages
  local now = GetTime()
  for k, b in pairs(buffers) do if now - b.t > 60 then buffers[k] = nil end end
end

function ns.CommStart()
  if ns.ticker then return end
  ns.ticker = C_Timer.NewTicker(0.3, pump)
end

---------------------------------------------------------------- targets
local function groupChannel()
  if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
  if IsInRaid() then return "RAID" end
  if IsInGroup() then return "PARTY" end
end

local function forEachTarget(fn)
  local cfg = ns.db.settings.channels
  if cfg.guild and IsInGuild() then fn("GUILD") end
  if cfg.party then
    local ch = groupChannel()
    if ch then fn(ch) end
  end
  if cfg.friends then
    for i = 1, C_FriendList.GetNumFriends() or 0 do
      local info = C_FriendList.GetFriendInfoByIndex(i)
      if info and info.connected and info.name then fn("WHISPER", info.name) end
    end
  end
  if cfg.bnet then
    ns.ForEachBNetWoW(function(id) fn("BN", id) end)
  end
end

function ns.Hello() return ns.PROTO .. "~H~" .. ns.VERSION end

local function newer(a, b)   -- is version a newer than b?
  local x, y = {}, {}
  for n in tostring(a):gmatch("%d+") do x[#x + 1] = tonumber(n) end
  for n in tostring(b):gmatch("%d+") do y[#y + 1] = tonumber(n) end
  for i = 1, math.max(#x, #y) do
    if (x[i] or 0) ~= (y[i] or 0) then return (x[i] or 0) > (y[i] or 0) end
  end
  return false
end

function ns.Broadcast(hello)
  local s = ns.UpdateSelf(true)
  if not s then return end
  local msg, tagged = ns.Serialize(s), ns.Serialize(s, false, true)
  ns.lastSent = ns.Serialize(s, true)
  forEachTarget(function(ch, target)
    enqueue(ch, target, ch == "BN" and tagged or msg)
    if hello then enqueue(ch, target, ns.Hello()) end
  end)
end

-- Snapshot + hello to one target (used when a friend comes online)
function ns.SendTo(ch, target)
  local s = ns.db.players[ns.selfKey]
  if not s then return end
  enqueue(ch, target, ns.Serialize(s, false, ch == "BN"))
  enqueue(ch, target, ns.Hello())
end

function ns.Debug()
  local P = ns.Print
  local cfg = ns.db.settings.channels
  P("SmilerKeys " .. ns.VERSION .. " – sharing: guild " .. tostring(cfg.guild) .. ", friends " .. tostring(cfg.friends) ..
    ", bnet " .. tostring(cfg.bnet) .. ", group " .. tostring(cfg.party))
  local bn = {}
  ns.ForEachBNetWoW(function(id, tag, char, realm) bn[#bn + 1] = (tag or "?") .. " on " .. (char or "?") .. "-" .. (realm or "?") end)
  P("Battle.net friends in WoW right now: " .. (#bn > 0 and table.concat(bn, ", ") or "none"))
  local cf = {}
  for i = 1, C_FriendList.GetNumFriends() or 0 do
    local f = C_FriendList.GetFriendInfoByIndex(i)
    if f and f.connected and f.name and f.name ~= "" then cf[#cf + 1] = f.name end
  end
  P("Character friends online: " .. (#cf > 0 and table.concat(cf, ", ") or "none"))
  P("In a guild: " .. tostring(IsInGuild()) .. " · in a group: " .. tostring(IsInGroup()))
  P("Messages sent: " .. ns.stats.sent .. " · received: " .. ns.stats.recv .. " · waiting to send: " .. #queue)
  for _, l in ipairs(ns.stats.log) do
    P(string.format("  %ds ago  %s via %s  (%s)", GetTime() - l.t, l.who, l.ch, l.what))
  end
  local n = 0
  for _ in pairs(ns.db.players) do n = n + 1 end
  P("Players saved: " .. n .. ". Ask your friend to run /sk debug too and compare.")
end

function ns.SendToGroup()
  if not ns.db.settings.channels.party then return end
  local ch, s = groupChannel(), ns.db.players[ns.selfKey]
  if ch and s then
    enqueue(ch, nil, ns.Serialize(s))
    enqueue(ch, nil, ns.Hello())
  end
end

---------------------------------------------------------------- receive
local SRC = { GUILD = "guild", PARTY = "group", RAID = "group", INSTANCE_CHAT = "group",
              WHISPER = "friend", BN = "bnet" }
local lastReply = {}

local function handle(msg, channel, replyCh, replyTarget, senderKey, btag)
  local obj = ns.Deserialize(msg)
  if not obj then ns.LogRecv(senderKey, channel, "unreadable message"); return end
  ns.LogRecv(senderKey or btag, channel, obj.kind == "H" and ("hello, v" .. tostring(obj.ver)) or ("data for " .. tostring(obj.key)))

  if obj.kind == "H" then
    if obj.ver and not ns.toldNewer and newer(obj.ver, ns.VERSION) then
      ns.toldNewer = true
      ns.Print(string.format("%s is using SmilerKeys %s (you have %s) – ask them for the new version.",
        senderKey and senderKey:match("^(.-)%-") or "A friend", obj.ver, ns.VERSION))
    end
    local rk = replyCh .. ":" .. tostring(replyTarget)
    if lastReply[rk] and GetTime() - lastReply[rk] < 30 then return end
    lastReply[rk] = GetTime()
    local me = ns.db.players[ns.selfKey]
    if not me then return end
    enqueue(replyCh, replyTarget, ns.Serialize(me, false, replyCh == "BN"))
    -- relay: over private channels, also pass on cached people they may not reach
    if channel == "WHISPER" or channel == "BN" then
      local sent, now = 0, ns.Now()
      for key, p in pairs(ns.db.players) do
        if key ~= ns.selfKey and key ~= senderKey and p.hasAddon and not p.test
          and now - (p.ts or 0) < 7 * 86400 then
          enqueue(replyCh, replyTarget, ns.Serialize(p))
          sent = sent + 1
          if sent >= 15 then break end
        end
      end
    end
  elseif obj.kind == "S" then
    obj.kind = nil
    obj.src = (senderKey and obj.key ~= senderKey) and "relay" or (SRC[channel] or "?")
    if obj.key ~= senderKey then
      obj.acct = nil                         -- only trust a tag about the sender themself
    elseif btag then
      obj.acct = btag                        -- the friend list is the authority over Battle.net
    end
    ns.Store(obj)
  end
end

local function secret(...)
  if not issecretvalue then return false end
  for i = 1, select("#", ...) do
    if issecretvalue((select(i, ...))) then return true end
  end
  return false
end

function ns.CHAT_MSG_ADDON(prefix, text, channel, sender)
  if secret(prefix, text, sender) or prefix ~= ns.PREFIX then return end
  local key = ns.Normalize(sender)
  if not key or key == ns.selfKey then return end
  local full = reassemble(text, key)
  if not full then return end
  local replyCh, replyTarget = "WHISPER", sender
  handle(full, channel, replyCh, replyTarget, key)
end

local function tagFor(gameAccountID)
  local found
  ns.ForEachBNetWoW(function(id, tag) if id == gameAccountID and tag then found = tag end end)
  return found and (found:gsub("[~;,|]", "")) or nil
end

function ns.BN_CHAT_MSG_ADDON(prefix, text, _, gameAccountID)
  if secret(prefix, text, gameAccountID) or prefix ~= ns.PREFIX then return end
  local senderKey
  local info = C_BattleNet.GetGameAccountInfoByID(gameAccountID)
  if info and info.characterName and info.realmName then
    senderKey = info.characterName .. "-" .. ns.NormalizeRealm(info.realmName)
  end
  local full = reassemble(text, "bn" .. tostring(gameAccountID))
  if not full then return end
  handle(full, "BN", "BN", gameAccountID, senderKey, tagFor(gameAccountID))
end
