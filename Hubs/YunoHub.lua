--[[
	Hubs/YunoHub.lua  (ModuleScript)

	Beispiel-Hub, das die YunoHubLibrary benutzt. Gibt eine einzige Funktion zurück, die der
	Loader mit der Library aufruft — darin baust du dein Fenster genau wie bei Rayfield:
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

	local welcomeSection = homeTab:CreateSection("Willkommen, " .. player.DisplayName, "Kleine Info-Übersicht für diese Session.")
	welcomeSection:CreateLabel(("Server-Zeit: %s"):format(os.date("%H:%M:%S")))
	welcomeSection:CreateLabel(("Place-ID: %d"):format(game.PlaceId))
	welcomeSection:CreateButton("Sag Hallo", function()
		Window:Notify("Hallo!", player.DisplayName .. ", schön dich zu sehen.", 3)
	end)

	local quickSection = homeTab:CreateSection("Schnellzugriff")
	quickSection:CreateToggle("Auto-Farm", false, function(state)
		Window:Notify("Auto-Farm", state and "Aktiviert" or "Deaktiviert", 2.5)
	end)
	quickSection:CreateSlider("Geschwindigkeit", 0, 100, 50, nil)

	-- ===== Presets =====
	local presetsTab = Window:CreateTab("Presets", "sparkles")
	local presetSection = presetsTab:CreateSection("Gespeicherte Presets", "Wähle eine Konfiguration, um sie sofort zu laden.")
	for _, presetName in ipairs({ "Speedrun", "Farming", "PvP" }) do
		presetSection:CreateButton("Preset laden: " .. presetName, function()
			Window:Notify("Preset geladen", presetName .. " wurde angewendet.", 2.5)
		end)
	end

	-- ===== Stats =====
	local statsTab = Window:CreateTab("Stats", "bar-chart")
	local progressSection = statsTab:CreateSection("Fortschritt")
	progressSection:CreateProgressBar("Level-XP", 68, "1 360 / 2 000")
	progressSection:CreateProgressBar("Energie", 42)
	progressSection:CreateProgressBar("Ruf bei Fraktion", 90, "Fast maximal")

	-- ===== Settings =====
	local settingsTab = Window:CreateTab("Settings", "settings")
	local uiSection = settingsTab:CreateSection("Oberfläche")
	uiSection:CreateToggle("UI-Sounds", true, nil)
	uiSection:CreateDropdown("Akzentfarbe", { "Violett", "Magenta", "Cyan" }, "Violett", nil)
	uiSection:CreateLabel("Tipp: RightShift oder der Launcher-Orb blenden das Fenster ein/aus.")

	local dangerSection = settingsTab:CreateSection("Danger Zone", "Diese Aktion kann nicht rückgängig gemacht werden.")
	dangerSection:CreateButton("Komplett unloaden", function()
		Window:Unload()
	end)

	return Window
end
