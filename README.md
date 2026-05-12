# AI-HUB ClipSync Known-Good

This repository is the known-good snapshot of David's AI-HUB / ClipSync desktop workflow as of 2026-05-12.

It was created from the live working Startup copy because that is the version that was actually behaving correctly.

## What Works

- AI-HUB starts from Windows Startup.
- Local ClipSync server runs on `http://127.0.0.1:3456`.
- Clipboard, prompts, links, mission, and comms panels can launch from AI-HUB.
- Theophysics Comms dashboard uses `https://comms.faiththruphysics.com`.
- The repo dashboard does not ship with a bearer token. Enter one locally when prompted.
- Comms dashboard loads live rooms including `programs`, `workflow-1`, and `workflow-2`.
- Nerve TTS has one clear app launcher: `Nerve TTS Engine`.
- TTS hotkeys:
  - `Ctrl+Alt+P`: pause / resume
  - `Ctrl+Alt+X`: replace TTS text with clipboard and play from beginning
  - `Ctrl+Alt+Shift+X`: stop
- Syncthing vault anchor:
  - `B:\AI-HUB-SYNC`
  - Syncthing folder id: `ai-hub-clipboard-vault`

## Important Paths

Live runtime:

`C:\Users\lowes\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\ai-hub-v2`

Standalone TTS hotkey:

`C:\Users\lowes\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\nerve-tts-hotkey.ahk`

Known-good repo:

`D:\GitHub\physics-of-faith\ai-hub-clipsync`

Synced vault:

`B:\AI-HUB-SYNC`

## Startup Files

The repo includes:

- `AI-HUB.ahk`
- `hub_core.ahk`
- `sync_server.py`
- `modules/`
- `BetterTTS/`
- `startup/nerve-tts-hotkey.ahk`
- `docs/CLIPSYNC_PATH_FORWARD_2026-05-12.md`

The repo intentionally ignores live runtime data such as:

- `Data/`
- clipboard database files
- local private settings
- Python cache files
- backup files

## Restore (Real Script)

Run:

`restore_known_good_to_startup.bat`

What it does:

1. Rebuilds `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\ai-hub-v2` from this known-good repo.
2. Refreshes `nerve-tts-hotkey.ahk` in Startup.
3. Leaves live data folders out of the restore copy.

## Daily Local Export

Run:

`daily_export_to_sync.bat`

Export target:

`B:\AI-HUB-SYNC\exports\YYYY-MM-DD\`

Export contents:

- `restore.ini`
- `manifest.json`
- `config/`
- `databases/`
- `saved/`

Cloudflare/R2 backup retention is intentionally deferred until local exports are stable.

## Do Not Push Public

This is a local workflow repo. Review credentials, tokens, local paths, and personal data before publishing anywhere public.


## Pre-Public Push Audit

Run `audit_for_public_push.bat` before any public push to scan for hard-coded secrets/tokens.
