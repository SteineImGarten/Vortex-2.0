--[[
    Combat Warriors - Settings Configurator
    Safely initialises default settings variables in the global environment (getgenv) and Vortex.State.
]]

local Settings = {}

function Settings.LoadDefaults()
    local globalEnv = getgenv or function() return _G end
    local Vortex = globalEnv()._VortexCoreInstance

    local Defaults = {
        Keybinds = {
            Fly = Enum.KeyCode.V,
            Desync = Enum.KeyCode.B,
            SilentAim = Enum.KeyCode.M
        },
        HitPart = "HumanoidRootPart",
        FOV = 40,
        NoReloadCancel = false,
        SilentAim = false,
        Fly = false,
        DesyncEnabled = false,
        FlySpeed = 60,
        RangeExpander = false,
        HitReach = 25,
        AntiParry = false,
        FastSpawn = false,
        AntiRagdoll = false
    }

    -- Set default keys if they don't exist yet
    for Key, Val in pairs(Defaults) do
        if globalEnv()[Key] == nil then
            globalEnv()[Key] = Val
        elseif type(Val) == "table" and type(globalEnv()[Key]) == "table" then
            -- Deep copy/merge first level for sub-tables like Keybinds
            for SubKey, SubVal in pairs(Val) do
                if globalEnv()[Key][SubKey] == nil then
                    globalEnv()[Key][SubKey] = SubVal
                end
            end
        end

        -- Sync with Vortex State
        if Vortex then
            Vortex.State[Key] = globalEnv()[Key]
        end
    end

    if Vortex then
        Vortex.Keybinds = globalEnv().Keybinds
    end
end

return Settings
