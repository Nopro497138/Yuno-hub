return function(Library)
    -- ==========================================
    -- 1. Services & Variables
    -- ==========================================
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Camera = workspace.CurrentCamera
    local LocalPlayer = Players.LocalPlayer

    -- Settings Dictionaries
    local AimbotSettings = {
        Enabled = false,
        Aiming = false,
        TargetPart = "Head",
        Smoothing = 0.5
    }

    local ESPSettings = {
        Enabled = false,
        Chams = false
    }

    -- ==========================================
    -- 2. Helper Functions (ESP & Aimbot Logic)
    -- ==========================================
    
    -- ESP Function
    local function UpdateESP()
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local highlight = player.Character:FindFirstChild("YunoESP")
                
                if ESPSettings.Enabled then
                    if not highlight then
                        highlight = Instance.new("Highlight")
                        highlight.Name = "YunoESP"
                        highlight.Parent = player.Character
                    end
                    
                    highlight.FillTransparency = ESPSettings.Chams and 0.5 or 1
                    highlight.OutlineTransparency = 0
                    highlight.FillColor = Color3.fromRGB(255, 0, 0)
                    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                else
                    if highlight then
                        highlight:Destroy()
                    end
                end
            end
        end
    end

    -- Aimbot Target Selection
    local function GetClosestPlayer()
        local closestPlayer = nil
        local shortestDistance = math.huge
        local mousePos = UserInputService:GetMouseLocation()

        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild(AimbotSettings.TargetPart) and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
                local targetPos, onScreen = Camera:WorldToViewportPoint(player.Character[AimbotSettings.TargetPart].Position)
                
                if onScreen then
                    local distance = (Vector2.new(targetPos.X, targetPos.Y) - mousePos).Magnitude
                    if distance < shortestDistance then
                        closestPlayer = player
                        shortestDistance = distance
                    end
                end
            end
        end
        return closestPlayer
    end

    -- Loops for Aimbot & ESP
    RunService.RenderStepped:Connect(function()
        if ESPSettings.Enabled then
            UpdateESP()
        end

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

    -- Aimbot Keybind (Right Mouse Button)
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton2 then
            AimbotSettings.Aiming = true
        end
    end)

    UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            AimbotSettings.Aiming = false
        end
    end)

    -- ==========================================
    -- 3. UI Construction with YunoHubLibrary
    -- ==========================================
    
    local Window = Library.CreateWindow({
        Title = "Bonk & Block",
        Subtitle = "v1.0",
    })

    -- ===== Combat Tab =====
    local combatTab = Window:CreateTab("Combat", "crosshair")
    local aimbotSection = combatTab:CreateSection("Aimbot Settings")
    
    aimbotSection:CreateToggle("Enable Aimbot", false, function(state)
        AimbotSettings.Enabled = state
    end, "aimbotEnabled")

    aimbotSection:CreateDropdown("Target Part", {"Head", "HumanoidRootPart", "Torso"}, "Head", function(selected)
        AimbotSettings.TargetPart = selected
    end, "aimbotTarget")
    
    aimbotSection:CreateLabel("Aimbot Keybind: Hold Right Mouse Button (RMB)")

    -- ===== Visuals Tab =====
    local visualsTab = Window:CreateTab("Visuals", "eye")
    local espSection = visualsTab:CreateSection("ESP Options")

    espSection:CreateToggle("Enable Player ESP", false, function(state)
        ESPSettings.Enabled = state
        if not state then UpdateESP() end -- Clean up when disabled
    end, "espEnabled")

    espSection:CreateToggle("Fill Chams", false, function(state)
        ESPSettings.Chams = state
    end, "espChams")

    -- ===== Movement Tab =====
    local movementTab = Window:CreateTab("Movement", "rocket")
    local speedSection = movementTab:CreateSection("Local Player")

    speedSection:CreateSlider("Walkspeed", 16, 250, 16, function(value)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = value
        end
    end, "walkSpeed")

    -- ===== Misc Tab =====
    local miscTab = Window:CreateTab("Misc", "settings")
    local utilitySection = miscTab:CreateSection("Utility")

    utilitySection:CreateButton("Unlock Mouse", function()
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        Window:Notify("Mouse Unlocked", "You can now move your cursor freely.", 3, "zap")
    end)

    return Window
end
