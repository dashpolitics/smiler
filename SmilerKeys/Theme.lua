-- SmilerKeys: look shared with the Smiler core (falls back to built-in values without it)
local _, ns = ...
local T = {}
ns.T = T

local S = Smiler
T.hasCore = S and S.C and true or false

T.C = S and S.C or {
  void = { 0.024, 0.012, 0.059 }, card = { 0.110, 0.063, 0.227 }, raised = { 0.133, 0.078, 0.275 },
  edge = { 0.549, 0.314, 0.863 }, text = { 0.941, 0.922, 1.000 }, soft = { 0.847, 0.784, 1.000 },
  muted = { 0.706, 0.627, 0.863 }, amethyst = { 0.714, 0.431, 1.000 }, diamond = { 0.910, 0.957, 1.000 },
  emerald = { 0.000, 0.902, 0.463 }, topaz = { 1.000, 0.671, 0.000 }, ruby = { 1.000, 0.176, 0.333 },
  sapphire = { 0.361, 0.608, 1.000 },
}

function T.RGB(name, a)
  local c = T.C[name] or T.C.text
  return c[1], c[2], c[3], a or 1
end
function T.Hex(name)
  local c = T.C[name] or T.C.text
  return string.format("%02x%02x%02x", c[1] * 255 + 0.5, c[2] * 255 + 0.5, c[3] * 255 + 0.5)
end

local FALLBACK_FONT = { display = "Fonts\\FRIZQT__.TTF", label = "Fonts\\FRIZQT__.TTF", body = "Fonts\\ARIALN.TTF", strong = "Fonts\\ARIALN.TTF" }
function T.Font(fs, role, size, flags)
  if S and S.Font then S.Font(fs, role, size, flags); return end
  fs:SetFont(FALLBACK_FONT[role] or FALLBACK_FONT.body, math.max(8, size - 1), flags or "")
  fs:SetShadowColor(0, 0, 0, 0.85); fs:SetShadowOffset(1, -1)
end

function T.Text(parent, role, size, color, justify, flags)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  T.Font(fs, role, size, flags)
  fs:SetTextColor(T.RGB(color or "text"))
  fs:SetJustifyH(justify or "LEFT")
  fs:SetWordWrap(false)
  return fs
end

T.BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }
function T.Panel(f, bg, bgA, edgeA)
  if not f.SetBackdrop then Mixin(f, BackdropTemplateMixin) end
  f:SetBackdrop(T.BACKDROP)
  f:SetBackdropColor(T.RGB(bg or "void", bgA or 0.96))
  f:SetBackdropBorderColor(T.RGB("edge", edgeA or 0.38))
end

function T.TopLine(f, from, to)
  local t = f:CreateTexture(nil, "ARTWORK", nil, 7)
  t:SetPoint("TOPLEFT", 1, -1); t:SetPoint("TOPRIGHT", -1, -1); t:SetHeight(2)
  t:SetColorTexture(1, 1, 1, 1)
  local a, b = T.C[from or "amethyst"], T.C[to or "diamond"]
  t:SetGradient("HORIZONTAL", CreateColor(a[1], a[2], a[3], 1), CreateColor(b[1], b[2], b[3], 1))
  return t
end

-- icons: Smiler's own, or game atlases without it
local ATLAS = { star = "PetJournal-FavoritesIcon", tick = "common-icon-checkmark", tickcircle = "common-icon-checkmark",
                close = "common-icon-redx", arrow = "bags-greenarrow", warn = "services-icon-warning", info = "QuestNormal",
                dot = "worldquest-tracker-ring", ball = "communities-icon-searchmagnifyingglass", play = "common-icon-forwardarrow" }
function T.Icon(tex, name)
  if S and S.Icon then tex:SetTexture(S.Icon(name)); return end
  if not pcall(tex.SetAtlas, tex, ATLAS[name] or "common-icon-checkmark") then tex:SetTexture(134400) end
end
function T.IconTex(parent, name, size, color, layer)
  local t = parent:CreateTexture(nil, layer or "OVERLAY")
  T.Icon(t, name)
  t:SetSize(size, size)
  if T.hasCore then t:SetVertexColor(T.RGB(color or "text")) end
  return t
end

function T.Button(parent, label, w, h, onClick, style)
  if S and S.W then return S.W.Button(parent, label, w, h, onClick, style) end
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w, h or 24)
  T.Panel(b, style == "primary" and "amethyst" or "raised", 1, 0.6)
  b.text = T.Text(b, "strong", 13, style == "primary" and "void" or "text", "CENTER")
  b.text:SetPoint("CENTER")
  b.text:SetText(label)
  b:SetScript("OnClick", onClick)
  function b:SetLabel(t) self.text:SetText(t) end
  return b
end

function T.Segmented(parent, options, get, set, h)
  if S and S.W then return S.W.Segmented(parent, options, get, set, h) end
  local f = CreateFrame("Frame", nil, parent)
  f.buttons = {}
  local x = 0
  for i, o in ipairs(options) do
    local b = T.Button(f, o[2], 80, h or 24, function() set(o[1]); f:Sync() end)
    b:SetPoint("LEFT", x, 0); x = x + 82
    b.key = o[1]
    f.buttons[i] = b
  end
  f:SetSize(x, h or 24)
  function f:Sync()
    for _, b in ipairs(self.buttons) do
      local on = b.key == get()
      b:SetBackdropColor(T.RGB(on and "amethyst" or "raised"))
      b.text:SetTextColor(T.RGB(on and "void" or "soft"))
    end
  end
  f:Sync()
  return f
end
