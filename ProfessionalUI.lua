--[[
	ProfessionalUI.lua — "Galaxy" Style UI Demo

	- Galaxy-Theme: Sternenfeld + Nebel-Glow im Hintergrund, violett/magenta/cyan Akzente,
	  langsam durchlaufender Farbverlauf am Fensterrand
	- Handgezeichnete Vektor-Icons (Haus, Zahnrad, Sparkle, Balken, Auge, Power) — Design an
	  echten lucide-Icons ausgerichtet (via Iconify recherchiert: house / settings / sparkles /
	  bar-chart / eye / power), aber als native Roblox-Frames gebaut. So braucht es keinen
	  Bild-Upload/Studio-Account, um korrekt zu rendern.
	- Top-Right Overlay: echtes Profilbild (Roblox-Thumbnail-API), Live-FPS, Live-Ping
	  (farbcodierter Punkt), einklappbar über eigenen Augen-Button
	- Fenster: draggable, minimierbar, ausblendbar (schwebender Launcher-Orb bleibt sichtbar)
	  und vollständig "unloadbar" (zerstört die gesamte UI, Sicherheits-Doppelklick)
	- Tabs mit Icons: Home / Presets / Stats / Settings, Sections mit Button/Toggle/Slider/
	  Dropdown/Progressbar, Eröffnungs- und Wechsel-Animationen

	Als LocalScript in StarterPlayerScripts einfügen.
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local StatsService = game:GetService("Stats")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============ Galaxy Theme ============

local Theme = {
	Background   = Color3.fromRGB(10, 9, 20),
	Topbar       = Color3.fromRGB(16, 14, 30),
	Sidebar      = Color3.fromRGB(14, 13, 26),
	Section      = Color3.fromRGB(20, 18, 38),
	Element      = Color3.fromRGB(28, 25, 50),
	ElementHover = Color3.fromRGB(38, 34, 66),
	Violet       = Color3.fromRGB(150, 100, 255),
	Magenta      = Color3.fromRGB(230, 90, 210),
	Cyan         = Color3.fromRGB(80, 210, 255),
	Text         = Color3.fromRGB(238, 235, 250),
	SubText      = Color3.fromRGB(150, 145, 175),
	Good         = Color3.fromRGB(90, 230, 150),
	Warn         = Color3.fromRGB(255, 200, 80),
	Bad          = Color3.fromRGB(255, 95, 110),
}

local FONT = Enum.Font.Gotham
local FONT_BOLD = Enum.Font.GothamSemibold

-- ============ Helpers ============

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = (radius == "circle") and UDim.new(1, 0) or UDim.new(0, radius or 6)
	c.Parent = parent
	return c
end

local function ring(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 1
	s.Transparency = 0
	s.Parent = parent
	return s
end

local function faintStroke(parent, transparency)
	local s = Instance.new("UIStroke")
	s.Color = Theme.Violet
	s.Thickness = 1
	s.Transparency = transparency or 0.8
	s.Parent = parent
	return s
end

local function tween(inst, props, dur, style, dir)
	local t = TweenService:Create(inst, TweenInfo.new(dur or 0.2, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function addHoverScale(button, upScale)
	local scale = Instance.new("UIScale")
	scale.Parent = button
	button.MouseEnter:Connect(function() tween(scale, { Scale = upScale or 1.04 }, 0.15) end)
	button.MouseLeave:Connect(function() tween(scale, { Scale = 1 }, 0.15) end)
	return scale
end

local function makeDraggable(handle, target)
	local dragging, dragStart, startPos
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = target.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	handle.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end

-- ============ Vektor-Icons (Iconify-Recherche: lucide house/settings/sparkles/bar-chart/eye/power) ============

local Icons = {}

local function iconBase(parent, size)
	local c = Instance.new("Frame")
	c.BackgroundTransparency = 1
	c.Size = UDim2.fromOffset(size, size)
	c.Parent = parent
	return c
end

function Icons.house(parent, size, color)
	local c = iconBase(parent, size)
	local roof = Instance.new("Frame")
	roof.AnchorPoint = Vector2.new(0.5, 0.5)
	roof.Position = UDim2.new(0.5, 0, 0.34, 0)
	roof.Size = UDim2.fromOffset(size * 0.6, size * 0.6)
	roof.Rotation = 45
	roof.BackgroundColor3 = color
	roof.ZIndex = 1
	roof.Parent = c
	corner(roof, size * 0.08)

	local base = Instance.new("Frame")
	base.AnchorPoint = Vector2.new(0.5, 1)
	base.Position = UDim2.new(0.5, 0, 1, 0)
	base.Size = UDim2.fromOffset(size * 0.68, size * 0.46)
	base.BackgroundColor3 = color
	base.ZIndex = 2
	base.Parent = c
	corner(base, size * 0.06)
	return c
end

function Icons.gear(parent, size, color, spin)
	local c = iconBase(parent, size)
	local body = Instance.new("Frame")
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.5, 0.5)
	body.Size = UDim2.fromOffset(size * 0.62, size * 0.62)
	body.BackgroundTransparency = 1
	body.Parent = c
	corner(body, "circle")
	ring(body, color, size * 0.11)

	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(size * 0.16, size * 0.16)
	dot.BackgroundColor3 = color
	dot.Parent = c
	corner(dot, "circle")

	for i = 0, 7 do
		local angle = (i / 8) * math.pi * 2
		local tooth = Instance.new("Frame")
		tooth.AnchorPoint = Vector2.new(0.5, 0.5)
		tooth.Size = UDim2.fromOffset(size * 0.15, size * 0.15)
		tooth.Position = UDim2.new(0.5, math.cos(angle) * size * 0.4, 0.5, math.sin(angle) * size * 0.4)
		tooth.BackgroundColor3 = color
		tooth.Rotation = 45
		tooth.Parent = c
		corner(tooth, size * 0.03)
	end

	if spin then
		RunService.Heartbeat:Connect(function(dt)
			if c.Parent then
				c.Rotation = (c.Rotation + dt * 14) % 360
			end
		end)
	end
	return c
end

function Icons.sparkle(parent, size, color)
	local c = iconBase(parent, size)
	local big = Instance.new("Frame")
	big.AnchorPoint = Vector2.new(0.5, 0.5)
	big.Position = UDim2.new(0.42, 0, 0.42, 0)
	big.Size = UDim2.fromOffset(size * 0.5, size * 0.5)
	big.Rotation = 45
	big.BackgroundColor3 = color
	big.Parent = c
	corner(big, size * 0.1)

	local small = Instance.new("Frame")
	small.AnchorPoint = Vector2.new(0.5, 0.5)
	small.Position = UDim2.new(0.82, 0, 0.82, 0)
	small.Size = UDim2.fromOffset(size * 0.22, size * 0.22)
	small.Rotation = 45
	small.BackgroundColor3 = color
	small.Parent = c
	corner(small, size * 0.06)
	return c
end

function Icons.bars(parent, size, color)
	local c = iconBase(parent, size)
	local heights = { 0.4, 0.7, 1 }
	for i, h in ipairs(heights) do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0, 1)
		bar.Position = UDim2.new((i - 1) * 0.36, 0, 1, 0)
		bar.Size = UDim2.new(0, size * 0.24, h * 0.85, 0)
		bar.BackgroundColor3 = color
		bar.Parent = c
		corner(bar, size * 0.04)
	end
	return c
end

function Icons.power(parent, size, color)
	local c = iconBase(parent, size)
	local body = Instance.new("Frame")
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.5, 0.56)
	body.Size = UDim2.fromOffset(size * 0.6, size * 0.6)
	body.BackgroundTransparency = 1
	body.Parent = c
	corner(body, "circle")
	ring(body, color, size * 0.11)

	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(0.5, 0)
	line.Position = UDim2.new(0.5, 0, 0, 0)
	line.Size = UDim2.fromOffset(size * 0.11, size * 0.42)
	line.BackgroundColor3 = color
	line.Parent = c
	corner(line, size * 0.05)
	return c
end

function Icons.eye(parent, size, color)
	local c = iconBase(parent, size)
	local lens = Instance.new("Frame")
	lens.AnchorPoint = Vector2.new(0.5, 0.5)
	lens.Position = UDim2.fromScale(0.5, 0.5)
	lens.Size = UDim2.fromOffset(size * 0.9, size * 0.5)
	lens.BackgroundTransparency = 1
	lens.Name = "Lens"
	lens.Parent = c
	corner(lens, size * 0.25)
	ring(lens, color, size * 0.1)

	local pupil = Instance.new("Frame")
	pupil.Name = "Pupil"
	pupil.AnchorPoint = Vector2.new(0.5, 0.5)
	pupil.Position = UDim2.fromScale(0.5, 0.5)
	pupil.Size = UDim2.fromOffset(size * 0.22, size * 0.22)
	pupil.BackgroundColor3 = color
	pupil.Parent = c
	corner(pupil, "circle")

	local closedLine = Instance.new("Frame")
	closedLine.Name = "ClosedLine"
	closedLine.AnchorPoint = Vector2.new(0.5, 0.5)
	closedLine.Position = UDim2.fromScale(0.5, 0.5)
	closedLine.Size = UDim2.fromOffset(size * 0.85, size * 0.12)
	closedLine.BackgroundColor3 = color
	closedLine.Visible = false
	closedLine.Parent = c
	corner(closedLine, size * 0.06)

	return c
end

local function setEyeState(eyeIcon, open)
	eyeIcon.Lens.Visible = open
	eyeIcon.Pupil.Visible = open
	eyeIcon.ClosedLine.Visible = not open
end

-- ============ Root ScreenGui + Galaxy Background ============

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GalaxyUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.BackgroundTransparency = 1
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.ZIndex = 1
backdrop.Parent = screenGui

-- Nebel-Glow (mehrere gestapelte, transparente Kreise als weicher Glow)
local function nebulaGlow(pos, baseColor, maxSize)
	for i = 1, 4 do
		local glow = Instance.new("Frame")
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = pos
		glow.Size = UDim2.fromOffset(maxSize * (i / 4), maxSize * (i / 4))
		glow.BackgroundColor3 = baseColor
		glow.BackgroundTransparency = 0.94 + (i * 0.012)
		glow.BorderSizePixel = 0
		glow.ZIndex = 1
		glow.Parent = backdrop
		corner(glow, "circle")
	end
end

nebulaGlow(UDim2.fromScale(0.12, 0.18), Theme.Violet, 500)
nebulaGlow(UDim2.fromScale(0.9, 0.75), Theme.Cyan, 420)
nebulaGlow(UDim2.fromScale(0.75, 0.15), Theme.Magenta, 360)

-- Sternenfeld mit Twinkle-Animation
for _ = 1, 55 do
	local star = Instance.new("Frame")
	local s = math.random(1, 3)
	star.Size = UDim2.fromOffset(s, s)
	star.Position = UDim2.fromScale(math.random(), math.random())
	star.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	star.BackgroundTransparency = math.random(30, 80) / 100
	star.BorderSizePixel = 0
	star.ZIndex = 1
	star.Parent = backdrop
	corner(star, "circle")

	local dur = math.random(15, 35) / 10
	local t = TweenService:Create(star, TweenInfo.new(dur, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 1 })
	task.delay(math.random() * dur, function() t:Play() end)
end

-- ============ Window ============

local FULL_SIZE = UDim2.fromOffset(600, 400)

local Window = Instance.new("Frame")
Window.Name = "Window"
Window.AnchorPoint = Vector2.new(0.5, 0.5)
Window.Position = UDim2.fromScale(0.5, 0.5)
Window.Size = FULL_SIZE
Window.BackgroundColor3 = Theme.Background
Window.BackgroundTransparency = 1
Window.ClipsDescendants = true
Window.ZIndex = 4
Window.Parent = screenGui
corner(Window, 10)
local windowStroke = ring(Window, Theme.Violet, 1.4)

-- Langsam durchlaufender Galaxy-Farbverlauf am Rand
RunService.Heartbeat:Connect(function()
	if not Window.Parent then return end
	local hue = 0.72 + 0.13 * math.sin(os.clock() * 0.35)
	windowStroke.Color = Color3.fromHSV(hue % 1, 0.55, 1)
end)

-- Topbar
local Topbar = Instance.new("Frame")
Topbar.BackgroundColor3 = Theme.Topbar
Topbar.Size = UDim2.new(1, 0, 0, 44)
Topbar.ZIndex = 5
Topbar.Parent = Window
corner(Topbar, 10)

local topbarFix = Instance.new("Frame")
topbarFix.BackgroundColor3 = Theme.Topbar
topbarFix.BorderSizePixel = 0
topbarFix.Position = UDim2.new(0, 0, 1, -10)
topbarFix.Size = UDim2.new(1, 0, 0, 10)
topbarFix.ZIndex = 5
topbarFix.Parent = Topbar

local titleIconHolder = Instance.new("Frame")
titleIconHolder.BackgroundTransparency = 1
titleIconHolder.Position = UDim2.new(0, 12, 0.5, -10)
titleIconHolder.Size = UDim2.fromOffset(20, 20)
titleIconHolder.ZIndex = 6
titleIconHolder.Parent = Topbar
Icons.sparkle(titleIconHolder, 20, Theme.Cyan)

local Title = Instance.new("TextLabel")
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 40, 0, 2)
Title.Size = UDim2.new(0.5, 0, 0, 18)
Title.Font = FONT_BOLD
Title.TextSize = 15
Title.TextColor3 = Theme.Text
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Text = "Galaxy Hub"
Title.ZIndex = 6
Title.Parent = Topbar

local Subtitle = Instance.new("TextLabel")
Subtitle.BackgroundTransparency = 1
Subtitle.Position = UDim2.new(0, 40, 0, 20)
Subtitle.Size = UDim2.new(0.5, 0, 0, 16)
Subtitle.Font = FONT
Subtitle.TextSize = 11
Subtitle.TextColor3 = Theme.SubText
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.Text = "v1.0 · galaxy theme"
Subtitle.ZIndex = 6
Subtitle.Parent = Topbar

-- Launcher-Orb (bleibt sichtbar, wenn das Fenster versteckt ist)
local Launcher = Instance.new("TextButton")
Launcher.Name = "Launcher"
Launcher.AnchorPoint = Vector2.new(0, 0.5)
Launcher.Position = UDim2.new(0, 20, 0.5, 0)
Launcher.Size = UDim2.fromOffset(46, 46)
Launcher.BackgroundColor3 = Theme.Element
Launcher.AutoButtonColor = false
Launcher.Text = ""
Launcher.Visible = false
Launcher.ZIndex = 10
Launcher.Parent = screenGui
corner(Launcher, "circle")
ring(Launcher, Theme.Violet, 1.4)
addHoverScale(Launcher, 1.1)
local launcherIconHolder = Instance.new("Frame")
launcherIconHolder.BackgroundTransparency = 1
launcherIconHolder.AnchorPoint = Vector2.new(0.5, 0.5)
launcherIconHolder.Position = UDim2.fromScale(0.5, 0.5)
launcherIconHolder.Size = UDim2.fromOffset(22, 22)
launcherIconHolder.ZIndex = 11
launcherIconHolder.Parent = Launcher
Icons.sparkle(launcherIconHolder, 22, Theme.Cyan)

local windowVisible = true
local function setWindowVisible(visible, animate)
	windowVisible = visible
	if visible then
		Launcher.Visible = false
		Window.Visible = true
		if animate then
			Window.Size = UDim2.fromOffset(FULL_SIZE.X.Offset - 30, FULL_SIZE.Y.Offset - 30)
			Window.BackgroundTransparency = 1
			tween(Window, { Size = FULL_SIZE, BackgroundTransparency = 0 }, 0.3, Enum.EasingStyle.Back)
		end
	else
		if animate then
			tween(Window, { BackgroundTransparency = 1, Size = UDim2.fromOffset(FULL_SIZE.X.Offset - 30, FULL_SIZE.Y.Offset - 30) }, 0.2)
			task.delay(0.2, function()
				Window.Visible = false
				Launcher.Visible = true
				Launcher.BackgroundTransparency = 1
				tween(Launcher, { BackgroundTransparency = 0 }, 0.2)
			end)
		else
			Window.Visible = false
			Launcher.Visible = true
		end
	end
end

Launcher.MouseButton1Click:Connect(function() setWindowVisible(true, true) end)

-- Eye-Button: Fenster verstecken/zeigen
local hideBtn = Instance.new("TextButton")
hideBtn.AnchorPoint = Vector2.new(1, 0.5)
hideBtn.Position = UDim2.new(1, -78, 0.5, 0)
hideBtn.Size = UDim2.fromOffset(26, 26)
hideBtn.BackgroundTransparency = 1
hideBtn.AutoButtonColor = false
hideBtn.Text = ""
hideBtn.ZIndex = 6
hideBtn.Parent = Topbar
local hideBtnIcon = Icons.eye(hideBtn, 18, Theme.SubText)
hideBtnIcon.AnchorPoint = Vector2.new(0.5, 0.5)
hideBtnIcon.Position = UDim2.fromScale(0.5, 0.5)
hideBtn.MouseEnter:Connect(function()
	for _, d in ipairs(hideBtnIcon:GetDescendants()) do
		if d:IsA("Frame") and d.BackgroundTransparency == 0 then tween(d, { BackgroundColor3 = Theme.Text }, 0.15) end
	end
end)
hideBtn.MouseButton1Click:Connect(function() setWindowVisible(false, true) end)

-- Minimize
local minimized = false
local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.AnchorPoint = Vector2.new(1, 0.5)
MinimizeBtn.Position = UDim2.new(1, -44, 0.5, 0)
MinimizeBtn.Size = UDim2.fromOffset(26, 26)
MinimizeBtn.BackgroundTransparency = 1
MinimizeBtn.AutoButtonColor = false
MinimizeBtn.Font = FONT_BOLD
MinimizeBtn.TextSize = 16
MinimizeBtn.TextColor3 = Theme.SubText
MinimizeBtn.Text = "–"
MinimizeBtn.ZIndex = 6
MinimizeBtn.Parent = Topbar

-- Unload (zerstört die UI komplett, mit Sicherheits-Doppelklick)
local UnloadBtn = Instance.new("TextButton")
UnloadBtn.AnchorPoint = Vector2.new(1, 0.5)
UnloadBtn.Position = UDim2.new(1, -12, 0.5, 0)
UnloadBtn.Size = UDim2.fromOffset(26, 26)
UnloadBtn.BackgroundTransparency = 1
UnloadBtn.AutoButtonColor = false
UnloadBtn.Font = FONT_BOLD
UnloadBtn.TextSize = 14
UnloadBtn.TextColor3 = Theme.SubText
UnloadBtn.Text = "×"
UnloadBtn.ZIndex = 6
UnloadBtn.Parent = Topbar

for _, btn in ipairs({ MinimizeBtn }) do
	btn.MouseEnter:Connect(function() tween(btn, { TextColor3 = Theme.Text }, 0.15) end)
	btn.MouseLeave:Connect(function() tween(btn, { TextColor3 = Theme.SubText }, 0.15) end)
end
UnloadBtn.MouseEnter:Connect(function() tween(UnloadBtn, { TextColor3 = Theme.Bad }, 0.15) end)
UnloadBtn.MouseLeave:Connect(function()
	if UnloadBtn.Text ~= "OK?" then tween(UnloadBtn, { TextColor3 = Theme.SubText }, 0.15) end
end)

local unloadArmed = false
UnloadBtn.MouseButton1Click:Connect(function()
	if not unloadArmed then
		unloadArmed = true
		UnloadBtn.Text = "OK?"
		UnloadBtn.TextColor3 = Theme.Bad
		task.delay(2.5, function()
			if unloadArmed then
				unloadArmed = false
				UnloadBtn.Text = "×"
				UnloadBtn.TextColor3 = Theme.SubText
			end
		end)
	else
		tween(Window, { BackgroundTransparency = 1, Size = UDim2.fromOffset(Window.AbsoluteSize.X - 60, Window.AbsoluteSize.Y - 60) }, 0.25)
		task.delay(0.25, function() screenGui:Destroy() end)
	end
end)

makeDraggable(Topbar, Window)

-- Sidebar
local Sidebar = Instance.new("Frame")
Sidebar.BackgroundColor3 = Theme.Sidebar
Sidebar.Position = UDim2.new(0, 0, 0, 44)
Sidebar.Size = UDim2.new(0, 150, 1, -44)
Sidebar.ZIndex = 4
Sidebar.Parent = Window

local TabList = Instance.new("Frame")
TabList.BackgroundTransparency = 1
TabList.Position = UDim2.new(0, 8, 0, 10)
TabList.Size = UDim2.new(1, -16, 1, -20)
TabList.ZIndex = 4
TabList.Parent = Sidebar

local TabListLayout = Instance.new("UIListLayout")
TabListLayout.Padding = UDim.new(0, 4)
TabListLayout.Parent = TabList

-- Content
local ContentHolder = Instance.new("Frame")
ContentHolder.BackgroundTransparency = 1
ContentHolder.Position = UDim2.new(0, 150, 0, 44)
ContentHolder.Size = UDim2.new(1, -150, 1, -44)
ContentHolder.ZIndex = 4
ContentHolder.Parent = Window

-- ============ Top-Right Overlay: Profil / FPS / Ping ============

local overlayExpanded = true

local Overlay = Instance.new("Frame")
Overlay.Name = "StatsOverlay"
Overlay.AnchorPoint = Vector2.new(1, 0)
Overlay.Position = UDim2.new(1, -16, 0, 16)
Overlay.Size = UDim2.fromOffset(230, 52)
Overlay.BackgroundColor3 = Theme.Section
Overlay.ClipsDescendants = true
Overlay.ZIndex = 8
Overlay.Parent = screenGui
corner(Overlay, "circle")
faintStroke(Overlay, 0.75)

local avatarImg = Instance.new("ImageLabel")
avatarImg.AnchorPoint = Vector2.new(0, 0.5)
avatarImg.Position = UDim2.new(0, 6, 0.5, 0)
avatarImg.Size = UDim2.fromOffset(40, 40)
avatarImg.BackgroundColor3 = Theme.Element
avatarImg.ZIndex = 9
avatarImg.Parent = Overlay
corner(avatarImg, "circle")
ring(avatarImg, Theme.Violet, 1.2)

task.spawn(function()
	local ok, content = pcall(function()
		return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
	end)
	if ok then avatarImg.Image = content end
end)

local nameLabel = Instance.new("TextLabel")
nameLabel.BackgroundTransparency = 1
nameLabel.Position = UDim2.new(0, 54, 0, 6)
nameLabel.Size = UDim2.fromOffset(90, 16)
nameLabel.Font = FONT_BOLD
nameLabel.TextSize = 12
nameLabel.TextColor3 = Theme.Text
nameLabel.TextXAlignment = Enum.TextXAlignment.Left
nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
nameLabel.Text = player.DisplayName
nameLabel.ZIndex = 9
nameLabel.Parent = Overlay

local placeLabel = Instance.new("TextLabel")
placeLabel.BackgroundTransparency = 1
placeLabel.Position = UDim2.new(0, 54, 0, 22)
placeLabel.Size = UDim2.fromOffset(90, 14)
placeLabel.Font = FONT
placeLabel.TextSize = 10
placeLabel.TextColor3 = Theme.SubText
placeLabel.TextXAlignment = Enum.TextXAlignment.Left
placeLabel.TextTruncate = Enum.TextTruncate.AtEnd
placeLabel.Text = ("%d Spieler online"):format(#Players:GetPlayers())
placeLabel.ZIndex = 9
placeLabel.Parent = Overlay

-- FPS
local fpsHolder = Instance.new("Frame")
fpsHolder.BackgroundTransparency = 1
fpsHolder.Position = UDim2.new(0, 150, 0, 6)
fpsHolder.Size = UDim2.fromOffset(36, 16)
fpsHolder.ZIndex = 9
fpsHolder.Parent = Overlay
Icons.bars(fpsHolder, 12, Theme.Cyan)
local fpsValue = Instance.new("TextLabel")
fpsValue.BackgroundTransparency = 1
fpsValue.Position = UDim2.new(0, 16, 0, -1)
fpsValue.Size = UDim2.fromOffset(30, 16)
fpsValue.Font = FONT_BOLD
fpsValue.TextSize = 12
fpsValue.TextColor3 = Theme.Text
fpsValue.TextXAlignment = Enum.TextXAlignment.Left
fpsValue.Text = "0"
fpsValue.Parent = fpsHolder

local fpsCaption = Instance.new("TextLabel")
fpsCaption.BackgroundTransparency = 1
fpsCaption.Position = UDim2.new(0, 150, 0, 22)
fpsCaption.Size = UDim2.fromOffset(46, 14)
fpsCaption.Font = FONT
fpsCaption.TextSize = 10
fpsCaption.TextColor3 = Theme.SubText
fpsCaption.TextXAlignment = Enum.TextXAlignment.Left
fpsCaption.Text = "FPS"
fpsCaption.ZIndex = 9
fpsCaption.Parent = Overlay

-- Ping
local pingDot = Instance.new("Frame")
pingDot.AnchorPoint = Vector2.new(0, 0.5)
pingDot.Position = UDim2.new(0, 190, 0, 12)
pingDot.Size = UDim2.fromOffset(8, 8)
pingDot.BackgroundColor3 = Theme.Good
pingDot.ZIndex = 9
pingDot.Parent = Overlay
corner(pingDot, "circle")

local pingValue = Instance.new("TextLabel")
pingValue.BackgroundTransparency = 1
pingValue.Position = UDim2.new(0, 150, 0, 22)
pingValue.Size = UDim2.fromOffset(70, 14)
pingValue.Font = FONT
pingValue.TextSize = 10
pingValue.TextColor3 = Theme.SubText
pingValue.TextXAlignment = Enum.TextXAlignment.Left
pingValue.Text = "-- ms"
pingValue.ZIndex = 9
pingValue.Parent = Overlay

local function updatePing()
	local ok, ping = pcall(function()
		return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()
	end)
	if ok then
		pingValue.Text = ("%d ms"):format(math.floor(ping))
		local c = ping < 100 and Theme.Good or (ping < 200 and Theme.Warn or Theme.Bad)
		tween(pingDot, { BackgroundColor3 = c }, 0.3)
	end
end

task.spawn(function()
	while Overlay.Parent do
		updatePing()
		placeLabel.Text = ("%d Spieler online"):format(#Players:GetPlayers())
		task.wait(1)
	end
end)

do
	local frames, elapsed = 0, 0
	RunService.RenderStepped:Connect(function(dt)
		frames += 1
		elapsed += dt
		if elapsed >= 1 then
			fpsValue.Text = tostring(frames)
			frames, elapsed = 0, 0
		end
	end)
end

-- Overlay ein-/ausklappen (eigener Eye-Button)
local overlayEyeBtn = Instance.new("TextButton")
overlayEyeBtn.AnchorPoint = Vector2.new(1, 0.5)
overlayEyeBtn.Position = UDim2.new(1, -8, 0.5, 0)
overlayEyeBtn.Size = UDim2.fromOffset(22, 22)
overlayEyeBtn.BackgroundTransparency = 1
overlayEyeBtn.AutoButtonColor = false
overlayEyeBtn.Text = ""
overlayEyeBtn.ZIndex = 10
overlayEyeBtn.Parent = Overlay
local overlayEyeIcon = Icons.eye(overlayEyeBtn, 16, Theme.SubText)
overlayEyeIcon.AnchorPoint = Vector2.new(0.5, 0.5)
overlayEyeIcon.Position = UDim2.fromScale(0.5, 0.5)

local overlayPill = Instance.new("TextButton")
overlayPill.AnchorPoint = Vector2.new(1, 0)
overlayPill.Position = UDim2.new(1, -16, 0, 16)
overlayPill.Size = UDim2.fromOffset(40, 40)
overlayPill.BackgroundColor3 = Theme.Section
overlayPill.AutoButtonColor = false
overlayPill.Text = ""
overlayPill.Visible = false
overlayPill.ZIndex = 8
overlayPill.Parent = screenGui
corner(overlayPill, "circle")
faintStroke(overlayPill, 0.75)
local overlayPillIcon = Icons.eye(overlayPill, 18, Theme.SubText)
overlayPillIcon.AnchorPoint = Vector2.new(0.5, 0.5)
overlayPillIcon.Position = UDim2.fromScale(0.5, 0.5)
setEyeState(overlayPillIcon, false)

local function setOverlayExpanded(expanded)
	overlayExpanded = expanded
	if expanded then
		overlayPill.Visible = false
		Overlay.Visible = true
		tween(Overlay, { Size = UDim2.fromOffset(230, 52) }, 0.25, Enum.EasingStyle.Back)
	else
		tween(Overlay, { Size = UDim2.fromOffset(52, 52) }, 0.2)
		task.delay(0.2, function()
			Overlay.Visible = false
			overlayPill.Visible = true
		end)
	end
end

overlayEyeBtn.MouseButton1Click:Connect(function() setOverlayExpanded(false) end)
overlayPill.MouseButton1Click:Connect(function() setOverlayExpanded(true) end)
addHoverScale(overlayPill, 1.1)

-- ============ Tabs / Sections / Elements ============

local tabs = {}
local firstTab = true

local function CreateTab(name, iconFn)
	local tabBtn = Instance.new("TextButton")
	tabBtn.BackgroundTransparency = 1
	tabBtn.Size = UDim2.new(1, 0, 0, 34)
	tabBtn.AutoButtonColor = false
	tabBtn.Text = ""
	tabBtn.Parent = TabList
	corner(tabBtn, 8)

	local iconHolder = Instance.new("Frame")
	iconHolder.BackgroundTransparency = 1
	iconHolder.Position = UDim2.new(0, 10, 0.5, -9)
	iconHolder.Size = UDim2.fromOffset(18, 18)
	iconHolder.Parent = tabBtn
	local iconColor = firstTab and Theme.Text or Theme.SubText
	local iconInst = iconFn(iconHolder, 18, iconColor)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 36, 0, 0)
	label.Size = UDim2.new(1, -40, 1, 0)
	label.Font = FONT
	label.TextSize = 13
	label.TextColor3 = iconColor
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = name
	label.Parent = tabBtn

	local page = Instance.new("ScrollingFrame")
	page.BackgroundTransparency = 1
	page.Size = UDim2.fromScale(1, 1)
	page.CanvasSize = UDim2.new(0, 0, 0, 0)
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.ScrollBarThickness = 3
	page.ScrollBarImageColor3 = Theme.Violet
	page.Visible = firstTab
	page.Parent = ContentHolder

	local pagePad = Instance.new("UIPadding")
	pagePad.PaddingTop = UDim.new(0, 12)
	pagePad.PaddingLeft = UDim.new(0, 12)
	pagePad.PaddingRight = UDim.new(0, 12)
	pagePad.Parent = page

	local pageLayout = Instance.new("UIListLayout")
	pageLayout.Padding = UDim.new(0, 10)
	pageLayout.Parent = page

	if firstTab then
		tabBtn.BackgroundColor3 = Theme.Element
		tabBtn.BackgroundTransparency = 0
		firstTab = false
	end

	local function setChildColors(color)
		label.TextColor3 = color
		local function tint(inst)
			for _, d in ipairs(inst:GetDescendants()) do
				if d:IsA("Frame") and d.BackgroundTransparency == 0 and not d:FindFirstChildOfClass("UIStroke") then
					tween(d, { BackgroundColor3 = color }, 0.15)
				end
			end
		end
		tint(iconHolder)
	end

	tabBtn.MouseButton1Click:Connect(function()
		if page.Visible then return end
		for _, t in ipairs(tabs) do
			tween(t.btn, { BackgroundTransparency = 1 }, 0.15)
			t.setColor(Theme.SubText)
			t.page.Visible = false
		end
		tabBtn.BackgroundColor3 = Theme.Element
		tween(tabBtn, { BackgroundTransparency = 0 }, 0.15)
		setChildColors(Theme.Text)
		page.Visible = true

		for _, child in ipairs(page:GetChildren()) do
			if child:IsA("GuiObject") then
				local originalPos = child.Position
				child.Position = originalPos + UDim2.fromOffset(0, 6)
				tween(child, { Position = originalPos }, 0.25)
			end
		end
	end)

	tabBtn.MouseEnter:Connect(function()
		if page.Visible then return end
		tween(tabBtn, { BackgroundTransparency = 0.85, BackgroundColor3 = Theme.Element }, 0.15)
	end)
	tabBtn.MouseLeave:Connect(function()
		if page.Visible then return end
		tween(tabBtn, { BackgroundTransparency = 1 }, 0.15)
	end)

	table.insert(tabs, { btn = tabBtn, page = page, setColor = setChildColors })

	local TabObject = {}

	function TabObject:CreateSection(sectionName, infoText)
		local section = Instance.new("Frame")
		section.BackgroundColor3 = Theme.Section
		section.Size = UDim2.new(1, -6, 0, 0)
		section.AutomaticSize = Enum.AutomaticSize.Y
		section.Parent = page
		corner(section, 8)
		faintStroke(section, 0.85)

		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 10)
		pad.PaddingBottom = UDim.new(0, 10)
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 10)
		pad.Parent = section

		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 8)
		layout.Parent = section

		local header = Instance.new("TextLabel")
		header.BackgroundTransparency = 1
		header.Size = UDim2.new(1, 0, 0, 16)
		header.Font = FONT_BOLD
		header.TextSize = 13
		header.TextColor3 = Theme.Text
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.Text = sectionName
		header.LayoutOrder = 0
		header.Parent = section

		local order = 1
		if infoText then
			order += 1
			local info = Instance.new("TextLabel")
			info.LayoutOrder = order
			info.BackgroundTransparency = 1
			info.Size = UDim2.new(1, 0, 0, 14)
			info.Font = FONT
			info.TextSize = 11
			info.TextColor3 = Theme.SubText
			info.TextXAlignment = Enum.TextXAlignment.Left
			info.TextWrapped = true
			info.Text = infoText
			info.Parent = section
		end

		local SectionObject = {}

		function SectionObject:CreateButton(text, callback)
			order += 1
			local btn = Instance.new("TextButton")
			btn.LayoutOrder = order
			btn.Size = UDim2.new(1, 0, 0, 32)
			btn.BackgroundColor3 = Theme.Element
			btn.AutoButtonColor = false
			btn.Font = FONT
			btn.TextSize = 13
			btn.TextColor3 = Theme.Text
			btn.Text = text
			btn.Parent = section
			corner(btn, 6)
			addHoverScale(btn, 1.02)

			btn.MouseEnter:Connect(function() tween(btn, { BackgroundColor3 = Theme.ElementHover }, 0.15) end)
			btn.MouseLeave:Connect(function() tween(btn, { BackgroundColor3 = Theme.Element }, 0.15) end)
			btn.MouseButton1Click:Connect(function()
				tween(btn, { BackgroundColor3 = Theme.Violet }, 0.08)
				task.delay(0.08, function() tween(btn, { BackgroundColor3 = Theme.ElementHover }, 0.15) end)
				if callback then callback() end
			end)
			return btn
		end

		function SectionObject:CreateToggle(text, default, callback)
			order += 1
			local state = default or false

			local holder = Instance.new("Frame")
			holder.LayoutOrder = order
			holder.BackgroundColor3 = Theme.Element
			holder.Size = UDim2.new(1, 0, 0, 32)
			holder.Parent = section
			corner(holder, 6)

			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Position = UDim2.new(0, 10, 0, 0)
			label.Size = UDim2.new(1, -60, 1, 0)
			label.Font = FONT
			label.TextSize = 13
			label.TextColor3 = Theme.Text
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Text = text
			label.Parent = holder

			local track = Instance.new("Frame")
			track.AnchorPoint = Vector2.new(1, 0.5)
			track.Position = UDim2.new(1, -10, 0.5, 0)
			track.Size = UDim2.fromOffset(36, 20)
			track.BackgroundColor3 = state and Theme.Violet or Color3.fromRGB(55, 50, 80)
			track.Parent = holder
			corner(track, "circle")

			local knob = Instance.new("Frame")
			knob.Size = UDim2.fromOffset(16, 16)
			knob.Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
			knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			knob.Parent = track
			corner(knob, "circle")

			local click = Instance.new("TextButton")
			click.BackgroundTransparency = 1
			click.Size = UDim2.fromScale(1, 1)
			click.Text = ""
			click.Parent = holder

			click.MouseButton1Click:Connect(function()
				state = not state
				tween(track, { BackgroundColor3 = state and Theme.Violet or Color3.fromRGB(55, 50, 80) }, 0.15)
				tween(knob, { Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8) }, 0.15)
				if callback then callback(state) end
			end)
			return holder
		end

		function SectionObject:CreateSlider(text, min, max, default, callback)
			order += 1
			local value = default or min

			local holder = Instance.new("Frame")
			holder.LayoutOrder = order
			holder.BackgroundColor3 = Theme.Element
			holder.Size = UDim2.new(1, 0, 0, 46)
			holder.Parent = section
			corner(holder, 6)

			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Position = UDim2.new(0, 10, 0, 4)
			label.Size = UDim2.new(1, -60, 0, 16)
			label.Font = FONT
			label.TextSize = 13
			label.TextColor3 = Theme.Text
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Text = text
			label.Parent = holder

			local valueLabel = Instance.new("TextLabel")
			valueLabel.BackgroundTransparency = 1
			valueLabel.AnchorPoint = Vector2.new(1, 0)
			valueLabel.Position = UDim2.new(1, -10, 0, 4)
			valueLabel.Size = UDim2.fromOffset(40, 16)
			valueLabel.Font = FONT
			valueLabel.TextSize = 13
			valueLabel.TextColor3 = Theme.SubText
			valueLabel.TextXAlignment = Enum.TextXAlignment.Right
			valueLabel.Text = tostring(value)
			valueLabel.Parent = holder

			local track = Instance.new("Frame")
			track.Position = UDim2.new(0, 10, 1, -14)
			track.Size = UDim2.new(1, -20, 0, 6)
			track.BackgroundColor3 = Color3.fromRGB(55, 50, 80)
			track.Parent = holder
			corner(track, 3)

			local fill = Instance.new("Frame")
			fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
			fill.BackgroundColor3 = Theme.Violet
			fill.Parent = track
			corner(fill, 3)

			local dragging = false
			local function updateFromX(xPos)
				local pct = math.clamp((xPos - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
				value = math.floor(min + (max - min) * pct + 0.5)
				fill.Size = UDim2.new(pct, 0, 1, 0)
				valueLabel.Text = tostring(value)
				if callback then callback(value) end
			end

			track.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = true
					updateFromX(input.Position.X)
				end
			end)
			UserInputService.InputChanged:Connect(function(input)
				if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
					updateFromX(input.Position.X)
				end
			end)
			UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = false
				end
			end)
			return holder
		end

		function SectionObject:CreateDropdown(text, options, default, callback)
			order += 1
			local selected = default or options[1]
			local open = false

			local holder = Instance.new("Frame")
			holder.LayoutOrder = order
			holder.BackgroundColor3 = Theme.Element
			holder.Size = UDim2.new(1, 0, 0, 32)
			holder.ClipsDescendants = true
			holder.ZIndex = 2
			holder.Parent = section
			corner(holder, 6)

			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Position = UDim2.new(0, 10, 0, 0)
			label.Size = UDim2.new(0.5, 0, 0, 32)
			label.Font = FONT
			label.TextSize = 13
			label.TextColor3 = Theme.Text
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Text = text
			label.Parent = holder

			local selectedLabel = Instance.new("TextLabel")
			selectedLabel.BackgroundTransparency = 1
			selectedLabel.AnchorPoint = Vector2.new(1, 0)
			selectedLabel.Position = UDim2.new(1, -28, 0, 0)
			selectedLabel.Size = UDim2.new(0.4, 0, 0, 32)
			selectedLabel.Font = FONT
			selectedLabel.TextSize = 13
			selectedLabel.TextColor3 = Theme.SubText
			selectedLabel.TextXAlignment = Enum.TextXAlignment.Right
			selectedLabel.Text = selected
			selectedLabel.Parent = holder

			local chevron = Instance.new("TextLabel")
			chevron.BackgroundTransparency = 1
			chevron.AnchorPoint = Vector2.new(1, 0)
			chevron.Position = UDim2.new(1, -8, 0, 0)
			chevron.Size = UDim2.fromOffset(16, 32)
			chevron.Font = FONT_BOLD
			chevron.TextSize = 12
			chevron.TextColor3 = Theme.SubText
			chevron.Text = "v"
			chevron.Parent = holder

			local optionList = Instance.new("Frame")
			optionList.Position = UDim2.new(0, 0, 0, 34)
			optionList.Size = UDim2.new(1, 0, 0, #options * 26)
			optionList.BackgroundTransparency = 1
			optionList.Parent = holder

			local optListLayout = Instance.new("UIListLayout")
			optListLayout.Parent = optionList

			for _, opt in ipairs(options) do
				local optBtn = Instance.new("TextButton")
				optBtn.Size = UDim2.new(1, 0, 0, 26)
				optBtn.BackgroundTransparency = 1
				optBtn.AutoButtonColor = false
				optBtn.Font = FONT
				optBtn.TextSize = 12
				optBtn.TextColor3 = Theme.SubText
				optBtn.Text = opt
				optBtn.Parent = optionList

				optBtn.MouseEnter:Connect(function() tween(optBtn, { TextColor3 = Theme.Text }, 0.1) end)
				optBtn.MouseLeave:Connect(function() tween(optBtn, { TextColor3 = Theme.SubText }, 0.1) end)
				optBtn.MouseButton1Click:Connect(function()
					selected = opt
					selectedLabel.Text = opt
					open = false
					tween(holder, { Size = UDim2.new(1, 0, 0, 32) }, 0.2)
					tween(chevron, { Rotation = 0 }, 0.2)
					if callback then callback(opt) end
				end)
			end

			local clickArea = Instance.new("TextButton")
			clickArea.BackgroundTransparency = 1
			clickArea.Size = UDim2.new(1, 0, 0, 32)
			clickArea.Text = ""
			clickArea.ZIndex = 3
			clickArea.Parent = holder

			clickArea.MouseButton1Click:Connect(function()
				open = not open
				local targetSize = open and UDim2.new(1, 0, 0, 34 + #options * 26) or UDim2.new(1, 0, 0, 32)
				tween(holder, { Size = targetSize }, 0.2)
				tween(chevron, { Rotation = open and 180 or 0 }, 0.2)
			end)
			return holder
		end

		function SectionObject:CreateProgressBar(text, percent, note)
			order += 1
			local holder = Instance.new("Frame")
			holder.LayoutOrder = order
			holder.BackgroundTransparency = 1
			holder.Size = UDim2.new(1, 0, 0, 40)
			holder.Parent = section

			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.new(1, 0, 0, 16)
			label.Font = FONT
			label.TextSize = 12
			label.TextColor3 = Theme.Text
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Text = text .. (note and ("  ·  " .. note) or "")
			label.Parent = holder

			local track = Instance.new("Frame")
			track.Position = UDim2.new(0, 0, 0, 22)
			track.Size = UDim2.new(1, 0, 0, 8)
			track.BackgroundColor3 = Color3.fromRGB(45, 40, 70)
			track.ClipsDescendants = true
			track.Parent = holder
			corner(track, 4)

			local fill = Instance.new("Frame")
			fill.Size = UDim2.new(percent / 100, 0, 1, 0)
			fill.BackgroundColor3 = Theme.Violet
			fill.Parent = track
			corner(fill, 4)

			local fillGradient = Instance.new("UIGradient")
			fillGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Theme.Violet),
				ColorSequenceKeypoint.new(1, Theme.Cyan),
			})
			fillGradient.Parent = fill

			local shimmer = Instance.new("Frame")
			shimmer.Size = UDim2.new(0.25, 0, 1, 0)
			shimmer.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			shimmer.BackgroundTransparency = 0.75
			shimmer.Position = UDim2.new(-0.3, 0, 0, 0)
			shimmer.Parent = fill

			local shimmerTween = TweenService:Create(shimmer, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false), { Position = UDim2.new(1.1, 0, 0, 0) })
			shimmerTween:Play()

			return holder
		end

		function SectionObject:CreateLabel(text)
			order += 1
			local label = Instance.new("TextLabel")
			label.LayoutOrder = order
			label.BackgroundTransparency = 1
			label.Size = UDim2.new(1, 0, 0, 16)
			label.Font = FONT
			label.TextSize = 12
			label.TextColor3 = Theme.SubText
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextWrapped = true
			label.Text = text
			label.Parent = section
			return label
		end

		return SectionObject
	end

	return TabObject
end

-- ============ Notifications (unten rechts) ============

local NotifyHolder = Instance.new("Frame")
NotifyHolder.AnchorPoint = Vector2.new(1, 1)
NotifyHolder.Position = UDim2.new(1, -20, 1, -20)
NotifyHolder.Size = UDim2.fromOffset(280, 400)
NotifyHolder.BackgroundTransparency = 1
NotifyHolder.Parent = screenGui

local NotifyLayout = Instance.new("UIListLayout")
NotifyLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
NotifyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
NotifyLayout.Padding = UDim.new(0, 8)
NotifyLayout.Parent = NotifyHolder

local function Notify(titleText, contentText, duration)
	duration = duration or 3.5
	local notif = Instance.new("Frame")
	notif.BackgroundColor3 = Theme.Section
	notif.Size = UDim2.new(1, 0, 0, 64)
	notif.ClipsDescendants = true
	notif.Parent = NotifyHolder
	corner(notif, 8)
	faintStroke(notif, 0.75)
	notif.Position = UDim2.fromOffset(300, 0)

	local nTitle = Instance.new("TextLabel")
	nTitle.BackgroundTransparency = 1
	nTitle.Position = UDim2.new(0, 12, 0, 8)
	nTitle.Size = UDim2.new(1, -24, 0, 18)
	nTitle.Font = FONT_BOLD
	nTitle.TextSize = 14
	nTitle.TextColor3 = Theme.Text
	nTitle.TextXAlignment = Enum.TextXAlignment.Left
	nTitle.Text = titleText
	nTitle.Parent = notif

	local nContent = Instance.new("TextLabel")
	nContent.BackgroundTransparency = 1
	nContent.Position = UDim2.new(0, 12, 0, 28)
	nContent.Size = UDim2.new(1, -24, 0, 24)
	nContent.Font = FONT
	nContent.TextSize = 12
	nContent.TextColor3 = Theme.SubText
	nContent.TextXAlignment = Enum.TextXAlignment.Left
	nContent.TextWrapped = true
	nContent.Text = contentText
	nContent.Parent = notif

	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.new(0, 0, 1, 0)
	bar.Size = UDim2.new(1, 0, 0, 3)
	bar.BackgroundColor3 = Theme.Violet
	bar.BorderSizePixel = 0
	bar.Parent = notif

	tween(notif, { Position = UDim2.fromOffset(0, 0) }, 0.35, Enum.EasingStyle.Back)
	tween(bar, { Size = UDim2.new(0, 0, 0, 3) }, duration, Enum.EasingStyle.Linear)

	task.delay(duration, function()
		tween(notif, { Position = UDim2.fromOffset(300, 0) }, 0.3, Enum.EasingStyle.Quint)
		task.delay(0.3, function() notif:Destroy() end)
	end)
end

-- ============ Demo-Inhalt ============

local homeTab = CreateTab("Home", Icons.house)
local welcomeSection = homeTab:CreateSection("Willkommen, " .. player.DisplayName, "Kleine Info-Übersicht für diese Session.")
welcomeSection:CreateLabel(("Server-Zeit: %s"):format(os.date("%H:%M:%S")))
welcomeSection:CreateLabel(("Place-ID: %d"):format(game.PlaceId))
welcomeSection:CreateButton("Sag Hallo", function()
	Notify("Hallo!", player.DisplayName .. ", schön dich zu sehen.", 3)
end)

local quickSection = homeTab:CreateSection("Schnellzugriff")
quickSection:CreateToggle("Auto-Farm", false, function(state)
	Notify("Auto-Farm", state and "Aktiviert" or "Deaktiviert", 2.5)
end)
quickSection:CreateSlider("Geschwindigkeit", 0, 100, 50, nil)

local presetsTab = CreateTab("Presets", Icons.sparkle)
local presetSection = presetsTab:CreateSection("Gespeicherte Presets", "Wähle eine Konfiguration, um sie sofort zu laden.")
for _, presetName in ipairs({ "Speedrun", "Farming", "PvP" }) do
	presetSection:CreateButton("Preset laden: " .. presetName, function()
		Notify("Preset geladen", presetName .. " wurde angewendet.", 2.5)
	end)
end

local statsTab = CreateTab("Stats", Icons.bars)
local progressSection = statsTab:CreateSection("Fortschritt")
progressSection:CreateProgressBar("Level-XP", 68, "1 360 / 2 000")
progressSection:CreateProgressBar("Energie", 42)
progressSection:CreateProgressBar("Ruf bei Fraktion", 90, "Fast maximal")

local settingsTab = CreateTab("Settings", function(p, s, c) return Icons.gear(p, s, c, true) end)
local uiSection = settingsTab:CreateSection("Oberfläche")
uiSection:CreateToggle("UI-Sounds", true, nil)
uiSection:CreateDropdown("Akzentfarbe", { "Violett", "Magenta", "Cyan" }, "Violett", nil)
uiSection:CreateLabel("Tipp: RightShift oder der Launcher-Orb blenden das Fenster ein/aus.")

local dangerSection = settingsTab:CreateSection("Danger Zone", "Diese Aktion kann nicht rückgängig gemacht werden.")
dangerSection:CreateButton("Komplett unloaden", function()
	tween(Window, { BackgroundTransparency = 1 }, 0.25)
	task.delay(0.25, function() screenGui:Destroy() end)
end)

-- ============ Keybind + Öffnungsanimation ============

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		setWindowVisible(not windowVisible, true)
	end
end)

Window.BackgroundTransparency = 1
Window.Size = UDim2.fromOffset(FULL_SIZE.X.Offset - 40, FULL_SIZE.Y.Offset - 40)
tween(Window, { BackgroundTransparency = 0, Size = FULL_SIZE }, 0.4, Enum.EasingStyle.Back)

Overlay.Position = Overlay.Position - UDim2.fromOffset(0, -20)
Overlay.BackgroundTransparency = 1
tween(Overlay, { Position = UDim2.new(1, -16, 0, 16), BackgroundTransparency = 0 }, 0.4, Enum.EasingStyle.Back)
