--[[
	Loader.client.lua  (LocalScript)

	Zeigt zuerst eine Auswahl-Liste ("welche Instanz willst du laden?"), bevor der eigentliche
	Hub gebaut wird. Neue Hubs fügst du einfach unten in der Instances-Tabelle hinzu — Name,
	Bild und Beschreibung sind frei wählbar, Module verweist auf dein eigenes ModuleScript
	(das intern die YunoHubLibrary benutzt, um Tabs/Buttons/Slider usw. zu bauen).

	Erwartete Struktur in Studio (z.B. unter StarterPlayerScripts):
		StarterPlayerScripts/
			Loader (LocalScript)              <- diese Datei
			YunoHubLibrary (ModuleScript)      <- YunoHubLibrary.lua
			Hubs (Folder)
				YunoHub (ModuleScript)         <- Hubs/YunoHub.lua
				SecondInstance (ModuleScript)  <- Hubs/SecondInstance.lua

	Image-Feld pro Instanz: entweder ein Icon-Name aus YunoHubLibrary.IconAssets
	(z.B. "rocket", "skull", "shield" ...) für den Monogramm-/Icon-Platzhalter, oder direkt
	eine eigene "rbxassetid://..." falls du schon ein hochgeladenes Bild hast.
]]

local Library = require(script.Parent:WaitForChild("YunoHubLibrary"))

local Hubs = script.Parent:WaitForChild("Hubs")

local Instances = {
	{
		Name = "Yuno Hub",
		Image = "sparkles",
		Description = "Das Haupt-Hub mit Home, Presets, Stats und Settings.",
		Module = Hubs:WaitForChild("YunoHub"),
	},
	{
		Name = "Zweite Instanz",
		Image = "skull",
		Description = "Beispiel für ein zweites, unabhängiges Hub in derselben Auswahl.",
		Module = Hubs:WaitForChild("SecondInstance"),
	},
	-- Weitere eigene Instanzen einfach hier ergänzen:
	-- {
	-- 	Name = "Mein Hub",
	-- 	Image = "rocket", -- oder "rbxassetid://123456789"
	-- 	Description = "Kurze Beschreibung, was dieses Hub macht.",
	-- 	Module = Hubs:WaitForChild("MeinHub"),
	-- },
}

Library.CreateLoader({
	Title = "Yuno Hub",
	Subtitle = "Wähle eine Instanz zum Laden",
	Instances = Instances,
})
