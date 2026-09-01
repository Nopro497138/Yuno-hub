return function(Library)
    -- ==========================================
    -- 1. Services & Variables
    -- ==========================================
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Camera = workspace.CurrentCamera
    local LocalPlayer = Players.LocalPlayer

    -- Settings
    local AimbotSettings = {
        Enabled = false,
        Aiming = false,
        TargetPart = "Head",
        UseFOV = false,
        FOVRadius = 100
    }

    local ESPSettings = {
        Enabled = false,
        Chams = false,
        Boxes = false,
        Names = false,
        Distance = false,
        Tracers = false
    }

    -- FOV Circle Setup
    local FOVCircle = Drawing.new("Circle")
    FOVCircle.Thickness = 1
    FOVCircle.Color = Color3.fromRGB(255, 255, 255)
    FOVCircle.Filled = false
    FOVCircle.Visible = false

    -- Cache for ESP Drawings & Instances
    local ESP_Cache = {}

    -- ==========================================
    -- 2. Helper Functions (ESP & Aimbot)
    -- ==========================================
    
    local function GetClosestPlayer()
        local closestPlayer = nil
        local shortestDistance = math.huge
        local mousePos = UserInputService:GetMouseLocation()

        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild(AimbotSettings.TargetPart) and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
                local targetPos, onScreen = Camera:WorldToViewportPoint(player.Character[AimbotSettings.TargetPart].Position)
                
                if onScreen then
                    local distance = (Vector2.new(targetPos.X, targetPos.Y) - mousePos).Magnitude
                    
                    -- FOV Check
                    if AimbotSettings.UseFOV and distance > AimbotSettings.FOVRadius then
                        continue
                    end

                    if distance < shortestDistance then
                        closestPlayer = player
                        shortestDistance = distance
                    end
                end
            end
        end
        return closestPlayer
    end

    local function ClearESP(player)
        if ESP_Cache[player] then
            if ESP_Cache[player].Box then ESP_Cache[player].Box:Remove() end
            if ESP_Cache[player].Tracer then ESP_Cache[player].Tracer:Remove() end
            if ESP_Cache[player].Billboard then ESP_Cache[player].Billboard:Destroy() end
            if player.Character and player.Character:FindFirstChild("YunoESP") then
                player.Character.YunoESP:Destroy()
            end
            ESP_Cache[player] = nil
        end
    end

    local function UpdateESP()
        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            
            if not ESPSettings.Enabled or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") or player.Character.Humanoid.Health <= 0 then
                ClearESP(player)
                continue
            end

            -- Init Cache for Player
            if not ESP_Cache[player] then
                ESP_Cache[player] = {
                    Box = Drawing.new("Square"),
                    Tracer = Drawing.new("Line"),
                    Billboard = Instance.new("BillboardGui"),
                    Text = Instance.new("TextLabel")
                }
                
                -- Setup Billboard for Name/Distance
                local bb = ESP_Cache[player].Billboard
                local txt = ESP_Cache[player].Text
                bb.AlwaysOnTop = true
                bb.Size = UDim2.new(0, 100, 0, 40)
                bb.StudsOffset = Vector3.new(0, 3, 0)
                txt.Parent = bb
                txt.BackgroundTransparency = 1
                txt.Size = UDim2.new(1, 0, 1, 0)
                txt.Font = Enum.Font.Code
                txt.TextSize = 14
                txt.TextColor3 = Color3.new(1, 1, 1)
                txt.TextStrokeTransparency = 0
            end

            local cache = ESP_Cache[player]
            local hrp = player.Character.HumanoidRootPart
            local vector, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            local rootPartPos = hrp.Position

            -- Chams
            local highlight = player.Character:FindFirstChild("YunoESP")
            if ESPSettings.Chams then
                if not highlight then
                    highlight = Instance.new("Highlight")
                    highlight.Name = "YunoESP"
                    highlight.Parent = player.Character
                end
                highlight.FillTransparency = 0.5
                highlight.FillColor = Color3.new(1, 0, 0)
            elseif highlight then
                highlight:Destroy()
            end

            if onScreen then
                -- Box
                if ESPSettings.Boxes then
                    local sizeX = 2000 / vector.Z
                    local sizeY = 3000 / vector.Z
                    cache.Box.Size = Vector2.new(sizeX, sizeY)
                    cache.Box.Position = Vector2.new(vector.X - sizeX / 2, vector.Y - sizeY / 2)
                    cache.Box.Color = Color3.new(1, 0, 0)
                    cache.Box.Thickness = 1
                    cache.Box.Filled = false
                    cache.Box.Visible = true
                else
                    cache.Box.Visible = false
                end

                -- Tracers
                if ESPSettings.Tracers then
                    cache.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    cache.Tracer.To = Vector2.new(vector.X, vector.Y)
                    cache.Tracer.Color = Color3.new(1, 0, 0)
                    cache.Tracer.Thickness = 1
                    cache.Tracer.Visible = true
                else
                    cache.Tracer.Visible = false
                end

                -- Name & Distance
                if ESPSettings.Names or ESPSettings.Distance then
                    cache.Billboard.Parent = player.Character.Head
                    local dist = math.floor((Camera.CFrame.Position - rootPartPos).Magnitude)
                    local displayStr = ""
                    if ESPSettings.Names then displayStr = player.Name end
                    if ESPSettings.Distance then displayStr = displayStr .. "\n[" .. dist .. "m]" end
                    cache.Text.Text = displayStr
                    cache.Billboard.Enabled = true
                else
                    cache.Billboard.Enabled = false
                end
            else
                cache.Box.Visible = false
                cache.Tracer.Visible = false
                cache.Billboard.Enabled = false
            end
        end
    end

    -- Update Loop
    RunService.RenderStepped:Connect(function()
        -- FOV Logic
        local mousePos = UserInputService:GetMouseLocation()
        FOVCircle.Position = mousePos
        FOVCircle.Radius = AimbotSettings.FOVRadius
        FOVCircle.Visible = AimbotSettings.UseFOV

        -- ESP Logic
        UpdateESP()

        -- Aimbot Logic
        if AimbotSettings.Enabled and AimbotSettings.Aiming then
            local target = GetClosestPlayer()
            if target and target.Character then
                local targetPart = target.Character:FindFirstChild(AimbotSettings.TargetPart)
                if targetPart then
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPart.Position)
                end
            end
        end
    end)

    -- Aimbot Keybind
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton2 then AimbotSettings.Aiming = true end
    end)
    UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then AimbotSettings.Aiming = false end
    end)

    -- Cleanup on Player Leave
    Players.PlayerRemoving:Connect(ClearESP)

    -- ==========================================
    -- 3. UI Construction
    -- ==========================================
    local Window = Library.CreateWindow({ Title = "Bonk & Block", Subtitle = "v2.0 PRO" })

    -- ===== Combat Tab =====
    local combatTab = Window:CreateTab("Combat", "crosshair")
    local aimbotSection = combatTab:CreateSection("Aimbot")
    aimbotSection:CreateToggle("Enable Aimbot", false, function(s) AimbotSettings.Enabled = s end, "aimbotEnabled")
    aimbotSection:CreateDropdown("Target Part", {"Head", "HumanoidRootPart", "Torso"}, "Head", function(s) AimbotSettings.TargetPart = s end, "aimbotTarget")
    
    local fovSection = combatTab:CreateSection("FOV Settings")
    fovSection:CreateToggle("Show & Use FOV Circle", false, function(s) AimbotSettings.UseFOV = s end, "useFov")
    fovSection:CreateSlider("FOV Radius", 10, 500, 100, function(v) AimbotSettings.FOVRadius = v end, "fovRadius")

    -- ===== Visuals Tab =====
    local visualsTab = Window:CreateTab("Visuals", "eye")
    local espSection = visualsTab:CreateSection("ESP Components")
    espSection:CreateToggle("Master Switch", false, function(s) 
        ESPSettings.Enabled = s 
        if not s then for _, p in pairs(Players:GetPlayers()) do ClearESP(p) end end
    end, "espEnabled")
    espSection:CreateToggle("Boxes", false, function(s) ESPSettings.Boxes = s end, "espBoxes")
    espSection:CreateToggle("Names", false, function(s) ESPSettings.Names = s end, "espNames")
    espSection:CreateToggle("Distance", false, function(s) ESPSettings.Distance = s end, "espDistance")
    espSection:CreateToggle("Tracers", false, function(s) ESPSettings.Tracers = s end, "espTracers")
    espSection:CreateToggle("Chams (Highlight)", false, function(s) ESPSettings.Chams = s end, "espChams")

    -- ===== Movement Tab =====
    local movementTab = Window:CreateTab("Movement", "rocket")
    local speedSection = movementTab:CreateSection("Local Player")
    speedSection:CreateSlider("Walkspeed", 16, 250, 16, function(v)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = v
        end
    end, "walkSpeed")

    -- ===== Presets Tab =====
    local presetsTab = Window:CreateTab("Presets", "sparkles")
    local presetSection = presetsTab:CreateSection("Configurations", "Save your settings for later.")
    presetSection:CreatePresetManager()

    return Window
end
