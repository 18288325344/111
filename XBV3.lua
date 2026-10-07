-- 加载 Rayfield 库（比 Fluent 稳定）
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- 常用服务
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LP = Players.LocalPlayer

-- 欢迎提示
Rayfield:Notify({
    Title = "吃吃世界 · 二改版",
    Content = "自瞄 + 透视 | 横向UI",
    Duration = 3,
})
local Config = {
    -- 自瞄
    AimbotEnabled = false,
    AimSmoothness = 0.25,
    AimSpeed = 1,
    AimPart = "Head",
    AimDistance = 500,
    TeamCheck = true,
    WallCheck = true,

    -- FOV 圆圈
    FOVRadius = 120,
    FOVColor = Color3.fromRGB(255, 255, 255),
    FOVThickness = 2,
    FOVTransparency = 0.9,

    -- 透视
    ESPEnabled = false,
    ESPTeamCheck = true,

    -- 其他
    ActionSpeed = false,
    EatMultiply = false,
    EatMultiplier = 2,
    WalkSpeed = 16,
    SmoothFollow = false,
    LockView = false,
    Crosshair = false,
    CrosshairSpin = false,
}
-- 空心圆
local FOVCircle = Drawing.new("Circle")
FOVCircle.NumSides = 100
FOVCircle.Filled = false
FOVCircle.Thickness = 2
FOVCircle.Color = Color3.fromRGB(255, 255, 255)
FOVCircle.Radius = 120
FOVCircle.Transparency = 0.9
FOVCircle.Visible = false

-- 每帧更新位置，保证居中
RunService.RenderStepped:Connect(function()
    FOVCircle.Position = Camera.ViewportSize / 2   -- 屏幕正中
    FOVCircle.Radius = Config.FOVRadius
    FOVCircle.Thickness = Config.FOVThickness
    FOVCircle.Color = Config.FOVColor
    FOVCircle.Transparency = Config.FOVTransparency
    FOVCircle.Visible = Config.AimbotEnabled
end)
-- 射线检测参数
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

-- 判断是否队友
local function isSameTeam(plr)
    if not Config.TeamCheck then return false end
    if not plr.Team or not LP.Team then return false end
    return plr.Team == LP.Team
end

-- 判断是否有掩体挡住
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
-- 找最近敌人
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

-- 自瞄主循环
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
    if head then data.BB.Adornee = head end
    data.BB.Enabled = true
    data.N.Text = plr.Name .. (isMate and " [队友]" or " [敌人]")
    data.N.TextColor3 = color

    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        data.H.Text = math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth)
    end
end

RunService.Heartbeat:Connect(function()
    for _, plr in ipairs(Players:GetPlayers()) do ensureESP(plr) end
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

-- 准星旋转
RunService.Heartbeat:Connect(function()
    if Config.Crosshair and Config.CrosshairSpin then
        CrosshairFrame.Rotation = (CrosshairFrame.Rotation + 1) % 360
    elseif Config.Crosshair then
        CrosshairFrame.Rotation = 0
    end
    CrosshairFrame.Visible = Config.Crosshair
end)
-- 动作加速
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

-- 吃倍数 Hook
task.spawn(function()
    for _, obj in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local n = obj.Name:lower()
            if n:find("eat") or n:find("consume") or n:find("food") then
                local oldFire = obj.FireServer
                obj.FireServer = function(self, ...)
                    if Config.EatMultiply then
                        for _ = 1, Config.EatMultiplier do
                            oldFire(self, ...); task.wait(0.05)
                        end
                        return
                    end
                    return oldFire(self, ...)
                end
            end
        end
    end
end)

-- 持续保持移动速度
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
-- 平滑跟随
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

-- 锁定视角
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
-- 飞行的状态变量
local flying = false
local flySpeed = 5
local flyBV, flyBG

-- 创建飞行按钮 UI
local FlyGui = Instance.new("ScreenGui")
FlyGui.Parent = LP:WaitForChild("PlayerGui")
FlyGui.ResetOnSpawn = false

local FlyBtn = Instance.new("TextButton")
FlyBtn.Size = UDim2.new(0, 100, 0, 40)
FlyBtn.Position = UDim2.new(0.1, 0, 0.3, 0)
FlyBtn.BackgroundColor3 = Color3.fromRGB(79, 255, 152)
FlyBtn.Text = "点我飞行"
FlyBtn.TextSize = 16
FlyBtn.Font = Enum.Font.GothamBold
FlyBtn.Parent = FlyGui
FlyBtn.Draggable = true

-- 点击开关飞行
FlyBtn.MouseButton1Click:Connect(function()
    flying = not flying
    FlyBtn.Text = flying and "飞行中..." or "点我飞行"

    local char = LP.Character
    if not char then flying = false; return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then flying = false; return end

    if flying then
        flyBV = Instance.new("BodyVelocity", hrp)
        flyBV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        flyBG = Instance.new("BodyGyro", hrp)
        flyBG.P = 9e4
        flyBG.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        flyBG.CFrame = hrp.CFrame

        -- 移动循环
        task.spawn(function()
            while flying and hrp and hrp.Parent do
                RunService.RenderStepped:Wait()
                local move = hum.MoveDirection
                flyBV.Velocity = move * flySpeed * 10 + Vector3.new(0, 0, 0)
                flyBG.CFrame = Camera.CFrame
            end
        end)
    else
        if flyBV then flyBV:Destroy(); flyBV = nil end
        if flyBG then flyBG:Destroy(); flyBG = nil end
    end
end)

-- 速度控制（W 加速 / S 减速）
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Equals then flySpeed = flySpeed + 1 end
    if input.KeyCode == Enum.KeyCode.Minus and flySpeed > 1 then flySpeed = flySpeed - 1 end
end)
local Window = Rayfield:CreateWindow({
    Name = "吃吃世界 · 二改版",
    LoadingTitle = "加载中...",
    LoadingSubtitle = "自瞄 + 透视",
    ConfigurationSaving = { Enabled = false },
})

-- 3 个大 Tab
local AimTab = Window:CreateTab("自瞄", 4483362458)
local ESPTab = Window:CreateTab("透视", 4483362458)
local OtherTab = Window:CreateTab("其他", 4483362458)

-- ===== 自瞄 Tab =====
AimTab:CreateSection("功能开关")
AimTab:CreateToggle({
    Name = "启用自瞄",
    CurrentValue = false,
    Flag = "AimbotEnabled",
    Callback = function(v) Config.AimbotEnabled = v end,
})
AimTab:CreateToggle({
    Name = "队伍识别（不打队友）",
    CurrentValue = true,
    Flag = "TeamCheck",
    Callback = function(v) Config.TeamCheck = v end,
})
AimTab:CreateToggle({
    Name = "掩体识别（隔墙不打）",
    CurrentValue = true,
    Flag = "WallCheck",
    Callback = function(v) Config.WallCheck = v end,
})

AimTab:CreateSection("参数调节")
AimTab:CreateSlider({
    Name = "平滑度（越小越稳）",
    Range = {0.05, 1}, Increment = 0.01, CurrentValue = 0.25,
    Flag = "AimSmoothness",
    Callback = function(v) Config.AimSmoothness = v end,
})
AimTab:CreateSlider({
    Name = "自瞄速度",
    Range = {0.1, 3}, Increment = 0.1, CurrentValue = 1,
    Flag = "AimSpeed",
    Callback = function(v) Config.AimSpeed = v end,
})
AimTab:CreateSlider({
    Name = "自瞄距离 (米)",
    Range = {50, 2000}, Increment = 10, CurrentValue = 500,
    Flag = "AimDistance",
    Callback = function(v) Config.AimDistance = v end,
})
AimTab:CreateSection("FOV 圆圈（居中空心）")
AimTab:CreateSlider({
    Name = "FOV 大小",
    Range = {30, 500}, Increment = 5, CurrentValue = 120,
    Flag = "FOVRadius",
    Callback = function(v) Config.FOVRadius = v end,
})
AimTab:CreateSlider({
    Name = "FOV 线条粗细",
    Range = {1, 10}, Increment = 0.5, CurrentValue = 2,
    Flag = "FOVThickness",
    Callback = function(v) Config.FOVThickness = v end,
})
AimTab:CreateSlider({
    Name = "FOV 透明度",
    Range = {0, 1}, Increment = 0.05, CurrentValue = 0.9,
    Flag = "FOVTransparency",
    Callback = function(v) Config.FOVTransparency = v end,
})
AimTab:CreateColorPicker({
    Name = "FOV 颜色（默认白色）",
    Color = Color3.fromRGB(255, 255, 255),
    Flag = "FOVColor",
    Callback = function(v) Config.FOVColor = v end,
})
AimTab:CreateDropdown({
    Name = "瞄准部位",
    Options = {"Head","HumanoidRootPart","UpperTorso","LowerTorso","Torso"},
    CurrentOption = {"Head"},
    Flag = "AimPart",
    Callback = function(v) Config.AimPart = v[1] end,
})
-- ===== 透视 Tab =====
ESPTab:CreateSection("透视设置")
ESPTab:CreateToggle({
    Name = "启用透视",
    CurrentValue = false,
    Flag = "ESPEnabled",
    Callback = function(v) Config.ESPEnabled = v end,
})
ESPTab:CreateToggle({
    Name = "透视队伍识别（队友绿/敌人红）",
    CurrentValue = true,
    Flag = "ESPTeamCheck",
    Callback = function(v) Config.ESPTeamCheck = v end,
})

-- ===== 其他 Tab =====
OtherTab:CreateSection("玩家功能")
OtherTab:CreateToggle({
    Name = "动作加速",
    CurrentValue = false, Flag = "ActionSpeed",
    Callback = function(v) Config.ActionSpeed = v end,
})
OtherTab:CreateToggle({
    Name = "吃倍数",
    CurrentValue = false, Flag = "EatMultiply",
    Callback = function(v) Config.EatMultiply = v end,
})
OtherTab:CreateSlider({
    Name = "吃倍数数值",
    Range = {1, 10}, Increment = 1, CurrentValue = 2,
    Flag = "EatMultiplier",
    Callback = function(v) Config.EatMultiplier = v end,
})
OtherTab:CreateSlider({
    Name = "移动速度",
    Range = {16, 200}, Increment = 1, CurrentValue = 16,
    Flag = "WalkSpeed",
    Callback = function(v) Config.WalkSpeed = v end,
})
OtherTab:CreateSection("视觉功能")
OtherTab:CreateToggle({
    Name = "平滑跟随",
    CurrentValue = false, Flag = "SmoothFollow",
    Callback = function(v) Config.SmoothFollow = v end,
})
OtherTab:CreateToggle({
    Name = "锁定视角",
    CurrentValue = false, Flag = "LockView",
    Callback = function(v) Config.LockView = v end,
})
OtherTab:CreateToggle({
    Name = "准星",
    CurrentValue = false, Flag = "Crosshair",
    Callback = function(v) Config.Crosshair = v end,
})
OtherTab:CreateToggle({
    Name = "准星旋转",
    CurrentValue = false, Flag = "CrosshairSpin",
    Callback = function(v) Config.CrosshairSpin = v end,
})
