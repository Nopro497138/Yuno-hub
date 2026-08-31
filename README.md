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
- `icons/*.svg` — 20 icon presets (home, settings, sparkles, bar-chart, eye, power, skull,
  crosshair, shield, sword, zap, gift, trophy, bell, lock, flame, gem, package, user, rocket).

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
  isn't one of the 20 presets (e.g. your own logo or banner art). Just upload any image as a
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
Roblox only loads `ImageLabel` images via `rbxassetid://`, never directly from a GitHub URL.

1. Upload each `.svg` from `icons/` in Studio (Asset Manager → Bulk Import, or upload as a
   Decal on roblox.com/develop) and copy the resulting asset ID.
2. In `YunoHubLibrary.lua`, fill in `Library.IconAssets`, e.g.:
   ```lua
   home = "rbxassetid://123456789",
   ```
3. Done — anywhere `"home"` is used as an icon name (tabs, loader cards, overlay), the real
   image now shows automatically instead of the placeholder.

You can keep the `.svg` files in your GitHub repo unchanged (e.g. as a source/reference
folder for yourself or contributors) — Roblox itself can only use them after they've been
uploaded.
