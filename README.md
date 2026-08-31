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
- `icons/*.svg` + `icons/*.png` — 35 icon presets: home, settings, sparkles, bar-chart, eye,
  power, skull, crosshair, shield, sword, zap, gift, trophy, bell, lock, flame, gem, package,
  user, rocket, crown, coins, key, wrench, map, heart, moon, battery, save, clipboard-list,
  dice, wand, layers, ghost, medal. The `.png` files (256x256, white on transparent) are ready
  to upload directly as Roblox Decals; the `.svg` files are the source/reference versions.

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

## Making the icon presets real

The icons are currently placeholders (circle + first letter) until real images are linked —
Roblox only loads `ImageLabel` images via `rbxassetid://`, never directly from a GitHub URL
or a local file. `icons/*.png` are ready to upload as-is (256x256, white on transparent, so
`ImageColor3` tinting still works); `icons/*.svg` are the source files, kept for reference /
re-exporting at a different size.

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

## Icons in notifications

`Window:Notify(title, content, duration, icon)` takes an optional 4th argument — any name
from `Library.IconAssets` (`"zap"`, `"sparkles"`, `"shield"`, ...). When given, a small round
icon badge appears to the left of the notification text; omit it for a plain text notification
like before. See `Hubs/YunoHub.lua` for examples (`"sparkles"` on the hello button, `"zap"` on
Auto-Farm, `"wand"` on preset loads).
