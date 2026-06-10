--[[
    Combat Warriors - Fast Spawn
    Checks character select interfaces on RenderStepped to instantly request client spawn events.
]]

local FastSpawn = {}
local Connected = false

function FastSpawn.Init(Vortex)
    if Connected then return end
    Connected = true

    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local globalEnv = getgenv or function() return _G end

    -- Connect render frame loop
    RunService.RenderStepped:Connect(function()
        if not globalEnv().FastSpawn then return end

        local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
        local RoactUI = PlayerGui and PlayerGui:FindFirstChild("RoactUI")
        local MainMenu = RoactUI and RoactUI:FindFirstChild("MainMenu")

        if MainMenu then
            -- Invoke client spawn method through simplified framework call (fixed FrameWork -> Vortex bug)
            Vortex.Call("@SpawnHandlerClient", "spawnCharacter", true)
        end
    end)
end

return FastSpawn
