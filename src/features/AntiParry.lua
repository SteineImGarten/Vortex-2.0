--[[
    Combat Warriors - Anti-Parry
    Suppresses attack events directed at players who have active parry states (detected via parry sounds).
]]

local AntiParry = {}

function AntiParry.Init(Vortex)
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local LocalPlayer = Players.LocalPlayer
    local globalEnv = getgenv or function() return _G end

    -- Global cache of player character models currently parrying
    globalEnv().RecentParryPlayers = globalEnv().RecentParryPlayers or {}

    -- Hook outgoing game events to block damage sent to parrying opponents
    Vortex.Hook(
        "@Network",
        "FireServer",
        "Anti-Hit",
        function(Original, ...)
            local Args = {...}

            if globalEnv().AntiParry and Args[2] == "MeleeDamage" then
                local TargetPart = Args[4]
                local PlayerModel = TargetPart and TargetPart.Parent

                if PlayerModel and globalEnv().RecentParryPlayers[PlayerModel] then
                    Vortex.Notify("success", "Anti-Parry", ("Suppressed %s"):format(PlayerModel.Name), 5)
                    
                    Vortex.Call("@SoundHandler", "playSound", {
                        soundObject = ReplicatedStorage.Shared.Assets.Sounds.Success2,
                        parent = workspace:FindFirstChild("Sounds") or workspace
                    })
          
                    return
                end
            end

            return Original(table.unpack(Args))
        end,
        { Spy = false }
    )

    -- Hook sound cues to identify target parry triggers
    Vortex.Hook(
        "@SoundHandler",
        "playSound",
        "Anti-Parry",
        function(Original, ...)
            local Args = {...}
            local Data = Args[1]

            if globalEnv().AntiParry and Data and Data.soundObject and Data.soundObject.Name == "Parry" then
                local Sound = Data.soundObject
                local PlayerModel = Data.parent and Data.parent.Parent and Data.parent.Parent.Parent

                if Sound and PlayerModel and PlayerModel ~= LocalPlayer.Character then
                    -- Record target parry window state
                    globalEnv().RecentParryPlayers[PlayerModel] = true

                    -- Reset parry window block state after 350ms
                    task.delay(0.35, function()
                        globalEnv().RecentParryPlayers[PlayerModel] = nil
                    end)
                end
            end

            return Original(...)
        end,
        { Spy = false }
    )
end

return AntiParry
