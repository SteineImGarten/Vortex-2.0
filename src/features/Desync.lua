--[[
    Combat Warriors - Desync Engine
    Simulates high replication latency via specific Roblox client FFlag toggles.
]]

local Desync = {}

function Desync.Init(Vortex)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Workspace = game:GetService("Workspace")
    local globalEnv = getgenv or function() return _G end

    -- Connect to the central FeatureToggled signal
    Vortex.Signals.FeatureToggled:Connect(function(featureName, state)
        if featureName == "Desync" then
            if state then
                -- Play sound and UI notification using framework wrapper
                Vortex.Notify("success", "Desync", "Desynced", 5)
                
                Vortex.Call("@SoundHandler", "playSound", {
                    soundObject = ReplicatedStorage.Shared.Assets.Sounds.Success2,
                    parent = Workspace.Sounds
                })
                
                -- Alter Roblox Replicator Fast Flag to trigger latency simulation
                setfflag("NextGenReplicatorEnabledWrite4", "True")
            else
                -- Disable latency simulation
                setfflag("NextGenReplicatorEnabledWrite4", "False")
            end
        end
    end)
end

return Desync
