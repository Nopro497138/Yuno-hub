--[[
    Wings Keyboard Escape Hub
    A lightweight utility hub built with Yuno Hub Library.

    Features:
      • Win Farm   – Auto-teleport to a fixed safe position (loop, 1s interval)
      • Speed Farm – Auto-fire "AddSpeed" RemoteEvent (loop, 0.01s interval)
      • Player ESP with name, distance, health, and box highlight
      • Preset manager for saving/loading flagged settings
      • Server hop, rejoin, and quick utility actions
]]

return function(Library)
    -- ========================== Services ==========================
    local Players           = game:GetService("Players")
    local RunService        = game:GetService("RunService")
    local UserInputService  = game:GetService("UserInputService")
    local TeleportService   = game:GetService("TeleportService")
    local Workspace         = game:GetService("Workspace")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local LocalPlayer = Players.LocalPlayer
    local Camera      = Workspace.CurrentCamera

    -- ========================== Window ==========================
    local Window = Library.CreateWindow({
        Title    = "Wings Keyboard Escape",
        Subtitle = "v1.1 · utility hub"
    })

    -- ========================== Helpers ==========================
    local function GetHRP()
        local char = LocalPlayer.Character
        if not char then return nil end
        return char:FindFirstChild("HumanoidRootPart")
    end

    local function GetHumanoid()
        local char = LocalPlayer.Character
        if not char then return nil end
        return char:FindFirstChildOfClass("Humanoid")
    end

    local function Round(n)
        return math.floor(n + 0.5)
    end

    -- ========================== Tabs ==========================
    local mainTab    = Window:CreateTab("Main", "rocket")
    local espTab     = Window:CreateTab("ESP", "eye")
    local utilityTab = Window:CreateTab("Utility", "wrench")
    local presetTab  = Window:CreateTab("Presets", "save")

    -- ========================== Main Tab ==========================

    -- -------------------- Win Farm --------------------
    local winFarmSection = mainTab:CreateSection(
        "Win Farm",
        "Continuously repositions your character to the winning position."
    )

    local TELEPORT_POSITION = Vector3.new(21165, 68, -773)

    local tpEnabled = false
    local tpThread  = nil

    local function StartTeleportLoop(interval)
        if tpThread then
            task.cancel(tpThread)
            tpThread = nil
        end
        tpEnabled = true
        tpThread = task.spawn(function()
            while tpEnabled and Window.Instance and Window.Instance.Parent do
                local hrp = GetHRP()
                if hrp then
                    pcall(function()
                        hrp.CFrame = CFrame.new(TELEPORT_POSITION)
                    end)
                end
                task.wait(interval or 1)
            end
        end)
    end

    local function StopTeleportLoop()
        tpEnabled = false
        if tpThread then
            task.cancel(tpThread)
            tpThread = nil
        end
    end

    winFarmSection:CreateToggle("Win Farm", false, function(state)
        if state then
            StartTeleportLoop(1)
            Window:Notify("Win Farm", "Enabled.", 2, "trophy")
        else
            StopTeleportLoop()
            Window:Notify("Win Farm", "Disabled.", 2, "power")
        end
    end, "winFarm")

    winFarmSection:CreateSlider("Farm Interval (s)", 1, 5, 1, function(value)
        if tpEnabled then
            StartTeleportLoop(value)
        end
    end, "winFarmInterval")

    winFarmSection:CreateButton("Teleport Once Now", function()
        local hrp = GetHRP()
        if hrp then
            hrp.CFrame = CFrame.new(TELEPORT_POSITION)
            Window:Notify("Win Farm", "Teleported to target position.", 2, "map")
        else
            Window:Notify("Win Farm", "No character found.", 2, "warning")
        end
    end)

    -- -------------------- Speed Farm --------------------
    local speedFarmSection = mainTab:CreateSection(
        "Speed Farm",
        "Repeatedly fires the AddSpeed RemoteEvent for a speed boost."
    )

    local speedEnabled = false
    local speedThread  = nil

    local function GetAddSpeedEvent()
        local events = ReplicatedStorage:FindFirstChild("Events")
        if not events then return nil end
        return events:FindFirstChild("AddSpeed")
    end

    local function StartSpeedLoop()
        local event = GetAddSpeedEvent()
        if not event then
            Window:Notify("Speed Farm", "RemoteEvent 'AddSpeed' not found.", 3, "warning")
            return false
        end

        if speedThread then
            task.cancel(speedThread)
            speedThread = nil
        end
        speedEnabled = true
        speedThread = task.spawn(function()
            while speedEnabled and Window.Instance and Window.Instance.Parent do
                local ev = GetAddSpeedEvent()
                if ev then
                    pcall(function()
                        ev:FireServer()
                    end)
                end
                task.wait(0.01)
            end
        end)
        return true
    end

    local function StopSpeedLoop()
        speedEnabled = false
        if speedThread then
            task.cancel(speedThread)
            speedThread = nil
        end
    end

    speedFarmSection:CreateToggle("Speed Farm", false, function(state)
        if state then
            local ok = StartSpeedLoop()
            if ok then
                Window:Notify("Speed Farm", "Enabled.", 2, "zap")
            end
        else
            StopSpeedLoop()
            Window:Notify("Speed Farm", "Disabled.", 2, "power")
        end
    end, "speedFarm")

    speedFarmSection:CreateButton("Fire AddSpeed Once", function()
        local event = GetAddSpeedEvent()
        if event then
            pcall(function() event:FireServer() end)
            Window:Notify("Speed Farm", "Event fired once.", 2, "zap")
        else
            Window:Notify("Speed Farm", "RemoteEvent 'AddSpeed' not found.", 3, "warning")
        end
    end)

    -- ========================== ESP Tab ==========================

    local espSection = espTab:CreateSection(
        "Player ESP",
        "Visual overlays for other players in the server."
    )

    local espEnabled      = false
    local espShowName     = true
    local espShowDist     = true
    local espShowHP       = true
    local espShowBox      = true
    local espRange        = 500
    local espConnections  = {}
    local espRenderConn   = nil

    local function CreateBillboard(character, player)
        local head = character:FindFirstChild("Head")
        if not head then return nil end

        local billboard = Instance.new("BillboardGui")
        billboard.Name        = "WingsESP"
        billboard.Size        = UDim2.new(0, 220, 0, 50)
        billboard.StudsOffset = Vector3.new(0, 3, 0)
        billboard.AlwaysOnTop = true
        billboard.MaxDistance = espRange
        billboard.Adornee     = head
        billboard.Parent      = head

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name                   = "NameLabel"
        nameLabel.BackgroundTransparency = 1
        nameLabel.Size                   = UDim2.new(1, 0, 0, 18)
        nameLabel.Font                   = Enum.Font.GothamBold
        nameLabel.TextSize               = 14
        nameLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
        nameLabel.TextStrokeTransparency = 0.2
        nameLabel.Text                   = player.Name
        nameLabel.Parent                 = billboard

        local hpLabel = Instance.new("TextLabel")
        hpLabel.Name                   = "HPLabel"
        hpLabel.BackgroundTransparency = 1
        hpLabel.Position               = UDim2.new(0, 0, 0, 18)
        hpLabel.Size                   = UDim2.new(1, 0, 0, 16)
        hpLabel.Font                   = Enum.Font.Gotham
        hpLabel.TextSize               = 12
        hpLabel.TextColor3             = Color3.fromRGB(120, 255, 120)
        hpLabel.TextStrokeTransparency = 0.4
        hpLabel.Text                   = "100 HP"
        hpLabel.Parent                 = billboard

        local distLabel = Instance.new("TextLabel")
        distLabel.Name                   = "DistLabel"
        distLabel.BackgroundTransparency = 1
        distLabel.Position               = UDim2.new(0, 0, 0, 34)
        distLabel.Size                   = UDim2.new(1, 0, 0, 16)
        distLabel.Font                   = Enum.Font.Gotham
        distLabel.TextSize               = 12
        distLabel.TextColor3             = Color3.fromRGB(200, 200, 200)
        distLabel.TextStrokeTransparency = 0.4
        distLabel.Text                   = "0 m"
        distLabel.Parent                 = billboard

        return billboard
    end

    local function CreateHighlight(character)
        local hl = Instance.new("Highlight")
        hl.Name                = "WingsESPHL"
        hl.Adornee             = character
        hl.FillColor           = Color3.fromRGB(255, 0, 90)
        hl.OutlineColor        = Color3.fromRGB(255, 255, 255)
        hl.FillTransparency    = 0.6
        hl.OutlineTransparency = 0
        hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent              = character
        return hl
    end

    local function TeardownESP(player)
        local data = espConnections[player]
        if not data then return end

        if data.rootConn     then data.rootConn:Disconnect()     end
        if data.humanoidConn then data.humanoidConn:Disconnect() end
        if data.diedConn     then data.diedConn:Disconnect()     end
        if data.charConn     then data.charConn:Disconnect()     end

        if data.highlight and data.highlight.Parent then
            data.highlight:Destroy()
        end
        if data.billboard and data.billboard.Parent then
            data.billboard:Destroy()
        end
        espConnections[player] = nil
    end

    local function SetupESP(player)
        if player == LocalPlayer then return end

        local function onCharacter(character)
            -- Preserve charConn
            local oldData = espConnections[player]
            local savedCharConn = oldData and oldData.charConn or nil

            TeardownESP(player)

            local head = character:WaitForChild("Head", 5)
            if not head then return end

            local humanoid = character:WaitForChild("Humanoid", 5)

            local billboard = CreateBillboard(character, player)
            local highlight = espShowBox and CreateHighlight(character) or nil

            local data = {
                billboard = billboard,
                highlight = highlight,
                charConn  = savedCharConn,
            }

            if humanoid then
                data.humanoidConn = humanoid.HealthChanged:Connect(function(hp)
                    if billboard and billboard.Parent then
                        local hpLabel = billboard:FindFirstChild("HPLabel")
                        if hpLabel then
                            hpLabel.Text = string.format("%d HP", Round(hp))
                            local ratio = math.clamp(hp / math.max(humanoid.MaxHealth, 1), 0, 1)
                            hpLabel.TextColor3 = Color3.fromRGB(
                                255 - 155 * ratio,
                                100 + 155 * ratio,
                                100
                            )
                        end
                    end
                end)

                data.diedConn = humanoid.Died:Connect(function()
                    TeardownESP(player)
                end)
            end

            espConnections[player] = data
        end

        if player.Character then
            onCharacter(player.Character)
        end
        local conn = player.CharacterAdded:Connect(onCharacter)

        -- Store the CharacterAdded connection under a temp holder so it survives
        if espConnections[player] then
            espConnections[player].charConn = conn
        else
            espConnections[player] = { charConn = conn }
        end
    end

    local function ClearAllESP()
        for player in pairs(espConnections) do
            TeardownESP(player)
        end
        espConnections = {}
    end

    local function RefreshESPLabels()
        local myHRP = GetHRP()
        if not myHRP then return end
        local myPos = myHRP.Position

        for player, data in pairs(espConnections) do
            local char = player.Character
            if not char then
                TeardownESP(player)
                continue
            end
            local head = char:FindFirstChild("Head")
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if not head or not humanoid then continue end

            local dist = (head.Position - myPos).Magnitude
            local inRange = dist <= espRange

            if data.billboard and data.billboard.Parent then
                data.billboard.Enabled = inRange
                local nameLabel = data.billboard:FindFirstChild("NameLabel")
                local distLabel = data.billboard:FindFirstChild("DistLabel")
                local hpLabel   = data.billboard:FindFirstChild("HPLabel")

                if nameLabel then
                    nameLabel.Visible = espShowName
                    nameLabel.Text = player.Name
                end
                if distLabel then
                    distLabel.Visible = espShowDist
                    distLabel.Text = string.format("%d m", Round(dist))
                end
                if hpLabel then
                    hpLabel.Visible = espShowHP
                    hpLabel.Text = string.format("%d HP", Round(humanoid.Health))
                end
            end

            if data.highlight then
                data.highlight.Enabled = inRange
            end
        end
    end

    local function StartESPRender()
        if espRenderConn then return end
        espRenderConn = RunService.RenderStepped:Connect(RefreshESPLabels)
    end

    local function StopESPRender()
        if espRenderConn then
            espRenderConn:Disconnect()
            espRenderConn = nil
        end
    end

    espSection:CreateToggle("Enable Player ESP", false, function(state)
        espEnabled = state
        if state then
            for _, plr in ipairs(Players:GetPlayers()) do
                SetupESP(plr)
            end
            StartESPRender()
            Window:Notify("ESP", "Player ESP enabled.", 2, "eye")
        else
            ClearAllESP()
            StopESPRender()
            Window:Notify("ESP", "Player ESP disabled.", 2, "power")
        end
    end, "espPlayers")

    Players.PlayerAdded:Connect(function(plr)
        if espEnabled then
            SetupESP(plr)
        end
    end)
    Players.PlayerRemoving:Connect(function(plr)
        TeardownESP(plr)
    end)

    espSection:CreateToggle("Show Name", true, function(state)
        espShowName = state
    end, "espShowName")

    espSection:CreateToggle("Show Distance", true, function(state)
        espShowDist = state
    end, "espShowDist")

    espSection:CreateToggle("Show Health", true, function(state)
        espShowHP = state
    end, "espShowHP")

    espSection:CreateToggle("Show Box Highlight", true, function(state)
        espShowBox = state
        if not espEnabled then return end
        for player, data in pairs(espConnections) do
            if state then
                if not data.highlight or not data.highlight.Parent then
                    if player.Character then
                        data.highlight = CreateHighlight(player.Character)
                    end
                end
            else
                if data.highlight then
                    data.highlight:Destroy()
                    data.highlight = nil
                end
            end
        end
    end, "espShowBox")

    espSection:CreateSlider("ESP Max Range", 50, 2000, 500, function(value)
        espRange = value
        for _, data in pairs(espConnections) do
            if data.billboard then
                data.billboard.MaxDistance = value
            end
        end
    end, "espRange")

    -- ========================== Utility Tab ==========================

    local utilSection = utilityTab:CreateSection(
        "Server & Character",
        "Quick actions and handy tools."
    )

    utilSection:CreateButton("Rejoin Server", function()
        Window:Notify("Server", "Rejoining…", 2, "power")
        task.wait(0.5)
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)

    utilSection:CreateButton("Server Hop (smallest)", function()
        Window:Notify("Server", "Searching for a new server…", 3, "map")
        local ok, err = pcall(function()
            local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)
            local response = game:HttpGet(url)
            local data = game:GetService("HttpService"):JSONDecode(response)
            for _, server in ipairs(data.data) do
                if server.playing < server.maxPlayers and server.id ~= game.JobId then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
                    return
                end
            end
            Window:Notify("Server", "No available servers found.", 3, "warning")
        end)
        if not ok then
            Window:Notify("Server", "Server hop failed: " .. tostring(err), 4, "warning")
        end
    end)

    utilSection:CreateButton("Reset Character", function()
        local humanoid = GetHumanoid()
        if humanoid then
            humanoid.Health = 0
            Window:Notify("Character", "Character reset.", 2, "heart")
        else
            Window:Notify("Character", "No character found.", 2, "warning")
        end
    end)

    utilSection:CreateButton("Copy Job ID", function()
        if setclipboard then
            setclipboard(game.JobId)
            Window:Notify("Clipboard", "Job ID copied.", 2, "clipboard-list")
        else
            Window:Notify("Clipboard", "setclipboard is not available.", 3, "warning")
        end
    end)

    utilSection:CreateSlider("WalkSpeed", 16, 300, 16, function(value)
        local humanoid = GetHumanoid()
        if humanoid then humanoid.WalkSpeed = value end
    end, "walkSpeed")

    utilSection:CreateSlider("JumpPower", 50, 500, 50, function(value)
        local humanoid = GetHumanoid()
        if humanoid then humanoid.JumpPower = value end
    end, "jumpPower")

    -- ========================== Presets Tab ==========================

    local presetSection = presetTab:CreateSection(
        "Preset Manager",
        "Save, load, and delete your flagged settings."
    )
    presetSection:CreatePresetManager()

    -- ========================== Cleanup watchdog ==========================
    task.spawn(function()
        while Window.Instance and Window.Instance.Parent do
            task.wait(1)
        end
        tpEnabled    = false
        speedEnabled = false
        espEnabled   = false
        if tpThread    then task.cancel(tpThread)    end
        if speedThread then task.cancel(speedThread) end
        ClearAllESP()
        StopESPRender()
    end)

    return Window
end
