# Deepgram Nova-3 + Simplified Settings

**Date:** 2026-07-22
**Status:** Approved design, pending implementation plan

## Goal

Move Sadaa's speech-to-text to Deepgram Nova-3, remove every Azure OpenAI dependency, and simplify the Settings UI. The Deepgram API key is entered in a masked field in the UI and stored securely in the macOS Keychain (the app's secret "backend"), never in plain settings.

## Decisions (locked with the user)

1. **Fully Deepgram, drop the GPT features.** Deepgram Nova-3 does transcription plus built-in `smart_format` cleanup. The Azure GPT "Writing" cleanup and Voice Edit are removed entirely. Local dictionary / replacement / snippet corrections stay (they need no LLM).
2. **Auto-format toggle, default on.** A single "Auto-format transcript" switch drives Deepgram `smart_format`. Off gives raw output.
3. **Data section trimmed.** Keep "Stop after silence" and "Keep recordings" only.
4. **Remove cost everywhere.** The cost meter, its rate settings, and every cost display (Settings monthly estimate + History per-record estimate) are removed.
5. **Keep the `TranscriptionProvider` protocol**, add a single `DeepgramProvider`, delete the two Azure/OpenAI providers. The pipeline already consumes `[TranscriptionProvider]`, so this is the smallest, lowest-risk change.

## Architecture

### Speech-to-text: `DeepgramProvider: TranscriptionProvider`

New file `Sources/SadaaCore/Transcription/DeepgramProvider.swift`.

- **Request:** `POST https://api.deepgram.com/v1/listen`
  - Header `Authorization: Token <key>`
  - Header `Content-Type: audio/wav`
  - Body: the raw WAV bytes (Deepgram's pre-recorded endpoint takes the raw audio body, no multipart)
  - Query params:
    - `model=nova-3`
    - `smart_format=true|false` (from the auto-format toggle)
    - Language mapping from `LanguagePin`: `.en` -> `language=en`, `.de` -> `language=de`, `.auto` -> `language=multi` (Nova-3 multilingual / code-switching)
    - Local dictionary terms passed as Deepgram key-terms so the user's vocabulary still biases recognition
- **Response parsing:** read `results.channels[0].alternatives[0].transcript` and `metadata.duration`. Detected language is optional (Deepgram reports it per-word in `multi` mode; downstream already treats `detectedLanguage` as optional).
- **Reuse:** the existing 15s wall-clock deadline (`AzureOpenAIProvider.withDeadline` logic is moved into `DeepgramProvider` or a shared helper) and the existing `ProviderError` cases (`.http`, `.badResponse`, `.notConfigured`, `.timedOut`, `.transport`).
- **Validation note:** exact Nova-3 parameter spelling (`keyterm` vs `keywords`, `language=multi` support) is verified against Deepgram's current REST docs at implementation time via context7 before finalizing the request builder.

### Transcription pipeline (`DictationController`, `AppDelegate`)

- `DictationController` is unchanged in shape. It keeps `FormattingContext` / `FormattingResult` as the plumbing for local corrections.
- `AppDelegate.buildProviders` returns `[DeepgramProvider(...)]` when a `deepgram-key` exists in the Keychain, else `[]`.
- `AppDelegate`'s `format` closure keeps running `LanguageMemoryPostProcessor` (dictionary/replacement/snippet corrections) and returns that result. No GPT call remains. `buildFormatter`, `describeFormatterError`, and the `formatterUnavailable` notice are deleted.
- Deepgram `smart_format` now supplies the punctuation/capitalization the GPT formatter used to add.

### Secrets (the "backend")

- Keychain service stays `ai.karko.sadaa`. New account: `deepgram-key`.
- UI shows a masked `SecureField` with a placeholder. On save, a non-empty entry is written to the Keychain and the field clears. When a key exists, the UI shows "Stored in Keychain" plus a "Remove saved key" button. This reuses the existing `secretField` component.
- Old accounts `azure-openai-key` and `openai-compatible-key` simply stop being referenced (no destructive migration).

## Settings model (`AppSettings.swift`)

- **Remove:** `speechProviderKind`, `azureEndpoint`, `azureDeployment`, `azureAPIVersion`, `compatibleEndpoint`, `compatibleModel`, `gptDeployment`, `speakerContext`, `transcriptionPreset`, `fastTranscriptionDeployment`, `accurateTranscriptionDeployment`, `transcriptionRatePerMinute`, `formatterRatePer1kChars`. Delete the `SpeechProviderKind` and `TranscriptionPreset` enums (both become unused).
- **Repurpose:** `formattingEnabled` now means "Auto-format transcript" and drives Deepgram `smart_format` (default `true`, UserDefaults key kept to preserve any existing on/off preference).
- **Keep:** `languagePin`, `silenceTimeout`, `recordingsToKeep`, `hotkeyKeycode`, `languageSwitchKeycode`, `soundEffectsEnabled`, `lastExportFolder`.

## Settings UI (`SettingsPage.swift`)

Four cards, down from the current sprawl:

- **General** (unchanged): language, dictation hotkey, language hotkey, start-at-login, sound cues, microphone/accessibility shortcut buttons.
- **Speech (Deepgram)**: one masked API-key field (placeholder `Enter your Deepgram API key`, "Stored in Keychain" + Remove when saved) and the **Auto-format transcript** toggle. No provider picker, no endpoint / deployment / API-version / model fields.
- **Data and recording**: "Stop after silence" slider and "Keep recordings" stepper only. No cost fields, no monthly estimate.
- Header status line, **Test connection**, and **Save settings** stay. `testConnection` builds a `DeepgramProvider` and runs the existing `ProviderHealthCheck`.

## Cost removal (everywhere)

- Delete `Sources/SadaaCore/Cost/CostMeter.swift` and `CostEstimator.swift`.
- `SadaaViewModel`: remove `monthlyCost` and `refreshCost`.
- `AppDelegate`: remove both `CostEstimator.estimate` sites and the cost stored on records.
- `HistoryPage`: remove the "Estimated cost" detail line.
- `HomePage`/`PageFormat`: remove the `dollars` helper if nothing else uses it.
- `DictationRecord`: trace and remove `estimatedCost` / `withEstimatedCost`. Old persisted history JSON that still carries the key decodes fine (extra keys are ignored). This is the riskiest ripple (history persistence, reprocess paths, tests) and is handled with care.

## Removals summary

**Delete (source):** `AzureOpenAIProvider`, `OpenAICompatibleProvider`, `AzureChatFormatter`, `FormattingPromptBuilder`, `FormattingProfile`, `FormatterHealthCheck`, `VoiceEditController`, `VoiceEditPromptBuilder`, `CostMeter`, `CostEstimator`. Remove `MultipartBody` only if unused after the providers go (Deepgram uses a raw body).

**Delete (tests):** the matching test files for each deleted type: `AzureOpenAIProviderTests`, `OpenAICompatibleProviderTests`, `AzureChatFormatterTests`, `FormattingPromptBuilderTests`, `FormattingProfileTests`, `VoiceEditTests`, `VoiceEditPromptBuilderTests`, `CostTests`, and `MultipartBodyTests` if `MultipartBody` is removed.

**Keep:** all `LanguageMemory` files, `FormattingContext`/`FormattingResult` (local-correction plumbing; the now-unused `speakerContext` field is dropped from the struct and its construction site), `ProviderHealthCheck`, `DictationController`.

## Tests

- **Add** `DeepgramProviderTests`: request shape (URL, `Token` auth header, `model=nova-3`, `smart_format` on/off, language mapping, key-terms) and response parsing (transcript + duration, and a malformed-body error case).
- **Update** `AppSettingsTests` (trimmed keys, repurposed `formattingEnabled`), `DictationControllerTests` and `ProviderHealthCheckTests` (no formatter, Deepgram provider), and `DictationHistoryTests`/`SnippetStoreTests` if touched by the cost-field removal.

## Verification before any PR

1. `swift build` clean, `swift test` green.
2. Build and install `Sadaa.app` via the existing `Makefile` / `scripts`.
3. User launches it, enters a Deepgram key, and confirms dictation + auto-format work end to end.
4. Only after the user confirms: run `/code-review` at high effort (Keychain + network + settings are sensitive) and the adversarial review, then branch/commit/push/PR, CodeRabbit green, merge.

## Out of scope

- No web/server backend is introduced; "backend" means the macOS Keychain.
- No change to History/Notes/Dictionary features beyond removing cost display.
- No new Deepgram features (diarization, streaming, summarization) beyond Nova-3 pre-recorded transcription with `smart_format`.
