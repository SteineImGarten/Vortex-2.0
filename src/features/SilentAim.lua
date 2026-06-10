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

    -- Hook Ranged Weapon Fire Direction
    Vortex.Hook(
        "@RangedWeaponHandler",
        "calculateFireDirection",
        "SilentAim",
        function(Original, ...)
            local Ranged, MetaData = Vortex.RangedWeapon()
            local Args = { ... }

            if typeof(Args[1]) == "CFrame" and globalEnv().SilentAim then
                if MetaData and MetaData._itemConfig then
                    local Speed = MetaData._itemConfig.speed
                    local Gravity = MetaData._itemConfig.gravity
                    local Origin = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position

                    if Origin then
                        -- Query closest target inside screen FOV
                        local Target = Vortex.MouseTarget(nil, globalEnv().FOV)
                        if Target and Target.Character then
                            local TargetPartName = globalEnv().HitPart or "HumanoidRootPart"
                            local TargetPart = Target.Character:FindFirstChild(TargetPartName)
                            
                            if TargetPart then
                                -- Project Aim Vector using Kalman physics prediction integrated in Vortex
                                Args[1] = Vortex.Predict(
                                    TargetPart,
                                    Origin,
                                    Speed,
                                    false,
                                    Vector3.new(0, 0, 0) -- Vertical Gravity force vector
                                )
                            end
                        end
                    end
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
