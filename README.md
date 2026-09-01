# Yuno Hub

Galaxy-style Roblox UI library (Rayfield-like): a loader selection screen before the actual
hub, then a window with tabs/sections/buttons/toggles/sliders/dropdowns.

## Files

- `YunoHubLibrary.lua` — the reusable library. Contains the theme, icon system,
  `CreateLoader`, `CreateWindow`. Works both as a Roblox ModuleScript (`require(...)`) and as
  a raw chunk loaded via `loadstring(game:HttpGet(url))()` — same file, no changes needed.
- `Loader.client.lua` — entry point for the **Studio setup**: put this as a LocalScript next
  to the library and a `Hubs` folder of ModuleScripts (see below).
- `Bootstrap.lua` — entry point for the **loadstring/GitHub setup**: point a single
  `loadstring(game:HttpGet("..."))()` line at this file once it's pushed to your repo.
- `Hubs/YunoHub.lua`, `Hubs/SecondInstance.lua` — example hubs. Each file returns
  `function(Library) ... end` and builds its own window inside — this works unchanged whether
  it's `require()`'d (Studio) or fetched + `loadstring()`'d (GitHub).
- `icons/*.png` — 35 icon presets: home, settings, sparkles, bar-chart, eye, power, skull,
  crosshair, shield, sword, zap, gift, trophy, bell, lock, flame, gem, package, user, rocket,
  crown, coins, key, wrench, map, heart, moon, battery, save, clipboard-list, dice, wand,
  layers, ghost, medal — 256x256, white on transparent, ready to upload as Roblox Decals.

## Two ways to load it

### A) Studio setup (ModuleScript instances)

Under e.g. `StarterPlayerScripts`:

```
StarterPlayerScripts/
    Loader (LocalScript)              <- Loader.client.lua
    YunoHubLibrary (ModuleScript)     <- YunoHubLibrary.lua
    Hubs (Folder)
        YunoHub (ModuleScript)        <- Hubs/YunoHub.lua
        SecondInstance (ModuleScript) <- Hubs/SecondInstance.lua
```

Add your own hub: create a new ModuleScript in `Hubs` (same shape as
`Hubs/SecondInstance.lua`), then add an entry to `Instances` in `Loader.client.lua` pointing
`Module` at it.

### B) loadstring + GitHub setup

1. Push this whole folder to a public GitHub repo.
2. In `Bootstrap.lua`, set `RAW_BASE` to your repo's raw URL, e.g.
   `"https://raw.githubusercontent.com/yourname/yourrepo/main/"`.
3. Run (in whatever environment provides `loadstring`, e.g. an executor):
   ```lua
   loadstring(game:HttpGet("https://raw.githubusercontent.com/yourname/yourrepo/main/Bootstrap.lua"))()
   ```
   This fetches the library and opens the loader screen immediately; each hub's own code is
   only fetched when you click "Load" on its card — so the loader really does load first,
   the hub second, exactly in that order.
4. Add your own hub: add a new `Hubs/MyHub.lua` file to the repo (same shape as
   `Hubs/SecondInstance.lua`), then add an entry to `Instances` in `Bootstrap.lua` with
   `Url = RAW_BASE .. "Hubs/MyHub.lua"` instead of `Module`.

Note: `loadstring` is disabled by default in real, live Roblox game clients/servers — this
path only works in an environment that provides its own `loadstring` (an executor). Inside a
normal published game, use setup A instead.

## Adding images in the loader

Each entry in the `Instances` table has an `Image` field — that's the picture/icon shown on
its card in the loader. It accepts two kinds of value:

- **An icon name** from `YunoHubLibrary.IconAssets` (`"home"`, `"rocket"`, `"skull"`,
  `"shield"`, `"sword"`, `"crosshair"`, ... see the list at the top of `YunoHubLibrary.lua`).
  This uses the library's built-in icon system — a clean circle + letter placeholder until
  you upload a real asset (see "Making icons real" below), after which it automatically shows
  the uploaded picture instead.
- **A direct `"rbxassetid://..."` string** — use this for a custom, per-hub thumbnail that
  isn't one of the 35 presets (e.g. your own logo or banner art). Just upload any image as a
  Decal in Studio (Asset Manager → right-click → Upload, or via roblox.com/create) and paste
  the resulting `rbxassetid://<id>` directly as the `Image` value:
  ```lua
  {
      Name = "My Hub",
      Image = "rbxassetid://123456789",
      Description = "...",
      Module = Hubs.MyHub, -- or Url = RAW_BASE .. "Hubs/MyHub.lua"
  },
  ```

## Auto-loading a hub on join

Add `AutoLoad = { PlaceIds = { ... } }` to an instance entry to skip the picker screen
entirely for that game — the moment `Library.CreateLoader` runs, it checks the current
`game.PlaceId` against every entry's `AutoLoad.PlaceIds`, and if one matches, that hub is
built immediately with no loader UI ever shown:

```lua
{
    Name = "My Hub",
    Image = "rocket",
    Description = "...",
    Module = Hubs.MyHub,
    AutoLoad = { PlaceIds = { 123456789, 987654321 } }, -- your game's place ID(s)
},
```

Entries without `AutoLoad` behave exactly as before — you only need this on the one entry
you want to launch automatically. If no entry matches the current place, the picker shows
normally. `PlaceIds` also accepts a single number instead of a table if you only have one.

## Hub logo

`Library.Logo` is the branding image used in the loader topbar, the window topbar and the
launcher orb. Upload your logo in Studio and paste its asset ID:

```lua
Library.Logo = "rbxassetid://123456789"
```

Unlike the monochrome icons it is drawn in full colour, so artwork keeps its own look.
While it is empty the library falls back to the `sparkles` icon.

## Making the icon presets real

The icons are currently placeholders (circle + first letter) until real images are linked —
Roblox only loads `ImageLabel` images via `rbxassetid://`, never directly from a GitHub URL
or a local file. `icons/*.png` are ready to upload as-is (256x256, white on transparent, so
`ImageColor3` tinting still works).

**Option A — manual, no setup (a couple minutes):**
1. In Studio: Asset Manager → drag-and-drop all the `.png` files in (or right-click →
   Bulk Import Files). Roblox uploads and moderates each one, usually within seconds.
2. Copy each resulting asset ID from the Asset Manager.
3. In `YunoHubLibrary.lua`, fill in `Library.IconAssets`, e.g.:
   ```lua
   home = "rbxassetid://123456789",
   ```
4. Done — anywhere `"home"` is used as an icon name (tabs, loader cards, overlay), the real
   image now shows automatically instead of the placeholder.

**Option B — scripted, uploads + fills in the IDs for you:** `scripts/upload_icons.py` uses
Roblox's official Open Cloud API to upload every `icons/*.png`, then automatically patches the
resulting `rbxassetid://...` values into `Library.IconAssets` in `YunoHubLibrary.lua`. You run
it yourself with your own Open Cloud API key (from
https://create.roblox.com/dashboard/credentials) — see the comment at the top of that script
for the exact setup steps. Nothing about your account or key is shared with anyone but Roblox's
API when you run it.

**Gotcha (affects Option B):** assets uploaded as a Decal get a Decal asset ID, but
`ImageLabel.Image` sometimes needs the *texture* ID that Decal wraps internally — using the
Decal ID directly can render as a blank placeholder even though the upload succeeded. There's
no safe way to resolve that over plain HTTP without a full account session cookie (which this
project never handles). The one safe fix: open Roblox Studio, then run
`scripts/resolve_texture_ids.py`'s companion Luau snippet (see the comment at the top of that
script) via the command bar or a plugin — it uses `InsertService:LoadAsset` to read each
Decal's real texture ID, authenticated by your own Studio session, no cookie involved.

## Presets

Any toggle, slider, dropdown or input created with a **flag** (the last argument) is
included in presets automatically:

```lua
quickSection:CreateToggle("Auto-Farm", false, callback, "autoFarm")
quickSection:CreateSlider("Speed", 0, 100, 50, callback, "speed")
uiSection:CreateDropdown("Accent", { "Violet", "Cyan" }, "Violet", callback, "accent")
```

Then drop a ready-made manager into any section — name box, Save button, and a list of
saved presets each with Load/Delete:

```lua
presetSection:CreatePresetManager()
```

Presets are written to `YunoHub_presets.json` when the environment exposes `writefile` /
`readfile` (executors do), so they survive between sessions. In a normal Roblox client
those functions don't exist and presets simply live for the session instead.

You can also drive it from code:

```lua
Window:GetConfig()            -- snapshot of every flagged value
Window:LoadConfig(tbl)        -- apply a snapshot
Window:SavePreset("PvP")
Window:LoadPreset("PvP")
Window:DeletePreset("PvP")
Window:GetPresetNames()
```

## Element handles

Every `Create*` call returns a handle rather than the raw Instance, so elements can be
updated after creation:

```lua
local xpBar = section:CreateProgressBar("Level XP", 68, "1,360 / 2,000")
xpBar:Set(90, "1,800 / 2,000")

local toggle = section:CreateToggle("Auto-Farm", false, nil, "autoFarm")
toggle:Set(true)
print(toggle:Get())
```

Use `handle.Instance` if you need the underlying Roblox object.

## Icons in notifications

`Window:Notify(title, content, duration, icon)` takes an optional 4th argument — any name
from `Library.IconAssets` (`"zap"`, `"sparkles"`, `"shield"`, ...). When given, a small round
icon badge appears to the left of the notification text; omit it for a plain text notification
like before. See `Hubs/YunoHub.lua` for examples (`"sparkles"` on the hello button, `"zap"` on
Auto-Farm, `"wand"` on preset loads).
