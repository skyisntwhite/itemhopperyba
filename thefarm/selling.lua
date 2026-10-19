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

local function GetCharacter(Part)
    if Player.Character then
        if not Part then
            return Player.Character
        elseif typeof(Part) == "string" then
            return Player.Character:FindFirstChild(Part) or nil
        end
    end
    return nil
end

local function FindMerchantCFrame()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.MaxActivationDistance ~= 0 then
            local objText = tostring(obj.ObjectText or ""):lower()
            local actText = tostring(obj.ActionText or ""):lower()
            local parent = obj.Parent
            local matchedMerchant = false
            local depth = 0
            while parent and parent ~= Workspace and depth < 6 do
                local name = tostring(parent.Name):lower()
                if name:find("merchant", 1, true) or name:find("shiftplox", 1, true) then
                    matchedMerchant = true
                    break
                end
                parent = parent.Parent
                depth = depth + 1
            end
            if matchedMerchant or objText:find("merchant", 1, true) or actText:find("merchant", 1, true) or objText:find("shiftplox", 1, true) then
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

    local toConsider = {}
    if Player.Backpack then
        for _, t in pairs(Player.Backpack:GetChildren()) do
            if t:IsA("Tool") then
                table.insert(toConsider, t)
            end
        end
    end
    if Player.Character then
        for _, t in pairs(Player.Character:GetChildren()) do
            if t:IsA("Tool") and t.Parent then
                table.insert(toConsider, t)
            end
        end
    end

    if #toConsider == 0 then
        print("[Selling] No tools found to consider for selling.")
        return false, 0, 0, "No tools"
    end

    local hasSellableItems = false
    for _, tool in ipairs(toConsider) do
        if SellItems[tool.Name] then
            hasSellableItems = true
            break
        end
    end

    if not hasSellableItems then
        print("[Selling] No sellable items found; skipping merchant interaction.")
        return false, 0, 0, "No sellable items"
    end

    print("[Selling] Found items to sell, teleporting to Merchant...")

    local hrp = GetCharacter("HumanoidRootPart")
    local savedCFrame = hrp and hrp.CFrame

    -- Locate Merchant and wait up to 3 seconds if server just loaded
    local merchantCF = nil
    local attempts = 0
    while not merchantCF and attempts < 10 do
        merchantCF = FindMerchantCFrame()
        if not merchantCF then
            task.wait(0.3)
            attempts = attempts + 1
        end
    end

    if hrp and merchantCF then
        hrp.CFrame = merchantCF + Vector3.new(0, 3, 0)
        task.wait(0.4)
    else
        print("[Selling] Warning: Merchant CFrame not found, attempting remote sale anyway...")
    end

    local function TrySellTool(toolInstance)
        if not toolInstance or not toolInstance.Parent then return false end
        local toolName = toolInstance.Name
        local shouldSell = SellItems[toolName]
        if not shouldSell then
            return false
        end

        local humanoid = GetCharacter("Humanoid")
        if humanoid then
            pcall(function()
                humanoid:EquipTool(toolInstance)
            end)
            task.wait(0.2)
        end

        pcall(function()
            local remote = GetCharacter("RemoteEvent")
            if remote then
                remote:FireServer("EndDialogue", {
                    ["NPC"] = "Merchant",
                    ["Dialogue"] = "Dialogue5",
                    ["Option"] = "Option2"
                })
            end
        end)

        print(("Sold: %s"):format(toolName))
        task.wait(0.2)
        return true
    end

    for _, tool in ipairs(toConsider) do
        TrySellTool(tool)
    end

    task.wait(0.5)

    -- Restore player position back to safe zone / previous spot
    if hrp and savedCFrame then
        hrp.CFrame = savedCFrame
    end

    return true, 0, 0, nil
end

local function AutoSellScanAndSell()
    if not AutoSell then return end
    SellAllWithDiagnostics("AutoSellScan", false)
end

local function ShouldBuyLuckyArrow()
    if not UpdateMoneyRef() then
        return false
    end
    if BuyLucky ~= true then
        return false
    end
    if Money.Value < 75000 then
        return false
    end
    if GetLuckyArrowCount() >= 9 then
        return false
    end
    return true
end

local function AttemptBuyLuckyBeforeHop()
    if not ShouldBuyLuckyArrow() then
        return
    end

    print("Attempting to buy Lucky Arrow")
    local attempts = 0
    while attempts < 10 and ShouldBuyLuckyArrow() do
        local remote = GetCharacter("RemoteEvent")
        if remote then
            remote:FireServer("PurchaseShopItem", {["ItemName"] = "1x Lucky Arrow"})
        end
        attempts = attempts + 1
        task.wait(0.5)
    end
    
    if attempts > 0 then
        print(("Sent %d Lucky Arrow purchase requests"):format(attempts))
    end
end

return {
    UpdateMoneyRef = UpdateMoneyRef,
    GetLuckyArrowCount = GetLuckyArrowCount,
    SellAllWithDiagnostics = SellAllWithDiagnostics,
    AutoSellScanAndSell = AutoSellScanAndSell,
    AttemptBuyLuckyBeforeHop = AttemptBuyLuckyBeforeHop
}
