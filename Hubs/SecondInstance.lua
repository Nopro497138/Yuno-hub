--[[
	Hubs/SecondInstance.lua  (ModuleScript)

	Minimales zweites Beispiel, um zu zeigen, wie einfach eine weitere Instanz ist: eine
	Datei, eine Funktion, eigenes Fenster + eigene Tabs. Einfach kopieren, umbenennen und
	in Loader.client.lua referenzieren, um dein eigenes Hub hinzuzufügen.
]]

return function(Library)
	local Window = Library.CreateWindow({
		Title = "Zweite Instanz",
		Subtitle = "Minimal-Beispiel",
	})

	local mainTab = Window:CreateTab("Main", "skull")
	local section = mainTab:CreateSection("Beispiel-Elemente")
	section:CreateLabel("Das hier ist ein komplett unabhängiges zweites Hub.")
	section:CreateButton("Test-Button", function()
		Window:Notify("Zweite Instanz", "Button wurde geklickt.", 2.5)
	end)
	section:CreateToggle("Beispiel-Toggle", false, nil)
	section:CreateSlider("Beispiel-Slider", 0, 10, 5, nil)

	return Window
end
