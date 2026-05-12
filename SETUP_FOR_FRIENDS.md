# AI-HUB v2 Setup For Friends

## Best Way To Share It

- Run `build_friend_package.bat`
- Zip the folder it creates in `dist\AI-HUB-v2-FRIEND`
- Send that zip, not your live working folder

## Before You Zip It

- Do not share `config/settings.ini` as-is. It contains personal API keys.
- Keep `config/settings.example.ini` in the package.
- Remove any personal prompts, bookmarks, or clipboard history you do not want to share from `config/`.

## What They Need

- Windows 10 or 11
- [AutoHotkey v2](https://www.autohotkey.com/)
- Python 3.10+
- Microsoft Edge or Google Chrome

## Install Steps

1. Extract the folder anywhere they want.
2. Run `install_ai_hub_friend.bat`.
3. Add their own API keys in `config/settings.ini`.
4. Re-run `install_ai_hub_friend.bat` or launch `AI-HUB.ahk`.

## What Starts Automatically

- The main AI-HUB window
- The local Python bridge server on `http://localhost:3456`
- The `POF 2828` prompt picker
- Research links
- BetterTTS

## First Checks

- Open the prompt picker and create a test prompt.
- Confirm it saves and is still there after refresh.
- Hit `Ctrl+Alt+P` to reopen prompts.
- Hit `Ctrl+Alt+S` to confirm the bridge server is running.

## Packaging Notes

- The installer creates a Startup shortcut, so the whole folder does not need to live inside the Windows Startup folder.
- The clean package resets prompts, research links, clipboard history, and bridge data to starter files.
- The package now includes the current prompt picker, research links, and calendar UIs even if the target PC does not have your `Desktop\Personal dashboard` folder.
