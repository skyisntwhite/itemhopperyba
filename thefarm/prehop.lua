-- PreHop module: robust pre-hop sell confirmation and buy-lucky integration
-- Designed to be required from invisfarmnosettings.lua.
local PreHop = {}

local HttpService = game:GetService("HttpService")

-- Counts sellable items using provided SellItems table and Player
local function CountSellableItems(SellItems, Player)
    local total = 0
    for itemName, enabled in pairs(SellItems or {}) do
        if enabled then
            local count = 0
            pcall(function()
                if Player.Backpack then
                    for _, tool in pairs(Player.Backpack:GetChildren()) do
                        if tool.Name == itemName then count = count + 1 end
                    end
                end
                if Player.Character then
                    for _, tool in pairs(Player.Character:GetChildren()) do
                        if tool:IsA("Tool") and tool.Name == itemName then count = count + 1 end
                    end
                end
            end)
            total = total + count
        end
    end
    return total
end

-- Attempts to confirm selling before hop.
-- params: {
--   SellItems = table,
--   Player = Player object,
--   ReplicatedStorage = service,
--   SellAllWithDiagnostics = function,
--   AttemptBuyLuckyBeforeHop = function,
--   Visited = table, JobId=string, SaveFile=string,
--   ServerHop = function,
--   VerifyTimeout=number (optional), MaxAttempts=number (optional)
-- }
function PreHop.Run(params)
    local SellItems = params.SellItems
    local Player = params.Player
    local ReplicatedStorage = params.ReplicatedStorage
    local SellAllWithDiagnostics = params.SellAllWithDiagnostics
    local AttemptBuyLuckyBeforeHop = params.AttemptBuyLuckyBeforeHop
    local Visited, JobId, SaveFile = params.Visited, params.JobId, params.SaveFile
    local ServerHop = params.ServerHop

    local verifyTimeout = params.VerifyTimeout or 2.0
    local maxAttempts = params.MaxAttempts or 3

    local function anySellable()
        return CountSellableItems(SellItems, Player) > 0
    end

    local before = CountSellableItems(SellItems, Player)
    if before <= 0 then
        print("[PreHop] no sellable items detected; safe to continue.")
    else
        local soldConfirmed = false
        for attempt = 1, maxAttempts do
            print(('[PreHop] Sell attempt %d/%d'):format(attempt, maxAttempts))

            -- Try Inventory module SellAll first
            local tried = false
            local ModulesFolder = ReplicatedStorage and ReplicatedStorage:FindFirstChild("Modules")
            if ModulesFolder then
                local InventoryModuleObject = ModulesFolder:FindFirstChild("Inventory")
                if InventoryModuleObject then
                    local ok, Inventory = pcall(function() return require(InventoryModuleObject) end)
                    if ok and Inventory and type(Inventory.SellAll) == "function" then
                        tried = true
                        local ok2, res = pcall(function() return Inventory:SellAll(false) end)
                        print('[PreHop] Inventory:SellAll returned', ok2, res)
                    end
                end
            end

            -- Fallback to wrapper
            if not tried and type(SellAllWithDiagnostics) == "function" then
                pcall(function()
                    SellAllWithDiagnostics("server-hop", false)
                end)
            end

            -- Wait for replication and verify inventory decreased
            local deadline = tick() + verifyTimeout
            while tick() < deadline do
                if CountSellableItems(SellItems, Player) < before then
                    print("[PreHop] confirmed inventory decreased before hop.")
                    soldConfirmed = true
                    break
                end
                task.wait(0.12)
            end

            if soldConfirmed then break end
            task.wait(0.25)
        end

        if not soldConfirmed then
            print('[PreHop] sell not confirmed after attempts; proceeding with caution.')
        end
    end

    -- Attempt buy-lucky if thresholds met
    if type(AttemptBuyLuckyBeforeHop) == "function" then
        pcall(AttemptBuyLuckyBeforeHop)
    end

    -- Update visited and hop
    if Visited and JobId and SaveFile then
        if not table.find(Visited, JobId) then
            table.insert(Visited, JobId)
            pcall(function() writefile(SaveFile, HttpService:JSONEncode(Visited)) end)
        end
    end

    task.wait(0.4)
    if ServerHop and type(ServerHop) == "function" then
        pcall(ServerHop)
    end

    -- Continuous hop loop (keeps original behavior)
    while true do
        pcall(ServerHop)
        task.wait(3)
    end
end

return PreHop
