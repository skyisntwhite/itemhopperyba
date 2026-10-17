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
-- Added services used by updated selling flow
local VirtualInputManager = pcall(function() return game:GetService("VirtualInputManager") end) and game:GetService("VirtualInputManager") or nil
local UserInputService = game:GetService("UserInputService")

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
            if item.Name == "Lucky Arrow" then
                Count += 1
            end
        end
    end)
    
    if Player.Backpack then
        for _, tool in pairs(Player.Backpack:GetChildren()) do
            if tool.Name == "Lucky Arrow" then
                Count += 1
            end
        end
    end
    
    if Player.Character then
        for _, tool in pairs(Player.Character:GetChildren()) do
            if tool.Name == "Lucky Arrow" then
                Count += 1
            end
        end
    end
    
    return Count
end

local function PersistLastSend(timestamp)
    pcall(function()
        writefile(LastSendFile, tostring(timestamp))
    end)
    getgenv().WebhookLastSend = timestamp
end

local function ReadLastSend()
    if getgenv().WebhookLastSend then
        return getgenv().WebhookLastSend
    end
    
    local t = 0
    pcall(function()
        if isfile and isfile(LastSendFile) then
            local raw = readfile(LastSendFile)
            t = tonumber(raw) or 0
        end
    end)
    
    if t > 0 then
        getgenv().WebhookLastSend = t
    end
    
    return t
end

local function SendWebhook(content, isEmbed)
    if not WebhookURL or WebhookURL == "" or WebhookURL:find("PUT_YOUR_WEBHOOK") then
        warn("Webhook URL not configured properly")
        return false
    end
    
    local payload
    if isEmbed then
        payload = content
    else
        payload = HttpService:JSONEncode({content = content})
    end
    
    local success = false
    
    pcall(function()
        if syn and syn.request then
            syn.request({
                Url = WebhookURL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = payload
            })
            success = true
            return
        end
        
        if request then
            request({
                Url = WebhookURL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = payload
            })
            success = true
            return
        end
        
        if http_request then
            http_request({
                Url = WebhookURL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = payload
            })
            success = true
            return
        end
        
        if HttpService.PostAsync then
            HttpService:PostAsync(WebhookURL, payload, Enum.HttpContentType.ApplicationJson)
            success = true
            return
        end
    end)
    
    if not success then
        warn("Failed to send webhook - no compatible HTTP function found")
    end
    
    return success
end

local function SendPeriodicStatus()
    if not UpdateMoneyRef() or not Money then 
        warn("Money reference not available for webhook")
        return 
    end
    
    local moneyVal = tonumber(Money.Value) or 0
    local luckyCount = GetLuckyArrowCount()

    local formattedMoney = tostring(moneyVal):reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,",")")

    local embed = HttpService:JSONEncode({
        embeds = {{
            title = "🎮 YBA Autofarm Status",
            description = string.format(
                "**💰 Money:** `$%s`\n**🤑 Lucky Arrows:** `%d`",
                formattedMoney,
                luckyCount
            ),
            color = 0x57F287,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            footer = {
                text = "Account: " .. Player.Name
            }
        }}
    })

    local success = SendWebhook(embed, true)

    if success then
        print("Webhook sent successfully")
        local currentTime = os.time()
        PersistLastSend(currentTime)
        return currentTime
    else
        warn("Webhook failed to send")
        return nil
    end
end

local LastSend = ReadLastSend()
local currentTime = os.time()

local shouldSendInitial = (currentTime - LastSend) >= SendInterval

if shouldSendInitial then
    task.spawn(function()
        task.wait(5)
        print("Attempting to send initial webhook...")
        local sentTime = SendPeriodicStatus()
        if sentTime then
            LastSend = sentTime
        end
    end)
else
    local timeLeft = SendInterval - (currentTime - LastSend)
    print(string.format("Webhook cooldown: %d minutes remaining", math.ceil(timeLeft / 60)))
end

game:GetService("RunService"):Set3dRenderingEnabled(false)

task.spawn(function()
    while true do
        task.wait(60)
        
        local now = os.time()
        local timeSinceLastSend = now - LastSend
        
        if timeSinceLastSend >= SendInterval then
            print(string.format("15 minutes elapsed (%d min), sending periodic update...", math.floor(timeSinceLastSend / 60)))
            local sentTime = SendPeriodicStatus()
            if sentTime then
                LastSend = sentTime
            else
                warn("Webhook send failed, will retry in 1 minute")
            end
        else
            local timeLeft = SendInterval - timeSinceLastSend
            if timeLeft % 300 == 0 then -- Print every 5 minutes
                print(string.format("Next webhook in %d minutes", math.ceil(timeLeft / 60)))
            end
        end
    end
end)

game:GetService("CoreGui").DescendantAdded:Connect(function(child)
    if child.Name == "ErrorPrompt" then
        local GrabError = child:FindFirstChild("ErrorMessage", true)
        repeat task.wait() until GrabError.Text ~= "Label"
        local Reason = GrabError.Text
        if Reason:match("kick") or Reason:match("You") or Reason:match("conn") or Reason:match("rejoin") then
            game:GetService("TeleportService"):Teleport(2809202155, Player)
        end
    end
end)

repeat task.wait() until game:IsLoaded() and Player and Player.Character

local Character = Player.Character
repeat task.wait() until Character:FindFirstChild("RemoteEvent") and Character:FindFirstChild("RemoteFunction")
local RemoteFunction, RemoteEvent = Character.RemoteFunction, Character.RemoteEvent
local HRP = Character.PrimaryPart

if not PlayerGui:FindFirstChild("HUD") then
    local HUD = ReplicatedStorage.Objects.HUD:Clone()
    HUD.Parent = PlayerGui
end

RemoteEvent:FireServer("PressedPlay")

task.spawn(function()
    wait(2)
    pcall(function()
        if PlayerGui:FindFirstChild("LoadingScreen1") then
            PlayerGui.LoadingScreen1:Destroy()
        end
    end)
    pcall(function()
        if PlayerGui:FindFirstChild("LoadingScreen") then
            PlayerGui.LoadingScreen:Destroy()
        end
    end)
    pcall(function()
        if workspace:FindFirstChild("LoadingScreen") and workspace.LoadingScreen:FindFirstChild("Song") then
            workspace.LoadingScreen.Song:Destroy()
        end
    end)
    pcall(function()
        if game.Lighting:FindFirstChild("DepthOfField") then
            game.Lighting.DepthOfField:Destroy()
        end
    end)
end)

local Has2x = MarketplaceService:UserOwnsGamePassAsync(Player.UserId, 14597778)

local oldMagnitude
oldMagnitude = hookmetamethod(Vector3.new(), "__index", newcclosure(function(self, index)
    local CallingScript = tostring(getcallingscript())
    if not checkcaller() and index == "magnitude" and CallingScript == "ItemSpawn" then
        return 0
    end
    return oldMagnitude(self, index)
end))

local ItemSpawnFolder = Workspace:WaitForChild("Item_Spawns"):WaitForChild("Items")

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

local function TeleportTo(Position)
    local HumanoidRootPart = GetCharacter("HumanoidRootPart")
    if HumanoidRootPart then
        local PositionType = typeof(Position)
        if PositionType == "CFrame" then
            HumanoidRootPart.CFrame = Position
        end
    end
end

local Map = workspace:FindFirstChild("Map")
if Map then
    local MapFolder = Instance.new("Folder", workspace)
    for i, MapPart in pairs(Map:GetChildren()) do
        task.spawn(function()
            MapPart.Parent = MapFolder
        end)
    end
    game.StarterGui:SetCore("SendNotification", {
        Title = "NoClip Bypass Activated",
        Text = "Enjoy sneaky farming!",
        Duration = 5
    })
end

local function ApplyNoClip()
    if not Player.Character then return end
    for _, part in pairs(Player.Character:GetDescendants()) do
        if part:IsA("BasePart") or part:IsA("UnionOperation") then
            part.CanCollide = false
        end
    end
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
    ["Clackers"] = 10,
    ["Steel Ball"] = 10,
    ["Dio's Diary"] = 10
}

if Has2x then
    for Index, Max in pairs(MaxItemAmounts) do
        MaxItemAmounts[Index] = Max * 2
    end
end

local function HasMaxItem(Item)
    local Count = 0
    for _, Tool in pairs(Player.Backpack:GetChildren()) do
        if Tool.Name == Item then
            Count += 1
        end
    end
    if MaxItemAmounts[Item] then
        return Count >= MaxItemAmounts[Item]
    else
        return false
    end
end

local function HasLuckyArrows()
    local Count = 0
    if Player.Backpack then
        for _, Tool in pairs(Player.Backpack:GetChildren()) do
            if Tool.Name == "Lucky Arrow" then
                Count += 1
            end
        end
    end
    if Player.Character then
        for _, Tool in pairs(Player.Character:GetChildren()) do
            if Tool.Name == "Lucky Arrow" then
                Count += 1
            end
        end
    end
    return Count >= 9
end

-- serverhop
local Http = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local PlaceId = game.PlaceId
local JobId = game.JobId
local SaveFile = "VisitedServers.json"
local Visited = {}

pcall(function()
    Visited = Http:JSONDecode(readfile(SaveFile))
end)

if not table.find(Visited, JobId) then
    table.insert(Visited, JobId)
    pcall(function()
        writefile(SaveFile, Http:JSONEncode(Visited))
    end)
end

local function GetServers(cursor)
    local url = "https://games.roblox.com/v1/games/"..PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
    if cursor then
        url = url .. "&cursor=" .. cursor
    end
    local response = game:HttpGet(url)
    return Http:JSONDecode(response)
end

local VisitedServersCache = {}
pcall(function()
    local cached = readfile("VisitedServersCache.json")
    VisitedServersCache = Http:JSONDecode(cached)
end)

local PreferLowPop = true

function ServerHop()
    local MaxRetries = 8
    local Attempt = 0

    local function FetchServers(cursor)
        local url = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100"):format(PlaceId)
        if cursor then
            url = url .. "&cursor=" .. cursor
        end
        local success, result = pcall(function()
            return Http:JSONDecode(game:HttpGet(url))
        end)
        return (success and result) or nil
    end

    while Attempt < MaxRetries do
        Attempt += 1
        local data = FetchServers()
        
        if data and data.data and #data.data > 0 then
            local candidates = {}

            for _, server in ipairs(data.data) do
                if server.id ~= JobId and server.playing < server.maxPlayers and not VisitedServersCache[server.id] then
                    table.insert(candidates, server)
                end
            end

            if #candidates > 0 then
                if PreferLowPop then
                    table.sort(candidates, function(a, b)
                        return a.playing < b.playing
                    end)
                end

                local target = candidates[1]

                VisitedServersCache[target.id] = true
                pcall(function()
                    writefile("VisitedServersCache.json", Http:JSONEncode(VisitedServersCache))
                end)

                print(("[ServerHop] Switching to server %s (%d/%d players)"):format(target.id, target.playing, target.maxPlayers))
                TeleportService:TeleportToPlaceInstance(PlaceId, target.id, Player)
                task.wait(3)
            end
        end
        
        task.wait(1.5)
    end

    print("[ServerHop] No suitable servers found → Resetting visited cache and retrying.")
    VisitedServersCache = {}
    pcall(function()
        writefile("VisitedServersCache.json", Http:JSONEncode(VisitedServersCache))
    end)
    task.wait(2)
    TeleportService:Teleport(PlaceId, Player)
end

local function GetItemInfo(Model)
    if Model and Model:IsA("Model") and Model.Parent and Model.Parent.Name == "Items" then
        local PrimaryPart = Model.PrimaryPart
        local Position = nil
        if PrimaryPart and PrimaryPart:IsA("BasePart") then
            Position = PrimaryPart.Position
        else
            local anyPart = Model:FindFirstChildWhichIsA("BasePart")
            if anyPart then
                Position = anyPart.Position
            end
        end

        local ProximityPrompt
        for _, ItemInstance in pairs(Model:GetDescendants()) do
            if ItemInstance:IsA("ProximityPrompt") and ItemInstance.MaxActivationDistance == 8 then
                ProximityPrompt = ItemInstance
                break
            end
        end

        if ProximityPrompt and Position then
            return {["Name"] = ProximityPrompt.ObjectText, ["ProximityPrompt"] = ProximityPrompt, ["Position"] = Position}
        end
    end
    return nil
end

getgenv().SpawnedItems = {}

ItemSpawnFolder.ChildAdded:Connect(function(Model)
    task.wait(0.5)
    if Model:IsA("Model") then
        local primary = Model.PrimaryPart or Model:FindFirstChildWhichIsA("BasePart")
        local timer = 0
        while not primary and timer < 2 do
            task.wait(0.2)
            timer = timer + 0.2
            primary = Model.PrimaryPart or Model:FindFirstChildWhichIsA("BasePart")
        end

        local ItemInfo = GetItemInfo(Model)
        if ItemInfo then
            table.insert(getgenv().SpawnedItems, { Model = Model, Info = ItemInfo })
            print(("SpawnedItems added: %s at (%.1f,%.1f,%.1f)"):format(ItemInfo.Name, ItemInfo.Position.X, ItemInfo.Position.Y, ItemInfo.Position.Z))
        end
    end
end)

local UzuKeeIsRetardedAndDoesntKnowHowToMakeAnAntiCheatOnTheServerSideAlsoVexStfuIKnowTheCodeIsBadYouDontNeedToTellMe = "  ___XP DE KEY"

local oldNc
oldNc = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local Method = getnamecallmethod()
    local Args = {...}
    if not checkcaller() and rawequal(self.Name, "Returner") and rawequal(Args[1], "idklolbrah2de") then
        return UzuKeeIsRetardedAndDoesntKnowHowToMakeAnAntiCheatOnTheServerSideAlsoVexStfuIKnowTheCodeIsBadYouDontNeedToTellMe
    end
    return oldNc(self, ...)
end))

task.wait(1)

if not PlayerGui:FindFirstChild("HUD") then
    local HUD = ReplicatedStorage.Objects.HUD:Clone()
    HUD.Parent = PlayerGui
end

task.wait()
repeat task.wait() until GetCharacter() and GetCharacter("RemoteEvent")

GetCharacter("RemoteEvent"):FireServer("PressedPlay")

TeleportTo(CFrame.new(978, -42, -49))

local function PlayAnimation(HumanoidCharacter, AnimationID, AnimationSpeed, Time)
    local CreatedAnimation = Instance.new("Animation")
    CreatedAnimation.AnimationId = AnimationID
    local animationTrack = HumanoidCharacter:FindFirstChildOfClass("Humanoid")
        :FindFirstChildOfClass("Animator"):LoadAnimation(CreatedAnimation)
    animationTrack:Play()
    animationTrack:AdjustSpeed(AnimationSpeed)
    animationTrack.Priority = Enum.AnimationPriority.Action4
    animationTrack.TimePosition = Time
    return animationTrack
end

local function GoInvisible()
    if not Player or not Player.Character then return end
    local char = Player.Character
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")

    if not humanoid or not hrp then
        repeat task.wait() 
            humanoid = char:FindFirstChildOfClass("Humanoid")
            hrp = char:FindFirstChild("HumanoidRootPart")
        until humanoid and hrp
    end

    local prevDisplayType = humanoid.DisplayDistanceType
    local prevNameDistance = humanoid.NameDisplayDistance or 100
    local prevAutoRotate = humanoid.AutoRotate

    local HUD = PlayerGui:FindFirstChild("HUD")
    if HUD then HUD.Parent = nil end

    local ok, animTrack = pcall(function()
        local a = Instance.new("Animation")
        a.AnimationId = "rbxassetid://7189062263"
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return nil end
        local animator = hum:FindFirstChildOfClass("Animator") or hum:FindFirstChildOfClass("Humanoid")
        if not animator then return nil end
        local track = animator:LoadAnimation(a)
        track.Priority = Enum.AnimationPriority.Action4
        track:Play()
        track:AdjustSpeed(0)
        track.TimePosition = 5
        return track
    end)

    pcall(function()
        Player.Character = nil
    end)
    if ok and animTrack then
        pcall(function() animTrack:Stop() end)
    end
    pcall(function()
        Player.Character = char
    end)
    task.wait(0.03)
    if hrp and hrp.Parent then
        pcall(function() hrp.CFrame = hrp.CFrame end)
    end

    local existing = char:FindFirstChild("InvisibilityHighlight")
    if existing then
        pcall(function() existing:Destroy() end)
    end
    local Highlight = Instance.new("Highlight")
    Highlight.Name = "InvisibilityHighlight"
    Highlight.Parent = char
    Highlight.Enabled = true

    pcall(function()
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        humanoid.NameDisplayDistance = 0
    end)

    pcall(function()
        humanoid.AutoRotate = prevAutoRotate
    end)

    if HUD then HUD.Parent = PlayerGui end
end


task.spawn(function()
    while task.wait(0.15) do
        local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
                local id = track.Animation and track.Animation.AnimationId
                if id then
                    if id ~= "rbxassetid://7189062263" then
                        -- Pickups + generic idle re-sync animations get stopped
                        pcall(function() track:Stop() end)
                    end
                end
            end
        end
    end
end)

GoInvisible()

local TPBypass
TPBypass = hookfunction(getrawmetatable(game).__namecall, newcclosure(function(self, ...)
    local args = { ... }
    if self.Name == "Returner" and args[1] == "idklolbrah2de" then
        return "  ___XP DE KEY"
    end
    return TPBypass(self, ...)
end))

GoInvisible()

task.wait(5)

local HumanoidRootPart = GetCharacter("HumanoidRootPart")
local SafeZone = CFrame.new(978, -42, -49)
local BodyVelocity = Instance.new("BodyVelocity")
BodyVelocity.Velocity = Vector3.new(0, 0, 0)

ApplyNoClip()
RunService.Heartbeat:Connect(ApplyNoClip) -- Maintain continuously

repeat
    for i = #getgenv().SpawnedItems, 1, -1 do
        local entry = getgenv().SpawnedItems[i]
        if not entry then
            table.remove(getgenv().SpawnedItems, i)
        else
            local Model = entry.Model
            local ItemInfo = entry.Info

            if not Model or not Model.Parent then
                table.remove(getgenv().SpawnedItems, i)
            else
                HumanoidRootPart = GetCharacter("HumanoidRootPart") or HumanoidRootPart
                if HumanoidRootPart then
                    local Name = ItemInfo.Name
                    if not HasMaxItem(Name) then
                        local ProximityPrompt = ItemInfo.ProximityPrompt
                        local Position = (Model.PrimaryPart and Model.PrimaryPart:IsA("BasePart") and Model.PrimaryPart.Position) or ItemInfo.Position

                        table.remove(getgenv().SpawnedItems, i)

                        if ProximityPrompt and ProximityPrompt.Parent then
                            BodyVelocity.Parent = HumanoidRootPart
                            HumanoidRootPart.CFrame = CFrame.new(Position.X, Position.Y - 25, Position.Z)
                            task.wait(.4)
                            pcall(fireproximityprompt, ProximityPrompt)
                            task.wait(.55)
                            HumanoidRootPart.CFrame = SafeZone
                        end
                    else
                        table.remove(getgenv().SpawnedItems, i)
                    end
                end
            end
        end
    end
    task.wait(0.6)
until #getgenv().SpawnedItems == 0

if BodyVelocity and BodyVelocity.Parent then
    BodyVelocity:Destroy()
end

-- Updated selling mechanics adapted from JTpo4ital-loh.lua.txt
-- This replaces the old EndDialogue remote-based sell with a dialogue-driven flow that matches
-- newer YBA merchant dialog behavior.

-- Helpers for dialogue/merchant interaction
local function normalizeText(text)
    text = tostring(text or ""):lower()
    text = text:gsub("[%c%p]", " ")
    text = text:gsub("%s+", " ")
    return text:match("^%s*(.-)%s*") or ""
end

local function getButtonText(btn)
    if not btn then return "" end
    if btn:IsA("TextButton") and btn.Text ~= "" then return btn.Text end
    for _, child in ipairs(btn:GetDescendants()) do
        if child:IsA("TextLabel") and child.Text ~= "" then return child.Text end
    end
    return ""
end

local function isActuallyVisible(obj)
    if not obj or not obj.Parent then return false end
    if obj:IsA("GuiObject") and obj.Visible == false then return false end
    local parent = obj.Parent
    while parent and parent ~= Player.PlayerGui do
        if parent:IsA("GuiObject") and parent.Visible == false then return false end
        parent = parent.Parent
    end
    return true
end

local function getDialogueGui()
    local direct = Player.PlayerGui:FindFirstChild("DialogueGui")
    if direct then return direct end
    for _, obj in ipairs(Player.PlayerGui:GetChildren()) do
        if tostring(obj.Name):lower():find("dialog", 1, true) then
            return obj
        end
    end
    return nil
end

local function getVisibleDialogueButtons()
    local dlg = getDialogueGui()
    if not dlg then return {} end
    local buttons = {}
    for _, obj in ipairs(dlg:GetDescendants()) do
        if obj:IsA("GuiButton") and isActuallyVisible(obj) then
            local text = getButtonText(obj)
            if normalizeText(text) ~= "" then
                table.insert(buttons, {
                    Button = obj,
                    Text = text,
                    Normalized = normalizeText(text),
                })
            end
        end
    end
    return buttons
end

local function clickButton(btn)
    if not btn or not btn.Parent then return false end
    -- Prefer VirtualInputManager for reliable clicks, fallback to firesignal/getconnections
    if VirtualInputManager then
        local absPos = btn.AbsolutePosition
        local absSize = btn.AbsoluteSize
        local x = absPos.X + absSize.X / 2
        local y = absPos.Y + absSize.Y / 2
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
        end)
        return true
    end

    if firesignal then
        pcall(function() firesignal(btn.MouseButton1Click) end)
        return true
    elseif getconnections then
        local ok = pcall(function()
            for _, c in ipairs(getconnections(btn.MouseButton1Click)) do
                pcall(function() c.Function() end)
            end
        end)
        if ok then return true end
    end
    return false
end

local NEGATIVE_WORDS = {
    "buy", "leave", "cancel", "nevermind", "never mind",
    "no thanks", "no thank", "goodbye", "exit", "nothing",
}

local function containsAny(text, words)
    for _, word in ipairs(words) do
        if text:find(word, 1, true) then return true end
    end
    return false
end

local function scoreSellOption(entry)
    local text = entry.Normalized
    if text == "" then return -math.huge end
    if containsAny(text, NEGATIVE_WORDS) then return -1000 end

    local score = 0
    local hasSell = text:find("sell", 1, true) ~= nil
    local hasAll = text:find("all", 1, true) ~= nil
    local hasEverything = text:find("everything", 1, true) ~= nil
    local hasMax = text:find("max", 1, true) ~= nil

    if hasSell and (hasAll or hasEverything or hasMax) then score = score + 220 end
    if hasAll or hasEverything or hasMax then score = score + 150 end
    if hasSell then score = score + 100 end
    if text:find("this", 1, true) and hasSell then score = score + 30 end
    if text:find("item", 1, true) and hasSell then score = score + 20 end
    if text:find("deal", 1, true) then score = score + 90 end
    if text:find("confirm", 1, true) then score = score + 80 end
    if text == "yes" or text:find("yes ", 1, true) == 1 then score = score + 70 end
    if text == "ok" or text == "okay" or text:find("sure", 1, true) then score = score + 55 end

    local quantity = tonumber(text:match("(%d+)%s*x")) or tonumber(text:match("sell%s+(%d+)"))
    if quantity then score = score + math.min(quantity, 50) end

    return score
end

local function waitForDialogueButtons(timeout)
    timeout = timeout or 3
    local started = tick()
    while tick() - started < timeout do
        local buttons = getVisibleDialogueButtons()
        if #buttons > 0 then return buttons end
        task.wait(0.1)
    end
    return {}
end

local function chooseBestSellButton(buttons)
    local best, bestScore = nil, -math.huge
    for _, entry in ipairs(buttons) do
        local s = scoreSellOption(entry)
        if s > bestScore then
            bestScore = s
            best = entry
        end
    end
    if bestScore <= 0 then return nil end
    return best
end

local function closeDialogueIfOpen()
    local dlg = getDialogueGui()
    if not dlg then return end
    local buttons = getVisibleDialogueButtons()
    for _, entry in ipairs(buttons) do
        local t = entry.Normalized
        if t:find("leave", 1, true) or t:find("cancel", 1, true)
            or t:find("nevermind", 1, true) or t:find("never mind", 1, true)
            or t:find("goodbye", 1, true) or t:find("exit", 1, true) then
            clickButton(entry.Button)
            task.wait(0.2)
            return
        end
    end
end

local function countItem(name)
    local count = 0
    if Player.Backpack then
        for _, tool in ipairs(Player.Backpack:GetChildren()) do
            if tool.Name == name then count = count + 1 end
        end
    end
    if Player.Character then
        for _, obj in ipairs(Player.Character:GetChildren()) do
            if obj:IsA("Tool") and obj.Name == name then count = count + 1 end
        end
    end
    return count
end

local function equipTool(itemName)
    local char = Player.Character
    local hum = char and char:FindFirstChildWhichIsA("Humanoid")
    if not hum then return nil end
    local tool = Player.Backpack:FindFirstChild(itemName)
    if not tool and char then tool = char:FindFirstChild(itemName) end
    if not tool then return nil end
    if tool.Parent == Player.Backpack then
        local ok = pcall(function() hum:EquipTool(tool) end)
        if not ok then return nil end
        task.wait(0.08)
    end
    local deadline = tick() + 0.35
    while tool.Parent ~= char and tick() < deadline do task.wait() end
    if tool.Parent ~= char then return nil end
    return tool
end

local function runMerchantSellDialogue(itemName, beforeCount)
    local lastOptions = ""
    local repeated = 0

    for step = 1, 7 do
        if countItem(itemName) < beforeCount then return true end

        local buttons = waitForDialogueButtons(step == 1 and 3 or 2)
        if #buttons == 0 then
            task.wait(0.35)
            if countItem(itemName) < beforeCount then return true end
            return false
        end

        local description = ""
        for _, e in ipairs(buttons) do description = description .. e.Text .. " | " end

        if description == lastOptions then
            repeated = repeated + 1
        else
            repeated = 0
            lastOptions = description
        end

        if repeated >= 2 then return false end

        local chosen = chooseBestSellButton(buttons)
        if not chosen then return false end

        if not clickButton(chosen.Button) then return false end
        task.wait(0.5)
    end

    return countItem(itemName) < beforeCount
end

local function getSellableItems()
    local items = {}
    local seen = {}
    local function addItem(name)
        if not seen[name] and SellItems[name] then
            seen[name] = true
            table.insert(items, name)
        end
    end
    if Player.Backpack then
        for _, tool in ipairs(Player.Backpack:GetChildren()) do
            if tool:IsA("Tool") then addItem(tool.Name) end
        end
    end
    if Player.Character then
        for _, obj in ipairs(Player.Character:GetChildren()) do
            if obj:IsA("Tool") then addItem(obj.Name) end
        end
    end
    return items
end

local sellSpamThread = nil
local sellingNow = false

local function startSellMouseSpam(x, y)
    if sellSpamThread then return end
    if not x or not y then return end
    if not VirtualInputManager then return end
    sellSpamThread = task.spawn(function()
        while sellingNow do
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
                task.wait(0.01)
                VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
            end)
            task.wait(0.5)
        end
    end)
end

local function stopSellMouseSpam()
    if sellSpamThread then
        pcall(function() task.cancel(sellSpamThread) end)
        sellSpamThread = nil
    end
end

local function findMerchantPrompt()
    local dlgFolder = ReplicatedStorage:FindFirstChild("Dialogue")
    if dlgFolder then
        local merchant = dlgFolder:FindFirstChild("Merchant", true)
        if merchant then
            local prompt = merchant:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt then return prompt end
        end
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            local parent = obj.Parent
            local matched = false
            local depth = 0
            while parent and parent ~= workspace and depth < 6 do
                if tostring(parent.Name):lower():find("merchant", 1, true) then
                    matched = true
                    break
                end
                parent = parent.Parent
                depth = depth + 1
            end
            local otext = normalizeText(obj.ObjectText)
            local atext = normalizeText(obj.ActionText)
            if matched or otext:find("merchant", 1, true) or atext:find("merchant", 1, true) then
                return obj
            end
        end
    end
    return nil
end

local function sellAllNow()
    if sellingNow then return false, "Already selling" end

    local merchantPrompt = findMerchantPrompt()
    if not merchantPrompt then return false, "Merchant not found" end

    local toSell = getSellableItems()
    if #toSell == 0 then return false, "Nothing to sell" end

    sellingNow = true

    -- optional mouse spam to help click through busy dialogs (values chosen as reasonable defaults)
    startSellMouseSpam(1236, 681)

    local soldTypes = 0
    for _, itemName in ipairs(toSell) do
        if not sellingNow then break end
        local initialCount = countItem(itemName)
        if initialCount > 0 then
            equipTool(itemName)
            closeDialogueIfOpen()
            pcall(function() fireproximityprompt(merchantPrompt) end)
            task.wait(0.45)

            local before = countItem(itemName)
            runMerchantSellDialogue(itemName, before)
            task.wait(0.5)

            local after = countItem(itemName)
            if after < initialCount then soldTypes = soldTypes + 1 end
            closeDialogueIfOpen()
        end
        task.wait(0.05)
    end

    sellingNow = false
    stopSellMouseSpam()
    print("Auto Sell complete. Sold types: " .. soldTypes .. "/" .. #toSell)
    return true, "Sold types: " .. soldTypes .. "/" .. #toSell
end

-- Replace old AutoSellScanAndSell with a call to new sellAllNow flow
local function AutoSellScanAndSell()
    if not AutoSell then
        print("AutoSell disabled; skipping selling.")
        return
    end

    local items = getSellableItems()
    if #items == 0 then
        print("No sellable items found; skipping merchant interaction.")
        return
    end

    print("Found items to sell, proceeding with dialogue-based merchant interaction...")
    local ok, msg = pcall(function() return sellAllNow() end)
    if not ok then
        warn("AutoSell failed:", msg)
    end
end

AutoSellScanAndSell()

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
    
    if HasLuckyArrows() then
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

task.spawn(AttemptBuyLuckyBeforeHop)

task.wait(1.5)

print("Farming complete - initiating ServerHop to move to next server.")
if not table.find(Visited, JobId) then
    table.insert(Visited, JobId)
    pcall(function() writefile(SaveFile, Http:JSONEncode(Visited)) end)
end
task.wait(0.4)
ServerHop()

while true do
    ServerHop()
    task.wait(3)
end
