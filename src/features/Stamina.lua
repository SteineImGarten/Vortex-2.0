--[[
    Combat Warriors - Stamina Boost
    Queries local character stamina parameters and configures faster regeneration scaling.
]]

local Stamina = {}

function Stamina.Init(Vortex)
    -- Retrieve default stamina handler using simplified framework call method
    local DefaultStamina = Vortex.Call("@DefaultStaminaHandlerClient", "getDefaultStamina")
    if not DefaultStamina then
        warn("[Stamina] DefaultStamina handler instance not found!")
        return
    end

    -- Boost Base Max Stamina & set current stamina level
    Vortex.Call("@Stamina", "setBaseMaxStamina", DefaultStamina, 350)
    Vortex.Call("@Stamina", "setStamina", DefaultStamina, 200)

    -- Configure gain delay and rates
    print(("[Stamina] Initial Gain Delay: %s | Gain Rate: %s"):format(tostring(DefaultStamina.gainDelay), tostring(DefaultStamina.gainPerSecond)))
    
    DefaultStamina.gainDelay = 0.05
    DefaultStamina.gainPerSecond = 75
    
    print(("[Stamina] Modified Gain Delay: %s | Gain Rate: %s"):format(tostring(DefaultStamina.gainDelay), tostring(DefaultStamina.gainPerSecond)))
end

return Stamina
