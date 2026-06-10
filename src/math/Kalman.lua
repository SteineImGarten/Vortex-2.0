--[[
    Combat Warriors - Kalman Prediction Math
    Provides trajectory prediction based on velocity and gravity, with a 3D Kalman Filter template.
]]

local Kalman = {}
Kalman.__index = Kalman

local Workspace = game:GetService("Workspace")

-- 3D Kalman Filter Object definition
local KalmanFilter = {}
KalmanFilter.__index = KalmanFilter

function KalmanFilter.new()
    local self = setmetatable({}, KalmanFilter)
    self.X = Vector3.new(0, 0, 0)      -- State Estimate
    self.P = Vector3.new(1, 1, 1)      -- Estimate Covariance
    self.Q = Vector3.new(0.1, 0.1, 0.1)-- Process Noise Covariance
    self.R = Vector3.new(0.1, 0.1, 0.1)-- Measurement Noise Covariance
    self.K = Vector3.new(0, 0, 0)      -- Kalman Gain
    return self
end

function KalmanFilter:Predict()
    self.P = self.P + self.Q
end

function KalmanFilter:Update(Z)
    self.K = Vector3.new(
        self.P.X / (self.P.X + self.R.X),
        self.P.Y / (self.P.Y + self.R.Y),
        self.P.Z / (self.P.Z + self.R.Z)
    )
    self.X = self.X + Vector3.new(
        self.K.X * (Z.X - self.X.X),
        self.K.Y * (Z.Y - self.X.Y),
        self.K.Z * (Z.Z - self.X.Z)
    )
    self.P = Vector3.new(
        (1 - self.K.X) * self.P.X,
        (1 - self.K.Y) * self.P.Y,
        (1 - self.K.Z) * self.P.Z
    )
end

-- Draw dynamic prediction line in the screen viewport
local function DrawPredictionLine(Origin, Target, Color, Duration)
    local Camera = Workspace.CurrentCamera
    local Line = Drawing.new("Line")
    Line.Thickness = 1.5
    Line.Color = Color
    Line.Transparency = 1

    coroutine.wrap(function()
        local Start = tick()
        while tick() - Start < Duration do
            local OriginPos = Camera:WorldToViewportPoint(Origin)    
            local TargetPos = Camera:WorldToViewportPoint(Target)    

            Line.From = Vector2.new(OriginPos.X, OriginPos.Y)    
            Line.To = Vector2.new(TargetPos.X, TargetPos.Y)    
            Line.Visible = true    

            task.wait()    
        end    
        Line:Remove()
    end)()
end

-- Predict future coordinate based on velocity, projectile speed and gravity
function Kalman.Predict(Part, Origin, Speed, DrawLine, Gravity)
    local Velocity = Part.AssemblyLinearVelocity
    Speed = Speed or 300
    Gravity = Gravity or Vector3.new(0, -196.2, 0)

    local FlatTarget = Vector3.new(Part.Position.X, 0, Part.Position.Z)
    local FlatOrigin = Vector3.new(Origin.X, 0, Origin.Z)
    local HorizontalDistance = (FlatTarget - FlatOrigin).Magnitude

    -- Compute travel duration
    local TimeToHit = HorizontalDistance / Speed

    -- Calculate horizontal displacement
    local PredictedFlat = FlatTarget + Vector3.new(Velocity.X, 0, Velocity.Z) * TimeToHit

    -- Calculate gravity vertical offset
    local GravityOffset = 0.5 * Gravity * TimeToHit^2

    -- Combine into aiming coordinate
    local AimPosition = Vector3.new(
        PredictedFlat.X,
        Part.Position.Y - GravityOffset.Y,
        PredictedFlat.Z
    )

    if DrawLine then
        DrawPredictionLine(Origin, AimPosition, Color3.new(0, 1, 0), TimeToHit)
    end

    return CFrame.lookAt(Origin, AimPosition)
end

return Kalman
