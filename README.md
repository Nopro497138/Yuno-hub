# Yuno Hub

Galaxy-Style Roblox-UI-Library (Rayfield-artig): ein Loader-Auswahlbildschirm vor dem
eigentlichen Hub, dann ein Fenster mit Tabs/Sections/Buttons/Toggles/Slidern/Dropdowns.

## Dateien

- `YunoHubLibrary.lua` — die wiederverwendbare Library (ModuleScript). Enthält Theme,
  Icon-System, `CreateLoader`, `CreateWindow`.
- `Loader.client.lua` — LocalScript, Einstiegspunkt. Referenziert die Hub-Module in einer
  Tabelle oben im Code (Name, Bild, Beschreibung, Module).
- `Hubs/YunoHub.lua`, `Hubs/SecondInstance.lua` — Beispiel-Hubs. Jede Datei ist eine
  ModuleScript, die `function(Library) ... end` zurückgibt und darin ihr eigenes Fenster baut.
- `icons/*.svg` — 20 Icon-Presets (home, settings, sparkles, bar-chart, eye, power, skull,
  crosshair, shield, sword, zap, gift, trophy, bell, lock, flame, gem, package, user, rocket).

## In Studio einrichten

Unter z.B. `StarterPlayerScripts`:

```
StarterPlayerScripts/
    Loader (LocalScript)              <- Loader.client.lua
    YunoHubLibrary (ModuleScript)     <- YunoHubLibrary.lua
    Hubs (Folder)
        YunoHub (ModuleScript)        <- Hubs/YunoHub.lua
        SecondInstance (ModuleScript) <- Hubs/SecondInstance.lua
```

Eigene Hubs hinzufügen: neue ModuleScript in `Hubs` erstellen (Inhalt wie
`Hubs/SecondInstance.lua`), dann in `Loader.client.lua` einen neuen Eintrag in
`Instances` ergänzen.

## Icons scharf schalten

Die Icons sind aktuell Platzhalter (Kreis + Anfangsbuchstabe), bis echte Bilder verlinkt
sind — Roblox lädt `ImageLabel`-Bilder nur über `rbxassetid://`, nicht direkt von GitHub-URLs.

1. Jede `.svg` aus `icons/` in Studio hochladen (Asset-Manager → Bulk Import, oder auf
   roblox.com/develop als Decal hochladen) und die resultierende Asset-ID kopieren.
2. In `YunoHubLibrary.lua` bei `Library.IconAssets` eintragen, z.B.:
   ```lua
   home = "rbxassetid://123456789",
   ```
3. Fertig — überall, wo `"home"` als Icon-Name benutzt wird, erscheint automatisch das
   echte Bild statt des Platzhalters.

Die `.svg`-Dateien kannst du unverändert in dein GitHub-Repo packen (z.B. als
Icon-Quellordner für dich/Mitwirkende) — Roblox selbst kann sie nur nach dem Upload nutzen.
