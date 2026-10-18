-- einsteinian and copilot(mostworks oml)
-- v21: Github Loadstring Support Added

local Config = getgenv().YBAFarmSettings or {
    WebhookURL = "",
    SendInterval = 900,
    BuyLucky = true,
    AutoSell = true,
    SellItems = {
        ["Gold Coin"] = true, ["Rokakaka"] = true, ["Pure Rokakaka"] = true,
        ["Mysterious Arrow"] = true, ["Diamond"] = true, ["Ancient Scroll"] = true,
        ["Caesar's Headband"] = true, ["Stone Mask"] = true, ["Rib Cage of The Saint's Corpse"] = true,
        ["Quinton's Glove"] = true, ["Zeppeli's Hat"] = true, ["Lucky Arrow"] = false,
        ["Clackers"] = true, ["Steel Ball"] = true, ["Dio's Diary"] = true
    }
}

repeat task.wait(0.25) until game:IsLoaded()
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

if not Player then
    Player = Players.LocalPlayer or Players.PlayerAdded:Wait()
end

repeat
    task.wait()
until Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") and Player.Character:FindFirstChildOfClass("Humanoid")

task.wait(1)
print("Loaded.")

-- Services
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")
local PlayerGui = Player:WaitForChild("PlayerGui")
local Money = nil

-- Configuration Mapping
local WebhookURL = Config.WebhookURL
local LastSendFile = "webhook_lastsend.txt"
local SendInterval = Config.SendInterval
local BuyLucky = Config.BuyLucky
local AutoSell = Config.AutoSell
local SellItems = Config.SellItems

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
            if item.Name and item.Name:match("Lucky Arrow") then
                Count = Count + 1
            end
        end
    end)
    
    return Count
end

-- SELLING SUBSYSTEM (REPLACEMENT FOR BROKEN/OLD SELLING CODE)
-- Uses client-side dialogue scanning + VirtualInputManager click emulation.
-- Integrates with Config.SellItems (true => sell, false => keep).

local VirtualInputManager = (pcall(function() return game:GetService("VirtualInputManager") end) and game:GetService("VirtualInputManager")) or nil
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- keep local references to existing config values
local AutoSellEnabled = AutoSell -- from top of file (keeps compatibility)
local SellConfig = SellItems or {}

local SELL_UI_WAIT = 5      -- seconds to wait for dialogue/UI to appear
local SELL_ITEM_TIMEOUT = 6 -- per item operation timeout
local CLICK_PAUSE = 0.06    -- pause between simulated clicks
local RETRY_ATTEMPTS = 3

local function log(...)
    -- small helper; replace with your print/log target if needed
    pcall(print, "[AutoSell]", ...)
end

-- Build a list of items that we should attempt to sell (names with true)
local function GetSellListFromConfig()
    local list = {}
    for name, shouldSell in pairs(SellConfig) do
        if shouldSell == true then
            list[#list + 1] = name
        end
    end
    return list
end

-- Count how many sellable items we currently have (search Backpack + Character + PlayerStats.Inventory if present)
local function CountItemInstances(name)
    local count = 0
    -- Backpack
    if Player.Backpack then
        for _, child in ipairs(Player.Backpack:GetChildren()) do
            if child.Name == name then count = count + 1 end
        end
    end
    -- Character (equipped)
    if Player.Character then
        for _, child in ipairs(Player.Character:GetChildren()) do
            if child:IsA("Tool") and child.Name == name then count = count + 1 end
        end
    end
    -- PlayerStats/Inventory folder (some clients expose)
    pcall(function()
        local stats = Player:FindFirstChild("PlayerStats")
        if stats then
            local inv = stats:FindFirstChild("Inventory")
            if inv then
                for _, obj in ipairs(inv:GetChildren()) do
                    if obj.Name == name then count = count + 1 end
                end
            end
        end
    end)
    return count
end

-- Returns true if we currently have any sellable items to sell
local function HasAnythingToSell()
    for _, name in ipairs(GetSellListFromConfig()) do
        if CountItemInstances(name) > 0 then
            return true
        end
    end
    return false
end

-- Utility: try to click/activate a GUI object robustly
local function ClickGuiObject(guiObject)
    if not guiObject or not guiObject:IsA("GuiObject") then return false end
    -- prefer VirtualInputManager because it reliably triggers client-side handling
    local success = false
    pcall(function()
        if VirtualInputManager and typeof(VirtualInputManager.SendMouseButtonEvent) == "function" then
            local absPos = guiObject.AbsolutePosition
            local absSize = guiObject.AbsoluteSize
            -- click at center
            local x = absPos.X + absSize.X / 2
            local y = absPos.Y + absSize.Y / 2
            -- press
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
            task.wait(CLICK_PAUSE)
            -- release
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
            success = true
            return
        end
    end)
    if success then return true end

    -- fallback: try :Activate() (works on TextButton in many contexts)
    local ok = pcall(function() if guiObject.Activate then guiObject:Activate() end end)
    if ok then return true end

    -- final fallback: fire the MouseButton1Click event if present (may error in some environments)
    pcall(function()
        local ev = guiObject.MouseButton1Click
        if ev and typeof(ev.Fire) == "function" then
            ev:Fire()
            success = true
        end
    end)
    return success
end

-- Find candidate merchant/dialogue UI roots in PlayerGui
-- This function returns a table of frames that look like merchant/dialogue UIs.
local function FindDialogueRoots()
    local roots = {}
    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if not gui:IsA("ScreenGui") then goto continue end
        -- Search descendants for an obvious merchant UI button/text
        for _, obj in ipairs(gui:GetDescendants()) do
            if obj:IsA("TextButton") or obj:IsA("TextLabel") then
                local txt = tostring(obj.Text or ""):lower()
                if txt:find("merchant") or txt:find("sell") or txt:find("sell all") or txt:find("sell selected") or txt:find("inventory") then
                    roots[#roots + 1] = gui
                    break
                end
            end
        end
        ::continue::
    end
    return roots
end

-- Given a dialogue root, find the most likely "Sell" / "Sell All" / item rows / Confirm controls.
local function AnalyzeDialogue(root)
    local out = {
        sellAllButton = nil,
        sellButton = nil, -- generic "Sell" or "Sell Selected"
        confirmButton = nil,
        itemButtons = {}, -- item row buttons (TextButton or Frame containing TextButton)
    }
    if not root then return out end
    local sellList = GetSellListFromConfig()
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("TextButton") or obj:IsA("ImageButton") then
            local t = tostring(obj.Text or ""):lower()
            if t == "sell all" or t:find("sell all") then
                out.sellAllButton = obj
            elseif t == "sell selected" or t == "sell" or t:find("^sell%s*$") then
                -- generic sell button
                out.sellButton = out.sellButton or obj
            elseif t == "confirm" or t == "yes" or t == "ok" or t == "accept" then
                out.confirmButton = obj
            else
                -- maybe an item row: often text is the item name or "Gold Coin x10"
                for _, wanted in ipairs(sellList) do
                    local wantLower = tostring(wanted):lower()
                    if t:find(wantLower, 1, true) then
                        out.itemButtons[#out.itemButtons + 1] = obj
                        break
                    end
                end
            end
        elseif obj:IsA("TextLabel") then
            -- Sometimes item rows are TextLabels inside Buttons; collect labels for matching if needed
            local t = tostring(obj.Text or ""):lower()
            for _, wanted in ipairs(sellList) do
                local wantLower = tostring(wanted):lower()
                if t:find(wantLower, 1, true) then
                    -- try to find a nearest ancestor button/frame to click
                    local parent = obj.Parent
                    while parent and parent ~= root do
                        if parent:IsA("TextButton") or parent:IsA("ImageButton") or parent:IsA("Frame") then
                            out.itemButtons[#out.itemButtons + 1] = parent
                            break
                        end
                        parent = parent.Parent
                    end
                    break
                end
            end
        end
    end
    return out
end

-- Try to open the merchant dialogue if a "Merchant" NPC prompt is available.
-- This is a best-effort attempt; if your farming controller already opens the dialogue, this can be skipped.
local function TryOpenMerchantDialogue()
    -- Many modern YBA merchants open a dialogue client-side when player is near and interacts.
    -- We try to click any ProximityPrompt on nearby NPCs named "Merchant" or "Shop".
    local workspace = game:GetService("Workspace")
    local nearestPrompt = nil
    local nearestDist = math.huge
    local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    for _, model in ipairs(workspace:GetDescendants()) do
        if model:IsA("ProximityPrompt") then
            local parentName = tostring(model.Parent and model.Parent.Name or ""):lower()
            if parentName:find("merchant") or parentName:find("shop") or parentName:find("vendor") or parentName:find("merchant") then
                local part = model.Parent:FindFirstChildWhichIsA("BasePart") or model.Parent:FindFirstChild("HumanoidRootPart")
                if part then
                    local dist = (hrp.Position - part.Position).Magnitude
                    if dist < nearestDist and dist <= 20 then
                        nearestPrompt = model
                        nearestDist = dist
                    end
                end
            end
        end
    end
    if nearestPrompt then
        pcall(function() nearestPrompt:InputHoldBegin() end)
        task.wait(0.15)
        pcall(function() nearestPrompt:InputHoldEnd() end)
        return true
    end
    return false
end

-- High-level routine: Attempt to sell everything that should be sold according to config.
-- Returns true if a sell action was performed (or already no sellable items), false on unrecoverable failure.
local function PerformSellCycle()
    if not HasAnythingToSell() then
        log("Nothing to sell (according to config).")
        return true
    end

    local attempts = 0
    while attempts < RETRY_ATTEMPTS and HasAnythingToSell() do
        attempts = attempts + 1
        log("Sell attempt", attempts, "— searching for dialogue UI")

        -- Wait for dialogue UI to appear
        local roots = FindDialogueRoots()
        local root = roots[1]
        local waited = 0
        while not root and waited < SELL_UI_WAIT do
            -- try to open merchant dialogue if nothing found
            TryOpenMerchantDialogue()
            task.wait(0.25)
            waited = waited + 0.25
            roots = FindDialogueRoots()
            root = roots[1]
        end

        if not root then
            log("Dialogue UI not found; attempting to open merchant prompt and retry.")
            TryOpenMerchantDialogue()
            task.wait(0.5)
            roots = FindDialogueRoots()
            root = roots[1]
            if not root then
                log("Unable to find or open merchant dialogue. Aborting this sell attempt.")
                break
            end
        end

        -- analyze UI
        local ui = AnalyzeDialogue(root)
        -- strategy 1: use "Sell All" if present
        if ui.sellAllButton then
            log("Found 'Sell All' button; clicking it.")
            ClickGuiObject(ui.sellAllButton)
            task.wait(0.25)
            if ui.confirmButton then
                ClickGuiObject(ui.confirmButton)
            end
            -- small delay to let server process and items be removed
            task.wait(0.6)
        else
            -- strategy 2: select sellable items then click Sell / Sell Selected then Confirm
            local itemsClicked = 0
            for _, itemBtn in ipairs(ui.itemButtons) do
                if HasAnythingToSell() == false then break end
                if ClickGuiObject(itemBtn) then
                    itemsClicked = itemsClicked + 1
                    task.wait(0.07)
                end
            end
            if itemsClicked == 0 then
                -- as fallback, try clicking generic sell button if any
                if ui.sellButton then
                    log("No item rows found; clicking generic sell button.")
                    ClickGuiObject(ui.sellButton)
                    task.wait(0.35)
                else
                    log("No sellable rows/buttons detected in dialogue.")
                end
            else
                log("Selected", itemsClicked, "item rows to sell.")
                if ui.sellButton then
                    ClickGuiObject(ui.sellButton)
                    task.wait(0.15)
                end
            end
            -- confirm
            if ui.confirmButton then
                ClickGuiObject(ui.confirmButton)
            end
            task.wait(0.6)
        end

        -- give server some time to update inventory, and re-evaluate
        local t0 = tick()
        while tick() - t0 < SELL_ITEM_TIMEOUT do
            if not HasAnythingToSell() then
                log("Sell cycle complete — no sellable items remain.")
                return true
            end
            task.wait(0.2)
        end

        log("Sell attempt timed out waiting for inventory to update, retrying...")
    end

    if HasAnythingToSell() then
        log("Sell routine finished but sellable items remain; something prevented selling.")
        return false
    end

    return true
end

-- Exposed public function used by the farm: call this to perform selling once
local function SellNow()
    if not AutoSellEnabled then
        log("AutoSell disabled; skipping sell.")
        return true
    end
    local ok, result = pcall(PerformSellCycle)
    if not ok then
        log("SellNow error:", result)
        return false
    end
    return result
end

-- Optional: continuous background auto-sell task (if your invisfarm used background autosell)
local AutoSellTask = nil
local function StartAutoSellLoop(intervalSeconds)
    if AutoSellTask then return end
    intervalSeconds = intervalSeconds or 12 -- default small interval between checks
    AutoSellTask = task.spawn(function()
        while AutoSellEnabled do
            if HasAnythingToSell() then
                local ok = SellNow()
                if not ok then
                    log("Auto-sell failed; will retry on next cycle.")
                end
            end
            for i=1, math.max(1, intervalSeconds*10) do
                if not AutoSellEnabled then break end
                task.wait(0.1)
            end
        end
        AutoSellTask = nil
    end)
end

local function StopAutoSellLoop()
    AutoSellEnabled = false
    -- AutoSellTask will exit naturally
end

-- Hook up the exported functions back into the script environment:
-- Replace old selling calls to use SellNow(), StartAutoSellLoop, StopAutoSellLoop as needed.
-- Example:
--   if AutoSell then SellNow() end
-- or to run in background:
--   if AutoSell then StartAutoSellLoop(15) end

-- Provide functions to outer scope
getgenv().InvisFarm_SellNow = SellNow
getgenv().InvisFarm_StartAutoSellLoop = StartAutoSellLoop
getgenv().InvisFarm_StopAutoSellLoop = StopAutoSellLoop

log("New selling subsystem loaded. Call InvisFarm_SellNow() to run a manual sell cycle, or InvisFarm_StartAutoSellLoop(sec) to start background sells.")

-- End of invisfarmnosettings.lua
