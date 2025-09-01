-- Roblox Teleport GUI - Mobile/Delta friendly
-- Limpo, com validação flexível e sem depender de getclipboard

local Players             = game:GetService("Players")
local TeleportService     = game:GetService("TeleportService")
local TweenService        = game:GetService("TweenService")
local UserInputService    = game:GetService("UserInputService")
local LocalizationService = game:GetService("LocalizationService")
local HttpService         = game:GetService("HttpService")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

-- i18n simples
local function lang()
    local id = tostring(LocalizationService.RobloxLocaleId or "en")
    return id:sub(1,2) == "pt" and "pt" or "en"
end
local L = lang()
local TX = {
    en = {
        title="Teleport GUI",
        place="PlaceId",
        job="JobId",
        paste="Paste",
        tp="Teleport",
        status="Status",
        ok="Ready",
        badGuid="Invalid JobId",
        noPlace="Invalid PlaceId",
        tpStart="Teleporting...",
        tpDone="Teleport requested",
        used="JobId already saved",
        history="Save used JobIds",
        toggle="Press RightShift to toggle",
        noclip="Clipboard not available; paste manually",
    },
    pt = {
        title="Teleport GUI",
        place="PlaceId",
        job="JobId",
        paste="Colar",
        tp="Teleportar",
        status="Status",
        ok="Pronto",
        badGuid="JobId inválido",
        noPlace="PlaceId inválido",
        tpStart="Teleportando...",
        tpDone="Teleport solicitado",
        used="JobId já salvo",
        history="Salvar JobIds usados",
        toggle="Pressione RightShift para mostrar/ocultar",
        noclip="Clipboard indisponível; cole manualmente",
    }
}[L]

-- Config/histórico (opcional)
local DEFAULT_PLACEID = 109983668079237
local USED_FILE = "used_jobids.json"
local used = {}

pcall(function()
    if isfile and isfile(USED_FILE) then
        local raw = readfile(USED_FILE)
        local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
        if ok and type(data) == "table" then used = data end
    end
end)

local function save_used()
    pcall(function()
        if writefile then
            writefile(USED_FILE, HttpService:JSONEncode(used))
        end
    end)
end

-- Sanitização/validação flexível de JobId
local function normalize_jobid(s)
    if type(s) ~= "string" then return nil end
    s = s:gsub("%s+", "")
         :gsub("[\"']", "")   -- remove aspas
         :gsub("[{}]", "")    -- remove chaves
         :upper()

    -- já no formato GUID?
    if s:match("^[%x]+%-%x+%-%x+%-%x+%-%x+$") then
        return s
    end

    -- 32 hex sem hífens? Insere 8-4-4-4-12
    if s:match("^[A-F0-9]{32}$") then
        return table.concat({
            s:sub(1,8), "-",
            s:sub(9,12), "-",
            s:sub(13,16), "-",
            s:sub(17,20), "-",
            s:sub(21,32)
        })
    end

    return nil
end

local function parse_place(text)
    local n = tonumber((text or ""):gsub("%s",""))
    if n and n > 0 then return math.floor(n) end
    return nil
end

-- GUI
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
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", frame)
stroke.Thickness = 2
stroke.Color = Color3.fromRGB(60,120,255)
stroke.Transparency = 0.6

-- arrastável
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
        local d = i.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)

local function label(parent, props)
    local x = Instance.new("TextLabel")
    x.BackgroundTransparency = 1
    x.Font = props.bold and Enum.Font.GothamBold or Enum.Font.Gotham
    x.TextSize = props.size or 14
    x.TextXAlignment = props.align or Enum.TextXAlignment.Left
    x.Text = props.text or ""
    x.TextColor3 = props.color or Color3.fromRGB(220,220,220)
    x.Size = props.size2 or UDim2.new(1, -20, 0, 24)
    x.Position = props.pos or UDim2.fromOffset(10, 10)
    x.Parent = parent
    return x
end
local function textbox(parent, placeholder, pos)
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
    tb.Position = pos
    tb.Parent = parent
    Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 6)
    local s = Instance.new("UIStroke", tb)
    s.Thickness = 1
    s.Color = Color3.fromRGB(70,70,90)
    s.Transparency = 0.4
    return tb
end
local function button(parent, text, pos)
    local b = Instance.new("TextButton")
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.BackgroundColor3 = Color3.fromRGB(40,110,255)
    b.AutoButtonColor = false
    b.Size = UDim2.fromOffset(120, 32)
    b.Position = pos
    b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(70,140,255)}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(40,110,255)}):Play()
    end)
    return b
end

label(frame, {text = TX.title, bold = true, size = 18, size2 = UDim2.new(1,-20,0,28), pos = UDim2.fromOffset(10,8), color = Color3.fromRGB(255,255,255)})
label(frame, {text = TX.toggle, size = 12, size2 = UDim2.new(1,-20,0,16), pos = UDim2.fromOffset(10,30), color = Color3.fromRGB(170,170,170)})

label(frame, {text = TX.place, pos = UDim2.fromOffset(12,64)})
local placeBox = textbox(frame, TX.place, UDim2.fromOffset(105,64))
placeBox.Text = tostring(DEFAULT_PLACEID)

label(frame, {text = TX.job, pos = UDim2.fromOffset(12,100)})
local jobBox = textbox(frame, TX.job, UDim2.fromOffset(105,100))

local pasteBtn = button(frame, TX.paste, UDim2.fromOffset(290, 98))
local tpBtn    = button(frame, TX.tp,    UDim2.fromOffset(290, 140))

label(frame, {text = TX.status..":", pos = UDim2.fromOffset(12,148)})
local statusText = label(frame, {text = TX.ok, pos = UDim2.fromOffset(72,148), color = Color3.fromRGB(120,255,140)})

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

-- Botão Colar: tenta getclipboard; se não tiver, apenas informa e NÃO marca erro
pasteBtn.MouseButton1Click:Connect(function()
    local ok, clip = pcall(function()
        -- Vários executores usam nomes diferentes; tentamos alguns
        if getclipboard then return getclipboard() end
        if clipboard and clipboard.get then return clipboard.get() end
        return nil
    end)
    if ok and type(clip) == "string" and #clip > 0 then
        jobBox.Text = clip
        local norm = normalize_jobid(clip)
        if norm then
            jobBox.Text = norm
            statusText.Text = TX.ok
            statusText.TextColor3 = Color3.fromRGB(120,255,140)
        else
            statusText.Text = TX.badGuid
            statusText.TextColor3 = Color3.fromRGB(255,120,120)
        end
    else
        statusText.Text = TX.noclip
        statusText.TextColor3 = Color3.fromRGB(255,180,120)
    end
end)

-- Teleport
local function doTeleport()
    local placeId = parse_place(placeBox.Text)
    if not placeId then
        statusText.Text = TX.noPlace
        statusText.TextColor3 = Color3.fromRGB(255,120,120)
        return
    end

    local raw = tostring(jobBox.Text or "")
    local jobId = normalize_jobid(raw)

    if not jobId then
        statusText.Text = TX.badGuid
        statusText.TextColor3 = Color3.fromRGB(255,120,120)
        return
    end

    if saveEnabled and used[jobId] then
        statusText.Text = TX.used
        statusText.TextColor3 = Color3.fromRGB(255,180,120)
        -- Ainda permite tentar
    end

    statusText.Text = TX.tpStart
    statusText.TextColor3 = Color3.fromRGB(220,220,120)

    if saveEnabled then
        used[jobId] = true
        save_used()
    end

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
