--[[
    Combat Warriors - HookLoader Legacy Wrapper
    Forwards all legacy imports to the unified Vortex framework.
]]

local globalEnv = getgenv or function() return _G end
return globalEnv()._VortexCoreInstance or import("core/Vortex")
