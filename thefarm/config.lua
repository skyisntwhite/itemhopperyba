-- config.lua
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
return Config