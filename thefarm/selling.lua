-- selling.lua (Stable & Crash-Proof)
local Config = ... or (getgenv and getgenv().YBAFarmSettings) or {}
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")

local BuyLucky = Config.BuyLucky ~= nil and Config.BuyLucky or true
local AutoSell = Config.AutoSell ~= nil and Config.AutoSell or true
local SellItems = Config.SellItems or {}
local Money = nil

local ForceKeep = {
    ["Lucky Arrow"] = true,
    ["Lucky Stone Mask"] = true,
}

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

local function ClickButton(btn)
    if not btn or not btn.Parent then return false end
    if type(firesignal) == "function" then
        local ok = pcall(function() firesignal(btn.MouseButton1Click) end)
        if ok then return true end
    end
    local ok = pcall(function() if btn.Activate then btn:Activate() end end)
    return ok
end

local function HandleDialogue()
    local deadline = tick() + 1.5
    while tick() < deadline do
        local dlg = Player.PlayerGui:FindFirstChild("DialogueGui") or Player.PlayerGui:FindFirstChild("Dialogue")
        if dlg then
            for _, obj in ipairs(dlg:GetDescendants()) do
                if obj:IsA("TextButton") and obj.Visible then
                    local text = tostring(obj.Text or ""):lower()
                    if text:find("sell") or text:find("all") or text:find("yes") or text:find("ok") or text:find("confirm") or text:find("deal") or text:find("option1") then
                        ClickButton(obj)
                        task.wait(0.12)
                    end
                end
            end
        end
        task.wait(0.05)
    end
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
                depth += 1
            end
            local objText = tostring(obj.ObjectText or ""):lower()
            local actText = tostring(obj.ActionText or ""):lower()
            if matchedMerchant or objText:find("merchant", 1, true) or actText:find("merchant", 1, true) then
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

    local tool = Player.Backpack:FindFirstChild(itemName) or (char and char:FindFirstChild(itemName))
    if not tool then return nil end

    if tool.Parent == Player.Backpack then
        pcall(function() hum:EquipTool(tool) end)
        task.wait(0.05)
    end

    local deadline = tick() + 0.4
    while tool.Parent ~= char and tick() < deadline do
        task.wait(0.01)
    end
    return tool.Parent == char and tool or nil
end

local function CountSellable()
    local c = 0
    if Player.Backpack then
        for _, tool in pairs(Player.Backpack:GetChildren()) do
            if tool:IsA("Tool") and SellItems[tool.Name] and not ForceKeep[tool.Name] then c += 1 end
        end
    end
    if Player.Character then
        for _, tool in pairs(Player.Character:GetChildren()) do
            if tool:IsA("Tool") and SellItems[tool.Name] and not ForceKeep[tool.Name] then c += 1 end
        end
    end
    return c
end

local function SellAllWithDiagnostics(source, manualRequest)
    if not manualRequest and not AutoSell then
        return false, 0, 0, "AutoSell disabled"
    end

    local before = CountSellable()
    if before == 0 then
        return false, 0, 0, "No items"
    end

    local prompt = FindMerchantPrompt()
    if not prompt then
        return false, 0, 0, "Prompt not found"
    end

    local hrp = GetCharacter("HumanoidRootPart")
    local savedCFrame = hrp and hrp.CFrame
    local parentPart = prompt.Parent
    if hrp and parentPart and parentPart:IsA("BasePart") then
        hrp.CFrame = parentPart.CFrame + Vector3.new(0, 3, 0)
        task.wait(0.2)
    end

    for itemName, enabled in pairs(SellItems) do
        if enabled and not ForceKeep[itemName] then
            local attempts = 0
            while (Player.Backpack and Player.Backpack:FindFirstChild(itemName)) or (Player.Character and Player.Character:FindFirstChild(itemName)) do
                if attempts >= 6 then break end
                local tool = EquipSellTool(itemName)
                if not tool then break end

                pcall(function() fireproximityprompt(prompt) end)
                task.wait(0.2)

                HandleDialogue()
                task.wait(0.3)

                attempts += 1
            end
        end
    end

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

    local attempts = 0
    while attempts < 10 and ShouldBuyLuckyArrow() do
        local char = Player.Character
        local remote = char and char:FindFirstChild("RemoteEvent")
        if remote then
            remote:FireServer("PurchaseShopItem", {["ItemName"] = "1x Lucky Arrow"})
        end
        attempts += 1
        task.wait(0.4)
    end
end

return {
    UpdateMoneyRef = UpdateMoneyRef,
    GetLuckyArrowCount = GetLuckyArrowCount,
    SellAllWithDiagnostics = SellAllWithDiagnostics,
    AutoSellScanAndSell = AutoSellScanAndSell,
    AttemptBuyLuckyBeforeHop = AttemptBuyLuckyBeforeHop
}
