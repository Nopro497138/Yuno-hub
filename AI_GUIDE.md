# Yuno Hub Library — AI Usage Guide

This document is written for an AI assistant that needs to write Lua code using
`YunoHubLibrary.lua`. It describes the full public API, exact call signatures, and the
conventions the library expects. Read this before generating any hub code.

## What this library is

A Rayfield-style Roblox UI library ("galaxy" dark theme: violet/magenta/cyan accents,
starfield background). It provides two entry points and a fluent builder API:

- `Library.CreateLoader(config)` — an instance-picker screen shown before any hub loads.
- `Library.CreateWindow(opts)` — the actual hub window, with `Window:CreateTab(...)` →
  `Tab:CreateSection(...)` → `Section:CreateButton/Toggle/Slider/Dropdown/...(...)`.

You almost always write a **hub file**, not changes to the library itself. A hub file is a
`.lua` file (ModuleScript in Studio, or a raw file fetched via `loadstring`+GitHub) that
returns exactly one function:

```lua
return function(Library)
    local Window = Library.CreateWindow({ Title = "My Hub", Subtitle = "v1.0" })
    local tab = Window:CreateTab("Home", "home")
    local section = tab:CreateSection("Main")
    section:CreateButton("Click me", function()
        Window:Notify("Hi", "Button clicked", 2.5, "sparkles")
    end)
    return Window -- optional, but return it if the caller might want it
end
```

This function is the ONLY thing a hub file should return. Do not call `Library.CreateWindow`
at the top level of a module outside this function — the loader calls this function itself
when the user picks that hub from the list, so the window must not be built before that.

## Getting a `Library` reference

Two ways, both give you the exact same table:

```lua
-- Studio: the library is a ModuleScript instance somewhere in the game
local Library = require(pathToModuleScript)

-- loadstring/GitHub (executor-only; loadstring is disabled in real live games):
local Library = loadstring(game:HttpGet(rawGithubUrlToLibraryLua))()
```

If you're writing a hub file, you never do this yourself — the loader hands you the
`Library` table as the parameter of the function your hub file returns.

## `Library.CreateWindow(opts) -> Window`

```lua
local Window = Library.CreateWindow({
    Title = "Yuno Hub",           -- optional, defaults to "Yuno Hub"
    Subtitle = "v1.0 · galaxy theme", -- optional
})
```

Builds and shows the window immediately (with a pop-in animation). Returns a `Window`
object (see below). Calling this creates a brand new `ScreenGui` — call it once per hub.

## Window methods

| Method | Signature | Notes |
|---|---|---|
| `Window:CreateTab` | `(name: string, iconName: string?) -> Tab` | `iconName` is a key into `Library.IconAssets` (see Icons section). Defaults to `"sparkles"`. First tab created is shown by default. |
| `Window:Notify` | `(title: string, content: string, duration: number?, icon: string?) -> ()` | Toast in the bottom-right. `duration` defaults to `3.5`. `icon` is optional; when given, a small round badge with that icon appears next to the text. |
| `Window:SetVisible` | `(visible: boolean) -> ()` | Animated show/hide. When hidden, a small "launcher orb" appears so the user can bring it back. Also bound to the `RightShift` key automatically. |
| `Window:Unload` | `() -> ()` | Animates the whole UI away and destroys the ScreenGui. Irreversible without re-running the hub. |
| `Window:GetConfig` | `() -> table<string, any>` | Snapshot of every flagged element's current value (see Presets). |
| `Window:LoadConfig` | `(config: table<string, any>) -> ()` | Applies a snapshot produced by `GetConfig`. |
| `Window:SavePreset` | `(name: string) -> ()` | Snapshots the current config under `name`. |
| `Window:LoadPreset` | `(name: string) -> boolean` | Re-applies a saved preset. Returns `false` and notifies if it doesn't exist. |
| `Window:DeletePreset` | `(name: string) -> boolean` | Removes a saved preset. |
| `Window:GetPresetNames` | `() -> string[]` | Sorted list of saved preset names. |
| `Window:CountFlags` | `() -> number` | How many elements currently have a flag registered. |

## `Tab:CreateSection(name, infoText?) -> Section`

A section is a rounded card inside a tab's scroll area, with a bold header and an optional
one-line description below it.

```lua
local section = tab:CreateSection("Combat", "Options that affect PvP.")
```

All `Section:Create*` calls below append an element to that card, top to bottom, in call
order. There's no manual layout to manage.

## Section element methods

Every one of these returns a **handle**, not a raw Roblox Instance:

```lua
{
    Instance = <the underlying GuiObject/Frame>,
    Set = function(self, value) ... end,   -- update the element's value programmatically
    Get = function() return value end,     -- read the current value
}
```

Use `handle:Set(x)` / `handle:Get()` for post-creation updates; use `handle.Instance` only
if you need to touch the raw Roblox object directly (rare).

### `Section:CreateButton(text, callback) -> handle`

```lua
section:CreateButton("Teleport to spawn", function()
    -- your logic here
end)
```

`handle:Set(newText)` renames the button; `handle:Get()` returns its current text.

### `Section:CreateToggle(text, default, callback, flag?) -> handle`

```lua
section:CreateToggle("Auto-Farm", false, function(state: boolean)
    -- state is true/false
end, "autoFarm")
```

`handle:Set(true/false)` flips it (fires the callback). `handle:Get()` returns the boolean.

### `Section:CreateSlider(text, min, max, default, callback, flag?) -> handle`

```lua
section:CreateSlider("Speed", 0, 100, 50, function(value: number)
    -- value is an integer between min and max
end, "speed")
```

Values are always rounded to the nearest integer. `handle:Set(n)` animates the fill to `n`
and fires the callback; `handle:Get()` returns the current integer value.

### `Section:CreateDropdown(text, options, default, callback, flag?) -> handle`

```lua
section:CreateDropdown("Mode", { "Easy", "Normal", "Hard" }, "Normal", function(choice: string)
    -- choice is one of the strings in `options`
end, "difficulty")
```

`handle:Set(optionString)` selects it (must be a member of the original `options` list,
otherwise it's ignored). `handle:Get()` returns the selected string.

### `Section:CreateInput(text, placeholder?, callback?, flag?) -> handle`

A labeled text box.

```lua
section:CreateInput("Webhook URL", "https://...", function(text: string, enterPressed: boolean)
    -- fires on focus lost; enterPressed is true if they hit Enter
end, "webhookUrl")
```

`handle:Set(text)` sets the box contents without firing the callback. `handle:Get()`
returns the current text.

### `Section:CreateProgressBar(text, percent, note?) -> handle`

A non-interactive animated bar (violet→cyan gradient fill, soft shimmer sweep).

```lua
local xpBar = section:CreateProgressBar("Level XP", 68, "1,360 / 2,000")
-- later:
xpBar:Set(90, "1,800 / 2,000") -- note is optional on Set too; pass nil to leave it unchanged
```

`percent` is clamped to `0..100`. `handle:Get()` returns the current percent (number).

### `Section:CreateLabel(text) -> handle`

Plain wrapped text line, no interaction, muted color. `handle:Set(text)` /
`handle:Get()` work like the other elements.

### `Section:CreatePresetManager() -> { Instance, Refresh }`

Drops in a ready-made preset UI: a name box + Save button, and a list of saved presets each
with Load/Delete buttons. Call this once per hub, usually in its own tab/section:

```lua
local presetsTab = Window:CreateTab("Presets", "sparkles")
local section = presetsTab:CreateSection("Your Presets", "Save your current settings.")
section:CreatePresetManager()
```

It reads and writes through the same `Window:SavePreset/LoadPreset/DeletePreset` API
described above — you don't need to wire anything else up. It just needs at least one
flagged element elsewhere in the hub to have something worth saving.

## The flag system (how presets actually work)

`flag` is the optional last argument on `CreateToggle`, `CreateSlider`, `CreateDropdown`,
and `CreateInput`. Passing a flag registers that element's get/set pair under that name in
the window's internal flag table. `Window:GetConfig()` returns `{ [flag] = value, ... }` for
every flagged element; `Window:SavePreset(name)` stores exactly that table.

Rules to follow:
- Flags must be unique per window. Reusing a flag name on a second element makes the
  second one silently overwrite the first in the flag table.
- Only give an element a flag if it should be affected by presets. Purely cosmetic or
  one-shot elements (buttons, labels, progress bars) don't take a flag at all — they
  aren't meant to be "restored."
- Flag values round-trip through `HttpService:JSONEncode/JSONDecode` when persisted to
  disk, so only use JSON-safe values: booleans, numbers, strings. Don't expect Vector3,
  Color3, etc. to survive a save/load cycle as-is.

## Icons

`iconName` / `icon` parameters (tab icons, `Window:Notify`'s icon, loader card images) take
a string key into `Library.IconAssets`. The current built-in set (35 names):

```
home, settings, sparkles, bar-chart, eye, power, skull, crosshair, shield, sword, zap,
gift, trophy, bell, lock, flame, gem, package, user, rocket, crown, coins, key, wrench,
map, heart, moon, battery, save, clipboard-list, dice, wand, layers, ghost, medal
```

If an icon name has no asset uploaded yet, it renders as a clean circle + first-letter
monogram automatically — this is expected behavior, not a bug, so don't treat a monogram
as something to "fix" in code. Never invent a new icon name and expect it to render
something meaningful; unknown names just show their first letter.

`Library.Logo` (a single `rbxassetid://...` string, full color, not tinted) is the
branding mark shown in the loader topbar, window topbar, and launcher orb. It's set once
at the library level, not per-hub — don't try to set it from inside a hub file.

## `Library.CreateLoader(config)` — only relevant if you're building the entry point, not a hub

```lua
Library.CreateLoader({
    Title = "Yuno Hub",
    Subtitle = "Select an instance to load",
    Instances = {
        {
            Name = "My Hub",
            Image = "rocket",              -- an icon name, OR a direct "rbxassetid://..."
            Description = "One line about what this hub does.",
            Module = someModuleScriptInstance,  -- Studio setup: require()'d on click
            -- Url = "https://raw.githubusercontent.com/.../MyHub.lua", -- GitHub setup instead
        },
        -- more entries...
    },
})
```

Each entry needs exactly one of `Module` (a ModuleScript instance) or `Url` (a raw file
URL). The referenced code must return `function(Library) ... end`, exactly like a hub file
described above. Never give an entry both or neither.

### Auto-loading (skipping the picker)

An entry with `AutoLoad = { PlaceIds = { 123456789 } }` bypasses the picker screen entirely:
`CreateLoader` checks `game.PlaceId` against every entry's `AutoLoad.PlaceIds` before it
renders anything, and if one matches, that hub is built immediately with no loader UI ever
shown. `PlaceIds` accepts either a single number or a table of numbers. Only add this to the
one entry that should launch automatically for a given place — entries without `AutoLoad`
are unaffected and still show up normally in the picker for every other place.

## Things to never do

- Don't call `Library.CreateWindow` more than once per hub — one hub, one window.
- Don't mutate `Library.IconAssets` or `Library.Theme` from inside a hub file; those are
  library-level configuration, not per-hub state.
- Don't hold onto a `Section`/`Tab`/`Window` reference across a `Window:Unload()` call and
  keep calling methods on it — the ScreenGui is destroyed and everything under it is gone.
- Don't assume `writefile`/`readfile`/`isfile` exist — they only do in executor
  environments. The library already checks for them before persisting presets; don't add
  your own file I/O in hub code without the same guard.
- Don't build UI directly with `Instance.new` inside a hub file when a library method
  covers it — use `Section:Create*` so the hub stays visually consistent with the rest of
  the library.
