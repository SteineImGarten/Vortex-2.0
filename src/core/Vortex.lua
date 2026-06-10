--[[
    Vortex Framework - Core Engine (Production Release Build)
    Universal modular script engine with built-in hooking, PsmSignal event-driven design,
    predictive math, and decoupled game adapters.
]]

setthreadidentity(2)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local globalEnv = getgenv or function() return _G end

local Vortex = globalEnv()._VortexCoreInstance or {}
Vortex.Adapters = Vortex.Adapters or {}
Vortex.Signals = Vortex.Signals or {}

Vortex._InternalStorage = Vortex._InternalStorage or {
    Originals = {},
    Wrapped = {}
}
Vortex._HookRegistry = Vortex._HookRegistry or {}
Vortex._LoaderCache = Vortex._LoaderCache or {}
Vortex._LoadedModules = Vortex._LoadedModules or {}
Vortex.Keybinds = Vortex.Keybinds or {}
Vortex.State = Vortex.State or {}

globalEnv()._VortexCoreInstance = Vortex

--------------------------------------------------------------------------------
-- 1. PsmSignal Class Implementation
--------------------------------------------------------------------------------

local PsmSignal = Vortex.PsmSignal or {}
if not PsmSignal.__index then
    PsmSignal.__index = PsmSignal

    function PsmSignal.new()
        local self = setmetatable({}, PsmSignal)
        self._connections = {}
        return self
    end

    function PsmSignal:Connect(callback)
        local connection = {
            Callback = callback,
            Connected = true,
            Disconnect = function(conn)
                conn.Connected = false
                for i, c in ipairs(self._connections) do
                    if c == conn then
                        table.remove(self._connections, i)
                        break
                    end
                end
            end
        }
        table.insert(self._connections, connection)
        return connection
    end

    function PsmSignal:Once(callback)
        local connection
        connection = self:Connect(function(...)
            if connection then
                connection:Disconnect()
            end
            callback(...)
        end)
        return connection
    end

    function PsmSignal:Wait()
        local thread = coroutine.running()
        local connection
        connection = self:Connect(function(...)
            connection:Disconnect()
            task.spawn(thread, ...)
        end)
        return coroutine.yield()
    end

    function PsmSignal:Fire(...)
        local connections = table.clone(self._connections)
        for _, conn in ipairs(connections) do
            if conn.Connected then
                task.spawn(conn.Callback, ...)
            end
        end
    end

    Vortex.PsmSignal = PsmSignal
    Vortex.Signal = PsmSignal
    globalEnv().PsmSignal = PsmSignal
    globalEnv().Signal = PsmSignal
end

--------------------------------------------------------------------------------
-- 2. Core Signals & State Synchronization
--------------------------------------------------------------------------------

Vortex.Signals.FeatureToggled = Vortex.Signals.FeatureToggled or PsmSignal.new()
Vortex.Signals.FrameworkLoaded = Vortex.Signals.FrameworkLoaded or PsmSignal.new()

-- Synchronize state changes to global environment using signal connections
Vortex.Signals.FeatureToggled:Connect(function(featureName, state)
    local stateVar = featureName
    if featureName == "Desync" then
        stateVar = "DesyncEnabled"
    end
    Vortex.State[stateVar] = state
    globalEnv()[stateVar] = state
end)

-- Unified State Controller
function Vortex.SetState(featureName, state)
    local stateVar = featureName
    if featureName == "Desync" then
        stateVar = "DesyncEnabled"
    end
    
    if Vortex.State[stateVar] ~= state then
        Vortex.Signals.FeatureToggled:Fire(featureName, state)
    end
end

--------------------------------------------------------------------------------
-- 3. Core Engine Configuration & Logic
--------------------------------------------------------------------------------

local Debug = false
local SpyEnabled = false
local SpyConfig = {
    Delay = 0,
    LogReturns = true
}

local Folders = {}
local SpyWrapped = {}
local SpyBackups = {}

function Vortex.Debug(State)
    Debug = not not State
end

function Vortex.Folders(List)
    Folders = List or {}
end

local function SafeRequire(Module)
    local Ok, Result = pcall(require, Module)
    if not Ok then
        if Debug then
            warn(("[Vortex] Failed to require module '%s': %s"):format(Module:GetFullName(), tostring(Result)))
        end
        return nil
    end
    if typeof(Result) ~= "table" then
        return {}
    end
    return Result
end

local function FormatValue(Value, Depth, Seen)
    Depth = Depth or 0
    Seen = Seen or {}
    local Indent = string.rep("  ", Depth)
    local t = typeof(Value)
    
    if t == "string" then
        return ("\"%s\""):format(Value:gsub("\n", "\\n"))
    elseif t == "number" or t == "boolean" or t == "nil" then
        return tostring(Value)
    elseif t == "table" then
        if Seen[Value] then return "<cycle>" end
        Seen[Value] = true
        local Parts = {}
        local IsArray = true
        local MaxIndex = 0
        
        for k, _ in pairs(Value) do
            if type(k) ~= "number" then
                IsArray = false
                break
            else
                if k > MaxIndex then MaxIndex = k end
            end
        end
        
        if IsArray and MaxIndex > 0 then
            table.insert(Parts, "[")
            for i = 1, MaxIndex do
                local v = Value[i]
                table.insert(Parts, ("\n%s  %s,"):format(Indent, FormatValue(v, Depth + 1, Seen)))
            end
            table.insert(Parts, ("\n%s]"):format(Indent))
            return table.concat(Parts, "")
        else
            table.insert(Parts, "{")
            for k, v in pairs(Value) do
                local KeySTR = tostring(k)
                local ValSTR = FormatValue(v, Depth + 1, Seen)
                table.insert(Parts, ("\n%s  %s = %s,"):format(Indent, KeySTR, ValSTR))
            end
            table.insert(Parts, ("\n%s}"):format(Indent))
            return table.concat(Parts, "")
        end
    else
        return tostring(Value)
    end
end

local function PrintArgs(Args)
    for i = 1, #Args do
        local v = Args[i]
        local t = typeof(v)
        if t == "table" then
            print(("[Vortex] Arg%d (table): %s"):format(i, FormatValue(v, 0, {})))
        else
            print(("[Vortex] Arg%d (%s): %s"):format(i, t, FormatValue(v)))
        end
    end
end

local function PrintReturn(Ret)
    if typeof(Ret) == "table" then
        print(("[Vortex] Return: %s"):format(FormatValue(Ret, 0, {})))
    else
        print(("[Vortex] Return: %s"):format(FormatValue(Ret)))
    end
end

local function IsCClosureFunc(f)
    if iscclosure then return iscclosure(f) end
    return debug.info(f, "s") == "[C]"
end

local function WrapWithSpy(ModuleKey, Mod, FuncName)
    local Key = ModuleKey .. "." .. FuncName
    if SpyWrapped[Key] then return end

    local Original = Mod[FuncName]
    if type(Original) ~= "function" then return end

    SpyWrapped[Key] = true
    local lastPrint = 0

    local function spyWrapper(...)
        local now = tick()
        if SpyEnabled and (now - lastPrint >= (SpyConfig.Delay or 0)) then
            lastPrint = now
            print(("=== [SPY] %s -> %s ==="):format(ModuleKey, FuncName))
            PrintArgs({...})
        end

        local results
        if SpyBackups[Key] then
            results = table.pack(SpyBackups[Key](...))
        else
            results = table.pack(Original(...))
        end

        if SpyEnabled and SpyConfig.LogReturns then
            PrintReturn(results.n == 1 and results[1] or results)
        end

        return table.unpack(results, 1, results.n)
    end

    if oth and oth.hook and IsCClosureFunc(Original) then
        SpyBackups[Key] = oth.hook(Original, spyWrapper)
    elseif hookfunction then
        local nativeWrapper = newcclosure and newcclosure(spyWrapper) or spyWrapper
        SpyBackups[Key] = hookfunction(Original, nativeWrapper)
    else
        Mod[FuncName] = spyWrapper
    end
end

local function ApplyGlobalSpy()
    for ModuleKey, Mod in pairs(Vortex._LoadedModules) do
        if type(ModuleKey) == "string" and ModuleKey:sub(1, 1) == "@" and type(Mod) == "table" then
            for FuncName, Value in pairs(Mod) do
                if type(Value) == "function" then
                    WrapWithSpy(ModuleKey, Mod, FuncName)
                end
            end
        end
    end
end

function Vortex.Spy(State, Config)
    SpyEnabled = not not State
    SpyConfig = Config or SpyConfig
    if SpyEnabled then
        ApplyGlobalSpy()
        print("[Vortex] Global Spy ENABLED")
    else
        print("[Vortex] Global Spy DISABLED")
    end
end

function Vortex.Load()
    local Mods = {}
    for _, Folder in ipairs(Folders) do
        for _, Module in ipairs(Folder:GetDescendants()) do
            if Module:IsA("ModuleScript") then
                local Tbl = SafeRequire(Module)
                if Tbl then
                    local Key = "@" .. Module.Name
                    Mods[Key] = Tbl
                    if Debug then
                        print(("[Vortex] Loaded module: %s"):format(Module:GetFullName()))
                    end
                end
            end
        end
    end

    for Key, Val in pairs(Mods) do
        Vortex._LoadedModules[Key] = Val
    end

    if Debug then
        local Count = 0
        for _ in pairs(Mods) do Count = Count + 1 end
        print("[Vortex] Total modules loaded:", Count)
    end

    Vortex.LOAD_FINISHED = true
    Vortex.Signals.FrameworkLoaded:Fire()
    
    return Mods
end

function Vortex.Call(ModuleKey, FunctionName, ...)
    local Args = {...}
    local BypassHook = false

    if #Args > 0 and type(Args[#Args]) == "table" and Args[#Args].BypassHook then
        BypassHook = true
        table.remove(Args, #Args)
        if Debug then PrintArgs(Args) end
    end

    local Mod = Vortex._LoadedModules[ModuleKey]
    if not Mod then
        warn(("[Vortex] Module '%s' not found"):format(ModuleKey))
        return nil
    end

    local Func
    local StorageKey = ModuleKey .. "." .. FunctionName
    if BypassHook and Vortex._InternalStorage.Originals[StorageKey] then
        Func = Vortex._InternalStorage.Originals[StorageKey]
    else
        Func = Mod[FunctionName]
    end

    if typeof(Func) ~= "function" then
        warn(("[Vortex] Function '%s' not found in module '%s'"):format(FunctionName, ModuleKey))
        return nil
    end
    
    return Func(table.unpack(Args))
end

function Vortex.Hook(ModuleKey, FunctionName, HookID, HookFunc, Config)
    if type(HookFunc) ~= "function" and type(HookID) == "function" then
        HookFunc, Config = HookID, HookFunc
        HookID = "Default"
    end

    Config = Config or {}
    HookID = HookID or "Default"

    local Mod = Vortex._LoadedModules[ModuleKey] or globalEnv()[ModuleKey]
    if not Mod then
        warn(("[Vortex] Module '%s' not found"):format(ModuleKey))
        return nil
    end

    local OrigFunc = Mod[FunctionName]
    if type(OrigFunc) ~= "function" then
        warn(("[Vortex] Function '%s' not found in module '%s'"):format(FunctionName, ModuleKey))
        return nil
    end

    Vortex._HookRegistry[ModuleKey] = Vortex._HookRegistry[ModuleKey] or {}
    Vortex._HookRegistry[ModuleKey][FunctionName] = Vortex._HookRegistry[ModuleKey][FunctionName] or {}

    local HookTable = Vortex._HookRegistry[ModuleKey][FunctionName]
    local StorageKey = ModuleKey .. "." .. FunctionName

    if HookTable[HookID] then
        HookTable[HookID].Func = HookFunc
        HookTable[HookID].Config = Config
        HookTable[HookID].Priority = Config.Priority or 0
        HookTable[HookID].Active = true
        return Vortex._InternalStorage.Originals[StorageKey]
    end

    HookTable[HookID] = {
        HookID = HookID,
        Func = HookFunc,
        Active = true,
        Config = Config,
        Priority = Config.Priority or 0
    }

    if Vortex._InternalStorage.Wrapped[StorageKey] then
        return Vortex._InternalStorage.Originals[StorageKey]
    end

    Vortex._InternalStorage.Wrapped[StorageKey] = true

    local function SafeCall(Func, ...)
        local ok, result = pcall(Func, ...)
        if not ok then
            warn(("[Vortex] Hook Error: %s"):format(tostring(result)))
            return nil
        end
        return result
    end

    local LastSpyPrintTime = {}

    local function GetActiveHook()
        local best
        for _, hook in pairs(HookTable) do
            if hook.Active then
                if not best or hook.Priority > best.Priority then
                    best = hook
                end
            end
        end
        return best
    end

    local function Wrapper(...)
        local HookData = GetActiveHook()
        local baseFunc = Vortex._InternalStorage.Originals[StorageKey] or OrigFunc
        
        if not HookData then
            return baseFunc(...)
        end

        local CFG = HookData.Config or {}
        local HookFn = HookData.Func
        local key = StorageKey .. "." .. HookData.HookID

        if CFG.Spy then
            local now = tick()
            local delay = CFG.SpyDelay or 0
            LastSpyPrintTime[key] = LastSpyPrintTime[key] or 0

            if now - LastSpyPrintTime[key] >= delay then
                LastSpyPrintTime[key] = now
                print(("--- Spy Hook: %s -> %s [ID=%s] ---"):format(ModuleKey, FunctionName, HookData.HookID))
                PrintArgs({...})
            end
        end

        return SafeCall(HookFn, baseFunc, ...)
    end

    if oth and oth.hook and IsCClosureFunc(OrigFunc) then
        local backup = oth.hook(OrigFunc, Wrapper)
        Vortex._InternalStorage.Originals[StorageKey] = backup
    elseif hookfunction then
        local nativeWrapper = newcclosure and newcclosure(Wrapper) or Wrapper
        local backup = hookfunction(OrigFunc, nativeWrapper)
        Vortex._InternalStorage.Originals[StorageKey] = backup
    else
        Vortex._InternalStorage.Originals[StorageKey] = OrigFunc
        Mod[FunctionName] = Wrapper
    end

    return Vortex._InternalStorage.Originals[StorageKey]
end

function Vortex.UnHook(ModuleKey, FunctionName, HookID)
    if not Vortex._HookRegistry[ModuleKey] or not Vortex._HookRegistry[ModuleKey][FunctionName] then
        return
    end

    if HookID then
        Vortex._HookRegistry[ModuleKey][FunctionName][HookID] = nil
    else
        Vortex._HookRegistry[ModuleKey][FunctionName] = {}
    end
end

function Vortex.ViewHookIDs(ModuleKey, FunctionName)
    if not Vortex._HookRegistry[ModuleKey] or not Vortex._HookRegistry[ModuleKey][FunctionName] then
        print(("[Vortex] No hooks found for %s -> %s"):format(ModuleKey, FunctionName))
        return
    end

    print(("[Vortex] Hooks for %s -> %s:"):format(ModuleKey, FunctionName))
    for HookID, Data in pairs(Vortex._HookRegistry[ModuleKey][FunctionName]) do
        local Status = Data.Active and "ACTIVE" or "INACTIVE"
        local ConfigSTR = ""
        if Data.Config and next(Data.Config) then
            local Parts = {}
            for k, v in pairs(Data.Config) do
                table.insert(Parts, ("%s -> %s"):format(k, tostring(v)))
            end
            ConfigSTR = " | Modifies: " .. table.concat(Parts, ", ")
        end
        print(("  ID: %s [%s]%s"):format(HookID, Status, ConfigSTR))
    end
end

function Vortex.ShowFunc(FuncName)
    if type(FuncName) ~= "string" then
        warn("[Vortex] ShowFunc requires a string argument")
        return {}
    end

    local Results = {}
    local Searched = 0

    for Key, Mod in pairs(Vortex._LoadedModules) do
        if type(Key) == "string" and Key:sub(1, 1) == "@" then
            Searched = Searched + 1
            local Ok, HasFunc = pcall(function()
                return type(Mod) == "table" and typeof(Mod[FuncName]) == "function"
            end)

            if Ok and HasFunc then
                table.insert(Results, Key)
            end
        end
    end

    if #Results == 0 then
        print(("[Vortex] No modules contain a function named '%s' (searched %d modules)"):format(FuncName, Searched))
    else
        print(("[Vortex] Found function '%s' in %d module(s):"):format(FuncName, #Results))
        for _, ModKey in ipairs(Results) do
            print("  →", ModKey)
        end
    end

    return Results
end

function Vortex.Get(Name)
    if type(Name) ~= "string" then
        warn("[Vortex] Get requires a string module name")
        return nil
    end
    return Vortex._LoadedModules[Name] or Vortex._LoadedModules["@" .. Name]
end

--------------------------------------------------------------------------------
-- 4. Extensible Adapter Registry
--------------------------------------------------------------------------------

function Vortex.RegisterAdapter(Name, Func)
    Vortex.Adapters[Name] = Func
end

--------------------------------------------------------------------------------
-- 5. Universal Helper Utilities
--------------------------------------------------------------------------------

function Vortex.GetCharacter(Player)
    Player = Player or Players.LocalPlayer
    return Player and Player.Character
end

function Vortex.IsAlive(Player)
    local Char = Vortex.GetCharacter(Player)
    local Hum = Char and Char:FindFirstChildOfClass("Humanoid")
    local Hrp = Char and Char:FindFirstChild("HumanoidRootPart")
    return not not (Hum and Hrp and Hum.Health > 0)
end

function Vortex.GetTeam(Player)
    Player = Player or Players.LocalPlayer
    return Player and Player.Team
end

function Vortex.IsEnemy(Player)
    local LocalPlayer = Players.LocalPlayer
    if not Player or Player == LocalPlayer then return false end
    
    local LocalTeam = Vortex.GetTeam(LocalPlayer)
    local TargetTeam = Vortex.GetTeam(Player)
    
    if LocalTeam and TargetTeam then
        return LocalTeam ~= TargetTeam
    end
    return true
end

function Vortex.Notify(Type, Title, Text, Duration)
    Type = Type or "success"
    Duration = Duration or 5
    
    local StoreObj = Vortex.Get("RoduxStore")
    if StoreObj then
        pcall(function()
            Vortex.Call("@ToastNotificationActionsClient", "add", Type, Text, Duration, true, { BypassHook = false })(StoreObj.store)
        end)
    else
        print(("[Vortex Notification] [%s] %s: %s"):format(Type:upper(), tostring(Title or ""), tostring(Text)))
    end
end

function Vortex.GetPartsInRange(Position, Radius, PartName)
    local Targets = {}
    PartName = PartName or "Head"
    for _, Player in ipairs(Players:GetPlayers()) do
        if Player == Players.LocalPlayer then continue end
        local Char = Vortex.GetCharacter(Player)
        local Part = Char and Char:FindFirstChild(PartName)
        if Part then
            local Dist = (Part.Position - Position).Magnitude
            if Dist <= Radius then
                table.insert(Targets, Part)
            end
        end
    end
    return Targets
end

function Vortex.GetClosestPlayer(MaxDistance, CheckFunction)
    local LocalPlayer = Players.LocalPlayer
    local Check = CheckFunction or function(p)
        return Vortex.IsAlive(p)
    end

    MaxDistance = MaxDistance or math.huge
    local ClosestDist = MaxDistance
    local Result = {}

    for _, Player in ipairs(Players:GetPlayers()) do
        if Player == LocalPlayer then continue end
        if not Check(Player) then continue end

        local Char = Vortex.GetCharacter(Player)
        local Hrp = Char and Char:FindFirstChild("HumanoidRootPart")
        local LocalHrp = Vortex.GetCharacter(LocalPlayer) and Vortex.GetCharacter(LocalPlayer):FindFirstChild("HumanoidRootPart")
        if not Hrp or not LocalHrp then continue end

        local Dist = (Hrp.Position - LocalHrp.Position).Magnitude
        if Dist < ClosestDist then
            ClosestDist = Dist
            Result[Player.Name] = Char:FindFirstChildOfClass("Humanoid").Health
        end
    end
    return Result
end

function Vortex.GetHealthTarget(MaxDistance, Priority, CheckFunction)
    local LocalPlayer = Players.LocalPlayer
    local Check = CheckFunction or function(p)
        local Char = Vortex.GetCharacter(p)
        return Vortex.IsAlive(p) and not Char:FindFirstChildOfClass("ForceField")
    end

    MaxDistance = MaxDistance or math.huge
    local LowestHealth = math.huge
    local ClosestDist = MaxDistance
    local TargetObj = nil

    for _, Player in ipairs(Players:GetPlayers()) do
        if Player == LocalPlayer then continue end
        if not Check(Player) then continue end

        local Char = Vortex.GetCharacter(Player)
        local Hrp = Char and Char:FindFirstChild("HumanoidRootPart")
        local LocalHrp = Vortex.GetCharacter(LocalPlayer) and Vortex.GetCharacter(LocalPlayer):FindFirstChild("HumanoidRootPart")
        if not Hrp or not LocalHrp then continue end

        local Dist = (Hrp.Position - LocalHrp.Position).Magnitude
        local Health = Char:FindFirstChildOfClass("Humanoid").Health

        if Dist <= ClosestDist then
            if Priority == "Health" then
                if Health < LowestHealth then
                    LowestHealth = Health
                    TargetObj = Player
                end
            end
        else
            ClosestDist = Dist
            TargetObj = Player
        end
    end
    return TargetObj and { [TargetObj.Name] = true } or nil
end

function Vortex.GetMouseTarget(MaxDistance, Fov, PartName, CheckFunction)
    local LocalPlayer = Players.LocalPlayer
    local Mouse = LocalPlayer:GetMouse()
    local Camera = Workspace.CurrentCamera
    PartName = PartName or "Torso"

    local Check = CheckFunction or function(p)
        return Vortex.IsAlive(p)
    end

    MaxDistance = MaxDistance or math.huge
    Fov = Fov or math.huge

    local ClosestTarget = nil
    local ClosestScreenDist = Fov

    for _, Player in ipairs(Players:GetPlayers()) do
        if Player == LocalPlayer then continue end
        if not Check(Player) then continue end

        local Char = Vortex.GetCharacter(Player)
        local TargetPart = Char:FindFirstChild(PartName)
            or Char:FindFirstChild("UpperTorso")
            or Char:FindFirstChild("HumanoidRootPart")

        if not TargetPart then continue end

        local ScreenPos, OnScreen = Camera:WorldToScreenPoint(TargetPart.Position)
        if not OnScreen then continue end

        local ScreenDist = (Vector2.new(Mouse.X, Mouse.Y) - Vector2.new(ScreenPos.X, ScreenPos.Y)).Magnitude
        if ScreenDist < ClosestScreenDist then
            ClosestScreenDist = ScreenDist
            ClosestTarget = Player
        end
    end

    return ClosestTarget
end

function Vortex.MeleeWeapon(Player)
    local Adapter = Vortex.Adapters.GetMeleeWeapon
    if Adapter then return Adapter(Player) end
    Player = Player or Players.LocalPlayer
    local Char = Vortex.GetCharacter(Player)
    if Char then
        for _, Tool in ipairs(Char:GetChildren()) do
            if Tool:IsA("Tool") then return Tool end
        end
    end
end

function Vortex.RangedWeapon(Player)
    local Adapter = Vortex.Adapters.GetRangedWeapon
    if Adapter then return Adapter(Player) end
    Player = Player or Players.LocalPlayer
    local Char = Vortex.GetCharacter(Player)
    if Char then
        for _, Tool in ipairs(Char:GetChildren()) do
            if Tool:IsA("Tool") then return Tool end
        end
    end
end

function Vortex.PlayerState()
    local Adapter = Vortex.Adapters.GetPlayerState
    if Adapter then return Adapter() end
    return nil
end

function Vortex.SessionData(Player)
    local Adapter = Vortex.Adapters.GetSessionData
    if Adapter then return Adapter(Player) end
    return nil
end

local Kalman = globalEnv().import and globalEnv().import("math/Kalman")
if Kalman then
    function Vortex.Predict(Part, Origin, Speed, DrawLine, Gravity)
        return Kalman.Predict(Part, Origin, Speed, DrawLine, Gravity)
    end
    Vortex.Kalman = Kalman
end

Vortex.ItemData = function(...)
    local Adapter = Vortex.Adapters.GetItemData
    if Adapter then return Adapter(...) end
end
Vortex.ModRanged = function(...)
    local Adapter = Vortex.Adapters.ModRanged
    if Adapter then return Adapter(...) end
end
Vortex.PrintWepStats = function(...)
    local Adapter = Vortex.Adapters.PrintWepStats
    if Adapter then return Adapter(...) end
end
Vortex.ClosestPlayer = Vortex.GetClosestPlayer
Vortex.HealthTarget = Vortex.GetHealthTarget
Vortex.MouseTarget = Vortex.GetMouseTarget

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    
    local keybinds = Vortex.Keybinds or globalEnv().Keybinds
    if not keybinds then return end
    
    for featureName, keycode in pairs(keybinds) do
        if input.KeyCode == keycode then
            local stateVar = featureName
            if featureName == "Desync" then
                stateVar = "DesyncEnabled"
            end
            
            local currentState = Vortex.State[stateVar]
            if currentState == nil then
                currentState = globalEnv()[stateVar]
            end
            
            if currentState ~= nil then
                local newState = not currentState
                Vortex.SetState(featureName, newState)
            end
        end
    end
end)

table.insert(Vortex._LoaderCache, {Folders = Folders, Loader = Vortex})

return Vortex
