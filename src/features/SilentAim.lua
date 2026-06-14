--[[
    Combat Warriors - Silent Aim
    Intercepts ranged weapon target paths, applying prediction math to direct shots to target joints.
]]

local SilentAim = {}

function SilentAim.Init(Vortex)
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local globalEnv = getgenv or function() return _G end

    -- Bind key listener to log silent aim state changes
    Vortex.Signals.FeatureToggled:Connect(function(featureName, state)
        if featureName == "SilentAim" then
            print("[SilentAim] Toggled State:", state)
        end
    end)

    Vortex.Hook(
        "@RangedWeaponHandler",
        "calculateFireDirection",
        "SilentAim",
        function(Original, ...)
            local Ranged, MetaData = Vortex.RangedWeapon()
            local Args = { ... }

            if typeof(Args[1]) == "CFrame" and globalEnv().SilentAim then
                -- Reconstruct MetaData using the working Vortex upvalue pattern
                if not MetaData and typeof(Ranged) == "Instance" and Ranged:IsA("Tool") then
                    local ItemId = Ranged:GetAttribute("ItemId")
                    if Vortex and ItemId then
                        local WeaponMeta = Vortex.Get("WeaponMetadata")
                        MetaData = WeaponMeta and WeaponMeta[ItemId]
                    end
                end

                if MetaData then
                    local Speed = MetaData.speed
                    local GravityValue = MetaData.gravity
                    local Character = LocalPlayer.Character
                    
                    -- REVERTED ORIGIN SOURCE: Direct HumanoidRootPart indexing
                    local Origin = Character and Character:FindFirstChild("HumanoidRootPart") and Character.HumanoidRootPart.Position

                    if Origin and Speed then
                        local Target = Vortex.MouseTarget(nil, globalEnv().FOV)
                        if Target and Target.Character then
                            local TargetPartName = globalEnv().HitPart or "HumanoidRootPart"
                            local TargetPart = Target.Character:FindFirstChild(TargetPartName)
                            
                            if TargetPart then
                                local FinalGravity = typeof(GravityValue) == "Vector3" and GravityValue or Vector3.new(0, 0, 0)
                                
                                local OldCFrame = Args[1]
                                Args[1] = Vortex.Predict(
                                    TargetPart,
                                    Origin,
                                    Speed,
                                    false,
                                    FinalGravity
                                )
                            end
                        end
                    end
                else
                    warn("[SilentAim DEBUG] Critical: MetaData structural lookup failed completely.")
                end
            end

            return Original(table.unpack(Args))
        end,
        { Spy = false }
    )

    -- Hook Ranged Weapon Reload Handler
    Vortex.Hook(
        "@RangedWeaponClient",
        "cancelReload",
        "SilentAimCancel",
        function(Original, ...)
            if globalEnv().NoReloadCancel then
                -- Bypass reload cancel (stop call)
                return
            end
            -- Forward execution to original handler if NoReloadCancel is false
            return Original(...)
        end,
        { Spy = false }
    )
end

return SilentAim
