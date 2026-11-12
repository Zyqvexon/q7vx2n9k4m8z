if not game:IsLoaded() then
    game.Loaded:Wait()
end

local GLOBAL_ENV = (getgenv and getgenv()) or _G
if GLOBAL_ENV.__SAS_ULTIMATE_CLEANUP then
    pcall(GLOBAL_ENV.__SAS_ULTIMATE_CLEANUP)
end

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local VirtualUser       = game:GetService("VirtualUser")
local TeleportService   = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    Players.PlayerAdded:Wait()
    LocalPlayer = Players.LocalPlayer
end

local hookmetamethod_fn      = hookmetamethod or (debug and debug.hookmetamethod)
local getnamecallmethod_fn   = getnamecallmethod or function() return "" end
local checkcaller_fn         = checkcaller or function() return false end
local fireproximityprompt_fn = fireproximityprompt or function(prompt)
    if prompt and prompt:IsA("ProximityPrompt") then
        pcall(function()
            prompt:InputHoldBegin()
            task.wait(prompt.HoldDuration or 0)
            prompt:InputHoldEnd()
        end)
    end
end
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 15)

local function GetRemote(name)
    if not Remotes then return nil end
    return Remotes:FindFirstChild(name)
end

local EnemyKillRemote    = GetRemote("EnemyKill")
local EnemyRewardRemote  = GetRemote("EnemyReward")
local EnemyHurtMeRemote  = GetRemote("EnemyHurtMe")
local EnemyClaimRemote   = GetRemote("EnemyClaim")
local TeleportHomeRemote = GetRemote("TeleportHome")
local OpenPackRemote     = GetRemote("OpenPack")
local RebirthRemote      = GetRemote("Rebirth")
local BuyUpgradeRemote   = GetRemote("BuyUpgrade")
local BuyCosmeticRemote  = GetRemote("BuyCosmetic")
local EquipCosmeticRemote= GetRemote("EquipCosmetic")
local EquipBestRemote    = GetRemote("EquipBest")
local BenchUpgradeRemote = GetRemote("BenchUpgrade")
local BenchStopRemote    = GetRemote("BenchStop")

local function SafeRequire(pathTbl)
    local curr = ReplicatedStorage
    for _, seg in ipairs(pathTbl) do
        if not curr then return nil end
        curr = curr:FindFirstChild(seg)
    end
    if curr and curr:IsA("ModuleScript") then
        local ok, mod = pcall(require, curr)
        if ok then return mod end
    end
    return nil
end

local PlayerState         = SafeRequire({ "Client", "Core", "PlayerState" })
local LocalEnemyRegistry  = SafeRequire({ "Client", "Core", "LocalEnemyRegistry" })
local SettingsController  = SafeRequire({ "Client", "Controllers", "SettingsController" })
local Progression         = SafeRequire({ "Shared", "Rules", "Progression" })
local PowerConfig         = SafeRequire({ "Shared", "Rules", "PowerConfig" })
local CosmeticConfig      = SafeRequire({ "Shared", "Rules", "CosmeticConfig" })
local PlaceConfig         = SafeRequire({ "Shared", "Rules", "PlaceConfig" })

local function CallRemote(remote, ...)
    if not remote then return nil end
    local args = { ... }
    if remote:IsA("RemoteFunction") then
        local ok, res = pcall(function()
            return remote:InvokeServer(table.unpack(args))
        end)
        return ok and res or nil
    elseif remote:IsA("RemoteEvent") then
        pcall(function()
            remote:FireServer(table.unpack(args))
        end)
        return true
    end
    return nil
end

local WORLD_1_ZONES = {
    "Ruin", "Forest", "Desert", "Frozen Peaks", "Volcano",
    "Toxic Wasteland", "Thunder Peaks", "Shadow Realm", "Cosmos", "Empyrean Palace"
}

local WORLD_2_ZONES = {
    "Crimson Palace", "Cursed Wood", "Candlelit Keep", "Fools's Fair", "Amber Canyon",
    "Emerald Grotto", "Copper Ruins", "Amethyst Fields", "Crimson Gardens", "Violet Tundra", "Sapphire Lagoon"
}

local ZONE_POSITIONS = {
    
    ["Ruin"]            = Vector3.new(-1, 3, -265),
    ["Forest"]          = Vector3.new(-1, 3, -765),
    ["Desert"]          = Vector3.new(-1, 3, -1305),
    ["Frozen Peaks"]    = Vector3.new(-1, 3, -1905),
    ["Volcano"]         = Vector3.new(-1, 3, -2505),
    ["Toxic Wasteland"] = Vector3.new(-1, 3, -3155),
    ["Thunder Peaks"]   = Vector3.new(-1, 3, -3845),
    ["Shadow Realm"]    = Vector3.new(-1, 3, -4575),
    ["Cosmos"]          = Vector3.new(-1, 3, -5315),
    ["Empyrean Palace"] = Vector3.new(-1, 3, -6005),
    
    ["Crimson Palace"]  = Vector3.new(-1, 3, 3),
    ["Cursed Wood"]     = Vector3.new(-1, 3, 475),
    ["Candlelit Keep"]  = Vector3.new(-1, 3, 1305),
    ["Fools's Fair"]    = Vector3.new(-1, 3, -2045),
    ["Amber Canyon"]    = Vector3.new(-1, 3, -2675),
    ["Emerald Grotto"]  = Vector3.new(-1, 3, -3315),
    ["Copper Ruins"]    = Vector3.new(-1, 3, -3925),
    ["Amethyst Fields"] = Vector3.new(-1, 3, -4575),
    ["Crimson Gardens"] = Vector3.new(-1, 3, -5275),
    ["Violet Tundra"]   = Vector3.new(-1, 3, -6105),
    ["Sapphire Lagoon"] = Vector3.new(-1, 3, -6735),
}

local ENEMY_DATABASE = {
    
    Noob                           = { loc = "Ruin",            isBoss = false },
    NoobKing                       = { loc = "Ruin",            isBoss = true  },
    BaconHair                      = { loc = "Forest",          isBoss = false },
    Outlaw                         = { loc = "Forest",          isBoss = true  },
    DesertRaider                   = { loc = "Desert",          isBoss = false },
    SandSultan                     = { loc = "Desert",          isBoss = true  },
    FrostNinja                     = { loc = "Frozen Peaks",    isBoss = false },
    DominusFrigidus                = { loc = "Frozen Peaks",    isBoss = true  },
    MagmaImp                       = { loc = "Volcano",         isBoss = false },
    DominusInfernus                = { loc = "Volcano",         isBoss = true  },
    ToxicScavenger                 = { loc = "Toxic Wasteland", isBoss = false },
    DominusVespertilio             = { loc = "Toxic Wasteland", isBoss = true  },
    Valkyrie                       = { loc = "Thunder Peaks",   isBoss = false },
    DominusAureus                  = { loc = "Thunder Peaks",   isBoss = true  },
    ShadowNinja                    = { loc = "Shadow Realm",    isBoss = false },
    DominusFormidulosus            = { loc = "Shadow Realm",    isBoss = true  },
    StarTrooper                    = { loc = "Cosmos",          isBoss = false },
    DominusAstra                   = { loc = "Cosmos",          isBoss = true  },
    EmpyreanKnight                 = { loc = "Empyrean Palace", isBoss = false },
    DominusEmpyreus                = { loc = "Empyrean Palace", isBoss = true  },
    
    OmegaKnight                    = { loc = "Crimson Palace",  isBoss = false },
    OmegaMage                      = { loc = "Crimson Palace",  isBoss = false },
    DarkApprentice                 = { loc = "Crimson Palace",  isBoss = false },
    CrimsonSentinel                = { loc = "Crimson Palace",  isBoss = false },
    RiftCantor                     = { loc = "Crimson Palace",  isBoss = false },
    CrimsonVoidcaller              = { loc = "Crimson Palace",  isBoss = true  },
    WanwoodAcolyte                 = { loc = "Cursed Wood",     isBoss = false },
    CursedWarden                   = { loc = "Cursed Wood",     isBoss = false },
    GrimGlow                       = { loc = "Cursed Wood",     isBoss = true  },
    CandleVotary                   = { loc = "Candlelit Keep",  isBoss = false },
    DungeonHeadsman                = { loc = "Candlelit Keep",  isBoss = false },
    SolemnDarkOne                  = { loc = "Candlelit Keep",  isBoss = true  },
    FederationJester               = { loc = "Fools's Fair",    isBoss = false },
    FoolOfTheFederation            = { loc = "Fools's Fair",    isBoss = true  },
    AmberSentry                    = { loc = "Amber Canyon",    isBoss = false },
    ViscountOfTheFederation        = { loc = "Amber Canyon",    isBoss = true  },
    EmeraldWarden                  = { loc = "Emerald Grotto",  isBoss = false },
    EarlOfTheFederation            = { loc = "Emerald Grotto",  isBoss = true  },
    CopperRevenant                 = { loc = "Copper Ruins",    isBoss = false },
    DisgracedBaronOfTheFederation  = { loc = "Copper Ruins",    isBoss = true  },
    AmethystCourtier               = { loc = "Amethyst Fields", isBoss = false },
    ArchdukeOfTheFederation        = { loc = "Amethyst Fields", isBoss = true  },
    CrimsonRonin                   = { loc = "Crimson Gardens", isBoss = false },
    DukeOfTheFederation            = { loc = "Crimson Gardens", isBoss = true  },
    FrostlitHerald                 = { loc = "Violet Tundra",   isBoss = false },
    LadyOfTheFederation            = { loc = "Violet Tundra",   isBoss = true  },
    TideKnight                     = { loc = "Sapphire Lagoon", isBoss = false },
    LordOfTheFederation            = { loc = "Sapphire Lagoon", isBoss = true  },
}

local ALL_PACK_NAMES = {
    "Rookie", "Hero", "Elite", "Champion", "Legend", "Eternity", "Omega",
    "Dominus", "Godly", "Cosmic", "Ruin", "GrimGlow", "Hex", "Phantom",
    "Rift", "Ascension", "Korblox", "Valkyrie", "Oblivion", "Cosmos",
    "Null", "Supreme", "GoldRush", "Hacker", "Secret", "Sanctum", "Fighter"
}

local ALL_UPGRADE_IDS = {
    "Cash", "Health", "Carry", "Crit", "Cooldown", "Streak", "Damage", "Speed"
}

local ACTIVE_CODES = {
    "5KMEMBERS", "10KCCU", "50KLIKES", "30KLIKES", "20KLIKES",
    "SOZFORUPDATES", "10KLIKES", "1KCCU", "POTIONS", "DISCORD"
}

local State = {
    Running             = true,

    AutoFarm            = false,
    BuiltInAutoAttack   = false,
    KillAura            = false,
    KillBosses          = true,
    AttackRate          = 20,      
    DamageMultEnabled   = false,
    DamageMultValue     = 10000,
    Godmode             = false,

    AutoStageTravel     = false,
    HoverHeight         = 6,
    ZonePatrolEnabled   = false,
    SelectedZones       = { "Ruin", "Forest", "Desert" },
    CurrentPatrolIdx    = 1,
    PatrolDwellTime     = 4,

    AutoBankPacks       = false,
    IsBanking           = false,
    AutoOpenPacks       = false,
    AutoEquipBest       = false,
    AutoPlaceBestBase   = false,
    AutoBenchUpgrade    = false,

    AutoRebirth         = false,
    AutoBuyUpgrades     = false,
    SelectedUpgrades    = { "Cash", "Damage", "Carry", "Crit", "Cooldown", "Streak", "Health", "Speed" },
    AutoBestAura        = false,
    AutoFastestTrail    = false,

    WalkSpeedEnabled    = false,
    WalkSpeedValue      = 75,
    InfJump             = false,
    Noclip              = false,
    AntiAFK             = true,

    HitCounter          = 0,
    TotalKills          = 0,
    KillTimestamps      = {},
    EarningsWindow      = {},
    CachedBestPrompt    = nil,
}

local Connections = {}
local function TrackConnection(conn)
    if conn then
        table.insert(Connections, conn)
    end
    return conn
end

local function FormatNumber(n)
    n = tonumber(n) or 0
    if n >= 1e15 then return string.format("%.2fQa", n / 1e15) end
    if n >= 1e12 then return string.format("%.2fT",  n / 1e12) end
    if n >= 1e9  then return string.format("%.2fB",  n / 1e9)  end
    if n >= 1e6  then return string.format("%.2fM",  n / 1e6)  end
    if n >= 1e3  then return string.format("%.1fK",  n / 1e3)  end
    return tostring(math.floor(n))
end

local function GetPlayerData()
    if PlayerState and type(PlayerState.Data) == "table" then
        return PlayerState.Data
    end
    return nil
end

local function GetCurrentWorld()
    if PlaceConfig and type(PlaceConfig.World) == "number" then
        return PlaceConfig.World
    end
    local d = GetPlayerData()
    if d then
        if type(d.World) == "number" then return d.World end
        if type(d.World) == "function" then
            local ok, w = pcall(d.World, d)
            if ok and type(w) == "number" then return w end
        end
    end
    
    local enemies = workspace:FindFirstChild("Enemies")
    if enemies then
        for _, e in ipairs(enemies:GetChildren()) do
            local info = ENEMY_DATABASE[e.Name]
            if info and table.find(WORLD_2_ZONES, info.loc) then
                return 2
            end
        end
    end
    return 1
end

local function GetCharacterParts()
    local char = LocalPlayer.Character
    if not char then return nil, nil, nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then
        return nil, nil, nil
    end
    return char, hrp, hum
end

local function SafeTeleport(targetPosOrCF)
    local _, hrp = GetCharacterParts()
    if not hrp then return false end
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    if typeof(targetPosOrCF) == "CFrame" then
        hrp.CFrame = targetPosOrCF
    elseif typeof(targetPosOrCF) == "Vector3" then
        hrp.CFrame = CFrame.new(targetPosOrCF)
    end
    return true
end

local function GetCarriedPackCount()
    local raw = LocalPlayer:GetAttribute("CarriedPacks")
    if type(raw) ~= "string" or raw == "" then
        return 0
    end
    local count = 0
    for _ in string.gmatch(raw, "[^;]+") do
        count = count + 1
    end
    return count
end

local function GetCarryCapacity()
    return tonumber(LocalPlayer:GetAttribute("CarryCapacity")) or 5
end

local function GetEnemyPadsFolder()
    local map = workspace:FindFirstChild("Map")
    if map and map:FindFirstChild("EnemyPads") then
        return map.EnemyPads
    end
    return workspace:FindFirstChild("EnemyPads", true)
end

local function GetSortedPads()
    local folder = GetEnemyPadsFolder()
    if not folder then return {} end
    local pads = {}
    for _, pad in ipairs(folder:GetChildren()) do
        local id = tonumber(pad.Name)
        local cf = pad:GetAttribute("PadCFrame")
        if id and typeof(cf) == "CFrame" then
            table.insert(pads, { id = id, cframe = cf, instance = pad })
        elseif id and pad:IsA("BasePart") then
            table.insert(pads, { id = id, cframe = pad.CFrame, instance = pad })
        end
    end
    table.sort(pads, function(a, b) return a.id < b.id end)
    return pads
end

local function GetActiveEnemies(filterZones)
    local folder = workspace:FindFirstChild("Enemies")
    if not folder then return {} end

    local zoneLookup = nil
    if filterZones and #filterZones > 0 then
        zoneLookup = {}
        for _, z in ipairs(filterZones) do
            zoneLookup[z] = true
        end
    end

    local results = {}
    for _, enemy in ipairs(folder:GetChildren()) do
        local padId = enemy:GetAttribute("PadId")
        local isBossAttr = enemy:GetAttribute("Boss")
        local dbInfo = ENEMY_DATABASE[enemy.Name]
        local isBoss = (isBossAttr == true) or (dbInfo and dbInfo.isBoss == true)

        if (not isBoss) or State.KillBosses then
            local zoneMatch = true
            if zoneLookup and dbInfo and dbInfo.loc then
                zoneMatch = (zoneLookup[dbInfo.loc] == true)
            end
            if zoneMatch then
                local root = enemy:FindFirstChild("HumanoidRootPart")
                    or enemy.PrimaryPart
                    or enemy:FindFirstChildWhichIsA("BasePart")
                local hum = enemy:FindFirstChildOfClass("Humanoid")
                local alive = (not hum) or (hum.Health > 0)
                if alive then
                    table.insert(results, {
                        model  = enemy,
                        padId  = padId,
                        isBoss = isBoss,
                        root   = root,
                        loc    = dbInfo and dbInfo.loc or nil,
                    })
                end
            end
        end
    end

    table.sort(results, function(a, b)
        return (tonumber(a.padId) or 9999) < (tonumber(b.padId) or 9999)
    end)
    return results
end

local function GetLocalPlayerBaseBestPrompt()
    if State.CachedBestPrompt and State.CachedBestPrompt.Parent then
        return State.CachedBestPrompt
    end

    local bases = workspace:FindFirstChild("Bases")
    if not bases then return nil end

    local baseSpawn = LocalPlayer:GetAttribute("BaseSpawn")
    local bestPlot = nil
    local bestDist = math.huge

    for _, plot in ipairs(bases:GetChildren()) do
        local ownerAttr = plot:GetAttribute("Owner")
            or plot:GetAttribute("OwnerId")
            or plot:GetAttribute("OwnerUserId")
            or plot:GetAttribute("UserId")
        local ownerVal = plot:FindFirstChild("Owner") or plot:FindFirstChild("OwnerId")

        if ownerAttr == LocalPlayer.UserId or ownerAttr == LocalPlayer.Name then
            bestPlot = plot
            break
        elseif ownerVal and (ownerVal.Value == LocalPlayer or ownerVal.Value == LocalPlayer.UserId or ownerVal.Value == LocalPlayer.Name) then
            bestPlot = plot
            break
        elseif typeof(baseSpawn) == "CFrame" then
            local pivotOk, pivotCF = pcall(function() return plot:GetPivot() end)
            if pivotOk and pivotCF then
                local d = (pivotCF.Position - baseSpawn.Position).Magnitude
                if d < bestDist then
                    bestDist = d
                    bestPlot = plot
                end
            end
        end
    end

    if bestPlot then
        local bestBtn = bestPlot:FindFirstChild("BestButton", true)
        if bestBtn then
            local press = bestBtn:FindFirstChild("Press", true) or bestBtn
            local prompt = press:FindFirstChildWhichIsA("ProximityPrompt", true)
                or bestBtn:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt then
                State.CachedBestPrompt = prompt
                return prompt
            end
        end
    end
    return nil
end

if hookmetamethod_fn then
    pcall(function()
        local oldNamecall
        oldNamecall = hookmetamethod_fn(game, "__namecall", function(self, ...)
            if not checkcaller_fn() and State.Running and State.Godmode then
                local method = getnamecallmethod_fn()
                if method == "FireServer" and (self == EnemyHurtMeRemote or self == EnemyClaimRemote or tostring(self) == "EnemyHurtMe" or tostring(self) == "EnemyClaim") then
                    return nil
                end
            end
            return oldNamecall(self, ...)
        end)

        local oldNewIndex
        oldNewIndex = hookmetamethod_fn(game, "__newindex", function(self, key, value)
            if not checkcaller_fn() and State.Running then
                
                if State.Godmode and key == "Health" and typeof(self) == "Instance" and self:IsA("Humanoid") then
                    local char = LocalPlayer.Character
                    if char and self.Parent == char and type(value) == "number" and value < self.MaxHealth then
                        return oldNewIndex(self, key, self.MaxHealth)
                    end
                end

            end
            return oldNewIndex(self, key, value)
        end)
    end)
end

if EnemyRewardRemote and EnemyRewardRemote:IsA("RemoteEvent") then
    TrackConnection(EnemyRewardRemote.OnClientEvent:Connect(function(padId, cashEarned, powerEarned)
        local now = os.clock()
        local c = tonumber(cashEarned) or 0
        local p = tonumber(powerEarned) or 0
        State.TotalKills   = State.TotalKills + 1
        table.insert(State.KillTimestamps, now)
        table.insert(State.EarningsWindow, { t = now, cash = c, power = p })
    end))
end

local function GetTelemetryRates()
    local now = os.clock()
    local kills10s = 0
    for i = #State.KillTimestamps, 1, -1 do
        if now - State.KillTimestamps[i] <= 10 then
            kills10s = kills10s + 1
        else
            table.remove(State.KillTimestamps, i)
        end
    end

    local cash10s, power10s = 0, 0
    for i = #State.EarningsWindow, 1, -1 do
        local entry = State.EarningsWindow[i]
        if now - entry.t <= 10 then
            cash10s  = cash10s + entry.cash
            power10s = power10s + entry.power
        else
            table.remove(State.EarningsWindow, i)
        end
    end

    return kills10s / 10, cash10s / 10, power10s / 10
end

local function ApplyDamageMultiplier(enabled, val)
    pcall(function()
        LocalPlayer:SetAttribute("DamageMultiplier", enabled and val or 1)
    end)
end

local function SetBuiltInAutoAttack(enabled)
    pcall(function()
        if SettingsController and type(SettingsController.Set) == "function" then
            SettingsController:Set("AutoAttack", enabled)
        end
    end)
end

task.spawn(function()
    while State.Running do
        local interval = math.clamp(1 / math.max(State.AttackRate, 1), 0.02, 1)
        if not State.IsBanking then
            
            if State.AutoFarm and EnemyKillRemote then
                local filter = State.ZonePatrolEnabled and State.SelectedZones or nil
                local enemies = GetActiveEnemies(filter)
                if #enemies > 0 then
                    for _, enemy in ipairs(enemies) do
                        if not State.Running or not State.AutoFarm or State.IsBanking then break end
                        if enemy.padId then
                            State.HitCounter = State.HitCounter + 1
                            pcall(function()
                                EnemyKillRemote:FireServer(enemy.padId, State.HitCounter, false, Vector3.new(0, 1, 0))
                            end)
                        end
                    end
                else
                    
                    local pads = GetSortedPads()
                    for _, pad in ipairs(pads) do
                        if not State.Running or not State.AutoFarm or State.IsBanking then break end
                        State.HitCounter = State.HitCounter + 1
                        pcall(function()
                            EnemyKillRemote:FireServer(pad.id, State.HitCounter, false, Vector3.new(0, 1, 0))
                        end)
                    end
                end
            end

            if State.KillAura and LocalEnemyRegistry and type(LocalEnemyRegistry.Damage) == "function" then
                pcall(function()
                    local registryTable = LocalEnemyRegistry.activeEnemies
                        or LocalEnemyRegistry.Enemies
                        or LocalEnemyRegistry._enemies
                        or LocalEnemyRegistry
                    for _, entry in pairs(registryTable) do
                        if type(entry) == "table" then
                            local isBoss = entry.isBoss or entry.Boss or (entry.model and entry.model:GetAttribute("Boss"))
                            if (not isBoss) or State.KillBosses then
                                LocalEnemyRegistry:Damage(entry, math.huge, Vector3.zero, "Hit", true)
                            end
                        end
                    end
                end)
            end
        end
        task.wait(interval)
    end
end)

task.spawn(function()
    local padIndex = 1
    local lastPatrolSwitch = os.clock()

    while State.Running do
        if not State.IsBanking then
            if State.ZonePatrolEnabled and #State.SelectedZones > 0 then
                local enemies = GetActiveEnemies(State.SelectedZones)
                if #enemies > 0 and enemies[1].root then
                    local targetPos = enemies[1].root.Position + Vector3.new(0, State.HoverHeight, 0)
                    SafeTeleport(targetPos)
                else
                    if os.clock() - lastPatrolSwitch >= State.PatrolDwellTime then
                        State.CurrentPatrolIdx = (State.CurrentPatrolIdx % #State.SelectedZones) + 1
                        lastPatrolSwitch = os.clock()
                    end
                    local zoneName = State.SelectedZones[State.CurrentPatrolIdx] or State.SelectedZones[1]
                    local zonePos = ZONE_POSITIONS[zoneName]
                    if zonePos then
                        SafeTeleport(zonePos + Vector3.new(0, State.HoverHeight, 0))
                    end
                end
                task.wait(0.18)
            elseif State.AutoStageTravel then
                local pads = GetSortedPads()
                if #pads > 0 then
                    if padIndex > #pads then padIndex = 1 end
                    local pad = pads[padIndex]
                    padIndex = padIndex + 1
                    if pad and pad.cframe then
                        SafeTeleport(pad.cframe.Position + Vector3.new(0, State.HoverHeight, 0))
                    end
                end
                task.wait(0.22)
            else
                task.wait(0.35)
            end
        else
            task.wait(0.25)
        end
    end
end)

task.spawn(function()
    while State.Running do
        if State.AutoBankPacks and not State.IsBanking then
            local carried  = GetCarriedPackCount()
            local capacity = GetCarryCapacity()
            if carried >= capacity and capacity > 0 then
                State.IsBanking = true
                local _, hrp = GetCharacterParts()
                local savedCF = hrp and hrp.CFrame or nil

                pcall(function()
                    local baseSpawn = LocalPlayer:GetAttribute("BaseSpawn")
                    if typeof(baseSpawn) == "CFrame" then
                        SafeTeleport(baseSpawn.Position + Vector3.new(0, 4, 0))
                    end
                    if TeleportHomeRemote then
                        TeleportHomeRemote:FireServer()
                    end
                end)

                local t0 = os.clock()
                while State.Running and os.clock() - t0 < 3.5 do
                    if GetCarriedPackCount() == 0 then
                        break
                    end
                    if TeleportHomeRemote then
                        pcall(function() TeleportHomeRemote:FireServer() end)
                    end
                    task.wait(0.25)
                end

                if savedCF and not State.AutoStageTravel and not State.ZonePatrolEnabled then
                    task.wait(0.15)
                    SafeTeleport(savedCF)
                end
                State.IsBanking = false
            end
        end
        task.wait(0.35)
    end
end)

task.spawn(function()
    while State.Running do
        
        if State.AutoOpenPacks and OpenPackRemote then
            local d = GetPlayerData()
            if d and type(d.Packs) == "table" then
                for packName, count in pairs(d.Packs) do
                    if type(count) == "number" and count > 0 then
                        CallRemote(OpenPackRemote, packName, count)
                    end
                end
            else
                for _, packName in ipairs(ALL_PACK_NAMES) do
                    if not State.AutoOpenPacks or not State.Running then break end
                    CallRemote(OpenPackRemote, packName, 1)
                end
            end
        end

        if State.AutoEquipBest and EquipBestRemote then
            CallRemote(EquipBestRemote)
        end

        if State.AutoPlaceBestBase then
            pcall(function()
                local prompt = GetLocalPlayerBaseBestPrompt()
                if prompt then
                    fireproximityprompt_fn(prompt)
                end
            end)
        end

        if State.AutoBenchUpgrade and BenchUpgradeRemote then
            CallRemote(BenchUpgradeRemote)
        end

        task.wait(0.8)
    end
end)

task.spawn(function()
    while State.Running do
        local d = GetPlayerData()
        local world = GetCurrentWorld()

        if State.AutoRebirth and RebirthRemote then
            local canRebirth = true
            if d and Progression and type(Progression.Level) == "function" and type(Progression.RebirthLevelRequirement) == "function" then
                local lvl = Progression.Level(d.Power or 0)
                local req = Progression.RebirthLevelRequirement(d.Rebirths or 0)
                canRebirth = (lvl >= req)
            end
            if canRebirth then
                CallRemote(RebirthRemote)
            end
        end

        if State.AutoBuyUpgrades and BuyUpgradeRemote then
            if d and PowerConfig and type(PowerConfig.UpgradePrice) == "function" and type(PowerConfig.Upgrades) == "table" then
                local selectedSet = {}
                for _, id in ipairs(State.SelectedUpgrades) do
                    selectedSet[id] = true
                end

                for _ = 1, 5 do
                    if not State.AutoBuyUpgrades or not State.Running then break end
                    local cash = tonumber(d.Cash) or 0
                    local upgradesTbl = d.Upgrades or {}
                    local cheapestId, cheapestPrice = nil, math.huge

                    for _, upg in ipairs(PowerConfig.Upgrades) do
                        if selectedSet[upg.Id] then
                            local curLvl = tonumber(upgradesTbl[upg.Id]) or 0
                            if curLvl < (upg.MaxLevel or 9999) then
                                local ok, price = pcall(PowerConfig.UpgradePrice, world, upg.Id, curLvl)
                                if ok and type(price) == "number" and price <= cash and price < cheapestPrice then
                                    cheapestId = upg.Id
                                    cheapestPrice = price
                                end
                            end
                        end
                    end

                    if cheapestId then
                        CallRemote(BuyUpgradeRemote, cheapestId)
                        task.wait(0.1)
                    else
                        break
                    end
                end
            else
                for _, id in ipairs(State.SelectedUpgrades) do
                    if not State.AutoBuyUpgrades or not State.Running then break end
                    CallRemote(BuyUpgradeRemote, id)
                end
            end
        end

        if CosmeticConfig and type(CosmeticConfig.Kinds) == "table" and d then
            local function ProcessCosmetic(kindName, scoreFn)
                local cfg = CosmeticConfig.Kinds[kindName]
                if not cfg or type(cfg.Items) ~= "table" then return end
                local ownedTbl   = d[cfg.Owned] or {}
                local equippedId = d[cfg.Equipped]
                local cash       = tonumber(d.Cash) or 0

                for _, item in ipairs(cfg.Items) do
                    if item.World == world and not item.RobuxOnly and not ownedTbl[item.Id] then
                        if (tonumber(item.Price) or math.huge) <= cash then
                            CallRemote(BuyCosmeticRemote, kindName, item.Id)
                            d = GetPlayerData() or d
                            cash = tonumber(d.Cash) or 0
                            ownedTbl = d[cfg.Owned] or ownedTbl
                        end
                    end
                end

                local bestId, bestScore = nil, -1
                for _, item in ipairs(cfg.Items) do
                    if item.World == world and ownedTbl[item.Id] then
                        local s = scoreFn(item)
                        if s > bestScore then
                            bestScore = s
                            bestId = item.Id
                        end
                    end
                end
                if bestId and bestId ~= equippedId then
                    CallRemote(EquipCosmeticRemote, kindName, bestId)
                end
            end

            if State.AutoBestAura then
                pcall(ProcessCosmetic, "Aura", function(it)
                    return (tonumber(it.Multiplier) or 0) * 1000 + (tonumber(it.Order) or 0)
                end)
            end
            if State.AutoFastestTrail then
                pcall(ProcessCosmetic, "Trail", function(it)
                    return (tonumber(it.Speed) or 0) * 1000 + (tonumber(it.Order) or 0)
                end)
            end
        end

        task.wait(0.6)
    end
end)

TrackConnection(RunService.Heartbeat:Connect(function()
    if not State.Running then return end
    local _, hrp, hum = GetCharacterParts()
    if hum and State.Godmode and hum.Health < hum.MaxHealth then
        hum.Health = hum.MaxHealth
    end
    if hrp and hum and State.WalkSpeedEnabled then
        local dir = hum.MoveDirection
        if dir.Magnitude > 0 then
            hrp.AssemblyLinearVelocity = Vector3.new(
                dir.X * State.WalkSpeedValue,
                hrp.AssemblyLinearVelocity.Y,
                dir.Z * State.WalkSpeedValue
            )
        end
    end
    if State.DamageMultEnabled then
        if LocalPlayer:GetAttribute("DamageMultiplier") ~= State.DamageMultValue then
            ApplyDamageMultiplier(true, State.DamageMultValue)
        end
    end
end))

local NoclipCharacter = nil
local NoclipParts = {}
local NoclipAddedConnection = nil

local function CacheNoclipCharacter(char)
    if NoclipAddedConnection then
        NoclipAddedConnection:Disconnect()
        NoclipAddedConnection = nil
    end
    NoclipCharacter = char
    table.clear(NoclipParts)
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            table.insert(NoclipParts, part)
        end
    end
    NoclipAddedConnection = char.DescendantAdded:Connect(function(part)
        if part:IsA("BasePart") then
            table.insert(NoclipParts, part)
        end
    end)
end

TrackConnection(RunService.Stepped:Connect(function()
    if not State.Running or not State.Noclip then return end
    local char = LocalPlayer.Character
    if not char then return end
    if NoclipCharacter ~= char then
        CacheNoclipCharacter(char)
    end
    for i = #NoclipParts, 1, -1 do
        local part = NoclipParts[i]
        if not part or not part.Parent then
            table.remove(NoclipParts, i)
        elseif part.CanCollide then
            part.CanCollide = false
        end
    end
end))

TrackConnection(UserInputService.JumpRequest:Connect(function()
    if not State.Running or not State.InfJump then return end
    local _, _, hum = GetCharacterParts()
    if hum then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end))

TrackConnection(LocalPlayer.Idled:Connect(function()
    if not State.Running or not State.AntiAFK then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.zero)
    end)
end))

local function RedeemAllCodes()
    if not Remotes then return 0 end
    local codeRemotes = {}
    for _, r in ipairs(Remotes:GetChildren()) do
        local lower = string.lower(r.Name)
        if string.find(lower, "code") or string.find(lower, "redeem") then
            table.insert(codeRemotes, r)
        end
    end
    local count = 0
    for _, code in ipairs(ACTIVE_CODES) do
        for _, r in ipairs(codeRemotes) do
            CallRemote(r, code)
        end
        count = count + 1
        task.wait(0.1)
    end
    return count
end

local Rayfield
pcall(function()
    Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()
end)

local Window
if Rayfield then
    local ok, result = pcall(function()
        return Rayfield:CreateWindow({
            name = "[⚡] Steal a Superpower!",
            subtitle = "VeloxHub • by Ovei",
            profile = "Ovei | VeloxHub",
            icon = "zap",
            showName = "VeloxHub",
            showIcon = "zap",
            showIconOnly = false,
            sidebarLayout = true,
        })
    end)
    if ok then
        Window = result
    end
end

if Window then
    pcall(function()
        Window:CreateTag({
            text = "VELOXHUB",
            title = "by Ovei",
            icon = "zap",
            color = Color3.fromRGB(245, 158, 11),
        })
    end)

    local FarmTab = Window:CreateTab({ name = "Farm", icon = "swords" })
    local WorldTab = Window:CreateTab({ name = "World", icon = "map" })
    local InventoryTab = Window:CreateTab({ name = "Inventory", icon = "package" })
    local PlayerTab = Window:CreateTab({ name = "Player", icon = "user-round" })

    FarmTab:CreateSection({ name = "Combat" })

    FarmTab:CreateToggle({
        name = "Auto Farm",
        value = State.AutoFarm,
        callback = function(v)
            State.AutoFarm = v
        end,
    })

    FarmTab:CreateToggle({
        name = "Kill Aura",
        value = State.KillAura,
        callback = function(v)
            State.KillAura = v
        end,
    })

    FarmTab:CreateToggle({
        name = "Auto Attack",
        value = State.BuiltInAutoAttack,
        callback = function(v)
            State.BuiltInAutoAttack = v
            SetBuiltInAutoAttack(v)
        end,
    })

    FarmTab:CreateToggle({
        name = "Target Bosses",
        value = State.KillBosses,
        callback = function(v)
            State.KillBosses = v
        end,
    })

    FarmTab:CreateSlider({
        name = "Attack Rate",
        range = { 5, 60 },
        increment = 1,
        value = State.AttackRate,
        suffix = "/s",
        callback = function(v)
            State.AttackRate = tonumber(v) or 20
        end,
    })

    FarmTab:CreateSection({ name = "Power" })

    FarmTab:CreateToggle({
        name = "Godmode",
        value = State.Godmode,
        callback = function(v)
            State.Godmode = v
        end,
    })

    FarmTab:CreateToggle({
        name = "Damage Multiplier",
        value = State.DamageMultEnabled,
        callback = function(v)
            State.DamageMultEnabled = v
            ApplyDamageMultiplier(v, State.DamageMultValue)
        end,
    })

    FarmTab:CreateSlider({
        name = "Multiplier Value",
        range = { 10, 1000000 },
        increment = 100,
        value = State.DamageMultValue,
        callback = function(v)
            State.DamageMultValue = tonumber(v) or 10000
            if State.DamageMultEnabled then
                ApplyDamageMultiplier(true, State.DamageMultValue)
            end
        end,
    })

    FarmTab:CreateSection({ name = "Zone Patrol" })

    FarmTab:CreateToggle({
        name = "Auto Stage Travel",
        value = State.AutoStageTravel,
        callback = function(v)
            State.AutoStageTravel = v
        end,
    })

    FarmTab:CreateToggle({
        name = "Multi-Zone Patrol",
        value = State.ZonePatrolEnabled,
        callback = function(v)
            State.ZonePatrolEnabled = v
        end,
    })

    local allZonesCombined = {}
    for _, z in ipairs(WORLD_1_ZONES) do
        table.insert(allZonesCombined, z)
    end
    for _, z in ipairs(WORLD_2_ZONES) do
        table.insert(allZonesCombined, z)
    end

    FarmTab:CreateDropdown({
        name = "Patrol Zones",
        options = allZonesCombined,
        value = State.SelectedZones,
        multiSelect = true,
        placeholder = "Select zones",
        callback = function(selected)
            if type(selected) == "table" then
                local list = {}
                for k, v in pairs(selected) do
                    if type(k) == "number" and type(v) == "string" then
                        table.insert(list, v)
                    elseif type(k) == "string" and v == true then
                        table.insert(list, k)
                    end
                end
                if #list > 0 then
                    State.SelectedZones = list
                    State.CurrentPatrolIdx = 1
                end
            end
        end,
    })

    FarmTab:CreateSlider({
        name = "Hover Height",
        range = { 2, 25 },
        increment = 1,
        value = State.HoverHeight,
        suffix = " studs",
        callback = function(v)
            State.HoverHeight = tonumber(v) or 6
        end,
    })

    WorldTab:CreateSection({ name = "Home Base" })

    WorldTab:CreateButton({
        name = "Teleport Home",
        icon = "house",
        callback = function()
            local baseSpawn = LocalPlayer:GetAttribute("BaseSpawn")
            if typeof(baseSpawn) == "CFrame" then
                SafeTeleport(baseSpawn.Position + Vector3.new(0, 4, 0))
            end
            if TeleportHomeRemote then
                pcall(function()
                    TeleportHomeRemote:FireServer()
                end)
            end
        end,
    })

    WorldTab:CreateSection({ name = "World 1" })

    WorldTab:CreateDropdown({
        name = "World 1 Zone",
        options = WORLD_1_ZONES,
        value = "Ruin",
        callback = function(zoneName)
            local pos = ZONE_POSITIONS[zoneName]
            if pos then
                SafeTeleport(pos + Vector3.new(0, 4, 0))
            end
        end,
    })

    WorldTab:CreateSection({ name = "World 2" })

    WorldTab:CreateDropdown({
        name = "World 2 Zone",
        options = WORLD_2_ZONES,
        value = "Crimson Palace",
        callback = function(zoneName)
            local pos = ZONE_POSITIONS[zoneName]
            if pos then
                SafeTeleport(pos + Vector3.new(0, 4, 0))
            end
        end,
    })

    InventoryTab:CreateSection({ name = "Packs & Base" })

    InventoryTab:CreateToggle({
        name = "Auto Bank Packs",
        value = State.AutoBankPacks,
        callback = function(v)
            State.AutoBankPacks = v
        end,
    })

    InventoryTab:CreateToggle({
        name = "Auto Open Packs",
        value = State.AutoOpenPacks,
        callback = function(v)
            State.AutoOpenPacks = v
        end,
    })

    InventoryTab:CreateToggle({
        name = "Equip Best Cards",
        value = State.AutoEquipBest,
        callback = function(v)
            State.AutoEquipBest = v
        end,
    })

    InventoryTab:CreateToggle({
        name = "Place Best Cards",
        value = State.AutoPlaceBestBase,
        callback = function(v)
            State.AutoPlaceBestBase = v
        end,
    })

    InventoryTab:CreateToggle({
        name = "Upgrade Card Bench",
        value = State.AutoBenchUpgrade,
        callback = function(v)
            State.AutoBenchUpgrade = v
            if not v and BenchStopRemote then
                CallRemote(BenchStopRemote)
            end
        end,
    })

    InventoryTab:CreateSection({ name = "Progression" })

    InventoryTab:CreateToggle({
        name = "Auto Rebirth",
        value = State.AutoRebirth,
        callback = function(v)
            State.AutoRebirth = v
        end,
    })

    InventoryTab:CreateToggle({
        name = "Auto Buy Upgrades",
        value = State.AutoBuyUpgrades,
        callback = function(v)
            State.AutoBuyUpgrades = v
        end,
    })

    InventoryTab:CreateDropdown({
        name = "Selected Upgrades",
        options = ALL_UPGRADE_IDS,
        value = State.SelectedUpgrades,
        multiSelect = true,
        placeholder = "Select upgrades",
        callback = function(selected)
            if type(selected) == "table" then
                local list = {}
                for k, v in pairs(selected) do
                    if type(k) == "number" and type(v) == "string" then
                        table.insert(list, v)
                    elseif type(k) == "string" and v == true then
                        table.insert(list, k)
                    end
                end
                State.SelectedUpgrades = list
            end
        end,
    })

    InventoryTab:CreateSection({ name = "Cosmetics & Codes" })

    InventoryTab:CreateToggle({
        name = "Best Aura",
        value = State.AutoBestAura,
        callback = function(v)
            State.AutoBestAura = v
        end,
    })

    InventoryTab:CreateToggle({
        name = "Fastest Trail",
        value = State.AutoFastestTrail,
        callback = function(v)
            State.AutoFastestTrail = v
        end,
    })

    InventoryTab:CreateButton({
        name = "Redeem Active Codes",
        icon = "gift",
        callback = function()
            local n = RedeemAllCodes()
            pcall(function()
                Window:Notify({
                    title = "Codes Processed",
                    content = string.format("Attempted %d active codes.", n),
                    duration = 4,
                })
            end)
        end,
    })

    PlayerTab:CreateSection({ name = "Movement" })

    PlayerTab:CreateToggle({
        name = "WalkSpeed Boost",
        value = State.WalkSpeedEnabled,
        callback = function(v)
            State.WalkSpeedEnabled = v
        end,
    })

    PlayerTab:CreateSlider({
        name = "WalkSpeed",
        range = { 16, 300 },
        increment = 1,
        value = State.WalkSpeedValue,
        callback = function(v)
            State.WalkSpeedValue = tonumber(v) or 75
        end,
    })

    PlayerTab:CreateToggle({
        name = "Infinite Jump",
        value = State.InfJump,
        callback = function(v)
            State.InfJump = v
        end,
    })

    PlayerTab:CreateToggle({
        name = "Noclip",
        value = State.Noclip,
        callback = function(v)
            State.Noclip = v
        end,
    })

    PlayerTab:CreateToggle({
        name = "Anti-AFK",
        value = State.AntiAFK,
        callback = function(v)
            State.AntiAFK = v
        end,
    })

    PlayerTab:CreateSection({ name = "Session Stats" })

    local TelemetryText = PlayerTab:CreateText({
        name = "Live Metrics",
        text = "Waiting for data...",
    })

    task.spawn(function()
        while State.Running do
            pcall(function()
                local d = GetPlayerData()
                local kps, cps, pps = GetTelemetryRates()
                local carried = GetCarriedPackCount()
                local cap = GetCarryCapacity()
                local cash = d and d.Cash or 0
                local power = d and d.Power or 0
                local rebs = d and d.Rebirths or 0
                local lvl = (Progression and Progression.Level and d) and Progression.Level(power) or 0
                local reqLvl = (Progression and Progression.RebirthLevelRequirement and d) and Progression.RebirthLevelRequirement(rebs) or 0

                TelemetryText:Set(string.format(
                    "World: %d | Packs: %d / %d%s\nCash: $%s (+%s/s) | Power: %s (+%s/s)\nLevel: %d / %d | Rebirths: %d\nKills: %d (%.1f/s)",
                    GetCurrentWorld(), carried, cap, State.IsBanking and " [BANKING]" or "",
                    FormatNumber(cash), FormatNumber(cps),
                    FormatNumber(power), FormatNumber(pps),
                    lvl, reqLvl, rebs, State.TotalKills, kps
                ))
            end)
            task.wait(0.75)
        end
    end)

    PlayerTab:CreateSection({ name = "Utilities" })

    PlayerTab:CreateButton({
        name = "Rejoin Server",
        icon = "refresh-cw",
        callback = function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end,
    })

    PlayerTab:CreateKeybind({
        name = "Toggle UI Key",
        value = Enum.KeyCode.RightShift,
        isMenuToggle = true,
    })
end

GLOBAL_ENV.__SAS_ULTIMATE_CLEANUP = function()
    State.Running = false
    ApplyDamageMultiplier(false, 1)
    for _, conn in ipairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(Connections)
    if NoclipAddedConnection then
        pcall(function() NoclipAddedConnection:Disconnect() end)
        NoclipAddedConnection = nil
    end
    if Window and Window.Unload then
        pcall(function() Window:Unload() end)
    end
end
