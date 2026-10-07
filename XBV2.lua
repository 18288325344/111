-- 弹出欢迎通知
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "吃吃世界 · 二改版",
    Text = "自瞄 + 透视 | 横向UI",
    Duration = 3,
})

-- ===== 换成稳定的 Fluent 官方库地址 =====
local LibURL = "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Init.lua"
local AddonsURL = "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/"

-- 安全加载函数
local function safeLoad(url)
    local ok, res = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    if not ok then
        warn("加载失败: " .. url)
        return nil
    end
    return res
end

-- 加载主库
local Library = safeLoad(LibURL)

-- 加载附加组件
local ThemeManager = safeLoad(AddonsURL .. "ThemeManager.lua")
local SaveManager  = safeLoad(AddonsURL .. "SaveManager.lua")

-- 库加载失败就退出
if not Library then
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "错误",
        Text = "Fluent 库加载失败，请检查网络",
        Duration = 5,
    })
    return
end
-- 常用的几个服务
local Players = game:GetService("Players")       -- 玩家服务
local RunService = game:GetService("RunService") -- 每帧服务
local UIS = game:GetService("UserInputService")  -- 键鼠输入
local Camera = workspace.CurrentCamera           -- 当前摄像机
local LP = Players.LocalPlayer                   -- 本地玩家

-- 所有可调参数都在这里，UI 滑块改的就是这里
local Config = {
    -- ===== 自瞄 =====
    AimbotEnabled = false,      -- 自瞄总开关
    AimSmoothness = 0.25,       -- 平滑度，越小越稳（0.05~1）
    AimSpeed = 1,               -- 自瞄速度倍率
    AimPart = "Head",           -- 瞄准部位
    AimDistance = 500,          -- 最大距离（米）
    TeamCheck = true,           -- 队伍识别
    WallCheck = true,           -- 掩体识别

    -- ===== FOV 圆圈 =====
    FOVRadius = 120,            -- 半径
    FOVColor = Color3.fromRGB(255, 255, 255),  -- 默认白色
    FOVThickness = 2,           -- 线条粗细
    FOVTransparency = 0.9,      -- 透明度

    -- ===== 透视 =====
    ESPEnabled = false,         -- 透视总开关
    ESPTeamCheck = true,        -- 透视队伍识别（队友绿、敌人红）

    -- ===== 原有功能 =====
    ActionSpeed = false,        -- 动作加速
    EatMultiply = false,        -- 吃倍数
    EatMultiplier = 2,          -- 吃倍数数值
    WalkSpeed = 16,             -- 移动速度
    SmoothFollow = false,       -- 平滑跟随
    LockView = false,           -- 锁定视角
    Crosshair = false,          -- 准星
    CrosshairSpin = false,      -- 准星旋转
}
-- ====== FOV 圆圈（用 Drawing 画，能直接画在屏幕上）======
local FOVCircle = Drawing.new("Circle")
FOVCircle.NumSides = 100       -- 圆的边数，越多越圆滑
FOVCircle.Filled = false       -- 空心（不填充内部）
FOVCircle.Thickness = 2
FOVCircle.Color = Color3.fromRGB(255, 255, 255)  -- 白色
FOVCircle.Radius = 120
FOVCircle.Transparency = 0.9
FOVCircle.Visible = false      -- 一开始不显示

-- 每帧更新圆圈位置（保证它一直在屏幕正中央，不偏下）
RunService.RenderStepped:Connect(function()
    -- Camera.ViewportSize / 2 就是屏幕正中心那个点，X 和 Y 都取一半
    FOVCircle.Position = Camera.ViewportSize / 2
    FOVCircle.Radius = Config.FOVRadius                    -- 半径跟配置走
    FOVCircle.Thickness = Config.FOVThickness              -- 粗细跟配置走
    FOVCircle.Color = Config.FOVColor                      -- 颜色跟配置走
    FOVCircle.Transparency = Config.FOVTransparency        -- 透明度跟配置走
    FOVCircle.Visible = Config.AimbotEnabled               -- 开自瞄才显示
end)

-- ====== 准星 UI（原脚本保留）======
local CrosshairGui = Instance.new("ScreenGui")
CrosshairGui.Name = "CrosshairGui"
CrosshairGui.Parent = LP:WaitForChild("PlayerGui")
CrosshairGui.ResetOnSpawn = false
CrosshairGui.IgnoreGuiInset = true

local CrosshairFrame = Instance.new("Frame")
CrosshairFrame.Size = UDim2.new(0, 30, 0, 30)
CrosshairFrame.Position = UDim2.new(0.5, -15, 0.5, -15)
CrosshairFrame.BackgroundTransparency = 1
CrosshairFrame.Visible = false
CrosshairFrame.Parent = CrosshairGui

-- 横线
local hLine = Instance.new("Frame", CrosshairFrame)
hLine.Size = UDim2.new(1, 0, 0, 2)
hLine.Position = UDim2.new(0, 0, 0.5, -1)
hLine.BackgroundColor3 = Color3.new(1,1,1)
hLine.BorderSizePixel = 0

-- 竖线
local vLine = Instance.new("Frame", CrosshairFrame)
vLine.Size = UDim2.new(0, 2, 1, 0)
vLine.Position = UDim2.new(0.5, -1, 0, 0)
vLine.BackgroundColor3 = Color3.new(1,1,1)
vLine.BorderSizePixel = 0

-- 中心点
local dot = Instance.new("Frame", CrosshairFrame)
dot.Size = UDim2.new(0, 6, 0, 6)
dot.Position = UDim2.new(0.5, -3, 0.5, -3)
dot.BackgroundColor3 = Color3.new(1,1,1)
dot.BorderSizePixel = 0
local dotCorner = Instance.new("UICorner", dot)
dotCorner.CornerRadius = UDim.new(1, 0)
-- ====== 射线检测参数（用于掩体识别）======
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude  -- 排除某些物体不检测
rayParams.IgnoreWater = true                           -- 忽略水

-- 队伍识别：判断某个玩家是不是你的队友
local function isSameTeam(plr)
    if not Config.TeamCheck then return false end          -- 没开队伍识别就不算队友
    if not plr.Team or not LP.Team then return false end   -- 没队伍也返回 false
    return plr.Team == LP.Team                             -- 同队伍就返回 true
end

-- 掩体识别：你和目标之间有没有墙
local function hasLineOfSight(plr, partName)
    if not Config.WallCheck then return true end       -- 没开掩体识别直接能看见
    if not LP.Character then return false end          -- 自己没角色就看不见

    -- 找到目标身上要瞄准的部位
    local tPart = plr.Character and plr.Character:FindFirstChild(partName)
    if not tPart then return false end

    -- 排除列表：自己、目标、队伍指示器
    local filter = {LP.Character, plr.Character}
    local ti = workspace:FindFirstChild("TeamIndicators")
    if ti then table.insert(filter, ti) end
    rayParams.FilterDescendantsInstances = filter

    -- 从相机位置向目标发射一条射线
    local origin = Camera.CFrame.Position
    local dir = tPart.Position - origin
    local result = workspace:Raycast(origin, dir, rayParams)

    -- 没打到东西 = 中间没墙 = 能看见
    return result == nil
end

-- 找出 FOV 圈内离屏幕中心最近的敌人
local function findTarget()
    local closest, shortest = nil, Config.FOVRadius
    local center = Camera.ViewportSize / 2   -- 屏幕正中心

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end            -- 跳过自己
        if isSameTeam(plr) then continue end      -- 跳过队友
        if not plr.Character then continue end    -- 跳过没角色的

        -- 检查是否活着
        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end

        -- 找瞄准部位（找不到就用身体中心）
        local part = plr.Character:FindFirstChild(Config.AimPart)
            or plr.Character:FindFirstChild("HumanoidRootPart")
        if not part then continue end

        -- 3D 坐标转屏幕 2D 坐标
        local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end

        -- 计算离屏幕中心的距离（像素）
        local d = (Vector2.new(pos.X, pos.Y) - center).Magnitude
        if d > Config.FOVRadius then continue end     -- 超出 FOV 圈跳过

        -- 检查距离上限
        local myHrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        local tHrp = plr.Character:FindFirstChild("HumanoidRootPart")
        if myHrp and tHrp then
            if (myHrp.Position - tHrp.Position).Magnitude > Config.AimDistance then
                continue
            end
        end

        -- 掩体检查
        if not hasLineOfSight(plr, Config.AimPart) then continue end

        -- 记录最近的
        if d < shortest then
            shortest = d
            closest = part
        end
    end
    return closest
end

-- 自瞄主循环（每帧执行）
RunService.RenderStepped:Connect(function()
    if not Config.AimbotEnabled then return end    -- 没开自瞄退出
    local target = findTarget()                    -- 找目标
    if not target then return end                  -- 没目标退出

    local camPos = Camera.CFrame.Position
    local desired = CFrame.new(camPos, target.Position)  -- 想看向的方向

    -- alpha 越大转得越快，越小越平滑
    local alpha = math.clamp(Config.AimSmoothness * Config.AimSpeed, 0.01, 1)

    -- Lerp 是线性插值，让相机平滑过渡而不是瞬间甩过去
    Camera.CFrame = Camera.CFrame:Lerp(desired, alpha)
end)
-- ====== 透视系统（Highlight + 头顶文字）======
local espCache = {}   -- 缓存每个玩家的透视对象

local function ensureESP(plr)
    if plr == LP then return end              -- 跳过自己
    if not plr.Character then return end      -- 没角色跳过

    local data = espCache[plr]

    -- 第一次碰到这个玩家就创建透视对象
    if not data then
        -- 高亮（人物发光）
        local hl = Instance.new("Highlight")
        hl.Name = "ESP_HL"
        hl.FillTransparency = 0.5
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop  -- 穿透显示
        hl.Parent = game:GetService("CoreGui")

        -- 头顶文字框
        local bb = Instance.new("BillboardGui")
        bb.Name = "ESP_BB"
        bb.Size = UDim2.new(0, 200, 0, 50)
        bb.StudsOffset = Vector3.new(0, 3, 0)     -- 头顶上方 3 格
        bb.AlwaysOnTop = true
        bb.Parent = game:GetService("CoreGui")

        -- 名字
        local n = Instance.new("TextLabel", bb)
        n.Size = UDim2.new(1, 0, 0.5, 0)
        n.BackgroundTransparency = 1
        n.TextColor3 = Color3.new(1,1,1)
        n.TextStrokeTransparency = 0.5
        n.TextScaled = true
        n.Font = Enum.Font.GothamBold

        -- 血量
        local h = Instance.new("TextLabel", bb)
        h.Position = UDim2.new(0, 0, 0.5, 0)
        h.Size = UDim2.new(1, 0, 0.5, 0)
        h.BackgroundTransparency = 1
        h.TextColor3 = Color3.new(0,1,0)
        h.TextStrokeTransparency = 0.5
        h.TextScaled = true
        h.Font = Enum.Font.GothamBold

        data = {HL = hl, BB = bb, N = n, H = h}
        espCache[plr] = data
    end

    -- 透视关了或目标没角色就隐藏
    if not Config.ESPEnabled or not plr.Character then
        data.HL.Enabled = false
        data.BB.Enabled = false
        return
    end

    -- 队伍判断：队友绿色 敌人红色
    local isMate = Config.ESPTeamCheck and plr.Team and plr.Team == LP.Team
    local color = isMate and Color3.fromRGB(0, 255, 0)     -- 队友绿
                       or Color3.fromRGB(255, 0, 0)        -- 敌人红

    -- 更新发光
    data.HL.Adornee = plr.Character
    data.HL.FillColor = color
    data.HL.OutlineColor = color
    data.HL.Enabled = true

    -- 把文字挂在头顶
    local head = plr.Character:FindFirstChild("Head")
    if head then data.BB.Adornee = head end
    data.BB.Enabled = true

    -- 名字（带队伍标记）
    data.N.Text = plr.Name .. (isMate and " [队友]" or " [敌人]")
    data.N.TextColor3 = color

    -- 血量
    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        data.H.Text = math.floor(hum.Health) .. " / " .. math.floor(hum.MaxHealth)
    end
end

-- 每帧刷新所有玩家的透视
RunService.Heartbeat:Connect(function()
    for _, plr in ipairs(Players:GetPlayers()) do
        ensureESP(plr)
    end
end)

-- 玩家离开时清理透视对象，防止内存泄漏
Players.PlayerRemoving:Connect(function(plr)
    if espCache[plr] then
        espCache[plr].HL:Destroy()
        espCache[plr].BB:Destroy()
        espCache[plr] = nil
    end
end)
-- ====== 动作加速（吃东西、搬东西动画变快）======
task.spawn(function()
    while true do
        if Config.ActionSpeed then
            local char = LP.Character
            if char then
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    -- 把所有正在播放的动画速度改成 3 倍
                    for _, track in pairs(humanoid:GetPlayingAnimationTracks()) do
                        track:AdjustSpeed(3.0)
                    end
                end
            end
        end
        task.wait(0.3)
    end
end)

-- ====== 吃倍数（Hook 所有 Eat/Consume/Food 相关的远程事件）======
task.spawn(function()
    local rs = game:GetService("ReplicatedStorage")
    for _, obj in ipairs(rs:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local name = obj.Name:lower()
            if name:find("eat") or name:find("consume") or name:find("food") then
                local oldFire = obj.FireServer
                -- 拦截 FireServer，触发多次
                obj.FireServer = function(self, ...)
                    if Config.EatMultiply then
                        for i = 1, Config.EatMultiplier do
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

-- ====== 持续保持移动速度 ======
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

-- ====== 平滑跟随（自动贴到最近玩家身后）======
RunService.Heartbeat:Connect(function()
    if not Config.SmoothFollow then return end
    local myChar = LP.Character
    if not myChar then return end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    -- 找最近的玩家
    local nearest, minDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local dist = (p.Character.HumanoidRootPart.Position - myRoot.Position).Magnitude
            if dist < minDist then
                minDist = dist
                nearest = p
            end
        end
    end

    if nearest then
        local tRoot = nearest.Character.HumanoidRootPart
        local offset = tRoot.CFrame.LookVector * -2.5   -- 对方身后 2.5 格
        myRoot.CFrame = CFrame.new(tRoot.Position + offset, tRoot.Position)
    end
end)

-- ====== 锁定视角（相机转向哪，人就面朝哪）======
RunService:BindToRenderStep("LockView", Enum.RenderPriority.Camera.Value + 1, function()
    if not Config.LockView then return end
    local char = LP.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local camDir = Camera.CFrame.LookVector
    -- 忽略 Y 轴，只取水平方向
    local flatDir = Vector3.new(camDir.X, 0, camDir.Z)
    if flatDir.Magnitude > 0.01 then
        root.CFrame = CFrame.new(root.Position, root.Position + flatDir)
    end
end)

-- ====== 准星旋转 ======
RunService.Heartbeat:Connect(function()
    if Config.Crosshair and Config.CrosshairSpin then
        CrosshairFrame.Rotation = (CrosshairFrame.Rotation + 1) % 360
    elseif Config.Crosshair then
        CrosshairFrame.Rotation = 0
    end
    CrosshairFrame.Visible = Config.Crosshair
end)
-- ====== 飞行脚本（创建一个小窗口）======
local function loadFlightScript()
    -- 创建所有 UI 元素
    local main = Instance.new("ScreenGui")
    local Frame = Instance.new("Frame")
    local up = Instance.new("TextButton")
    local down = Instance.new("TextButton")
    local onof = Instance.new("TextButton")
    local TextLabel = Instance.new("TextLabel")
    local plus = Instance.new("TextButton")
    local speed = Instance.new("TextLabel")
    local mine = Instance.new("TextButton")
    local closebutton = Instance.new("TextButton")
    local mini = Instance.new("TextButton")
    local mini2 = Instance.new("TextButton")

    main.Name = "main"
    main.Parent = LP:WaitForChild("PlayerGui")
    main.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    main.ResetOnSpawn = false

    -- 主框架（绿色）
    Frame.Parent = main
    Frame.BackgroundColor3 = Color3.fromRGB(163,255,137)
    Frame.BorderColor3 = Color3.fromRGB(103,221,213)
    Frame.Position = UDim2.new(0.1, 0, 0.38, 0)
    Frame.Size = UDim2.new(0, 190, 0, 57)

    -- 上升按钮
    up.Name = "up"; up.Parent = Frame
    up.BackgroundColor3 = Color3.fromRGB(79,255,152)
    up.Size = UDim2.new(0, 44, 0, 28)
    up.Text = "上升"; up.TextSize = 14

    -- 下落按钮
    down.Name = "down"; down.Parent = Frame
    down.BackgroundColor3 = Color3.fromRGB(215,255,121)
    down.Position = UDim2.new(0, 0, 0.49, 0)
    down.Size = UDim2.new(0, 44, 0, 28)
    down.Text = "下落"; down.TextSize = 14

    -- 飞行开关按钮
    onof.Name = "onof"; onof.Parent = Frame
    onof.BackgroundColor3 = Color3.fromRGB(255,249,74)
    onof.Position = UDim2.new(0.7, 0, 0.49, 0)
    onof.Size = UDim2.new(0, 56, 0, 28)
    onof.Text = "飞"; onof.TextSize = 14

    -- 标题文字
    TextLabel.Parent = Frame
    TextLabel.BackgroundColor3 = Color3.fromRGB(242,60,255)
    TextLabel.Position = UDim2.new(0.47, 0, 0, 0)
    TextLabel.Size = UDim2.new(0, 100, 0, 28)
    TextLabel.Text = "恐拜大帝"; TextLabel.TextScaled = true

    -- 加速按钮
    plus.Name = "plus"; plus.Parent = Frame
    plus.BackgroundColor3 = Color3.fromRGB(133,145,255)
    plus.Position = UDim2.new(0.23, 0, 0, 0)
    plus.Size = UDim2.new(0, 45, 0, 28)
    plus.Text = "+"; plus.TextScaled = true

    -- 当前速度数字
    speed.Name = "speed"; speed.Parent = Frame
    speed.BackgroundColor3 = Color3.fromRGB(255,85,0)
    speed.Position = UDim2.new(0.47, 0, 0.49, 0)
    speed.Size = UDim2.new(0, 44, 0, 28)
    speed.Text = "1"; speed.TextScaled = true

    -- 减速按钮
    mine.Name = "mine"; mine.Parent = Frame
    mine.BackgroundColor3 = Color3.fromRGB(123,255,247)
    mine.Position = UDim2.new(0.23, 0, 0.49, 0)
    mine.Size = UDim2.new(0, 45, 0, 29)
    mine.Text = "-"; mine.TextScaled = true

    -- 关闭按钮
    closebutton.Name = "Close"; closebutton.Parent = Frame
    closebutton.BackgroundColor3 = Color3.fromRGB(225,25,0)
    closebutton.Size = UDim2.new(0, 45, 0, 28)
    closebutton.Text = "X"; closebutton.TextSize = 30
    closebutton.Position = UDim2.new(0, 0, -1, 27)

    -- 最小化按钮
    mini.Name = "minimize"; mini.Parent = Frame
    mini.BackgroundColor3 = Color3.fromRGB(192,150,230)
    mini.Size = UDim2.new(0, 45, 0, 28)
    mini.Text = "-"; mini.TextSize = 40
    mini.Position = UDim2.new(0, 44, -1, 27)

    -- 恢复按钮
    mini2.Name = "minimize2"; mini2.Parent = Frame
    mini2.BackgroundColor3 = Color3.fromRGB(192,150,230)
    mini2.Size = UDim2.new(0, 45, 0, 28)
    mini2.Text = "+"; mini2.TextSize = 40
    mini2.Position = UDim2.new(0, 44, 0, 30)
    mini2.Visible = false

    -- 一些变量
    local speeds = 1
    local speaker = LP
    local chr = speaker.Character
    local hum = chr and chr:FindFirstChildWhichIsA("Humanoid")
    local nowe = false

    Frame.Active = true
    Frame.Draggable = true
    -- 关闭按钮：销毁整个窗口
closebutton.MouseButton1Click:Connect(function() main:Destroy() end)

-- 上升 3 格
up.MouseButton1Click:Connect(function()
    if chr and chr:FindFirstChild("HumanoidRootPart") then
        chr.HumanoidRootPart.CFrame = chr.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0)
    end
end)

-- 下落 3 格
down.MouseButton1Click:Connect(function()
    if chr and chr:FindFirstChild("HumanoidRootPart") then
        chr.HumanoidRootPart.CFrame = chr.HumanoidRootPart.CFrame + Vector3.new(0, -3, 0)
    end
end)

-- 最小化：隐藏所有按钮，只留标题
mini.MouseButton1Click:Connect(function()
    up.Visible = false; down.Visible = false; onof.Visible = false
    plus.Visible = false; speed.Visible = false; mine.Visible = false
    closebutton.Visible = false; mini.Visible = false; mini2.Visible = true
    Frame.Size = UDim2.new(0, 100, 0, 28)
    TextLabel.Position = UDim2.new(0, 0, 0, 0)
end)

-- 恢复：显示所有按钮
mini2.MouseButton1Click:Connect(function()
    up.Visible = true; down.Visible = true; onof.Visible = true
    plus.Visible = true; speed.Visible = true; mine.Visible = true
    closebutton.Visible = true; mini.Visible = true; mini2.Visible = false
    Frame.Size = UDim2.new(0, 190, 0, 57)
    TextLabel.Position = UDim2.new(0.47, 0, 0, 0)
end)

-- 加速：速度 +1
plus.MouseButton1Click:Connect(function()
    speeds = speeds + 1
    speed.Text = tostring(speeds)
end)

-- 减速：速度 -1，最小为 1
mine.MouseButton1Click:Connect(function()
    if speeds > 1 then
        speeds = speeds - 1
        speed.Text = tostring(speeds)
    else
        speed.Text = "错误"
        task.wait(0.2)
        speed.Text = "1"
    end
end)

-- 角色重生时更新引用（防止换角色后失效）
speaker.CharacterAdded:Connect(function(newChar)
    chr = newChar
    hum = chr:FindFirstChildOfClass("Humanoid")
end)
    -- 点击"飞"按钮：开启/关闭飞行
    onof.MouseButton1Click:Connect(function()
        nowe = not nowe
        if nowe then
            -- ===== 开启飞行 =====
            if hum then
                -- 禁用所有 Humanoid 状态
                for _, state in pairs(Enum.HumanoidStateType:GetEnumItems()) do
                    hum:SetStateEnabled(state, false)
                end
                hum:ChangeState(Enum.HumanoidStateType.Swimming)
            end
            if chr.Animate then chr.Animate.Disabled = true end

            -- 根据移动方向持续推人
            task.spawn(function()
                while nowe and chr and hum do
                    RunService.Heartbeat:Wait()
                    if hum.MoveDirection.Magnitude > 0 then
                        chr:TranslateBy(hum.MoveDirection * speeds)
                    end
                end
            end)

            -- 根据 R6 / R15 分别处理物理
            if hum.RigType == Enum.HumanoidRigType.R6 then
                local torso = chr.Torso
                local bg = Instance.new("BodyGyro", torso)
                bg.P = 9e4
                bg.maxTorque = Vector3.new(9e9, 9e9, 9e9)
                bg.CFrame = torso.CFrame
                local bv = Instance.new("BodyVelocity", torso)
                bv.Velocity = Vector3.new(0,0,0)
                bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
                if nowe then chr.Humanoid.PlatformStand = true end
                -- 相机朝哪就飞哪
                while nowe and chr.Humanoid.Health > 0 do
                    RunService.RenderStepped:Wait()
                    bg.CFrame = Camera.CoordinateFrame
                end
                bg:Destroy(); bv:Destroy()
                chr.Humanoid.PlatformStand = false
                chr.Animate.Disabled = false
            else
                local upperTorso = chr.UpperTorso
                local bg = Instance.new("BodyGyro", upperTorso)
                bg.P = 9e4
                bg.maxTorque = Vector3.new(9e9, 9e9, 9e9)
                bg.CFrame = upperTorso.CFrame
                local bv = Instance.new("BodyVelocity", upperTorso)
                bv.Velocity = Vector3.new(0,0,0)
                bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
                if nowe then chr.Humanoid.PlatformStand = true end
                while nowe and chr.Humanoid.Health > 0 do
                    task.wait()
                    bg.CFrame = Camera.CoordinateFrame
                end
                bg:Destroy(); bv:Destroy()
                chr.Humanoid.PlatformStand = false
                chr.Animate.Disabled = false
            end
        else
            -- ===== 关闭飞行 =====
            if hum then
                -- 恢复所有 Humanoid 状态
                for _, state in pairs(Enum.HumanoidStateType:GetEnumItems()) do
                    hum:SetStateEnabled(state, true)
                end
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end
            if chr.Animate then chr.Animate.Disabled = false end
        end
    end)
end   -- ← 这里结束 loadFlightScript 函数
-- ====== 创建主窗口 ======
local Window = Library:CreateWindow({
    Title = "吃吃世界 · 二改版",
    Footer = "自瞄 + 透视 | By 恐拜大帝",
    Icon = 131153193945220,
    NotifySide = "Right",
    ShowCustomCursor = true,
})

-- 3 个大分类 Tab（横向排列）
local Tabs = {
    Aimbot = Window:AddTab("自瞄", "crosshair"),   -- 自瞄大类
    ESP    = Window:AddTab("透视", "eye"),         -- 透视大类
    Other  = Window:AddTab("其他", "settings"),    -- 其他功能
}

-- 自瞄 Tab：左边放开关，右边放参数
local AimLeft  = Tabs.Aimbot:AddLeftGroupbox("功能开关")
local AimRight = Tabs.Aimbot:AddRightGroupbox("参数调节")
-- ============ 透视 Tab ============
local EspLeft  = Tabs.ESP:AddLeftGroupbox("透视开关")
local EspRight = Tabs.ESP:AddRightGroupbox("识别设置")

-- 透视总开关
EspLeft:AddToggle('ESPEnabled', {
    Text = '启用透视',
    Default = false,
    Callback = function(v) Config.ESPEnabled = v end,
})

-- 透视队伍识别
EspRight:AddToggle('ESPTeamCheck', {
    Text = '透视队伍识别（队友绿/敌人红）',
    Default = true,
    Callback = function(v) Config.ESPTeamCheck = v end,
})

-- ============ 其他 Tab ============
local OtherLeft  = Tabs.Other:AddLeftGroupbox("玩家功能")
local OtherRight = Tabs.Other:AddRightGroupbox("视觉功能")

-- 动作加速
OtherLeft:AddToggle('ActionSpeed', {
    Text = '动作加速',
    Default = false,
    Callback = function(v) Config.ActionSpeed = v end,
})

-- 吃倍数开关
OtherLeft:AddToggle('EatMultiply', {
    Text = '吃倍数',
    Default = false,
    Callback = function(v) Config.EatMultiply = v end,
})

-- 吃倍数数值
OtherLeft:AddSlider('EatMultiplier', {
    Text = '吃倍数数值',
    Default = 2,
    Min = 1,
    Max = 10,
    Rounding = 0,
    Suffix = '倍',
    Callback = function(v) Config.EatMultiplier = v end,
})

-- 移动速度
OtherLeft:AddSlider('WalkSpeed', {
    Text = '移动速度',
    Default = 16,
    Min = 16,
    Max = 200,
    Rounding = 0,
    Suffix = 'studs',
    Callback = function(v) Config.WalkSpeed = v end,
})

-- 召唤飞行脚本按钮
OtherLeft:AddButton({
    Text = '召唤飞行脚本',
    Func = loadFlightScript,
    DoubleClick = false,
})

-- 平滑跟随
OtherRight:AddToggle('SmoothFollow', {
    Text = '平滑跟随',
    Default = false,
    Callback = function(v) Config.SmoothFollow = v end,
})

-- 锁定视角
OtherRight:AddToggle('LockView', {
    Text = '锁定视角',
    Default = false,
    Callback = function(v) Config.LockView = v end,
})

-- 准星
OtherRight:AddToggle('Crosshair', {
    Text = '准星',
    Default = false,
    Callback = function(v) Config.Crosshair = v end,
})

-- 准星旋转
OtherRight:AddToggle('CrosshairSpin', {
    Text = '准星旋转',
    Default = false,
    Callback = function(v) Config.CrosshairSpin = v end,
})

-- 作者信息和卸载按钮
OtherLeft:AddLabel("作者：恐拜大帝 | QQ：3999698324")
OtherLeft:AddButton({
    Text = '卸载脚本',
    Func = function() Library:Unload() end,
    DoubleClick = false,
})

-- ============ 主题 / 配置保存 ============
if ThemeManager then
    ThemeManager:SetLibrary(Library)
    ThemeManager:SetFolder("ChiChiWorld")
    ThemeManager:ApplyToTab(Tabs.Other)
end

if SaveManager then
    SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetFolder("ChiChiWorldConfig")
    SaveManager:BuildConfigSection(Tabs.Other)
end
