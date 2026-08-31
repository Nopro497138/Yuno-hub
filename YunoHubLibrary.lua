--[[
	YunoHubLibrary.lua  (ModuleScript)

	Wiederverwendbare UI-Library im Galaxy-Style, konzeptionell wie Rayfield aufgebaut:
	Library.CreateLoader(...)  -> Instanz-Auswahlbildschirm (zeigt mehrere Hubs zur Auswahl)
	Library.CreateWindow(...)  -> das eigentliche Hub-Fenster
	Window:CreateTab(name, icon) -> Tab
	Tab:CreateSection(name, info) -> Section
	Section:CreateButton / :CreateToggle / :CreateSlider / :CreateDropdown / :CreateProgressBar / :CreateLabel
	Window:Notify(title, content, duration)
	Window:SetVisible(bool) / Window:Unload()

	Icons: Library.IconAssets[name] = "rbxassetid://..." — trag hier deine eigenen, hochgeladenen
	Asset-IDs ein (siehe /icons Ordner + README). Solange ein Eintrag leer ist, zeigt die Library
	einen sauberen Monogramm-Platzhalter (Kreis + Anfangsbuchstabe) statt eines kaputten Bildes.
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local StatsService = game:GetService("Stats")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Library = {}

Library.Theme = {
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

local Theme = Library.Theme
local FONT = Enum.Font.Gotham
local FONT_BOLD = Enum.Font.GothamSemibold

-- Trag hier nach dem Upload deiner Icons (siehe /icons, GitHub-Link, Studio-Asset-Upload) die
-- jeweilige rbxassetid ein, z.B. home = "rbxassetid://123456789".
Library.IconAssets = {
	home = "", settings = "", sparkles = "", ["bar-chart"] = "", eye = "", power = "",
	skull = "", crosshair = "", shield = "", sword = "", zap = "", gift = "", trophy = "",
	bell = "", lock = "", flame = "", gem = "", package = "", user = "", rocket = "",
}

-- ============ Generische Helfer ============

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = (radius == "circle") and UDim.new(1, 0) or UDim.new(0, radius or 6)
	c.Parent = parent
	return c
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

-- Hover-Grow + Press-Squeeze, für ein spürbares, "richtiges" Klickgefühl
local function addPressFeel(button, upScale)
	upScale = upScale or 1.04
	local scale = Instance.new("UIScale")
	scale.Parent = button
	button.MouseEnter:Connect(function() tween(scale, { Scale = upScale }, 0.15) end)
	button.MouseLeave:Connect(function() tween(scale, { Scale = 1 }, 0.15) end)
	button.MouseButton1Down:Connect(function() tween(scale, { Scale = 0.94 }, 0.08, Enum.EasingStyle.Sine) end)
	button.MouseButton1Up:Connect(function() tween(scale, { Scale = upScale }, 0.2, Enum.EasingStyle.Back) end)
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

-- ============ Icon-System ============
-- Nutzt eine hochgeladene rbxassetid falls vorhanden, sonst ein sauberes Monogramm.

function Library.GetIcon(parent, size, color, name, spin)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(size, size)
	holder.Parent = parent

	local assetId = Library.IconAssets[name]
	if assetId and assetId ~= "" then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = assetId
		img.ImageColor3 = color
		img.Parent = holder
	else
		local ringFrame = Instance.new("Frame")
		ringFrame.BackgroundTransparency = 1
		ringFrame.Size = UDim2.fromScale(1, 1)
		ringFrame.Parent = holder
		corner(ringFrame, "circle")
		local s = Instance.new("UIStroke")
		s.Color = color
		s.Thickness = math.max(1, size * 0.08)
		s.Transparency = 0.15
		s.Parent = ringFrame

		local letter = Instance.new("TextLabel")
		letter.BackgroundTransparency = 1
		letter.Size = UDim2.fromScale(1, 1)
		letter.Font = FONT_BOLD
		letter.TextScaled = true
		letter.TextColor3 = color
		letter.Text = (name or "?"):sub(1, 1):upper()
		letter.Parent = ringFrame
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, size * 0.22)
		pad.PaddingBottom = UDim.new(0, size * 0.22)
		pad.Parent = letter
	end

	if spin then
		RunService.Heartbeat:Connect(function(dt)
			if holder.Parent then
				holder.Rotation = (holder.Rotation + dt * 14) % 360
			end
		end)
	end

	return holder
end

-- ============ Galaxy-Hintergrund (Sterne + Nebel-Glow), gemeinsam für Loader & Window ============

local function buildGalaxyBackdrop(screenGui)
	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.BackgroundTransparency = 1
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.ZIndex = 1
	backdrop.Parent = screenGui

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

	return backdrop
end

-- ============ Notifications ============

local function attachNotify(screenGui)
	local NotifyHolder = Instance.new("Frame")
	NotifyHolder.AnchorPoint = Vector2.new(1, 1)
	NotifyHolder.Position = UDim2.new(1, -20, 1, -20)
	NotifyHolder.Size = UDim2.fromOffset(280, 400)
	NotifyHolder.BackgroundTransparency = 1
	NotifyHolder.Parent = screenGui

	local NotifyLayout = Instance.new("UIListLayout")
	NotifyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	NotifyLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	NotifyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	NotifyLayout.Padding = UDim.new(0, 8)
	NotifyLayout.Parent = NotifyHolder

	return function(titleText, contentText, duration)
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
end

-- ============ CreateWindow ============

function Library.CreateWindow(opts)
	opts = opts or {}
	local windowTitle = opts.Title or "Yuno Hub"
	local windowSubtitle = opts.Subtitle or "v1.0 · galaxy theme"

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "YunoHubWindow"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	buildGalaxyBackdrop(screenGui)
	local Notify = attachNotify(screenGui)

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
	local windowStroke = Instance.new("UIStroke")
	windowStroke.Thickness = 1.4
	windowStroke.Color = Theme.Violet
	windowStroke.Parent = Window

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
	Library.GetIcon(titleIconHolder, 20, Theme.Cyan, "sparkles")

	local Title = Instance.new("TextLabel")
	Title.BackgroundTransparency = 1
	Title.Position = UDim2.new(0, 40, 0, 2)
	Title.Size = UDim2.new(0.5, 0, 0, 18)
	Title.Font = FONT_BOLD
	Title.TextSize = 15
	Title.TextColor3 = Theme.Text
	Title.TextXAlignment = Enum.TextXAlignment.Left
	Title.Text = windowTitle
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
	Subtitle.Text = windowSubtitle
	Subtitle.ZIndex = 6
	Subtitle.Parent = Topbar

	-- Launcher-Orb (sichtbar, wenn Fenster versteckt ist)
	local Launcher = Instance.new("TextButton")
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
	faintStroke(Launcher, 0.4)
	addPressFeel(Launcher, 1.1)
	local launcherIconHolder = Instance.new("Frame")
	launcherIconHolder.BackgroundTransparency = 1
	launcherIconHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	launcherIconHolder.Position = UDim2.fromScale(0.5, 0.5)
	launcherIconHolder.Size = UDim2.fromOffset(22, 22)
	launcherIconHolder.ZIndex = 11
	launcherIconHolder.Parent = Launcher
	Library.GetIcon(launcherIconHolder, 22, Theme.Cyan, "sparkles")

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

	local hideBtn = Instance.new("TextButton")
	hideBtn.AnchorPoint = Vector2.new(1, 0.5)
	hideBtn.Position = UDim2.new(1, -78, 0.5, 0)
	hideBtn.Size = UDim2.fromOffset(26, 26)
	hideBtn.BackgroundTransparency = 1
	hideBtn.AutoButtonColor = false
	hideBtn.Text = ""
	hideBtn.ZIndex = 6
	hideBtn.Parent = Topbar
	addPressFeel(hideBtn, 1.15)
	local hideBtnIconHolder = Instance.new("Frame")
	hideBtnIconHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	hideBtnIconHolder.Position = UDim2.fromScale(0.5, 0.5)
	hideBtnIconHolder.Size = UDim2.fromOffset(18, 18)
	hideBtnIconHolder.Parent = hideBtn
	Library.GetIcon(hideBtnIconHolder, 18, Theme.SubText, "eye")
	hideBtn.MouseButton1Click:Connect(function() setWindowVisible(false, true) end)

	local MinimizeBtn = Instance.new("TextButton")
	MinimizeBtn.AnchorPoint = Vector2.new(1, 0.5)
	MinimizeBtn.Position = UDim2.new(1, -44, 0.5, 0)
	MinimizeBtn.Size = UDim2.fromOffset(26, 26)
	MinimizeBtn.BackgroundTransparency = 1
	MinimizeBtn.AutoButtonColor = false
	MinimizeBtn.Font = FONT_BOLD
	MinimizeBtn.TextSize = 16
	MinimizeBtn.TextColor3 = Theme.SubText
	MinimizeBtn.Text = "\226\128\147"
	MinimizeBtn.ZIndex = 6
	MinimizeBtn.Parent = Topbar
	addPressFeel(MinimizeBtn, 1.15)
	MinimizeBtn.MouseEnter:Connect(function() tween(MinimizeBtn, { TextColor3 = Theme.Text }, 0.15) end)
	MinimizeBtn.MouseLeave:Connect(function() tween(MinimizeBtn, { TextColor3 = Theme.SubText }, 0.15) end)

	local UnloadBtn = Instance.new("TextButton")
	UnloadBtn.AnchorPoint = Vector2.new(1, 0.5)
	UnloadBtn.Position = UDim2.new(1, -12, 0.5, 0)
	UnloadBtn.Size = UDim2.fromOffset(26, 26)
	UnloadBtn.BackgroundTransparency = 1
	UnloadBtn.AutoButtonColor = false
	UnloadBtn.Font = FONT_BOLD
	UnloadBtn.TextSize = 14
	UnloadBtn.TextColor3 = Theme.SubText
	UnloadBtn.Text = "\195\151"
	UnloadBtn.ZIndex = 6
	UnloadBtn.Parent = Topbar
	addPressFeel(UnloadBtn, 1.15)

	local function doUnload()
		tween(Window, { BackgroundTransparency = 1, Size = UDim2.fromOffset(Window.AbsoluteSize.X - 60, Window.AbsoluteSize.Y - 60) }, 0.25)
		task.delay(0.25, function() screenGui:Destroy() end)
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
					UnloadBtn.Text = "\195\151"
					UnloadBtn.TextColor3 = Theme.SubText
				end
			end)
		else
			doUnload()
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
	TabListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	TabListLayout.Padding = UDim.new(0, 4)
	TabListLayout.Parent = TabList

	local ContentHolder = Instance.new("Frame")
	ContentHolder.BackgroundTransparency = 1
	ContentHolder.Position = UDim2.new(0, 150, 0, 44)
	ContentHolder.Size = UDim2.new(1, -150, 1, -44)
	ContentHolder.ZIndex = 4
	ContentHolder.Parent = Window

	-- ============ Top-Right Overlay: Profil / FPS / Ping ============
	-- UIListLayout sorgt dafür, dass sich nichts überlappt (auto-fließendes Layout statt fixer Offsets).

	local EXPANDED_HEIGHT = 52
	local EXPANDED_WIDTH = 344

	local Overlay = Instance.new("Frame")
	Overlay.Name = "StatsOverlay"
	Overlay.AnchorPoint = Vector2.new(1, 0)
	Overlay.Position = UDim2.new(1, -14, 0, 14)
	Overlay.Size = UDim2.fromOffset(EXPANDED_WIDTH, EXPANDED_HEIGHT)
	Overlay.BackgroundColor3 = Theme.Section
	Overlay.ClipsDescendants = true
	Overlay.ZIndex = 8
	Overlay.Parent = screenGui
	corner(Overlay, "circle")
	faintStroke(Overlay, 0.75)

	local overlayPad = Instance.new("UIPadding")
	overlayPad.PaddingLeft = UDim.new(0, 6)
	overlayPad.PaddingRight = UDim.new(0, 10)
	overlayPad.Parent = Overlay

	local overlayList = Instance.new("UIListLayout")
	overlayList.SortOrder = Enum.SortOrder.LayoutOrder
	overlayList.FillDirection = Enum.FillDirection.Horizontal
	overlayList.VerticalAlignment = Enum.VerticalAlignment.Center
	overlayList.Padding = UDim.new(0, 10)
	overlayList.Parent = Overlay

	local function divider(order)
		local d = Instance.new("Frame")
		d.LayoutOrder = order
		d.Size = UDim2.fromOffset(1, 28)
		d.BackgroundColor3 = Theme.Element
		d.BorderSizePixel = 0
		d.Parent = Overlay
		return d
	end

	local avatarImg = Instance.new("ImageLabel")
	avatarImg.LayoutOrder = 1
	avatarImg.Size = UDim2.fromOffset(40, 40)
	avatarImg.BackgroundColor3 = Theme.Element
	avatarImg.ZIndex = 9
	avatarImg.Parent = Overlay
	corner(avatarImg, "circle")
	faintStroke(avatarImg, 0.4)

	task.spawn(function()
		local ok, content = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok then avatarImg.Image = content end
	end)

	local nameStack = Instance.new("Frame")
	nameStack.LayoutOrder = 2
	nameStack.BackgroundTransparency = 1
	nameStack.Size = UDim2.fromOffset(96, 40)
	nameStack.ZIndex = 9
	nameStack.Parent = Overlay

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.new(0, 0, 0, 1)
	nameLabel.Size = UDim2.new(1, 0, 0, 16)
	nameLabel.Font = FONT_BOLD
	nameLabel.TextSize = 12
	nameLabel.TextColor3 = Theme.Text
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Text = player.DisplayName
	nameLabel.Parent = nameStack

	local placeLabel = Instance.new("TextLabel")
	placeLabel.BackgroundTransparency = 1
	placeLabel.Position = UDim2.new(0, 0, 0, 19)
	placeLabel.Size = UDim2.new(1, 0, 0, 14)
	placeLabel.Font = FONT
	placeLabel.TextSize = 10
	placeLabel.TextColor3 = Theme.SubText
	placeLabel.TextXAlignment = Enum.TextXAlignment.Left
	placeLabel.TextTruncate = Enum.TextTruncate.AtEnd
	placeLabel.Text = ("%d Spieler online"):format(#Players:GetPlayers())
	placeLabel.Parent = nameStack

	divider(3)

	local fpsStack = Instance.new("Frame")
	fpsStack.LayoutOrder = 4
	fpsStack.BackgroundTransparency = 1
	fpsStack.Size = UDim2.fromOffset(38, 40)
	fpsStack.ZIndex = 9
	fpsStack.Parent = Overlay

	local fpsRow = Instance.new("Frame")
	fpsRow.BackgroundTransparency = 1
	fpsRow.Position = UDim2.new(0, 0, 0, 2)
	fpsRow.Size = UDim2.new(1, 0, 0, 16)
	fpsRow.Parent = fpsStack

	local fpsIconHolder = Instance.new("Frame")
	fpsIconHolder.BackgroundTransparency = 1
	fpsIconHolder.Size = UDim2.fromOffset(12, 12)
	fpsIconHolder.Position = UDim2.new(0, 0, 0, 2)
	fpsIconHolder.Parent = fpsRow
	Library.GetIcon(fpsIconHolder, 12, Theme.Cyan, "bar-chart")

	local fpsValue = Instance.new("TextLabel")
	fpsValue.BackgroundTransparency = 1
	fpsValue.Position = UDim2.new(0, 16, 0, -2)
	fpsValue.Size = UDim2.new(1, -16, 1, 0)
	fpsValue.Font = FONT_BOLD
	fpsValue.TextSize = 13
	fpsValue.TextColor3 = Theme.Text
	fpsValue.TextXAlignment = Enum.TextXAlignment.Left
	fpsValue.Text = "0"
	fpsValue.Parent = fpsRow

	local fpsCaption = Instance.new("TextLabel")
	fpsCaption.BackgroundTransparency = 1
	fpsCaption.Position = UDim2.new(0, 0, 0, 20)
	fpsCaption.Size = UDim2.new(1, 0, 0, 14)
	fpsCaption.Font = FONT
	fpsCaption.TextSize = 10
	fpsCaption.TextColor3 = Theme.SubText
	fpsCaption.TextXAlignment = Enum.TextXAlignment.Left
	fpsCaption.Text = "FPS"
	fpsCaption.Parent = fpsStack

	divider(5)

	local pingStack = Instance.new("Frame")
	pingStack.LayoutOrder = 6
	pingStack.BackgroundTransparency = 1
	pingStack.Size = UDim2.fromOffset(52, 40)
	pingStack.ZIndex = 9
	pingStack.Parent = Overlay

	local pingRow = Instance.new("Frame")
	pingRow.BackgroundTransparency = 1
	pingRow.Position = UDim2.new(0, 0, 0, 2)
	pingRow.Size = UDim2.new(1, 0, 0, 16)
	pingRow.Parent = pingStack

	local pingDot = Instance.new("Frame")
	pingDot.AnchorPoint = Vector2.new(0, 0.5)
	pingDot.Position = UDim2.new(0, 0, 0.5, 0)
	pingDot.Size = UDim2.fromOffset(8, 8)
	pingDot.BackgroundColor3 = Theme.Good
	pingDot.Parent = pingRow
	corner(pingDot, "circle")

	local pingValue = Instance.new("TextLabel")
	pingValue.BackgroundTransparency = 1
	pingValue.Position = UDim2.new(0, 14, 0, -2)
	pingValue.Size = UDim2.new(1, -14, 1, 0)
	pingValue.Font = FONT_BOLD
	pingValue.TextSize = 13
	pingValue.TextColor3 = Theme.Text
	pingValue.TextXAlignment = Enum.TextXAlignment.Left
	pingValue.Text = "--"
	pingValue.Parent = pingRow

	local pingCaption = Instance.new("TextLabel")
	pingCaption.BackgroundTransparency = 1
	pingCaption.Position = UDim2.new(0, 0, 0, 20)
	pingCaption.Size = UDim2.new(1, 0, 0, 14)
	pingCaption.Font = FONT
	pingCaption.TextSize = 10
	pingCaption.TextColor3 = Theme.SubText
	pingCaption.TextXAlignment = Enum.TextXAlignment.Left
	pingCaption.Text = "Ping"
	pingCaption.Parent = pingStack

	local function updatePing()
		local ok, ping = pcall(function()
			return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()
		end)
		if ok then
			pingValue.Text = math.floor(ping) .. "ms"
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

	divider(7)

	local overlayEyeBtn = Instance.new("TextButton")
	overlayEyeBtn.LayoutOrder = 8
	overlayEyeBtn.Size = UDim2.fromOffset(22, 22)
	overlayEyeBtn.BackgroundTransparency = 1
	overlayEyeBtn.AutoButtonColor = false
	overlayEyeBtn.Text = ""
	overlayEyeBtn.ZIndex = 10
	overlayEyeBtn.Parent = Overlay
	addPressFeel(overlayEyeBtn, 1.15)
	local overlayEyeIconHolder = Instance.new("Frame")
	overlayEyeIconHolder.BackgroundTransparency = 1
	overlayEyeIconHolder.Size = UDim2.fromOffset(16, 16)
	overlayEyeIconHolder.Position = UDim2.new(0.5, -8, 0.5, -8)
	overlayEyeIconHolder.Parent = overlayEyeBtn
	Library.GetIcon(overlayEyeIconHolder, 16, Theme.SubText, "eye")

	local overlayPill = Instance.new("TextButton")
	overlayPill.AnchorPoint = Vector2.new(1, 0)
	overlayPill.Position = UDim2.new(1, -14, 0, 14)
	overlayPill.Size = UDim2.fromOffset(EXPANDED_HEIGHT, EXPANDED_HEIGHT)
	overlayPill.BackgroundColor3 = Theme.Section
	overlayPill.AutoButtonColor = false
	overlayPill.Text = ""
	overlayPill.Visible = false
	overlayPill.ZIndex = 8
	overlayPill.Parent = screenGui
	corner(overlayPill, "circle")
	faintStroke(overlayPill, 0.75)
	addPressFeel(overlayPill, 1.1)
	local overlayPillIconHolder = Instance.new("Frame")
	overlayPillIconHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	overlayPillIconHolder.Position = UDim2.fromScale(0.5, 0.5)
	overlayPillIconHolder.Size = UDim2.fromOffset(18, 18)
	overlayPillIconHolder.Parent = overlayPill
	Library.GetIcon(overlayPillIconHolder, 18, Theme.SubText, "eye")

	local function setOverlayExpanded(expanded)
		if expanded then
			overlayPill.Visible = false
			Overlay.Visible = true
			tween(Overlay, { Size = UDim2.fromOffset(EXPANDED_WIDTH, EXPANDED_HEIGHT) }, 0.25, Enum.EasingStyle.Back)
		else
			tween(Overlay, { Size = UDim2.fromOffset(EXPANDED_HEIGHT, EXPANDED_HEIGHT) }, 0.2)
			task.delay(0.2, function()
				Overlay.Visible = false
				overlayPill.Visible = true
			end)
		end
	end
	overlayEyeBtn.MouseButton1Click:Connect(function() setOverlayExpanded(false) end)
	overlayPill.MouseButton1Click:Connect(function() setOverlayExpanded(true) end)

	-- ============ Tabs / Sections / Elemente ============

	local tabs = {}
	local firstTab = true

	local WindowObject = {}

	function WindowObject:CreateTab(name, iconName)
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
		Library.GetIcon(iconHolder, 18, iconColor, iconName or "sparkles")

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
		pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
		pageLayout.Padding = UDim.new(0, 10)
		pageLayout.Parent = page

		if firstTab then
			tabBtn.BackgroundColor3 = Theme.Element
			tabBtn.BackgroundTransparency = 0
			firstTab = false
		end

		local function setChildColors(color)
			label.TextColor3 = color
			for _, d in ipairs(iconHolder:GetDescendants()) do
				if d:IsA("Frame") and d.BackgroundTransparency == 0 and not d:FindFirstChildOfClass("UIStroke") then
					tween(d, { BackgroundColor3 = color }, 0.15)
				elseif d:IsA("TextLabel") then
					tween(d, { TextColor3 = color }, 0.15)
				elseif d:IsA("ImageLabel") then
					tween(d, { ImageColor3 = color }, 0.15)
				end
			end
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
			layout.SortOrder = Enum.SortOrder.LayoutOrder
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
				addPressFeel(btn, 1.015)

				btn.MouseEnter:Connect(function() tween(btn, { BackgroundColor3 = Theme.ElementHover }, 0.15) end)
				btn.MouseLeave:Connect(function() tween(btn, { BackgroundColor3 = Theme.Element }, 0.15) end)
				btn.MouseButton1Down:Connect(function()
					tween(btn, { BackgroundColor3 = Theme.Violet }, 0.08)
				end)
				btn.MouseButton1Click:Connect(function()
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

				local label2 = Instance.new("TextLabel")
				label2.BackgroundTransparency = 1
				label2.Position = UDim2.new(0, 10, 0, 0)
				label2.Size = UDim2.new(1, -60, 1, 0)
				label2.Font = FONT
				label2.TextSize = 13
				label2.TextColor3 = Theme.Text
				label2.TextXAlignment = Enum.TextXAlignment.Left
				label2.Text = text
				label2.Parent = holder

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
				addPressFeel(click, 1)

				click.MouseButton1Click:Connect(function()
					state = not state
					tween(track, { BackgroundColor3 = state and Theme.Violet or Color3.fromRGB(55, 50, 80) }, 0.15)
					tween(knob, { Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8) }, 0.15, Enum.EasingStyle.Back)
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

				local label2 = Instance.new("TextLabel")
				label2.BackgroundTransparency = 1
				label2.Position = UDim2.new(0, 10, 0, 4)
				label2.Size = UDim2.new(1, -60, 0, 16)
				label2.Font = FONT
				label2.TextSize = 13
				label2.TextColor3 = Theme.Text
				label2.TextXAlignment = Enum.TextXAlignment.Left
				label2.Text = text
				label2.Parent = holder

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

				local label2 = Instance.new("TextLabel")
				label2.BackgroundTransparency = 1
				label2.Position = UDim2.new(0, 10, 0, 0)
				label2.Size = UDim2.new(0.5, 0, 0, 32)
				label2.Font = FONT
				label2.TextSize = 13
				label2.TextColor3 = Theme.Text
				label2.TextXAlignment = Enum.TextXAlignment.Left
				label2.Text = text
				label2.Parent = holder

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
				optListLayout.SortOrder = Enum.SortOrder.LayoutOrder
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

				local label2 = Instance.new("TextLabel")
				label2.BackgroundTransparency = 1
				label2.Size = UDim2.new(1, 0, 0, 16)
				label2.Font = FONT
				label2.TextSize = 12
				label2.TextColor3 = Theme.Text
				label2.TextXAlignment = Enum.TextXAlignment.Left
				label2.Text = text .. (note and ("  \194\183  " .. note) or "")
				label2.Parent = holder

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
				local label2 = Instance.new("TextLabel")
				label2.LayoutOrder = order
				label2.BackgroundTransparency = 1
				label2.Size = UDim2.new(1, 0, 0, 16)
				label2.Font = FONT
				label2.TextSize = 12
				label2.TextColor3 = Theme.SubText
				label2.TextXAlignment = Enum.TextXAlignment.Left
				label2.TextWrapped = true
				label2.Text = text
				label2.Parent = section
				return label2
			end

			return SectionObject
		end

		return TabObject
	end

	function WindowObject:Notify(title, content, duration)
		Notify(title, content, duration)
	end

	function WindowObject:SetVisible(visible)
		setWindowVisible(visible, true)
	end

	function WindowObject:Unload()
		doUnload()
	end

	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == Enum.KeyCode.RightShift and Window.Parent then
			setWindowVisible(not windowVisible, true)
		end
	end)

	-- Pop-up-Öffnungsanimation
	Window.BackgroundTransparency = 1
	Window.Size = UDim2.fromOffset(FULL_SIZE.X.Offset * 0.85, FULL_SIZE.Y.Offset * 0.85)
	tween(Window, { BackgroundTransparency = 0, Size = FULL_SIZE }, 0.45, Enum.EasingStyle.Back)

	Overlay.Position = Overlay.Position - UDim2.fromOffset(0, -16)
	Overlay.BackgroundTransparency = 1
	tween(Overlay, { Position = UDim2.new(1, -14, 0, 14), BackgroundTransparency = 0 }, 0.4, Enum.EasingStyle.Back)

	return WindowObject
end

-- ============ CreateLoader ============
-- Zeigt eine Auswahl-Liste von "Instanzen" (anderen Lua/ModuleScript-Dateien), bevor der
-- eigentliche Hub geladen wird. Jede Instanz definiert Name / Image / Description selbst
-- über die Instances-Tabelle, siehe Loader.client.lua.

function Library.CreateLoader(config)
	config = config or {}
	local instances = config.Instances or {}

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "YunoHubLoader"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	buildGalaxyBackdrop(screenGui)

	local dim = Instance.new("Frame")
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 1
	dim.Size = UDim2.fromScale(1, 1)
	dim.ZIndex = 2
	dim.Parent = screenGui
	tween(dim, { BackgroundTransparency = 0.4 }, 0.35)

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(420, 480)
	panel.BackgroundColor3 = Theme.Background
	panel.BackgroundTransparency = 1
	panel.ClipsDescendants = true
	panel.ZIndex = 3
	panel.Parent = screenGui
	corner(panel, 12)
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Thickness = 1.4
	panelStroke.Color = Theme.Violet
	panelStroke.Parent = panel

	RunService.Heartbeat:Connect(function()
		if not panel.Parent then return end
		local hue = 0.72 + 0.13 * math.sin(os.clock() * 0.35)
		panelStroke.Color = Color3.fromHSV(hue % 1, 0.55, 1)
	end)

	local header = Instance.new("Frame")
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 70)
	header.ZIndex = 4
	header.Parent = panel

	local logoHolder = Instance.new("Frame")
	logoHolder.AnchorPoint = Vector2.new(0.5, 0)
	logoHolder.Position = UDim2.new(0.5, 0, 0, 16)
	logoHolder.Size = UDim2.fromOffset(28, 28)
	logoHolder.ZIndex = 4
	logoHolder.Parent = header
	Library.GetIcon(logoHolder, 28, Theme.Cyan, "sparkles")

	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.new(0, 0, 0, 44)
	titleLabel.Size = UDim2.new(1, 0, 0, 22)
	titleLabel.Font = FONT_BOLD
	titleLabel.TextSize = 18
	titleLabel.TextColor3 = Theme.Text
	titleLabel.Text = config.Title or "Yuno Hub"
	titleLabel.ZIndex = 4
	titleLabel.Parent = header

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Position = UDim2.new(0, 0, 0, 46)
	subtitleLabel.Size = UDim2.new(1, 0, 0, 16)
	subtitleLabel.Font = FONT
	subtitleLabel.TextSize = 11
	subtitleLabel.TextColor3 = Theme.SubText
	subtitleLabel.Text = config.Subtitle or "Wähle eine Instanz zum Laden"
	subtitleLabel.ZIndex = 4
	subtitleLabel.Parent = header

	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.new(0, 16, 0, 78)
	list.Size = UDim2.new(1, -32, 1, -94)
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 3
	list.ScrollBarImageColor3 = Theme.Violet
	list.ZIndex = 4
	list.Parent = panel

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 10)
	listLayout.Parent = list

	for i, entry in ipairs(instances) do
		local card = Instance.new("Frame")
		card.LayoutOrder = i
		card.BackgroundColor3 = Theme.Section
		card.Size = UDim2.new(1, 0, 0, 78)
		card.ZIndex = 4
		card.Parent = list
		corner(card, 10)
		faintStroke(card, 0.85)

		local iconHolder = Instance.new("Frame")
		iconHolder.AnchorPoint = Vector2.new(0, 0.5)
		iconHolder.Position = UDim2.new(0, 14, 0.5, 0)
		iconHolder.Size = UDim2.fromOffset(40, 40)
		iconHolder.ZIndex = 5
		iconHolder.Parent = card

		if type(entry.Image) == "string" and entry.Image:match("^rbxassetid://") then
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Size = UDim2.fromScale(1, 1)
			img.Image = entry.Image
			img.Parent = iconHolder
			corner(img, 8)
		else
			Library.GetIcon(iconHolder, 40, Theme.Violet, entry.Image or entry.Name or "sparkles")
		end

		local nameLbl = Instance.new("TextLabel")
		nameLbl.BackgroundTransparency = 1
		nameLbl.Position = UDim2.new(0, 66, 0, 12)
		nameLbl.Size = UDim2.new(1, -170, 0, 18)
		nameLbl.Font = FONT_BOLD
		nameLbl.TextSize = 14
		nameLbl.TextColor3 = Theme.Text
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
		nameLbl.Text = entry.Name or ("Instanz " .. i)
		nameLbl.ZIndex = 5
		nameLbl.Parent = card

		local descLbl = Instance.new("TextLabel")
		descLbl.BackgroundTransparency = 1
		descLbl.Position = UDim2.new(0, 66, 0, 32)
		descLbl.Size = UDim2.new(1, -170, 0, 36)
		descLbl.Font = FONT
		descLbl.TextSize = 11
		descLbl.TextColor3 = Theme.SubText
		descLbl.TextXAlignment = Enum.TextXAlignment.Left
		descLbl.TextYAlignment = Enum.TextYAlignment.Top
		descLbl.TextWrapped = true
		descLbl.Text = entry.Description or ""
		descLbl.ZIndex = 5
		descLbl.Parent = card

		local loadBtn = Instance.new("TextButton")
		loadBtn.AnchorPoint = Vector2.new(1, 0.5)
		loadBtn.Position = UDim2.new(1, -12, 0.5, 0)
		loadBtn.Size = UDim2.fromOffset(80, 32)
		loadBtn.BackgroundColor3 = Theme.Element
		loadBtn.AutoButtonColor = false
		loadBtn.Font = FONT_BOLD
		loadBtn.TextSize = 12
		loadBtn.TextColor3 = Theme.Text
		loadBtn.Text = "Laden"
		loadBtn.ZIndex = 5
		loadBtn.Parent = card
		corner(loadBtn, 8)
		addPressFeel(loadBtn, 1.06)

		loadBtn.MouseEnter:Connect(function() tween(loadBtn, { BackgroundColor3 = Theme.Violet }, 0.15) end)
		loadBtn.MouseLeave:Connect(function() tween(loadBtn, { BackgroundColor3 = Theme.Element }, 0.15) end)

		loadBtn.MouseButton1Click:Connect(function()
			if not entry.Module then
				warn("[YunoHub] Diese Instanz hat kein Module referenziert: " .. tostring(entry.Name))
				return
			end
			tween(panel, { BackgroundTransparency = 1, Size = panel.Size - UDim2.fromOffset(30, 30) }, 0.25)
			tween(dim, { BackgroundTransparency = 1 }, 0.25)
			task.delay(0.25, function()
				screenGui:Destroy()
				local ok, err = pcall(function()
					local initFn = require(entry.Module)
					initFn(Library)
				end)
				if not ok then
					warn("[YunoHub] Fehler beim Laden von '" .. tostring(entry.Name) .. "': " .. tostring(err))
				end
			end)
		end)
	end

	-- Pop-up-Öffnungsanimation
	panel.Size = UDim2.fromOffset(420 * 0.85, 480 * 0.85)
	tween(panel, { Size = UDim2.fromOffset(420, 480), BackgroundTransparency = 0 }, 0.45, Enum.EasingStyle.Back)

	return screenGui
end

return Library
