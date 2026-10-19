-- selling.lua
local Config = ...
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")

local BuyLucky = Config.BuyLucky
local AutoSell = Config.AutoSell
local SellItems = Config.SellItems
local Money = nil

-- keep list (always protect these)
local ForceKeep = {
    ["Lucky Arrow"] = true,
    ["Lucky Stone Mask"] = true,
}

-- Helpers - money / inventory
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

-- Click helpers (firesignal/getconnections fallback)
local function ClickButton(btn)
    if not btn or not btn.Parent then return false end
    if type(firesignal) == "function" then
        local ok = pcall(function() firesignal(btn.MouseButton1Click) end)
        if ok then return true end
    end
    if type(getconnections) == "function" then
        local ok, conns = pcall(function() return getconnections(btn.MouseButton1Click) end)
        if ok and type(conns) == "table" then
            for _, conn in ipairs(conns) do
                local fn = nil
                pcall(function() fn = conn.Function end)
                if type(fn) == "function" then
                    if pcall(fn) then return true end
                end
            end
        end
    end
    return false
end

local function HandleDialogue()
    -- click any obvious sell/all/yes/confirm buttons in the open dialogue
    local deadline = tick() + 2.0
    while tick() < deadline do
        local dlg = Player.PlayerGui:FindFirstChild("DialogueGui") or Player.PlayerGui:FindFirstChild("Dialogue")
        if dlg then
            for _, obj in ipairs(dlg:GetDescendants()) do
                if obj:IsA("TextButton") and obj.Visible then
                    local text = tostring(obj.Text or ""):lower()
                    if text:find("sell") or text:find("all") or text:find("yes") or text:find("ok") or text:find("confirm") or text:find("deal") or text:find("option1") then
                        ClickButton(obj)
                        task.wait(0.18)
                        -- allow dialogue to progress
                    end
                end
            end
        end
        task.wait(0.08)
    end
end

-- Try to require the repository's Inventory module (preferred)
local InventoryModule = nil
pcall(function()
    local ModulesFolder = ReplicatedStorage:FindFirstChild("Modules")
    if ModulesFolder then
        local InventoryObject = ModulesFolder:FindFirstChild("Inventory")
        if InventoryObject then
            local ok, mod = pcall(function() return require(InventoryObject) end)
            if ok and mod then InventoryModule = mod end
        end
    end
end)

local function FindMerchantPrompt()
    -- search workspace for a merchant proximity prompt
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.MaxActivationDistance ~= 0 then
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
            local objText = tostring(obj.ObjectText or ""):lower()
            local actText = tostring(obj.ActionText or ""):lower()
            if matchedMerchant or objText:find("merchant", 1, true) or actText:find("merchant", 1, true) or objText:find("shiftplox", 1, true) or actText:find("shiftplox", 1, true) then
                return obj
            end
        end
    end
    return nil
end

local function EquipSellTool(itemName)
    local char = Player.Character
    local hum = char and char:FindFirstChildWhichIsA("Humanoid")
    if not hum then return nil end

    local tool = Player.Backpack:FindFirstChild(itemName)
    if not tool and char then
        tool = char:FindFirstChild(itemName)
    end
    if not tool then return nil end

    if tool.Parent == Player.Backpack then
        pcall(function() hum:EquipTool(tool) end)
        task.wait(0.08)
    end

    local deadline = tick() + 0.45
    while tool.Parent ~= char and tick() < deadline do
        task.wait(0.01)
    end
    return tool.Parent == char and tool or nil
end

local function CountSellable()
    local c = 0
    if Player.Backpack then
        for _, tool in pairs(Player.Backpack:GetChildren()) do
            if tool:IsA("Tool") and SellItems[tool.Name] and not ForceKeep[tool.Name] then c = c + 1 end
        end
    end
    if Player.Character then
        for _, tool in pairs(Player.Character:GetChildren()) do
            if tool:IsA("Tool") and SellItems[tool.Name] and not ForceKeep[tool.Name] then c = c + 1 end
        end
    end
    return c
end

local function SellAllWithDiagnostics(source, manualRequest)
    -- prefer Inventory module if available
    if InventoryModule and type(InventoryModule.SellAll) == "function" then
        -- Inventory.SellAll(manual)
        pcall(function() InventoryModule:SellAll(manualRequest == true) end)
        -- allow it a moment to complete
        task.wait(0.9)
        return true, 0, 0, nil
    end

    if not manualRequest and not AutoSell then
        return false, 0, 0, "AutoSell disabled"
    end

    local before = CountSellable()
    if before == 0 then
        return false, 0, 0, "No items"
    end

    -- find merchant prompt
    local prompt = FindMerchantPrompt()
    if not prompt then
        return false, 0, 0, "Prompt not found"
    end

    -- move close to merchant
    local hrp = GetCharacter("HumanoidRootPart")
    local savedCFrame = hrp and hrp.CFrame
    local parentPart = prompt.Parent
    if hrp and parentPart and parentPart:IsA("BasePart") then
        hrp.CFrame = parentPart.CFrame + Vector3.new(0, 3, 0)
        task.wait(0.28)
    end

    -- iterate sellable items (skip force-kept)
    for itemName, enabled in pairs(SellItems) do
        if enabled and not ForceKeep[itemName] then
            -- attempt to sell all instances of this item
            local attempts = 0
            while (Player.Backpack and Player.Backpack:FindFirstChild(itemName)) or (Player.Character and Player.Character:FindFirstChild(itemName)) do
                if attempts >= 8 then break end
                local tool = EquipSellTool(itemName)
                if not tool then break end

                -- Trigger the merchant dialogue via prompt
                pcall(function() fireproximityprompt(prompt) end)
                task.wait(0.28)

                -- Click sell/all/confirm buttons if dialogue opens
                HandleDialogue()

                -- small wait for server processing
                task.wait(0.38)

                -- sanity: if not decreased, try one remote fallback if available
                local nowCount
                pcall(function() nowCount = (Player.Backpack and #Player.Backpack:GetChildren() or 0) + (Player.Character and #Player.Character:GetChildren() or 0) end)

                attempts = attempts + 1
            end
        end
    end

    -- restore position
    if hrp and savedCFrame then
        hrp.CFrame = savedCFrame
    end

    return true, 0, 0, nil
end

local function AutoSellScanAndSell()
    if not AutoSell then return end
    if CountSellable() > 0 then
        SellAllWithDiagnostics("AutoSellScan", false)
    end
end

local function ShouldBuyLuckyArrow()
    if not UpdateMoneyRef() then return false end
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
