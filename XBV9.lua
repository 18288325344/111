-- 加载 WindUI 库
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/ylt410/roblox-Script/refs/heads/main/UI库"))()

-- 基础服务
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Camera = workspace.CurrentCamera
local LP = Players.LocalPlayer

-- 通知函数
local function Notify(title, content, duration, icon)
    pcall(function()
        WindUI:Notify({
            Title = tostring(title or "提示"),
            Content = tostring(content or ""),
            Duration = duration or 3,
            Icon = icon or "info",
        })
    end)
end

-- 加载成功提示
Notify("自瞄+透视", "脚本已加载", 3, "success")
-- 当前主题
local CurrentTheme = "Dark"

-- 背景图预设（可自行添加）
local BgPresets = {
    ["蓝色系猫娘"] = "https://raw.githubusercontent.com/ylt410/Liquid-glass-script/refs/heads/main/FB28370F-CEA8-4CC6-A6E0-51B7DF9071D3.png",
    ["蓝色系少女"] = "https://raw.githubusercontent.com/ylt410/Liquid-glass-script/refs/heads/main/E7B068E4-0859-420F-A6B1-AF519C804C39.png",
    ["粉色系少女"] = "https://raw.githubusercontent.com/ylt410/Liquid-glass-script/refs/heads/main/A19A17E7-7AF5-4E1D-998B-DA69A7C0CD77.png",
}

-- 默认背景
local BgImage = BgPresets["蓝色系猫娘"]
local BackgroundEnabled = true
local BgTransValue = 0.55

-- 注册自定义主题（BlackGold）
WindUI:AddTheme({
    Name = "BlackGold",
    Background = Color3.fromRGB(8,8,10),
    ElementBackground = Color3.fromRGB(98,98,100),
    Button = Color3.fromRGB(140,125,100),
    Hover = Color3.fromRGB(255,255,255),
    Text = Color3.fromRGB(235,235,235),
    Placeholder = Color3.fromRGB(120,120,130),
    Icon = Color3.fromRGB(200,160,80),
    Outline = Color3.fromRGB(70,70,75),
    Accent = WindUI:Gradient({
        ["0"] = { Color = Color3.fromRGB(200,160,80), Transparency = 0.5 },
        ["100"] = { Color = Color3.fromRGB(120,90,40), Transparency = 0.5 },
    }),
    WindowBackground = Color3.fromRGB(8,8,10),
    TabTitle = Color3.fromRGB(235,235,235),
    TabIcon = Color3.fromRGB(200,160,80),
    ElementTitle = Color3.fromRGB(235,235,235),
    ElementDesc = Color3.fromRGB(150,150,160),
    Toggle = Color3.fromRGB(90,70,40),
    ToggleBar = Color3.fromRGB(255,255,255),
    Slider = Color3.fromRGB(90,70,40),
    SliderThumb = Color3.fromRGB(255,255,255),
    Checkbox = Color3.fromRGB(90,70,40),
    CheckboxIcon = Color3.fromRGB(255,255,255),
})
-- 创建一个 ScreenGui 挂 FOV 圈
local FOVScreenGui = Instance.new("ScreenGui")
FOVScreenGui.Name = "FOVCircle"
FOVScreenGui.IgnoreGuiInset = true
FOVScreenGui.ResetOnSpawn = false
FOVScreenGui.Parent = game.CoreGui

-- FOV 圆圈本体（居中、空心、白色）
local FOVCircle = Instance.new("Frame")
FOVCircle.Name = "Circle"
FOVCircle.AnchorPoint = Vector2.new(0.5, 0.5)
FOVCircle.Position = UDim2.new(0.5, 0, 0.5, 0)   -- 屏幕正中央
FOVCircle.Size = UDim2.new(0, 240, 0, 240)
FOVCircle.BackgroundTransparency = 1              -- 空心
FOVCircle.Visible = false                          -- 默认隐藏
FOVCircle.Parent = FOVScreenGui

-- 描边（白色）
local FOVStroke = Instance.new("UIStroke")
FOVStroke.Thickness = 2
FOVStroke.Color = Color3.fromRGB(255, 255, 255)   -- 白色
FOVStroke.Transparency = 0.3
FOVStroke.Parent = FOVCircle

-- 圆角（做成圆）
local FOVCorner = Instance.new("UICorner")
FOVCorner.CornerRadius = UDim.new(1, 0)
FOVCorner.Parent = FOVCircle
-- ============ 自瞄变量 ============
local Aim = {
    Enabled = false,        -- 自瞄开关
    TeamCheck = true,       -- 队伍识别
    WallCheck = true,       -- 掩体识别
    SmoothAim = true,       -- 平滑自瞄
    Smoothness = 0.18,      -- 平滑度
    FOV = 120,              -- FOV 半径
    MaxDistance = 1000,     -- 最大距离
    AimPart = "Head",       -- 瞄准部位
    ShowFOV = true,         -- 显示 FOV 圈
}

-- 瞄准部位列表
local AimPartsList = {"Head", "HumanoidRootPart", "UpperTorso", "Torso"}

-- 获取瞄准部位
local function GetAimPart(char)
    if not char then return nil end
    local part = char:FindFirstChild(Aim.AimPart)
    if not part then
        part = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    end
    return part
end

-- 队伍判断
local function IsSameTeam(plr)
    if not Aim.TeamCheck then return false end
    if not plr.Team or not LP.Team then return false end
    return plr.Team == LP.Team
end

-- 掩体判断（射线检测）
local function HasLineOfSight(plr, part)
    if not Aim.WallCheck then return true end
    if not LP.Character then return false end

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.IgnoreWater = true
    rayParams.FilterDescendantsInstances = {LP.Character, plr.Character}

    local origin = Camera.CFrame.Position
    local result = workspace:Raycast(origin, part.Position - origin, rayParams)
    return result == nil
end
-- 找 FOV 内最近的敌人
local function GetTarget()
    local closest = nil
    local shortestDist = Aim.FOV

    local center = Camera.ViewportSize / 2

    for _, plr in ipairs(Players:GetPlayers()) do
        -- 跳过自己
        if plr ~= LP and not IsSameTeam(plr) and plr.Character then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local part = GetAimPart(plr.Character)
                if part then
                    -- 距离检查
                    local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                    if myRoot then
                        local dist3D = (part.Position - myRoot.Position).Magnitude
                        if dist3D <= Aim.MaxDistance then
                            -- 屏幕坐标转换
                            local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                            if onScreen then
                                -- FOV 距离
                                local dist2D = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                                if dist2D <= Aim.FOV then
                                    -- 掩体检查
                                    if HasLineOfSight(plr, part) then
                                        if dist2D < shortestDist then
                                            shortestDist = dist2D
                                            closest = part
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return closest
end
-- 自瞄渲染循环
RunService.RenderStepped:Connect(function()
    -- ===== FOV 圈更新（不管自瞄开没开，FOV 圈都可能显示）=====
    if FOVCircle then
        -- 更新大小（半径 * 2）
        FOVCircle.Size = UDim2.new(0, Aim.FOV * 2, 0, Aim.FOV * 2)

        -- 显示状态：自瞄开 + 显示 FOV 开
        local shouldShow = Aim.Enabled and Aim.ShowFOV
        if FOVCircle.Visible ~= shouldShow then
            FOVCircle.Visible = shouldShow
        end
    end

    -- ===== 自瞄逻辑 =====
    if not Aim.Enabled then return end
    if not LP.Character then return end

    local target = GetTarget()
    if target then
        local camPos = Camera.CFrame.Position
        local direction = (target.Position - camPos).Unit
        local newCF = CFrame.new(camPos, camPos + direction)

        if Aim.SmoothAim then
            -- 平滑过渡
            Camera.CFrame = Camera.CFrame:Lerp(newCF, Aim.Smoothness)
        else
            -- 瞬间锁定
            Camera.CFrame = newCF
        end
    end
end)
-- ============ 透视变量 ============
local ESP = {
    Enabled = false,        -- 透视总开关
    Highlight = true,       -- 高亮
    Box = false,            -- 方框
    ShowName = true,        -- 名字
    ShowHealth = true,      -- 血量
    ShowDist = false,       -- 距离
    TeamCheck = true,       -- 队伍识别
}

-- 每个玩家的透视对象缓存
local espCache = {}

-- 清理单个玩家的透视
local function RemoveESP(plr)
    if espCache[plr] then
        for _, obj in pairs(espCache[plr]) do
            if obj and obj.Destroy then obj:Destroy() end
        end
        espCache[plr] = nil
    end
end

-- 清理所有透视
local function ClearAllESP()
    for plr, _ in pairs(espCache) do
        RemoveESP(plr)
    end
    espCache = {}
end
-- 更新单个玩家的透视
local function UpdateESP(plr)
    -- 跳过自己
    if plr == LP or not plr.Character then return end

    local char = plr.Character
    local hum = char:FindFirstChild("Humanoid")
    local head = char:FindFirstChild("Head")
    local root = char:FindFirstChild("HumanoidRootPart")

    -- 检查有效性
    if not hum or not head or not root or hum.Health <= 0 then
        RemoveESP(plr)
        return
    end

    -- 队伍检查（同队跳过）
    if ESP.TeamCheck and plr.Team and plr.Team == LP.Team then
        RemoveESP(plr)
        return
    end

    -- 队伍颜色
    local isMate = plr.Team and LP.Team and plr.Team == LP.Team
    local color = isMate and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0)

    -- 获取或创建缓存
    local data = espCache[plr]
    if not data then
        data = {}
        espCache[plr] = data
    end

    -- 高亮
    if ESP.Highlight then
        if not data.HL or not data.HL.Parent then
            data.HL = Instance.new("Highlight")
            data.HL.Name = "PlayerESP_HL"
            data.HL.FillTransparency = 0.5
            data.HL.OutlineTransparency = 0
            data.HL.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            data.HL.Parent = char
        end
        data.HL.FillColor = color
        data.HL.OutlineColor = color
    elseif data.HL then
        data.HL:Destroy()
        data.HL = nil
    end
    -- 信息文字（名字 + 血量 + 距离）
    local needInfo = ESP.ShowName or ESP.ShowHealth or ESP.ShowDist
    if needInfo then
        if not data.BB or not data.BB.Parent then
            data.BB = Instance.new("BillboardGui")
            data.BB.Name = "PlayerESP_BB"
            data.BB.Size = UDim2.new(0, 200, 0, 40)
            data.BB.StudsOffset = Vector3.new(0, 3, 0)
            data.BB.AlwaysOnTop = true
            data.BB.Parent = char

            data.Label = Instance.new("TextLabel")
            data.Label.Size = UDim2.new(1, 0, 1, 0)
            data.Label.BackgroundTransparency = 1
            data.Label.TextStrokeTransparency = 0.5
            data.Label.TextScaled = true
            data.Label.Font = Enum.Font.GothamBold
            data.Label.RichText = true
            data.Label.Parent = data.BB
        end

        data.BB.Adornee = head

        local text = ""
        if ESP.ShowName then
            text = "<b>" .. plr.DisplayName .. "</b>"
        end
        if ESP.ShowHealth then
            if text ~= "" then text = text .. " " end
            text = text .. "<font color='#"..(hum.Health > 50 and "55ff55" or "ff5555").."'>HP:"..math.floor(hum.Health).."</font>"
        end
        if ESP.ShowDist then
            local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if myRoot then
                local d = math.floor((myRoot.Position - root.Position).Magnitude)
                if text ~= "" then text = text .. " " end
                text = text .. "|" .. d .. "m"
            end
        end

        data.Label.Text = text
        data.Label.TextColor3 = color
    elseif data.BB then
        data.BB:Destroy()
        data.BB = nil
    end
end

-- 透视主循环
RunService.Heartbeat:Connect(function()
    if not ESP.Enabled then
        ClearAllESP()
        return
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        UpdateESP(plr)
    end
end)

-- 玩家离开时清理
Players.PlayerRemoving:Connect(function(plr)
    RemoveESP(plr)
end)
-- 创建主窗口
local Window = WindUI:CreateWindow({
    Title = "自瞄透视",
    Icon = "rbxassetid://114890258053806",
    Author = "精简版",
    Folder = "AimESP",
    Size = UDim2.fromOffset(520, 420),
    Transparent = true,
    Theme = CurrentTheme,
    NewElements = false,
    Background = BackgroundEnabled and BgImage or nil,
    BackgroundImageTransparency = BgTransValue,
    SideBarWidth = 150,
    User = { Enabled = true, Anonymous = false },
})

-- ============ 自瞄 Tab ============
local AimTab = Window:Tab({ Title = "自瞄", Icon = "target", Locked = false })

AimTab:Toggle({
    Title = "自瞄开关",
    Default = false,
    Callback = function(v) Aim.Enabled = v end,
})

AimTab:Toggle({
    Title = "队伍识别",
    Default = true,
    Callback = function(v) Aim.TeamCheck = v end,
})

AimTab:Toggle({
    Title = "掩体识别",
    Default = true,
    Callback = function(v) Aim.WallCheck = v end,
})

AimTab:Toggle({
    Title = "平滑自瞄",
    Default = true,
    Callback = function(v) Aim.SmoothAim = v end,
})

AimTab:Slider({
    Title = "平滑度",
    Value = { Min = 0.05, Max = 1, Default = 0.18 },
    Increment = 0.01,
    Callback = function(v) Aim.Smoothness = v end,
})

AimTab:Slider({
    Title = "自瞄范围 FOV",
    Value = { Min = 30, Max = 600, Default = 120 },
    Increment = 10,
    Callback = function(v) Aim.FOV = v end,
})

AimTab:Slider({
    Title = "最大距离",
    Value = { Min = 100, Max = 3000, Default = 1000 },
    Increment = 50,
    Callback = function(v) Aim.MaxDistance = v end,
})

AimTab:Dropdown({
    Title = "瞄准部位",
    Values = AimPartsList,
    Default = "Head",
    Callback = function(v) Aim.AimPart = v end,
})

AimTab:Toggle({
    Title = "显示 FOV 圈",
    Default = true,
    Callback = function(v) Aim.ShowFOV = v end,
})

-- ============ 透视 Tab ============
local ESPTab = Window:Tab({ Title = "透视", Icon = "eye", Locked = false })

ESPTab:Toggle({
    Title = "透视总开关",
    Default = false,
    Callback = function(v) ESP.Enabled = v end,
})

ESPTab:Toggle({
    Title = "高亮",
    Default = true,
    Callback = function(v) ESP.Highlight = v end,
})

ESPTab:Toggle({
    Title = "显示名字",
    Default = true,
    Callback = function(v) ESP.ShowName = v end,
})

ESPTab:Toggle({
    Title = "显示血量",
    Default = true,
    Callback = function(v) ESP.ShowHealth = v end,
})

ESPTab:Toggle({
    Title = "显示距离",
    Default = false,
    Callback = function(v) ESP.ShowDist = v end,
})

ESPTab:Toggle({
    Title = "透视队伍识别（队友绿/敌人红）",
    Default = true,
    Callback = function(v) ESP.TeamCheck = v end,
})

-- 加载完成提示
WindUI:Notify({
    Title = "加载完成",
    Content = "自瞄 + 透视 | 精简版",
    Duration = 3,
    Icon = "success",
})