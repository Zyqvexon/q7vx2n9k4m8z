if _G.__ThrowFood_Cleanup then
    pcall(_G.__ThrowFood_Cleanup)
end

local Window

local function notify(data)
    if not Window then
        return
    end

    data = data or {}
    pcall(function()
        Window:Notify({
            title = data.Title or data.title or data.name or "VeloxHub",
            content = data.Content or data.content or "",
            duration = data.Duration or data.duration,
            icon = data.Icon or data.icon,
        })
    end)
end

pcall(function()
    local CoreGui = game:GetService("CoreGui")
    local target = (gethui and gethui()) or CoreGui:FindFirstChild("RobloxGui") or CoreGui
    if target then
        for _, c in ipairs(target:GetChildren()) do
            if c.Name:find("Rayfield") or c.Name:find("VeloxHub") or c.Name:find("JenicakesHub") or c.Name:find("Jenicakes_") then
                c:Destroy()
            end
        end
    end
end)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getRootPart()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local ActiveConnections = {}
local function trackConnect(signal, fn)
    local conn = signal:Connect(fn)
    table.insert(ActiveConnections, conn)
    return conn
end

local SharedFolder = ReplicatedStorage:FindFirstChild("Shared")
local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")

local function safeRequire(path)
    if not path then return nil end
    local ok, res = pcall(require, path)
    if ok then return res end
    return nil
end

local RemotesSharedModule = safeRequire(SharedFolder and SharedFolder:FindFirstChild("Remotes"))

local function getRemote(name)
    if RemotesFolder then
        return RemotesFolder:FindFirstChild(name)
    end
    return nil
end

local function invokeRemote(name, ...)
    if RemotesSharedModule then
        local fn = RemotesSharedModule.Invoke or RemotesSharedModule.invoke
        if type(fn) == "function" then
            local ok, res = pcall(fn, name, ...)
            if ok and res ~= nil then return res end
            local ok2, res2 = pcall(fn, RemotesSharedModule, name, ...)
            if ok2 and res2 ~= nil then return res2 end
        end
    end
    local rem = getRemote(name)
    if rem then
        if rem:IsA("RemoteFunction") then
            local ok, res = pcall(rem.InvokeServer, rem, ...)
            if ok then return res end
        elseif rem:IsA("RemoteEvent") then
            pcall(rem.FireServer, rem, ...)
            return { Ok = true }
        end
    end
    return nil
end

local function fireRemote(name, ...)
    if RemotesSharedModule then
        local fn = RemotesSharedModule.Fire or RemotesSharedModule.fire
        if type(fn) == "function" then
            local ok = pcall(fn, name, ...)
            if ok then return end
            pcall(fn, RemotesSharedModule, name, ...)
            return
        end
    end
    local rem = getRemote(name)
    if rem then
        if rem:IsA("RemoteEvent") then
            pcall(rem.FireServer, rem, ...)
        elseif rem:IsA("RemoteFunction") then
            pcall(rem.InvokeServer, rem, ...)
        end
    end
end

local function getControllersFolder()
    local ps = LocalPlayer:FindFirstChild("PlayerScripts")
    local client = ps and (ps:FindFirstChild("Client") or ps:WaitForChild("Client", 3))
    return client and (client:FindFirstChild("Controllers") or client:WaitForChild("Controllers", 3))
end

local Controllers = getControllersFolder()
local ThrowController    = Controllers and safeRequire(Controllers:FindFirstChild("ThrowController"))
local ThrowMeter         = Controllers and safeRequire(Controllers:FindFirstChild("ThrowMeter"))
local RevealSequence     = Controllers and safeRequire(Controllers:FindFirstChild("RevealSequence"))
local TrainingController = Controllers and safeRequire(Controllers:FindFirstChild("TrainingController"))
local DataController     = Controllers and safeRequire(Controllers:FindFirstChild("DataController"))
local ClientState        = Controllers and safeRequire(Controllers:FindFirstChild("ClientState"))

local ConfigFolder = ReplicatedStorage:FindFirstChild("Config") or ReplicatedStorage:WaitForChild("Config", 3)
local GameConfig   = ConfigFolder and safeRequire(ConfigFolder:FindFirstChild("GameConfig"))
local StandsConfig = ConfigFolder and safeRequire(ConfigFolder:FindFirstChild("StandsConfig"))
local FoodsConfig  = ConfigFolder and safeRequire(ConfigFolder:FindFirstChild("FoodsConfig"))
local AreasConfig  = ConfigFolder and safeRequire(ConfigFolder:FindFirstChild("AreasConfig"))
local BalanceCurve = SharedFolder and safeRequire(SharedFolder:FindFirstChild("BalanceCurve"))
local Boosts       = SharedFolder and safeRequire(SharedFolder:FindFirstChild("Boosts"))

local Settings = {
    AutoTraining       = false,
    AutoTapBonus       = true,
    FastTraining       = true,
    TrainingSpeed      = 3.0,
    AutoStandUpgrade   = true,

    AutoThrow          = false,
    ThrowMode          = "Visual (With Animation & Meter)",
    AlwaysPerfectThrow = true,
    AutoSkipCutscene   = true,
    AutoUseSuperThrow  = false,
    ThrowDelay         = 0.35,

    AutoEquipBest      = false,
    AutoUpgradeFence   = false,

    AutoClaimOffline   = true,
    AutoClaimGifts     = true,
    AutoBuyBestFood    = false,
    AutoEquipBestFood  = false,

    SpeedEnabled       = false,
    WalkSpeed          = 35,
    SpeedMode          = "CFrame (Bypass)",
    JumpEnabled        = false,
    JumpPower          = 65,
    InfiniteJump       = false,
    NoClip             = false,
    AntiAFK            = true,
}

local isThrowLoopRunning = false
local isManualOneThrowRunning = false
local isSpamBurstRunning = false

if not _G.__OrigThrowMeterNew and ThrowMeter and type(ThrowMeter.new) == "function" then
    _G.__OrigThrowMeterNew = ThrowMeter.new
end

if not _G.__OrigThrowMeterRun and ThrowMeter and type(ThrowMeter.Run) == "function" then
    _G.__OrigThrowMeterRun = ThrowMeter.Run
end

if not _G.__OrigRevealPlay and RevealSequence and type(RevealSequence.Play) == "function" then
    _G.__OrigRevealPlay = RevealSequence.Play
end

if not _G.__OrigRevealRun and RevealSequence and type(RevealSequence.Run) == "function" then
    _G.__OrigRevealRun = RevealSequence.Run
end

if not _G.__OrigThrowStart and ThrowController and type(ThrowController.Start) == "function" then
    _G.__OrigThrowStart = ThrowController.Start
end

if ThrowMeter and type(_G.__OrigThrowMeterNew) == "function" then
    ThrowMeter.new = function(...)
        local inst = _G.__OrigThrowMeterNew(...)
        if inst and type(inst.Run) == "function" then
            local rawInstRun = inst.Run
            inst.Run = function(self, ...)
                local isAutoMode = Settings.AutoThrow or isManualOneThrowRunning or isSpamBurstRunning
                if isAutoMode then
                    if Settings.AlwaysPerfectThrow then
                        task.wait(0.28)
                        local ratings = GameConfig and GameConfig.Throw and GameConfig.Throw.MeterRatings
                        local maxRating = (ratings and ratings[#ratings]) or { Text = "PERFECT!", Color = Color3.fromRGB(255, 215, 0) }
                        local bonusStuds = (GameConfig and GameConfig.Throw and GameConfig.Throw.MeterBonusStuds) or 20
                        return 1.0, maxRating, bonusStuds
                    else
                        task.wait(0.25)
                        return 0.85, nil, 10
                    end
                end

                if Settings.AlwaysPerfectThrow then
                    self.Locked = true
                else
                    self.Locked = false
                end

                return rawInstRun(self, ...)
            end
        end
        return inst
    end
end

if ThrowMeter and type(_G.__OrigThrowMeterRun) == "function" then
    ThrowMeter.Run = function(self, ...)
        local isAutoMode = Settings.AutoThrow or isManualOneThrowRunning or isSpamBurstRunning
        if isAutoMode then
            if Settings.AlwaysPerfectThrow then
                task.wait(0.28)
                local ratings = GameConfig and GameConfig.Throw and GameConfig.Throw.MeterRatings
                local maxRating = (ratings and ratings[#ratings]) or { Text = "PERFECT!", Color = Color3.fromRGB(255, 215, 0) }
                local bonusStuds = (GameConfig and GameConfig.Throw and GameConfig.Throw.MeterBonusStuds) or 20
                return 1.0, maxRating, bonusStuds
            else
                task.wait(0.25)
                return 0.85, nil, 10
            end
        end

        if Settings.AlwaysPerfectThrow then
            self.Locked = true
        else
            self.Locked = false
        end

        return _G.__OrigThrowMeterRun(self, ...)
    end
end

if RevealSequence then
    if type(_G.__OrigRevealPlay) == "function" then
        RevealSequence.Play = function(params, ...)
            local isAutoMode = Settings.AutoThrow or isManualOneThrowRunning or isSpamBurstRunning
            if isAutoMode and Settings.AutoSkipCutscene then
                task.wait(0.12)
                return
            end
            return _G.__OrigRevealPlay(params, ...)
        end
    end
    if type(_G.__OrigRevealRun) == "function" then
        RevealSequence.Run = function(...)
            local isAutoMode = Settings.AutoThrow or isManualOneThrowRunning or isSpamBurstRunning
            if isAutoMode and Settings.AutoSkipCutscene then
                task.wait(0.12)
                return
            end
            return _G.__OrigRevealRun(...)
        end
    end
end

local function triggerButton(btn)
    if not btn or not btn:IsA("GuiButton") then return end
    pcall(function()
        if type(firesignal) == "function" then
            firesignal(btn.Activated)
            firesignal(btn.MouseButton1Click)
        end
    end)
    pcall(function()
        if type(getconnections) == "function" then
            for _, sig in ipairs({ btn.Activated, btn.MouseButton1Click }) do
                local ok, conns = pcall(getconnections, sig)
                if ok and conns then
                    for _, conn in ipairs(conns) do
                        if type(conn.Fire) == "function" then
                            conn:Fire()
                        elseif type(conn.Function) == "function" then
                            conn.Function()
                        end
                    end
                end
            end
        end
    end)
    pcall(function()
        if type(btn.Activate) == "function" then
            btn:Activate()
        end
    end)
end

local function autoClickTapBonus(btn)
    if not Settings.AutoTapBonus then return end
    if btn and btn:IsA("ImageButton") and btn.Parent and btn.Parent.Name == "TapBonusLayer" then
        task.defer(function()
            if btn.Parent then
                for _ = 1, 3 do
                    triggerButton(btn)
                    task.wait(0.02)
                end
            end
        end)
    end
end

trackConnect(LocalPlayer.PlayerGui.DescendantAdded, function(desc)
    if desc:IsA("ImageButton") and desc.Parent and desc.Parent.Name == "TapBonusLayer" then
        autoClickTapBonus(desc)
    end
end)

local TrainingBonusRemote = getRemote("Training_Bonus")
if TrainingBonusRemote then
    trackConnect(TrainingBonusRemote.OnClientEvent, function(rawBonus)
        if not Settings.AutoTapBonus then return end
        local bonusId = (type(rawBonus) == "table" and (rawBonus.Id or rawBonus[1])) or rawBonus
        if bonusId then
            task.spawn(function()
                for _ = 1, 3 do
                    invokeRemote("Training_TapBonus", bonusId)
                    task.wait(0.04)
                end
            end)
        end
        local ts = LocalPlayer.PlayerGui:FindFirstChild("TrainingSequence")
        local layer = ts and ts:FindFirstChild("TapBonusLayer")
        if layer then
            for _, c in ipairs(layer:GetChildren()) do
                autoClickTapBonus(c)
            end
        end
    end)
end

trackConnect(RunService.Heartbeat, function()
    if Settings.AutoTapBonus then
        local ts = LocalPlayer.PlayerGui:FindFirstChild("TrainingSequence")
        local layer = ts and ts:FindFirstChild("TapBonusLayer")
        if layer then
            for _, btn in ipairs(layer:GetChildren()) do
                if btn:IsA("ImageButton") and btn.Active and btn.Parent then
                    autoClickTapBonus(btn)
                end
            end
        end
    end

    if Settings.AutoTraining and Settings.FastTraining then
        local hum = getHumanoid()
        if hum then
            for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
                local name = track.Name:lower()
                if name:find("train") or name:find("pull") or name:find("bar") or name:find("workout") or (track.Length > 0 and track.Speed == 1) then
                    local targetSpeed = Settings.TrainingSpeed or 3.0
                    if track.Speed ~= targetSpeed and track.Speed > 0 then
                        track:AdjustSpeed(targetSpeed)
                    end
                end
            end
        end
    end
end)

local function getMyPlot()
    local idx = LocalPlayer:GetAttribute("PlotIndex") or (DataController and DataController:Get("PlotIndex")) or 1
    local plots = Workspace:FindFirstChild("Plots")
    return plots and plots:FindFirstChild(tostring(idx))
end

local function getTrainingSpot()
    local lpp = Workspace:FindFirstChild("LocalPlotProps")
    if lpp and lpp:FindFirstChild("TrainingArea") and lpp.TrainingArea:FindFirstChild("TrainingSpot") then
        local spot = lpp.TrainingArea.TrainingSpot
        if spot:IsA("BasePart") then return spot end
    end
    return nil
end

local function getCrossLine()
    local area = Workspace:FindFirstChild("StarterArea")
    return area and area:FindFirstChild("CrossLine")
end

local function teleportTo(cf)
    local hrp = getRootPart()
    if hrp then
        hrp.CFrame = typeof(cf) == "CFrame" and cf or CFrame.new(cf)
    end
end

local function ensurePastLine()
    local hrp = getRootPart()
    if not hrp then return false end
    local crossLine = getCrossLine()
    if crossLine then
        if hrp.Position.Z > crossLine.Position.Z - 4 then
            hrp.CFrame = CFrame.new(crossLine.Position.X, crossLine.Position.Y + 2, crossLine.Position.Z - 8)
        end
    else
        hrp.CFrame = CFrame.new(0, 3.5, -42)
    end
    return true
end

local function teleportBackFromLine()
    local hrp = getRootPart()
    if not hrp then return end
    local crossLine = getCrossLine()
    if crossLine then
        hrp.CFrame = CFrame.new(crossLine.Position.X, crossLine.Position.Y + 2, crossLine.Position.Z + 20)
    else
        hrp.CFrame = CFrame.new(0, 3.5, -15)
    end
end

local function getPlayerMoney()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    local m = ls and ls:FindFirstChild("Money")
    if m then
        local raw = tostring(m.Value):gsub("%$", ""):gsub(",", "")
        local num = tonumber(raw)
        if num then return num end
    end
    if DataController and DataController:IsReady() then
        return tonumber(DataController:Get("Money")) or 0
    end
    return 0
end

local function getNextStandPrice()
    if not StandsConfig or not StandsConfig.Get or not DataController then return nil end
    local curStand = tonumber(DataController:Get("Stand")) or 1
    local count = (StandsConfig.Count and StandsConfig.Count()) or 58
    if curStand >= count then return nil end
    local nextStand = StandsConfig.Get(curStand + 1)
    if not nextStand then return nil end
    if BalanceCurve and BalanceCurve.GetItemPrice then
        local ok, price = pcall(BalanceCurve.GetItemPrice, LocalPlayer, nextStand)
        if ok and tonumber(price) then return tonumber(price) end
    end
    return tonumber(nextStand.Price) or nil
end

local function getCurrentStandInfo()
    local curStand = (DataController and tonumber(DataController:Get("Stand"))) or 1
    local curData = (StandsConfig and StandsConfig.Get and StandsConfig.Get(curStand)) or nil
    local nextData = (StandsConfig and StandsConfig.Get and StandsConfig.Get(curStand + 1)) or nil
    local curXp = (curData and curData.XpPerRep) or 5
    local nextXp = (nextData and nextData.XpPerRep) or nil
    local nextPrice = getNextStandPrice()
    local standName = (curData and curData.Name) or ("Stand #" .. tostring(curStand))
    return curStand, standName, curXp, nextPrice, nextXp
end

local lastThrowAt = 0
local cooldownEstimate = 1.15
local cooldownStrikes = 0
isThrowLoopRunning = false

local function resetThrowState()
    if ClientState and ClientState.Busy then
        ClientState.Busy = nil
    end
    pcall(function() invokeRemote("Throw_Cancel") end)
    task.wait(0.05)
    pcall(function() invokeRemote("Throw_Cancel") end)
end

local function waitForThrowCooldown()
    local elapsed = os.clock() - lastThrowAt
    local remain = cooldownEstimate - elapsed
    if remain > 0.05 then
        task.wait(remain + 0.02)
    end
end

local function performVisualThrow()
    local hrp = getRootPart()
    if not hrp or not Settings.AutoThrow then return false end

    ensurePastLine()
    task.wait(0.08)

    if not Settings.AutoThrow then return false end

    if Settings.AutoUseSuperThrow then
        pcall(function() invokeRemote("Throw_UseSuper") end)
    end

    if ThrowController then
        local startFn = ThrowController.Start or ThrowController.start
        if type(startFn) == "function" then
            pcall(function()
                startFn(ThrowController)
            end)
        end
    else
        invokeRemote("Throw_Start")
        invokeRemote("Throw_Resolve", 1)
        task.wait(0.3)
        invokeRemote("Throw_Complete")
    end

    local delayTime = math.max(Settings.ThrowDelay or 0.35, 0.2) + 0.7
    local startTime = os.clock()
    while Settings.AutoThrow and (os.clock() - startTime < delayTime) do
        task.wait(0.04)
    end

    lastThrowAt = os.clock()
    return true
end

local function performInstantThrow()
    local hrp = getRootPart()
    if not hrp or not Settings.AutoThrow then return false, false end

    ensurePastLine()
    waitForThrowCooldown()

    if not Settings.AutoThrow then return false, false end

    if ClientState then
        ClientState.Busy = "Throw"
    end

    local wasAnchored = hrp.Anchored
    hrp.Anchored = true

    if Settings.AutoUseSuperThrow then
        pcall(function() invokeRemote("Throw_UseSuper") end)
    end

    local startResult = invokeRemote("Throw_Start")
    local cooldownHit = false
    local complete = false

    if type(startResult) == "table" and startResult.Ok == true then
        local resolveResult = invokeRemote("Throw_Resolve", 1)

        if type(resolveResult) == "table" and resolveResult.Ok == true then
            local waitTime = math.max(Settings.ThrowDelay or 0.35, 0.15)
            local startTime = os.clock()

            while Settings.AutoThrow and (os.clock() - startTime < waitTime) do
                task.wait(0.02)
            end

            if not Settings.AutoThrow then
                pcall(function() invokeRemote("Throw_Cancel") end)
                if ClientState then ClientState.Busy = nil end
                hrp.Anchored = wasAnchored
                return false, false
            end

            invokeRemote("Throw_Complete")
            lastThrowAt = os.clock()
            cooldownStrikes = 0
            complete = true
        else
            pcall(function() invokeRemote("Throw_Cancel") end)
        end
    else
        if type(startResult) == "table" and startResult.Reason == "Cooldown" then
            cooldownHit = true
            cooldownStrikes = cooldownStrikes + 1
            if cooldownStrikes >= 2 then
                cooldownEstimate = math.min(cooldownEstimate + 0.25, 2.5)
                cooldownStrikes = 0
            end
        else
            pcall(function() invokeRemote("Throw_Cancel") end)
        end
    end

    hrp.Anchored = wasAnchored
    if ClientState then ClientState.Busy = nil end
    return complete, cooldownHit
end

local function stopAutoThrowEngine()
    Settings.AutoThrow = false
    isThrowLoopRunning = false
    isManualOneThrowRunning = false
    isSpamBurstRunning = false

    resetThrowState()

    if ThrowController then
        pcall(function()
            if type(ThrowController.Stop) == "function" then ThrowController.Stop(ThrowController) end
            if type(ThrowController.Cancel) == "function" then ThrowController.Cancel(ThrowController) end
            if ThrowController._running ~= nil then ThrowController._running = false end
            if ThrowController.Running ~= nil then ThrowController.Running = false end
        end)
    end

    local hrp = getRootPart()
    if hrp then
        hrp.Anchored = false
    end

    pcall(teleportBackFromLine)
end

local function startAutoThrowEngine()
    if isThrowLoopRunning then return end
    isThrowLoopRunning = true

    task.spawn(function()
        ensurePastLine()

        while Settings.AutoThrow do
            if TrainingController and TrainingController.IsRunning() then
                pcall(function() TrainingController.Stop() end)
                pcall(function() invokeRemote("Training_Stop") end)
                task.wait(0.2)
            end

            if Settings.ThrowMode == "Visual (With Animation & Meter)" then
                pcall(performVisualThrow)
            else
                local ok, _, cooldownHit = pcall(performInstantThrow)
                if not ok or not Settings.AutoThrow then
                    task.wait(0.1)
                elseif cooldownHit then
                    task.wait(0.1)
                else
                    task.wait(0.04)
                end
            end
        end

        stopAutoThrowEngine()
    end)
end

local function performManualSingleThrow()
    if isThrowLoopRunning then
        pcall(function()
            notify({
                Title = "Manual Throw",
                Content = "Auto Throw bot is currently active. Turn it OFF first to throw manually!",
                Duration = 2.5,
                Icon = "alert-triangle"
            })
        end)
        return
    end

    if isManualOneThrowRunning or isSpamBurstRunning then
        pcall(function()
            notify({
                Title = "Manual Throw",
                Content = "A throw is already in progress, please wait!",
                Duration = 2.0,
                Icon = "clock"
            })
        end)
        return
    end

    isManualOneThrowRunning = true
    task.spawn(function()
        pcall(function()
            notify({
                Title = "Manual Throw",
                Content = "Executing 1x Throw...",
                Duration = 1.8,
                Icon = "play"
            })
        end)

        ensurePastLine()
        task.wait(0.08)

        if Settings.AutoUseSuperThrow then
            pcall(function() invokeRemote("Throw_UseSuper") end)
        end

        if Settings.ThrowMode == "Visual (With Animation & Meter)" and ThrowController then
            local startFn = ThrowController.Start or ThrowController.start
            if type(startFn) == "function" then
                pcall(function() startFn(ThrowController) end)
            end
        else
            local startResult = invokeRemote("Throw_Start")
            if type(startResult) == "table" and startResult.Ok == true then
                invokeRemote("Throw_Resolve", 1)
                task.wait(math.max(Settings.ThrowDelay or 0.35, 0.2))
                invokeRemote("Throw_Complete")
            else
                pcall(function() invokeRemote("Throw_Cancel") end)
            end
        end

        task.wait(0.4)
        isManualOneThrowRunning = false

        pcall(function()
            notify({
                Title = "Manual Throw",
                Content = "Manual 1x Throw completed!",
                Duration = 2.0,
                Icon = "check"
            })
        end)
    end)
end

local function performManualSpamBurst(count)
    count = count or 5

    if isThrowLoopRunning then
        pcall(function()
            notify({
                Title = "Manual Spam",
                Content = "Auto Throw bot is currently active. Turn it OFF first to manual spam!",
                Duration = 2.5,
                Icon = "alert-triangle"
            })
        end)
        return
    end

    if isManualOneThrowRunning or isSpamBurstRunning then
        pcall(function()
            notify({
                Title = "Manual Spam",
                Content = "A throw action is already running, please wait!",
                Duration = 2.0,
                Icon = "clock"
            })
        end)
        return
    end

    isSpamBurstRunning = true
    task.spawn(function()
        pcall(function()
            notify({
                Title = "Manual Spam Burst",
                Content = string.format("Firing %dx Rapid Burst Throws...", count),
                Duration = 2.0,
                Icon = "zap"
            })
        end)

        ensurePastLine()
        task.wait(0.08)

        local executed = 0
        for i = 1, count do
            if not isSpamBurstRunning then break end

            if Settings.AutoUseSuperThrow then
                pcall(function() invokeRemote("Throw_UseSuper") end)
            end

            local startResult = invokeRemote("Throw_Start")
            if type(startResult) == "table" and startResult.Ok == true then
                local res = invokeRemote("Throw_Resolve", 1)
                if type(res) == "table" and res.Ok == true then
                    local delayTime = math.max(Settings.ThrowDelay or 0.35, 0.15)
                    task.wait(delayTime)
                    invokeRemote("Throw_Complete")
                    executed = executed + 1
                    lastThrowAt = os.clock()
                else
                    pcall(function() invokeRemote("Throw_Cancel") end)
                end
            else
                pcall(function() invokeRemote("Throw_Cancel") end)
                task.wait(0.12)
            end

            task.wait(0.05)
        end

        isSpamBurstRunning = false
        pcall(teleportBackFromLine)

        pcall(function()
            notify({
                Title = "Manual Spam Burst",
                Content = string.format("Burst completed! (%d/%d throws executed)", executed, count),
                Duration = 3.0,
                Icon = "check"
            })
        end)
    end)
end

local function performInstantStandUpgrade()
    local price = getNextStandPrice()
    if price and getPlayerMoney() >= price then
        local res = invokeRemote("Stand_Upgrade")
        return (type(res) == "table" and res.Ok) or res == true
    end
    return false
end

task.spawn(function()
    while true do
        task.wait(0.2)

        if Settings.AutoStandUpgrade or Settings.AutoTraining then
            pcall(performInstantStandUpgrade)
        end

        if Settings.AutoTraining then
            pcall(function()
                if ClientState and ClientState.Busy and ClientState.Busy ~= "Training" then
                    ClientState.Busy = nil
                end

                local spot = getTrainingSpot()
                local hrp = getRootPart()

                if spot and hrp then
                    local diff = Vector3.new(hrp.Position.X - spot.Position.X, 0, hrp.Position.Z - spot.Position.Z).Magnitude
                    if diff > 3.0 then
                        hrp.CFrame = spot.CFrame + Vector3.new(0, 1.8, 0)
                        task.wait(0.15)
                    end
                end

                if TrainingController and not TrainingController.IsRunning() then
                    task.spawn(function()
                        if TrainingController.Start then
                            TrainingController.Start()
                        else
                            invokeRemote("Training_Start")
                        end
                    end)
                end
            end)
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(2.5)

        if Settings.AutoStandUpgrade then
            pcall(function()
                local price = getNextStandPrice()
                if price and getPlayerMoney() >= price then
                    invokeRemote("Stand_Upgrade")
                end
            end)
        end

        if Settings.AutoEquipBest then
            pcall(function()
                invokeRemote("Plot_EquipBest")
            end)
        end

        if Settings.AutoUpgradeFence then
            pcall(function()
                invokeRemote("Plot_UpgradeFence")
            end)
        end

        if Settings.AutoClaimOffline then
            pcall(function()
                invokeRemote("Offline_Claim")
            end)
        end

        if Settings.AutoClaimGifts then
            pcall(function()
                invokeRemote("Shop_ClaimFree")
            end)
        end

        if (Settings.AutoBuyBestFood or Settings.AutoEquipBestFood) and FoodsConfig then
            pcall(function()
                local foodsList = FoodsConfig.List or FoodsConfig.All
                if foodsList then
                    local money = getPlayerMoney()
                    local ownedFoods = (DataController and DataController:Get("OwnedFoods")) or {}
                    local bestOwnedId = 1
                    local bestAffordableId = 1

                    for idx, food in ipairs(foodsList) do
                        if ownedFoods[tostring(idx)] or ownedFoods[idx] then
                            if idx > bestOwnedId then bestOwnedId = idx end
                        end
                        if food.Price and money >= food.Price then
                            if idx > bestAffordableId then bestAffordableId = idx end
                        end
                    end

                    if Settings.AutoBuyBestFood and bestAffordableId > bestOwnedId then
                        invokeRemote("Shop_Buy", bestAffordableId)
                    end

                    if Settings.AutoEquipBestFood then
                        local curEquipped = DataController and DataController:Get("EquippedFood")
                        if curEquipped ~= bestOwnedId then
                            invokeRemote("Shop_Equip", bestOwnedId)
                        end
                    end
                end
            end)
        end
    end
end)

trackConnect(RunService.RenderStepped, function(dt)
    if Settings.SpeedEnabled and Settings.WalkSpeed > 16 then
        local hum = getHumanoid()
        local hrp = getRootPart()
        if hum and hrp then
            local mode = Settings.SpeedMode or "CFrame (Bypass)"

            if mode == "WalkSpeed" or mode == "Both" then
                if hum.WalkSpeed ~= Settings.WalkSpeed then
                    hum.WalkSpeed = Settings.WalkSpeed
                end
            end

            if mode == "CFrame (Bypass)" or mode == "Both" then
                local moveDir = hum.MoveDirection
                if moveDir.Magnitude > 0 then
                    local speedDelta = (Settings.WalkSpeed - 16)
                    local step = moveDir * (speedDelta * dt)
                    hrp.CFrame = hrp.CFrame + step
                end
            end
        end
    end

    if Settings.JumpEnabled then
        local hum = getHumanoid()
        if hum then
            if not hum.UseJumpPower then
                hum.UseJumpPower = true
            end
            if hum.JumpPower ~= Settings.JumpPower then
                hum.JumpPower = Settings.JumpPower
            end
            pcall(function()
                local grav = workspace.Gravity > 0 and workspace.Gravity or 196.2
                hum.JumpHeight = (Settings.JumpPower ^ 2) / (2 * grav)
            end)
        end
    end
end)

trackConnect(RunService.Stepped, function()
    if Settings.NoClip then
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end
end)

trackConnect(UserInputService.JumpRequest, function()
    if Settings.InfiniteJump then
        local hum = getHumanoid()
        local hrp = getRootPart()
        if hum and hrp then
            local jumpVel = Settings.JumpEnabled and (Settings.JumpPower or 50) or 50
            hrp.Velocity = Vector3.new(hrp.Velocity.X, jumpVel, hrp.Velocity.Z)
            pcall(function()
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end)
        end
    end
end)

if Settings.AntiAFK then
    trackConnect(LocalPlayer.Idled, function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end)
end

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()
_G.__Rayfield = Rayfield

Window = Rayfield:CreateWindow({
    name = "Throw Food For Animals",
    subtitle = "VeloxHub | Ovei",
    icon = "bone",
    theme = "cobalt",
    sidebarLayout = true,
    showName = "VeloxHub",
    configuration = {
        autoSave = true,
        autoLoad = true,
        fileName = "VeloxHub_ThrowFoodForAnimals",
    },
})

local TabFarm = Window:CreateTab({ name = "Farm", icon = "zap" })
local TabThrow = Window:CreateTab({ name = "Throw", icon = "target" })
local TabPlot = Window:CreateTab({ name = "Plot", icon = "paw-print" })
local TabPlayer = Window:CreateTab({ name = "Player", icon = "user" })

local TabShop = TabPlot
local TabTeleports = TabPlayer
local TabMisc = TabPlayer

trackConnect(UserInputService.InputBegan, function(input, gameProcessed)
    if gameProcessed then
        return
    end
    if input.KeyCode == Enum.KeyCode.RightControl then
        Window:ToggleHide()
    end
end)

local StatParagraph = TabFarm:CreateText({
    name = "Live Player Stats & Economy",
    text = "Calculating live balances..."
})

task.spawn(function()
    while true do
        task.wait(1.5)
        pcall(function()
            local ls = LocalPlayer:FindFirstChild("leaderstats")
            local moneyStr = ls and ls:FindFirstChild("Money") and ls.Money.Value or "$0"
            local powerStr = ls and ls:FindFirstChild("Throw Power") and tostring(ls["Throw Power"].Value) or "0"
            local rateStr  = ls and ls:FindFirstChild("Money/s") and ls["Money/s"].Value or "$0/s"
            local level = DataController and DataController:Get("Level") or 1
            local xp = DataController and DataController:Get("Xp") or 0
            local curStand, standName, curXp, nextPrice, nextXp = getCurrentStandInfo()

            local nextText = nextPrice and string.format("Next Stand: +%s XP/rep ($%s)", tostring(nextXp or "?"), tostring(nextPrice)) or "MAX PULL-UP TIER REACHED"

            StatParagraph:Set(string.format(
                "Money: %s | Income: %s\nLevel: %d (XP: %d) | Throw Power: %s\nPull-Up Bar: %s (#%d/58)\nCurrent EXP Rate: +%s XP / pull-up rep\n%s",
                tostring(moneyStr), tostring(rateStr), tonumber(level), tonumber(xp), tostring(powerStr), tostring(standName), tonumber(curStand), tostring(curXp), nextText
            ))
        end)
    end
end)

TabFarm:CreateSection({ name = "Training" })

TabFarm:CreateToggle({
    name = "Auto Train",
    value = Settings.AutoTraining,
    callback = function(v)
        Settings.AutoTraining = v
        if not v then
            if TrainingController and TrainingController.IsRunning() then
                pcall(function() TrainingController.Stop() end)
            end
            pcall(function() invokeRemote("Training_Stop") end)
            pcall(function()
                local hum = getHumanoid()
                if hum then
                    for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
                        track:AdjustSpeed(1)
                    end
                end
            end)
        end
    end
})

TabFarm:CreateToggle({
    name = "Auto Upgrade Stand",
    value = Settings.AutoStandUpgrade,
    callback = function(v)
        Settings.AutoStandUpgrade = v
    end
})

TabFarm:CreateToggle({
    name = "Auto Training Bonus",
    value = Settings.AutoTapBonus,
    callback = function(v)
        Settings.AutoTapBonus = v
    end
})

TabFarm:CreateToggle({
    name = "Fast Training",
    value = Settings.FastTraining,
    callback = function(v)
        Settings.FastTraining = v
        if not v then
            pcall(function()
                local hum = getHumanoid()
                if hum then
                    for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
                        track:AdjustSpeed(1)
                    end
                end
            end)
        end
    end
})

TabFarm:CreateSlider({
    name = "Training Speed",
    increment = 0.5,
    range = { 1.0, 5.0 },
    value = Settings.TrainingSpeed,
    callback = function(v)
        Settings.TrainingSpeed = v
    end
})

TabFarm:CreateSection({ name = "Actions" })

TabFarm:CreateButton({
    name = "Upgrade Pull-Up Stand Now",
    callback = function()
        local res = invokeRemote("Stand_Upgrade")
        local success = (type(res) == "table" and res.Ok) or res == true
        notify({
            name = "Stand Upgrade",
            Content = success and "Stand upgraded successfully! Your EXP per pull-up increased!" or "Cannot upgrade stand (insufficient money)",
            Duration = 2.5,
            Icon = "zap"
        })
    end
})

TabFarm:CreateButton({
    name = "Teleport to Training Spot",
    callback = function()
        local spot = getTrainingSpot()
        if spot then
            teleportTo(spot.CFrame + Vector3.new(0, 3, 0))
            notify({
                name = "Training Pad",
                Content = "Teleported to your pull-up stand!",
                Duration = 2.0,
                Icon = "check"
            })
        else
            notify({
                name = "Training Spot",
                Content = "Training spot not found. Is your plot loaded?",
                Duration = 2.5,
                Icon = "alert-circle"
            })
        end
    end
})

TabThrow:CreateSection({ name = "Automation" })

TabThrow:CreateToggle({
    name = "Auto Throw",
    value = Settings.AutoThrow,
    callback = function(v)
        Settings.AutoThrow = v
        if v then
            if Settings.AutoTraining then
                Settings.AutoTraining = false
                if TrainingController and TrainingController.IsRunning() then
                    pcall(function() TrainingController.Stop() end)
                end
            end
            startAutoThrowEngine()
        else
            stopAutoThrowEngine()
        end
    end
})

TabThrow:CreateDropdown({
    name = "Throwing Mode",
    options = { "Visual (With Animation & Meter)", "Fast Instant (No Animation)" },
    value = Settings.ThrowMode,
    callback = function(v)
        Settings.ThrowMode = v
    end
})

TabThrow:CreateToggle({
    name = "Perfect Throw",
    value = Settings.AlwaysPerfectThrow,
    callback = function(v)
        Settings.AlwaysPerfectThrow = v
    end
})

TabThrow:CreateToggle({
    name = "Skip Cutscene",
    value = Settings.AutoSkipCutscene,
    callback = function(v)
        Settings.AutoSkipCutscene = v
    end
})

TabThrow:CreateToggle({
    name = "Use Super Throw",
    value = Settings.AutoUseSuperThrow,
    callback = function(v)
        Settings.AutoUseSuperThrow = v
    end
})

TabThrow:CreateSlider({
    name = "Throw Delay",
    increment = 0.05,
    range = { 0.15, 1.50 },
    value = Settings.ThrowDelay,
    callback = function(v)
        Settings.ThrowDelay = v
    end
})

TabThrow:CreateSection({ name = "Manual Actions" })

TabThrow:CreateButton({
    name = "Throw Once",
    callback = function()
        performManualSingleThrow()
    end
})

TabThrow:CreateButton({
    name = "5x Throw Burst",
    callback = function()
        performManualSpamBurst(5)
    end
})

TabThrow:CreateButton({
    name = "10x Throw Burst",
    callback = function()
        performManualSpamBurst(10)
    end
})

TabThrow:CreateButton({
    name = "Teleport to Throw Line",
    callback = function()
        ensurePastLine()
        notify({
            name = "Throw Line",
            Content = "Arrived at throw lane!",
            Duration = 2.0,
            Icon = "check"
        })
    end
})

TabThrow:CreateButton({
    name = "Stop Throw",
    callback = function()
        stopAutoThrowEngine()
        notify({
            name = "Throw Reset",
            Content = "Stopped and stepped back to safety!",
            Duration = 2.0,
            Icon = "refresh-cw"
        })
    end
})

TabPlot:CreateSection({ name = "Animals" })

TabPlot:CreateToggle({
    name = "Auto Equip Best",
    value = Settings.AutoEquipBest,
    callback = function(v)
        Settings.AutoEquipBest = v
    end
})

TabPlot:CreateToggle({
    name = "Auto Upgrade Fence",
    value = Settings.AutoUpgradeFence,
    callback = function(v)
        Settings.AutoUpgradeFence = v
    end
})

TabPlot:CreateSection({ name = "Plot Actions" })

TabPlot:CreateButton({
    name = "Equip Best Now",
    callback = function()
        local res = invokeRemote("Plot_EquipBest")
        local success = (type(res) == "table" and res.Ok) or res ~= nil
        notify({
            name = "Plot Management",
            Content = success and "Best animals equipped!" or "Failed to equip animals",
            Duration = 2.5,
            Icon = "check"
        })
    end
})

TabPlot:CreateButton({
    name = "Upgrade Fence",
    callback = function()
        local res = invokeRemote("Plot_UpgradeFence")
        local success = (type(res) == "table" and res.Ok) or res == true
        notify({
            name = "Fence Upgrade",
            Content = success and "Fence upgraded successfully!" or "Cannot upgrade fence yet",
            Duration = 2.5,
            Icon = "shield"
        })
    end
})

TabPlot:CreateButton({
    name = "Sell All",
    callback = function()
        local res = invokeRemote("Plot_SellAll")
        local success = (type(res) == "table" and res.Ok) or res ~= nil
        notify({
            name = "Sold Animals",
            Content = success and "All placed animals sold!" or "Failed to sell animals",
            Duration = 2.5,
            Icon = "dollar-sign"
        })
    end
})

TabShop:CreateSection({ name = "Shop Automation" })

TabShop:CreateToggle({
    name = "Claim Offline Rewards",
    value = Settings.AutoClaimOffline,
    callback = function(v)
        Settings.AutoClaimOffline = v
    end
})

TabShop:CreateToggle({
    name = "Claim Free Gifts",
    value = Settings.AutoClaimGifts,
    callback = function(v)
        Settings.AutoClaimGifts = v
    end
})

TabShop:CreateToggle({
    name = "Buy Best Food",
    value = Settings.AutoBuyBestFood,
    callback = function(v)
        Settings.AutoBuyBestFood = v
    end
})

TabShop:CreateToggle({
    name = "Equip Best Food",
    value = Settings.AutoEquipBestFood,
    callback = function(v)
        Settings.AutoEquipBestFood = v
    end
})

TabShop:CreateSection({ name = "Food" })

local foodNames = {}
local foodList = FoodsConfig and (FoodsConfig.List or FoodsConfig.All) or {}
for idx, f in ipairs(foodList) do
    table.insert(foodNames, string.format("#%d %s", idx, f.Name or "Food"))
end

local selectedFoodIdx = 1
TabShop:CreateDropdown({
    name = "Select Food",
    options = #foodNames > 0 and foodNames or { "#1 Carrot", "#2 Apple" },
    value = foodNames[1] or "#1 Carrot",
    callback = function(v)
        local num = v:match("#(%d+)")
        if num then
            selectedFoodIdx = tonumber(num)
        end
    end
})

TabShop:CreateButton({
    name = "Buy Food",
    callback = function()
        local res = invokeRemote("Shop_Buy", selectedFoodIdx)
        local success = (type(res) == "table" and res.Ok) or res == true
        notify({
            name = "Food Purchase",
            Content = success and "Food purchased!" or "Failed to purchase food",
            Duration = 2.5,
            Icon = "check"
        })
    end
})

TabShop:CreateButton({
    name = "Equip Food",
    callback = function()
        local res = invokeRemote("Shop_Equip", selectedFoodIdx)
        local success = (type(res) == "table" and res.Ok) or res == true
        notify({
            name = "Food Equipped",
            Content = success and "Food equipped!" or "Failed to equip food",
            Duration = 2.5,
            Icon = "check"
        })
    end
})

TabTeleports:CreateSection({ name = "Locations" })

TabTeleports:CreateButton({
    name = "Plot Entrance",
    callback = function()
        local p = getMyPlot()
        if p then
            local offset = (GameConfig and GameConfig.Plot and GameConfig.Plot.EntranceOffset) or Vector3.new(0, 3.5, -5)
            teleportTo(p.Position + offset)
            notify({
                name = "Teleported",
                Content = "Arrived at Plot Entrance",
                Duration = 2.0,
                Icon = "check"
            })
        else
            notify({
                name = "Teleport",
                Content = "Plot not found or loaded yet",
                Duration = 2.0,
                Icon = "alert-circle"
            })
        end
    end
})

TabTeleports:CreateButton({
    name = "Teleport to Training",
    callback = function()
        local spot = getTrainingSpot()
        if spot then
            teleportTo(spot.CFrame + Vector3.new(0, 3, 0))
            notify({
                name = "Teleported",
                Content = "Arrived at Training Spot",
                Duration = 2.0,
                Icon = "check"
            })
        else
            notify({
                name = "Teleport",
                Content = "Training spot not loaded yet",
                Duration = 2.0,
                Icon = "alert-circle"
            })
        end
    end
})

TabTeleports:CreateButton({
    name = "Teleport to Throw Line",
    callback = function()
        ensurePastLine()
        notify({
            name = "Teleported",
            Content = "Arrived at Throw Lane",
            Duration = 2.0,
            Icon = "check"
        })
    end
})

TabTeleports:CreateButton({
    name = "Food Shop",
    callback = function()
        local p = getMyPlot()
        if p then
            teleportTo(p.Position + Vector3.new(10.5, 3.5, -8.3))
        else
            teleportTo(CFrame.new(10.5, 3.5, -8.3))
        end
        notify({
            name = "Teleported",
            Content = "Arrived at Food Shop Stall",
            Duration = 2.0,
            Icon = "check"
        })
    end
})

TabTeleports:CreateSection({ name = "Player Plots" })

local selectedPlotNum = 1
local plotOptions = { "Plot 1", "Plot 2", "Plot 3", "Plot 4", "Plot 5", "Plot 6" }

TabTeleports:CreateDropdown({
    name = "Select Plot",
    options = plotOptions,
    value = plotOptions[1],
    callback = function(v)
        local num = v:match("(%d+)")
        if num then
            selectedPlotNum = tonumber(num)
        end
    end
})

TabTeleports:CreateButton({
    name = "Visit Selected Plot",
    callback = function()
        local plots = Workspace:FindFirstChild("Plots")
        local targetPlot = plots and plots:FindFirstChild(tostring(selectedPlotNum))
        if targetPlot then
            local pos = targetPlot.Position or (targetPlot:IsA("Model") and targetPlot:GetPivot().Position)
            if pos then
                teleportTo(pos + Vector3.new(0, 4, -5))
                notify({
                    name = "Teleported",
                    Content = "Arrived at Plot #" .. tostring(selectedPlotNum),
                    Duration = 2.0,
                    Icon = "check"
                })
                return
            end
        end
        notify({
            name = "Plot Teleport",
            Content = "Plot #" .. tostring(selectedPlotNum) .. " is not available",
            Duration = 2.0,
            Icon = "alert-circle"
        })
    end
})

TabTeleports:CreateSection({ name = "Biomes" })

local biomeOptions = {
    "Forest", "Savana", "Desert", "Jungle", "Ocean",
    "Mountains", "Taiga", "Winter", "Hell"
}
local selectedBiome = biomeOptions[1]

TabTeleports:CreateDropdown({
    name = "Select Biome",
    options = biomeOptions,
    value = biomeOptions[1],
    callback = function(v)
        selectedBiome = v
    end
})

TabTeleports:CreateButton({
    name = "Visit Biome",
    callback = function()
        local biomesFolder = Workspace:FindFirstChild("Biomes")
        local bFolder = biomesFolder and biomesFolder:FindFirstChild(selectedBiome)
        if bFolder then
            local part = bFolder:IsA("BasePart") and bFolder or bFolder:FindFirstChildWhichIsA("BasePart")
            if part then
                teleportTo(part.CFrame + Vector3.new(0, 6, 0))
                notify({
                    name = "Teleported",
                    Content = "Arrived at " .. selectedBiome .. " biome!",
                    Duration = 2.0,
                    Icon = "navigation"
                })
                return
            end
        end
        notify({
            name = "Biome Not Found",
            Content = selectedBiome .. " zone is not currently loaded in workspace.",
            Duration = 2.5,
            Icon = "alert-circle"
        })
    end
})

TabMisc:CreateSection({ name = "Movement" })

TabMisc:CreateToggle({
    name = "Custom Speed",
    value = Settings.SpeedEnabled,
    callback = function(v)
        Settings.SpeedEnabled = v
        local hum = getHumanoid()
        if not v and hum then
            hum.WalkSpeed = 16
        end
    end
})

TabMisc:CreateSlider({
    name = "Walk Speed",
    increment = 1,
    range = { 16, 200 },
    value = Settings.WalkSpeed,
    callback = function(v)
        Settings.WalkSpeed = v
        if Settings.SpeedEnabled then
            local hum = getHumanoid()
            if hum and (Settings.SpeedMode == "WalkSpeed" or Settings.SpeedMode == "Both") then
                hum.WalkSpeed = v
            end
        end
    end
})

TabMisc:CreateDropdown({
    name = "Speed Mode",
    options = { "CFrame (Bypass)", "WalkSpeed", "Both" },
    value = Settings.SpeedMode,
    callback = function(v)
        Settings.SpeedMode = v
    end
})

TabMisc:CreateToggle({
    name = "Custom Jump",
    value = Settings.JumpEnabled,
    callback = function(v)
        Settings.JumpEnabled = v
        local hum = getHumanoid()
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower = v and Settings.JumpPower or 50
            if not v then
                hum.JumpHeight = 7.2
            end
        end
    end
})

TabMisc:CreateSlider({
    name = "Jump Power",
    increment = 1,
    range = { 50, 250 },
    value = Settings.JumpPower,
    callback = function(v)
        Settings.JumpPower = v
        if Settings.JumpEnabled then
            local hum = getHumanoid()
            if hum then
                hum.UseJumpPower = true
                hum.JumpPower = v
                pcall(function()
                    local grav = workspace.Gravity > 0 and workspace.Gravity or 196.2
                    hum.JumpHeight = (v ^ 2) / (2 * grav)
                end)
            end
        end
    end
})

TabMisc:CreateToggle({
    name = "Infinite Jump",
    value = Settings.InfiniteJump,
    callback = function(v)
        Settings.InfiniteJump = v
    end
})

TabMisc:CreateToggle({
    name = "NoClip",
    value = Settings.NoClip,
    callback = function(v)
        Settings.NoClip = v
    end
})

TabMisc:CreateToggle({
    name = "Anti-AFK",
    value = Settings.AntiAFK,
    callback = function(v)
        Settings.AntiAFK = v
    end
})

TabMisc:CreateSection({ name = "Unload" })

TabMisc:CreateButton({
    name = "Unload VeloxHub",
    callback = function()
        if _G.__ThrowFood_Cleanup then
            _G.__ThrowFood_Cleanup()
        end
    end
})

_G.__ThrowFood_Cleanup = function()
    stopAutoThrowEngine()
    Settings.AutoTraining = false

    pcall(function()
        if Window and not Window.unloaded then
            Window:Unload()
        end
    end)

    if ThrowMeter and _G.__OrigThrowMeterNew then
        ThrowMeter.new = _G.__OrigThrowMeterNew
    end
    if ThrowMeter and _G.__OrigThrowMeterRun then
        ThrowMeter.Run = _G.__OrigThrowMeterRun
    end
    if RevealSequence and _G.__OrigRevealPlay then
        RevealSequence.Play = _G.__OrigRevealPlay
    end
    if RevealSequence and _G.__OrigRevealRun then
        RevealSequence.Run = _G.__OrigRevealRun
    end
    if ThrowController and _G.__OrigThrowStart then
        ThrowController.Start = _G.__OrigThrowStart
    end

    for _, conn in ipairs(ActiveConnections) do
        pcall(function() conn:Disconnect() end)
    end
    ActiveConnections = {}

    pcall(function()
        local hum = getHumanoid()
        if hum then
            hum.WalkSpeed = 16
            hum.JumpPower = 50
            hum.JumpHeight = 7.2
            hum.UseJumpPower = true
            for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
                track:AdjustSpeed(1)
            end
        end
    end)

    pcall(function()
        local CoreGui = game:GetService("CoreGui")
        local target = (gethui and gethui()) or CoreGui:FindFirstChild("RobloxGui") or CoreGui
        if target then
            for _, c in ipairs(target:GetChildren()) do
                if c.Name:find("Rayfield") or c.Name:find("VeloxHub") or c.Name:find("JenicakesHub") then
                    c:Destroy()
                end
            end
        end
    end)

end

notify({
    Title = "Throw Food For Animals",
    Content = "VeloxHub is ready. Press Right Control to toggle the UI.",
    Duration = 4.0,
    Icon = "check-check"
})
