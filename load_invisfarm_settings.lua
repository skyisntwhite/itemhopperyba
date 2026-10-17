-- loader: sets user settings and loads invisfarmnosettings.lua from the repo
-- by einsteinian (updated)

-- Edit these settings or keep them in a separate executor config before running.
getgenv().YBAFarmSettings = {
    -- Webhook Settings
    WebhookURL = "PUT_YOUR_WEBHOOK_HERE", -- Keep this private!
    SendInterval = 900, -- How often to send webhook (in seconds)

    -- Buying/Selling Settings
    BuyLucky = true,  -- Auto buy Lucky Arrows if money > 75k
    AutoSell = true,  -- Enable auto selling
    
    -- Items to Sell (true = sell, false = keep)
    SellItems = {
        ["Gold Coin"] = true,
        ["Rokakaka"] = true,
        ["Pure Rokakaka"] = true,
        ["Mysterious Arrow"] = true,
        ["Diamond"] = true,
        ["Ancient Scroll"] = true,
        ["Caesar's Headband"] = true,
        ["Stone Mask"] = true,
        ["Rib Cage of The Saint's Corpse"] = true,
        ["Quinton's Glove"] = true,
        ["Zeppeli's Hat"] = true,
        ["Lucky Arrow"] = false, -- KEEP FALSE
        ["Clackers"] = true,
        ["Steel Ball"] = true,
        ["Dio's Diary"] = true
    }
}

local url = "https://raw.githubusercontent.com/skyisntwhite/itemhopperyba/main/invisfarmnosettings.lua"

local ok, res = pcall(function()
    return game:HttpGet(url)
end)

if not ok or not res or res == "" then
    error("Failed to fetch invisfarmnosettings.lua from repo: " .. tostring(res))
end

local fn, err = loadstring(res)
if not fn then
    error("Failed to load invisfarmnosettings.lua: " .. tostring(err))
end

pcall(function()
    fn()
end)
