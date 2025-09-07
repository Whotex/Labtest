-- DEX / Staircase Builder (client-side, FE-safe)
-- Cria uma escada ancorada e colidível à frente do seu personagem.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
if not player then return warn("DEX Escada: LocalPlayer não encontrado") end

local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart", 10) or character.PrimaryPart
if not hrp then return warn("DEX Escada: HumanoidRootPart não encontrado") end

-- ====== CONFIGURAÇÕES RÁPIDAS ======
local STEPS            = 18      -- quantidade de degraus
local STEP_HEIGHT      = 1.2     -- altura de cada degrau (studs)
local STEP_DEPTH       = 3       -- profundidade de cada degrau (studs)
local STEP_WIDTH       = 6       -- largura da escada (studs)
local GAP              = 0.05    -- micro folga para evitar z-fighting
local START_AHEAD      = 3       -- distância inicial à frente do player (studs)
local LIFT_ABOVE_GROUND= 8       -- quanto elevar acima do chão (studs)
local MODEL_NAME       = "__DEX_Staircase__"
local COLOR_STEP       = Color3.fromRGB(140,145,160)
local COLOR_TOP        = Color3.fromRGB(120,160,255)

-- Remove escada anterior (se existir)
local old = workspace:FindFirstChild(MODEL_NAME)
if old then old:Destroy() end

-- Model raiz
local model = Instance.new("Model")
model.Name = MODEL_NAME
model.Parent = workspace

-- Raycast helper para achar o chão
local function getGroundY(origin)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character, model}
    params.IgnoreWater = false

    local from = origin + Vector3.new(0, 100, 0)
    local dir  = Vector3.new(0, -1200, 0)
    local hit  = workspace:Raycast(from, dir, params)
    return hit and hit.Position.Y or nil
end

-- Vetores baseados no olhar do player (nivelado no plano XZ)
local look = hrp.CFrame.LookVector
look = Vector3.new(look.X, 0, look.Z)
if look.Magnitude < 0.01 then look = Vector3.new(0,0,-1) end
look = look.Unit

-- Altura inicial
local pos = hrp.Position
local gy  = getGroundY(pos)
local baseY = (gy and math.max(gy + LIFT_ABOVE_GROUND, pos.Y - 1)) or (pos.Y + 4)

-- Primeiro degrau (centro)
local firstCenterY = baseY + (STEP_HEIGHT/2)
local firstPos = pos + look * START_AHEAD
firstPos = Vector3.new(firstPos.X, firstCenterY, firstPos.Z)

-- Função de criação de degrau
local function makeStep(i, atPos, facing)
    local p = Instance.new("Part")
    p.Size = Vector3.new(STEP_WIDTH, STEP_HEIGHT, STEP_DEPTH - GAP)
    p.Anchored = true
    p.CanCollide = true
    p.CanTouch = true
    p.CanQuery = true
    p.Material = Enum.Material.Metal
    p.Color = COLOR_STEP
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Name = string.format("Step_%02d", i)
    p.CFrame = CFrame.lookAt(atPos, atPos + facing)
    p.Parent = model
    p:SetAttribute("DEX_Step", true)
    return p
end

-- Constrói os degraus
for i = 1, STEPS do
    local offsetForward = (i-1) * (STEP_DEPTH + GAP)
    local offsetUp      = (i-1) * (STEP_HEIGHT + GAP)
    local stepPos       = firstPos + look*offsetForward + Vector3.new(0, offsetUp, 0)
    makeStep(i, stepPos, look)
end

-- Plataforma de topo (um “pouso” confortável)
local top = Instance.new("Part")
top.Size = Vector3.new(STEP_WIDTH*1.2, STEP_HEIGHT, STEP_DEPTH*1.6)
top.Anchored = true
top.CanCollide = true
top.CanTouch = true
top.CanQuery = true
top.Material = Enum.Material.Metal
top.Color = COLOR_TOP
top.Name = "TopLanding"
local topPos = firstPos + look*((STEPS-0.5)*(STEP_DEPTH + GAP)) + Vector3.new(0, (STEPS-1)*(STEP_HEIGHT + GAP), 0)
top.CFrame = CFrame.lookAt(topPos, topPos + look)
top.Parent = model

-- Destaque (client-side) para ajudar a localizar
pcall(function()
    local hl = Instance.new("Highlight")
    hl.FillColor = Color3.fromRGB(72,123,255)
    hl.OutlineColor = Color3.fromRGB(220,235,255)
    hl.FillTransparency = 0.85
    hl.Adornee = model
    hl.Parent = model
end)

-- Notificação visual (se disponível)
pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "DEX Escada";
        Text = ("Escada criada: %d degraus."):format(STEPS);
        Duration = 3;
    })
end)

print(("DEX Escada: criada com %d degraus em %s"):format(STEPS, tostring(topPos)))
