-- Surve Your Ideas | VeloxHub
-- Author: Ovei
-- Interface: Rayfield Gen2
-- Standalone build.

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

local function logMessage(message, level)
    if level == "warn" or level == "error" then
        warn(message)
    else
        print(message)
    end
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

local loggedOnce = {}
local function logOnce(key, message, level)
	if loggedOnce[key] then
		return
	end
	loggedOnce[key] = true
	logMessage("[VeloxHub] " .. message, level or "info")
end

logMessage("[VeloxHub] Surve Your Ideas by Ovei loaded", "info")

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
	AutoRoll = false,
	CoinFarm = false,
	AutoRevive = false,
	AutoCarry = false,
	AutoClaimDiary = false,
	AutoUseItem = false,
	UseItemId = nil,
	HazardWarn = false,
	AutoDodge = false,
	UnlimitedStamina = false,
	UnlimitedOxygen = false,
	AutoStruggle = false,
	AutoWriterPrompt = false,
	AutoWrite = false,
	WriteWord = "money",
	AutoWriteWorst = false,
	AutoMastery = false,
}

---------------------------------------------------------------------
-- ESP
---------------------------------------------------------------------

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

local function createEsp(instance, part, color, text)
	local gui = Instance.new("BillboardGui")
	gui.Name = "VeloxHub_ESP"
	gui.Size = UDim2.fromOffset(190, 44)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = part
	gui.Parent = overlay

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = gui

	local highlight = Instance.new("Highlight")
	highlight.Name = "VeloxHub_ESPHighlight"
	highlight.Adornee = instance
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = color
	highlight.FillTransparency = 0.8
	highlight.OutlineColor = color
	highlight.OutlineTransparency = 0
	highlight.Parent = instance

	local entry = { Gui = gui, Label = label, Highlight = highlight }
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
				if player ~= LocalPlayer and player.Character then
					local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
					local root = player.Character:FindFirstChild("HumanoidRootPart")
					if humanoid and humanoid.Health > 0 and root then
						local distance = (root.Position - myRoot.Position).Magnitude
						if distance <= Settings.EspDistance then
							local text = string.format("%s\n%d HP  %d studs", player.Name, math.ceil(humanoid.Health), math.floor(distance))
							local color = Color3.fromRGB(255, 120, 120)
							visible[player.Character] = true
							local entry = espEntries[player.Character]
							if not entry then
								entry = createEsp(player.Character, root, color, text)
							end
							entry.Gui.Adornee = root
							entry.Label.Text = text
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
								local text = string.format("%s\n%d studs", group.Label, math.floor(distance))
								visible[instance] = true
								local entry = espEntries[instance]
								if not entry then
									entry = createEsp(instance, part, group.Color, text)
								end
								entry.Gui.Adornee = part
								entry.Label.Text = text
							end
						end
					end
				end
			end
		end
	end
	for instance, entry in pairs(espEntries) do
		if not visible[instance] then
			entry.Gui:Destroy()
			entry.Highlight:Destroy()
			espEntries[instance] = nil
		end
	end
end

---------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------

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

-- This game scatters its remotes across several top-level folders.
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
		if remote and (remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") or remote:IsA("RemoteFunction")) then
			return remote
		end
	end
	return nil
end

local function fireRemote(name, ...)
	local remote = findRemote(name)
	if not (remote and (remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent"))) then
		logOnce("remote_missing_" .. name, "remote not found: " .. name, "warn")
		return false
	end
	local args = table.pack(...)
	pcall(function()
		remote:FireServer(table.unpack(args, 1, args.n))
	end)
	return true
end

local function itemRequest()
	local items = ReplicatedStorage:FindFirstChild("Items")
	local remotes = items and items:FindFirstChild("Remotes")
	return remotes and remotes:FindFirstChild("Request")
end

local function itemRequestInvoke(...)
	local request = itemRequest()
	if not (request and request:IsA("RemoteFunction")) then
		logOnce("item_request_missing", "Items.Remotes.Request not found", "warn")
		return nil
	end
	local args = table.pack(...)
	local ok, result = pcall(function()
		return request:InvokeServer(table.unpack(args, 1, args.n))
	end)
	if not ok then
		logOnce("item_request_failed", "item request failed: " .. tostring(result), "warn")
	end
	return ok and result or nil
end

-- Item catalogue for the "Auto Use Item" dropdown.
local ItemLibrary = nil
do
	local items = ReplicatedStorage:WaitForChild("Items", 10)
	local module = items and items:WaitForChild("ItemLibrary", 10)
	if module then
		local ok, result = pcall(require, module)
		if ok then
			ItemLibrary = result
		end
	end
end

local itemNames = { "None" }
local itemNameToId = {}
if ItemLibrary and ItemLibrary.Items then
	for _, item in ipairs(ItemLibrary.Items) do
		if item.name and item.id then
			table.insert(itemNames, item.name)
			itemNameToId[item.name] = item.id
		end
	end
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
		logOnce("coin_ok", "coin farm: walking to the nearest coin", "info")
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
		logOnce("revive_missing", "auto revive: ShopRemotes.TestGrant not found", "warn")
		return
	end
	pcall(function()
		grant:FireServer("revive")
	end)
	logOnce("revive_ok", "auto revive: sent the revive grant", "info")
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
		logOnce("carry_missing", "auto carry: CarryRemotes.Request not found", "warn")
		return
	end
	pcall(function()
		request:FireServer("pick", part)
	end)
	logOnce("carry_ok", "auto carry: picking up a carryable", "info")
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
		logOnce("diary_missing", "diary auto-claim: Diary remotes/catalog not found", "warn")
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
	logOnce("diary_ok", "diary auto-claim: tried every category", "info")
end

local nextUseAt = 0
local function autoUseItemStep()
	if not Settings.UseItemId then
		return
	end
	local now = os.clock()
	if now < nextUseAt then
		return
	end
	nextUseAt = now + 2
	itemRequestInvoke("use", Settings.UseItemId, nil)
	logOnce("useitem_ok", "auto use item: using " .. tostring(Settings.UseItemId), "info")
end

local HAZARD_TAGS = { "LavaFlood", "TsunamiWave", "TornadoFx", "Geyser", "StormCloud", "StructureFlame", "GrassFlame", "LeafPile" }
local warnedHazards = {}

local function hazardStep()
	local myRoot = getRootPart()
	local humanoid = getHumanoid()
	if not myRoot then
		return
	end
	for _, tag in ipairs(HAZARD_TAGS) do
		for _, instance in ipairs(CollectionService:GetTagged(tag)) do
			local part = espPart(instance)
			if part then
				local distance = (part.Position - myRoot.Position).Magnitude
				if distance <= 120 and not warnedHazards[tag] then
					warnedHazards[tag] = true
					logMessage(string.format("[VeloxHub] HAZARD: %s is %.0f studs away", tag, distance), "warn")
				end
				if Settings.AutoDodge and humanoid and distance <= 60 then
					local away = myRoot.Position - part.Position
					if away.Magnitude > 0.1 then
						humanoid:MoveTo(myRoot.Position + away.Unit * 40)
						logOnce("dodge_ok", "auto dodge: moving away from " .. tag, "info")
					end
				end
			end
		end
	end
end

---------------------------------------------------------------------
-- Stamina + writer
---------------------------------------------------------------------

local lastStaminaLog = 0
local function unlimitedStaminaStep()
	local now = os.clock()
	local sprintRemotes = ReplicatedStorage:FindFirstChild("SprintRemotes")
	local setSprint = sprintRemotes and sprintRemotes:FindFirstChild("SetSprint")
	local before = LocalPlayer:GetAttribute("Stamina")
	pcall(function()
		LocalPlayer:SetAttribute("Stamina", 100)
		LocalPlayer:SetAttribute("StaminaDrainMultiplier", 0)
	end)
	local after = LocalPlayer:GetAttribute("Stamina")
	local character = getCharacter()
	local sprinting = character and character:GetAttribute("Sprinting")
	local fired = false
	if setSprint and setSprint:IsA("RemoteEvent") then
		pcall(function()
			setSprint:FireServer(true)
		end)
		fired = true
	end
	if now - lastStaminaLog >= 1 then
		lastStaminaLog = now
		logMessage(
			string.format(
				"[VeloxHub] stamina debug: before=%s after=%s sprinting=%s drainMul=%s fired=%s",
				tostring(before),
				tostring(after),
				tostring(sprinting),
				tostring(LocalPlayer:GetAttribute("StaminaDrainMultiplier")),
				tostring(fired)
			),
			"info"
		)
	end
	logOnce("stamina_ok", "unlimited stamina: keeping stamina full", "info")
end

local lastBreathLog = 0
local function unlimitedOxygenStep()
	local now = os.clock()
	local breath = LocalPlayer:GetAttribute("Breath")
	local isNumber = typeof(breath) == "number"
	pcall(function()
		LocalPlayer:SetAttribute("Breath", 100)
	end)
	if now - lastBreathLog >= 2 then
		lastBreathLog = now
		logMessage(string.format("[VeloxHub] oxygen debug: breath=%s", isNumber and tostring(math.floor(breath)) or "nil"), "info")
	end
	logOnce("oxygen_ok", "unlimited oxygen: keeping breath full", "info")
end

local WRITE_CANDIDATES = {
	{ { "WriterRemotes" }, "SubmitWord" },
	{ { "MetaWords", "Remotes" }, "TryMeta" },
	{ { "MetaWords", "Remotes" }, "Submit" },
	{ { "WriterRemotes" }, "Submit" },
	{ { "WriterRemotes" }, "Write" },
}

local function findWriteRemote()
	for _, candidate in ipairs(WRITE_CANDIDATES) do
		local folder = folderPath(table.unpack(candidate[1]))
		local remote = folder and folder:FindFirstChild(candidate[2])
		if remote and (remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent")) then
			return remote
		end
	end
	return nil
end

task.spawn(function()
	local metaWords = ReplicatedStorage:WaitForChild("MetaWords", 15)
	local metaRemotes = metaWords and metaWords:WaitForChild("Remotes", 15)
	local writerRemotes = ReplicatedStorage:WaitForChild("WriterRemotes", 15)
	local sprintRemotes = ReplicatedStorage:WaitForChild("SprintRemotes", 15)
	local itemsRemotes = folderPath("Items", "Remotes")
	if not running then
		return
	end
	local function names(folder)
		local list = {}
		if folder then
			for _, child in ipairs(folder:GetChildren()) do
				table.insert(list, child.Name)
			end
		end
		return table.concat(list, ", ")
	end
	logMessage("[VeloxHub] MetaWords.Remotes: " .. names(metaRemotes), "info")
	logMessage("[VeloxHub] WriterRemotes: " .. names(writerRemotes), "info")
	logMessage("[VeloxHub] SprintRemotes: " .. names(sprintRemotes), "info")
	logMessage("[VeloxHub] Items.Remotes: " .. names(itemsRemotes), "info")
end)

-- Every word in the game's DiaryCatalog (416 entries).
local ALL_DISASTERS = {
	"delete", "shrink", "tsunami", "fire", "zombie", "lava", "meteor", "tornado", "lightning", "storm",
	"earthquake", "bomb", "ice", "volcano", "shark", "ghost", "bees", "dinosaur", "monster", "kill",
	"clown", "rain", "wind", "giant", "gravity", "speed", "jump", "night", "fog", "acid",
	"laser", "black_hole", "heat", "snow", "alien", "dragon", "spider", "snake", "invisible", "fly",
	"teleport", "swap", "building", "city", "tree", "wall", "oof", "sky_letter", "tacos", "dance",
	"money", "cat", "dog", "chair", "robot", "banana", "jail", "magnet", "food", "hunger",
	"ban", "train", "boulder", "fart", "pirate", "bubble", "darkclone", "wizard", "fireworks", "king",
	"cow", "octopus", "jackbox", "circus", "frog", "worm", "slime", "medkit", "size", "shield",
	"gift", "conveyor", "launchpad", "zone", "pendulum", "dominoes", "sneeze", "sleep", "revive", "safehouse",
	"star", "peace", "helicopter", "house", "bed", "picnic", "ladder", "tower", "flowers", "mansion",
	"computer", "flood", "dry", "enxurrada", "epidemia", "gun", "melee", "ball", "box", "chicken",
	"mountain", "day", "hail", "umbrella", "chest", "car", "igloo", "sandstorm", "fountain", "anvil",
	"duck", "halloween", "pumpkin", "water", "hi", "love", "pig", "monkey", "bear", "lion",
	"wolf", "skeleton", "fish", "spikes", "quicksand", "tank", "airstrike", "nuke", "plane", "landmine",
	"saw", "cactus", "vampire", "devil", "angel", "slow", "dizzy", "mud", "oil", "glue",
	"heaven", "sky", "hell", "apocalypse", "nothing", "parachute", "table", "door", "lamp", "tv",
	"bridge", "island", "beach", "maze", "kite", "penguin", "crab", "rabbit", "rat", "crocodile",
	"ant", "mosquito", "unicorn", "werewolf", "mummy", "ninja", "santa", "whale", "bike", "bus",
	"67", "skibidi", "sigma", "bruh", "castle", "pyramid", "lighthouse", "barn", "treehouse", "playground",
	"church", "camping", "school", "windmill", "stadium", "jenga", "bouncycastle", "supermarket", "backrooms", "ferriswheel",
	"temple", "skatepark", "aquarium", "carousel", "gasstation", "hospital", "snowman", "cave", "museum", "stonehenge",
	"moai", "waterslide", "cinema", "basketball", "sandcastle", "minecraft", "gojo", "energy_blast", "time_stop", "domain",
	"snap", "falling_blocks", "ogre", "capybara", "hamster_ball", "troll", "bonk", "nokia", "error", "lucky_block",
	"animatronic", "verity", "moodeng", "diamond", "guest", "geyser", "upside_down", "nextbot", "walk", "spin",
	"laugh", "scream", "gg", "wow", "sorry", "please", "die", "fall", "push", "cry",
	"ok", "crazy", "what", "ez", "idk", "person", "angry", "win", "sit", "quiet",
	"reset", "afk", "idle", "paint", "mom", "up", "space", "button", "easter", "vomit",
	"ballerina", "chimpanzini", "firetruck", "firefighter", "piano", "cockroach", "elephant", "goose", "waterfall", "tung",
	"tralalero", "mrbeast", "book", "grass", "lego", "balloons", "cones", "tires", "sandbags", "bamboo",
	"clear", "retro", "desert", "christmas", "autumn", "graveyard", "farm", "neon", "swamp", "hat",
	"stairs", "jellyfish", "bowling", "trash", "jungle", "savanna", "western", "paper", "underwater", "prehistoric",
	"tundra", "matrix", "dream", "upside", "kitchen", "bathtub", "sheep", "satellite", "hypergamy", "scarecrow",
	"bush", "gnome", "greenhouse", "pinata", "fireflies", "confetti", "raft", "boat", "beanstalk", "fairy",
	"leprechaun", "zipline", "icecreamtruck", "rollercoaster", "gokart", "treasure", "teacups", "oasis", "festajunina", "churrasco",
	"pillows", "sunset", "naruto", "rasengan", "kaioken", "tanjiro", "bankai", "luffy", "saitama", "nani",
	"patapim", "lirili", "trippi", "sans", "pikachu", "btools", "sussy", "rizz", "chillguy", "siuuu",
	"neymar", "ohio", "herobrine", "spiderman", "sharingan", "nyan", "brookhaven", "roadroller", "arise", "rumbling",
	"supernova", "locust", "poo", "skinwalker", "normal", "me", "baby", "aura", "end", "horror",
	"scp", "hero", "dad", "doctor", "kingkong", "sirenhead", "slenderman", "deathnote", "seek", "reaper",
	"titanic", "zoo", "exit", "jesus", "roblox", "obby", "mahoraga", "doom", "godzilla", "noob",
	"fortnite", "hulk", "titan", "goku", "sonic", "superman", "ironman", "homelander", "god", "sukuna",
	"moon", "destruction", "chaos", "blind", "admin", "boss",
}

local function randomDisaster()
	return ALL_DISASTERS[math.random(1, #ALL_DISASTERS)]
end

-- Mastery words from ReplicatedStorage.Mastery.MasteryConfig.
local MASTERY_WORDS = { "tornado", "tsunami", "nuke", "black_hole", "monster", "dinosaur", "gojo", "hero", "earthquake", "kill" }
local MASTERY_CATEGORY = {
	tornado = "disasters",
	tsunami = "disasters",
	nuke = "weapons",
	black_hole = "disasters",
	monster = "monsters",
	dinosaur = "animals",
	gojo = "memes",
	hero = "memes",
	earthquake = "disasters",
	kill = "memes",
}
local masteryIndex = 0

local function fireDiaryPush(key, category, shown, times, isNew, rewardReady)
	local diary = ReplicatedStorage:FindFirstChild("Diary")
	local remotes = diary and diary:FindFirstChild("Remotes")
	local push = remotes and remotes:FindFirstChild("Push")
	if not (push and push:IsA("RemoteEvent")) then
		logOnce("diarypush_missing", "Diary.Remotes.Push not found", "warn")
		return false
	end
	local payload = {
		key = key,
		category = category,
		shown = shown or key,
		times = times or 2,
		isNew = isNew or false,
		rewardReady = rewardReady or false,
	}
	local fired = false
	if type(firesignal) == "function" then
		local ok = pcall(firesignal, push.OnClientEvent, "word", payload)
		fired = fired or ok
	end
	if type(getconnections) == "function" then
		local ok, connections = pcall(getconnections, push.OnClientEvent)
		if ok and type(connections) == "table" then
			for _, connection in ipairs(connections) do
				pcall(connection.Fire, connection, "word", payload)
				fired = true
			end
		end
	end
	logOnce("diarypush_" .. key, "diary push -> " .. key, "info")
	return fired
end

local nextWriteAt = 0
local function autoWriteStep()
	local word
	if Settings.AutoMastery then
		masteryIndex = masteryIndex % #MASTERY_WORDS + 1
		word = MASTERY_WORDS[masteryIndex]
	elseif Settings.AutoWriteWorst then
		word = randomDisaster()
	else
		word = Settings.WriteWord
	end
	if type(word) ~= "string" or word == "" then
		return
	end
	local now = os.clock()
	if now < nextWriteAt then
		return
	end
	nextWriteAt = now + 1.5
	local remote = findWriteRemote()
	if not remote then
		logOnce("write_nomote", "auto write: no writer submit remote found (see WriterRemotes log)", "warn")
		return
	end
	pcall(function()
		remote:FireServer(word)
	end)
	logOnce("write_word_" .. word, "auto write -> " .. word, "info")
	if Settings.AutoMastery then
		fireDiaryPush(word, MASTERY_CATEGORY[word] or "disasters", word, 2, false, true)
	end
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
		logOnce("struggle_missing", "auto struggle: GrabRemotes.Struggle not found", "warn")
		return
	end
	pcall(function()
		struggle:FireServer()
	end)
	logOnce("struggle_ok", "auto struggle: struggling out of grabs", "info")
end

local function fireWriterPrompt(writerId, seconds, slot)
	local writerRemotes = ReplicatedStorage:FindFirstChild("WriterRemotes")
	local prompt = writerRemotes and writerRemotes:FindFirstChild("WriterPrompt")
	if not (prompt and prompt:IsA("RemoteEvent")) then
		logOnce("prompt_missing", "WriterRemotes.WriterPrompt not found", "warn")
		return false
	end
	local args = { writerId or 19, seconds or 30, slot or 1 }
	local fired = false
	if type(firesignal) == "function" then
		local ok = pcall(function()
			firesignal(prompt.OnClientEvent, table.unpack(args))
		end)
		fired = fired or ok
	end
	if type(getconnections) == "function" then
		local ok, connections = pcall(getconnections, prompt.OnClientEvent)
		if ok and type(connections) == "table" then
			for _, connection in ipairs(connections) do
				pcall(function()
					connection.Fire(table.unpack(args))
				end)
				fired = true
			end
		end
	end
	logOnce("prompt_ok", "writer prompt: fired the WriterPrompt signal", "info")
	return fired
end

---------------------------------------------------------------------
-- Player helpers
---------------------------------------------------------------------

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
		logOnce("ragdoll_ok", "anti-ragdoll: forcing the getting-up state", "info")
	end
end

-- The game ragdolls you from the server through RagdollRemotes.RagdollState.
-- Our connection is added after the game's, so it can undo the physics state.
task.spawn(function()
	local ragdollRemotes = ReplicatedStorage:WaitForChild("RagdollRemotes", 15)
	local ragdollState = ragdollRemotes and ragdollRemotes:WaitForChild("RagdollState", 15)
	if not running then
		return
	end
	if not (ragdollState and ragdollState:IsA("RemoteEvent")) then
		logOnce("ragdoll_remote_missing", "anti-ragdoll: RagdollRemotes.RagdollState not found", "warn")
		return
	end
	trackConnection(ragdollState.OnClientEvent:Connect(function(state)
		logOnce("ragdoll_event", "anti-ragdoll: RagdollState event received (" .. tostring(state) .. ")", "info")
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
		logOnce("ragdoll_blocked", "anti-ragdoll: countered a RagdollState event", "info")
	end))
	logOnce("ragdoll_hooked", "anti-ragdoll: RagdollState is being countered", "info")
end)

local function infiniteJump()
	local humanoid = getHumanoid()
	if humanoid and humanoid:GetState() == Enum.HumanoidStateType.Freefall then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end

---------------------------------------------------------------------
-- Item roll
---------------------------------------------------------------------

local nextRollAt = 0
local function autoRoll()
	local now = os.clock()
	if now < nextRollAt then
		return
	end
	nextRollAt = now + 2
	local ok = fireRemote("Spin")
	if not ok then
		itemRequestInvoke("spin")
	end
	logOnce("roll_ok", "auto roll: firing the item spin", "info")
end

---------------------------------------------------------------------
-- Rayfield Gen2 UI
---------------------------------------------------------------------

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()
local window = Rayfield:CreateWindow({
    name = "Surve Your Ideas",
    subtitle = "VeloxHub | by Ovei",
    sidebarLayout = true,
    configuration = {
        autoSave = true,
        autoLoad = false,
        fileName = "VeloxHub_SurveYourIdeas",
    },
})

local Player = window:CreateTab({ name = "Player", icon = "user-round" })
local Visuals = window:CreateTab({ name = "Visuals", icon = "eye" })
local Words = window:CreateTab({ name = "Words", icon = "type" })
local Items = window:CreateTab({ name = "Items", icon = "package" })
local Farm = window:CreateTab({ name = "Farm", icon = "coins" })
local Survival = window:CreateTab({ name = "Survival", icon = "shield" })
local System = window:CreateTab({ name = "System", icon = "settings" })

Player:CreateSection({ name = "Movement" })
Player:CreateToggle({
    name = "Speed Boost",
    value = false,
    flag = "syi_speed_on",
    callback = function(value)
        Settings.SpeedOn = value
        applySpeed()
    end,
})
Player:CreateSlider({
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
Player:CreateToggle({
    name = "Jump Boost",
    value = false,
    flag = "syi_jump_on",
    callback = function(value)
        Settings.JumpOn = value
        applyJump()
    end,
})
Player:CreateSlider({
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
Player:CreateToggle({
    name = "Infinite Jump",
    value = false,
    flag = "syi_infinite_jump",
    callback = function(value)
        Settings.InfiniteJump = value
    end,
})
Player:CreateToggle({
    name = "Unlimited Oxygen",
    value = false,
    flag = "syi_unlimited_oxygen",
    callback = function(value)
        Settings.UnlimitedOxygen = value
    end,
})
Player:CreateToggle({
    name = "Unlimited Stamina",
    value = false,
    flag = "syi_unlimited_stamina",
    callback = function(value)
        Settings.UnlimitedStamina = value
    end,
})
Player:CreateToggle({
    name = "Force Sprint",
    value = false,
    flag = "syi_sprint",
    callback = function(value)
        Settings.Sprint = value
    end,
})
Player:CreateToggle({
    name = "Anti-Ragdoll",
    value = false,
    flag = "syi_anti_ragdoll",
    callback = function(value)
        Settings.AntiRagdoll = value
    end,
})

Visuals:CreateSection({ name = "ESP" })
Visuals:CreateToggle({
    name = "Player ESP",
    value = false,
    flag = "syi_esp_player",
    callback = function(value)
        Settings.EspPlayer = value
    end,
})
Visuals:CreateToggle({
    name = "Creature ESP",
    value = false,
    flag = "syi_esp_creature",
    callback = function(value)
        Settings.EspCreature = value
    end,
})
Visuals:CreateToggle({
    name = "Coin ESP",
    value = false,
    flag = "syi_esp_coin",
    callback = function(value)
        Settings.EspCoin = value
    end,
})
Visuals:CreateToggle({
    name = "Item ESP",
    value = false,
    flag = "syi_esp_item",
    callback = function(value)
        Settings.EspItem = value
    end,
})
Visuals:CreateToggle({
    name = "Disaster ESP",
    value = false,
    flag = "syi_esp_disaster",
    callback = function(value)
        Settings.EspDisaster = value
    end,
})
Visuals:CreateToggle({
    name = "Boss ESP",
    value = false,
    flag = "syi_esp_boss",
    callback = function(value)
        Settings.EspBoss = value
    end,
})
Visuals:CreateSlider({
    name = "ESP Distance",
    range = { 50, 2000 },
    increment = 50,
    value = 500,
    suffix = " studs",
    flag = "syi_esp_distance",
    callback = function(value)
        Settings.EspDistance = value
    end,
})

Words:CreateSection({ name = "Manual Word" })
Words:CreateInput({
    name = "Word",
    placeholder = "/god",
    value = "/god",
    callback = function(value)
        if type(value) == "string" then
            Settings.WriteWord = value
        end
    end,
})
Words:CreateButton({
    name = "Trigger Word",
    callback = function()
        local word = Settings.WriteWord
        if type(word) ~= "string" or word == "" then
            window:Notify({ title = "Missing word", content = "Enter a word first." })
            return
        end
        if fireRemote("WordTyped", word) or fireRemote("SubmitWord", word) or fireRemote("MetaWord", word) then
            window:Toast({ title = "Word submitted" })
        else
            window:Notify({ title = "Remote unavailable", content = "No supported word remote was found." })
        end
    end,
})
Words:CreateText({
    name = "Known words",
    text = "/admin, /reset, /chaos, /god, /double, /secret, /lag, /undo, /ghost, /jackpot",
})
Words:CreateSection({ name = "Auto Write" })
Words:CreateToggle({
    name = "Auto Write",
    value = false,
    flag = "syi_auto_write",
    callback = function(value)
        Settings.AutoWrite = value
    end,
})
Words:CreateToggle({
    name = "Random Diary Word",
    value = false,
    flag = "syi_write_worst",
    callback = function(value)
        Settings.AutoWriteWorst = value
    end,
})
Words:CreateToggle({
    name = "Auto Mastery Fill",
    value = false,
    flag = "syi_auto_mastery",
    callback = function(value)
        Settings.AutoMastery = value
    end,
})
Words:CreateText({
    name = "Mastery words",
    text = "tornado, tsunami, nuke, black_hole, monster, dinosaur, gojo, hero, earthquake, kill",
})
Words:CreateButton({
    name = "Force All Mastery Pushes",
    callback = function()
        for _, word in ipairs(MASTERY_WORDS) do
            fireDiaryPush(word, MASTERY_CATEGORY[word] or "disasters", word, 2, false, true)
        end
        window:Toast({ title = "Mastery push attempted" })
    end,
})
Words:CreateButton({
    name = "Force Writer Prompt",
    callback = function()
        fireWriterPrompt(19, 30, 1)
    end,
})
Words:CreateToggle({
    name = "Auto Writer Prompt",
    value = false,
    flag = "syi_auto_prompt",
    callback = function(value)
        Settings.AutoWriterPrompt = value
    end,
})

Items:CreateSection({ name = "Item Roll" })
Items:CreateToggle({
    name = "Auto Roll",
    value = false,
    flag = "syi_auto_roll",
    callback = function(value)
        Settings.AutoRoll = value
    end,
})

Farm:CreateSection({ name = "Money" })
Farm:CreateToggle({
    name = "Coin Auto-Farm",
    value = false,
    flag = "syi_coin_farm",
    callback = function(value)
        Settings.CoinFarm = value
    end,
})
Farm:CreateSection({ name = "Items" })
Farm:CreateToggle({
    name = "Auto Use Item",
    value = false,
    flag = "syi_auto_use_item",
    callback = function(value)
        Settings.AutoUseItem = value
    end,
})
Farm:CreateDropdown({
    name = "Item to Use",
    options = itemNames,
    value = "None",
    flag = "syi_use_item",
    callback = function(value)
        Settings.UseItemId = itemNameToId[value]
    end,
})
Farm:CreateToggle({
    name = "Auto Carry",
    value = false,
    flag = "syi_auto_carry",
    callback = function(value)
        Settings.AutoCarry = value
    end,
})
Farm:CreateSection({ name = "Progress" })
Farm:CreateToggle({
    name = "Auto Revive",
    value = false,
    flag = "syi_auto_revive",
    callback = function(value)
        Settings.AutoRevive = value
    end,
})
Farm:CreateToggle({
    name = "Diary Auto-Claim",
    value = false,
    flag = "syi_auto_diary",
    callback = function(value)
        Settings.AutoClaimDiary = value
    end,
})

Survival:CreateSection({ name = "Hazards" })
Survival:CreateToggle({
    name = "Auto Struggle",
    value = false,
    flag = "syi_auto_struggle",
    callback = function(value)
        Settings.AutoStruggle = value
    end,
})
Survival:CreateToggle({
    name = "Hazard Warnings",
    value = false,
    flag = "syi_hazard_warn",
    callback = function(value)
        Settings.HazardWarn = value
    end,
})
Survival:CreateToggle({
    name = "Auto Dodge",
    value = false,
    flag = "syi_auto_dodge",
    callback = function(value)
        Settings.AutoDodge = value
    end,
})

System:CreateSection({ name = "Live Activity" })
local liveActivity = System:CreateText({
    name = "Live Activity",
    text = "Status: Initializing\nActive features: 0\nUptime: 00:00:00",
})

System:CreateSection({ name = "Runtime" })
System:CreateText({
    name = "Developer",
    text = "VeloxHub  |  Surve Your Ideas  |  Author: Ovei",
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

---------------------------------------------------------------------
-- Loops
---------------------------------------------------------------------

local startedAt = os.clock()
local activityKeys = {
    "SpeedOn", "JumpOn", "InfiniteJump", "Sprint", "AntiRagdoll",
    "EspPlayer", "EspCreature", "EspCoin", "EspItem", "EspDisaster", "EspBoss",
    "AutoRoll", "CoinFarm", "AutoRevive", "AutoCarry", "AutoClaimDiary",
    "AutoUseItem", "HazardWarn", "AutoDodge", "UnlimitedStamina",
    "UnlimitedOxygen", "AutoStruggle", "AutoWriterPrompt", "AutoWrite",
    "AutoWriteWorst", "AutoMastery",
}

task.spawn(function()
    while running do
        local active = {}
        for _, key in ipairs(activityKeys) do
            if Settings[key] then
                table.insert(active, key)
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
		task.wait(0.2)
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
		if Settings.AutoRoll then
			pcall(autoRoll)
		end
		task.wait(0.5)
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

local nextWriterPromptAt = 0
task.spawn(function()
	while running do
		if Settings.UnlimitedStamina then
			pcall(unlimitedStaminaStep)
		end
		if Settings.AutoWriterPrompt and os.clock() >= nextWriterPromptAt then
			nextWriterPromptAt = os.clock() + 3
			pcall(fireWriterPrompt, 19, 30, 1)
		end
		if Settings.UnlimitedOxygen then
			pcall(unlimitedOxygenStep)
		end
		if Settings.AutoStruggle then
			pcall(autoStruggleStep)
		end
		if Settings.AutoWrite or Settings.AutoWriteWorst or Settings.AutoMastery then
			pcall(autoWriteStep)
		end
		task.wait(0.2)
	end
end)

task.spawn(function()
	while running do
		if Settings.AutoUseItem then
			pcall(autoUseItemStep)
		end
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

---------------------------------------------------------------------
-- Shutdown
---------------------------------------------------------------------

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
    Settings.UseItemId = nil

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

    logMessage("[VeloxHub] script stopped and cleanup completed", "info")
    pcall(function()
        window:Notify({
            title = "Script stopped",
            content = "Background loops and tracked ESP objects have been cleaned up.",
        })
    end)
end

logMessage("[VeloxHub] Rayfield Gen2 interface loaded", "info")
