-- 4 escadas ao redor do player (~15 m cada), pisáveis, começando alguns metros acima do chão
do
    local Players = game:GetService("Players")
    local StarterGui = game:GetService("StarterGui")

    local plr = Players.LocalPlayer
    if not plr then return end

    local char = plr.Character or plr.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")

    -- ======= Ajustes principais =======
    local lengthStuds = 50       -- ~15 m de extensão horizontal (1 m ≈ 3.3 studs)
    local stepDepth   = 2        -- profundidade de cada degrau (studs)
    local stepHeight  = 0.5      -- subida por degrau (studs) -> ~12.5 studs de ganho total
    local stepWidth   = 4        -- largura da escada (studs)
    local liftAboveGround = 6    -- levanta tudo alguns studs acima do chão para não “sumir”

    -- ======= Base no chão (raycast) com folga =======
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {char}

    local origin = hrp.Position + Vector3.new(0, 200, 0)
    local result = workspace:Raycast(origin, Vector3.new(0, -1000, 0), rayParams)
    local groundY = result and result.Position.Y or (hrp.Position.Y - (hum and hum.HipHeight or 3))
    local baseY = math.max(groundY + 0.5, hrp.Position.Y - (hum and hum.HipHeight or 3)) + liftAboveGround

    -- ======= Container das escadas =======
    local root = Instance.new("Folder")
    root.Name = "AutoStairs_" .. math.floor(os.clock()*100)
    root.Parent = workspace

    -- Direções relativas à orientação do personagem (frente, trás, direita, esquerda)
    local dirs = {
        {v = hrp.CFrame.LookVector,       color = Color3.fromRGB(255, 80,  80),  name = "Front"},
        {v = -hrp.CFrame.LookVector,      color = Color3.fromRGB( 80, 150, 255), name = "Back"},
        {v = hrp.CFrame.RightVector,      color = Color3.fromRGB( 80, 255, 120), name = "Right"},
        {v = -hrp.CFrame.RightVector,     color = Color3.fromRGB(255, 225,  80), name = "Left"},
    }

    local steps = math.max(1, math.floor(lengthStuds / stepDepth))

    for _, d in ipairs(dirs) do
        local dir = d.v.Magnitude > 0 and d.v.Unit or Vector3.new(1,0,0)
        local section = Instance.new("Folder")
        section.Name = "Stairs_" .. d.name
        section.Parent = root

        for i = 1, steps do
            local part = Instance.new("Part")
            part.Name = ("Step_%d"):format(i)
            part.Size = Vector3.new(stepWidth, 1, stepDepth)
            part.Anchored = true
            part.CanCollide = true
            part.Material = Enum.Material.Concrete
            part.TopSurface = Enum.SurfaceType.Smooth
            part.BottomSurface = Enum.SurfaceType.Smooth
            part.Color = d.color

            local offset = dir * (i * stepDepth)
            local pos = Vector3.new(hrp.Position.X, baseY + i * stepHeight, hrp.Position.Z) + offset
            part.CFrame = CFrame.lookAt(pos, pos + dir)
            part.Parent = section
        end
    end

    -- Feedback visual opcional: um marcador no centro (pode apagar)
    local marker = Instance.new("Part")
    marker.Name = "CenterMarker"
    marker.Size = Vector3.new(2, 6, 2)
    marker.Anchored = true
    marker.CanCollide = false
    marker.Color = Color3.fromRGB(255, 0, 255)
    marker.Material = Enum.Material.Neon
    marker.CFrame = CFrame.new(hrp.Position + Vector3.new(0, baseY - (hrp.Position.Y - (hum and hum.HipHeight or 3)), 0))
    marker.Parent = root

    -- Notificação (se suportado)
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title="AutoStairs", Text="Geradas 4 escadas (~15m) ao seu redor", Duration=3})
    end)
end
