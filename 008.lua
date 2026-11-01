task.wait(2)

local source = game:HttpGet("https://sirius.menu/gen2")
local patchedSource = source:gsub(
    "af%.guiContainer=%(function%(%):Instance.-end%)%(%)",
    "af.guiContainer=(function():Instance local ag=af.localPlayer if ag then local ah=ag:FindFirstChildOfClass('PlayerGui') or ag:WaitForChild('PlayerGui') if ah then return ah end end return af.coreGui end)()",
    1
)

local Rayfield = loadstring(patchedSource)()

local Window = Rayfield:CreateWindow({
    name = "[🎃] Tap Simulator REBORN",
    subtitle = "by Ovei",
    theme = "cobalt",
    sidebarLayout = false,
    configuration = {
        autoSave = true,
        autoLoad = true,
        fileName = "TapSimulatorReborn",
        customFolder = "TapSimulatorReborn",
    },
})

local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        Window:ToggleHide()
    end
end)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local LocalPlayer = Players.LocalPlayer
local RS = ReplicatedStorage

local DataController = require(RS.Controllers.Core.DataController)
local CommModule = require(RS.Packages.Comm)

local RemoteServices = RS:FindFirstChild("RemoteServices")

local TapChestConfig = require(RS.Shared.Game.TapChestConfig)
local TapChestController = require(RS.Controllers.Game.TapChestController)
local DigConfig = require(RS.Shared.Minigames.DigConfig)
local DigWorld = require(RS.Shared.Minigames.DigWorld)
local HoneyPotConfig = require(RS.Shared.Items.HoneyPotConfig)
local ColosseumAdapter = require(RS.Controllers.Minigames.ColosseumClientAdapter)

local EggConfig = require(RS.Shared.Pets.LaunchEggConfig)
local EggPricing = require(RS.Shared.Pets.EggPricing)
local EggIdleAnimation
pcall(function()
    EggIdleAnimation = require(RS.Modules.Client.Pets.EggIdleAnimation)
end)
local GamepassPerks = require(RS.Shared.Monetization.GamepassPerks)
local BoostFormula = require(RS.Shared.Items.BoostFormula)
local BoostConfig = require(RS.Shared.Items.BoostConfig)
local MachineConfig = require(RS.Shared.Pets.MachineConfig)
local SkillTreeConfig = require(RS.Shared.Progression.SkillTreeConfig)
local SkillTreeFormula = require(RS.Shared.Progression.SkillTreeFormula)
local SkillTreeRequirements = require(RS.Shared.Progression.SkillTreeRequirements)
local QuestConfig = require(RS.Shared.Quests.QuestConfig)
local RebirthConfig = require(RS.Shared.Progression.RebirthConfig)
local RebirthButtonConfig = require(RS.Shared.Progression.RebirthButtonConfig)
local PhysicalUpgradeConfig = require(RS.Shared.Progression.PhysicalUpgradeConfig)
local CurrencyConfig = require(RS.Shared.Core.CurrencyConfig)
local GiftController = require(RS.Controllers.Items.GiftController)

local EggService = CommModule.ClientComm.new(RemoteServices, false, "EggService"):BuildObject()
local MachineService = CommModule.ClientComm.new(RemoteServices, false, "MachineService"):BuildObject()
local SkillTreeService = CommModule.ClientComm.new(RemoteServices, false, "SkillTreeService"):BuildObject()
local ItemService = CommModule.ClientComm.new(RemoteServices, false, "ItemService"):BuildObject()
local TapChestService = CommModule.ClientComm.new(RemoteServices, false, "TapChestService"):BuildObject()
local DigComm = CommModule.ClientComm.new(RemoteServices, false, "DigService"):BuildObject()
local HoneyPotService = CommModule.ClientComm.new(RemoteServices, false, "HoneyPotService"):BuildObject()

local function getRemote(serviceName, kind, name)
    local svc = RemoteServices:FindFirstChild(serviceName)
    if not svc then return nil end
    local k = svc:FindFirstChild(kind)
    if k then return k:FindFirstChild(name) end
    return svc:FindFirstChild(name)
end

local TapRemote = getRemote("TapService", "RE", "TapRequested")
local RebirthRemote = getRemote("RebirthService", "RE", "RebirthRequested")
local BoostRemote = getRemote("BoostService", "RF", "Use")
local JumpRemote = getRemote("PhysicalUpgradeService", "RF", "Purchase")
local ClaimQuestRF = getRemote("QuestService", "RF", "ClaimQuest")
local ClaimQuestRE = getRemote("QuestService", "RE", "ClaimQuest")

local ColosseumNetwork = ColosseumAdapter and ColosseumAdapter.Network or nil

local function Notify(cfg)
    Window:Notify({
        title = cfg.title or cfg.name or "Tap Simulator REBORN",
        content = cfg.content or "",
        duration = cfg.duration,
    })
end

local function getData()
    return DataController:GetReplica().Data
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

-- EggController uses a strict proximity threshold when selecting an egg.
-- This helper verifies against that tighter range instead of TeleportTo's
-- generic 10/15-stud tolerance.
local function TeleportToRange(targetPos, maxDistance)
    if typeof(targetPos) ~= "Vector3" then return false end
    maxDistance = tonumber(maxDistance) or 8.5

    for attempt = 1, 3 do
        local char = LocalPlayer.Character
        if not char then return false end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end
        if (hrp.Position - targetPos).Magnitude <= maxDistance then return true end

        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.Physics) end
        hrp.Anchored = true
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        for _ = 1, 5 do
            hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 1.5, 0))
            task.wait(0.05)
        end
        hrp.Anchored = false
        if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
        task.wait(0.25)

        hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp and (hrp.Position - targetPos).Magnitude <= maxDistance then
            return true
        end
    end
    return false
end

local function getObjectBounds(obj)
    if not obj then return nil, nil end
    if obj:IsA("BasePart") then
        return obj.CFrame, obj.Size
    end
    if obj:IsA("Model") then
        local ok, cf, size = pcall(function()
            local boundsCFrame, boundsSize = obj:GetBoundingBox()
            return boundsCFrame, boundsSize
        end)
        if ok and cf and size then return cf, size end
    end
    return nil, nil
end

local function isInsideObjectBounds(obj, worldPosition)
    local boundsCFrame, boundsSize = getObjectBounds(obj)
    if not boundsCFrame or not boundsSize then return false end
    local localPosition = boundsCFrame:PointToObjectSpace(worldPosition)
    local half = boundsSize / 2
    return math.abs(localPosition.X) <= half.X
        and math.abs(localPosition.Y) <= half.Y
        and math.abs(localPosition.Z) <= half.Z
end

-- The Golden Machine's interaction detector checks the tagged object's actual
-- bounding box, not a generic distance from its first child part.
local function TeleportIntoInteractionPoint(interactionPoint)
    local boundsCFrame, boundsSize = getObjectBounds(interactionPoint)
    if not boundsCFrame or not boundsSize then return false end

    local verticalOffset = math.min(0.75, math.max(0, boundsSize.Y * 0.2))
    local destination = boundsCFrame:PointToWorldSpace(Vector3.new(0, verticalOffset, 0))

    for attempt = 1, 3 do
        local char = LocalPlayer.Character
        if not char then return false end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end

        if isInsideObjectBounds(interactionPoint, hrp.Position) then return true end

        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.Physics) end
        hrp.Anchored = true
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        for _ = 1, 4 do
            hrp.CFrame = CFrame.new(destination)
            task.wait(0.05)
        end
        hrp.Anchored = false
        if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
        task.wait(0.2)

        hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp and isInsideObjectBounds(interactionPoint, hrp.Position) then
            return true
        end
    end
    return false
end

local TapState = { Running = false, Seq = 0, Delay = 0.01, Count = 0 }

task.spawn(function()
    while true do
        task.wait(TapState.Delay)
        if not TapState.Running then continue end
        TapState.Seq = TapState.Seq + 1
        TapRemote:FireServer({ ClientSequence = TapState.Seq, Auto = false, Source = "screen" })
        TapState.Count = TapState.Count + 1
    end
end)

local RebirthState = { Selected = false, Highest = false, SelectedIndex = 1, Delay = 1, Count = 0 }
local RebirthOptions = {}
local RebirthIndexByName = {}

local function rebuildRebirthOptions()
    RebirthOptions = {}
    RebirthIndexByName = {}
    local maxOptions = 5
    local data = getData()
    if data and RebirthButtonConfig then
        local unlocked = data.Upgrades and data.Upgrades.RebirthButtons or 0
        local count = RebirthButtonConfig.GetOptionCount(unlocked, "Main")
        if count and count > 0 then maxOptions = count end
    end
    for i = 1, maxOptions do
        local amt = RebirthConfig.GetAmountFromIndex(i)
        if amt then
            local label = tostring(amt)
            table.insert(RebirthOptions, label)
            RebirthIndexByName[label] = i
        end
    end
end

rebuildRebirthOptions()

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
                local amt = RebirthConfig.GetAmountFromIndex(i)
                if not amt then break end
                local price = RebirthConfig.GetPrice(amt, rebirths)
                if price and coins >= price then bestIdx = i else break end
            end
            if bestIdx > 0 then
                RebirthRemote:FireServer({ Index = bestIdx })
                RebirthState.Count = RebirthState.Count + 1
            end
        elseif RebirthState.Selected then
            local amt = RebirthConfig.GetAmountFromIndex(RebirthState.SelectedIndex)
            if amt then
                local price = RebirthConfig.GetPrice(amt, rebirths)
                if price and coins >= price then
                    RebirthRemote:FireServer({ Index = RebirthState.SelectedIndex })
                    RebirthState.Count = RebirthState.Count + 1
                end
            end
        end
    end
end)

local JumpState = { Running = false, Delay = 1, Count = 0 }

local function attemptBuyJump()
    local data = getData()
    if not data then return false end
    local config = PhysicalUpgradeConfig.Get("+1 Jump")
    if not config then return false end
    local nextIdx = PhysicalUpgradeConfig.GetOwned(data, config) + 1
    local price = PhysicalUpgradeConfig.GetPrice(config, nextIdx)
    local locked = PhysicalUpgradeConfig.GetLockedIsland(data, config, nextIdx)
    if not price or locked then return false end
    
    local currency = data
    local paths = CurrencyConfig.Paths[config.Currency]
    if paths then
        for _, v in ipairs(paths) do
            if type(currency) == "table" then currency = currency[v] end
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
    JumpRemote:InvokeServer({ Index = nextIdx, Upgrade = "+1 Jump" })
    if savedPos then
        task.delay(1, function()
            local hrp2 = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp2 then TeleportTo(savedPos) end
        end)
    end
    return true
end

task.spawn(function()
    while true do
        task.wait(JumpState.Delay)
        if not JumpState.Running then continue end
        if attemptBuyJump() then
            JumpState.Count = JumpState.Count + 1
        end
    end
end)

local SkillState = { Running = false, Delay = 1, Count = 0 }

task.spawn(function()
    while true do
        task.wait(SkillState.Delay)
        if not SkillState.Running then continue end
        local data = getData()
        if not data then continue end
        local unlocked = (data.SkillTree and data.SkillTree.Unlocked) or {}
        local gems = (data.Currencies and data.Currencies.Gems) or 0
        
        local function scan(node, parentUnlocked)
            if type(node) ~= "table" or not node.Name then return false end
            if unlocked[node.Name] or node.Origin then
                for _, dir in ipairs({"N", "S", "NE", "NW", "SE", "SW"}) do
                    if type(node[dir]) == "table" and scan(node[dir], true) then return true end
                end
            elseif parentUnlocked and not node.Category and not node.Origin then
                local price = SkillTreeFormula.GetPrice(data, node.Name)
                if price and price <= gems then
                    local lockedShop = SkillTreeRequirements.GetLockedShop(data, node)
                    local lockedIsland = SkillTreeRequirements.GetLockedIsland(data, node)
                    local withheld = SkillTreeFormula.IsWithheld(data, node.Name)
                    if not lockedShop and not lockedIsland and not withheld then
                        local res = SkillTreeService:Unlock({ Name = node.Name })
                        if type(res) == "table" and res.Success then
                            SkillState.Count = SkillState.Count + 1
                            return true
                        end
                    end
                end
            end
            return false
        end
        
        for _, tree in pairs(SkillTreeConfig) do
            if scan(tree, true) then break end
        end
    end
end)

local QuestState = { Running = false, Delay = 1, Count = 0 }

task.spawn(function()
    while true do
        task.wait(QuestState.Delay)
        if not QuestState.Running then continue end
        local data = getData()
        if not data or not data.Quests then continue end
        for name, qData in pairs(data.Quests) do
            local config = QuestConfig.Definitions and QuestConfig.Definitions[name]
            if config and not qData.Claimed then
                local completed = qData.Completed
                local amount = qData.Amount or 0
                local goal = config.Goal or 0
                if completed or (goal > 0 and amount >= goal) then
                    if ClaimQuestRF then ClaimQuestRF:InvokeServer({ Quest = name })
                    elseif ClaimQuestRE then ClaimQuestRE:FireServer({ Quest = name }) end
                    QuestState.Count = QuestState.Count + 1
                    task.wait(0.1)
                end
            end
        end
    end
end)

local HatchState = {
    HatchRunning = false,
    SelectedEgg = nil, SelectedAmount = 1,
    HatchDelay = 0.5,
    isRequestPending = false,
    lastHatchResultTime = 0,
    Hatched = 0, Status = "Idle",
}

EggService.EggHatchResult:Connect(function(result)
    HatchState.isRequestPending = false
    HatchState.lastHatchResultTime = os.clock()

    if type(result) == "table" and result.Success == true then
        HatchState.Hatched = HatchState.Hatched + 1
        HatchState.Status = "Hatched | total " .. HatchState.Hatched
    elseif type(result) == "table" and result.Error then
        HatchState.Status = "Hatch failed: " .. tostring(result.Error)
    else
        HatchState.Status = "Hatch request completed"
    end
end)

local function getEggModel(eggName)
    local eggsFolder = Workspace:FindFirstChild("Eggs")
    if not eggsFolder then return nil end
    return eggsFolder:FindFirstChild(eggName)
end

local function getEggPos(eggName)
    local eggModel = getEggModel(eggName)
    if not eggModel then return nil end

    -- EggController uses EggIdleAnimation.GetPosition for its proximity test.
    if EggIdleAnimation and type(EggIdleAnimation.GetPosition) == "function" then
        local ok, position = pcall(EggIdleAnimation.GetPosition, eggModel)
        if ok and typeof(position) == "Vector3" then return position end
    end

    -- Match EggController's fallback: prefer the part under the "Egg" child,
    -- then that child's PrimaryPart/first BasePart, then the outer model root.
    local eggRoot = eggModel:FindFirstChild("Egg")
    if eggRoot and eggRoot:IsA("BasePart") then
        return eggRoot.Position
    elseif eggRoot and eggRoot:IsA("Model") then
        local rootPart = eggRoot.PrimaryPart or eggRoot:FindFirstChildWhichIsA("BasePart", true)
        if rootPart then return rootPart.Position end
    end
    local rootPart = eggModel.PrimaryPart or eggModel:FindFirstChildWhichIsA("BasePart", true)
    if rootPart then return rootPart.Position end
    return nil
end

task.spawn(function()
    while true do
        task.wait(0.1)
        if HatchState.isRequestPending or not HatchState.HatchRunning then continue end
        local data = getData()
        if not data then continue end
        if os.clock() - HatchState.lastHatchResultTime < HatchState.HatchDelay then continue end
        local invCount = 0
        for _ in pairs((data.Pets and data.Pets.Owned) or {}) do invCount = invCount + 1 end
        local limit = (data.Pets and data.Pets.StorageLimit) or math.huge
        if invCount >= limit then continue end
        if not HatchState.SelectedEgg or not EggConfig[HatchState.SelectedEgg] then continue end
        local price = EggPricing.GetTotal(data, HatchState.SelectedEgg, EggConfig[HatchState.SelectedEgg].Price, HatchState.SelectedAmount)
        local coins = (data.Currencies and data.Currencies.Coins) or 0
        if not (price and coins >= price) then continue end
        if HatchState.SelectedAmount == 8 then
            local hasPerk = GamepassPerks.Has(data, "x8Egg")
            local hasBoost = BoostFormula.HasType(data, "OctoHatch")
            if not hasPerk and not hasBoost then
                HatchState.Status = "x8 Gamepass required"
                continue
            end
        end
        local pos = getEggPos(HatchState.SelectedEgg)
        if not pos then
            HatchState.Status = "Egg not loaded"
            task.wait(0.5)
            continue
        end

        -- EggController only recognizes an egg inside its 10-stud proximity
        -- range. Aim for 8 studs to leave room for character movement/physics.
        if not TeleportToRange(pos, 8.5) then
            HatchState.Status = "Could not reach egg"
            task.wait(0.5)
            continue
        end
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp or (hrp.Position - pos).Magnitude >= 9 then
            HatchState.Status = "Outside egg range"
            task.wait(0.5)
            continue
        end

        HatchState.isRequestPending = true
        HatchState.Status = "Waiting for hatch result..."
        EggService.EggHatchRequested:Fire({
            Egg = HatchState.SelectedEgg,
            Count = HatchState.SelectedAmount,
            Auto = true,
            Seq = math.random(1, 100000),
        })
        task.delay(12, function()
            if HatchState.isRequestPending then
                HatchState.isRequestPending = false
                HatchState.Status = "Hatch timed out; retrying"
            end
        end)
    end
end)

local ItemState = {
    BoostRunning = false, GiftRunning = false, TreatRunning = false, TotemRunning = false,
    Delay = 1, SelectedBoosts = {}, SelectedGifts = {}, SelectedTreats = {}, SelectedTotems = {},
    Used = 0,
}

task.spawn(function()
    while true do
        task.wait(ItemState.Delay)
        local data = getData()
        if not data then continue end
        local items = (data.Items and data.Items.Owned) or {}
        local function hasItem(name) return (items[name] or 0) > 0 end
        
        if ItemState.BoostRunning then
            local boosts = data.Boosts or {}
            for _, name in ipairs(ItemState.SelectedBoosts) do
                if (boosts[name] or 0) > 0 then
                    BoostRemote:InvokeServer(name)
                    ItemState.Used = ItemState.Used + 1
                    break
                end
            end
        end
        
        if ItemState.GiftRunning then
            for _, name in ipairs(ItemState.SelectedGifts) do
                if hasItem(name) then
                    GiftController:Open(name, 1)
                    ItemState.Used = ItemState.Used + 1
                    break
                end
            end
        end
        
        if ItemState.TreatRunning then
            local petId = nil
            for id in pairs((data.Pets and data.Pets.Owned) or {}) do petId = id; break end
            if petId then
                for _, name in ipairs(ItemState.SelectedTreats) do
                    if hasItem(name) then
                        ItemService:UseOnPet({ Item = name, PetId = petId, Amount = 1 })
                        ItemState.Used = ItemState.Used + 1
                        break
                    end
                end
            end
        end
        
        if ItemState.TotemRunning then
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _, name in ipairs(ItemState.SelectedTotems) do
                    if hasItem(name) then
                        ItemService:PlaceTotem({ TotemName = name, Position = hrp.Position + hrp.CFrame.LookVector * 5 })
                        ItemState.Used = ItemState.Used + 1
                        break
                    end
                end
            end
        end
    end
end)

local CraftState = {
    GoldenRunning = false,
    PetsToUse = 6,
    SelectedMutation = "None",
    isRequestPending = false,
    lastCraftResultTime = 0,
    GoldenCrafted = 0,
    Status = "Idle",
}

MachineService.MachineCraftResult:Connect(function(result)
    CraftState.isRequestPending = false
    CraftState.lastCraftResultTime = os.clock()

    if type(result) == "table" and result.Success == true then
        CraftState.GoldenCrafted = CraftState.GoldenCrafted + 1
        CraftState.Status = "Golden craft successful"
    elseif type(result) == "table" and result.Error then
        CraftState.Status = "Golden craft failed: " .. tostring(result.Error)
    else
        CraftState.Status = "Golden craft result received"
    end
end)

local function getGoldenMachineTarget()
    local attributeFallback
    for _, v in CollectionService:GetTagged("InteractionPoint") do
        if v.Name == "Golden" then
            return v
        end
        if v:GetAttribute("UpgradeName") == "Golden" then
            attributeFallback = attributeFallback or v
        end
    end
    return attributeFallback
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
        if CraftState.isRequestPending or not CraftState.GoldenRunning then continue end
        local data = getData()
        if not data then continue end
        if os.clock() - CraftState.lastCraftResultTime < 1 then continue end
        local groups = {}
        local owned = (data.Pets and data.Pets.Owned) or {}
        for id, pet in pairs(owned) do
            if pet.Tier == "Normal" and not pet.Locked and not pet.Frozen and not pet.Enchant and not pet.Signature then
                if petMatchesMutation(pet, CraftState.SelectedMutation) then
                    if not groups[pet.Name] then groups[pet.Name] = {} end
                    table.insert(groups[pet.Name], id)
                end
            end
        end
        for _, ids in pairs(groups) do
            if #ids >= CraftState.PetsToUse then
                local selected = {}
                for i = 1, CraftState.PetsToUse do table.insert(selected, ids[i]) end

                local machine = getGoldenMachineTarget()
                if not machine then
                    CraftState.Status = "Golden Machine interaction point not found"
                    task.wait(0.75)
                    break
                end

                -- The game's own InteractionPoint detector tests the player's
                -- position against the tagged part/model bounding box. A generic
                -- 10-15 stud distance check is not sufficient for this machine.
                if not TeleportIntoInteractionPoint(machine) then
                    CraftState.Status = "Could not enter Golden Machine range"
                    task.wait(0.75)
                    break
                end

                task.wait(0.2)
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp or not isInsideObjectBounds(machine, hrp.Position) then
                    CraftState.Status = "Outside Golden Machine interaction area"
                    task.wait(0.75)
                    break
                end

                CraftState.isRequestPending = true
                CraftState.Status = "Crafting Golden pets..."
                MachineService.MachineCraftRequested:Fire({ Machine = "Golden", PetIds = selected })
                task.delay(5, function()
                    if CraftState.isRequestPending then
                        CraftState.isRequestPending = false
                        CraftState.Status = "Golden craft timed out; retrying"
                    end
                end)
                break
            end
        end
    end
end)

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
    if not data then return nil, 0 end
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

task.spawn(function()
    while true do
        task.wait(HoneyPotState.Delay)
        if not (HoneyPotState.ClaimRunning or HoneyPotState.CraftRunning) or HoneyPotState.Mutex then continue end
        HoneyPotState.Mutex = true
        
        if HoneyPotState.AutoTeleport and not honeyPotNear() then
            local pos = honeyPotMachinePos()
            if pos then
                HoneyPotState.Status = "Teleporting to machine..."
                TeleportTo(pos)
                HoneyPotState.Mutex = false
                continue
            end
        end
        if not honeyPotNear() then
            HoneyPotState.Status = "Not at machine"
            HoneyPotState.Mutex = false
            continue
        end
        
        if HoneyPotState.ClaimRunning then
            local readySlot = honeyPotFindReady()
            if readySlot then
                local resp = HoneyPotService:Claim(readySlot)
                if type(resp) == "table" and resp.Success then
                    HoneyPotState.Claimed = HoneyPotState.Claimed + 1
                    HoneyPotState.Status = "Claimed slot " .. readySlot .. " | total " .. HoneyPotState.Claimed
                else
                    HoneyPotState.Failed = HoneyPotState.Failed + 1
                end
                HoneyPotState.Mutex = false
                continue
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
                        local resp = HoneyPotService:Craft(recipe.Key, amount)
                        if type(resp) == "table" and resp.Success then
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
        HoneyPotState.Mutex = false
    end
end)

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
    for _, model in CollectionService:GetTagged(TapChestConfig.Tag) do
        if model:IsA("Model") and model.Parent and isChestReady(model) then
            table.insert(list, model)
        end
    end
    return list
end

local function processTapChest(model, timeout)
    local pos = getChestPos(model)
    if not pos then return false, "no position" end
    if not TeleportTo(pos) then return false, "unreachable" end
    TapChestController:Interact(model)
    local deadline = os.clock() + (timeout or 20)
    while os.clock() < deadline do
        if not isChestReady(model) then return true, "opened" end
        task.wait(0.5)
    end
    local chestId = getChestId(model)
    if chestId then
        local holder = {}
        task.spawn(function()
            local res = TapChestService:Claim(chestId)
            holder.Result = res
            holder.Done = true
        end)
        local deadline2 = os.clock() + 6
        while not holder.Done and os.clock() < deadline2 do task.wait() end
        local result = holder.Result
        if type(result) == "table" and result.Success then return true, result.Coins or 0 end
    end
    return false, "failed"
end

task.spawn(function()
    while true do
        task.wait(0.5)
        if not (TapChestState.CollectRunning or TapChestState.OpenRunning) or TapChestState.Mutex then continue end
        TapChestState.Mutex = true
        local ready = getReadyChests()
        if #ready == 0 then
            TapChestState.Status = "No ready chests"
            TapChestState.Mutex = false
            continue
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
        TapChestState.Mutex = false
    end
end)

local ClickerState = { Running = false, Delay = 0.5, Current = nil }

local function getClickerChest()
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and obj.Name == "ClickerChest" then return obj end
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
                if hrp and (hrp.Position - pos).Magnitude > 10 then TeleportTo(pos) end
            end
        end
    end
end)

local DigState = {
    Running = false, Session = nil, LastHitTime = 0,
    TotalHits = 0, TotalGames = 0, LastReward = nil, Status = "Idle",
}

local MinHitInterval = tonumber(DigConfig.MinHitInterval) or 0.2

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
    local site = DigWorld.GetSite()
    if site then
        local zone = site:FindFirstChild("DigZone")
        if zone then return zone end
    end
    local islands = Workspace:FindFirstChild("Ts2Islands")
    if not islands then return nil end
    local autumn = islands:FindFirstChild("Autumn")
    if autumn then
        local site2 = autumn:FindFirstChild("Digsite")
        if site2 then
            local zone = site2:FindFirstChild("DigZone")
            if zone then return zone end
        end
    end
    for _, island in ipairs(islands:GetChildren()) do
        local site3 = island:FindFirstChild("Digsite")
        if site3 then
            local zone = site3:FindFirstChild("DigZone")
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
    local res = DigWorld.Contains(zone, char)
    if res then return true end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local pos = getPartPos(zone)
    if hrp and pos then return (hrp.Position - pos).Magnitude <= 30 end
    return false
end

local function cancelDigSession()
    if DigState.Session and DigState.Session.Id then
        local sid = DigState.Session.Id
        task.spawn(function() DigComm:Cancel(sid) end)
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
    local resp = DigComm:Begin()
    if not resp then
        DigState.Status = "Begin failed"
        task.wait(0.5)
        return true
    end
    if resp.Error then
        if resp.Error == "Cooldown" then
            local mins = math.ceil((resp.Remaining or 0) / 60)
            DigState.Status = string.format("Cooldown %dm", mins)
            Notify({title = "Auto Dig", content = "Out of digs. Wait " .. mins .. " min.", duration = 4})
            DigState.Running = false
            return false
        end
        DigState.Status = "Begin error: " .. tostring(resp.Error)
        task.wait(1)
        return true
    end
    if not resp.Id then
        DigState.Status = "Session missing Id"
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
            if remaining > 0.05 then task.wait(math.min(remaining - 0.02, 0.1))
            else task.wait() end
        end
        if not DigState.Running then return false end
        local hitTime = Workspace:GetServerTimeNow()
        local hResp = DigComm:Hit(session.Id, session.Round.Sequence, hitTime)
        if not hResp then
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
                Notify({title = "Dig Complete", content = tostring(hResp.Reward) .. " x" .. tostring(hResp.Amount or 1), duration = 3})
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
        processOneDigGame()
    end
    cancelDigSession()
end)

local ColosseumState = {
    Active = false, Opponents = {},
    AttackInterval = 0.15, CriticalInterval = 7,
    Waves = 0, Status = "Idle",
}

local ColosseumToggle

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
            if ColosseumToggle then
                ColosseumToggle:Set(false)
            end
            task.spawn(function()
                ColosseumNetwork:InvokeServer("ReturnFromArena")
            end)
        end
    end,
})

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
        local resp = ColosseumNetwork:InvokeServer("AttackOpponent", targetId)
        colosseumApplyResponse(targetId, resp)
    end
end)

task.spawn(function()
    while true do
        task.wait(ColosseumState.CriticalInterval)
        if not ColosseumState.Active then continue end
        local targetId = colosseumPickTarget()
        if not targetId then continue end
        local resp = ColosseumNetwork:InvokeServer("CriticalAttackOpponent", targetId)
        colosseumApplyResponse(targetId, resp)
    end
end)

local function getColosseumArena()
    local gameFolder = Workspace:FindFirstChild("Game")
    if gameFolder then
        local arena = gameFolder:FindFirstChild("WaveDefense")
        if arena then return arena end
    end
    return Workspace:FindFirstChild("WaveDefense")
end

local function getColosseumArenaPos()
    local arena = getColosseumArena()
    if not arena then return nil end
    local door = arena:FindFirstChild("Door")
    if door then
        local endCF = door:GetAttribute("EndCFrame")
        if typeof(endCF) == "CFrame" then return endCF.Position end
    end
    local ok, cf = pcall(function() return arena:GetBoundingBox() end)
    if ok and cf then return cf.Position end
    return getPartPos(arena)
end

local function colosseumStart()
    if ColosseumState.Active then return true end
    ColosseumState.Status = "Teleporting to arena..."
    ColosseumState.Opponents = {}
    ColosseumState.Waves = 0
    local arenaPos = getColosseumArenaPos()
    if arenaPos then
        TeleportTo(arenaPos)
        task.wait(0.6)
    end
    if ColosseumAdapter and type(ColosseumAdapter.SetActive) == "function" then
        ColosseumAdapter:SetActive(true)
        task.wait(0.25)
    end
    ColosseumState.Status = "Starting wave defense..."
    local resp = ColosseumNetwork:InvokeServer("StartWaveDefense")
    if not resp then
        ColosseumState.Status = "No response"
        if ColosseumAdapter and type(ColosseumAdapter.SetActive) == "function" then
            ColosseumAdapter:SetActive(false)
        end
        return false, "No response"
    end
    if type(resp) == "table" and (resp.OnCooldown or resp.Error) then
        local errMsg = tostring(resp.Error or "On cooldown")
        if resp.Remaining then errMsg = errMsg .. " (" .. math.ceil(resp.Remaining / 60) .. "m)" end
        ColosseumState.Status = errMsg
        if ColosseumAdapter and type(ColosseumAdapter.SetActive) == "function" then
            ColosseumAdapter:SetActive(false)
        end
        return false, errMsg
    end
    ColosseumState.Active = true
    ColosseumState.Status = "Playing"
    if type(resp) == "table" and type(resp.PendingSpawns) == "table" then
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
    if ColosseumAdapter and type(ColosseumAdapter.SetActive) == "function" then
        ColosseumAdapter:SetActive(false)
    end
    task.spawn(function()
        ColosseumNetwork:InvokeServer("EndWaveDefense")
        task.wait(0.5)
        ColosseumNetwork:InvokeServer("ReturnFromArena")
        ColosseumState.Status = "Stopped"
    end)
end

local FarmTab = Window:CreateTab({ name = "Farm" })
local PetsTab = Window:CreateTab({ name = "Pets" })
local ChestsTab = Window:CreateTab({ name = "Chests" })
local GamesTab = Window:CreateTab({ name = "Games" })
local CraftTab = Window:CreateTab({ name = "Crafting" })

FarmTab:CreateSection({ name = "Auto Tap" })
FarmTab:CreateSlider({
    name = "Tap Speed",
    range = { 0, 0.5 },
    increment = 0.01,
    value = 0.01,
    callback = function(v) TapState.Delay = v end,
})
FarmTab:CreateToggle({
    name = "Auto Tap",
    value = false,
    flag = "autoTap",
    callback = function(v) TapState.Running = v end,
})

FarmTab:CreateSection({ name = "Auto Rebirth" })
local RebirthDropdown
RebirthDropdown = FarmTab:CreateDropdown({
    name = "Rebirth Amount",
    options = RebirthOptions,
    value = RebirthOptions[1],
    callback = function(v) RebirthState.SelectedIndex = RebirthIndexByName[v[1]] or 1 end,
})
FarmTab:CreateButton({
    name = "Refresh Rebirth List",
    callback = function()
        rebuildRebirthOptions()
        if RebirthDropdown then
            RebirthDropdown:Refresh(RebirthOptions)
            local label = tostring(RebirthOptions[RebirthState.SelectedIndex] or RebirthOptions[1])
            if RebirthIndexByName[label] then
                RebirthDropdown:Set(label)
            else
                RebirthState.SelectedIndex = 1
                RebirthDropdown:Set(RebirthOptions[1])
            end
        end
    end,
})
local RebirthSelectedToggle, RebirthHighestToggle
RebirthSelectedToggle = FarmTab:CreateToggle({
    name = "Buy Selected Rebirth",
    value = false,
    flag = "buySelectedRebirth",
    callback = function(v)
        RebirthState.Selected = v
        if v and RebirthState.Highest then
            RebirthState.Highest = false
            RebirthHighestToggle:Set(false)
        end
    end,
})
RebirthHighestToggle = FarmTab:CreateToggle({
    name = "Buy Highest Rebirth",
    value = false,
    flag = "buyHighestRebirth",
    callback = function(v)
        RebirthState.Highest = v
        if v and RebirthState.Selected then
            RebirthState.Selected = false
            RebirthSelectedToggle:Set(false)
        end
    end,
})
FarmTab:CreateSlider({
    name = "Rebirth Delay",
    range = { 0.5, 5 },
    increment = 0.1,
    value = 1,
    callback = function(v) RebirthState.Delay = v end,
})

FarmTab:CreateSection({ name = "Auto Double Jump" })
FarmTab:CreateToggle({
    name = "Auto Buy Double Jumps",
    value = false,
    flag = "autoJump",
    callback = function(v) JumpState.Running = v end,
})
FarmTab:CreateButton({
    name = "Buy Once",
    callback = function()
        if attemptBuyJump() then
            Notify({ title = "Double Jump", content = "Purchase requested", duration = 2 })
        else
            Notify({ title = "Double Jump", content = "Not enough funds or blocked", duration = 2 })
        end
    end,
})
FarmTab:CreateSlider({
    name = "Jump Delay",
    range = { 0.5, 5 },
    increment = 0.1,
    value = 1,
    callback = function(v) JumpState.Delay = v end,
})

FarmTab:CreateSection({ name = "Auto Skill Tree" })
FarmTab:CreateToggle({
    name = "Auto Unlock Skills",
    value = false,
    flag = "autoSkillTree",
    callback = function(v) SkillState.Running = v end,
})
FarmTab:CreateSlider({
    name = "Skill Delay",
    range = { 0.5, 5 },
    increment = 0.1,
    value = 1,
    callback = function(v) SkillState.Delay = v end,
})

FarmTab:CreateSection({ name = "Auto Quests" })
FarmTab:CreateToggle({
    name = "Auto Claim Quests",
    value = false,
    flag = "autoQuest",
    callback = function(v) QuestState.Running = v end,
})
FarmTab:CreateSlider({
    name = "Claim Delay",
    range = { 0.5, 5 },
    increment = 0.1,
    value = 1,
    callback = function(v) QuestState.Delay = v end,
})

local FarmStatus = FarmTab:CreateText({ name = "Status", text = "Idle" })
task.spawn(function()
    while true do
        task.wait(0.5)
        FarmStatus:Set(string.format(
            "Tap: %d | Rebirth: %d | Jump: %d | Skills: %d | Quests: %d",
            TapState.Count, RebirthState.Count, JumpState.Count, SkillState.Count, QuestState.Count
        ))
    end
end)

PetsTab:CreateSection({ name = "Auto Hatch" })
local EggOptions = {}
for eggName in pairs(EggConfig) do table.insert(EggOptions, eggName) end
table.sort(EggOptions)
HatchState.SelectedEgg = EggOptions[1]

PetsTab:CreateDropdown({
    name = "Select Egg",
    options = EggOptions,
    value = EggOptions[1],
    callback = function(v) HatchState.SelectedEgg = v[1] end,
})
PetsTab:CreateDropdown({
    name = "Hatch Amount",
    options = { "1", "3", "8" },
    value = "1",
    callback = function(v) HatchState.SelectedAmount = tonumber(v[1]) or 1 end,
})
PetsTab:CreateToggle({
    name = "Auto Hatch",
    value = false,
    flag = "autoHatch",
    callback = function(v) HatchState.HatchRunning = v end,
})
PetsTab:CreateSlider({
    name = "Hatch Delay",
    range = { 0.1, 2 },
    increment = 0.1,
    value = 0.5,
    callback = function(v) HatchState.HatchDelay = v end,
})

local BoostList = {}
for name in pairs(BoostConfig.Definitions) do table.insert(BoostList, name) end
table.sort(BoostList)
local GiftsList = { "New Years Gift", "Valentines Gift", "St. Patrick Gift", "Release Gift" }
local TreatsList = { "RegularTreat", "BagOfTreats", "ExoticShard", "ElectricShard", "SecretFruit", "DragonFruit", "GoldenApple", "RainbowStrawberry", "GoldenTreat" }
local TotemsList = { "TotemOfLuck", "TotemOfRebirths", "TotemOfClicks", "TotemOfSecretLuck", "TotemOfHatchSpeed" }

PetsTab:CreateSection({ name = "Auto Boosts" })
PetsTab:CreateDropdown({
    name = "Select Boosts",
    options = BoostList,
    multiSelect = true,
    value = {},
    callback = function(v) ItemState.SelectedBoosts = v end,
})
PetsTab:CreateToggle({
    name = "Use Boosts",
    value = false,
    flag = "useBoosts",
    callback = function(v) ItemState.BoostRunning = v end,
})

PetsTab:CreateSection({ name = "Auto Gifts" })
PetsTab:CreateDropdown({
    name = "Select Gifts",
    options = GiftsList,
    multiSelect = true,
    value = {},
    callback = function(v) ItemState.SelectedGifts = v end,
})
PetsTab:CreateToggle({
    name = "Open Gifts",
    value = false,
    flag = "openGifts",
    callback = function(v) ItemState.GiftRunning = v end,
})

PetsTab:CreateSection({ name = "Auto Treats" })
PetsTab:CreateDropdown({
    name = "Select Treats",
    options = TreatsList,
    multiSelect = true,
    value = {},
    callback = function(v) ItemState.SelectedTreats = v end,
})
PetsTab:CreateToggle({
    name = "Feed Treats",
    value = false,
    flag = "feedTreats",
    callback = function(v) ItemState.TreatRunning = v end,
})

PetsTab:CreateSection({ name = "Auto Totems" })
PetsTab:CreateDropdown({
    name = "Select Totems",
    options = TotemsList,
    multiSelect = true,
    value = {},
    callback = function(v) ItemState.SelectedTotems = v end,
})
PetsTab:CreateToggle({
    name = "Place Totems",
    value = false,
    flag = "placeTotems",
    callback = function(v) ItemState.TotemRunning = v end,
})

PetsTab:CreateSection({ name = "Item Timing" })
PetsTab:CreateSlider({
    name = "Item Delay",
    range = { 0.5, 5 },
    increment = 0.1,
    value = 1,
    callback = function(v) ItemState.Delay = v end,
})

local PetsStatus = PetsTab:CreateText({ name = "Status", text = "Idle" })
task.spawn(function()
    while true do
        task.wait(0.5)
        PetsStatus:Set(string.format(
            "Hatched: %d | Items used: %d | %s",
            HatchState.Hatched, ItemState.Used, HatchState.Status
        ))
    end
end)

ChestsTab:CreateSection({ name = "Auto Tap Chest" })
local TapChestCollectToggle, TapChestOpenToggle
TapChestCollectToggle = ChestsTab:CreateToggle({
    name = "Auto Collect Tap Chest",
    value = false,
    flag = "autoCollectTapChest",
    callback = function(v)
        TapChestState.CollectRunning = v
        if v and TapChestState.OpenRunning then
            TapChestState.OpenRunning = false
            TapChestOpenToggle:Set(false)
        end
    end,
})
TapChestOpenToggle = ChestsTab:CreateToggle({
    name = "Auto Open Tap Chest",
    value = false,
    flag = "autoOpenTapChest",
    callback = function(v)
        TapChestState.OpenRunning = v
        if v and TapChestState.CollectRunning then
            TapChestState.CollectRunning = false
            TapChestCollectToggle:Set(false)
        end
    end,
})
ChestsTab:CreateSlider({
    name = "Chest Delay",
    range = { 0.1, 3 },
    increment = 0.1,
    value = 0.5,
    callback = function(v) TapChestState.Delay = v end,
})

ChestsTab:CreateSection({ name = "Auto Clicker Chest" })
ChestsTab:CreateToggle({
    name = "Auto Teleport to Clicker Chest",
    value = false,
    flag = "autoClickerChest",
    callback = function(v)
        ClickerState.Running = v
        if v then ClickerState.Current = getClickerChest() end
    end,
})
ChestsTab:CreateSlider({
    name = "Check Delay",
    range = { 0.1, 3 },
    increment = 0.1,
    value = 0.5,
    callback = function(v) ClickerState.Delay = v end,
})

local ChestsStatus = ChestsTab:CreateText({ name = "Status", text = "Idle" })
task.spawn(function()
    while true do
        task.wait(0.5)
        ChestsStatus:Set(string.format(
            "Collected: %d | Opened: %d | Failed: %d | %s",
            TapChestState.Collected, TapChestState.Opened, TapChestState.Failed, TapChestState.Status
        ))
    end
end)

GamesTab:CreateSection({ name = "Auto Dig Perfect" })
GamesTab:CreateToggle({
    name = "Auto Dig Perfect",
    value = false,
    flag = "autoDigPerfect",
    callback = function(v)
        DigState.Running = v
        if not v then cancelDigSession() end
        if v then
            DigState.Status = "Starting..."
            Notify({title = "Auto Dig", content = "Starting", duration = 2})
        end
    end,
})
GamesTab:CreateButton({
    name = "Cancel Current Session",
    callback = function()
        cancelDigSession()
        DigState.Status = "Session cancelled"
    end,
})
GamesTab:CreateButton({
    name = "Reset Dig Stats",
    callback = function()
        DigState.TotalHits = 0
        DigState.TotalGames = 0
        DigState.LastReward = nil
        DigState.Status = "Stats reset"
    end,
})

GamesTab:CreateSection({ name = "Auto Colosseum" })
ColosseumToggle = GamesTab:CreateToggle({
    name = "Auto Colosseum",
    value = false,
    flag = "autoColosseum",
    callback = function(v)
        if v then
            local ok, err = colosseumStart()
            if not ok then
                ColosseumToggle:Set(false)
                Notify({
                    title = "Colosseum",
                    content = "Cannot start: " .. tostring(err or "unknown"),
                    duration = 5,
                })
            end
        else
            colosseumStop()
        end
    end,
})
GamesTab:CreateSlider({
    name = "Attack Interval",
    range = { 0.05, 1 },
    increment = 0.01,
    value = 0.15,
    callback = function(v) ColosseumState.AttackInterval = v end,
})
GamesTab:CreateSlider({
    name = "Critical Interval",
    range = { 3, 15 },
    increment = 0.5,
    value = 7,
    callback = function(v) ColosseumState.CriticalInterval = v end,
})
GamesTab:CreateText({
    name = "Note",
    text = "Opponent models may not appear since auto-start skips the client intro. Combat and rewards work normally.",
})

local GamesStatus = GamesTab:CreateText({ name = "Status", text = "Idle" })
task.spawn(function()
    while true do
        task.wait(0.5)
        GamesStatus:Set(string.format(
            "Dig: %s (%d hits, %d games) | Colosseum: %d waves, %s",
            DigState.Status, DigState.TotalHits, DigState.TotalGames,
            ColosseumState.Waves, ColosseumState.Status
        ))
    end
end)

CraftTab:CreateSection({ name = "Auto Craft Golden Pets" })

local CraftPetsOptions = {}
for i, chance in ipairs(MachineConfig.Golden.Chances) do
    table.insert(CraftPetsOptions, string.format("%d Pets (%d%%)", i, chance))
end
CraftTab:CreateDropdown({
    name = "Pets to Use",
    options = CraftPetsOptions,
    value = CraftPetsOptions[6],
    callback = function(v)
        local n = tonumber(string.match(v[1], "%d+"))
        if n then CraftState.PetsToUse = n end
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
CraftMutationDropdown = CraftTab:CreateDropdown({
    name = "Filter Mutation",
    options = getMutationOptions(),
    value = "None",
    callback = function(v) CraftState.SelectedMutation = v[1] end,
})
CraftTab:CreateButton({
    name = "Refresh Mutations",
    callback = function()
        local opts = getMutationOptions()
        if CraftMutationDropdown then
            CraftMutationDropdown:Refresh(opts)
            if not table.find(opts, CraftState.SelectedMutation) then
                CraftState.SelectedMutation = "None"
                CraftMutationDropdown:Set("None")
            end
        end
    end,
})
CraftTab:CreateToggle({
    name = "Auto Craft Golden Pets",
    value = false,
    flag = "autoCraftGolden",
    callback = function(v) CraftState.GoldenRunning = v end,
})

CraftTab:CreateSection({ name = "Auto Honey Pot" })

local HoneyPotRecipeOptions = { "Auto" }
local HoneyPotRecipeKeyByLabel = {}
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

CraftTab:CreateDropdown({
    name = "Honey Pot Recipe",
    options = HoneyPotRecipeOptions,
    value = "Auto",
    callback = function(v)
        if v[1] == "Auto" then
            HoneyPotState.SelectedRecipe = "Auto"
        else
            HoneyPotState.SelectedRecipe = HoneyPotRecipeKeyByLabel[v[1]] or "Auto"
        end
    end,
})
CraftTab:CreateToggle({
    name = "Auto Claim",
    value = false,
    flag = "autoClaimHoneyPot",
    callback = function(v) HoneyPotState.ClaimRunning = v end,
})
CraftTab:CreateToggle({
    name = "Auto Craft",
    value = false,
    flag = "autoCraftHoneyPot",
    callback = function(v) HoneyPotState.CraftRunning = v end,
})
CraftTab:CreateToggle({
    name = "Auto Teleport to Machine",
    value = true,
    flag = "autoTeleportHoneyPot",
    callback = function(v) HoneyPotState.AutoTeleport = v end,
})
CraftTab:CreateSlider({
    name = "Craft Amount",
    range = { 1, 50 },
    increment = 1,
    value = 1,
    callback = function(v) HoneyPotState.CraftAmount = v end,
})
CraftTab:CreateSlider({
    name = "Action Delay",
    range = { 0.3, 3 },
    increment = 0.1,
    value = 0.5,
    callback = function(v) HoneyPotState.Delay = v end,
})

local CraftStatus = CraftTab:CreateText({ name = "Status", text = "Idle" })
task.spawn(function()
    while true do
        task.wait(0.5)
        CraftStatus:Set(string.format(
            "Golden: %d (%s) | Honey Pot: %d claimed, %d crafted | %s",
            CraftState.GoldenCrafted, CraftState.Status, HoneyPotState.Claimed, HoneyPotState.Crafted, HoneyPotState.Status
        ))
    end
end)

Notify({
    title = "Tap Simulator REBORN",
    content = "Loaded. Toggle anything to start.",
    duration = 5,
})
