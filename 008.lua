task.wait(2)

getgenv().gethui = function()
    return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
end

local okWind, WindUI = pcall(function()
    return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/download/1.6.66/main.lua"))()
end)

if not okWind or not WindUI then
    warn("[Tap Simulator REBORN] WindUI load failed")
    return
end

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local LocalPlayer = Players.LocalPlayer
local RS = ReplicatedStorage

local function safeRequire(path)
    if not path then return nil end
    local ok, mod = pcall(require, path)
    return ok and mod or nil
end

local DataController = safeRequire(RS.Controllers.Core.DataController)
local CommModule     = safeRequire(RS.Packages.Comm)

if not DataController or not CommModule then
    warn("[Tap Simulator REBORN] Core modules missing")
    return
end

local RemoteServices = RS:FindFirstChild("RemoteServices")

local TapChestConfig       = safeRequire(RS.Shared.Game.TapChestConfig)
local TapChestController   = safeRequire(RS.Controllers.Game.TapChestController)
local DigConfig            = safeRequire(RS.Shared.Minigames.DigConfig)
local DigWorld             = safeRequire(RS.Shared.Minigames.DigWorld)
local HoneyPotConfig       = safeRequire(RS.Shared.Items.HoneyPotConfig)
local ColosseumAdapter     = safeRequire(RS.Controllers.Minigames.ColosseumClientAdapter)

local EggConfig            = safeRequire(RS.Shared.Pets.LaunchEggConfig)
local EggPricing           = safeRequire(RS.Shared.Pets.EggPricing)
local GamepassPerks        = safeRequire(RS.Shared.Monetization.GamepassPerks)
local BoostFormula         = safeRequire(RS.Shared.Items.BoostFormula)
local BoostConfig          = safeRequire(RS.Shared.Items.BoostConfig)
local MachineConfig        = safeRequire(RS.Shared.Pets.MachineConfig)
local SkillTreeConfig      = safeRequire(RS.Shared.Progression.SkillTreeConfig)
local SkillTreeFormula     = safeRequire(RS.Shared.Progression.SkillTreeFormula)
local SkillTreeRequirements= safeRequire(RS.Shared.Progression.SkillTreeRequirements)
local QuestConfig          = safeRequire(RS.Shared.Quests.QuestConfig)
local RebirthConfig        = safeRequire(RS.Shared.Progression.RebirthConfig)
local RebirthButtonConfig  = safeRequire(RS.Shared.Progression.RebirthButtonConfig)
local PhysicalUpgradeConfig= safeRequire(RS.Shared.Progression.PhysicalUpgradeConfig)
local CurrencyConfig       = safeRequire(RS.Shared.Core.CurrencyConfig)
local GiftController       = safeRequire(RS.Controllers.Items.GiftController)

local function makeService(name)
    if not RemoteServices then return nil end
    local ok, svc = pcall(function()
        return CommModule.ClientComm.new(RemoteServices, false, name):BuildObject()
    end)
    return ok and svc or nil
end

local EggService       = makeService("EggService")
local MachineService   = makeService("MachineService")
local SkillTreeService = makeService("SkillTreeService")
local ItemService      = makeService("ItemService")
local TapChestService  = makeService("TapChestService")
local DigComm          = makeService("DigService")
local HoneyPotService  = makeService("HoneyPotService")

local function getRemote(serviceName, kind, name)
    if not RemoteServices then return nil end
    local svc = RemoteServices:FindFirstChild(serviceName)
    if not svc then return nil end
    local k = svc:FindFirstChild(kind)
    if k then return k:FindFirstChild(name) end
    return svc:FindFirstChild(name)
end

local TapRemote     = getRemote("TapService", "RE", "TapRequested")
local RebirthRemote = getRemote("RebirthService", "RE", "RebirthRequested")
local BoostRemote   = getRemote("BoostService", "RF", "Use")
local JumpRemote    = getRemote("PhysicalUpgradeService", "RF", "Purchase")
local ClaimQuestRF  = getRemote("QuestService", "RF", "ClaimQuest")
local ClaimQuestRE  = getRemote("QuestService", "RE", "ClaimQuest")

local ColosseumNetwork = ColosseumAdapter and ColosseumAdapter.Network or nil

local function Notify(cfg)
    pcall(function() WindUI:Notify(cfg) end)
end

local function getData()
    local replica = DataController:GetReplica()
    if not replica then return nil end
    return replica.Data
end

local function getPartPos(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj.Position end
    local pp = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
    if pp then return pp.Position end
    local ok, pivot = pcall(function() return obj:GetPivot() end)
    if ok and pivot then return pivot.Position end
    return nil
end

local function TeleportTo(targetPos)
    if not targetPos then return false end
    for attempt = 1, 3 do
        local char = LocalPlayer.Character
        if not char then return false end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end
        local dist = (hrp.Position - targetPos).Magnitude
        if dist <= 10 then return true end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.Physics) end
        hrp.Anchored = true
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        for i = 1, 5 do
            hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 5, 0))
            task.wait(0.05)
        end
        hrp.Anchored = false
        if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
        task.wait(0.4)
        hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp and (hrp.Position - targetPos).Magnitude <= 15 then return true end
    end
    return false
end

-- ============================================================
-- FARM: Auto Tap
-- ============================================================

local TapState = { Running = false, Seq = 0, Delay = 0.01, Count = 0, Status = "Idle" }

if TapRemote then
    task.spawn(function()
        while true do
            task.wait(TapState.Delay)
            if not TapState.Running then continue end
            TapState.Seq = TapState.Seq + 1
            local ok = pcall(function()
                TapRemote:FireServer({ ClientSequence = TapState.Seq, Auto = false, Source = "screen" })
            end)
            if ok then TapState.Count = TapState.Count + 1 end
        end
    end)
end

-- ============================================================
-- FARM: Auto Rebirth
-- ============================================================

local RebirthState = { Selected = false, Highest = false, SelectedIndex = 1, Delay = 1, Count = 0, Status = "Idle" }
local RebirthOptions = {}
local RebirthIndexByName = {}

local function rebuildRebirthOptions()
    RebirthOptions = {}
    RebirthIndexByName = {}
    if not RebirthConfig then return end
    local maxOptions = 5
    local data = getData()
    if data and RebirthButtonConfig then
        local ok, count = pcall(function()
            local unlocked = data.Upgrades and data.Upgrades.RebirthButtons or 0
            return RebirthButtonConfig.GetOptionCount(unlocked, "Main")
        end)
        if ok and count and count > 0 then maxOptions = count end
    end
    for i = 1, maxOptions do
        local ok, amt = pcall(function() return RebirthConfig.GetAmountFromIndex(i) end)
        if ok and amt then
            local label = tostring(amt)
            table.insert(RebirthOptions, label)
            RebirthIndexByName[label] = i
        end
    end
end

rebuildRebirthOptions()

if RebirthRemote and RebirthConfig then
    task.spawn(function()
        while true do
            task.wait(RebirthState.Delay)
            if not (RebirthState.Selected or RebirthState.Highest) then continue end
            local data = getData()
            if not data then continue end
            local coins = (data.Currencies and data.Currencies.Coins) or 0
            local rebirths = (data.Statistics and data.Statistics.Rebirths) or 0
            if RebirthState.Highest then
                local bestIdx = 0
                for i = 1, #RebirthOptions do
                    local ok, amt = pcall(function() return RebirthConfig.GetAmountFromIndex(i) end)
                    if not ok or not amt then break end
                    local ok2, price = pcall(function() return RebirthConfig.GetPrice(amt, rebirths) end)
                    if ok2 and price and coins >= price then bestIdx = i else break end
                end
                if bestIdx > 0 then
                    pcall(function() RebirthRemote:FireServer({ Index = bestIdx }) end)
                    RebirthState.Count = RebirthState.Count + 1
                    RebirthState.Status = "Rebirth " .. bestIdx .. " | total " .. RebirthState.Count
                end
            elseif RebirthState.Selected then
                local ok, amt = pcall(function() return RebirthConfig.GetAmountFromIndex(RebirthState.SelectedIndex) end)
                if ok and amt then
                    local ok2, price = pcall(function() return RebirthConfig.GetPrice(amt, rebirths) end)
                    if ok2 and price and coins >= price then
                        pcall(function() RebirthRemote:FireServer({ Index = RebirthState.SelectedIndex }) end)
                        RebirthState.Count = RebirthState.Count + 1
                        RebirthState.Status = "Rebirth " .. RebirthState.SelectedIndex .. " | total " .. RebirthState.Count
                    end
                end
            end
        end
    end)
end

-- ============================================================
-- FARM: Auto Double Jump
-- ============================================================

local JumpState = { Running = false, Delay = 1, Count = 0, Status = "Idle" }

local function attemptBuyJump()
    if not PhysicalUpgradeConfig or not JumpRemote then return false end
    local data = getData()
    if not data then return false end
    local ok, config = pcall(function() return PhysicalUpgradeConfig.Get("+1 Jump") end)
    if not ok or not config then return false end
    local ok2, nextIdx = pcall(function() return PhysicalUpgradeConfig.GetOwned(data, config) + 1 end)
    if not ok2 or not nextIdx then return false end
    local ok3, price = pcall(function() return PhysicalUpgradeConfig.GetPrice(config, nextIdx) end)
    if not ok3 or not price then return false end
    local ok4, locked = pcall(function() return PhysicalUpgradeConfig.GetLockedIsland(data, config, nextIdx) end)
    if ok4 and locked then return false end
    local currency = data
    if CurrencyConfig then
        local paths = CurrencyConfig.Paths[config.Currency]
        if paths then
            for _, v in ipairs(paths) do
                if type(currency) == "table" then currency = currency[v] end
            end
        end
    end
    if type(currency) ~= "number" or currency < price then return false end
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local savedPos = hrp and hrp.Position or nil
    local machine = Workspace:FindFirstChild("double jump machine")
    if machine then
        local pos = getPartPos(machine)
        if pos then TeleportTo(pos) end
    end
    local success = pcall(function() JumpRemote:InvokeServer({ Index = nextIdx, Upgrade = "+1 Jump" }) end)
    if success and savedPos then
        task.delay(1, function()
            local hrp2 = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp2 then TeleportTo(savedPos) end
        end)
    end
    return success
end

task.spawn(function()
    while true do
        task.wait(JumpState.Delay)
        if not JumpState.Running then continue end
        if attemptBuyJump() then
            JumpState.Count = JumpState.Count + 1
            JumpState.Status = "Purchased | total " .. JumpState.Count
        else
            JumpState.Status = "Waiting for funds"
        end
    end
end)

-- ============================================================
-- FARM: Auto Skill Tree
-- ============================================================

local SkillState = { Running = false, Delay = 1, Count = 0, Status = "Idle" }

task.spawn(function()
    while true do
        task.wait(SkillState.Delay)
        if not SkillState.Running then continue end
        if not SkillTreeService or not SkillTreeConfig or not SkillTreeFormula or not SkillTreeRequirements then continue end
        local data = getData()
        if not data then continue end
        local unlocked = (data.SkillTree and data.SkillTree.Unlocked) or {}
        local gems = (data.Currencies and data.Currencies.Gems) or 0
        local bought = false
        local function scan(node, parentUnlocked)
            if type(node) ~= "table" or not node.Name then return false end
            if unlocked[node.Name] or node.Origin then
                for _, dir in ipairs({"N", "S", "NE", "NW", "SE", "SW"}) do
                    if type(node[dir]) == "table" and scan(node[dir], true) then return true end
                end
            elseif parentUnlocked and not node.Category and not node.Origin then
                local ok1, price = pcall(function() return SkillTreeFormula.GetPrice(data, node.Name) end)
                if ok1 and price and price <= gems then
                    local ok2, lockedShop = pcall(function() return SkillTreeRequirements.GetLockedShop(data, node) end)
                    local ok3, lockedIsland = pcall(function() return SkillTreeRequirements.GetLockedIsland(data, node) end)
                    local ok4, withheld = pcall(function() return SkillTreeFormula.IsWithheld(data, node.Name) end)
                    if ok2 and not lockedShop and ok3 and not lockedIsland and ok4 and not withheld then
                        local ok5, res = pcall(function() return SkillTreeService:Unlock({ Name = node.Name }) end)
                        if ok5 and type(res) == "table" and res.Success then
                            SkillState.Count = SkillState.Count + 1
                            SkillState.Status = "Unlocked " .. node.Name .. " | total " .. SkillState.Count
                            return true
                        end
                    end
                end
            end
            return false
        end
        for _, tree in pairs(SkillTreeConfig) do
            if scan(tree, true) then bought = true; break end
        end
        if not bought then SkillState.Status = "No affordable nodes" end
    end
end)

-- ============================================================
-- FARM: Auto Quests
-- ============================================================

local QuestState = { Running = false, Delay = 1, Count = 0, Status = "Idle" }

task.spawn(function()
    while true do
        task.wait(QuestState.Delay)
        if not QuestState.Running then continue end
        local data = getData()
        if not data or not data.Quests or not QuestConfig then continue end
        for name, qData in pairs(data.Quests) do
            local config = QuestConfig.Definitions and QuestConfig.Definitions[name]
            if config and not qData.Claimed then
                local completed = qData.Completed
                local amount = qData.Amount or 0
                local goal = config.Goal or 0
                if completed or (goal > 0 and amount >= goal) then
                    local ok = false
                    if ClaimQuestRF then ok = pcall(function() ClaimQuestRF:InvokeServer({ Quest = name }) end)
                    elseif ClaimQuestRE then ok = pcall(function() ClaimQuestRE:FireServer({ Quest = name }) end)
                    end
                    if ok then
                        QuestState.Count = QuestState.Count + 1
                        QuestState.Status = "Claimed " .. name .. " | total " .. QuestState.Count
                    end
                    task.wait(0.1)
                end
            end
        end
    end
end)

-- ============================================================
-- PETS: Auto Hatch & Craft
-- ============================================================

local HatchCraftState = {
    HatchRunning = false, CraftRunning = false,
    SelectedEgg = nil, SelectedAmount = 1,
    HatchDelay = 0.5, CraftDelay = 1,
    PetsToUse = 6, SelectedMutation = "None",
    isRequestPending = false,
    lastHatchResultTime = 0, lastCraftResultTime = 0,
    Hatched = 0, Crafted = 0, Status = "Idle",
}

if EggService then
    pcall(function()
        EggService.EggHatchResult:Connect(function()
            HatchCraftState.isRequestPending = false
            HatchCraftState.lastHatchResultTime = os.clock()
        end)
    end)
end
if MachineService then
    pcall(function()
        MachineService.MachineCraftResult:Connect(function()
            HatchCraftState.isRequestPending = false
            HatchCraftState.lastCraftResultTime = os.clock()
        end)
    end)
end

local function getEggPos(eggName)
    local eggsFolder = Workspace:FindFirstChild("Eggs")
    if not eggsFolder then return nil end
    local eggModel = eggsFolder:FindFirstChild(eggName)
    if not eggModel then return nil end
    return getPartPos(eggModel)
end

local function getGoldenMachinePos()
    for _, v in CollectionService:GetTagged("InteractionPoint") do
        if v:GetAttribute("UpgradeName") == "Golden" or v.Name == "Golden" then
            return getPartPos(v)
        end
    end
    return nil
end

local function petMatchesMutation(pet, mutation)
    if mutation == "None" then
        local mut = pet.Mutation
        if mut == nil or mut == "" then return true end
        if type(mut) == "table" and #mut == 0 then return true end
        return false
    end
    local mut = pet.Mutation
    if type(mut) == "string" then return mut == mutation end
    if type(mut) == "table" then
        for _, m in pairs(mut) do if m == mutation then return true end end
    end
    return false
end

task.spawn(function()
    while true do
        task.wait(0.1)
        if HatchCraftState.isRequestPending then continue end
        if not (HatchCraftState.HatchRunning or HatchCraftState.CraftRunning) then continue end
        local data = getData()
        if not data then continue end
        local now = os.clock()
        local crafted = false

        if HatchCraftState.CraftRunning and MachineService and (now - HatchCraftState.lastCraftResultTime >= HatchCraftState.CraftDelay) then
            local groups = {}
            local owned = (data.Pets and data.Pets.Owned) or {}
            for id, pet in pairs(owned) do
                if pet.Tier == "Normal" and not pet.Locked and not pet.Frozen and not pet.Enchant and not pet.Signature then
                    if petMatchesMutation(pet, HatchCraftState.SelectedMutation) then
                        if not groups[pet.Name] then groups[pet.Name] = {} end
                        table.insert(groups[pet.Name], id)
                    end
                end
            end
            for _, ids in pairs(groups) do
                if #ids >= HatchCraftState.PetsToUse then
                    local selected = {}
                    for i = 1, HatchCraftState.PetsToUse do table.insert(selected, ids[i]) end
                    HatchCraftState.isRequestPending = true
                    local pos = getGoldenMachinePos()
                    if pos then TeleportTo(pos) end
                    pcall(function()
                        MachineService.MachineCraftRequested:Fire({ Machine = "Golden", PetIds = selected })
                    end)
                    HatchCraftState.Crafted = HatchCraftState.Crafted + 1
                    HatchCraftState.Status = "Crafted | total " .. HatchCraftState.Crafted
                    task.delay(5, function() if HatchCraftState.isRequestPending then HatchCraftState.isRequestPending = false end end)
                    crafted = true
                    break
                end
            end
        end

        if not crafted and HatchCraftState.HatchRunning and EggService and EggConfig and EggPricing and (now - HatchCraftState.lastHatchResultTime >= HatchCraftState.HatchDelay) then
            local invCount = 0
            for _ in pairs((data.Pets and data.Pets.Owned) or {}) do invCount = invCount + 1 end
            local limit = (data.Pets and data.Pets.StorageLimit) or math.huge
            if invCount < limit then
                if HatchCraftState.SelectedEgg and EggConfig[HatchCraftState.SelectedEgg] then
                    local ok, price = pcall(function()
                        return EggPricing.GetTotal(data, HatchCraftState.SelectedEgg, EggConfig[HatchCraftState.SelectedEgg].Price, HatchCraftState.SelectedAmount)
                    end)
                    local coins = (data.Currencies and data.Currencies.Coins) or 0
                    if ok and price and coins >= price then
                        if HatchCraftState.SelectedAmount == 8 and GamepassPerks and BoostFormula then
                            local hasPerk = false
                            pcall(function() hasPerk = GamepassPerks.Has(data, "x8Egg") end)
                            local hasBoost = false
                            pcall(function() hasBoost = BoostFormula.HasType(data, "OctoHatch") end)
                            if not hasPerk and not hasBoost then
                                HatchCraftState.Status = "x8 Gamepass required"
                                continue
                            end
                        end
                        local pos = getEggPos(HatchCraftState.SelectedEgg)
                        if pos then
                            TeleportTo(pos)
                            HatchCraftState.isRequestPending = true
                            pcall(function()
                                EggService.EggHatchRequested:Fire({
                                    Egg = HatchCraftState.SelectedEgg,
                                    Count = HatchCraftState.SelectedAmount,
                                    Auto = true,
                                    Seq = math.random(1, 100000),
                                })
                            end)
                            HatchCraftState.Hatched = HatchCraftState.Hatched + 1
                            HatchCraftState.Status = "Hatched | total " .. HatchCraftState.Hatched
                            task.delay(3, function() if HatchCraftState.isRequestPending then HatchCraftState.isRequestPending = false end end)
                        else
                            HatchCraftState.Status = "Egg not loaded"
                        end
                    end
                end
            end
        end
    end
end)

-- ============================================================
-- PETS: Auto Items
-- ============================================================

local ItemState = {
    BoostRunning = false, GiftRunning = false, TreatRunning = false, TotemRunning = false,
    Delay = 1, SelectedBoosts = {}, SelectedGifts = {}, SelectedTreats = {}, SelectedTotems = {},
    Status = "Idle", Used = 0,
}

task.spawn(function()
    while true do
        task.wait(ItemState.Delay)
        local data = getData()
        if not data then continue end
        local function hasItem(name)
            local items = (data.Items and data.Items.Owned) or {}
            return (items[name] or 0) > 0
        end
        if ItemState.BoostRunning and BoostRemote then
            local boosts = data.Boosts or {}
            for _, name in ipairs(ItemState.SelectedBoosts) do
                if (boosts[name] or 0) > 0 then
                    local ok = pcall(function() BoostRemote:InvokeServer(name) end)
                    if ok then
                        ItemState.Used = ItemState.Used + 1
                        ItemState.Status = "Boost " .. name
                    end
                    break
                end
            end
        end
        if ItemState.GiftRunning and GiftController then
            for _, name in ipairs(ItemState.SelectedGifts) do
                if hasItem(name) then
                    local ok = pcall(function() GiftController:Open(name, 1) end)
                    if ok then
                        ItemState.Used = ItemState.Used + 1
                        ItemState.Status = "Gift " .. name
                    end
                    break
                end
            end
        end
        if ItemState.TreatRunning and ItemService then
            local petId = nil
            for id in pairs((data.Pets and data.Pets.Owned) or {}) do petId = id; break end
            if petId then
                for _, name in ipairs(ItemState.SelectedTreats) do
                    if hasItem(name) then
                        local ok = pcall(function()
                            ItemService:UseOnPet({ Item = name, PetId = petId, Amount = 1 })
                        end)
                        if ok then
                            ItemState.Used = ItemState.Used + 1
                            ItemState.Status = "Treat " .. name
                        end
                        break
                    end
                end
            end
        end
        if ItemState.TotemRunning and ItemService then
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _, name in ipairs(ItemState.SelectedTotems) do
                    if hasItem(name) then
                        local ok = pcall(function()
                            ItemService:PlaceTotem({ TotemName = name, Position = hrp.Position + hrp.CFrame.LookVector * 5 })
                        end)
                        if ok then
                            ItemState.Used = ItemState.Used + 1
                            ItemState.Status = "Totem " .. name
                        end
                        break
                    end
                end
            end
        end
    end
end)

-- ============================================================
-- CHESTS: Tap Chest + Clicker
-- ============================================================

local TapChestState = {
    CollectRunning = false, OpenRunning = false, Mutex = false,
    Delay = 0.5, Collected = 0, Opened = 0, Failed = 0, Status = "Idle",
}

local function getAttrFirst(model, names)
    for _, n in ipairs(names) do
        local v = model:GetAttribute(n)
        if v ~= nil then return v end
    end
    return nil
end

local function getChestId(model)
    local v = getAttrFirst(model, {"TS2TapChestId", "TapChestId", "ChestId", "Id", "TS2TapChestID", "TapChestID", "ChestID", "ID"})
    return type(v) == "string" and v or nil
end

local function getChestPos(model)
    if not TapChestConfig then return getPartPos(model) end
    local front = getAttrFirst(model, {"TS2TapChestFront", "TapChestFront", "Front"})
    local size = getAttrFirst(model, {"TS2TapChestSize", "TapChestSize", "Size"})
    if typeof(front) == "CFrame" then
        if typeof(size) == "Vector3" then
            local base = front.Position - Vector3.new(0, 1, 0) * size.Y * 0.5
            return base + front.LookVector * (size.Z * 0.5 + TapChestConfig.PromptInset)
                + Vector3.new(0, 1, 0) * TapChestConfig.PromptHeight
        end
        return front.Position
    end
    return getPartPos(model)
end

local function isChestReady(model)
    if not CollectionService:HasTag(model, "Interactable") then return false end
    return model:GetAttribute("InteractableId") == "TapChest"
end

local function getReadyChests()
    local list = {}
    if not TapChestConfig then return list end
    for _, model in CollectionService:GetTagged(TapChestConfig.Tag) do
        if model:IsA("Model") and model.Parent and isChestReady(model) then
            table.insert(list, model)
        end
    end
    return list
end

local function claimChestDirect(chestId)
    if not TapChestService then return nil end
    local holder = {}
    task.spawn(function()
        local ok, res = pcall(function() return TapChestService:Claim(chestId) end)
        if not ok then res = nil end
        holder.Result = res
        holder.Done = true
    end)
    local deadline = os.clock() + 6
    while not holder.Done and os.clock() < deadline do task.wait() end
    return holder.Result
end

local function processTapChest(model, timeout)
    local pos = getChestPos(model)
    if not pos then return false, "no position" end
    if not TeleportTo(pos) then return false, "unreachable" end
    if TapChestController then
        pcall(function() TapChestController:Interact(model) end)
        local deadline = os.clock() + (timeout or 20)
        while os.clock() < deadline do
            if not isChestReady(model) then return true, "opened" end
            task.wait(0.5)
        end
    end
    local chestId = getChestId(model)
    if chestId then
        local result = claimChestDirect(chestId)
        if type(result) == "table" and result.Success then return true, result.Coins or 0 end
    end
    return false, "failed"
end

task.spawn(function()
    while true do
        task.wait(0.5)
        if not (TapChestState.CollectRunning or TapChestState.OpenRunning) or TapChestState.Mutex then continue end
        TapChestState.Mutex = true
        local ok, err = pcall(function()
            local ready = getReadyChests()
            if #ready == 0 then
                TapChestState.Status = "No ready chests"
                return
            end
            for _, model in ready do
                if not (TapChestState.CollectRunning or TapChestState.OpenRunning) then break end
                local timeout = TapChestState.OpenRunning and 25 or 20
                local success, info = processTapChest(model, timeout)
                if success then
                    if TapChestState.CollectRunning then
                        TapChestState.Collected = TapChestState.Collected + 1
                        TapChestState.Status = "Collected " .. TapChestState.Collected
                    end
                    if TapChestState.OpenRunning then
                        TapChestState.Opened = TapChestState.Opened + 1
                        TapChestState.Status = "Opened " .. TapChestState.Opened
                    end
                else
                    TapChestState.Failed = TapChestState.Failed + 1
                    TapChestState.Status = "Failed: " .. tostring(info)
                end
                task.wait(TapChestState.Delay)
            end
        end)
        TapChestState.Mutex = false
        if not ok then warn("[TapChest] " .. tostring(err)) end
    end
end)

local ClickerState = { Running = false, Delay = 0.5, Current = nil, Status = "Idle" }

local function getClickerChest()
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and obj.Name == "ClickerChest" then
            return obj
        end
    end
    return nil
end

task.spawn(function()
    while true do
        task.wait(ClickerState.Delay)
        if not ClickerState.Running then continue end
        if not ClickerState.Current or not ClickerState.Current.Parent then
            ClickerState.Current = getClickerChest()
        end
        if ClickerState.Current then
            local pos = getPartPos(ClickerState.Current)
            if pos then
                local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp and (hrp.Position - pos).Magnitude > 10 then
                    TeleportTo(pos)
                    ClickerState.Status = "Teleported to chest"
                end
            end
        else
            ClickerState.Status = "Searching..."
        end
    end
end)

-- ============================================================
-- GAMES: Auto Dig Perfect
-- ============================================================

local DigState = {
    Running = false, Session = nil, LastHitTime = 0,
    TotalHits = 0, TotalGames = 0, LastReward = nil, Status = "Idle",
}

local MinHitInterval = 0.2
if DigConfig and tonumber(DigConfig.MinHitInterval) then
    MinHitInterval = tonumber(DigConfig.MinHitInterval)
end

local function solveRawForCursor(target)
    if target <= 0.5 then
        return (-1 + math.sqrt(1 + 16 * target)) / 4
    else
        local u = (-1 + math.sqrt(1 + 16 * (1 - target))) / 4
        return 1 - u
    end
end

local function nextTimeForRaw(round, r)
    local speed = round.Speed or 1
    if speed <= 0 then return 0 end
    local k = 0.6 * speed
    local phase = round.Phase or 0
    local eAsc  = ((r - phase) % 2) / k
    local eDesc = ((2 - r - phase) % 2) / k
    return math.min(eAsc, eDesc)
end

local function computePerfectTime(round, minTime)
    if not round or not round.Speed or round.Speed <= 0 or not round.Center then return nil end
    local r = solveRawForCursor(round.Center)
    local elapsed = nextTimeForRaw(round, r)
    local target = (round.Epoch or 0) + elapsed
    local period = 2 / (0.6 * round.Speed)
    local safety = 0
    while target < minTime and safety < 1000 do
        target = target + period
        safety = safety + 1
    end
    return target
end

local function getDigZone()
    if DigWorld and type(DigWorld.GetSite) == "function" then
        local ok, site = pcall(DigWorld.GetSite)
        if ok and site then
            local zone = site:FindFirstChild("DigZone")
            if zone then return zone end
        end
    end
    local islands = Workspace:FindFirstChild("Ts2Islands")
    if not islands then return nil end
    local autumn = islands:FindFirstChild("Autumn")
    if autumn then
        local site = autumn:FindFirstChild("Digsite")
        if site then
            local zone = site:FindFirstChild("DigZone")
            if zone then return zone end
        end
    end
    for _, island in ipairs(islands:GetChildren()) do
        local site = island:FindFirstChild("Digsite")
        if site then
            local zone = site:FindFirstChild("DigZone")
            if zone then return zone end
        end
    end
    return nil
end

local function isInDigZone()
    if LocalPlayer:GetAttribute("AtDigsite") == true then return true end
    local zone = getDigZone()
    if not zone then return false end
    local char = LocalPlayer.Character
    if not char then return false end
    if DigWorld and type(DigWorld.Contains) == "function" then
        local ok, res = pcall(function() return DigWorld.Contains(zone, char) end)
        if ok and res then return true end
    end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local pos = getPartPos(zone)
    if hrp and pos then
        return (hrp.Position - pos).Magnitude <= 30
    end
    return false
end

local function cancelDigSession()
    if DigState.Session and DigState.Session.Id and DigComm then
        local sid = DigState.Session.Id
        task.spawn(function() pcall(function() DigComm:Cancel(sid) end) end)
    end
    DigState.Session = nil
end

local function processOneDigGame()
    local zone = getDigZone()
    if not zone then
        DigState.Status = "Dig site not found"
        return true
    end

    if not isInDigZone() then
        local pos = getPartPos(zone)
        if not pos then
            DigState.Status = "Zone has no position"
            return true
        end
        DigState.Status = "Teleporting to site..."
        TeleportTo(pos)
        local deadline = os.clock() + 3
        while os.clock() < deadline do
            if not DigState.Running then return false end
            if isInDigZone() then break end
            task.wait(0.1)
        end
        if not isInDigZone() then
            DigState.Status = "Not detected at site"
            return true
        end
    end

    local ok, resp = pcall(function() return DigComm:Begin() end)
    if not ok or not resp then
        DigState.Status = "Begin failed"
        task.wait(0.5)
        return true
    end

    if resp.Error then
        if resp.Error == "Cooldown" then
            local mins = math.ceil((resp.Remaining or 0) / 60)
            DigState.Status = string.format("Cooldown %dm", mins)
            Notify({Title = "Auto Dig", Content = "Out of digs. Wait " .. mins .. " min.", Icon = "clock", Duration = 4})
            DigState.Running = false
            return false
        end
        DigState.Status = "Begin error: " .. tostring(resp.Error)
        task.wait(1)
        return true
    end

    DigState.Session = resp

    while DigState.Running and DigState.Session do
        local session = DigState.Session
        if not session.Round then
            DigState.Session = nil
            break
        end
        if session.Complete then
            DigState.Session = nil
            break
        end

        local now = Workspace:GetServerTimeNow()
        local minTime = math.max(now + 0.02, DigState.LastHitTime + MinHitInterval + 0.02)
        local target = computePerfectTime(session.Round, minTime)

        if not target then
            DigState.Session = nil
            DigState.Status = "Invalid round"
            break
        end

        while DigState.Running do
            local t = Workspace:GetServerTimeNow()
            if t >= target - 0.005 then break end
            local remaining = target - t
            if remaining > 0.05 then
                task.wait(math.min(remaining - 0.02, 0.1))
            else
                task.wait()
            end
        end

        if not DigState.Running then return false end

        local hitTime = Workspace:GetServerTimeNow()
        local hOk, hResp = pcall(function()
            return DigComm:Hit(session.Id, session.Round.Sequence, hitTime)
        end)

        if not hOk or not hResp then
            DigState.Status = "Hit failed"
            task.wait(0.5)
            DigState.Session = nil
            break
        end

        if hResp.Error then
            if hResp.Error == "NoSession" or hResp.Error == "StaleRound" then
                DigState.Session = nil
                break
            elseif hResp.Error == "Cooldown" then
                local mins = math.ceil((hResp.Remaining or 0) / 60)
                DigState.Status = string.format("Cooldown %dm", mins)
                DigState.Running = false
                return false
            elseif hResp.Error == "TooSoon" then
                task.wait(0.1)
            elseif hResp.Error == "Busy" then
                task.wait(0.2)
            else
                DigState.Session = nil
                DigState.Status = "Error: " .. tostring(hResp.Error)
                task.wait(0.5)
                break
            end
        else
            DigState.LastHitTime = hitTime
            DigState.TotalHits = DigState.TotalHits + 1

            if hResp.Complete then
                DigState.TotalGames = DigState.TotalGames + 1
                DigState.LastReward = hResp.Reward
                DigState.Status = "Done: " .. tostring(hResp.Reward) .. " x" .. tostring(hResp.Amount or 1)
                DigState.Session = nil
                Notify({Title = "Dig Complete", Content = tostring(hResp.Reward) .. " x" .. tostring(hResp.Amount or 1), Icon = "check", Duration = 3})
                task.wait(1.1)
                break
            else
                DigState.Session = hResp
                DigState.Status = "Hit " .. DigState.TotalHits
            end
        end
    end

    return true
end

task.spawn(function()
    while true do
        task.wait(0.3)
        if not DigState.Running then continue end
        if not DigComm then
            DigState.Status = "Service unavailable"
            DigState.Running = false
            continue
        end
        processOneDigGame()
    end
    cancelDigSession()
end)

-- ============================================================
-- GAMES: Auto Colosseum
-- ============================================================

local ColosseumState = {
    Active = false, Opponents = {},
    AttackInterval = 0.15, CriticalInterval = 7,
    Attacks = 0, Kills = 0, Criticals = 0, Waves = 0, Status = "Idle",
}

if ColosseumNetwork then
    pcall(function()
        ColosseumNetwork:BindEvents({
            ["WaveDefenseOpponentSpawned"] = function(data)
                if not ColosseumState.Active or not data or not data.Id then return end
                ColosseumState.Opponents[data.Id] = {
                    Id = data.Id, ArrivalTime = data.ArrivalTime, SpawnTime = data.SpawnTime,
                    Health = data.Health or data.MaxHealth, MaxHealth = data.MaxHealth,
                }
            end,
            ["WaveDefenseOpponentDefeated"] = function(data)
                if not data or not data.OpponentId then return end
                ColosseumState.Opponents[data.OpponentId] = nil
                ColosseumState.Kills = ColosseumState.Kills + 1
            end,
            ["WaveDefenseHeartLost"] = function(data)
                if not data or not data.OpponentId then return end
                ColosseumState.Opponents[data.OpponentId] = nil
            end,
            ["WaveDefenseWaveComplete"] = function()
                ColosseumState.Waves = ColosseumState.Waves + 1
                ColosseumState.Opponents = {}
            end,
            ["WaveDefenseGameOver"] = function()
                if ColosseumState.Active then
                    ColosseumState.Active = false
                    ColosseumState.Status = "Game over"
                    task.spawn(function()
                        pcall(function() ColosseumNetwork:InvokeServer("ReturnFromArena") end)
                    end)
                end
            end,
        })
    end)

    local function colosseumPickTarget()
        local targetId, minArrival = nil, math.huge
        for id, opp in pairs(ColosseumState.Opponents) do
            if opp.ArrivalTime and opp.ArrivalTime < minArrival then
                minArrival = opp.ArrivalTime
                targetId = id
            end
        end
        return targetId
    end

    local function colosseumApplyResponse(targetId, resp)
        if not resp or not resp.Health then return false end
        if resp.Defeated then
            ColosseumState.Opponents[targetId] = nil
        elseif ColosseumState.Opponents[targetId] then
            ColosseumState.Opponents[targetId].Health = resp.Health
            if resp.NewArrivalTime then
                ColosseumState.Opponents[targetId].ArrivalTime = resp.NewArrivalTime
            end
        end
        return true
    end

    task.spawn(function()
        while true do
            task.wait(ColosseumState.AttackInterval)
            if not ColosseumState.Active then continue end
            local targetId = colosseumPickTarget()
            if not targetId then continue end
            local ok, resp = pcall(function() return ColosseumNetwork:InvokeServer("AttackOpponent", targetId) end)
            if ok and colosseumApplyResponse(targetId, resp) then
                ColosseumState.Attacks = ColosseumState.Attacks + 1
            end
        end
    end)

    task.spawn(function()
        while true do
            task.wait(ColosseumState.CriticalInterval)
            if not ColosseumState.Active then continue end
            local targetId = colosseumPickTarget()
            if not targetId then continue end
            local ok, resp = pcall(function() return ColosseumNetwork:InvokeServer("CriticalAttackOpponent", targetId) end)
            if ok and colosseumApplyResponse(targetId, resp) then
                ColosseumState.Criticals = ColosseumState.Criticals + 1
            end
        end
    end)
end

local function colosseumStart()
    if not ColosseumNetwork then return false end
    if ColosseumState.Active then return true end
    ColosseumState.Status = "Starting..."
    ColosseumState.Opponents = {}
    ColosseumState.Attacks = 0
    ColosseumState.Kills = 0
    ColosseumState.Criticals = 0
    ColosseumState.Waves = 0
    local ok, resp = pcall(function() return ColosseumNetwork:InvokeServer("StartWaveDefense") end)
    if not ok or not resp then
        ColosseumState.Status = "Start failed"
        return false
    end
    if resp.OnCooldown or resp.Error then
        ColosseumState.Status = tostring(resp.Error or "Cooldown")
        return false
    end
    ColosseumState.Active = true
    ColosseumState.Status = "Playing"
    if type(resp.PendingSpawns) == "table" then
        for _, spawn in ipairs(resp.PendingSpawns) do
            if type(spawn) == "table" and spawn.Id then
                ColosseumState.Opponents[spawn.Id] = {
                    Id = spawn.Id, ArrivalTime = spawn.ArrivalTime, SpawnTime = spawn.SpawnTime,
                    Health = spawn.MaxHealth, MaxHealth = spawn.MaxHealth,
                }
            end
        end
    end
    return true
end

local function colosseumStop()
    ColosseumState.Active = false
    ColosseumState.Status = "Stopping..."
    if ColosseumNetwork then
        task.spawn(function()
            pcall(function() ColosseumNetwork:InvokeServer("EndWaveDefense") end)
            task.wait(0.5)
            pcall(function() ColosseumNetwork:InvokeServer("ReturnFromArena") end)
            ColosseumState.Status = "Stopped"
        end)
    end
end

-- ============================================================
-- MACHINES: Auto Honey Pot
-- ============================================================

local HoneyPotState = {
    ClaimRunning = false, CraftRunning = false, AutoTeleport = true,
    Delay = 0.5, SelectedRecipe = "Auto", CraftAmount = 1,
    Claimed = 0, Crafted = 0, Failed = 0, Status = "Idle", Mutex = false,
}

local function honeyPotSlots()
    local data = getData()
    if not data or type(data.HoneyPot) ~= "table" then return {} end
    return data.HoneyPot.Slots or {}
end

local function honeyPotSlotState(slot)
    if slot == nil then return "Empty" end
    local now = Workspace:GetServerTimeNow()
    if HoneyPotConfig.Progress(slot, now) >= slot.Amount then return "Ready" end
    return "Blending"
end

local function honeyPotMachinePos()
    if not HoneyPotConfig then return nil end
    local machine = HoneyPotConfig.FindMachine(Workspace)
    if not machine then return nil end
    return getPartPos(machine)
end

local function honeyPotNear()
    local pos = honeyPotMachinePos()
    if not pos then return false end
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    return (hrp.Position - pos).Magnitude <= HoneyPotConfig.Range
end

local function honeyPotFindEmpty()
    local slots = honeyPotSlots()
    for i = 1, HoneyPotConfig.SlotCount do
        if slots[tostring(i)] == nil then return i end
    end
    return nil
end

local function honeyPotFindReady()
    local slots = honeyPotSlots()
    for i = 1, HoneyPotConfig.SlotCount do
        local slot = slots[tostring(i)]
        if slot and honeyPotSlotState(slot) == "Ready" then return i end
    end
    return nil
end

local rarityMap = {Common=1, Uncommon=2, Rare=3, Epic=4, Legendary=5, Mythical=6, Mythic=6}
local function getRarityRank(item)
    local rarity = item and item.Rarity
    if type(rarity) == "number" then
        if rarity < 10 then return 1 end
        if rarity < 100 then return 2 end
        if rarity < 1000 then return 3 end
        if rarity < 10000 then return 4 end
        return 6
    end
    if type(rarity) == "string" then return rarityMap[rarity] or 1 end
    return 1
end

local function honeyPotFindRecipe(data)
    if not data or not HoneyPotConfig then return nil, 0 end
    if HoneyPotState.SelectedRecipe ~= "Auto" then
        local recipe = HoneyPotConfig.ByKey[HoneyPotState.SelectedRecipe]
        if recipe then
            local max = HoneyPotConfig.MaxCraftable(data, recipe)
            if max > 0 then return recipe, max end
        end
        return nil, 0
    end
    local best, bestRank, bestMax = nil, -1, 0
    for _, recipe in ipairs(HoneyPotConfig.Recipes) do
        local max = HoneyPotConfig.MaxCraftable(data, recipe)
        if max > 0 then
            local output = HoneyPotConfig.Describe(recipe.Output)
            local rank = getRarityRank(output)
            if rank > bestRank or (rank == bestRank and max > bestMax) then
                best, bestRank, bestMax = recipe, rank, max
            end
        end
    end
    return best, bestMax
end

if HoneyPotService and HoneyPotConfig then
    task.spawn(function()
        while true do
            task.wait(HoneyPotState.Delay)
            if not (HoneyPotState.ClaimRunning or HoneyPotState.CraftRunning) or HoneyPotState.Mutex then continue end
            HoneyPotState.Mutex = true
            local ok, err = pcall(function()
                if HoneyPotState.AutoTeleport and not honeyPotNear() then
                    local pos = honeyPotMachinePos()
                    if pos then
                        HoneyPotState.Status = "Teleporting to machine..."
                        TeleportTo(pos)
                        return
                    end
                end
                if not honeyPotNear() then
                    HoneyPotState.Status = "Not at machine"
                    return
                end
                if HoneyPotState.ClaimRunning then
                    local readySlot = honeyPotFindReady()
                    if readySlot then
                        local ok2, resp = pcall(function() return HoneyPotService:Claim(readySlot) end)
                        if ok2 and type(resp) == "table" and resp.Success then
                            HoneyPotState.Claimed = HoneyPotState.Claimed + 1
                            HoneyPotState.Status = "Claimed slot " .. readySlot .. " | total " .. HoneyPotState.Claimed
                        else
                            HoneyPotState.Failed = HoneyPotState.Failed + 1
                        end
                        return
                    end
                end
                if HoneyPotState.CraftRunning then
                    local emptySlot = honeyPotFindEmpty()
                    if emptySlot then
                        local data = getData()
                        local recipe, max = honeyPotFindRecipe(data)
                        if recipe then
                            local amount = math.min(HoneyPotState.CraftAmount, max, HoneyPotConfig.MaxAmount)
                            if amount >= 1 then
                                local ok2, resp = pcall(function() return HoneyPotService:Craft(recipe.Key, amount) end)
                                if ok2 and type(resp) == "table" and resp.Success then
                                    HoneyPotState.Crafted = HoneyPotState.Crafted + 1
                                    local output = HoneyPotConfig.Describe(recipe.Output)
                                    local name = (output and output.Name) or recipe.Key
                                    HoneyPotState.Status = "Crafted " .. name .. " | total " .. HoneyPotState.Crafted
                                else
                                    HoneyPotState.Failed = HoneyPotState.Failed + 1
                                end
                            end
                        else
                            HoneyPotState.Status = "No craftable recipe"
                        end
                    else
                        HoneyPotState.Status = "All slots busy"
                    end
                end
            end)
            HoneyPotState.Mutex = false
            if not ok then warn("[HoneyPot] " .. tostring(err)) end
        end
    end)
end

-- ============================================================
-- WINDOW
-- ============================================================

local Window = WindUI:CreateWindow({
    Title     = "[🎃] Tap Simulator REBORN",
    Author    = "by Ovei",
    Icon      = "star",
    Folder    = "TapSimulatorReborn",
    Size      = UDim2.fromOffset(540, 560),
    ToggleKey = Enum.KeyCode.RightShift,
    Theme     = "Dark",
    Resizable = true,
    AutoScale = true,
})

local FarmTab     = Window:Tab({ Title = "Farm",     Icon = "mouse-pointer" })
local PetsTab     = Window:Tab({ Title = "Pets",     Icon = "egg" })
local ChestsTab   = Window:Tab({ Title = "Chests",   Icon = "package" })
local GamesTab    = Window:Tab({ Title = "Games",    Icon = "swords" })
local MachinesTab = Window:Tab({ Title = "Machines", Icon = "cog" })

-- ============================================================
-- FARM TAB
-- ============================================================

FarmTab:Section({ Title = "Auto Tap", Opened = true })
FarmTab:Slider({
    Title = "Tap Speed",
    Desc  = "How fast taps are sent to the server.",
    Step  = 0.01,
    Value = { Min = 0, Max = 0.5, Default = 0.01 },
    Callback = function(v) TapState.Delay = v end,
})
FarmTab:Toggle({
    Title = "Auto Tap",
    Desc  = "Taps the screen automatically for you.",
    Value = false,
    Flag  = "autoTap",
    Callback = function(v) TapState.Running = v end,
})

FarmTab:Section({ Title = "Auto Rebirth", Opened = false })
local RebirthDropdown
RebirthDropdown = FarmTab:Dropdown({
    Title  = "Rebirth Amount",
    Desc   = "Select the specific rebirth tier to buy.",
    Values = RebirthOptions,
    Value  = RebirthOptions[1],
    Callback = function(v) RebirthState.SelectedIndex = RebirthIndexByName[v] or 1 end,
})
FarmTab:Button({
    Title = "Refresh Rebirth List",
    Desc  = "Updates the dropdown based on your unlocked tiers.",
    Icon  = "refresh-cw",
    Callback = function()
        rebuildRebirthOptions()
        if RebirthDropdown then
            pcall(function() RebirthDropdown:Refresh(RebirthOptions) end)
            local label = tostring(RebirthOptions[RebirthState.SelectedIndex] or RebirthOptions[1])
            if RebirthIndexByName[label] then
                pcall(function() RebirthDropdown:Select(label) end)
            else
                RebirthState.SelectedIndex = 1
                pcall(function() RebirthDropdown:Select(RebirthOptions[1]) end)
            end
        end
    end,
})
local RebirthSelectedToggle, RebirthHighestToggle
RebirthSelectedToggle = FarmTab:Toggle({
    Title = "Buy Selected Rebirth",
    Desc  = "Purchases the rebirth tier chosen in the dropdown.",
    Value = false,
    Flag  = "buySelectedRebirth",
    Callback = function(v)
        RebirthState.Selected = v
        if v and RebirthState.Highest then
            RebirthState.Highest = false
            pcall(function() RebirthHighestToggle:Set(false) end)
        end
    end,
})
RebirthHighestToggle = FarmTab:Toggle({
    Title = "Buy Highest Rebirth",
    Desc  = "Purchases the highest rebirth you can currently afford.",
    Value = false,
    Flag  = "buyHighestRebirth",
    Callback = function(v)
        RebirthState.Highest = v
        if v and RebirthState.Selected then
            RebirthState.Selected = false
            pcall(function() RebirthSelectedToggle:Set(false) end)
        end
    end,
})
FarmTab:Slider({
    Title = "Rebirth Delay",
    Desc  = "Time to wait between purchase attempts.",
    Step  = 0.1,
    Value = { Min = 0.5, Max = 5, Default = 1 },
    Callback = function(v) RebirthState.Delay = v end,
})

FarmTab:Section({ Title = "Auto Double Jump", Opened = false })
FarmTab:Toggle({
    Title = "Auto Buy Double Jumps",
    Desc  = "Buys the next available double jump upgrade when affordable.",
    Value = false,
    Flag  = "autoJump",
    Callback = function(v) JumpState.Running = v end,
})
FarmTab:Button({
    Title = "Buy Once",
    Desc  = "Triggers one purchase attempt right now.",
    Icon  = "zap",
    Callback = function()
        if attemptBuyJump() then
            Notify({ Title = "Double Jump", Content = "Purchase requested", Icon = "check", Duration = 2 })
        else
            Notify({ Title = "Double Jump", Content = "Not enough funds or blocked", Icon = "x", Duration = 2 })
        end
    end,
})
FarmTab:Slider({
    Title = "Jump Delay",
    Desc  = "Time to wait between purchase attempts.",
    Step  = 0.1,
    Value = { Min = 0.5, Max = 5, Default = 1 },
    Callback = function(v) JumpState.Delay = v end,
})

FarmTab:Section({ Title = "Auto Skill Tree", Opened = false })
FarmTab:Toggle({
    Title = "Auto Unlock Skills",
    Desc  = "Unlocks any affordable skill tree node.",
    Value = false,
    Flag  = "autoSkillTree",
    Callback = function(v) SkillState.Running = v end,
})
FarmTab:Slider({
    Title = "Skill Delay",
    Desc  = "Time to wait between skill upgrade checks.",
    Step  = 0.1,
    Value = { Min = 0.5, Max = 5, Default = 1 },
    Callback = function(v) SkillState.Delay = v end,
})

FarmTab:Section({ Title = "Auto Quests", Opened = false })
FarmTab:Toggle({
    Title = "Auto Claim Quests",
    Desc  = "Claims all completed and unclaimed quests.",
    Value = false,
    Flag  = "autoQuest",
    Callback = function(v) QuestState.Running = v end,
})
FarmTab:Slider({
    Title = "Claim Delay",
    Desc  = "Time to wait between claim attempts.",
    Step  = 0.1,
    Value = { Min = 0.5, Max = 5, Default = 1 },
    Callback = function(v) QuestState.Delay = v end,
})

local FarmStatus = FarmTab:Paragraph({ Title = "Status", Desc = "Idle" })
task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(function()
            FarmStatus:SetDesc(string.format(
                "Tap: %d | Rebirth: %d | Jump: %d | Skills: %d | Quests: %d",
                TapState.Count, RebirthState.Count, JumpState.Count, SkillState.Count, QuestState.Count
            ))
        end)
    end
end)

-- ============================================================
-- PETS TAB
-- ============================================================

PetsTab:Section({ Title = "Auto Hatch", Opened = true })
local EggOptions = {}
if EggConfig then
    for eggName in pairs(EggConfig) do table.insert(EggOptions, eggName) end
    table.sort(EggOptions)
    HatchCraftState.SelectedEgg = EggOptions[1]
end
PetsTab:Dropdown({
    Title  = "Select Egg",
    Desc   = "Choose the egg you want to hatch.",
    Values = EggOptions,
    Value  = EggOptions[1],
    Callback = function(v) HatchCraftState.SelectedEgg = v end,
})
PetsTab:Dropdown({
    Title  = "Hatch Amount",
    Desc   = "How many eggs to hatch at once. x8 requires a Gamepass.",
    Values = { "1", "3", "8" },
    Value  = "1",
    Callback = function(v) HatchCraftState.SelectedAmount = tonumber(v) or 1 end,
})
PetsTab:Toggle({
    Title = "Auto Hatch",
    Desc  = "Automatically hatches eggs. Crafting takes priority if enabled.",
    Value = false,
    Flag  = "autoHatch",
    Callback = function(v) HatchCraftState.HatchRunning = v end,
})
PetsTab:Slider({
    Title = "Hatch Delay",
    Desc  = "Time to wait between hatch attempts.",
    Step  = 0.1,
    Value = { Min = 0.1, Max = 2, Default = 0.5 },
    Callback = function(v) HatchCraftState.HatchDelay = v end,
})

PetsTab:Section({ Title = "Auto Craft", Opened = false })
local CraftPetsOptions = {}
if MachineConfig and MachineConfig.Golden and MachineConfig.Golden.Chances then
    for i, chance in ipairs(MachineConfig.Golden.Chances) do
        table.insert(CraftPetsOptions, string.format("%d Pets (%d%%)", i, chance))
    end
end
PetsTab:Dropdown({
    Title  = "Pets to Use",
    Desc   = "Number of pets consumed per craft.",
    Values = CraftPetsOptions,
    Value  = CraftPetsOptions[6],
    Callback = function(v)
        local n = tonumber(string.match(v, "%d+"))
        if n then HatchCraftState.PetsToUse = n end
    end,
})

local function getMutationOptions()
    local set = { ["None"] = true }
    local data = getData()
    if data and data.Pets and data.Pets.Owned then
        for _, pet in pairs(data.Pets.Owned) do
            if type(pet.Mutation) == "string" and pet.Mutation ~= "" then
                set[pet.Mutation] = true
            end
        end
    end
    local list = {}
    for name in pairs(set) do table.insert(list, name) end
    table.sort(list)
    return list
end

local CraftMutationDropdown
CraftMutationDropdown = PetsTab:Dropdown({
    Title  = "Filter Mutation",
    Desc   = "Only craft pets that have this mutation.",
    Values = getMutationOptions(),
    Value  = "None",
    Callback = function(v) HatchCraftState.SelectedMutation = v end,
})
PetsTab:Button({
    Title = "Refresh Mutations",
    Desc  = "Updates the mutation list based on your current pets.",
    Icon  = "refresh-cw",
    Callback = function()
        local opts = getMutationOptions()
        if CraftMutationDropdown then
            pcall(function() CraftMutationDropdown:Refresh(opts) end)
            if not table.find(opts, HatchCraftState.SelectedMutation) then
                HatchCraftState.SelectedMutation = "None"
                pcall(function() CraftMutationDropdown:Select("None") end)
            end
        end
    end,
})
PetsTab:Toggle({
    Title = "Auto Craft",
    Desc  = "Automatically crafts Golden pets from matching inventory.",
    Value = false,
    Flag  = "autoCraft",
    Callback = function(v) HatchCraftState.CraftRunning = v end,
})
PetsTab:Slider({
    Title = "Craft Delay",
    Desc  = "Time to wait between craft attempts.",
    Step  = 0.1,
    Value = { Min = 0.5, Max = 5, Default = 1 },
    Callback = function(v) HatchCraftState.CraftDelay = v end,
})

PetsTab:Section({ Title = "Auto Items", Opened = false })
local BoostList = {}
if BoostConfig and BoostConfig.Definitions then
    for name in pairs(BoostConfig.Definitions) do table.insert(BoostList, name) end
    table.sort(BoostList)
end
local GiftsList = { "New Years Gift", "Valentines Gift", "St. Patrick Gift", "Release Gift" }
local TreatsList = { "RegularTreat", "BagOfTreats", "ExoticShard", "ElectricShard", "SecretFruit", "DragonFruit", "GoldenApple", "RainbowStrawberry", "GoldenTreat" }
local TotemsList = { "TotemOfLuck", "TotemOfRebirths", "TotemOfClicks", "TotemOfSecretLuck", "TotemOfHatchSpeed" }

PetsTab:Toggle({
    Title = "Use Boosts",
    Desc  = "Uses selected boosts from your inventory.",
    Value = false,
    Flag  = "useBoosts",
    Callback = function(v) ItemState.BoostRunning = v end,
})
PetsTab:Dropdown({
    Title  = "Select Boosts",
    Desc   = "Choose which boosts to use.",
    Values = BoostList,
    Multi  = true,
    AllowNone = true,
    Callback = function(v) ItemState.SelectedBoosts = v end,
})
PetsTab:Toggle({
    Title = "Open Gifts",
    Desc  = "Opens selected gift items.",
    Value = false,
    Flag  = "openGifts",
    Callback = function(v) ItemState.GiftRunning = v end,
})
PetsTab:Dropdown({
    Title  = "Select Gifts",
    Desc   = "Choose which gifts to open.",
    Values = GiftsList,
    Multi  = true,
    AllowNone = true,
    Callback = function(v) ItemState.SelectedGifts = v end,
})
PetsTab:Toggle({
    Title = "Feed Treats",
    Desc  = "Feeds selected treats to your first pet.",
    Value = false,
    Flag  = "feedTreats",
    Callback = function(v) ItemState.TreatRunning = v end,
})
PetsTab:Dropdown({
    Title  = "Select Treats",
    Desc   = "Choose which treats to feed.",
    Values = TreatsList,
    Multi  = true,
    AllowNone = true,
    Callback = function(v) ItemState.SelectedTreats = v end,
})
PetsTab:Toggle({
    Title = "Place Totems",
    Desc  = "Places selected totems near you.",
    Value = false,
    Flag  = "placeTotems",
    Callback = function(v) ItemState.TotemRunning = v end,
})
PetsTab:Dropdown({
    Title  = "Select Totems",
    Desc   = "Choose which totems to place.",
    Values = TotemsList,
    Multi  = true,
    AllowNone = true,
    Callback = function(v) ItemState.SelectedTotems = v end,
})
PetsTab:Slider({
    Title = "Item Delay",
    Desc  = "Time to wait between item actions.",
    Step  = 0.1,
    Value = { Min = 0.5, Max = 5, Default = 1 },
    Callback = function(v) ItemState.Delay = v end,
})

local PetsStatus = PetsTab:Paragraph({ Title = "Status", Desc = "Idle" })
task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(function()
            PetsStatus:SetDesc(string.format(
                "Hatched: %d | Crafted: %d | Items used: %d | %s",
                HatchCraftState.Hatched, HatchCraftState.Crafted, ItemState.Used, HatchCraftState.Status
            ))
        end)
    end
end)

-- ============================================================
-- CHESTS TAB
-- ============================================================

ChestsTab:Section({ Title = "Auto Tap Chest", Opened = true })
local TapChestCollectToggle, TapChestOpenToggle
TapChestCollectToggle = ChestsTab:Toggle({
    Title = "Auto Collect Tap Chest",
    Desc  = "Runs the game's own chest opening sequence.",
    Value = false,
    Flag  = "autoCollectTapChest",
    Callback = function(v)
        TapChestState.CollectRunning = v
        if v and TapChestState.OpenRunning then
            TapChestState.OpenRunning = false
            pcall(function() TapChestOpenToggle:Set(false) end)
        end
    end,
})
TapChestOpenToggle = ChestsTab:Toggle({
    Title = "Auto Open Tap Chest",
    Desc  = "Runs the full chest opening animation before claiming.",
    Value = false,
    Flag  = "autoOpenTapChest",
    Callback = function(v)
        TapChestState.OpenRunning = v
        if v and TapChestState.CollectRunning then
            TapChestState.CollectRunning = false
            pcall(function() TapChestCollectToggle:Set(false) end)
        end
    end,
})
ChestsTab:Slider({
    Title = "Chest Delay",
    Desc  = "Time to wait between chest actions.",
    Step  = 0.1,
    Value = { Min = 0.1, Max = 3, Default = 0.5 },
    Callback = function(v) TapChestState.Delay = v end,
})

ChestsTab:Section({ Title = "Auto Clicker Chest", Opened = false })
ChestsTab:Toggle({
    Title = "Auto Teleport to Clicker Chest",
    Desc  = "Finds the nearest ClickerChest and teleports to it.",
    Value = false,
    Flag  = "autoClickerChest",
    Callback = function(v)
        ClickerState.Running = v
        if v then ClickerState.Current = getClickerChest() end
    end,
})
ChestsTab:Slider({
    Title = "Check Delay",
    Desc  = "Time to wait between scans for a new chest.",
    Step  = 0.1,
    Value = { Min = 0.1, Max = 3, Default = 0.5 },
    Callback = function(v) ClickerState.Delay = v end,
})

local ChestsStatus = ChestsTab:Paragraph({ Title = "Status", Desc = "Idle" })
task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(function()
            ChestsStatus:SetDesc(string.format(
                "Collected: %d | Opened: %d | Failed: %d | %s",
                TapChestState.Collected, TapChestState.Opened, TapChestState.Failed, TapChestState.Status
            ))
        end)
    end
end)

-- ============================================================
-- GAMES TAB
-- ============================================================

GamesTab:Section({ Title = "Auto Dig Perfect", Opened = true })
GamesTab:Toggle({
    Title = "Auto Dig Perfect",
    Desc  = "Teleports to the dig site and hits every round at the perfect zone.",
    Value = false,
    Flag  = "autoDigPerfect",
    Callback = function(v)
        DigState.Running = v
        if not v then cancelDigSession() end
        if v then
            DigState.Status = "Starting..."
            Notify({Title = "Auto Dig", Content = "Starting", Icon = "circle-check", Duration = 2})
        end
    end,
})
GamesTab:Button({
    Title = "Cancel Current Session",
    Desc  = "Fires the cancel remote and clears local state.",
    Icon  = "x",
    Callback = function()
        cancelDigSession()
        DigState.Status = "Session cancelled"
    end,
})
GamesTab:Button({
    Title = "Reset Dig Stats",
    Desc  = "Clears hit and game counters.",
    Icon  = "refresh-cw",
    Callback = function()
        DigState.TotalHits = 0
        DigState.TotalGames = 0
        DigState.LastReward = nil
        DigState.Status = "Stats reset"
    end,
})

GamesTab:Section({ Title = "Auto Colosseum", Opened = false })
local ColosseumToggle
ColosseumToggle = GamesTab:Toggle({
    Title = "Auto Colosseum",
    Desc  = "Starts Pet Defense and auto-attacks the closest threat.",
    Value = false,
    Flag  = "autoColosseum",
    Callback = function(v)
        if v then
            local ok = colosseumStart()
            if not ok and ColosseumToggle then
                pcall(function() ColosseumToggle:Set(false) end)
                Notify({ Title = "Colosseum", Content = "Could not start", Icon = "x", Duration = 3 })
            end
        else
            colosseumStop()
        end
    end,
})
GamesTab:Slider({
    Title = "Attack Interval",
    Desc  = "Time between attacks on the same opponent.",
    Step  = 0.01,
    Value = { Min = 0.05, Max = 1, Default = 0.15 },
    Callback = function(v) ColosseumState.AttackInterval = v end,
})
GamesTab:Slider({
    Title = "Critical Interval",
    Desc  = "Time between critical hit attempts.",
    Step  = 0.5,
    Value = { Min = 3, Max = 15, Default = 7 },
    Callback = function(v) ColosseumState.CriticalInterval = v end,
})
GamesTab:Paragraph({
    Title = "Note",
    Desc  = "Auto-start skips the client intro, so opponent models may not appear. Combat and rewards work normally.",
})

local GamesStatus = GamesTab:Paragraph({ Title = "Status", Desc = "Idle" })
task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(function()
            GamesStatus:SetDesc(string.format(
                "Dig: hits %d, games %d, last %s | Colosseum: %d waves",
                DigState.TotalHits, DigState.TotalGames, tostring(DigState.LastReward or "-"), ColosseumState.Waves
            ))
        end)
    end
end)

-- ============================================================
-- MACHINES TAB
-- ============================================================

MachinesTab:Section({ Title = "Auto Honey Pot", Opened = true })

local HoneyPotRecipeOptions = { "Auto" }
local HoneyPotRecipeKeyByLabel = {}
if HoneyPotConfig then
    local seen = {}
    for i, recipe in ipairs(HoneyPotConfig.Recipes) do
        local output = HoneyPotConfig.Describe(recipe.Output)
        local base = (output and output.Name) or recipe.Key
        local label = base
        if seen[base] then label = base .. " #" .. i end
        seen[base] = true
        HoneyPotRecipeKeyByLabel[label] = recipe.Key
        table.insert(HoneyPotRecipeOptions, label)
    end
end

MachinesTab:Toggle({
    Title = "Auto Claim",
    Desc  = "Claims any ready slot on the Honey Pot machine.",
    Value = false,
    Flag  = "autoClaimHoneyPot",
    Callback = function(v) HoneyPotState.ClaimRunning = v end,
})
MachinesTab:Toggle({
    Title = "Auto Craft",
    Desc  = "Crafts into empty slots when ingredients are available.",
    Value = false,
    Flag  = "autoCraftHoneyPot",
    Callback = function(v) HoneyPotState.CraftRunning = v end,
})
MachinesTab:Toggle({
    Title = "Auto Teleport to Machine",
    Desc  = "Teleports to the Honey Pot machine when out of range.",
    Value = true,
    Flag  = "autoTeleportHoneyPot",
    Callback = function(v) HoneyPotState.AutoTeleport = v end,
})
MachinesTab:Dropdown({
    Title  = "Recipe",
    Desc   = "Auto picks the highest-rarity craftable recipe.",
    Values = HoneyPotRecipeOptions,
    Value  = "Auto",
    Callback = function(v)
        if v == "Auto" then
            HoneyPotState.SelectedRecipe = "Auto"
        else
            HoneyPotState.SelectedRecipe = HoneyPotRecipeKeyByLabel[v] or "Auto"
        end
    end,
})
MachinesTab:Slider({
    Title = "Craft Amount",
    Desc  = "Max amount per craft request.",
    Step  = 1,
    Value = { Min = 1, Max = 50, Default = 1 },
    Callback = function(v) HoneyPotState.CraftAmount = v end,
})
MachinesTab:Slider({
    Title = "Action Delay",
    Desc  = "Time between claim and craft actions.",
    Step  = 0.1,
    Value = { Min = 0.3, Max = 3, Default = 0.5 },
    Callback = function(v) HoneyPotState.Delay = v end,
})

local MachinesStatus = MachinesTab:Paragraph({ Title = "Status", Desc = "Idle" })
task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(function()
            MachinesStatus:SetDesc(string.format(
                "Claimed: %d | Crafted: %d | Failed: %d | %s",
                HoneyPotState.Claimed, HoneyPotState.Crafted, HoneyPotState.Failed, HoneyPotState.Status
            ))
        end)
    end
end)

Notify({
    Title = "Tap Simulator REBORN",
    Content = "Loaded. Toggle anything to start.",
    Icon = "check",
    Duration = 5,
})
