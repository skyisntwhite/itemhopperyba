-- items.lua
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local TeleportService = game:GetService("TeleportService")
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Error Prompt Rejoin Handler
game:GetService("CoreGui").DescendantAdded:Connect(function(child)
    if child.Name == "ErrorPrompt" then
        local GrabError = child:FindFirstChild("ErrorMessage", true)
        if GrabError then
            repeat task.wait() until GrabError.Text ~= "Label"
            local Reason = GrabError.Text
            if Reason:match("kick") or Reason:match("You") or Reason:match("conn") or Reason:match("rejoin") then
                TeleportService:Teleport(2809202155, Player)
            end
        end
    end
end)

-- Anti-Cheat / Remote / Magnitude Hooks
pcall(function()
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
end)

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

local Has2x = false
pcall(function()
    Has2x = MarketplaceService:UserOwnsGamePassAsync(Player.UserId, 14597778)
end)

local MaxItemAmounts = {
    ["Gold Coin"] = 45, ["Rokakaka"] = 25, ["Pure Rokakaka"] = 10,
    ["Mysterious Arrow"] = 25, ["Diamond"] = 30, ["Ancient Scroll"] = 10,
    ["Caesar's Headband"] = 10, ["Stone Mask"] = 10, ["Rib Cage of The Saint's Corpse"] = 20,
    ["Quinton's Glove"] = 10, ["Zeppeli's Hat"] = 10, ["Lucky Arrow"] = 10,
    ["Clackers"] = 10, ["Steel Ball"] = 10, ["Dio's Diary"] = 10
}

if Has2x then
    for Index, Max in pairs(MaxItemAmounts) do
        MaxItemAmounts[Index] = Max * 2
    end
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

local function TeleportTo(Position)
    local HumanoidRootPart = GetCharacter("HumanoidRootPart")
    if HumanoidRootPart and typeof(Position) == "CFrame" then
        HumanoidRootPart.CFrame = Position
    end
end

local function ApplyNoClip()
    if not Player.Character then return end
    for _, part in pairs(Player.Character:GetDescendants()) do
        if part:IsA("BasePart") or part:IsA("UnionOperation") then
            part.CanCollide = false
        end
    end
end
RunService.Heartbeat:Connect(ApplyNoClip)

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
        Player.Character = nil
        task.wait(0.03)
        Player.Character = char
        track:Stop()
    end)

    local existing = char:FindFirstChild("InvisibilityHighlight")
    if existing then existing:Destroy() end
    local Highlight = Instance.new("Highlight")
    Highlight.Name = "InvisibilityHighlight"
    Highlight.Parent = char

    pcall(function()
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        humanoid.NameDisplayDistance = 0
        humanoid.AutoRotate = prevAutoRotate
    end)

    if HUD then HUD.Parent = PlayerGui end
end

-- Animation blocker loop


local function HasMaxItem(Item)
    local Count = 0
    if Player.Backpack then
        for _, Tool in pairs(Player.Backpack:GetChildren()) do
            if Tool.Name == Item then Count += 1 end
        end
    end
    return MaxItemAmounts[Item] and Count >= MaxItemAmounts[Item] or false
end

local function GetItemInfo(Model)
    if Model and Model:IsA("Model") and Model.Parent and Model.Parent.Name == "Items" then
        local PrimaryPart = Model.PrimaryPart or Model:FindFirstChildWhichIsA("BasePart")
        local Position = PrimaryPart and PrimaryPart.Position
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

local function InitFarming()
    GoInvisible()
    task.wait(1)
    TeleportTo(CFrame.new(978, -42, -49))
    
    local ItemSpawnFolder = Workspace:WaitForChild("Item_Spawns"):WaitForChild("Items")
    getgenv().SpawnedItems = {}

    ItemSpawnFolder.ChildAdded:Connect(function(Model)
        task.wait(0.5)
        if Model:IsA("Model") then
            local ItemInfo = GetItemInfo(Model)
            if ItemInfo then
                table.insert(getgenv().SpawnedItems, { Model = Model, Info = ItemInfo })
            end
        end
    end)

    for _, Model in ipairs(ItemSpawnFolder:GetChildren()) do
        if Model:IsA("Model") then
            local ItemInfo = GetItemInfo(Model)
            if ItemInfo then
                table.insert(getgenv().SpawnedItems, { Model = Model, Info = ItemInfo })
            end
        end
    end

    local SafeZone = CFrame.new(978, -42, -49)
    local BodyVelocity = Instance.new("BodyVelocity")
    BodyVelocity.Velocity = Vector3.new(0, 0, 0)

    task.spawn(function()
        repeat
            for i = #getgenv().SpawnedItems, 1, -1 do
                local entry = getgenv().SpawnedItems[i]
                if not entry or not entry.Model or not entry.Model.Parent then
                    table.remove(getgenv().SpawnedItems, i)
                else
                    local Model = entry.Model
                    local ItemInfo = entry.Info
                    local HumanoidRootPart = GetCharacter("HumanoidRootPart")
                    if HumanoidRootPart then
                        local Name = ItemInfo.Name
                        if not HasMaxItem(Name) then
                            local ProximityPrompt = ItemInfo.ProximityPrompt
                            local Position = (Model.PrimaryPart and Model.PrimaryPart.Position) or ItemInfo.Position

                            table.remove(getgenv().SpawnedItems, i)

                            if ProximityPrompt and ProximityPrompt.Parent then
                                BodyVelocity.Parent = HumanoidRootPart
                                HumanoidRootPart.CFrame = CFrame.new(Position.X, Position.Y - 25, Position.Z)
                                task.wait(0.4)
                                pcall(fireproximityprompt, ProximityPrompt)
                                task.wait(0.55)
                                HumanoidRootPart.CFrame = SafeZone
                            end
                        else
                            table.remove(getgenv().SpawnedItems, i)
                        end
                    end
                end
            end
            task.wait(0.6)
        until false
    end)
end

return {
    InitFarming = InitFarming,
    GoInvisible = GoInvisible,
    TeleportTo = TeleportTo
}
