# Sadaa

A fast, personal voice-dictation app for macOS. Tap a hotkey anywhere, speak in English or German, and the transcript lands at your cursor. Built to use your Azure OpenAI whisper deployment (the thing OpenWhispr and friends can't do).

This is the **MVP** (milestone 2 of the plan): record, transcribe via Azure OpenAI, insert at cursor with a clipboard backup. Smart formatting, the dictionary, history, snippets, voice-edit and the MAI provider come in later plans.

## Build and run

```bash
make bundle      # builds dist/Sadaa.app (ad-hoc signed)
open dist/Sadaa.app
```

A waveform icon appears in the menu bar. No Dock icon.

Requirements: macOS 14+, Apple Silicon, Command Line Tools (no full Xcode needed).

## First-run setup (do this once)

1. **Microphone**: grant it when macOS prompts (or System Settings > Privacy & Security > Microphone).
2. **Accessibility**: System Settings > Privacy & Security > Accessibility, enable Sadaa. This powers the Right Option hotkey AND inserting text at your cursor. The app polls for this, so once you grant it the hotkey starts working without a relaunch (no need to quit and reopen).
3. **Azure**: menu bar icon > Settings, fill in:
   - Endpoint, e.g. `https://your-resource.openai.azure.com`
   - Whisper deployment name
   - API version (defaults to `2024-10-21`)
   - API key (stored in the macOS Keychain, never in a file)

Until Azure is configured, every dictation ends with the HUD saying "No transcription provider configured."

## Using it

- **Tap Right Option** to start recording (a gold pill appears at the bottom of the screen). Tap again to stop, transcribe and insert.
- **Esc** while recording cancels.
- Recording auto-stops after 60s of silence or 10 minutes total.
- Pick **Auto-detect / English / German** in the menu bar.
- The final text is always copied to the clipboard as a backup, so if insertion misses you can paste it.

## Develop

```bash
make test        # 29 unit tests (Swift Testing)
swift build      # debug build
```

Tests run under Command Line Tools; the Makefile injects the framework paths Swift Testing needs. Use `make test`, not bare `swift test`.

## Layout

- `Sources/SadaaCore` - testable core: settings, keychain, providers, audio writer/recorder, recording store, hotkey recognizer, the `DictationController` pipeline.
- `Sources/SadaaApp` - macOS glue: AppDelegate, menu bar, HUD, hotkey tap, text insertion, settings window.
- `docs/superpowers/specs` - the design spec. `docs/superpowers/plans` - the implementation plan.
- `assets/branding` - the app icon (navy-on-cream 3D sound wave, Karko palette).
