-- Roblox Teleport GUI - by ChatGPT (clean version)
-- Requisitos esperados no executor: game:HttpGet, isfile/writefile/readfile, getclipboard (opcional)

--=== Serviços ===--
local Players            = game:GetService("Players")
local TeleportService    = game:GetService("TeleportService")
local TweenService       = game:GetService("TweenService")
local UserInputService   = game:GetService("UserInputService")
local RunService         = game:GetService("RunService")
local LocalizationService= game:GetService("LocalizationService")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

--=== Localização simples (pt/en) ===--
local function lang()
    local id = tostring(LocalizationService.RobloxLocaleId or "en")
    if id:sub(1,2) == "pt" then return "pt" end
    return "en"
end
local L = lang()
local T = {
    en = {
        title="Teleport GUI",
        place="PlaceId",
        job="JobId (GUID)",
        paste="Paste",
        tp="Teleport",
        status="Status",
        ok="Ready",
        badGuid="Invalid JobId format",
        noPlace="Invalid PlaceId",
        tpStart="Teleporting...",
        tpDone="Teleport requested",
        used="Already used JobId",
        saved="Saved",
        history="Save used JobIds",
        toggle="Press RightShift to toggle",
    },
    pt = {
        title="Teleport GUI",
        place="PlaceId",
        job="JobId (GUID)",
        paste="Colar",
        tp="Teleportar",
        status="Status",
        ok="Pronto",
        badGuid="Formato de JobId inválido",
        noPlace="PlaceId inválido",
        tpStart="Teleportando...",
        tpDone="Teleport solicitado",
        used="JobId já utilizado",
        saved="Salvo",
        history="Salvar JobIds usados",
        toggle="Pressione RightShift para mostrar/ocultar",
    }
}
local TX = T[L]

--=== Config/Historico ===--
local DEFAULT_PLACEID = 109983668079237 -- o mesmo do seu script
local USED_FILE = "used_jobids.json"
local used = {}

pcall(function()
    if isfile and isfile(USED_FILE) then
        local raw = readfile(USED_FILE)
        local ok, data = pcall(function() return game:GetService("HttpService"):JSONDecode(raw) end)
        if ok and type(data) == "table" then used = data end
    end
end)
local function save_used()
    pcall(function()
        if writefile then
            writefile(USED_FILE, game:GetService("HttpService"):JSONEncode(used))
        end
    end)
end

--=== Util ===--
local function is_uuid(s)
    -- Roblox JobId é um GUID do tipo 8-4-4-4-12 (hex). Aceita maiúsculas/minúsculas.
    if type(s) ~= "string" then return false end
    s = s:gsub("%s+", "")
    return s:match("^[%x]+%-%x+%-%x+%-%x+%-%x+$") ~= nil
end
local function parse_place(text)
    local n = tonumber((text or ""):gsub("%s",""))
    if n and n > 0 then return math.floor(n) end
    return nil
end

--=== GUI ===--
if PG:FindFirstChild("TP_GUI") then PG.TP_GUI:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "TP_GUI"
gui.ResetOnSpawn = false
gui.Parent = PG

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(420, 220)
frame.Position = UDim2.new(0.5, -210, 0.45, -110)
frame.BackgroundColor3 = Color3.fromRGB(26,26,32)
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner", frame)
corner.CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", frame)
stroke.Thickness = 2
stroke.Color = Color3.fromRGB(60,120,255)
stroke.Transparency = 0.6

-- Draggable
local dragging, dragStart, startPos
frame.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = i.Position
        startPos = frame.Position
        i.Changed:Connect(function()
            if i.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = i.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Title
local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = TX.title
title.TextColor3 = Color3.fromRGB(255,255,255)
title.Size = UDim2.new(1, -20, 0, 28)
title.Position = UDim2.fromOffset(10, 8)
title.Parent = frame

-- Hint
local hint = Instance.new("TextLabel")
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.Gotham
hint.TextSize = 12
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.Text = TX.toggle
hint.TextColor3 = Color3.fromRGB(170,170,170)
hint.Size = UDim2.new(1, -20, 0, 16)
hint.Position = UDim2.fromOffset(10, 30)
hint.Parent = frame

-- Labels/Inputs
local function makeLabel(text, y)
    local lb = Instance.new("TextLabel")
    lb.BackgroundTransparency = 1
    lb.Font = Enum.Font.Gotham
    lb.TextSize = 14
    lb.TextXAlignment = Enum.TextXAlignment.Left
    lb.Text = text
    lb.TextColor3 = Color3.fromRGB(220,220,220)
    lb.Size = UDim2.new(0, 90, 0, 24)
    lb.Position = UDim2.fromOffset(12, y)
    lb.Parent = frame
    return lb
end

local function makeBox(placeholder, y)
    local tb = Instance.new("TextBox")
    tb.Font = Enum.Font.Gotham
    tb.TextSize = 14
    tb.PlaceholderText = placeholder
    tb.Text = ""
    tb.ClearTextOnFocus = false
    tb.BackgroundColor3 = Color3.fromRGB(36,36,44)
    tb.TextColor3 = Color3.fromRGB(255,255,255)
    tb.BorderSizePixel = 0
    tb.Size = UDim2.new(1, -130, 0, 28)
    tb.Position = UDim2.fromOffset(105, y)
    tb.Parent = frame
    Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 6)
    local s = Instance.new("UIStroke", tb)
    s.Thickness = 1
    s.Color = Color3.fromRGB(70,70,90)
    s.Transparency = 0.4
    return tb
end

makeLabel(TX.place, 64)
local placeBox = makeBox(TX.place, 64)
placeBox.Text = tostring(DEFAULT_PLACEID)

makeLabel(TX.job, 100)
local jobBox = makeBox(TX.job, 100)

-- Buttons
local function makeBtn(text, pos)
    local b = Instance.new("TextButton")
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.BackgroundColor3 = Color3.fromRGB(40,110,255)
    b.AutoButtonColor = false
    b.Size = UDim2.fromOffset(120, 32)
    b.Position = pos
    b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(70,140,255)}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(40,110,255)}):Play()
    end)
    return b
end

local pasteBtn = makeBtn(TX.paste, UDim2.fromOffset(290, 98))
local tpBtn    = makeBtn(TX.tp,    UDim2.fromOffset(290, 140))

-- Status
local statusTitle = Instance.new("TextLabel")
statusTitle.BackgroundTransparency = 1
statusTitle.Font = Enum.Font.Gotham
statusTitle.TextSize = 14
statusTitle.TextXAlignment = Enum.TextXAlignment.Left
statusTitle.Text = TX.status .. ":"
statusTitle.TextColor3 = Color3.fromRGB(220,220,220)
statusTitle.Size = UDim2.new(0, 60, 0, 24)
statusTitle.Position = UDim2.fromOffset(12, 148)
statusTitle.Parent = frame

local statusText = Instance.new("TextLabel")
statusText.BackgroundTransparency = 1
statusText.Font = Enum.Font.Gotham
statusText.TextSize = 14
statusText.TextXAlignment = Enum.TextXAlignment.Left
statusText.Text = TX.ok
statusText.TextColor3 = Color3.fromRGB(120,255,140)
statusText.Size = UDim2.new(1, -80, 0, 24)
statusText.Position = UDim2.fromOffset(72, 148)
statusText.Parent = frame

local saveChk = Instance.new("TextButton")
saveChk.Font = Enum.Font.Gotham
saveChk.TextSize = 13
saveChk.TextXAlignment = Enum.TextXAlignment.Left
saveChk.AutoButtonColor = false
saveChk.BackgroundColor3 = Color3.fromRGB(36,36,44)
saveChk.TextColor3 = Color3.fromRGB(220,220,220)
saveChk.Text = "☑ " .. TX.history
saveChk.Size = UDim2.new(1, -24, 0, 26)
saveChk.Position = UDim2.fromOffset(12, 180)
saveChk.Parent = frame
Instance.new("UICorner", saveChk).CornerRadius = UDim.new(0, 6)
local saveEnabled = true
saveChk.MouseButton1Click:Connect(function()
    saveEnabled = not saveEnabled
    saveChk.Text = (saveEnabled and "☑ " or "☐ ") .. TX.history
end)

-- Paste
pasteBtn.MouseButton1Click:Connect(function()
    if getclipboard then
        local txt = tostring(getclipboard()):gsub("%s+","")
        jobBox.Text = txt
        if is_uuid(txt) then
            statusText.Text = TX.ok
            statusText.TextColor3 = Color3.fromRGB(120,255,140)
        else
            statusText.Text = TX.badGuid
            statusText.TextColor3 = Color3.fromRGB(255,120,120)
        end
    else
        statusText.Text = "getclipboard não disponível"
        statusText.TextColor3 = Color3.fromRGB(255,180,120)
    end
end)

-- Teleport logic
local function doTeleport()
    local placeId = parse_place(placeBox.Text)
    if not placeId then
        statusText.Text = TX.noPlace
        statusText.TextColor3 = Color3.fromRGB(255,120,120)
        return
    end
    local jobId = tostring(jobBox.Text or ""):gsub("%s+","")
    if not is_uuid(jobId) then
        statusText.Text = TX.badGuid
        statusText.TextColor3 = Color3.fromRGB(255,120,120)
        return
    end
    if used[jobId] then
        statusText.Text = TX.used
        statusText.TextColor3 = Color3.fromRGB(255,180,120)
        -- ainda permite tentar mesmo assim
    end

    statusText.Text = TX.tpStart
    statusText.TextColor3 = Color3.fromRGB(220,220,120)

    -- registra como usado antes para evitar repetição
    if saveEnabled then
        used[jobId] = true
        save_used()
    end

    -- tenta teleportar
    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(placeId, jobId, LP)
    end)
    if ok then
        statusText.Text = TX.tpDone
        statusText.TextColor3 = Color3.fromRGB(120,255,140)
    else
        statusText.Text = tostring(err)
        statusText.TextColor3 = Color3.fromRGB(255,120,120)
    end
end

tpBtn.MouseButton1Click:Connect(doTeleport)

-- Enter envia
jobBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then doTeleport() end
end)

-- Toggle de visibilidade
local visible = true
UserInputService.InputBegan:Connect(function(i, gpe)
    if gpe then return end
    if i.KeyCode == Enum.KeyCode.RightShift then
        visible = not visible
        gui.Enabled = visible
    end
end)

-- Pulse visual de qualidade
local function pulse(inst, to)
    TweenService:Create(inst, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), to):Play()
end
for _,b in ipairs({tpBtn,pasteBtn}) do
    b.MouseButton1Down:Connect(function() pulse(b, {Size = UDim2.fromOffset(b.Size.X.Offset-4, b.Size.Y.Offset-2)}) end)
    b.MouseButton1Up:Connect(function() pulse(b, {Size = UDim2.fromOffset(b.Size.X.Offset+4, b.Size.Y.Offset+2)}) end)
end
