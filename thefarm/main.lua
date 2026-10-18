-- main.lua
repeat task.wait(0.25) until game:IsLoaded()
local Players = game:GetService("Players")
local Player = Players.LocalPlayer or Players.PlayerAdded:Wait()

repeat task.wait() until Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")

-- Load Modules (Replace paths with your GitHub raw URLs if hosted online)
local Config = loadstring(game:HttpGet("YOUR_RAW_GITHUB_URL/Config.lua"))()
local Webhook = loadstring(game:HttpGet("YOUR_RAW_GITHUB_URL/Webhook.lua"))(Config)
loadstring(game:HttpGet("YOUR_RAW_GITHUB_URL/Bypasses.lua"))()
local Items = loadstring(game:HttpGet("YOUR_RAW_GITHUB_URL/Items.lua"))()
local Selling = loadstring(game:HttpGet("YOUR_RAW_GITHUB_URL/Selling.lua"))(Config)
local ServerHop = loadstring(game:HttpGet("YOUR_RAW_GITHUB_URL/ServerHop.lua"))()

print("[YBA Farm] Modules loaded successfully.")

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

-- Execute AutoSell & Buy Before Server Hop
Selling.SellAllWithDiagnostics("startup", false)
Selling.AttemptBuyLuckyBeforeHop()

-- Start Server Hopping when done
task.wait(2)
ServerHop()