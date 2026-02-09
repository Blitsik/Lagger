-- VAEB BOOSTER: STYLED GUI
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Remove accessories
local function RemoveAccessories(character)
    if not character then return end
    
    for _, accessory in ipairs(character:GetDescendants()) do
        if accessory:IsA("Accessory") then
            accessory:Destroy()
        end
    end
    
    character.DescendantAdded:Connect(function(child)
        if child:IsA("Accessory") then
            child:Destroy()
        end
    end)
    
    RunService.Heartbeat:Connect(function()
        for _, item in ipairs(character:GetChildren()) do
            if item:IsA("Accessory") then
                item:Destroy()
            end
        end
    end)
end

if LocalPlayer.Character then
    RemoveAccessories(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(RemoveAccessories)

-- GUI Creation
local sg = Instance.new("ScreenGui")
sg.Name = "VaebBooster_Styled"
sg.ResetOnSpawn = false
sg.Parent = PlayerGui

-- Main Frame
local frame = Instance.new("Frame", sg)
frame.Size = UDim2.new(0, 340, 0, 180)
frame.Position = UDim2.new(0.5, -170, 0.5, -90)
frame.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.ClipsDescendants = true

-- ЖИРНАЯ розовая обводка
local frameStroke = Instance.new("UIStroke", frame)
frameStroke.Color = Color3.fromRGB(255, 85, 255)
frameStroke.Thickness = 5

-- Скругление
local frameCorner = Instance.new("UICorner", frame)
frameCorner.CornerRadius = UDim.new(0, 18)

-- Title
local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, -50, 0, 40)
title.Position = UDim2.new(0, 10, 0, 0)
title.Text = "VAEB BOOSTER"
title.TextColor3 = Color3.fromRGB(245, 245, 255)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left

-- Minimize Button
local minBtn = Instance.new("TextButton", frame)
minBtn.Size = UDim2.new(0, 35, 0, 35)
minBtn.Position = UDim2.new(1, -40, 0, 5)
minBtn.Text = "—"
minBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
minBtn.BackgroundTransparency = 1
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 20

-- Speed Label
local speedLabel = Instance.new("TextLabel", frame)
speedLabel.Size = UDim2.new(0, 80, 0, 25)
speedLabel.Position = UDim2.new(0, 15, 0, 50)
speedLabel.Text = "Speed:"
speedLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
speedLabel.BackgroundTransparency = 1
speedLabel.Font = Enum.Font.Gotham
speedLabel.TextSize = 13
speedLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Speed Input
local speedBox = Instance.new("TextBox", frame)
speedBox.Size = UDim2.new(0, 100, 0, 30)
speedBox.Position = UDim2.new(0, 100, 0, 47)
speedBox.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
speedBox.Text = "22.5"
speedBox.TextColor3 = Color3.new(1, 1, 1)
speedBox.Font = Enum.Font.GothamBold
speedBox.TextSize = 14
speedBox.ClearTextOnFocus = false
speedBox.BorderSizePixel = 0

local speedBoxCorner = Instance.new("UICorner", speedBox)
speedBoxCorner.CornerRadius = UDim.new(0, 8)

local speedBoxStroke = Instance.new("UIStroke", speedBox)
speedBoxStroke.Color = Color3.fromRGB(255, 85, 255)
speedBoxStroke.Thickness = 2

-- Jump Label
local jumpLabel = Instance.new("TextLabel", frame)
jumpLabel.Size = UDim2.new(0, 80, 0, 25)
jumpLabel.Position = UDim2.new(0, 15, 0, 90)
jumpLabel.Text = "Jump:"
jumpLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
jumpLabel.BackgroundTransparency = 1
jumpLabel.Font = Enum.Font.Gotham
jumpLabel.TextSize = 13
jumpLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Jump Input
local jumpBox = Instance.new("TextBox", frame)
jumpBox.Size = UDim2.new(0, 100, 0, 30)
jumpBox.Position = UDim2.new(0, 100, 0, 87)
jumpBox.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
jumpBox.Text = "35"
jumpBox.TextColor3 = Color3.new(1, 1, 1)
jumpBox.Font = Enum.Font.GothamBold
jumpBox.TextSize = 14
jumpBox.ClearTextOnFocus = false
jumpBox.BorderSizePixel = 0

local jumpBoxCorner = Instance.new("UICorner", jumpBox)
jumpBoxCorner.CornerRadius = UDim.new(0, 8)

local jumpBoxStroke = Instance.new("UIStroke", jumpBox)
jumpBoxStroke.Color = Color3.fromRGB(255, 85, 255)
jumpBoxStroke.Thickness = 2

-- Toggle Button
local toggleBtn = Instance.new("TextButton", frame)
toggleBtn.Size = UDim2.new(0, 100, 0, 35)
toggleBtn.Position = UDim2.new(0, 220, 0, 55)
toggleBtn.Text = "OFF"
toggleBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
toggleBtn.TextColor3 = Color3.new(1, 1, 1)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 14
toggleBtn.BorderSizePixel = 0

local toggleCorner = Instance.new("UICorner", toggleBtn)
toggleCorner.CornerRadius = UDim.new(0, 10)

local toggleStroke = Instance.new("UIStroke", toggleBtn)
toggleStroke.Color = Color3.fromRGB(255, 50, 50)
toggleStroke.Thickness = 3

-- Status Label
local statusLabel = Instance.new("TextLabel", frame)
statusLabel.Size = UDim2.new(0.5, -10, 0, 20)
statusLabel.Position = UDim2.new(0, 10, 1, -25)
statusLabel.Text = "STATUS: OFF"
statusLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
statusLabel.TextSize = 11
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Code
statusLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Telegram Link
local tgLink = Instance.new("TextLabel", frame)
tgLink.Size = UDim2.new(0.5, -10, 0, 20)
tgLink.Position = UDim2.new(0.5, 0, 1, -25)
tgLink.Text = "t.me/vaeb_scripts"
tgLink.TextColor3 = Color3.fromRGB(255, 85, 255)
tgLink.TextSize = 11
tgLink.BackgroundTransparency = 1
tgLink.Font = Enum.Font.Code
tgLink.TextXAlignment = Enum.TextXAlignment.Right

-- Minimize Logic
local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        frame:TweenSize(UDim2.new(0, 340, 0, 45), "Out", "Quad", 0.3, true)
        minBtn.Text = "+"
    else
        frame:TweenSize(UDim2.new(0, 340, 0, 180), "Out", "Quad", 0.3, true)
        minBtn.Text = "—"
    end
end)

-- Booster Logic
local BoosterEnabled = false
local SpeedValue = 22.5
local JumpValue = 35

local TweenInfoSmooth = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

toggleBtn.MouseButton1Click:Connect(function()
    BoosterEnabled = not BoosterEnabled
    
    if BoosterEnabled then
        toggleBtn.Text = "ON"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
        toggleStroke.Color = Color3.fromRGB(50, 255, 50)
        statusLabel.Text = "STATUS: ON"
        statusLabel.TextColor3 = Color3.fromRGB(50, 255, 50)
    else
        toggleBtn.Text = "OFF"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        toggleStroke.Color = Color3.fromRGB(255, 50, 50)
        statusLabel.Text = "STATUS: OFF"
        statusLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
    end
end)

speedBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        local num = tonumber(speedBox.Text)
        if num and num > 0 then
            SpeedValue = num
        else
            speedBox.Text = tostring(SpeedValue)
        end
    end
end)

jumpBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        local num = tonumber(jumpBox.Text)
        if num and num > 0 then
            JumpValue = num
        else
            jumpBox.Text = tostring(JumpValue)
        end
    end
end)

-- Main Loop
RunService.Heartbeat:Connect(function()
    if not BoosterEnabled then return end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then return end
    
    if humanoid.MoveDirection.Magnitude > 0 then
        rootPart.Velocity = Vector3.new(
            humanoid.MoveDirection.X * SpeedValue,
            rootPart.Velocity.Y,
            humanoid.MoveDirection.Z * SpeedValue
        )
    end
    
    humanoid.UseJumpPower = true
    humanoid.JumpPower = JumpValue
end)
