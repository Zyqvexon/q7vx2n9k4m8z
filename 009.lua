if not shared then
	return warn("No shared, no script.")
end

local MonkeyHub = {}

local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({ tasks = {} }, Maid)
end

function Maid:give(task)
	table.insert(self.tasks, task)
	return task
end

function Maid:clean()
	for index = #self.tasks, 1, -1 do
		local task = self.tasks[index]
		self.tasks[index] = nil
		local kind = typeof(task)
		if kind == "RBXScriptConnection" then
			task:Disconnect()
		elseif kind == "Instance" then
			pcall(task.Destroy, task)
		elseif kind == "function" then
			pcall(task)
		else
			pcall(function()
				task:Remove()
			end)
		end
	end
end

local LOBBY_PLACE_ID = 99409088950210
local MATCH_PLACE_ID = 115317125060158

local CONFIG = {
	REEXEC_SOURCE = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/primelyn123-jpg/monkey-hub/main/MonkeyHub.lua"))()',
	READY_TIMEOUT = 90,
	TICK_RATE = 0.08,
	BOSS_TICK_RATE = 0.03,
	SCAN_MAX = 4096,
	SCAN_RADIUS = 2000,
	ESP_MAX = 150,
	ESP_RADIUS = 600,
	BOSS_DISTANCE = 90,
	BOSS_RETREAT_DISTANCE = 120,
	RETREAT_HEALTH = 0.6,
	SKIP_METER_LIMIT = 0.85,
	SKIP_ENEMY_LIMIT = 400,
	SKIP_RESUME_ENEMIES = 300,
	FLIGHT_HEIGHT = 2.5,
	
	CHEST_REACH = 7,
	CHEST_TIMEOUT = 30,
	
	REMOTE_GAPS = { Vote = 1, GameAction = 10 },
}

local playersService = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local lightingService = game:GetService("Lighting")
local virtualUser = game:GetService("VirtualUser")
local pathfindingService = game:GetService("PathfindingService")

local localPlayer = playersService.LocalPlayer
local maid = Maid.new()
local Game = {}
local Library, Toggles, Options = nil, nil, nil
local Net = { last = {}, counts = {}, total = 0 }
local state = {
	zones = {},
	bossEvents = {},
	hazardSequence = 0,
	lastSkipScan = 0,
	lastStatus = 0,
	errors = 0,
}

local function newCrowd()
	return { x = {}, y = {}, z = {}, r = {}, hp = {}, id = {}, d = {} }
end

local crowd = newCrowd()
local skillCrowd = newCrowd()
local espCrowd = newCrowd()

local function safeRequire(module)
	local previous = getthreadidentity and getthreadidentity() or 8
	if setthreadidentity then
		setthreadidentity(2)
	end
	local ok, result = pcall(require, module)
	if setthreadidentity then
		setthreadidentity(previous)
	end
	if not ok then
		error(string.format("require %s failed: %s", module:GetFullName(), tostring(result)), 2)
	end
	return result
end

local function findModule(name)
	local scripts = localPlayer:FindFirstChild("PlayerScripts")
	local module = scripts and scripts:FindFirstChild(name, true)
	if module then
		return module
	end
	if not getloadedmodules then
		return nil
	end
	for _, loaded in getloadedmodules() do
		if loaded.Name == name then
			return loaded
		end
	end
	return nil
end

local function waitPath(root, path)
	local current = root
	for name in path:gmatch("[^%.]+") do
		current = current:WaitForChild(name, 15)
		assert(current, "missing " .. root.Name .. "." .. path)
	end
	return current
end

local function requireFolder(folder)
	local result = {}
	for _, module in folder:GetChildren() do
		if not module:IsA("ModuleScript") then
			continue
		end
		local ok, value = pcall(safeRequire, module)
		if ok then
			result[module.Name] = value
		end
	end
	return result
end

local function loadGame()
	local unitsModule = findModule("UnitViewController")
	local dataModule = findModule("DataController")
	assert(unitsModule and dataModule, "game controllers not found (game updated?)")
	Game.units = safeRequire(unitsModule)
	Game.data = safeRequire(dataModule)
	Game.patterns = safeRequire(waitPath(replicatedStorage, "Shared.Content.AoePatterns"))
	Game.bossDefinitions = requireFolder(waitPath(replicatedStorage, "Shared.Bosses.Definitions"))
	Game.waves = waitPath(replicatedStorage, "Shared.Waves")
	Game.bossesLive = waitPath(replicatedStorage, "Shared.Bosses.Live")
	Game.voteRemote = waitPath(Game.waves, "Vote")
	Game.gameActionRemote = waitPath(replicatedStorage, "Remotes.GameAction")
	Game.bossFxRemote = waitPath(replicatedStorage, "Shared.Bosses.Fx")
	Game.aoeRemote = waitPath(replicatedStorage, "Shared.Effects.Aoe")
	assert(type(Game.units.crowd) == "function", "UnitViewController.crowd missing (game updated?)")
end

function Net.fire(key, group, remote, ...)
	local now = os.clock()
	if now - (Net.last[key] or -math.huge) < CONFIG.REMOTE_GAPS[group] then
		return false
	end
	Net.last[key] = now
	Net.counts[group] = (Net.counts[group] or 0) + 1
	Net.total += 1
	remote:FireServer(...)
	return true
end

local function enabled(name)
	local toggle = Toggles and Toggles[name]
	return toggle ~= nil and toggle.Value == true
end

local function getCharacter()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return character, humanoid, root
end

local function crowdPoint(set, i)
	return Vector3.new(set.x[i], set.y[i], set.z[i])
end

local function addHazard(zone)
	state.hazardSequence += 1
	state.zones["persistent_" .. state.hazardSequence] = zone
end

local function hookHazards()
	maid:give(Game.bossFxRemote.OnClientEvent:Connect(function(id, _, event, attackName, data)
		local definition
		for _, live in Game.bossesLive:GetChildren() do
			if live:GetAttribute("Id") == id then
				definition = Game.bossDefinitions[live:GetAttribute("Definition")]
				break
			end
		end
		local attack = definition and definition.Attacks and definition.Attacks[attackName]
		if event == "Windup" then
			state.bossEvents[id] = { untilTime = os.clock() + 5, attack = attackName }
		elseif event == "Recovery" or event == "Cancel" or event == "Dead" then
			state.bossEvents[id] = nil
		end
		if type(data) ~= "table" then
			return
		end
		local now = workspace:GetServerTimeNow()
		if event == "Residue" and typeof(data.At) == "Vector3" then
			addHazard({ Position = data.At, Yaw = 0, Pattern = "Circle", Radius = data.Radius or 10, EndsAt = data.Ends or now + 6 })
		elseif event == "Acid" and type(data.Points) == "table" then
			for i = 1, #data.Points - 1 do
				addHazard({ Kind = "AcidSegment", A = data.Points[i], B = data.Points[i + 1], Width = data.Width or 20, EndsAt = data.Ends or now + 6 })
			end
		elseif event == "Charge" and typeof(data.At) == "Vector3" and typeof(data.Direction) == "Vector3" then
			local finish = data.At + data.Direction * (data.Distance or 50)
			local width = attack and attack.Aoe and attack.Aoe.Width or 24
			addHazard({ Kind = "AcidSegment", A = data.At, B = finish, Width = width, EndsAt = (data.Start or now) + (data.Duration or 1) + 0.5 })
		end
	end))
	maid:give(Game.aoeRemote.OnClientEvent:Connect(function(position, yaw, pattern, radius, endsAt, _, id, width)
		if typeof(position) == "Vector3" then
			state.zones[id] = { Position = position, Yaw = yaw, Pattern = pattern, Radius = radius, Width = width, EndsAt = endsAt + 0.4 }
			return
		end
		if type(position) ~= "number" then
			return
		end
		local zone = state.zones[position]
		if typeof(yaw) == "Vector3" and zone then
			zone.Position, zone.Yaw, zone.Radius = yaw, pattern, radius
		else
			state.zones[position] = nil
		end
	end))
end

local function dangerous(point, serverNow)
	local margin = state.bossId and 16 or 10
	if state.bossPoint then
		local delta = point - state.bossPoint
		if Vector3.new(delta.X, 0, delta.Z).Magnitude < (state.requiredBossDistance or CONFIG.BOSS_DISTANCE) - 8 then
			return true
		end
	end
	for id, zone in state.zones do
		if zone.EndsAt < serverNow then
			state.zones[id] = nil
			continue
		end
		if zone.Kind == "AcidSegment" then
			local segment = Vector3.new(zone.B.X - zone.A.X, 0, zone.B.Z - zone.A.Z)
			local delta = Vector3.new(point.X - zone.A.X, 0, point.Z - zone.A.Z)
			local length = segment:Dot(segment)
			local t = length > 0 and math.clamp(delta:Dot(segment) / length, 0, 1) or 0
			if (delta - segment * t).Magnitude < zone.Width * 0.5 + margin then
				return true
			end
		elseif zone.Kind == "AcidBox" then
			local localPoint = zone.CFrame:PointToObjectSpace(point)
			if math.abs(localPoint.X) < zone.Size.X * 0.5 + margin and math.abs(localPoint.Z) < zone.Size.Z * 0.5 + margin then
				return true
			end
		else
			local shape = Game.patterns.Patterns and Game.patterns.Patterns[zone.Pattern]
			if not shape then
				continue
			end
			local dx, dz = point.X - zone.Position.X, point.Z - zone.Position.Z
			local hit
			if shape.Kind == "Rect" then
				hit = Game.patterns.containsRect(dx, dz, zone.Yaw, zone.Radius, zone.Width or 10, -margin)
			else
				hit = Game.patterns.contains(shape, dx, dz, zone.Yaw, zone.Radius, -margin)
			end
			if hit then
				return true
			end
		end
	end
	return false
end

local function safePath(from, to, serverNow)
	local steps = math.max(2, math.ceil((to - from).Magnitude / 8))
	local leftDanger = not dangerous(from, serverNow)
	for i = 1, steps do
		local hit = dangerous(from:Lerp(to, i / steps), serverNow)
		if hit and leftDanger then
			return false
		end
		if not hit then
			leftDanger = true
		end
	end
	return leftDanger
end

local function dodge(root, destination)
	state.avoiding = false
	if not enabled("AvoidHazards") then
		return destination
	end
	local serverNow = workspace:GetServerTimeNow()
	local ahead = root.Position + root.AssemblyLinearVelocity * 0.7
	if not dangerous(root.Position, serverNow) and not dangerous(ahead, serverNow) and not dangerous(destination, serverNow)
		and safePath(root.Position, destination, serverNow) then
		return destination
	end
	local best, bestScore
	for _, radius in { 30, 60, 100, 160 } do
		for i = 1, 16 do
			local angle = i * math.pi / 8
			local point = root.Position + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			if dangerous(point, serverNow) or not safePath(root.Position, point, serverNow) then
				continue
			end
			local score = (point - destination).Magnitude + radius * 0.25
			if not bestScore or score < bestScore then
				best, bestScore = point, score
			end
		end
	end
	state.avoiding = true
	return best or root.Position
end

local function survival(root, humanoid, now)
	state.healthRatio = humanoid.Health / math.max(humanoid.MaxHealth, 1)
	if state.lastHealth and humanoid.Health < state.lastHealth - 3 then
		state.retreatUntil = now + 5
	end
	state.lastHealth = humanoid.Health
	local liveBosses = {}
	for _, live in Game.bossesLive:GetChildren() do
		local id = live:GetAttribute("Id")
		if id and (live:GetAttribute("Health") or 1) > 0 then
			liveBosses[id] = live
		end
	end
	state.bossId, state.bossPoint, state.bossName, state.bossHealth = nil, nil, nil, nil
	if next(liveBosses) then
		local count = Game.units.crowd(root.Position.X, root.Position.Z, CONFIG.SCAN_RADIUS, CONFIG.SCAN_MAX, crowd)
		local nearest = math.huge
		for i = 1, count do
			local live = liveBosses[crowd.id[i]]
			if not live then
				continue
			end
			local point = crowdPoint(crowd, i)
			local distance = (point - root.Position).Magnitude
			if distance < nearest then
				nearest = distance
				state.bossId, state.bossPoint = crowd.id[i], point
				state.bossName = live:GetAttribute("Definition")
				state.bossHealth = live:GetAttribute("Health")
			end
		end
	end
	local retreat = state.healthRatio < CONFIG.RETREAT_HEALTH or now < (state.retreatUntil or 0)
	state.requiredBossDistance = retreat and CONFIG.BOSS_RETREAT_DISTANCE or CONFIG.BOSS_DISTANCE
	if now - (state.lastAcidScan or 0) <= 0.4 then
		return
	end
	state.lastAcidScan = now
	local acid = workspace:FindFirstChild("BossAcid")
	if not acid then
		return
	end
	for _, part in acid:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 0.95 then
			state.zones[part] = { Kind = "AcidBox", CFrame = part.CFrame, Size = part.Size, EndsAt = workspace:GetServerTimeNow() + 0.7 }
		end
	end
end

local function adaptiveSkip(root, humanoid, now)
	if now - state.lastSkipScan < 0.4 then
		return
	end
	state.lastSkipScan = now
	local count = Game.units.crowd(root.Position.X, root.Position.Z, CONFIG.SCAN_RADIUS, CONFIG.SCAN_MAX, skillCrowd)
	local alive = 0
	local nearestPoint, nearestDistance = nil, math.huge
	for i = 1, count do
		if skillCrowd.hp[i] > 0 then
			alive += 1
			local point = crowdPoint(skillCrowd, i)
			local distance = (point - root.Position).Magnitude
			if distance < nearestDistance then
				nearestPoint, nearestDistance = point, distance
			end
		end
	end
	state.enemyPoint = nearestPoint
	state.liveEnemies = alive
	if not enabled("AutoSkip") then
		if state.skipOwned and localPlayer:GetAttribute("AutoSkip") == true then
			if Net.fire("Vote", "Vote", Game.voteRemote, "Auto", false) then
				state.skipOwned = false
			end
		end
		return
	end
	local progress = Game.waves:GetAttribute("BossProgress") or 0
	local bossFight = Game.waves:GetAttribute("BossState") == "Fight" or #Game.bossesLive:GetChildren() > 0
	if alive >= CONFIG.SKIP_ENEMY_LIMIT then
		state.skipCrowdPaused = true
	elseif alive < CONFIG.SKIP_RESUME_ENEMIES then
		state.skipCrowdPaused = false
	end
	local wanted = not bossFight
		and progress < CONFIG.SKIP_METER_LIMIT
		and not state.skipCrowdPaused
		and humanoid.Health / humanoid.MaxHealth >= 0.8
		and now >= (state.retreatUntil or 0)
	if (localPlayer:GetAttribute("AutoSkip") == true) == wanted then
		return
	end
	if Net.fire("Vote", "Vote", Game.voteRemote, "Auto", wanted) then
		state.skipOwned = true
	end
end

local function kite(humanoid, root)
	if enabled("FlightOrbit") then
		return
	end
	local destination
	if enabled("Kite") and state.enemyPoint then
		local distance = Options.KiteDistance.Value
		local delta = root.Position - state.enemyPoint
		local flat = Vector3.new(delta.X, 0, delta.Z)
		if flat.Magnitude < distance then
			local away = flat.Magnitude > 0.1 and flat.Unit or root.CFrame.LookVector
			destination = root.Position + away * (distance - flat.Magnitude + 6)
		end
	end
	if state.bossPoint then
		local delta = root.Position - state.bossPoint
		local flat = Vector3.new(delta.X, 0, delta.Z)
		if flat.Magnitude < state.requiredBossDistance then
			local away = flat.Magnitude > 0.1 and flat.Unit or root.CFrame.LookVector
			destination = state.bossPoint + away * state.requiredBossDistance
		end
	end
	local safe = dodge(root, destination or root.Position)
	if destination or state.avoiding then
		humanoid:MoveTo(safe)
		state.moving = true
	elseif state.moving then
		humanoid:Move(Vector3.zero)
		state.moving = false
	end
end

local Chest = { tried = {}, lastStart = 0 }

function Chest.isOpened(chest)
	for _, id in string.split(localPlayer:GetAttribute("OpenedChests") or "", ",") do
		if id == chest.Name then
			return true
		end
	end
	return false
end

function Chest.pick(root)
	local folder = workspace:FindFirstChild("Chests")
	local budget = (localPlayer:GetAttribute("Cash") or 0) - Options.ChestReserve.Value
	local best, bestPrompt, bestDistance
	for _, chest in folder and folder:GetChildren() or {} do
		local price = chest:GetAttribute("Price")
		local prompt = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
		if not price or price > budget or not prompt or not prompt.Enabled or chest:GetAttribute("Leaving") then
			continue
		end
		if Chest.isOpened(chest) or os.clock() < (Chest.tried[chest] or 0) then
			continue
		end
		local distance = (chest:GetPivot().Position - root.Position).Magnitude
		if not bestDistance or distance < bestDistance then
			best, bestPrompt, bestDistance = chest, prompt, distance
		end
	end
	return best, bestPrompt
end

function Chest.plan(chest, root)
	local path = pathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
	local ok = pcall(path.ComputeAsync, path, root.Position, chest:GetPivot().Position)
	Chest.waypoints = ok and path.Status == Enum.PathStatus.Success and path:GetWaypoints() or nil
	Chest.waypointIndex = 2
end

function Chest.step(humanoid, root, now)
	if not enabled("AutoChest") or state.bossId or (state.healthRatio or 1) < 0.6 or enabled("FlightOrbit") then
		Chest.target = nil
		return false
	end
	if not Chest.target then
		if now - Chest.lastStart < 3 then
			return false
		end
		local chest, prompt = Chest.pick(root)
		if not chest then
			return false
		end
		Chest.target, Chest.prompt, Chest.startedAt, Chest.lastStart = chest, prompt, now, now
		Chest.planning = true
		task.spawn(function()
			Chest.plan(chest, root)
			Chest.planning = false
		end)
	end
	local chest, prompt = Chest.target, Chest.prompt
	if not chest.Parent or not prompt.Enabled or Chest.isOpened(chest) or now - Chest.startedAt > CONFIG.CHEST_TIMEOUT then
		Chest.tried[chest] = os.clock() + 20
		Chest.target = nil
		return false
	end
	local goal = chest:GetPivot().Position
	if (goal - root.Position).Magnitude <= CONFIG.CHEST_REACH then
		humanoid:Move(Vector3.zero)
		prompt:InputHoldBegin()
		task.delay(0.1, function()
			prompt:InputHoldEnd()
		end)
		Chest.tried[chest] = os.clock() + 5
		Chest.target = nil
		return true
	end
	if Chest.planning then
		return true
	end
	local waypoints = Chest.waypoints
	local waypoint = waypoints and waypoints[Chest.waypointIndex]
	if waypoint and (waypoint.Position - root.Position).Magnitude < 4 then
		Chest.waypointIndex += 1
		waypoint = waypoints[Chest.waypointIndex]
	end
	if waypoint and waypoint.Action == Enum.PathWaypointAction.Jump then
		humanoid.Jump = true
	end
	humanoid:MoveTo(dodge(root, waypoint and waypoint.Position or goal))
	return true
end

local Flight = { obstacleState = {}, obstacleConnections = {} }

function Flight.disableObstacle(object)
	local original = Flight.obstacleState[object]
	if not original then
		original = {}
		Flight.obstacleState[object] = original
	end
	if object:IsA("BasePart") then
		if original.CanCollide == nil then
			original.CanCollide = object.CanCollide
		end
		object.CanCollide = false
	end
end

function Flight.restoreObstacles()
	for _, connection in Flight.obstacleConnections do
		connection:Disconnect()
	end
	table.clear(Flight.obstacleConnections)
	for object, original in Flight.obstacleState do
		for property, value in original do
			pcall(function()
				object[property] = value
			end)
		end
	end
	table.clear(Flight.obstacleState)
	Flight.noclipped = false
end

function Flight.stop()
	Flight.restoreObstacles()
	if Flight.velocity then
		Flight.velocity:Destroy()
	end
	if Flight.attachment then
		Flight.attachment:Destroy()
	end
	if Flight.root and Flight.root.Parent then
		Flight.root.AssemblyLinearVelocity = Vector3.zero
	end
	Flight.root, Flight.attachment, Flight.velocity, Flight.center = nil, nil, nil, nil
end

function Flight.flyTo(humanoid, root, destination)
	if Flight.root ~= root or not Flight.velocity or not Flight.velocity.Parent then
		Flight.stop()
		Flight.root = root
		Flight.attachment = Instance.new("Attachment")
		Flight.attachment.Parent = root
		Flight.velocity = Instance.new("LinearVelocity")
		Flight.velocity.Attachment0 = Flight.attachment
		Flight.velocity.RelativeTo = Enum.ActuatorRelativeTo.World
		Flight.velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		Flight.velocity.MaxForce = 1000000
		Flight.velocity.VectorVelocity = Vector3.zero
		Flight.velocity.Parent = root
		humanoid:Move(Vector3.zero)
	end
	if enabled("FlightNoclip") and not Flight.noclipped then
		Flight.noclipped = true
		for _, name in { "Map", "EdgeWalls", "Placements", "GlassKits" } do
			local folder = workspace:FindFirstChild(name)
			if not folder then
				continue
			end
			for _, object in folder:GetDescendants() do
				Flight.disableObstacle(object)
			end
			table.insert(Flight.obstacleConnections, folder.DescendantAdded:Connect(Flight.disableObstacle))
		end
	elseif not enabled("FlightNoclip") and Flight.noclipped then
		Flight.restoreObstacles()
	end
	local speed = Options.FlightSpeed.Value
	local delta = destination - root.Position
	Flight.velocity.VectorVelocity = delta.Magnitude > 0.6 and delta.Unit * math.min(speed, delta.Magnitude * 3) or Vector3.zero
end

function Flight.orbit(humanoid, root, now)
	local map = workspace:FindFirstChild("Map")
	if not map then
		Flight.stop()
		return
	end
	local speed = Options.FlightSpeed.Value
	if Flight.map ~= map or not Flight.center then
		local bounds, size = map:GetBoundingBox()
		local center = Vector3.new(bounds.Position.X, 0, bounds.Position.Z)
		local spawn = map:FindFirstChild("SpawnLocation")
		Flight.radius = math.clamp(math.min(size.X, size.Z) * 0.25, 35, 120)
		Flight.angle = math.atan2(root.Position.Z - center.Z, root.Position.X - center.X)
		Flight.height = (spawn and spawn.Position.Y or root.Position.Y) + CONFIG.FLIGHT_HEIGHT
		Flight.time = now
		Flight.center = center
		Flight.map = map
	end
	local dt = math.clamp(now - (Flight.time or now), 0, 0.2)
	Flight.time = now
	Flight.angle = (Flight.angle + speed / Flight.radius * dt) % (math.pi * 2)
	local ahead = Flight.angle + 0.18
	local destination = Flight.center + Vector3.new(math.cos(ahead) * Flight.radius, Flight.height, math.sin(ahead) * Flight.radius)
	if state.bossPoint then
		local delta = root.Position - state.bossPoint
		local angle = math.atan2(delta.Z, delta.X) + speed / state.requiredBossDistance * dt + 0.12
		destination = state.bossPoint + Vector3.new(math.cos(angle) * state.requiredBossDistance, 10, math.sin(angle) * state.requiredBossDistance)
	end
	Flight.flyTo(humanoid, root, dodge(root, destination))
end

local function replay(humanoid)
	local dead = localPlayer:GetAttribute("Dead") == true or (humanoid and humanoid.Health <= 0)
	local ended = Game.waves:GetAttribute("Phase") == "Complete"
	if not dead and not ended then
		return false
	end
	if not enabled("AutoReplay") then
		return true
	end
	local endGui = localPlayer.PlayerGui:FindFirstChild("End")
	local gameOver = endGui and endGui:FindFirstChild("GameOver")
	if not ended and not (endGui and endGui.Enabled and gameOver and gameOver.Visible) then
		return true
	end
	if enabled("ReExecute") and not state.teleportQueued then
		local queue = queue_on_teleport or getgenv().queueonteleport
		if queue then
			queue(CONFIG.REEXEC_SOURCE)
			state.teleportQueued = true
		end
	end
	Net.fire("Replay", "GameAction", Game.gameActionRemote, "Replay")
	return true
end

local function formatNumber(value)
	local digits = string.format("%.0f", math.max(0, tonumber(value) or 0))
	return (digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function updateStatus(now)
	if now - state.lastStatus < 0.5 or not state.statusLabel then
		return
	end
	state.lastStatus = now
	local ok, data = pcall(Game.data.GetData, Game.data)
	local gems = ok and data and data.Gems or 0
	state.statusLabel:Set(string.format(
		"Gems %s | run +%s\nWave %s | kills %s | monkeys %s\nBoss %s\nRemotes sent %d (vote %d, act %d)",
		formatNumber(gems),
		formatNumber(localPlayer:GetAttribute("RunGems")),
		tostring(Game.waves:GetAttribute("Number") or "-"),
		formatNumber(localPlayer:GetAttribute("Kills")),
		tostring(state.liveEnemies or 0),
		state.bossName and string.format("%s (%s hp)", state.bossName, tostring(state.bossHealth)) or "none",
		Net.total,
		Net.counts.Vote or 0,
		Net.counts.GameAction or 0
	))
end

local function update()
	local now = os.clock()
	local character, humanoid, root = getCharacter()
	updateStatus(now)
	if replay(humanoid) then
		Flight.stop()
		return
	end
	if not humanoid or not root or humanoid.Health <= 0 then
		Flight.stop()
		return
	end
	if root.Anchored then
		Flight.stop()
		return
	end
	survival(root, humanoid, now)
	adaptiveSkip(root, humanoid, now)
	if enabled("FlightOrbit") then
		Flight.orbit(humanoid, root, now)
	else
		if Flight.root then
			Flight.stop()
		end
		if not Chest.step(humanoid, root, now) then
			kite(humanoid, root)
		end
	end
end

local Esp = { dots = {} }

function Esp.init()
	if not Drawing then
		return
	end
	for i = 1, CONFIG.ESP_MAX do
		local dot = Drawing.new("Circle")
		dot.Filled = true
		dot.NumSides = 12
		dot.Thickness = 1
		dot.Transparency = 1
		dot.Visible = false
		Esp.dots[i] = maid:give(dot)
	end
	Esp.boss = maid:give(Drawing.new("Text"))
	Esp.boss.Center = true
	Esp.boss.Outline = true
	Esp.boss.Size = 18
	Esp.boss.Color = Color3.fromRGB(255, 80, 80)
	Esp.boss.Visible = false
end

function Esp.hide(from)
	for i = from, #Esp.dots do
		Esp.dots[i].Visible = false
	end
end

function Esp.render()
	if not Drawing or not Esp.boss then
		return
	end
	local camera = workspace.CurrentCamera
	if not enabled("MonkeyEsp") or not camera then
		Esp.hide(1)
	else
		local focus = camera.CFrame.Position
		local count = Game.units.crowd(focus.X, focus.Z, CONFIG.ESP_RADIUS, CONFIG.ESP_MAX, espCrowd)
		local color = Options.EspColor and Options.EspColor.Value or Color3.fromRGB(255, 200, 60)
		local used = 0
		for i = 1, count do
			if espCrowd.hp[i] <= 0 then
				continue
			end
			local screen, onScreen = camera:WorldToViewportPoint(crowdPoint(espCrowd, i))
			if not onScreen then
				continue
			end
			used += 1
			local dot = Esp.dots[used]
			dot.Position = Vector2.new(screen.X, screen.Y)
			dot.Radius = math.clamp(300 / math.max(screen.Z, 1), 2, 9)
			dot.Color = espCrowd.id[i] == state.bossId and Color3.fromRGB(255, 60, 60) or color
			dot.Visible = true
		end
		Esp.hide(used + 1)
	end
	if not enabled("BossEsp") or not camera or not state.bossPoint then
		Esp.boss.Visible = false
		return
	end
	local screen, onScreen = camera:WorldToViewportPoint(state.bossPoint + Vector3.new(0, 8, 0))
	Esp.boss.Visible = onScreen
	Esp.boss.Position = Vector2.new(screen.X, screen.Y)
	Esp.boss.Text = string.format("%s  %s hp", tostring(state.bossName), tostring(state.bossHealth))
end

local Misc = { lighting = nil }

function Misc.setFullbright(on)
	if on and not Misc.lighting then
		Misc.lighting = {
			Brightness = lightingService.Brightness,
			ClockTime = lightingService.ClockTime,
			FogEnd = lightingService.FogEnd,
			GlobalShadows = lightingService.GlobalShadows,
		}
		lightingService.Brightness = 3
		lightingService.ClockTime = 14
		lightingService.FogEnd = 1000000
		lightingService.GlobalShadows = false
	elseif not on and Misc.lighting then
		for property, value in Misc.lighting do
			lightingService[property] = value
		end
		Misc.lighting = nil
	end
end

function Misc.init()
	maid:give(localPlayer.Idled:Connect(function()
		if not enabled("AntiAfk") then
			return
		end
		virtualUser:CaptureController()
		virtualUser:ClickButton2(Vector2.new(0, 0))
	end))
	maid:give(userInputService.JumpRequest:Connect(function()
		if not enabled("InfiniteJump") then
			return
		end
		local _, humanoid = getCharacter()
		if humanoid then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end))
	maid:give(runService.Heartbeat:Connect(function()
		local _, humanoid = getCharacter()
		if not humanoid then
			return
		end
		if enabled("WalkSpeed") then
			Misc.baseSpeed = Misc.baseSpeed or humanoid.WalkSpeed
			humanoid.WalkSpeed = Options.WalkSpeedValue.Value
		elseif Misc.baseSpeed then
			humanoid.WalkSpeed = Misc.baseSpeed
			Misc.baseSpeed = nil
		end
	end))
end

local ESP_COLORS = {
	Gold = Color3.fromRGB(255, 200, 60),
	Red = Color3.fromRGB(255, 70, 90),
	Cyan = Color3.fromRGB(0, 212, 255),
	Purple = Color3.fromRGB(124, 92, 255),
	Green = Color3.fromRGB(80, 230, 130),
}

local function buildUi()
	Toggles, Options = {}, {}

	local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()
	local window = Rayfield:CreateWindow({
		name = "Monkey Hub",
		subtitle = "Survive a Million Monkeys",
		theme = "cobalt",
		sidebarLayout = true,
		profile = "Survive a Million Monkeys",
		configuration = {
			autoSave = true,
			autoLoad = true,
			fileName = "MonkeyHub",
			customFolder = "MonkeyHub",
		},
	})

	Library = {
		Notify = function(_, message, duration)
			window:Notify({
				title = "Monkey Hub",
				content = tostring(message),
				duration = duration or 4,
			})
		end,
		Unload = function()
			window:Unload()
		end,
	}

	local function addToggle(tab, idx, cfg)
		local entry = { Value = cfg.Default == true }
		Toggles[idx] = entry
		tab:CreateToggle({
			name = cfg.Risky and (cfg.Text .. " (risky)") or cfg.Text,
			value = entry.Value,
			flag = idx,
			callback = function(value)
				entry.Value = value == true
				if cfg.Callback then
					cfg.Callback(entry.Value)
				end
			end,
		})
	end

	local function addSlider(tab, idx, cfg)
		local entry = { Value = cfg.Default, Raw = cfg.Default }
		Options[idx] = entry
		tab:CreateSlider({
			name = cfg.Text,
			range = { cfg.Min, cfg.Max },
			increment = cfg.Increment or 1,
			value = cfg.Default,
			flag = idx,
			callback = function(value)
				entry.Value, entry.Raw = value, value
			end,
		})
	end

	local function addDropdown(tab, idx, cfg)
		local names = cfg.Values
		local selected = names[cfg.Default or 1]
		local entry = {
			Value = cfg.Map and cfg.Map[selected] or selected,
			Raw = selected,
		}
		Options[idx] = entry
		tab:CreateDropdown({
			name = cfg.Text,
			options = names,
			value = selected,
			flag = idx,
			callback = function(value)
				local name = type(value) == "table" and value[1] or value
				if not name then
					return
				end
				entry.Raw = name
				entry.Value = cfg.Map and cfg.Map[name] or name
			end,
		})
	end

	window:CreateSection({ name = "Gameplay" })

	local survivalTab = window:CreateTab({ name = "Survival" })
	survivalTab:CreateSection({ name = "Dodging" })
	addToggle(survivalTab, "AvoidHazards", { Text = "Dodge boss attacks / acid", Default = false })
	addToggle(survivalTab, "Kite", { Text = "Kite the swarm (walk)", Default = false })
	addSlider(survivalTab, "KiteDistance", { Text = "Kite distance", Default = 22, Min = 8, Max = 60 })
	survivalTab:CreateSection({ name = "Flight" })
	addToggle(survivalTab, "FlightOrbit", { Text = "Flight orbit farm", Default = false, Risky = true })
	addToggle(survivalTab, "FlightNoclip", { Text = "Noclip while flying", Default = false, Risky = true })
	addSlider(survivalTab, "FlightSpeed", { Text = "Flight speed", Default = 40, Min = 16, Max = 64 })

	local progressTab = window:CreateTab({ name = "Progress" })
	progressTab:CreateSection({ name = "Waves" })
	addToggle(progressTab, "AutoSkip", { Text = "Smart wave skip", Default = false })
	progressTab:CreateSection({ name = "Loot" })
	addToggle(progressTab, "AutoChest", { Text = "Auto open chests (walks there)", Default = false })
	addSlider(progressTab, "ChestReserve", { Text = "Keep cash reserve", Default = 0, Min = 0, Max = 2000 })
	progressTab:CreateSection({ name = "Runs" })
	addToggle(progressTab, "AutoReplay", { Text = "Auto replay", Default = false })
	addToggle(progressTab, "ReExecute", { Text = "Re-run hub after replay teleport", Default = true })

	local statusTab = window:CreateTab({ name = "Status" })
	statusTab:CreateSection({ name = "Run" })
	state.statusLabel = statusTab:CreateText({ name = "Run status", text = "Loading..." })

	window:CreateSection({ name = "Visuals" })

	local espTab = window:CreateTab({ name = "ESP" })
	espTab:CreateSection({ name = "Monkeys" })
	addToggle(espTab, "MonkeyEsp", { Text = "Monkey ESP", Default = false })
	addDropdown(espTab, "EspColor", {
		Text = "Monkey color",
		Values = { "Gold", "Red", "Cyan", "Purple", "Green" },
		Default = 1,
		Map = ESP_COLORS,
	})
	espTab:CreateSection({ name = "Bosses" })
	addToggle(espTab, "BossEsp", { Text = "Boss ESP", Default = true })

	local worldTab = window:CreateTab({ name = "World" })
	worldTab:CreateSection({ name = "Lighting" })
	addToggle(worldTab, "Fullbright", { Text = "Fullbright", Default = false, Callback = Misc.setFullbright })

	window:CreateSection({ name = "Player" })

	local moveTab = window:CreateTab({ name = "Movement" })
	moveTab:CreateSection({ name = "Utility" })
	addToggle(moveTab, "AntiAfk", { Text = "Anti-AFK", Default = true })
	moveTab:CreateSection({ name = "Movement" })
	addToggle(moveTab, "WalkSpeed", { Text = "Walk speed", Default = false, Risky = true })
	addSlider(moveTab, "WalkSpeedValue", { Text = "Speed", Default = 22, Min = 16, Max = 40 })
	addToggle(moveTab, "InfiniteJump", { Text = "Infinite jump", Default = false, Risky = true })

	window:CreateSection({ name = "System" })

	local settingsTab = window:CreateTab({ name = "Settings" })
	settingsTab:CreateSection({ name = "Menu" })
	settingsTab:CreateText({
		name = "Visibility",
		text = "Use the Rayfield hide pill to show or hide the menu.",
	})
	settingsTab:CreateButton({
		name = "Unload",
		callback = function()
			MonkeyHub.detach()
		end,
	})
end

local function waitForClient()
	local deadline = os.clock() + CONFIG.READY_TIMEOUT
	while localPlayer:GetAttribute("ClientReady") ~= true do
		assert(os.clock() < deadline, "ClientReady never set")
		task.wait(0.2)
	end
end

local function onInitError(message)
	warn("[MonkeyHub] init failed:", message, debug.traceback())
	pcall(MonkeyHub.detach)
end

function MonkeyHub.detach()
	if not MonkeyHub.running then
		return
	end
	MonkeyHub.running = false
	if state.skipOwned and Game.voteRemote and localPlayer:GetAttribute("AutoSkip") == true then
		pcall(Game.voteRemote.FireServer, Game.voteRemote, "Auto", false)
	end
	pcall(Flight.stop)
	pcall(Misc.setFullbright, false)
	maid:clean()
	if Library then
		pcall(Library.Unload, Library)
	end
end

function MonkeyHub.init()
	assert(game.PlaceId == MATCH_PLACE_ID, game.PlaceId == LOBBY_PLACE_ID and "start a run first; the hub runs inside a match" or "wrong game")
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	waitForClient()
	loadGame()
	MonkeyHub.running = true
	hookHazards()
	buildUi()
	Esp.init()
	Misc.init()
	maid:give(runService.RenderStepped:Connect(Esp.render))
	local elapsed = 0
	maid:give(runService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < (state.bossId and CONFIG.BOSS_TICK_RATE or CONFIG.TICK_RATE) then
			return
		end
		elapsed = 0
		local ok, err = pcall(update)
		if ok then
			state.errors = 0
			return
		end
		state.errors += 1
		if state.errors <= 3 then
			warn("[MonkeyHub]", err)
		end
		if state.errors >= 10 then
			Library:Notify("Monkey Hub stopped after repeated errors: " .. tostring(err), 8)
			MonkeyHub.detach()
		end
	end))
	Library:Notify("Monkey Hub loaded. Use the Rayfield pill to hide or show the menu.", 5)
end

if shared.MonkeyHub then
	pcall(shared.MonkeyHub.detach)
end
shared.MonkeyHub = MonkeyHub

xpcall(MonkeyHub.init, onInitError)
