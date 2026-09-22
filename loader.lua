-- NyxLine Loader

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local BASE_URL = "https://raw.githubusercontent.com/sapphirevr1-cmyk/NyxLine/main/"
local WEBHOOK_URL = "https://discord.com/api/webhooks/1551797073530327073/IXdOZ7l1GBgkS80S8wqvxaEk03YmhD6bmrvCKjyTNK6-3F17CVZxVZHMGqnhL6YuybEf"

-- Environment
local function getEnv()
    local success, env = pcall(function()
        if typeof(getfenv().getgenv) == "function" then
            return getfenv().getgenv()
        end
    end)
    return (success and env) or _G
end

local env = getEnv()

-- HTTP fetch with retry limit
local function httpGet(url, retries)
    retries = retries or 3
    for i = 1, retries do
        local ok, result = pcall(function()
            return game:HttpGet(url .. "?_=" .. tostring(tick()), true)
        end)
        if ok and result and result ~= "" and #result > 2 then
            return result
        end
        warn("[NyxLine] HTTP attempt " .. i .. "/" .. retries .. " failed for: " .. url)
        if not ok then warn("[NyxLine] Error: " .. tostring(result)) end
        task.wait(1)
    end
    return nil
end

-- Load and execute remote script
local function httpLoad(url, ...)
    local source = httpGet(url)
    if not source then
        warn("[NyxLine] Failed to fetch: " .. url)
        return nil
    end
    local fn, err = loadstring(source)
    if not fn then
        warn("[NyxLine] Failed to parse: " .. url .. " | " .. tostring(err))
        return nil
    end
    local ok, result = pcall(fn, ...)
    if not ok then
        warn("[NyxLine] Failed to execute: " .. url .. " | " .. tostring(result))
        return nil
    end
    return result
end

-- Error reporting via Discord webhook
local function reportError(errorMsg, detail)
    pcall(function()
        if not getfenv().request then return end
        local UIS = game:GetService("UserInputService")
        getfenv().request({
            Url = WEBHOOK_URL,
            Method = "POST",
            Body = HttpService:JSONEncode({
                embeds = {{
                    title = "NyxLine Error Report",
                    color = 14495300,
                    fields = {
                        {name = "Error", value = tostring(errorMsg), inline = false},
                        {name = "Detail", value = tostring(detail):sub(1, 500), inline = false},
                        {name = "User", value = tostring(LocalPlayer.Name) .. " (" .. tostring(LocalPlayer.UserId) .. ")", inline = true},
                        {name = "Game", value = tostring(env.GameName or "Unknown"), inline = true},
                        {name = "PlaceId", value = tostring(game.PlaceId), inline = true},
                        {name = "JobId", value = tostring(game.JobId):sub(1, 20), inline = true},
                        {name = "Players", value = tostring(#Players:GetPlayers()) .. "/" .. tostring(Players.MaxPlayers), inline = true},
                        {name = "Platform", value = (UIS.KeyboardEnabled and not UIS.TouchEnabled and "Desktop") or "Mobile", inline = true},
                        {name = "Executor", value = (getfenv().identifyexecutor and getfenv().identifyexecutor()) or "Unknown", inline = true},
                    },
                }},
            }),
            Headers = {["Content-Type"] = "application/json"},
        })
    end)
end

-- Double-load guard
if env.NyxLineLoaded then
    warn("[NyxLine] Already loaded this session")
    return
end
env.NyxLineLoaded = true

print("[NyxLine] Loading...")

-- Load UI library
local Library = httpLoad(BASE_URL .. "library.lua")
if not Library then
    env.NyxLineLoaded = false
    warn("[NyxLine] FATAL: Library failed to load!")
    reportError("Library failed to load", "httpLoad returned nil")
    return
end

env.NyxLineLibrary = Library
print("[NyxLine] Library loaded")

local function notify(text, duration)
    pcall(function()
        Library.Notifications:Notification({
            Text = text,
            Title = "NyxLine",
            Duration = duration or 5,
        })
    end)
end

notify("NyxLine initialization begun!\nDoing some base checks & getting data...")

-- Fetch player data
local rawPlayerData = httpGet(BASE_URL .. "playerdata.json")
if rawPlayerData then
    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(rawPlayerData)
    end)
    if ok and decoded then
        env.PersonalPlayerData = decoded
        local myData = decoded[tostring(LocalPlayer.UserId)]
        if myData then
            if myData.Admin then
                notify("Ooh, you're an admin, cool!")
            elseif myData.Ban and myData.Ban[1] then
                local remaining = myData.Ban[1] - os.time()
                if remaining > 0 then
                    local reason = myData.Ban[2] or "No reason provided."
                    local d = math.floor(remaining / 86400)
                    local h = math.floor((remaining % 86400) / 3600)
                    local m = math.floor((remaining % 3600) / 60)
                    local s = remaining % 60
                    notify("You are banned from NyxLine for " .. d .. "D " .. h .. "H " .. m .. "M " .. s .. "S\n" .. reason, 30)
                    return
                end
            end
        end
    end
else
    warn("[NyxLine] Could not fetch player data (non-fatal)")
end

-- Fetch game config
local rawGameConfig = httpGet(BASE_URL .. "games.json")
if not rawGameConfig then
    notify("Failed to load: Could not fetch game config")
    reportError("Could not fetch game config", "httpGet returned nil")
    return
end

local configOk, gameConfig = pcall(function()
    return HttpService:JSONDecode(rawGameConfig)
end)

if not configOk or not gameConfig then
    notify("Failed to load: Could not parse game config")
    warn("[NyxLine] Game config parse error: " .. tostring(gameConfig))
    reportError("Could not parse game config", tostring(gameConfig))
    return
end

if not gameConfig.Works then
    notify("Failed to load:\nThe script is currently down!" .. ((typeof(gameConfig.Works) == "string" and ("\n" .. gameConfig.Works)) or ""))
    return
end

-- Find matching game
notify("Checks passed! Loading game script...")
print("[NyxLine] Searching for game with PlaceId: " .. tostring(game.PlaceId))

for gameName, gameData in pairs(gameConfig) do
    if typeof(gameData) == "table" then
        -- Check if current PlaceId is in the game's PlaceId list
        local found = false
        for i, v in ipairs(gameData) do
            if v == game.PlaceId then
                found = true
                break
            end
        end

        if found then
            local scriptUrl = gameData[1]
            if not scriptUrl or typeof(scriptUrl) ~= "string" then
                notify("The game " .. gameName .. " is not yet supported!")
                return
            end

            env.GameName = gameName
            print("[NyxLine] Found game: " .. gameName)
            notify("NyxLine loading: " .. gameName)

            local gameScript = httpLoad(scriptUrl)
            if not gameScript then
                print("[NyxLine] Game script returned nil (may be normal if it doesn't return a value)")
            end
            print("[NyxLine] Done!")
            return
        end
    end
end

notify("Failed to load:\nThe game is not supported!")
print("[NyxLine] PlaceId " .. tostring(game.PlaceId) .. " not found in game config")
