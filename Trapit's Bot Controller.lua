-- Trapit's Commands - Cleaned Grey/Black Theme
-- Works on external executors

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Local references
local localPlayer = Players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

-- Configuration
local COMMAND_PREFIX = "!"
local TARGET_USER = nil
local FOLLOW_SPEED = 25
local SPIN_SPEED = 10
local FOLLOW_DISTANCE = 3
local LINEUP_OFFSET = 3
local FLOAT_HEIGHT = 10

-- State management
local states = {
    isSpinning = false,
    isFollowing = false,
    isLoopGoto = false,
    isFloating = false
}

local currentSpinSpeed = SPIN_SPEED
local currentFollowTarget = nil
local floatConnection = nil

-- GUI References
local screenGui, mainFrame
local usernameBox, setButton, commandsList, closeButton

-- Function to send chat messages
local function sendChatMessage(message)
    local success, err = pcall(function()
        local textChannel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
        if textChannel then
            textChannel:SendAsync(message)
            return
        end
        local sayMessageRequest = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents") and
                                 ReplicatedStorage.DefaultChatSystemChatEvents:FindFirstChild("SayMessageRequest")
        if sayMessageRequest then
            sayMessageRequest:FireServer(message, "All")
        else
            warn("Chat system not found, cannot send message.")
        end
    end)
    if not success then
        warn("Failed to send chat message:", err)
    end
end

-- Command list for !cmds
local function getCommandListString()
    return "Commands: !goto, !loopgoto, !unloopgoto, !spin, !unspin, !follow, !unfollow, !float, !unfloat, !say, !lineup, !view, !unview, !sit, !stand, !refresh, !rejoin, !cmds"
end

-- Player finder
local function findPlayer(username)
    if not username or username == "" then return nil end
    local lowerUsername = string.lower(username)
    
    for _, player in ipairs(Players:GetPlayers()) do
        if string.lower(player.Name) == lowerUsername or 
           string.lower(player.DisplayName) == lowerUsername then
            return player
        end
    end
    
    -- Partial match
    for _, player in ipairs(Players:GetPlayers()) do
        if string.lower(string.sub(player.Name, 1, #username)) == lowerUsername then
            return player
        elseif string.lower(string.sub(player.DisplayName, 1, #username)) == lowerUsername then
            return player
        end
    end
    return nil
end

-- Character root getter
local function getCharacterRoot(player)
    if player and player.Character then
        return player.Character:FindFirstChild("HumanoidRootPart")
    end
    return nil
end

-- Teleport
local function teleportToPlayer(targetName)
    local targetPlayer = findPlayer(targetName)
    if targetPlayer then
        local targetRoot = getCharacterRoot(targetPlayer)
        if targetRoot and humanoidRootPart then
            humanoidRootPart.CFrame = targetRoot.CFrame
            return true
        end
    end
    return false
end

-- Spin
local function startSpinning(speed)
    if not speed then speed = SPIN_SPEED end
    currentSpinSpeed = tonumber(speed) or SPIN_SPEED
    states.isSpinning = true
    
    spawn(function()
        while states.isSpinning and humanoidRootPart do
            humanoidRootPart.CFrame = humanoidRootPart.CFrame * CFrame.Angles(0, math.rad(currentSpinSpeed), 0)
            RunService.Heartbeat:Wait()
        end
    end)
end

local function stopSpinning()
    states.isSpinning = false
end

-- Follow
local function startFollowing(targetName)
    local targetPlayer = findPlayer(targetName)
    if not targetPlayer then return end
    
    states.isFollowing = true
    currentFollowTarget = targetPlayer
    
    spawn(function()
        while states.isFollowing and currentFollowTarget and humanoidRootPart do
            local targetRoot = getCharacterRoot(currentFollowTarget)
            if targetRoot then
                local targetPosition = targetRoot.Position
                local targetLookVector = targetRoot.CFrame.LookVector
                local desiredPosition = targetPosition - (targetLookVector * FOLLOW_DISTANCE)
                desiredPosition = Vector3.new(desiredPosition.X, targetPosition.Y, desiredPosition.Z)
                
                local toDesired = (desiredPosition - humanoidRootPart.Position)
                local distanceToDesired = toDesired.Magnitude
                
                if distanceToDesired > 0.5 then
                    local moveDirection = toDesired.Unit
                    humanoidRootPart.CFrame = CFrame.new(humanoidRootPart.Position, 
                        Vector3.new(targetPosition.X, humanoidRootPart.Position.Y, targetPosition.Z))
                    
                    if distanceToDesired > FOLLOW_DISTANCE * 1.5 then
                        humanoidRootPart.Velocity = moveDirection * FOLLOW_SPEED * 1.5
                    else
                        humanoidRootPart.Velocity = moveDirection * FOLLOW_SPEED
                    end
                else
                    humanoidRootPart.CFrame = CFrame.new(humanoidRootPart.Position, 
                        Vector3.new(targetPosition.X, humanoidRootPart.Position.Y, targetPosition.Z))
                    humanoidRootPart.Velocity = Vector3.new(0, 0, 0)
                end
            end
            RunService.Heartbeat:Wait()
        end
        
        if humanoidRootPart then
            humanoidRootPart.Velocity = Vector3.new(0, 0, 0)
        end
    end)
end

local function stopFollowing()
    states.isFollowing = false
    currentFollowTarget = nil
end

-- Float
local function startFloating(height)
    if not height then height = FLOAT_HEIGHT end
    local floatHeight = tonumber(height) or FLOAT_HEIGHT
    states.isFloating = true
    
    if floatConnection then
        floatConnection:Disconnect()
    end
    
    floatConnection = RunService.Heartbeat:Connect(function()
        if not humanoidRootPart or not states.isFloating then 
            floatConnection:Disconnect()
            return 
        end
        
        local ray = Ray.new(humanoidRootPart.Position + Vector3.new(0, 3, 0), Vector3.new(0, -50, 0))
        local hit, position = Workspace:FindPartOnRay(ray, character)
        
        if hit then
            local distance = (position - humanoidRootPart.Position).Magnitude
            if distance < floatHeight then
                humanoidRootPart.Velocity = Vector3.new(humanoidRootPart.Velocity.X, floatHeight * 2, humanoidRootPart.Velocity.Z)
            else
                humanoidRootPart.Velocity = Vector3.new(humanoidRootPart.Velocity.X, 0, humanoidRootPart.Velocity.Z)
            end
        end
    end)
end

local function stopFloating()
    states.isFloating = false
    if floatConnection then
        floatConnection:Disconnect()
        floatConnection = nil
    end
    if humanoidRootPart then
        humanoidRootPart.Velocity = Vector3.new(humanoidRootPart.Velocity.X, 0, humanoidRootPart.Velocity.Z)
    end
end

-- Lineup
local function lineupNextToController()
    if not TARGET_USER then return end
    local controllerRoot = getCharacterRoot(TARGET_USER)
    if controllerRoot and humanoidRootPart then
        local offset = controllerRoot.CFrame.RightVector * LINEUP_OFFSET
        local newPosition = controllerRoot.Position + offset
        humanoidRootPart.CFrame = CFrame.new(newPosition, newPosition + controllerRoot.CFrame.LookVector)
        stopFollowing()
        stopSpinning()
        stopFloating()
        states.isLoopGoto = false
    end
end

-- Command parser
local function parseCommand(message)
    if not TARGET_USER then return end
    
    local args = {}
    for arg in message:gmatch("%S+") do
        table.insert(args, arg)
    end
    
    if #args == 0 then return end
    
    local command = string.lower(args[1])
    
    if command == "!goto" and args[2] then
        teleportToPlayer(args[2])
    elseif command == "!loopgoto" and args[2] then
        states.isLoopGoto = true
        spawn(function()
            while states.isLoopGoto do
                teleportToPlayer(args[2])
                wait(0.05)
            end
        end)
    elseif command == "!unloopgoto" then
        states.isLoopGoto = false
    elseif command == "!spin" then
        startSpinning(args[2])
    elseif command == "!unspin" then
        stopSpinning()
    elseif command == "!follow" and args[2] then
        startFollowing(args[2])
    elseif command == "!unfollow" then
        stopFollowing()
    elseif command == "!float" then
        startFloating(args[2])
    elseif command == "!unfloat" then
        stopFloating()
    elseif command == "!say" and #args >= 2 then
        local sayMessage = table.concat(args, " ", 2)
        sendChatMessage(sayMessage)
    elseif command == "!lineup" then
        lineupNextToController()
    elseif command == "!cmds" then
        sendChatMessage(getCommandListString())
    elseif command == "!view" and args[2] then
        local target = findPlayer(args[2])
        if target and target.Character then
            Workspace.CurrentCamera.CameraSubject = target.Character.Humanoid
        end
    elseif command == "!unview" then
        Workspace.CurrentCamera.CameraSubject = humanoid
    elseif command == "!sit" then
        humanoid.Sit = true
    elseif command == "!stand" then
        humanoid.Sit = false
    elseif command == "!refresh" then
        localPlayer.Character:BreakJoints()
    elseif command == "!rejoin" then
        game:GetService("TeleportService"):Teleport(game.PlaceId, localPlayer)
    end
end

-- Chat listener
local function setupChatListener()
    if TextChatService then
        local channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral") or
                       TextChatService.TextChannels:FindFirstChild("TextChatChannel")
        if channel then
            channel.OnIncomingMessage = function(message)
                local speaker = message.TextSource
                if speaker then
                    local player = Players:GetPlayerByUserId(speaker.UserId)
                    if player and player == TARGET_USER then
                        parseCommand(message.Text)
                    end
                end
            end
        end
    end
    
    local chatEvents = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
    if chatEvents then
        local onMessageDone = chatEvents:FindFirstChild("OnMessageDoneFiltering")
        if onMessageDone then
            onMessageDone.OnClientEvent:Connect(function(messageData)
                local player = Players:GetPlayerByUserId(messageData.FromUserId)
                if player and player == TARGET_USER then
                    parseCommand(messageData.Message)
                end
            end)
        end
    end
end

-- GUI Creation (Cleaned)
local function createGUI()
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "TrapitsCommands"
    screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Main Frame
    mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 380, 0, 360) -- Reduced height after removing status bar
    mainFrame.Position = UDim2.new(0, 20, 0.5, -180)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui

    -- Corner
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame

    -- Stroke
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(80, 80, 80)
    stroke.Thickness = 1
    stroke.Transparency = 0.3
    stroke.Parent = mainFrame

    -- Gradient
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 40, 40)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 10))
    })
    gradient.Rotation = 90
    gradient.Parent = mainFrame

    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundTransparency = 1
    titleBar.Parent = mainFrame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0, 200, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Trapit's Commands"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

    -- White to black gradient on title
    local titleGradient = Instance.new("UIGradient")
    titleGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)), -- White
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))        -- Black
    })
    titleGradient.Rotation = 90
    titleGradient.Parent = title

    -- Close Button (X)
    closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -40, 0.5, -15)
    closeButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextSize = 16
    closeButton.Parent = titleBar

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = closeButton

    -- Hover effect
    closeButton.MouseEnter:Connect(function()
        TweenService:Create(closeButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(100,100,100)}):Play()
    end)
    closeButton.MouseLeave:Connect(function()
        TweenService:Create(closeButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(60,60,60)}):Play()
    end)

    -- Input Section (directly below title, no status bar)
    local inputSection = Instance.new("Frame")
    inputSection.Size = UDim2.new(1, -20, 0, 80)
    inputSection.Position = UDim2.new(0, 10, 0, 50)
    inputSection.BackgroundTransparency = 1
    inputSection.Parent = mainFrame

    local usernameLabel = Instance.new("TextLabel")
    usernameLabel.Size = UDim2.new(1, 0, 0, 20)
    usernameLabel.Text = "Controller:"
    usernameLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    usernameLabel.Font = Enum.Font.GothamBold
    usernameLabel.TextSize = 14
    usernameLabel.BackgroundTransparency = 1
    usernameLabel.Parent = inputSection

    usernameBox = Instance.new("TextBox")
    usernameBox.Size = UDim2.new(1, -70, 0, 35)
    usernameBox.Position = UDim2.new(0, 0, 0, 25)
    usernameBox.PlaceholderText = "Enter username"
    usernameBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    usernameBox.BorderSizePixel = 0
    usernameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    usernameBox.Font = Enum.Font.Gotham
    usernameBox.TextSize = 14
    usernameBox.Parent = inputSection

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 4)
    boxCorner.Parent = usernameBox

    setButton = Instance.new("TextButton")
    setButton.Size = UDim2.new(0, 60, 0, 35)
    setButton.Position = UDim2.new(1, -60, 0, 25)
    setButton.Text = "SET"
    setButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    setButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    setButton.Font = Enum.Font.GothamBold
    setButton.TextSize = 14
    setButton.Parent = inputSection

    local setCorner = Instance.new("UICorner")
    setCorner.CornerRadius = UDim.new(0, 4)
    setCorner.Parent = setButton

    setButton.MouseEnter:Connect(function()
        TweenService:Create(setButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(120,120,120)}):Play()
    end)
    setButton.MouseLeave:Connect(function()
        TweenService:Create(setButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(80,80,80)}):Play()
    end)

    -- Commands Frame (now positioned directly after input)
    local commandsFrame = Instance.new("Frame")
    commandsFrame.Size = UDim2.new(1, -20, 0, 210)
    commandsFrame.Position = UDim2.new(0, 10, 0, 140)
    commandsFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    commandsFrame.Parent = mainFrame

    local commandsCorner = Instance.new("UICorner")
    commandsCorner.CornerRadius = UDim.new(0, 6)
    commandsCorner.Parent = commandsFrame

    -- Search Box
    local searchBox = Instance.new("TextBox")
    searchBox.Size = UDim2.new(1, -20, 0, 25)
    searchBox.Position = UDim2.new(0, 10, 0, 5)
    searchBox.PlaceholderText = "Search commands..."
    searchBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    searchBox.BorderSizePixel = 0
    searchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextSize = 12
    searchBox.Parent = commandsFrame

    local searchCorner = Instance.new("UICorner")
    searchCorner.CornerRadius = UDim.new(0, 4)
    searchCorner.Parent = searchBox

    -- Commands List
    commandsList = Instance.new("ScrollingFrame")
    commandsList.Size = UDim2.new(1, -20, 1, -40)
    commandsList.Position = UDim2.new(0, 10, 0, 35)
    commandsList.BackgroundTransparency = 1
    commandsList.ScrollBarThickness = 4
    commandsList.ScrollBarImageColor3 = Color3.fromRGB(120, 120, 120)
    commandsList.Parent = commandsFrame

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 5)
    listLayout.Parent = commandsList

    -- Commands Data
    local commandsData = {
        {name="!goto [user]", desc="Teleport to player"},
        {name="!loopgoto [user]", desc="Loop teleport"},
        {name="!unloopgoto", desc="Stop loop"},
        {name="!spin [speed]", desc="Spin"},
        {name="!unspin", desc="Stop spin"},
        {name="!follow [user]", desc="Follow player"},
        {name="!unfollow", desc="Stop follow"},
        {name="!float [height]", desc="Float"},
        {name="!unfloat", desc="Stop float"},
        {name="!say [msg]", desc="Say something"},
        {name="!lineup", desc="Line up next to controller"},
        {name="!cmds", desc="List commands in chat"},
        {name="!view [user]", desc="View target"},
        {name="!unview", desc="Reset view"},
        {name="!sit", desc="Sit"},
        {name="!stand", desc="Stand"},
        {name="!refresh", desc="Refresh character"},
        {name="!rejoin", desc="Rejoin server"}
    }

    local commandFrames = {}
    for _, cmd in ipairs(commandsData) do
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 25)
        frame.BackgroundTransparency = 0.9
        frame.BackgroundColor3 = Color3.fromRGB(255,255,255)
        frame.Parent = commandsList

        local frameCorner = Instance.new("UICorner")
        frameCorner.CornerRadius = UDim.new(0, 3)
        frameCorner.Parent = frame

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(0, 140, 1, 0)
        nameLabel.Position = UDim2.new(0, 5, 0, 0)
        nameLabel.Text = cmd.name
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 11
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = frame

        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(1, -150, 1, 0)
        descLabel.Position = UDim2.new(0, 145, 0, 0)
        descLabel.Text = cmd.desc
        descLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        descLabel.BackgroundTransparency = 1
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextSize = 11
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.Parent = frame

        table.insert(commandFrames, {frame=frame, name=cmd.name})
    end

    commandsList.CanvasSize = UDim2.new(0, 0, 0, #commandsData * 30)

    -- Search functionality
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local query = string.lower(searchBox.Text)
        local visibleCount = 0
        for i, data in ipairs(commandFrames) do
            local cmdText = string.lower(data.name)
            local visible = query == "" or string.find(cmdText, query, 1, true)
            data.frame.Visible = visible
            if visible then visibleCount = visibleCount + 1 end
        end
        commandsList.CanvasSize = UDim2.new(0, 0, 0, visibleCount * 30)
    end)
end

-- GUI Event Handlers
local function setupGUIEvents()
    setButton.MouseButton1Click:Connect(function()
        local username = usernameBox.Text
        if username and username ~= "" then
            local player = findPlayer(username)
            if player then
                TARGET_USER = player
                usernameBox.Text = player.Name
                teleportToPlayer(player.Name)
                sendChatMessage("Hello " .. player.Name .. " how may I assist you. say !cmds for help.")
            else
                usernameBox.Text = "Player not found"
                TARGET_USER = nil
            end
        end
    end)

    closeButton.MouseButton1Click:Connect(function()
        stopSpinning()
        stopFollowing()
        stopFloating()
        states.isLoopGoto = false
        screenGui:Destroy()
    end)
end

-- Character respawn handler
localPlayer.CharacterAdded:Connect(function(newChar)
    character = newChar
    wait(1)
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    humanoid = character:WaitForChild("Humanoid")
    stopSpinning()
    stopFollowing()
    stopFloating()
    states.isLoopGoto = false
end)

-- Initialize
createGUI()
setupGUIEvents()
setupChatListener()

print("Trapit's Commands - Cleaned loaded!")
print("Set target username to allow them to control you")

-- Auto-set target
spawn(function()
    wait(5)
    if not TARGET_USER then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= localPlayer then
                TARGET_USER = player
                usernameBox.Text = player.Name
                break
            end
        end
    end
end)
