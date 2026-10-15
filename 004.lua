local WINDUI_VERSION_URL = "https://github.com/Footagesus/WindUI/releases/download/1.6.66/main.lua"
local httpOk, windUISource = pcall(function()
    return game:HttpGet(WINDUI_VERSION_URL)
end)
if not httpOk or type(windUISource) ~= "string" then
    warn("[Search For The Needle] Could not download WindUI 1.6.66: " .. tostring(windUISource))
    return
end

local compileOk, WindUILoader, compileError = pcall(loadstring, windUISource)
if not compileOk or type(WindUILoader) ~= "function" then
    warn("[Search For The Needle] Could not compile WindUI 1.6.66: " .. tostring(compileError or WindUILoader))
    return
end

local initOk, WindUI = pcall(WindUILoader)
if not initOk or type(WindUI) ~= "table" then
    warn("[Search For The Needle] Could not initialize WindUI 1.6.66: " .. tostring(WindUI))
    return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer

local Unloaded = false
local MapReady = false
local State = {}

local ThemeName = "Dark"
pcall(function()
    WindUI:AddTheme({
        Name = "Needle",
        Accent = "#282828",
        Dialog = "#161616",
        Outline = "#5865F2",
        Text = "#FFFFFF",
        Placeholder = "#8A8A8A",
        Background = "#0D0D0D",
        Button = "#3A3A3A",
        Icon = "#C9CCFF",
    })
    ThemeName = "Needle"
end)

local Window = WindUI:CreateWindow({
    Title = "Search For The Needle",
    Icon = "search",
    Folder = "SearchForTheNeedle",
    Size = UDim2.fromOffset(640, 480),
    Theme = ThemeName,
    Transparent = false,
    Resizable = true,
    SideBarWidth = 200,
    HideSearchBar = true,
})

pcall(function() Window:SetToggleKey(Enum.KeyCode.RightShift) end)
pcall(function()
    Window:EditOpenButton({
        Title = "Search For The Needle",
        Icon = "search",
        CornerRadius = UDim.new(0, 16),
        StrokeThickness = 2,
        Color = ColorSequence.new(Color3.fromHex("#5865F2"), Color3.fromHex("#8EA1FF")),
        OnlyMobile = false,
        Enabled = true,
        Draggable = true,
    })
end)

local function Notify(title, content, duration, icon)
    pcall(function()
        WindUI:Notify({ Title = title, Content = content, Duration = duration or 3, Icon = icon })
    end)
end

local LobbyUpgradeKeys = {
    UpgBagSize = true,
    UpgExtraTake = true,
    UpgGemValue = true,
    UpgHayValue = true,
}

local function NotifyToggle(title, enabled, key)
    if enabled and not MapReady and not LobbyUpgradeKeys[key] then
        Notify(
            "Map Required",
            title .. " is ON, but the map is still loading. It will work once the map is ready.",
            4,
            "map"
        )
        return
    end

    Notify(
        enabled and "Toggle Enabled" or "Toggle Disabled",
        title .. (enabled and " is now ON." or " is now OFF."),
        2.5,
        enabled and "check" or "x"
    )
end

local function Header(tab, title)
    pcall(function() tab:Section({ Title = title }) end)
end

local ToggleDescriptions = {
    AutoPickHay = "Automatically picks nearby hay. Returns to the hay pile when no hay is close.",
    AutoCollectDroppedHay = "Automatically collects hay dropped around the map.",
    AutoCollectGems = "Automatically collects nearby gems.",
    AutoVacuumCollect = "Uses the Vacuum tool to collect hay. Requires the Vacuum to be owned.",
    AutoSellHay = "Automatically sells hay when the selected amount is reached.",
    SellOnlyIfFull = "Waits until your carrying bag is full before selling hay.",
    AutoUseTNT = "Automatically lights and throws TNT when available. Requires TNT.",
    AutoUsePitchfork = "Automatically digs nearby hay with the Pitchfork. Requires the Pitchfork.",
    AutoDeployDrone = "Deploys your Drone when it is owned and not already deployed.",
    AutoVacuum = "Keeps the Vacuum running to collect hay. Requires the Vacuum.",
    AutoFindNeedle = "Clears hay around the pile to help reveal the hidden needle.",
    AutoHandInNeedle = "Moves near the Farmer and attempts to hand in the needle.",
    AutoBuyTools = "Automatically buys the items selected above when you can afford them.",
    UpgBagSize = "Buys permanent bag-size upgrades using gems when affordable.",
    UpgExtraTake = "Buys permanent hand-grab amount upgrades using gems.",
    UpgGemValue = "Buys permanent upgrades that increase gem value.",
    UpgHayValue = "Buys permanent upgrades that increase hay value.",
    UpgHandSpeed = "Automatically upgrades hand speed with cash.",
    UpgHandGrab = "Automatically upgrades the amount of hay grabbed by hand.",
    UpgHandHold = "Automatically upgrades how much hay your hand can hold.",
    UpgTntLuck = "Automatically upgrades TNT lucky-blast chance.",
    UpgTntCooldown = "Automatically reduces TNT cooldown.",
    UpgTntPower = "Automatically upgrades TNT power.",
    UpgPitchCooldown = "Automatically reduces Pitchfork cooldown.",
    UpgPitchHold = "Automatically upgrades Pitchfork hold capacity.",
    UpgPitchSweep = "Automatically upgrades the Pitchfork sweep level.",
    UpgDroneSpeed = "Automatically upgrades Drone speed.",
    UpgDroneGrab = "Automatically upgrades the amount the Drone can grab.",
    UpgDroneCapacity = "Automatically upgrades Drone capacity.",
    UpgVacPower = "Automatically upgrades Vacuum power.",
    UpgVacCooling = "Automatically upgrades Vacuum cooling.",
    UpgVacRuntime = "Automatically upgrades Vacuum runtime.",
    UpgCapacity = "Automatically upgrades carrying capacity with cash.",
}

local SliderDescriptions = {
    CollectInterval = "Time between resource-collection checks. Lower values check more often.",
    SellThreshold = "Sell when the amount of carried hay reaches this number, unless full-bag mode is enabled.",
    ToolInterval = "Time between automatic tool-use checks.",
    NeedleInterval = "Time between needle-search and hand-in checks.",
    BuyInterval = "Time between automatic shop purchase checks.",
    PermInterval = "Time between permanent gem-upgrade checks.",
}

local function AddToggle(tab, key, title, default, desc)
    State[key] = default and true or false
    return tab:Toggle({
        Title = title,
        Desc = desc or ToggleDescriptions[key] or "Runs this feature when the required map is loaded.",
        Value = State[key],
        Callback = function(v)
            State[key] = v == true
            NotifyToggle(title, State[key], key)
        end,
    })
end

local function AddSlider(tab, key, title, min, max, default, step, desc)
    State[key] = default
    return tab:Slider({
        Title = title,
        Desc = desc or SliderDescriptions[key] or "Adjusts how often this feature checks or runs.",
        Step = step or 1,
        Value = { Min = min, Max = max, Default = default },
        Callback = function(v) State[key] = tonumber(v) or default end,
    })
end

local NeedleHaystack = nil
local GameConfig = nil
local UpgradeConfig = nil
local PlayerDataClient = nil
local ShopItemsConfig = nil
local ShopNetworker = nil
local ShopRemoteFunction = nil
local BuyUpgrade = nil
local BuyShopItem = nil
local PickHay = nil
local PickDroppedHay = nil
local SellHay = nil
local CollectGem = nil
local DeployDrone = nil
local PitchforkDig = nil
local TntAction = nil
local VacuumAction = nil
local NeedleHandIn = nil
local BarnShop = nil
local DroppedHayFolder = nil
local GemsClientFolder = nil

local function refreshGameReferences()
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    local configs = shared and shared:FindFirstChild("Configs")
    local upgradeModule = configs and configs:FindFirstChild("UpgradeConfig")
    if upgradeModule and type(UpgradeConfig) ~= "table" then
        local ok, result = pcall(require, upgradeModule)
        if ok and type(result) == "table" then UpgradeConfig = result end
    end

    NeedleHaystack = ReplicatedStorage:FindFirstChild("NeedleHaystack")
    if not NeedleHaystack then
        BuyUpgrade = ReplicatedStorage:FindFirstChild("BuyUpgrade")
        return false
    end

    local configModule = NeedleHaystack:FindFirstChild("Config")
    if configModule and type(GameConfig) ~= "table" then
        local ok, result = pcall(require, configModule)
        if ok and type(result) == "table" then GameConfig = result end
    end

    BuyUpgrade = NeedleHaystack:FindFirstChild("BuyUpgrade")
    BuyShopItem = NeedleHaystack:FindFirstChild("BuyShopItem")
    PickHay = NeedleHaystack:FindFirstChild("PickHay")
    PickDroppedHay = NeedleHaystack:FindFirstChild("PickDroppedHay")
    SellHay = NeedleHaystack:FindFirstChild("SellHay")
    CollectGem = NeedleHaystack:FindFirstChild("CollectGem")
    DeployDrone = NeedleHaystack:FindFirstChild("DeployDrone")
    PitchforkDig = NeedleHaystack:FindFirstChild("PitchforkDig")
    TntAction = NeedleHaystack:FindFirstChild("TntAction")
    VacuumAction = NeedleHaystack:FindFirstChild("VacuumAction")
    NeedleHandIn = NeedleHaystack:FindFirstChild("NeedleHandIn")

    BarnShop = Workspace:FindFirstChild("BarnShop")
    DroppedHayFolder = Workspace:FindFirstChild("DroppedHay")
    GemsClientFolder = Workspace:FindFirstChild("GemsClient")

    return type(GameConfig) == "table"
        and type(UpgradeConfig) == "table"
        and BarnShop ~= nil
        and BuyUpgrade ~= nil
        and BuyShopItem ~= nil
        and PickHay ~= nil
        and PickDroppedHay ~= nil
        and SellHay ~= nil
        and CollectGem ~= nil
        and DeployDrone ~= nil
        and PitchforkDig ~= nil
        and TntAction ~= nil
        and VacuumAction ~= nil
        and NeedleHandIn ~= nil
end

local PermanentNoticeState = {}

local function NotifyPermanentOnce(key, title, content, duration, icon)
    local now = os.clock()
    local previous = PermanentNoticeState[key]
    if previous and previous.content == content and now - previous.time < 8 then
        return
    end
    PermanentNoticeState[key] = { time = now, content = content }
    Notify(title, content, duration or 4, icon or "info")
end

local function refreshPermanentUpgradeReferences()
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    local configs = shared and shared:FindFirstChild("Configs")
    local upgradeModule = configs and configs:FindFirstChild("UpgradeConfig")
    if upgradeModule and type(UpgradeConfig) ~= "table" then
        local ok, result = pcall(require, upgradeModule)
        if ok and type(result) == "table" then
            UpgradeConfig = result
        end
    end

    local shopItemsModule = configs and configs:FindFirstChild("ShopItems")
    if shopItemsModule and type(ShopItemsConfig) ~= "table" then
        local ok, result = pcall(require, shopItemsModule)
        if ok and type(result) == "table" then
            ShopItemsConfig = result
        end
    end

    local services = shared and shared:FindFirstChild("Services")
    local dataModule = services and services:FindFirstChild("Data")
    if dataModule then
        local ok, result = pcall(require, dataModule)
        if ok and type(result) == "table" and type(result.client) == "table" then
            PlayerDataClient = result.client
        end
    end

    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local shopGui = playerGui and playerGui:FindFirstChild("ShopUI")
    local shopMain = shopGui and shopGui:FindFirstChild("Main")
    local shopClientScript = shopMain and shopMain:FindFirstChild("ShopUIClient")
    if shopClientScript and shopClientScript:IsA("ModuleScript") then
        local ok, client = pcall(require, shopClientScript)
        if ok and type(client) == "table" then
            local networker = client.networker
            if type(networker) == "table" and type(networker.fetch) == "function" then
                ShopNetworker = networker
            end
        end
    end

    local packages = ReplicatedStorage:FindFirstChild("Packages")
    local networkerFolder = packages and packages:FindFirstChild("Networker")
    local remotes = networkerFolder and networkerFolder:FindFirstChild("_remotes")
    local shopRemoteFolder = remotes and remotes:FindFirstChild("ShopUI")
    local remoteFunction = shopRemoteFolder and shopRemoteFolder:FindFirstChild("RemoteFunction")
    if remoteFunction and remoteFunction:IsA("RemoteFunction") then
        ShopRemoteFunction = remoteFunction
    end

    return type(UpgradeConfig) == "table"
        and type(PlayerDataClient) == "table"
        and (ShopNetworker ~= nil or ShopRemoteFunction ~= nil)
end

local function readClientDataValue(container, key)
    if container == nil or key == nil then
        return nil
    end

    local ok, value = pcall(function()
        return container[key]
    end)
    if not ok then
        return nil
    end

    if type(value) == "function" then
        local valueOk, result = pcall(value)
        if valueOk then
            return result
        end
        return nil
    end

    if typeof(value) == "Instance" and value:IsA("ValueBase") then
        return value.Value
    end

    return value
end

local function getCash()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    local cash = ls and ls:FindFirstChild("Cash")
    return cash and cash.Value or 0
end

local function getGems()
    local client = PlayerDataClient
    if type(client) == "table" then
        local memberOk, member = pcall(function()
            return client.Gems
        end)
        if memberOk then
            if type(member) == "function" then
                local valueOk, value = pcall(member)
                if not valueOk then
                    valueOk, value = pcall(member, client)
                end
                if valueOk then
                    local amount = tonumber(value)
                    if amount ~= nil then
                        return amount
                    end
                    if typeof(value) == "Instance" and value:IsA("ValueBase") then
                        amount = tonumber(value.Value)
                        if amount ~= nil then
                            return amount
                        end
                    end
                end
            else
                local amount = tonumber(member)
                if amount ~= nil then
                    return amount
                end
                if typeof(member) == "Instance" and member:IsA("ValueBase") then
                    amount = tonumber(member.Value)
                    if amount ~= nil then
                        return amount
                    end
                end
            end
        end
    end

    local attributeAmount = tonumber(LocalPlayer:GetAttribute("Gems"))
    if attributeAmount ~= nil then
        return attributeAmount
    end

    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    local gemsValue = leaderstats and leaderstats:FindFirstChild("Gems")
    if gemsValue and gemsValue:IsA("ValueBase") then
        return tonumber(gemsValue.Value)
    end

    return nil
end

local function getHayHeld()
    local v = LocalPlayer:GetAttribute("HayHeld")
    if v ~= nil then return tonumber(v) or 0 end
    return 0
end

local function getHayCapacity()
    return tonumber(LocalPlayer:GetAttribute("HayCapacity")) or 25
end

local function owns(attr)
    return LocalPlayer:GetAttribute(attr) == true
end

local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function findClosestHay()
    local hrp = getHRP()
    if not hrp then return nil end
    local best, bestDist = nil, math.huge

    for _, inst in ipairs(Workspace:GetDescendants()) do
        if inst:GetAttribute("HayId") and inst:IsA("BasePart") and inst.Parent then
            local d = (inst.Position - hrp.Position).Magnitude
            if d < bestDist and d < 30 then
                bestDist = d
                best = inst
            end
        end
    end
    return best
end

local function getGrabCandidates(centerPart)

    local radius = tonumber(LocalPlayer:GetAttribute("HayGrabRadius")) or 0
    if radius <= 0 then return {} end
    local out = {}
    if not centerPart then return out end
    local cp = centerPart.Position
    for _, inst in ipairs(Workspace:GetDescendants()) do
        if inst ~= centerPart and inst:GetAttribute("HayId") and inst:IsA("BasePart") then
            if (inst.Position - cp).Magnitude <= radius + 1 then
                table.insert(out, inst:GetAttribute("HayId"))
                if #out >= 6 then break end
            end
        end
    end
    return out
end

local function findClosestDropped()
    if not DroppedHayFolder then DroppedHayFolder = Workspace:FindFirstChild("DroppedHay") end
    if not DroppedHayFolder then return nil end
    local hrp = getHRP()
    if not hrp then return nil end
    local best, bestDist = nil, 28
    for _, m in ipairs(DroppedHayFolder:GetChildren()) do
        local part = m:IsA("BasePart") and m or m:FindFirstChildWhichIsA("BasePart")
        if part then
            local d = (part.Position - hrp.Position).Magnitude
            if d < bestDist then
                bestDist = d
                best = part.Parent:IsA("BasePart") and part.Parent or m
            end
        end
    end
    return best
end

local function findClosestGem()
    if not GemsClientFolder then GemsClientFolder = Workspace:FindFirstChild("GemsClient") end
    local root = GemsClientFolder or Workspace
    local hrp = getHRP()
    if not hrp then return nil end
    local best, bestDist, bestId = nil, 35, nil
    for _, mdl in ipairs(root:GetDescendants()) do
        if mdl:IsA("BasePart") and mdl:GetAttribute("GemId") then
            local d = (mdl.Position - hrp.Position).Magnitude
            if d < bestDist then
                bestDist = d
                best = mdl
                bestId = mdl:GetAttribute("GemId")
            end
        end
    end
    if best and bestId then return best, bestId end

    for _, mdl in ipairs(Workspace:GetDescendants()) do
        if mdl:GetAttribute("GemId") and mdl:IsA("BasePart") then
            local d = (mdl.Position - hrp.Position).Magnitude
            if d < bestDist then
                bestDist = d
                best = mdl
                bestId = mdl:GetAttribute("GemId")
            end
        end
    end
    if best then return best, bestId end
    return nil, nil
end

local function isBagFull()
    return getHayHeld() >= getHayCapacity()
end

local function getNearestSellPart()
    local camPos = Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame.Position
        or (LocalPlayer.Character and LocalPlayer.Character:GetPivot().Position or Vector3.new(0, 0, 0))
    local best, bestDist = nil, math.huge
    for _, part in ipairs(CollectionService:GetTagged(GameConfig.SELL_PART_NAME)) do
        if part:IsA("BasePart") and part:IsDescendantOf(Workspace) then
            local d = (part.Position - camPos).Magnitude

            local hrp = getHRP()
            if hrp then
                local cd = (part.Position - hrp.Position).Magnitude
                d = math.min(d, cd)
            end
            if d < bestDist then
                bestDist = d
                best = part
            end
        end
    end
    if not best then

        local sellModel = Workspace:FindFirstChild("SellModel")
        if sellModel then
            for _, inst in ipairs(sellModel:GetDescendants()) do
                if inst.Name == "SellPart" and inst:IsA("BasePart") then
                    return inst
                end
            end
        end
    end
    return best
end

local function trySell()
    local hrp = getHRP()
    local sellPart = getNearestSellPart()
    if hrp and sellPart then
        local dist = (hrp.Position - sellPart.Position).Magnitude
        if dist > 14 then

            hrp.CFrame = sellPart.CFrame + Vector3.new(0, 3, 2)

            if Workspace.CurrentCamera then
                Workspace.CurrentCamera.CFrame = CFrame.lookAt(Workspace.CurrentCamera.CFrame.Position, sellPart.Position)
            end
            task.wait(0.25)
        else

            if Workspace.CurrentCamera then
                pcall(function()
                    Workspace.CurrentCamera.CFrame = CFrame.lookAt(Workspace.CurrentCamera.CFrame.Position, sellPart.Position)
                end)
            end
            task.wait(0.05)
        end
    end
    local ok, err = pcall(function() SellHay:FireServer() end)
    if not ok then
        Notify("Sell Failed", tostring(err), 2, "x")
    end

    task.spawn(function()
        local before = getHayHeld()
        task.wait(0.6)
        if before > 0 and getHayHeld() == before and hrp and sellPart then
            hrp.CFrame = sellPart.CFrame + Vector3.new(0, 4, 0)
            task.wait(0.2)
            pcall(function() SellHay:FireServer() end)
        end
    end)

    task.spawn(function()
        task.wait(1.0)
        local needReturn = false
        if MapReady and State.AutoPickHay then needReturn = true end
        if MapReady and State.AutoCollectDroppedHay then needReturn = true end
        if MapReady and State.AutoCollectGems then needReturn = true end
        if MapReady and State.AutoVacuumCollect then needReturn = true end
        if MapReady and State.AutoVacuum then needReturn = true end
        if MapReady and State.AutoUsePitchfork then needReturn = true end
        if MapReady and State.AutoFindNeedle then needReturn = true end
        if needReturn and getHayHeld() == 0 then
            local pile = GameConfig.PILE_CENTER
            local hrp2 = getHRP()
            if hrp2 and (hrp2.Position - pile).Magnitude > 22 then
                hrp2.CFrame = CFrame.new(pile + Vector3.new(math.random(-2, 2), 5, math.random(-2, 2)))
                if Workspace.CurrentCamera then
                    Workspace.CurrentCamera.CFrame = CFrame.new(hrp2.Position + Vector3.new(0, 4, 0), pile)
                end
            end
        end
    end)
end

local function waitInterval(optName, fallback)
    return tonumber(State[optName]) or fallback
end

local function ensureNearPileForPick()
    local pile = GameConfig.PILE_CENTER
    local hrp = getHRP()
    if not hrp then return end
    local distToPile = (hrp.Position - pile).Magnitude
    if distToPile > 28 then
        hrp.CFrame = CFrame.new(pile + Vector3.new(math.random(-3, 3), 5, math.random(-3, 3)))
        if Workspace.CurrentCamera then
            Workspace.CurrentCamera.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 4, 0), pile)
        end
        task.wait(0.25)
    end
end

local function teleportToPart(part, yOffset)
    local hrp = getHRP()
    if not hrp or not part then return end
    local dist = (hrp.Position - part.Position).Magnitude
    if dist > 15 then
        hrp.CFrame = part.CFrame + Vector3.new(0, yOffset or 4, 1.5)
        if Workspace.CurrentCamera then
            pcall(function() Workspace.CurrentCamera.CFrame = CFrame.lookAt(Workspace.CurrentCamera.CFrame.Position, part.Position) end)
        end
        task.wait(0.18)
    else
        if Workspace.CurrentCamera then
            pcall(function() Workspace.CurrentCamera.CFrame = CFrame.lookAt(Workspace.CurrentCamera.CFrame.Position, part.Position) end)
        end
    end
end

local function tryBuyTrack(trackName)

    local track = GameConfig.UPGRADE_TRACKS[trackName]
    if not track then return end
    local cur = tonumber(LocalPlayer:GetAttribute("HayUpgrade" .. trackName)) or 1
    if cur >= #track.Levels then return end
    local nxt = track.Levels[cur + 1]
    if not nxt then return end
    local cost = nxt.Cost or 0
    if getCash() >= cost then
        pcall(function() BuyUpgrade:FireServer(trackName) end)
    end
end

local function getPermanentUpgradeById(id)
    if type(ShopItemsConfig) == "table" and type(ShopItemsConfig.getUpgrades) == "function" then
        local ok, upgrades = pcall(function()
            return ShopItemsConfig.getUpgrades()
        end)
        if ok and type(upgrades) == "table" then
            for _, upgrade in pairs(upgrades) do
                if type(upgrade) == "table" and (upgrade.Id == id or upgrade.DataKey == id) then
                    return upgrade
                end
            end
        end
    end

    if type(UpgradeConfig) ~= "table" then
        return nil
    end

    if UpgradeConfig.Scope and UpgradeConfig.Scope.Permanent ~= nil
        and type(UpgradeConfig.getByScope) == "function" then
        local ok, upgrades = pcall(function()
            return UpgradeConfig.getByScope(UpgradeConfig.Scope.Permanent)
        end)
        if ok and type(upgrades) == "table" then
            for _, upgrade in pairs(upgrades) do
                if type(upgrade) == "table" and (upgrade.Id == id or upgrade.DataKey == id) then
                    return upgrade
                end
            end
        end
    end

    if type(UpgradeConfig.getUpgrade) == "function" then
        local ok, upgrade = pcall(function()
            return UpgradeConfig.getUpgrade(id)
        end)
        if ok and type(upgrade) == "table" then
            return upgrade
        end
    end

    return nil
end

local function tryBuyPermanent(id)
    if not refreshPermanentUpgradeReferences() then
        NotifyPermanentOnce(
            "PermanentUpgradeSetup",
            "Permanent Upgrades Waiting",
            "Waiting for the lobby shop data and purchase remote to load.",
            4,
            "clock"
        )
        return
    end

    local upgrade = getPermanentUpgradeById(id)
    if not upgrade then
        NotifyPermanentOnce(
            "MissingUpgrade:" .. id,
            "Upgrade Not Found",
            "Couldn't find the permanent upgrade: " .. id,
            4,
            "alert-circle"
        )
        return
    end

    local playerUpgrades = readClientDataValue(PlayerDataClient, "PlayerUpgrades")
    local dataKey = upgrade.DataKey or id
    local currentLevel = tonumber(readClientDataValue(playerUpgrades, dataKey))
    if currentLevel == nil then
        currentLevel = tonumber(LocalPlayer:GetAttribute("Upgrade" .. dataKey)) or 0
    end

    local maxOk, maxLevel = pcall(function()
        return UpgradeConfig.getMaxLevel(upgrade)
    end)
    if not maxOk or type(maxLevel) ~= "number" then
        NotifyPermanentOnce(
            "MaxLevel:" .. id,
            "Upgrade Data Error",
            "Couldn't read the maximum level for " .. tostring(upgrade.Name or id) .. ".",
            4,
            "alert-circle"
        )
        return
    end

    if currentLevel >= maxLevel then
        return
    end

    local priceOk, price = pcall(function()
        return UpgradeConfig.getPrice(upgrade, currentLevel)
    end)
    price = priceOk and tonumber(price) or nil
    if not price then
        NotifyPermanentOnce(
            "PriceUnavailable:" .. id,
            "Upgrade Price Unavailable",
            "Couldn't read the next gem cost for " .. tostring(upgrade.Name or id) .. ".",
            4,
            "alert-circle"
        )
        return
    end

    local currencyName = upgrade.Currency or "Gems"
    local currencyAmount
    if currencyName == "Gems" then
        currencyAmount = getGems()
        if currencyAmount == nil then
            NotifyPermanentOnce(
                "GemBalanceUnavailable:" .. id,
                "Gem Balance Unavailable",
                "Couldn't read your gem balance from the game's Data.client.Gems() value yet. Try again after the lobby data finishes loading.",
                4,
                "alert-circle"
            )
            return
        end
    else
        currencyAmount = tonumber(readClientDataValue(PlayerDataClient, currencyName)) or 0
    end
    if currencyAmount < price then
        NotifyPermanentOnce(
            "InsufficientCurrency:" .. id,
            "Not Enough " .. currencyName,
            tostring(upgrade.Name or id) .. " costs " .. tostring(price) .. " " .. currencyName
                .. "; you currently have " .. tostring(currencyAmount) .. ".",
            4,
            "gem"
        )
        return
    end

    local requestOk, purchased, purchaseError = pcall(function()
        if ShopNetworker and type(ShopNetworker.fetch) == "function" then
            return ShopNetworker:fetch("BuyUpgrade", upgrade.Id or id)
        end
        if ShopRemoteFunction then
            return ShopRemoteFunction:InvokeServer("BuyUpgrade", upgrade.Id or id)
        end
        error("The game's ShopUI purchase network is not ready yet.")
    end)

    if not requestOk then
        NotifyPermanentOnce(
            "PurchaseException:" .. id,
            "Upgrade Purchase Error",
            tostring(purchased),
            4,
            "x"
        )
        return
    end

    if purchased then
        NotifyPermanentOnce(
            "Purchased:" .. id .. ":" .. tostring(currentLevel + 1),
            "Permanent Upgrade Purchased",
            tostring(upgrade.Name or id) .. " upgraded to level " .. tostring(currentLevel + 1) .. ".",
            3,
            "check"
        )
    else
        NotifyPermanentOnce(
            "PurchaseRejected:" .. id,
            "Upgrade Purchase Failed",
            tostring(purchaseError or "The game did not confirm the purchase."),
            4,
            "x"
        )
    end
end

local function doUnload()
    if Unloaded then return end
    Unloaded = true
    pcall(function() VacuumAction:FireServer("Stop") end)
end

pcall(function() Window:OnDestroy(doUnload) end)

local MainTab = Window:Tab({ Title = "Overview", Icon = "layout-dashboard" })
local CollectingTab = Window:Tab({ Title = "Collect", Icon = "package-search" })
local SellingTab = Window:Tab({ Title = "Sell", Icon = "coins" })
local ToolsTab = Window:Tab({ Title = "Tools", Icon = "hammer" })
local NeedleTab = Window:Tab({ Title = "Find Needle", Icon = "search" })
local ShopTab = Window:Tab({ Title = "Shop", Icon = "shopping-cart" })
local UpgradesTab = Window:Tab({ Title = "Upgrades", Icon = "trending-up" })

local mapStatusPara = nil

do
    mapStatusPara = MainTab:Paragraph({
        Title = "Map Status",
        Desc = "Waiting for a playable map. Automation becomes available when the game systems are ready."
    })
    local sessionPara = MainTab:Paragraph({ Title = "Session Stats", Desc = "Time: 0m 0s | Cash: $0 | Gems: 0 | Hay: 0/25" })

    task.spawn(function()
        local s = 0
        while true do
            task.wait(1)
            if Unloaded then break end
            s = s + 1
            pcall(function()
                sessionPara:SetDesc(string.format(
                    "Time: %dm %ds | Cash: $%s | Gems: %s | Hay: %d/%d",
                    s // 60, s % 60, tostring(getCash()), tostring(getGems()), getHayHeld(), getHayCapacity()
                ))
            end)
        end
    end)
end

do
    Header(CollectingTab, "Collect Resources")
    AddToggle(CollectingTab, "AutoPickHay", "Auto Collect Hay", false)
    AddToggle(CollectingTab, "AutoCollectDroppedHay", "Collect Dropped Hay", false)
    AddToggle(CollectingTab, "AutoCollectGems", "Collect Gems", false)
    AddToggle(CollectingTab, "AutoVacuumCollect", "Collect with Vacuum", false)
    AddSlider(CollectingTab, "CollectInterval", "Collection Check Interval", 0.1, 3, 1, 0.1)
end

do
    Header(SellingTab, "Automatic Selling")
    AddToggle(SellingTab, "AutoSellHay", "Auto Sell Hay", false)
    AddSlider(SellingTab, "SellThreshold", "Hay Amount to Sell At", 1, 250, 25, 1)
    AddToggle(SellingTab, "SellOnlyIfFull", "Sell Only When Bag Is Full", false)
end

do
    Header(ToolsTab, "Automatic Tool Use")
    AddToggle(ToolsTab, "AutoUseTNT", "Auto Use TNT", false)
    AddToggle(ToolsTab, "AutoUsePitchfork", "Auto Use Pitchfork", false)
    AddToggle(ToolsTab, "AutoDeployDrone", "Auto Deploy Drone", false)
    AddToggle(ToolsTab, "AutoVacuum", "Auto Run Vacuum", false)
    AddSlider(ToolsTab, "ToolInterval", "Tool Check Interval", 0.2, 5, 1, 0.1)
end

do
    Header(NeedleTab, "Needle Search")
    AddToggle(NeedleTab, "AutoFindNeedle", "Auto Search for Needle", false)
    AddToggle(NeedleTab, "AutoHandInNeedle", "Auto Hand In Needle", false)
    AddSlider(NeedleTab, "NeedleInterval", "Search Check Interval", 0.2, 3, 1, 0.1)
end

do
    Header(ShopTab, "Automatic Purchases")
    State.BuyToolsList = { "Pitchfork" }
    ShopTab:Dropdown({
        Title = "Items to Buy",
        Desc = "Select the items that Auto Buy should purchase when affordable.",
        Values = { "Pitchfork", "TNT", "Drone", "Vacuum", "Infinite Bag", "Capacity Bag" },
        Value = { "Pitchfork" },
        Multi = true,
        AllowNone = true,
        Callback = function(v) State.BuyToolsList = v end,
    })
    AddToggle(ShopTab, "AutoBuyTools", "Auto Buy Selected Items", false)
    AddSlider(ShopTab, "BuyInterval", "Purchase Check Interval", 0.5, 5, 1, 0.1)
    Header(ShopTab, "Owned Items")
    ShopTab:Button({
        Title = "Check Item Ownership",
        Desc = "Shows whether the game marks each tool or bag as owned.",
        Callback = function()
            local t = {}
            for _, k in ipairs({ "PitchforkOwned", "TntOwned", "DroneOwned", "VacuumOwned", "InfiniteBagOwned", "HayUpgradeCapacity" }) do
                table.insert(t, k .. ": " .. tostring(LocalPlayer:GetAttribute(k)))
            end
            Notify("Item Ownership", table.concat(t, "\n"), 4, "check")
        end,
    })
end

do
    Header(UpgradesTab, "Permanent Upgrades (Gems)")
    AddToggle(UpgradesTab, "UpgBagSize", "Upgrade Permanent Bag Size", false)
    AddToggle(UpgradesTab, "UpgExtraTake", "Upgrade Hand Grab Amount", false)
    AddToggle(UpgradesTab, "UpgGemValue", "Upgrade Gem Value", false)
    AddToggle(UpgradesTab, "UpgHayValue", "Upgrade Hay Value", false)
    AddSlider(UpgradesTab, "PermInterval", "Gem Upgrade Check Interval", 0.5, 5, 1, 0.1)

    Header(UpgradesTab, "Hand Upgrades (Cash)")
    AddToggle(UpgradesTab, "UpgHandSpeed", "Upgrade Hand Speed", false)
    AddToggle(UpgradesTab, "UpgHandGrab", "Upgrade Hand Grab Amount", false)
    AddToggle(UpgradesTab, "UpgHandHold", "Upgrade Hand Carry Amount", false)

    Header(UpgradesTab, "TNT Upgrades")
    AddToggle(UpgradesTab, "UpgTntLuck", "Upgrade TNT Luck", false)
    AddToggle(UpgradesTab, "UpgTntCooldown", "Upgrade TNT Cooldown", false)
    AddToggle(UpgradesTab, "UpgTntPower", "Upgrade TNT Power", false)

    Header(UpgradesTab, "Pitchfork Upgrades")
    AddToggle(UpgradesTab, "UpgPitchCooldown", "Upgrade Pitchfork Cooldown", false)
    AddToggle(UpgradesTab, "UpgPitchHold", "Upgrade Pitchfork Hold", false)
    AddToggle(UpgradesTab, "UpgPitchSweep", "Upgrade Pitchfork Sweep", false)

    Header(UpgradesTab, "Drone Upgrades")
    AddToggle(UpgradesTab, "UpgDroneSpeed", "Upgrade Drone Speed", false)
    AddToggle(UpgradesTab, "UpgDroneGrab", "Upgrade Drone Grab Amount", false)
    AddToggle(UpgradesTab, "UpgDroneCapacity", "Upgrade Drone Capacity", false)

    Header(UpgradesTab, "Vacuum Upgrades")
    AddToggle(UpgradesTab, "UpgVacPower", "Upgrade Vacuum Power", false)
    AddToggle(UpgradesTab, "UpgVacCooling", "Upgrade Vacuum Cooling", false)
    AddToggle(UpgradesTab, "UpgVacRuntime", "Upgrade Vacuum Runtime", false)

    Header(UpgradesTab, "Carrying Capacity")
    AddToggle(UpgradesTab, "UpgCapacity", "Upgrade Carrying Capacity (Cash)", false)
end

pcall(function() MainTab:Select() end)

Notify("UI Ready", "The interface is loaded. Permanent gem upgrades can run in the lobby; map automation starts when a playable map is detected.", 6, "map")
pcall(function()
    mapStatusPara:SetDesc("Waiting for a playable map. Permanent gem upgrades can run in the lobby when upgrade data is available.")
end)

task.spawn(function()
    while not Unloaded do
        local ready = refreshGameReferences()
        if ready and not MapReady then
            MapReady = true
            pcall(function()
                mapStatusPara:SetDesc("Map loaded. Map automation is ready. Permanent gem upgrades can run in the lobby.")
            end)
            Notify("Map Loaded", "Map detected successfully. Map automation is now ready.", 5, "check")
        elseif not ready and MapReady then
            MapReady = false
            pcall(function()
                mapStatusPara:SetDesc("Waiting for a playable map. Permanent gem upgrades remain available in the lobby when upgrade data is loaded.")
            end)
        end
        task.wait(1)
    end
end)

task.spawn(function()
    while true do
        task.wait(waitInterval("CollectInterval", 1))
        if Unloaded then break end
        if MapReady and State.AutoPickHay then
            if not isBagFull() then
                local hay = findClosestHay()
                if not hay then
                    ensureNearPileForPick()
                    hay = findClosestHay()
                end
                if hay then
                    teleportToPart(hay, 4)
                    local id = hay:GetAttribute("HayId")
                    if id then
                        local candidates = getGrabCandidates(hay)
                        pcall(function() PickHay:FireServer(id, candidates) end)
                    else
                        pcall(function() PickDroppedHay:FireServer(hay) end)
                    end
                else
                    ensureNearPileForPick()
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(waitInterval("CollectInterval", 1))
        if Unloaded then break end
        if MapReady and State.AutoCollectDroppedHay then
            if not isBagFull() then
                local d = findClosestDropped()
                if not d then
                    ensureNearPileForPick()
                    d = findClosestDropped()
                end
                if d then
                    local part = d:IsA("BasePart") and d or d:FindFirstChildWhichIsA("BasePart")
                    if part then teleportToPart(part, 3) end
                    pcall(function() PickDroppedHay:FireServer(d) end)
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(waitInterval("CollectInterval", 1))
        if Unloaded then break end
        if MapReady and State.AutoCollectGems then
            local gemPart, id = findClosestGem()
            if not gemPart then
                ensureNearPileForPick()
                gemPart, id = findClosestGem()
            end
            if gemPart and id then
                teleportToPart(gemPart, 3)
                pcall(function() CollectGem:FireServer(id) end)
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(1)
        if Unloaded then break end
        if MapReady and State.AutoSellHay then
            local held = getHayHeld()
            local thresh = tonumber(State.SellThreshold) or 25
            local should
            if State.SellOnlyIfFull then
                should = isBagFull()
            else
                should = held >= thresh
            end
            if should and held > 0 then trySell() end
        end
    end
end)

do
    local vacActive = false
    task.spawn(function()
        while true do
            task.wait(waitInterval("CollectInterval", 1))
            if Unloaded then break end
            local should = MapReady and (State.AutoVacuumCollect or State.AutoVacuum)
            if should and owns("VacuumOwned") then
                if not vacActive and not isBagFull() then

                    local hay = findClosestHay()
                    if not hay then
                        ensureNearPileForPick()
                        hay = findClosestHay()
                    end
                    if hay then teleportToPart(hay, 5) end
                    pcall(function() VacuumAction:FireServer("Start") end)
                    vacActive = true
                elseif isBagFull() and vacActive then
                    pcall(function() VacuumAction:FireServer("Stop") end)
                    vacActive = false
                    trySell()
                end
            else
                if vacActive then
                    pcall(function() VacuumAction:FireServer("Stop") end)
                    vacActive = false
                end
            end

            if vacActive and LocalPlayer:GetAttribute("VacuumOverheated") then
                pcall(function() VacuumAction:FireServer("Stop") end)
                vacActive = false
                task.wait(0.5)
                ensureNearPileForPick()
            end
        end
    end)
end

task.spawn(function()
    while true do
        task.wait(waitInterval("ToolInterval", 1))
        if Unloaded then break end
        if MapReady and State.AutoUseTNT and owns("TntOwned") then
            local ok = not LocalPlayer:GetAttribute("NeedleInputLocked")
            if ok then
                pcall(function() TntAction:FireServer("light") end)
                task.wait(0.4)
                local cam = Workspace.CurrentCamera
                if cam then
                    local dir = cam.CFrame.LookVector * 40 + Vector3.new(0, 8, 0)
                    local cf = cam.CFrame
                    pcall(function() TntAction:FireServer("throw", cf, dir) end)
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(waitInterval("ToolInterval", 1))
        if Unloaded then break end
        if MapReady and State.AutoUsePitchfork and owns("PitchforkOwned") then
            local hay = findClosestHay()
            if not hay then
                ensureNearPileForPick()
                hay = findClosestHay()
            end
            if hay then teleportToPart(hay, 4) end
            local id = hay and hay:GetAttribute("HayId")
            if id then
                pcall(function() PitchforkDig:FireServer(id) end)
            else
                local fakeId = LocalPlayer:GetAttribute("HoveredHayId")
                if fakeId then

                    ensureNearPileForPick()
                    pcall(function() PitchforkDig:FireServer(fakeId) end)
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(waitInterval("ToolInterval", 1))
        if Unloaded then break end
        if MapReady and State.AutoDeployDrone and owns("DroneOwned") then
            if not LocalPlayer:GetAttribute("DroneDeployed") then
                pcall(function() DeployDrone:FireServer() end)
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(waitInterval("NeedleInterval", 1))
        if Unloaded then break end
        if MapReady and State.AutoFindNeedle then
            if not LocalPlayer:GetAttribute("NeedleRoundComplete") then
                local hay = findClosestHay()
                if not hay then
                ensureNearPileForPick()
                hay = findClosestHay()
            end
                if hay then
                    teleportToPart(hay, 4)
                    local id = hay:GetAttribute("HayId")
                    if id and not isBagFull() then
                        pcall(function() PickHay:FireServer(id, getGrabCandidates(hay)) end)
                    elseif isBagFull() then
                        trySell()
                    end
                else
                    ensureNearPileForPick()
                end
            end
        end
        if MapReady and State.AutoHandInNeedle then

            local farmer = Workspace:FindFirstChild("NPC") and Workspace.NPC:FindFirstChild("Farmer_NPC")
            if farmer and farmer:GetPivot() then
                local hrp = getHRP()
                if hrp and (hrp.Position - farmer:GetPivot().Position).Magnitude > 20 then
                    hrp.CFrame = farmer:GetPivot() * CFrame.new(0, 0, 4)
                    task.wait(0.2)
                end
            end
            pcall(function() NeedleHandIn:FireServer() end)
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(waitInterval("BuyInterval", 1))
        if Unloaded then break end
        if MapReady and State.AutoBuyTools then
            local sel = State.BuyToolsList or {}
            local list = {}
            if typeof(sel) == "table" then
                for k, v in pairs(sel) do
                    if type(k) == "number" then
                        if type(v) == "string" then table.insert(list, v) end
                    elseif v then
                        table.insert(list, k)
                    end
                end
            end
            for _, name in ipairs(list) do
                if name == "Pitchfork" and not owns("PitchforkOwned") then
                    pcall(function() BuyShopItem:FireServer("Pitchfork") end)
                elseif name == "TNT" and not owns("TntOwned") then
                    pcall(function() BuyShopItem:FireServer("Tnt") end)
                elseif name == "Drone" and not owns("DroneOwned") then
                    pcall(function() BuyShopItem:FireServer("Drone") end)
                elseif name == "Vacuum" and not owns("VacuumOwned") then
                    pcall(function() BuyShopItem:FireServer("Vacuum") end)
                elseif name == "Infinite Bag" and not owns("InfiniteBagOwned") then
                    pcall(function() BuyShopItem:FireServer("InfiniteBag") end)
                elseif name == "Capacity Bag" then

                    local st = tonumber(LocalPlayer:GetAttribute("HayUpgradeCapacity")) or 1
                    local track = GameConfig.UPGRADE_TRACKS["Capacity"]
                    if track and st < #track.Levels then
                        local cost = track.Levels[st + 1].Cost
                        if getCash() >= (cost or 0) then
                            pcall(function() BuyUpgrade:FireServer("Capacity") end)
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    refreshPermanentUpgradeReferences()
    while true do
        task.wait(waitInterval("PermInterval", 1))
        if Unloaded then break end
        if State.UpgBagSize then tryBuyPermanent("ExtraHoldAmount") end
        if State.UpgExtraTake then tryBuyPermanent("ExtraTakeAmount") end
        if State.UpgGemValue then tryBuyPermanent("GemValue") end
        if State.UpgHayValue then tryBuyPermanent("ExtraHayValuePercentage") end
    end
end)

task.spawn(function()
    while true do
        task.wait(1.2)
        if Unloaded then break end
        if MapReady and State.UpgCapacity then tryBuyTrack("Capacity") end
        if MapReady and State.UpgHandSpeed then tryBuyTrack("Speed") end
        if MapReady and State.UpgHandGrab then tryBuyTrack("Grab") end
        if MapReady and State.UpgHandHold then tryBuyTrack("HandHold") end
        if MapReady and State.UpgTntLuck then tryBuyTrack("TntLuck") end
        if MapReady and State.UpgTntCooldown then tryBuyTrack("TntCooldown") end
        if MapReady and State.UpgTntPower then tryBuyTrack("TntPower") end
        if MapReady and State.UpgPitchCooldown then tryBuyTrack("PitchforkCooldown") end
        if MapReady and State.UpgPitchHold then tryBuyTrack("PitchforkHold") end
        if MapReady and State.UpgPitchSweep then tryBuyTrack("Pitchfork") end
        if MapReady and State.UpgDroneSpeed then tryBuyTrack("DroneSpeed") end
        if MapReady and State.UpgDroneGrab then tryBuyTrack("DroneGrab") end
        if MapReady and State.UpgDroneCapacity then tryBuyTrack("DroneCapacity") end
        if MapReady and State.UpgVacPower then tryBuyTrack("VacuumPower") end
        if MapReady and State.UpgVacCooling then tryBuyTrack("VacuumCooling") end
        if MapReady and State.UpgVacRuntime then tryBuyTrack("VacuumRuntime") end
    end
end)

