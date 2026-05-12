# ClipSync Path Forward

Active room: Theophysics Comms `workflow-2`
Program label: `[program:clipsync]`
Local vault: `B:\AI-HUB-SYNC`
Syncthing folder id: `ai-hub-clipboard-vault`

## Purpose

Make AI-HUB / ClipboardVault restorable and portable across:

- AI-HUB local desktop state
- Syncthing device sync
- Cloudflare / R2 daily backups

## Current Vault Lanes

- `desktop`
- `documents`
- `html`
- `markdown`
- `audio`
- `video`
- `images`
- `files`
- `inbox`
- `databases`
- `config`
- `exports`
- `saved`

## Preserve First

- `settings.ini`
- `prompts.json`
- `hotkeys.ini`
- `hotstrings.sav`
- `research_links.json`
- `storage.json`
- `clipdata/`
- clipboard database snapshots when useful

## Export Shape

Daily exports should land at:

`B:\AI-HUB-SYNC\exports\YYYY-MM-DD\`

Expected contents:

- `restore.ini`
- `manifest.json`
- `config/`
- `databases/`
- `saved/`

Cloudflare/R2 should keep 14 daily exports and drop older days.

## TTS Decision

- `Ctrl+Alt+P`: pause / resume
- `Ctrl+Alt+X`: replace current TTS text with clipboard and play from the beginning
- `Ctrl+Alt+Shift+X`: stop

BetterTTS should also support:

- Reset button near speed
- Right-click text box to clear current text
- Clipboard reset/paste/play from one action
