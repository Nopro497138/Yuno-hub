--[[
	Bootstrap.lua

	This is the single file you point a "loadstring + GitHub" one-liner at, e.g.:

		loadstring(game:HttpGet("https://raw.githubusercontent.com/<user>/<repo>/main/Bootstrap.lua"))()

	Loading order: this script fetches YunoHubLibrary.lua and immediately opens the loader
	screen (with all its stars/glow/animations already running) — the actual Hub file is only
	fetched and executed once you click "Load" on its card, exactly like the Studio setup.

	Note: `loadstring` is disabled by default in real, live Roblox game clients/servers — it
	only works in environments that provide their own (an executor, for example). If you paste
	this into a normal Script/LocalScript inside your own published game, it will error with
	something like "loadstring is not enabled". For a normal game, use Loader.client.lua +
	actual ModuleScript instances in Studio instead (see README.md).

	Before this works you need to:
	  1. Push this whole folder to a public GitHub repo.
	  2. Set RAW_BASE below to your repo's raw.githubusercontent.com base URL.
]]

local RAW_BASE = "https://raw.githubusercontent.com/Nopro497138/Yuno-hub/main/"

local function fetchLibrary()
	local source = game:HttpGet(RAW_BASE .. "YunoHubLibrary.lua")
	return loadstring(source)()
end

local Library = fetchLibrary()

local Instances = {
	{
		Name = "Yuno Hub",
		Image = "sparkles",
		Description = "The main hub with Home, Presets, Stats and Settings.",
		Url = RAW_BASE .. "Hubs/YunoHub.lua",
	},
	{
		Name = "Second Instance",
		Image = "skull",
		Description = "Example of a second, independent hub in the same selection list.",
		Url = RAW_BASE .. "Hubs/SecondInstance.lua",
	},
	-- Add your own instances here:
	-- {
	-- 	Name = "My Hub",
	-- 	Image = "rocket", -- or "rbxassetid://123456789"
	-- 	Description = "Short description of what this hub does.",
	-- 	Url = RAW_BASE .. "Hubs/MyHub.lua",
	-- },
}

Library.CreateLoader({
	Title = "Yuno Hub",
	Subtitle = "Select an instance to load",
	Instances = Instances,
})
