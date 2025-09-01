-- Teleport GUI – Delta friendly with diagnostics
local Players             = game:GetService("Players")
local TeleportService     = game:GetService("TeleportService")
local TweenService        = game:GetService("TweenService")
local UserInputService    = game:GetService("UserInputService")
local StarterGui          = game:GetService("StarterGui")
local LocalizationService = game:GetService("LocalizationService")
local HttpService         = game:GetService("HttpService")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

local function log(msg)
    pcall(function() if rconsoleprint then rconsoleprint("[TP-GUI] "..tostring(msg).."\n") end end)
    print("[TP-GUI] "..tostring(msg))
end
local function notify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title = title, Text = text, Duration = 5})
    end)
end

-- i18n simples
local lang = (tostring(LocalizationService.RobloxLocaleId or "en"):sub(1,2) == "pt") and "pt" or "en"
local TX = (lang == "pt") and {
    title="Teleport GUI",
    place="PlaceId",
    job="JobId",
    paste="Colar",
    tp="Teleportar",
    tpsimple="Testar Teleport simples",
    status="Status",
    ok="Pronto",
    badGuid="JobId inválido",
    noPlace="PlaceId inválido",
    tpStart="Teleportando...",
    tpDone="Teleport solicitado",
    used="JobId já salvo",
    history="Salvar JobIds usados",
    toggle="RightShift mostra/oculta",
    noclip="Clipboard indisponível; cole manualmente",
    useCurrent="Usar PlaceId atual",
} or {
    title="Teleport GUI",
    place="PlaceId",
    job="JobId",
    paste="Paste",
    tp="Teleport",
    tpsimple="Test simple Teleport",
    status="Status",
    ok="Ready",
    badGuid="Invalid JobId",
    noPlace="Invalid PlaceId",
    tpStart="Teleporting...",
    tpDone="Teleport requested",
    used="JobId already saved",
    history="Save used JobIds",
    toggle="RightShift toggles",
    noclip="Clipboard not available; paste manually",
    useCurrent="Use current PlaceId",
}

-- Config/histórico
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
        if writefile then writefile(USED_FILE, HttpService:JSONEncode(used)) end
    end)
end

-- Normalização JobId: minúsculas, permite 32 hex sem hífen, remove aspas/chaves
local function normalize_jobid(s)
    if type(s) ~= "string" then return nil end
    s = s:gsub("%s+",""):gsub("[\"{}']","")
    local lower = s:lower()

    if lower:match("^[%x]+%-%x+%-%x+%-%x+%-%x+$") then
        return lower
    end
    if lower:match("^[a-f0-9]{32}$") then
        return table.concat({
            lower:sub(1,8), "-", lower:sub(9,12), "-", lower:sub(13,16),
            "-", lower:sub(17,20), "-", lower:sub(21,32)
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
frame.Size = UDim2.fromOffset(460, 260)
frame.Position = UDim2.new(0.5, -230, 0.45, -130)
frame.BackgroundColor3 = Color3.fromRGB(26,26,32)
frame.BorderSizePixel = 0
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", frame)
stroke.Thickness = 2
stroke.Color = Color3.fromRGB(60,120,255)
stroke.Transparency = 0.6

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

local function textbox(parent, placeholder, pos, w)
    local tb = Instance.new("TextBox")
    tb.Font = Enum.Font.Gotham
    tb.TextSize = 14
    tb.PlaceholderText = placeholder
    tb.Text = ""
    tb.ClearTextOnFocus = false
    tb.BackgroundColor3 = Color3.fromRGB(36,36,44)
    tb.TextColor3 = Color3.fromRGB(255,255,255)
    tb.BorderSizePixel = 0
    tb.Size = UDim2.fromOffset(w or 250, 28)
    tb.Position = pos
    tb.Parent = parent
    Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 6)
    local s = Instance.new("UIStroke", tb)
    s.Thickness = 1
    s.Color = Color3.fromRGB(70,70,90)
    s.Transparency = 0.4
    return tb
end

local function button(parent, text, pos, w)
    local b = Instance.new("TextButton")
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.BackgroundColor3 = Color3.fromRGB(40,110,255)
    b.AutoButtonColor = false
    b.Size = UDim2.fromOffset(w or 140, 32)
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
local placeBox = textbox(frame, TX.place, UDim2.fromOffset(105,64), 200)
placeBox.Text = tostring(game.PlaceId) -- usa o PlaceId atual por padrão

local useCurrent = Instance.new("TextButton")
useCurrent.Font = Enum.Font.Gotham
useCurrent.TextSize = 13
useCurrent.TextXAlignment = Enum.TextXAlignment.Left
useCurrent.AutoButtonColor = false
useCurrent.BackgroundColor3 = Color3.fromRGB(36,36,44)
useCurrent.TextColor3 = Color3.fromRGB(220,220,220)
useCurrent.Text = "☑ "..TX.useCurrent
useCurrent.Size = UDim2.fromOffset(180, 26)
useCurrent.Position = UDim2.fromOffset(315, 64)
useCurrent.Parent = frame
Instance.new("UICorner", useCurrent).CornerRadius = UDim.new(0, 6)
local useCurrentOn = true
useCurrent.MouseButton1Click:Connect(function()
    useCurrentOn = not useCurrentOn
    useCurrent.Text = (useCurrentOn and "☑ " or "☐ ")..TX.useCurrent
    if useCurrentOn then placeBox.Text = tostring(game.PlaceId) end
end)

label(frame, {text = TX.job, pos = UDim2.fromOffset(12,100)})
local jobBox = textbox(frame, TX.job, UDim2.fromOffset(105,100), 340)

local pasteBtn = button(frame, TX.paste, UDim2.fromOffset(12, 140), 120)
local tpBtn    = button(frame, TX.tp,    UDim2.fromOffset(146, 140), 140)
local tpSimple = button(frame, TX.tpsimple, UDim2.fromOffset(300, 140), 150)

label(frame, {text = TX.status..":", pos = UDim2.fromOffset(12,180)})
local statusText = label(frame, {text = TX.ok, pos = UDim2.fromOffset(72,180), color = Color3.fromRGB(120,255,140)})

local saveChk = Instance.new("TextButton")
saveChk.Font = Enum.Font.Gotham
saveChk.TextSize = 13
saveChk.TextXAlignment = Enum.TextXAlignment.Left
saveChk.AutoButtonColor = false
saveChk.BackgroundColor3 = Color3.fromRGB(36,36,44)
saveChk.TextColor3 = Color3.fromRGB(220,220,220)
saveChk.Text = "☑ "..((lang=="pt") and "Salvar JobIds usados" or "Save used JobIds")
saveChk.Size = UDim2.new(1, -24, 0, 26)
saveChk.Position = UDim2.fromOffset(12, 212)
saveChk.Parent = frame
Instance.new("UICorner", saveChk).CornerRadius = UDim.new(0, 6)
local saveEnabled = true
saveChk.MouseButton1Click:Connect(function()
    saveEnabled = not saveEnabled
    saveChk.Text = (saveEnabled and "☑ " or "☐ ")..((lang=="pt") and "Salvar JobIds usados" or "Save used JobIds")
end)

-- TeleportInitFailed diagnostics
local connected = false
local function connectFailListener()
    if connected then return end
    connected = true
    TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage)
        if player ~= LP then return end
        local msg = string.format("Falha: %s | %s", tostring(teleportResult), tostring(errorMessage))
        statusText.Text = msg
        statusText.TextColor3 = Color3.fromRGB(255,120,120)
        log("TeleportInitFailed: "..msg)
        notify("Teleport", msg)
    end)
end
connectFailListener()

-- Botão Colar
pasteBtn.MouseButton1Click:Connect(function()
    local got = nil
    local ok = pcall(function()
        if getclipboard then got = getclipboard() return end
        if clipboard and clipboard.get then got = clipboard.get() return end
    end)
    if ok and type(got) == "string" and #got > 0 then
        local norm = normalize_jobid(got)
        jobBox.Text = norm or got
        if norm then
            statusText.Text = TX.ok
            statusText.TextColor3 = Color3.fromRGB(120,255,140)
        else
            statusText.Text = TX.badGuid
            statusText.TextColor3 = Color3.fromRGB(255,180,120)
        end
    else
        statusText.Text = TX.noclip
        statusText.TextColor3 = Color3.fromRGB(255,180,120)
        notify("Clipboard", TX.noclip)
    end
end)

-- Execução do Teleport
local function doTeleport()
    local placeId = useCurrentOn and game.PlaceId or parse_place(placeBox.Text)
    if not placeId then
        statusText.Text = TX.noPlace
        statusText.TextColor3 = Color3.fromRGB(255,120,120)
        notify("Teleport", TX.noPlace)
        return
    end
    local norm = normalize_jobid(tostring(jobBox.Text or ""))
    if not norm then
        statusText.Text = TX.badGuid
        statusText.TextColor3 = Color3.fromRGB(255,120,120)
        notify("Teleport", TX.badGuid)
        return
    end

    statusText.Text = TX.tpStart.." "..placeId
    statusText.TextColor3 = Color3.fromRGB(220,220,120)
    log("TeleportToPlaceInstance -> placeId="..tostring(placeId).." jobId="..tostring(norm))

    if saveEnabled then
        used[norm] = true
        save_used()
    end

    connectFailListener()

    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(placeId, norm, LP)
    end)
    if ok then
        statusText.Text = TX.tpDone
        statusText.TextColor3 = Color3.fromRGB(120,255,140)
        notify("Teleport", TX.tpDone)
    else
        statusText.Text = tostring(err)
        statusText.TextColor3 = Color3.fromRGB(255,120,120)
        log("Teleport pcall error: "..tostring(err))
        notify("Teleport", tostring(err))
    end
end

tpBtn.MouseButton1Click:Connect(doTeleport)

-- Teleport simples para diagnóstico: só Teleport(placeId)
tpSimple.MouseButton1Click:Connect(function()
    local placeId = useCurrentOn and game.PlaceId or parse_place(placeBox.Text)
    if not placeId then
        statusText.Text = TX.noPlace
        statusText.TextColor3 = Color3.fromRGB(255,120,120)
        return
    end
    statusText.Text = TX.tpStart.." "..placeId.." [simple]"
    statusText.TextColor3 = Color3.fromRGB(220,220,120)
    log("Teleport (simple) -> placeId="..tostring(placeId))
    connectFailListener()
    local ok, err = pcall(function()
        TeleportService:Teleport(placeId, LP)
    end)
    if ok then
        statusText.Text = TX.tpDone.." [simple]"
        statusText.TextColor3 = Color3.fromRGB(120,255,140)
    else
        statusText.Text = tostring(err)
        statusText.TextColor3 = Color3.fromRGB(255,120,120)
        log("Teleport simple error: "..tostring(err))
    end
end)

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

log("GUI pronta. Digite o JobId e clique Teleportar. Se falhar, veja o Status, a notificação e o output.")
notify("Teleport GUI", "Pronta. Informe o JobId e clique Teleportar.")
