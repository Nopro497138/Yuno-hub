--[[
    SuperMarket AutoFarm Hub for YunoHubLibrary
    Drop this file into: Hubs/SuperMarketAutoFarm.lua

    It returns function(Library) ... end, matching the Yuno Hub format.
]]

return function(Library)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local VirtualInputManager = game:GetService("VirtualInputManager")
    local LocalPlayer = Players.LocalPlayer
    local Camera = workspace.CurrentCamera

    -- ============================================================
    -- State
    -- ============================================================

    local State = {
        AutoFarm = false,
        InfiniteHealth = false,
        WalkSpeed = 16,

        ObjectESP = false,
        ObjectNames = true,
        ObjectDistance = true,
        ObjectMaxDistance = 500,

        PlayerESP = false,
        PlayerNames = true,
        PlayerBoxes = true,
        PlayerHealth = true,
        PlayerDistance = true,
        PlayerTracers = false,
        PlayerSkeleton = false,
        PlayerMaxDistance = 1000,
        TeamCheck = false,
    }

    local processedModels = {}
    local espObjects = {}
    local playerESP = {}
    local loopsStarted = false
    local destroyed = false
    local farmGeneration = 0

    -- Drawing API is preferred for skeleton/box/tracer ESP.
    -- Highlight/BillboardGui are used for object ESP because they are more
    -- compatible with different executors.
    local DrawingAvailable = false
    pcall(function()
        DrawingAvailable = Drawing ~= nil
            and type(Drawing.new) == "function"
    end)

    -- ============================================================
    -- Window
    -- ============================================================

    local Window = Library.CreateWindow({
        Title = "SuperMarket AutoFarm",
        Subtitle = "Yuno Hub • AutoFarm + ESP",
    })

    -- ============================================================
    -- Helpers
    -- ============================================================

    local function notify(title, content, duration, icon)
        pcall(function()
            Window:Notify(title, content, duration or 2.5, icon)
        end)
    end

    local function getCharacter()
        return LocalPlayer.Character
    end

    local function getHRP()
        local char = getCharacter()
        return char and char:FindFirstChild("HumanoidRootPart")
    end

    local function getHumanoid()
        local char = getCharacter()
        return char and char:FindFirstChildOfClass("Humanoid")
    end

    local function zeroVelocity(hrp)
        if hrp and hrp:IsA("BasePart") then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            -- Keep compatibility with older executor/game implementations.
            pcall(function()
                hrp.Velocity = Vector3.zero
            end)
        end
    end

    local function getTargetModel()
        local supermarket = workspace:FindFirstChild("SuperMarket")
        local plots = supermarket and supermarket:FindFirstChild("Plots")
        local modelsFolder = plots and plots:FindFirstChild("Models")

        if not modelsFolder then
            return nil, nil
        end

        for _, plot in ipairs(modelsFolder:GetChildren()) do
            for _, item in ipairs(plot:GetChildren()) do
                if item:IsA("Model")
                    and not processedModels[item]
                    and item:IsDescendantOf(workspace)
                then
                    local part = item.PrimaryPart
                        or item:FindFirstChildWhichIsA("BasePart", true)

                    if part then
                        return item, part
                    end
                end
            end
        end

        return nil, nil
    end

    local function findPrompt(instance)
        if not instance then
            return nil
        end

        return instance:FindFirstChildWhichIsA("ProximityPrompt", true)
    end

    local function tryFirePrompt(instance)
        local prompt = findPrompt(instance)
        if not prompt then
            return false
        end

        local ok = pcall(function()
            fireproximityprompt(prompt)
        end)

        return ok
    end

    local function keyDown(keyCode)
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        end)
    end

    local function keyUp(keyCode)
        pcall(function()
            VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
        end)
    end

    local function pressZ(duration)
        keyDown(Enum.KeyCode.Z)
        task.wait(duration or 0.2)
        keyUp(Enum.KeyCode.Z)
    end

    local function distanceFromCharacter(part)
        local hrp = getHRP()
        if not hrp or not part then
            return math.huge
        end
        return (hrp.Position - part.Position).Magnitude
    end

    local function objectLabel(model)
        return model:GetAttribute("DisplayName")
            or model:GetAttribute("Name")
            or model.Name
    end

    -- ============================================================
    -- Auto Farm
    -- ============================================================

    local function stopFarm()
        farmGeneration += 1
        State.AutoFarm = false
        Camera.CameraType = Enum.CameraType.Custom
    end

    local function startFarm()
        farmGeneration += 1
        local myGeneration = farmGeneration

        task.spawn(function()
            while State.AutoFarm and myGeneration == farmGeneration and not destroyed do
                local hrp = getHRP()

                if not hrp then
                    task.wait(0.75)
                    continue
                end

                -- 1) Go to the collection area.
                hrp.CFrame = CFrame.new(-382, 10, -408)
                zeroVelocity(hrp)
                task.wait(2.5)

                if not State.AutoFarm or myGeneration ~= farmGeneration then
                    break
                end

                local model, targetPart = getTargetModel()

                if model and targetPart and model.Parent then
                    local objPos = targetPart.Position
                    local standPos = objPos + Vector3.new(-1, -3, -7)

                    -- 2) Face the item and lock the camera on it.
                    hrp.CFrame = CFrame.lookAt(standPos, objPos)
                    zeroVelocity(hrp)

                    Camera.CameraType = Enum.CameraType.Scriptable
                    Camera.CFrame = CFrame.lookAt(
                        standPos + Vector3.new(0, 1.5, 0),
                        objPos
                    )

                    task.wait(1.5)

                    if not State.AutoFarm or myGeneration ~= farmGeneration then
                        break
                    end

                    -- 3) Pick up.
                    local promptFired = tryFirePrompt(model)

                    if not promptFired then
                        keyDown(Enum.KeyCode.Z)
                        task.wait(1.2)
                        keyUp(Enum.KeyCode.Z)
                    else
                        task.wait(1.2)
                    end

                    task.wait(0.5)
                    processedModels[model] = true

                    if not State.AutoFarm or myGeneration ~= farmGeneration then
                        break
                    end

                    -- 4) Deliver.
                    Camera.CameraType = Enum.CameraType.Custom
                    hrp.CFrame = CFrame.new(-427, 202, 54)
                    zeroVelocity(hrp)

                    task.wait(1.5)

                    -- 5) Deliver with Z.
                    pressZ(0.2)

                    task.wait(2)
                else
                    Camera.CameraType = Enum.CameraType.Custom
                    task.wait(2)
                end
            end

            Camera.CameraType = Enum.CameraType.Custom
        end)
    end

    -- ============================================================
    -- Player utilities
    -- ============================================================

    local function applyWalkSpeed()
        local humanoid = getHumanoid()
        if humanoid and humanoid.WalkSpeed ~= State.WalkSpeed then
            humanoid.WalkSpeed = State.WalkSpeed
        end
    end

    local function applyInfiniteHealth()
        if not State.InfiniteHealth then
            return
        end

        local humanoid = getHumanoid()
        if humanoid and humanoid.Health < humanoid.MaxHealth then
            pcall(function()
                humanoid.Health = humanoid.MaxHealth
            end)
        end
    end

    -- ============================================================
    -- Object ESP
    -- ============================================================

    local function destroyObjectESP(model)
        local bundle = espObjects[model]
        if not bundle then
            return
        end

        for _, instance in pairs(bundle) do
            pcall(function()
                instance:Destroy()
            end)
        end

        espObjects[model] = nil
    end

    local function createBillboard()
        local gui = Instance.new("BillboardGui")
        gui.Name = "YunoObjectESP"
        gui.AlwaysOnTop = true
        gui.Size = UDim2.fromOffset(220, 36)
        gui.StudsOffset = Vector3.new(0, 2.75, 0)

        local label = Instance.new("TextLabel")
        label.Name = "Label"
        label.BackgroundTransparency = 1
        label.Size = UDim2.fromScale(1, 1)
        label.Font = Enum.Font.GothamSemibold
        label.TextSize = 13
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextStrokeTransparency = 0.25
        label.RichText = false
        label.Parent = gui

        return gui, label
    end

    local function createObjectESP(model)
        if espObjects[model] or not model:IsDescendantOf(workspace) then
            return
        end

        local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
        if not part then
            return
        end

        local highlight = Instance.new("Highlight")
        highlight.Name = "YunoObjectHighlight"
        highlight.Adornee = model
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillColor = Color3.fromRGB(150, 100, 255)
        highlight.FillTransparency = 0.78
        highlight.OutlineColor = Color3.fromRGB(230, 90, 210)
        highlight.OutlineTransparency = 0.05
        highlight.Parent = model

        local gui, label = createBillboard()
        gui.Adornee = part
        gui.Enabled = State.ObjectESP
        gui.Parent = model

        espObjects[model] = {
            Highlight = highlight,
            Billboard = gui,
            Label = label,
        }
    end

    local function scanObjects()
        local supermarket = workspace:FindFirstChild("SuperMarket")
        local plots = supermarket and supermarket:FindFirstChild("Plots")
        local modelsFolder = plots and plots:FindFirstChild("Models")

        if not modelsFolder then
            return
        end

        for _, plot in ipairs(modelsFolder:GetChildren()) do
            for _, child in ipairs(plot:GetChildren()) do
                if child:IsA("Model") then
                    createObjectESP(child)
                end
            end
        end
    end

    local function updateObjectESP()
        if not State.ObjectESP then
            for _, model in pairs(espObjects) do
                if model.Billboard then
                    model.Billboard.Enabled = false
                end
                if model.Highlight then
                    model.Highlight.Enabled = false
                end
            end
            return
        end

        scanObjects()

        for model, bundle in pairs(espObjects) do
            if not model or not model.Parent then
                destroyObjectESP(model)
            else
                local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
                if part then

                    local distance = distanceFromCharacter(part)
                    local visible = distance <= State.ObjectMaxDistance

                    if bundle.Billboard then
                        bundle.Billboard.Enabled = visible

                        local text = objectLabel(model)

                        if State.ObjectDistance then
                            text = ("%s  [%dm]"):format(text, math.floor(distance + 0.5))
                        end

                        if not State.ObjectNames then
                            text = State.ObjectDistance
                                and ("[%dm]"):format(math.floor(distance + 0.5))
                                or ""
                        end

                        bundle.Label.Text = text
                    end

                    if bundle.Highlight then
                        bundle.Highlight.Enabled = visible
                    end
                end
            end
        end
    end

    -- ============================================================
    -- Player ESP (Drawing based, fallback-safe)
    -- ============================================================

    local function newDrawing(kind, props)
        if not DrawingAvailable then
            return nil
        end

        local ok, obj = pcall(function()
            return Drawing.new(kind)
        end)

        if not ok or not obj then
            return nil
        end

        for key, value in pairs(props or {}) do
            pcall(function()
                obj[key] = value
            end)
        end

        return obj
    end

    local function destroyDrawing(obj)
        if obj then
            pcall(function()
                obj:Remove()
            end)
        end
    end

    local function newPlayerESP()
        local bundle = {
            Name = newDrawing("Text", {
                Center = true,
                Outline = true,
                Size = 13,
                Color = Color3.fromRGB(255, 255, 255),
                Transparency = 1,
                Visible = false,
            }),

            Distance = newDrawing("Text", {
                Center = true,
                Outline = true,
                Size = 12,
                Color = Color3.fromRGB(185, 185, 185),
                Transparency = 1,
                Visible = false,
            }),

            Tracer = newDrawing("Line", {
                Thickness = 1,
                Transparency = 0.85,
                Color = Color3.fromRGB(150, 100, 255),
                Visible = false,
            }),

            BoxOutline = newDrawing("Square", {
                Thickness = 3,
                Transparency = 0.9,
                Color = Color3.fromRGB(0, 0, 0),
                Filled = false,
                Visible = false,
            }),

            Box = newDrawing("Square", {
                Thickness = 1,
                Transparency = 1,
                Color = Color3.fromRGB(150, 100, 255),
                Filled = false,
                Visible = false,
            }),

            HealthBack = newDrawing("Square", {
                Thickness = 1,
                Transparency = 0.9,
                Color = Color3.fromRGB(0, 0, 0),
                Filled = true,
                Visible = false,
            }),

            Health = newDrawing("Square", {
                Thickness = 1,
                Transparency = 1,
                Color = Color3.fromRGB(90, 230, 150),
                Filled = true,
                Visible = false,
            }),

            Skeleton = {},
        }

        -- R6/R15 common links. Missing parts are simply ignored.
        local links = {
            {"Head", "UpperTorso"},
            {"UpperTorso", "LowerTorso"},
            {"UpperTorso", "LeftUpperArm"},
            {"LeftUpperArm", "LeftLowerArm"},
            {"LeftLowerArm", "LeftHand"},
            {"UpperTorso", "RightUpperArm"},
            {"RightUpperArm", "RightLowerArm"},
            {"RightLowerArm", "RightHand"},
            {"LowerTorso", "LeftUpperLeg"},
            {"LeftUpperLeg", "LeftLowerLeg"},
            {"LeftLowerLeg", "LeftFoot"},
            {"LowerTorso", "RightUpperLeg"},
            {"RightUpperLeg", "RightLowerLeg"},
            {"RightLowerLeg", "RightFoot"},

            -- R6 fallback
            {"Torso", "Left Arm"},
            {"Left Arm", "Left Leg"},
            {"Torso", "Right Arm"},
            {"Right Arm", "Right Leg"},
            {"Torso", "Left Leg"},
            {"Torso", "Right Leg"},
            {"Head", "Torso"},
        }

        for i = 1, #links do
            bundle.Skeleton[i] = newDrawing("Line", {
                Thickness = 1,
                Transparency = 1,
                Color = Color3.fromRGB(230, 90, 210),
                Visible = false,
            })
        end

        return bundle
    end

    local function hidePlayerESP(bundle)
        for key, object in pairs(bundle) do
            if key == "Skeleton" then
                for _, line in ipairs(object) do
                    if line then
                        line.Visible = false
                    end
                end
            elseif object then
                pcall(function()
                    object.Visible = false
                end)
            end
        end
    end

    local function destroyPlayerESP(player)
        local bundle = playerESP[player]
        if not bundle then
            return
        end

        for key, object in pairs(bundle) do
            if key == "Skeleton" then
                for _, line in ipairs(object) do
                    destroyDrawing(line)
                end
            else
                destroyDrawing(object)
            end
        end

        playerESP[player] = nil
    end

    local function shouldShowPlayer(player)
        if player == LocalPlayer then
            return false
        end

        if State.TeamCheck and LocalPlayer.Team and player.Team == LocalPlayer.Team then
            return false
        end

        return true
    end

    local function getPart(character, name)
        return character and character:FindFirstChild(name)
    end

    local function worldToScreen(position)
        local vector, onScreen = Camera:WorldToViewportPoint(position)
        return Vector2.new(vector.X, vector.Y), onScreen, vector.Z
    end

    local function setLine(line, from2D, to2D, visible)
        if not line then
            return
        end

        line.From = from2D
        line.To = to2D
        line.Visible = visible
    end

    local function updateSkeleton(bundle, character, visible)
        if not State.PlayerSkeleton or not visible then
            for _, line in ipairs(bundle.Skeleton) do
                if line then
                    line.Visible = false
                end
            end
            return
        end

        local links = {
            {"Head", "UpperTorso"},
            {"UpperTorso", "LowerTorso"},
            {"UpperTorso", "LeftUpperArm"},
            {"LeftUpperArm", "LeftLowerArm"},
            {"LeftLowerArm", "LeftHand"},
            {"UpperTorso", "RightUpperArm"},
            {"RightUpperArm", "RightLowerArm"},
            {"RightLowerArm", "RightHand"},
            {"LowerTorso", "LeftUpperLeg"},
            {"LeftUpperLeg", "LeftLowerLeg"},
            {"LeftLowerLeg", "LeftFoot"},
            {"LowerTorso", "RightUpperLeg"},
            {"RightUpperLeg", "RightLowerLeg"},
            {"RightLowerLeg", "RightFoot"},

            -- R6
            {"Torso", "Left Arm"},
            {"Left Arm", "Left Leg"},
            {"Torso", "Right Arm"},
            {"Right Arm", "Right Leg"},
            {"Torso", "Left Leg"},
            {"Torso", "Right Leg"},
            {"Head", "Torso"},
        }

        local used = 0

        for _, pair in ipairs(links) do
            local a = getPart(character, pair[1])
            local b = getPart(character, pair[2])

            if a and b then
                used += 1

                local a2d, aOn = worldToScreen(a.Position)
                local b2d, bOn = worldToScreen(b.Position)

                setLine(bundle.Skeleton[used], a2d, b2d, aOn and bOn)
            end
        end

        for i = used + 1, #bundle.Skeleton do
            if bundle.Skeleton[i] then
                bundle.Skeleton[i].Visible = false
            end
        end
    end

    local function updateOnePlayerESP(player)
        if not DrawingAvailable then
            return
        end

        if not shouldShowPlayer(player) then
            if playerESP[player] then
                hidePlayerESP(playerESP[player])
            end
            return
        end

        if not playerESP[player] then
            playerESP[player] = newPlayerESP()
        end

        local bundle = playerESP[player]
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local head = character and character:FindFirstChild("Head")

        if not character or not humanoid or not root or humanoid.Health <= 0 then
            hidePlayerESP(bundle)
            return
        end

        local distance = distanceFromCharacter(root)

        if distance > State.PlayerMaxDistance then
            hidePlayerESP(bundle)
            return
        end

        local root2D, rootOn, rootDepth = worldToScreen(root.Position)
        local headPos = head and head.Position or (root.Position + Vector3.new(0, 2.5, 0))
        local head2D, headOn = worldToScreen(headPos)

        if not rootOn or not headOn or rootDepth <= 0 then
            hidePlayerESP(bundle)
            return
        end

        local height = math.abs(root2D.Y - head2D.Y) * 1.25
        local width = math.max(height * 0.55, 20)
        local left = root2D.X - width / 2
        local top = head2D.Y - height * 0.2
        local size = Vector2.new(width, height)

        -- Name
        if bundle.Name then
            bundle.Name.Text = player.DisplayName ~= player.Name
                and ("%s (@%s)"):format(player.DisplayName, player.Name)
                or player.Name

            bundle.Name.Position = Vector2.new(root2D.X, top - 18)
            bundle.Name.Visible = State.PlayerNames
        end

        -- Distance
        if bundle.Distance then
            bundle.Distance.Text = ("%dm"):format(math.floor(distance + 0.5))
            bundle.Distance.Position = Vector2.new(root2D.X, top + height + 4)
            bundle.Distance.Visible = State.PlayerDistance
        end

        -- Box
        if bundle.BoxOutline and bundle.Box then
            bundle.BoxOutline.Position = Vector2.new(left, top)
            bundle.BoxOutline.Size = size
            bundle.Box.Position = Vector2.new(left, top)
            bundle.Box.Size = size

            bundle.BoxOutline.Visible = State.PlayerBoxes
            bundle.Box.Visible = State.PlayerBoxes
        end

        -- Healthbar
        if bundle.HealthBack and bundle.Health then
            local healthPct = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
            local barX = left - 6

            bundle.HealthBack.Position = Vector2.new(barX, top)
            bundle.HealthBack.Size = Vector2.new(3, height)

            bundle.Health.Position = Vector2.new(
                barX,
                top + height * (1 - healthPct)
            )
            bundle.Health.Size = Vector2.new(
                3,
                height * healthPct
            )

            bundle.HealthBack.Visible = State.PlayerHealth
            bundle.Health.Visible = State.PlayerHealth

            pcall(function()
                bundle.Health.Color = Color3.new(
                    1 - healthPct,
                    healthPct,
                    0
                )
            end)
        end

        -- Tracer
        if bundle.Tracer then
            local viewport = Camera.ViewportSize
            local from = Vector2.new(viewport.X / 2, viewport.Y)
            bundle.Tracer.From = from
            bundle.Tracer.To = root2D
            bundle.Tracer.Visible = State.PlayerTracers
        end

        -- Skeleton
        updateSkeleton(bundle, character, true)
    end

    local function updatePlayerESP()
        if not State.PlayerESP or not DrawingAvailable then
            for _, bundle in pairs(playerESP) do
                hidePlayerESP(bundle)
            end
            return
        end

        for _, player in ipairs(Players:GetPlayers()) do
            updateOnePlayerESP(player)
        end
    end

    local function clearAllESP()
        for model in pairs(espObjects) do
            destroyObjectESP(model)
        end

        for player in pairs(playerESP) do
            destroyPlayerESP(player)
        end
    end

    -- ============================================================
    -- Main update loops
    -- ============================================================

    local function startLoops()
        if loopsStarted then
            return
        end

        loopsStarted = true

        RunService.Heartbeat:Connect(function()
            if destroyed then
                return
            end

            applyWalkSpeed()
            applyInfiniteHealth()
        end)

        RunService.RenderStepped:Connect(function()
            if destroyed then
                return
            end

            updateObjectESP()
            updatePlayerESP()
        end)

        Players.PlayerRemoving:Connect(function(player)
            destroyPlayerESP(player)
        end)
    end

    startLoops()

    -- ============================================================
    -- TAB: Auto Farm
    -- ============================================================

    local farmTab = Window:CreateTab("Auto Farm", "zap")

    local farmSection = farmTab:CreateSection(
        "SuperMarket Farm",
        "Automatisches Aufheben und Abgeben der Objekte."
    )

    farmSection:CreateToggle(
        "Start Auto Farm",
        false,
        function(value)
            State.AutoFarm = value

            if value then
                startFarm()
                notify("Auto Farm", "Gestartet.", 2.5, "zap")
            else
                stopFarm()
                notify("Auto Farm", "Gestoppt.", 2.5, "power")
            end
        end,
        "autoFarm"
    )

    farmSection:CreateButton(
        "Ignored Objects Reset",
        function()
            processedModels = {}
            notify(
                "Auto Farm",
                "Alle bisher ignorierten Objekte wurden zurückgesetzt.",
                3,
                "save"
            )
        end
    )

    local farmInfo = farmTab:CreateSection("Farm Settings")
    farmInfo:CreateLabel("Collection: (-382, 10, -408)")
    farmInfo:CreateLabel("Delivery: (-427, 202, 54)")
    farmInfo:CreateLabel("Pickup: ProximityPrompt → Z fallback")
    farmInfo:CreateLabel("Die Kamera wird während des Pickups automatisch auf das Objekt gerichtet.")

    -- ============================================================
    -- TAB: Player
    -- ============================================================

    local playerTab = Window:CreateTab("Player", "user")

    local playerSection = playerTab:CreateSection("Player Utilities")

    playerSection:CreateToggle(
        "Infinite Health",
        false,
        function(value)
            State.InfiniteHealth = value

            if value then
                applyInfiniteHealth()
                notify("Infinite Health", "Aktiviert.", 2, "heart")
            else
                notify("Infinite Health", "Deaktiviert.", 2, "shield")
            end
        end,
        "infiniteHealth"
    )

    playerSection:CreateSlider(
        "WalkSpeed",
        16,
        200,
        16,
        function(value)
            State.WalkSpeed = value
            applyWalkSpeed()
        end,
        "walkSpeed"
    )

    playerSection:CreateButton(
        "Reset WalkSpeed",
        function()
            State.WalkSpeed = 16
            applyWalkSpeed()
            notify("Player", "WalkSpeed auf 16 gesetzt.", 2, "user")
        end
    )

    -- ============================================================
    -- TAB: Object ESP
    -- ============================================================

    local objectTab = Window:CreateTab("Object ESP", "package")

    local objectSection = objectTab:CreateSection(
        "SuperMarket Objects",
        "ESP für Objekte im SuperMarket/Plots/Models Ordner."
    )

    objectSection:CreateToggle(
        "Object ESP",
        false,
        function(value)
            State.ObjectESP = value

            if value then
                scanObjects()
                notify("Object ESP", "Aktiviert.", 2.5, "eye")
            else
                notify("Object ESP", "Deaktiviert.", 2.5, "eye")
            end
        end,
        "objectESP"
    )

    objectSection:CreateToggle(
        "Show Names",
        true,
        function(value)
            State.ObjectNames = value
        end,
        "objectNames"
    )

    objectSection:CreateToggle(
        "Show Distance",
        true,
        function(value)
            State.ObjectDistance = value
        end,
        "objectDistance"
    )

    objectSection:CreateSlider(
        "Max Distance",
        50,
        2500,
        500,
        function(value)
            State.ObjectMaxDistance = value
        end,
        "objectMaxDistance"
    )

    objectSection:CreateButton(
        "Refresh Objects",
        function()
            scanObjects()
            notify("Object ESP", "Objekte neu gescannt.", 2, "wrench")
        end
    )

    -- ============================================================
    -- TAB: Player ESP
    -- ============================================================

    local espTab = Window:CreateTab("Player ESP", "eye")

    local espSection = espTab:CreateSection(
        "Player ESP",
        "Drawing-ESP mit Name, Box, Healthbar, Distance, Tracer und Skeleton."
    )

    espSection:CreateToggle(
        "Player ESP",
        false,
        function(value)
            State.PlayerESP = value

            if value and not DrawingAvailable then
                State.PlayerESP = false
                notify(
                    "Player ESP",
                    "Dein Executor stellt keine Drawing API bereit.",
                    4,
                    "shield"
                )
                return
            end

            notify(
                "Player ESP",
                value and "Aktiviert." or "Deaktiviert.",
                2.5,
                "eye"
            )
        end,
        "playerESP"
    )

    espSection:CreateToggle(
        "Names",
        true,
        function(value)
            State.PlayerNames = value
        end,
        "espNames"
    )

    espSection:CreateToggle(
        "Boxes",
        true,
        function(value)
            State.PlayerBoxes = value
        end,
        "espBoxes"
    )

    espSection:CreateToggle(
        "Health Bar",
        true,
        function(value)
            State.PlayerHealth = value
        end,
        "espHealth"
    )

    espSection:CreateToggle(
        "Distance",
        true,
        function(value)
            State.PlayerDistance = value
        end,
        "espDistance"
    )

    espSection:CreateToggle(
        "Tracers",
        false,
        function(value)
            State.PlayerTracers = value
        end,
        "espTracers"
    )

    espSection:CreateToggle(
        "Skeleton",
        false,
        function(value)
            State.PlayerSkeleton = value
        end,
        "espSkeleton"
    )

    espSection:CreateToggle(
        "Team Check",
        false,
        function(value)
            State.TeamCheck = value
        end,
        "espTeamCheck"
    )

    espSection:CreateSlider(
        "Max Distance",
        100,
        5000,
        1000,
        function(value)
            State.PlayerMaxDistance = value
        end,
        "playerMaxDistance"
    )

    espSection:CreateButton(
        "Refresh Player ESP",
        function()
            for player in pairs(playerESP) do
                destroyPlayerESP(player)
            end

            if State.PlayerESP then
                updatePlayerESP()
            end

            notify("Player ESP", "ESP neu aufgebaut.", 2, "wrench")
        end
    )

    if not DrawingAvailable then
        espSection:CreateLabel("Hinweis: Skeleton/Box/Tracer benötigen Drawing API.")
    end

    -- ============================================================
    -- TAB: Presets
    -- ============================================================

    local presetsTab = Window:CreateTab("Presets", "save")

    local presetsSection = presetsTab:CreateSection(
        "Preset Manager",
        "Speichert alle geflaggten Toggles und Slider."
    )

    presetsSection:CreatePresetManager()

    local presetHelp = presetsTab:CreateSection("Beispiel-Presets")
    presetHelp:CreateButton(
        "Save: AFK Farm",
        function()
            Window:SavePreset("AFK Farm")
            notify("Preset", "AFK Farm gespeichert.", 2.5, "save")
        end
    )

    presetHelp:CreateButton(
        "Save: Object Hunt",
        function()
            Window:SavePreset("Object Hunt")
            notify("Preset", "Object Hunt gespeichert.", 2.5, "save")
        end
    )

    presetHelp:CreateButton(
        "Save: Player ESP",
        function()
            Window:SavePreset("Player ESP")
            notify("Preset", "Player ESP gespeichert.", 2.5, "save")
        end
    )

    -- ============================================================
    -- TAB: Settings
    -- ============================================================

    local settingsTab = Window:CreateTab("Settings", "settings")

    local miscSection = settingsTab:CreateSection("Utility")

    miscSection:CreateButton(
        "Stop All",
        function()
            stopFarm()
            State.ObjectESP = false
            State.PlayerESP = false

            notify("Utility", "AutoFarm + ESP gestoppt.", 3, "power")
        end
    )

    miscSection:CreateButton(
        "Clear ESP",
        function()
            clearAllESP()
            notify("ESP", "Alle ESP-Objekte gelöscht.", 2.5, "skull")
        end
    )

    miscSection:CreateButton(
        "Unload Hub",
        function()
            destroyed = true
            stopFarm()
            clearAllESP()
            Window:Unload()
        end
    )

    miscSection:CreateLabel(
        DrawingAvailable
            and "Drawing API: verfügbar"
            or "Drawing API: nicht verfügbar"
    )

    return Window
end
