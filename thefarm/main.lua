-- main.lua
repeat task.wait(0.25) until game:IsLoaded()
local Players = game:GetService("Players")
local Player = Players.LocalPlayer or Players.PlayerAdded:Wait()

repeat
    task.wait()
until Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") and Player.Character:FindFirstChildOfClass("Humanoid")

task.wait(1)
print("Loaded.")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local PlayerGui = Player:WaitForChild("PlayerGui")

local Config = getgenv().YBAFarmSettings or {
    WebhookURL = "",
    SendInterval = 900,
    BuyLucky = true,
    AutoSell = true,
    SellItems = {
        ["Gold Coin"] = true, ["Rokakaka"] = true, ["Pure Rokakaka"] = true,
        ["Mysterious Arrow"] = true, ["Diamond"] = true, ["Ancient Scroll"] = true,
        ["Caesar's Headband"] = true, ["Stone Mask"] = true, ["Rib Cage of The Saint's Corpse"] = true,
        ["Quinton's Glove"] = true, ["Zeppeli's Hat"] = true, ["Lucky Arrow"] = false,
        ["Clackers"] = true, ["Steel Ball"] = true, ["Dio's Diary"] = true
    }
}

-- GitHub Raw URL Base Directory
local baseURL = "https://raw.githubusercontent.com/skyisntwhite/itemhopperyba/refs/heads/main/thefarm/"

-- Load Modules
local Selling = loadstring(game:HttpGet(baseURL .. "selling.lua"))(Config)
local Items = loadstring(game:HttpGet(baseURL .. "items.lua"))()
local ServerHop = loadstring(game:HttpGet(baseURL .. "serverhop.lua"))()

print("[YBA Farm] All modules loaded successfully.")

-- Webhook management
local LastSendFile = "webhook_lastsend.txt"
local Money = nil

local function UpdateMoneyRef()
    if Player and Player:FindFirstChild("PlayerStats") then
        Money = Player.PlayerStats:FindFirstChild("Money")
        return Money ~= nil
    end
    return false
end

local function PersistLastSend(timestamp)
    pcall(function() writefile(LastSendFile, tostring(timestamp)) end)
    getgenv().WebhookLastSend = timestamp
end

local function ReadLastSend()
    if getgenv().WebhookLastSend then return getgenv().WebhookLastSend end
    local t = 0
    pcall(function()
        if isfile and isfile(LastSendFile) then
            t = tonumber(readfile(LastSendFile)) or 0
        end
    end)
    if t > 0 then getgenv().WebhookLastSend = t end
    return t
end

local function SendWebhook(content, isEmbed)
    local WebhookURL = Config.WebhookURL
    if not WebhookURL or WebhookURL == "" or WebhookURL:find("PUT_YOUR_WEBHOOK") then return false end
    local payload = isEmbed and content or HttpService:JSONEncode({content = content})
    local success = false
    pcall(function()
        local req = syn and syn.request or request or http_request
        if req then
            req({ Url = WebhookURL, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload })
            success = true
            return
        end
        if HttpService.PostAsync then
            HttpService:PostAsync(WebhookURL, payload, Enum.HttpContentType.ApplicationJson)
            success = true
        end
    end)
    return success
end

local function SendPeriodicStatus()
    if not UpdateMoneyRef() or not Money then return end
    local moneyVal = tonumber(Money.Value) or 0
    local luckyCount = Selling.GetLuckyArrowCount()
    local formattedMoney = tostring(moneyVal):reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","")

    local embed = HttpService:JSONEncode({
        embeds = {{
            title = "🎮 YBA Autofarm Status",
            description = string.format("**💰 Money:** `$%s`\n**🤑 Lucky Arrows:** `%d`", formattedMoney, luckyCount),
            color = 0x57F287,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            footer = { text = "Account: " .. Player.Name }
        }}
    })

    if SendWebhook(embed, true) then
        local currentTime = os.time()
        PersistLastSend(currentTime)
        return currentTime
    end
    return nil
end

-- Webhook Cooldown & Periodic Check
local LastSend = ReadLastSend()
local currentTime = os.time()
if (currentTime - LastSend) >= Config.SendInterval then
    task.spawn(function()
        task.wait(5)
        SendPeriodicStatus()
    end)
end

task.spawn(function()
    while true do
        task.wait(60)
        if (os.time() - LastSend) >= Config.SendInterval then
            local sentTime = SendPeriodicStatus()
            if sentTime then LastSend = sentTime end
        end
    end
end)

game:GetService("RunService"):Set3dRenderingEnabled(false)

-- HUD & Loading Screens Cleanup
if not PlayerGui:FindFirstChild("HUD") then
    local HUD = ReplicatedStorage:WaitForChild("Objects"):WaitForChild("HUD"):Clone()
    HUD.Parent = PlayerGui
end

local char = Player.Character
if char and char:FindFirstChild("RemoteEvent") then
    char.RemoteEvent:FireServer("PressedPlay")
end

task.spawn(function()
    task.wait(2)
    pcall(function() if PlayerGui:FindFirstChild("LoadingScreen1") then PlayerGui.LoadingScreen1:Destroy() end end)
    pcall(function() if PlayerGui:FindFirstChild("LoadingScreen") then PlayerGui.LoadingScreen:Destroy() end end)
    pcall(function() if workspace:FindFirstChild("LoadingScreen") then workspace.LoadingScreen:Destroy() end end)
    pcall(function() if game.Lighting:FindFirstChild("DepthOfField") then game.Lighting.DepthOfField:Destroy() end end)
end)

-- 1. Execute Synchronous Item Farm
Items.RunItemFarm()

-- 2. Execute Auto-Sell Scan & Sell Loop
Selling.AutoSellScanAndSell()

-- 3. Attempt Buying Lucky Arrow
Selling.AttemptBuyLuckyBeforeHop()

-- 4. Server Hop Routine
print("Farming complete - initiating ServerHop to move to next server.")
task.wait(2)
ServerHop()

while true do
    ServerHop()
    task.wait(3)
end
