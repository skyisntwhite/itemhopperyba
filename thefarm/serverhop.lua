-- serverhop.lua
local Http = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local PlaceId = game.PlaceId
local JobId = game.JobId
local SaveFile = "VisitedServersCache.json"

-- Persistent visited cache
local VisitedServersCache = {}
pcall(function()
    local cached = readfile(SaveFile)
    VisitedServersCache = Http:JSONDecode(cached)
end)

-- Preference toggle: default to false (or whatever default you prefer)
if getgenv().PreferLowPop == nil then
    getgenv().PreferLowPop = false
end

-- Convenience functions for runtime control
getgenv().SetPreferLowPop = function(val)
    getgenv().PreferLowPop = not not val
    pcall(function() print("[ServerHop] PreferLowPop set to", getgenv().PreferLowPop) end)
end

getgenv().TogglePreferLowPop = function()
    getgenv().PreferLowPop = not getgenv().PreferLowPop
    pcall(function() print("[ServerHop] PreferLowPop toggled to", getgenv().PreferLowPop) end)
end

local function ServerHop()
    local MaxRetries = 8
    local Attempt = 0

    while Attempt < MaxRetries do
        Attempt = Attempt + 1
        
        -- Dynamically set sortOrder based on PreferLowPop preference
        local sortOrder = getgenv().PreferLowPop and "Asc" or "Desc"
        local url = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=%s&limit=100"):format(PlaceId, sortOrder)
        
        local success, result = pcall(function()
            return Http:JSONDecode(game:HttpGet(url))
        end)

        if success and result and result.data then
            local candidates = {}
            for _, server in ipairs(result.data) do
                if server.id ~= JobId and server.playing < server.maxPlayers and not VisitedServersCache[server.id] then
                    table.insert(candidates, server)
                end
            end

            if #candidates > 0 then
                -- Sort candidate list based on user preference
                if getgenv().PreferLowPop then
                    table.sort(candidates, function(a, b) return a.playing < b.playing end)
                else
                    table.sort(candidates, function(a, b) return a.playing > b.playing end)
                end

                local target = candidates[1]

                VisitedServersCache[target.id] = true
                pcall(function()
                    writefile(SaveFile, Http:JSONEncode(VisitedServersCache))
                end)

                pcall(function()
                    print(("[ServerHop] Switching to server %s (%d/%d players) PreferLowPop=%s"):format(
                        target.id, target.playing, target.maxPlayers, tostring(getgenv().PreferLowPop)
                    ))
                end)

                TeleportService:TeleportToPlaceInstance(PlaceId, target.id, Player)
                task.wait(3)
            end
        end
        task.wait(1.5)
    end

    -- Clear cache and retry standard teleport if no candidates match
    VisitedServersCache = {}
    pcall(function()
        writefile(SaveFile, Http:JSONEncode(VisitedServersCache))
    end)
    TeleportService:Teleport(PlaceId, Player)
end

return ServerHop
