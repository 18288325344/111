-- 最小UI测试
local LP = game:GetService("Players").LocalPlayer

local test = Instance.new("ScreenGui")
test.Name = "TestUI"
test.ResetOnSpawn = false
test.Parent = LP:WaitForChild("PlayerGui")

local box = Instance.new("Frame")
box.Size = UDim2.new(0, 300, 0, 200)
box.Position = UDim2.new(0.5, -150, 0.5, -100)
box.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
box.BorderSizePixel = 0
box.Parent = test

print("测试UI创建完成，应该能看到红色方块")
-- CoreGui测试
local test = Instance.new("ScreenGui")
test.Name = "TestUI2"
test.ResetOnSpawn = false
test.Parent = game:GetService("CoreGui")

local box = Instance.new("Frame")
box.Size = UDim2.new(0, 300, 0, 200)
box.Position = UDim2.new(0.5, -150, 0.5, -100)
box.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
box.BorderSizePixel = 0
box.Parent = test

print("CoreGui测试完成，应该能看到绿色方块")