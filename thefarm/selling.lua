-- selling.lua
local Config = ...
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SellItems = Config.SellItems
local AutoSell = Config.AutoSell
local BuyLucky = Config.BuyLucky

local function UpdateMoneyRef()
    if Player and Player:FindFirstChild("PlayerStats") then
        return Player.PlayerStats:FindFirstChild("Money")
    end
    return nil
end

local function SellAllWithDiagnostics(source, manualRequest)
    if not manualRequest and not AutoSell then return false end
    
    local ModulesFolder = ReplicatedStorage:FindFirstChild("Modules")
    local InventoryModuleObject = ModulesFolder and ModulesFolder:FindFirstChild("Inventory")
    if InventoryModuleObject then
        local ok, Inventory = pcall(function() return require(InventoryModuleObject) end)
        if ok and Inventory and type(Inventory.SellAll) == "function" then
            pcall(function() Inventory:SellAll(manualRequest == true) end)
        end
    end
end

local function AttemptBuyLuckyBeforeHop()
    local Money = UpdateMoneyRef()
    if not BuyLucky or not Money or Money.Value < 75000 then return end

    local ModulesFolder = ReplicatedStorage:FindFirstChild("Modules")
    local bought = false
    if ModulesFolder then
        local InventoryModuleObject = ModulesFolder:FindFirstChild("Inventory")
        if InventoryModuleObject then
            local ok, Inventory = pcall(function() return require(InventoryModuleObject) end)
            if ok and Inventory and type(Inventory.BuyLucky) == "function" then
                pcall(function() Inventory:BuyLucky() end)
                bought = true
            end
        end
    end

    if not bought and Player.Character and Player.Character:FindFirstChild("RemoteEvent") then
        for _ = 1, 10 do
            Player.Character.RemoteEvent:FireServer("PurchaseShopItem", {["ItemName"] = "1x Lucky Arrow"})
            task.wait(0.5)
        end
    end
end

return {
    SellAllWithDiagnostics = SellAllWithDiagnostics,
    AttemptBuyLuckyBeforeHop = AttemptBuyLuckyBeforeHop
}