local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LP = Players.LocalPlayer

local Config = {
    AimbotEnabled = false,
    AimSmoothness = 0.25,
    AimSpeed = 1,
    AimPart = "Head",
    AimDistance = 500,
    TeamCheck = true,
    WallCheck = true,
    FOVRadius = 120,
    FOVColor = Color3.fromRGB(255, 255, 255),
    FOVThickness = 2,
    FOVTransparency = 0.9,
    ESPEnabled = false,
    ESPTeamCheck = true,
    ActionSpeed = false,
    EatMultiply = false,
    EatMultiplier = 2,
    WalkSpeed = 16,
    SmoothFollow = false,
    LockView = false,
    Crosshair = false,
    CrosshairSpin = false,
}
local FOVCircle = Drawing.new("Circle")
FOVCircle.NumSides = 100
FOVCircle.Filled = false
FOVCircle.Thickness = 2
FOVCircle.Color = Color3.fromRGB(255, 255, 255)
FOVCircle.Radius = 120
FOVCircle.Transparency = 0.9
FOVCircle.Visible = false

RunService.RenderStepped:Connect(function()
    FOVCircle.Position = Camera.ViewportSize / 2
    FOVCircle.Radius = Config.FOVRadius
    FOVCircle.Thickness = Config.FOVThickness
    FOVCircle.Color = Config.FOVColor
    FOVCircle.Transparency = Config.FOVTransparency
    FOVCircle.Visible = Config.AimbotEnabled
end)
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function isSameTeam(plr)
    if not Config.TeamCheck then return false end
    if not plr.Team or not LP.Team then return false end
    return plr.Team == LP.Team
end

local function hasLineOfSight(plr, partName)
    if not Config.WallCheck then return true end
    if not LP.Character then return false end
    local tPart = plr.Character and plr.Character:FindFirstChild(partName)
    if not tPart then return false end
    local filter = {LP.Character, plr.Character}
    local ti = workspace:FindFirstChild("TeamIndicators")
    if ti then table.insert(filter, ti) end
    rayParams.FilterDescendantsInstances = filter
    local origin = Camera.CFrame.Position
    local result = workspace:Raycast(origin, tPart.Position - origin, rayParams)
    return result == nil
end
local function findTarget()
    local closest, shortest = nil, Config.FOVRadius
    local center = Camera.ViewportSize / 2
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end
        if isSameTeam(plr) then continue end
        if not plr.Character then continue end
        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local part = plr.Character:FindFirstChild(Config.AimPart)
            or plr.Character:FindFirstChild("HumanoidRootPart")
        if not part then continue end
        local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end
        local d = (Vector2.new(pos.X, pos.Y) - center).Magnitude
        if d > Config.FOVRadius then continue end
        local myHrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        local tHrp = plr.Character:FindFirstChild("HumanoidRootPart")
        if myHrp and tHrp then
            if (myHrp.Position - tHrp.Position).Magnitude > Config.AimDistance then
                continue
            end
        end
        if not hasLineOfSight(plr, Config.AimPart) then continue end
        if d < shortest then shortest = d; closest = part end
    end
    return closest
end

RunService.RenderStepped:Connect(function()
    if not Config.AimbotEnabled then return end
    local target = findTarget()
    if not target then return end
    local camPos = Camera.CFrame.Position
    local desired = CFrame.new(camPos, target.Position)
    local alpha = math.clamp(Config.AimSmoothness * Config.AimSpeed, 0.01, 1)
    Camera.CFrame = Camera.CFrame:Lerp(desired, alpha)
end)
local espCache = {}

local function ensureESP(plr)
    if plr == LP or not plr.Character then return end
    local data = espCache[plr]

    if not data then
        local hl = Instance.new("Highlight")
        hl.FillTransparency = 0.5
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = game:GetService("CoreGui")

        local bb = Instance.new("BillboardGui")
        bb.Size = UDim2.new(0, 200, 0, 50)
        bb.StudsOffset = Vector3.new(0, 3, 0)
        bb.AlwaysOnTop = true
        bb.Parent = game:GetService("CoreGui")

        local n = Instance.new("TextLabel", bb)
        n.Size = UDim2.new(1, 0, 0.5, 0)
        n.BackgroundTransparency = 1
        n.TextStrokeTransparency = 0.5
        n.TextScaled = true
        n.Font = Enum.Font.GothamBold

        local h = Instance.new("TextLabel", bb)
        h.Position = UDim2.new(0, 0, 0.5, 0)
        h.Size = UDim2.new(1, 0, 0.5, 0)
        h.BackgroundTransparency = 1
        h.TextStrokeTransparency = 0.5
        h.TextScaled = true
        h.Font = Enum.Font.GothamBold

        data = {HL = hl, BB = bb, N = n, H = h}
        espCache[plr] = data
    end
        if not Config.ESPEnabled then
        data.HL.Enabled = false
        data.BB.Enabled = false
        return
    end

    local isMate = Config.ESPTeamCheck and plr.Team and plr.Team == LP.Team
    local color = isMate and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0)

    data.HL.Adornee = plr.Character
    data.HL.FillColor = color
    data.HL.OutlineColor = color
    data.HL.Enabled = true

    local head = plr.Character:FindFirstChild("Head")
    if head then
        data.BB.Adornee = head
        data.BB.Enabled = true
    else
        data.BB.Enabled = false
    end
    data.N.Text = plr.Name .. (isMate and " [队友]" or " [敌人]")
    data.N.TextColor3 = color

    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        data.H.Text = math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth)
    end
end

RunService.Heartbeat:Connect(function()
    for _, plr in ipairs(Players:GetPlayers()) do
        ensureESP(plr)
    end
end)

Players.PlayerRemoving:Connect(function(plr)
    if espCache[plr] then
        espCache[plr].HL:Destroy()
        espCache[plr].BB:Destroy()
        espCache[plr] = nil
    end
end)
local CrosshairGui = Instance.new("ScreenGui")
CrosshairGui.Parent = LP:WaitForChild("PlayerGui")
CrosshairGui.ResetOnSpawn = false
CrosshairGui.IgnoreGuiInset = true

local CrosshairFrame = Instance.new("Frame")
CrosshairFrame.Size = UDim2.new(0, 30, 0, 30)
CrosshairFrame.Position = UDim2.new(0.5, -15, 0.5, -15)
CrosshairFrame.BackgroundTransparency = 1
CrosshairFrame.Visible = false
CrosshairFrame.Parent = CrosshairGui

local hLine = Instance.new("Frame", CrosshairFrame)
hLine.Size = UDim2.new(1, 0, 0, 2)
hLine.Position = UDim2.new(0, 0, 0.5, -1)
hLine.BackgroundColor3 = Color3.new(1,1,1)
hLine.BorderSizePixel = 0

local vLine = Instance.new("Frame", CrosshairFrame)
vLine.Size = UDim2.new(0, 2, 1, 0)
vLine.Position = UDim2.new(0.5, -1, 0, 0)
vLine.BackgroundColor3 = Color3.new(1,1,1)
vLine.BorderSizePixel = 0

local dot = Instance.new("Frame", CrosshairFrame)
dot.Size = UDim2.new(0, 6, 0, 6)
dot.Position = UDim2.new(0.5, -3, 0.5, -3)
dot.BackgroundColor3 = Color3.new(1,1,1)
dot.BorderSizePixel = 0
local dotCorner = Instance.new("UICorner", dot)
dotCorner.CornerRadius = UDim.new(1, 0)

RunService.Heartbeat:Connect(function()
    if Config.Crosshair and Config.CrosshairSpin then
        CrosshairFrame.Rotation = (CrosshairFrame.Rotation + 1) % 360
    elseif Config.Crosshair then
        CrosshairFrame.Rotation = 0
    end
    CrosshairFrame.Visible = Config.Crosshair
end)
task.spawn(function()
    while true do
        if Config.ActionSpeed and LP.Character then
            local humanoid = LP.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                for _, track in pairs(humanoid:GetPlayingAnimationTracks()) do
                    track:AdjustSpeed(3.0)
                end
            end
        end
        task.wait(0.3)
    end
end)

task.spawn(function()
    while true do
        task.wait(0.1)
        local char = LP.Character
        if char then
            local humanoid = char:FindFirstChild("Humanoid")
            if humanoid and humanoid.WalkSpeed ~= Config.WalkSpeed then
                humanoid.WalkSpeed = Config.WalkSpeed
            end
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if not Config.SmoothFollow then return end
    local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    local nearest, minDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local r = p.Character:FindFirstChild("HumanoidRootPart")
            if r then
                local d = (r.Position - myRoot.Position).Magnitude
                if d < minDist then minDist = d; nearest = p end
            end
        end
    end
    if nearest then
        local tRoot = nearest.Character.HumanoidRootPart
        local offset = tRoot.CFrame.LookVector * -2.5
        myRoot.CFrame = CFrame.new(tRoot.Position + offset, tRoot.Position)
    end
end)
local UI = Instance.new("ScreenGui")
UI.Name = "PiUI"
UI.ResetOnSpawn = false
UI.Parent = LP:WaitForChild("PlayerGui")

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 520, 0, 320)
Main.Position = UDim2.new(0.5, -260, 0.5, -160)
Main.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = UI        -- 注意：不用 Draggable 了
local corner = Instance.new("UICorner", Main)
corner.CornerRadius = UDim.new(0, 8)

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 30)
TopBar.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
TopBar.BorderSizePixel = 0
TopBar.Parent = Main
local topCorner = Instance.new("UICorner", TopBar)
topCorner.CornerRadius = UDim.new(0, 8)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -80, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "吃吃世界 · 二改版"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.Parent = TopBar
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(1, -70, 0, 0)
MinBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
MinBtn.Text = "—"
MinBtn.TextColor3 = Color3.new(1,1,1)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 16
MinBtn.BorderSizePixel = 0
MinBtn.Parent = TopBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -35, 0, 0)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.new(1,1,1)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 16
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = TopBar

CloseBtn.MouseButton1Click:Connect(function() UI:Destroy() end)

local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    Main.Size = minimized and UDim2.new(0, 520, 0, 30) or UDim2.new(0, 520, 0, 320)
end)

-- 手动拖动（替代 Draggable）
local draggingMain, dragStart, startPos = false, nil, nil
TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingMain = true
        dragStart = input.Position
        startPos = Main.Position
    end
end)
UIS.InputChanged:Connect(function(input)
    if draggingMain and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingMain = false
    end
end)
local LeftBar = Instance.new("Frame")
LeftBar.Size = UDim2.new(0, 110, 1, -40)
LeftBar.Position = UDim2.new(0, 8, 0, 36)
LeftBar.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
LeftBar.BorderSizePixel = 0
LeftBar.Parent = Main
local lbCorner = Instance.new("UICorner", LeftBar)
lbCorner.CornerRadius = UDim.new(0, 6)

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -130, 1, -40)
Content.Position = UDim2.new(0, 124, 0, 36)
Content.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
Content.BorderSizePixel = 0
Content.Parent = Main
local ctCorner = Instance.new("UICorner", Content)
ctCorner.CornerRadius = UDim.new(0, 6)

local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -10, 1, -10)
Scroll.Position = UDim2.new(0, 5, 0, 5)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 4
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.Parent = Content
local scrollLayout = Instance.new("UIListLayout", Scroll)
scrollLayout.Padding = UDim.new(0, 5)
scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
local function MakeToggle(parent, text, key, default)
    if Config[key] == nil then Config[key] = default end   -- 修复：不重置

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 32)
    btn.BackgroundColor3 = Config[key] and Color3.fromRGB(60, 180, 80)
                                       or Color3.fromRGB(60, 60, 70)
    btn.Text = text .. (Config[key] and "  ✔" or "  ✘")
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.BorderSizePixel = 0
    btn.Parent = parent
    local c = Instance.new("UICorner", btn)
    c.CornerRadius = UDim.new(0, 5)

    btn.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        btn.BackgroundColor3 = Config[key] and Color3.fromRGB(60, 180, 80)
                                           or Color3.fromRGB(60, 60, 70)
        btn.Text = text .. (Config[key] and "  ✔" or "  ✘")
    end)
    return btn
end
local function MakeSlider(parent, text, key, minV, maxV, step, default)
    if Config[key] == nil then Config[key] = default end   -- 修复：不重置

    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -10, 0, 44)
    holder.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    holder.BorderSizePixel = 0
    holder.Parent = parent
    local hc = Instance.new("UICorner", holder)
    hc.CornerRadius = UDim.new(0, 5)

    local label = Instance.new("TextLabel", holder)
    label.Size = UDim2.new(1, -10, 0, 20)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.Gotham
    label.TextSize = 12

    local bar = Instance.new("Frame", holder)
    bar.Size = UDim2.new(1, -20, 0, 8)
    bar.Position = UDim2.new(0, 10, 0, 28)
    bar.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
    bar.BorderSizePixel = 0
    local bc = Instance.new("UICorner", bar)
    bc.CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame", bar)
    fill.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
    fill.BorderSizePixel = 0
    local fc = Instance.new("UICorner", fill)
    fc.CornerRadius = UDim.new(1, 0)
    fill.Size = UDim2.new((Config[key] - minV) / (maxV - minV), 0, 1, 0)
    label.Text = text .. ": " .. tostring(Config[key])
        local dragging = false
    local function update(input)
        local relX = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local val = minV + (maxV - minV) * relX
        val = math.floor(val / step + 0.5) * step
        val = math.clamp(val, minV, maxV)
        Config[key] = val
        fill.Size = UDim2.new((val - minV) / (maxV - minV), 0, 1, 0)
        -- 修复：去掉小数尾巴
        local shown = (step < 1) and string.format("%.2f", val) or tostring(math.floor(val))
        label.Text = text .. ": " .. shown
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            update(input)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            update(input)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end   -- 结束 MakeSlider 函数
local function MakeTabButton(text, yPos)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 32)
    btn.Position = UDim2.new(0, 5, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.BorderSizePixel = 0
    btn.Parent = LeftBar
    local c = Instance.new("UICorner", btn)
    c.CornerRadius = UDim.new(0, 5)
    return btn
end

local BtnAim = MakeTabButton("自瞄", 10)
local BtnESP = MakeTabButton("透视", 50)
local BtnOther = MakeTabButton("其他", 90)

local function clearContent()
    for _, child in ipairs(Scroll:GetChildren()) do
        if not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end
end
local function showAim()
    clearContent()
    MakeToggle(Scroll, "启用自瞄", "AimbotEnabled", false)
    MakeToggle(Scroll, "队伍识别（不打队友）", "TeamCheck", true)
    MakeToggle(Scroll, "掩体识别（隔墙不打）", "WallCheck", true)
    MakeSlider(Scroll, "平滑度（越小越稳）", "AimSmoothness", 0.05, 1, 0.01, 0.25)
    MakeSlider(Scroll, "自瞄速度", "AimSpeed", 0.1, 3, 0.1, 1)
    MakeSlider(Scroll, "自瞄距离 (米)", "AimDistance", 50, 2000, 10, 500)
    MakeSlider(Scroll, "FOV 圆圈大小", "FOVRadius", 30, 500, 5, 120)
    MakeSlider(Scroll, "FOV 线条粗细", "FOVThickness", 1, 10, 0.5, 2)
    MakeSlider(Scroll, "FOV 透明度", "FOVTransparency", 0, 1, 0.05, 0.9)

    local colorFrame = Instance.new("Frame")
    colorFrame.Size = UDim2.new(1, -10, 0, 32)
    colorFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    colorFrame.BorderSizePixel = 0
    colorFrame.Parent = Scroll
    local cfc = Instance.new("UICorner", colorFrame)
    cfc.CornerRadius = UDim.new(0, 5)

    local lbl = Instance.new("TextLabel", colorFrame)
    lbl.Size = UDim2.new(0, 100, 1, 0)
    lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "FOV 颜色"
    lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local colors = {
        {Color3.fromRGB(255,255,255)}, {Color3.fromRGB(255,0,0)},
        {Color3.fromRGB(0,255,0)}, {Color3.fromRGB(0,150,255)},
        {Color3.fromRGB(255,255,0)}, {Color3.fromRGB(0,255,255)},
    }
    for i, data in ipairs(colors) do
        local cb = Instance.new("TextButton")
        cb.Size = UDim2.new(0, 24, 0, 24)
        cb.Position = UDim2.new(0, 110 + (i-1) * 30, 0, 4)
        cb.BackgroundColor3 = data[1]
        cb.Text = ""
        cb.BorderSizePixel = 1
        cb.BorderColor3 = Color3.new(0,0,0)
        cb.Parent = colorFrame
        local cbc = Instance.new("UICorner", cb)
        cbc.CornerRadius = UDim.new(1, 0)
        cb.MouseButton1Click:Connect(function()
            Config.FOVColor = data[1]
        end)
    end
end
-- ============================================================
--  透视页内容
-- ============================================================
local function showESP()
    clearContent()
    MakeToggle(Scroll, "启用透视", "ESPEnabled", false)
    MakeToggle(Scroll, "透视队伍识别（队友绿/敌人红）", "ESPTeamCheck", true)
end

-- ============================================================
--  其他页内容
-- ============================================================
local function showOther()
    clearContent()
    MakeToggle(Scroll, "动作加速", "ActionSpeed", false)
    MakeToggle(Scroll, "吃倍数", "EatMultiply", false)
    MakeSlider(Scroll, "吃倍数数值", "EatMultiplier", 1, 10, 1, 2)
    MakeSlider(Scroll, "移动速度", "WalkSpeed", 16, 200, 1, 16)
    MakeToggle(Scroll, "平滑跟随", "SmoothFollow", false)
    MakeToggle(Scroll, "锁定视角", "LockView", false)
    MakeToggle(Scroll, "准星", "Crosshair", false)
    MakeToggle(Scroll, "准星旋转", "CrosshairSpin", false)
end

-- ============================================================
--  给三个分类按钮绑定点击事件
-- ============================================================
BtnAim.MouseButton1Click:Connect(showAim)
BtnESP.MouseButton1Click:Connect(showESP)
BtnOther.MouseButton1Click:Connect(showOther)

-- 默认显示"自瞄"页
showAim()

-- 加载完成提示
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "吃吃世界 · 本地UI版",
    Text = "加载完成",
    Duration = 3,
})