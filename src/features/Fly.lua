--[[
    Combat Warriors - Flight Mechanic
    Features WASD movement using customized body mover linear velocity vectors.
]]

local Fly = {}

function Fly.Init(Vortex)
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local LocalPlayer = Players.LocalPlayer
    local Camera = Workspace.CurrentCamera
    local globalEnv = getgenv or function() return _G end

    local FlyEnabled = false

    local function UpdateFlightState()
        local HRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")  
        if not HRP then return end  

        if FlyEnabled then
            if not HRP:FindFirstChild("flyVel") then  
                local Attachment = Instance.new("Attachment")
                Attachment.Parent = HRP
                
                -- Call AntiCheatHandler via simplified framework method
                local LinearVelocity = Vortex.Call("@AntiCheatHandler", "createBodyMover", "LinearVelocity")  
                if LinearVelocity then
                    LinearVelocity.Name = "flyVel"  
                    LinearVelocity.Attachment0 = Attachment  
                    LinearVelocity.VectorVelocity = Vector3.new(0, 0, 0)  
                    LinearVelocity.MaxForce = 1e8  
                    LinearVelocity.Parent = HRP  
                end
            end
        else
            local FlyVel = HRP:FindFirstChild("flyVel")
            if FlyVel then
                FlyVel:Destroy()
            end
            local Attachment = HRP:FindFirstChildOfClass("Attachment")
            if Attachment and Attachment.Name == "Attachment" then
                Attachment:Destroy()
            end
        end  
    end

    -- Listen to the central FeatureToggled signal
    Vortex.Signals.FeatureToggled:Connect(function(featureName, state)
        if featureName == "Fly" then
            FlyEnabled = state
            UpdateFlightState()
        end
    end)

    -- Auto re-enable flight on respawn if active
    LocalPlayer.CharacterAdded:Connect(function()
        if FlyEnabled then
            task.wait(0.5)
            UpdateFlightState()
        end
    end)

    -- Hook movement tick
    RunService.RenderStepped:Connect(function()
        if not FlyEnabled then return end

        local HRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if HRP and HRP:FindFirstChild("flyVel") then
            local Move = Vector3.new()
            
            -- Accumulate vector direction based on key inputs
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then Move = Move + Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then Move = Move - Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then Move = Move - Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then Move = Move + Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then Move = Move + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then Move = Move - Vector3.new(0, 1, 0) end
            
            if Move.Magnitude > 0 then 
                Move = Move.Unit * (globalEnv().FlySpeed or 60) 
            end
            
            pcall(function()
                HRP.flyVel.VectorVelocity = Move
            end)
        end
    end)
end

return Fly
