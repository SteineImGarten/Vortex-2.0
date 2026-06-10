--[[
    Vortex Framework - Main Bootstrapper (Production Build)
    Integrates the modular architecture components, handles initialization, and triggers hooks.
    Supports dynamic loading of all modules inside the features/ directory.
]]

local Main = {}

local HttpService = game:GetService("HttpService")
local globalEnv = getgenv or function() return _G end

local function HttpRequest(url)
    local response = request({
        Url = url,
        Method = "GET"
    })

    if response and response.StatusCode == 200 then
        return true, response.Body
    else
        return false, response and tostring(response.StatusCode) or "No response"
    end
end

-- Dynamically list all modules inside the features directory
local function ScanFeatureModules()
    local features = {}
    local isLocal = globalEnv().import_is_local
    local localPath = globalEnv().import_local_path
    local owner = globalEnv().import_repo_owner
    local repo = globalEnv().import_repo_name
    local branch = globalEnv().import_repo_branch

    if isLocal then
        -- Local Mode: Scan executor workspace directory
        if listfiles then
            local success, files = pcall(listfiles, localPath .. "features")
            if success and type(files) == "table" then
                for _, filePath in ipairs(files) do
                    -- Extract filename from path (e.g., "Combat Warriors Project/src/features/Fly.lua" -> "Fly")
                    local name = filePath:match("features/([^/%.]+)%.lua$") or filePath:match("features\\([^\\]+)%.lua$")
                    if name then
                        table.insert(features, "features/" .. name)
                    end
                end
            else
                warn("[Vortex] Failed to scan local features directory. Using fallback list.")
            end
        else
            warn("[Vortex] listfiles is not supported by your executor. Using fallback list.")
        end
    else
        -- GitHub Mode: Fetch clean array manifest via safe executor network request
        local manifestURL = ("https://raw.githubusercontent.com/%s/%s/%s/src/features/manifest.json"):format(owner, repo, branch)
        local success, response = HttpRequest(manifestURL)
        
        if success and response then
            local ok, list = pcall(function() return HttpService:JSONDecode(response) end)
            if ok and type(list) == "table" then
                for _, featureName in ipairs(list) do
                    table.insert(features, "features/" .. featureName)
                end
            else
                warn("[Vortex] Failed to decode raw manifest JSON. Using fallback list.")
            end
        else
            warn("[Vortex] Manifest network fetch failed. Using fallback list.")
        end
    end

    -- Fallback list in case the API calls or file scans fail
    if #features == 0 then
        print("[Vortex] Using default features manifest fallback.")
        features = {
            "features/Fly",
            "features/Desync",
            "features/SilentAim",
            "features/RangeExpander",
            "features/AntiParry",
            "features/AntiRagdoll",
            "features/FastSpawn",
            "features/Stamina"
        }
    end

    return features
end

function Main.Start()
    if globalEnv().EXECUTED then
        print("[Vortex] Already executed, skipping initialization.")
        return
    end

    -- 1. Initialize configuration environment
    local Settings = import("config/Settings")
    Settings.LoadDefaults()

    -- 2. Load Core Framework APIs (Pfad angepasst auf core/Vortex)
    local Vortex = import("core/Vortex")
    
    -- 3. Configure Debug Mode
    Vortex.Debug(true)
    
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    Vortex.Folders({
        ReplicatedStorage.Client.Source,
        ReplicatedStorage.Shared.Source,
        ReplicatedStorage.Shared.Vendor
    })
    
    -- 4. Load Roblox Replicated Modules (wandern jetzt direkt in Vortex._LoadedModules)
    Vortex.Load()

    -- 5. Trigger sound and toast notifying successful module loader hook
    task.spawn(function()
        local storeObj = Vortex.Get("RoduxStore")
        if storeObj then
            Vortex.Call("@ToastNotificationActionsClient", "add", "success", "Hook Finished", 5, true, { BypassHook = false })(storeObj.store)
        end
        
        Vortex.Call("@SoundHandler", "playSound", {
            soundObject = ReplicatedStorage.Shared.Assets.Sounds.Success2,
            parent = workspace:FindFirstChild("Sounds") or workspace
        })
    end)

    -- 6. Setup general hook configurations directly on Vortex
    Vortex.Hook("@ToastNotificationActionsClient", "add", "ConfigOne", function(Original, Type, Text, Duration, ShouldToast)
        return Original(Type, Text, Duration, ShouldToast)
    end)

    -- 7. Initialize Visual drawings
    pcall(function()
        import("ui/Visuals").Init(Vortex)
    end)

    -- 8. Discover and load all feature modules dynamically
    local featureModules = ScanFeatureModules()
    print("[Vortex] Discovered " .. #featureModules .. " feature modules to load.")

    for _, featurePath in ipairs(featureModules) do
        local success, err = pcall(function()
            local module = import(featurePath)
            if module and type(module.Init) == "function" then
                module.Init(Vortex)
                print("[Vortex] Loaded feature: " .. featurePath)
            else
                warn("[Vortex] Feature module does not export Init: " .. featurePath)
            end
        end)
        
        if not success then
            warn("[Vortex] Failed to load feature '" .. featurePath .. "': " .. tostring(err))
        end
    end

    globalEnv().EXECUTED = true
    globalEnv().Loaded_FIN = true
    
    Vortex.Signals.FrameworkLoaded:Fire()
    print("[Vortex] Framework fully loaded and features initialized successfully!")

    setthreadidentity(8)
end

return Main
