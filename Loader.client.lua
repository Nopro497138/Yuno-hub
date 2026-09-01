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
]]

local Library = require(script.Parent:WaitForChild("YunoHubLibrary"))

local Hubs = script.Parent:WaitForChild("Hubs")

local Instances = {
{
		Name = "STAY INSIDE",
		Image = "rbxassetid://77009249529372",
		Description = "Script for STAY INSIDE, has autofarm, ESP and more!",
		Module = Hubs:WaitForChild("StayInside"),
	},
	{
		Name = "BONK & BLOCK",
		Image = "rbxassetid://97173577563395",
		Description = "Script for BONK & BLOCK! Has ESP, Aimbot and more!",
		Module = Hubs:WaitForChild("BonkBlock"),
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
