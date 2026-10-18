-- webhook.lua
local Config = ...
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local LastSendFile = "webhook_lastsend.txt"
local Money = nil

local function UpdateMoneyRef()
    if Player and Player:FindFirstChild("PlayerStats") then
        Money = Player.PlayerStats:FindFirstChild("Money")
        return Money ~= nil
    end
    return false
end

local function GetLuckyArrowCount()
    local Count = 0
    pcall(function()
        local invFolder = Player:WaitForChild("PlayerStats", 2):WaitForChild("Inventory", 2)
        for _, item in pairs(invFolder:GetChildren()) do
            if item.Name == "Lucky Arrow" then Count += 1 end
        end
    end)
    if Player.Backpack then
        for _, tool in pairs(Player.Backpack:GetChildren()) do
            if tool.Name == "Lucky Arrow" then Count += 1 end
        end
    end
    if Player.Character then
        for _, tool in pairs(Player.Character:GetChildren()) do
            if tool.Name == "Lucky Arrow" then Count += 1 end
        end
    end
    return Count
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
    if not WebhookURL or WebhookURL == "" or WebhookURL:find("PUT_YOUR_WEBHOOK") then
        warn("Webhook URL not configured properly")
        return false
    end
    
    local payload = isEmbed and content or HttpService:JSONEncode({content = content})
    local success = false
    
    pcall(function()
        local req = syn and syn.request or request or http_request
        if req then
            req({
                Url = WebhookURL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = payload
            })
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
    local luckyCount = GetLuckyArrowCount()
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

return {
    ReadLastSend = ReadLastSend,
    SendPeriodicStatus = SendPeriodicStatus
}