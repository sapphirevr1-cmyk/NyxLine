--[[
    NyxLine — Funky Friday
    Autoplayer, anti-miss, bot detection dodge
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer

-- Get the global env
local function getEnv()
    local env = getfenv()
    if typeof(env.getgenv) == "function" and typeof(env.getgenv()) == "table" then
        return env.getgenv()
    end
    return _G
end

local env = getEnv()
local Library = env.NyxLineLibrary

if not Library then
    warn("NyxLine: Library not loaded")
    return
end

-- Settings
local Settings = {
    AutoPlay = false,
    HitDelay = 0,
    RandomDelay = false,
    DelayMin = 0,
    DelayMax = 30,
    AntiMiss = false,
    AutoDifficulty = "None",
}

-- Arrow key mapping
local ArrowKeys = {
    Left = Enum.KeyCode.Left,
    Down = Enum.KeyCode.Down,
    Up = Enum.KeyCode.Up,
    Right = Enum.KeyCode.Right,
    Space = Enum.KeyCode.Space,
}

-- Find the scrolling frame with arrows
local function getArrowFrames()
    local playerGui = Player:WaitForChild("PlayerGui")
    for _, gui in ipairs(playerGui:GetChildren()) do
        if gui:IsA("ScreenGui") then
            for _, desc in ipairs(gui:GetDescendants()) do
                if desc:IsA("Frame") and desc.Name == "GameplayFrame" then
                    return desc
                end
            end
        end
    end
    return nil
end

-- Detect arrow direction from position/name
local function getArrowDirection(arrow)
    local name = arrow.Name:lower()
    if name:find("left") then return "Left"
    elseif name:find("down") then return "Down"
    elseif name:find("up") then return "Up"
    elseif name:find("right") then return "Right"
    elseif name:find("space") then return "Space"
    end

    -- Fallback: use X position
    local pos = arrow.AbsolutePosition.X
    local screenW = workspace.CurrentCamera.ViewportSize.X
    local relative = pos / screenW
    if relative < 0.35 then return "Left"
    elseif relative < 0.45 then return "Down"
    elseif relative < 0.55 then return "Up"
    else return "Right" end
end

-- Press a key
local function pressKey(keyCode)
    VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
    task.delay(0.05, function()
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)
end

-- Hook into the game's scoring system for anti-miss
local function setupAntiMiss()
    -- Find and hook the miss handler in the remote events
    for _, remote in ipairs(ReplicatedStorage:GetDescendants()) do
        if remote:IsA("RemoteEvent") and remote.Name:lower():find("miss") then
            -- Block miss events
            local oldFire
            oldFire = hookfunction(remote.FireServer, function(self, ...)
                if Settings.AntiMiss and self == remote then
                    return
                end
                return oldFire(self, ...)
            end)
        end
    end
end

-- Main autoplayer loop
local autoplayConnection
local function startAutoplay()
    if autoplayConnection then
        autoplayConnection:Disconnect()
    end

    autoplayConnection = RunService.Heartbeat:Connect(function()
        if not Settings.AutoPlay then return end

        local gameplayFrame = getArrowFrames()
        if not gameplayFrame then return end

        for _, arrow in ipairs(gameplayFrame:GetDescendants()) do
            if arrow:IsA("ImageLabel") or arrow:IsA("Frame") then
                local hitZone = gameplayFrame:FindFirstChild("HitZone") or gameplayFrame:FindFirstChild("Receptor")
                if not hitZone then continue end

                local arrowY = arrow.AbsolutePosition.Y
                local hitY = hitZone.AbsolutePosition.Y
                local threshold = 30

                if math.abs(arrowY - hitY) <= threshold then
                    local direction = getArrowDirection(arrow)
                    local key = ArrowKeys[direction]
                    if key then
                        local delay = Settings.HitDelay
                        if Settings.RandomDelay then
                            delay = math.random(Settings.DelayMin, Settings.DelayMax)
                        end

                        if delay > 0 then
                            task.delay(delay / 1000, function()
                                pressKey(key)
                            end)
                        else
                            pressKey(key)
                        end
                    end
                end
            end
        end
    end)
end

-- Alternative: hook the note spawning system directly
local function hookNoteSystem()
    -- Look for the SongPlayer or equivalent module
    local modules = ReplicatedStorage:FindFirstChild("Modules") or ReplicatedStorage:FindFirstChild("Assets")
    if not modules then return false end

    for _, module in ipairs(modules:GetDescendants()) do
        if module:IsA("ModuleScript") then
            local success, result = pcall(require, module)
            if success and typeof(result) == "table" then
                if result.OnNoteReach or result.HitNote or result.NoteHit then
                    -- Found the note handler
                    return true
                end
            end
        end
    end
    return false
end

-- Setup Funky Friday specific hooks using remotes
local function setupRemoteHook()
    local songRemote
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
            local n = v.Name:lower()
            if n:find("note") or n:find("hit") or n:find("sing") or n:find("score") then
                songRemote = v
                break
            end
        end
    end

    if songRemote and songRemote:IsA("RemoteEvent") then
        -- Watch for incoming notes
        songRemote.OnClientEvent:Connect(function(data)
            if not Settings.AutoPlay then return end
            if typeof(data) == "table" and data.Direction then
                local key = ArrowKeys[data.Direction]
                if key then
                    local delay = Settings.HitDelay
                    if Settings.RandomDelay then
                        delay = math.random(Settings.DelayMin, Settings.DelayMax)
                    end
                    task.delay(delay / 1000, function()
                        pressKey(key)
                    end)
                end
            end
        end)
    end
end

------------------------------------------------------------------------
-- UI
------------------------------------------------------------------------

local Window = Library:CreateWindow({
    Title = "NyxLine — Funky Friday",
    Size = UDim2.new(0, 520, 0, 380),
    ToggleKey = Enum.KeyCode.RightControl,
})

-- Main tab
local mainTab = Window:CreateTab({Name = "Main", Icon = "🎵"})

mainTab:CreateSection("Autoplayer")

mainTab:CreateToggle({
    Name = "Auto Play",
    Default = false,
    Callback = function(state)
        Settings.AutoPlay = state
        if state then
            startAutoplay()
        end
        Window.Notifications:Notification({
            Text = "Auto Play " .. (state and "enabled" or "disabled"),
            Title = "NyxLine",
            Duration = 3,
        })
    end,
})

mainTab:CreateSlider({
    Name = "Hit Delay (ms)",
    Min = 0,
    Max = 100,
    Default = 0,
    Increment = 1,
    Callback = function(value)
        Settings.HitDelay = value
    end,
})

mainTab:CreateToggle({
    Name = "Random Delay",
    Default = false,
    Callback = function(state)
        Settings.RandomDelay = state
    end,
})

mainTab:CreateSlider({
    Name = "Random Min (ms)",
    Min = 0,
    Max = 50,
    Default = 0,
    Increment = 1,
    Callback = function(value)
        Settings.DelayMin = value
    end,
})

mainTab:CreateSlider({
    Name = "Random Max (ms)",
    Min = 0,
    Max = 100,
    Default = 30,
    Increment = 1,
    Callback = function(value)
        Settings.DelayMax = value
    end,
})

-- Safety tab
local safetyTab = Window:CreateTab({Name = "Safety", Icon = "🛡"})

safetyTab:CreateSection("Anti-Detection")

safetyTab:CreateToggle({
    Name = "Anti Miss",
    Default = false,
    Callback = function(state)
        Settings.AntiMiss = state
    end,
})

safetyTab:CreateDropdown({
    Name = "Auto Difficulty",
    Options = {"None", "Easy", "Medium", "Hard", "Expert", "Crazy"},
    Default = "None",
    Callback = function(selected)
        Settings.AutoDifficulty = selected
        if selected ~= "None" then
            -- Look for difficulty selector and change it
            local playerGui = Player:WaitForChild("PlayerGui")
            for _, desc in ipairs(playerGui:GetDescendants()) do
                if desc:IsA("TextButton") and desc.Text:lower() == selected:lower() then
                    pcall(function() desc:FindFirstAncestorOfClass("TextButton") end)
                    pcall(function()
                        firesignal(desc, "MouseButton1Click")
                    end)
                    break
                end
            end
        end
    end,
})

safetyTab:CreateLabel("Tip: Use 10-30ms random delay to look more human")

-- Settings tab
local settingsTab = Window:CreateTab({Name = "Settings", Icon = "⚙"})

settingsTab:CreateSection("Window")

settingsTab:CreateKeybind({
    Name = "Toggle UI",
    Default = Enum.KeyCode.RightControl,
    Callback = function() end,
})

settingsTab:CreateButton({
    Name = "Destroy UI",
    Callback = function()
        if autoplayConnection then
            autoplayConnection:Disconnect()
        end
        Window.Gui:Destroy()
    end,
})

settingsTab:CreateSection("Info")
settingsTab:CreateLabel("NyxLine v1.0 — Funky Friday")
settingsTab:CreateLabel("Game: " .. game.PlaceId)

------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------

pcall(setupAntiMiss)
pcall(setupRemoteHook)
startAutoplay()

Window.Notifications:Notification({
    Text = "NyxLine loaded for Funky Friday!\nPress RightCtrl to toggle UI",
    Title = "NyxLine",
    Duration = 5,
})
