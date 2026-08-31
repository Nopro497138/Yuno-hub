--[[
	Hubs/YunoHub.lua  (ModuleScript, or a raw file fetched via loadstring/GitHub)

	Example hub that uses YunoHubLibrary. Returns a single function that the loader calls
	with the Library — inside it you build your window exactly like with Rayfield:
	Window:CreateTab(...) -> Tab:CreateSection(...) -> Section:CreateButton/Toggle/Slider/...

	Note the last argument on toggles/sliders/dropdowns: that is the element's *flag*. Any
	element given a flag is included in presets automatically, so "save/load preset" works
	without you wiring anything up per element.
]]

return function(Library)
	local Players = game:GetService("Players")
	local player = Players.LocalPlayer

	local Window = Library.CreateWindow({
		Title = "Yuno Hub",
		Subtitle = "v1.0 · galaxy theme",
	})

	-- ===== Home =====
	local homeTab = Window:CreateTab("Home", "home")

	local welcomeSection = homeTab:CreateSection("Welcome, " .. player.DisplayName, "A quick info overview for this session.")
	welcomeSection:CreateLabel(("Server time: %s"):format(os.date("%H:%M:%S")))
	welcomeSection:CreateLabel(("Place ID: %d"):format(game.PlaceId))
	welcomeSection:CreateButton("Say hi", function()
		Window:Notify("Hi!", "Good to see you, " .. player.DisplayName .. ".", 3, "sparkles")
	end)

	local quickSection = homeTab:CreateSection("Quick Access")
	quickSection:CreateToggle("Auto-Farm", false, function(state)
		Window:Notify("Auto-Farm", state and "Enabled" or "Disabled", 2.5, "zap")
	end, "autoFarm")
	quickSection:CreateSlider("Speed", 0, 100, 50, nil, "speed")
	quickSection:CreateSlider("Jump Power", 0, 200, 50, nil, "jumpPower")
	quickSection:CreateToggle("Infinite Jump", false, nil, "infiniteJump")

	-- ===== Presets =====
	local presetsTab = Window:CreateTab("Presets", "sparkles")

	local presetSection = presetsTab:CreateSection(
		"Your Presets",
		"Type a name and hit Save to capture every setting in this hub. Load re-applies it."
	)
	presetSection:CreatePresetManager()

	local presetInfo = presetsTab:CreateSection("How it works")
	presetInfo:CreateLabel("A preset stores every toggle, slider and dropdown that has a flag.")
	presetInfo:CreateLabel("Presets persist between sessions when your executor supports writefile.")

	-- ===== Stats =====
	local statsTab = Window:CreateTab("Stats", "bar-chart")
	local progressSection = statsTab:CreateSection("Progress")
	local xpBar = progressSection:CreateProgressBar("Level XP", 68, "1,360 / 2,000")
	progressSection:CreateProgressBar("Energy", 42)
	progressSection:CreateProgressBar("Faction Reputation", 90, "Almost maxed")

	local demoSection = statsTab:CreateSection("Live demo", "Progress bars can be updated at runtime.")
	demoSection:CreateButton("Randomise Level XP", function()
		local pct = math.random(0, 100)
		xpBar:Set(pct, ("%d / 2,000"):format(math.floor(pct / 100 * 2000)))
	end)

	-- ===== Settings =====
	local settingsTab = Window:CreateTab("Settings", "settings")
	local uiSection = settingsTab:CreateSection("Interface")
	uiSection:CreateToggle("UI Sounds", true, nil, "uiSounds")
	uiSection:CreateDropdown("Accent Color", { "Violet", "Magenta", "Cyan" }, "Violet", nil, "accent")
	uiSection:CreateLabel("Tip: RightShift or the launcher orb toggle the window on/off.")

	local dangerSection = settingsTab:CreateSection("Danger Zone", "This action cannot be undone.")
	dangerSection:CreateButton("Fully unload", function()
		Window:Unload()
	end)

	return Window
end
