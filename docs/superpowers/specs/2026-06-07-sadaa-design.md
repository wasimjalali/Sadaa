# Sadaa - Design Spec

**Date:** 2026-06-07
**Status:** Approved pending user review
**Platform:** macOS 14+ (Apple Silicon), native Swift/SwiftUI
**Owner:** Wasim Jalali

## 1. What Sadaa is

Sadaa is a personal voice-dictation app for macOS, in the spirit of Wispr Flow. Press a hotkey anywhere, speak in English or German, and polished text appears at your cursor in whatever app you're using. It exists because existing tools (OpenWhispr and friends) can't talk to Azure OpenAI deployments, and Wasim has Azure credits plus a need for a fast, dictionary-aware dictation tool he uses heavily for coding prompts.

### Goals
- Dictation that feels instant: text at the cursor ~1.5-3s after stopping.
- First-class Azure OpenAI support (endpoint + key + deployment name + api-version).
- Pluggable providers so new models (MAI-Transcribe, future releases) are a config entry, not a rewrite.
- A dictionary that actually works: biases recognition AND fixes spelling, and learns new terms semi-automatically.
- English and German, auto-detected, with a manual pin as override.
- Never lose a dictation.

### Non-goals
- Windows, iOS, or web versions.
- Live streaming transcription (words appearing while you speak). Batch on stop only. Streaming can be a later phase.
- Wake word ("Hey Sadaa"), meeting transcription, speaker diarization, team/sync features.
- App Store distribution (sandboxing would break Accessibility integration).

## 2. Decisions made (with Wasim, 2026-06-07)

| Topic | Decision |
|---|---|
| Platform | macOS only, native Swift/SwiftUI |
| Activation | Toggle hotkey (tap to start, tap to stop), Esc cancels |
| Output | Insert at cursor + always copy to clipboard as backup |
| Latency mode | Batch (transcribe on stop), no streaming |
| Post-processing | Full smart formatting via Azure GPT deployment, context-aware per app, toggleable |
| Dictionary | Manual entries + auto-suggested terms with one-click accept |
| Languages | EN + DE auto-detect, manual pin override in menu bar |
| Default STT | Azure OpenAI whisper deployment (user's existing one) |
| Other providers | OpenAI API at launch; MAI-Transcribe-1.5 provider built in, becomes selectable when available on user's subscription |
| Extras | History panel, snippets, voice edit mode, notes, recording HUD, auto-stop on silence, provider fallback, cost meter |
| Name | Sadaa (bundle id `ai.karko.sadaa`, changeable) |
| Branding | Karko AI palette (navy/gold/cream/sage, Inter), 3D-feel app icon |
| Domain context | Formatter and base vocabulary primed for AI/dev topics (Claude Code, Codex, agents) |
| Dictionary size | Deliberately small and lean; capped suggestions, capped bias list |

## 3. Model and provider strategy

One protocol, three implementations. The user picks a default in settings; failures walk down a fallback chain automatically.

### 3.1 `TranscriptionProvider` protocol

```swift
protocol TranscriptionProvider {
    var id: ProviderID { get }
    func transcribe(audio: URL, hint: TranscriptionHint) async throws -> Transcript
}

struct TranscriptionHint {
    let language: LanguagePin      // .auto, .english, .german
    let dictionaryWords: [String]  // fed as prompt or phraseList per provider
}

struct Transcript {
    let text: String
    let detectedLanguage: String?
    let durationSeconds: Double
}
```

### 3.2 Azure OpenAI (default)

- `POST https://{resource}.openai.azure.com/openai/deployments/{deployment}/audio/transcriptions?api-version={apiVersion}`
- Auth: `api-key` header.
- Multipart form: `file` (wav), `prompt` (dictionary words joined, biases recognition), `language` (only when pinned: `en`/`de`), `response_format=verbose_json` (gives detected language), `temperature=0`.
- Settings fields: resource endpoint, API key, STT deployment name, api-version (default `2024-10-21`).
- Note: Microsoft docs indicate whisper and gpt-4o-transcribe retired on Azure OpenAI around 2026-06-01. Wasim's deployment may still work; he verifies. If it dies, `gpt-4o-transcribe-diarize` (GA until April 2027) is the batch REST alternative on the same endpoint shape, and the realtime models remain an option to explore later. Either way it's the same provider config, just a different deployment name.

### 3.3 Azure Speech / MAI-Transcribe (built in, selectable when available)

- `POST https://{resource}.cognitiveservices.azure.com/speechtotext/transcriptions:transcribe?api-version=2025-10-15`
- Auth: `Ocp-Apim-Subscription-Key` header.
- Multipart: `audio` file + `definition` JSON:

```json
{
  "locales": ["en-US", "de-DE"],
  "phraseList": { "phrases": ["Karko", "Supabase", "Wasim"] },
  "enhancedMode": { "enabled": true, "model": "mai-transcribe-1.5" }
}
```

- `phraseList` is the native dictionary mechanism (~30% WER reduction on domain terms per Microsoft).
- MAI-Transcribe-1.5 is public preview as of 2026-06-02 and not yet reachable on Wasim's subscription. The provider ships disabled-by-default; turning it on is a settings toggle once Azure exposes it to him.

### 3.4 OpenAI API (fallback)

- `POST https://api.openai.com/v1/audio/transcriptions`
- Auth: `Authorization: Bearer`.
- Same multipart shape as Azure OpenAI with an explicit `model` field (`whisper-1` or `gpt-4o-transcribe`).

### 3.5 Fallback chain

Ordered list in settings, default: Azure OpenAI -> OpenAI API (-> MAI when enabled). On provider error or timeout (15s), the next provider gets the same audio. The HUD shows which provider served the request when it wasn't the primary. If all fail, the audio file is kept and the HUD offers retry.

### 3.6 Formatting model

- Azure OpenAI chat completions: `POST https://{resource}.openai.azure.com/openai/deployments/{gptDeployment}/chat/completions?api-version={apiVersion}`.
- Settings: GPT deployment name (a fast model like gpt-4o-mini or gpt-4.1-mini class). Falls back to OpenAI API key with a configurable model if Azure fails.

## 4. Architecture

Menu bar app (`NSStatusItem` for icon animation), no Dock icon, launch-at-login via `SMAppService`. Single process. Modules:

| Module | One job | Depends on |
|---|---|---|
| `HotkeyManager` | CGEventTap; toggle key, Esc-cancel while active, voice-edit key. Consumes handled keys. | Accessibility permission |
| `AudioRecorder` | AVAudioEngine tap -> 16kHz mono PCM16 wav in a temp dir; live RMS levels; silence watchdog (auto-stop after 60s silence, configurable); 10 min hard cap | Microphone permission |
| `TranscriptionService` | Runs the provider chain with hint (language pin + dictionary) | Providers, Keychain |
| `FormattingService` | Chat call: raw transcript + frontmost app bundle id -> profile + dictionary + snippets. Returns `{text, newTerms[]}` JSON. Skippable (raw mode toggle and per-dictation modifier) | Azure/OpenAI GPT |
| `TextInserter` | AX insertion (`kAXSelectedTextAttribute` on focused element) first; fallback clipboard + synthetic Cmd-V with prior clipboard restored; always also writes final text to clipboard | Accessibility permission |
| `DictionaryStore` | Words + optional "sounds like" aliases; feeds providers and formatter; holds pending auto-suggestions | SwiftData |
| `SnippetStore` | Spoken trigger -> expansion text; applied during formatting | SwiftData |
| `HistoryStore` | Every dictation: raw text, final text, app, provider, duration, est. cost, timestamp. Searchable, one-click copy | SwiftData |
| `NotesStore` | Lightweight notes dictated inside the app | SwiftData |
| `VoiceEditService` | Reads selection (AX, Cmd-C fallback), records spoken instruction, rewrites via GPT, replaces selection | TextInserter |
| `HUD` | Non-activating floating `NSPanel`, bottom-center of active screen. States: recording (waveform + timer), transcribing, formatting, inserting, done, error | - |
| `SettingsWindow` | Providers, hotkeys, language pin, profiles, dictionary, snippets, cost meter, permissions status | Keychain |

### Data flow (core loop)

```
toggle key
  -> AudioRecorder starts, HUD shows waveform
toggle key again (or 60s silence, or Esc to abort)
  -> wav file closed
  -> TranscriptionService (provider chain, dictionary bias, language hint)
  -> raw Transcript  ........................ saved to History immediately
  -> FormattingService (app profile + dictionary + snippets), unless raw mode
  -> final text  ............................ History row updated
  -> TextInserter (AX -> paste fallback) + clipboard
  -> Dictionary auto-suggestions queued from formatter's newTerms
  -> HUD: done (or precise error)
```

### Formatting profiles

A profile is a named system-prompt fragment plus a list of app bundle ids. Defaults shipped:

- **Prompt/code** (Cursor, VS Code, Terminal, Warp): keep technical terms, camelCase/snake_case, no filler, no greetings, plain imperative sentences.
- **Chat** (Slack, Discord, WhatsApp, Telegram): casual, contractions, short.
- **Mail/docs** (Mail, Pages, Google Docs domains in browsers fall back to default): full sentences, proper punctuation.
- **Default**: light cleanup, neutral tone.

The formatter always: removes filler words, fixes punctuation/casing, applies mid-sentence corrections ("at 2... actually 3" -> "at 3"), formats spoken lists, enforces dictionary spellings, expands snippet triggers, and replies in the language of the transcript (German stays German). Profiles are editable in settings.

**Speaker context:** the formatter's system prompt states that the speaker is an AI specialist and founder whose dictations are usually about AI engineering and dev tooling. Ambiguous transcriptions resolve toward that domain: "cloud code" -> "Claude Code", "codecs" -> "Codex", "cursor" stays the editor, not the pointer. This context line is editable in settings.

### Dictionary lifecycle

The dictionary is deliberately small. It has two layers:

- **Base vocabulary (shipped, read-only, toggleable):** ~40 AI/dev terms Wasim says daily: Claude, Claude Code, Codex, Anthropic, OpenAI, Whisper, MCP, LLM, RAG, agent, token, repo, PR, Supabase, Next.js, Vercel, Stripe, Bedrock, Tailwind, TypeScript, Karko AI, Sadaa, and similar. Lives in a bundled file, not in the user's list, so the personal dictionary stays clean.
- **Personal dictionary (user-managed):** stays lean by design.

Lifecycle:

1. Wasim adds words manually (word + optional "sounds like" alias).
2. Every transcription request carries a bias list: personal words first (most recently used first), then base terms, cut off at the provider budget (whisper's `prompt` accepts ~224 tokens; MAI's `phraseList` allows more).
3. The formatter enforces correct spellings post-hoc.
4. The formatter returns `newTerms`: unusual proper nouns/jargon it had to guess, max 3 per dictation. These appear as pending suggestions (badge on the dictionary panel); one click accepts, one dismisses. Dismissed terms aren't suggested again.

## 5. Error handling

Rule: **never lose a dictation, never fail silently.**

- Raw transcript is written to History before formatting or insertion is attempted.
- Audio file is deleted only after a transcript exists; last 10 audio files are retained for retry/debugging (configurable, default on).
- Provider failure -> automatic fallback chain; non-primary provider use is surfaced in the HUD.
- All providers fail -> HUD error with one-click retry; audio retained.
- Formatting failure -> insert the raw transcript instead, HUD notes "raw (formatter offline)".
- Insertion: AX write fails -> paste fallback -> if both fail, text is on the clipboard and the HUD says "Copied, press Cmd-V".
- Secure input active (password fields): detected via `IsSecureEventInputEnabled()`, dictation is refused with a clear HUD message instead of typing into a password box.
- Mic/Accessibility permission missing -> onboarding checklist window with deep links to System Settings panes.
- No speech detected in the whole recording -> discard with HUD notice, nothing inserted, nothing billed beyond the STT call.

## 6. Security and privacy

- API keys in macOS Keychain only. Never in files, never logged, never in SwiftData.
- Audio and transcripts stay local (`~/Library/Application Support/Sadaa/`) except the API calls themselves.
- No analytics, no telemetry.
- `.env*` files are not used by this project.

## 7. Cost meter

Each history row stores `durationSeconds * providerRatePerSecond` plus a rough formatter token estimate. Rates are editable constants in settings (defaults: whisper-class $0.006/min, MAI $0.006/min, formatter estimated from characters). Settings shows this month's minutes and estimated spend. This is an estimate for credit awareness, not accounting.

## 8. Defaults

| Setting | Default |
|---|---|
| Toggle hotkey | Right Option (tap). No character output, no app conflicts. Rebindable. |
| Voice edit hotkey | Ctrl+Option+E, rebindable |
| Cancel | Esc while recording |
| Raw-mode modifier | Hold Shift when stopping -> skip formatter |
| Language | Auto-detect, pin via menu bar (Auto/EN/DE) |
| Silence auto-stop | 60s |
| Max recording | 10 min |
| Audio retention | Last 10 recordings |
| Formatter | On |

## 9. Branding

Sadaa wears the Karko AI brand (source of truth: `Karko_AI/src/app/globals.css`).

| Token | Value | Use |
|---|---|---|
| Navy 600 | `#1E3A5F` | Primary, HUD background, icon base |
| Navy 800 | `#12243B` | Depth/shadows |
| Gold 400 | `#D4A853` | Accent, waveform, active states |
| Gold 300/600 | `#E0C687` / `#A37824` | Gradient stops, 3D shading |
| Cream 100 | `#FAF7F2` | Light surfaces, settings background |
| Sage 500 | `#5B8A72` | Success states |
| Charcoal | `#2D3748` | Text on light |
| Font | Inter (system fallback) | All UI |

**App icon:** macOS squircle with a 3D-feel sound-wave mark (Notion-style soft extrusion and lighting), navy wave with a gold center bar on cream, meaningful to the name (Sadaa = voice). Chosen variant: `assets/branding/sadaa-icon-b-navy-on-cream.svg` (master) -> generated `.icns`. The HUD pill and menu bar states reuse the same mark.

## 10. Testing

- **Unit tests (XCTest):** provider request builders (URL shape, auth header, multipart body, prompt/phraseList injection, api-version), fallback-chain logic, formatter prompt construction and `newTerms` JSON parsing, cost math, dictionary suggestion dedupe. Networking mocked with `URLProtocol` stubs.
- **Integration smoke (manual checklist, repeated before calling any milestone done):** hotkey toggle in Cursor, Chrome, Slack, Mail, Terminal; Esc cancel; clipboard restore after paste fallback; secure-input refusal; German dictation; dictionary word recognized; provider fallback by breaking the primary key.
- AX insertion and CGEventTap behavior can't be meaningfully automated; the checklist owns them.

## 11. Build sequence (high level)

1. Menu bar skeleton + hotkey + audio capture + HUD (records and plays back, nothing else).
2. Azure OpenAI provider + insertion + clipboard backup. **This is the usable MVP.**
3. Formatting pass + per-app profiles + raw-mode modifier.
4. Dictionary: manual entries + request biasing, then auto-suggest loop.
5. History panel + cost meter.
6. Fallback chain + OpenAI provider + MAI provider (behind toggle).
7. Snippets, voice edit mode, notes.
8. Onboarding/permissions flow, settings polish, launch-at-login, app icon.

Detailed task breakdown lives in the implementation plan (next document).

## 12. Risks

| Risk | Mitigation |
|---|---|
| Azure OpenAI whisper deployment already retired | Verify first thing; same provider works with `gpt-4o-transcribe-diarize` deployment; OpenAI API fallback ships at launch |
| MAI-Transcribe-1.5 not yet on Wasim's subscription | Ships as disabled provider; enabling is a toggle |
| MAI is preview, no SLA | It's a fallback/optional provider, not the default |
| Some apps block AX text insertion (Electron, browser address bars) | Paste fallback + clipboard always set |
| CGEventTap needs Accessibility (sometimes Input Monitoring) | Onboarding detects and deep-links both panes |
| Whisper cold start after idle (2-5s occasionally) | Known Azure behavior; fallback timeout at 15s covers the worst case; HUD shows progress so it never feels hung |
