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

## Restore Sketch

1. Copy this repo folder to the Windows Startup location as `ai-hub-v2`.
2. Copy `startup/nerve-tts-hotkey.ahk` into the Windows Startup folder.
3. Make sure `Nerve TTS Engine` is installed as the Edge app.
4. Make sure `B:\AI-HUB-SYNC` exists or update paths in the config.
5. Start `AI-HUB.ahk`.

## Do Not Push Public

This is a local workflow repo. Review credentials, tokens, local paths, and personal data before publishing anywhere public.
