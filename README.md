# Sadaa

A fast, personal voice-dictation app for macOS. Tap a hotkey anywhere, speak in English or German, and the transcript lands at your cursor. Built to use your Azure OpenAI whisper deployment (the thing OpenWhispr and friends can't do).

This is now the premium local-first Sadaa build: record, transcribe through Azure-hosted models, clean the text, apply personal Language Memory, and insert at your cursor with a clipboard backup. The main window is a control center for readiness, Language Memory, Scratchpad notes, history, provider setup, and diagnostics.

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
3. **Azure**: menu bar icon > Settings, fill in:
   - Endpoint, e.g. `https://your-resource.openai.azure.com`
   - Transcription deployment name
   - API version (defaults to `2025-03-01-preview`)
   - API key (stored in the macOS Keychain, never in a file)

Until Azure is configured, every dictation ends with the HUD saying "No transcription provider configured."
Use **Test Azure** in Settings to run a tiny redacted transcription probe against the current deployment before you rely on it.

## Using it

- **Tap your dictation key** to start recording (Right Command by default; a gold pill appears at the bottom of the screen). Tap again to stop, transcribe and insert.
- **Tap your voice-edit key** to rewrite selected text by voice (Right Option by default).
- **Esc** while recording cancels.
- Recording auto-stops after 60s of silence or 10 minutes total.
- Pick **Auto-detect / English / German** in the menu bar.
- The final text is always copied to the clipboard as a backup, so if insertion misses you can paste it.
- Teach Sadaa names, product terms, pronunciations, deterministic replacements with live preview, and spoken snippets in **Language Memory**, with per-term priority and English/German/Any-language targeting. Replacements and snippets can be paused instead of deleted. Snippets expand deterministically around smart formatting, and raw-mode dictation still applies local deterministic memory without calling GPT. History rows show memory/snippet-hit counts so you can tell when Sadaa actually matched your memory, and matched terms/replacements/snippets gain usage counts that improve future biasing. Copy or import Language Memory JSON, terms CSV, or replacements CSV for local backup/migration.
- Use **Scratchpad** for local dictated notes with search, pins, auto-save, tags, word/character stats, selected-note Markdown copy, all-notes Markdown export, JSON backup/restore, and append-latest-dictation.
- In **History**, copy, send a dictation to Scratchpad, reprocess from retained audio when available, or turn a correction into a term/replacement.

## Recommended Azure models

Use Azure OpenAI / Foundry deployments when available:

- **Fast daily dictation**: your Azure deployment of `gpt-4o-mini-transcribe`, or the newest mini transcribe variant available in your region
- **Best accuracy**: your Azure deployment of `gpt-4o-transcribe`
- **Legacy fallback**: `whisper` / `whisper-1` only if your Azure resource does not yet expose the newer transcribe models
- **Azure Speech / MAI**: `mai-transcribe-1.5` where you have that Speech resource enabled
- **Realtime models**: useful for future streaming/live transcription work, but not the current Sadaa hotkey flow, which records an utterance and submits it through the file-based audio transcription path

Smart formatting should use a chat deployment such as `gpt-4o-mini` for low-latency cleanup. API keys remain in Keychain. Local app data stays under Sadaa's Application Support directory; Sadaa does not read, scan, index, or default-save into your Documents folder.

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
