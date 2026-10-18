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

-- count sellable tools in Backpack + Character
local function countSellable()
    local c = 0
    if Player and Player.Backpack then
        for _, tool in pairs(Player.Backpack:GetChildren()) do
            if tool and SellItems and SellItems[tool.Name] then
                c = c + 1
            end
        end
    end
    if Player and Player.Character then
        for _, obj in pairs(Player.Character:GetChildren()) do
            if obj and obj:IsA("Tool") and SellItems and SellItems[obj.Name] then
                c = c + 1
            end
        end
    end
    return c
end

-- attempt to require Inventory module if present under ReplicatedStorage.Modules or ReplicatedStorage
local function loadInventoryModule()
    local ok, inv
    pcall(function()
        local mFolder = ReplicatedStorage:FindFirstChild("Modules") or ReplicatedStorage
        local moduleObj = mFolder and mFolder:FindFirstChild("Inventory")
        if moduleObj then inv = require(moduleObj) end
    end)
    return inv
end

-- Fallback: find a Merchant ProximityPrompt in workspace heuristically
local function findMerchantPromptLocal()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            local parent = obj.Parent
            local nameLow = tostring(parent and parent.Name or ""):lower()
            local objectText = tostring(obj.ObjectText or ""):lower()
            local actionText = tostring(obj.ActionText or ""):lower()
            if nameLow:find("merchant", 1, true) or objectText:find("merchant", 1, true)
               or objectText:find("shiftplox", 1, true) or actionText:find("merchant", 1, true) then
                return obj
            end
        end
    end
    return nil
end

-- Robust activation: fireproximityprompt, Trigger, or move HRP into prompt area
local function activatePrompt(prompt)
    if not prompt then return false end

    -- 1) try global engine helper
    pcall(function()
        if fireproximityprompt then pcall(function() fireproximityprompt(prompt) end) end
    end)

    -- 2) try Trigger method
    pcall(function()
        if typeof(prompt.Trigger) == "function" then
            pcall(function() prompt:Trigger() end)
        end
    end)

    -- 3) move near part fallback (if safe)
    pcall(function()
        local pParent = prompt.Parent
        if pParent and pParent:IsA("BasePart") and Player and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = Player.Character.HumanoidRootPart
            local saved = hrp.CFrame
            hrp.CFrame = pParent.CFrame + Vector3.new(0, 2, 0)
            task.wait(0.12)
            if fireproximityprompt then pcall(function() fireproximityprompt(prompt) end) end
            task.wait(0.08)
            pcall(function() hrp.CFrame = saved end)
        end
    end)

    return true
end

-- Attempt to sell via Inventory:SellAll if present, otherwise use prompt fallback.
-- Verifies result by watching countSellable() drop. Retries when needed.
local function AutoSellAndWait(manualRequest)
    if not manualRequest and not AutoSell then
        print("[Selling] AutoSell disabled; skipping sell.")
        return true
    end

    local before = countSellable()
    if before == 0 then
        print("[Selling] No sellable items detected.")
        return true
    end

    local inv = loadInventoryModule()
    if inv and type(inv.SellAll) == "function" then
        pcall(function() inv:SellAll(manualRequest == true) end)
        print("[Selling] Invoked Inventory:SellAll()")
    else
        print("[Selling] Inventory module not found — trying prompt fallback.")
        local prompt = findMerchantPromptLocal()
        if prompt then
            activatePrompt(prompt)
            print("[Selling] Prompt activation attempted.")
        else
            warn("[Selling] No merchant prompt found in workspace.")
        end
    end

    -- Wait for sell to be visible (count decreases)
    local deadline = tick() + 6
    while tick() < deadline do
        if countSellable() < before then
            print("[Selling] Sell confirmed (items decreased).")
            return true
        end
        task.wait(0.12)
    end

    -- retries
    for attempt = 1, 2 do
        warn(("[Selling] Sell not confirmed — retry %d"):format(attempt))
        if inv and type(inv.SellAll) == "function" then
            pcall(function() inv:SellAll(false) end)
        else
            local prompt = findMerchantPromptLocal()
            if prompt then activatePrompt(prompt) end
        end
        local retryDeadline = tick() + 4
        while tick() < retryDeadline do
            if countSellable() < before then
                print("[Selling] Sell confirmed on retry.")
                return true
            end
            task.wait(0.12)
        end
    end

    warn("[Selling] Sell not confirmed after retries.")
    return false
end

-- original convenience wrapper (keeps backward compatibility)
local function SellAllWithDiagnostics(source, manualRequest)
    if not manualRequest and not AutoSell then return false end
    -- Try inventory path (legacy behavior) but prefer the new verified flow
    return AutoSellAndWait(manualRequest)
end

-- Buy Lucky routine (keeps original behavior, with Inventory integration)
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
            pcall(function()
                Player.Character.RemoteEvent:FireServer("PurchaseShopItem", {["ItemName"] = "1x Lucky Arrow"})
            end)
            task.wait(0.5)
        end
    end
end

-- High level: ensure items are sold and attempt buy-lucky if enabled; returns true if sell confirmed
local function EnsureSoldThenBuyLucky()
    local sold = AutoSellAndWait(false)
    if sold and BuyLucky then
        -- prefer Inventory's buy if available
        local inv = loadInventoryModule()
        if inv and type(inv.BuyLucky) == "function" then
            pcall(function() inv:BuyLucky() end)
            print("[Selling] Inventory:BuyLucky() called.")
        else
            -- fallback purchase attempts
            pcall(function()
                if Player.Character and Player.Character:FindFirstChild("RemoteEvent") then
                    for i = 1, 6 do
                        Player.Character.RemoteEvent:FireServer("PurchaseShopItem", {["ItemName"] = "1x Lucky Arrow"})
                        task.wait(0.45)
                    end
                end
            end)
            print("[Selling] Fallback buy attempts executed.")
        end
    end
    return sold
end

-- Public helper that main.lua / caller should call before serverhop
local function EnsureSoldThenHop()
    local ok = EnsureSoldThenBuyLucky()
    if not ok then
        warn("[EnsureSoldThenHop] Sell not confirmed; proceeding to serverhop may leave items unsold.")
    end
    return ok
end

return {
    SellAllWithDiagnostics = SellAllWithDiagnostics,
    AttemptBuyLuckyBeforeHop = AttemptBuyLuckyBeforeHop,
    EnsureSoldThenHop = EnsureSoldThenHop,
    -- exported for testing/debug
    AutoSellAndWait = AutoSellAndWait,
}
