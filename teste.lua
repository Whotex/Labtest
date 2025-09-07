-- Mayunie DEX Explorer - Unified Emulator Friendly
-- Recursos: arvore hierarquica, busca, painel de propriedades com edicao opcional, copy path, SelectionBox, minimizar, compacto, responsivo
-- Tecla: RightCtrl alterna visibilidade

-- ===== Boot seguro e compat =====
if not game:IsLoaded() then game.Loaded:Wait() end
getgenv = getgenv or function() return _G end
local env = (getgenv and getgenv()) or _G
env.setclipboard = env.setclipboard or function() end
env.gethui = env.gethui or function()
    local ok, h = pcall(function() return get_hidden_ui and get_hidden_ui() end)
    if ok and h then return h end
    return game:GetService("CoreGui")
end

local Services = setmetatable({}, {
    __index = function(t, k) local s = game:GetService(k); rawset(t, k, s); return s end
})

pcall(function() local old = Services.CoreGui:FindFirstChild("MayunieDexExplorer"); if old then old:Destroy() end end)

local protect_gui = rawget(getfenv(), "syn") and syn.protect_gui or (protectgui or function() end)
local GUI_PARENT = (gethui and gethui()) or Services.CoreGui

local function typeofRbx(v) local ok,t=pcall(function()return typeof(v)end); if ok then return t end; local mt=getmetatable(v); return mt and mt.__type or type(v) end
local function safeSetClipboard(text) local ok=pcall(function() setclipboard(text) end); return ok end
local function getFullPath(inst)
    if not inst or not inst:IsDescendantOf(game) then return "?" end
    local seg,cur={},inst
    while cur and cur~=game do table.insert(seg,1,("%s[%s]"):format(cur.Name,cur.ClassName)); cur=cur.Parent end
    return "game."..table.concat(seg,".")
end

-- ===== Serializacao e parse =====
local function serialize(v)
    local t=typeofRbx(v)
    if t=="Instance" then return ("%s (%s)"):format(v.Name,v.ClassName)
    elseif t=="Vector3" then return ("%g, %g, %g"):format(v.X,v.Y,v.Z)
    elseif t=="Vector2" then return ("%g, %g"):format(v.X,v.Y)
    elseif t=="UDim2" then return ("{%g, %g}; {%g, %g}"):format(v.X.Scale,v.X.Offset,v.Y.Scale,v.Y.Offset)
    elseif t=="UDim" then return ("%g, %g"):format(v.Scale,v.Offset)
    elseif t=="Color3" then return ("%g, %g, %g"):format(v.R,v.G,v.B)
    elseif t=="CFrame" then local cf=v:GetComponents(); return table.concat(cf,", ")
    elseif t=="BrickColor" or t=="EnumItem" then return v.Name
    elseif t=="string" then return v
    elseif t=="boolean" then return v and "true" or "false"
    elseif t=="number" then return tostring(v)
    elseif t=="table" then return "[table]" end
    return tostring(v)
end

local function parseVector3(s) local x,y,z=s:match("^%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*$"); if x then return Vector3.new(tonumber(x),tonumber(y),tonumber(z)) end end
local function parseVector2(s) local x,y=s:match("^%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*$"); if x then return Vector2.new(tonumber(x),tonumber(y)) end end
local function parseUDim2(s) local sx,ox,sy,oy=s:match("^%s*{%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*}%s*;%s*{%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*}%s*$"); if sx then return UDim2.new(tonumber(sx),tonumber(ox),tonumber(sy),tonumber(oy)) end end
local function parseUDim(s) local a,b=s:match("^%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*$"); if a then return UDim.new(tonumber(a),tonumber(b)) end end
local function parseColor3(s) local r,g,b=s:match("^%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*$"); if r then return Color3.new(tonumber(r),tonumber(g),tonumber(b)) end end
local function parseBool(s) s=s:lower(); if s=="true" or s=="1" or s=="on" or s=="yes" then return true end; if s=="false" or s=="0" or s=="off" or s=="no" then return false end end
local function smartParse(targetValue, txt)
    local t=typeofRbx(targetValue)
    if t=="Vector3" then return parseVector3(txt)
    elseif t=="Vector2" then return parseVector2(txt)
    elseif t=="UDim2" then return parseUDim2(txt)
    elseif t=="UDim" then return parseUDim(txt)
    elseif t=="Color3" then return parseColor3(txt)
    elseif t=="boolean" then return parseBool(txt)
    elseif t=="number" then return tonumber(txt)
    elseif t=="string" then return txt
    elseif t=="EnumItem" then
        local enumType=tostring(targetValue.EnumType) -- "Enum.Material"
        local fam=Enum[enumType:match("Enum%.(.+)$") or ""]
        if fam then
            for _,it in ipairs(fam:GetEnumItems()) do
                if it.Name:lower()==txt:lower() then return it end
            end
        end
    end
end

-- ===== Propriedades por classe =====
local COMMON_PROPS = {
    ["Instance"]={"Name","ClassName","Parent","Archivable"},
    ["Workspace"]={"Gravity","CurrentCamera"},
    ["Players"]={"MaxPlayers","PreferredPlayers","RespawnTime"},
    ["Lighting"]={"Ambient","Brightness","ClockTime","FogColor","FogEnd","FogStart","OutdoorAmbient","GlobalShadows","ShadowSoftness","Technology"},
    ["SoundService"]={"RespectFilteringEnabled","AmbientReverb","DistanceFactor","DopplerScale","RolloffScale","Volume"},
    ["StarterGui"]={"ResetPlayerGuiOnSpawn","ShowDevelopmentGui"},
    ["Workspace/BasePart"]={"Name","Transparency","Reflectance","Material","Color","Size","CFrame","Anchored","CanCollide","CanQuery","CanTouch","CastShadow"},
    ["Workspace/Model"]={"Name","PrimaryPart"},
    ["GuiObject"]={"Name","Visible","Active","ZIndex","AnchorPoint","Position","Size","BackgroundColor3","BackgroundTransparency","BorderSizePixel"},
    ["TextLabel"]={"Text","TextSize","TextColor3","TextTransparency","TextWrapped","RichText"},
    ["TextButton"]={"Text","TextSize","TextColor3","TextTransparency","TextWrapped","AutoButtonColor"},
    ["TextBox"]={"Text","TextSize","TextColor3","TextTransparency","TextWrapped","ClearTextOnFocus","MultiLine"},
    ["ImageLabel"]={"Image","ImageTransparency","ScaleType"},
    ["ImageButton"]={"Image","ImageTransparency","ScaleType"},
    ["ScrollingFrame"]={"CanvasSize","AutomaticCanvasSize","ScrollBarThickness","ScrollingDirection"},
    ["Frame"]={"BackgroundColor3","BackgroundTransparency","BorderSizePixel"},
    ["Folder"]={"Name"},
    ["Sound"]={"SoundId","Volume","PlaybackSpeed","TimePosition","Playing","Looped"},
    ["Camera"]={"CFrame","FieldOfView"},
    ["Humanoid"]={"Health","MaxHealth","WalkSpeed","JumpPower","AutoRotate"},
}
local function fallbackProps(inst)
    if inst:IsA("BasePart") then return COMMON_PROPS["Workspace/BasePart"]
    elseif inst:IsA("Model") then return COMMON_PROPS["Workspace/Model"]
    elseif inst:IsA("GuiObject") then return COMMON_PROPS["GuiObject"]
    else return COMMON_PROPS[inst.ClassName] or COMMON_PROPS["Instance"] end
end

local getproperties_fn = rawget(getfenv(), "getproperties") or rawget(getfenv(), "getprops")

-- ===== GUI base =====
local Theme = {
    bg=Color3.fromRGB(18,18,22), panel=Color3.fromRGB(26,26,32), panel2=Color3.fromRGB(32,32,40),
    stroke=Color3.fromRGB(64,64,80), text=Color3.fromRGB(235,235,245), subtext=Color3.fromRGB(190,190,205),
    accent=Color3.fromRGB(95,135,255), ok=Color3.fromRGB(80,190,120), warn=Color3.fromRGB(255,170,60)
}

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name="MayunieDexExplorer"; ScreenGui.IgnoreGuiInset=true; ScreenGui.ResetOnSpawn=false
pcall(protect_gui, ScreenGui); ScreenGui.Parent = GUI_PARENT

local Main = Instance.new("Frame")
Main.Name="Main"; Main.Size=UDim2.fromOffset(980,560); Main.Position=UDim2.fromScale(0.5,0.5)
Main.AnchorPoint=Vector2.new(0.5,0.5); Main.BackgroundColor3=Theme.panel; Main.Parent=ScreenGui
Instance.new("UICorner",Main).CornerRadius=UDim.new(0,14); local stroke=Instance.new("UIStroke",Main); stroke.Color=Theme.stroke; stroke.Thickness=1

local TopBar = Instance.new("Frame"); TopBar.Name="TopBar"; TopBar.BackgroundColor3=Theme.panel2; TopBar.Size=UDim2.new(1,0,0,44); TopBar.Parent=Main
Instance.new("UICorner",TopBar).CornerRadius=UDim.new(0,14)

local Title = Instance.new("TextLabel")
Title.BackgroundTransparency=1; Title.Font=Enum.Font.GothamSemibold; Title.TextSize=16; Title.TextColor3=Theme.text
Title.TextXAlignment=Enum.TextXAlignment.Left; Title.Text="Mayunie DEX Explorer"; Title.Size=UDim2.new(0,240,1,0); Title.Position=UDim2.new(0,16,0,0); Title.Parent=TopBar

local SearchBox = Instance.new("TextBox")
SearchBox.Size=UDim2.new(0,280,0,28); SearchBox.Position=UDim2.new(0,260,0,8); SearchBox.BackgroundColor3=Theme.bg; SearchBox.TextColor3=Theme.text
SearchBox.PlaceholderColor3=Theme.subtext; SearchBox.PlaceholderText="Buscar por Nome ou ClassName"; SearchBox.Font=Enum.Font.Gotham; SearchBox.TextSize=14
SearchBox.ClearTextOnFocus=false; Instance.new("UICorner",SearchBox).CornerRadius=UDim.new(0,8); Instance.new("UIStroke",SearchBox).Color=Theme.stroke; SearchBox.Parent=TopBar

local RefreshBtn = Instance.new("TextButton")
RefreshBtn.Size=UDim2.new(0,90,0,28); RefreshBtn.Position=UDim2.new(0,550,0,8); RefreshBtn.BackgroundColor3=Theme.bg; RefreshBtn.TextColor3=Theme.text
RefreshBtn.Font=Enum.Font.GothamSemibold; RefreshBtn.TextSize=14; RefreshBtn.Text="Refresh"; Instance.new("UICorner",RefreshBtn).CornerRadius=UDim.new(0,8)
Instance.new("UIStroke",RefreshBtn).Color=Theme.stroke; RefreshBtn.Parent=TopBar

local CopyPathBtn = Instance.new("TextButton")
CopyPathBtn.Size=UDim2.new(0,110,0,28); CopyPathBtn.Position=UDim2.new(0,650,0,8); CopyPathBtn.BackgroundColor3=Theme.bg; CopyPathBtn.TextColor3=Theme.text
CopyPathBtn.Font=Enum.Font.GothamSemibold; CopyPathBtn.TextSize=14; CopyPathBtn.Text="Copy Path"; Instance.new("UICorner",CopyPathBtn).CornerRadius=UDim.new(0,8)
Instance.new("UIStroke",CopyPathBtn).Color=Theme.stroke; CopyPathBtn.Parent=TopBar

local ToggleEditBtn = Instance.new("TextButton")
ToggleEditBtn.Size=UDim2.new(0,140,0,28); ToggleEditBtn.Position=UDim2.new(1,-156,0,8); ToggleEditBtn.AnchorPoint=Vector2.new(1,0)
ToggleEditBtn.BackgroundColor3=Theme.bg; ToggleEditBtn.TextColor3=Theme.warn; ToggleEditBtn.Font=Enum.Font.GothamSemibold; ToggleEditBtn.TextSize=14
ToggleEditBtn.Text="Edicao: DESLIGADA"; Instance.new("UICorner",ToggleEditBtn).CornerRadius=UDim.new(0,8); Instance.new("UIStroke",ToggleEditBtn).Color=Theme.stroke; ToggleEditBtn.Parent=TopBar

local Body = Instance.new("Frame"); Body.BackgroundTransparency=1; Body.Position=UDim2.new(0,0,0,44); Body.Size=UDim2.new(1,0,1,-44); Body.Name="Body"; Body.Parent=Main
local LeftPane = Instance.new("Frame"); LeftPane.BackgroundColor3=Theme.panel; LeftPane.Size=UDim2.new(0,360,1,0); LeftPane.Name="LeftPane"; LeftPane.Parent=Body; Instance.new("UIStroke",LeftPane).Color=Theme.stroke
local Splitter = Instance.new("Frame"); Splitter.BackgroundColor3=Theme.stroke; Splitter.Size=UDim2.new(0,4,1,0); Splitter.Position=UDim2.new(0,360,0,0); Splitter.Name="Splitter"; Splitter.Parent=Body
local RightPane = Instance.new("Frame"); RightPane.BackgroundColor3=Theme.panel; RightPane.Position=UDim2.new(0,364,0,0); RightPane.Size=UDim2.new(1,-364,1,0); RightPane.Name="RightPane"; RightPane.Parent=Body; Instance.new("UIStroke",RightPane).Color=Theme.stroke

local TreeScroll = Instance.new("ScrollingFrame"); TreeScroll.BackgroundTransparency=1; TreeScroll.BorderSizePixel=0; TreeScroll.CanvasSize=UDim2.new(0,0,0,0)
TreeScroll.ScrollingDirection=Enum.ScrollingDirection.Y; TreeScroll.ScrollBarThickness=6; TreeScroll.Size=UDim2.new(1,0,1,0); TreeScroll.Parent=LeftPane
local TreeLayout = Instance.new("UIListLayout"); TreeLayout.Padding=UDim.new(0,2); TreeLayout.SortOrder=Enum.SortOrder.LayoutOrder; TreeLayout.Parent=TreeScroll

local PropHeader = Instance.new("TextLabel"); PropHeader.BackgroundTransparency=1; PropHeader.Font=Enum.Font.GothamSemibold; PropHeader.TextSize=16; PropHeader.TextColor3=Theme.text
PropHeader.TextXAlignment=Enum.TextXAlignment.Left; PropHeader.Text="Propriedades"; PropHeader.Size=UDim2.new(1,-16,0,28); PropHeader.Position=UDim2.new(0,12,0,8); PropHeader.Parent=RightPane

local PropScroll = Instance.new("ScrollingFrame"); PropScroll.BackgroundTransparency=1; PropScroll.BorderSizePixel=0; PropScroll.CanvasSize=UDim2.new(0,0,0,0)
PropScroll.ScrollingDirection=Enum.ScrollingDirection.Y; PropScroll.ScrollBarThickness=6; PropScroll.Size=UDim2.new(1,-24,1,-48); PropScroll.Position=UDim2.new(0,12,0,40); PropScroll.Parent=RightPane
local PropLayout = Instance.new("UIListLayout"); PropLayout.Padding=UDim.new(0,4); PropLayout.SortOrder=Enum.SortOrder.LayoutOrder; PropLayout.Parent=PropScroll

local StatusLabel = Instance.new("TextLabel"); StatusLabel.BackgroundTransparency=1; StatusLabel.Font=Enum.Font.Gotham; StatusLabel.TextSize=13; StatusLabel.TextColor3=Theme.subtext
StatusLabel.TextXAlignment=Enum.TextXAlignment.Left; StatusLabel.Text=""; StatusLabel.Size=UDim2.new(1,-16,0,24); StatusLabel.Position=UDim2.new(0,12,1,-28); StatusLabel.Parent=RightPane

local function setStatus(t) StatusLabel.Text=t or "" end
local function clearChildren(gui) for _,c in ipairs(gui:GetChildren()) do if not c:IsA("UIListLayout") then c:Destroy() end end end

-- ===== Property panel =====
local function rowProperty(name, value, inst, allowEdit)
    local Row = Instance.new("Frame"); Row.BackgroundColor3=Theme.bg; Row.Size=UDim2.new(1,0,0,30)
    Instance.new("UICorner",Row).CornerRadius=UDim.new(0,6); Instance.new("UIStroke",Row).Color=Theme.stroke
    local L = Instance.new("TextLabel"); L.BackgroundTransparency=1; L.Font=Enum.Font.GothamSemibold; L.TextSize=13; L.TextColor3=Theme.text; L.TextXAlignment=Enum.TextXAlignment.Left
    L.Text=name; L.Size=UDim2.new(0.35,-8,1,0); L.Position=UDim2.new(0,8,0,0); L.Parent=Row
    local V = Instance.new("TextBox"); V.BackgroundTransparency=allowEdit and 0 or 1; V.BackgroundColor3=Theme.panel2; V.ClearTextOnFocus=false
    V.Font=Enum.Font.Gotham; V.TextSize=13; V.TextXAlignment=Enum.TextXAlignment.Left; V.TextColor3=allowEdit and Theme.text or Theme.subtext; V.TextEditable=allowEdit
    V.Text=serialize(value); V.Size=UDim2.new(0.65,-12,1,-8); V.Position=UDim2.new(0.35,4,0,4); Instance.new("UICorner",V).CornerRadius=UDim.new(0,6); if allowEdit then Instance.new("UIStroke",V).Color=Theme.stroke end
    V.Parent=Row
    if allowEdit then
        V.FocusLost:Connect(function(enter)
            if not enter then return end
            local ok, cur = pcall(function() return inst[name] end)
            if not ok then setStatus("Propriedade protegida ou inexistente"); return end
            local new = smartParse(cur, V.Text)
            if new==nil then setStatus("Formato invalido para "..name); V.Text=serialize(cur); return end
            local success, err = pcall(function() inst[name]=new end)
            if success then V.Text=serialize(inst[name]); setStatus("Atualizado "..name) else setStatus("Erro: "..tostring(err)); V.Text=serialize(cur) end
        end)
    end
    return Row
end

local function buildPropertyPanel(inst, allowEdit)
    clearChildren(PropScroll)
    PropHeader.Text=("Propriedades — %s (%s)"):format(inst.Name,inst.ClassName)
    PropLayout.Parent=nil
    rowProperty("Name",inst.Name,inst,allowEdit).Parent=PropScroll
    rowProperty("ClassName",inst.ClassName,inst,false).Parent=PropScroll

    local listed={}
    local function addProp(p)
        if listed[p] then return end
        local ok,v=pcall(function() return inst[p] end)
        if ok then listed[p]=true; rowProperty(p,v,inst,allowEdit).Parent=PropScroll end
    end

    if getproperties_fn then
        local ok, list = pcall(function() return getproperties_fn(inst) end)
        if ok and type(list)=="table" then for _,p in ipairs(list) do addProp(p) end end
    end
    for _,p in ipairs(fallbackProps(inst)) do addProp(p) end

    local attrs={} pcall(function() attrs=inst:GetAttributes() end)
    if attrs and next(attrs)~=nil then
        local sep=Instance.new("TextLabel"); sep.BackgroundTransparency=1; sep.Text="Atributos"; sep.Font=Enum.Font.GothamSemibold; sep.TextSize=14; sep.TextColor3=Theme.subtext; sep.TextXAlignment=Enum.TextXAlignment.Left
        sep.Size=UDim2.new(1,-8,0,24); sep.Parent=PropScroll
        for k,v in pairs(attrs) do
            local Row = Instance.new("Frame"); Row.BackgroundColor3=Theme.bg; Row.Size=UDim2.new(1,0,0,30)
            Instance.new("UICorner",Row).CornerRadius=UDim.new(0,6); Instance.new("UIStroke",Row).Color=Theme.stroke
            local L=Instance.new("TextLabel"); L.BackgroundTransparency=1; L.Font=Enum.Font.GothamSemibold; L.TextSize=13; L.TextColor3=Theme.text; L.TextXAlignment=Enum.TextXAlignment.Left
            L.Text="[Attr] "..k; L.Size=UDim2.new(0.35,-8,1,0); L.Position=UDim2.new(0,8,0,0); L.Parent=Row
            local V=Instance.new("TextBox"); V.BackgroundColor3=Theme.panel2; V.ClearTextOnFocus=false; V.Font=Enum.Font.Gotham; V.TextSize=13; V.TextXAlignment=Enum.TextXAlignment.Left; V.TextColor3=Theme.text
            V.Text=serialize(v); V.Size=UDim2.new(0.65,-12,1,-8); V.Position=UDim2.new(0.35,4,0,4); Instance.new("UICorner",V).CornerRadius=UDim.new(0,6); Instance.new("UIStroke",V).Color=Theme.stroke; V.Parent=Row
            V.FocusLost:Connect(function(enter) if not enter then return end; local parsed=tonumber(V.Text) or (V.Text:lower()=="true" and true) or (V.Text:lower()=="false" and false) or V.Text; pcall(function() inst:SetAttribute(k,parsed) end) end)
            Row.Parent=PropScroll
        end
    end

    PropLayout.Parent=PropScroll
    PropScroll.CanvasSize=UDim2.new(0,0,0,PropLayout.AbsoluteContentSize.Y+16)
    inst.Changed:Connect(function(p) if p=="Name" then PropHeader.Text=("Propriedades — %s (%s)"):format(inst.Name,inst.ClassName) end end)
    inst.AncestryChanged:Connect(function() if not inst:IsDescendantOf(game) then setStatus("Instancia destruida"); clearChildren(PropScroll) end end)
end

-- ===== Tree =====
local Selected, SelectionBox

local function makeTreeRow(inst, depth)
    local Row=Instance.new("Frame"); Row.BackgroundColor3=Theme.bg; Row.Size=UDim2.new(1,-8,0,26); Row.LayoutOrder=depth
    Instance.new("UICorner",Row).CornerRadius=UDim.new(0,6); Instance.new("UIStroke",Row).Color=Theme.stroke

    local Toggle=Instance.new("TextButton"); Toggle.BackgroundTransparency=1; Toggle.Text="▶"; Toggle.Font=Enum.Font.GothamSemibold; Toggle.TextSize=12; Toggle.TextColor3=Theme.subtext
    Toggle.Size=UDim2.new(0,24,1,0); Toggle.Position=UDim2.new(0,6+depth*12,0,0); Toggle.Parent=Row

    local NameBtn=Instance.new("TextButton"); NameBtn.BackgroundTransparency=1; NameBtn.TextXAlignment=Enum.TextXAlignment.Left; NameBtn.Font=Enum.Font.Gotham; NameBtn.TextSize=13; NameBtn.TextColor3=Theme.text
    NameBtn.Text=("%s  [%s]"):format(inst.Name,inst.ClassName); NameBtn.Size=UDim2.new(1,-60-depth*12,1,0); NameBtn.Position=UDim2.new(0,30+depth*12,0,0); NameBtn.Parent=Row

    local ChildrenContainer=Instance.new("Frame"); ChildrenContainer.BackgroundTransparency=1; ChildrenContainer.Size=UDim2.new(1,0,0,0); ChildrenContainer.Parent=Row
    local ChildLayout=Instance.new("UIListLayout"); ChildLayout.SortOrder=Enum.SortOrder.LayoutOrder; ChildLayout.Padding=UDim.new(0,2); ChildLayout.Parent=ChildrenContainer

    local expanded=false
    local function refreshChildren()
        clearChildren(ChildrenContainer)
        local kids={} pcall(function() kids=inst:GetChildren() end)
        table.sort(kids,function(a,b) return a.Name:lower()<b.Name:lower() end)
        for _,child in ipairs(kids) do local sub=makeTreeRow(child, depth+1); sub.Parent=ChildrenContainer end
        ChildrenContainer.Size=UDim2.new(1,0,0,ChildLayout.AbsoluteContentSize.Y)
        ChildLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            ChildrenContainer.Size=UDim2.new(1,0,0,ChildLayout.AbsoluteContentSize.Y)
            Services.RunService.Heartbeat:Wait()
            TreeScroll.CanvasSize=UDim2.new(0,0,0,TreeLayout.AbsoluteContentSize.Y+16)
        end)
    end

    Toggle.MouseButton1Click:Connect(function()
        expanded=not expanded; Toggle.Text=expanded and "▼" or "▶"
        if expanded then refreshChildren() else clearChildren(ChildrenContainer); ChildrenContainer.Size=UDim2.new(1,0,0,0) end
        Services.RunService.Heartbeat:Wait()
        TreeScroll.CanvasSize=UDim2.new(0,0,0,TreeLayout.AbsoluteContentSize.Y+16)
    end)

    NameBtn.MouseButton1Click:Connect(function()
        Selected=inst; buildPropertyPanel(inst, ToggleEditBtn.Text:find("LIGADA")~=nil); setStatus("Selecionado: "..getFullPath(inst))
        if SelectionBox then SelectionBox:Destroy() end
        if inst:IsA("BasePart") then
            SelectionBox=Instance.new("SelectionBox"); SelectionBox.Name="MayunieDexSelection"; SelectionBox.LineThickness=0.03; SelectionBox.SurfaceTransparency=1; SelectionBox.Color3=Theme.accent
            SelectionBox.Adornee=inst; SelectionBox.Parent=inst
        end
    end)

    inst.ChildAdded:Connect(function() if expanded then refreshChildren() end end)
    inst.ChildRemoved:Connect(function() if expanded then refreshChildren() end end)

    return Row
end

local ROOTS = {
    Services.Workspace, Services.Players, Services.ReplicatedStorage, Services.StarterGui, Services.StarterPack,
    Services.ServerStorage, Services.ServerScriptService, Services.ReplicatedFirst, Services.Lighting, Services.SoundService,
    Services.HttpService, Services.Chat, Services.CoreGui
}

local function buildTree()
    clearChildren(TreeScroll)
    for _,root in ipairs(ROOTS) do makeTreeRow(root,0).Parent=TreeScroll end
    TreeScroll.CanvasSize=UDim2.new(0,0,0,TreeLayout.AbsoluteContentSize.Y+16)
end

-- ===== Busca =====
local ResultsDrop=Instance.new("Frame"); ResultsDrop.BackgroundColor3=Theme.panel2; ResultsDrop.Visible=false; ResultsDrop.Size=UDim2.new(0,280,0,180); ResultsDrop.Position=UDim2.new(0,260,0,40); ResultsDrop.Parent=Main
Instance.new("UICorner",ResultsDrop).CornerRadius=UDim.new(0,8); Instance.new("UIStroke",ResultsDrop).Color=Theme.stroke
local ResultsScroll=Instance.new("ScrollingFrame"); ResultsScroll.BackgroundTransparency=1; ResultsScroll.Size=UDim2.new(1,-8,1,-8); ResultsScroll.Position=UDim2.new(0,4,0,4); ResultsScroll.CanvasSize=UDim2.new(0,0,0,0); ResultsScroll.ScrollBarThickness=6; ResultsScroll.Parent=ResultsDrop
local ResultsLayout=Instance.new("UIListLayout",ResultsScroll); ResultsLayout.Padding=UDim.new(0,4)

local function addResultItem(inst)
    local Btn=Instance.new("TextButton"); Btn.BackgroundColor3=Theme.bg; Btn.Size=UDim2.new(1,0,0,28); Btn.TextXAlignment=Enum.TextXAlignment.Left; Btn.Font=Enum.Font.Gotham; Btn.TextSize=13; Btn.TextColor3=Theme.text
    Btn.Text=inst.Name.."  ["..inst.ClassName.."]"; Instance.new("UICorner",Btn).CornerRadius=UDim.new(0,6); Instance.new("UIStroke",Btn).Color=Theme.stroke; Btn.Parent=ResultsScroll
    Btn.MouseButton1Click:Connect(function()
        Selected=inst; buildPropertyPanel(inst, ToggleEditBtn.Text:find("LIGADA")~=nil); setStatus("Selecionado: "..getFullPath(inst)); ResultsDrop.Visible=false
        if SelectionBox then SelectionBox:Destroy() end
        if inst:IsA("BasePart") then SelectionBox=Instance.new("SelectionBox"); SelectionBox.LineThickness=0.03; SelectionBox.SurfaceTransparency=1; SelectionBox.Color3=Theme.accent; SelectionBox.Adornee=inst; SelectionBox.Parent=inst end
    end)
end

local function runSearch(q)
    clearChildren(ResultsScroll)
    if not q or q=="" then ResultsDrop.Visible=false; return end
    q=q:lower()
    local matches={}
    local function scan(root)
        for _,d in ipairs(root:GetDescendants()) do
            local ok1,cn=pcall(function() return d.ClassName end); local ok2,nm=pcall(function() return d.Name end)
            if ok1 and ok2 and (nm:lower():find(q,1,true) or cn:lower():find(q,1,true)) then table.insert(matches,d); if #matches>=200 then return end end
        end
    end
    for _,root in ipairs(ROOTS) do pcall(scan,root); if #matches>=200 then break end end
    for _,inst in ipairs(matches) do addResultItem(inst) end
    ResultsDrop.Visible=#matches>0; ResultsScroll.CanvasSize=UDim2.new(0,0,0,ResultsLayout.AbsoluteContentSize.Y+8)
end

SearchBox:GetPropertyChangedSignal("Text"):Connect(function() runSearch(SearchBox.Text) end)

-- ===== Top buttons =====
RefreshBtn.MouseButton1Click:Connect(function() buildTree(); setStatus("Arvore atualizada") end)
CopyPathBtn.MouseButton1Click:Connect(function()
    if not Selected then setStatus("Nada selecionado"); return end
    local path=getFullPath(Selected)
    if safeSetClipboard(path) then setStatus("Caminho copiado") else setStatus("Clipboard indisponivel. Path: "..path) end
end)
ToggleEditBtn.MouseButton1Click:Connect(function()
    local enable=ToggleEditBtn.Text:find("DESLIGADA")~=nil
    if enable then ToggleEditBtn.Text="Edicao: LIGADA"; ToggleEditBtn.TextColor3=Theme.ok; if Selected then buildPropertyPanel(Selected,true) end; setStatus("Edicao habilitada")
    else ToggleEditBtn.Text="Edicao: DESLIGADA"; ToggleEditBtn.TextColor3=Theme.warn; if Selected then buildPropertyPanel(Selected,false) end; setStatus("Edicao desabilitada") end
end)

-- ===== Arraste e Splitter =====
do
    local dragging=false; local dragStart; local startPos; local UIS=Services.UserInputService
    TopBar.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=true; dragStart=input.Position; startPos=Main.Position
            input.Changed:Connect(function() if input.UserInputState==Enum.UserInputState.End then dragging=false end end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        local move = input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch
        if dragging and move then
            local delta=input.Position-dragStart
            local x=startPos.X.Offset+delta.X; local y=startPos.Y.Offset+delta.Y
            local vp=workspace.CurrentCamera.ViewportSize; local w=Main.AbsoluteSize.X; local h=Main.AbsoluteSize.Y
            x=math.clamp(x,-w+40,vp.X-40); y=math.clamp(y,0,vp.Y-40)
            Main.Position=UDim2.fromOffset(x,y)
        end
    end)
end

do
    local resizing=false; local dragStart; local startX; local UIS=Services.UserInputService
    Splitter.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 then
            resizing=true; dragStart=input.Position; startX=LeftPane.Size.X.Offset
            input.Changed:Connect(function() if input.UserInputState==Enum.UserInputState.End then resizing=false end end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if resizing and input.UserInputType==Enum.UserInputType.MouseMovement then
            local delta=input.Position-dragStart; local w=math.clamp(startX+delta.X,240,600)
            LeftPane.Size=UDim2.new(0,w,1,0); Splitter.Position=UDim2.new(0,w,0,0); RightPane.Position=UDim2.new(0,w+4,0,0); RightPane.Size=UDim2.new(1,-(w+4),1,0)
        end
    end)
end

-- ===== Responsivo p/ Emulador + Minimizar + Compacto =====
local cam = workspace.CurrentCamera or workspace:WaitForChild("CurrentCamera")
local scaler = Instance.new("UIScale"); scaler.Parent=Main
local lastSize = Vector2.new(980,560)
local function fitWindow()
    local vp = cam and cam.ViewportSize or Vector2.new(1280,720)
    local pad=16; local base=Vector2.new(980,560)
    local scale = math.min((vp.X-pad*2)/base.X, (vp.Y-pad*2)/base.Y)
    scale = math.clamp(scale, 0.55, 1)
    scaler.Scale = scale
    local w = math.floor(base.X*scale); local h=math.floor(base.Y*scale)
    Main.Size=UDim2.fromOffset(w,h); Main.Position=UDim2.fromOffset((vp.X-w)/2,(vp.Y-h)/2)
    lastSize=Vector2.new(w,h)
end
fitWindow()
cam:GetPropertyChangedSignal("ViewportSize"):Connect(fitWindow)

local MinBtn=Instance.new("TextButton"); MinBtn.Name="MinBtn"; MinBtn.Parent=TopBar; MinBtn.Size=UDim2.new(0,28,0,28)
MinBtn.Position=UDim2.new(1,-36,0,8); MinBtn.AnchorPoint=Vector2.new(1,0); MinBtn.BackgroundColor3=Theme.bg; MinBtn.Text="_"
MinBtn.Font=Enum.Font.GothamSemibold; MinBtn.TextSize=16; MinBtn.TextColor3=Theme.text; Instance.new("UICorner",MinBtn).CornerRadius=UDim.new(0,8); Instance.new("UIStroke",MinBtn).Color=Theme.stroke
local minimized=false
MinBtn.MouseButton1Click:Connect(function()
    minimized=not minimized
    Body.Visible=not minimized; Splitter.Visible=not minimized
    if minimized then Main.Size=UDim2.fromOffset(lastSize.X,44) else fitWindow() end
end)

local CompactBtn=Instance.new("TextButton"); CompactBtn.Name="CompactBtn"; CompactBtn.Parent=TopBar; CompactBtn.Size=UDim2.new(0,96,0,28)
CompactBtn.Position=UDim2.new(1,-170,0,8); CompactBtn.AnchorPoint=Vector2.new(1,0); CompactBtn.BackgroundColor3=Theme.bg; CompactBtn.Text="Compacto: Off"
CompactBtn.Font=Enum.Font.GothamSemibold; CompactBtn.TextSize=14; CompactBtn.TextColor3=Theme.text; Instance.new("UICorner",CompactBtn).CornerRadius=UDim.new(0,8); Instance.new("UIStroke",CompactBtn).Color=Theme.stroke
local compact=false; local defaultLeft=360
CompactBtn.MouseButton1Click:Connect(function()
    compact=not compact; CompactBtn.Text=compact and "Compacto: On" or "Compacto: Off"
    if compact then LeftPane.Size=UDim2.new(1,0,1,0); RightPane.Visible=false; Splitter.Visible=false else LeftPane.Size=UDim2.new(0,defaultLeft,1,0); RightPane.Visible=true; Splitter.Visible=true end
    fitWindow()
end)

-- ===== Hotkey de visibilidade =====
local visible=true
Services.UserInputService.InputBegan:Connect(function(input,gp)
    if gp then return end
    if input.KeyCode==Enum.KeyCode.RightControl then visible=not visible; ScreenGui.Enabled=visible end
end)

-- ===== Inicializa =====
buildTree(); setStatus("Pronto")
task.defer(function() local ok=pcall(function() buildPropertyPanel(Services.Workspace,false) end); if ok then setStatus("Selecionado: Workspace") end end)
