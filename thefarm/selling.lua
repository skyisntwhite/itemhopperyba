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

-- Items to always keep, regardless of SellItems config
local ForceKeep = {
    ["Lucky Arrow"] = true,
    ["Lucky Stone Mask"] = true
}

local sellBusy = false

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

local function FindMerchantPrompt()
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
        task.wait(0.12)
    end

    local deadline = tick() + 0.6
    while tool.Parent ~= char and tick() < deadline do
        task.wait(0.02)
    end
    return tool.Parent == char and tool or nil
end

local function CountSellable()
    local c = 0
    if Player.Backpack then
        for _, tool in pairs(Player.Backpack:GetChildren()) do
            if ForceKeep[tool.Name] then
                -- forced keep: skip
            elseif SellItems[tool.Name] then
                c = c + 1
            end
        end
    end
    if Player.Character then
        for _, tool in pairs(Player.Character:GetChildren()) do
            if tool:IsA("Tool") then
                if ForceKeep[tool.Name] then
                    -- skip
                elseif SellItems[tool.Name] then
                    c = c + 1
                end
            end
        end
    end
    return c
end

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
    local dlg = Player.PlayerGui:FindFirstChild("DialogueGui")
    local deadline = tick() + 2.0
    while tick() < deadline do
        dlg = Player.PlayerGui:FindFirstChild("DialogueGui")
        if dlg then
            for _, obj in ipairs(dlg:GetDescendants()) do
                if obj:IsA("TextButton") and obj.Visible then
                    local text = tostring(obj.Text or ""):lower()
                    if text:find("sell") or text:find("all") or text:find("yes") or text:find("ok") or text:find("deal") or text:find("confirm") or text:find("option1") then
                        ClickButton(obj)
                        task.wait(0.2)
                    end
                end
            end
        end
        task.wait(0.08)
    end
end

-- Try to use Inventory.SellAll fast path. Returns true if we invoked it.
local function TryInventorySell(manual)
    local ModulesFolder = ReplicatedStorage:FindFirstChild("Modules")
    if not ModulesFolder then return false end
    local InventoryModuleObject = ModulesFolder:FindFirstChild("Inventory")
    if not InventoryModuleObject then return false end
    local invOk, Inventory = pcall(function() return require(InventoryModuleObject) end)
    if not invOk or not Inventory or type(Inventory.SellAll) ~= "function" then return false end
    pcall(function()
        Inventory:SellAll(manual == true)
    end)
    return true
end

local function SellAllWithDiagnostics(source, manualRequest)
    if sellBusy then
        return false, 0, 0, "sell busy"
    end
    sellBusy = true

    if not manualRequest and not AutoSell then
        sellBusy = false
        return false, 0, 0, "AutoSell disabled"
    end

    local before = CountSellable()
    if before == 0 then
        sellBusy = false
        print("[Selling] No sellable items found.")
        return false, 0, 0, "No items"
    end

    print(('[Selling] Found %d items to sell. Interacting with Merchant...'):format(before))

    -- Prefer Inventory module
    local usedInv = TryInventorySell(manualRequest == true)
    if usedInv then
        -- give server a short moment to process
        task.wait(0.9)
        sellBusy = false
        return true, 0, 0, nil
    end

    -- Build stable to-sell list excluding forced-keeps
    local toSell = {}
    for name, enabled in pairs(SellItems) do
        if enabled and not ForceKeep[name] then
            table.insert(toSell, name)
        end
    end

    if #toSell == 0 then
        sellBusy = false
        print("[Selling] No configured sellable items after applying forced keep list.")
        return false, 0, 0, "No sellable after keep"
    end

    -- Find merchant prompt once and reuse
    local prompt = FindMerchantPrompt()
    if not prompt then
        print("[Selling] Merchant ProximityPrompt not found in workspace.")
        sellBusy = false
        return false, 0, 0, "Prompt not found"
    end

    local parentPart = prompt.Parent
    local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    local savedCFrame = hrp and hrp.CFrame

    -- Teleport only if we can and needed
    if hrp and parentPart and parentPart:IsA("BasePart") then
        local ok, dist = pcall(function()
            return (hrp.Position - parentPart.Position).Magnitude
        end)
        if ok and dist and dist > 6 then
            hrp.CFrame = parentPart.CFrame + Vector3.new(0, 3, 0)
            task.wait(0.35)
        else
            task.wait(0.08)
        end
    end

    -- Iterate through items, equip and trigger prompt with short controlled delays
    for _, itemName in ipairs(toSell) do
        while (Player.Backpack and Player.Backpack:FindFirstChild(itemName)) or (Player.Character and Player.Character:FindFirstChild(itemName)) do
            -- safety check: don't accidentally sell forced-kept items
            if ForceKeep[itemName] then break end

            local tool = EquipSellTool(itemName)
            if not tool then break end

            pcall(function() fireproximityprompt(prompt) end)
            task.wait(0.28)
            HandleDialogue()
            task.wait(0.42)

            -- wait and verify inventory decreased
            local start = tick()
            local timedOut = true
            while tick() - start < 1.0 do
                if CountSellable() < before then
                    timedOut = false
                    break
                end
                task.wait(0.12)
            end
            if timedOut then
                -- nothing changed; break to avoid infinite loop
                break
            end
            before = CountSellable()
        end
    end

    if hrp and savedCFrame then
        hrp.CFrame = savedCFrame
        task.wait(0.15)
    end

    sellBusy = false
    return true, 0, 0, nil
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
