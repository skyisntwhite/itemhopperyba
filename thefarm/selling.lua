-- selling.lua
local Config = ...
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

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

local function CountSellable()
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

local function FindMerchantCFrame()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.MaxActivationDistance ~= 0 then
            local objText = tostring(obj.ObjectText or ""):lower()
            local actText = tostring(obj.ActionText or ""):lower()
            if objText:find("merchant", 1, true) or actText:find("merchant", 1, true) or objText:find("shiftplox", 1, true) then
                if obj.Parent and obj.Parent:IsA("BasePart") then
                    return obj.Parent.CFrame
                end
            end
        end
    end
    return nil
end

local function SellAllWithDiagnostics(source, manualRequest)
    if not manualRequest and not AutoSell then
        return false, 0, 0, "AutoSell disabled"
    end

    local before = CountSellable()
    if before == 0 then
        print("[Selling] No sellable items found.")
        return false, 0, 0, "No items"
    end

    print(("[Selling] Found %d items to sell. Teleporting to Merchant..."):format(before))

    local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    local savedCFrame = hrp and hrp.CFrame
    local merchantCF = FindMerchantCFrame()

    -- Teleport character directly next to the merchant so proximity and distance checks pass
    if hrp and merchantCF then
        hrp.CFrame = merchantCF + Vector3.new(0, 3, 0)
        task.wait(0.4)
    else
        print("[Selling] Warning: Merchant location not found in workspace.")
    end

    local sold, types, failed, reason = false, 0, 0, nil
    
    -- Initialize and call the game's native Inventory module which handles automated dialogue injection
    local success = pcall(function()
        local ModulesFolder = ReplicatedStorage:FindFirstChild("Modules")
        if ModulesFolder then
            local InventoryModuleObject = ModulesFolder:FindFirstChild("Inventory")
            if InventoryModuleObject then
                local invOk, Inventory = pcall(function() return require(InventoryModuleObject) end)
                if invOk and Inventory then
                    if type(Inventory.Init) == "function" then
                        pcall(function()
                            Inventory:Init({
                                Config = {
                                    Get = function(_, key)
                                        if key == "FarmEnabled" then return true end
                                        if key == "AutoSell" then return AutoSell end
                                        if key == "BuyLucky" then return BuyLucky end
                                        return Config[key]
                                    end,
                                    GetSellItems = function()
                                        return SellItems
                                    end
                                },
                                RuntimeLog = nil,
                                Movement = {
                                    GetCharacter = function(_, part)
                                        if Player.Character then
                                            if not part then return Player.Character end
                                            return Player.Character:FindFirstChild(part)
                                        end
                                        return nil
                                    end,
                                    Teleport = function(_, cf)
                                        local h = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                                        if h then h.CFrame = cf end
                                    end
                                }
                            })
                        end)
                    end
                    if type(Inventory.SellAll) == "function" then
                        sold, types, failed, reason = Inventory:SellAll(true)
                    end
                end
            end
        end
    end)

    -- Restore player position back to the safe zone / previous position
    if hrp and savedCFrame then
        hrp.CFrame = savedCFrame
    end

    if success and sold then
        print("[Selling] Inventory module successfully completed the sale.")
        return true, types, failed, reason
    end

    return false, 0, 0, reason or "Sell execution failed"
end

local function AutoSellScanAndSell()
    if not AutoSell then return end
    if CountSellable() > 0 then
        SellAllWithDiagnostics("AutoSellScan", false)
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
