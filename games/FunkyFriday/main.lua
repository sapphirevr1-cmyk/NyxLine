--[[
    NyxLine — Funky Friday
    Autoplayer via framework hook
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local function getEnv()
    local ok, env = pcall(function()
        if typeof(getfenv().getgenv) == "function" then
            return getfenv().getgenv()
        end
    end)
    return (ok and env) or _G
end

local env = getEnv()
local Library = env.NyxLineLibrary

if not Library then
    warn("[NyxLine FF] Library not loaded")
    return
end

-- Settings
local Settings = {
    AutoPlay = false,
    HitDelay = 0,
    RandomDelay = false,
    DelayMin = 0,
    DelayMax = 30,
}

-- Key mappings for each lane
local DefaultKeys = {
    [1] = Enum.KeyCode.Left,   -- or D
    [2] = Enum.KeyCode.Down,   -- or F
    [3] = Enum.KeyCode.Up,     -- or J
    [4] = Enum.KeyCode.Right,  -- or K
}

local function pressKey(keyCode)
    VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
    task.delay(0.05, function()
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)
end

------------------------------------------------------------------------
-- Framework Hook Approach
-- Funky Friday stores its song/arrow data in modules.
-- We find and hook the scoring system directly.
------------------------------------------------------------------------

local Framework = nil
local Arrows = nil

-- Search for the game's core modules
local function findFramework()
    -- Look for common module patterns in Funky Friday
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("ModuleScript") then
            local ok, mod = pcall(require, obj)
            if ok and typeof(mod) == "table" then
                -- Check for arrow/note related properties
                if mod.Arrows or mod.NoteSpeed or mod.SongData or mod.Score then
                    print("[NyxLine FF] Found framework module: " .. obj:GetFullName())
                    Framework = mod
                    return true
                end
            end
        end
    end
    return false
end

------------------------------------------------------------------------
-- UI Scanning Approach (fallback)
-- Find arrow elements in PlayerGui by scanning the actual UI tree
------------------------------------------------------------------------

local Receptors = {}
local ArrowContainer = nil
local ScanConnection = nil

local function findGameUI()
    -- Scan all ScreenGuis for the gameplay elements
    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Name ~= "NyxLine" then
            for _, desc in ipairs(gui:GetDescendants()) do
                local name = desc.Name:lower()
                -- Find the receptor/hit zone
                if (name:find("receptor") or name:find("hitzone") or name:find("hit_zone") or name:find("strum")) and desc:IsA("GuiObject") then
                    print("[NyxLine FF] Found receptor: " .. desc:GetFullName())
                    table.insert(Receptors, desc)
                end
                -- Find arrow/note container
                if (name:find("arrow") or name:find("note") or name:find("lane")) and desc:IsA("Frame") then
                    if not ArrowContainer or desc.AbsoluteSize.Y > ArrowContainer.AbsoluteSize.Y then
                        ArrowContainer = desc
                    end
                end
            end
        end
    end

    if #Receptors > 0 then
        print("[NyxLine FF] Found " .. #Receptors .. " receptors")
        return true
    end
    return false
end

-- Determine which lane an arrow belongs to based on X position
local function getLane(arrow, laneCount)
    if not arrow or not arrow.Parent then return nil end
    local parent = arrow.Parent
    while parent and not parent:IsA("ScreenGui") do
        if parent:IsA("Frame") then
            local siblings = {}
            for _, child in ipairs(parent:GetChildren()) do
                if child:IsA("Frame") or child:IsA("ImageLabel") then
                    table.insert(siblings, child)
                end
            end
            if #siblings >= 2 then
                table.sort(siblings, function(a, b)
                    return a.AbsolutePosition.X < b.AbsolutePosition.X
                end)
                for i, sib in ipairs(siblings) do
                    if sib == arrow then return math.min(i, 4) end
                end
            end
        end
        parent = parent.Parent
    end
    -- Fallback: use X position ratio
    local screenW = workspace.CurrentCamera.ViewportSize.X
    local relX = arrow.AbsolutePosition.X / screenW
    if relX < 0.35 then return 1
    elseif relX < 0.45 then return 2
    elseif relX < 0.55 then return 3
    else return 4 end
end

------------------------------------------------------------------------
-- Main Autoplayer Loop
------------------------------------------------------------------------

local hitArrows = {} -- track arrows we already hit

local function startAutoplay()
    if ScanConnection then ScanConnection:Disconnect() end

    ScanConnection = RunService.Heartbeat:Connect(function()
        if not Settings.AutoPlay then return end

        -- Scan PlayerGui for active arrows near receptors
        for _, gui in ipairs(PlayerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Name ~= "NyxLine" then
                for _, desc in ipairs(gui:GetDescendants()) do
                    if (desc:IsA("ImageLabel") or desc:IsA("ImageButton") or desc:IsA("Frame")) and desc.Visible then
                        local name = desc.Name:lower()
                        -- Skip non-arrow elements
                        if name:find("receptor") or name:find("strum") or name:find("bg") or name:find("background") then
                            continue
                        end

                        -- Check if this looks like an arrow (has image or specific size)
                        local isArrow = false
                        if desc:IsA("ImageLabel") or desc:IsA("ImageButton") then
                            if desc.Image ~= "" and desc.AbsoluteSize.X > 20 and desc.AbsoluteSize.X < 200 then
                                isArrow = true
                            end
                        end

                        if isArrow and not hitArrows[desc] then
                            -- Check against each receptor
                            for _, receptor in ipairs(Receptors) do
                                local arrowY = desc.AbsolutePosition.Y + desc.AbsoluteSize.Y / 2
                                local receptorY = receptor.AbsolutePosition.Y + receptor.AbsoluteSize.Y / 2
                                local threshold = receptor.AbsoluteSize.Y * 0.8

                                if math.abs(arrowY - receptorY) <= threshold then
                                    -- Check X alignment (same lane)
                                    local arrowCenterX = desc.AbsolutePosition.X + desc.AbsoluteSize.X / 2
                                    local receptorCenterX = receptor.AbsolutePosition.X + receptor.AbsoluteSize.X / 2

                                    if math.abs(arrowCenterX - receptorCenterX) < receptor.AbsoluteSize.X then
                                        hitArrows[desc] = true
                                        local lane = getLane(receptor, 4)
                                        local key = DefaultKeys[lane] or Enum.KeyCode.Space

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
                    end
                end
            end
        end

        -- Clean up destroyed arrows from tracking
        for arrow in pairs(hitArrows) do
            if not arrow.Parent then
                hitArrows[arrow] = nil
            end
        end
    end)
end

------------------------------------------------------------------------
-- Alternative: Direct input simulation based on game events
------------------------------------------------------------------------

local function setupEventHook()
    -- Listen for new arrows being added to the UI
    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Name ~= "NyxLine" then
            gui.DescendantAdded:Connect(function(desc)
                if not Settings.AutoPlay then return end
                if not (desc:IsA("ImageLabel") or desc:IsA("ImageButton")) then return end
                if desc.Image == "" then return end

                -- Watch this arrow's position
                local watching = true
                local conn
                conn = RunService.Heartbeat:Connect(function()
                    if not watching or not desc.Parent then
                        if conn then conn:Disconnect() end
                        return
                    end

                    for _, receptor in ipairs(Receptors) do
                        local arrowY = desc.AbsolutePosition.Y + desc.AbsoluteSize.Y / 2
                        local receptorY = receptor.AbsolutePosition.Y + receptor.AbsoluteSize.Y / 2
                        local arrowX = desc.AbsolutePosition.X + desc.AbsoluteSize.X / 2
                        local receptorX = receptor.AbsolutePosition.X + receptor.AbsoluteSize.X / 2

                        if math.abs(arrowX - receptorX) < receptor.AbsoluteSize.X and math.abs(arrowY - receptorY) <= receptor.AbsoluteSize.Y * 0.6 then
                            watching = false
                            if conn then conn:Disconnect() end

                            local lane = getLane(receptor, 4)
                            local key = DefaultKeys[lane] or Enum.KeyCode.Space

                            local delay = Settings.HitDelay
                            if Settings.RandomDelay then
                                delay = math.random(Settings.DelayMin, Settings.DelayMax)
                            end

                            task.delay(delay / 1000, function()
                                pressKey(key)
                            end)
                            break
                        end
                    end
                end)
            end)
        end
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

local mainTab = Window:CreateTab({Name = "Main", Icon = "🎵"})

mainTab:CreateSection("Autoplayer")

mainTab:CreateToggle({
    Name = "Auto Play",
    Default = false,
    Callback = function(state)
        Settings.AutoPlay = state
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

mainTab:CreateButton({
    Name = "Rescan UI",
    Callback = function()
        Receptors = {}
        ArrowContainer = nil
        findGameUI()
        Window.Notifications:Notification({
            Text = "Rescanned! Found " .. #Receptors .. " receptors",
            Title = "NyxLine",
            Duration = 3,
        })
    end,
})

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
        if ScanConnection then ScanConnection:Disconnect() end
        Window.Gui:Destroy()
    end,
})

settingsTab:CreateSection("Info")
settingsTab:CreateLabel("NyxLine v1.0 — Funky Friday")
settingsTab:CreateLabel("PlaceId: " .. tostring(game.PlaceId))

------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------

print("[NyxLine FF] Initializing...")
pcall(findFramework)

-- Wait a moment for game UI to fully load
task.wait(2)
findGameUI()
print("[NyxLine FF] Receptors found: " .. #Receptors)

-- Continuously watch for UI changes (new songs load new UI)
PlayerGui.DescendantAdded:Connect(function(desc)
    if desc:IsA("Frame") or desc:IsA("ImageLabel") then
        local name = desc.Name:lower()
        if name:find("receptor") or name:find("strum") or name:find("hitzone") then
            task.wait(0.5)
            Receptors = {}
            findGameUI()
            print("[NyxLine FF] UI changed, rescanned: " .. #Receptors .. " receptors")
        end
    end
end)

startAutoplay()
setupEventHook()

Window.Notifications:Notification({
    Text = "NyxLine loaded!\nReceptors: " .. #Receptors .. "\nPress RightCtrl to toggle UI",
    Title = "NyxLine",
    Duration = 5,
})

print("[NyxLine FF] Ready! Receptors: " .. #Receptors)
