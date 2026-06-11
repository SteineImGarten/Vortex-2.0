--[[
    Vortex Addon - Continuous Defibrillator (Zero-Delay Mode)
    Dual Operation: Hooks FireServer via exact native format and triggers automatically under 15 HP.
]]
local globalEnv = getgenv or function() return _G end
-- 1. Grab the running framework from the environment cache
local Vortex = globalEnv()._VortexCoreInstance
if not Vortex then
    warn("[Defib Addon] Vortex core engine instance is not running! Make sure to run the main framework loader first.")
    return
end
-- 2. Define the Defibrillator Addon module structure
local DefibContinuous = {}
function DefibContinuous.Init(VortexInstance)
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local MaxDistance = 20  -- Studs radius
    -- Attribute-based helper to locate equipped/backpack weapon
    local function FindWeapon()
        local Character = VortexInstance.GetCharacter(LocalPlayer)
        local Backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        local Containers = {Character, Backpack}
        
        for _, Container in ipairs(Containers) do
            if Container then
                for _, Item in ipairs(Container:GetChildren()) do
                    if Item:IsA("Tool") then
                        local ItemType = Item:GetAttribute("ItemType") or Item:GetAttribute("itemType")
                        if typeof(ItemType) == "string" and ItemType:lower() == "weapon" then
                            return Item
                        end
                    end
                end
            end
        end
        return nil
    end
    -- Helper to collect valid targets in radius (utilizing framework helper functions)
    local function GetTargets(ExcludeSelf)
        local Targets = {}
        local Character = VortexInstance.GetCharacter(LocalPlayer)
        local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
        if not RootPart then return Targets end
        for _, Player in ipairs(Players:GetPlayers()) do
            if ExcludeSelf and Player == LocalPlayer then
                continue
            end
            if VortexInstance.IsAlive(Player) then
                local TargetChar = VortexInstance.GetCharacter(Player)
                local TargetRoot = TargetChar and TargetChar:FindFirstChild("HumanoidRootPart")
                if TargetRoot then
                    local Distance = (RootPart.Position - TargetRoot.Position).Magnitude
                    if Distance <= MaxDistance then
                        table.insert(Targets, TargetChar)
                    end
                end
            end
        end
        return Targets
    end
    -- Core function to instantly handle the dual activation payload
    local function FireInstantDefib(NetworkInstance, Tool)
        VortexInstance.Notify("info", "Defibrillator", ("Activating payload via %s"):format(Tool.Name), 3)
        -- 1. Fire progress initialization packet
        VortexInstance.Call("@Network", "FireServer", NetworkInstance, "StartUtilityActionProgress", Tool)
        -- 2. Gather available targets within radius (Include self because we are low health)
        local Targets = GetTargets(false)
        -- 3. Instantly dispatch activation packet without structural pause or cooldown
        VortexInstance.Call("@Network", "FireServer", NetworkInstance, "DefibrillatorsActivate", Tool, Targets)
        
        -- 4. Defer the re-equip to the next cycle so Roblox processes the weapon switch correctly
        task.defer(function()
            local Character = VortexInstance.GetCharacter(LocalPlayer)
            local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
            local Backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
            local Weapon = FindWeapon()
            if Weapon and Humanoid and Backpack and Weapon:IsDescendantOf(Backpack) then
                Humanoid:EquipTool(Weapon)
            end
        end)
    end
    -- MODE 1: Hook the Network FireServer using exact framework design (Manual trigger)
    VortexInstance.Hook(
        "@Network",
        "FireServer",
        "DefiAuto",
        function(Original, ...)
            local Args = {...}
            --[[
                Vortex framework hook arguments mapping:
                Args[1] = Network Instance (Self)
                Args[2] = Action Name string ("StartUtilityActionProgress")
                Args[3] = Tool Instance (Defibrillators)
            ]]
            if Args[2] == "StartUtilityActionProgress" and typeof(Args[3]) == "Instance" and Args[3].Name:lower():find("defi") then
                local NetworkInstance = Args[1] or VortexInstance.Get("@Network")
                local HookTool = Args[3]
                if NetworkInstance and HookTool then
                    task.spawn(function()
                        -- 1. Let the original initialization pass instantly to register action start
                        Original(table.unpack(Args))
                        -- 2. Gather targets (EXCLUDE SELF for manual use mode)
                        local Targets = GetTargets(true)
                        
                        -- 3. Fire follow-up execution immediately
                        VortexInstance.Call("@Network", "FireServer", NetworkInstance, "DefibrillatorsActivate", HookTool, Targets)
                        -- 4. Run weapon restoration sequence
                        task.defer(function()
                            local Character = VortexInstance.GetCharacter(LocalPlayer)
                            local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
                            local Backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
                            local Weapon = FindWeapon()
                            if Weapon and Humanoid and Backpack and Weapon:IsDescendantOf(Backpack) then
                                Humanoid:EquipTool(Weapon)
                            end
                        end)
                    end)
                    return -- Block the un-altered duplicate chain call down the line
                end
            end
            return Original(table.unpack(Args))
        end,
        { Spy = true }
    )
    -- MODE 2: Auto-trigger sequence when running low on health (< 15 HP)
    local function CheckAndExecute(CurrentHealth)
        if CurrentHealth <= 0 or CurrentHealth >= 15 then return end
        local Character = VortexInstance.GetCharacter(LocalPlayer)
        local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
        local Backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        local CurrentNetwork = VortexInstance.Get("@Network")
        if not (Humanoid and CurrentNetwork) then return end
        -- Locate and Equip the Defibrillator Tool Instantly
        local Tool = Character:FindFirstChild("Defibrillators") or Character:FindFirstChildOfClass("Tool")
        if not (Tool and Tool.Name:lower():find("defi")) then
            if Backpack then
                for _, Item in ipairs(Backpack:GetChildren()) do
                    if Item:IsA("Tool") and Item.Name:lower():find("defi") then
                        Tool = Item
                        Humanoid:EquipTool(Tool)
                        break
                    end
                end
            end
        end
        -- If equipped, execute the payload tracking loop
        if Tool and Tool.Name:lower():find("defi") and Tool:IsDescendantOf(Character) then
            FireInstantDefib(CurrentNetwork, Tool)
        end
    end
    -- Setup listener connections on character setup
    local function SetupCharacterConnections(Character)
        local Humanoid = Character:WaitForChild("Humanoid", 5)
        if humanoid then
            Humanoid.HealthChanged:Connect(function(Health)
                CheckAndExecute(Health)
            end)
            
            -- Check initial state on spawn
            CheckAndExecute(Humanoid.Health)
        end
    end
    -- Connect lifestyle event for handling respawns seamlessly
    if LocalPlayer.Character then
        task.spawn(SetupCharacterConnections, LocalPlayer.Character)
    end
    LocalPlayer.CharacterAdded:Connect(SetupCharacterConnections)
    VortexInstance.Notify("success", "Defibrillator Addon", "Continuous listeners synchronized.", 5)
end
-- 3. Instantly execute the initialization routine manually
local Success, Error = pcall(DefibContinuous.Init, Vortex)
if not Success then
    warn("[Defib Addon] Failed to initialize live execution script: " .. tostring(Error))
end
return DefibContinuous
