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

-- Uses the fully robust Inventory module integration or internal dialogue handling if present
local function SellAllWithDiagnostics(source, manualRequest)
    if not manualRequest and not AutoSell then
        return false, 0, 0, "AutoSell disabled"
    end

    local before = CountSellable()
    if before == 0 then
        print("[Selling] No sellable items found.")
        return false, 0, 0, "No items"
    end

    print(("[Selling] Found %d items to sell. Executing Inventory:SellAll..."):format(before))

    local sold, types, failed, reason = false, 0, 0, nil
    local success = pcall(function()
        local ModulesFolder = ReplicatedStorage:FindFirstChild("Modules")
        if ModulesFolder then
            local InventoryModuleObject = ModulesFolder:FindFirstChild("Inventory")
            if InventoryModuleObject then
                local invOk, Inventory = pcall(function() return require(InventoryModuleObject) end)
                if invOk and Inventory and type(Inventory.SellAll) == "function" then
                    -- If Inventory module has its own Init/Config, try to init it or call SellAll directly
                    if type(Inventory.Init) == "function" then
                        pcall(function()
                            Inventory:Init({
                                Config = {
                                    GetSellItems = function() return SellItems end,
                                    Get = function(self, key)
                                        if key == "FarmEnabled" or key == "AutoSell" then return true end
                                        return nil
                                    end
                                },
                                RuntimeLog = nil,
                                Movement = nil
                            })
                        end)
                    end
                    sold, types, failed, reason = Inventory:SellAll(true)
                end
            end
        end
    end)

    if success and sold then
        print("[Selling] Inventory:SellAll completed successfully.")
        return true, types, failed, reason
    end

    -- Fallback manual prompt interaction if external Inventory module isn't loaded/responsive
    local prompt = nil
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.MaxActivationDistance ~= 0 then
            local objText = tostring(obj.ObjectText or ""):lower()
            local actText = tostring(obj.ActionText or ""):lower()
            if objText:find("merchant", 1, true) or actText:find("merchant", 1, true) or objText:find("shiftplox", 1, true) then
                prompt = obj
                break
            end
        end
    end

    if prompt then
        local parentPart = prompt.Parent
        local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
        local savedCFrame = hrp and hrp.CFrame

        if hrp and parentPart and parentPart:IsA("BasePart") then
            hrp.CFrame = parentPart.CFrame + Vector3.new(0, 3, 0)
            task.wait(0.3)
        end

        pcall(function() fireproximityprompt(prompt) end)
        task.wait(1)

        if hrp and savedCFrame then
            hrp.CFrame = savedCFrame
        end
        return true, 0, 0, nil
    end

    return false, 0, 0, "Failed to execute sale"
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