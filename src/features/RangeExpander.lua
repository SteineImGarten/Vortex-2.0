--[[
    Combat Warriors - Range Expander
    Hooks client-side melee swing raycasts to strike multiple characters within range bounds.
]]

local RangeExpander = {}

function RangeExpander.Init(Vortex)
    local globalEnv = getgenv or function() return _G end

    -- Hook melee slash hit raycast processor
    Vortex.Hook(
        "@MeleeWeaponClient",
        "onSlashRayHit",
        "RangeExpander",
        function(Original, ...)
            local Args = {...}
            local HitPosition = Args[6]
            
            -- If expansion toggle is disabled or position is invalid, process single target
            if not globalEnv().RangeExpander or not HitPosition then 
                return Original(table.unpack(Args)) 
            end

            -- Query parts in range using framework-provided API
            local HitReach = globalEnv().HitReach or 25
            local Targets = Vortex.GetPartsInRange(HitPosition, HitReach, "Head")
            
            if Targets and #Targets > 0 then
                for _, Target in ipairs(Targets) do
                    -- Re-target inputs to match each candidate's location coordinates
                    Args[3] = Target
                    Args[4] = { Position = Target.Position }
                    Args[5] = Target.Position
                    Original(table.unpack(Args))
                end
            else
                return Original(table.unpack(Args))
            end
        end,
        { Spy = false }
    )
end

return RangeExpander
