-- Trapit's Commands
-- Works on external executors

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
local FOLLOW_DISTANCE = 3 -- Distance to maintain from target
local LINEUP_OFFSET = 3 -- Distance to stand next to controller

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

-- Function to send chat messages
local function sendChatMessage(message)
    -- Try TextChatService (new chat)
    local success, err = pcall(function()
        local textChannel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
        if textChannel then
            textChannel:SendAsync(message)
            return
        end
        -- Fallback to legacy chat
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

-- Command list for !cmds (concise, fits in one message)
local function getCommandListString()
    return "Commands: !goto, !loopgoto, !unloopgoto, !spin, !unspin, !follow, !unfollow, !float, !unfloat, !say, !lineup, !view, !unview, !sit, !stand, !refresh, !rejoin, !cmds"
end

-- GUI Creation
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TrapitsCommands"
screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
screenGui.ResetOnSpawn = false

-- Main Frame
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 350, 0, 405)
mainFrame.Position = UDim2.new(0, 10, 0.5, -202.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0) -- Pure dark black
mainFrame.BackgroundTransparency = 0.1
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
title.BackgroundTransparency = 0.5
title.Text = "Trapit's Commands"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.Parent = mainFrame

-- White to black gradient on title text
local titleGradient = Instance.new("UIGradient")
titleGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)), -- White
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))        -- Black
})
titleGradient.Rotation = 90
titleGradient.Parent = title

-- Close button (grey background)
local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -35, 0, 5)
closeButton.Text = "X"
closeButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80) -- Grey
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 14
closeButton.Parent = mainFrame

-- Minimize button (grey background)
local minimizeButton = Instance.new("TextButton")
minimizeButton.Size = UDim2.new(0, 30, 0, 30)
minimizeButton.Position = UDim2.new(1, -70, 0, 5)
minimizeButton.Text = "-"
minimizeButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80) -- Grey
minimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeButton.Font = Enum.Font.GothamBold
minimizeButton.TextSize = 14
minimizeButton.Parent = mainFrame

-- Target input section
local inputFrame = Instance.new("Frame")
inputFrame.Size = UDim2.new(1, -20, 0, 80)
inputFrame.Position = UDim2.new(0, 10, 0, 50)
inputFrame.BackgroundTransparency = 1
inputFrame.Parent = mainFrame

local usernameLabel = Instance.new("TextLabel")
usernameLabel.Size = UDim2.new(1, 0, 0, 20)
usernameLabel.Text = "Controller:"
usernameLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
usernameLabel.Font = Enum.Font.GothamBold
usernameLabel.TextSize = 14
usernameLabel.BackgroundTransparency = 1
usernameLabel.Parent = inputFrame

local usernameBox = Instance.new("TextBox")
usernameBox.Size = UDim2.new(1, -70, 0, 35)
usernameBox.Position = UDim2.new(0, 0, 0, 25)
usernameBox.PlaceholderText = "Enter username"
usernameBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
usernameBox.BorderSizePixel = 0
usernameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
usernameBox.Font = Enum.Font.Gotham
usernameBox.TextSize = 14
usernameBox.Parent = inputFrame

-- Set button (grey background)
local setButton = Instance.new("TextButton")
setButton.Size = UDim2.new(0, 60, 0, 35)
setButton.Position = UDim2.new(1, -60, 0, 25)
setButton.Text = "SET"
setButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80) -- Grey
setButton.TextColor3 = Color3.fromRGB(255, 255, 255)
setButton.Font = Enum.Font.GothamBold
setButton.TextSize = 14
setButton.Parent = inputFrame

-- Commands display
local commandsFrame = Instance.new("Frame")
commandsFrame.Size = UDim2.new(1, -20, 0, 265)
commandsFrame.Position = UDim2.new(0, 10, 0, 140)
commandsFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
commandsFrame.BackgroundTransparency = 0.2
commandsFrame.Parent = mainFrame

local commandsLabel = Instance.new("TextLabel")
commandsLabel.Size = UDim2.new(1, 0, 0, 30)
commandsLabel.Text = "Available Commands:"
commandsLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
commandsLabel.Font = Enum.Font.GothamBold
commandsLabel.TextSize = 16
commandsLabel.BackgroundTransparency = 1
commandsLabel.Parent = commandsFrame

local commandsList = Instance.new("ScrollingFrame")
commandsList.Size = UDim2.new(1, 0, 1, -40)
commandsList.Position = UDim2.new(0, 0, 0, 35)
commandsList.BackgroundTransparency = 1
commandsList.ScrollBarThickness = 6
commandsList.ScrollBarImageColor3 = Color3.fromRGB(0, 150, 255)
commandsList.Parent = commandsFrame

local commandLayout = Instance.new("UIListLayout")
commandLayout.Padding = UDim.new(0, 5)
commandLayout.Parent = commandsList

-- Command list with white text
local commands = {
    "!goto [user] - Teleport to player",
    "!loopgoto [user] - Loop teleport",
    "!unloopgoto - Stop loop teleport",
    "!spin [speed] - Spin player",
    "!unspin - Stop spinning",
    "!follow [user] - Follow player",
    "!unfollow - Stop following",
    "!float [height] - Float in air",
    "!unfloat - Stop floating",
    "!say [message] - Make player say something",
    "!lineup - Line up next to controller",
    "!cmds - List all commands in chat",
    "!view [user] - View target",
    "!unview - Reset view",
    "!sit - Make character sit",
    "!stand - Make character stand",
    "!refresh - Refresh character",
    "!rejoin - Rejoin server"
}

for _, command in ipairs(commands) do
    local cmdFrame = Instance.new("Frame")
    cmdFrame.Size = UDim2.new(1, 0, 0, 25)
    cmdFrame.BackgroundTransparency = 1
    
    local cmdLabel = Instance.new("TextLabel")
    cmdLabel.Size = UDim2.new(1, 0, 1, 0)
    cmdLabel.Text = command
    cmdLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- White text
    cmdLabel.Font = Enum.Font.Gotham
    cmdLabel.TextSize = 12
    cmdLabel.TextXAlignment = Enum.TextXAlignment.Left
    cmdLabel.BackgroundTransparency = 1
    cmdLabel.Parent = cmdFrame
    
    cmdFrame.Parent = commandsList
end

commandsList.CanvasSize = UDim2.new(0, 0, 0, #commands * 30)

-- Player finder with enhanced shorthand
local function findPlayer(username)
    if not username or username == "" then return nil end
    
    local lowerUsername = string.lower(username)
    
    -- Check for exact matches first
    for _, player in ipairs(Players:GetPlayers()) do
        if string.lower(player.Name) == lowerUsername or 
           string.lower(player.DisplayName) == lowerUsername then
            return player
        end
    end
    
    -- Check for partial matches (shorthand)
    local matches = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if string.lower(string.sub(player.Name, 1, #username)) == lowerUsername then
            table.insert(matches, player)
        elseif string.lower(string.sub(player.DisplayName, 1, #username)) == lowerUsername then
            table.insert(matches, player)
        end
    end
    
    if #matches == 1 then
        return matches[1]
    elseif #matches > 1 then
        return matches[1] -- Return first match
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

-- Teleport functions
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

-- Spin function
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

-- Follow function (follows 3 studs before target)
local function startFollowing(targetName)
    local targetPlayer = findPlayer(targetName)
    if not targetPlayer then return end
    
    states.isFollowing = true
    currentFollowTarget = targetPlayer
    
    spawn(function()
        while states.isFollowing and currentFollowTarget and humanoidRootPart do
            local targetRoot = getCharacterRoot(currentFollowTarget)
            if targetRoot then
                -- Get the direction from target to us
                local direction = (targetRoot.Position - humanoidRootPart.Position).Unit
                
                -- Calculate position 3 studs in front of target
                local targetCFrame = targetRoot.CFrame
                local targetLookVector = targetCFrame.LookVector
                local targetPosition = targetRoot.Position
                
                -- Calculate desired position (3 studs in front of target, facing the target)
                local desiredPosition = targetPosition - (targetLookVector * FOLLOW_DISTANCE)
                desiredPosition = Vector3.new(desiredPosition.X, targetPosition.Y, desiredPosition.Z)
                
                -- Calculate direction to desired position
                local toDesired = (desiredPosition - humanoidRootPart.Position)
                local distanceToDesired = toDesired.Magnitude
                
                if distanceToDesired > 0.5 then
                    -- Move towards desired position
                    local moveDirection = toDesired.Unit
                    
                    -- Face the target
                    humanoidRootPart.CFrame = CFrame.new(humanoidRootPart.Position, 
                        Vector3.new(targetPosition.X, humanoidRootPart.Position.Y, targetPosition.Z))
                    
                    -- Move towards desired position
                    if distanceToDesired > FOLLOW_DISTANCE * 1.5 then
                        -- If far away, move faster
                        humanoidRootPart.Velocity = moveDirection * FOLLOW_SPEED * 1.5
                    else
                        -- If close, move at normal speed
                        humanoidRootPart.Velocity = moveDirection * FOLLOW_SPEED
                    end
                else
                    -- Close enough to desired position, just face target and maintain position
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

-- FLOAT FUNCTION
local function startFloating(height)
    if not height then height = 10 end
    local floatHeight = tonumber(height) or 10
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

-- Lineup function
local function lineupNextToController()
    if not TARGET_USER then return end
    local controllerRoot = getCharacterRoot(TARGET_USER)
    if controllerRoot and humanoidRootPart then
        -- Calculate offset to the right of the controller (3 studs)
        local offset = controllerRoot.CFrame.RightVector * LINEUP_OFFSET
        local newPosition = controllerRoot.Position + offset
        -- Set our CFrame to face the same direction as the controller
        humanoidRootPart.CFrame = CFrame.new(newPosition, newPosition + controllerRoot.CFrame.LookVector)
        -- Optionally stop any following/spinning states to avoid conflict
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
    
    -- Movement commands
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
        
    -- Float commands
    elseif command == "!float" then
        startFloating(args[2])
        
    elseif command == "!unfloat" then
        stopFloating()
        
    -- Say command
    elseif command == "!say" then
        -- Combine all remaining arguments into a single message
        if #args >= 2 then
            local sayMessage = table.concat(args, " ", 2)
            sendChatMessage(sayMessage)
        end
        
    -- Lineup command
    elseif command == "!lineup" then
        lineupNextToController()
        
    -- Cmds command
    elseif command == "!cmds" then
        sendChatMessage(getCommandListString())
        
    -- View command
    elseif command == "!view" and args[2] then
        local target = findPlayer(args[2])
        if target and target.Character then
            Workspace.CurrentCamera.CameraSubject = target.Character.Humanoid
        end
        
    elseif command == "!unview" then
        Workspace.CurrentCamera.CameraSubject = humanoid
        
    -- Sit/Stand
    elseif command == "!sit" then
        humanoid.Sit = true
        
    elseif command == "!stand" then
        humanoid.Sit = false
        
    -- Refresh character
    elseif command == "!refresh" then
        localPlayer.Character:BreakJoints()
        
    -- Rejoin
    elseif command == "!rejoin" then
        game:GetService("TeleportService"):Teleport(game.PlaceId, localPlayer)
    end
end

-- Chat monitoring
local function setupChatListener()
    -- New TextChatService
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
    
    -- Legacy chat system
    local success, err = pcall(function()
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
    end)
end

-- GUI event handlers
setButton.MouseButton1Click:Connect(function()
    local username = usernameBox.Text
    if username and username ~= "" then
        local player = findPlayer(username)
        if player then
            TARGET_USER = player
            usernameBox.Text = player.Name
            print("Target set to:", player.Name)
            
            -- Teleport to the player
            teleportToPlayer(player.Name)
            
            -- Send greeting message with help tip
            sendChatMessage("Hello " .. player.Name .. " how may I assist you. say !cmds for help.")
        else
            usernameBox.Text = "Player not found"
            TARGET_USER = nil
        end
    end
end)

closeButton.MouseButton1Click:Connect(function()
    screenGui:Destroy()
    -- Clean up all processes
    stopSpinning()
    stopFollowing()
    stopFloating()
    states.isLoopGoto = false
end)

local isMinimized = false
minimizeButton.MouseButton1Click:Connect(function()
    if not isMinimized then
        mainFrame.Size = UDim2.new(0, 350, 0, 50)
        commandsFrame.Visible = false
        inputFrame.Visible = false
        minimizeButton.Text = "+"
    else
        mainFrame.Size = UDim2.new(0, 350, 0, 405)
        commandsFrame.Visible = true
        inputFrame.Visible = true
        minimizeButton.Text = "-"
    end
    isMinimized = not isMinimized
end)

-- Character respawn handler
localPlayer.CharacterAdded:Connect(function(newChar)
    character = newChar
    wait(1)
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    humanoid = character:WaitForChild("Humanoid")
    
    -- Reset states
    stopSpinning()
    stopFollowing()
    stopFloating()
    states.isLoopGoto = false
end)

-- Initialize
setupChatListener()
print("Trapit's Commands loaded!")
print("Set target username to allow them to control you")

-- Auto-attach to most recent target (optional)
spawn(function()
    wait(5)
    if not TARGET_USER then
        -- Auto-set to first other player
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= localPlayer then
                TARGET_USER = player
                usernameBox.Text = player.Name
                print("Auto-set target to:", player.Name)
                break
            end
        end
    end
end)
