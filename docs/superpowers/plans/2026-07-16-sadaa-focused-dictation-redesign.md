# Sadaa Focused Dictation Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. This plan is executed inline without subagents. Do not commit, push, open a PR, merge or install before the user reviews the localhost app.

**Goal:** Rebuild Sadaa around one clear dictation flow, a clean transcript library, a simple personal dictionary, focused notes and provider-neutral settings.

**Architecture:** Keep testable provider, settings, dictionary and persistence behavior in SadaaCore. Keep the macOS shell, pages and interaction states in SadaaApp. Add one OpenAI-compatible transcription provider beside the Azure provider, remove Voice Edit from active wiring and replace the existing dashboard-heavy pages with stable split-view workflows.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit, Swift Testing, URLSession, UserDefaults and macOS Keychain.

## Global Constraints

- macOS 14 minimum.
- No new packages.
- `npm` is irrelevant to this Swift package.
- White is the dominant surface, navy is the brand ink, gold is the only decorative/action accent and cream is secondary only.
- No gradients, glass effects, decorative glow, emoji icons or purple-family colors.
- One user-facing dictation flow. No Voice Edit or raw-mode hotkey behavior.
- API keys stay in Keychain and never appear in logs, diagnostics, exports or tests beyond dummy values.
- Preserve the untracked `NH_LP/` directory.
- Work on `codex/sadaa-dictation-redesign` and wait for user review before git publishing actions.

---

### Task 1: Provider-neutral speech connection

**Files:**
- Modify: `Sources/SadaaCore/Settings/AppSettings.swift`
- Create: `Sources/SadaaCore/Transcription/OpenAICompatibleProvider.swift`
- Modify: `Sources/SadaaApp/AppDelegate.swift`
- Modify: `Sources/SadaaApp/SadaaViewModel.swift`
- Test: `Tests/SadaaCoreTests/AppSettingsTests.swift`
- Create: `Tests/SadaaCoreTests/OpenAICompatibleProviderTests.swift`

**Interfaces:**
- Produce `SpeechProviderKind: String, CaseIterable, Sendable` with `.azureOpenAI` and `.openAICompatible`.
- Produce `AppSettings.speechProviderKind`, `compatibleEndpoint` and `compatibleModel`.
- Produce `OpenAICompatibleProvider.Config(baseURL:apiKey:model:)` and standard multipart transcription behavior.
- Active provider readiness is exposed as `providerConfigured` and `providerName` on `SadaaViewModel`.

- [ ] Write failing tests proving the default provider is Azure, generic settings round-trip and OpenAI-compatible requests use `POST {base}/v1/audio/transcriptions`, `Authorization: Bearer`, a `model` field, optional language and dictionary prompt.
- [ ] Run `make test` and confirm the new tests fail because the provider and settings do not exist.
- [ ] Implement the settings enum and generic provider with the same total deadline and response parser used by Azure.
- [ ] Update provider construction and readiness checks without reading Keychain values on the main thread.
- [ ] Run focused provider/settings tests and the full `make test` suite.

### Task 2: One active dictation flow

**Files:**
- Modify: `Sources/SadaaApp/HotkeyManager.swift`
- Modify: `Sources/SadaaApp/AppDelegate.swift`
- Modify: `Sources/SadaaApp/SadaaViewModel.swift`
- Modify: `Sources/SadaaCore/Settings/AppSettings.swift`
- Modify: `Sources/SadaaApp/HUD/HUDView.swift`
- Modify: `Tests/SadaaCoreTests/AppSettingsTests.swift`

**Interfaces:**
- HotkeyManager exposes dictation, cancel and language-switch callbacks only.
- `DictationController.toggle()` is called without a raw-mode modifier from the app layer.
- Old history modes continue to decode.

- [ ] Update tests to expect two configurable tap keys instead of three and to preserve distinct dictation/language keys.
- [ ] Run tests and confirm failure against the existing Voice Edit settings behavior.
- [ ] Remove Voice Edit settings, callbacks, hotkey recognizer, controller setup and HUD routing from the active app path.
- [ ] Remove Shift/raw-mode detection from the dictation hotkey callback.
- [ ] Grep active app sources for `voiceEdit`, `Voice Edit`, `rawMode` and user-facing mode copy. Keep only migration-compatible core code where necessary.
- [ ] Run `make test`.

### Task 3: Shared premium native design system and shell

**Files:**
- Modify: `Sources/SadaaApp/Theme.swift`
- Modify: `Sources/SadaaApp/Components/PremiumControls.swift`
- Modify: `Sources/SadaaApp/Components/SidebarItem.swift`
- Modify: `Sources/SadaaApp/RootView.swift`
- Modify: `Sources/SadaaApp/MainWindowController.swift`

**Interfaces:**
- Theme provides role-based colors: surface, surfaceSubtle, brand, brandStrong, accent, ink, muted, line, danger and success.
- Shared controls provide page title, panel, primary/secondary button, search field, empty state, labeled field and compact status line.

- [ ] Replace the cream detail background and sage accents with the approved white/navy/gold system.
- [ ] Remove decorative eyebrow copy, excessive badges, spring motion and uniform card styling from shared controls.
- [ ] Rename sidebar destinations to Dictate, Library, Dictionary, Notes and Settings.
- [ ] Build a quieter navy sidebar with a white content canvas and clear active state.
- [ ] Keep minimum-window navigation and keyboard focus usable.
- [ ] Run `swift build`.

### Task 4: Dictate page

**Files:**
- Modify: `Sources/SadaaApp/Pages/HomePage.swift`
- Modify: `Sources/SadaaApp/Components/MicButton.swift`

**Interfaces:**
- The page consumes current dictation state, provider readiness, language, hotkey, retry state and recent transcripts.
- The page exposes one primary action through `viewModel.toggle()`.

- [ ] Replace dashboard metrics with a compact readiness bar.
- [ ] Build the recording stage for idle, recording, processing, inserting, error and retry states.
- [ ] Add latest transcript actions and a three-row recent transcript section.
- [ ] Remove model posture, learning pulse, cost cards and multi-mode language.
- [ ] Verify text overflow and empty states in SwiftUI previews or renderer fixtures.
- [ ] Run `swift build`.

### Task 5: Dictionary page

**Files:**
- Modify: `Sources/SadaaApp/Pages/LanguageMemoryPage.swift`
- Modify: `Sources/SadaaApp/Components/MemoryRows.swift`
- Modify: `Sources/SadaaApp/ViewModels/LanguageMemoryViewModel.swift` only if a small presentation helper is required.

**Interfaces:**
- Two primary sections: words/names and auto-corrections.
- Suggestions are an inline review strip.
- Snippets remain behind an Advanced disclosure.

- [ ] Replace the four-mode workbench with a two-section page.
- [ ] Add direct quick-add rows with advanced disclosures for term metadata and replacement match settings.
- [ ] Render searchable, editable-looking rows with quiet metadata and hover actions.
- [ ] Move import/export to one menu and clear actions away from the primary toolbar.
- [ ] Add useful empty states and inline duplicate/validation feedback.
- [ ] Run `swift build` and memory-related tests.

### Task 6: Library page

**Files:**
- Modify: `Sources/SadaaApp/Pages/HistoryPage.swift`

**Interfaces:**
- Stable list/detail workspace using existing DictationHistory and correction/reprocess actions.
- Provider/cost/memory/mode metadata is placed in a collapsed Details section.

- [ ] Remove the metric strip, timeline rail and repeated icon action rows.
- [ ] Build compact date-grouped transcript rows with selection and search.
- [ ] Build a readable detail pane with Copy, Learn correction, Send to notes, Reprocess and Delete.
- [ ] Keep clear-history confirmation and add a useful no-results state.
- [ ] Ensure compact width presents the selected transcript without horizontal clipping.
- [ ] Run `swift build` and history tests.

### Task 7: Notes page

**Files:**
- Modify: `Sources/SadaaApp/Pages/ScratchpadPage.swift`
- Modify: `Sources/SadaaApp/Components/ScratchpadRows.swift`

**Interfaces:**
- Two-pane notes list/editor at regular width and stacked selected-note flow at compact width.
- One overflow menu owns pin, duplicate, export, import and delete actions.

- [ ] Remove the separate utility rail and colored statistic badges.
- [ ] Tighten the notes list and editor hierarchy.
- [ ] Keep autosave, search, tags, append latest dictation, Markdown export and JSON backup behavior.
- [ ] Add clear empty states for no notes and no search matches.
- [ ] Run `swift build` and scratchpad tests.

### Task 8: Settings page

**Files:**
- Modify: `Sources/SadaaApp/Pages/SettingsPage.swift`
- Modify: `README.md`

**Interfaces:**
- Settings sections: General, Speech provider, Writing and Data.
- Provider-specific fields are selected by `SpeechProviderKind`.
- Save and Test connection work for both provider types with redacted diagnostics.

- [ ] Replace the Azure dashboard and metric cards with calm grouped settings.
- [ ] Add provider selection and conditional Azure/OpenAI-compatible connection fields.
- [ ] Keep API keys in provider-specific Keychain accounts.
- [ ] Keep cleanup settings available under Writing and explain Azure-only cleanup when relevant.
- [ ] Remove Voice Edit hotkey controls and user-facing mode language.
- [ ] Update README setup and usage instructions for provider-neutral connections and the renamed pages.
- [ ] Run provider health, settings and full tests.

### Task 9: Visual verification and completion evidence

**Files:**
- Create or update renderer support only if required for screenshots.
- Create: `docs/release/sadaa-focused-redesign-2026-07-16/` screenshots.
- Create: `docs/release/sadaa-focused-redesign-verification-2026-07-16.md`.

**Interfaces:**
- Evidence covers Dictate, Library, Dictionary, Notes and Settings at regular and compact widths.

- [ ] Run `make test` and record the exact passing test count.
- [ ] Run `swift build -c release`, `make bundle` and `codesign --verify --deep --strict --verbose=2 dist/Sadaa.app`.
- [ ] Launch the bundled app without installing it.
- [ ] Capture and inspect every page at regular width and the key compact-width layouts.
- [ ] Check empty, populated, error/readiness, hover/focus and disabled states where available.
- [ ] Run `rg -n "gradient|backdrop-blur|blur-|indigo|violet|purple|fuchsia|animate-|marquee|✨|🤖"` across changed UI files and remove unjustified hits.
- [ ] Review active provider and diagnostic code for secret leakage.
- [ ] Start the local bundled preview for user review and stop before commit, push, PR, merge or installation.
