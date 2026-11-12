local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local LocalPlayer = Players.LocalPlayer

local running = true
local connections = {}
local function trackConnection(connection)
    if connection then
        table.insert(connections, connection)
    end
    return connection
end

local function getCharacter()
	return LocalPlayer.Character
end

local function getHumanoid()
	local character = LocalPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function getRootPart()
	local character = LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local Settings = {
	SpeedOn = false,
	Speed = 30,
	JumpOn = false,
	JumpPower = 100,
	InfiniteJump = false,
	Sprint = false,
	AntiRagdoll = false,
	EspPlayer = false,
	EspCreature = false,
	EspCoin = false,
	EspItem = false,
	EspDisaster = false,
	EspBoss = false,
	EspDistance = 500,
	CoinFarm = false,
	AutoRevive = false,
	AutoCarry = false,
	AutoClaimDiary = false,
	HazardWarn = false,
	AutoDodge = false,
	UnlimitedStamina = false,
	UnlimitedOxygen = false,
	AutoStruggle = false,
}

local overlay = Instance.new("ScreenGui")
overlay.Name = "VeloxHub_SurviveIdeas"
overlay.ResetOnSpawn = false
overlay.IgnoreGuiInset = true
overlay.Parent = LocalPlayer:WaitForChild("PlayerGui")

local espEntries = {}

local function espPart(instance)
	if instance:IsA("BasePart") then
		return instance
	end
	if instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	end
	return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function createEsp(instance, part, color, title, detail)
    local gui = Instance.new("BillboardGui")
    gui.Name = "VeloxHub_ESP"
    gui.Size = UDim2.fromOffset(188, 48)
    gui.StudsOffset = Vector3.new(0, 3.6, 0)
    gui.AlwaysOnTop = true
    gui.LightInfluence = 0
    gui.Adornee = part
    gui.Parent = overlay

    local card = Instance.new("Frame")
    card.Name = "Card"
    card.Size = UDim2.fromScale(1, 1)
    card.BackgroundColor3 = Color3.fromRGB(15, 18, 27)
    card.BackgroundTransparency = 0.12
    card.BorderSizePixel = 0
    card.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = card

    local border = Instance.new("UIStroke")
    border.Color = color
    border.Thickness = 1
    border.Transparency = 0.22
    border.Parent = card

    local accent = Instance.new("Frame")
    accent.Name = "Accent"
    accent.Size = UDim2.new(0, 3, 1, -12)
    accent.Position = UDim2.fromOffset(6, 6)
    accent.BackgroundColor3 = color
    accent.BorderSizePixel = 0
    accent.Parent = card

    local accentCorner = Instance.new("UICorner")
    accentCorner.CornerRadius = UDim.new(1, 0)
    accentCorner.Parent = accent

    local heading = Instance.new("TextLabel")
    heading.Name = "Title"
    heading.BackgroundTransparency = 1
    heading.Position = UDim2.fromOffset(16, 6)
    heading.Size = UDim2.new(1, -22, 0, 17)
    heading.Font = Enum.Font.GothamBold
    heading.TextSize = 11
    heading.TextColor3 = Color3.fromRGB(245, 247, 255)
    heading.TextXAlignment = Enum.TextXAlignment.Left
    heading.TextTruncate = Enum.TextTruncate.AtEnd
    heading.Text = title
    heading.Parent = card

    local subline = Instance.new("TextLabel")
    subline.Name = "Details"
    subline.BackgroundTransparency = 1
    subline.Position = UDim2.fromOffset(16, 25)
    subline.Size = UDim2.new(1, -22, 0, 15)
    subline.Font = Enum.Font.GothamMedium
    subline.TextSize = 10
    subline.TextColor3 = Color3.fromRGB(174, 184, 202)
    subline.TextXAlignment = Enum.TextXAlignment.Left
    subline.TextTruncate = Enum.TextTruncate.AtEnd
    subline.Text = detail
    subline.Parent = card

    local highlight = Instance.new("Highlight")
    highlight.Name = "VeloxHub_ESPHighlight"
    highlight.Adornee = instance
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = color
    highlight.FillTransparency = 0.88
    highlight.OutlineColor = color
    highlight.OutlineTransparency = 0.12
    highlight.Parent = instance

    local entry = {
        Gui = gui,
        Title = heading,
        Details = subline,
        Highlight = highlight,
    }
    espEntries[instance] = entry
    return entry
end
local TAG_GROUPS = {
	{ Setting = "EspCreature", Label = "CREATURE", Color = Color3.fromRGB(255, 120, 120), Tags = { "Creature", "NextbotPupil", "SpiderRig", "TrollFace", "NameNpc" } },
	{ Setting = "EspCoin", Label = "COIN", Color = Color3.fromRGB(255, 220, 60), Tags = { "Coin" } },
	{ Setting = "EspItem", Label = "ITEM", Color = Color3.fromRGB(120, 220, 255), Tags = { "ItemBob", "Carryable", "AirDropFlare" } },
	{
		Setting = "EspDisaster",
		Label = "DISASTER",
		Color = Color3.fromRGB(255, 160, 60),
		Tags = { "LavaFlood", "Geyser", "TsunamiWave", "TornadoFx", "StormCloud", "StructureFlame", "GrassFlame", "LeafPile" },
	},
	{
		Setting = "EspBoss",
		Label = "BOSS",
		Color = Color3.fromRGB(255, 80, 255),
		Tags = { "BossHealthBar" },
	},
}

local function espStep()
    local myRoot = getRootPart()
    local visible = {}

    if myRoot then
        if Settings.EspPlayer then
            for _, player in ipairs(Players:GetPlayers()) do
                local character = player.Character
                if player ~= LocalPlayer and character then
                    local humanoid = character:FindFirstChildOfClass("Humanoid")
                    local root = character:FindFirstChild("HumanoidRootPart")
                    if humanoid and humanoid.Health > 0 and root then
                        local distance = (root.Position - myRoot.Position).Magnitude
                        if distance <= Settings.EspDistance then
                            local title = player.DisplayName ~= "" and player.DisplayName or player.Name
                            local detail = string.format("%d HP  |  %d studs", math.ceil(humanoid.Health), math.floor(distance))
                            local color = Color3.fromRGB(255, 120, 135)
                            visible[character] = true
                            local entry = espEntries[character]
                            if not entry then
                                entry = createEsp(character, root, color, title, detail)
                            end
                            entry.Gui.Adornee = root
                            entry.Title.Text = title
                            entry.Details.Text = detail
                        end
                    end
                end
            end
        end

        for _, group in ipairs(TAG_GROUPS) do
            if Settings[group.Setting] then
                for _, tag in ipairs(group.Tags) do
                    for _, instance in ipairs(CollectionService:GetTagged(tag)) do
                        local part = espPart(instance)
                        if part and instance.Parent then
                            local distance = (part.Position - myRoot.Position).Magnitude
                            if distance <= Settings.EspDistance then
                                local title = group.Label
                                local detail = string.format("%s  |  %d studs", instance.Name, math.floor(distance))
                                visible[instance] = true
                                local entry = espEntries[instance]
                                if not entry then
                                    entry = createEsp(instance, part, group.Color, title, detail)
                                end
                                entry.Gui.Adornee = part
                                entry.Title.Text = title
                                entry.Details.Text = detail
                            end
                        end
                    end
                end
            end
        end
    end

    for instance, entry in pairs(espEntries) do
        if not visible[instance] then
            if entry.Gui then entry.Gui:Destroy() end
            if entry.Highlight then entry.Highlight:Destroy() end
            espEntries[instance] = nil
        end
    end
end

local function folderPath(...)
	local current = ReplicatedStorage
	for _, name in ipairs({ ... }) do
		current = current:FindFirstChild(name)
		if not current then
			return nil
		end
	end
	return current
end
local REMOTE_FOLDERS = {
	{ "Remotes", "Client", "Game" },
	{ "Remotes" },
	{ "SprintRemotes" },
	{ "Items", "Remotes" },
	{ "MetaWords", "Remotes" },
	{ "WriterRemotes" },
	{ "CarryRemotes" },
}

local function findRemote(name)
	for _, path in ipairs(REMOTE_FOLDERS) do
		local folder = folderPath(table.unpack(path))
		local remote = folder and folder:FindFirstChild(name)
		if remote and (remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent")) then
			return remote
		end
	end
	return nil
end

local function fireRemote(name, ...)
	local remote = findRemote(name)
	if not (remote and (remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent"))) then
		return false
	end
	local args = table.pack(...)
	pcall(function()
		remote:FireServer(table.unpack(args, 1, args.n))
	end)
	return true
end

local function nearestTagPart(tag)
	local myRoot = getRootPart()
	if not myRoot then
		return nil
	end
	local best, bestDistance = nil, math.huge
	for _, instance in ipairs(CollectionService:GetTagged(tag)) do
		local part = espPart(instance)
		if part then
			local distance = (part.Position - myRoot.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = part, distance
			end
		end
	end
	return best, bestDistance
end

local function coinFarmStep()
	local humanoid = getHumanoid()
	local coin = nearestTagPart("Coin")
	if humanoid and coin then
		humanoid:MoveTo(coin.Position)
	end
end

local function autoReviveStep()
	local humanoid = getHumanoid()
	if humanoid and humanoid.Health > 0 and LocalPlayer.Character then
		return
	end
	local shopRemotes = ReplicatedStorage:FindFirstChild("ShopRemotes")
	local grant = shopRemotes and shopRemotes:FindFirstChild("TestGrant")
	if not (grant and grant:IsA("RemoteEvent")) then
		return
	end
	pcall(function()
		grant:FireServer("revive")
	end)
end

local nextCarryAt = 0
local function autoCarryStep()
	local now = os.clock()
	if now < nextCarryAt then
		return
	end
	nextCarryAt = now + 1
	local part = nearestTagPart("Carryable")
	if not part then
		return
	end
	local carryRemotes = ReplicatedStorage:FindFirstChild("CarryRemotes")
	local request = carryRemotes and carryRemotes:FindFirstChild("Request")
	if not (request and request:IsA("RemoteEvent")) then
		return
	end
	pcall(function()
		request:FireServer("pick", part)
	end)
end

local claimedDiary = {}
local nextDiaryAt = 0
local function autoClaimDiaryStep()
	local now = os.clock()
	if now < nextDiaryAt then
		return
	end
	nextDiaryAt = now + 5
	local diary = ReplicatedStorage:FindFirstChild("Diary")
	local remotes = diary and diary:FindFirstChild("Remotes")
	local request = remotes and remotes:FindFirstChild("Request")
	local catalog = diary and diary:FindFirstChild("DiaryCatalog")
	if not (request and request:IsA("RemoteFunction") and catalog) then
		return
	end
	local ok, module = pcall(require, catalog)
	if not (ok and type(module) == "table") then
		return
	end
	local categories = module.Categories or module
	for id in pairs(categories) do
		local categoryId = type(id) == "string" and id or nil
		if categoryId and not claimedDiary[categoryId] then
			local invoked, result = pcall(function()
				return request:InvokeServer("claim", categoryId)
			end)
			if invoked and result then
				claimedDiary[categoryId] = true
			end
		end
	end
end

local window
local hazardNoticeAt = {}
local nextDodgeAt = {}

local HAZARD_TAGS = { "LavaFlood", "TsunamiWave", "TornadoFx", "Geyser", "StormCloud", "StructureFlame", "GrassFlame", "LeafPile" }
local function hazardStep()
    local myRoot = getRootPart()
    local humanoid = getHumanoid()
    if not myRoot then
        return
    end

    local now = os.clock()
    for _, tag in ipairs(HAZARD_TAGS) do
        for _, instance in ipairs(CollectionService:GetTagged(tag)) do
            local part = espPart(instance)
            if part then
                local distance = (part.Position - myRoot.Position).Magnitude
                if Settings.HazardWarn and distance <= 120 and now >= (hazardNoticeAt[tag] or 0) then
                    hazardNoticeAt[tag] = now + 10
                    if window then
                        pcall(function()
                            window:Notify({
                                title = "Nearby hazard",
                                content = string.format("%s detected about %d studs away.", tag, math.floor(distance)),
                            })
                        end)
                    end
                end
                if Settings.AutoDodge and humanoid and distance <= 60 and now >= (nextDodgeAt[tag] or 0) then
                    nextDodgeAt[tag] = now + 0.8
                    local away = myRoot.Position - part.Position
                    if away.Magnitude > 0.1 then
                        humanoid:MoveTo(myRoot.Position + away.Unit * 40)
                    end
                end
            end
        end
    end
end

local function unlimitedStaminaStep()
    local sprintRemotes = ReplicatedStorage:FindFirstChild("SprintRemotes")
    local setSprint = sprintRemotes and sprintRemotes:FindFirstChild("SetSprint")
    pcall(function()
        LocalPlayer:SetAttribute("Stamina", 100)
        LocalPlayer:SetAttribute("StaminaDrainMultiplier", 0)
    end)
    if setSprint and setSprint:IsA("RemoteEvent") then
        pcall(function()
            setSprint:FireServer(true)
        end)
    end
end

local function unlimitedOxygenStep()
    pcall(function()
        LocalPlayer:SetAttribute("Breath", 100)
    end)
end

local nextStruggleAt = 0
local function autoStruggleStep()
    local now = os.clock()
    if now < nextStruggleAt then
        return
    end
    nextStruggleAt = now + 0.2
    local grabRemotes = ReplicatedStorage:FindFirstChild("GrabRemotes")
    local struggle = grabRemotes and grabRemotes:FindFirstChild("Struggle")
    if not (struggle and struggle:IsA("RemoteEvent")) then
        return
    end
    pcall(function()
        struggle:FireServer()
    end)
end

local function applySpeed()
	local humanoid = getHumanoid()
	if humanoid then
		humanoid.WalkSpeed = Settings.SpeedOn and Settings.Speed or 16
	end
end

local function applyJump()
	local humanoid = getHumanoid()
	if humanoid then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = Settings.JumpOn and Settings.JumpPower or 50
	end
end

local function applySprint()
	if Settings.Sprint then
		fireRemote("SetSprint", true)
	end
end

local function applyAntiRagdoll()
	local character = getCharacter()
	local humanoid = getHumanoid()
	if not character or not humanoid then
		return
	end
	local ragdolled = character:GetAttribute("Ragdolled")
	local state = humanoid:GetState()
	if
		ragdolled
		or state == Enum.HumanoidStateType.Physics
		or state == Enum.HumanoidStateType.FallingDown
		or state == Enum.HumanoidStateType.PlatformStanding
	then
		pcall(function()
			character:SetAttribute("Ragdolled", false)
		end)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
		pcall(function()
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end)
		humanoid.PlatformStand = false
		if workspace.CurrentCamera then
			workspace.CurrentCamera.CameraSubject = humanoid
		end
	end
end
task.spawn(function()
	local ragdollRemotes = ReplicatedStorage:WaitForChild("RagdollRemotes", 15)
	local ragdollState = ragdollRemotes and ragdollRemotes:WaitForChild("RagdollState", 15)
	if not running then
		return
	end
	if not (ragdollState and ragdollState:IsA("RemoteEvent")) then
		return
	end
	trackConnection(ragdollState.OnClientEvent:Connect(function()
		if not Settings.AntiRagdoll then
			return
		end
		local character = getCharacter()
		local humanoid = getHumanoid()
		if not character or not humanoid then
			return
		end
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
		pcall(function()
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end)
		humanoid.PlatformStand = false
		pcall(function()
			character:SetAttribute("Ragdolled", false)
		end)
		if workspace.CurrentCamera then
			workspace.CurrentCamera.CameraSubject = humanoid
		end
	end))
end)

local function infiniteJump()
	local humanoid = getHumanoid()
	if humanoid and humanoid:GetState() == Enum.HumanoidStateType.Freefall then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()
window = Rayfield:CreateWindow({
    name = "Surve Your Ideas",
    subtitle = "VeloxHub  •  Author: Ovei",
    sidebarLayout = true,
    configuration = {
        autoSave = true,
        autoLoad = false,
        fileName = "VeloxHub_SurveYourIdeas",
    },
})

local Character = window:CreateTab({ name = "Character", icon = "user-round" })
local ESP = window:CreateTab({ name = "ESP", icon = "eye" })
local Automation = window:CreateTab({ name = "Automation", icon = "workflow" })
local System = window:CreateTab({ name = "System", icon = "activity" })

Character:CreateSection({ name = "Movement" })
Character:CreateToggle({
    name = "Speed Boost",
    value = false,
    flag = "syi_speed_on",
    callback = function(value)
        Settings.SpeedOn = value
        applySpeed()
    end,
})
Character:CreateSlider({
    name = "Walk Speed",
    range = { 16, 150 },
    increment = 1,
    value = 30,
    suffix = " studs",
    flag = "syi_speed",
    callback = function(value)
        Settings.Speed = value
        applySpeed()
    end,
})
Character:CreateToggle({
    name = "Jump Boost",
    value = false,
    flag = "syi_jump_on",
    callback = function(value)
        Settings.JumpOn = value
        applyJump()
    end,
})
Character:CreateSlider({
    name = "Jump Power",
    range = { 50, 300 },
    increment = 5,
    value = 100,
    flag = "syi_jump",
    callback = function(value)
        Settings.JumpPower = value
        applyJump()
    end,
})
Character:CreateToggle({
    name = "Infinite Jump",
    value = false,
    flag = "syi_infinite_jump",
    callback = function(value)
        Settings.InfiniteJump = value
    end,
})

Character:CreateSection({ name = "Survival" })
Character:CreateToggle({
    name = "Unlimited Oxygen",
    value = false,
    flag = "syi_unlimited_oxygen",
    callback = function(value)
        Settings.UnlimitedOxygen = value
    end,
})
Character:CreateToggle({
    name = "Unlimited Stamina",
    value = false,
    flag = "syi_unlimited_stamina",
    callback = function(value)
        Settings.UnlimitedStamina = value
    end,
})
Character:CreateToggle({
    name = "Force Sprint",
    value = false,
    flag = "syi_sprint",
    callback = function(value)
        Settings.Sprint = value
    end,
})
Character:CreateToggle({
    name = "Anti-Ragdoll",
    value = false,
    flag = "syi_anti_ragdoll",
    callback = function(value)
        Settings.AntiRagdoll = value
    end,
})
Character:CreateToggle({
    name = "Auto Struggle",
    value = false,
    flag = "syi_auto_struggle",
    callback = function(value)
        Settings.AutoStruggle = value
    end,
})
Character:CreateToggle({
    name = "Hazard Alerts",
    value = false,
    flag = "syi_hazard_warn",
    callback = function(value)
        Settings.HazardWarn = value
    end,
})
Character:CreateToggle({
    name = "Auto Dodge",
    value = false,
    flag = "syi_auto_dodge",
    callback = function(value)
        Settings.AutoDodge = value
    end,
})

ESP:CreateSection({ name = "Players" })
ESP:CreateToggle({
    name = "Player ESP",
    value = false,
    flag = "syi_esp_player",
    callback = function(value)
        Settings.EspPlayer = value
    end,
})
ESP:CreateSection({ name = "World" })
ESP:CreateToggle({
    name = "Creature ESP",
    value = false,
    flag = "syi_esp_creature",
    callback = function(value)
        Settings.EspCreature = value
    end,
})
ESP:CreateToggle({
    name = "Coin ESP",
    value = false,
    flag = "syi_esp_coin",
    callback = function(value)
        Settings.EspCoin = value
    end,
})
ESP:CreateToggle({
    name = "Item ESP",
    value = false,
    flag = "syi_esp_item",
    callback = function(value)
        Settings.EspItem = value
    end,
})
ESP:CreateToggle({
    name = "Hazard ESP",
    value = false,
    flag = "syi_esp_disaster",
    callback = function(value)
        Settings.EspDisaster = value
    end,
})
ESP:CreateToggle({
    name = "Boss ESP",
    value = false,
    flag = "syi_esp_boss",
    callback = function(value)
        Settings.EspBoss = value
    end,
})
ESP:CreateSlider({
    name = "ESP Range",
    range = { 50, 2000 },
    increment = 50,
    value = 500,
    suffix = " studs",
    flag = "syi_esp_distance",
    callback = function(value)
        Settings.EspDistance = value
    end,
})

Automation:CreateSection({ name = "Gathering" })
Automation:CreateToggle({
    name = "Coin Auto-Farm",
    value = false,
    flag = "syi_coin_farm",
    callback = function(value)
        Settings.CoinFarm = value
    end,
})
Automation:CreateToggle({
    name = "Auto Carry",
    value = false,
    flag = "syi_auto_carry",
    callback = function(value)
        Settings.AutoCarry = value
    end,
})

Automation:CreateSection({ name = "Progress" })
Automation:CreateToggle({
    name = "Auto Revive",
    value = false,
    flag = "syi_auto_revive",
    callback = function(value)
        Settings.AutoRevive = value
    end,
})
Automation:CreateToggle({
    name = "Diary Auto-Claim",
    value = false,
    flag = "syi_auto_diary",
    callback = function(value)
        Settings.AutoClaimDiary = value
    end,
})

System:CreateSection({ name = "Live Activity" })
local liveActivity = System:CreateText({
    name = "Session Status",
    text = "Status: Initializing\nActive features: 0\nUptime: 00:00:00",
})
System:CreateSection({ name = "Runtime" })
System:CreateText({
    name = "About",
    text = "VeloxHub  |  Surve Your Ideas  |  Ovei",
})
local shutdown
System:CreateButton({
    name = "Stop Script",
    callback = function()
        if shutdown then
            shutdown()
        end
    end,
})

local startedAt = os.clock()
local activityItems = {
    { "SpeedOn", "Speed Boost" }, { "JumpOn", "Jump Boost" },
    { "InfiniteJump", "Infinite Jump" }, { "Sprint", "Force Sprint" },
    { "AntiRagdoll", "Anti-Ragdoll" }, { "EspPlayer", "Player ESP" },
    { "EspCreature", "Creature ESP" }, { "EspCoin", "Coin ESP" },
    { "EspItem", "Item ESP" }, { "EspDisaster", "Hazard ESP" },
    { "EspBoss", "Boss ESP" }, { "CoinFarm", "Coin Auto-Farm" },
    { "AutoRevive", "Auto Revive" }, { "AutoCarry", "Auto Carry" },
    { "AutoClaimDiary", "Diary Auto-Claim" }, { "HazardWarn", "Hazard Alerts" },
    { "AutoDodge", "Auto Dodge" }, { "UnlimitedStamina", "Unlimited Stamina" },
    { "UnlimitedOxygen", "Unlimited Oxygen" }, { "AutoStruggle", "Auto Struggle" },
}

task.spawn(function()
    while running do
        local active = {}
        for _, item in ipairs(activityItems) do
            if Settings[item[1]] then
                table.insert(active, item[2])
            end
        end
        local elapsed = math.floor(os.clock() - startedAt)
        local hours = math.floor(elapsed / 3600)
        local minutes = math.floor((elapsed % 3600) / 60)
        local seconds = elapsed % 60
        local status = #active > 0 and table.concat(active, ", ") or "Idle"
        pcall(function()
            liveActivity:Set(string.format(
                "Status: %s\nActive features (%d): %s\nUptime: %02d:%02d:%02d",
                #active > 0 and "Running" or "Ready", #active, status,
                hours, minutes, seconds
            ))
        end)
        task.wait(1)
    end
end)

task.spawn(function()
	while running do
		if Settings.EspPlayer or Settings.EspCreature or Settings.EspCoin or Settings.EspItem or Settings.EspDisaster or Settings.EspBoss or next(espEntries) then
			pcall(espStep)
		end
		task.wait(0.35)
	end
end)

task.spawn(function()
	while running do
		if Settings.SpeedOn then
			pcall(applySpeed)
		end
		if Settings.JumpOn then
			pcall(applyJump)
		end
		if Settings.Sprint then
			pcall(applySprint)
		end
		if Settings.AntiRagdoll then
			pcall(applyAntiRagdoll)
		end
		task.wait(0.25)
	end
end)

task.spawn(function()
	while running do
		if Settings.InfiniteJump then
			pcall(infiniteJump)
		end
		task.wait(0.1)
	end
end)

task.spawn(function()
	while running do
		if Settings.CoinFarm then
			pcall(coinFarmStep)
		end
		if Settings.AutoCarry then
			pcall(autoCarryStep)
		end
		if Settings.AutoRevive then
			pcall(autoReviveStep)
		end
		if Settings.AutoClaimDiary then
			pcall(autoClaimDiaryStep)
		end
		task.wait(0.3)
	end
end)
task.spawn(function()
	while running do
		if Settings.UnlimitedStamina then
			pcall(unlimitedStaminaStep)
		end
		if Settings.UnlimitedOxygen then
			pcall(unlimitedOxygenStep)
		end
		if Settings.AutoStruggle then
			pcall(autoStruggleStep)
		end
		task.wait(0.2)
	end
end)

task.spawn(function()
	while running do
		if Settings.HazardWarn or Settings.AutoDodge then
			pcall(hazardStep)
		end
		task.wait(0.2)
	end
end)

trackConnection(LocalPlayer.CharacterAdded:Connect(function(character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid then
		if Settings.SpeedOn then
			humanoid.WalkSpeed = Settings.Speed
		end
		if Settings.JumpOn then
			humanoid.UseJumpPower = true
			humanoid.JumpPower = Settings.JumpPower
		end
	end
end))

shutdown = function()
    if not running then
        return
    end

    running = false

    for key, value in pairs(Settings) do
        if type(value) == "boolean" then
            Settings[key] = false
        end
    end

    for _, connection in ipairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(connections)

    for instance, entry in pairs(espEntries) do
        pcall(function()
            entry.Gui:Destroy()
        end)
        pcall(function()
            entry.Highlight:Destroy()
        end)
        espEntries[instance] = nil
    end

    if overlay then
        pcall(function()
            overlay:Destroy()
        end)
    end

    local humanoid = getHumanoid()
    if humanoid then
        humanoid.WalkSpeed = 16
        humanoid.UseJumpPower = true
        humanoid.JumpPower = 50
        humanoid.PlatformStand = false
    end
    pcall(function()
        window:Notify({
            title = "Script stopped",
            content = "Background loops and tracked ESP objects have been cleaned up.",
        })
    end)
end
