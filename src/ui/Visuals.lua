--[[
    Vortex Framework - Visual Renderings
    Handles screen overlays, drawings, and circles like the FOV visualizer.
]]

local Visuals = {}

function Visuals.Init(Vortex)
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local globalEnv = getgenv or function() return _G end

    -- Instantiate screen drawing FOV Circle
    local FovCircle = Drawing.new("Circle")
    FovCircle.Radius = globalEnv().FOV or 40
    FovCircle.Color = Color3.fromRGB(0, 255, 120) -- Sleek custom green/teal color
    FovCircle.Filled = false
    FovCircle.NumSides = 64 -- Smoother circle
    FovCircle.Transparency = 0.5
    FovCircle.Visible = false

    -- Hook render loop to track mouse cursor
    local Connection = RunService.RenderStepped:Connect(function()
        -- Sync radius with current global settings
        FovCircle.Radius = globalEnv().FOV or 40
        
        -- FOV is visible only when Silent Aim is enabled and active
        FovCircle.Visible = not not globalEnv().SilentAim

        if FovCircle.Visible then
            local MousePos = UserInputService:GetMouseLocation()
            FovCircle.Position = Vector2.new(MousePos.X, MousePos.Y)
        end
    end)

    return {
        Circle = FovCircle,
        Connection = Connection
    }
end

return Visuals
