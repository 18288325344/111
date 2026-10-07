-- ============================================================
-- 服务
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Camera = workspace.CurrentCamera
local LP = Players.LocalPlayer

-- 背景图 ID（填你自己的，不填也没事，只是没背景）
local BG_IMAGE_ID = "rbxassetid://0"
local BG_TRANSPARENCY = 0.4

-- ============================================================
-- 配置表
-- ============================================================
local Config = {
    AimbotEnabled = false, AimSmoothness = 0.25, AimSpeed = 1,
    AimPart = "Head", AimDistance = 500, TeamCheck = true, WallCheck = true,
    FOVRadius = 120, FOVColor = Color3.fromRGB(255, 255, 255),
    FOVThickness = 2, FOVTransparency = 0.9,
    ESPEnabled = false, ESPTeamCheck = true,
    ActionSpeed = false, EatMultiply = false, EatMultiplier = 2, WalkSpeed = 16,
    SmoothFollow = false, LockView = false, Crosshair = false, CrosshairSpin = false,
}

-- ============================================================
-- FOV 空心圆（居中、白色）
-- ============================================================
local FOVCircle = Drawing.new("Circle")
FOVCircle.NumSides = 100
FOVCircle.Filled = false
FOVCircle.Thickness = 2
FOVCircle.Color = Color3.fromRGB(255, 255, 255)
FOVCircle.Radius = 120
FOVCircle.Transparency = 0.9
FOVCircle.Visible = false

-- ============================================================
-- 射线检测参数
-- ============================================================
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

-- ============================================================
-- 队伍识别
-- ============================================================
local function isSameTeam(plr)
    if not Config.TeamCheck then return false end
    if not plr.Team or not LP.Team then return false end
    return plr.Team == LP.Team
end

-- ============================================================
-- 掩体识别
-- ============================================================
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
-- ============================================================
-- 找 FOV 内最近的敌人
-- ============================================================
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
            if (myHrp.Position - tHrp.Position).Magnitude > Config.AimDistance then continue end
        end
        if not hasLineOfSight(plr, Config.AimPart) then continue end
        if d < shortest then shortest = d; closest = part end
    end
    return closest
end

-- ============================================================
-- 自瞄循环
-- ============================================================
local aimConnection = RunService.RenderStepped:Connect(function()
    if not Config.AimbotEnabled then return end
    local target = findTarget()
    if not target then return end
    local camPos = Camera.CFrame.Position
    local desired = CFrame.new(camPos, target.Position)
    local alpha = math.clamp(Config.AimSmoothness * Config.AimSpeed, 0.01, 1)
    Camera.CFrame = Camera.CFrame:Lerp(desired, alpha)
end)

-- ============================================================
-- FOV 圆圈每帧更新
-- ============================================================
local fovConnection = RunService.RenderStepped:Connect(function()
    FOVCircle.Position = Camera.ViewportSize / 2
    FOVCircle.Radius = Config.FOVRadius
    FOVCircle.Thickness = Config.FOVThickness
    FOVCircle.Color = Config.FOVColor
    FOVCircle.Transparency = Config.FOVTransparency
    FOVCircle.Visible = Config.AimbotEnabled
end)

-- ============================================================
-- 透视 ESP
-- ============================================================
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

local espConnection = RunService.Heartbeat:Connect(function()
    for _, plr in ipairs(Players:GetPlayers()) do ensureESP(plr) end
end)

local function clearESP()
    for plr, data in pairs(espCache) do
        data.HL:Destroy()
        data.BB:Destroy()
    end
    espCache = {}
end
-- ============================================================
-- 准星 UI
-- ============================================================
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

local crossConnection = RunService.Heartbeat:Connect(function()
    if Config.Crosshair and Config.CrosshairSpin then
        CrosshairFrame.Rotation = (CrosshairFrame.Rotation + 1) % 360
    elseif Config.Crosshair then
        CrosshairFrame.Rotation = 0
    end
    CrosshairFrame.Visible = Config.Crosshair
end)

-- ============================================================
-- 吃倍数 Hook
-- ============================================================
task.spawn(function()
    local rs = game:GetService("ReplicatedStorage")
    for _, obj in ipairs(rs:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local n = obj.Name:lower()
            if n:find("eat") or n:find("consume") or n:find("food") then
                local oldFire = obj.FireServer
                obj.FireServer = function(self, ...)
                    if Config.EatMultiply then
                        for _ = 1, Config.EatMultiplier do
                            oldFire(self, ...)
                            task.wait(0.05)
                        end
                        return
                    end
                    return oldFire(self, ...)
                end
            end
        end
    end
end)

-- ============================================================
-- 锁定视角
-- ============================================================
RunService:BindToRenderStep("LockView", Enum.RenderPriority.Camera.Value + 1, function()
    if not Config.LockView then return end
    local char = LP.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local camDir = Camera.CFrame.LookVector
    local flatDir = Vector3.new(camDir.X, 0, camDir.Z)
    if flatDir.Magnitude > 0.01 then
        root.CFrame = CFrame.new(root.Position, root.Position + flatDir)
    end
end)

-- ============================================================
-- 动作加速
-- ============================================================
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

-- ============================================================
-- 持续保持移动速度
-- ============================================================
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

-- ============================================================
-- 平滑跟随
-- ============================================================
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
-- ============================================================
-- 清理旧 UI
-- ============================================================
pcall(function()
    if game.CoreGui:FindFirstChild("PiUI") then
        game.CoreGui.PiUI:Destroy()
    end
    if LP.PlayerGui:FindFirstChild("PiUI") then
        LP.PlayerGui.PiUI:Destroy()
    end
end)

-- ============================================================
-- 主 ScreenGui + 主窗口
-- ============================================================
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
Main.Parent = UI
local corner = Instance.new("UICorner", Main)
corner.CornerRadius = UDim.new(0, 8)

-- 背景图
local BgImg = Instance.new("ImageLabel")
BgImg.Size = UDim2.new(1, 0, 1, 0)
BgImg.BackgroundTransparency = 1
BgImg.Image = BG_IMAGE_ID
BgImg.ImageTransparency = BG_TRANSPARENCY
BgImg.ScaleType = Enum.ScaleType.Crop
BgImg.ZIndex = 0
BgImg.Parent = Main
local bgCorner = Instance.new("UICorner", BgImg)
bgCorner.CornerRadius = UDim.new(0, 8)

-- ============================================================
-- 顶部栏
-- ============================================================
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 30)
TopBar.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
TopBar.BackgroundTransparency = 0.2
TopBar.BorderSizePixel = 0
TopBar.ZIndex = 2
TopBar.Parent = Main
local topCorner = Instance.new("UICorner", TopBar)
topCorner.CornerRadius = UDim.new(0, 8)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -80, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "吃吃世界 · 全量优化版"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.ZIndex = 2
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
MinBtn.ZIndex = 2
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
CloseBtn.ZIndex = 2
CloseBtn.Parent = TopBar

-- ============================================================
-- 拖动逻辑
-- ============================================================
local draggingMain, dragStart, startPos = false, nil, nil
TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingMain = true; dragStart = input.Position; startPos = Main.Position
    end
end)
UIS.InputChanged:Connect(function(input)
    if draggingMain and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingMain = false end
end)

-- ============================================================
-- 最小化
-- ============================================================
local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    Main.Size = minimized and UDim2.new(0, 520, 0, 30) or UDim2.new(0, 520, 0, 320)
end)

-- ============================================================
-- 关闭 + 彻底清理所有残留
-- ============================================================
CloseBtn.MouseButton1Click:Connect(function()
    FOVCircle.Visible = false
    FOVCircle:Remove()
    aimConnection:Disconnect()
    fovConnection:Disconnect()
    clearESP()
    espConnection:Disconnect()
    crossConnection:Disconnect()
    CrosshairGui:Destroy()
    UI:Destroy()
end)
-- ============================================================
-- 左右滑动 Toggle 开关
-- ============================================================
local function MakeToggle(parent, text, key, default)
    if Config[key] == nil then Config[key] = default end

    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -10, 0, 36)
    holder.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    holder.BackgroundTransparency = 0.3
    holder.BorderSizePixel = 0
    holder.Parent = parent
    local hc = Instance.new("UICorner", holder)
    hc.CornerRadius = UDim.new(0, 6)

    local label = Instance.new("TextLabel", holder)
    label.Size = UDim2.new(1, -70, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.Gotham
    label.TextSize = 13

    local switchBg = Instance.new("Frame", holder)
    switchBg.Size = UDim2.new(0, 50, 0, 24)
    switchBg.Position = UDim2.new(1, -60, 0.5, -12)
    switchBg.BackgroundColor3 = Config[key] and Color3.fromRGB(60, 180, 80) or Color3.fromRGB(80, 80, 90)
    switchBg.BorderSizePixel = 0
    local sbc = Instance.new("UICorner", switchBg)
    sbc.CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame", switchBg)
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = Config[key] and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    local kc = Instance.new("UICorner", knob)
    kc.CornerRadius = UDim.new(1, 0)

    local clickBtn = Instance.new("TextButton", holder)
    clickBtn.Size = UDim2.new(1, 0, 1, 0)
    clickBtn.BackgroundTransparency = 1
    clickBtn.Text = ""
    clickBtn.ZIndex = 3

    clickBtn.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        local goalColor = Config[key] and Color3.fromRGB(60, 180, 80) or Color3.fromRGB(80, 80, 90)
        local goalPos = Config[key] and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        TweenService:Create(switchBg, TweenInfo.new(0.2), {BackgroundColor3 = goalColor}):Play()
        TweenService:Create(knob, TweenInfo.new(0.2), {Position = goalPos}):Play()
    end)
end

-- ============================================================
-- 滑条
-- ============================================================
local function MakeSlider(parent, text, key, minV, maxV, step, default)
    if Config[key] == nil then Config[key] = default end
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -10, 0, 44)
    holder.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    holder.BackgroundTransparency = 0.3
    holder.BorderSizePixel = 0
    holder.Parent = parent
    local hc = Instance.new("UICorner", holder)
    hc.CornerRadius = UDim.new(0, 6)

    local label = Instance.new("TextLabel", holder)
    label.Size = UDim2.new(1, -10, 0, 20)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.Gotham
    label.TextSize = 12

    local bar = Instance.new("Frame", holder)
    bar.Size = UDim2.new(1, -20, 0, 6)
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
        local shown = (step < 1) and string.format("%.2f", val) or tostring(math.floor(val))
        label.Text = text .. ": " .. shown
    end
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; update(input) end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then update(input) end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
end
-- ============================================================
-- 左侧分类栏
-- ============================================================
local LeftBar = Instance.new("Frame")
LeftBar.Size = UDim2.new(0, 100, 1, -40)
LeftBar.Position = UDim2.new(0, 8, 0, 36)
LeftBar.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
LeftBar.BackgroundTransparency = 0.3
LeftBar.BorderSizePixel = 0
LeftBar.ZIndex = 1
LeftBar.Parent = Main
local lbCorner = Instance.new("UICorner", LeftBar)
lbCorner.CornerRadius = UDim.new(0, 6)

-- 右侧内容区
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -120, 1, -40)
Content.Position = UDim2.new(0, 114, 0, 36)
Content.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
Content.BackgroundTransparency = 0.3
Content.BorderSizePixel = 0
Content.ZIndex = 1
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
Scroll.ZIndex = 1
Scroll.Parent = Content
local scrollLayout = Instance.new("UIListLayout", Scroll)
scrollLayout.Padding = UDim.new(0, 5)
scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- 分类按钮生成器
local function MakeTabButton(text, yPos)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 32)
    btn.Position = UDim2.new(0, 5, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    btn.BackgroundTransparency = 0.3
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.BorderSizePixel = 0
    btn.ZIndex = 2
    btn.Parent = LeftBar
    local c = Instance.new("UICorner", btn)
    c.CornerRadius = UDim.new(0, 5)
    return btn
end

local BtnAim = MakeTabButton("自瞄", 10)
local BtnESP = MakeTabButton("透视", 50)
local BtnOther = MakeTabButton("其他", 90)

-- 清空右侧内容
local function clearContent()
    for _, child in ipairs(Scroll:GetChildren()) do
        if not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end
end

-- ============================================================
-- 自瞄页
-- ============================================================
local function showAim()
    clearContent()
    MakeToggle(Scroll, "启用自瞄", "AimbotEnabled", false)
    MakeToggle(Scroll, "队伍识别", "TeamCheck", true)
    MakeToggle(Scroll, "掩体识别", "WallCheck", true)
    MakeSlider(Scroll, "平滑度", "AimSmoothness", 0.05, 1, 0.01, 0.25)
    MakeSlider(Scroll, "自瞄速度", "AimSpeed", 0.1, 3, 0.1, 1)
    MakeSlider(Scroll, "自瞄距离", "AimDistance", 50, 2000, 10, 500)
    MakeSlider(Scroll, "FOV 大小", "FOVRadius", 30, 500, 5, 120)
    MakeSlider(Scroll, "FOV 粗细", "FOVThickness", 1, 10, 0.5, 2)
    MakeSlider(Scroll, "FOV 透明度", "FOVTransparency", 0, 1, 0.05, 0.9)

    -- FOV 颜色按钮
    local colorFrame = Instance.new("Frame")
    colorFrame.Size = UDim2.new(1, -10, 0, 36)
    colorFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    colorFrame.BackgroundTransparency = 0.3
    colorFrame.BorderSizePixel = 0
    colorFrame.Parent = Scroll
    local cfCorner = Instance.new("UICorner", colorFrame)
    cfCorner.CornerRadius = UDim.new(0, 6)

    local cfLabel = Instance.new("TextLabel", colorFrame)
    cfLabel.Size = UDim2.new(0, 80, 1, 0)
    cfLabel.Position = UDim2.new(0, 10, 0, 0)
    cfLabel.BackgroundTransparency = 1
    cfLabel.Text = "FOV 颜色"
    cfLabel.TextColor3 = Color3.new(1,1,1)
    cfLabel.Font = Enum.Font.Gotham
    cfLabel.TextSize = 12
    cfLabel.TextXAlignment = Enum.TextXAlignment.Left

    local colors = {
        Color3.fromRGB(255,255,255), Color3.fromRGB(255,0,0),
        Color3.fromRGB(0,255,0), Color3.fromRGB(0,150,255),
        Color3.fromRGB(255,255,0), Color3.fromRGB(0,255,255),
    }
    for i, col in ipairs(colors) do
        local cb = Instance.new("TextButton", colorFrame)
        cb.Size = UDim2.new(0, 22, 0, 22)
        cb.Position = UDim2.new(0, 95 + (i-1) * 28, 0.5, -11)
        cb.BackgroundColor3 = col
        cb.Text = ""
        cb.BorderSizePixel = 1
        cb.BorderColor3 = Color3.new(0,0,0)
        local cbc = Instance.new("UICorner", cb)
        cbc.CornerRadius = UDim.new(1, 0)
        cb.MouseButton1Click:Connect(function()
            Config.FOVColor = col
        end)
    end

    -- 瞄准部位切换
    local partFrame = Instance.new("Frame")
    partFrame.Size = UDim2.new(1, -10, 0, 36)
    partFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    partFrame.BackgroundTransparency = 0.3
    partFrame.BorderSizePixel = 0
    partFrame.Parent = Scroll
    local pfCorner = Instance.new("UICorner", partFrame)
    pfCorner.CornerRadius = UDim.new(0, 6)

    local pfLabel = Instance.new("TextLabel", partFrame)
    pfLabel.Size = UDim2.new(0, 80, 1, 0)
    pfLabel.Position = UDim2.new(0, 10, 0, 0)
    pfLabel.BackgroundTransparency = 1
    pfLabel.Text = "瞄准部位"
    pfLabel.TextColor3 = Color3.new(1,1,1)
    pfLabel.Font = Enum.Font.Gotham
    pfLabel.TextSize = 12
    pfLabel.TextXAlignment = Enum.TextXAlignment.Left

    -- 3 个部位按钮
    local parts = {"Head", "HumanoidRootPart", "UpperTorso"}
    for i, pname in ipairs(parts) do
        local pb = Instance.new("TextButton", partFrame)
        pb.Size = UDim2.new(0, 70, 0, 22)
        pb.Position = UDim2.new(0, 95 + (i-1) * 75, 0.5, -11)
        pb.BackgroundColor3 = (Config.AimPart == pname) and Color3.fromRGB(80,160,255)
                                                          or Color3.fromRGB(60,60,70)
        pb.Text = pname
        pb.TextColor3 = Color3.new(1,1,1)
        pb.Font = Enum.Font.Gotham
        pb.TextSize = 10
        pb.BorderSizePixel = 0
        local pbc = Instance.new("UICorner", pb)
        pbc.CornerRadius = UDim.new(0, 5)
        pb.MouseButton1Click:Connect(function()
            Config.AimPart = pname
            for _, other in ipairs(partFrame:GetChildren()) do
                if other:IsA("TextButton") then
                    other.BackgroundColor3 = (other.Text == pname)
                        and Color3.fromRGB(80,160,255)
                        or Color3.fromRGB(60,60,70)
                end
            end
        end)
    end
end    -- ← 这里是 showAim 函数的结束，必须有

-- ============================================================
-- 透视页
-- ============================================================
local function showESP()
    clearContent()
    MakeToggle(Scroll, "启用透视", "ESPEnabled", false)
    MakeToggle(Scroll, "透视队伍识别", "ESPTeamCheck", true)
end

-- ============================================================
-- 其他页
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
-- 绑定分类按钮 + 默认显示自瞄页
-- ============================================================
BtnAim.MouseButton1Click:Connect(showAim)
BtnESP.MouseButton1Click:Connect(showESP)
BtnOther.MouseButton1Click:Connect(showOther)
showAim()

-- ============================================================
-- 加载完成提示
-- ============================================================
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "吃吃世界 · 全量优化版",
    Text = "加载完成",
    Duration = 3,
})