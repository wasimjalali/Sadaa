# Sadaa Premium Redesign - Design Spec

**Date:** 2026-06-26
**Status:** Approved direction, pending user review of written spec
**Platform:** macOS 14+, Apple Silicon, native Swift/SwiftUI
**Owner/User:** Wasim Jalali
**Builds on:** `2026-06-07-sadaa-design.md` and `2026-06-07-sadaa-main-window-design.md`

## 1. Product Intent

Sadaa becomes a premium, local-first voice operating layer for Wasim's own daily writing, prompting, coding, messaging, and note capture. It should feel closer to the best dictation products in the category: fast, calm, smart about personal vocabulary, and useful in every text field. It should not become a public SaaS product in this version.

The redesign has four jobs:

1. Make dictation feel high-end and reliable enough to use all day.
2. Replace the weak dictionary with a first-class "Language Memory" system.
3. Replace the lightweight notes page with a fast Scratchpad for dictated thinking.
4. Improve Azure model choices, provider setup, health checks, and verification.

## 2. V1 Scope Decision: Personal Local-First

This version is for Wasim first. No auth, cloud accounts, team management, billing, sync, or public launch infrastructure belongs in v1. Those concerns are deferred to v2, when the app is prepared for public release.

V1 storage remains local under Sadaa's Application Support directory. API keys remain in macOS Keychain. Import/export and local backup are in scope because they help personal durability without creating cloud complexity.

Do not access or use the user's `Documents` folder. Export and backup flows default to a user-chosen folder or Sadaa-controlled Application Support paths, never `~/Documents`.

## 3. Current App Baseline

The current app already has a strong foundation:

- Native macOS app with SwiftUI pages and AppKit glue.
- Global tap hotkeys for dictation, voice edit, language switching, and Esc cancel.
- Floating HUD with recording, transcribing, delivering, success, error, and language states.
- Azure OpenAI transcription provider, optional OpenAI fallback, and Azure Speech/MAI provider plumbing.
- Smart formatting through Azure chat completions.
- History, dictionary, snippets, notes, cost estimates, and provider fallback tests.
- JSON-backed stores and macOS Keychain secrets.

The app passes its current baseline test suite before this redesign begins: 188 tests pass via `make test`.

The weak areas are product depth and information architecture:

- Dictionary is a flat list of words plus optional sounds-like aliases. It helps, but it does not feel intelligent.
- Snippets are hidden inside the Dictionary page, though they are part of the same personal-language workflow.
- Notes are basic add/edit/copy/delete rows, not a daily capture surface.
- Settings are powerful but crowded and provider/model choices are too manual.
- History cannot yet reprocess dictations, teach corrections, or send text into notes.
- The UI has a nice brand palette, but the pages still feel like a functional MVP rather than a premium product.

## 4. Competitor Patterns To Use

Useful patterns to adapt, without copying product bloat:

| Product | Pattern worth adopting | How Sadaa adapts it |
|---|---|---|
| Wispr Flow | Personal dictionary with words and replacement rules | Language Memory terms plus deterministic replacements |
| Wispr Flow | Snippets for repeated spoken phrases | Snippets become a first-class tab inside Language Memory |
| Wispr Flow | Command Mode for selected text | Existing Voice Edit is kept and polished as selected-text command editing |
| Wispr Flow | Scratchpad notes | Sadaa Notes becomes a local Scratchpad with search, pins, auto-save, and markdown |
| Superwhisper | Vocabulary and automatic replacements | Separate terms from replacement rules, and apply both in the pipeline |
| Superwhisper | Reprocess from history | History rows can retry/reprocess with the latest model/settings |
| TalkTastic | Context-aware writing | Keep frontmost-app context and speaker context, but avoid screen snapshots in v1 |

Not adopted in v1:

- Accounts, cloud sync, team dictionaries, team snippets, public billing, analytics, meeting transcription, diarization, mobile apps, and realtime live typing.
- Screen-snapshot context, because it adds privacy, permission, and failure complexity. V1 uses app bundle, selected text, clipboard-safe context, speaker context, and Language Memory.

Research inputs checked on 2026-06-26:

- Wispr Flow docs: dictionary words and replacement rules, snippets, Command Mode, Scratchpad notes.
- Superwhisper docs: vocabulary plus replacement rules, history reprocessing.
- Microsoft Learn and Microsoft Foundry sources: Azure OpenAI audio/transcription models, Azure Speech fast transcription, MAI-Transcribe, phrase-list support.

## 5. Product Principles

- **Fast first:** dictation must remain the primary workflow. No feature can slow the start/stop/transcribe/insert loop unnecessarily.
- **Local-first privacy:** audio, history, notes, dictionary, replacements, snippets, and backups stay local unless explicitly exported by the user.
- **No feature flooding:** every new feature must either improve dictation quality, reduce repeated typing, improve note capture, improve recovery, or make setup safer.
- **Explainable memory:** the user should be able to see why Sadaa keeps spelling something a certain way.
- **Premium utility, not marketing:** dense, calm, native UI. Avoid decorative cards and landing-page composition inside the app.
- **Never lose work:** audio, raw transcripts, formatted text, notes, and exports need clear recovery paths.

## 6. Primary Navigation

Rename and organize the main window into five sections:

| Section | Purpose |
|---|---|
| Home | Readiness, hotkey state, model health, recent dictations, quick actions |
| Language Memory | Terms, replacements, snippets, suggestions, imports, exports |
| Scratchpad | Local note capture, pinned notes, markdown/plain text, dictated notes |
| History | Dictation archive, search, copy, retry, reprocess, learn correction, send to note |
| Settings | Providers, models, hotkeys, language, formatting, permissions, storage, diagnostics |

The app remains a hybrid menu-bar plus main-window app. The hotkey/HUD workflow remains primary; the window is the control center.

## 7. Visual And Interaction Direction

Keep the Karko palette but make the product feel more mature:

- Background: warm cream for content, navy sidebar, restrained gold accents, sage success states.
- Typography: system San Francisco unless a packaged font is already justified. Avoid introducing a font dependency.
- Layout: compact, structured, scan-friendly. No nested cards. Cards only for repeated items and focused tools.
- Controls: icon buttons for copy, delete, retry, learn, pin, export, and edit. Use SF Symbols because this is SwiftUI/macOS.
- Density: operational app density, not SaaS landing-page scale.
- Motion: subtle state transitions, respect Reduce Motion, no decorative animation outside the HUD and useful feedback.

Home should feel like a premium cockpit:

- Large but not oversized mic/status center.
- Provider health, selected language, formatting mode, and hotkey active state visible at a glance.
- Recent dictations with copy, send to note, and learn correction affordances.
- This month usage/cost, compact and secondary.
- Clear next action when setup is incomplete.

The HUD remains the live "working" surface:

- Listening: waveform/logo, timer, Esc key hint.
- Processing: transcribing, formatting, inserting shown as clear stages.
- Done: success confirmation.
- Warning: copied-only, fallback provider, raw formatter fallback.
- Error: plain-language message with retry where possible.

## 8. Language Memory

Language Memory replaces the current Dictionary page. It is the most important feature in this redesign.

### 8.1 Data Model

Introduce a new `LanguageMemoryStore` in `SadaaCore`, persisted as JSON with a versioned schema and migration from existing dictionary/snippet files.

Core entities:

```swift
public struct MemoryTerm: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var phrase: String
    public var pronunciations: [String]
    public var aliases: [String]
    public var language: MemoryLanguage
    public var priority: MemoryPriority
    public var notes: String
    public var createdAt: Date
    public var updatedAt: Date
    public var usageCount: Int
}

public struct ReplacementRule: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var match: String
    public var replacement: String
    public var matchMode: ReplacementMatchMode
    public var language: MemoryLanguage
    public var isEnabled: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var usageCount: Int
}

public struct MemorySnippet: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var trigger: String
    public var expansion: String
    public var language: MemoryLanguage
    public var tags: [String]
    public var isEnabled: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var usageCount: Int
}

public struct MemorySuggestion: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var kind: MemorySuggestionKind
    public var observed: String
    public var proposed: String
    public var evidenceCount: Int
    public var lastSeenAt: Date
    public var source: MemorySuggestionSource
}
```

Enums:

- `MemoryLanguage`: auto, English, German.
- `MemoryPriority`: normal, high, always.
- `ReplacementMatchMode`: exact phrase, case-insensitive phrase, word-boundary phrase.
- `MemorySuggestionKind`: term, replacement, snippet candidate.
- `MemorySuggestionSource`: formatter, history correction, manual import, reprocess.

### 8.2 UI

Language Memory has four tabs:

1. **Terms:** names, product names, acronyms, domain words, multi-word phrases.
2. **Replacements:** deterministic fixes such as "cloud code" -> "Claude Code".
3. **Snippets:** spoken triggers such as "my signature" -> full expansion.
4. **Suggestions:** terms/replacements Sadaa proposes after repeated evidence.

Top area:

- Search across terms, replacements, snippets, and suggestions.
- Add button with a menu: term, replacement, snippet, import.
- Count summary: total terms, active replacements, snippets, pending suggestions.
- Import/export buttons.

Term editor:

- Phrase.
- Pronunciations/sounds-like list.
- Aliases.
- Language selector.
- Priority selector.
- Notes.
- Last used and usage count.

Replacement editor:

- Heard/mistaken phrase.
- Correct output.
- Match mode.
- Language selector.
- Enabled toggle.
- Test field: type sample text and preview replacement.

Snippet editor:

- Spoken trigger.
- Expansion text.
- Tags.
- Enabled toggle.
- Preview.

Suggestions:

- Ranked by evidence count and recency.
- Accept as term, accept as replacement, edit before accepting, dismiss.
- "Why this?" expands evidence: recent raw/final snippets, source, count.

### 8.3 Pipeline Behavior

Language Memory feeds three points in the pipeline:

1. **Provider hinting:** terms and pronunciations generate a capped bias list. The list is ordered by priority, recent usage, personal terms, then base vocabulary.
2. **Formatter enforcement:** terms, replacements, snippets, and speaker context are sent to the formatter prompt in structured sections.
3. **Deterministic cleanup:** replacement rules run locally after transcription and before/after formatter depending on rule type.

Proposed order:

```text
audio
  -> transcription provider with bias list
  -> raw transcript saved
  -> local pre-format replacements for obvious transcription mistakes
  -> formatter with terms/replacements/snippets/context
  -> local post-format replacements for deterministic final-output fixes
  -> history record saved with raw, intermediate, final, model, provider, memory hits
  -> insert/copy
  -> suggestions updated
```

History records should store enough diagnostics to understand memory behavior:

- raw text
- final text
- provider
- model/deployment
- formatting mode
- memory hits
- replacement rules applied
- suggestions generated

### 8.4 Migration

Migrate existing data automatically:

- Existing `DictionaryEntry.word` -> `MemoryTerm.phrase`.
- Existing `DictionaryEntry.soundsLike` -> one pronunciation.
- Existing `Snippet` -> `MemorySnippet`.
- Existing pending dictionary suggestions -> `MemorySuggestion(kind: term)`.

Keep a `.bak` of pre-migration files. Do not delete old files until the new store writes successfully.

### 8.5 Import And Export

Support:

- JSON export/import of full Language Memory.
- CSV import/export for terms and replacements.
- Duplicate handling by canonical match.
- Preview before import: new, updated, duplicate, invalid.

Default export location must not be `Documents`. Use an NSSavePanel and remember the last user-chosen export folder in app settings. If no folder has been chosen, default to the user's home directory or Desktop, not Documents.

## 9. Scratchpad Notes

The Notes page becomes Scratchpad: a fast local workspace for dictated notes, drafts, and structured thoughts.

### 9.1 Data Model

Introduce a versioned `ScratchpadStore` with migration from `NotesStore`.

```swift
public struct ScratchpadNote: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var body: String
    public var tags: [String]
    public var isPinned: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var lastOpenedAt: Date?
}
```

Migration:

- Existing `Note.text` becomes `body`.
- Title is generated from the first sentence or first line, capped to a short length.
- Existing created date is preserved.

### 9.2 UI

Scratchpad layout:

- Left note list with search, pins first, recent grouping, tag filter.
- Right editor with title, body, metadata, and actions.
- Auto-save on edit with debounced persistence.
- Empty state: create note, dictate note, import text.

Editor modes:

- Plain text editing.
- Markdown preview toggle.
- Focus mode that hides list/sidebar.

Actions:

- Copy note.
- Pin/unpin.
- Duplicate.
- Delete with confirmation.
- Export as `.txt` or `.md`.
- Create note from selected history item.
- Append latest dictation.

Voice-first behavior:

- If the editor is focused, dictation inserts into the note at the cursor.
- If no note is selected, a dictated note can create a new note.
- History row action "Send to Scratchpad" creates or appends to a note.

AI actions:

- Generate title.
- Clean up note.
- Summarize.
- Convert to bullets.
- Extract action items.

These actions use the existing formatter/GPT deployment and must fail clearly when no GPT deployment is configured. They never replace note text without a preview or undo path.

## 10. History Upgrades

History becomes more than an archive:

- Full-text search.
- Filters: date, provider, language, raw/formatted, fallback used, has memory hits.
- Row actions: copy, delete, send to Scratchpad, reprocess, retry audio if available, learn correction.
- Reprocess uses current model, current Language Memory, and selected formatting profile without re-recording.
- Retry reuses saved audio if available.
- Learn correction opens a compact sheet:
  - "Sadaa wrote"
  - "Should be"
  - Save as term or replacement
  - Apply to similar future dictations

History retention remains capped, but the cap should be visible and configurable. Audio retention remains separate and conservative.

## 11. Settings And Model Strategy

Settings should keep advanced power but reduce confusion.

### 11.1 Provider Presets

Add model presets:

| Preset | Provider/deployment intent | Use case |
|---|---|---|
| Fast | Azure OpenAI `gpt-4o-mini-transcribe` deployment | Daily short dictation, lowest latency |
| Accurate | Azure OpenAI `gpt-4o-transcribe` deployment | Hard audio, names, technical speech |
| Speech/MAI | Azure Speech LLM Speech with `mai-transcribe-1.5` where available | Fast transcription and phrase-list support |
| Legacy | Existing Whisper deployment | Compatibility with current setup |

The app cannot assume deployment names exist in the user's Azure tenant. The UI should ask for deployment names, but explain which model each preset expects.

### 11.2 Health Checks

Provider setup gets a "Test" button:

- Validates endpoint shape.
- Confirms key is present without displaying it.
- Sends a tiny generated WAV or uses a local test path where safe.
- Reports latency, provider, response text, and error details.

Health checks must not persist secrets outside Keychain and must not inspect Documents.

### 11.3 Recommended Defaults

For v1 personal use:

- Primary transcription: Azure OpenAI `gpt-4o-mini-transcribe` for speed, if available.
- Accuracy alternative: Azure OpenAI `gpt-4o-transcribe`.
- Azure Speech/MAI: optional path where the user has access, especially for phrase-list support.
- Realtime Whisper: defer to later. It changes architecture and is only justified if live text becomes a product goal.
- Formatter: Azure chat deployment already configured by the user, ideally a fast mini-class model.

### 11.4 Diagnostics

Settings gets a Diagnostics panel:

- Current provider chain.
- API version.
- Deployment names.
- Last provider error.
- Last fallback event.
- Audio retention path.
- History and Language Memory file paths.
- Export diagnostics bundle, excluding keys and excluding Documents.

## 12. Voice Edit

Keep the existing Voice Edit feature and polish it as Sadaa's selected-text command mode.

Behavior:

- Select text anywhere.
- Tap voice-edit hotkey.
- Speak command.
- Sadaa transcribes the command, rewrites the selected text, and replaces it.

Improvements:

- Clear HUD state: "Editing selection" and "Replacing".
- Better error messages when no selection is found.
- Optional preview mode for longer selections.
- History entry for voice edit operations with original, instruction, and result.
- Uses Language Memory and app context.

## 13. Local Storage And Privacy

Storage remains local:

- `~/Library/Application Support/Sadaa/history.json`
- `~/Library/Application Support/Sadaa/language-memory.json`
- `~/Library/Application Support/Sadaa/scratchpad.json`
- `~/Library/Application Support/Sadaa/Recordings/`
- `~/Library/Application Support/Sadaa/Backups/`

Keys:

- Azure/OpenAI keys stay in Keychain.
- No `.env` files.
- No keys in diagnostics.

Backups:

- Before migrations, write `.bak` files beside the old stores.
- Add manual "Create backup" action.
- Optional rolling local backups inside Sadaa's Application Support directory.

Explicit boundary:

- Do not read, scan, index, or default-save to the user's Documents folder.

## 14. Architecture

### 14.1 New Core Units

| Unit | Responsibility |
|---|---|
| `LanguageMemoryStore` | Versioned JSON store for terms, replacements, snippets, suggestions |
| `LanguageMemoryModels` | Codable types and enums |
| `LanguageMemoryMatcher` | Canonicalization, duplicate detection, rule matching |
| `MemoryBiasBuilder` | Builds provider-specific hint lists within budgets |
| `ReplacementEngine` | Applies deterministic rules safely |
| `MemorySuggestionEngine` | Ranks and dedupes suggestions |
| `LanguageMemoryMigrator` | Migrates DictionaryStore and SnippetStore into Language Memory |
| `ScratchpadStore` | Versioned JSON store for notes |
| `ScratchpadModels` | Codable note types |
| `ScratchpadMigrator` | Migrates NotesStore into Scratchpad |
| `ProviderHealthCheck` | Test provider setup without leaking secrets |
| `HistoryReprocessor` | Reprocess existing audio/transcripts with current settings |

### 14.2 App Units

| Unit | Responsibility |
|---|---|
| `PremiumRootView` or evolved `RootView` | Main shell and navigation |
| `HomePage` | Readiness cockpit and recent quick actions |
| `LanguageMemoryPage` | Terms/replacements/snippets/suggestions |
| `ScratchpadPage` | Notes list, editor, AI actions |
| `HistoryPage` | Search, filters, reprocess, learn correction, note handoff |
| `SettingsPage` | Provider presets, model health checks, permissions, diagnostics |
| Shared components | Toolbar buttons, search fields, segmented tabs, status badges, rows, editors |

Keep boundaries small. The current `DictionaryPage.swift`, `NotesPage.swift`, `HistoryPage.swift`, and `SettingsPage.swift` are likely to grow too large if all behavior stays inline. Split complex row/editor/sheet components into focused files when implementing.

### 14.3 View Model

The current `SadaaViewModel` can remain the app bridge, but it should delegate feature-specific logic to smaller observable models if it becomes too large:

- `LanguageMemoryViewModel`
- `ScratchpadViewModel`
- `HistoryActionsViewModel`
- `ProviderSettingsViewModel`

The implementation plan should choose the smallest split that keeps files readable.

## 15. Error Handling

Continue the rule: never lose a dictation and never fail silently.

New error rules:

- Failed Language Memory migration: keep old files, start old store, show migration warning.
- Invalid import file: preview errors, import nothing until the user confirms valid rows.
- Replacement rule conflict: show conflict before saving.
- Health check failure: show provider status and response body excerpt, never hide behind "unknown error".
- Scratchpad auto-save failure: show visible warning and keep in-memory text until saved or exported.
- Reprocess failure: preserve original history row; write no partial replacement.
- AI note action failure: do not modify the note; show actionable error.

## 16. Verification Strategy

### 16.1 Unit Tests

Add focused tests for:

- Language Memory migration from existing dictionary/snippets.
- Term canonicalization, alias matching, pronunciation retention.
- Replacement rules: exact, case-insensitive, word-boundary, disabled.
- Replacement conflict detection.
- Bias list ordering and caps.
- Suggestions ranking, evidence counts, dismiss behavior.
- Import/export JSON and CSV.
- Scratchpad add/update/delete/pin/search/tag/export.
- Notes migration.
- History reprocess preserves originals on failure.
- Provider health check request construction and redaction.
- Settings defaults for model presets.

### 16.2 Integration/Manual Smoke

Manual checklist before calling the app launched:

- Open app and verify Home readiness states.
- Dictate into a normal editor.
- Dictate into Scratchpad editor.
- Add a Language Memory term and verify it appears in provider hint and formatter context.
- Add a replacement and verify it fixes a sample transcript.
- Add a snippet and verify it expands.
- Accept and dismiss suggestions.
- Reprocess a history row.
- Learn correction from history.
- Send history item to Scratchpad.
- Test provider health check with valid and invalid settings.
- Verify keychain values are not printed or exported.
- Verify no path touches Documents.
- Build bundle with `make bundle`.
- Install/launch with `make install` if appropriate.

### 16.3 Adversarial Review

Before final deploy/push:

- Review migration failure paths.
- Review every text insertion path.
- Review replacement rules for accidental partial replacements.
- Review import/export for malformed rows.
- Review provider diagnostics for secret leakage.
- Review UI for text clipping and overlapping at narrow window sizes.
- Review no-Documents constraint with file path search.

## 17. Deployment And Release

V1 completion requires:

- All tests green.
- Bundle builds.
- App launches locally.
- Smoke checklist completed.
- Adversarial review completed and fixed.
- Changes pushed to GitHub `main` as requested by the user.
- Interactive HTML walkthrough created after implementation, showing:
  - what changed
  - how to use Home
  - how to use Language Memory
  - how to use Scratchpad
  - how to reprocess history and learn corrections
  - provider/model recommendations
  - verification performed

The walkthrough is a local HTML artifact in the repo or a docs/output folder, not stored in Documents.

## 18. Phased Build

### Phase 1: Foundation And Shell

- Rework navigation labels and app shell.
- Introduce shared premium components.
- Preserve current working dictation behavior.
- Add diagnostics/readiness layout on Home.

### Phase 2: Language Memory Backend

- Add models, store, matcher, bias builder, replacement engine, suggestion engine.
- Add migration from dictionary/snippets.
- Wire into transcription hints and formatter context.
- Add tests.

### Phase 3: Language Memory UI

- Replace Dictionary page with Language Memory tabs.
- Add editors, search, suggestions, import/export, previews.
- Add learn-correction entry points from history.

### Phase 4: Scratchpad Backend And UI

- Add Scratchpad store and migration.
- Build note list/editor/pins/search/tags/export.
- Add note actions and history-to-note flow.

### Phase 5: Provider And Model UX

- Add presets, provider health checks, clearer Azure setup.
- Add diagnostics panel.
- Update README with recommended Azure model setup.

### Phase 6: History Reprocess And Voice Edit Polish

- Add reprocess/retry actions.
- Add voice-edit history and clearer HUD states.
- Add selected text preview when useful.

### Phase 7: Verification, Deploy, Walkthrough

- Full tests.
- Bundle/install/launch.
- Adversarial review.
- Push to GitHub `main`.
- Create interactive HTML walkthrough.

## 19. V2/Public Release Deferral

Defer until after personal v1 is excellent:

- Auth.
- User accounts.
- Cloud sync.
- Team dictionaries/snippets.
- Public billing.
- Public telemetry/analytics.
- Cross-device mobile apps.
- Admin controls.
- Shared workspaces.
- Public onboarding funnel.

When v2 starts, the v1 local-first data model should be reusable as the local cache and sync payload shape.

## 20. Scope Boundaries

In v1:

- Premium native UI redesign.
- Language Memory terms/replacements/snippets/suggestions.
- Scratchpad notes.
- Model presets and provider health checks.
- History reprocess and learn correction.
- Local import/export/backup.
- Verification, adversarial review, bundle/install/launch, push main, HTML walkthrough.

Out of v1:

- Auth, cloud sync, public SaaS features, mobile, team workflows, realtime live typing, meeting transcription, diarization, screen snapshots, and app-store distribution.

## 21. Open Decisions For Implementation Plan

These do not block the spec, but the implementation plan must decide them explicitly:

1. Whether to evolve existing pages in place or introduce new page files and retire old ones gradually.
2. Whether `SadaaViewModel` stays single or splits into feature view models during Phase 2.
3. Whether history stores raw/intermediate/final text in the existing `DictationRecord` or a versioned replacement record.
4. Which CSV dialect to support for import/export.
5. Whether Scratchpad AI actions preview in a sheet or inline diff.

The recommended implementation style is incremental: preserve current dictation behavior after every phase and keep tests green at each checkpoint.
