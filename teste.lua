--[[
  Mayunie DEX Explorer (standalone)
  Autor: ChatGPT (para Bruno)
  Objetivo: Explorer estilo Dex, seguro e compatível, com GUI moderna e Property Inspector.

  Atalhos:
  - RightCtrl: mostrar/ocultar a janela
  - Botão Refresh: recarrega a árvore
  - Clique no triângulo ▶ para expandir/colapsar
  - Clique no nome do item para selecionar
  - "Copy Path" copia o caminho do objeto
  Observação: edição de propriedades depende do nível de permissão do executor e da classe. Propriedades protegidas serão ignoradas com segurança.
]]--

-- ==============================
--  Utilidades e compat wrappers
-- ==============================
local Services = setmetatable({}, {
    __index = function(t, k)
        local s = game:GetService(k)
        rawset(t, k, s)
        return s
    end
})

-- Evita GUI duplicada
pcall(function()
    local old = Services.CoreGui:FindFirstChild("MayunieDexExplorer")
    if old then old:Destroy() end
end)

local protect_gui = rawget(getfenv(), "syn") and syn.protect_gui or (protectgui or function() end)
local gethui_ok, hiddenui = pcall(function() return gethui and gethui() end)
local GUI_PARENT = (gethui_ok and hiddenui) or Services.CoreGui

local function safeSetClipboard(text)
    local ok = pcall(function()
        if setclipboard then
            setclipboard(text)
        else
            error("setclipboard indisponível")
        end
    end)
    return ok
end

local function typeofRbx(v)
    local ok, t = pcall(function() return typeof(v) end)
    if ok then return t end
    -- fallback
    local mt = getmetatable(v)
    return mt and mt.__type or type(v)
end

local function serialize(v)
    local t = typeofRbx(v)
    if t == "Instance" then
        return string.format("%s (%s)", v.Name, v.ClassName)
    elseif t == "Vector3" then
        return string.format("%g, %g, %g", v.X, v.Y, v.Z)
    elseif t == "Vector2" then
        return string.format("%g, %g", v.X, v.Y)
    elseif t == "UDim2" then
        return string.format("{%g, %g}; {%g, %g}", v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset)
    elseif t == "UDim" then
        return string.format("%g, %g", v.Scale, v.Offset)
    elseif t == "Color3" then
        return string.format("%g, %g, %g", v.R, v.G, v.B)
    elseif t == "CFrame" then
        local cf = v:GetComponents()
        return table.concat(cf, ", ")
    elseif t == "BrickColor" then
        return v.Name
    elseif t == "EnumItem" then
        return v.Name
    elseif t == "string" then
        return v
    elseif t == "boolean" then
        return v and "true" or "false"
    elseif t == "number" then
        return tostring(v)
    elseif t == "table" then
        return "[table]"
    else
        return tostring(v)
    end
end

-- Parses básicos para edição textual
local function parseVector3(str)
    local x,y,z = str:match("^%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*$")
    if x and y and z then
        return Vector3.new(tonumber(x), tonumber(y), tonumber(z))
    end
end
local function parseVector2(str)
    local x,y = str:match("^%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*$")
    if x and y then
        return Vector2.new(tonumber(x), tonumber(y))
    end
end
local function parseUDim2(str)
    -- Formato: "{sx, ox}; {sy, oy}"
    local sx,ox,sy,oy = str:match("^%s*{%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*}%s*;%s*{%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*}%s*$")
    if sx and ox and sy and oy then
        return UDim2.new(tonumber(sx), tonumber(ox), tonumber(sy), tonumber(oy))
    end
end
local function parseUDim(str)
    local s,o = str:match("^%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*$")
    if s and o then return UDim.new(tonumber(s), tonumber(o)) end
end
local function parseColor3(str)
    local r,g,b = str:match("^%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*$")
    if r and g and b then return Color3.new(tonumber(r), tonumber(g), tonumber(b)) end
end
local function parseBool(str)
    str = str:lower()
    if str == "true" or str == "1" or str == "on" or str == "yes" then return true end
    if str == "false" or str == "0" or str == "off" or str == "no" then return false end
end

-- Tenta descobrir a propriedade com base no tipo de destino
local function smartParse(targetValue, text)
    local t = typeofRbx(targetValue)
    if t == "Vector3" then return parseVector3(text)
    elseif t == "Vector2" then return parseVector2(text)
    elseif t == "UDim2" then return parseUDim2(text)
    elseif t == "UDim" then return parseUDim(text)
    elseif t == "Color3" then return parseColor3(text)
    elseif t == "boolean" then return parseBool(text)
    elseif t == "number" then
        local n = tonumber(text)
        return n
    elseif t == "string" then
        return text
    elseif t == "EnumItem" then
        -- permite setar por nome curto, se corresponder
        local enumType = tostring(targetValue.EnumType) -- "Enum.Material"
        local enumFamily = Enum[enumType:match("Enum%.(.+)$") or ""]
        if enumFamily then
            local found
            for _,item in ipairs(enumFamily:GetEnumItems()) do
                if item.Name:lower() == text:lower() then
                    found = item; break
                end
            end
            return found
        end
    end
    return nil
end

local function getFullPath(inst)
    if not inst or not inst:IsDescendantOf(game) then return "?" end
    local segments = {}
    local current = inst
    while current and current ~= game do
        table.insert(segments, 1, string.format("%s[%s]", current.Name, current.ClassName))
        current = current.Parent
    end
    return "game." .. table.concat(segments, ".")
end

-- Lista de propriedades comuns por classe fallback
local COMMON_PROPS = {
    ["Instance"] = {"Name", "ClassName", "Parent", "Archivable"},
    ["Workspace"] = {"Gravity", "CurrentCamera"},
    ["Players"] = {"MaxPlayers", "PreferredPlayers", "RespawnTime"},
    ["Lighting"] = {"Ambient", "Brightness", "ClockTime", "FogColor", "FogEnd", "FogStart", "OutdoorAmbient", "GlobalShadows", "ShadowSoftness", "Technology"},
    ["SoundService"] = {"RespectFilteringEnabled", "AmbientReverb", "DistanceFactor", "DopplerScale", "RolloffScale", "Volume"},
    ["ReplicatedStorage"] = {},
    ["ServerStorage"] = {},
    ["StarterGui"] = {"ResetPlayerGuiOnSpawn", "ShowDevelopmentGui"},
    ["CoreGui"] = {},
    ["Workspace/BasePart"] = {"Name", "Transparency", "Reflectance", "Material", "Color", "Size", "CFrame", "Anchored", "CanCollide", "CanQuery", "CanTouch", "CastShadow"},
    ["Workspace/Model"] = {"Name", "PrimaryPart"},
    ["GuiObject"] = {"Name", "Visible", "Active", "ZIndex", "AnchorPoint", "Position", "Size", "BackgroundColor3", "BackgroundTransparency", "BorderSizePixel"},
    ["TextLabel"] = {"Text", "TextSize", "TextColor3", "TextTransparency", "TextWrapped", "RichText"},
    ["TextButton"] = {"Text", "TextSize", "TextColor3", "TextTransparency", "TextWrapped", "AutoButtonColor"},
    ["TextBox"] = {"Text", "TextSize", "TextColor3", "TextTransparency", "TextWrapped", "ClearTextOnFocus", "MultiLine"},
    ["ImageLabel"] = {"Image", "ImageTransparency", "ScaleType"},
    ["ImageButton"] = {"Image", "ImageTransparency", "ScaleType"},
    ["ScrollingFrame"] = {"CanvasSize", "AutomaticCanvasSize", "ScrollBarThickness", "ScrollingDirection"},
    ["Frame"] = {"BackgroundColor3", "BackgroundTransparency", "BorderSizePixel"},
    ["Folder"] = {"Name"},
    ["Sound"] = {"SoundId", "Volume", "PlaybackSpeed", "TimePosition", "Playing", "Looped"},
    ["Camera"] = {"CFrame", "FieldOfView"},
    ["Humanoid"] = {"Health", "MaxHealth", "WalkSpeed", "JumpPower", "AutoRotate"},
}

-- Executor helpers para propriedades (se existirem)
local getproperties_fn = rawget(getfenv(), "getproperties") or rawget(getfenv(), "getprops")
local gethiddenproperty_fn = rawget(getfenv(), "gethiddenproperty")
local sethiddenproperty_fn = rawget(getfenv(), "sethiddenproperty")

-- ==============================
--        Construção da GUI
-- ==============================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MayunieDexExplorer"
ScreenGui.IgnoreGuiInset = true
ScreenGui.ResetOnSpawn = false
pcall(protect_gui, ScreenGui)
ScreenGui.Parent = GUI_PARENT

local Theme = {
    bg = Color3.fromRGB(18, 18, 22),
    panel = Color3.fromRGB(26, 26, 32),
    panel2 = Color3.fromRGB(32, 32, 40),
    stroke = Color3.fromRGB(64, 64, 80),
    text = Color3.fromRGB(235, 235, 245),
    subtext = Color3.fromRGB(190, 190, 205),
    accent = Color3.fromRGB(95, 135, 255),
    ok = Color3.fromRGB(80, 190, 120),
    warn = Color3.fromRGB(255, 170, 60),
}

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 980, 0, 560)
Main.Position = UDim2.new(0.5, -490, 0.5, -280)
Main.BackgroundColor3 = Theme.panel
Main.Parent = ScreenGui

local corner = Instance.new("UICorner", Main)
corner.CornerRadius = UDim.new(0, 14)
local stroke = Instance.new("UIStroke", Main)
stroke.Color = Theme.stroke
stroke.Thickness = 1

local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.BackgroundColor3 = Theme.panel2
TopBar.Size = UDim2.new(1, 0, 0, 44)
TopBar.Parent = Main
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 14)

local Title = Instance.new("TextLabel")
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamSemibold
Title.TextSize = 16
Title.TextColor3 = Theme.text
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Text = "Mayunie DEX Explorer"
Title.Size = UDim2.new(0, 240, 1, 0)
Title.Position = UDim2.new(0, 16, 0, 0)
Title.Parent = TopBar

local SearchBox = Instance.new("TextBox")
SearchBox.Size = UDim2.new(0, 280, 0, 28)
SearchBox.Position = UDim2.new(0, 260, 0, 8)
SearchBox.BackgroundColor3 = Theme.bg
SearchBox.TextColor3 = Theme.text
SearchBox.PlaceholderColor3 = Theme.subtext
SearchBox.PlaceholderText = "Buscar por Nome ou ClassName"
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextSize = 14
SearchBox.ClearTextOnFocus = false
Instance.new("UICorner", SearchBox).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", SearchBox).Color = Theme.stroke
SearchBox.Parent = TopBar

local RefreshBtn = Instance.new("TextButton")
RefreshBtn.Size = UDim2.new(0, 90, 0, 28)
RefreshBtn.Position = UDim2.new(0, 550, 0, 8)
RefreshBtn.BackgroundColor3 = Theme.bg
RefreshBtn.TextColor3 = Theme.text
RefreshBtn.Font = Enum.Font.GothamSemibold
RefreshBtn.TextSize = 14
RefreshBtn.Text = "Refresh"
Instance.new("UICorner", RefreshBtn).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", RefreshBtn).Color = Theme.stroke
RefreshBtn.Parent = TopBar

local CopyPathBtn = Instance.new("TextButton")
CopyPathBtn.Size = UDim2.new(0, 110, 0, 28)
CopyPathBtn.Position = UDim2.new(0, 650, 0, 8)
CopyPathBtn.BackgroundColor3 = Theme.bg
CopyPathBtn.TextColor3 = Theme.text
CopyPathBtn.Font = Enum.Font.GothamSemibold
CopyPathBtn.TextSize = 14
CopyPathBtn.Text = "Copy Path"
Instance.new("UICorner", CopyPathBtn).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", CopyPathBtn).Color = Theme.stroke
CopyPathBtn.Parent = TopBar

local ToggleEditBtn = Instance.new("TextButton")
ToggleEditBtn.Size = UDim2.new(0, 140, 0, 28)
ToggleEditBtn.Position = UDim2.new(1, -156, 0, 8)
ToggleEditBtn.AnchorPoint = Vector2.new(1, 0)
ToggleEditBtn.BackgroundColor3 = Theme.bg
ToggleEditBtn.TextColor3 = Theme.warn
ToggleEditBtn.Font = Enum.Font.GothamSemibold
ToggleEditBtn.TextSize = 14
ToggleEditBtn.Text = "Edição: DESLIGADA"
Instance.new("UICorner", ToggleEditBtn).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", ToggleEditBtn).Color = Theme.stroke
ToggleEditBtn.Parent = TopBar

-- Corpo com árvore e propriedades
local Body = Instance.new("Frame")
Body.BackgroundTransparency = 1
Body.Position = UDim2.new(0, 0, 0, 44)
Body.Size = UDim2.new(1, 0, 1, -44)
Body.Parent = Main

local LeftPane = Instance.new("Frame")
LeftPane.BackgroundColor3 = Theme.panel
LeftPane.Size = UDim2.new(0, 360, 1, 0)
LeftPane.Parent = Body
Instance.new("UIStroke", LeftPane).Color = Theme.stroke

local Splitter = Instance.new("Frame")
Splitter.BackgroundColor3 = Theme.stroke
Splitter.Size = UDim2.new(0, 4, 1, 0)
Splitter.Position = UDim2.new(0, 360, 0, 0)
Splitter.Parent = Body

local RightPane = Instance.new("Frame")
RightPane.BackgroundColor3 = Theme.panel
RightPane.Position = UDim2.new(0, 364, 0, 0)
RightPane.Size = UDim2.new(1, -364, 1, 0)
RightPane.Parent = Body
Instance.new("UIStroke", RightPane).Color = Theme.stroke

local TreeScroll = Instance.new("ScrollingFrame")
TreeScroll.BackgroundTransparency = 1
TreeScroll.BorderSizePixel = 0
TreeScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
TreeScroll.ScrollingDirection = Enum.ScrollingDirection.Y
TreeScroll.ScrollBarThickness = 6
TreeScroll.Size = UDim2.new(1, 0, 1, 0)
TreeScroll.Parent = LeftPane

local TreeLayout = Instance.new("UIListLayout")
TreeLayout.Padding = UDim.new(0, 2)
TreeLayout.SortOrder = Enum.SortOrder.LayoutOrder
TreeLayout.Parent = TreeScroll

local PropHeader = Instance.new("TextLabel")
PropHeader.BackgroundTransparency = 1
PropHeader.Font = Enum.Font.GothamSemibold
PropHeader.TextSize = 16
PropHeader.TextColor3 = Theme.text
PropHeader.TextXAlignment = Enum.TextXAlignment.Left
PropHeader.Text = "Propriedades"
PropHeader.Size = UDim2.new(1, -16, 0, 28)
PropHeader.Position = UDim2.new(0, 12, 0, 8)
PropHeader.Parent = RightPane

local PropScroll = Instance.new("ScrollingFrame")
PropScroll.BackgroundTransparency = 1
PropScroll.BorderSizePixel = 0
PropScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
PropScroll.ScrollingDirection = Enum.ScrollingDirection.Y
PropScroll.ScrollBarThickness = 6
PropScroll.Size = UDim2.new(1, -24, 1, -48)
PropScroll.Position = UDim2.new(0, 12, 0, 40)
PropScroll.Parent = RightPane

local PropLayout = Instance.new("UIListLayout")
PropLayout.Padding = UDim.new(0, 4)
PropLayout.SortOrder = Enum.SortOrder.LayoutOrder
PropLayout.Parent = PropScroll

-- Barra de status para mensagens
local StatusLabel = Instance.new("TextLabel")
StatusLabel.BackgroundTransparency = 1
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 13
StatusLabel.TextColor3 = Theme.subtext
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Text = ""
StatusLabel.Size = UDim2.new(1, -16, 0, 24)
StatusLabel.Position = UDim2.new(0, 12, 1, -28)
StatusLabel.Parent = RightPane

-- ==============================
--   Arrastar janela e splitter
-- ==============================
do
    local dragging = false
    local dragStart, startPos
    TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = Main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    Services.UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

do
    local resizing = false
    local dragStart, startX
    Splitter.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizing = true
            dragStart = input.Position
            startX = LeftPane.Size.X.Offset
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then resizing = false end
            end)
        end
    end)
    Services.UserInputService.InputChanged:Connect(function(input)
        if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            local w = math.clamp(startX + delta.X, 240, 600)
            LeftPane.Size = UDim2.new(0, w, 1, 0)
            Splitter.Position = UDim2.new(0, w, 0, 0)
            RightPane.Position = UDim2.new(0, w + 4, 0, 0)
            RightPane.Size = UDim2.new(1, -(w + 4), 1, 0)
        end
    end)
end

-- ==============================
--           Explorer
-- ==============================
local Selected
local SelectionBox

local function setStatus(msg)
    StatusLabel.Text = msg or ""
end

local function clearChildren(gui)
    for _,c in ipairs(gui:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
end

local function rowProperty(name, value, inst, allowEdit)
    local Row = Instance.new("Frame")
    Row.BackgroundColor3 = Theme.bg
    Row.Size = UDim2.new(1, 0, 0, 30)
    Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 6)
    Instance.new("UIStroke", Row).Color = Theme.stroke

    local L = Instance.new("TextLabel")
    L.BackgroundTransparency = 1
    L.Font = Enum.Font.GothamSemibold
    L.TextSize = 13
    L.TextColor3 = Theme.text
    L.TextXAlignment = Enum.TextXAlignment.Left
    L.Text = name
    L.Size = UDim2.new(0.35, -8, 1, 0)
    L.Position = UDim2.new(0, 8, 0, 0)
    L.Parent = Row

    local V = Instance.new("TextBox")
    V.BackgroundTransparency = allowEdit and 0 or 1
    V.BackgroundColor3 = Theme.panel2
    V.ClearTextOnFocus = false
    V.Font = Enum.Font.Gotham
    V.TextSize = 13
    V.TextXAlignment = Enum.TextXAlignment.Left
    V.TextColor3 = allowEdit and Theme.text or Theme.subtext
    V.TextEditable = allowEdit
    V.Text = serialize(value)
    V.Size = UDim2.new(0.65, -12, 1, -8)
    V.Position = UDim2.new(0.35, 4, 0, 4)
    Instance.new("UICorner", V).CornerRadius = UDim.new(0, 6)
    if allowEdit then Instance.new("UIStroke", V).Color = Theme.stroke end
    V.Parent = Row

    if allowEdit then
        V.FocusLost:Connect(function(enter)
            if not enter then return end
            local ok, cur = pcall(function() return inst[name] end)
            if not ok then
                setStatus("Propriedade protegida ou inexistente")
                return
            end
            local new = smartParse(cur, V.Text)
            if new == nil then
                setStatus("Formato inválido para " .. name)
                V.Text = serialize(cur)
                return
            end
            local success, err = pcall(function()
                inst[name] = new
            end)
            if success then
                V.Text = serialize(inst[name])
                setStatus("Atualizado " .. name)
            else
                setStatus("Erro ao atualizar: " .. tostring(err))
                V.Text = serialize(cur)
            end
        end)
    end

    return Row
end

local function getClassFallbackProps(inst)
    local class = inst.ClassName
    if inst:IsA("BasePart") then
        return COMMON_PROPS["Workspace/BasePart"]
    elseif inst:IsA("Model") then
        return COMMON_PROPS["Workspace/Model"]
    elseif inst:IsA("GuiObject") then
        return COMMON_PROPS["GuiObject"]
    else
        return COMMON_PROPS[class] or COMMON_PROPS["Instance"]
    end
end

local function buildPropertyPanel(inst, allowEdit)
    clearChildren(PropScroll)
    PropHeader.Text = ("Propriedades — %s (%s)"):format(inst.Name, inst.ClassName)

    -- Nome e classe sempre no topo
    PropLayout.Parent = nil
    rowProperty("Name", inst.Name, inst, allowEdit).Parent = PropScroll
    rowProperty("ClassName", inst.ClassName, inst, false).Parent = PropScroll

    -- Atributos do Roblox
    local propsListed = {}
    local function addProp(p)
        if propsListed[p] then return end
        local ok, v = pcall(function() return inst[p] end)
        if ok then
            propsListed[p] = true
            rowProperty(p, v, inst, allowEdit).Parent = PropScroll
        end
    end

    -- via executor getproperties
    if getproperties_fn then
        local ok, list = pcall(function() return getproperties_fn(inst) end)
        if ok and type(list) == "table" then
            for _,p in ipairs(list) do
                addProp(p)
            end
        end
    end

    -- fallback por classe
    for _,p in ipairs(getClassFallbackProps(inst)) do
        addProp(p)
    end

    -- Attributes do usuário
    local attrs = {}
    pcall(function() attrs = inst:GetAttributes() end)
    if attrs and next(attrs) ~= nil then
        local sep = Instance.new("TextLabel")
        sep.BackgroundTransparency = 1
        sep.Text = "Atributos"
        sep.Font = Enum.Font.GothamSemibold
        sep.TextSize = 14
        sep.TextColor3 = Theme.subtext
        sep.TextXAlignment = Enum.TextXAlignment.Left
        sep.Size = UDim2.new(1, -8, 0, 24)
        sep.Parent = PropScroll
        for k,v in pairs(attrs) do
            local Row = Instance.new("Frame")
            Row.BackgroundColor3 = Theme.bg
            Row.Size = UDim2.new(1, 0, 0, 30)
            Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 6)
            Instance.new("UIStroke", Row).Color = Theme.stroke

            local L = Instance.new("TextLabel")
            L.BackgroundTransparency = 1
            L.Font = Enum.Font.GothamSemibold
            L.TextSize = 13
            L.TextColor3 = Theme.text
            L.TextXAlignment = Enum.TextXAlignment.Left
            L.Text = "[Attr] "..k
            L.Size = UDim2.new(0.35, -8, 1, 0)
            L.Position = UDim2.new(0, 8, 0, 0)
            L.Parent = Row

            local V = Instance.new("TextBox")
            V.BackgroundColor3 = Theme.panel2
            V.ClearTextOnFocus = false
            V.Font = Enum.Font.Gotham
            V.TextSize = 13
            V.TextXAlignment = Enum.TextXAlignment.Left
            V.TextColor3 = Theme.text
            V.Text = serialize(v)
            V.Size = UDim2.new(0.65, -12, 1, -8)
            V.Position = UDim2.new(0.35, 4, 0, 4)
            Instance.new("UICorner", V).CornerRadius = UDim.new(0, 6)
            Instance.new("UIStroke", V).Color = Theme.stroke
            V.Parent = Row

            V.FocusLost:Connect(function(enter)
                if not enter then return end
                local parsed = tonumber(V.Text) or (V.Text:lower() == "true" and true) or (V.Text:lower() == "false" and false) or V.Text
                pcall(function() inst:SetAttribute(k, parsed) end)
            end)

            Row.Parent = PropScroll
        end
    end

    PropLayout.Parent = PropScroll
    PropScroll.CanvasSize = UDim2.new(0, 0, 0, PropLayout.AbsoluteContentSize.Y + 16)

    -- Conecta auto-update de propriedades básicas
    local conn
    conn = inst.Changed:Connect(function(p)
        -- Atualiza só a linha do Name rapidamente
        if p == "Name" then
            PropHeader.Text = ("Propriedades — %s (%s)"):format(inst.Name, inst.ClassName)
        end
    end)
    inst.AncestryChanged:Connect(function()
        if not inst:IsDescendantOf(game) then
            setStatus("Instância destruída")
            Selected = nil
            clearChildren(PropScroll)
        end
    end)
end

local function makeTreeRow(inst, depth)
    local Row = Instance.new("Frame")
    Row.BackgroundColor3 = Theme.bg
    Row.Size = UDim2.new(1, -8, 0, 26)
    Row.LayoutOrder = depth
    Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 6)
    Instance.new("UIStroke", Row).Color = Theme.stroke

    local Toggle = Instance.new("TextButton")
    Toggle.BackgroundTransparency = 1
    Toggle.Text = "▶"
    Toggle.Font = Enum.Font.GothamSemibold
    Toggle.TextSize = 12
    Toggle.TextColor3 = Theme.subtext
    Toggle.Size = UDim2.new(0, 24, 1, 0)
    Toggle.Position = UDim2.new(0, 6 + depth * 12, 0, 0)
    Toggle.Parent = Row

    local NameBtn = Instance.new("TextButton")
    NameBtn.BackgroundTransparency = 1
    NameBtn.TextXAlignment = Enum.TextXAlignment.Left
    NameBtn.Font = Enum.Font.Gotham
    NameBtn.TextSize = 13
    NameBtn.TextColor3 = Theme.text
    NameBtn.Text = string.format("%s  [%s]", inst.Name, inst.ClassName)
    NameBtn.Size = UDim2.new(1, -60 - depth * 12, 1, 0)
    NameBtn.Position = UDim2.new(0, 30 + depth * 12, 0, 0)
    NameBtn.Parent = Row

    local ChildrenContainer = Instance.new("Frame")
    ChildrenContainer.BackgroundTransparency = 1
    ChildrenContainer.Size = UDim2.new(1, 0, 0, 0)
    ChildrenContainer.Parent = Row

    local ChildLayout = Instance.new("UIListLayout")
    ChildLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ChildLayout.Padding = UDim.new(0, 2)
    ChildLayout.Parent = ChildrenContainer

    local expanded = false
    local function refreshChildren()
        clearChildren(ChildrenContainer)
        local kids = {}
        pcall(function() kids = inst:GetChildren() end)
        table.sort(kids, function(a, b) return a.Name:lower() < b.Name:lower() end)
        for _,child in ipairs(kids) do
            local sub = makeTreeRow(child, depth + 1)
            sub.Parent = ChildrenContainer
        end
        ChildrenContainer.Size = UDim2.new(1, 0, 0, ChildLayout.AbsoluteContentSize.Y)
        ChildLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            ChildrenContainer.Size = UDim2.new(1, 0, 0, ChildLayout.AbsoluteContentSize.Y)
            Services.RunService.Heartbeat:Wait()
            TreeScroll.CanvasSize = UDim2.new(0, 0, 0, TreeLayout.AbsoluteContentSize.Y + 16)
        end)
    end

    Toggle.MouseButton1Click:Connect(function()
        expanded = not expanded
        Toggle.Text = expanded and "▼" or "▶"
        if expanded then
            refreshChildren()
        else
            clearChildren(ChildrenContainer)
            ChildrenContainer.Size = UDim2.new(1, 0, 0, 0)
        end
        Services.RunService.Heartbeat:Wait()
        TreeScroll.CanvasSize = UDim2.new(0, 0, 0, TreeLayout.AbsoluteContentSize.Y + 16)
    end)

    NameBtn.MouseButton1Click:Connect(function()
        Selected = inst
        buildPropertyPanel(inst, ToggleEditBtn.Text:find("LIGADA") ~= nil)
        setStatus("Selecionado: " .. getFullPath(inst))

        -- SelectionBox para partes
        if SelectionBox then SelectionBox:Destroy() end
        if inst:IsA("BasePart") then
            SelectionBox = Instance.new("SelectionBox")
            SelectionBox.Name = "MayunieDexSelection"
            SelectionBox.LineThickness = 0.03
            SelectionBox.SurfaceTransparency = 1
            SelectionBox.Color3 = Theme.accent
            SelectionBox.Adornee = inst
            SelectionBox.Parent = inst
        end
    end)

    -- Auto-update do ramo
    inst.ChildAdded:Connect(function()
        if expanded then refreshChildren() end
    end)
    inst.ChildRemoved:Connect(function()
        if expanded then refreshChildren() end
    end)

    return Row
end

local ROOTS = {
    Services.Workspace,
    Services.Players,
    Services.ReplicatedStorage,
    Services.StarterGui,
    Services.StarterPack,
    Services.ServerStorage,
    Services.ServerScriptService,
    Services.ReplicatedFirst,
    Services.Lighting,
    Services.SoundService,
    Services.HttpService,
    Services.Chat,
    Services.CoreGui,
}

local function buildTree()
    clearChildren(TreeScroll)
    for i,root in ipairs(ROOTS) do
        local node = makeTreeRow(root, 0)
        node.Parent = TreeScroll
    end
    TreeScroll.CanvasSize = UDim2.new(0, 0, 0, TreeLayout.AbsoluteContentSize.Y + 16)
end

-- ==============================
--           Busca
-- ==============================
local ResultsDrop = Instance.new("Frame")
ResultsDrop.BackgroundColor3 = Theme.panel2
ResultsDrop.Visible = false
ResultsDrop.Size = UDim2.new(0, 280, 0, 180)
ResultsDrop.Position = UDim2.new(0, 260, 0, 40)
ResultsDrop.Parent = Main
Instance.new("UICorner", ResultsDrop).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", ResultsDrop).Color = Theme.stroke

local ResultsScroll = Instance.new("ScrollingFrame")
ResultsScroll.BackgroundTransparency = 1
ResultsScroll.Size = UDim2.new(1, -8, 1, -8)
ResultsScroll.Position = UDim2.new(0, 4, 0, 4)
ResultsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
ResultsScroll.ScrollBarThickness = 6
ResultsScroll.Parent = ResultsDrop
local ResultsLayout = Instance.new("UIListLayout", ResultsScroll)
ResultsLayout.Padding = UDim.new(0, 4)

local function addResultItem(inst)
    local Btn = Instance.new("TextButton")
    Btn.BackgroundColor3 = Theme.bg
    Btn.Size = UDim2.new(1, 0, 0, 28)
    Btn.TextXAlignment = Enum.TextXAlignment.Left
    Btn.Font = Enum.Font.Gotham
    Btn.TextSize = 13
    Btn.TextColor3 = Theme.text
    Btn.Text = inst.Name .. "  [" .. inst.ClassName .. "]"
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)
    Instance.new("UIStroke", Btn).Color = Theme.stroke
    Btn.Parent = ResultsScroll

    Btn.MouseButton1Click:Connect(function()
        Selected = inst
        buildPropertyPanel(inst, ToggleEditBtn.Text:find("LIGADA") ~= nil)
        setStatus("Selecionado: " .. getFullPath(inst))
        ResultsDrop.Visible = false

        if SelectionBox then SelectionBox:Destroy() end
        if inst:IsA("BasePart") then
            SelectionBox = Instance.new("SelectionBox")
            SelectionBox.LineThickness = 0.03
            SelectionBox.SurfaceTransparency = 1
            SelectionBox.Color3 = Theme.accent
            SelectionBox.Adornee = inst
            SelectionBox.Parent = inst
        end
    end)
end

local function runSearch(query)
    clearChildren(ResultsScroll)
    if not query or query == "" then
        ResultsDrop.Visible = false
        return
    end
    query = query:lower()

    local matches = {}
    local function scan(root)
        for _,d in ipairs(root:GetDescendants()) do
            local ok, cname = pcall(function() return d.ClassName end)
            local ok2, nm = pcall(function() return d.Name end)
            if ok and ok2 then
                if nm:lower():find(query, 1, true) or cname:lower():find(query, 1, true) then
                    table.insert(matches, d)
                    if #matches >= 200 then return end
                end
            end
        end
    end
    for _,root in ipairs(ROOTS) do
        pcall(scan, root)
        if #matches >= 200 then break end
    end

    for _,inst in ipairs(matches) do
        addResultItem(inst)
    end
    ResultsDrop.Visible = #matches > 0
    ResultsScroll.CanvasSize = UDim2.new(0, 0, 0, ResultsLayout.AbsoluteContentSize.Y + 8)
end

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    runSearch(SearchBox.Text)
end)

-- ==============================
--     Botões de topo e toggle
-- ==============================
RefreshBtn.MouseButton1Click:Connect(function()
    buildTree()
    setStatus("Árvore atualizada")
end)

CopyPathBtn.MouseButton1Click:Connect(function()
    if not Selected then setStatus("Nada selecionado") return end
    local path = getFullPath(Selected)
    if safeSetClipboard(path) then
        setStatus("Caminho copiado")
    else
        setStatus("Clipboard indisponível — exibindo no status")
        StatusLabel.Text = path
    end
end)

ToggleEditBtn.MouseButton1Click:Connect(function()
    local enabled = ToggleEditBtn.Text:find("DESLIGADA") ~= nil
    if enabled then
        ToggleEditBtn.Text = "Edição: LIGADA"
        ToggleEditBtn.TextColor3 = Theme.ok
        if Selected then buildPropertyPanel(Selected, true) end
        setStatus("Edição habilitada")
    else
        ToggleEditBtn.Text = "Edição: DESLIGADA"
        ToggleEditBtn.TextColor3 = Theme.warn
        if Selected then buildPropertyPanel(Selected, false) end
        setStatus("Edição desabilitada")
    end
end)

-- Hotkey RightCtrl para mostrar/ocultar
local visible = true
Services.UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightControl then
        visible = not visible
        ScreenGui.Enabled = visible
    end
end)

-- ==============================
--     Inicialização da árvore
-- ==============================
buildTree()
setStatus("Pronto")

-- Opcional: tente selecionar Workspace por padrão
task.defer(function()
    local ok, _ = pcall(function()
        Selected = Services.Workspace
        buildPropertyPanel(Selected, false)
        setStatus("Selecionado: Workspace")
    end)
end)
