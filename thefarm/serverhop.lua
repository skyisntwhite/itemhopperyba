-- serverhop.lua
local Http = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local PlaceId = game.PlaceId
local JobId = game.JobId
local SaveFile = "VisitedServersCache.json"

local VisitedServersCache = {}
pcall(function()
    local cached = readfile(SaveFile)
    VisitedServersCache = Http:JSONDecode(cached)
end)

local function ServerHop()
    local MaxRetries = 8
    local Attempt = 0

    while Attempt < MaxRetries do
        Attempt += 1
        local url = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100"):format(PlaceId)
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
                table.sort(candidates, function(a, b) return a.playing < b.playing end)
                local target = candidates[1]

                VisitedServersCache[target.id] = true
                pcall(function()
                    writefile(SaveFile, Http:JSONEncode(VisitedServersCache))
                end)

                TeleportService:TeleportToPlaceInstance(PlaceId, target.id, Player)
                task.wait(3)
            end
        end
        task.wait(1.5)
    end

    VisitedServersCache = {}
    pcall(function()
        writefile(SaveFile, Http:JSONEncode(VisitedServersCache))
    end)
    TeleportService:Teleport(PlaceId, Player)
end

return ServerHop