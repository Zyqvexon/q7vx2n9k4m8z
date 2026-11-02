local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local SoundService      = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

local Rayfield
local rayfieldOk, rayfieldResult = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/gen2"))()
end)

if rayfieldOk and type(rayfieldResult) == "table" and type(rayfieldResult.CreateWindow) == "function" then
    Rayfield = rayfieldResult
else
    error("Rayfield Gen2 could not be loaded. Check HTTP and loadstring support.")
end

local GAME = {
    rooms = {
        [1] = { name = "PILLAR HALL" },
        [2] = { name = "BROKEN WALKWAY" },
        [3] = { name = "SINKING PLATFORMS" },
        [4] = { name = "ROTATING BRIDGE" },
        [5] = { name = "MOVING PLATFORMS" },
        [6] = { name = "DRIFTING PLATFORMS" },
        [7] = { name = "MEMORY BRIDGE" },
        [8] = { name = "CRUSHING WALLS" },
        [9] = { name = "LOCKED EXIT" },
    },
}

local STATE_COLORS = {
    Patrol = Color3.fromRGB(80, 255, 150),
    Search = Color3.fromRGB(255, 210, 60),
    Hunt   = Color3.fromRGB(255, 140, 40),
    Chase  = Color3.fromRGB(255, 60, 60),
    Attack = Color3.fromRGB(255, 40, 180),
    Caught = Color3.fromRGB(200, 0, 255),
}

local gameRootCache
local function getGameRoot()
    if gameRootCache and gameRootCache.Parent == workspace then return gameRootCache end
    gameRootCache = workspace:FindFirstChild("StillWater")
    return gameRootCache
end

local function getListenerFolder()
    local root = getGameRoot()
    return root and root:FindFirstChild("Creatures")
end

local function getPickupFolder()
    local root = getGameRoot()
    return root and root:FindFirstChild("PebblePickups")
end

local cachedCharacter
local cachedHumanoid
local cachedRoot

local function getCharacter()
    local model = LocalPlayer.Character
    if model ~= cachedCharacter then
        cachedCharacter = model
        cachedHumanoid = nil
        cachedRoot = nil
    end
    return model
end

local function getHumanoid()
    local model = getCharacter()
    if not model then return nil end
    if cachedHumanoid and cachedHumanoid.Parent == model then return cachedHumanoid end
    cachedHumanoid = model:FindFirstChildOfClass("Humanoid")
    return cachedHumanoid
end

local function getRootPart()
    local model = getCharacter()
    if not model then return nil end
    if cachedRoot and cachedRoot.Parent == model then return cachedRoot end
    cachedRoot = model:FindFirstChild("HumanoidRootPart")
    return cachedRoot
end

local function getPlayerGui()
    return LocalPlayer:FindFirstChildOfClass("PlayerGui")
end

local function readGuiText(guiName, ...)
    local parent = getPlayerGui()
    local gui = parent and parent:FindFirstChild(guiName)
    if not gui then return nil end
    local node = gui
    for _, name in ipairs({ ... }) do
        node = node and node:FindFirstChild(name)
    end
    return node and node:IsA("TextLabel") and node.Text or nil
end

local function getStateColor(state)
    return STATE_COLORS[state] or Color3.fromRGB(180, 180, 200)
end

local function getDistance(position)
    local root = getRootPart()
    if not root or not position then return math.huge end
    return (position - root.Position).Magnitude
end

local function formatDistance(distance)
    if distance == math.huge then return "—" end
    return string.format("%d", math.floor(distance + 0.5))
end

local function getCurrentRoom()
    local root = getRootPart()
    if not root then return 0 end
    local z = root.Position.Z
    if z < 8 then return 0 end
    return math.clamp(math.floor((z + 8) / 830) + 1, 1, 9)
end

local CFG = {

    showListener        = true,
    showTeammates       = false,
    showPickups         = false,
    showPlatforms       = false,
    platformSafeOnly    = false,
    showExits           = false,
    showCode            = true,
    showMemoryNumbers   = false,

    highlights          = true,
    boxes               = true,
    labels              = true,
    labelDistance       = true,
    listenerTarget      = false,
    maxDistance         = 0,
    fillOpacity         = 0.55,
    boxOpacity          = 0.6,

    alarmEnabled        = false,
    alarmDistance       = 60,
    alarmFlash          = false,

    speedEnabled        = false,
    speedValue          = 30,
}

local SPEED_MIN = 24
local SPEED_MAX = 40

local CONNECTIONS = {}
local STOPPED = false

local function trackConnection(connection)
    if connection then table.insert(CONNECTIONS, connection) end
    return connection
end

local function disconnectAll()
    STOPPED = true
    for _, connection in ipairs(CONNECTIONS) do
        pcall(function() connection:Disconnect() end)
    end
    CONNECTIONS = {}
end

do
    local environment = getgenv and getgenv()
    local previous = environment and (environment.VeloxHub or environment.StillWaterHub or environment["Rob" .. "script"])
    if previous and previous.unload then
        pcall(previous.unload)
    end
end

local visuals = {}

local HIGHLIGHT_BUDGET = 240
local highlightCount = 0
local MARKS_NAME = "VeloxHubDontSplashMarks"
local marksFolder

local function getMarksFolder()
    if marksFolder and marksFolder.Parent then return marksFolder end
    local existing = workspace:FindFirstChild(MARKS_NAME)
    if not existing then
        existing = Instance.new("Folder")
        existing.Name = MARKS_NAME
        existing.Parent = workspace
    end
    marksFolder = existing
    return marksFolder
end

local function isWithinEspRange(position)
    if CFG.maxDistance <= 0 then return true end
    local root = getRootPart()
    if not root or not position then return false end
    local offset = position - root.Position
    local limit = CFG.maxDistance * CFG.maxDistance
    return offset:Dot(offset) <= limit
end

local function createHighlight(part, color)
    if highlightCount >= HIGHLIGHT_BUDGET then return nil end
    local highlight = Instance.new("Highlight")
    highlight.Name = "VeloxHubHighlight"
    highlight.Adornee = part
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = color
    highlight.FillTransparency = CFG.fillOpacity
    highlight.OutlineColor = color
    highlight.OutlineTransparency = 0.1
    highlight.Parent = getMarksFolder()
    highlightCount = highlightCount + 1
    return highlight
end

local function removeHighlight(entry)
    if not entry or not entry.hl then return end
    entry.hl:Destroy()
    entry.hl = nil
    highlightCount = math.max(0, highlightCount - 1)
end

local function createBoxAdornment(part, color, transparency)
    local adornment = Instance.new("BoxHandleAdornment")
    adornment.Name = "VeloxHubBox"
    adornment.Adornee = part
    adornment.Size = part.Size + Vector3.new(0.08, 0.08, 0.08)
    adornment.Color3 = color
    adornment.Transparency = transparency or CFG.boxOpacity
    adornment.AlwaysOnTop = true
    adornment.ZIndex = 2
    adornment.Parent = getMarksFolder()
    return adornment
end

local function createLabelGui(part, offsetY, size, worldOffset)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "VeloxHubTag"
    billboard.Size = size or UDim2.fromOffset(190, 36)
    if worldOffset then
        billboard.StudsOffsetWorldSpace = Vector3.new(0, offsetY or 3, 0)
    else
        billboard.StudsOffset = Vector3.new(0, offsetY or 3, 0)
    end
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = CFG.maxDistance > 0 and CFG.maxDistance or 10000
    billboard.LightInfluence = 0
    billboard.Adornee = part
    billboard.Parent = getMarksFolder()

    local card = Instance.new("Frame")
    card.Name = "Card"
    card.Size = UDim2.fromScale(1, 1)
    card.BackgroundColor3 = Color3.fromRGB(13, 18, 29)
    card.BackgroundTransparency = 0.16
    card.BorderSizePixel = 0
    card.Parent = billboard

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(110, 170, 255)
    stroke.Thickness = 1
    stroke.Transparency = 0.18
    stroke.Parent = card

    local label = Instance.new("TextLabel")
    label.Name = "Text"
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(6, 2)
    label.Size = UDim2.new(1, -12, 1, -4)
    label.Font = Enum.Font.GothamSemibold
    label.TextSize = 14
    label.TextWrapped = true
    label.TextColor3 = Color3.fromRGB(245, 248, 255)
    label.TextStrokeTransparency = 0.8
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.RichText = true
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Text = ""
    label.Parent = card

    local constraint = Instance.new("UITextSizeConstraint")
    constraint.MinTextSize = 10
    constraint.MaxTextSize = 16
    constraint.Parent = label

    return billboard, label, card, stroke
end

local function removeLabelGui(entry)
    if entry.bb then entry.bb:Destroy() end
    entry.bb, entry.label, entry.card, entry.cardStroke = nil, nil, nil, nil
end

local function removeVisual(part)
    local entry = visuals[part]
    if not entry then return end
    removeHighlight(entry)
    if entry.box then entry.box:Destroy() end
    removeLabelGui(entry)
    if entry.marker then entry.marker:Destroy() end
    visuals[part] = nil
end

local function updateLabelDistance()
    local maxDistance = CFG.maxDistance > 0 and CFG.maxDistance or 10000
    for _, entry in pairs(visuals) do
        if entry.bb and entry.bb.MaxDistance ~= maxDistance then
            entry.bb.MaxDistance = maxDistance
        end
    end
end

local function getOrCreateVisual(part)
    local entry = visuals[part]
    if not entry then

        entry = { part = part }
        visuals[part] = entry
    else
        entry.part = part
    end
    return entry
end

local function cleanupVisuals()
    for part, entry in pairs(visuals) do
        if not part.Parent then
            removeHighlight(entry)
            if entry.box then entry.box:Destroy() end
            removeLabelGui(entry)
            if entry.marker then entry.marker:Destroy() end
            visuals[part] = nil
        end
    end
end

local function removeVisualsByType(tag)
    for part, entry in pairs(visuals) do
        if entry.tag == tag then removeVisual(part) end
    end
end

local function applyHighlight(entry, color)
    if not CFG.highlights then
        removeHighlight(entry)
        return
    end
    if not entry.hl then entry.hl = createHighlight(entry.part, color) end
    if not entry.hl then return end
    local highlight = entry.hl
    if highlight.FillColor ~= color then highlight.FillColor = color end
    if highlight.OutlineColor ~= color then highlight.OutlineColor = color end
    if highlight.FillTransparency ~= CFG.fillOpacity then highlight.FillTransparency = CFG.fillOpacity end
    if highlight.OutlineTransparency ~= 0.06 then highlight.OutlineTransparency = 0.06 end
end

local function applyBox(entry, color, transparency)
    if not CFG.boxes then
        if entry.box then entry.box:Destroy(); entry.box = nil end
        return
    end
    if entry.box and not entry.box.Parent then entry.box = nil end
    if not entry.box then
        entry.box = createBoxAdornment(entry.part, color, transparency)
        entry.boxBaseTransparency = transparency
    else
        if entry.box.Color3 ~= color then entry.box.Color3 = color end
        local targetSize = entry.part.Size + Vector3.new(0.08, 0.08, 0.08)
        if entry.box.Size ~= targetSize then entry.box.Size = targetSize end
        local targetTransparency = transparency or CFG.boxOpacity
        if entry.box.Transparency ~= targetTransparency then entry.box.Transparency = targetTransparency end
        entry.boxBaseTransparency = transparency
    end
end

local listenerCache = { at = 0, folder = nil, list = {} }

local function getListeners(force)
    local now = os.clock()
    local folder = getListenerFolder()
    if not force and folder == listenerCache.folder and now - listenerCache.at < 0.18 then
        return listenerCache.list
    end

    for index = #listenerCache.list, 1, -1 do
        listenerCache.list[index] = nil
    end

    if folder then
        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("BasePart") then
                listenerCache.list[#listenerCache.list + 1] = child
            end
        end
    end

    listenerCache.folder = folder
    listenerCache.at = now
    return listenerCache.list
end

local function refreshListenerEsp()
    if not CFG.showListener then
        removeVisualsByType("listener")
        return
    end

    for _, part in ipairs(getListeners()) do
        if isWithinEspRange(part.Position) then
            local entry = getOrCreateVisual(part)
            entry.tag = "listener"
            entry.part = part

            local state = tostring(part:GetAttribute("State") or "?")
            local color = getStateColor(state)
            local red   = math.floor(color.R * 255)
            local green = math.floor(color.G * 255)
            local blue  = math.floor(color.B * 255)

            applyHighlight(entry, color)
            if entry.cardStroke and entry.cardStroke.Color ~= color then entry.cardStroke.Color = color end
            if not entry.hl then applyBox(entry, color, 0.45) end

            if CFG.labels then
                if not entry.bb then
                    entry.bb, entry.label, entry.card, entry.cardStroke = createLabelGui(part, 4, UDim2.fromOffset(220, 46))
                end
                local room = tostring(part:GetAttribute("Room") or "?")
                local tail = CFG.labelDistance
                    and string.format('<font color="rgb(%d,%d,%d)">%s</font> · %s studs',
                        red, green, blue, state, formatDistance(getDistance(part.Position)))
                    or string.format('<font color="rgb(%d,%d,%d)">%s</font>', red, green, blue, state)
                local text = string.format(
                    '<font color="rgb(%d,%d,%d)">LISTENER</font> <font color="rgb(200,200,200)">Room %s</font>\n%s',
                    red, green, blue, room, tail)
                if entry.label.Text ~= text then entry.label.Text = text end
            elseif entry.bb then
                removeLabelGui(entry)
            end

            local target = part:GetAttribute("Target")
            if CFG.listenerTarget and typeof(target) == "Vector3" then
                if not entry.marker or not entry.marker.Parent then
                    local marker = Instance.new("Part")
                    marker.Name = "VeloxHubTargetMarker"
                    marker.Shape = Enum.PartType.Ball
                    marker.Size = Vector3.new(2, 2, 2)
                    marker.Material = Enum.Material.Neon
                    marker.Anchored = true
                    marker.CanCollide = false
                    marker.CanQuery = false
                    marker.CanTouch = false
                    marker.Transparency = 0.35
                    marker.Parent = workspace
                    entry.marker = marker
                end
                entry.marker.Position = target
                entry.marker.Color = color
            elseif entry.marker then
                entry.marker:Destroy(); entry.marker = nil
            end
        else
            local entry = visuals[part]
            if entry and entry.tag == "listener" then removeVisual(part) end
        end
    end
end

local PLATFORM_TAGS = { "Platform", "IsPlatform", "Safe", "MemTile", "CanSink", "IsSinking", "Sinking", "Stable" }

local function getPlatformTag(part)
    for _, name in ipairs(PLATFORM_TAGS) do
        if part:GetAttribute(name) == true then return name end
    end
    return nil
end

local function collectPlatformParts()
    local list = {}
    local root = getGameRoot()
    if not root then return list end
    for _, room in ipairs(root:GetChildren()) do
        local gen = room:FindFirstChild("Gen")
        if gen then
            for _, part in ipairs(gen:GetChildren()) do
                if part:IsA("BasePart") and getPlatformTag(part) then
                    table.insert(list, part)
                end
            end
        end
    end
    return list
end

local platformCache = { at = 0, list = {} }

local function refreshPlatformEsp()
    if not CFG.boxes then

        for part, entry in pairs(visuals) do
            if entry.tag == "platform" then
                if entry.box then entry.box:Destroy(); entry.box = nil end
                if not entry.bb then visuals[part] = nil end
            end
        end
        return
    end

    if not (CFG.showPlatforms or CFG.showMemoryNumbers) then
        removeVisualsByType("platform")
        return
    end

    if (os.clock() - platformCache.at) > 3 then
        platformCache.list = collectPlatformParts()
        platformCache.at = os.clock()
    end

    for _, part in ipairs(platformCache.list) do
        if part.Parent then
            local safe   = part:GetAttribute("Safe") == true
            local memory = part:GetAttribute("MemTile") == true

            local allowed = CFG.showPlatforms
                and ((not CFG.platformSafeOnly) or safe or memory)
                or (CFG.showMemoryNumbers and memory)
            local show = allowed and isWithinEspRange(part.Position)

            if show then
                local entry = getOrCreateVisual(part)
                if not entry.box or entry.tag ~= "platform" then
                    local color = safe and Color3.fromRGB(70, 220, 255)
                        or (memory and Color3.fromRGB(200, 120, 255)
                            or Color3.fromRGB(110, 255, 160))

                    applyBox(entry, color)
                    entry.tag = "platform"
                end
            else
                local entry = visuals[part]
                if entry and entry.tag == "platform" then removeVisual(part) end
            end
        end
    end
end

local pickupCache = { at = 0, folder = nil, list = {} }

local function collectPickupParts()
    local now = os.clock()
    local folder = getPickupFolder()
    if folder ~= pickupCache.folder or now - pickupCache.at >= 0.8 then
        for index = #pickupCache.list, 1, -1 do
            pickupCache.list[index] = nil
        end
        if folder then
            for _, pile in ipairs(folder:GetChildren()) do
                for _, part in ipairs(pile:GetChildren()) do
                    if part:IsA("BasePart") then
                        pickupCache.list[#pickupCache.list + 1] = part
                    end
                end
            end
        end
        pickupCache.folder = folder
        pickupCache.at = now
    end
    return pickupCache.list
end

local function refreshPickupEsp()
    if not CFG.showPickups or not CFG.boxes then
        removeVisualsByType("pickup")
        return
    end

    for _, part in ipairs(collectPickupParts()) do
        if part.Parent and isWithinEspRange(part.Position) then
            local entry = getOrCreateVisual(part)
            if not entry.box or entry.tag ~= "pickup" then
                applyBox(entry, Color3.fromRGB(255, 225, 120), 0.3)
                entry.tag = "pickup"
            end
        else
            local entry = visuals[part]
            if entry and entry.tag == "pickup" then removeVisual(part) end
        end
    end
end

local function refreshPlayerEsp()
    if not CFG.showTeammates or (not CFG.highlights and not CFG.boxes) then
        removeVisualsByType("teammate")
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local model = player.Character
            local part = model and model:FindFirstChild("HumanoidRootPart")
            if part and isWithinEspRange(part.Position) then
                local entry = getOrCreateVisual(part)
                entry.tag = "teammate"
                applyHighlight(entry, Color3.fromRGB(110, 190, 255))
                if CFG.highlights and not entry.hl then
                    applyBox(entry, Color3.fromRGB(110, 190, 255), 0.4)
                elseif CFG.boxes and not CFG.highlights then
                    applyBox(entry, Color3.fromRGB(110, 190, 255), 0.4)
                end
                if CFG.labels then
                    if not entry.bb then
                        entry.bb, entry.label, entry.card, entry.cardStroke = createLabelGui(part, 3, UDim2.fromOffset(170, 30))
                    end
                    local playerColor = Color3.fromRGB(110, 190, 255)
                    if entry.cardStroke and entry.cardStroke.Color ~= playerColor then entry.cardStroke.Color = playerColor end
                    local text = string.format("%s · %s studs", player.DisplayName, formatDistance(getDistance(part.Position)))
                    if entry.label.Text ~= text then entry.label.Text = text end
                elseif entry.bb then
                    entry.bb:Destroy()
                    entry.bb, entry.label, entry.card, entry.cardStroke = nil, nil, nil, nil
                end
            else
                local entry = part and visuals[part]
                if entry and entry.tag == "teammate" then removeVisual(part) end
            end
        end
    end
end

local exitTargetCache = { root = nil, at = 0, list = {} }

local function getExitTargets(root)
    local now = os.clock()
    if root == exitTargetCache.root and now - exitTargetCache.at < 3 then
        return exitTargetCache.list
    end

    local targets = {}
    local function add(part, text, color)
        if part and part:IsA("BasePart") then
            targets[#targets + 1] = { part = part, text = text, color = color }
        end
    end

    for index = 1, 8 do
        local corridor = root:FindFirstChild("Corridor" .. index)
        add(corridor and corridor:FindFirstChild("Checkpoint" .. index),
            "CHECKPOINT " .. index, Color3.fromRGB(120, 220, 255))
    end

    local room9 = root:FindFirstChild("Room9_LockedExit")
    local shell9 = room9 and room9:FindFirstChild("Shell")
    add(shell9 and shell9:FindFirstChild("ExitDeck"), "ROOM 9 EXIT", Color3.fromRGB(255, 220, 90))
    add(room9 and room9:FindFirstChild("FinalDoor"), "FINAL DOOR", Color3.fromRGB(255, 220, 90))
    add(room9 and room9:FindFirstChild("DoorLamp"), "FINAL DOOR", Color3.fromRGB(255, 220, 90))

    local lobby = root:FindFirstChild("Lobby")
    local back = lobby and lobby:FindFirstChild("BackToLobby")
    add(back and back:FindFirstChild("DoorGlow"), "BACK TO LOBBY", Color3.fromRGB(180, 180, 255))

    exitTargetCache.root = root
    exitTargetCache.at = now
    exitTargetCache.list = targets
    return targets
end

local function refreshExitEsp()
    if not CFG.showExits then
        removeVisualsByType("exit")
        return
    end

    local root = getGameRoot()
    if not root then return end

    for _, item in ipairs(getExitTargets(root)) do
        if item.part.Parent and isWithinEspRange(item.part.Position) then
            local entry = getOrCreateVisual(item.part)
            entry.tag = "exit"
            applyHighlight(entry, item.color)
            if not entry.hl then applyBox(entry, item.color, 0.4) end
            if entry.cardStroke and entry.cardStroke.Color ~= item.color then entry.cardStroke.Color = item.color end
            if CFG.labels then
                if not entry.bb then

                    local offset = item.part.Size.Y * 0.5 + 2.5
                    entry.bb, entry.label, entry.card, entry.cardStroke = createLabelGui(item.part, offset, UDim2.fromOffset(170, 30), true)
                end
                local text = CFG.labelDistance
                    and string.format("%s · %s studs", item.text, formatDistance(getDistance(item.part.Position)))
                    or item.text
                if entry.label.Text ~= text then entry.label.Text = text end
                if entry.label.TextColor3 ~= item.color then entry.label.TextColor3 = item.color end
            elseif entry.bb then
                removeLabelGui(entry)
            end
        else
            local entry = visuals[item.part]
            if entry and entry.tag == "exit" then removeVisual(item.part) end
        end
    end
end

local function getDoorCode()
    local root = getGameRoot()
    local room = root and root:FindFirstChild("Room9_LockedExit")
    local gen = room and room:FindFirstChild("Gen")
    if not gen then return nil end

    local digits = {}
    for _, part in ipairs(gen:GetChildren()) do
        if part:IsA("BasePart") and part.Name == "CodeNumber" then
            local index = part:GetAttribute("CodeIndex")
            local text
            local surface = part:FindFirstChildOfClass("SurfaceGui")
            if surface then
                for _, descendant in ipairs(surface:GetDescendants()) do
                    if descendant:IsA("TextLabel") and descendant.Text ~= "" and descendant.Text ~= " " then
                        text = descendant.Text
                        break
                    end
                end
            end
            if index and text then digits[index] = text end
        end
    end

    local out = {}
    for index = 1, 4 do out[index] = digits[index] or "?" end
    return table.concat(out, " ")
end

local function readCodeDigit(part)
    local surface = part:FindFirstChildOfClass("SurfaceGui")
    if not surface then return "?" end
    for _, descendant in ipairs(surface:GetDescendants()) do
        if descendant:IsA("TextLabel") and descendant.Text ~= "" then
            return descendant.Text
        end
    end
    return "?"
end

local function refreshCodeEsp()
    if not CFG.showCode then
        removeVisualsByType("code")
        return
    end

    local root = getGameRoot()
    local room = root and root:FindFirstChild("Room9_LockedExit")
    local gen = room and room:FindFirstChild("Gen")
    if not gen then return end

    for _, part in ipairs(gen:GetChildren()) do
        if part:IsA("BasePart") and part.Name == "CodeNumber" then
            if isWithinEspRange(part.Position) then
                local entry = getOrCreateVisual(part)
                entry.tag = "code"
                entry.part = part

                if CFG.labels then
                    if not entry.bb then
                        local offset = part.Size.Y * 0.5 + 1.5
                        entry.bb, entry.label, entry.card, entry.cardStroke = createLabelGui(part, offset, UDim2.fromOffset(90, 90), true)
                        if entry.label then entry.label.TextStrokeTransparency = 0.1 end
                    end
                    local text = string.format(
                        '#%s\n<font color="rgb(255,255,255)">%s</font>',
                        tostring(part:GetAttribute("CodeIndex") or "?"), readCodeDigit(part))
                    if entry.label.Text ~= text then entry.label.Text = text end
                elseif entry.bb then
                    removeLabelGui(entry)
                end

                applyHighlight(entry, Color3.fromRGB(120, 255, 255))
                if not entry.hl then applyBox(entry, Color3.fromRGB(120, 255, 255), 0.35) end
                local codeColor = Color3.fromRGB(120, 255, 255)
                if entry.cardStroke and entry.cardStroke.Color ~= codeColor then entry.cardStroke.Color = codeColor end
            else
                local entry = visuals[part]
                if entry and entry.tag == "code" then removeVisual(part) end
            end
        end
    end
end

local memory = {
    baseline = {},
    active = {},
    sequence = {},
    order = {},
    lastAt = 0,
    finished = nil,
}

local memoryTileCache = { at = 0, folder = nil, list = {} }

local function getMemoryTiles(force)
    local now = os.clock()
    local root = getGameRoot()
    local room = root and root:FindFirstChild("Room7_MemoryBridge")
    local gen = room and room:FindFirstChild("Gen")
    if not force and gen == memoryTileCache.folder and now - memoryTileCache.at < 0.8 then
        return memoryTileCache.list
    end

    for index = #memoryTileCache.list, 1, -1 do
        memoryTileCache.list[index] = nil
    end

    if gen then
        for _, part in ipairs(gen:GetChildren()) do
            if part:IsA("BasePart") and part:GetAttribute("MemTile") == true then
                memoryTileCache.list[#memoryTileCache.list + 1] = part
            end
        end
    end

    memoryTileCache.folder = gen
    memoryTileCache.at = now
    return memoryTileCache.list
end

local function luma(color)
    return 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
end

local function getTileSnapshot(part)
    return {
        color = part.Color,
        material = part.Material,
        transparency = part.Transparency,
        reflectance = part.Reflectance,
    }
end

local function updateMemorySequence()
    local tiles = getMemoryTiles()
    if #tiles == 0 then
        memory.active = {}
        return
    end

    local now = os.clock()

    for _, part in ipairs(tiles) do
        local previous = memory.baseline[part]
        if previous == nil then
            memory.baseline[part] = getTileSnapshot(part)
        else
            local changed = previous.color ~= part.Color
                or previous.material ~= part.Material
                or previous.transparency ~= part.Transparency
                or previous.reflectance ~= part.Reflectance
            if changed then
                local lit = (not memory.active[part]) and (
                    part.Transparency < 0.5
                    or luma(part.Color) > 0.55
                    or part.Material == Enum.Material.Neon
                )

                if lit then
                    memory.active[part] = true
                    memory.lastAt = now
                    local id = part:GetAttribute("MemId")
                    if id and not memory.order[id] then
                        memory.sequence[#memory.sequence + 1] = id
                        memory.order[id] = #memory.sequence
                    end
                elseif memory.active[part] and part.Transparency >= 0.5 and luma(part.Color) < 0.4 then
                    memory.active[part] = nil
                end
                previous.color = part.Color
                previous.material = part.Material
                previous.transparency = part.Transparency
                previous.reflectance = part.Reflectance
            end
        end
    end

    if #memory.sequence > 0 and (now - memory.lastAt) > 3 then
        memory.finished = table.concat(memory.sequence, " → ")
        memory.sequence = {}
        memory.order = {}
    end
end

local function getMemorySequenceText()
    if #memory.sequence > 0 then
        local parts = {}
        for _, id in ipairs(memory.sequence) do parts[#parts + 1] = tostring(id) end
        return table.concat(parts, " → ")
    end
    return memory.finished or "Waiting for the flash..."
end

local function refreshMemoryEsp()
    for _, part in ipairs(getMemoryTiles()) do
        local entry = visuals[part]
        local showing = CFG.showMemoryNumbers and isWithinEspRange(part.Position)

        if showing then
            entry = getOrCreateVisual(part)
            entry.memory = true

            if CFG.labels then
                if not entry.bb then
                    local offset = part.Size.Y * 0.5 + 1.5
                    entry.bb, entry.label, entry.card, entry.cardStroke = createLabelGui(part, offset, UDim2.fromOffset(70, 40), true)
                    if entry.label then entry.label.TextColor3 = Color3.fromRGB(225, 205, 255) end
                end
                if entry.cardStroke then entry.cardStroke.Color = memory.active[part] and Color3.fromRGB(120, 255, 140) or Color3.fromRGB(185, 125, 255) end
                local order = memory.order[part:GetAttribute("MemId")]
                entry.label.Text = order
                    and ('<font color="rgb(120,255,140)">' .. order .. "</font>")
                    or tostring(part:GetAttribute("MemId") or "")
            elseif entry.bb then
                removeLabelGui(entry)
            end

            if memory.active[part] and entry.box then
                entry.box.Color3 = Color3.fromRGB(120, 255, 140)
            end
        elseif entry and entry.memory then
            if entry.bb then removeLabelGui(entry) end
            if entry.box then entry.box.Color3 = Color3.fromRGB(200, 120, 255) end
            entry.memory = nil
        end
    end
end

local alarmGui, alarmFrame
local alarmTween
local beep

local function createAlarmGui()
    if alarmGui and alarmGui.Parent then return end
    local parent = getPlayerGui()
    if not parent then return end

    alarmGui = Instance.new("ScreenGui")
    alarmGui.Name = "VeloxHubAlarm"
    alarmGui.IgnoreGuiInset = true
    alarmGui.ResetOnSpawn = false
    alarmGui.DisplayOrder = 999
    alarmGui.Parent = parent

    alarmFrame = Instance.new("Frame")
    alarmFrame.Size = UDim2.fromScale(1, 1)
    alarmFrame.BackgroundColor3 = Color3.fromRGB(255, 30, 30)
    alarmFrame.BackgroundTransparency = 1
    alarmFrame.BorderSizePixel = 0
    alarmFrame.Parent = alarmGui
end

local function showAlarmFlash()
    if not CFG.alarmFlash then return end
    createAlarmGui()
    if not alarmFrame then return end
    if alarmTween then alarmTween:Cancel() end
    alarmFrame.BackgroundTransparency = 0.55
    alarmTween = TweenService:Create(alarmFrame, TweenInfo.new(0.55, Enum.EasingStyle.Quad), {
        BackgroundTransparency = 1,
    })
    alarmTween:Play()
end

local function playAlarmSound()
    if beep and beep.Parent then
        if beep.IsPlaying then beep:Stop() end
        beep.TimePosition = 0
        beep:Play()
        return
    end

    local ok, sounds = pcall(function()
        return require(ReplicatedStorage.Config.Sounds)
    end)
    if not ok or type(sounds) ~= "table" then return end

    local soundId
    for _, key in ipairs({ "ERROR", "ROOMTONE", "CLICK" }) do
        local value = sounds[key]
        if type(value) == "string" then
            soundId = value
        elseif type(value) == "number" then
            soundId = "rbxassetid://" .. tostring(value)
        elseif type(value) == "table" then
            local id = value.Id or value.SoundId or value.id
            if type(id) == "string" then
                soundId = id
            elseif type(id) == "number" then
                soundId = "rbxassetid://" .. tostring(id)
            end
        end
        if soundId then break end
    end
    if not soundId then return end
    if not soundId:match("^rbxassetid://") and not soundId:match("^rbxasset") then
        soundId = "rbxassetid://" .. soundId
    end

    beep = Instance.new("Sound")
    beep.SoundId = soundId
    beep.Volume = 0.35
    beep.PlaybackSpeed = 1.6
    beep.Parent = SoundService
    beep:Play()
end

local nearest = { part = nil, distance = math.huge, state = nil, room = nil }
local nearestUpdatedAt = 0

local function getNearestListener(force)
    local now = os.clock()
    if not force and now - nearestUpdatedAt < 0.15 then return nearest end
    local root = getRootPart()
    local best, bestSquared = nil, math.huge
    if root then
        for _, part in ipairs(getListeners()) do
            local offset = part.Position - root.Position
            local squared = offset:Dot(offset)
            if squared < bestSquared then
                best, bestSquared = part, squared
            end
        end
    end
    local bestDistance = best and math.sqrt(bestSquared) or math.huge
    nearest = {
        part = best,
        distance = bestDistance,
        state = best and tostring(best:GetAttribute("State") or "?") or nil,
        room = best and tostring(best:GetAttribute("Room") or "?") or nil,
    }
    nearestUpdatedAt = now
    return nearest
end

local lastAlarmAt = 0
local lastDangerStep = 0

local function updateProximityAlert()
    if not CFG.alarmEnabled then return end
    local now = os.clock()
    if now - lastDangerStep < 0.15 then return end
    lastDangerStep = now
    local current = getNearestListener()
    local aggressive = current.state ~= nil and current.state ~= "Patrol"

    if CFG.alarmEnabled and current.part then
        if current.distance <= CFG.alarmDistance or aggressive then
            local now = os.clock()
            local interval = aggressive and 0.8 or 1.6
            if now - lastAlarmAt > interval then
                lastAlarmAt = now
                showAlarmFlash()
                playAlarmSound()
            end
        end
    end
end

local function isListenerTargetingPlayer()
    local root = getRootPart()
    if not root then return false end
    for _, part in ipairs(getListeners()) do
        local state = tostring(part:GetAttribute("State") or "")
        if state == "Chase" or state == "Hunt" or state == "Attack" then
            local target = part:GetAttribute("Target")
            if typeof(target) == "Vector3" and (target - root.Position).Magnitude < 70 then
                return true
            end
        end
    end
    return false
end

local BOOST_NAME = "VeloxHubBoostVelocity"
local BOOST_RAMP = 10
local boost = { constraint = nil, attachment = nil, current = 0 }

local function removeBoostObjects(model)
    if not model then return end
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant.Name == BOOST_NAME then descendant:Destroy() end
    end
end

local boostFailureAt = 0

local function getBoostConstraint()
    local root = getRootPart()
    if not root then return nil end

    if boost.constraint and boost.constraint.Parent == root
        and boost.attachment and boost.attachment.Parent == root then
        return boost.constraint
    end

    if os.clock() - boostFailureAt < 2 then return nil end

    removeBoostObjects(root)
    boost.constraint = nil
    boost.attachment = nil

    local ok, constraint = pcall(function()
        local attachment = Instance.new("Attachment")
        attachment.Name = BOOST_NAME
        attachment.Parent = root

        local velocity = Instance.new("LinearVelocity")
        velocity.Name = BOOST_NAME
        velocity.Attachment0 = attachment
        velocity.MaxForce = 1e5
        velocity.RelativeTo = Enum.ActuatorRelativeTo.World

        velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
        velocity.PrimaryTangentAxis = Vector3.new(1, 0, 0)
        velocity.SecondaryTangentAxis = Vector3.new(0, 0, 1)
        velocity.PlaneVelocity = Vector2.zero
        velocity.Enabled = false
        velocity.Parent = root
        return velocity
    end)

    if not ok or not constraint then
        boostFailureAt = os.clock()
        removeBoostObjects(root)
        boost.constraint = nil
        boost.attachment = nil
        return nil
    end

    boost.attachment = constraint.Attachment0
    boost.constraint = constraint
    boost.current = 0
    return constraint
end

local function stopBoost(constraint, root)
    boost.current = 0
    if constraint then
        constraint.Enabled = false
        constraint.PlaneVelocity = Vector2.zero
    end
    boost.constraint = nil
    boost.attachment = nil
    removeBoostObjects(root)
end

local function isOnGround()
    local hum = getHumanoid()
    if not hum then return false end
    return hum.FloorMaterial ~= Enum.Material.Air
end

local function isInWater()
    return LocalPlayer:GetAttribute("InWater") == true
end

local function updateSpeedBoost(deltaTime)
    if not CFG.speedEnabled and not boost.constraint then return end
    local root = getRootPart()
    local hum = getHumanoid()

    if not root or not hum then
        local oldRoot = boost.constraint and boost.constraint.Parent
        if oldRoot then
            stopBoost(boost.constraint, oldRoot)
        else
            boost.constraint = nil
            boost.attachment = nil
            boost.current = 0
        end
        return
    end

    if not CFG.speedEnabled then
        if boost.constraint then stopBoost(boost.constraint, root) end
        return
    end

    local constraint = getBoostConstraint()
    if not constraint then return end

    local move = hum.MoveDirection
    local walking = move.Magnitude > 0.05

    local allowed = walking and not isInWater()

    local target = 0
    if allowed then
        target = math.clamp(CFG.speedValue, SPEED_MIN, SPEED_MAX)
    end

    local alpha = 1 - math.exp(-BOOST_RAMP * deltaTime)
    boost.current = boost.current + (target - boost.current) * alpha
    if boost.current < 0.3 and target == 0 then
        boost.current = 0
    end

    if boost.current > 0.3 and walking then
        local direction = Vector3.new(move.X, 0, move.Z)
        if direction.Magnitude > 0 then direction = direction.Unit end

        constraint.PlaneVelocity = Vector2.new(
            direction.X * boost.current,
            direction.Z * boost.current
        )
        constraint.Enabled = true
    else
        constraint.Enabled = false
        constraint.PlaneVelocity = Vector2.zero
    end
end

local function getUiParent()
    local ok, hidden = pcall(function()
        return gethui and gethui()
    end)
    if ok and hidden then return hidden end
    return LocalPlayer:FindFirstChildOfClass("PlayerGui") or game:GetService("CoreGui")
end

do
    for _, gui in ipairs(getUiParent():GetChildren()) do
        if gui:IsA("ScreenGui") and (
            gui.Name == "DONT SPLASH"
            or gui.Name == "Velox Hub"
            or gui.Name == "VeloxHubAlarm"
            or gui.Name == "Still Water Hub"
            or gui.Name == "StillWaterAlarm"
            or gui.Name == ("Rob" .. "scriptAlarm")
            or gui.Name == ("Rob" .. "script.com")
        ) then
            gui:Destroy()
        end
    end
    local staleMarks = workspace:FindFirstChild(MARKS_NAME)
    if staleMarks then staleMarks:Destroy() end
end

local Window = Rayfield:CreateWindow({
    name = "DONT SPLASH",
    subtitle = "Velox Hub · By Ovei",
    theme = "cobalt",
    sidebarLayout = true,
    profile = "By Ovei",
    showName = "DONT SPLASH",
    configuration = {
        autoSave = true,
        autoLoad = true,
        fileName = "DONT_SPLASH",
        customFolder = "VeloxHub",
    },
})

local DashboardTab = Window:CreateTab({ name = "Dashboard" })
local VisualsTab = Window:CreateTab({ name = "Visuals" })
local ToolsTab = Window:CreateTab({ name = "Tools" })
local SettingsTab = Window:CreateTab({ name = "Settings" })

local controls = {}
local uiCache = {}

local function showNotification(title, content, duration)
    Window:Notify({
        title = title,
        content = content or "",
        duration = duration or 4,
    })
end

local function addTabNote(tab, text)
    tab:CreateText({ name = "Note", text = text })
end

local function createToggle(tab, name, flag, value, callback)
    local handle = tab:CreateToggle({
        name = name,
        flag = flag,
        value = value,
        callback = callback,
    })
    controls[flag] = handle
    return handle
end

local function createSlider(tab, name, flag, range, increment, value, suffix, callback)
    local handle = tab:CreateSlider({
        name = name,
        flag = flag,
        range = range,
        increment = increment,
        value = value,
        suffix = suffix,
        callback = callback,
    })
    controls[flag] = handle
    return handle
end

local function setControlValue(flag, value)
    local handle = controls[flag]
    if handle then
        pcall(function() handle:Set(value) end)
    end
end

local function appendIfChanged(console, key, value)
    value = tostring(value)
    if uiCache[key] == value then return end
    uiCache[key] = value
    console:Append(value)
end

local function setStatIfChanged(stat, key, value)
    if uiCache[key] == value then return end
    uiCache[key] = value
    stat:Set(value)
end

addTabNote(DashboardTab, "Keep an eye on the closest Listener and check the room list as you move.")
DashboardTab:CreateSection({ name = "Run Status" })
local roomStat = DashboardTab:CreateStat({ name = "Room", value = 0 })
local nearestStat = DashboardTab:CreateStat({ name = "Nearest Listener", value = 0, suffix = " studs" })
DashboardTab:CreateSection({ name = "Proximity Alert" })
createToggle(DashboardTab, "Proximity Alarm", "AlarmEnabled", false, function(value)
    CFG.alarmEnabled = value
end)
createToggle(DashboardTab, "Screen Flash", "AlarmFlash", false, function(value)
    CFG.alarmFlash = value
end)
createSlider(DashboardTab, "Alert Distance", "AlarmDistance", { 20, 150 }, 5, 60, " studs", function(value)
    CFG.alarmDistance = value
end)
local overviewConsole = DashboardTab:CreateConsole({
    name = "Run Overview",
    text = "Waiting for game data...",
    height = 126,
    follow = true,
    maxLines = 30,
})
local threatConsole = DashboardTab:CreateConsole({
    name = "Listener Locations",
    text = "Waiting for Listener data...",
    height = 150,
    follow = true,
    maxLines = 45,
})
addTabNote(VisualsTab, "Turn on only the markers you need to keep busy rooms clear.")
VisualsTab:CreateSection({ name = "ESP Targets" })
createToggle(VisualsTab, "Listener ESP", "ShowListener", true, function(value)
    CFG.showListener = value
    if not value then removeVisualsByType("listener") end
end)
createToggle(VisualsTab, "Player ESP", "ShowTeammates", false, function(value)
    CFG.showTeammates = value
    if not value then removeVisualsByType("teammate") end
end)
createToggle(VisualsTab, "Pebble ESP", "ShowPickups", false, function(value)
    CFG.showPickups = value
    if not value then removeVisualsByType("pickup") end
end)
createToggle(VisualsTab, "Platform ESP", "ShowPlatforms", false, function(value)
    CFG.showPlatforms = value
    if not value and not CFG.showMemoryNumbers then removeVisualsByType("platform") end
end)
createToggle(VisualsTab, "Safe Platforms Only", "PlatformSafeOnly", false, function(value)
    CFG.platformSafeOnly = value
end)
createToggle(VisualsTab, "Checkpoint and Exit ESP", "ShowExits", false, function(value)
    CFG.showExits = value
    if not value then removeVisualsByType("exit") end
end)
createToggle(VisualsTab, "Door Code ESP", "ShowCode", true, function(value)
    CFG.showCode = value
    if not value then removeVisualsByType("code") end
end)
createToggle(VisualsTab, "Memory Tile ESP", "ShowMemoryNumbers", false, function(value)
    CFG.showMemoryNumbers = value
    if not value and not CFG.showPlatforms then removeVisualsByType("platform") end
end)

VisualsTab:CreateSection({ name = "Style" })
createToggle(VisualsTab, "Highlights", "Highlights", true, function(value)
    CFG.highlights = value
    if not value then
        for _, entry in pairs(visuals) do removeHighlight(entry) end
    end
end)
createToggle(VisualsTab, "3D Boxes", "BoxOutlines", true, function(value)
    CFG.boxes = value
    if not value then
        for _, entry in pairs(visuals) do
            if entry.box then entry.box:Destroy(); entry.box = nil end
        end
    end
end)
createToggle(VisualsTab, "Labels", "Labels", true, function(value)
    CFG.labels = value
    if not value then
        for _, entry in pairs(visuals) do
            if entry.bb then removeLabelGui(entry) end
        end
    end
end)
createToggle(VisualsTab, "Label Distance", "LabelDistance", true, function(value)
    CFG.labelDistance = value
end)
createToggle(VisualsTab, "Listener Target Marker", "ListenerTarget", false, function(value)
    CFG.listenerTarget = value
end)
createSlider(VisualsTab, "Max Distance", "MaxDistance", { 0, 500 }, 10, 0, " studs", function(value)
    CFG.maxDistance = value
    updateLabelDistance()
end)
createSlider(VisualsTab, "Fill Transparency", "FillOpacity", { 0, 80 }, 5, 55, "%", function(value)
    CFG.fillOpacity = value / 100
end)
createSlider(VisualsTab, "Box Transparency", "BoxOpacity", { 10, 90 }, 5, 60, "%", function(value)
    CFG.boxOpacity = value / 100
    for _, entry in pairs(visuals) do
        if entry.box and entry.boxBaseTransparency == nil then
            entry.box.Transparency = CFG.boxOpacity
        end
    end
end)

VisualsTab:CreateSection({ name = "Live Count" })
local highlightStat = VisualsTab:CreateStat({ name = "Highlights Active", value = 0 })
local boxStat = VisualsTab:CreateStat({ name = "Boxes Active", value = 0 })
VisualsTab:CreateButton({
    name = "Clear ESP",
    callback = function()
        for _, flag in ipairs({ "ShowListener", "ShowTeammates", "ShowPickups", "ShowPlatforms", "ShowExits", "ShowCode", "ShowMemoryNumbers" }) do
            setControlValue(flag, false)
        end
        for part in pairs(visuals) do removeVisual(part) end
        showNotification("ESP cleared", "All ESP markers have been removed.", 3)
    end,
})

addTabNote(ToolsTab, "Copy the room 9 code, follow the room 7 lights, or adjust your movement speed.")
ToolsTab:CreateSection({ name = "Door Code" })
local codeConsole = ToolsTab:CreateConsole({
    name = "Room 9 Code",
    text = "Room 9 has not loaded yet.",
    height = 82,
    follow = true,
    maxLines = 12,
})
ToolsTab:CreateButton({
    name = "Copy Code",
    callback = function()
        local code = getDoorCode()
        if not code or code == "? ? ? ?" then
            showNotification("Code not ready", "Visit the room 9 pillars first.", 4)
            return
        end
        local copied = pcall(function()
            if type(setclipboard) ~= "function" then error("Clipboard is unavailable") end
            setclipboard(code)
        end)
        showNotification(copied and "Door code copied" or "Door code", copied and code or "Clipboard is not available in this executor.", 4)
    end,
})
ToolsTab:CreateSection({ name = "Memory Bridge" })
local memoryConsole = ToolsTab:CreateConsole({
    name = "Tile Order",
    text = "Waiting for the tiles to light up...",
    height = 90,
    follow = true,
    maxLines = 14,
})
ToolsTab:CreateButton({
    name = "Reset Tile Order",
    callback = function()
        memory.sequence = {}
        memory.order = {}
        memory.finished = nil
        memory.baseline = {}
        memory.active = {}
        memory.lastAt = 0
        showNotification("Memory recording reset", "Ready to record the next sequence.", 3)
    end,
})

ToolsTab:CreateSection({ name = "Speed Boost" })
createToggle(ToolsTab, "Speed Boost", "SpeedEnabled", false, function(value)
    CFG.speedEnabled = value
end)
createSlider(ToolsTab, "Boost Speed", "SpeedValue", { SPEED_MIN, SPEED_MAX }, 1, 30, " studs/s", function(value)
    CFG.speedValue = value
end)
local speedStat = ToolsTab:CreateStat({ name = "Current Speed", value = 0, suffix = " studs/s" })
local movementConsole = ToolsTab:CreateConsole({
    name = "Boost Status",
    text = "Boost is off.",
    height = 76,
    follow = true,
    maxLines = 10,
})

addTabNote(SettingsTab, "Save your setup, change the colors, or rejoin this server.")
SettingsTab:CreateSection({ name = "Run Info" })
local runConsole = SettingsTab:CreateConsole({
    name = "Run Summary",
    text = "Waiting for game data...",
    height = 128,
    follow = true,
    maxLines = 24,
})
SettingsTab:CreateSection({ name = "Theme" })
SettingsTab:CreateDropdown({
    name = "Color Theme",
    options = { "default", "cobalt", "ember", "amethyst", "frost", "rose" },
    value = "cobalt",
    callback = function(selected)
        local theme = type(selected) == "table" and selected[1] or selected
        if type(theme) == "string" then
            pcall(function() Window:ChangeTheme(theme) end)
        end
    end,
})
SettingsTab:CreateSection({ name = "Setup" })
SettingsTab:CreateButton({
    name = "Save Setup",
    callback = function()
        local ok, saved = pcall(function() return Window:Save() end)
        showNotification(ok and saved and "Settings saved" or "Save failed", ok and saved and "Your current setup has been saved." or "Check whether this executor supports file saving.", 4)
    end,
})
SettingsTab:CreateButton({
    name = "Load Setup",
    callback = function()
        local ok, loaded = pcall(function() return Window:Load() end)
        showNotification(ok and loaded and "Settings loaded" or "Load failed", ok and loaded and "Your saved setup has been loaded." or "No saved setup was found or file access is unavailable.", 4)
    end,
})
SettingsTab:CreateButton({
    name = "Reset Visuals",
    callback = function()
        local defaults = {
            ShowListener = true,
            ShowTeammates = false,
            ShowPickups = false,
            ShowPlatforms = false,
            PlatformSafeOnly = false,
            ShowExits = false,
            ShowCode = true,
            ShowMemoryNumbers = false,
            Highlights = true,
            BoxOutlines = true,
            Labels = true,
            LabelDistance = true,
            ListenerTarget = false,
            MaxDistance = 0,
            FillOpacity = 55,
            BoxOpacity = 60,
        }
        for flag, value in pairs(defaults) do setControlValue(flag, value) end
        for part in pairs(visuals) do removeVisual(part) end
        showNotification("ESP settings reset", "The default ESP setup is back.", 3)
    end,
})
SettingsTab:CreateButton({
    name = "Rejoin Server",
    callback = function()
        local ok = pcall(function()
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end)
        if not ok then showNotification("Rejoin failed", "The server could not be joined again.", 4) end
    end,
})

local function refreshUiPanels()
    local current = getNearestListener()
    local distance = current.distance < math.huge and math.floor(current.distance + 0.5) or 0
    setStatIfChanged(nearestStat, "stat-nearest", distance)
    setStatIfChanged(roomStat, "stat-room", getCurrentRoom())
    setStatIfChanged(highlightStat, "stat-highlights", highlightCount)

    local boxes = 0
    for _, entry in pairs(visuals) do
        if entry.box then boxes = boxes + 1 end
    end
    setStatIfChanged(boxStat, "stat-boxes", boxes)
    setStatIfChanged(speedStat, "stat-speed", math.floor(boost.current + 0.5))

    if not CFG.speedEnabled then
        appendIfChanged(movementConsole, "movement", "Boost is off.")
    elseif isInWater() then
        appendIfChanged(movementConsole, "movement", "Boost is paused while you are in water.")
    else
        local movementState = isOnGround() and "on the ground" or "in the air"
        appendIfChanged(movementConsole, "movement", string.format("Boost is active at about %d studs/s · %s.", math.floor(boost.current + 0.5), movementState))
    end

    local nearestLine
    if not current.part then
        nearestLine = "No Listener is loaded."
    else
        local danger = isListenerTargetingPlayer() and " · Hunting you" or ""
        nearestLine = string.format("Room %s · %s · %d studs away%s", tostring(current.room or "?"), tostring(current.state or "?"), distance, danger)
    end
    appendIfChanged(overviewConsole, "overview-nearest", nearestLine)

    local list = getListeners()
    table.sort(list, function(a, b)
        return (tonumber(a:GetAttribute("Room")) or 0) < (tonumber(b:GetAttribute("Room")) or 0)
    end)
    local rows = {}
    for _, part in ipairs(list) do
        rows[#rows + 1] = string.format("Room %s · %s · %s studs", tostring(part:GetAttribute("Room") or "?"), tostring(part:GetAttribute("State") or "?"), formatDistance(getDistance(part.Position)))
    end
    if #rows == 0 then rows[1] = "No Listener data is available." end
    appendIfChanged(threatConsole, "overview-rooms", table.concat(rows, "\n"))

    local roomIndex = getCurrentRoom()
    local roomName = roomIndex == 0 and "Lobby" or (GAME.rooms[roomIndex] and GAME.rooms[roomIndex].name or "Unknown")
    local root = getGameRoot()
    local mode = root and tostring(root:GetAttribute("Mode") or "—") or "—"
    local timer = readGuiText("StillWaterUI", "ClientHUD", "Timer") or "—"
    local coins = readGuiText("StillWaterRunUI", "RunUI", "Coins", "Amount") or "—"
    local detail = string.format("Room: %s\nMode: %s\nTime: %s\nCoins: %s", roomName, mode, timer, coins)
    appendIfChanged(runConsole, "run-details", detail)

    local hotbar = getPlayerGui()
    hotbar = hotbar and hotbar:FindFirstChild("StillWaterRunUI")
    hotbar = hotbar and hotbar:FindFirstChild("RunUI")
    hotbar = hotbar and hotbar:FindFirstChild("Hotbar")
    local inventory = {}
    if hotbar then
        for _, slot in ipairs(hotbar:GetChildren()) do
            if slot:IsA("TextButton") then
                local count = slot:FindFirstChild("Count")
                local tag = slot:FindFirstChild("Tag")
                local used = slot:FindFirstChild("Used")
                local label = tag and tag.Text ~= "" and tag.Text or slot.Name
                local amount = count and count.Text or "0"
                local spent = used and used.Text == "USED" and " (used)" or ""
                inventory[#inventory + 1] = string.format("%s x %s%s", label, amount, spent)
            end
        end
    end
    appendIfChanged(runConsole, "run-inventory", #inventory > 0 and ("Items: " .. table.concat(inventory, " · ")) or "Items: None")

    local code = getDoorCode()
    local codeLine = code and ("Room 9 code: " .. code) or "Room 9 is not loaded yet."
    appendIfChanged(codeConsole, "puzzle-code", codeLine)
    appendIfChanged(memoryConsole, "puzzle-memory", "Sequence: " .. getMemorySequenceText())
end

trackConnection(UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.RightControl then
        Window:ToggleHide()
    end
end))

local lastFrameAt = os.clock()

trackConnection(RunService.RenderStepped:Connect(function()
    local now = os.clock()
    local deltaTime = math.clamp(now - lastFrameAt, 0.001, 0.2)
    lastFrameAt = now
    updateSpeedBoost(deltaTime)
end))

trackConnection(RunService.Heartbeat:Connect(updateProximityAlert))

task.spawn(function()
    local nextListener = 0
    local nextPrune = 0
    local nextPlatform = 0
    local nextCode = 0
    local nextMemoryVisual = 0
    local nextPickup = 0
    local nextPlayers = 0
    local nextExit = 0
    local nextMemoryRead = 0
    local nextUi = 0

    while not STOPPED do
        local now = os.clock()

        if now >= nextListener then
            pcall(refreshListenerEsp)
            nextListener = now + 0.15
        end
        if now >= nextPrune then
            pcall(cleanupVisuals)
            nextPrune = now + 0.8
        end
        if now >= nextPlatform then
            pcall(refreshPlatformEsp)
            nextPlatform = now + 1.25
        end
        if now >= nextCode then
            pcall(refreshCodeEsp)
            nextCode = now + 1.0
        end
        if now >= nextMemoryVisual then
            pcall(refreshMemoryEsp)
            nextMemoryVisual = now + 0.45
        end
        if now >= nextPickup then
            pcall(refreshPickupEsp)
            nextPickup = now + 0.8
        end
        if now >= nextPlayers then
            pcall(refreshPlayerEsp)
            nextPlayers = now + 0.8
        end
        if now >= nextExit then
            pcall(refreshExitEsp)
            nextExit = now + 1.5
        end
        if now >= nextMemoryRead then
            pcall(updateMemorySequence)
            nextMemoryRead = now + 0.12
        end
        if now >= nextUi then
            pcall(refreshUiPanels)
            nextUi = now + 1.0
        end

        task.wait(0.05)
    end
end)

trackConnection(LocalPlayer.CharacterAdded:Connect(function(model)
    task.wait(1)
    removeBoostObjects(model)
    boost.constraint = nil
    boost.attachment = nil
    boost.current = 0
end))

local api = {
    cfg = CFG,
    window = Window,

    listener = function() return getNearestListener() end,

    code = function() return getDoorCode() end,

    memory = function() return getMemorySequenceText() end,

    boostSpeed = function() return boost.current end,

    clearEsp = function()
        for part in pairs(visuals) do removeVisual(part) end
    end,

    unload = function()
        disconnectAll()
        for part in pairs(visuals) do
            removeVisual(part)
        end
        highlightCount = 0
        if marksFolder then
            pcall(function() marksFolder:Destroy() end)
            marksFolder = nil
        end
        removeBoostObjects(getRootPart())
        boost.constraint = nil
        boost.attachment = nil
        boost.current = 0
        pcall(function() Window:Unload() end)
        if alarmTween then pcall(function() alarmTween:Cancel() end) end
        if alarmGui then pcall(function() alarmGui:Destroy() end) end
        if beep then pcall(function() beep:Destroy() end) end
        if getgenv then
            getgenv().VeloxHub = nil
            getgenv()["Rob" .. "script"] = nil
            getgenv().StillWaterHub = nil
        end
    end,
}

if getgenv then
    getgenv().VeloxHub = api
    getgenv().StillWaterHub = api
end

showNotification("DONT SPLASH is ready", "Press RightControl to hide or show the menu.", 5)

return api
