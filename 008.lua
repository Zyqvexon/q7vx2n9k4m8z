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
                    if ok2 and price and coins >= price then
                        bestIdx = i
                    else
                        break
                    end
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

local HatchCraftState = {
    HatchRunning = false,
    CraftRunning = false,
    SelectedEgg = nil,
    SelectedAmount = 1,
    HatchDelay = 0.5,
    CraftDelay = 1,
    PetsToUse = 6,
    SelectedMutation = "None",
    isRequestPending = false,
    lastHatchResultTime = 0,
    lastCraftResultTime = 0,
    Hatched = 0,
    Crafted = 0,
    Status = "Idle",
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

local ItemState = {
    BoostRunning = false,
    GiftRunning = false,
    TreatRunning = false,
    TotemRunning = false,
    Delay = 1,
    SelectedBoosts = {},
    SelectedGifts = {},
    SelectedTreats = {},
    SelectedTotems = {},
    Status = "Idle",
    Used = 0,
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

local TapChestState = {
    CollectRunning = false,
    OpenRunning = false,
    Mutex = false,
    Delay = 0.5,
    Collected = 0,
    Opened = 0,
    Failed = 0,
    Status = "Idle",
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

local DigState = {
    Running = false,
    Session = nil,
    LastHitTime = 0,
    TotalHits = 0,
    TotalGames = 0,
    LastReward = nil,
    Status = "Idle",
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
    local islands = Workspace:FindFirstChild("Ts2Islands")
    if not islands then return nil end
    local autumn = islands:FindFirstChild("Autumn")
    if not autumn then return nil end
    local site = autumn:FindFirstChild("Digsite")
    if not site then return nil end
    return site:FindFirstChild("DigZone")
end

local function isInDigZone()
    local zone = getDigZone()
    if not zone then return false end
    local char = LocalPlayer.Character
    if not char then return false end
    if not DigWorld or type(DigWorld.Contains) ~= "function" then return false end
    local ok, res = pcall(function() return DigWorld.Contains(zone, char) end)
    return ok and res
end

local function getDigAllowance()
    if not DataController or not DigConfig or type(DigConfig.Allowance) ~= "function" then return 999, 0 end
    local replica = DataController:GetReplica()
    if not replica or not replica.Data or not replica.Data.Digging then return 0, 0 end
    local ok, a, b = pcall(function() return DigConfig.Allowance(replica.Data.Digging, os.time()) end)
    if ok then return a or 0, b or 0 end
    return 0, 0
end

local function cancelDigSession()
    if DigState.Session and DigState.Session.Id and DigComm then
        local sid = DigState.Session.Id
        task.spawn(function() pcall(function() DigComm:Cancel(sid) end) end)
    end
    DigState.Session = nil
end

task.spawn(function()
    while true do
        task.wait(0.5)
        if not DigState.Running then continue end
        if not DigComm then
            DigState.Status = "Service unavailable"
            DigState.Running = false
            continue
        end
        local zone = getDigZone()
        if not zone then
            DigState.Status = "Dig site not found"
            continue
        end
        if not isInDigZone() then
            local pos = getPartPos(zone)
            if pos then TeleportTo(pos) end
            if not isInDigZone() then
                DigState.Status = "Teleporting to site..."
                continue
            end
        end
        local digsLeft = getDigAllowance()
        if digsLeft <= 0 then
            DigState.Status = "Out of digs"
            DigState.Running = false
            continue
        end
        if not DigState.Session then
            local ok, resp = pcall(function() return DigComm:Begin() end)
            if not ok or not resp then
                DigState.Status = "Begin failed"
                continue
            end
            if resp.Error then
                if resp.Error == "Cooldown" then
                    DigState.Status = "Cooldown"
                    DigState.Running = false
                    continue
                end
                DigState.Status = "Error: " .. tostring(resp.Error)
                continue
            end
            DigState.Session = resp
        end
        local session = DigState.Session
        if not session or not session.Round then
            DigState.Session = nil
            continue
        end
        if session.Complete then
            DigState.Session = nil
            continue
        end
        local now = Workspace:GetServerTimeNow()
        local minTime = math.max(now + 0.02, DigState.LastHitTime + MinHitInterval)
        local target = computePerfectTime(session.Round, minTime)
        if not target then
            DigState.Session = nil
            DigState.Status = "Invalid round"
            continue
        end
        while DigState.Running do
            local t = Workspace:GetServerTimeNow()
            if t >= target - 0.005 then break end
            local remaining = target - t
            if remaining > 0.05 then task.wait(math.min(remaining - 0.02, 0.2))
            else task.wait() end
        end
        if not DigState.Running then break end
        local hitTime = Workspace:GetServerTimeNow()
        local ok, resp = pcall(function() return DigComm:Hit(session.Id, session.Round.Sequence, hitTime) end)
        if not ok or not resp then
            DigState.Session = nil
            DigState.Status = "Hit failed"
            continue
        end
        if resp.Error then
            if resp.Error == "NoSession" then DigState.Session = nil
            elseif resp.Error == "Cooldown" then
                DigState.Status = "Cooldown"
                DigState.Running = false
                break
            elseif resp.Error == "TooSoon" then task.wait(0.2)
            elseif resp.Error == "Busy" then task.wait(0.3)
            elseif resp.Error == "StaleRound" then DigState.Session = nil
            else
                DigState.Session = nil
                DigState.Status = "Error: " .. tostring(resp.Error)
            end
            continue
        end
        DigState.LastHitTime = hitTime
        DigState.TotalHits = DigState.TotalHits + 1
        if resp.Complete then
            DigState.TotalGames = DigState.TotalGames + 1
            DigState.LastReward = resp.Reward
            DigState.Status = "Done: " .. tostring(resp.Reward)
            DigState.Session = nil
            task.wait(0.4)
        else
            DigState.Session = resp
            DigState.Status = "Hit " .. DigState.TotalHits
        end
    end
    cancelDigSession()
end)

local ColosseumState = {
    Active = false,
    Opponents = {},
    AttackInterval = 0.15,
    CriticalInterval = 7,
    Attacks = 0,
    Kills = 0,
    Criticals = 0,
    Waves = 0,
    Status = "Idle",
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
