--[[
    Combat Warriors - Framework Adapter
    Registers Combat Warriors specific functions and metadata handlers as adapters on the universal Vortex framework.
]]

local globalEnv = getgenv or function() return _G end
local Vortex = globalEnv()._VortexCoreInstance or import("core/Vortex")
local HL = Vortex

local Players = game:GetService("Players")

local UtilityIds = {}
local WeaponIds = {}
local WeaponOrder = {}
local AllItemsDefault = {}

-- Retrieve metadata for weapons and utilities
local function ItemData(ItemName, ItemId)
    local Key = ItemName and ItemName:lower():gsub("%s+", "")
    if Key and not WeaponIds[Key] and not UtilityIds[Key] then return end

    if Key and WeaponIds[Key] then
        return HL.Get("WeaponMetadata")[WeaponIds[Key]]
    elseif Key and UtilityIds[Key] then
        return HL.Get("UtilityMetadata")[UtilityIds[Key]]
    else
        return HL.Get("WeaponMetadata")[ItemId] or HL.Get("UtilityMetadata")[ItemId]
    end
end

-- Asynchronously wait and pre-load items lists
task.spawn(function()
    repeat task.wait(0.05) until Vortex.LOAD_FINISHED or globalEnv().LOAD_FINISHED

    -- Populate IDs from HookLoader's cached game objects
    local UtilIdsObj = HL.Get("UtilityIds")
    if UtilIdsObj then
        for Key, Value in pairs(UtilIdsObj) do
            UtilityIds[Key:lower()] = Value
        end
    end

    local WeaponIdsObj = HL.Get("WeaponIds")
    if WeaponIdsObj then
        for Key, Value in pairs(WeaponIdsObj) do
            WeaponIds[Key:lower()] = Value
        end
    end

    local WeaponsInOrderObj = HL.Get("WeaponsInOrder")
    if WeaponsInOrderObj then
        for _, v in pairs(WeaponsInOrderObj) do
            WeaponOrder[v.id] = v
        end
    end

    local WeaponMetaObj = HL.Get("WeaponMetadata")
    if WeaponMetaObj then
        for Key, Id in pairs(WeaponIds) do
            local Meta = WeaponMetaObj[Id]
            if Meta then
                table.insert(AllItemsDefault, { Name = Key, OG = table.clone(Meta) })
            end
        end
    end

    local UtilMetaObj = HL.Get("UtilityMetadata")
    if UtilMetaObj then
        for Key, Id in pairs(UtilityIds) do
            local Meta = UtilMetaObj[Id]
            if Meta then
                table.insert(AllItemsDefault, { Name = Key, OG = table.clone(Meta) })
            end
        end
    end
end)

local function NormalizeKey(str)
    return str:lower():gsub("%s+", "")
end

local function WaitForItems()
    repeat task.wait(0.05) until #AllItemsDefault > 0
end

-- Get character's currently equipped melee tool and object reference
local function MeleeWeapon(Player)
    Player = Player or Players.LocalPlayer
    local Character = Player.Character or Player.CharacterAdded:Wait()

    for _, Tool in ipairs(Character:GetChildren()) do
        if Tool:IsA("Tool") and Tool:GetAttribute("ItemType") == "weapon" then
            local ItemId = Tool:GetAttribute("ItemId")
            local WeaponMeta = HL.Get("WeaponMetadata")
            local Meta = WeaponMeta and WeaponMeta[ItemId]
            if Meta and Meta.class:lower():match("melee") then
                local ClientObj = HL.Get("MeleeWeaponClient")
                return Tool, ClientObj and ClientObj.getObj(Tool)
            end
        end
    end
end

-- Get character's currently equipped ranged tool and object reference
local function RangedWeapon(Player)
    Player = Player or Players.LocalPlayer
    local Character = Player.Character or Player.CharacterAdded:Wait()

    for _, Tool in ipairs(Character:GetChildren()) do
        if Tool:IsA("Tool") and Tool:GetAttribute("ItemType") == "weapon" then
            local ItemId = Tool:GetAttribute("ItemId")
            local WeaponMeta = HL.Get("WeaponMetadata")
            local Meta = WeaponMeta and WeaponMeta[ItemId]
            if Meta and Meta.class:lower():match("ranged") then
                local ClientObj = HL.Get("RangedWeaponClient")
                return Tool, ClientObj and ClientObj.getObj(Tool)
            end
        end
    end
end

-- Modify range properties across all default items
local function ModRanged(Name, Value)
    for _, v in ipairs(AllItemsDefault) do
        local Meta = ItemData(v.Name)
        if Meta and Meta[Name] then
            Meta[Name] = Value
        end
    end
end

-- Utility printer for nested tables
local function PrintTable(Tbl, Indent)
    Indent = Indent or ""
    for Key, Value in pairs(Tbl) do
        if type(Value) == "table" then
            print(Indent .. tostring(Key) .. " :")
            PrintTable(Value, Indent .. "  ")
        else
            print(Indent .. tostring(Key) .. " : " .. tostring(Value))
        end
    end
end

-- Display properties of currently equipped weapon in log console
local function PrintWepStats(Player)
    WaitForItems()

    Player = Player or Players.LocalPlayer
    local Character = Player.Character or Player.CharacterAdded:Wait()

    local Tool
    for _, Item in ipairs(Character:GetChildren()) do
        if Item:IsA("Tool") and Item:GetAttribute("ItemType") == "weapon" then
            Tool = Item
            break
        end
    end

    if not Tool then
        warn("[Framework] No weapon equipped!")
        return
    end

    local WeaponKey = NormalizeKey(Tool.Name)
    print("[Framework] Stats for currently held weapon: " .. Tool.Name)

    for _, Item in ipairs(AllItemsDefault) do
        if NormalizeKey(Item.Name) == WeaponKey then
            PrintTable(Item.OG, "  ")
            return
        end
    end

    warn("[Framework] Weapon stats not found in AllItemsDefault: " .. Tool.Name)
end

-- Get state from Rodux Store
local function PlayerState()
    local StoreObj = HL.Get("RoduxStore")
    return StoreObj and StoreObj.store:getState()
end

-- Get player session data
local function SessionData(Player)
    Player = Player or Players.LocalPlayer
    local DataHandler = HL.Get("DataHandler")
    return DataHandler and DataHandler.getSessionDataRoduxStoreForPlayer(Player)
end

-- Register Adapters on Vortex
Vortex.RegisterAdapter("GetMeleeWeapon", MeleeWeapon)
Vortex.RegisterAdapter("GetRangedWeapon", RangedWeapon)
Vortex.RegisterAdapter("GetPlayerState", PlayerState)
Vortex.RegisterAdapter("GetSessionData", SessionData)
Vortex.RegisterAdapter("GetItemData", ItemData)
Vortex.RegisterAdapter("ModRanged", ModRanged)
Vortex.RegisterAdapter("PrintWepStats", PrintWepStats)

return Vortex
