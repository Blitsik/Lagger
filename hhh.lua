-- VAEB HUB | BETA v1 - Cleaned Version
-- Compact Tabbed Interface: Main & Extra

print("Starting VAEB HUB...")

local CONFIG = {
    AUTO_STEAL_NEAREST = false,
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Check if AnimalsData exists, if not, create dummy data
local AnimalsData = {}
pcall(function()
    local Datas = ReplicatedStorage:FindFirstChild("Datas")
    if Datas then
        local Animals = Datas:FindFirstChild("Animals")
        if Animals then
            AnimalsData = require(Animals)
        end
    end
end)

local allAnimalsCache = {}
local PromptMemoryCache = {}
local InternalStealCache = {}
local LastTargetUID = nil
local LastPlayerPosition = nil
local PlayerVelocity = Vector3.zero

local AUTO_STEAL_PROX_RADIUS = 20
local IsStealing = false
local StealProgress = 0
local CurrentStealTarget = nil
local StealStartTime = 0

local CIRCLE_RADIUS = AUTO_STEAL_PROX_RADIUS
local PART_THICKNESS = 0.3
local PART_HEIGHT = 0.2
local PART_COLOR = Color3.fromRGB(200, 30, 30)
local PartsCount = 65
local circleParts = {}
local circleEnabled = true

local stealConnection = nil
local velocityConnection = nil

-- INVISIBILITY VARIABLES
local connections = {SemiInvisible = {}}
local isInvisible = false
local clone, oldRoot, hip, animTrack, connection, characterConnection

-- ANTI RAGDOLL VARIABLES
local antiRagdollMode = nil
local ragdollConnections = {}
local cachedCharData = {}

-- SETTINGS SAVE/LOAD
local SETTINGS_FILE = "VAEBHubSettings.json"

local function saveSettings()
    local settings = {
        autoGrab = CONFIG.AUTO_STEAL_NEAREST,
        invisSteal = isInvisible,
        antiRagdoll = (antiRagdollMode == "v1"),
        stealRadius = AUTO_STEAL_PROX_RADIUS
    }
    
    pcall(function()
        writefile(SETTINGS_FILE, game:GetService("HttpService"):JSONEncode(settings))
        print("Settings saved!")
    end)
end

local function loadSettings()
    if isfile and isfile(SETTINGS_FILE) then
        local success, data = pcall(function()
            return game:GetService("HttpService"):JSONDecode(readfile(SETTINGS_FILE))
        end)
        
        if success and data then
            print("Settings loaded!")
            return data
        end
    end
    return nil
end

-- CORE AUTO STEAL FUNCTIONS
local function getHRP()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso")
end

local function isMyBase(plotName)
    if not workspace:FindFirstChild("Plots") then return false end
    local plot = workspace.Plots:FindFirstChild(plotName)
    if not plot then return false end
    
    local sign = plot:FindFirstChild("PlotSign")
    if sign then
        local yourBase = sign:FindFirstChild("YourBase")
        if yourBase and yourBase:IsA("BillboardGui") then
            return yourBase.Enabled == true
        end
    end
    return false
end

local function scanSinglePlot(plot)
    if not plot or not plot:IsA("Model") then return end
    if isMyBase(plot.Name) then return end
    
    local podiums = plot:FindFirstChild("AnimalPodiums")
    if not podiums then return end
    
    for _, podium in ipairs(podiums:GetChildren()) do
        if podium:IsA("Model") and podium:FindFirstChild("Base") then
            local animalName = "Unknown"
            local spawn = podium.Base:FindFirstChild("Spawn")
            if spawn then
                for _, child in ipairs(spawn:GetChildren()) do
                    if child:IsA("Model") and child.Name ~= "PromptAttachment" then
                        animalName = child.Name
                        local animalInfo = AnimalsData[animalName]
                        if animalInfo and animalInfo.DisplayName then
                            animalName = animalInfo.DisplayName
                        end
                        break
                    end
                end
            end
            
            table.insert(allAnimalsCache, {
                name = animalName,
                plot = plot.Name,
                slot = podium.Name,
                worldPosition = podium:GetPivot().Position,
                uid = plot.Name .. "_" .. podium.Name,
            })
        end
    end
end

local function initializeScanner()
    task.spawn(function()
        task.wait(2)
        
        if not workspace:FindFirstChild("Plots") then 
            print("No Plots found in workspace")
            return
        end
        
        local plots = workspace.Plots
        
        for _, plot in ipairs(plots:GetChildren()) do
            if plot:IsA("Model") then
                scanSinglePlot(plot)
            end
        end
        
        plots.ChildAdded:Connect(function(plot)
            if plot:IsA("Model") then
                task.wait(0.5)
                scanSinglePlot(plot)
            end
        end)
        
        task.spawn(function()
            while task.wait(5) do
                allAnimalsCache = {}
                for _, plot in ipairs(plots:GetChildren()) do
                    if plot:IsA("Model") then
                        scanSinglePlot(plot)
                    end
                end
            end
        end)
    end)
end

local function findProximityPromptForAnimal(animalData)
    if not animalData then return nil end
    
    local cachedPrompt = PromptMemoryCache[animalData.uid]
    if cachedPrompt and cachedPrompt.Parent then
        return cachedPrompt
    end
    
    if not workspace:FindFirstChild("Plots") then return nil end
    local plot = workspace.Plots:FindFirstChild(animalData.plot)
    if not plot then return nil end
    
    local podiums = plot:FindFirstChild("AnimalPodiums")
    if not podiums then return nil end
    
    local podium = podiums:FindFirstChild(animalData.slot)
    if not podium then return nil end
    
    local base = podium:FindFirstChild("Base")
    if not base then return nil end
    
    local spawn = base:FindFirstChild("Spawn")
    if not spawn then return nil end
    
    local attach = spawn:FindFirstChild("PromptAttachment")
    if not attach then return nil end
    
    for _, p in ipairs(attach:GetChildren()) do
        if p:IsA("ProximityPrompt") then
            PromptMemoryCache[animalData.uid] = p
            return p
        end
    end
    
    return nil
end

local function updatePlayerVelocity()
    local hrp = getHRP()
    if not hrp then return end
    
    local currentPos = hrp.Position
    
    if LastPlayerPosition then
        PlayerVelocity = (currentPos - LastPlayerPosition) / task.wait()
    end
    
    LastPlayerPosition = currentPos
end

local function shouldSteal(animalData)
    if not animalData or not animalData.worldPosition then return false end
    
    local hrp = getHRP()
    if not hrp then return false end
    
    local currentDistance = (hrp.Position - animalData.worldPosition).Magnitude
    
    return currentDistance <= AUTO_STEAL_PROX_RADIUS
end

local function buildStealCallbacks(prompt)
    if InternalStealCache[prompt] then return end
    
    local data = {
        holdCallbacks = {},
        triggerCallbacks = {},
        ready = true,
    }
    
    local ok1, conns1 = pcall(getconnections, prompt.PromptButtonHoldBegan)
    if ok1 and type(conns1) == "table" then
        for _, conn in ipairs(conns1) do
            if type(conn.Function) == "function" then
                table.insert(data.holdCallbacks, conn.Function)
            end
        end
    end
    
    local ok2, conns2 = pcall(getconnections, prompt.Triggered)
    if ok2 and type(conns2) == "table" then
        for _, conn in ipairs(conns2) do
            if type(conn.Function) == "function" then
                table.insert(data.triggerCallbacks, conn.Function)
            end
        end
    end
    
    if (#data.holdCallbacks > 0) or (#data.triggerCallbacks > 0) then
        InternalStealCache[prompt] = data
    end
end

local function executeInternalStealAsync(prompt, animalData)
    local data = InternalStealCache[prompt]
    if not data or not data.ready then return false end
    
    data.ready = false
    IsStealing = true
    StealProgress = 0
    CurrentStealTarget = animalData
    StealStartTime = tick()
    
    task.spawn(function()
        if #data.holdCallbacks > 0 then
            for _, fn in ipairs(data.holdCallbacks) do
                task.spawn(fn)
            end
        end
        
        local startTime = tick()
        while tick() - startTime < 1.3 do
            StealProgress = (tick() - startTime) / 1.3
            task.wait(0.05)
        end
        StealProgress = 1
        
        if #data.triggerCallbacks > 0 then
            for _, fn in ipairs(data.triggerCallbacks) do
                task.spawn(fn)
            end
        end
        
        task.wait(0.1)
        data.ready = true
        
        task.wait(0.3)
        IsStealing = false
        StealProgress = 0
        CurrentStealTarget = nil
    end)
    
    return true
end

local function attemptSteal(prompt, animalData)
    if not prompt or not prompt.Parent then return false end
    
    buildStealCallbacks(prompt)
    if not InternalStealCache[prompt] then return false end
    
    return executeInternalStealAsync(prompt, animalData)
end

local function getNearestAnimal()
    local hrp = getHRP()
    if not hrp then return nil end
    
    local nearest = nil
    local minDist = math.huge
    
    for _, animalData in ipairs(allAnimalsCache) do
        if isMyBase(animalData.plot) then continue end
        
        if animalData.worldPosition then
            local dist = (hrp.Position - animalData.worldPosition).Magnitude
            if dist < minDist then
                minDist = dist
                nearest = animalData
            end
        end
    end
    
    return nearest
end

local function autoStealLoop()
    if stealConnection then stealConnection:Disconnect() end
    if velocityConnection then velocityConnection:Disconnect() end
    
    velocityConnection = RunService.Heartbeat:Connect(updatePlayerVelocity)
    
    stealConnection = RunService.Heartbeat:Connect(function()
        if not CONFIG.AUTO_STEAL_NEAREST then return end
        if IsStealing then return end
        
        local targetAnimal = getNearestAnimal()
        if not targetAnimal then return end
        
        if not shouldSteal(targetAnimal) then return end
        
        if LastTargetUID ~= targetAnimal.uid then
            LastTargetUID = targetAnimal.uid
        end
        
        local prompt = PromptMemoryCache[targetAnimal.uid]
        if not prompt or not prompt.Parent then
            prompt = findProximityPromptForAnimal(targetAnimal)
        end
        
        if prompt then
            attemptSteal(prompt, targetAnimal)
        end
    end)
end

-- ANTI RAGDOLL FUNCTIONS (NO SPEED BOOST)
local function cacheCharacterData()
    local char = LocalPlayer.Character
    if not char then return false end
    
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    
    if not hum or not root then return false end
    
    cachedCharData = {
        character = char,
        humanoid = hum,
        root = root
    }
    return true
end

local function disconnectAllRagdoll()
    for _, conn in ipairs(ragdollConnections) do
        pcall(function() conn:Disconnect() end)
    end
    ragdollConnections = {}
end

local function isRagdolled()
    if not cachedCharData.humanoid then return false end
    local state = cachedCharData.humanoid:GetState()
    
    local ragdollStates = {
        [Enum.HumanoidStateType.Physics] = true,
        [Enum.HumanoidStateType.Ragdoll] = true,
        [Enum.HumanoidStateType.FallingDown] = true
    }
    
    if ragdollStates[state] then return true end
    
    local endTime = LocalPlayer:GetAttribute("RagdollEndTime")
    if endTime and (endTime - workspace:GetServerTimeNow()) > 0 then
        return true
    end
    
    return false
end

local function forceExitRagdoll()
    if not cachedCharData.humanoid or not cachedCharData.root then return end
    
    pcall(function()
        LocalPlayer:SetAttribute("RagdollEndTime", workspace:GetServerTimeNow())
    end)
    
    -- Clear physics constraints locally
    for _, descendant in ipairs(cachedCharData.character:GetDescendants()) do
        if descendant:IsA("BallSocketConstraint") or (descendant:IsA("Attachment") and descendant.Name:find("RagdollAttachment")) then
            descendant:Destroy()
        end
    end
    
    -- Force state back to running
    if cachedCharData.humanoid.Health > 0 then
        cachedCharData.humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end
    
    cachedCharData.root.Anchored = false
end

local function v1HeartbeatLoop()
    while antiRagdollMode == "v1" do
        task.wait()
        
        local currentlyRagdolled = isRagdolled()
        
        if currentlyRagdolled then
            forceExitRagdoll()
        end
    end
end

local function EnableAntiRagdoll()
    if antiRagdollMode == "v1" then return end
    if not cacheCharacterData() then return end
    
    antiRagdollMode = "v1"
    
    local camConn = RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        if cam and cachedCharData.humanoid then
            cam.CameraSubject = cachedCharData.humanoid
        end
    end)
    table.insert(ragdollConnections, camConn)
    
    local respawnConn = LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        cacheCharacterData()
    end)
    table.insert(ragdollConnections, respawnConn)

    task.spawn(v1HeartbeatLoop)
end

local function DisableAntiRagdoll()
    antiRagdollMode = nil
    disconnectAllRagdoll()
    cachedCharData = {}
end

-- INVISIBILITY FUNCTIONS
local function removeFolders()
    local playerName = LocalPlayer.Name
    local playerFolder = Workspace:FindFirstChild(playerName)
    if not playerFolder then return end
    local doubleRig = playerFolder:FindFirstChild("DoubleRig")
    if doubleRig then doubleRig:Destroy() end
    local constraints = playerFolder:FindFirstChild("Constraints")
    if constraints then constraints:Destroy() end
    local childAddedConn = playerFolder.ChildAdded:Connect(function(child)
        if child.Name == "DoubleRig" or child.Name == "Constraints" then
            child:Destroy()
        end
    end)
    table.insert(connections.SemiInvisible, childAddedConn)
end

local function doClone()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") and LocalPlayer.Character.Humanoid.Health > 0 then
        hip = LocalPlayer.Character.Humanoid.HipHeight
        oldRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not oldRoot or not oldRoot.Parent then return false end
        local tempParent = Instance.new("Model")
        tempParent.Parent = game
        LocalPlayer.Character.Parent = tempParent
        clone = oldRoot:Clone()
        clone.Parent = LocalPlayer.Character
        oldRoot.Parent = game.Workspace.CurrentCamera
        clone.CFrame = oldRoot.CFrame
        LocalPlayer.Character.PrimaryPart = clone
        LocalPlayer.Character.Parent = game.Workspace
        for _, v in pairs(LocalPlayer.Character:GetDescendants()) do
            if v:IsA("Weld") or v:IsA("Motor6D") then
                if v.Part0 == oldRoot then v.Part0 = clone end
                if v.Part1 == oldRoot then v.Part1 = clone end
            end
        end
        tempParent:Destroy()
        return true
    end
    return false
end

local function revertClone()
    if not oldRoot or not oldRoot:IsDescendantOf(game.Workspace) or not LocalPlayer.Character or LocalPlayer.Character.Humanoid.Health <= 0 then
        return false
    end
    local tempParent = Instance.new("Model")
    tempParent.Parent = game
    LocalPlayer.Character.Parent = tempParent
    oldRoot.Parent = LocalPlayer.Character
    LocalPlayer.Character.PrimaryPart = oldRoot
    LocalPlayer.Character.Parent = game.Workspace
    oldRoot.CanCollide = true
    for _, v in pairs(LocalPlayer.Character:GetDescendants()) do
        if v:IsA("Weld") or v:IsA("Motor6D") then
            if v.Part0 == clone then v.Part0 = oldRoot end
            if v.Part1 == clone then v.Part1 = oldRoot end
        end
    end
    if clone then
        local oldPos = clone.CFrame
        clone:Destroy()
        clone = nil
        oldRoot.CFrame = oldPos
    end
    oldRoot = nil
    if LocalPlayer.Character and LocalPlayer.Character.Humanoid then
        LocalPlayer.Character.Humanoid.HipHeight = hip
    end
end

local function animationTrickery()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") and LocalPlayer.Character.Humanoid.Health > 0 then
        local anim = Instance.new("Animation")
        anim.AnimationId = "http://www.roblox.com/asset/?id=18537363391"
        local humanoid = LocalPlayer.Character.Humanoid
        local animator = humanoid:FindFirstChild("Animator") or Instance.new("Animator", humanoid)
        animTrack = animator:LoadAnimation(anim)
        animTrack.Priority = Enum.AnimationPriority.Action4
        animTrack:Play(0, 1, 0)
        anim:Destroy()
        local animStoppedConn = animTrack.Stopped:Connect(function()
            if isInvisible then animationTrickery() end
        end)
        table.insert(connections.SemiInvisible, animStoppedConn)
        task.delay(0, function()
            animTrack.TimePosition = 0.7
            task.delay(1, function()
                animTrack:AdjustSpeed(math.huge)
            end)
        end)
    end
end

local function enableInvisibility()
    if not LocalPlayer.Character or LocalPlayer.Character.Humanoid.Health <= 0 then
        return false
    end
    removeFolders()
    local success = doClone()
    if success then
        task.wait(0.1)
        animationTrickery()
        connection = RunService.PreSimulation:Connect(function(dt)
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") and LocalPlayer.Character.Humanoid.Health > 0 and oldRoot then
                local root = LocalPlayer.Character.PrimaryPart or LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    local cf = root.CFrame - Vector3.new(0, LocalPlayer.Character.Humanoid.HipHeight + (root.Size.Y / 2) - 1 + 0.09, 0)
                    oldRoot.CFrame = cf * CFrame.Angles(math.rad(180), 0, 0)
                    oldRoot.Velocity = root.Velocity
                    oldRoot.CanCollide = false
                end
            end
        end)
        table.insert(connections.SemiInvisible, connection)
        characterConnection = LocalPlayer.CharacterAdded:Connect(function(newChar)
            if isInvisible then
                if animTrack then
                    animTrack:Stop()
                    animTrack:Destroy()
                    animTrack = nil
                end
                if connection then connection:Disconnect() end
                revertClone()
                removeFolders()
                isInvisible = false
                for _, conn in ipairs(connections.SemiInvisible) do
                    if conn then conn:Disconnect() end
                end
                connections.SemiInvisible = {}
            end
        end)
        table.insert(connections.SemiInvisible, characterConnection)
        return true
    end
    return false
end

local function disableInvisibility()
    if animTrack then
        animTrack:Stop()
        animTrack:Destroy()
        animTrack = nil
    end
    if connection then connection:Disconnect() end
    if characterConnection then characterConnection:Disconnect() end
    revertClone()
    removeFolders()
end

local function setupGodmode()
    pcall(function()
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local hum = char:WaitForChild("Humanoid")
        local mt = getrawmetatable(game)
        local oldNC = mt.__namecall
        local oldNI = mt.__newindex
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            local m = getnamecallmethod()
            if self == hum then
                if m == "ChangeState" and select(1, ...) == Enum.HumanoidStateType.Dead then
                    return
                end
                if m == "SetStateEnabled" then
                    local st, en = ...
                    if st == Enum.HumanoidStateType.Dead and en == true then
                        return
                    end
                end
                if m == "Destroy" then
                    return
                end
            end
            if self == char and m == "BreakJoints" then
                return
            end
            return oldNC(self, ...)
        end)
        mt.__newindex = newcclosure(function(self, k, v)
            if self == hum then
                if k == "Health" and type(v) == "number" and v <= 0 then
                    return
                end
                if k == "MaxHealth" and type(v) == "number" and v < hum.MaxHealth then
                    return
                end
                if k == "BreakJointsOnDeath" and v == true then
                    return
                end
                if k == "Parent" and v == nil then
                    return
                end
            end
            return oldNI(self, k, v)
        end)
        setreadonly(mt, true)
    end)
end

-- UI CREATION
print("Creating UI...")

for _, gui in pairs(PlayerGui:GetChildren()) do
    if gui.Name == "VAEBHubUI" then gui:Destroy() end
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "VAEBHubUI"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 999999
screenGui.IgnoreGuiInset = true
screenGui.Parent = PlayerGui

-- Main Frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 200, 0, 220)
mainFrame.Position = UDim2.new(0.5, -100, 0.5, -110)
mainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 8)
mainCorner.Parent = mainFrame

local borderStroke = Instance.new("UIStroke")
borderStroke.Thickness = 2
borderStroke.Color = Color3.fromRGB(200, 30, 30)
borderStroke.Transparency = 0.3
borderStroke.Parent = mainFrame

-- Title Bar
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 25)
titleBar.Position = UDim2.new(0, 0, 0, 0)
titleBar.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = titleBar

-- Title Text
local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -60, 1, 0)
titleText.Position = UDim2.new(0, 8, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "VAEB HUB"
titleText.Font = Enum.Font.GothamBold
titleText.TextSize = 12
titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Parent = titleBar

local titleGradient = Instance.new("UIGradient")
titleGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 30, 30)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 60, 60)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 30, 30))
})
titleGradient.Parent = titleText

-- Save Button
local saveBtn = Instance.new("TextButton")
saveBtn.Name = "SaveBtn"
saveBtn.Size = UDim2.new(0, 20, 0, 20)
saveBtn.Position = UDim2.new(1, -68, 0.5, -10)
saveBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
saveBtn.BorderSizePixel = 0
saveBtn.Text = "💾"
saveBtn.Font = Enum.Font.GothamBold
saveBtn.TextSize = 12
saveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
saveBtn.Parent = titleBar

local saveCorner = Instance.new("UICorner")
saveCorner.CornerRadius = UDim.new(0, 4)
saveCorner.Parent = saveBtn

local saveStroke = Instance.new("UIStroke")
saveStroke.Thickness = 1
saveStroke.Color = Color3.fromRGB(0, 220, 0)
saveStroke.Parent = saveBtn

-- Minimize Button
local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Name = "MinimizeBtn"
minimizeBtn.Size = UDim2.new(0, 20, 0, 20)
minimizeBtn.Position = UDim2.new(1, -45, 0.5, -10)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
minimizeBtn.BorderSizePixel = 0
minimizeBtn.Text = "-"
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 14
minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeBtn.Parent = titleBar

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 4)
minCorner.Parent = minimizeBtn

local minStroke = Instance.new("UIStroke")
minStroke.Thickness = 1
minStroke.Color = Color3.fromRGB(255, 60, 60)
minStroke.Parent = minimizeBtn

-- Close Button
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0, 20, 0, 20)
closeBtn.Position = UDim2.new(1, -22, 0.5, -10)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
closeBtn.BorderSizePixel = 0
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 11
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Parent = titleBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 4)
closeCorner.Parent = closeBtn

local closeStroke = Instance.new("UIStroke")
closeStroke.Thickness = 1
closeStroke.Color = Color3.fromRGB(255, 50, 50)
closeStroke.Parent = closeBtn

-- SHOOTING STARS CONTAINER
local starsContainer = Instance.new("Frame")
starsContainer.Name = "StarsContainer"
starsContainer.Size = UDim2.new(1, 0, 1, 0)
starsContainer.Position = UDim2.new(0, 0, 0, 0)
starsContainer.BackgroundTransparency = 1
starsContainer.ClipsDescendants = true
starsContainer.Parent = mainFrame

local function createShootingStar()
    local star = Instance.new("Frame")
    star.Size = UDim2.new(0, math.random(20, 40), 0, 1.5)
    star.Position = UDim2.new(math.random(-20, 120) / 100, 0, math.random(-20, 0) / 100, 0)
    star.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    star.BorderSizePixel = 0
    star.Rotation = 45
    star.Parent = starsContainer
    
    local starGradient = Instance.new("UIGradient")
    starGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.3, 0.3),
        NumberSequenceKeypoint.new(0.7, 0.3),
        NumberSequenceKeypoint.new(1, 1)
    })
    starGradient.Rotation = 90
    starGradient.Parent = star
    
    local endPos = UDim2.new(
        star.Position.X.Scale + 0.3,
        star.Position.X.Offset,
        star.Position.Y.Scale + 0.3,
        star.Position.Y.Offset
    )
    
    local tween = TweenService:Create(
        star,
        TweenInfo.new(math.random(15, 25) / 10, Enum.EasingStyle.Linear),
        {Position = endPos, BackgroundTransparency = 1}
    )
    
    tween:Play()
    tween.Completed:Connect(function()
        star:Destroy()
    end)
end

-- MAIN CONTENT
local mainContent = Instance.new("Frame")
mainContent.Name = "MainContent"
mainContent.Size = UDim2.new(1, 0, 1, -32)
mainContent.Position = UDim2.new(0, 0, 0, 32)
mainContent.BackgroundTransparency = 1
mainContent.Visible = true
mainContent.Parent = mainFrame

-- AUTO GRAB BUTTON
local autoGrabButton = Instance.new("TextButton")
autoGrabButton.Size = UDim2.new(0, 184, 0, 32)
autoGrabButton.Position = UDim2.new(0.5, -92, 0, 8)
autoGrabButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
autoGrabButton.BorderSizePixel = 0
autoGrabButton.Text = "Auto Grab: OFF"
autoGrabButton.Font = Enum.Font.GothamBold
autoGrabButton.TextSize = 11
autoGrabButton.TextColor3 = Color3.fromRGB(200, 200, 200)
autoGrabButton.Parent = mainContent

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 6)
buttonCorner.Parent = autoGrabButton

local buttonStroke = Instance.new("UIStroke")
buttonStroke.Thickness = 1.5
buttonStroke.Color = Color3.fromRGB(100, 100, 100)
buttonStroke.Parent = autoGrabButton

-- INVIS STEAL BUTTON
local invisStealButton = Instance.new("TextButton")
invisStealButton.Size = UDim2.new(0, 184, 0, 32)
invisStealButton.Position = UDim2.new(0.5, -92, 0, 46)
invisStealButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
invisStealButton.BorderSizePixel = 0
invisStealButton.Text = "Invis Steal: OFF"
invisStealButton.Font = Enum.Font.GothamBold
invisStealButton.TextSize = 11
invisStealButton.TextColor3 = Color3.fromRGB(200, 200, 200)
invisStealButton.Parent = mainContent

local invisCorner = Instance.new("UICorner")
invisCorner.CornerRadius = UDim.new(0, 6)
invisCorner.Parent = invisStealButton

local invisStroke = Instance.new("UIStroke")
invisStroke.Thickness = 1.5
invisStroke.Color = Color3.fromRGB(100, 100, 100)
invisStroke.Parent = invisStealButton

-- ANTI RAGDOLL BUTTON
local antiRagdollButton = Instance.new("TextButton")
antiRagdollButton.Size = UDim2.new(0, 184, 0, 32)
antiRagdollButton.Position = UDim2.new(0.5, -92, 0, 84)
antiRagdollButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
antiRagdollButton.BorderSizePixel = 0
antiRagdollButton.Text = "Anti Ragdoll: OFF"
antiRagdollButton.Font = Enum.Font.GothamBold
antiRagdollButton.TextSize = 11
antiRagdollButton.TextColor3 = Color3.fromRGB(200, 200, 200)
antiRagdollButton.Parent = mainContent

local antiRagdollCorner = Instance.new("UICorner")
antiRagdollCorner.CornerRadius = UDim.new(0, 6)
antiRagdollCorner.Parent = antiRagdollButton

local antiRagdollStroke = Instance.new("UIStroke")
antiRagdollStroke.Thickness = 1.5
antiRagdollStroke.Color = Color3.fromRGB(100, 100, 100)
antiRagdollStroke.Parent = antiRagdollButton

-- RADIUS CONTROL WITH TEXT INPUT
local radiusFrame = Instance.new("Frame")
radiusFrame.Size = UDim2.new(0, 184, 0, 32)
radiusFrame.Position = UDim2.new(0.5, -92, 0, 122)
radiusFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
radiusFrame.BorderSizePixel = 0
radiusFrame.Parent = mainContent

local radiusCorner = Instance.new("UICorner")
radiusCorner.CornerRadius = UDim.new(0, 6)
radiusCorner.Parent = radiusFrame

local radiusStroke = Instance.new("UIStroke")
radiusStroke.Thickness = 1.5
radiusStroke.Color = Color3.fromRGB(80, 80, 80)
radiusStroke.Parent = radiusFrame

local radiusLabel = Instance.new("TextLabel")
radiusLabel.Size = UDim2.new(0, 50, 1, 0)
radiusLabel.Position = UDim2.new(0, 6, 0, 0)
radiusLabel.BackgroundTransparency = 1
radiusLabel.Text = "Radius:"
radiusLabel.Font = Enum.Font.GothamBold
radiusLabel.TextSize = 10
radiusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
radiusLabel.TextXAlignment = Enum.TextXAlignment.Left
radiusLabel.Parent = radiusFrame

-- TEXT INPUT BOX
local radiusInput = Instance.new("TextBox")
radiusInput.Size = UDim2.new(0, 35, 0, 22)
radiusInput.Position = UDim2.new(0, 56, 0.5, -11)
radiusInput.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
radiusInput.BorderSizePixel = 0
radiusInput.Text = tostring(AUTO_STEAL_PROX_RADIUS)
radiusInput.Font = Enum.Font.GothamBold
radiusInput.TextSize = 10
radiusInput.TextColor3 = Color3.fromRGB(255, 255, 255)
radiusInput.TextXAlignment = Enum.TextXAlignment.Center
radiusInput.PlaceholderText = "1-100"
radiusInput.ClearTextOnFocus = false
radiusInput.Parent = radiusFrame

local inputCorner = Instance.new("UICorner")
inputCorner.CornerRadius = UDim.new(0, 4)
inputCorner.Parent = radiusInput

local inputStroke = Instance.new("UIStroke")
inputStroke.Thickness = 1
inputStroke.Color = Color3.fromRGB(200, 30, 30)
inputStroke.Parent = radiusInput

-- SLIDER
local sliderBg = Instance.new("Frame")
sliderBg.Size = UDim2.new(0, 85, 0, 4)
sliderBg.Position = UDim2.new(0, 95, 0.5, -2)
sliderBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
sliderBg.BorderSizePixel = 0
sliderBg.Parent = radiusFrame

local sliderBgCorner = Instance.new("UICorner")
sliderBgCorner.CornerRadius = UDim.new(1, 0)
sliderBgCorner.Parent = sliderBg

local sliderFill = Instance.new("Frame")
sliderFill.Size = UDim2.new((AUTO_STEAL_PROX_RADIUS - 1) / 99, 0, 1, 0)
sliderFill.Position = UDim2.new(0, 0, 0, 0)
sliderFill.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
sliderFill.BorderSizePixel = 0
sliderFill.Parent = sliderBg

local sliderFillCorner = Instance.new("UICorner")
sliderFillCorner.CornerRadius = UDim.new(1, 0)
sliderFillCorner.Parent = sliderFill

-- PROGRESS BAR
local progressLabel = Instance.new("TextLabel")
progressLabel.Size = UDim2.new(1, -16, 0, 10)
progressLabel.Position = UDim2.new(0, 8, 0, 160)
progressLabel.BackgroundTransparency = 1
progressLabel.Text = "Steal Progress"
progressLabel.Font = Enum.Font.GothamBold
progressLabel.TextSize = 9
progressLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
progressLabel.Parent = mainContent

local progressFrame = Instance.new("Frame")
progressFrame.Size = UDim2.new(1, -16, 0, 10)
progressFrame.Position = UDim2.new(0, 8, 0, 173)
progressFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
progressFrame.BorderSizePixel = 0
progressFrame.Parent = mainContent

local progressCorner = Instance.new("UICorner")
progressCorner.CornerRadius = UDim.new(1, 0)
progressCorner.Parent = progressFrame

local progressStroke = Instance.new("UIStroke")
progressStroke.Thickness = 1
progressStroke.Color = Color3.fromRGB(80, 80, 80)
progressStroke.Parent = progressFrame

local progressFill = Instance.new("Frame")
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.Position = UDim2.new(0, 0, 0, 0)
progressFill.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
progressFill.BorderSizePixel = 0
progressFill.Parent = progressFrame

local progressFillCorner = Instance.new("UICorner")
progressFillCorner.CornerRadius = UDim.new(1, 0)
progressFillCorner.Parent = progressFill

local progressGradient = Instance.new("UIGradient")
progressGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 30, 30)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 60, 60)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 30, 30))
})
progressGradient.Parent = progressFill

-- Function to update radius from any source
local function updateRadiusValue(newRadius)
    newRadius = math.clamp(math.floor(newRadius), 1, 100)
    AUTO_STEAL_PROX_RADIUS = newRadius
    CIRCLE_RADIUS = newRadius
    
    radiusInput.Text = tostring(newRadius)
    local fillSize = (newRadius - 1) / 99
    sliderFill.Size = UDim2.new(fillSize, 0, 1, 0)
    
    if circleEnabled and LocalPlayer.Character then
        updateCircleRadius()
    end
end

-- BUTTON CLICK HANDLERS
autoGrabButton.MouseButton1Click:Connect(function()
    CONFIG.AUTO_STEAL_NEAREST = not CONFIG.AUTO_STEAL_NEAREST
    
    if CONFIG.AUTO_STEAL_NEAREST then
        autoGrabButton.Text = "Auto Grab: ON"
        autoGrabButton.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
        autoGrabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        buttonStroke.Color = Color3.fromRGB(255, 60, 60)
    else
        autoGrabButton.Text = "Auto Grab: OFF"
        autoGrabButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        autoGrabButton.TextColor3 = Color3.fromRGB(200, 200, 200)
        buttonStroke.Color = Color3.fromRGB(100, 100, 100)
    end
end)

invisStealButton.MouseButton1Click:Connect(function()
    isInvisible = not isInvisible
    
    if isInvisible then
        invisStealButton.Text = "Invis Steal: ON"
        invisStealButton.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
        invisStealButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        invisStroke.Color = Color3.fromRGB(255, 60, 60)
        removeFolders()
        setupGodmode()
        enableInvisibility()
    else
        invisStealButton.Text = "Invis Steal: OFF"
        invisStealButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        invisStealButton.TextColor3 = Color3.fromRGB(200, 200, 200)
        invisStroke.Color = Color3.fromRGB(100, 100, 100)
        disableInvisibility()
        for _, conn in ipairs(connections.SemiInvisible) do
            if conn then conn:Disconnect() end
        end
        connections.SemiInvisible = {}
    end
end)

antiRagdollButton.MouseButton1Click:Connect(function()
    local isEnabled = antiRagdollMode == "v1"
    
    if not isEnabled then
        antiRagdollButton.Text = "Anti Ragdoll: ON"
        antiRagdollButton.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
        antiRagdollButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        antiRagdollStroke.Color = Color3.fromRGB(255, 60, 60)
        EnableAntiRagdoll()
    else
        antiRagdollButton.Text = "Anti Ragdoll: OFF"
        antiRagdollButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        antiRagdollButton.TextColor3 = Color3.fromRGB(200, 200, 200)
        antiRagdollStroke.Color = Color3.fromRGB(100, 100, 100)
        DisableAntiRagdoll()
    end
end)

-- Save Button Handler
saveBtn.MouseButton1Click:Connect(function()
    saveSettings()
    saveBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    task.wait(0.2)
    saveBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
end)

-- Minimize/Close Functionality
local isMinimized = false
local originalSize = mainFrame.Size

minimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        mainFrame:TweenSize(UDim2.new(0, 200, 0, 25), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
        minimizeBtn.Text = "+"
    else
        mainFrame:TweenSize(originalSize, Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
        minimizeBtn.Text = "-"
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

-- Text Input Handler
radiusInput.FocusLost:Connect(function(enterPressed)
    local inputValue = tonumber(radiusInput.Text)
    if inputValue then
        updateRadiusValue(inputValue)
    else
        radiusInput.Text = tostring(AUTO_STEAL_PROX_RADIUS)
    end
end)

-- Slider Interaction
local dragging = false
local function updateSlider(input)
    local relativeX = math.clamp((input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
    local newRadius = math.floor(1 + (relativeX * 99))
    updateRadiusValue(newRadius)
end

sliderBg.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        updateSlider(input)
    end
end)

sliderBg.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        updateSlider(input)
    end
end)

-- Make UI Draggable
local draggingUI = false
local dragStart = nil
local startPos = nil

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingUI = true
        dragStart = input.Position
        startPos = mainFrame.Position
    end
end)

titleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingUI = false
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if draggingUI and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

-- Spawn shooting stars continuously
task.spawn(function()
    while task.wait(math.random(5, 15) / 10) do
        if screenGui.Parent then
            createShootingStar()
        else
            break
        end
    end
end)

-- Progress Bar Update Loop
local progressTween = nil

task.spawn(function()
    while task.wait(0.03) do
        if IsStealing then
            if progressTween then progressTween:Cancel() end
            
            progressTween = TweenService:Create(
                progressFill,
                TweenInfo.new(0.1, Enum.EasingStyle.Linear),
                { Size = UDim2.new(StealProgress, 0, 1, 0) }
            )
            progressTween:Play()
        else
            if progressTween then
                progressTween:Cancel()
                progressTween = nil
            end
            
            if progressFill.Size.X.Scale > 0 then
                progressFill.Size = UDim2.new(
                    math.max(0, progressFill.Size.X.Scale - 0.05),
                    0,
                    1,
                    0
                )
            end
        end
    end
end)

-- CIRCLE SYSTEM
local function createCircle(character)
    for _, part in ipairs(circleParts) do
        if part then part:Destroy() end
    end
    circleParts = {}

    CIRCLE_RADIUS = AUTO_STEAL_PROX_RADIUS
    local root = character:WaitForChild("HumanoidRootPart")

    local points = {}
    for i = 0, PartsCount - 1 do
        local angle = math.rad(i * 360 / PartsCount)
        table.insert(points, Vector3.new(math.cos(angle), 0, math.sin(angle)) * CIRCLE_RADIUS)
    end

    for i = 1, #points do
        local nextIndex = i % #points + 1
        local p1 = points[i]
        local p2 = points[nextIndex]

        local part = Instance.new("Part")
        part.Anchored = true
        part.CanCollide = false
        part.Size = Vector3.new((p2 - p1).Magnitude, PART_HEIGHT, PART_THICKNESS)
        part.Color = PART_COLOR
        part.Material = Enum.Material.Neon
        part.Transparency = 0.3
        part.TopSurface = Enum.SurfaceType.Smooth
        part.BottomSurface = Enum.SurfaceType.Smooth
        part.Parent = workspace
        table.insert(circleParts, part)
    end
end

local function updateCircle(character)
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local points = {}
    for i = 0, PartsCount - 1 do
        local angle = math.rad(i * 360 / PartsCount)
        table.insert(points, Vector3.new(math.cos(angle), 0, math.sin(angle)) * CIRCLE_RADIUS)
    end

    for i, part in ipairs(circleParts) do
        local nextIndex = i % #points + 1
        local p1 = points[i]
        local p2 = points[nextIndex]
        local center = (p1 + p2) / 2 + root.Position

        part.CFrame = CFrame.new(center, center + Vector3.new(p2.X - p1.X, 0, p2.Z - p1.Z))
            * CFrame.Angles(0, math.pi/2, 0)
    end
end

local function onCharacterAdded(character)
    if circleEnabled then
        createCircle(character)
        RunService:BindToRenderStep("CircleFollow", Enum.RenderPriority.Camera.Value + 1, function()
            updateCircle(character)
        end)
    end
end

local function updateCircleRadius()
    CIRCLE_RADIUS = AUTO_STEAL_PROX_RADIUS
    local character = LocalPlayer.Character
    if character and circleEnabled then
        createCircle(character)
    end
end

-- INITIALIZE EVERYTHING
print("Initializing scanner...")
initializeScanner()

print("Starting auto steal loop...")
autoStealLoop()

if LocalPlayer.Character then
    onCharacterAdded(LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

-- Load saved settings
task.wait(1)
local savedSettings = loadSettings()
if savedSettings then
    if savedSettings.stealRadius then
        updateRadiusValue(savedSettings.stealRadius)
    end
    
    if savedSettings.autoGrab then
        CONFIG.AUTO_STEAL_NEAREST = true
        autoGrabButton.Text = "Auto Grab: ON"
        autoGrabButton.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
        autoGrabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        buttonStroke.Color = Color3.fromRGB(255, 60, 60)
    end
    
    if savedSettings.invisSteal then
        task.wait(0.5)
        isInvisible = true
        invisStealButton.Text = "Invis Steal: ON"
        invisStealButton.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
        invisStealButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        invisStroke.Color = Color3.fromRGB(255, 60, 60)
        removeFolders()
        setupGodmode()
        enableInvisibility()
    end
    
    if savedSettings.antiRagdoll then
        antiRagdollButton.Text = "Anti Ragdoll: ON"
        antiRagdollButton.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
        antiRagdollButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        antiRagdollStroke.Color = Color3.fromRGB(255, 60, 60)
        EnableAntiRagdoll()
    end
end

print("VAEB HUB | BETA v3 loaded successfully!")
print("UI should now be visible on your screen!")
