--[[
    Runaways Hub – v2.2
    Professional utility hub for Roblox.
    Features: Auto-Loot, ESP (Loot/NPCs/Vehicles), Vehicle Property Tweaks,
    Gas Level Fix, Player Mods (WalkSpeed, JumpPower, Fly, Aimbot).
    Auto‑load PlaceID: 117311404196294 (set in loader config)
]]

return function(Library)
    -- Services
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Workspace = game:GetService("Workspace")
    local TweenService = game:GetService("TweenService")

    local Player = Players.LocalPlayer
    local Character = Player.Character or Player.CharacterAdded:Wait()
    local Humanoid = Character:WaitForChild("Humanoid")
    local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

    -- Window
    local Window = Library.CreateWindow({
        Title = "Runaways Hub",
        Subtitle = "v2.2 · Advanced Utility"
    })

    -- ========================== Utility Functions ==========================

    local function IsValid(instance)
        return instance and instance.Parent ~= nil
    end

    local function FindInChildren(parent, name)
        for _, child in ipairs(parent:GetChildren()) do
            if child.Name == name then
                return child
            end
        end
        return nil
    end

    local function GetAllChildrenByName(parent, name)
        local found = {}
        for _, child in ipairs(parent:GetChildren()) do
            if child.Name == name then
                table.insert(found, child)
            end
        end
        return found
    end

    -- Simulate keypress (requires executor support)
    local function PressE()
        if keypress and keyrelease then
            keypress("E")
            task.wait(0.05)
            keyrelease("E")
        else
            -- Fallback: try to trigger ProximityPrompt directly
            local target = _G._LootTarget
            if target then
                for _, prompt in ipairs(target:GetDescendants()) do
                    if prompt:IsA("ProximityPrompt") and prompt.Enabled then
                        pcall(function()
                            prompt:InputHoldBegin(Player)
                            task.wait(0.1)
                            prompt:InputEnd(Player)
                        end)
                    end
                end
            end
        end
    end

    -- ========================== Tabs ==========================

    local mainTab = Window:CreateTab("Main", "home")
    local espTab = Window:CreateTab("ESP", "eye")
    local vehicleTab = Window:CreateTab("Vehicles", "car")
    local playerTab = Window:CreateTab("Player", "user")

    -- ========================== Main Tab – Auto-Loot ==========================

    local mainSection = mainTab:CreateSection("Loot Automation", "Auto‑collect & teleport to loot.")

    local autoLootEnabled = false
    local autoLootTask = nil
    local collectedLoot = {} -- track collected loot instances

    -- Returns the number of loot items successfully collected
    local function CollectLoot()
        local lootFolder = Workspace:FindFirstChild("Loot")
        if not lootFolder then return 0 end

        local count = 0
        for _, model in ipairs(lootFolder:GetChildren()) do
            if model:IsA("Model") and not collectedLoot[model] then
                local primaryPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
                if primaryPart then
                    -- Teleport to a position 3 studs away from the loot, facing it
                    local lootPos = primaryPart.Position
                    local dirToLoot = (lootPos - HumanoidRootPart.Position).Unit
                    local teleportPos = lootPos - dirToLoot * 3 + Vector3.new(0, 1, 0) -- offset a bit away and up
                    HumanoidRootPart.CFrame = CFrame.new(teleportPos, lootPos)
                    task.wait(0.1)

                    -- Look at the loot with the camera
                    Workspace.CurrentCamera.CFrame = CFrame.new(
                        Workspace.CurrentCamera.CFrame.Position,
                        lootPos
                    )

                    -- Press E
                    _G._LootTarget = model
                    PressE()
                    task.wait(0.2)
                    _G._LootTarget = nil

                    collectedLoot[model] = true
                    count = count + 1
                end
            end
        end
        return count
    end

    mainSection:CreateToggle("Auto-Loot", false, function(state)
        autoLootEnabled = state
        if state then
            autoLootTask = task.spawn(function()
                while autoLootEnabled and Window.Instance and Window.Instance.Parent do
                    CollectLoot() -- silently collect
                    task.wait(0.5)
                end
            end)
        else
            if autoLootTask then
                task.cancel(autoLootTask)
                autoLootTask = nil
            end
        end
    end, "autoLoot")

    -- Manual collect button with notifications
    mainSection:CreateButton("Collect All Loot (Once)", function()
        local lootFolder = Workspace:FindFirstChild("Loot")
        if not lootFolder then
            Window:Notify("Loot", "No loot folder found.", 2, "warning")
            return
        end

        local allLoot = {}
        for _, child in ipairs(lootFolder:GetChildren()) do
            if child:IsA("Model") then table.insert(allLoot, child) end
        end

        if #allLoot == 0 then
            Window:Notify("Loot", "No loot available.", 2, "warning")
            return
        end

        -- Check if all loot is already collected
        local uncollected = 0
        for _, model in ipairs(allLoot) do
            if not collectedLoot[model] then
                uncollected = uncollected + 1
            end
        end

        if uncollected == 0 then
            Window:Notify("Loot", "All loot already collected.", 2, "info")
            -- Optionally reset collected list? We'll let user toggle auto off/on to reset.
            return
        end

        local collected = CollectLoot()
        if collected > 0 then
            Window:Notify("Loot", string.format("Collected %d loot items.", collected), 2, "sparkles")
        else
            Window:Notify("Loot", "No new loot could be collected.", 2, "warning")
        end
    end)

    -- ========================== ESP Tab ==========================

    local espSection = espTab:CreateSection("ESP Settings", "Show information overlays.")

    local espEnabled = {
        Loot = false,
        NPC = false,
        Vehicles = false,
    }
    local espRange = 150
    local espObjects = {}          -- [model] = {Highlight, Billboard, ...}
    local espConnections = {}      -- store ChildAdded/Removed connections

    -- Create ESP for a single model
    local function CreateESPForModel(model, color, label)
        if espObjects[model] then return end

        local highlight = Instance.new("Highlight")
        highlight.FillTransparency = 0.5
        highlight.OutlineTransparency = 0
        highlight.FillColor = color or Color3.fromRGB(255, 255, 255)
        highlight.OutlineColor = color or Color3.fromRGB(255, 255, 255)
        highlight.Adornee = model
        highlight.Parent = model

        local billboard = Instance.new("BillboardGui")
        billboard.Size = UDim2.new(0, 200, 0, 30)
        billboard.StudsOffset = Vector3.new(0, 2, 0)
        billboard.MaxDistance = espRange
        billboard.AlwaysOnTop = true
        billboard.Parent = model

        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        textLabel.TextStrokeTransparency = 0.2
        textLabel.Font = Enum.Font.GothamBold
        textLabel.TextSize = 14
        textLabel.Text = label or model.Name
        textLabel.Parent = billboard

        local distLabel = Instance.new("TextLabel")
        distLabel.Size = UDim2.new(1, 0, 0, 20)
        distLabel.Position = UDim2.new(0, 0, 1, 0)
        distLabel.BackgroundTransparency = 1
        distLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        distLabel.TextStrokeTransparency = 0.4
        distLabel.Font = Enum.Font.Gotham
        distLabel.TextSize = 12
        distLabel.Text = "0m"
        distLabel.Parent = billboard

        espObjects[model] = {
            Highlight = highlight,
            Billboard = billboard,
            TextLabel = textLabel,
            DistLabel = distLabel,
        }
    end

    local function RemoveESPForModel(model)
        local data = espObjects[model]
        if data then
            data.Highlight:Destroy()
            data.Billboard:Destroy()
            espObjects[model] = nil
        end
    end

    local function ClearAllESP()
        for model, _ in pairs(espObjects) do
            RemoveESPForModel(model)
        end
        espObjects = {}
        -- Disconnect all child event connections
        for _, conn in ipairs(espConnections) do
            conn:Disconnect()
        end
        espConnections = {}
    end

    -- Update distance labels and visibility
    local function UpdateESP()
        local playerPos = HumanoidRootPart and HumanoidRootPart.Position or Vector3.zero
        for model, data in pairs(espObjects) do
            if not IsValid(model) then
                RemoveESPForModel(model)
                continue
            end
            local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
            if primary then
                local dist = (primary.Position - playerPos).Magnitude
                data.DistLabel.Text = string.format("%.0fm", dist)
                local visible = dist <= espRange
                data.Billboard.Enabled = visible
                data.Highlight.Enabled = visible
            else
                data.Billboard.Enabled = false
                data.Highlight.Enabled = false
            end
        end
    end

    local espHeartbeat = nil

    local function StartESPHeartbeat()
        if espHeartbeat then return end
        espHeartbeat = RunService.Heartbeat:Connect(UpdateESP)
    end

    local function StopESPHeartbeat()
        if espHeartbeat then
            espHeartbeat:Disconnect()
            espHeartbeat = nil
        end
    end

    -- Refresh ESP for a category (add/remove based on enabled state)
    local function RefreshESP(category, enabled, color, labelPrefix)
        local container
        if category == "Loot" then
            container = Workspace:FindFirstChild("Loot")
        elseif category == "NPC" then
            container = Workspace:FindFirstChild("NPCs")
        elseif category == "Vehicles" then
            container = Workspace:FindFirstChild("Vehicles")
        end
        if not container then return end

        if not enabled then
            -- Remove all ESP for this category
            for model, _ in pairs(espObjects) do
                if model:IsA("Model") and model:FindFirstChild("_ESP_Category") and model._ESP_Category.Value == category then
                    RemoveESPForModel(model)
                end
            end
            -- Disconnect child events for this category
            for i, conn in ipairs(espConnections) do
                if conn._category == category then
                    conn:Disconnect()
                    table.remove(espConnections, i)
                    break
                end
            end
            return
        end

        -- Add ESP to existing children
        for _, model in ipairs(container:GetChildren()) do
            if model:IsA("Model") and not espObjects[model] then
                local tag = Instance.new("StringValue")
                tag.Name = "_ESP_Category"
                tag.Value = category
                tag.Parent = model
                local label = (labelPrefix or "") .. model.Name
                CreateESPForModel(model, color, label)
            end
        end

        -- Listen for new children
        local childAddedConn = container.ChildAdded:Connect(function(child)
            if child:IsA("Model") and not espObjects[child] then
                local tag = Instance.new("StringValue")
                tag.Name = "_ESP_Category"
                tag.Value = category
                tag.Parent = child
                local label = (labelPrefix or "") .. child.Name
                CreateESPForModel(child, color, label)
            end
        end)
        childAddedConn._category = category
        table.insert(espConnections, childAddedConn)

        -- Also clean up when children are removed
        local childRemovedConn = container.ChildRemoved:Connect(function(child)
            if child:IsA("Model") then
                RemoveESPForModel(child)
            end
        end)
        childRemovedConn._category = category
        table.insert(espConnections, childRemovedConn)
    end

    -- Loot ESP
    espSection:CreateToggle("Loot ESP", false, function(state)
        espEnabled.Loot = state
        RefreshESP("Loot", state, Color3.fromRGB(255, 215, 0), "🟡 ")
        if state or espEnabled.NPC or espEnabled.Vehicles then
            StartESPHeartbeat()
        else
            StopESPHeartbeat()
        end
    end, "espLoot")

    -- NPC ESP
    espSection:CreateToggle("NPC ESP", false, function(state)
        espEnabled.NPC = state
        RefreshESP("NPC", state, Color3.fromRGB(255, 0, 0), "🔴 ")
        if state or espEnabled.Loot or espEnabled.Vehicles then
            StartESPHeartbeat()
        else
            StopESPHeartbeat()
        end
    end, "espNPC")

    -- Vehicle ESP
    espSection:CreateToggle("Vehicle ESP", false, function(state)
        espEnabled.Vehicles = state
        RefreshESP("Vehicles", state, Color3.fromRGB(0, 150, 255), "🔵 ")
        if state or espEnabled.Loot or espEnabled.NPC then
            StartESPHeartbeat()
        else
            StopESPHeartbeat()
        end
    end, "espVehicles")

    -- ESP Range
    espSection:CreateSlider("ESP Range", 10, 500, 150, function(value)
        espRange = value
        for _, data in pairs(espObjects) do
            data.Billboard.MaxDistance = value
        end
    end, "espRange")

    espSection:CreateButton("Clear All ESP", function()
        ClearAllESP()
        StopESPHeartbeat()
        espEnabled.Loot = false
        espEnabled.NPC = false
        espEnabled.Vehicles = false
        Window:Notify("ESP", "All ESP cleared.", 2, "eye")
    end)

    -- ========================== Vehicle Tab ==========================

    local vehicleSection = vehicleTab:CreateSection("Vehicle Tweaks", "Adjust vehicle properties and fuel.")

    -- Gas Level Fix
    local gasLevelEnabled = false
    local gasLevelTask = nil

    vehicleSection:CreateToggle("Fix Gas Level (999)", false, function(state)
        gasLevelEnabled = state
        if state then
            gasLevelTask = task.spawn(function()
                while gasLevelEnabled and Window.Instance and Window.Instance.Parent do
                    local vehicles = Workspace:FindFirstChild("Vehicles")
                    if vehicles then
                        for _, vehicle in ipairs(vehicles:GetChildren()) do
                            if vehicle:IsA("Model") then
                                local gas = FindInChildren(vehicle, "gasLevel")
                                if gas and gas:IsA("NumberValue") then
                                    gas.Value = 999
                                end
                            end
                        end
                    end
                    task.wait(0.1)
                end
            end)
        else
            if gasLevelTask then
                task.cancel(gasLevelTask)
                gasLevelTask = nil
            end
        end
    end, "gasLevelFix")

    -- Vehicle Property Sliders
    local selectedVehicleName = ""
    local propertySliders = {}
    local propertySection = nil

    local function GetVehiclesWithProperties()
        local vehicles = Workspace:FindFirstChild("Vehicles")
        if not vehicles then return {} end
        local list = {}
        for _, v in ipairs(vehicles:GetChildren()) do
            if v:IsA("Model") then
                local propFolder = FindInChildren(v, "VehicleProperty")
                if propFolder then
                    table.insert(list, v.Name)
                end
            end
        end
        return list
    end

    local function RebuildPropertySliders(vehicleName)
        if propertySection then
            -- Clear existing sliders
            local container = propertySection.Instance
            for _, child in ipairs(container:GetChildren()) do
                if child:IsA("GuiObject") then
                    child:Destroy()
                end
            end
            propertySliders = {}
        else
            propertySection = vehicleTab:CreateSection("Property Adjustments", "Fine‑tune vehicle stats.")
        end

        if not vehicleName or vehicleName == "" then return end

        local vehicles = Workspace:FindFirstChild("Vehicles")
        if not vehicles then return end
        local vehicle = vehicles:FindFirstChild(vehicleName)
        if not vehicle or not vehicle:IsA("Model") then return end

        local propFolder = FindInChildren(vehicle, "VehicleProperty")
        if not propFolder then
            propertySection:CreateLabel("No VehicleProperty folder found.")
            return
        end

        local props = {}
        for _, child in ipairs(propFolder:GetChildren()) do
            if child:IsA("NumberValue") then
                table.insert(props, child)
            end
        end

        if #props == 0 then
            propertySection:CreateLabel("No numeric properties found.")
            return
        end

        for _, prop in ipairs(props) do
            local name = prop.Name
            local current = prop.Value
            -- Heuristic min/max
            local min, max = 0, 100
            local lower = string.lower(name)
            if lower:find("accel") then
                min, max = 0, 200
            elseif lower:find("brake") or lower:find("break") then
                min, max = 0, 200
            elseif lower:find("speed") then
                min, max = 0, 300
            elseif lower:find("torque") then
                min, max = 0, 500
            else
                min, max = 0, 100
            end

            local slider = propertySection:CreateSlider(
                name,
                min,
                max,
                current,
                function(value)
                    prop.Value = value
                end,
                "veh_" .. name
            )
            propertySliders[prop] = slider
        end
    end

    local vehicleNames = GetVehiclesWithProperties()
    selectedVehicleName = vehicleNames[1] or ""
    vehicleSection:CreateDropdown("Select Vehicle", vehicleNames, selectedVehicleName, function(choice)
        selectedVehicleName = choice
        RebuildPropertySliders(choice)
    end, "selectedVehicle")

    vehicleSection:CreateButton("Refresh Vehicle List", function()
        local newList = GetVehiclesWithProperties()
        Window:Notify("Vehicles", "New list: " .. table.concat(newList, ", "), 3, "refresh")
        Window:Notify("Info", "Please restart the hub to refresh the dropdown.", 3, "info")
    end)

    if selectedVehicleName ~= "" then
        RebuildPropertySliders(selectedVehicleName)
    end

    -- ========================== Player Tab ==========================

    local playerSection = playerTab:CreateSection("Movement & Combat", "Enhance your character.")

    -- WalkSpeed
    playerSection:CreateSlider("Walk Speed", 16, 100, 16, function(value)
        if Humanoid then Humanoid.WalkSpeed = value end
    end, "walkSpeed")

    -- JumpPower
    playerSection:CreateSlider("Jump Power", 50, 300, 50, function(value)
        if Humanoid then Humanoid.JumpPower = value end
    end, "jumpPower")

    -- Fly
    local flyEnabled = false
    local flyBodyVelocity = nil
    local flyBodyGyro = nil
    local flyConnection = nil
    local keysDown = {}

    local function EnableFly()
        if not Character or not HumanoidRootPart then return end
        flyBodyVelocity = Instance.new("BodyVelocity")
        flyBodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        flyBodyVelocity.Velocity = Vector3.zero
        flyBodyVelocity.Parent = HumanoidRootPart

        flyBodyGyro = Instance.new("BodyGyro")
        flyBodyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
        flyBodyGyro.CFrame = HumanoidRootPart.CFrame
        flyBodyGyro.Parent = HumanoidRootPart

        if Humanoid then
            Humanoid.PlatformStand = true
        end

        flyConnection = RunService.Heartbeat:Connect(function()
            if not flyEnabled or not HumanoidRootPart then return end
            local move = Vector3.zero
            if keysDown["W"] then move = move + (HumanoidRootPart.CFrame.LookVector * 50) end
            if keysDown["S"] then move = move - (HumanoidRootPart.CFrame.LookVector * 50) end
            if keysDown["A"] then move = move - (HumanoidRootPart.CFrame.RightVector * 50) end
            if keysDown["D"] then move = move + (HumanoidRootPart.CFrame.RightVector * 50) end
            if keysDown["Space"] then move = move + Vector3.new(0, 50, 0) end
            if keysDown["LeftShift"] then move = move - Vector3.new(0, 50, 0) end
            flyBodyVelocity.Velocity = move
            flyBodyGyro.CFrame = HumanoidRootPart.CFrame
        end)
    end

    local function DisableFly()
        if flyBodyVelocity then flyBodyVelocity:Destroy(); flyBodyVelocity = nil end
        if flyBodyGyro then flyBodyGyro:Destroy(); flyBodyGyro = nil end
        if flyConnection then flyConnection:Disconnect(); flyConnection = nil end
        if Humanoid then
            Humanoid.PlatformStand = false
        end
    end

    local inputBeganConn, inputEndedConn

    playerSection:CreateToggle("Fly", false, function(state)
        flyEnabled = state
        if state then
            if not Character or not HumanoidRootPart then
                Window:Notify("Fly", "Character not found. Respawn first.", 3, "warning")
                return
            end
            EnableFly()
            inputBeganConn = UserInputService.InputBegan:Connect(function(input, gp)
                if gp then return end
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    keysDown[input.KeyCode.Name] = true
                end
            end)
            inputEndedConn = UserInputService.InputEnded:Connect(function(input, gp)
                if gp then return end
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    keysDown[input.KeyCode.Name] = nil
                end
            end)
        else
            DisableFly()
            if inputBeganConn then inputBeganConn:Disconnect(); inputBeganConn = nil end
            if inputEndedConn then inputEndedConn:Disconnect(); inputEndedConn = nil end
        end
    end, "fly")

    -- Aimbot
    local aimbotEnabled = false
    local aimbotConnection = nil

    local function GetNearestEnemy()
        local npcContainer = Workspace:FindFirstChild("NPCs")
        if not npcContainer then return nil end
        local playerPos = HumanoidRootPart and HumanoidRootPart.Position or Vector3.zero
        local nearest, nearestDist = nil, math.huge
        for _, model in ipairs(npcContainer:GetChildren()) do
            if model:IsA("Model") and model:FindFirstChildWhichIsA("Humanoid") then
                local head = model:FindFirstChild("Head")
                if head and head:IsA("BasePart") then
                    local dist = (head.Position - playerPos).Magnitude
                    if dist < nearestDist then
                        nearest = model
                        nearestDist = dist
                    end
                end
            end
        end
        return nearest
    end

    local function AimbotLoop()
        local camera = Workspace.CurrentCamera
        while aimbotEnabled and Window.Instance and Window.Instance.Parent do
            local target = GetNearestEnemy()
            if target and target:FindFirstChild("Head") then
                camera.CFrame = CFrame.new(camera.CFrame.Position, target.Head.Position)
            end
            task.wait(0.05)
        end
    end

    playerSection:CreateToggle("Aimbot (NPCs)", false, function(state)
        aimbotEnabled = state
        if state then
            if aimbotConnection then aimbotConnection:Disconnect() end
            aimbotConnection = task.spawn(AimbotLoop)
        else
            if aimbotConnection then
                task.cancel(aimbotConnection)
                aimbotConnection = nil
            end
        end
    end, "aimbot")

    -- ========================== Return ==========================

    return Window
end
