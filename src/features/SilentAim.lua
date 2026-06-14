--[[
    Combat Warriors - Silent Aim
    Intercepts ranged weapon target paths, applying prediction math to direct shots to target joints.
]]

local SilentAim = {}

function SilentAim.Init(Vortex)
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local globalEnv = getgenv or function() return _G end

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
                    
                    local Origin = Args[1].Position
                    local OriginSource = "Incoming CFrame"

                    if not Origin and typeof(Ranged) == "Instance" and Ranged:IsA("Tool") then
                        local ToolPart = Ranged:FindFirstChild("Handle") or Ranged:FindFirstChildWhichIsA("BasePart")
                        if ToolPart then
                            Origin = ToolPart.Position
                            OriginSource = "Tool Part (" .. ToolPart.Name .. ")"
                        end
                    end

                    if not Origin and Character and Character:FindFirstChild("HumanoidRootPart") then
                        Origin = Character.HumanoidRootPart.Position
                        OriginSource = "HumanoidRootPart Fallback"
                    end

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

    Vortex.Hook(
        "@RangedWeaponClient",
        "cancelReload",
        "SilentAimCancel",
        function(Original, ...)
            if globalEnv().NoReloadCancel then
                return
            end
            return Original(...)
        end,
        { Spy = false }
    )
end

return SilentAim
