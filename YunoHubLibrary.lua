--[[
	YunoHubLibrary.lua  (ModuleScript)

	Reusable UI library in the Galaxy style, structured conceptually like Rayfield:
	Library.CreateLoader(...)  -> instance-selection screen (shows several hubs to pick from)
	Library.CreateWindow(...)  -> the actual hub window
	Window:CreateTab(name, icon) -> Tab
	Tab:CreateSection(name, info) -> Section
	Section:CreateButton / :CreateToggle / :CreateSlider / :CreateDropdown / :CreateProgressBar / :CreateLabel
	Window:Notify(title, content, duration)
	Window:SetVisible(bool) / Window:Unload()

	This same file works both as a Roblox ModuleScript (require(...)) AND as a raw chunk
	loaded via loadstring(game:HttpGet(url))() — it just needs to end in `return Library`
	either way, which it does. See Bootstrap.lua for the loadstring/GitHub entry point.

	Icons: Library.IconAssets[name] = "rbxassetid://..." — fill in your own uploaded asset
	IDs here (see the /icons folder + README). While an entry is empty, the library shows a
	clean monogram placeholder (circle + first letter) instead of a broken image.
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local StatsService = game:GetService("Stats")
local HttpService = game:GetService("HttpService")

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

-- Branding image shown in the loader topbar, the window topbar and the launcher orb.
-- Upload your logo (e.g. the galaxy "Y") in Studio and paste its rbxassetid here. While it
-- is empty the library falls back to the "sparkles" icon so nothing looks broken.
-- Unlike the monochrome icons this is drawn in full colour, so artwork keeps its own look.
Library.Logo = ""

-- After uploading your icons (see /icons, GitHub link, Studio asset upload), fill in the
-- matching rbxassetid here, e.g. home = "rbxassetid://123456789".
Library.IconAssets = {
	home = "", settings = "rbxassetid://108128119691678", sparkles = "rbxassetid://102939560874422", ["bar-chart"] = "rbxassetid://94379991850418", eye = "rbxassetid://90113970304999", power = "rbxassetid://79781370224359",
	skull = "rbxassetid://130801325845894", crosshair = "rbxassetid://105922158996884", shield = "rbxassetid://98009801247120", sword = "rbxassetid://75064125564088", zap = "rbxassetid://127256677933477", gift = "rbxassetid://123930470777740", trophy = "rbxassetid://135167728881368",
	bell = "rbxassetid://87557547096119", lock = "rbxassetid://83161512836041", flame = "rbxassetid://78764037261724", gem = "rbxassetid://89956647859792", package = "rbxassetid://118869616844031", user = "rbxassetid://88727719972167", rocket = "rbxassetid://140102910130627",
	crown = "rbxassetid://80389799340753", coins = "rbxassetid://126119394485906", key = "rbxassetid://81002896415776", wrench = "rbxassetid://92543314798081", map = "rbxassetid://93547411683695", heart = "rbxassetid://83891299559410", moon = "rbxassetid://110911670478833",
	battery = "rbxassetid://115842063460165", save = "rbxassetid://134087985142574", ["clipboard-list"] = "rbxassetid://96622411563473", dice = "rbxassetid://97754275435971", wand = "rbxassetid://127285838323517", layers = "rbxassetid://89522153074978",
	ghost = "rbxassetid://128556369425614", medal = "rbxassetid://106927143847925",
}

-- ============ Generic helpers ============

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

-- Hover-grow + press-squeeze, for a tactile, "real" click feel
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

-- ============ Icon system ============
-- Uses an uploaded rbxassetid if one is set, otherwise falls back to a clean monogram.

-- Draws the monogram fallback (ring + first letter) into `holder`.
local function drawMonogram(holder, size, color, name)
	local ringFrame = Instance.new("Frame")
	ringFrame.Name = "Monogram"
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
	return ringFrame
end

-- Branding mark. Uses Library.Logo in full colour when set, otherwise the tinted
-- "sparkles" icon, so the UI is never left with an empty corner.
function Library.GetLogo(parent, size, fallbackColor)
	if Library.Logo and Library.Logo ~= "" then
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromOffset(size, size)
		holder.Parent = parent

		local img = Instance.new("ImageLabel")
		img.Name = "Logo"
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = Library.Logo
		img.ScaleType = Enum.ScaleType.Fit
		img.Parent = holder

		task.spawn(function()
			local waited = 0
			while waited < 5 do
				if not img.Parent then return end
				if img.IsLoaded then return end
				task.wait(0.25)
				waited += 0.25
			end
			if img.Parent and not img.IsLoaded then
				img:Destroy()
				Library.GetIcon(holder, size, fallbackColor or Theme.Cyan, "sparkles")
			end
		end)

		return holder
	end

	return Library.GetIcon(parent, size, fallbackColor or Theme.Cyan, "sparkles")
end

function Library.GetIcon(parent, size, color, name, spin)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(size, size)
	holder.Parent = parent

	local assetId = Library.IconAssets[name]
	if assetId and assetId ~= "" then
		local img = Instance.new("ImageLabel")
		img.Name = "Icon"
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = assetId
		img.ImageColor3 = color
		img.Parent = holder

		-- An asset ID can be valid yet still never render (most commonly a Decal ID where
		-- an Image ID is required, or one still awaiting moderation). Rather than leaving a
		-- blank gap in the UI, wait for the load and quietly swap in the monogram if it
		-- never arrives.
		task.spawn(function()
			local waited = 0
			while waited < 5 do
				if not img.Parent then return end
				if img.IsLoaded then return end
				task.wait(0.25)
				waited += 0.25
			end
			if img.Parent and not img.IsLoaded then
				img:Destroy()
				drawMonogram(holder, size, color, name)
			end
		end)
	else
		drawMonogram(holder, size, color, name)
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

-- ============ Galaxy backdrop (stars + nebula glow), shared by Loader & Window ============

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

	return function(titleText, contentText, duration, iconName)
		duration = duration or 3.5
		local notif = Instance.new("Frame")
		notif.BackgroundColor3 = Theme.Section
		notif.Size = UDim2.new(1, 0, 0, 64)
		notif.ClipsDescendants = true
		notif.Parent = NotifyHolder
		corner(notif, 8)
		faintStroke(notif, 0.75)
		notif.Position = UDim2.fromOffset(300, 0)

		local textOffset = 12
		if iconName then
			local iconHolder = Instance.new("Frame")
			iconHolder.AnchorPoint = Vector2.new(0, 0.5)
			iconHolder.Position = UDim2.new(0, 12, 0.5, 0)
			iconHolder.Size = UDim2.fromOffset(28, 28)
			iconHolder.Parent = notif
			corner(iconHolder, "circle")
			faintStroke(iconHolder, 0.4)
			local innerIconHolder = Instance.new("Frame")
			innerIconHolder.AnchorPoint = Vector2.new(0.5, 0.5)
			innerIconHolder.Position = UDim2.fromScale(0.5, 0.5)
			innerIconHolder.Size = UDim2.fromOffset(16, 16)
			innerIconHolder.Parent = iconHolder
			Library.GetIcon(innerIconHolder, 16, Theme.Violet, iconName)
			textOffset = 12 + 28 + 10
		end

		local nTitle = Instance.new("TextLabel")
		nTitle.BackgroundTransparency = 1
		nTitle.Position = UDim2.new(0, textOffset, 0, 8)
		nTitle.Size = UDim2.new(1, -textOffset - 12, 0, 18)
		nTitle.Font = FONT_BOLD
		nTitle.TextSize = 14
		nTitle.TextColor3 = Theme.Text
		nTitle.TextXAlignment = Enum.TextXAlignment.Left
		nTitle.Text = titleText
		nTitle.Parent = notif

		local nContent = Instance.new("TextLabel")
		nContent.BackgroundTransparency = 1
		nContent.Position = UDim2.new(0, textOffset, 0, 28)
		nContent.Size = UDim2.new(1, -textOffset - 12, 0, 24)
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
	screenGui.DisplayOrder = 1000
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

	-- Open/close animate this instead of Size: tweening Size reflows every child layout
	-- each frame, which is what made the old close read as a jerky "collapse".
	local windowScale = Instance.new("UIScale")
	windowScale.Parent = Window

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
	Library.GetLogo(titleIconHolder, 20, Theme.Cyan)

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

	-- Launcher orb (visible while the window is hidden)
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
	local launcherScale = addPressFeel(Launcher, 1.1)
	local launcherIconHolder = Instance.new("Frame")
	launcherIconHolder.BackgroundTransparency = 1
	launcherIconHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	launcherIconHolder.Position = UDim2.fromScale(0.5, 0.5)
	launcherIconHolder.Size = UDim2.fromOffset(22, 22)
	launcherIconHolder.ZIndex = 11
	launcherIconHolder.Parent = Launcher
	Library.GetLogo(launcherIconHolder, 22, Theme.Cyan)

	local windowVisible = true
	local function setWindowVisible(visible, animate)
		windowVisible = visible
		if visible then
			Launcher.Visible = false
			Window.Visible = true
			if animate then
				windowScale.Scale = 0.88
				Window.BackgroundTransparency = 1
				windowStroke.Transparency = 1
				tween(windowScale, { Scale = 1 }, 0.38, Enum.EasingStyle.Back)
				tween(Window, { BackgroundTransparency = 0 }, 0.22)
				tween(windowStroke, { Transparency = 0 }, 0.3)
			else
				windowScale.Scale = 1
				Window.BackgroundTransparency = 0
				windowStroke.Transparency = 0
			end
		else
			if animate then
				tween(windowScale, { Scale = 0.9 }, 0.2, Enum.EasingStyle.Quad)
				tween(Window, { BackgroundTransparency = 1 }, 0.2)
				tween(windowStroke, { Transparency = 1 }, 0.16)
				task.delay(0.2, function()
					Window.Visible = false
					windowScale.Scale = 1
					Window.BackgroundTransparency = 0
					windowStroke.Transparency = 0

					Launcher.Visible = true
					launcherScale.Scale = 0.6
					Launcher.BackgroundTransparency = 1
					tween(launcherScale, { Scale = 1 }, 0.34, Enum.EasingStyle.Back)
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
		-- Everything leaves together: window shrinks away, the stats pill and launcher orb
		-- fade with it, so nothing is left hanging on screen mid-animation.
		tween(windowScale, { Scale = 0.82 }, 0.26, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tween(Window, { BackgroundTransparency = 1 }, 0.26)
		tween(windowStroke, { Transparency = 1 }, 0.2)

		-- Walked from the ScreenGui rather than named directly: the overlay and pill are
		-- built further down this function, so naming them here would capture nil.
		for _, obj in ipairs(screenGui:GetChildren()) do
			if obj ~= Window and obj:IsA("GuiObject") and obj.Visible then
				tween(obj, { BackgroundTransparency = 1 }, 0.2)
			end
		end

		task.delay(0.3, function() screenGui:Destroy() end)
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

	-- ============ Top-right overlay: profile / FPS / ping ============
	-- UIListLayout keeps everything from overlapping (auto-flowing layout instead of fixed offsets).

	local EXPANDED_HEIGHT = 52

	local Overlay = Instance.new("Frame")
	Overlay.Name = "StatsOverlay"
	Overlay.AnchorPoint = Vector2.new(1, 0)
	Overlay.Position = UDim2.new(1, -14, 0, 14)
	-- Width is driven by the content (AutomaticSize) instead of a hardcoded number, so the
	-- pill always hugs the stats rather than leaving dead space on the right.
	Overlay.AutomaticSize = Enum.AutomaticSize.X
	Overlay.Size = UDim2.fromOffset(0, EXPANDED_HEIGHT)
	Overlay.BackgroundColor3 = Theme.Section
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
	placeLabel.Text = ("%d players online"):format(#Players:GetPlayers())
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

	-- Raw "Data Ping" jitters hard from sample to sample, so keep a small rolling average.
	local pingSamples = {}
	local function updatePing()
		local ok, ping = pcall(function()
			return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()
		end)
		if not ok or type(ping) ~= "number" or ping ~= ping then return end

		table.insert(pingSamples, ping)
		if #pingSamples > 5 then table.remove(pingSamples, 1) end

		local sum = 0
		for _, v in ipairs(pingSamples) do sum += v end
		local avg = sum / #pingSamples

		pingValue.Text = math.floor(avg + 0.5) .. "ms"
		local c = avg < 100 and Theme.Good or (avg < 200 and Theme.Warn or Theme.Bad)
		tween(pingDot, { BackgroundColor3 = c }, 0.3)
	end

	task.spawn(function()
		while Overlay.Parent do
			updatePing()
			placeLabel.Text = ("%d players online"):format(#Players:GetPlayers())
			task.wait(1)
		end
	end)

	do
		-- Divide by the real elapsed time instead of assuming the window was exactly 1s and
		-- zeroing the remainder -- that discarded leftover consistently under-reported FPS.
		local frames, elapsed = 0, 0
		local fpsConn
		fpsConn = RunService.RenderStepped:Connect(function(dt)
			if not Overlay.Parent then
				fpsConn:Disconnect()
				return
			end
			frames += 1
			elapsed += dt
			if elapsed >= 0.5 then
				fpsValue.Text = tostring(math.floor(frames / elapsed + 0.5))
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

	-- The overlay sizes itself to its content, so collapse/expand animates scale + fade
	-- rather than a width we would otherwise have to hardcode.
	local overlayScale = Instance.new("UIScale")
	overlayScale.Parent = Overlay
	local pillScale = Instance.new("UIScale")
	pillScale.Parent = overlayPill

	local function setOverlayExpanded(expanded)
		if expanded then
			tween(pillScale, { Scale = 0.7 }, 0.14)
			tween(overlayPill, { BackgroundTransparency = 1 }, 0.14)
			task.delay(0.14, function()
				overlayPill.Visible = false
				pillScale.Scale = 1
				overlayPill.BackgroundTransparency = 0

				Overlay.Visible = true
				overlayScale.Scale = 0.75
				Overlay.BackgroundTransparency = 1
				tween(overlayScale, { Scale = 1 }, 0.32, Enum.EasingStyle.Back)
				tween(Overlay, { BackgroundTransparency = 0 }, 0.22)
			end)
		else
			tween(overlayScale, { Scale = 0.75 }, 0.18)
			tween(Overlay, { BackgroundTransparency = 1 }, 0.18)
			task.delay(0.18, function()
				Overlay.Visible = false
				overlayScale.Scale = 1
				Overlay.BackgroundTransparency = 0

				overlayPill.Visible = true
				pillScale.Scale = 0.7
				overlayPill.BackgroundTransparency = 1
				tween(pillScale, { Scale = 1 }, 0.3, Enum.EasingStyle.Back)
				tween(overlayPill, { BackgroundTransparency = 0 }, 0.2)
			end)
		end
	end
	overlayEyeBtn.MouseButton1Click:Connect(function() setOverlayExpanded(false) end)
	overlayPill.MouseButton1Click:Connect(function() setOverlayExpanded(true) end)

	-- ============ Tabs / Sections / Elements ============

	local tabs = {}
	local firstTab = true

	-- Every element created with a `flag` registers a get/set pair here. That is what makes
	-- presets possible: a preset is just a snapshot of every flag's value.
	local flags = {}

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
				return {
					Instance = btn,
					Set = function(_, newText) btn.Text = tostring(newText) end,
					Get = function() return btn.Text end,
				}
			end

			function SectionObject:CreateToggle(text, default, callback, flag)
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

				local function applyState(newState, fireCallback)
					state = newState and true or false
					tween(track, { BackgroundColor3 = state and Theme.Violet or Color3.fromRGB(55, 50, 80) }, 0.15)
					tween(knob, { Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8) }, 0.15, Enum.EasingStyle.Back)
					if fireCallback ~= false and callback then callback(state) end
				end

				click.MouseButton1Click:Connect(function()
					applyState(not state, true)
				end)

				if flag then
					flags[flag] = {
						get = function() return state end,
						set = function(v) applyState(v, true) end,
					}
				end

				return {
					Instance = holder,
					Set = function(_, v) applyState(v, true) end,
					Get = function() return state end,
				}
			end

			function SectionObject:CreateSlider(text, min, max, default, callback, flag)
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

				-- Shared by dragging and by programmatic Set/preset loading.
				local function applyValue(newValue, fireCallback, animate)
					value = math.clamp(math.floor(newValue + 0.5), min, max)
					local pct = (value - min) / (max - min)
					valueLabel.Text = tostring(value)
					if animate then
						tween(fill, { Size = UDim2.new(pct, 0, 1, 0) }, 0.25)
					else
						fill.Size = UDim2.new(pct, 0, 1, 0)
					end
					if fireCallback ~= false and callback then callback(value) end
				end

				local function updateFromX(xPos)
					local pct = math.clamp((xPos - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
					applyValue(min + (max - min) * pct, true, false)
				end

				if flag then
					flags[flag] = {
						get = function() return value end,
						set = function(v)
							if type(v) == "number" then applyValue(v, true, true) end
						end,
					}
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

				return {
					Instance = holder,
					Set = function(_, v) applyValue(v, true, true) end,
					Get = function() return value end,
				}
			end

			function SectionObject:CreateDropdown(text, options, default, callback, flag)
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

				local function applySelection(opt, fireCallback)
					local valid = false
					for _, o in ipairs(options) do
						if o == opt then valid = true break end
					end
					if not valid then return end
					selected = opt
					selectedLabel.Text = opt
					if fireCallback ~= false and callback then callback(opt) end
				end

				if flag then
					flags[flag] = {
						get = function() return selected end,
						set = function(v) applySelection(v, true) end,
					}
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

				return {
					Instance = holder,
					Set = function(_, v) applySelection(v, true) end,
					Get = function() return selected end,
				}
			end

			function SectionObject:CreateProgressBar(text, percent, note)
				order += 1
				local holder = Instance.new("Frame")
				holder.LayoutOrder = order
				holder.BackgroundTransparency = 1
				holder.Size = UDim2.new(1, 0, 0, 42)
				holder.Parent = section

				local label2 = Instance.new("TextLabel")
				label2.BackgroundTransparency = 1
				label2.Size = UDim2.new(1, -46, 0, 16)
				label2.Font = FONT
				label2.TextSize = 12
				label2.TextColor3 = Theme.Text
				label2.TextXAlignment = Enum.TextXAlignment.Left
				label2.TextTruncate = Enum.TextTruncate.AtEnd
				label2.Text = text .. (note and ("  \194\183  " .. note) or "")
				label2.Parent = holder

				-- Percentage read-out on the right, so the bar is readable without guessing.
				local pctLabel = Instance.new("TextLabel")
				pctLabel.AnchorPoint = Vector2.new(1, 0)
				pctLabel.Position = UDim2.new(1, 0, 0, 0)
				pctLabel.Size = UDim2.fromOffset(44, 16)
				pctLabel.BackgroundTransparency = 1
				pctLabel.Font = FONT_BOLD
				pctLabel.TextSize = 12
				pctLabel.TextColor3 = Theme.SubText
				pctLabel.TextXAlignment = Enum.TextXAlignment.Right
				pctLabel.Text = math.floor(percent + 0.5) .. "%"
				pctLabel.Parent = holder

				local track = Instance.new("Frame")
				track.Position = UDim2.new(0, 0, 0, 24)
				track.Size = UDim2.new(1, 0, 0, 8)
				track.BackgroundColor3 = Color3.fromRGB(38, 34, 60)
				track.ClipsDescendants = true
				track.Parent = holder
				corner(track, 4)

				local fill = Instance.new("Frame")
				fill.Size = UDim2.new(0, 0, 1, 0)
				fill.BackgroundColor3 = Theme.Violet
				-- Without this the shimmer escapes the filled region and slides across the
				-- whole track, which reads as a stray bright block on the empty part.
				fill.ClipsDescendants = true
				fill.Parent = track
				corner(fill, 4)

				local fillGradient = Instance.new("UIGradient")
				fillGradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Theme.Violet),
					ColorSequenceKeypoint.new(1, Theme.Cyan),
				})
				fillGradient.Parent = fill

				-- Soft gradient sweep rather than a hard white rectangle.
				local shimmer = Instance.new("Frame")
				shimmer.Size = UDim2.new(0.4, 0, 1, 0)
				shimmer.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				shimmer.BackgroundTransparency = 0.82
				shimmer.BorderSizePixel = 0
				shimmer.Position = UDim2.new(-0.45, 0, 0, 0)
				shimmer.Parent = fill

				local shimmerGradient = Instance.new("UIGradient")
				shimmerGradient.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 0),
					NumberSequenceKeypoint.new(1, 1),
				})
				shimmerGradient.Parent = shimmer

				TweenService:Create(
					shimmer,
					TweenInfo.new(1.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 0.4),
					{ Position = UDim2.new(1.05, 0, 0, 0) }
				):Play()

				local current = percent
				local function setPercent(value, newNote, animate)
					current = math.clamp(value, 0, 100)
					pctLabel.Text = math.floor(current + 0.5) .. "%"
					if newNote ~= nil then
						label2.Text = text .. (newNote ~= "" and ("  \194\183  " .. newNote) or "")
					end
					local goal = UDim2.new(current / 100, 0, 1, 0)
					if animate == false then
						fill.Size = goal
					else
						tween(fill, { Size = goal }, 0.55, Enum.EasingStyle.Quint)
					end
				end

				-- Animate up from zero on first paint so the bar reads as "filling".
				setPercent(percent, nil, true)

				return {
					Instance = holder,
					Set = function(_, value, newNote) setPercent(value, newNote, true) end,
					Get = function() return current end,
				}
			end

			function SectionObject:CreateInput(text, placeholder, callback, flag)
				order += 1
				local holder = Instance.new("Frame")
				holder.LayoutOrder = order
				holder.BackgroundColor3 = Theme.Element
				holder.Size = UDim2.new(1, 0, 0, 32)
				holder.Parent = section
				corner(holder, 6)

				local label2 = Instance.new("TextLabel")
				label2.BackgroundTransparency = 1
				label2.Position = UDim2.new(0, 10, 0, 0)
				label2.Size = UDim2.new(0.4, 0, 1, 0)
				label2.Font = FONT
				label2.TextSize = 13
				label2.TextColor3 = Theme.Text
				label2.TextXAlignment = Enum.TextXAlignment.Left
				label2.TextTruncate = Enum.TextTruncate.AtEnd
				label2.Text = text
				label2.Parent = holder

				local box = Instance.new("TextBox")
				box.AnchorPoint = Vector2.new(1, 0.5)
				box.Position = UDim2.new(1, -6, 0.5, 0)
				box.Size = UDim2.new(0.55, -12, 0, 24)
				box.BackgroundColor3 = Theme.Background
				box.Font = FONT
				box.TextSize = 12
				box.TextColor3 = Theme.Text
				box.PlaceholderText = placeholder or ""
				box.PlaceholderColor3 = Theme.SubText
				box.Text = ""
				box.ClearTextOnFocus = false
				box.Parent = holder
				corner(box, 5)

				local boxPad = Instance.new("UIPadding")
				boxPad.PaddingLeft = UDim.new(0, 8)
				boxPad.PaddingRight = UDim.new(0, 8)
				boxPad.Parent = box

				local boxStroke = Instance.new("UIStroke")
				boxStroke.Color = Theme.Violet
				boxStroke.Thickness = 1
				boxStroke.Transparency = 0.85
				boxStroke.Parent = box

				box.Focused:Connect(function() tween(boxStroke, { Transparency = 0.2 }, 0.15) end)
				box.FocusLost:Connect(function(enter)
					tween(boxStroke, { Transparency = 0.85 }, 0.15)
					if callback then callback(box.Text, enter) end
				end)

				if flag then
					flags[flag] = {
						get = function() return box.Text end,
						set = function(v) box.Text = tostring(v or "") end,
					}
				end

				return {
					Instance = holder,
					Set = function(_, v) box.Text = tostring(v or "") end,
					Get = function() return box.Text end,
				}
			end

			-- Full preset manager: name a preset, save the current value of every flagged
			-- element, then load or delete it later. Persists to disk when the environment
			-- exposes writefile/readfile, otherwise it stays for the session.
			function SectionObject:CreatePresetManager()
				order += 1

				local nameHolder = Instance.new("Frame")
				nameHolder.LayoutOrder = order
				nameHolder.BackgroundTransparency = 1
				nameHolder.Size = UDim2.new(1, 0, 0, 32)
				nameHolder.Parent = section

				local nameBox = Instance.new("TextBox")
				nameBox.Size = UDim2.new(1, -92, 1, 0)
				nameBox.BackgroundColor3 = Theme.Element
				nameBox.Font = FONT
				nameBox.TextSize = 13
				nameBox.TextColor3 = Theme.Text
				nameBox.PlaceholderText = "Preset name..."
				nameBox.PlaceholderColor3 = Theme.SubText
				nameBox.Text = ""
				nameBox.ClearTextOnFocus = false
				nameBox.TextXAlignment = Enum.TextXAlignment.Left
				nameBox.Parent = nameHolder
				corner(nameBox, 6)

				local nbPad = Instance.new("UIPadding")
				nbPad.PaddingLeft = UDim.new(0, 10)
				nbPad.PaddingRight = UDim.new(0, 10)
				nbPad.Parent = nameBox

				local nbStroke = Instance.new("UIStroke")
				nbStroke.Color = Theme.Violet
				nbStroke.Thickness = 1
				nbStroke.Transparency = 0.85
				nbStroke.Parent = nameBox
				nameBox.Focused:Connect(function() tween(nbStroke, { Transparency = 0.2 }, 0.15) end)
				nameBox.FocusLost:Connect(function() tween(nbStroke, { Transparency = 0.85 }, 0.15) end)

				local saveBtn = Instance.new("TextButton")
				saveBtn.AnchorPoint = Vector2.new(1, 0.5)
				saveBtn.Position = UDim2.new(1, 0, 0.5, 0)
				saveBtn.Size = UDim2.fromOffset(84, 32)
				saveBtn.BackgroundColor3 = Theme.Element
				saveBtn.AutoButtonColor = false
				saveBtn.Font = FONT_BOLD
				saveBtn.TextSize = 12
				saveBtn.TextColor3 = Theme.Text
				saveBtn.Text = "Save"
				saveBtn.Parent = nameHolder
				corner(saveBtn, 6)
				addPressFeel(saveBtn, 1.04)
				saveBtn.MouseEnter:Connect(function() tween(saveBtn, { BackgroundColor3 = Theme.Violet }, 0.15) end)
				saveBtn.MouseLeave:Connect(function() tween(saveBtn, { BackgroundColor3 = Theme.Element }, 0.15) end)

				order += 1
				local listHolder = Instance.new("Frame")
				listHolder.LayoutOrder = order
				listHolder.BackgroundTransparency = 1
				listHolder.Size = UDim2.new(1, 0, 0, 0)
				listHolder.AutomaticSize = Enum.AutomaticSize.Y
				listHolder.Parent = section

				local listLayout2 = Instance.new("UIListLayout")
				listLayout2.SortOrder = Enum.SortOrder.LayoutOrder
				listLayout2.Padding = UDim.new(0, 6)
				listLayout2.Parent = listHolder

				local emptyLabel = Instance.new("TextLabel")
				emptyLabel.BackgroundTransparency = 1
				emptyLabel.Size = UDim2.new(1, 0, 0, 18)
				emptyLabel.Font = FONT
				emptyLabel.TextSize = 11
				emptyLabel.TextColor3 = Theme.SubText
				emptyLabel.TextXAlignment = Enum.TextXAlignment.Left
				emptyLabel.Text = "No presets saved yet."
				emptyLabel.Parent = listHolder

				local refreshList

				local function makeRow(presetName)
					local row = Instance.new("Frame")
					row.BackgroundColor3 = Theme.Element
					row.Size = UDim2.new(1, 0, 0, 30)
					row.Parent = listHolder
					corner(row, 6)

					local rowLabel = Instance.new("TextLabel")
					rowLabel.BackgroundTransparency = 1
					rowLabel.Position = UDim2.new(0, 10, 0, 0)
					rowLabel.Size = UDim2.new(1, -130, 1, 0)
					rowLabel.Font = FONT
					rowLabel.TextSize = 12
					rowLabel.TextColor3 = Theme.Text
					rowLabel.TextXAlignment = Enum.TextXAlignment.Left
					rowLabel.TextTruncate = Enum.TextTruncate.AtEnd
					rowLabel.Text = presetName
					rowLabel.Parent = row

					local delBtn = Instance.new("TextButton")
					delBtn.AnchorPoint = Vector2.new(1, 0.5)
					delBtn.Position = UDim2.new(1, -8, 0.5, 0)
					delBtn.Size = UDim2.fromOffset(52, 22)
					delBtn.BackgroundColor3 = Theme.Section
					delBtn.AutoButtonColor = false
					delBtn.Font = FONT
					delBtn.TextSize = 11
					delBtn.TextColor3 = Theme.SubText
					delBtn.Text = "Delete"
					delBtn.Parent = row
					corner(delBtn, 5)
					addPressFeel(delBtn, 1.06)
					delBtn.MouseEnter:Connect(function() tween(delBtn, { BackgroundColor3 = Theme.Bad, TextColor3 = Theme.Text }, 0.15) end)
					delBtn.MouseLeave:Connect(function() tween(delBtn, { BackgroundColor3 = Theme.Section, TextColor3 = Theme.SubText }, 0.15) end)
					delBtn.MouseButton1Click:Connect(function()
						WindowObject:DeletePreset(presetName)
						refreshList()
					end)

					local loadBtn2 = Instance.new("TextButton")
					loadBtn2.AnchorPoint = Vector2.new(1, 0.5)
					loadBtn2.Position = UDim2.new(1, -66, 0.5, 0)
					loadBtn2.Size = UDim2.fromOffset(52, 22)
					loadBtn2.BackgroundColor3 = Theme.Section
					loadBtn2.AutoButtonColor = false
					loadBtn2.Font = FONT
					loadBtn2.TextSize = 11
					loadBtn2.TextColor3 = Theme.SubText
					loadBtn2.Text = "Load"
					loadBtn2.Parent = row
					corner(loadBtn2, 5)
					addPressFeel(loadBtn2, 1.06)
					loadBtn2.MouseEnter:Connect(function() tween(loadBtn2, { BackgroundColor3 = Theme.Violet, TextColor3 = Theme.Text }, 0.15) end)
					loadBtn2.MouseLeave:Connect(function() tween(loadBtn2, { BackgroundColor3 = Theme.Section, TextColor3 = Theme.SubText }, 0.15) end)
					loadBtn2.MouseButton1Click:Connect(function()
						WindowObject:LoadPreset(presetName)
					end)

					return row
				end

				refreshList = function()
					for _, child in ipairs(listHolder:GetChildren()) do
						if child:IsA("Frame") then child:Destroy() end
					end
					local names = WindowObject:GetPresetNames()
					emptyLabel.Visible = (#names == 0)
					for _, n in ipairs(names) do
						makeRow(n)
					end
				end

				saveBtn.MouseButton1Click:Connect(function()
					local presetName = nameBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
					if presetName == "" then
						Notify("Preset", "Give the preset a name first.", 2.5, "clipboard-list")
						return
					end
					WindowObject:SavePreset(presetName)
					nameBox.Text = ""
					refreshList()
					Notify("Preset saved", ("\"%s\" now stores %d settings."):format(presetName, WindowObject:CountFlags()), 2.5, "save")
				end)

				refreshList()

				return { Instance = nameHolder, Refresh = refreshList }
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
				return {
					Instance = label2,
					Set = function(_, newText) label2.Text = tostring(newText) end,
					Get = function() return label2.Text end,
				}
			end

			return SectionObject
		end

		return TabObject
	end

	function WindowObject:Notify(title, content, duration, icon)
		Notify(title, content, duration, icon)
	end

	-- ============ Presets ============
	-- A preset is a snapshot of every flagged element's value. Saved to disk when the
	-- environment provides file functions (executors do; a normal Roblox client does not),
	-- otherwise kept in memory for the session.

	local PRESET_FILE = "YunoHub_presets.json"
	local presets = {}

	local function fileApiAvailable()
		return type(writefile) == "function"
			and type(readfile) == "function"
			and type(isfile) == "function"
	end

	local function persistPresets()
		if not fileApiAvailable() then return end
		pcall(function()
			writefile(PRESET_FILE, HttpService:JSONEncode(presets))
		end)
	end

	local function restorePresets()
		if not fileApiAvailable() then return end
		pcall(function()
			if isfile(PRESET_FILE) then
				local decoded = HttpService:JSONDecode(readfile(PRESET_FILE))
				if type(decoded) == "table" then presets = decoded end
			end
		end)
	end
	restorePresets()

	function WindowObject:CountFlags()
		local n = 0
		for _ in pairs(flags) do n += 1 end
		return n
	end

	function WindowObject:GetConfig()
		local config = {}
		for name, entry in pairs(flags) do
			local ok, value = pcall(entry.get)
			if ok then config[name] = value end
		end
		return config
	end

	function WindowObject:LoadConfig(config)
		if type(config) ~= "table" then return end
		for name, value in pairs(config) do
			local entry = flags[name]
			if entry then pcall(entry.set, value) end
		end
	end

	function WindowObject:SavePreset(name)
		presets[name] = self:GetConfig()
		persistPresets()
	end

	function WindowObject:LoadPreset(name)
		local config = presets[name]
		if not config then
			Notify("Preset", ("\"%s\" no longer exists."):format(tostring(name)), 2.5, "clipboard-list")
			return false
		end
		self:LoadConfig(config)
		Notify("Preset loaded", ("\"%s\" has been applied."):format(name), 2.5, "wand")
		return true
	end

	function WindowObject:DeletePreset(name)
		if presets[name] == nil then return false end
		presets[name] = nil
		persistPresets()
		Notify("Preset deleted", ("\"%s\" was removed."):format(name), 2.5, "skull")
		return true
	end

	function WindowObject:GetPresetNames()
		local names = {}
		for name in pairs(presets) do table.insert(names, name) end
		table.sort(names)
		return names
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

	-- Pop-up opening animation
	Window.BackgroundTransparency = 1
	Window.Size = UDim2.fromOffset(FULL_SIZE.X.Offset * 0.85, FULL_SIZE.Y.Offset * 0.85)
	tween(Window, { BackgroundTransparency = 0, Size = FULL_SIZE }, 0.45, Enum.EasingStyle.Back)

	Overlay.Position = Overlay.Position - UDim2.fromOffset(0, -16)
	Overlay.BackgroundTransparency = 1
	tween(Overlay, { Position = UDim2.new(1, -14, 0, 14), BackgroundTransparency = 0 }, 0.4, Enum.EasingStyle.Back)

	return WindowObject
end

-- ============ CreateLoader ============
-- Shows a selection list of "instances" (other Lua/ModuleScript files) before the actual
-- hub is loaded. Each instance defines its Name / Image / Description via the Instances
-- table — see Loader.client.lua (Studio) or Bootstrap.lua (loadstring/GitHub).
--
-- Each entry supports two ways of providing the hub code:
--   entry.Module = someModuleScriptInstance   -- require()'d directly (Studio setup)
--   entry.Url    = "https://raw.githubusercontent.com/.../Hub.lua"  -- fetched + loadstring()'d
--                                                                      on click (GitHub setup)

function Library.CreateLoader(config)
	config = config or {}
	local instances = config.Instances or {}

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "YunoHubLoader"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 1000
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

	local panelScale = Instance.new("UIScale")
	panelScale.Parent = panel

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Thickness = 1.4
	panelStroke.Color = Theme.Violet
	panelStroke.Parent = panel

	-- Shared exit animation for both the close button and picking an instance.
	local function closePanel(onDone)
		tween(panelScale, { Scale = 0.85 }, 0.24, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tween(panel, { BackgroundTransparency = 1 }, 0.24)
		tween(panelStroke, { Transparency = 1 }, 0.18)
		tween(dim, { BackgroundTransparency = 1 }, 0.26)
		task.delay(0.28, function()
			screenGui:Destroy()
			if onDone then onDone() end
		end)
	end

	RunService.Heartbeat:Connect(function()
		if not panel.Parent then return end
		local hue = 0.72 + 0.13 * math.sin(os.clock() * 0.35)
		panelStroke.Color = Color3.fromHSV(hue % 1, 0.55, 1)
	end)

	-- Topbar (matches the main Window's chrome): icon + title/subtitle, draggable, closeable.
	local Topbar = Instance.new("Frame")
	Topbar.BackgroundColor3 = Theme.Topbar
	Topbar.Size = UDim2.new(1, 0, 0, 44)
	Topbar.ZIndex = 4
	Topbar.Parent = panel
	corner(Topbar, 12)

	local topbarFix = Instance.new("Frame")
	topbarFix.BackgroundColor3 = Theme.Topbar
	topbarFix.BorderSizePixel = 0
	topbarFix.Position = UDim2.new(0, 0, 1, -12)
	topbarFix.Size = UDim2.new(1, 0, 0, 12)
	topbarFix.ZIndex = 4
	topbarFix.Parent = Topbar

	local logoHolder = Instance.new("Frame")
	logoHolder.BackgroundTransparency = 1
	logoHolder.Position = UDim2.new(0, 12, 0.5, -10)
	logoHolder.Size = UDim2.fromOffset(20, 20)
	logoHolder.ZIndex = 5
	logoHolder.Parent = Topbar
	Library.GetLogo(logoHolder, 20, Theme.Cyan)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.new(0, 40, 0, 2)
	titleLabel.Size = UDim2.new(1, -80, 0, 18)
	titleLabel.Font = FONT_BOLD
	titleLabel.TextSize = 15
	titleLabel.TextColor3 = Theme.Text
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.Text = config.Title or "Yuno Hub"
	titleLabel.ZIndex = 5
	titleLabel.Parent = Topbar

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Position = UDim2.new(0, 40, 0, 20)
	subtitleLabel.Size = UDim2.new(1, -80, 0, 16)
	subtitleLabel.Font = FONT
	subtitleLabel.TextSize = 11
	subtitleLabel.TextColor3 = Theme.SubText
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	subtitleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	subtitleLabel.Text = config.Subtitle or "Select an instance to load"
	subtitleLabel.ZIndex = 5
	subtitleLabel.Parent = Topbar

	local closeBtn = Instance.new("TextButton")
	closeBtn.AnchorPoint = Vector2.new(1, 0.5)
	closeBtn.Position = UDim2.new(1, -12, 0.5, 0)
	closeBtn.Size = UDim2.fromOffset(26, 26)
	closeBtn.BackgroundTransparency = 1
	closeBtn.AutoButtonColor = false
	closeBtn.Font = FONT_BOLD
	closeBtn.TextSize = 14
	closeBtn.TextColor3 = Theme.SubText
	closeBtn.Text = "\195\151"
	closeBtn.ZIndex = 5
	closeBtn.Parent = Topbar
	addPressFeel(closeBtn, 1.15)
	closeBtn.MouseEnter:Connect(function() tween(closeBtn, { TextColor3 = Theme.Bad }, 0.15) end)
	closeBtn.MouseLeave:Connect(function() tween(closeBtn, { TextColor3 = Theme.SubText }, 0.15) end)
	closeBtn.MouseButton1Click:Connect(function()
		closePanel()
	end)

	makeDraggable(Topbar, panel)

	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.new(0, 16, 0, 56)
	list.Size = UDim2.new(1, -32, 1, -72)
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
		loadBtn.Text = "Load"
		loadBtn.ZIndex = 5
		loadBtn.Parent = card
		corner(loadBtn, 8)
		addPressFeel(loadBtn, 1.06)

		loadBtn.MouseEnter:Connect(function() tween(loadBtn, { BackgroundColor3 = Theme.Violet }, 0.15) end)
		loadBtn.MouseLeave:Connect(function() tween(loadBtn, { BackgroundColor3 = Theme.Element }, 0.15) end)

		loadBtn.MouseButton1Click:Connect(function()
			if not entry.Module and not entry.Url then
				warn("[YunoHub] This instance has no Module or Url set: " .. tostring(entry.Name))
				return
			end

			loadBtn.Text = entry.Url and "..." or "Load"
			closePanel(function()
				local ok, err = pcall(function()
					local initFn
					if entry.Module then
						-- Studio setup: the hub is a ModuleScript instance already in the game
						initFn = require(entry.Module)
					else
						-- loadstring/GitHub setup: fetch the hub's source and run it as a chunk.
						-- Works because Hub files end in `return function(Library) ... end`,
						-- exactly like a ModuleScript would.
						local source = game:HttpGet(entry.Url)
						initFn = loadstring(source)()
					end
					initFn(Library)
				end)
				if not ok then
					warn("[YunoHub] Failed to load '" .. tostring(entry.Name) .. "': " .. tostring(err))
				end
			end)
		end)
	end

	-- Pop-up opening animation
	panelScale.Scale = 0.85
	panelStroke.Transparency = 1
	tween(panelScale, { Scale = 1 }, 0.45, Enum.EasingStyle.Back)
	tween(panel, { BackgroundTransparency = 0 }, 0.3)
	tween(panelStroke, { Transparency = 0 }, 0.4)

	-- Cards stagger in behind the panel so the list reads as assembling itself.
	for i, card in ipairs(list:GetChildren()) do
		if card:IsA("Frame") then
			local cardScale = Instance.new("UIScale")
			cardScale.Scale = 0.92
			cardScale.Parent = card
			card.BackgroundTransparency = 1
			task.delay(0.08 + (i * 0.05), function()
				tween(cardScale, { Scale = 1 }, 0.4, Enum.EasingStyle.Back)
				tween(card, { BackgroundTransparency = 0 }, 0.28)
			end)
		end
	end

	return screenGui
end

return Library
