--[[
	Loader.client.lua  (LocalScript)

	Studio setup: shows the instance-selection screen first ("which instance do you want to
	load?") before the actual hub is built. Add new hubs by adding an entry to the Instances
	table below — Name, Image and Description are all freely chosen, Module points at your
	own ModuleScript (which internally uses YunoHubLibrary to build tabs/buttons/sliders/etc).

	If you instead want the "loadstring + GitHub" one-liner workflow (e.g. for pasting into
	an executor), use Bootstrap.lua instead — same Library and Hub files, no Studio hierarchy
	required.

	Expected structure in Studio (e.g. under StarterPlayerScripts):
		StarterPlayerScripts/
			Loader (LocalScript)              <- this file
			YunoHubLibrary (ModuleScript)      <- YunoHubLibrary.lua
			Hubs (Folder)
				YunoHub (ModuleScript)         <- Hubs/YunoHub.lua
				SecondInstance (ModuleScript)  <- Hubs/SecondInstance.lua

	Image field per instance: either an icon name from YunoHubLibrary.IconAssets
	(e.g. "rocket", "skull", "shield" ...) for the monogram/icon placeholder, or a direct
	"rbxassetid://..." if you already have an uploaded image.

	Auto-load: give an entry `AutoLoad = { PlaceIds = { 123456789 } }` to skip this picker
	entirely and boot straight into that hub whenever a player is in one of those places —
	e.g. so your hub launches immediately when someone joins your own game, with the loader
	screen never shown at all. Leave it out for entries you want to keep picking manually.
]]

local Library = require(script.Parent:WaitForChild("YunoHubLibrary"))

local Hubs = script.Parent:WaitForChild("Hubs")

local Instances = {
	{
		Name = "Yuno Hub",
		Image = "sparkles",
		Description = "The main hub with Home, Presets, Stats and Settings.",
		Module = Hubs:WaitForChild("YunoHub"),
		-- AutoLoad = { PlaceIds = { 123456789 } }, -- uncomment + fill in to auto-launch this one
	},
	{
		Name = "Second Instance",
		Image = "skull",
		Description = "Example of a second, independent hub in the same selection list.",
		Module = Hubs:WaitForChild("SecondInstance"),
	},
	-- Add your own instances here:
	-- {
	-- 	Name = "My Hub",
	-- 	Image = "rocket", -- or "rbxassetid://123456789"
	-- 	Description = "Short description of what this hub does.",
	-- 	Module = Hubs:WaitForChild("MyHub"),
	-- },
}

Library.CreateLoader({
	Title = "Yuno Hub",
	Subtitle = "Select an instance to load",
	Instances = Instances,
})
