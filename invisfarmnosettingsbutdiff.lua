-- einsteinian, copilot, and modern architecture integration
-- Upgraded for YBA v1.7974+ Dialogue & Zero-Delay Selling Mechanics

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
print("Loaded Upgraded InvisFarm Script.")

-- Services
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local PlayerGui = Player:WaitForChild("PlayerGui")
local VirtualInputManager = pcall(function() return game:GetService("VirtualInputManager") end) and game:GetService("VirtualInputManager") or nil

local WebhookURL = Config.WebhookURL
local LastSendFile = "webhook_lastsend.txt"
local SendInterval = Config.SendInterval
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

local MaxItemAmounts = {
    ["Gold Coin"] = 45,
    ["Rokakaka"] = 25,
    ["Pure Rokakaka"] = 10,
    ["Mysterious Arrow"] = 25,
    ["Diamond"] = 30,
    ["Ancient Scroll"] = 10,
    ["Caesar's Headband"] = 10,
    ["Stone Mask"] = 10,
    ["Rib Cage of The Saint's Corpse"] = 20,
    ["Quinton's Glove"] = 10,
    ["Zeppeli's Hat"] = 10,
    ["Lucky Arrow"] = 10,
    ["Lucky Stone Mask"] = 10,
    ["Clackers"] = 10,
    ["Steel Ball"] = 10,
    ["Dio's Diary"] = 10
}

local Has2x = false
pcall(function()
    Has2x = MarketplaceService:UserOwnsGamePassAsync(Player.UserId, 14597778)
end)
if Has2x then
    for Index, Max in pairs(MaxItemAmounts) do
        MaxItemAmounts[Index] = Max * 2
    end
end

local function CountItem(name)
    local count = 0
    pcall(function()
        local inv = Player:WaitForChild("PlayerStats", 2):WaitForChild("Inventory", 2)
        for _, item in pairs(inv:GetChildren()) do
            if item.Name == name then count += 1 end
        end
    end)
    if Player.Backpack then
        for _, tool in pairs(Player.Backpack:GetChildren()) do
            if tool.Name == name then count += 1 end
        end
    end
    if Player.Character then
        for _, tool in pairs(Player.Character:GetChildren()) do
            if tool.Name == name then count += 1 end
        end
    end
    return count
end

local function HasMaxItem(Item)
    local count = CountItem(Item)
    local cap = MaxItemAmounts[Item] or 10
    return count >= cap
end

local function GetLuckyArrowCount()
    return CountItem("Lucky Arrow")
end

local function SendWebhook(content, isEmbed)
    if not WebhookURL or WebhookURL == "" or WebhookURL:find("PUT_YOUR_WEBHOOK") then return false end
    local payload = isEmbed and content or HttpService:JSONEncode({content = content})
    local success = false
    pcall(function()
        if syn and syn.request then syn.request({Url = WebhookURL, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload}); success = true; return end
        if request then request({Url = WebhookURL, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload}); success = true; return end
        if http_request then http_request({Url = WebhookURL, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload}); success = true; return end
        HttpService:PostAsync(WebhookURL, payload, Enum.HttpContentType.ApplicationJson)
        success = true
    end)
    return success
end

local function SendPeriodicStatus()
    if not UpdateMoneyRef() or not Money then return end
    local moneyVal = tonumber(Money.Value) or 0
    local luckyCount = GetLuckyArrowCount()
    local formattedMoney = tostring(moneyVal):reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","")
    local embed = HttpService:JSONEncode({
        embeds = {{
            title = "🎮 YBA Autofarm Status",
            description = string.format("**💰 Money:** `$%s`\n**🤑 Lucky Arrows:** `%d`", formattedMoney, luckyCount),
            color = 0x57F287,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            footer = { text = "Account: " .. Player.Name }
        }}
    })
    SendWebhook(embed, true)
end

-- Error Prompt Auto-Reconnection Handler
game:GetService("CoreGui").DescendantAdded:Connect(function(child)
    if child.Name == "ErrorPrompt" then
        local GrabError = child:FindFirstChild("ErrorMessage", true)
        repeat task.wait() until GrabError and GrabError.Text ~= "Label"
        local Reason = GrabError.Text
        if Reason:match("kick") or Reason:match("You") or Reason:match("conn") or Reason:match("rejoin") then
            TeleportService:Teleport(game.PlaceId, Player)
        end
    end
end)

local Character = Player.Character
repeat task.wait() until Character:FindFirstChild("RemoteEvent") and Character:FindFirstChild("RemoteFunction")
local RemoteEvent = Character.RemoteEvent

if not PlayerGui:FindFirstChild("HUD") then
    local HUD = ReplicatedStorage.Objects.HUD:Clone()
    HUD.Parent = PlayerGui
end

RemoteEvent:FireServer("PressedPlay")

-- Anti-Cheat Hooks
pcall(function()
    local oldMagnitude
    oldMagnitude = hookmetamethod(Vector3.new(), "__index", newcclosure(function(self, index)
        local CallingScript = tostring(getcallingscript())
        if not checkcaller() and index == "magnitude" and CallingScript == "ItemSpawn" then
            return 0
        end
        return oldMagnitude(self, index)
    end))
end)

pcall(function()
    local oldNc
    oldNc = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local Method = getnamecallmethod()
        local Args = {...}
        if not checkcaller() and rawequal(self.Name, "Returner") and rawequal(Args[1], "idklolbrah2de") then
            return "  ___XP DE KEY"
        end
        return oldNc(self, ...)
    end))
end)

-- Invisibility State Function
local function GoInvisible()
    if not Player or not Player.Character then return end
    local char = Player.Character
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp then return end

    local prevAutoRotate = humanoid.AutoRotate
    local HUD = PlayerGui:FindFirstChild("HUD")
    if HUD then HUD.Parent = nil end

    pcall(function()
        local a = Instance.new("Animation")
        a.AnimationId = "rbxassetid://7189062263"
        local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid
        local track = animator:LoadAnimation(a)
        track.Priority = Enum.AnimationPriority.Action4
        track:Play()
        track:AdjustSpeed(0)
        track.TimePosition = 5
    end)

    pcall(function() Player.Character = nil end)
    task.wait(0.03)
    pcall(function() Player.Character = char end)
    task.wait(0.03)

    if hrp and hrp.Parent then
        pcall(function() hrp.CFrame = hrp.CFrame end)
    end

    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    humanoid.AutoRotate = prevAutoRotate
    if HUD then HUD.Parent = PlayerGui end
end

GoInvisible()

task.spawn(function()
    while task.wait(0.15) do
        local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
                local id = track.Animation and track.Animation.AnimationId
                if id and id ~= "rbxassetid://7189062263" then
                    pcall(function() track:Stop() end)
                end
            end
        end
    end
end)

-- Modern Upgraded Selling Mechanics (Integrated from Inventory.lua structure)
local function FindMerchantPrompt()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            local parent = obj.Parent
            local matched = false
            for _ = 1, 4 do
                if parent and tostring(parent.Name):lower():find("merchant", 1, true) then
                    matched = true
                    break
                end
                parent = parent and parent.Parent
            end
            if matched or tostring(obj.ObjectText):lower():find("merchant", 1, true) then
                return obj
            end
        end
    end
    return nil
end

local function EquipTool(itemName)
    local char = Player.Character
    local hum = char and char:FindFirstChildWhichIsA("Humanoid")
    if not hum then return nil end
    local tool = Player.Backpack:FindFirstChild(itemName) or (char and char:FindFirstChild(itemName))
    if not tool then return nil end
    if tool.Parent == Player.Backpack then
        pcall(function() hum:EquipTool(tool) end)
        task.wait(0.08)
    end
    return tool
end

local function ModernSellAll()
    if not AutoSell then return end
    local merchantPrompt = FindMerchantPrompt()
    if not merchantPrompt then
        print("[Inventory] Merchant prompt not found for selling.")
        return
    end

    for itemName, sell in pairs(SellItems) do
        if sell and CountItem(itemName) > 0 then
            local before = CountItem(itemName)
            local tool = EquipTool(itemName)
            if tool then
                pcall(function() fireproximityprompt(merchantPrompt) end)
                task.wait(0.5)
                
                -- Attempt fast dialogue option injection/clicks matching YBA v1.7974+ dialogue UI
                pcall(function()
                    local dlg = PlayerGui:FindFirstChild("DialogueGui")
                    if dlg then
                        for _, btn in ipairs(dlg:GetDescendants()) do
                            if btn:IsA("GuiButton") and btn.Visible then
                                local text = tostring(btn.Text or ""):lower()
                                if text:find("sell") or text:find("all") or text:find("yes") or text:find("option1") then
                                    if type(firesignal) == "function" then
                                        firesignal(btn.MouseButton1Click)
                                    else
                                        btn.Activated:Fire()
                                    end
                                    task.wait(0.2)
                                end
                            end
                        end
                    end
                end)
                task.wait(0.5)
            end
        end
    end
end

local function BuyLuckyArrow()
    if not BuyLucky then return end
    if UpdateMoneyRef() and Money.Value >= 75000 and CountItem("Lucky Arrow") < 9 then
        pcall(function()
            local char = Player.Character
            local re = char and char:FindFirstChild("RemoteEvent")
            if re then
                re:FireServer("PurchaseShopItem", {["ItemName"] = "1x Lucky Arrow"})
            end
        end)
    end
end

-- Server Hopping Logic
local function ServerHop()
    local PlaceId = game.PlaceId
    local success, result = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100"):format(PlaceId)))
    end)
    if success and result and result.data then
        for _, server in ipairs(result.data) do
            if server.id ~= game.JobId and server.playing < server.maxPlayers then
                TeleportService:TeleportToPlaceInstance(PlaceId, server.id, Player)
                task.wait(3)
            end
        end
    end
    TeleportService:Teleport(PlaceId, Player)
end

-- Main Item Collection Loop
local ItemSpawnFolder = Workspace:WaitForChild("Item_Spawns"):WaitForChild("Items")
local SpawnedItems = {}

ItemSpawnFolder.ChildAdded:Connect(function(Model)
    task.wait(0.5)
    if Model:IsA("Model") then
        for _, v in pairs(Model:GetDescendants()) do
            if v:IsA("ProximityPrompt") then
                table.insert(SpawnedItems, {Model = Model, Prompt = v, Name = v.ObjectText})
            end
        end
    end
end)

task.spawn(function()
    while task.wait(1) do
        for i = #SpawnedItems, 1, -1 do
            local entry = SpawnedItems[i]
            if not entry or not entry.Model or not entry.Model.Parent then
                table.remove(SpawnedItems, i)
            else
                local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                if hrp and not HasMaxItem(entry.Name) then
                    hrp.CFrame = CFrame.new(entry.Model.PrimaryPart.Position.X, entry.Model.PrimaryPart.Position.Y - 25, entry.Model.PrimaryPart.Position.Z)
                    task.wait(0.3)
                    pcall(fireproximityprompt, entry.Prompt)
                    task.wait(0.4)
                    hrp.CFrame = CFrame.new(978, -42, -49)
                    table.remove(SpawnedItems, i)
                end
            end
        end
    end
end)

-- Periodic tasks (Selling, Purchasing, and Status Webhooks)
task.spawn(function()
    while task.wait(300) do
        ModernSellAll()
        BuyLuckyArrow()
        SendPeriodicStatus()
    end
end)

print("Upgraded InvisFarm initialized successfully with modern dialogue selling mechanics.")
