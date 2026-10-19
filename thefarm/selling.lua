-- selling.lua
local Config = ...
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuyLucky = Config.BuyLucky
local AutoSell = Config.AutoSell
local SellItems = Config.SellItems
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

local function SellAllWithDiagnostics(source, manualRequest)
    if not manualRequest and not AutoSell then
        return false, 0, 0, "AutoSell disabled"
    end

    local sold, types, failed, reason = false, 0, 0, nil
    pcall(function()
        local ModulesFolder = ReplicatedStorage:FindFirstChild("Modules")
        if ModulesFolder then
            local InventoryModuleObject = ModulesFolder:FindFirstChild("Inventory")
            if InventoryModuleObject then
                local invOk, Inventory = pcall(function() return require(InventoryModuleObject) end)
                if invOk and Inventory and type(Inventory.SellAll) == "function" then
                    sold, types, failed, reason = Inventory:SellAll(manualRequest == true)
                    return
                end
            end
        end
    end)
    return sold, types, failed, reason
end

local function AutoSellScanAndSell()
    if not AutoSell then return end
    
    local function countSellable()
        local c = 0
        if Player.Backpack then
            for _, tool in pairs(Player.Backpack:GetChildren()) do
                if SellItems[tool.Name] then c = c + 1 end
            end
        end
        if Player.Character then
            for _, tool in pairs(Player.Character:GetChildren()) do
                if tool:IsA("Tool") and SellItems[tool.Name] then c = c + 1 end
            end
        end
        return c
    end

    local before = countSellable()
    if before == 0 then return end

    SellAllWithDiagnostics("AutoSellScan", false)

    local deadline = tick() + 3.0
    while tick() < deadline do
        if countSellable() < before then break end
        task.wait(0.12)
    end
end

local function ShouldBuyLuckyArrow()
    if not UpdateMoneyRef() or not Money then return false end
    if BuyLucky ~= true then return false end
    if Money.Value < 75000 then return false end
    if GetLuckyArrowCount() >= 9 then return false end
    return true
end

local function AttemptBuyLuckyBeforeHop()
    if not ShouldBuyLuckyArrow() then return end

    local bought = false
    pcall(function()
        local ModulesFolder = ReplicatedStorage:FindFirstChild("Modules")
        if ModulesFolder then
            local InventoryModuleObject = ModulesFolder:FindFirstChild("Inventory")
            if InventoryModuleObject then
                local ok, Inventory = pcall(function() return require(InventoryModuleObject) end)
                if ok and Inventory and type(Inventory.BuyLucky) == "function" then
                    Inventory:BuyLucky()
                    bought = true
                end
            end
        end
    end)

    if not bought then
        local attempts = 0
        while attempts < 10 and ShouldBuyLuckyArrow() do
            local char = Player.Character
            local remote = char and char:FindFirstChild("RemoteEvent")
            if remote then
                remote:FireServer("PurchaseShopItem", {["ItemName"] = "1x Lucky Arrow"})
            end
            attempts = attempts + 1
            task.wait(0.5)
        end
    end
end

return {
    UpdateMoneyRef = UpdateMoneyRef,
    GetLuckyArrowCount = GetLuckyArrowCount,
    SellAllWithDiagnostics = SellAllWithDiagnostics,
    AutoSellScanAndSell = AutoSellScanAndSell,
    AttemptBuyLuckyBeforeHop = AttemptBuyLuckyBeforeHop
}