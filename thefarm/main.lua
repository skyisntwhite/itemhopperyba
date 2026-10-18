-- main.lua
repeat task.wait(0.25) until game:IsLoaded()
local Players = game:GetService("Players")
local Player = Players.LocalPlayer or Players.PlayerAdded:Wait()

repeat task.wait() until Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")

-- Base URL for your GitHub repository folder
local baseURL = "https://raw.githubusercontent.com/skyisntwhite/itemhopperyba/refs/heads/main/thefarm/"

-- Load Modules sequentially from your GitHub repository
local Config = loadstring(game:HttpGet(baseURL .. "config.lua"))()
local Webhook = loadstring(game:HttpGet(baseURL .. "webhook.lua"))(Config)
loadstring(game:HttpGet(baseURL .. "bypasses.lua"))()
local Items = loadstring(game:HttpGet(baseURL .. "items.lua"))()
local Selling = loadstring(game:HttpGet(baseURL .. "selling.lua"))(Config)
local ServerHop = loadstring(game:HttpGet(baseURL .. "serverhop.lua"))()

print("[YBA Farm] Modules loaded successfully from GitHub.")

-- Initial Webhook Check
local LastSend = Webhook.ReadLastSend()
local currentTime = os.time()
if (currentTime - LastSend) >= Config.SendInterval then
    task.spawn(function()
        task.wait(5)
        Webhook.SendPeriodicStatus()
    end)
end

-- Periodic Webhook Loop
task.spawn(function()
    while true do
        task.wait(60)
        if (os.time() - LastSend) >= Config.SendInterval then
            local sentTime = Webhook.SendPeriodicStatus()
            if sentTime then LastSend = sentTime end
        end
    end
end)

-- Main Execution Flow
local Workspace = game:GetService("Workspace")
local ItemSpawnFolder = Workspace:WaitForChild("Item_Spawns"):WaitForChild("Items")
getgenv().SpawnedItems = {}

ItemSpawnFolder.ChildAdded:Connect(function(Model)
    task.wait(0.5)
    if Model:IsA("Model") then
        local ItemInfo = Items.GetItemInfo(Model)
        if ItemInfo then
            table.insert(getgenv().SpawnedItems, { Model = Model, Info = ItemInfo })
        end
    end
end)

-- Execute AutoSell & Buy Before Server Hop using verified routine
local success = false
local ok, err = pcall(function()
    if type(Selling.EnsureSoldThenHop) == "function" then
        success = Selling.EnsureSoldThenHop()
    else
        -- fallback to existing functions if EnsureSoldThenHop is not present
        Selling.SellAllWithDiagnostics("startup", false)
        Selling.AttemptBuyLuckyBeforeHop()
        success = true
    end
end)
if not ok then
    warn("[main] EnsureSoldThenHop failed: ", tostring(err))
end

-- small delay, then serverhop
task.wait(0.5)
ServerHop()
