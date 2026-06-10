--[[
    Vortex Addon - Real-Time External Example Addon
    Demonstrates how to fetch, interface with, and extend the running Vortex framework at runtime.
]]

local globalEnv = getgenv or function() return _G end

-- 1. Verify and capture the running framework from memory
local Vortex = globalEnv()._VortexCoreInstance
if not Vortex then
    warn("[Vortex Addon] Vortex core engine instance is not running! Make sure to run the main framework loader first.")
    return
end

-- 2. Define the Custom Addon module structure
local ExampleAddon = {}

function ExampleAddon.Init(VortexInstance)
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    VortexInstance.Notify("success", "Example Addon", "Example Addon initialized successfully!", 5)

    -- 3. Register custom helper function as an adapter on Vortex
    VortexInstance.RegisterAdapter("GetPing", function()
        return LocalPlayer and LocalPlayer:GetNetworkPing() * 1000 or 0
    end)

    -- 4. Listen to Vortex framework event signals in real-time
    VortexInstance.Signals.FeatureToggled:Connect(function(FeatureName, State)
        print(("[Example Addon] Reacted to Feature Toggle: %s -> %s"):format(FeatureName, tostring(State)))
        
        -- Send a notification when a feature is toggled to demonstrate the API
        VortexInstance.Notify("info", "Feature Toggle Logged", ("%s is now %s"):format(FeatureName, State and "ON" or "OFF"), 3)
    end)

    -- 5. Hook character spawn to track status using universal helper functions
    LocalPlayer.CharacterAdded:Connect(function(Character)
        task.wait(1)
        if VortexInstance.IsAlive(LocalPlayer) then
            local CurrentPing = VortexInstance.Call("GetPing") or 0
            print(("[Example Addon] Character loaded! Current ping: %.1fms"):format(CurrentPing))
        end
    end)

    print("[Example Addon] Addon loaded and hooked into Vortex successfully.")
end

-- Execute the initialization
local Success, Error = pcall(ExampleAddon.Init, Vortex)
if not Success then
    warn("[Example Addon] Failed to initialize addon:", tostring(Error))
end

return ExampleAddon
