--[[
    ESP System v2.0 - Complete Rewrite
    High-performance, feature-rich ESP with modular architecture
    
    Features:
    - Entity-Component System
    - Object Pooling
    - Level of Detail (LOD)
    - Multiple box styles (Corner, Square, 3D)
    - Health bars with color gradients
    - Tracers with multiple origins
    - Distance indicators
    - Look direction lines
    - Enhanced chams with glow effects
    - Full color customization per category
    - Optimized rendering with staggered updates
]]

local ESPModule = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

-- CoreGui with cloneref for executor compatibility
local CoreGui
if cloneref then
    CoreGui = cloneref(game:GetService("CoreGui"))
elseif gethui then
    CoreGui = gethui()
else
    CoreGui = game:GetService("CoreGui")
end

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local ZERO_VECTOR3 = Vector3.new(0, 0, 0)
local ZERO_VECTOR2 = Vector2.new(0, 0)
local DEFAULT_SIZE = Vector3.new(4, 5, 2)

local HOSTILE_BOX_COLOR = Color3.fromRGB(255, 50, 50)
local HOSTILE_CHAM_FILL = Color3.fromRGB(255, 0, 0)
local HOSTILE_CHAM_OUTLINE = Color3.fromRGB(255, 100, 100)

local cachedTracerOrigin = nil
local lastViewportSize = nil

local playerColorCache = {}
local cachedPlayersList = {}
local playersListDirty = true
local lastPlayersUpdate = 0
local PLAYERS_CACHE_INTERVAL = 0.5

local refreshToRemove = {}
local refreshToRemoveCount = 0

local MAX_DISTANCE_SQ = 0
local LOD_NEAR_SQ = 0
local LOD_MEDIUM_SQ = 0
local LOD_FAR_SQ = 0

local REFRESH_INTERVAL = 1.0
local STAFF_CACHE_DURATION = 60
local SORT_INTERVAL = 0.5

-- Environment
local env = getgenv and getgenv() or {}

-- Prevent duplicate execution - return existing module if running
if env.ESP_V2_RUNNING and env.ESP_V2_MODULE then
    return env.ESP_V2_MODULE
end

local instanceId = tick()
env.ESP_V2_INSTANCE = instanceId
env.ESP_V2_RUNNING = true

local function isCurrentInstance()
    return env.ESP_V2_INSTANCE == instanceId and env.ESP_V2_RUNNING
end

--------------------------------------------------------------------------------
-- SECTION 1: CONFIGURATION & COLOR SCHEMES
--------------------------------------------------------------------------------

local DefaultColors = {
    Staff = {
        primary = Color3.fromRGB(255, 255, 0),
        secondary = Color3.fromRGB(255, 200, 0),
        text = Color3.fromRGB(255, 255, 0),
        textOutline = Color3.fromRGB(0, 0, 0),
        box = Color3.fromRGB(255, 255, 0),
        boxFill = Color3.fromRGB(255, 255, 0),
        tracer = Color3.fromRGB(255, 255, 0),
        healthHigh = Color3.fromRGB(0, 255, 0),
        healthMid = Color3.fromRGB(255, 255, 0),
        healthLow = Color3.fromRGB(255, 0, 0),
        chamFill = Color3.fromRGB(255, 255, 0),
        chamOutline = Color3.fromRGB(255, 200, 0),
        chamGlow = Color3.fromRGB(255, 255, 100),
    },
    SCP_NPC = {
        primary = Color3.fromRGB(128, 0, 255),
        secondary = Color3.fromRGB(160, 50, 255),
        text = Color3.fromRGB(255, 255, 255),
        textOutline = Color3.fromRGB(0, 0, 0),
        box = Color3.fromRGB(128, 0, 255),
        boxFill = Color3.fromRGB(128, 0, 255),
        tracer = Color3.fromRGB(128, 0, 255),
        healthHigh = Color3.fromRGB(0, 255, 0),
        healthMid = Color3.fromRGB(255, 255, 0),
        healthLow = Color3.fromRGB(255, 0, 0),
        chamFill = Color3.fromRGB(128, 0, 255),
        chamOutline = Color3.fromRGB(160, 50, 255),
        chamGlow = Color3.fromRGB(180, 100, 255),
    },
    SCP_NPC_Angry = {
        primary = Color3.fromRGB(255, 0, 0),
        secondary = Color3.fromRGB(255, 50, 50),
        text = Color3.fromRGB(255, 0, 0),
        textOutline = Color3.fromRGB(255, 255, 255),
        box = Color3.fromRGB(255, 0, 0),
        boxFill = Color3.fromRGB(255, 0, 0),
        tracer = Color3.fromRGB(255, 0, 0),
        healthHigh = Color3.fromRGB(0, 255, 0),
        healthMid = Color3.fromRGB(255, 255, 0),
        healthLow = Color3.fromRGB(255, 0, 0),
        chamFill = Color3.fromRGB(255, 0, 0),
        chamOutline = Color3.fromRGB(255, 100, 100),
        chamGlow = Color3.fromRGB(255, 150, 150),
    },
    SCP_Player = {
        primary = Color3.fromRGB(128, 0, 255),
        secondary = Color3.fromRGB(160, 50, 255),
        text = Color3.fromRGB(128, 0, 255),
        textOutline = Color3.fromRGB(255, 255, 255),
        box = Color3.fromRGB(128, 0, 255),
        boxFill = Color3.fromRGB(128, 0, 255),
        tracer = Color3.fromRGB(128, 0, 255),
        healthHigh = Color3.fromRGB(0, 255, 0),
        healthMid = Color3.fromRGB(255, 255, 0),
        healthLow = Color3.fromRGB(255, 0, 0),
        chamFill = Color3.fromRGB(128, 0, 255),
        chamOutline = Color3.fromRGB(160, 50, 255),
        chamGlow = Color3.fromRGB(180, 100, 255),
    },
    Traitor = {
        primary = Color3.fromRGB(255, 0, 0),
        secondary = Color3.fromRGB(255, 50, 50),
        text = Color3.fromRGB(255, 0, 0),
        textOutline = Color3.fromRGB(0, 0, 0),
        box = Color3.fromRGB(255, 0, 0),
        boxFill = Color3.fromRGB(255, 0, 0),
        tracer = Color3.fromRGB(255, 0, 0),
        healthHigh = Color3.fromRGB(0, 255, 0),
        healthMid = Color3.fromRGB(255, 255, 0),
        healthLow = Color3.fromRGB(255, 0, 0),
        chamFill = Color3.fromRGB(255, 0, 0),
        chamOutline = Color3.fromRGB(255, 100, 100),
        chamGlow = Color3.fromRGB(255, 150, 150),
    },
    Medical = {
        primary = Color3.fromRGB(0, 255, 0),
        secondary = Color3.fromRGB(50, 255, 50),
        text = Color3.fromRGB(0, 255, 0),
        textOutline = Color3.fromRGB(0, 0, 0),
        box = Color3.fromRGB(0, 255, 0),
        boxFill = Color3.fromRGB(0, 255, 0),
        tracer = Color3.fromRGB(0, 255, 0),
        healthHigh = Color3.fromRGB(0, 255, 0),
        healthMid = Color3.fromRGB(255, 255, 0),
        healthLow = Color3.fromRGB(255, 0, 0),
        chamFill = Color3.fromRGB(0, 255, 0),
        chamOutline = Color3.fromRGB(100, 255, 100),
        chamGlow = Color3.fromRGB(150, 255, 150),
    },
    Hostile = {
        primary = Color3.fromRGB(255, 0, 0),
        secondary = Color3.fromRGB(255, 50, 50),
        text = Color3.fromRGB(255, 0, 0),
        textOutline = Color3.fromRGB(0, 0, 0),
        box = Color3.fromRGB(255, 0, 0),
        boxFill = Color3.fromRGB(255, 0, 0),
        tracer = Color3.fromRGB(255, 0, 0),
        healthHigh = Color3.fromRGB(0, 255, 0),
        healthMid = Color3.fromRGB(255, 255, 0),
        healthLow = Color3.fromRGB(255, 0, 0),
        chamFill = Color3.fromRGB(255, 0, 0),
        chamOutline = Color3.fromRGB(255, 100, 100),
        chamGlow = Color3.fromRGB(255, 150, 150),
    },
    Friendly = {
        primary = Color3.fromRGB(0, 255, 0),
        secondary = Color3.fromRGB(50, 255, 50),
        text = Color3.fromRGB(255, 255, 255),
        textOutline = Color3.fromRGB(0, 0, 0),
        box = Color3.fromRGB(0, 255, 0),
        boxFill = Color3.fromRGB(0, 255, 0),
        tracer = Color3.fromRGB(0, 255, 0),
        healthHigh = Color3.fromRGB(0, 255, 0),
        healthMid = Color3.fromRGB(255, 255, 0),
        healthLow = Color3.fromRGB(255, 0, 0),
        chamFill = Color3.fromRGB(0, 255, 0),
        chamOutline = Color3.fromRGB(100, 255, 100),
        chamGlow = Color3.fromRGB(150, 255, 150),
    },
    Neutral = {
        primary = Color3.fromRGB(255, 255, 255),
        secondary = Color3.fromRGB(200, 200, 200),
        text = Color3.fromRGB(255, 255, 255),
        textOutline = Color3.fromRGB(0, 0, 0),
        box = Color3.fromRGB(255, 255, 255),
        boxFill = Color3.fromRGB(255, 255, 255),
        tracer = Color3.fromRGB(255, 255, 255),
        healthHigh = Color3.fromRGB(0, 255, 0),
        healthMid = Color3.fromRGB(255, 255, 0),
        healthLow = Color3.fromRGB(255, 0, 0),
        chamFill = Color3.fromRGB(255, 255, 255),
        chamOutline = Color3.fromRGB(200, 200, 200),
        chamGlow = Color3.fromRGB(255, 255, 255),
    },
    Item = {
        primary = Color3.fromRGB(0, 100, 255),
        secondary = Color3.fromRGB(50, 150, 255),
        text = Color3.fromRGB(0, 100, 255),
        textOutline = Color3.fromRGB(255, 255, 255),
        box = Color3.fromRGB(0, 100, 255),
        boxFill = Color3.fromRGB(0, 100, 255),
        tracer = Color3.fromRGB(0, 100, 255),
        healthHigh = Color3.fromRGB(0, 255, 0),
        healthMid = Color3.fromRGB(255, 255, 0),
        healthLow = Color3.fromRGB(255, 0, 0),
        chamFill = Color3.fromRGB(0, 100, 255),
        chamOutline = Color3.fromRGB(100, 150, 255),
        chamGlow = Color3.fromRGB(150, 200, 255),
    },
    SCP963 = {
        primary = Color3.fromRGB(255, 215, 0),
        secondary = Color3.fromRGB(255, 180, 0),
        text = Color3.fromRGB(255, 215, 0),
        textOutline = Color3.fromRGB(0, 0, 0),
        box = Color3.fromRGB(255, 215, 0),
        boxFill = Color3.fromRGB(255, 215, 0),
        tracer = Color3.fromRGB(255, 215, 0),
        healthHigh = Color3.fromRGB(0, 255, 0),
        healthMid = Color3.fromRGB(255, 255, 0),
        healthLow = Color3.fromRGB(255, 0, 0),
        chamFill = Color3.fromRGB(255, 215, 0),
        chamOutline = Color3.fromRGB(255, 180, 0),
        chamGlow = Color3.fromRGB(255, 230, 100),
    },
}

-- Deep copy function for colors
local function deepCopy(tbl)
    local copy = {}
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            copy[k] = deepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

-- Main Settings Structure
local Settings = {
    Enabled = false,
    MaxDistance = 2000,
    RefreshRate = 1/60,
    
    -- LOD Settings
    LOD = {
        Enabled = true,
        NearDistance = 200,
        MediumDistance = 500,
        FarDistance = 1000,
        MaxEntities = 100,
    },
    
    -- Category Enables
    Categories = {
        SCP963 = { enabled = true, priority = 100 },
        SCP_NPC = { enabled = true, priority = 90 },
        SCP_Player = { enabled = true, priority = 85 },
        Staff = { enabled = true, priority = 80 },
        Traitor = { enabled = true, priority = 75 },
        Medical = { enabled = false, priority = 70 },
        Player = { enabled = true, priority = 50 },
    },
    
    -- Component Settings
    Components = {
        Box = {
            Enabled = true,
            Style = "Corner",
            Thickness = 2,
            Filled = false,
            FillTransparency = 0.8,
        },
        HealthBar = {
            Enabled = true,
            Position = "Left",
            Width = 4,
            Padding = 4,
            ShowText = true,
            TextPosition = "Side",
        },
        Tracer = {
            Enabled = false,
            Origin = "Bottom",
            Thickness = 2,
        },
        Distance = {
            Enabled = true,
            Unit = "Studs",
            ShowBelowName = true,
        },
        Name = {
            Enabled = true,
            ShowDisplayName = false,
            Font = Enum.Font.Code,
            Size = 13,
            Outline = true,
        },
        Chams = {
            Enabled = true,
            FillTransparency = 0.7,
            OutlineTransparency = 0,
            DepthMode = "AlwaysOnTop",
        },
    },
    
    -- Filters
    Filters = {
        TeamFilter = false,
        VisibilityFilter = false,
        HostilesOnly = false,
        HostileColors = false,
    },
    
    -- Colors (user customizable)
    Colors = deepCopy(DefaultColors),
    
    -- SCP963 Special
    SCP963Spectate = false,
}

local function updateDistanceSquares()
    MAX_DISTANCE_SQ = Settings.MaxDistance * Settings.MaxDistance
    LOD_NEAR_SQ = Settings.LOD.NearDistance * Settings.LOD.NearDistance
    LOD_MEDIUM_SQ = Settings.LOD.MediumDistance * Settings.LOD.MediumDistance
    LOD_FAR_SQ = Settings.LOD.FarDistance * Settings.LOD.FarDistance
end
updateDistanceSquares()

-- Expose settings
env.ESP_V2_SETTINGS = Settings

--------------------------------------------------------------------------------
-- SECTION 2: GAME-SPECIFIC DATA & LOGIC
--------------------------------------------------------------------------------

local TeamGroups = {
    Hostile = {"Class-D", "Chaos Insurgency"},
    Foundation = {
        "Intelligence Agency", "Medical Department", "Mobile Task Force", 
        "O5 Command", "Rapid Response Team", "Scientific Department", 
        "Security Department", "Site Director", "Internal Security Department"
    }
}

local groupId = 2935212
local staffRoles = {
    "Management", "Lead Developer", "Developer", "Human Resources", 
    "Public Affairs", "Contributor", "Staff in Training"
}

local NPCSCPData = {
    { Name = "SCP-999", Class = "Safe", Path = "999" },
    { Name = "SCP-173", Class = "Euclid", Path = "scp_173", NoHumanoid = true, BodyPart = "Body" },
    { Name = "SCP-049", Class = "Euclid", Path = "049", HasAngryState = true },
    { Name = "SCP-2006", Class = "Euclid", Path = "2006.2006", HasAngryState = true },
    { Name = "SCP-939-1", Class = "Keter", Path = "SCPs.SCP-939-1" },
    { Name = "SCP-939-2", Class = "Keter", Path = "SCPs.SCP-939-2" },
    { Name = "SCP-939-3", Class = "Keter", Path = "SCPs.SCP-939-3" },
    { Name = "SCP-017", Class = "Keter", Path = "017.SCP-017" },
    { Name = "SCP-457", Class = "Keter", Path = "scp_457" },
    { Name = "SCP-106", Class = "Keter", Path = "InteriorBuild.SCP Items.SCP106" },
    { Name = "SCP-096", Class = "Euclid", Path = "SCP096" },
    { Name = "SCP-569-1", Class = "Keter", Path = "SCPs.569.SCP-569-1" },
    { Name = "SCP-569-2", Class = "Keter", Path = "SCPs.569.SCP-569-2" },
    { Name = "SCP-569-3", Class = "Keter", Path = "SCPs.569.SCP-569-3" },
    { Name = "SCP-610-H", Class = "Keter", Path = "hivemind" },
}

local ALL_WEAPONS = {
    "M4", "Taser", "M249", "UMP 45", "Stolen M4", "Glock-17", "HK-416", 
    "Heavy Turret", "AO-1780-12", "AK-74", "MP5-SD", "FAMAS", "DesertEagle", 
    "AUG-A2", "FN FAL"
}

-- Caches
local CachedSCPNames = {}
local CachedStaffRoles = {}
local CachedStaffTimestamps = {}
local CachedNPCModels = {}
local FailedNPCLookups = {}
local LastNPCRetryTime = {}
local UpdatingSCPNames = {}

local FAILED_LOOKUP = "__FAILED__"
local LastRetryTime = {}
local RETRY_INTERVAL = 5
local NPC_RETRY_INTERVAL = 10
local SCP_NAME_RETRY_INTERVAL = 10

--------------------------------------------------------------------------------
-- SECTION 3: UTILITY FUNCTIONS
--------------------------------------------------------------------------------

local function GetTeamGroup(teamName)
    if not teamName then return nil end
    for groupName, teams in pairs(TeamGroups) do
        for _, team in ipairs(teams) do
            if team == teamName then
                return groupName
            end
        end
    end
    return nil
end

local function isStaff(player)
    local now = tick()
    local cached = CachedStaffRoles[player.UserId]
    local timestamp = CachedStaffTimestamps[player.UserId]
    
    if cached and timestamp and (now - timestamp) < STAFF_CACHE_DURATION then
        if cached == FAILED_LOOKUP then
            return false, nil
        end
        return true, cached
    end
    
    if not cached then
        CachedStaffRoles[player.UserId] = FAILED_LOOKUP
        CachedStaffTimestamps[player.UserId] = now
        
        task.spawn(function()
            local success, role = pcall(function()
                return player:GetRoleInGroup(groupId)
            end)
            
            if not success or not role then
                return
            end
            
            for _, r in ipairs(staffRoles) do
                if role == r then
                    CachedStaffRoles[player.UserId] = role
                    CachedStaffTimestamps[player.UserId] = tick()
                    return
                end
            end
        end)
    end
    
    return false, nil
end

local function GetPathFromString(pathString)
    local parts = {}
    for part in string.gmatch(pathString, "[^.]+") do
        table.insert(parts, part)
    end
    local current = Workspace
    for _, part in ipairs(parts) do
        if not current then return nil end
        current = current:FindFirstChild(part)
    end
    return current
end

local function FindModelRecursive(parent, name, maxDepth)
    maxDepth = maxDepth or 2
    if maxDepth <= 0 then return nil end
    
    local found = parent:FindFirstChild(name)
    if found then return found end
    
    for _, child in pairs(parent:GetChildren()) do
        if child:IsA("Folder") or child:IsA("Model") then
            found = FindModelRecursive(child, name, maxDepth - 1)
            if found then return found end
        end
    end
    return nil
end

local function FindNPCModel(scpData)
    local model = GetPathFromString(scpData.Path)
    if model and model.Parent then return model end
    
    local searchName = scpData.Path:match("[^.]+$")
    
    local scpsFolder = Workspace:FindFirstChild("SCPs")
    if scpsFolder then
        model = FindModelRecursive(scpsFolder, searchName, 3)
        if model then return model end
    end
    
    model = FindModelRecursive(Workspace, searchName, 2)
    return model
end

local function GetPlayerSCPName(player)
    local success, result = pcall(function()
        local character = player.Character
        if character then
            local overhead = character:FindFirstChild("Overhead")
            if overhead then
                local overheadInner = overhead:FindFirstChild("overhead")
                if overheadInner then
                    local rank = overheadInner:FindFirstChild("rank")
                    if rank and rank:IsA("TextLabel") and rank.Text and string.sub(rank.Text, 1, 3) == "SCP" then
                        return rank.Text
                    end
                end
            end
        end
        
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if not playerGui then return nil end
        local hud = playerGui:FindFirstChild("Hud")
        if not hud then return nil end
        local playerlist = hud:FindFirstChild("playerlist")
        if not playerlist then return nil end
        local list = playerlist:FindFirstChild("list")
        if not list then return nil end
        local scrollFrame = list:FindFirstChild("scrollFrame")
        if not scrollFrame then return nil end
        
        for _, playerFrame in pairs(scrollFrame:GetChildren()) do
            if playerFrame:IsA("Frame") then
                local playername = playerFrame:FindFirstChild("playername")
                if playername then
                    local nameFrame = playername:FindFirstChild("Frame")
                    if nameFrame then
                        local nameLabel = nameFrame:FindFirstChild("TextLabel")
                        if nameLabel and nameLabel.Text == player.Name then
                            local rank = playerFrame:FindFirstChild("rank")
                            if rank then
                                local ranktext = rank:FindFirstChild("ranktext")
                                if ranktext and string.sub(ranktext.Text, 1, 3) == "SCP" then
                                    return ranktext.Text
                                end
                            end
                        end
                    end
                end
            end
        end
        return nil
    end)
    return success and result or nil
end

local function UpdateCachedSCPName(player)
    if not player or not player:IsA("Player") or UpdatingSCPNames[player.UserId] then
        return
    end
    UpdatingSCPNames[player.UserId] = true
    
    task.spawn(function()
        local attempts = 3
        for i = 1, attempts do
            local scpName = GetPlayerSCPName(player)
            if scpName then
                CachedSCPNames[player.UserId] = scpName
                LastRetryTime[player.UserId] = nil
                UpdatingSCPNames[player.UserId] = nil
                return
            end
            task.wait(0.3)
        end
        CachedSCPNames[player.UserId] = FAILED_LOOKUP
        LastRetryTime[player.UserId] = tick()
        UpdatingSCPNames[player.UserId] = nil
    end)
end

local function GetCachedSCPName(player)
    if not player or not player.UserId then return nil end
    local cached = CachedSCPNames[player.UserId]
    if cached == FAILED_LOOKUP then return nil end
    return cached
end

local function IsAngry(model, scpData)
    if not scpData.HasAngryState then return false end
    
    if scpData.Name == "SCP-049" then
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if humanoid then
            return humanoid.WalkSpeed ~= 8
        end
        return false
    elseif scpData.Name == "SCP-2006" then
        return not model:FindFirstChild("SpacemanHelm")
    end
    
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    return humanoid.Health < 500000
end

local function IsTraitor(player)
    if not player.Character then return false end
    local overhead = player.Character:FindFirstChild("Overhead")
    if not overhead then return false end
    overhead = overhead:FindFirstChild("overhead")
    if not overhead then return false end
    local traitor = overhead:FindFirstChild("traitor")
    if not traitor or not traitor:IsA("TextLabel") then return false end
    return traitor.Visible
end

local function HasWeapon(player)
    if player.Character then
        local tool = player.Character:FindFirstChildOfClass("Tool")
        if tool then
            for _, weaponName in ipairs(ALL_WEAPONS) do
                if tool.Name == weaponName then return true end
            end
        end
    end
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") then
                for _, weaponName in ipairs(ALL_WEAPONS) do
                    if item.Name == weaponName then return true end
                end
            end
        end
    end
    return false
end

local function IsHostileToLocal(player)
    if not player.Team or not LocalPlayer.Team then return false end
    if player.Team.Name == "SCP" or LocalPlayer.Team.Name == "SCP" then return false end
    if player.Team.Name == "Medical Department" then return false end
    
    local localGroup = GetTeamGroup(LocalPlayer.Team.Name)
    local targetGroup = GetTeamGroup(player.Team.Name)
    
    if not localGroup or not targetGroup then return false end
    if localGroup == targetGroup then return false end
    
    if localGroup == "Foundation" and targetGroup == "Hostile" then
        if not HasWeapon(player) then return false end
        return true
    elseif localGroup == "Hostile" and targetGroup == "Foundation" then
        return true
    end
    
    return false
end

local function ShouldShowESP(targetTeam)
    if not Settings.Filters.TeamFilter then return true end
    if not LocalPlayer.Team or not targetTeam then return true end
    
    local localTeamName = LocalPlayer.Team.Name
    local targetTeamName = targetTeam.Name
    
    if localTeamName == "SCP" then return true end
    if targetTeamName == "SCP" then return true end
    
    local localGroup = GetTeamGroup(localTeamName)
    local targetGroup = GetTeamGroup(targetTeamName)
    
    if not localGroup or not targetGroup then return true end
    return localGroup ~= targetGroup
end

local function FormatHealth(health)
    if health > 500000 then
        return "∞"
    else
        return tostring(math.floor(health))
    end
end

local function FormatDistance(distance)
    local unit = Settings.Components.Distance.Unit
    
    if unit == "Meters" then
        return tostring(math.floor(distance * 0.28)) .. "m"
    else
        return tostring(math.floor(distance)) .. " studs"
    end
end

local function LerpColor(c1, c2, t)
    return Color3.new(
        c1.R + (c2.R - c1.R) * t,
        c1.G + (c2.G - c1.G) * t,
        c1.B + (c2.B - c1.B) * t
    )
end

local function GetHealthColor(health, maxHealth, colors)
    local safeMax = maxHealth
    if not safeMax or safeMax <= 0 then safeMax = 100 end
    local safeHealth = health or safeMax
    local ratio = math.clamp(safeHealth / safeMax, 0, 1)
    
    local high = Color3.fromRGB(0, 255, 0)
    local mid = Color3.fromRGB(255, 255, 0)
    local low = Color3.fromRGB(255, 0, 0)
    
    if colors then
        if colors.healthHigh and typeof(colors.healthHigh) == "Color3" then
            high = colors.healthHigh
        end
        if colors.healthMid and typeof(colors.healthMid) == "Color3" then
            mid = colors.healthMid
        end
        if colors.healthLow and typeof(colors.healthLow) == "Color3" then
            low = colors.healthLow
        end
    end
    
    if ratio > 0.65 then
        return high
    elseif ratio > 0.35 then
        local t = (ratio - 0.35) / 0.3
        return LerpColor(mid, high, t)
    else
        local t = ratio / 0.35
        return LerpColor(low, mid, t)
    end
end

--------------------------------------------------------------------------------
-- SECTION 4: OBJECT POOLING SYSTEM
--------------------------------------------------------------------------------

local ObjectPool = {
    frames = {},
    lines = {},
    texts = {},
    highlights = {},
}

local function GetFromPool(poolName)
    local pool = ObjectPool[poolName]
    if pool and #pool > 0 then
        return table.remove(pool)
    end
    return nil
end

local function ReturnToPool(poolName, object)
    local pool = ObjectPool[poolName]
    if pool then
        if object:IsA("GuiObject") then
            object.Visible = false
            object.Position = UDim2.new(0, -1000, 0, -1000)
            object.Parent = nil
        elseif object:IsA("Highlight") then
            object.Enabled = false
            object.Adornee = nil
            object.Parent = nil
        end
        table.insert(pool, object)
    end
end

--------------------------------------------------------------------------------
-- SECTION 5: DRAWING SYSTEM (Frame-Based)
--------------------------------------------------------------------------------

local ESPContainer = nil

local function EnsureContainer()
    if ESPContainer and ESPContainer.Parent then
        return ESPContainer
    end
    
    -- Clean up old container if exists
    local oldContainer = CoreGui:FindFirstChild("ESP_V2_Container")
    if oldContainer then
        oldContainer:Destroy()
    end
    
    ESPContainer = Instance.new("ScreenGui")
    ESPContainer.Name = "ESP_V2_Container"
    ESPContainer.ResetOnSpawn = false
    ESPContainer.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ESPContainer.IgnoreGuiInset = true
    ESPContainer.Parent = CoreGui
    
    return ESPContainer
end

local function CreateLine()
    local pooled = GetFromPool("lines")
    if pooled then
        pooled.Visible = true
        pooled.BackgroundTransparency = 0
        pooled.Parent = EnsureContainer()
        return pooled
    end
    
    local line = Instance.new("Frame")
    line.Name = "ESPLine"
    line.BorderSizePixel = 0
    line.BackgroundTransparency = 0
    line.AnchorPoint = Vector2.new(0.5, 0.5)
    line.Parent = EnsureContainer()
    return line
end

local function CreateText()
    local pooled = GetFromPool("texts")
    if pooled then
        pooled.Visible = true
        pooled.Parent = EnsureContainer()
        return pooled
    end
    
    local text = Instance.new("TextLabel")
    text.Name = "ESPText"
    text.BackgroundTransparency = 1
    text.TextStrokeTransparency = 0
    text.Font = Enum.Font.Code
    text.TextSize = 13
    text.Parent = EnsureContainer()
    return text
end

local function CreateFrame()
    local pooled = GetFromPool("frames")
    if pooled then
        pooled.Visible = true
        pooled.Parent = EnsureContainer()
        return pooled
    end
    
    local frame = Instance.new("Frame")
    frame.Name = "ESPFrame"
    frame.BorderSizePixel = 0
    frame.Parent = EnsureContainer()
    return frame
end

local function CreateHighlight()
    local pooled = GetFromPool("highlights")
    if pooled then
        pooled.Enabled = true
        return pooled
    end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "ESPHighlight"
    return highlight
end

local function DrawLine(from, to, color, thickness, parent)
    local line = parent or CreateLine()
    
    local direction = to - from
    local center = (from + to) / 2
    local distance = direction.Magnitude
    local angle = math.atan2(direction.Y, direction.X)
    
    line.Position = UDim2.new(0, center.X, 0, center.Y)
    line.Size = UDim2.new(0, distance, 0, thickness)
    line.Rotation = math.deg(angle)
    line.BackgroundTransparency = 0
    
    local finalColor = Color3.fromRGB(255, 255, 255)
    if color and typeof(color) == "Color3" then
        if color.R > 0.01 or color.G > 0.01 or color.B > 0.01 then
            finalColor = color
        end
    end
    line.BackgroundColor3 = finalColor
    line.Visible = true
    
    return line
end

local function DrawLineWithOutline(from, to, color, thickness, outlineColor, outlineThickness)
    local lines = {}
    
    -- Outline
    local outline = CreateLine()
    DrawLine(from, to, outlineColor, thickness + outlineThickness * 2, outline)
    table.insert(lines, outline)
    
    -- Main line
    local main = CreateLine()
    DrawLine(from, to, color, thickness, main)
    table.insert(lines, main)
    
    return lines
end

--------------------------------------------------------------------------------
-- SECTION 6: ESP COMPONENT CLASSES
--------------------------------------------------------------------------------

-- Box Component
local BoxComponent = {}
BoxComponent.__index = BoxComponent

function BoxComponent.new(colors)
    local self = setmetatable({}, BoxComponent)
    self.lines = {}
    self.outlines = {}
    self.fill = nil
    self.colors = colors
    self.visible = false
    self.lastX, self.lastY, self.lastW, self.lastH = 0, 0, 0, 0
    return self
end

function BoxComponent:CreateCornerBox()
    for i = 1, 8 do
        self.outlines[i] = CreateLine()
        self.lines[i] = CreateLine()
    end
end

function BoxComponent:CreateSquareBox()
    for i = 1, 4 do
        self.outlines[i] = CreateLine()
        self.lines[i] = CreateLine()
    end
end

function BoxComponent:Create3DBox()
    for i = 1, 16 do
        self.lines[i] = CreateLine()
    end
end

function BoxComponent:UpdateCornerBox(x, y, w, h, colors)
    local ix, iy, iw, ih = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
    if ix == self.lastX and iy == self.lastY and iw == self.lastW and ih == self.lastH and self.visible then
        return
    end
    self.lastX, self.lastY, self.lastW, self.lastH = ix, iy, iw, ih
    
    local thickness = Settings.Components.Box.Thickness
    local cornerLength = math.max(math.min(w, h) * 0.3, 8)
    local color = Color3.fromRGB(255, 255, 255)
    local passedColors = colors or self.colors
    if passedColors and passedColors.box and typeof(passedColors.box) == "Color3" then
        color = passedColors.box
    end
    
    local x2, y2 = x + w, y + h
    
    DrawLine(Vector2.new(x, y), Vector2.new(x + cornerLength, y), color, thickness, self.lines[1])
    DrawLine(Vector2.new(x, y), Vector2.new(x, y + cornerLength), color, thickness, self.lines[2])
    
    DrawLine(Vector2.new(x2, y), Vector2.new(x2 - cornerLength, y), color, thickness, self.lines[3])
    DrawLine(Vector2.new(x2, y), Vector2.new(x2, y + cornerLength), color, thickness, self.lines[4])
    
    DrawLine(Vector2.new(x, y2), Vector2.new(x + cornerLength, y2), color, thickness, self.lines[5])
    DrawLine(Vector2.new(x, y2), Vector2.new(x, y2 - cornerLength), color, thickness, self.lines[6])
    
    DrawLine(Vector2.new(x2, y2), Vector2.new(x2 - cornerLength, y2), color, thickness, self.lines[7])
    DrawLine(Vector2.new(x2, y2), Vector2.new(x2, y2 - cornerLength), color, thickness, self.lines[8])
    
    self.visible = true
end

function BoxComponent:UpdateSquareBox(x, y, w, h, colors)
    local ix, iy, iw, ih = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
    if ix == self.lastX and iy == self.lastY and iw == self.lastW and ih == self.lastH and self.visible then
        return
    end
    self.lastX, self.lastY, self.lastW, self.lastH = ix, iy, iw, ih
    
    local thickness = Settings.Components.Box.Thickness
    local color = Color3.fromRGB(255, 255, 255)
    local passedColors = colors or self.colors
    if passedColors and passedColors.box and typeof(passedColors.box) == "Color3" then
        color = passedColors.box
    end
    
    local x2, y2 = x + w, y + h
    
    DrawLine(Vector2.new(x, y), Vector2.new(x2, y), color, thickness, self.lines[1])
    DrawLine(Vector2.new(x, y2), Vector2.new(x2, y2), color, thickness, self.lines[2])
    DrawLine(Vector2.new(x, y), Vector2.new(x, y2), color, thickness, self.lines[3])
    DrawLine(Vector2.new(x2, y), Vector2.new(x2, y2), color, thickness, self.lines[4])
    
    if self.fill then
        self.fill.Position = UDim2.new(0, x, 0, y)
        self.fill.Size = UDim2.new(0, w, 0, h)
        local fillColor = Color3.fromRGB(255, 255, 255)
        if passedColors and passedColors.boxFill and typeof(passedColors.boxFill) == "Color3" then
            fillColor = passedColors.boxFill
        end
        self.fill.BackgroundColor3 = fillColor
        self.fill.BackgroundTransparency = Settings.Components.Box.FillTransparency
        self.fill.Visible = true
    end
    
    self.visible = true
end

function BoxComponent:Update3DBox(cframe, size, camera, colors)
    local thickness = Settings.Components.Box.Thickness
    local color = Color3.fromRGB(255, 255, 255)
    local passedColors = colors or self.colors
    if passedColors and passedColors.box and typeof(passedColors.box) == "Color3" then
        color = passedColors.box
    end
    
    -- Calculate 8 corners of the 3D box
    local corners3D = {
        cframe * CFrame.new(-size.X/2, size.Y/2, -size.Z/2),   -- Front TL
        cframe * CFrame.new(size.X/2, size.Y/2, -size.Z/2),    -- Front TR
        cframe * CFrame.new(-size.X/2, -size.Y/2, -size.Z/2),  -- Front BL
        cframe * CFrame.new(size.X/2, -size.Y/2, -size.Z/2),   -- Front BR
        cframe * CFrame.new(-size.X/2, size.Y/2, size.Z/2),    -- Back TL
        cframe * CFrame.new(size.X/2, size.Y/2, size.Z/2),     -- Back TR
        cframe * CFrame.new(-size.X/2, -size.Y/2, size.Z/2),   -- Back BL
        cframe * CFrame.new(size.X/2, -size.Y/2, size.Z/2),    -- Back BR
    }
    
    -- Convert to screen space
    local corners2D = {}
    local allVisible = true
    for i, cf in ipairs(corners3D) do
        local pos, visible = camera:WorldToViewportPoint(cf.Position)
        if not visible or pos.Z < 0 then
            allVisible = false
            break
        end
        corners2D[i] = Vector2.new(pos.X, pos.Y)
    end
    
    if not allVisible then
        self:Hide()
        return
    end
    
    -- Draw edges
    local edges = {
        {1, 2}, {2, 4}, {4, 3}, {3, 1},  -- Front face
        {5, 6}, {6, 8}, {8, 7}, {7, 5},  -- Back face
        {1, 5}, {2, 6}, {3, 7}, {4, 8},  -- Connecting
    }
    
    for i, edge in ipairs(edges) do
        if self.lines[i] then
            DrawLine(corners2D[edge[1]], corners2D[edge[2]], color, thickness, self.lines[i])
        end
    end
    
    self.visible = true
end

function BoxComponent:Hide()
    for _, line in pairs(self.lines) do
        if line then line.Visible = false end
    end
    for _, outline in pairs(self.outlines) do
        if outline then outline.Visible = false end
    end
    if self.fill then self.fill.Visible = false end
    self.visible = false
    self.lastX, self.lastY, self.lastW, self.lastH = 0, 0, 0, 0
end

function BoxComponent:Destroy()
    for _, line in pairs(self.lines) do
        if line then ReturnToPool("lines", line) end
    end
    for _, outline in pairs(self.outlines) do
        if outline then ReturnToPool("lines", outline) end
    end
    if self.fill then ReturnToPool("frames", self.fill) end
    self.lines = {}
    self.outlines = {}
    self.fill = nil
end

-- Health Bar Component
local HealthBarComponent = {}
HealthBarComponent.__index = HealthBarComponent

function HealthBarComponent.new(colors)
    local self = setmetatable({}, HealthBarComponent)
    self.background = CreateFrame()
    self.fill = CreateFrame()
    self.text = nil
    if Settings.Components.HealthBar.ShowText then
        self.text = CreateText()
    end
    self.colors = colors
    self.visible = false
    self.lastX, self.lastY, self.lastHealth = 0, 0, -1
    return self
end

function HealthBarComponent:Update(x, y, w, h, health, maxHealth, colors)
    local ix, iy = math.floor(x), math.floor(y)
    local iHealth = math.floor(health or 0)
    if ix == self.lastX and iy == self.lastY and iHealth == self.lastHealth and self.visible then
        return
    end
    self.lastX, self.lastY, self.lastHealth = ix, iy, iHealth
    
    local barWidth = Settings.Components.HealthBar.Width
    local position = Settings.Components.HealthBar.Position
    local padding = Settings.Components.HealthBar.Padding or 4
    local safeMaxHealth = maxHealth
    if not safeMaxHealth or safeMaxHealth <= 0 then
        safeMaxHealth = 100
    end
    local safeHealth = health or safeMaxHealth
    local healthRatio = math.clamp(safeHealth / safeMaxHealth, 0, 1)
    local passedColors = colors or self.colors
    local safeColors = passedColors or {
        healthHigh = Color3.fromRGB(0, 255, 0),
        healthMid = Color3.fromRGB(255, 255, 0),
        healthLow = Color3.fromRGB(255, 0, 0),
    }
    if not safeColors.healthHigh then safeColors.healthHigh = Color3.fromRGB(0, 255, 0) end
    if not safeColors.healthMid then safeColors.healthMid = Color3.fromRGB(255, 255, 0) end
    if not safeColors.healthLow then safeColors.healthLow = Color3.fromRGB(255, 0, 0) end
    local healthColor = GetHealthColor(safeHealth, safeMaxHealth, safeColors)
    
    local barX, barY, barW, barH
    
    if position == "Left" then
        barX = x - barWidth - padding
        barY = y
        barW = barWidth
        barH = h
    elseif position == "Right" then
        barX = x + w + padding
        barY = y
        barW = barWidth
        barH = h
    elseif position == "Top" then
        barX = x
        barY = y - barWidth - padding
        barW = w
        barH = barWidth
    else
        barX = x
        barY = y + h + padding
        barW = w
        barH = barWidth
    end
    
    -- Background
    self.background.Position = UDim2.new(0, barX - 1, 0, barY - 1)
    self.background.Size = UDim2.new(0, barW + 2, 0, barH + 2)
    self.background.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    self.background.BackgroundTransparency = 0.3
    self.background.Visible = true
    
    -- Fill
    if position == "Left" or position == "Right" then
        local fillHeight = barH * healthRatio
        self.fill.Position = UDim2.new(0, barX, 0, barY + barH - fillHeight)
        self.fill.Size = UDim2.new(0, barW, 0, fillHeight)
    else
        local fillWidth = barW * healthRatio
        self.fill.Position = UDim2.new(0, barX, 0, barY)
        self.fill.Size = UDim2.new(0, fillWidth, 0, barH)
    end
    self.fill.BackgroundColor3 = healthColor
    self.fill.BackgroundTransparency = 0
    self.fill.Visible = true
    
    -- Text
    if self.text then
        local healthText = FormatHealth(health)
        if Settings.Components.HealthBar.TextPosition == "Side" then
            if position == "Left" then
                self.text.Position = UDim2.new(0, barX - 2, 0, barY + barH / 2)
                self.text.AnchorPoint = Vector2.new(1, 0.5)
            elseif position == "Right" then
                self.text.Position = UDim2.new(0, barX + barW + 2, 0, barY + barH / 2)
                self.text.AnchorPoint = Vector2.new(0, 0.5)
            else
                self.text.Position = UDim2.new(0, barX + barW / 2, 0, barY - 1)
                self.text.AnchorPoint = Vector2.new(0.5, 1)
            end
        end
        self.text.Text = healthText
        self.text.TextColor3 = healthColor
        self.text.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        self.text.TextSize = 11
        self.text.Size = UDim2.new(0, 50, 0, 20)
        self.text.Visible = true
    end
    
    self.visible = true
end

function HealthBarComponent:Hide()
    self.background.Visible = false
    self.fill.Visible = false
    if self.text then self.text.Visible = false end
    self.visible = false
    self.lastX, self.lastY, self.lastHealth = 0, 0, -1
end

function HealthBarComponent:Destroy()
    ReturnToPool("frames", self.background)
    ReturnToPool("frames", self.fill)
    if self.text then ReturnToPool("texts", self.text) end
end

-- Tracer Component
local TracerComponent = {}
TracerComponent.__index = TracerComponent

function TracerComponent.new(colors)
    local self = setmetatable({}, TracerComponent)
    self.outline = CreateLine()
    self.line = CreateLine()
    self.colors = colors
    self.visible = false
    self.lastTargetX, self.lastTargetY = 0, 0
    return self
end

function TracerComponent:Update(targetPos, colors)
    local itx, ity = math.floor(targetPos.X), math.floor(targetPos.Y)
    if itx == self.lastTargetX and ity == self.lastTargetY and self.visible then
        return
    end
    self.lastTargetX, self.lastTargetY = itx, ity
    
    local origin = Settings.Components.Tracer.Origin
    local viewportSize = Camera.ViewportSize
    
    local fromPos
    if origin == "Mouse" then
        local mousePos = UserInputService:GetMouseLocation()
        fromPos = Vector2.new(mousePos.X, mousePos.Y)
    else
        if not lastViewportSize or lastViewportSize ~= viewportSize then
            lastViewportSize = viewportSize
            cachedTracerOrigin = nil
        end
        if not cachedTracerOrigin then
            if origin == "Bottom" then
                cachedTracerOrigin = Vector2.new(viewportSize.X / 2, viewportSize.Y)
            elseif origin == "Top" then
                cachedTracerOrigin = Vector2.new(viewportSize.X / 2, 0)
            elseif origin == "Center" then
                cachedTracerOrigin = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
            else
                cachedTracerOrigin = Vector2.new(viewportSize.X / 2, viewportSize.Y)
            end
        end
        fromPos = cachedTracerOrigin
    end
    
    local thickness = Settings.Components.Tracer.Thickness
    local color = Color3.fromRGB(255, 255, 255)
    local passedColors = colors or self.colors
    if passedColors and passedColors.tracer and typeof(passedColors.tracer) == "Color3" then
        color = passedColors.tracer
    end
    
    DrawLine(fromPos, targetPos, Color3.fromRGB(0, 0, 0), thickness + 2, self.outline)
    DrawLine(fromPos, targetPos, color, thickness, self.line)
    
    self.visible = true
end

function TracerComponent:Hide()
    self.line.Visible = false
    self.outline.Visible = false
    self.visible = false
    self.lastTargetX, self.lastTargetY = 0, 0
end

function TracerComponent:Destroy()
    ReturnToPool("lines", self.line)
    ReturnToPool("lines", self.outline)
end

-- Text Component (Name + Distance + Custom Info)
local TextComponent = {}
TextComponent.__index = TextComponent

function TextComponent.new(colors)
    local self = setmetatable({}, TextComponent)
    self.nameLabel = CreateText()
    self.distanceLabel = nil
    self.infoLabel = nil
    if Settings.Components.Distance.Enabled then
        self.distanceLabel = CreateText()
    end
    self.colors = colors
    self.visible = false
    self.lastX, self.lastY, self.lastName = 0, 0, ""
    return self
end

function TextComponent:Update(x, y, w, name, distance, info, colors)
    local ix, iy = math.floor(x), math.floor(y)
    if ix == self.lastX and iy == self.lastY and name == self.lastName and self.visible then
        return
    end
    self.lastX, self.lastY, self.lastName = ix, iy, name
    
    local yOffset = 0
    
    local textColor = Color3.fromRGB(255, 255, 255)
    local textOutline = Color3.fromRGB(0, 0, 0)
    local passedColors = colors or self.colors
    if passedColors then
        if passedColors.text and typeof(passedColors.text) == "Color3" then
            textColor = passedColors.text
        end
        if passedColors.textOutline and typeof(passedColors.textOutline) == "Color3" then
            textOutline = passedColors.textOutline
        end
    end
    
    -- Name label
    if Settings.Components.Name.Enabled then
        self.nameLabel.Position = UDim2.new(0, x + w / 2, 0, y - 18)
        self.nameLabel.Size = UDim2.new(0, 200, 0, 16)
        self.nameLabel.AnchorPoint = Vector2.new(0.5, 0)
        self.nameLabel.Text = name
        self.nameLabel.TextColor3 = textColor
        self.nameLabel.TextStrokeColor3 = textOutline
        self.nameLabel.Font = Settings.Components.Name.Font
        self.nameLabel.TextSize = Settings.Components.Name.Size
        self.nameLabel.TextStrokeTransparency = Settings.Components.Name.Outline and 0 or 1
        self.nameLabel.Visible = true
        yOffset = yOffset + 16
    else
        self.nameLabel.Visible = false
    end
    
    -- Distance label
    if self.distanceLabel and Settings.Components.Distance.Enabled then
        self.distanceLabel.Position = UDim2.new(0, x + w / 2, 0, y - 18 - yOffset)
        self.distanceLabel.Size = UDim2.new(0, 100, 0, 14)
        self.distanceLabel.AnchorPoint = Vector2.new(0.5, 0)
        self.distanceLabel.Text = FormatDistance(distance)
        self.distanceLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        self.distanceLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        self.distanceLabel.Font = Enum.Font.Code
        self.distanceLabel.TextSize = 11
        self.distanceLabel.TextStrokeTransparency = 0
        self.distanceLabel.Visible = true
    elseif self.distanceLabel then
        self.distanceLabel.Visible = false
    end
    
    self.visible = true
end

function TextComponent:Hide()
    self.nameLabel.Visible = false
    if self.distanceLabel then self.distanceLabel.Visible = false end
    if self.infoLabel then self.infoLabel.Visible = false end
    self.visible = false
    self.lastX, self.lastY, self.lastName = 0, 0, ""
end

function TextComponent:Destroy()
    ReturnToPool("texts", self.nameLabel)
    if self.distanceLabel then ReturnToPool("texts", self.distanceLabel) end
    if self.infoLabel then ReturnToPool("texts", self.infoLabel) end
end

-- Look Direction Component
local LookDirectionComponent = {}
LookDirectionComponent.__index = LookDirectionComponent

function LookDirectionComponent.new(colors)
    local self = setmetatable({}, LookDirectionComponent)
    self.line = CreateLine()
    self.colors = colors
    self.visible = false
    return self
end

function LookDirectionComponent:Update(character, camera)
    local head = character:FindFirstChild("Head")
    if not head then
        self:Hide()
        return
    end
    
    local lookVector = head.CFrame.LookVector
    local headPos = head.Position
    local endPos = headPos + lookVector * Settings.Components.LookDirection.Length
    
    local headScreen, headVisible = camera:WorldToViewportPoint(headPos)
    local endScreen, endVisible = camera:WorldToViewportPoint(endPos)
    
    if not headVisible or headScreen.Z < 0 then
        self:Hide()
        return
    end
    
    local from = Vector2.new(headScreen.X, headScreen.Y)
    local to
    
    if endVisible and endScreen.Z > 0 then
        to = Vector2.new(endScreen.X, endScreen.Y)
    else
        -- Clamp to screen edge
        local dir = (Vector2.new(endScreen.X, endScreen.Y) - from).Unit
        to = from + dir * 100
    end
    
    local color = self.colors and self.colors.primary or Color3.fromRGB(255, 255, 255)
    DrawLine(from, to, color, Settings.Components.LookDirection.Thickness, self.line)
    self.visible = true
end

function LookDirectionComponent:Hide()
    self.line.Visible = false
    self.visible = false
end

function LookDirectionComponent:Destroy()
    ReturnToPool("lines", self.line)
end

-- Cham Component
local ChamComponent = {}
ChamComponent.__index = ChamComponent

function ChamComponent.new(colors)
    local self = setmetatable({}, ChamComponent)
    self.highlight = CreateHighlight()
    self.colors = colors
    self.visible = false
    self.currentTarget = nil
    self.lastFillColor = nil
    return self
end

function ChamComponent:Update(target, colors)
    local fillColor = Color3.fromRGB(255, 255, 255)
    local outlineColor = Color3.fromRGB(200, 200, 200)
    local passedColors = colors or self.colors
    if passedColors then
        if passedColors.chamFill and typeof(passedColors.chamFill) == "Color3" then
            fillColor = passedColors.chamFill
        end
        if passedColors.chamGlow and typeof(passedColors.chamGlow) == "Color3" then
            outlineColor = passedColors.chamGlow
        end
    end
    
    if self.currentTarget == target and self.lastFillColor == fillColor and self.visible then
        return
    end
    self.lastFillColor = fillColor
    
    self.highlight.FillColor = fillColor
    self.highlight.FillTransparency = Settings.Components.Chams.FillTransparency
    self.highlight.OutlineColor = outlineColor
    self.highlight.OutlineTransparency = 0
    self.highlight.DepthMode = Settings.Components.Chams.DepthMode == "AlwaysOnTop" 
        and Enum.HighlightDepthMode.AlwaysOnTop 
        or Enum.HighlightDepthMode.Occluded
    
    if self.currentTarget ~= target then
        self.highlight.Adornee = target
        self.highlight.Parent = target
        self.currentTarget = target
    end
    
    if not self.highlight.Enabled then
        self.highlight.Enabled = true
    end
    self.visible = true
end

function ChamComponent:Hide()
    self.highlight.Enabled = false
    self.highlight.Parent = nil
    self.currentTarget = nil
    self.visible = false
    self.lastFillColor = nil
end

function ChamComponent:Destroy()
    self.highlight:Destroy()
end

--------------------------------------------------------------------------------
-- SECTION 7: ESP ENTITY CLASS
--------------------------------------------------------------------------------

local ESPEntity = {}
ESPEntity.__index = ESPEntity

function ESPEntity.new(key, entityType, target, category, customData, initialColors)
    local self = setmetatable({}, ESPEntity)
    
    self.key = key
    self.entityType = entityType
    self.target = target
    self.category = category
    self.customData = customData or {}
    self.priority = Settings.Categories[category] and Settings.Categories[category].priority or 0
    
    -- State
    self.isVisible = false
    self.distance = 0
    self.health = 100
    self.maxHealth = 100
    self.screenPosition = Vector2.new(0, 0)
    self.targetScreenPosition = Vector2.new(0, 0)
    self.boxBounds = {x = 0, y = 0, w = 0, h = 0}
    self.targetBoxBounds = {x = 0, y = 0, w = 0, h = 0}
    self.lodLevel = 1  -- 1 = Full, 2 = Medium, 3 = Low, 4 = Minimal
    
    -- Lifecycle
    self.createdAt = tick()
    self.lastUpdate = 0
    self.lastFullUpdate = 0
    self.dirty = true
    self.interpolationSpeed = 15
    self.componentsCreated = false
    self.lastSettingsHash = 0
    
    -- Cached references (avoid FindFirstChild every frame)
    self.cachedRootPart = nil
    self.cachedHumanoid = nil
    self.cachedCharacterSize = nil
    self.lastSizeCacheTime = 0
    
    -- Get colors - use initialColors if provided, otherwise fall back to category/neutral
    -- Always deep copy to ensure we have our own mutable color table
    local sourceColors = initialColors or Settings.Colors[category] or Settings.Colors.Neutral
    self.colors = {
        primary = sourceColors.primary or Color3.fromRGB(255, 255, 255),
        secondary = sourceColors.secondary or Color3.fromRGB(200, 200, 200),
        text = sourceColors.text or Color3.fromRGB(255, 255, 255),
        textOutline = sourceColors.textOutline or Color3.fromRGB(0, 0, 0),
        box = sourceColors.box or Color3.fromRGB(255, 255, 255),
        boxFill = sourceColors.boxFill or Color3.fromRGB(255, 255, 255),
        tracer = sourceColors.tracer or Color3.fromRGB(255, 255, 255),
        healthHigh = sourceColors.healthHigh or Color3.fromRGB(0, 255, 0),
        healthMid = sourceColors.healthMid or Color3.fromRGB(255, 255, 0),
        healthLow = sourceColors.healthLow or Color3.fromRGB(255, 0, 0),
        chamFill = sourceColors.chamFill or Color3.fromRGB(255, 255, 255),
        chamOutline = sourceColors.chamOutline or Color3.fromRGB(200, 200, 200),
        chamGlow = sourceColors.chamGlow or Color3.fromRGB(255, 255, 255),
    }
    
    -- Track current component styles for change detection
    self.currentBoxStyle = nil
    
    -- Components (created lazily based on settings and LOD)
    self.components = {
        box = nil,
        healthBar = nil,
        tracer = nil,
        text = nil,
        lookDirection = nil,
        cham = nil,
    }
    
    return self
end

function ESPEntity:GetRootPart()
    if self.cachedRootPart and self.cachedRootPart.Parent then
        return self.cachedRootPart
    end
    
    if self.entityType == "Item" or self.entityType == "SCP963" then
        self.cachedRootPart = self.target
        return self.target
    end
    
    local target = self.target
    if target:IsA("Model") then
        self.cachedRootPart = target:FindFirstChild("HumanoidRootPart") 
            or target.PrimaryPart 
            or target:FindFirstChildWhichIsA("BasePart")
    elseif target:IsA("BasePart") then
        self.cachedRootPart = target
    end
    return self.cachedRootPart
end

function ESPEntity:GetHumanoid()
    if self.cachedHumanoid and self.cachedHumanoid.Parent then
        return self.cachedHumanoid
    end
    if self.target:IsA("Model") then
        self.cachedHumanoid = self.target:FindFirstChildOfClass("Humanoid")
        return self.cachedHumanoid
    end
    return nil
end

function ESPEntity:GetCharacterSize()
    local now = tick()
    if self.cachedCharacterSize and (now - self.lastSizeCacheTime) < 1.0 then
        return self.cachedCharacterSize
    end
    self.lastSizeCacheTime = now
    
    if self.target:IsA("Model") then
        self.cachedCharacterSize = self.target:GetExtentsSize()
    elseif self.target:IsA("BasePart") then
        self.cachedCharacterSize = self.target.Size
    else
        self.cachedCharacterSize = DEFAULT_SIZE
    end
    return self.cachedCharacterSize
end

function ESPEntity:CalculateLOD()
    if not Settings.LOD.Enabled then
        self.lodLevel = 1
        return
    end
    
    local distSq = self.distance * self.distance
    if distSq <= LOD_NEAR_SQ then
        self.lodLevel = 1
    elseif distSq <= LOD_MEDIUM_SQ then
        self.lodLevel = 2
    elseif distSq <= LOD_FAR_SQ then
        self.lodLevel = 3
    else
        self.lodLevel = 4
    end
end

local function GetSettingsHash()
    local hash = 0
    if Settings.Components.Box.Enabled then hash = hash + 1 end
    if Settings.Components.HealthBar.Enabled then hash = hash + 2 end
    if Settings.Components.Tracer.Enabled then hash = hash + 4 end
    if Settings.Components.Name.Enabled then hash = hash + 8 end
    if Settings.Components.Distance.Enabled then hash = hash + 16 end
    if Settings.Components.Chams.Enabled then hash = hash + 32 end
    if Settings.Components.Box.Style == "Corner" then hash = hash + 64
    elseif Settings.Components.Box.Style == "Square" then hash = hash + 128
    elseif Settings.Components.Box.Style == "3D" then hash = hash + 192 end
    return hash
end

function ESPEntity:CreateComponents()
    local currentHash = GetSettingsHash()
    if self.componentsCreated and currentHash == self.lastSettingsHash then
        return
    end
    self.lastSettingsHash = currentHash
    self.componentsCreated = true
    
    -- Box - destroy if disabled or style changed or is Item
    if self.components.box then
        if not Settings.Components.Box.Enabled or self.currentBoxStyle ~= Settings.Components.Box.Style or self.entityType == "Item" then
            self.components.box:Destroy()
            self.components.box = nil
            self.currentBoxStyle = nil
        end
    end
    
    -- Create box if enabled and doesn't exist (NOT for Items - they only get chams)
    if Settings.Components.Box.Enabled and self.lodLevel <= 3 and self.entityType ~= "Item" then
        if not self.components.box then
            self.components.box = BoxComponent.new(self.colors)
            local style = Settings.Components.Box.Style
            self.currentBoxStyle = style
            if style == "Corner" then
                self.components.box:CreateCornerBox()
            elseif style == "Square" then
                self.components.box:CreateSquareBox()
            elseif style == "3D" and self.lodLevel == 1 then
                self.components.box:Create3DBox()
            else
                self.components.box:CreateCornerBox()
            end
        end
    end
    
    -- Health Bar - destroy if disabled
    if self.components.healthBar and not Settings.Components.HealthBar.Enabled then
        self.components.healthBar:Destroy()
        self.components.healthBar = nil
    end
    
    -- Create health bar if enabled (removed LOD limit - always show)
    if Settings.Components.HealthBar.Enabled and self:GetHumanoid() then
        if not self.components.healthBar then
            self.components.healthBar = HealthBarComponent.new(self.colors)
        end
    end
    
    -- Tracer - destroy if disabled
    if self.components.tracer and not Settings.Components.Tracer.Enabled then
        self.components.tracer:Destroy()
        self.components.tracer = nil
    end
    
    -- Create tracer if enabled
    if Settings.Components.Tracer.Enabled then
        if not self.components.tracer then
            self.components.tracer = TracerComponent.new(self.colors)
        end
    end
    
    -- Text - recreate if distance setting changed or disabled
    local needsText = Settings.Components.Name.Enabled or Settings.Components.Distance.Enabled
    local hasDistanceLabel = self.components.text and self.components.text.distanceLabel ~= nil
    local wantsDistanceLabel = Settings.Components.Distance.Enabled
    
    if self.components.text and (not needsText or hasDistanceLabel ~= wantsDistanceLabel) then
        self.components.text:Destroy()
        self.components.text = nil
    end
    
    -- Create text if enabled (all entity types including SCP963, but not generic Item)
    if needsText and self.entityType ~= "Item" then
        if not self.components.text then
            self.components.text = TextComponent.new(self.colors)
        end
    end
    
    -- Chams - destroy if disabled
    if self.components.cham and not Settings.Components.Chams.Enabled then
        self.components.cham:Destroy()
        self.components.cham = nil
    end
    
    -- Create chams if enabled (for ALL entities including Items)
    if Settings.Components.Chams.Enabled then
        if not self.components.cham then
            self.components.cham = ChamComponent.new(self.colors)
        end
    end
end

function ESPEntity:UpdateColors(newColors)
    if not newColors then return end
    self.colors = newColors
    for name, component in pairs(self.components) do
        if component then
            component.colors = newColors
            if name == "box" and component.lines then
                for _, line in pairs(component.lines) do
                    if line and line.BackgroundColor3 then
                        line.BackgroundColor3 = newColors.box or Color3.fromRGB(255, 255, 255)
                    end
                end
            end
            if name == "tracer" then
                if component.line and component.line.BackgroundColor3 then
                    component.line.BackgroundColor3 = newColors.tracer or Color3.fromRGB(255, 255, 255)
                end
            end
            if name == "healthBar" then
                if component.fill and component.fill.BackgroundColor3 then
                    component.fill.BackgroundColor3 = GetHealthColor(self.health or 100, self.maxHealth or 100, newColors)
                end
            end
            if name == "cham" and component.highlight then
                component.highlight.FillColor = newColors.chamFill or Color3.fromRGB(255, 255, 255)
                component.highlight.OutlineColor = newColors.chamGlow or Color3.fromRGB(200, 200, 200)
            end
        end
    end
    self.dirty = true
end

function ESPEntity:CalculateBoxBounds(rootPart, camera, dt)
    local size = self:GetCharacterSize()
    local cframe = rootPart.CFrame
    
    local topPos = (cframe * CFrame.new(0, size.Y / 2, 0)).Position
    local bottomPos = (cframe * CFrame.new(0, -size.Y / 2, 0)).Position
    
    local topScreen, topVisible = camera:WorldToViewportPoint(topPos)
    local bottomScreen, bottomVisible = camera:WorldToViewportPoint(bottomPos)
    
    if not topVisible or not bottomVisible then
        return false
    end
    
    local height = math.abs(bottomScreen.Y - topScreen.Y)
    local width = height * 0.6
    local centerX = (topScreen.X + bottomScreen.X) / 2
    
    local targetX = centerX - width / 2
    local targetY = topScreen.Y
    local targetW = width
    local targetH = height
    
    self.targetBoxBounds.x = targetX
    self.targetBoxBounds.y = targetY
    self.targetBoxBounds.w = targetW
    self.targetBoxBounds.h = targetH
    self.targetScreenPosition = Vector2.new(centerX, (topScreen.Y + bottomScreen.Y) / 2)
    
    local lerpFactor = math.min(1, (dt or 0.016) * self.interpolationSpeed)
    
    if self.lodLevel <= 2 or not self.isVisible then
        self.boxBounds.x = targetX
        self.boxBounds.y = targetY
        self.boxBounds.w = targetW
        self.boxBounds.h = targetH
        self.screenPosition = self.targetScreenPosition
    else
        self.boxBounds.x = self.boxBounds.x + (targetX - self.boxBounds.x) * lerpFactor
        self.boxBounds.y = self.boxBounds.y + (targetY - self.boxBounds.y) * lerpFactor
        self.boxBounds.w = self.boxBounds.w + (targetW - self.boxBounds.w) * lerpFactor
        self.boxBounds.h = self.boxBounds.h + (targetH - self.boxBounds.h) * lerpFactor
        self.screenPosition = Vector2.new(
            self.screenPosition.X + (self.targetScreenPosition.X - self.screenPosition.X) * lerpFactor,
            self.screenPosition.Y + (self.targetScreenPosition.Y - self.screenPosition.Y) * lerpFactor
        )
    end
    
    return true
end

function ESPEntity:Update(camera, dt)
    dt = dt or 0.016
    local rootPart = self:GetRootPart()
    if not rootPart or not rootPart.Parent then
        self:Hide()
        return false
    end
    
    if self.entityType == "Item" or self.entityType == "SCP963" then
        local camera = Workspace.CurrentCamera
        self.distance = (rootPart.Position - camera.CFrame.Position).Magnitude
        
        if self.distance > Settings.MaxDistance then
            self:Hide()
            return false
        end
        
        local screenPos, visible = camera:WorldToViewportPoint(rootPart.Position)
        if not visible or screenPos.Z < 0 then
            self:Hide()
            return false
        end
        
        self:CreateComponents()
        
        local size = rootPart.Size
        local height = math.max(size.Y, size.X, size.Z) * 50 / self.distance
        local width = height * 0.8
        
        local boxX = screenPos.X - width / 2
        local boxY = screenPos.Y - height / 2
        
        self.boxBounds.x = boxX
        self.boxBounds.y = boxY
        self.boxBounds.w = width
        self.boxBounds.h = height
        local screenPosVec = Vector2.new(screenPos.X, screenPos.Y)
        self.screenPosition = screenPosVec
        
        if self.components.box then
            self.components.box:UpdateCornerBox(boxX, boxY, width, height, self.colors)
        end
        
        if self.components.tracer then
            self.components.tracer:Update(screenPosVec, self.colors)
        end
        
        if self.components.text then
            local displayName = self:GetDisplayName()
            self.components.text:Update(boxX, boxY, width, displayName, self.distance, nil, self.colors)
        end
        
        if self.components.cham then
            self.components.cham:Update(rootPart, self.colors)
        end
        
        self.isVisible = true
        self.lastUpdate = tick()
        return true
    end
    
    if self.entityType == "Player" and self.customData.player then
        local player = self.customData.player
        if player then
            local cachedColor = playerColorCache[player.UserId]
            if cachedColor then
                if Settings.Filters.HostileColors and self.customData.isHostile then
                    self.colors.box = HOSTILE_BOX_COLOR
                    self.colors.tracer = HOSTILE_BOX_COLOR
                    self.colors.chamFill = HOSTILE_CHAM_FILL
                    self.colors.chamOutline = HOSTILE_CHAM_OUTLINE
                    self.colors.chamGlow = HOSTILE_CHAM_OUTLINE
                else
                    self.colors.box = cachedColor
                    self.colors.tracer = cachedColor
                    self.colors.chamFill = cachedColor
                    self.colors.chamOutline = cachedColor
                    self.colors.chamGlow = cachedColor
                end
            end
        end
    end
    
    -- Calculate distance
    self.distance = (rootPart.Position - camera.CFrame.Position).Magnitude
    
    -- Check max distance
    if self.distance > Settings.MaxDistance then
        self:Hide()
        return false
    end
    
    -- Check if on screen
    local screenPos, visible = camera:WorldToViewportPoint(rootPart.Position)
    if not visible or screenPos.Z < 0 then
        self:Hide()
        return false
    end
    
    -- Calculate LOD
    self:CalculateLOD()
    
    -- Create/update components based on LOD
    self:CreateComponents()
    
    -- Calculate box bounds with interpolation
    if not self:CalculateBoxBounds(rootPart, camera, dt) then
        self:Hide()
        return false
    end
    
    -- Update health
    local humanoid = self:GetHumanoid()
    if humanoid then
        self.health = humanoid.Health
        self.maxHealth = humanoid.MaxHealth
    end
    
    -- Update components
    local b = self.boxBounds
    
    -- Box
    if self.components.box then
        local style = Settings.Components.Box.Style
        if style == "Corner" then
            self.components.box:UpdateCornerBox(b.x, b.y, b.w, b.h, self.colors)
        elseif style == "Square" then
            self.components.box:UpdateSquareBox(b.x, b.y, b.w, b.h, self.colors)
        elseif style == "3D" and self.lodLevel == 1 then
            self.components.box:Update3DBox(rootPart.CFrame, self:GetCharacterSize(), camera, self.colors)
        else
            self.components.box:UpdateCornerBox(b.x, b.y, b.w, b.h, self.colors)
        end
    end
    
    -- Health Bar
    if self.components.healthBar and humanoid then
        self.components.healthBar:Update(b.x, b.y, b.w, b.h, self.health, self.maxHealth, self.colors)
    end
    
    -- Tracer
    if self.components.tracer then
        self.components.tracer:Update(self.screenPosition, self.colors)
    end
    
    -- Text
    if self.components.text then
        local displayName = self:GetDisplayName()
        self.components.text:Update(b.x, b.y, b.w, displayName, self.distance, nil, self.colors)
    end
    
    -- Chams
    if self.components.cham then
        local chamTarget = self.target:IsA("Model") and self.target or self.target.Parent
        self.components.cham:Update(chamTarget, self.colors)
    end
    
    self.isVisible = true
    self.lastUpdate = tick()
    return true
end

function ESPEntity:GetBaseName()
    if self.cachedBaseName then return self.cachedBaseName end
    
    local baseName
    if self.entityType == "Player" and self.customData.player then
        local player = self.customData.player
        baseName = Settings.Components.Name.ShowDisplayName and player.DisplayName or player.Name
    elseif self.entityType == "Staff" then
        local player = self.customData.player
        local role = self.customData.role or "Staff"
        baseName = "STAFF: " .. player.Name .. " | " .. role
    elseif self.entityType == "SCP_Player" then
        local player = self.customData.player
        local scpName = self.customData.scpName or "SCP"
        baseName = player.Name .. " | " .. scpName
    elseif self.entityType == "Traitor" then
        local player = self.customData.player
        baseName = player.Name .. " | Traitor"
    elseif self.entityType == "Medical" then
        local player = self.customData.player
        baseName = player.Name
    elseif self.entityType == "SCP_NPC" then
        local scpData = self.customData.scpData
        baseName = scpData.Name
    elseif self.entityType == "SCP963" then
        baseName = "SCP-963"
    elseif self.entityType == "Item" then
        baseName = self.customData.itemName or "Item"
    else
        baseName = "Unknown"
    end
    
    self.cachedBaseName = baseName
    return baseName
end

function ESPEntity:GetDisplayName()
    local baseName = self:GetBaseName()
    local showStuds = not Settings.Components.Distance.Enabled
    
    if showStuds then
        local bucket = math.floor(self.distance / DISTANCE_CACHE_BUCKETS) * DISTANCE_CACHE_BUCKETS
        if bucket == self.lastDistanceBucket and self.cachedDisplayName then
            return self.cachedDisplayName
        end
        self.lastDistanceBucket = bucket
        local studsStr = FormatDistance(self.distance)
        self.cachedDisplayName = baseName .. " | " .. studsStr
        return self.cachedDisplayName
    else
        return baseName
    end
end

function ESPEntity:Hide()
    for name, component in pairs(self.components) do
        if component then
            component:Hide()
        end
    end
    self.isVisible = false
end

function ESPEntity:Destroy()
    for name, component in pairs(self.components) do
        if component then
            component:Destroy()
        end
    end
    self.components = {}
end

--------------------------------------------------------------------------------
-- SECTION 8: ESP MANAGER
--------------------------------------------------------------------------------

local ESPManager = {
    entities = {},
    entityKeys = {},
    connections = {},
    updateQueue = {},
    frameCount = 0,
    sortedCache = {},
    sortWorkTable = {},
    sortDirty = true,
}

local function entitySortComparator(a, b)
    if a.entity.priority ~= b.entity.priority then
        return a.entity.priority > b.entity.priority
    end
    return a.distSq < b.distSq
end

function ESPManager:Track(connection)
    table.insert(self.connections, connection)
    return connection
end

function ESPManager:AddEntity(key, entityType, target, category, customData, initialColors)
    if self.entities[key] then
        if initialColors then
            self.entities[key]:UpdateColors(initialColors)
        end
        return self.entities[key]
    end
    
    local entity = ESPEntity.new(key, entityType, target, category, customData, initialColors)
    self.entities[key] = entity
    self.entityKeys[#self.entityKeys + 1] = key
    self.sortDirty = true
    return entity
end

function ESPManager:RemoveEntity(key)
    local entity = self.entities[key]
    if entity then
        entity:Destroy()
        self.entities[key] = nil
        for i = #self.entityKeys, 1, -1 do
            if self.entityKeys[i] == key then
                table.remove(self.entityKeys, i)
                break
            end
        end
        self.sortDirty = true
    end
end

function ESPManager:GetEntity(key)
    return self.entities[key]
end

function ESPManager:UpdateAll(dt)
    self.frameCount = self.frameCount + 1
    self.timeSinceSort = (self.timeSinceSort or 0) + dt
    
    if not Settings.Enabled then
        for i = 1, #self.entityKeys do
            local entity = self.entities[self.entityKeys[i]]
            if entity then entity:Hide() end
        end
        return
    end
    
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local camPos = camera.CFrame.Position
    local maxDistSq = MAX_DISTANCE_SQ
    
    local shouldSort = self.sortDirty or self.timeSinceSort >= SORT_INTERVAL
    if shouldSort then
        self.timeSinceSort = 0
        local workTable = self.sortWorkTable
        local n = 0
        for i = 1, #self.entityKeys do
            local key = self.entityKeys[i]
            local entity = self.entities[key]
            if entity then
                local rootPart = entity:GetRootPart()
                if rootPart and rootPart.Parent then
                    local delta = rootPart.Position - camPos
                    local distSq = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
                    if distSq <= maxDistSq then
                        n = n + 1
                        local entry = workTable[n]
                        if entry then
                            entry.entity = entity
                            entry.distSq = distSq
                            entry.key = key
                        else
                            workTable[n] = {entity = entity, distSq = distSq, key = key}
                        end
                    else
                        entity:Hide()
                    end
                else
                    entity:Hide()
                end
            end
        end
        for i = n + 1, #workTable do
            workTable[i] = nil
        end
        
        table.sort(workTable, entitySortComparator)
        self.sortedCache = workTable
        self.sortDirty = false
    end
    
    local updated = 0
    local maxEntities = Settings.LOD.MaxEntities
    
    for i = 1, #self.sortedCache do
        local data = self.sortedCache[i]
        if updated >= maxEntities then
            data.entity:Hide()
        else
            local entity = data.entity
            local success = entity:Update(camera, dt)
            
            if success then
                updated = updated + 1
            end
        end
    end
end

function ESPManager:Clear()
    for i = 1, #self.entityKeys do
        local entity = self.entities[self.entityKeys[i]]
        if entity then entity:Destroy() end
    end
    table.clear(self.entities)
    table.clear(self.entityKeys)
    table.clear(self.sortedCache)
    table.clear(self.sortWorkTable)
    self.sortDirty = true
end

function ESPManager:Cleanup()
    self:Clear()
    
    for _, conn in ipairs(self.connections) do
        pcall(function() conn:Disconnect() end)
    end
    self.connections = {}
    
    if ESPContainer and ESPContainer.Parent then
        ESPContainer:Destroy()
        ESPContainer = nil
    end
    
    Initialized = false
end

--------------------------------------------------------------------------------
-- SECTION 9: GAME LOGIC INTEGRATION
--------------------------------------------------------------------------------

local function CreateSCP963ESP()
    if not Settings.Categories.SCP963.enabled then return end
    
    local scpsFolder = Workspace:FindFirstChild("SCPs")
    if not scpsFolder then return end
    local container = scpsFolder:FindFirstChild("963")
    if not container then return end
    local scp963 = container:FindFirstChild("SCP-963")
    
    if not scp963 or not scp963:IsA("BasePart") then return end
    if scp963.Transparency >= 1 then return end
    
    -- Check if taken
    for _, player in pairs(Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild("SCP-963") then
            ESPManager:RemoveEntity("SCP963")
            return
        end
    end
    
    if ESPManager:GetEntity("SCP963") then return end
    
    ESPManager:AddEntity("SCP963", "SCP963", scp963, "SCP963", {
        itemName = "SCP-963"
    })
end

local function CreateNPCSCPESP(scpData)
    local key = "NPC_" .. scpData.Name
    if not Settings.Categories.SCP_NPC.enabled then return end
    if ESPManager:GetEntity(key) then return end
    
    -- Check if we already failed to find this and if retry cooldown hasn't passed
    if FailedNPCLookups[scpData.Name] then
        local lastRetry = LastNPCRetryTime[scpData.Name]
        if lastRetry and (tick() - lastRetry) < NPC_RETRY_INTERVAL then
            return
        end
    end
    
    local model = CachedNPCModels[scpData.Name]
    if not model or not model.Parent then
        model = FindNPCModel(scpData)
        
        -- Cache failure and set retry time
        if not model or not model.Parent then
            FailedNPCLookups[scpData.Name] = true
            LastNPCRetryTime[scpData.Name] = tick()
            return
        end
        
        -- Clear failed lookup on success
        FailedNPCLookups[scpData.Name] = nil
    end
    
    CachedNPCModels[scpData.Name] = model
    
    if not model:IsA("Model") then return end
    
    if not scpData.NoHumanoid then
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health <= 0 then return end
    end
    
    local isAngry = IsAngry(model, scpData)
    local category = isAngry and "SCP_NPC_Angry" or "SCP_NPC"
    
    local entity = ESPManager:AddEntity(key, "SCP_NPC", model, category, {
        scpData = scpData,
        isAngry = isAngry,
    })
    
    -- Update colors based on angry state
    if isAngry then
        entity:UpdateColors(Settings.Colors.SCP_NPC_Angry)
    end
end

local function CreatePlayerSCPESP(player)
    local key = "PlayerSCP_" .. player.Name
    if not Settings.Categories.SCP_Player.enabled then return end
    if player == LocalPlayer then return end
    if not player.Team or player.Team.Name ~= "SCP" then return end
    if ESPManager:GetEntity(key) then return end
    
    local character = player.Character
    if not character then return end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health <= 0 then return end
    
    local scpName = GetCachedSCPName(player) or "SCP"
    
    ESPManager:AddEntity(key, "SCP_Player", character, "SCP_Player", {
        player = player,
        scpName = scpName,
    })
end

local function CreateStaffESP(player, role)
    local key = "Staff_" .. player.Name
    if not Settings.Categories.Staff.enabled then return end
    if player == LocalPlayer then return end
    if ESPManager:GetEntity(key) then return end
    
    local character = player.Character
    if not character then return end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health <= 0 then return end
    
    ESPManager:AddEntity(key, "Staff", character, "Staff", {
        player = player,
        role = role,
    })
end

local function CreateTraitorESP(player)
    local key = "Traitor_" .. player.Name
    if not Settings.Categories.Traitor.enabled then return end
    if player == LocalPlayer then return end
    if not IsTraitor(player) then return end
    if ESPManager:GetEntity(key) then return end
    
    local character = player.Character
    if not character then return end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health <= 0 then return end
    
    ESPManager:AddEntity(key, "Traitor", character, "Traitor", {
        player = player,
    })
end

local function CreateMedicalESP(player)
    local key = "Medical_" .. player.Name
    if not Settings.Categories.Medical.enabled then return end
    if player == LocalPlayer then return end
    if ESPManager:GetEntity(key) then return end
    
    local character = player.Character
    if not character then return end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 or humanoid.Health >= humanoid.MaxHealth then return end
    
    local isHostile = IsHostileToLocal(player)
    
    if Settings.Filters.HostilesOnly and not isHostile then
        local existingEntity = ESPManager:GetEntity(key)
        if existingEntity then
            ESPManager:RemoveEntity(key)
        end
        return
    end
    
    ESPManager:AddEntity(key, "Medical", character, "Medical", {
        player = player,
        isHostile = isHostile,
    })
end

local function CreatePlayerESP(player)
    local key = "Player_" .. player.Name
    if not Settings.Categories.Player.enabled then return end
    if player == LocalPlayer then return end
    if not player.Team then return end
    if player.Team.Name == "SCP" then return end
    if not ShouldShowESP(player.Team) then return end
    
    local staffKey = "Staff_" .. player.Name
    if ESPManager:GetEntity(staffKey) then return end
    
    local character = player.Character
    if not character then return end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health <= 0 then return end
    
    if Settings.Categories.Medical.enabled and humanoid and humanoid.Health < humanoid.MaxHealth then
        return
    end
    
    local isHostile = IsHostileToLocal(player)
    
    if Settings.Filters.HostilesOnly and not isHostile then
        local existingEntity = ESPManager:GetEntity(key)
        if existingEntity then
            ESPManager:RemoveEntity(key)
        end
        return
    end
    
    local localGroup = GetTeamGroup(LocalPlayer.Team and LocalPlayer.Team.Name)
    local targetGroup = GetTeamGroup(player.Team and player.Team.Name)
    
    local teamColor = Color3.fromRGB(255, 255, 255)
    if player.Team and player.Team.TeamColor then
        local success, color = pcall(function()
            return player.Team.TeamColor.Color
        end)
        if success and color and typeof(color) == "Color3" then
            teamColor = color
        end
    end
    
    local colors = deepCopy(Settings.Colors.Neutral)
    
    if Settings.Filters.HostileColors and isHostile then
        colors.box = Color3.fromRGB(255, 50, 50)
        colors.boxFill = Color3.fromRGB(255, 0, 0)
        colors.tracer = Color3.fromRGB(255, 50, 50)
        colors.text = Color3.fromRGB(255, 255, 255)
        colors.textOutline = Color3.fromRGB(0, 0, 0)
        colors.chamFill = Color3.fromRGB(255, 0, 0)
        colors.chamOutline = Color3.fromRGB(255, 100, 100)
        colors.chamGlow = Color3.fromRGB(255, 100, 100)
        colors.healthHigh = Color3.fromRGB(0, 255, 0)
        colors.healthMid = Color3.fromRGB(255, 255, 0)
        colors.healthLow = Color3.fromRGB(255, 0, 0)
    else
        colors.box = teamColor
        colors.boxFill = teamColor
        colors.tracer = teamColor
        colors.text = Color3.fromRGB(255, 255, 255)
        colors.textOutline = Color3.fromRGB(0, 0, 0)
        colors.chamFill = teamColor
        colors.chamOutline = teamColor
        colors.chamGlow = teamColor
        colors.healthHigh = Color3.fromRGB(0, 255, 0)
        colors.healthMid = Color3.fromRGB(255, 255, 0)
        colors.healthLow = Color3.fromRGB(255, 0, 0)
    end
    
    local existingEntity = ESPManager:GetEntity(key)
    if existingEntity then
        existingEntity.customData.isHostile = isHostile
        existingEntity.customData.teamColor = teamColor
        existingEntity:UpdateColors(colors)
        return
    end
    
    ESPManager:AddEntity(key, "Player", character, isHostile and "Hostile" or "Friendly", {
        player = player,
        isHostile = isHostile,
        teamColor = teamColor,
    }, colors)
end

local function RefreshAllESP()
    refreshToRemoveCount = 0
    
    for i = 1, #ESPManager.entityKeys do
        local key = ESPManager.entityKeys[i]
        local entity = ESPManager.entities[key]
        if not entity then
            refreshToRemoveCount = refreshToRemoveCount + 1
            refreshToRemove[refreshToRemoveCount] = key
        else
            local valid = true
        
        if entity.entityType == "Player" or entity.entityType == "Staff" or 
           entity.entityType == "SCP_Player" or entity.entityType == "Traitor" or 
           entity.entityType == "Medical" then
            local player = entity.customData.player
            if not player or not player.Parent then
                valid = false
            elseif not player.Character or not player.Character.Parent then
                valid = false
            else
                local humanoid = entity:GetHumanoid()
                if humanoid and humanoid.Health <= 0 then
                    valid = false
                end
            end
            
            -- Type-specific checks
            if valid and entity.entityType == "SCP_Player" then
                if not Settings.Categories.SCP_Player.enabled then
                    valid = false
                elseif not player.Team or player.Team.Name ~= "SCP" then
                    valid = false
                end
            elseif valid and entity.entityType == "Traitor" then
                if not Settings.Categories.Traitor.enabled then
                    valid = false
                elseif not IsTraitor(player) then
                    valid = false
                end
            elseif valid and entity.entityType == "Medical" then
                if not Settings.Categories.Medical.enabled then
                    valid = false
                else
                    local humanoid = entity:GetHumanoid()
                    if not humanoid or humanoid.Health >= humanoid.MaxHealth then
                        valid = false
                    end
                    if valid and Settings.Filters.HostilesOnly and not entity.customData.isHostile then
                        valid = false
                    end
                end
            elseif valid and entity.entityType == "Player" then
                if not Settings.Categories.Player.enabled then
                    valid = false
                elseif Settings.Filters.HostilesOnly and not entity.customData.isHostile then
                    valid = false
                end
            elseif valid and entity.entityType == "Staff" then
                if not Settings.Categories.Staff.enabled then
                    valid = false
                end
            end
        elseif entity.entityType == "SCP_NPC" then
            if not Settings.Categories.SCP_NPC.enabled then
                valid = false
            else
                local model = entity.target
                if not model or not model.Parent then
                    valid = false
                elseif not entity.customData.scpData.NoHumanoid then
                    local humanoid = model:FindFirstChildOfClass("Humanoid")
                    if humanoid and humanoid.Health <= 0 then
                        valid = false
                    end
                end
                
                if valid and entity.customData.scpData.HasAngryState then
                    local newAngry = IsAngry(model, entity.customData.scpData)
                    if newAngry ~= entity.customData.isAngry then
                        entity.customData.isAngry = newAngry
                        local colors = newAngry and Settings.Colors.SCP_NPC_Angry or Settings.Colors.SCP_NPC
                        entity:UpdateColors(colors)
                    end
                end
            end
        elseif entity.entityType == "SCP963" then
            if not Settings.Categories.SCP963.enabled then
                valid = false
            else
                local model = entity.target
                if not model or not model.Parent then
                    valid = false
                end
            end
        elseif entity.entityType == "Item" then
            if not entity.target or not entity.target.Parent then
                valid = false
            elseif entity.target:IsA("BasePart") and entity.target.Transparency >= 1 then
                valid = false
            end
        end
        
        if not valid then
            refreshToRemoveCount = refreshToRemoveCount + 1
            refreshToRemove[refreshToRemoveCount] = key
        end
        end
    end
    
    for i = 1, refreshToRemoveCount do
        ESPManager:RemoveEntity(refreshToRemove[i])
    end
    
    -- Create new entities
    if Settings.Categories.SCP963.enabled then
        CreateSCP963ESP()
    end
    
    for _, scpData in ipairs(NPCSCPData) do
        if Settings.Categories.SCP_NPC.enabled then
            CreateNPCSCPESP(scpData)
        end
    end
    
    local now = tick()
    if playersListDirty or (now - lastPlayersUpdate) > PLAYERS_CACHE_INTERVAL then
        cachedPlayersList = Players:GetPlayers()
        lastPlayersUpdate = now
        playersListDirty = false
    end
    
    for i = 1, #cachedPlayersList do
        local player = cachedPlayersList[i]
        if player ~= LocalPlayer and player.Parent then
            if player.Team then
                local success, color = pcall(function()
                    return player.Team.TeamColor.Color
                end)
                if success and color and typeof(color) == "Color3" then
                    if color.R > 0.01 or color.G > 0.01 or color.B > 0.01 then
                        playerColorCache[player.UserId] = color
                    else
                        playerColorCache[player.UserId] = Color3.fromRGB(255, 255, 255)
                    end
                else
                    playerColorCache[player.UserId] = Color3.fromRGB(255, 255, 255)
                end
            else
                playerColorCache[player.UserId] = Color3.fromRGB(255, 255, 255)
            end
            
            if not CachedSCPNames[player.UserId] or CachedSCPNames[player.UserId] == FAILED_LOOKUP then
                local lastRetry = LastRetryTime[player.UserId]
                if not lastRetry or (tick() - lastRetry) > RETRY_INTERVAL then
                    UpdateCachedSCPName(player)
                end
            end
            
            if player.Character and player.Character.Parent then
                -- Determine what ESP type to show (priority order)
                local isStaffMember, role = isStaff(player)
                
                if Settings.Categories.Staff.enabled and isStaffMember then
                    CreateStaffESP(player, role)
                elseif player.Team and player.Team.Name == "SCP" and Settings.Categories.SCP_Player.enabled then
                    CreatePlayerSCPESP(player)
                elseif Settings.Categories.Traitor.enabled and IsTraitor(player) then
                    CreateTraitorESP(player)
                elseif Settings.Categories.Medical.enabled then
                    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                    if humanoid and humanoid.Health < humanoid.MaxHealth then
                        CreateMedicalESP(player)
                    elseif Settings.Categories.Player.enabled then
                        CreatePlayerESP(player)
                    end
                elseif Settings.Categories.Player.enabled then
                    CreatePlayerESP(player)
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- SECTION 10: MAIN LOOP & INITIALIZATION
--------------------------------------------------------------------------------

local Initialized = false

local function Initialize()
    if Initialized then return end
    Initialized = true
    
    -- Ensure ESP container exists
    EnsureContainer()
    
    -- Cache NPC models
    for _, scpData in ipairs(NPCSCPData) do
        local model = GetPathFromString(scpData.Path)
        if model then
            CachedNPCModels[scpData.Name] = model
        end
    end
    
    -- Player added
    ESPManager:Track(Players.PlayerAdded:Connect(function(player)
        playersListDirty = true
        UpdateCachedSCPName(player)
        
        ESPManager:Track(player.CharacterAdded:Connect(function(character)
            task.wait(0.5)
            RefreshAllESP()
        end))
        
        ESPManager:Track(player:GetPropertyChangedSignal("Team"):Connect(function()
            playerColorCache[player.UserId] = nil
            ESPManager:RemoveEntity("PlayerSCP_" .. player.Name)
            ESPManager:RemoveEntity("Player_" .. player.Name)
            ESPManager:RemoveEntity("Staff_" .. player.Name)
            ESPManager:RemoveEntity("Traitor_" .. player.Name)
            ESPManager:RemoveEntity("Medical_" .. player.Name)
            task.wait(0.3)
            RefreshAllESP()
        end))
    end))
    
    -- Player removing
    ESPManager:Track(Players.PlayerRemoving:Connect(function(player)
        playersListDirty = true
        ESPManager:RemoveEntity("PlayerSCP_" .. player.Name)
        ESPManager:RemoveEntity("Player_" .. player.Name)
        ESPManager:RemoveEntity("Staff_" .. player.Name)
        ESPManager:RemoveEntity("Traitor_" .. player.Name)
        ESPManager:RemoveEntity("Medical_" .. player.Name)
        
        if player.UserId then
            CachedSCPNames[player.UserId] = nil
            CachedStaffRoles[player.UserId] = nil
            CachedStaffTimestamps[player.UserId] = nil
            playerColorCache[player.UserId] = nil
        end
    end))
    
    -- Workspace descendant added (for NPC SCPs and SCP-963)
    ESPManager:Track(Workspace.DescendantAdded:Connect(function(descendant)
        if descendant.Name == "SCP-963" and descendant:IsA("BasePart") then
            task.wait(0.1)
            CreateSCP963ESP()
        end
        
        for _, scpData in ipairs(NPCSCPData) do
            local model = CachedNPCModels[scpData.Name]
            if model and descendant:IsDescendantOf(model) then
                task.wait(0.1)
                CreateNPCSCPESP(scpData)
                break
            end
        end
    end))
    
    -- Main render loop
    local lastRefresh = 0
    local lastFrame = tick()
    local isRefreshRunning = false
    
    ESPManager:Track(RunService.RenderStepped:Connect(function()
        if not isCurrentInstance() then return end
        
        local now = tick()
        local dt = now - lastFrame
        lastFrame = now
        
        if now - lastRefresh >= REFRESH_INTERVAL and not isRefreshRunning then
            lastRefresh = now
            isRefreshRunning = true
            task.spawn(function()
                RefreshAllESP()
                isRefreshRunning = false
            end)
        end
        
        ESPManager:UpdateAll(dt)
    end))
    
    -- Handle existing players immediately
    local initialPlayers = Players:GetPlayers()
    for i = 1, #initialPlayers do
        local player = initialPlayers[i]
        if player ~= LocalPlayer then
            UpdateCachedSCPName(player)
            
            ESPManager:Track(player.CharacterAdded:Connect(function(character)
                task.wait(0.3)
                RefreshAllESP()
            end))
            
            ESPManager:Track(player:GetPropertyChangedSignal("Team"):Connect(function()
                playerColorCache[player.UserId] = nil
                ESPManager:RemoveEntity("PlayerSCP_" .. player.Name)
                ESPManager:RemoveEntity("Player_" .. player.Name)
                ESPManager:RemoveEntity("Staff_" .. player.Name)
                ESPManager:RemoveEntity("Traitor_" .. player.Name)
                ESPManager:RemoveEntity("Medical_" .. player.Name)
                task.wait(0.2)
                RefreshAllESP()
            end))
        end
    end
    
    RefreshAllESP()
end

--------------------------------------------------------------------------------
-- SECTION 11: PUBLIC API
--------------------------------------------------------------------------------

function ESPModule.Start()
    -- Always claim instance
    env.ESP_V2_INSTANCE = instanceId
    env.ESP_V2_RUNNING = true
    Settings.Enabled = true
    
    -- Reset initialized if container was destroyed or connections were lost
    if not ESPContainer or not ESPContainer.Parent then
        Initialized = false
    end
    
    -- Check if RenderStepped connection is still alive
    if #ESPManager.connections == 0 then
        Initialized = false
    end
    
    Initialize()
    
    -- Force immediate refresh
    task.spawn(function()
        RefreshAllESP()
    end)
end

function ESPModule.Stop()
    Settings.Enabled = false
    ESPManager:Clear()
end

function ESPModule.Toggle()
    if Settings.Enabled then
        ESPModule.Stop()
    else
        ESPModule.Start()
    end
end

function ESPModule.Destroy()
    env.ESP_V2_RUNNING = false
    env.ESP_V2_INSTANCE = nil
    ESPManager:Cleanup()
end

function ESPModule.GetSettings()
    return Settings
end

function ESPModule.SetSettings(newSettings)
    for k, v in pairs(newSettings) do
        if type(v) == "table" and type(Settings[k]) == "table" then
            for k2, v2 in pairs(v) do
                Settings[k][k2] = v2
            end
        else
            Settings[k] = v
        end
    end
    updateDistanceSquares()
end

function ESPModule.SetCategoryEnabled(category, enabled)
    if Settings.Categories[category] then
        Settings.Categories[category].enabled = enabled
    end
end

function ESPModule.SetComponentEnabled(component, enabled)
    if Settings.Components[component] then
        Settings.Components[component].Enabled = enabled
    end
end

function ESPModule.SetColors(category, colors)
    if Settings.Colors[category] then
        for k, v in pairs(colors) do
            Settings.Colors[category][k] = v
        end
    end
end

function ESPModule.ResetColors(category)
    if DefaultColors[category] then
        Settings.Colors[category] = deepCopy(DefaultColors[category])
    end
end

function ESPModule.RefreshESP()
    RefreshAllESP()
end

-- Expose for external access
env.ESP_V2_MODULE = ESPModule
env.ESP_V2_REFRESH = RefreshAllESP
env.ESP_V2_STOP = ESPModule.Destroy

return ESPModule
