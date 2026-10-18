-- items.lua
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local MarketplaceService = game:GetService("MarketplaceService")

local Has2x = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(Player.UserId, 14597778) end) and MarketplaceService:UserOwnsGamePassAsync(Player.UserId, 14597778) or false

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

local function HasMaxItem(Item)
    local Count = 0
    if Player.Backpack then
        for _, Tool in pairs(Player.Backpack:GetChildren()) do
            if Tool.Name == Item then Count += 1 end
        end
    end
    return MaxItemAmounts[Item] and Count >= MaxItemAmounts[Item] or false
end

local function HasLuckyArrows()
    local Count = 0
    local function checkContainer(container)
        if container then
            for _, Tool in pairs(container:GetChildren()) do
                if Tool.Name == "Lucky Arrow" then Count += 1 end
            end
        end
    end
    checkContainer(Player.Backpack)
    checkContainer(Player.Character)
    return Count >= 9
end

local function GetItemInfo(Model)
    if Model and Model:IsA("Model") and Model.Parent and Model.Parent.Name == "Items" then
        local PrimaryPart = Model.PrimaryPart or Model:FindFirstChildWhichIsA("BasePart")
        local ProximityPrompt
        for _, ItemInstance in pairs(Model:GetDescendants()) do
            if ItemInstance:IsA("ProximityPrompt") and ItemInstance.MaxActivationDistance == 8 then
                ProximityPrompt = ItemInstance
                break
            end
        end
        if ProximityPrompt and PrimaryPart then
            return {["Name"] = ProximityPrompt.ObjectText, ["ProximityPrompt"] = ProximityPrompt, ["Position"] = PrimaryPart.Position}
        end
    end
    return nil
end

return {
    HasMaxItem = HasMaxItem,
    HasLuckyArrows = HasLuckyArrows,
    GetItemInfo = GetItemInfo
}