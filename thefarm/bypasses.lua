-- bypasses.lua
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Error Prompt / Rejoin Handler
game:GetService("CoreGui").DescendantAdded:Connect(function(child)
    if child.Name == "ErrorPrompt" then
        local GrabError = child:FindFirstChild("ErrorMessage", true)
        repeat task.wait() until GrabError and GrabError.Text ~= "Label"
        local Reason = GrabError.Text
        if Reason:match("kick") or Reason:match("You") or Reason:match("conn") or Reason:match("rejoin") then
            TeleportService:Teleport(2809202155, Player)
        end
    end
end)

-- Metamethod Hooks (Anti-Cheat Bypass)
local UzuKeeIsRetardedAndDoesntKnowHowToMakeAnAntiCheatOnTheServerSideAlsoVexStfuIKnowTheCodeIsBadYouDontNeedToTellMe = "  ___XP DE KEY"

pcall(function()
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

    if HUD then HUD.Parent = PlayerGui end
end

return {
    GoInvisible = GoInvisible,
    ApplyNoClip = ApplyNoClip
}