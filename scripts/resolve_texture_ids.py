"""
resolve_texture_ids.py

Patches YunoHubLibrary.lua's IconAssets so every icon points at its underlying *texture*
asset ID instead of the *Decal* asset ID it was uploaded as.

Why this exists: Decal uploads (what scripts/upload_icons.py produces) return a Decal
asset ID. Roblox's ImageLabel.Image sometimes needs the Image/texture ID that the Decal
wraps internally instead -- that mismatch is why the icons rendered as blank placeholders.

How the mapping below was produced: there is no safe way to resolve Decal -> texture ID
over plain HTTP without a full Roblox account session cookie, and this project does not
handle that credential (same reasoning as scripts/upload_icons.py only ever asking for an
Open Cloud API key, never a login). The one safe, official way is `InsertService:LoadAsset`
run inside Roblox Studio, which resolves each Decal to a real `Decal` instance and reads
its `.Texture` property directly -- authenticated by the Studio session, no cookie needed.
That's what filled in TEXTURE_IDS below (run once, interactively, via the Studio MCP).

This script itself is plain Python: it only rewrites the .lua file's rbxassetid values.
Run it again by hand whenever you upload new icons and re-resolve their texture IDs the
same way (see the README's "Making the icon presets real" section).
"""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIBRARY_FILE = ROOT / "YunoHubLibrary.lua"

# name -> texture (Image) asset id, resolved via InsertService:LoadAsset in Studio.
TEXTURE_IDS = {
    "medal": "74735026406123",
    "ghost": "101973788188413",
    "bar-chart": "72584118679611",
    "save": "126485506579939",
    "skull": "86616048766920",
    "wrench": "84346277426426",
    "key": "128251505045577",
    "lock": "104499419466145",
    "crown": "97108479956679",
    "bell": "116039089721439",
    "map": "96931562673365",
    "trophy": "131121362757837",
    "layers": "106442882333548",
    "gem": "106659542169007",
    "heart": "113057606722437",
    "crosshair": "96532914927004",
    "rocket": "110365788058652",
    "dice": "100178092254276",
    "zap": "103552562650492",
    "battery": "122763222875272",
    "coins": "87113891036132",
    "settings": "97597986086617",
    "moon": "112231190698084",
    "flame": "94993715640377",
    "power": "119903477110253",
    "shield": "127802172197672",
    "package": "105533338080015",
    "sword": "73428970722324",
    "gift": "129310286227038",
    "user": "139749689373457",
    "eye": "111297490539888",
    "sparkles": "102754611452699",
    "clipboard-list": "98513300351551",
    "wand": "74790531714804",
}


def patch_library() -> None:
    text = LIBRARY_FILE.read_text(encoding="utf-8")

    for name, texture_id in TEXTURE_IDS.items():
        key = f'["{name}"]' if "-" in name else name
        # matches:  key = "rbxassetid://<anything>"
        pattern = re.compile(re.escape(key) + r'\s*=\s*"rbxassetid://\d*"')
        replacement = f'{key} = "rbxassetid://{texture_id}"'
        new_text, count = pattern.subn(replacement, text, count=1)
        if count:
            text = new_text
            print(f"  patched {name} -> rbxassetid://{texture_id}")
        else:
            print(f"  skipped {name} (pattern not found -- check IconAssets formatting)")

    LIBRARY_FILE.write_text(text, encoding="utf-8")


if __name__ == "__main__":
    print("Patching YunoHubLibrary.lua with resolved texture IDs...")
    patch_library()
    print("Done.")
