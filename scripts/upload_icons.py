"""
upload_icons.py

Uploads every icons/*.png as a Decal via Roblox's Open Cloud Assets API, then patches the
resulting rbxassetid values straight into YunoHubLibrary.lua's IconAssets table.

You run this yourself, locally, with your own API key -- it never leaves your machine and
is never sent to anyone but Roblox's API.

Setup:
  1. Create an API key at https://create.roblox.com/dashboard/credentials with the
     "Assets" -> "Read" and "Write" permissions, scoped to your own user (or a group you own).
  2. pip install requests
  3. Set two environment variables before running:
       Windows (PowerShell):  $env:ROBLOX_API_KEY = "..."; $env:ROBLOX_CREATOR_ID = "123456"
       macOS/Linux (bash):    export ROBLOX_API_KEY="..."; export ROBLOX_CREATOR_ID="123456"
     ROBLOX_CREATOR_ID is your numeric Roblox user ID (profile URL number). Set
     ROBLOX_CREATOR_TYPE=Group instead of the default "User" if it's a group's ID.
  4. Run:  python scripts/upload_icons.py

It will print each uploaded icon's new asset ID and rewrite the empty "" entries in
Library.IconAssets (in YunoHubLibrary.lua) to "rbxassetid://<id>" automatically. Entries
that already have a value (like a manually-uploaded one) are left untouched.
"""

import os
import re
import sys
import time
import json
from pathlib import Path

try:
    import requests
except ImportError:
    sys.exit("Missing dependency. Run: pip install requests")

API_KEY = os.environ.get("ROBLOX_API_KEY")
CREATOR_ID = os.environ.get("ROBLOX_CREATOR_ID")
CREATOR_TYPE = os.environ.get("ROBLOX_CREATOR_TYPE", "User")  # "User" or "Group"

if not API_KEY or not CREATOR_ID:
    sys.exit("Set ROBLOX_API_KEY and ROBLOX_CREATOR_ID environment variables first (see the "
              "docstring at the top of this file).")

ROOT = Path(__file__).resolve().parent.parent
ICONS_DIR = ROOT / "icons"
LIBRARY_FILE = ROOT / "YunoHubLibrary.lua"

UPLOAD_URL = "https://apis.roblox.com/assets/v1/assets"
HEADERS = {"x-api-key": API_KEY}


def upload_one(png_path: Path) -> int:
    request_payload = {
        "assetType": "Decal",
        "displayName": png_path.stem,
        "description": f"Yuno Hub icon: {png_path.stem}",
        "creationContext": {
            "creator": (
                {"userId": str(CREATOR_ID)}
                if CREATOR_TYPE == "User"
                else {"groupId": str(CREATOR_ID)}
            )
        },
    }

    with open(png_path, "rb") as f:
        files = {
            "request": (None, json.dumps(request_payload), "application/json"),
            "fileContent": (png_path.name, f, "image/png"),
        }
        resp = requests.post(UPLOAD_URL, headers=HEADERS, files=files)

    if resp.status_code not in (200, 201):
        raise RuntimeError(f"Upload failed for {png_path.name}: {resp.status_code} {resp.text}")

    operation_path = resp.json()["path"]  # e.g. "operations/<id>"

    # Poll the operation until Roblox finishes processing + moderating the asset.
    for _ in range(30):
        op_resp = requests.get(f"https://apis.roblox.com/assets/v1/{operation_path}", headers=HEADERS)
        op_resp.raise_for_status()
        op = op_resp.json()
        if op.get("done"):
            return int(op["response"]["assetId"])
        time.sleep(2)

    raise TimeoutError(f"Timed out waiting for {png_path.name} to finish processing.")


def patch_library(results: dict) -> None:
    text = LIBRARY_FILE.read_text(encoding="utf-8")
    for name, asset_id in results.items():
        key = f'["{name}"]' if "-" in name else name
        pattern = re.compile(re.escape(key) + r'\s*=\s*""')
        replacement = f'{key} = "rbxassetid://{asset_id}"'
        new_text, count = pattern.subn(replacement, text, count=1)
        if count:
            text = new_text
            print(f"  patched {name} -> rbxassetid://{asset_id}")
        else:
            print(f"  skipped {name} (already set or not found -- edit it manually if needed)")
    LIBRARY_FILE.write_text(text, encoding="utf-8")


def main():
    pngs = sorted(ICONS_DIR.glob("*.png"))
    if not pngs:
        sys.exit(f"No .png files found in {ICONS_DIR}")

    results = {}
    for png in pngs:
        name = png.stem
        print(f"Uploading {name}...")
        try:
            asset_id = upload_one(png)
            print(f"  -> rbxassetid://{asset_id}")
            results[name] = asset_id
        except Exception as e:
            print(f"  FAILED: {e}")

    if results:
        print("\nPatching YunoHubLibrary.lua ...")
        patch_library(results)
        print("Done.")


if __name__ == "__main__":
    main()
