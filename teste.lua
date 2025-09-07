-- Mayunie DEX Explorer - V2 (Centered + AutoHeight Tree + Responsive Topbar)
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

-- Helpers
local function typeofRbx(v) local ok,t=pcall(function()return typeof(v)end); if ok then return t end; local mt=getmetatable(v); return mt and mt.__type or type(v) end
local function safeSetClipboard(text) local ok=pcall(function() setclipboard(text) end); return ok end
local function getFullPath(inst)
    if not inst or not inst:IsDescendantOf(game) then return "?" end
    local seg,cur={},inst
    while cur and cur~=game do table.insert(seg,1,("%s[%s]"):format(cur.Name,cur.ClassName)); cur=cur.Parent end
    return "game."..table.concat(seg,".")
end

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
        local enumType=tostring(targetValue.EnumType)
        local fam=Enum[enumType:match("Enum%.(.+)$") or ""]
        if fam then for _,it in ipairs(fam:GetEnumItems()) do if it.Name:lower()==txt:lower() then return it end end end
    end
end

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

-- Tema
local Theme = {
    bg=Color3.fromRGB(18,18,22), panel=Color3.fromRGB(26,26,32), panel2=Color3.fromRGB(32,32,40),
    stroke=Color3.fromRGB(64,64,80), text=Color3.fromRGB(235,235,245), subtext=Color3.fromRGB(190,190,205),
    accent=Color3.fromRGB(95,135,255), ok=Color3.fromRGB(80,190,120), warn=Color3.fromRGB(255,170,60)
}

-- GUI base
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name="MayunieDexExplorer"; ScreenGui.IgnoreGuiInset=true; ScreenGui.ResetOnSpawn=false
pcall(protect_gui, ScreenGui); ScreenGui.Parent = GUI_PARENT

local Main = Instance.new("Frame")
Main.Name="Main"; Main.Size=UDim2.fromOffset(980,560)
Main.AnchorPoint=Vector2.new(0.5,0.5); Main.Position=UDim2.fromScale(0.5,0.5)
Main.BackgroundColor3=Theme.panel; Main.Parent=ScreenGui
Instance.new("UICorner",Main).CornerRadius=UDim.new(0,14); local stroke=Instance.new("UIStroke",Main); stroke.Color=Theme.stroke; stroke.Thickness=1

local TopBar = Instance.new("Frame"); TopBar.Name="TopBar"; TopBar.BackgroundColor3=Theme.panel2; TopBar.Size=UDim2.new(1,0,0,44); TopBar.Parent=Main
Instance.new("UICorner",TopBar).CornerRadius=UDim.new(0,14)

local Title = Instance.new("TextLabel")
Title.BackgroundTransparency=1; Title.Font=Enum.Font.GothamSemibold; Title.TextSize=16; Title.TextColor3=Theme.text
Title.TextXAlignment=Enum.TextXAlignment.Left; Title.Text="Mayunie DEX Explorer"
Title.Size=UDim2.new(0,200,1,0); Title.Position=UDim2.new(0,16,0,0); Title.Parent=TopBar

local TopRight = Instance.new("Frame")
TopRight.BackgroundTransparency=1
TopRight.Size = UDim2.new(1,-232,1,0)   -- espaço restante ao lado do título
TopRight.Position = UDim2.new(0,228,0,0)
TopRight.Parent = TopBar

local H = Instance.new("UIListLayout", TopRight)
H.FillDirection = Enum.FillDirection.Horizontal
H.HorizontalAlignment = Enum.HorizontalAlignment.Right
H.VerticalAlignment = Enum.VerticalAlignment.Center
H.Padding = UDim.new(0,6)

local SearchBox = Instance.new("TextBox")
SearchBox.Size=UDim2.new(0,220,0,28); SearchBox.BackgroundColor3=Theme.bg; SearchBox.TextColor3=Theme.text
SearchBox.PlaceholderColor3=Theme.subtext; SearchBox.PlaceholderText="Buscar por Nome ou ClassName"
SearchBox.Font=Enum.Font.Gotham; SearchBox.TextSize=14; SearchBox.ClearTextOnFocus=false
Instance.new("UICorner",SearchBox).CornerRadius=UDim.new(0,8); Instance.new("UIStroke",SearchBox).Color=Theme.stroke
SearchBox.Parent = TopRight

local MoreBtn = Instance.new("TextButton")
MoreBtn.Size = UDim2.new(0,36,0,28); MoreBtn.BackgroundColor3=Theme.bg; MoreBtn.Text="⋮"; MoreBtn.Font=Enum.Font.GothamBold
MoreBtn.TextColor3=Theme.text; MoreBtn.TextSize=18
Instance.new("UICorner",MoreBtn).CornerRadius=UDim.new(0,8); Instance.new("UIStroke",MoreBtn).Color=Theme.stroke
MoreBtn.Parent = TopRight

local Body = Instance.new("Frame"); Body.Name="Body"; Body.BackgroundTransparency=1; Body.Position=UDim2.new(0,0,0,44); Body.Size=UDim2.new(1,0,1,-44); Body.Parent=Main
local LeftPane = Instance.new("Frame"); LeftPane.BackgroundColor3=Theme.panel; LeftPane.Size=UDim2.new(0,360,1,0); LeftPane.Name="LeftPane"; LeftPane.Parent=Body; Instance.new("UIStroke",LeftPane).Color=Theme.stroke
local Splitter = Instance.new("Frame"); Splitter.BackgroundColor3=Theme.stroke; Splitter.Size=UDim2.new(0,4,1,0); Splitter.Position=UDim2.new(0,360,0,0); Splitter.Name="Splitter"; Splitter.Parent=Body
local RightPane = Instance.new("Frame"); RightPane.BackgroundColor3=Theme.panel; RightPane.Position=UDim2.new(0,364,0,0); RightPane.Size=UDim2.new(1,-364,1,0); RightPane.Name="RightPane"; RightPane.Parent=Body; Instance.new("UIStroke",RightPane).Color=Theme.stroke

local TreeScroll = Instance.new("ScrollingFrame"); TreeScroll.BackgroundTransparency=1; TreeScroll.BorderSizePixel=0
TreeScroll.CanvasSize=UDim2.new(0,0,0,0); TreeScroll.ScrollingDirection=Enum.ScrollingDirection.Y; TreeScroll.ScrollBarThickness=6; TreeScroll.Size=UDim2.new(1,0,1,0); TreeScroll.Parent=LeftPane
local TreeLayout = Instance.new("UIListLayout"); TreeLayout.Padding=UDim.new(0,2); TreeLayout.SortOrder=Enum.SortOrder.LayoutOrder; TreeLayout.Parent=TreeScroll
TreeLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    TreeScroll.CanvasSize = UDim2.new(0, 0, 0, TreeLayout.AbsoluteContentSize.Y + 16)
end)

local PropHeader = Instance.new("TextLabel"); PropHeader.BackgroundTransparency=1; PropHeader.Font=Enum.Font.GothamSemibold; PropHeader.TextSize=16; PropHeader.TextColor3=Theme.text
PropHeader.TextXAlignment=Enum.TextXAlignment.Left; PropHeader.Text="Propriedades"; PropHeader.Size=UDim2.new(1,-16,0,28); PropHeader.Position=UDim2.new(0,12,0,8); PropHeader.Parent=RightPane

local PropScroll = Instance.new("ScrollingFrame"); PropScroll.BackgroundTransparency=1; PropScroll.BorderSizePixel=0
PropScroll.CanvasSize=UDim2.new(0,0,0,0); PropScroll.ScrollingDirection=Enum.ScrollingDirection.Y; PropScroll.ScrollBarThickness=6; PropScroll.Size=UDim2.new(1,-24,1,-48); PropScroll.Position=UDim2.new(0,12,0,40); PropScroll.Parent=RightPane
local PropLayout = Instance.new("UIListLayout"); PropLayout.Padding=UDim.new(0,4); PropLayout.SortOrder=Enum.SortOrder.LayoutOrder; PropLayout.Parent=PropScroll
PropLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    PropScroll.CanvasSize = UDim2.new(0,0,0,PropLayout.AbsoluteContentSize.Y + 16)
end)

local StatusLabel = Instance.new("TextLabel"); StatusLabel.BackgroundTransparency=1; StatusLabel.Font=Enum.Font.Gotham; StatusLabel.TextSize=13; StatusLabel.TextColor3=Theme.subtext
StatusLabel.TextXAlignment=Enum.TextXAlignment.Left; StatusLabel.Text=""; StatusLabel.Size=UDim2.new(1,-16,0,24); StatusLabel.Position=UDim2.new(0,12,1,-28); StatusLabel.Parent=RightPane
local function setStatus(t) StatusLabel.Text=t or "" end
local function clearChildren(gui) for _,c in ipairs(gui:GetChildren()) do if not c:IsA("UIListLayout") then c:Destroy() end end end

-- Property panel
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
end

-- Tree com altura automática
local Selected, SelectionBox

local function makeTreeRow(inst, depth)
    -- Linha raiz com altura automática
    local Row=Instance.new("Frame")
    Row.BackgroundColor3=Theme.bg
    Row.AutomaticSize = Enum.AutomaticSize.Y
    Row.Size=UDim2.new(1,-8,0,0)
    Row.LayoutOrder=depth
    Instance.new("UICorner",Row).CornerRadius=UDim.new(0,6)
    Instance.new("UIStroke",Row).Color=Theme.stroke

    -- Layout vertical para Header + Children
    local V = Instance.new("UIListLayout", Row)
    V.FillDirection = Enum.FillDirection.Vertical
    V.Padding = UDim.new(0,2)

    -- Header fixo 26px
    local Header = Instance.new("Frame")
    Header.BackgroundTransparency = 1
    Header.Size = UDim2.new(1,0,0,26)
    Header.Parent = Row

    local Toggle=Instance.new("TextButton"); Toggle.BackgroundTransparency=1; Toggle.Text="▶"; Toggle.Font=Enum.Font.GothamSemibold; Toggle.TextSize=12; Toggle.TextColor3=Theme.subtext
    Toggle.Size=UDim2.new(0,24,1,0); Toggle.Position=UDim2.new(0,6+depth*12,0,0); Toggle.Parent=Header

    local NameBtn=Instance.new("TextButton"); NameBtn.BackgroundTransparency=1; NameBtn.TextXAlignment=Enum.TextXAlignment.Left; NameBtn.Font=Enum.Font.Gotham; NameBtn.TextSize=13; NameBtn.TextColor3=Theme.text
    NameBtn.Text=("%s  [%s]"):format(inst.Name,inst.ClassName); NameBtn.Size=UDim2.new(1,-60-depth*12,1,0); NameBtn.Position=UDim2.new(0,30+depth*12,0,0); NameBtn.Parent=Header

    -- Container dos filhos, auto height
    local ChildrenContainer=Instance.new("Frame"); ChildrenContainer.BackgroundTransparency=1
    ChildrenContainer.AutomaticSize = Enum.AutomaticSize.Y
    ChildrenContainer.Size=UDim2.new(1,0,0,0)
    ChildrenContainer.Parent=Row

    local ChildLayout=Instance.new("UIListLayout", ChildrenContainer)
    ChildLayout.SortOrder=Enum.SortOrder.LayoutOrder
    ChildLayout.Padding=UDim.new(0,2)

    local expanded=false
    local function refreshChildren()
        clearChildren(ChildrenContainer)
        local kids={} pcall(function() kids=inst:GetChildren() end)
        table.sort(kids,function(a,b) return a.Name:lower()<b.Name:lower() end)
        for _,child in ipairs(kids) do makeTreeRow(child, depth+1).Parent=ChildrenContainer end
    end

    Toggle.MouseButton1Click:Connect(function()
        expanded=not expanded; Toggle.Text=expanded and "▼" or "▶"
        if expanded then refreshChildren() else clearChildren(ChildrenContainer) end
    end)

    NameBtn.MouseButton1Click:Connect(function()
        Selected=inst; buildPropertyPanel(inst, false); setStatus("Selecionado: "..getFullPath(inst))
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
end

-- Busca
local ResultsDrop=Instance.new("Frame"); ResultsDrop.BackgroundColor3=Theme.panel2; ResultsDrop.Visible=false; ResultsDrop.Size=UDim2.new(0,240,0,180); ResultsDrop.Parent=Main
Instance.new("UICorner",ResultsDrop).CornerRadius=UDim.new(0,8); Instance.new("UIStroke",ResultsDrop).Color=Theme.stroke
local ResultsScroll=Instance.new("ScrollingFrame"); ResultsScroll.BackgroundTransparency=1; ResultsScroll.Size=UDim2.new(1,-8,1,-8); ResultsScroll.Position=UDim2.new(0,4,0,4); ResultsScroll.CanvasSize=UDim2.new(0,0,0,0); ResultsScroll.ScrollBarThickness=6; ResultsScroll.Parent=ResultsDrop
local ResultsLayout=Instance.new("UIListLayout",ResultsScroll); ResultsLayout.Padding=UDim.new(0,4)
ResultsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ResultsScroll.CanvasSize = UDim2.new(0,0,0,ResultsLayout.AbsoluteContentSize.Y + 8)
end)

local function addResultItem(inst)
    local Btn=Instance.new("TextButton"); Btn.BackgroundColor3=Theme.bg; Btn.Size=UDim2.new(1,0,0,28); Btn.TextXAlignment=Enum.TextXAlignment.Left; Btn.Font=Enum.Font.Gotham; Btn.TextSize=13; Btn.TextColor3=Theme.text
    Btn.Text=inst.Name.."  ["..inst.ClassName.."]"; Instance.new("UICorner",Btn).CornerRadius=UDim.new(0,6); Instance.new("UIStroke",Btn).Color=Theme.stroke; Btn.Parent=ResultsScroll
    Btn.MouseButton1Click:Connect(function()
        Selected=inst; buildPropertyPanel(inst, false); setStatus("Selecionado: "..getFullPath(inst)); ResultsDrop.Visible=false
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
    -- Posiciona o dropdown abaixo da busca
    local abs = SearchBox.AbsolutePosition
    local size = SearchBox.AbsoluteSize
    ResultsDrop.Position = UDim2.fromOffset(abs.X, abs.Y + size.Y + 4)
    ResultsDrop.Size = UDim2.fromOffset(size.X, 180)
    ResultsDrop.Visible = #matches>0
end

SearchBox:GetPropertyChangedSignal("Text"):Connect(function() runSearch(SearchBox.Text) end)

-- Menu ⋮
local Menu = Instance.new("Frame")
Menu.Visible = false
Menu.Size = UDim2.fromOffset(180, 6)  -- altura ajusta depois
Menu.BackgroundColor3 = Theme.panel2
Menu.Parent = Main
Instance.new("UICorner", Menu).CornerRadius = UDim.new(0,8)
Instance.new("UIStroke", Menu).Color = Theme.stroke

local MenuList = Instance.new("UIListLayout", Menu)
MenuList.Padding = UDim.new(0,6)
MenuList.FillDirection = Enum.FillDirection.Vertical
MenuList.HorizontalAlignment = Enum.HorizontalAlignment.Stretch
MenuList.VerticalAlignment = Enum.VerticalAlignment.Top

local function menuButton(txt)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,-12,0,28)
    b.Position = UDim2.new(0,6,0,0)
    b.BackgroundColor3 = Theme.bg
    b.Text = txt
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 14
    b.TextColor3 = Theme.text
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
    Instance.new("UIStroke", b).Color = Theme.stroke
    b.Parent = Menu
    return b
end

local BtnRefresh = menuButton("Atualizar árvore")
local BtnCopyPath = menuButton("Copiar Path")
local BtnToggleEdit = menuButton("Edição: OFF")
local BtnCompact = menuButton("Compacto: OFF")
local BtnMin = menuButton("Minimizar")

local function updateMenuHeight()
    Menu.Size = UDim2.fromOffset(180, MenuList.AbsoluteContentSize.Y + 12)
end
MenuList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateMenuHeight)
updateMenuHeight()

MoreBtn.MouseButton1Click:Connect(function()
    Menu.Visible = not Menu.Visible
    -- posiciona no canto direito da TopBar
    local abs = MoreBtn.AbsolutePosition
    Menu.Position = UDim2.fromOffset(abs.X - 180 + MoreBtn.AbsoluteSize.X, abs.Y + MoreBtn.AbsoluteSize.Y + 6)
end)

BtnRefresh.MouseButton1Click:Connect(function() buildTree(); setStatus("Árvore atualizada"); Menu.Visible=false end)
BtnCopyPath.MouseButton1Click:Connect(function()
    if not Selected then setStatus("Nada selecionado"); Menu.Visible=false; return end
    local path = getFullPath(Selected)
    if safeSetClipboard(path) then setStatus("Caminho copiado") else setStatus("Clipboard indisponível. Path: "..path) end
    Menu.Visible=false
end)

local editEnabled = false
BtnToggleEdit.MouseButton1Click:Connect(function()
    editEnabled = not editEnabled
    BtnToggleEdit.Text = editEnabled and "Edição: ON" or "Edição: OFF"
    if Selected then buildPropertyPanel(Selected, editEnabled) end
    setStatus(editEnabled and "Edição habilitada" or "Edição desabilitada")
    Menu.Visible=false
end)

local compact = false
BtnCompact.MouseButton1Click:Connect(function()
    compact = not compact
    BtnCompact.Text = compact and "Compacto: ON" or "Compacto: OFF"
    if compact then
        LeftPane.Size=UDim2.new(1,0,1,0); RightPane.Visible=false; Splitter.Visible=false
    else
        LeftPane.Size=UDim2.new(0,360,1,0); RightPane.Visible=true; Splitter.Visible=true
    end
    Menu.Visible=false
end)

local minimized=false
BtnMin.MouseButton1Click:Connect(function()
    minimized=not minimized
    Body.Visible=not minimized; Splitter.Visible=not minimized
    if minimized then Main.Size=UDim2.fromOffset(Main.AbsoluteSize.X,44) else Main.Size=UDim2.fromOffset(Main.AbsoluteSize.X,560) end
    Menu.Visible=false
end)

-- Arraste, Splitter e Responsivo
do
    local UIS=Services.UserInputService
    local dragging=false; local dragStart; local startPos
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
    local UIS=Services.UserInputService
    local resizing=false; local dragStart; local startX
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

local cam = workspace.CurrentCamera or workspace:WaitForChild("CurrentCamera")
local scaler = Instance.new("UIScale", Main)
local lastScale = 1
local function fitWindow()
    local vp = cam and cam.ViewportSize or Vector2.new(1280,720)
    local pad=16; local base=Vector2.new(980,560)
    local scale = math.min((vp.X-pad*2)/base.X, (vp.Y-pad*2)/base.Y)
    scale = math.clamp(scale, 0.55, 1)
    scaler.Scale = scale; lastScale = scale
    Main.Size=UDim2.fromOffset(math.floor(base.X*scale), math.floor(base.Y*scale))
    Main.AnchorPoint=Vector2.new(0.5,0.5)
    Main.Position=UDim2.fromOffset(math.floor(vp.X/2), math.floor(vp.Y/2))
end
fitWindow()
cam:GetPropertyChangedSignal("ViewportSize"):Connect(fitWindow)

-- Hotkey de visibilidade
local visible=true
Services.UserInputService.InputBegan:Connect(function(input,gp)
    if gp then return end
    if input.KeyCode==Enum.KeyCode.RightControl then visible=not visible; ScreenGui.Enabled=visible end
end)

-- Inicializa
local function buildPropertyPanelSafe(edit) if Selected then buildPropertyPanel(Selected, edit) end end
buildTree(); setStatus("Pronto")
task.defer(function() local ok=pcall(function() Selected=Services.Workspace; buildPropertyPanel(Selected,false) end); if ok then setStatus("Selecionado: Workspace") end end)
