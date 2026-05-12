# Known-Good Manifest - 2026-05-12

## Source Snapshot

Copied from:

`C:\Users\lowes\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\ai-hub-v2`

Added:

`startup/nerve-tts-hotkey.ahk`

Added docs from:

`B:\AI-HUB-SYNC\CLIPSYNC_PATH_FORWARD_2026-05-12.md`

## Verified Before Snapshot

- `http://127.0.0.1:3456/comms` returned HTTP 200.
- Comms dashboard rendered:
  - `/programs`
  - `/workflow-1`
  - `/workflow-2`
  - `[program:clipsync]`
  - `LIVE` status
- Syncthing folder `ai-hub-clipboard-vault` was idle and indexed.
- Windows Start Apps had only `Nerve TTS Engine` after removing stale `Labor of Love`.
- TTS hotkey listener was running from `nerve-tts-hotkey.ahk`.

## Active Comms Records

- `programs` message `455`
- `workflow-2` messages `456`, `457`, `458`

## Current Hotkeys

- `Ctrl+Alt+Space`: Smart Fix / autocorrect current text field
- `Ctrl+Alt+C`: Clipboard panel
- `Ctrl+Alt+O`: Prompts panel
- `Ctrl+Alt+P`: TTS pause / resume
- `Ctrl+Alt+X`: TTS replace clipboard and play from beginning
- `Ctrl+Alt+Shift+X`: TTS stop

## Next Work

- Added `daily_export_to_sync.bat` for `B:\AI-HUB-SYNC\exports\YYYY-MM-DD\`.
- Added `restore_known_good_to_startup.bat` for one-step Startup restore.
- Next: add Cloudflare/R2 14-day backup retention after local export stability is confirmed.
- Reconcile this known-good repo with the older `D:\GitHub\physics-of-faith\ai-hub` repo.
