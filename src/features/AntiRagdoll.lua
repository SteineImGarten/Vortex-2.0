--[[
    Combat Warriors - Anti-Ragdoll
    Overrides client transitions into ragdoll states to maintain character movement controls.
]]

local AntiRagdoll = {}

function AntiRagdoll.Init(Vortex)
    local globalEnv = getgenv or function() return _G end

    -- Hook Shared Ragdoll handler using simplified framework hook method
    Vortex.Hook(
        "@RagdollHandler",
        "toggleRagdoll",
        function(Original, ...)
            if globalEnv().AntiRagdoll then 
                return -- Suppress ragdoll activation
            end
            return Original(...)
        end
    )

    -- Hook Client-specific Ragdoll handler
    Vortex.Hook(
        "@RagdollHandlerClient",
        "toggleRagdoll",
        function(Original, ...)
            if globalEnv().AntiRagdoll then 
                return -- Suppress ragdoll activation
            end
            return Original(...)
        end
    )
end

return AntiRagdoll
