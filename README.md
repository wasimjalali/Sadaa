# Sadaa

**Type with your voice, anywhere on your Mac.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Swift](https://img.shields.io/badge/Swift-F05138?logo=swift&logoColor=white)](https://swift.org)
![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)

A fast, personal voice-dictation app for macOS. Tap a hotkey anywhere, speak in English or German, and the transcript lands at your cursor. Powered by Deepgram Nova-3 for fast, accurate speech-to-text.

Sadaa records, transcribes, applies your personal dictionary and inserts the result at your cursor with a clipboard backup. The main window focuses on five clear areas: Dictate, Library, Dictionary, Notes and Settings.

## Build and run

```bash
make bundle      # builds dist/Sadaa.app (ad-hoc signed)
open dist/Sadaa.app
```

A waveform icon appears in the menu bar. No Dock icon.

Requirements: macOS 14+, Apple Silicon, Command Line Tools (no full Xcode needed).

## First-run setup (do this once)

1. **Microphone**: grant it when macOS prompts (or System Settings > Privacy & Security > Microphone).
2. **Accessibility**: System Settings > Privacy & Security > Accessibility, enable Sadaa. This powers the tap hotkeys AND inserting text at your cursor. The app polls for this, so once you grant it the hotkey starts working without a relaunch (no need to quit and reopen).
3. **Deepgram API key**: open Settings and paste your Deepgram API key. Sadaa transcribes with the Deepgram Nova-3 model. Turn **Auto-format transcript** on for punctuation, capitalization and formatted numbers, or off for raw text.

Your Deepgram API key is stored in the macOS Keychain, never in a file.

Until your key is configured, every dictation ends with the HUD saying "No transcription provider configured."
Use **Test connection** in Settings to run a tiny redacted transcription probe before you rely on it.

## Using it

- **Tap your dictation key** to start recording (Right Command by default; a gold pill appears at the bottom of the screen). Tap again to stop, transcribe and insert.
- **Esc** while recording cancels.
- Recording auto-stops after 60s of silence or 10 minutes total.
- Pick **Auto-detect / English / German** in the menu bar.
- The final text is always copied to the clipboard as a backup, so if insertion misses you can paste it.
- Teach Sadaa exact names and specialist spellings in **Dictionary**, and add deterministic auto-corrections for recurring mistakes. Advanced spelling hints, text shortcuts and import/export stay available without cluttering the default workflow.
- Use **Notes** for local dictated notes with search, pins, auto-save, tags, Markdown copy, JSON backup/restore and append-latest-dictation.
- In **Library**, search, copy, send a dictation to Notes, reprocess retained audio or turn a correction into a dictionary entry.

## Transcription model

Sadaa uses Deepgram's **Nova-3** model for all dictation. Auto-format (Deepgram's `smart_format`) adds punctuation, capitalization and formatted numbers and dates; turn it off in Settings for raw text. Your personal dictionary terms are sent as Deepgram key-terms to bias recognition, and dictionary corrections always run locally. Local app data stays under Sadaa's Application Support directory; Sadaa does not read, scan, index, or default-save into your Documents folder.

## Develop

```bash
make test        # Swift Testing suite
swift build      # debug build
```

Tests run under Command Line Tools; the Makefile injects the framework paths Swift Testing needs. Use `make test`, not bare `swift test`.

## Layout

- `Sources/SadaaCore` - testable core: settings, keychain, providers, audio writer/recorder, recording store, hotkey recognizer, Language Memory, Scratchpad, history, and the `DictationController` pipeline.
- `Sources/SadaaApp` - macOS glue: AppDelegate, menu bar, HUD, hotkey tap, text insertion, premium pages, and settings window.
- `docs/superpowers/specs` - the design spec. `docs/superpowers/plans` - the implementation plan.
- `assets/branding` - the app icon (navy-on-cream 3D sound wave, Karko palette).

## License

MIT. See [LICENSE](LICENSE).
