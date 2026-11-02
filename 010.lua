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

local function stillWater()
    return workspace:FindFirstChild("StillWater")
end

local function listenerFolder()
    local root = stillWater()
    return root and root:FindFirstChild("Creatures")
end

local function pebbleFolder()
    local root = stillWater()
    return root and root:FindFirstChild("PebblePickups")
end

local cachedCharacter
local cachedHumanoid
local cachedRoot

local function character()
    local model = LocalPlayer.Character
    if model ~= cachedCharacter then
        cachedCharacter = model
        cachedHumanoid = nil
        cachedRoot = nil
    end
    return model
end

local function humanoid()
    local model = character()
    if not model then return nil end
    if cachedHumanoid and cachedHumanoid.Parent == model then return cachedHumanoid end
    cachedHumanoid = model:FindFirstChildOfClass("Humanoid")
    return cachedHumanoid
end

local function rootPart()
    local model = character()
    if not model then return nil end
    if cachedRoot and cachedRoot.Parent == model then return cachedRoot end
    cachedRoot = model:FindFirstChild("HumanoidRootPart")
    return cachedRoot
end

local function playerGui()
    return LocalPlayer:FindFirstChildOfClass("PlayerGui")
end

local function guiText(guiName, ...)
    local gui = playerGui() and playerGui():FindFirstChild(guiName)
    if not gui then return nil end
    local node = gui
    for _, name in ipairs({ ... }) do
        node = node and node:FindFirstChild(name)
    end
    return node and node:IsA("TextLabel") and node.Text or nil
end

local function stateColor(state)
    return STATE_COLORS[state] or Color3.fromRGB(180, 180, 200)
end

local function distanceTo(position)
    local root = rootPart()
    if not root or not position then return math.huge end
    return (position - root.Position).Magnitude
end

local function formatStuds(distance)
    if distance == math.huge then return "—" end
    return string.format("%d", math.floor(distance + 0.5))
end

local function currentRoomIndex()
    local root = rootPart()
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

local function keep(connection)
    if connection then table.insert(CONNECTIONS, connection) end
    return connection
end

local function stopAll()
    STOPPED = true
    for _, connection in ipairs(CONNECTIONS) do
        pcall(function() connection:Disconnect() end)
    end
    CONNECTIONS = {}
end

do
    local previous = getgenv and (getgenv().Robscript or getgenv().StillWaterHub)
    if previous and previous.unload then
        pcall(previous.unload)
    end
end

local visuals = {}

local HIGHLIGHT_BUDGET = 240
local highlightCount = 0
local MARKS_NAME = "StillWaterMarks"
local marksFolder

local function marks()
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

local function inRange(position)
    if CFG.maxDistance <= 0 then return true end
    return distanceTo(position) <= CFG.maxDistance
end

local function makeHighlight(part, color)
    if highlightCount >= HIGHLIGHT_BUDGET then return nil end
    local highlight = Instance.new("Highlight")
    highlight.Name = "StillWaterHighlight"
    highlight.Adornee = part
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = color
    highlight.FillTransparency = CFG.fillOpacity
    highlight.OutlineColor = color
    highlight.OutlineTransparency = 0.1
    highlight.Parent = marks()
    highlightCount = highlightCount + 1
    return highlight
end

local function releaseHighlight(entry)
    if not entry or not entry.hl then return end
    entry.hl:Destroy()
    entry.hl = nil
    highlightCount = math.max(0, highlightCount - 1)
end

local function makeBox(part, color, transparency)
    local adornment = Instance.new("BoxHandleAdornment")
    adornment.Name = "StillWaterBox"
    adornment.Adornee = part
    adornment.Size = part.Size + Vector3.new(0.08, 0.08, 0.08)
    adornment.Color3 = color
    adornment.Transparency = transparency or CFG.boxOpacity
    adornment.AlwaysOnTop = true
    adornment.ZIndex = 2
    adornment.Parent = marks()
    return adornment
end

local function makeBillboard(part, offsetY, size, worldOffset)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "StillWaterTag"
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
    billboard.Parent = marks()

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

local function removeBillboard(entry)
    if entry.bb then entry.bb:Destroy() end
    entry.bb, entry.label, entry.card, entry.cardStroke = nil, nil, nil, nil
end

local function dropVisual(part)
    local entry = visuals[part]
    if not entry then return end
    releaseHighlight(entry)
    if entry.box then entry.box:Destroy() end
    removeBillboard(entry)
    if entry.marker then entry.marker:Destroy() end
    visuals[part] = nil
end

local function getVisual(part)
    local entry = visuals[part]
    if not entry then

        entry = { part = part }
        visuals[part] = entry
    else
        entry.part = part
    end
    return entry
end

local function pruneVisuals()
    for part, entry in pairs(visuals) do
        if not part.Parent then
            releaseHighlight(entry)
            if entry.box then entry.box:Destroy() end
            removeBillboard(entry)
            if entry.marker then entry.marker:Destroy() end
            visuals[part] = nil
        end
    end
end

local function dropByTag(tag)
    for part, entry in pairs(visuals) do
        if entry.tag == tag then dropVisual(part) end
    end
end

local function styleHighlight(entry, color)
    if not CFG.highlights then
        releaseHighlight(entry)
        return
    end
    if not entry.hl then entry.hl = makeHighlight(entry.part, color) end
    if not entry.hl then return end
    entry.hl.FillColor = color
    entry.hl.OutlineColor = color
    entry.hl.FillTransparency = CFG.fillOpacity
    entry.hl.OutlineTransparency = 0.06
end

local function styleBox(entry, color, transparency)
    if not CFG.boxes then
        if entry.box then entry.box:Destroy(); entry.box = nil end
        return
    end
    if entry.box and not entry.box.Parent then entry.box = nil end
    if not entry.box then
        entry.box = makeBox(entry.part, color, transparency)
    else
        entry.box.Color3 = color
        entry.box.Size = entry.part.Size + Vector3.new(0.08, 0.08, 0.08)
        if transparency then entry.box.Transparency = transparency end
    end
end

local listenerCache = { at = 0, folder = nil, list = {} }

local function listeners(force)
    local now = os.clock()
    local folder = listenerFolder()
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

local function updateListenerVisuals()
    if not CFG.showListener then
        dropByTag("listener")
        return
    end

    for _, part in ipairs(listeners()) do
        if inRange(part.Position) then
            local entry = getVisual(part)
            entry.tag = "listener"
            entry.part = part

            local state = tostring(part:GetAttribute("State") or "?")
            local color = stateColor(state)
            local red   = math.floor(color.R * 255)
            local green = math.floor(color.G * 255)
            local blue  = math.floor(color.B * 255)

            styleHighlight(entry, color)
            if entry.cardStroke then entry.cardStroke.Color = color end
            if not entry.hl then styleBox(entry, color, 0.45) end

            if CFG.labels then
                if not entry.bb then
                    entry.bb, entry.label, entry.card, entry.cardStroke = makeBillboard(part, 4, UDim2.fromOffset(220, 46))
                end
                entry.bb.MaxDistance = CFG.maxDistance > 0 and CFG.maxDistance or 10000
                local room = tostring(part:GetAttribute("Room") or "?")
                local tail = CFG.labelDistance
                    and string.format('<font color="rgb(%d,%d,%d)">%s</font> · %s studs',
                        red, green, blue, state, formatStuds(distanceTo(part.Position)))
                    or string.format('<font color="rgb(%d,%d,%d)">%s</font>', red, green, blue, state)
                entry.label.Text = string.format(
                    '<font color="rgb(%d,%d,%d)">LISTENER</font> <font color="rgb(200,200,200)">Room %s</font>\n%s',
                    red, green, blue, room, tail)
            elseif entry.bb then
                removeBillboard(entry)
            end

            local target = part:GetAttribute("Target")
            if CFG.listenerTarget and typeof(target) == "Vector3" then
                if not entry.marker or not entry.marker.Parent then
                    local marker = Instance.new("Part")
                    marker.Name = "StillWaterTargetMarker"
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
            if entry and entry.tag == "listener" then dropVisual(part) end
        end
    end
end

local PLATFORM_TAGS = { "Platform", "IsPlatform", "Safe", "MemTile", "CanSink", "IsSinking", "Sinking", "Stable" }

local function platformTag(part)
    for _, name in ipairs(PLATFORM_TAGS) do
        if part:GetAttribute(name) == true then return name end
    end
    return nil
end

local function collectPlatforms()
    local list = {}
    local root = stillWater()
    if not root then return list end
    for _, room in ipairs(root:GetChildren()) do
        local gen = room:FindFirstChild("Gen")
        if gen then
            for _, part in ipairs(gen:GetChildren()) do
                if part:IsA("BasePart") and platformTag(part) then
                    table.insert(list, part)
                end
            end
        end
    end
    return list
end

local platformCache = { at = 0, list = {} }

local function updatePlatformVisuals()
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
        dropByTag("platform")
        return
    end

    if (os.clock() - platformCache.at) > 3 then
        platformCache.list = collectPlatforms()
        platformCache.at = os.clock()
    end

    for _, part in ipairs(platformCache.list) do
        if part.Parent then
            local safe   = part:GetAttribute("Safe") == true
            local memory = part:GetAttribute("MemTile") == true

            local allowed = CFG.showPlatforms
                and ((not CFG.platformSafeOnly) or safe or memory)
                or (CFG.showMemoryNumbers and memory)
            local show = allowed and inRange(part.Position)

            if show then
                local entry = getVisual(part)
                if not entry.box or entry.tag ~= "platform" then
                    local color = safe and Color3.fromRGB(70, 220, 255)
                        or (memory and Color3.fromRGB(200, 120, 255)
                            or Color3.fromRGB(110, 255, 160))

                    styleBox(entry, color)
                    entry.tag = "platform"
                end
            else
                local entry = visuals[part]
                if entry and entry.tag == "platform" then dropVisual(part) end
            end
        end
    end
end

local pickupCache = { at = 0, folder = nil, list = {} }

local function collectPickups()
    local now = os.clock()
    local folder = pebbleFolder()
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

local function updatePickupVisuals()
    if not CFG.showPickups or not CFG.boxes then
        dropByTag("pickup")
        return
    end

    for _, part in ipairs(collectPickups()) do
        if part.Parent and inRange(part.Position) then
            local entry = getVisual(part)
            if not entry.box or entry.tag ~= "pickup" then
                styleBox(entry, Color3.fromRGB(255, 225, 120), 0.3)
                entry.tag = "pickup"
            end
        else
            local entry = visuals[part]
            if entry and entry.tag == "pickup" then dropVisual(part) end
        end
    end
end

local function updatePlayerVisuals()
    if not CFG.showTeammates or (not CFG.highlights and not CFG.boxes) then
        dropByTag("teammate")
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local model = player.Character
            local part = model and model:FindFirstChild("HumanoidRootPart")
            if part and inRange(part.Position) then
                local entry = getVisual(part)
                entry.tag = "teammate"
                styleHighlight(entry, Color3.fromRGB(110, 190, 255))
                if CFG.highlights and not entry.hl then
                    styleBox(entry, Color3.fromRGB(110, 190, 255), 0.4)
                elseif CFG.boxes and not CFG.highlights then
                    styleBox(entry, Color3.fromRGB(110, 190, 255), 0.4)
                end
                if CFG.labels then
                    if not entry.bb then
                        entry.bb, entry.label, entry.card, entry.cardStroke = makeBillboard(part, 3, UDim2.fromOffset(170, 30))
                    end
                    entry.bb.MaxDistance = CFG.maxDistance > 0 and CFG.maxDistance or 10000
                    if entry.cardStroke then entry.cardStroke.Color = Color3.fromRGB(110, 190, 255) end
                    entry.label.Text = string.format("%s · %s studs", player.DisplayName, formatStuds(distanceTo(part.Position)))
                elseif entry.bb then
                    entry.bb:Destroy()
                    entry.bb, entry.label, entry.card, entry.cardStroke = nil, nil, nil, nil
                end
            else
                local root = model and model:FindFirstChild("HumanoidRootPart")
                local entry = root and visuals[root]
                if entry and entry.tag == "teammate" then dropVisual(root) end
            end
        end
    end
end

local function updateExitVisuals()
    if not CFG.showExits then
        dropByTag("exit")
        return
    end

    local root = stillWater()
    if not root then return end

    local targets = {}
    local function add(part, text, color)
        if part and part:IsA("BasePart") then
            table.insert(targets, { part = part, text = text, color = color })
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

    for _, item in ipairs(targets) do
        if inRange(item.part.Position) then
            local entry = getVisual(item.part)
            entry.tag = "exit"
            styleHighlight(entry, item.color)
            if not entry.hl then styleBox(entry, item.color, 0.4) end
            if entry.cardStroke then entry.cardStroke.Color = item.color end
            if CFG.labels then
                if not entry.bb then

                    local offset = item.part.Size.Y * 0.5 + 2.5
                    entry.bb, entry.label, entry.card, entry.cardStroke = makeBillboard(item.part, offset, UDim2.fromOffset(170, 30), true)
                end
                entry.bb.MaxDistance = CFG.maxDistance > 0 and CFG.maxDistance or 10000
                entry.label.Text = CFG.labelDistance
                    and string.format("%s · %s studs", item.text, formatStuds(distanceTo(item.part.Position)))
                    or item.text
                entry.label.TextColor3 = item.color
            elseif entry.bb then
                removeBillboard(entry)
            end
        else
            local entry = visuals[item.part]
            if entry and entry.tag == "exit" then dropVisual(item.part) end
        end
    end
end

local function readDoorCode()
    local root = stillWater()
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

local function readDigitFrom(part)
    local surface = part:FindFirstChildOfClass("SurfaceGui")
    if not surface then return "?" end
    for _, descendant in ipairs(surface:GetDescendants()) do
        if descendant:IsA("TextLabel") and descendant.Text ~= "" then
            return descendant.Text
        end
    end
    return "?"
end

local function updateCodeLabels()
    if not CFG.showCode then
        dropByTag("code")
        return
    end

    local root = stillWater()
    local room = root and root:FindFirstChild("Room9_LockedExit")
    local gen = room and room:FindFirstChild("Gen")
    if not gen then return end

    for _, part in ipairs(gen:GetChildren()) do
        if part:IsA("BasePart") and part.Name == "CodeNumber" then
            if inRange(part.Position) then
                local entry = getVisual(part)
                entry.tag = "code"
                entry.part = part

                if CFG.labels then
                    if not entry.bb then
                        local offset = part.Size.Y * 0.5 + 1.5
                        entry.bb, entry.label, entry.card, entry.cardStroke = makeBillboard(part, offset, UDim2.fromOffset(90, 90), true)
                        if entry.label then entry.label.TextStrokeTransparency = 0.1 end
                    end
                    entry.bb.MaxDistance = CFG.maxDistance > 0 and CFG.maxDistance or 10000
                    entry.label.Text = string.format(
                        '#%s\n<font color="rgb(255,255,255)">%s</font>',
                        tostring(part:GetAttribute("CodeIndex") or "?"), readDigitFrom(part))
                elseif entry.bb then
                    removeBillboard(entry)
                end

                styleHighlight(entry, Color3.fromRGB(120, 255, 255))
                if not entry.hl then styleBox(entry, Color3.fromRGB(120, 255, 255), 0.35) end
                if entry.cardStroke then entry.cardStroke.Color = Color3.fromRGB(120, 255, 255) end
            else
                local entry = visuals[part]
                if entry and entry.tag == "code" then dropVisual(part) end
            end
        end
    end
end

local memory = {
    baseline = {},
    active = {},
    sequence = {},
    lastAt = 0,
    finished = nil,
}

local memoryTileCache = { at = 0, folder = nil, list = {} }

local function memoryTiles(force)
    local now = os.clock()
    local root = stillWater()
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

local function tileSignature(part)
    return table.concat({
        tostring(part.Color), tostring(part.Material),
        tostring(part.Transparency), tostring(part.Reflectance),
    }, "|")
end

local function memoryStep()
    local tiles = memoryTiles()
    if #tiles == 0 then
        memory.active = {}
        return
    end

    local now = os.clock()

    for _, part in ipairs(tiles) do
        local signature = tileSignature(part)
        local previous = memory.baseline[part]

        if previous == nil then
            memory.baseline[part] = signature
        elseif previous ~= signature then
            local lit = (not memory.active[part]) and (
                part.Transparency < 0.5
                or luma(part.Color) > 0.55
                or part.Material == Enum.Material.Neon
            )

            if lit then
                memory.active[part] = true
                memory.lastAt = now
                local id = part:GetAttribute("MemId")
                if id and not table.find(memory.sequence, id) then
                    table.insert(memory.sequence, id)
                end
            elseif memory.active[part] and part.Transparency >= 0.5 and luma(part.Color) < 0.4 then
                memory.active[part] = nil
            end
            memory.baseline[part] = signature
        end
    end

    if #memory.sequence > 0 and (now - memory.lastAt) > 3 then
        memory.finished = table.concat(memory.sequence, " → ")
        memory.sequence = {}
    end
end

local function memoryText()
    if #memory.sequence > 0 then
        local parts = {}
        for _, id in ipairs(memory.sequence) do parts[#parts + 1] = tostring(id) end
        return table.concat(parts, " → ")
    end
    return memory.finished or "Waiting for the flash..."
end

local function updateMemoryVisuals()
    for _, part in ipairs(memoryTiles()) do
        local entry = visuals[part]
        local showing = CFG.showMemoryNumbers and inRange(part.Position)

        if showing then
            entry = getVisual(part)
            entry.memory = true

            if CFG.labels then
                if not entry.bb then
                    local offset = part.Size.Y * 0.5 + 1.5
                    entry.bb, entry.label, entry.card, entry.cardStroke = makeBillboard(part, offset, UDim2.fromOffset(70, 40), true)
                    if entry.label then entry.label.TextColor3 = Color3.fromRGB(225, 205, 255) end
                end
                entry.bb.MaxDistance = CFG.maxDistance > 0 and CFG.maxDistance or 10000
                if entry.cardStroke then entry.cardStroke.Color = memory.active[part] and Color3.fromRGB(120, 255, 140) or Color3.fromRGB(185, 125, 255) end
                local order = table.find(memory.sequence, part:GetAttribute("MemId"))
                entry.label.Text = order
                    and ('<font color="rgb(120,255,140)">' .. order .. "</font>")
                    or tostring(part:GetAttribute("MemId") or "")
            elseif entry.bb then
                removeBillboard(entry)
            end

            if memory.active[part] and entry.box then
                entry.box.Color3 = Color3.fromRGB(120, 255, 140)
            end
        elseif entry and entry.memory then
            if entry.bb then removeBillboard(entry) end
            if entry.box then entry.box.Color3 = Color3.fromRGB(200, 120, 255) end
            entry.memory = nil
        end
    end
end

local alarmGui, alarmFrame
local alarmTween
local beep

local function ensureAlarmGui()
    if alarmGui and alarmGui.Parent then return end
    local parent = playerGui()
    if not parent then return end

    alarmGui = Instance.new("ScreenGui")
    alarmGui.Name = "StillWaterAlarm"
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

local function flashAlarm()
    if not CFG.alarmFlash then return end
    ensureAlarmGui()
    if not alarmFrame then return end
    if alarmTween then alarmTween:Cancel() end
    alarmFrame.BackgroundTransparency = 0.55
    alarmTween = TweenService:Create(alarmFrame, TweenInfo.new(0.55, Enum.EasingStyle.Quad), {
        BackgroundTransparency = 1,
    })
    alarmTween:Play()
end

local function playBeep()
    if beep and beep.Parent then
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

local function updateNearest(force)
    local now = os.clock()
    if not force and now - nearestUpdatedAt < 0.15 then return nearest end
    local best, bestDistance = nil, math.huge
    for _, part in ipairs(listeners()) do
        local distance = distanceTo(part.Position)
        if distance < bestDistance then
            best, bestDistance = part, distance
        end
    end
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

local function dangerStep()
    if not CFG.alarmEnabled then return end
    local now = os.clock()
    if now - lastDangerStep < 0.15 then return end
    lastDangerStep = now
    local current = updateNearest()
    local aggressive = current.state ~= nil and current.state ~= "Patrol"

    if CFG.alarmEnabled and current.part then
        if current.distance <= CFG.alarmDistance or aggressive then
            local now = os.clock()
            local interval = aggressive and 0.8 or 1.6
            if now - lastAlarmAt > interval then
                lastAlarmAt = now
                flashAlarm()
                playBeep()
            end
        end
    end
end

local function huntingMe()
    local root = rootPart()
    if not root then return false end
    for _, part in ipairs(listeners()) do
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

local BOOST_NAME = "StillWaterBoostVelocity"
local BOOST_RAMP = 10
local boost = { constraint = nil, attachment = nil, current = 0 }

local function purgeBoostParts(model)
    if not model then return end
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant.Name == BOOST_NAME then descendant:Destroy() end
    end
end

local boostFailureAt = 0

local function ensureBoostConstraint()
    local root = rootPart()
    if not root then return nil end

    if boost.constraint and boost.constraint.Parent == root
        and boost.attachment and boost.attachment.Parent == root then
        return boost.constraint
    end

    if os.clock() - boostFailureAt < 2 then return nil end

    purgeBoostParts(root)
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
        purgeBoostParts(root)
        boost.constraint = nil
        boost.attachment = nil
        return nil
    end

    boost.attachment = constraint.Attachment0
    boost.constraint = constraint
    boost.current = 0
    return constraint
end

local function releaseBoost(constraint, root)
    boost.current = 0
    if constraint then
        constraint.Enabled = false
        constraint.PlaneVelocity = Vector2.zero
    end
    boost.constraint = nil
    boost.attachment = nil
    purgeBoostParts(root)
end

local function onSolidGround()
    local hum = humanoid()
    if not hum then return false end
    return hum.FloorMaterial ~= Enum.Material.Air
end

local function inWater()
    return LocalPlayer:GetAttribute("InWater") == true
end

local function boostStep(deltaTime)
    if not CFG.speedEnabled and not boost.constraint then return end
    local root = rootPart()
    local hum = humanoid()

    if not root or not hum then
        boost.constraint = nil
        boost.attachment = nil
        boost.current = 0
        return
    end

    if not CFG.speedEnabled then
        if boost.constraint then releaseBoost(boost.constraint, root) end
        return
    end

    local constraint = ensureBoostConstraint()
    if not constraint then return end

    local move = hum.MoveDirection
    local walking = move.Magnitude > 0.05

    local allowed = walking and not inWater()

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

local function uiParent()
    local ok, hidden = pcall(function()
        return gethui and gethui()
    end)
    if ok and hidden then return hidden end
    return LocalPlayer:FindFirstChildOfClass("PlayerGui") or game:GetService("CoreGui")
end

do
    for _, gui in ipairs(uiParent():GetChildren()) do
        if gui:IsA("ScreenGui") and (gui.Name == "Still Water Hub" or gui.Name == "StillWaterAlarm" or gui.Name == "RobscriptAlarm" or gui.Name == "Robscript.com") then
            gui:Destroy()
        end
    end
    local staleMarks = workspace:FindFirstChild(MARKS_NAME)
    if staleMarks then staleMarks:Destroy() end
end

local Window = Rayfield:CreateWindow({
    name = "Still Water Hub",
    subtitle = "Survival tools and room helpers",
    theme = "cobalt",
    sidebarLayout = true,
    profile = "Still Water",
    showName = "Still Water",
    configuration = {
        autoSave = true,
        autoLoad = true,
        fileName = "StillWaterHub",
        customFolder = "Robscript",
    },
})

local OverviewTab = Window:CreateTab({ name = "Overview" })
local EspTab = Window:CreateTab({ name = "ESP" })
local PuzzleTab = Window:CreateTab({ name = "Puzzles" })
local MoveTab = Window:CreateTab({ name = "Movement" })
local SettingsTab = Window:CreateTab({ name = "Settings" })

local controls = {}
local uiCache = {}

local function notify(title, content, duration)
    Window:Notify({
        title = title,
        content = content or "",
        duration = duration or 4,
    })
end

local function addNote(tab, text)
    tab:CreateText({ name = "Quick note", text = text })
end

local function addToggle(tab, name, flag, value, callback)
    local handle = tab:CreateToggle({
        name = name,
        flag = flag,
        value = value,
        callback = callback,
    })
    controls[flag] = handle
    return handle
end

local function addSlider(tab, name, flag, range, increment, value, suffix, callback)
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

local function setControl(flag, value)
    local handle = controls[flag]
    if handle then
        pcall(function() handle:Set(value) end)
    end
end

local function appendChanged(console, key, value)
    value = tostring(value)
    if uiCache[key] == value then return end
    uiCache[key] = value
    console:Append(value)
end

local function setStatChanged(stat, key, value)
    if uiCache[key] == value then return end
    uiCache[key] = value
    stat:Set(value)
end

addNote(OverviewTab, "Your quick view of the run. Check the closest Listener and room details before moving on.")
OverviewTab:CreateSection({ name = "Run status" })
local roomStat = OverviewTab:CreateStat({ name = "Current room", value = 0 })
local nearestStat = OverviewTab:CreateStat({ name = "Listener distance", value = 0, suffix = " studs" })
local overviewConsole = OverviewTab:CreateConsole({
    name = "Run details",
    text = "Waiting for game data...",
    height = 126,
    follow = true,
    maxLines = 30,
})
local threatConsole = OverviewTab:CreateConsole({
    name = "Listener status by room",
    text = "Waiting for Listener data...",
    height = 150,
    follow = true,
    maxLines = 45,
})
addNote(EspTab, "Choose the markers you need. Turning off extra boxes can make busy rooms easier to read.")
EspTab:CreateSection({ name = "Objects" })
addToggle(EspTab, "Show Listener", "ShowListener", true, function(value)
    CFG.showListener = value
    if not value then dropByTag("listener") end
end)
addToggle(EspTab, "Show Teammates", "ShowTeammates", false, function(value)
    CFG.showTeammates = value
    if not value then dropByTag("teammate") end
end)
addToggle(EspTab, "Show Pebble Pickups", "ShowPickups", false, function(value)
    CFG.showPickups = value
    if not value then dropByTag("pickup") end
end)
addToggle(EspTab, "Show Platforms", "ShowPlatforms", false, function(value)
    CFG.showPlatforms = value
    if not value and not CFG.showMemoryNumbers then dropByTag("platform") end
end)
addToggle(EspTab, "Safe Platforms Only", "PlatformSafeOnly", false, function(value)
    CFG.platformSafeOnly = value
end)
addToggle(EspTab, "Show Checkpoints and Exits", "ShowExits", false, function(value)
    CFG.showExits = value
    if not value then dropByTag("exit") end
end)
addToggle(EspTab, "Show Door Code Digits", "ShowCode", true, function(value)
    CFG.showCode = value
    if not value then dropByTag("code") end
end)
addToggle(EspTab, "Show Memory Tile Numbers", "ShowMemoryNumbers", false, function(value)
    CFG.showMemoryNumbers = value
    if not value and not CFG.showPlatforms then dropByTag("platform") end
end)

EspTab:CreateSection({ name = "Appearance" })
addToggle(EspTab, "Highlight Fill", "Highlights", true, function(value)
    CFG.highlights = value
    if not value then
        for _, entry in pairs(visuals) do releaseHighlight(entry) end
    end
end)
addToggle(EspTab, "3D Box Outlines", "BoxOutlines", true, function(value)
    CFG.boxes = value
    if not value then
        for _, entry in pairs(visuals) do
            if entry.box then entry.box:Destroy(); entry.box = nil end
        end
    end
end)
addToggle(EspTab, "Floating Labels", "Labels", true, function(value)
    CFG.labels = value
    if not value then
        for _, entry in pairs(visuals) do
            if entry.bb then removeBillboard(entry) end
        end
    end
end)
addToggle(EspTab, "Show Distance in Labels", "LabelDistance", true, function(value)
    CFG.labelDistance = value
end)
addToggle(EspTab, "Show Listener Destination", "ListenerTarget", false, function(value)
    CFG.listenerTarget = value
end)
addSlider(EspTab, "ESP Range", "MaxDistance", { 0, 500 }, 10, 0, " studs", function(value)
    CFG.maxDistance = value
end)
addSlider(EspTab, "Fill Transparency", "FillOpacity", { 0, 80 }, 5, 55, "%", function(value)
    CFG.fillOpacity = value / 100
end)
addSlider(EspTab, "Box Transparency", "BoxOpacity", { 10, 90 }, 5, 60, "%", function(value)
    CFG.boxOpacity = value / 100
end)

EspTab:CreateSection({ name = "ESP Status" })
local highlightStat = EspTab:CreateStat({ name = "Active highlights", value = 0 })
local boxStat = EspTab:CreateStat({ name = "Active boxes", value = 0 })
EspTab:CreateButton({
    name = "Clear All ESP",
    callback = function()
        for _, flag in ipairs({ "ShowListener", "ShowTeammates", "ShowPickups", "ShowPlatforms", "ShowExits", "ShowCode", "ShowMemoryNumbers" }) do
            setControl(flag, false)
        end
        for part in pairs(visuals) do dropVisual(part) end
        notify("ESP cleared", "All ESP markers have been removed.", 3)
    end,
})

addNote(PuzzleTab, "The door code appears when room 9 loads. The memory helper records the order of the lights in room 7.")
PuzzleTab:CreateSection({ name = "Room 9 Door Code" })
local codeConsole = PuzzleTab:CreateConsole({
    name = "Door code",
    text = "Room 9 has not loaded yet.",
    height = 82,
    follow = true,
    maxLines = 12,
})
PuzzleTab:CreateButton({
    name = "Copy Door Code",
    callback = function()
        local code = readDoorCode()
        if not code or code == "? ? ? ?" then
            notify("Code not ready", "Visit the room 9 pillars first.", 4)
            return
        end
        local copied = pcall(function()
            if type(setclipboard) ~= "function" then error("Clipboard is unavailable") end
            setclipboard(code)
        end)
        notify(copied and "Door code copied" or "Door code", copied and code or "Clipboard is not available in this executor.", 4)
    end,
})
PuzzleTab:CreateSection({ name = "Room 7 Memory Bridge" })
local memoryConsole = PuzzleTab:CreateConsole({
    name = "Light sequence",
    text = "Waiting for the tiles to light up...",
    height = 90,
    follow = true,
    maxLines = 14,
})
PuzzleTab:CreateButton({
    name = "Reset Memory Recording",
    callback = function()
        memory.sequence = {}
        memory.finished = nil
        memory.baseline = {}
        memory.active = {}
        memory.lastAt = 0
        notify("Memory recording reset", "Ready to record the next sequence.", 3)
    end,
})

addNote(MoveTab, "The speed boost only runs while you move and pauses in water. Keep the setting at a level that feels stable.")
MoveTab:CreateSection({ name = "Movement" })
addToggle(MoveTab, "Enable Speed Boost", "SpeedEnabled", false, function(value)
    CFG.speedEnabled = value
end)
addSlider(MoveTab, "Movement Speed", "SpeedValue", { SPEED_MIN, SPEED_MAX }, 1, 30, " studs/s", function(value)
    CFG.speedValue = value
end)
local speedStat = MoveTab:CreateStat({ name = "Current Boost", value = 0, suffix = " studs/s" })
local movementConsole = MoveTab:CreateConsole({
    name = "Movement status",
    text = "Boost is off.",
    height = 76,
    follow = true,
    maxLines = 10,
})

addNote(SettingsTab, "Change the look, save your setup, or check the items and details for the current run.")
SettingsTab:CreateSection({ name = "Run Details" })
local runConsole = SettingsTab:CreateConsole({
    name = "Current run",
    text = "Waiting for game data...",
    height = 128,
    follow = true,
    maxLines = 24,
})
SettingsTab:CreateSection({ name = "Appearance" })
SettingsTab:CreateDropdown({
    name = "Theme",
    options = { "default", "cobalt", "ember", "amethyst", "frost", "rose" },
    value = "cobalt",
    callback = function(selected)
        local theme = type(selected) == "table" and selected[1] or selected
        if type(theme) == "string" then
            pcall(function() Window:ChangeTheme(theme) end)
        end
    end,
})
SettingsTab:CreateSection({ name = "Configuration" })
SettingsTab:CreateButton({
    name = "Save Settings",
    callback = function()
        local ok, saved = pcall(function() return Window:Save() end)
        notify(ok and saved and "Settings saved" or "Save failed", ok and saved and "Your current setup has been saved." or "Check whether this executor supports file saving.", 4)
    end,
})
SettingsTab:CreateButton({
    name = "Load Settings",
    callback = function()
        local ok, loaded = pcall(function() return Window:Load() end)
        notify(ok and loaded and "Settings loaded" or "Load failed", ok and loaded and "Your saved setup has been loaded." or "No saved setup was found or file access is unavailable.", 4)
    end,
})
SettingsTab:CreateButton({
    name = "Reset ESP Settings",
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
        for flag, value in pairs(defaults) do setControl(flag, value) end
        for part in pairs(visuals) do dropVisual(part) end
        notify("ESP settings reset", "The default ESP setup is back.", 3)
    end,
})
SettingsTab:CreateButton({
    name = "Rejoin This Server",
    callback = function()
        local ok = pcall(function()
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end)
        if not ok then notify("Rejoin failed", "The server could not be joined again.", 4) end
    end,
})

local function updateUiPanels()
    local current = updateNearest()
    local distance = current.distance < math.huge and math.floor(current.distance + 0.5) or 0
    setStatChanged(nearestStat, "stat-nearest", distance)
    setStatChanged(roomStat, "stat-room", currentRoomIndex())
    setStatChanged(highlightStat, "stat-highlights", highlightCount)

    local boxes = 0
    for _, entry in pairs(visuals) do
        if entry.box then boxes = boxes + 1 end
    end
    setStatChanged(boxStat, "stat-boxes", boxes)
    setStatChanged(speedStat, "stat-speed", math.floor(boost.current + 0.5))

    if not CFG.speedEnabled then
        appendChanged(movementConsole, "movement", "Boost is off.")
    elseif inWater() then
        appendChanged(movementConsole, "movement", "Boost is paused while you are in water.")
    else
        local movementState = onSolidGround() and "on the ground" or "in the air"
        appendChanged(movementConsole, "movement", string.format("Boost is active at about %d studs/s · %s.", math.floor(boost.current + 0.5), movementState))
    end

    local nearestLine
    if not current.part then
        nearestLine = "No Listener is loaded."
    else
        local danger = huntingMe() and " · Hunting you" or ""
        nearestLine = string.format("Room %s · %s · %d studs away%s", tostring(current.room or "?"), tostring(current.state or "?"), distance, danger)
    end
    appendChanged(overviewConsole, "overview-nearest", nearestLine)

    local list = {}
    for _, part in ipairs(listeners()) do list[#list + 1] = part end
    table.sort(list, function(a, b)
        return (tonumber(a:GetAttribute("Room")) or 0) < (tonumber(b:GetAttribute("Room")) or 0)
    end)
    local rows = {}
    for _, part in ipairs(list) do
        rows[#rows + 1] = string.format("Room %s · %s · %s studs", tostring(part:GetAttribute("Room") or "?"), tostring(part:GetAttribute("State") or "?"), formatStuds(distanceTo(part.Position)))
    end
    if #rows == 0 then rows[1] = "No Listener data is available." end
    appendChanged(threatConsole, "overview-rooms", table.concat(rows, "\n"))

    local roomIndex = currentRoomIndex()
    local roomName = roomIndex == 0 and "Lobby" or (GAME.rooms[roomIndex] and GAME.rooms[roomIndex].name or "Unknown")
    local root = stillWater()
    local mode = root and tostring(root:GetAttribute("Mode") or "—") or "—"
    local timer = guiText("StillWaterUI", "ClientHUD", "Timer") or "—"
    local coins = guiText("StillWaterRunUI", "RunUI", "Coins", "Amount") or "—"
    local detail = string.format("Room: %s\nMode: %s\nTime: %s\nCoins: %s", roomName, mode, timer, coins)
    appendChanged(runConsole, "run-details", detail)

    local hotbar = playerGui()
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
    if #inventory > 0 then appendChanged(runConsole, "run-inventory", "Items: " .. table.concat(inventory, " · ")) end

    local code = readDoorCode()
    local codeLine = code and ("Room 9 code: " .. code) or "Room 9 is not loaded yet."
    appendChanged(codeConsole, "puzzle-code", codeLine)
    appendChanged(memoryConsole, "puzzle-memory", "Sequence: " .. memoryText())
end

keep(UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.RightControl then
        Window:ToggleHide()
    end
end))

local lastFrameAt = os.clock()

keep(RunService.RenderStepped:Connect(function()
    local now = os.clock()
    local deltaTime = math.clamp(now - lastFrameAt, 0.001, 0.2)
    lastFrameAt = now
    boostStep(deltaTime)
end))

keep(RunService.Heartbeat:Connect(dangerStep))

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
            pcall(updateListenerVisuals)
            nextListener = now + 0.12
        end
        if now >= nextPrune then
            pcall(pruneVisuals)
            nextPrune = now + 0.8
        end
        if now >= nextPlatform then
            pcall(updatePlatformVisuals)
            nextPlatform = now + 1.0
        end
        if now >= nextCode then
            pcall(updateCodeLabels)
            nextCode = now + 0.8
        end
        if now >= nextMemoryVisual then
            pcall(updateMemoryVisuals)
            nextMemoryVisual = now + 0.35
        end
        if now >= nextPickup then
            pcall(updatePickupVisuals)
            nextPickup = now + 0.6
        end
        if now >= nextPlayers then
            pcall(updatePlayerVisuals)
            nextPlayers = now + 0.6
        end
        if now >= nextExit then
            pcall(updateExitVisuals)
            nextExit = now + 1.0
        end
        if now >= nextMemoryRead then
            pcall(memoryStep)
            nextMemoryRead = now + 0.12
        end
        if now >= nextUi then
            pcall(updateUiPanels)
            nextUi = now + 0.7
        end

        task.wait(0.05)
    end
end)

keep(LocalPlayer.CharacterAdded:Connect(function(model)
    task.wait(1)
    purgeBoostParts(model)
    boost.constraint = nil
    boost.attachment = nil
    boost.current = 0
end))

local api = {
    cfg = CFG,
    window = Window,

    listener = function() return updateNearest() end,

    code = function() return readDoorCode() end,

    memory = function() return memoryText() end,

    boostSpeed = function() return boost.current end,

    clearEsp = function()
        for part in pairs(visuals) do dropVisual(part) end
    end,

    unload = function()
        stopAll()
        for part in pairs(visuals) do
            dropVisual(part)
        end
        highlightCount = 0
        if marksFolder then
            pcall(function() marksFolder:Destroy() end)
            marksFolder = nil
        end
        purgeBoostParts(rootPart())
        boost.constraint = nil
        boost.attachment = nil
        boost.current = 0
        pcall(function() Window:Unload() end)
        if alarmTween then pcall(function() alarmTween:Cancel() end) end
        if alarmGui then pcall(function() alarmGui:Destroy() end) end
        if beep then pcall(function() beep:Destroy() end) end
        if getgenv then
            getgenv().Robscript = nil
            getgenv().StillWaterHub = nil
        end
    end,
}

if getgenv then
    getgenv().Robscript = api
    getgenv().StillWaterHub = api
end

notify("Still Water Hub loaded", "Press RightControl to hide or show the window. Listener ESP is enabled.", 5)

return api
