--[[
	Hubs/YunoHub.lua  (ModuleScript, or a raw file fetched via loadstring/GitHub)

	Example hub that uses YunoHubLibrary. Returns a single function that the loader calls
	with the Library — inside it you build your window exactly like with Rayfield:
	Window:CreateTab(...) -> Tab:CreateSection(...) -> Section:CreateButton/Toggle/Slider/...
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
	end)
	quickSection:CreateSlider("Speed", 0, 100, 50, nil)

	-- ===== Presets =====
	local presetsTab = Window:CreateTab("Presets", "sparkles")
	local presetSection = presetsTab:CreateSection("Saved Presets", "Pick a configuration to apply it instantly.")
	for _, presetName in ipairs({ "Speedrun", "Farming", "PvP" }) do
		presetSection:CreateButton("Load preset: " .. presetName, function()
			Window:Notify("Preset loaded", presetName .. " has been applied.", 2.5, "wand")
		end)
	end

	-- ===== Stats =====
	local statsTab = Window:CreateTab("Stats", "bar-chart")
	local progressSection = statsTab:CreateSection("Progress")
	progressSection:CreateProgressBar("Level XP", 68, "1,360 / 2,000")
	progressSection:CreateProgressBar("Energy", 42)
	progressSection:CreateProgressBar("Faction Reputation", 90, "Almost maxed")

	-- ===== Settings =====
	local settingsTab = Window:CreateTab("Settings", "settings")
	local uiSection = settingsTab:CreateSection("Interface")
	uiSection:CreateToggle("UI Sounds", true, nil)
	uiSection:CreateDropdown("Accent Color", { "Violet", "Magenta", "Cyan" }, "Violet", nil)
	uiSection:CreateLabel("Tip: RightShift or the launcher orb toggle the window on/off.")

	local dangerSection = settingsTab:CreateSection("Danger Zone", "This action cannot be undone.")
	dangerSection:CreateButton("Fully unload", function()
		Window:Unload()
	end)

	return Window
end
