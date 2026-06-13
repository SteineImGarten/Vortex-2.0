--[[
    Combat Warriors - Stamina Boost Updated.
    Queries local character stamina parameters and configures faster regeneration scaling.
]]

local Stamina = {}

function Stamina.Init(Vortex)
    local LastStamina = nil
    local LastCheckTime = 0

    Vortex.Hook("@DefaultStaminaHandlerClient", "getDefaultStamina", "DefiAuto", function(Original, ...)
            
        local StaminaTable = Original(...)

        if type(StaminaTable) == "table" then
                
            StaminaTable._maxStamina = getgenv().MAX_STAMINA or 250
            StaminaTable._baseMaxStamina = getgenv().MAX_STAMINA or 250
            StaminaTable.gainDelay = getgenv().GAIN_DELAY or 0.05

            local CurrentStamina = StaminaTable._stamina

            local CurrentTime = os.clock()
            if LastStamina and CurrentTime ~= LastCheckTime then
                
                if CurrentStamina < LastStamina then
                        
                    local RawDrain = LastStamina - CurrentStamina
                    local SlowedDrain = RawDrain * (getgenv().DRAIN_FACTOR or 1)
                        
                    StaminaTable._stamina = LastStamina - SlowedDrain
                    
                elseif CurrentStamina > LastStamina then
                        
                    local RawGain = CurrentStamina - LastStamina
                    local BoostedGain = RawGain * (getgenv().GAIN_FACTOR or 1)
                        
                    StaminaTable._stamina = math.min(StaminaTable._maxStamina, LastStamina + BoostedGain)
                end
                
                LastCheckTime = CurrentTime
            end

            LastStamina = StaminaTable._stamina
        end

        return StaminaTable
    end, { Spy = false })
end

return Stamina
