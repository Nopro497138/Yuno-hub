--[[
	Hubs/SecondInstance.lua  (ModuleScript, or a raw file fetched via loadstring/GitHub)

	Minimal second example to show how easy another instance is: one file, one function, its
	own window and tabs. Copy it, rename it, and reference it in Loader.client.lua (or
	Bootstrap.lua) to add your own hub.
]]

return function(Library)
	local Window = Library.CreateWindow({
		Title = "Second Instance",
		Subtitle = "Minimal example",
	})

	local mainTab = Window:CreateTab("Main", "skull")
	local section = mainTab:CreateSection("Example Elements")
	section:CreateLabel("This is a completely independent second hub.")
	section:CreateButton("Test button", function()
		Window:Notify("Second Instance", "Button was clicked.", 2.5)
	end)
	section:CreateToggle("Example toggle", false, nil)
	section:CreateSlider("Example slider", 0, 10, 5, nil)

	return Window
end
