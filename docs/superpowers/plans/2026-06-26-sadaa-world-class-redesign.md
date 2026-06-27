# Sadaa World-Class Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the rejected previous premium pass with a full navy/cream/white/gold command-center redesign, remove MAI/legacy/fallback clutter, and make Language Memory a stronger correction-learning system for AI-specialist dictation.

**Architecture:** Work in vertical phases that each keep the app buildable. Keep SadaaCore responsible for provider policy, Memory learning, and persistence; keep SadaaApp responsible for the visual shell, pages, and interaction polish. Use shared SwiftUI primitives so Home, Memory, Scratchpad, History, Settings, and HUD look like one premium product instead of separate MVP screens.

**Tech Stack:** Swift 5.9 package, SwiftUI, AppKit, Foundation JSON stores, macOS Keychain, Swift Testing via `make test`, macOS 14+ Apple Silicon.

## Global Constraints

- The previous premium redesign is not the target.
- The visual system must use navy, cream, white, and restrained gold.
- Sadaa is a private voice layer for daily AI work.
- Do not add auth, cloud sync, teams, billing, analytics, or onboarding marketing screens.
- The main window has five sections: Home, Memory, Scratchpad, History, Settings.
- The app remains menu-bar first.
- Remove MAI, legacy model options, OpenAI fallback UI, and fallback-provider language from the primary app.
- The runtime provider chain should be simple: configured Azure transcription is the transcription provider.
- Corrections run locally even when GPT formatting is off or unavailable.
- History should make Memory better; it is not just an archive.
- Completion requires automated verification, visual/runtime verification, PR, merge to `main`, install, launch, and an evidence document.

---

## File Structure

### Modify

- `Sources/SadaaCore/Settings/AppSettings.swift`: remove active preset/fallback settings; keep Azure, GPT, language, hotkeys, storage, rates, and sound settings.
- `Sources/SadaaApp/AppDelegate.swift`: make `buildProviders(settings:)` return only configured Azure OpenAI; remove fallback-provider HUD messages; keep formatter fallback for GPT only.
- `Sources/SadaaApp/Pages/SettingsPage.swift`: rewrite into one flat premium settings surface with Azure, GPT formatting, language, hotkeys, permissions, storage, and diagnostics.
- `Sources/SadaaApp/Theme.swift`: extend the navy/cream/white/gold palette with named surface, border, focus, and text colors.
- `Sources/SadaaApp/Components/PremiumControls.swift`: replace small controls with shared command-center primitives.
- `Sources/SadaaApp/RootView.swift`: rename Language Memory navigation to Memory and rebuild the shell.
- `Sources/SadaaApp/Pages/HomePage.swift`: rebuild as command cockpit with readiness, mic, today metrics, recent actions, and Learning Pulse.
- `Sources/SadaaApp/Pages/LanguageMemoryPage.swift`: rebuild as split Memory workbench with Terms, Corrections, Snippets, Learning Queue.
- `Sources/SadaaApp/Components/MemoryRows.swift`: update row styling and action density for the split workbench.
- `Sources/SadaaApp/Pages/ScratchpadPage.swift`: rebuild as premium writing workspace.
- `Sources/SadaaApp/Components/ScratchpadRows.swift`: update note row styling for pinned/search/tag-heavy navigation.
- `Sources/SadaaApp/Pages/HistoryPage.swift`: rebuild as searchable transcript timeline with correction learning prominent.
- `Sources/SadaaApp/HUD/HUDView.swift`: polish the HUD as a premium navy instrument and remove provider-fallback copy.
- `README.md`: update current usage guidance and remove legacy/MAI/fallback recommendations.

### Test

- `Tests/SadaaCoreTests/AppSettingsTests.swift`: update defaults/roundtrip expectations after removing active preset/fallback settings.
- `Tests/SadaaCoreTests/DictationControllerTests.swift`: add an Azure-only/no-fallback behavior check at the controller seam.
- `Tests/SadaaCoreTests/LanguageMemoryStoreTests.swift`: add correction-learning expectations if the store API changes.
- `Tests/SadaaCoreTests/LanguageMemoryPostProcessorTests.swift`: keep deterministic correction/snippet tests green.
- `Tests/SadaaCoreTests/FormattingPromptBuilderTests.swift`: keep AI-specialist vocabulary and replacement prompt behavior green.

### Create

- `docs/release/sadaa-world-class-redesign-evidence-2026-06-26.md`: verification evidence, launch/install notes, and any manual limitations.

## Interfaces

Use these implementation-level interfaces and names:

```swift
public enum TranscriptionPreset: String, CaseIterable, Sendable {
    case fast, accurate
}
```

If `TranscriptionPreset` becomes unnecessary during implementation, delete it
and update all callers to use `AppSettings.azureDeployment` directly. Do not
keep `.speechMAI` or `.legacy`.

```swift
public var azureEndpoint: String
public var azureDeployment: String
public var azureAPIVersion: String
public var gptDeployment: String
public var formattingEnabled: Bool
public var speakerContext: String
public var languagePin: LanguagePin
public var hotkeyKeycode: Int
public var voiceEditKeycode: Int
public var languageSwitchKeycode: Int
public var soundEffectsEnabled: Bool
public var recordingsToKeep: Int
public var transcriptionRatePerMinute: Double
public var formatterRatePer1kChars: Double
```

The active app must not read or write `openaiEnabled`, `openaiModel`,
`maiEnabled`, `maiEndpoint`, `maiApiVersion`, or `maiModel`.

## Task 1: Remove Active Legacy/Fallback Provider Policy

**Files:**
- Modify: `Tests/SadaaCoreTests/AppSettingsTests.swift`
- Modify: `Sources/SadaaCore/Settings/AppSettings.swift`
- Modify: `Sources/SadaaApp/AppDelegate.swift`
- Modify: `Sources/SadaaApp/Pages/SettingsPage.swift`
- Modify: `README.md`

**Interfaces:**
- Consumes: current Azure, OpenAI, Azure Speech provider classes.
- Produces: active app path that exposes and constructs only Azure OpenAI transcription plus optional Azure GPT formatting.

- [ ] **Step 1: Write the failing AppSettings test**

Update `Tests/SadaaCoreTests/AppSettingsTests.swift` so `testDefaults()` expects no `.speechMAI` or `.legacy` cases:

```swift
#expect(TranscriptionPreset.allCases == [.fast, .accurate])
```

Remove assertions that depend on OpenAI fallback or MAI settings if present. Keep defaults for Azure, GPT, language, hotkeys, sound, and retention.

- [ ] **Step 2: Verify the test fails**

Run:

```bash
make test --filter AppSettingsTests/testDefaults
```

Expected: FAIL because `TranscriptionPreset.allCases` still includes `.speechMAI` and `.legacy`.

- [ ] **Step 3: Implement the settings cleanup**

In `Sources/SadaaCore/Settings/AppSettings.swift`, change:

```swift
public enum TranscriptionPreset: String, CaseIterable, Sendable {
    case fast, accurate, speechMAI, legacy
}
```

to:

```swift
public enum TranscriptionPreset: String, CaseIterable, Sendable {
    case fast, accurate
}
```

Remove active properties for OpenAI fallback and MAI from app-facing use. If removing stored properties causes too much churn, leave migration-compatible keys private and unused, but the active app must not call them.

- [ ] **Step 4: Remove fallback provider construction**

In `Sources/SadaaApp/AppDelegate.swift`, rewrite `buildProviders(settings:)` so it appends only `AzureOpenAIProvider` when endpoint, deployment, and key are configured. Remove OpenAI and MAI appends from active runtime.

- [ ] **Step 5: Remove fallback UI from Settings**

In `Sources/SadaaApp/Pages/SettingsPage.swift`, remove `fallbackCard`, OpenAI fields, MAI fields, `.speechMAI`, `.legacy`, and any copy that says provider fallback. Keep a simple Azure transcription section and a smart formatting section.

- [ ] **Step 6: Update README copy**

Remove Legacy fallback and Azure Speech/MAI recommendations. Recommended models become:

```markdown
- Fast daily dictation: Azure deployment of `gpt-4o-mini-transcribe`
- Best accuracy: Azure deployment of `gpt-4o-transcribe`
```

- [ ] **Step 7: Run targeted verification**

Run:

```bash
make test --filter AppSettingsTests
swift build
```

Expected: AppSettings tests pass and the app target builds.

- [ ] **Step 8: Commit**

```bash
git add Sources/SadaaCore/Settings/AppSettings.swift Sources/SadaaApp/AppDelegate.swift Sources/SadaaApp/Pages/SettingsPage.swift Tests/SadaaCoreTests/AppSettingsTests.swift README.md
git commit -m "feat: remove legacy fallback provider surface"
```

## Task 2: Build The Command-Center Design System

**Files:**
- Modify: `Sources/SadaaApp/Theme.swift`
- Modify: `Sources/SadaaApp/Components/PremiumControls.swift`
- Modify: `Sources/SadaaApp/RootView.swift`

**Interfaces:**
- Consumes: existing `Theme`, `PremiumStatusBadge`, `PremiumSearchField`, `PremiumIconButtonStyle`, `PremiumSection`.
- Produces: shared primitives for the new shell and all pages.

- [ ] **Step 1: Verify build baseline**

Run:

```bash
swift build
```

Expected: build succeeds before UI refactor.

- [ ] **Step 2: Extend Theme**

Add named colors in `Theme.swift`:

```swift
static let white = Color.white
static let ink = rgb(0x18, 0x24, 0x33)
static let muted = rgb(0x6B, 0x73, 0x80)
static let line = rgb(0xE6, 0xDD, 0xCD)
static let focus = gold
static let surface = creamSurface
```

Keep existing color names for compatibility.

- [ ] **Step 3: Replace shared controls**

In `PremiumControls.swift`, add:

```swift
struct CommandPageHeader<Accessory: View>: View
struct CommandPanel<Content: View>: View
struct CommandMetric: View
struct CommandToolbarButton: View
struct CommandEmptyState: View
```

All use navy text, white or cream surfaces, 8px or smaller radius except page-level tools, gold focus borders, and SF Symbols.

- [ ] **Step 4: Rebuild the shell**

In `RootView.swift`, rename `languageMemory` title to `Memory`, keep five sections, and restyle the sidebar as a compact navy product rail with a gold selected indicator. Keep `LanguageMemoryPage` as the Swift type name for now to avoid unnecessary file rename churn.

- [ ] **Step 5: Run verification**

Run:

```bash
swift build
```

Expected: build succeeds.

- [ ] **Step 6: Commit**

```bash
git add Sources/SadaaApp/Theme.swift Sources/SadaaApp/Components/PremiumControls.swift Sources/SadaaApp/RootView.swift
git commit -m "feat: add world-class command center design system"
```

## Task 3: Rebuild Home As A Cockpit

**Files:**
- Modify: `Sources/SadaaApp/Pages/HomePage.swift`

**Interfaces:**
- Consumes: `SadaaViewModel`, `DictationState`, `DictationHistory`, `LanguageMemoryViewModel`, shared command controls.
- Produces: Home page with readiness strip, premium mic, today metrics, recent actions, and Learning Pulse.

- [ ] **Step 1: Preserve compile baseline**

Run:

```bash
swift build
```

Expected: build succeeds before Home replacement.

- [ ] **Step 2: Rebuild the layout**

Replace the old centered stack with:

- `CommandPageHeader(title: "Command Center", subtitle: ...)`
- top readiness strip,
- mic/status panel,
- today metrics row,
- recent dictation panel with row action buttons,
- Learning Pulse panel from `viewModel.languageMemory.suggestions.prefix(4)`.

- [ ] **Step 3: Add recent row actions**

For each recent row expose copy, send to Scratchpad, learn correction, and reprocess. Use the existing `viewModel.sendToScratchpad(_:)` and `viewModel.reprocessHistoryWithLanguageMemory(_:)`.

- [ ] **Step 4: Run verification**

Run:

```bash
swift build
```

Expected: build succeeds and Home uses only command-center controls.

- [ ] **Step 5: Commit**

```bash
git add Sources/SadaaApp/Pages/HomePage.swift
git commit -m "feat: rebuild home as command cockpit"
```

## Task 4: Rebuild Memory As Split Workbench

**Files:**
- Modify: `Sources/SadaaApp/Pages/LanguageMemoryPage.swift`
- Modify: `Sources/SadaaApp/Components/MemoryRows.swift`
- Modify: `Tests/SadaaCoreTests/LanguageMemoryStoreTests.swift`

**Interfaces:**
- Consumes: `LanguageMemoryViewModel`, `MemoryTerm`, `ReplacementRule`, `MemorySnippet`, `MemorySuggestion`.
- Produces: split workbench with Terms, Corrections, Snippets, Learning Queue and stronger learn-correction behavior.

- [ ] **Step 1: Write the failing learning test**

Add a Swift Testing case that saves `"cloud code"` -> `"Claude Code"` as a replacement and equal text `"Codex"` as a high-priority term. Put the test in `Tests/SadaaCoreTests/LanguageMemoryStoreTests.swift` if it can exercise store-level behavior directly; otherwise create the smallest testable core helper used by `LanguageMemoryViewModel.learnCorrection(observed:corrected:)`.

Run:

```bash
make test --filter LanguageMemoryStoreTests
```

Expected: FAIL until the tested behavior exists.

- [ ] **Step 2: Implement or preserve learning behavior**

Ensure correction pairs become `ReplacementRule(match: observed, replacement: corrected, matchMode: .wordBoundaryPhrase)` and equal pairs become `MemoryTerm(priority: .high)`.

- [ ] **Step 3: Rebuild Memory page layout**

Use:

- left rail: search, mode switcher, metrics, import/export,
- center list: rows,
- right inspector/composer for the selected mode.

Rename UI copy from Language Memory to Memory while keeping storage/model names.

- [ ] **Step 4: Upgrade rows**

Rows show phrase/match/trigger, language, usage, enabled state, and last-updated style metadata. Use icon buttons for edit, pause/resume, delete, accept, dismiss.

- [ ] **Step 5: Run verification**

Run:

```bash
make test --filter LanguageMemory
swift build
```

Expected: Language Memory tests pass and app builds.

- [ ] **Step 6: Commit**

```bash
git add Sources/SadaaApp/Pages/LanguageMemoryPage.swift Sources/SadaaApp/Components/MemoryRows.swift Sources/SadaaApp/ViewModels/LanguageMemoryViewModel.swift Tests/SadaaCoreTests/LanguageMemoryStoreTests.swift
git commit -m "feat: rebuild memory as learning workbench"
```

## Task 5: Rebuild Scratchpad As Writing Workspace

**Files:**
- Modify: `Sources/SadaaApp/Pages/ScratchpadPage.swift`
- Modify: `Sources/SadaaApp/Components/ScratchpadRows.swift`

**Interfaces:**
- Consumes: `ScratchpadViewModel`, `ScratchpadNote`, shared command controls.
- Produces: premium writing workspace with pinned note rail, editor, metadata, and utility actions.

- [ ] **Step 1: Run scratchpad tests**

Run:

```bash
make test --filter Scratchpad
```

Expected: scratchpad store/migrator tests pass before UI work.

- [ ] **Step 2: Rebuild layout**

Use a three-zone workspace: left note rail, central white editor, utility strip. Keep search, pins, tags, autosave, stats, append latest dictation, duplicate, Markdown copy/export, JSON backup/restore.

- [ ] **Step 3: Run verification**

Run:

```bash
swift build
```

Expected: app builds with rebuilt Scratchpad.

- [ ] **Step 4: Commit**

```bash
git add Sources/SadaaApp/Pages/ScratchpadPage.swift Sources/SadaaApp/Components/ScratchpadRows.swift
git commit -m "feat: rebuild scratchpad as premium writing workspace"
```

## Task 6: Rebuild History As Transcript Timeline

**Files:**
- Modify: `Sources/SadaaApp/Pages/HistoryPage.swift`

**Interfaces:**
- Consumes: `DictationHistory`, `DictationRecord`, `SadaaViewModel`.
- Produces: premium searchable timeline where copy, send to Scratchpad, learn correction, and reprocess are prominent.

- [ ] **Step 1: Run history tests**

Run:

```bash
make test --filter DictationHistory
```

Expected: history tests pass before UI work.

- [ ] **Step 2: Rebuild timeline**

Use `CommandPageHeader`, filter/search row, grouped timeline, and a selected-record inspector or expanded row. Keep day grouping and existing actions.

- [ ] **Step 3: Make Learn correction prominent**

The row action uses the existing correction sheet but the button must be visible with a graduation-cap or sparkles-style SF Symbol and help text.

- [ ] **Step 4: Run verification**

Run:

```bash
swift build
```

Expected: app builds with rebuilt History.

- [ ] **Step 5: Commit**

```bash
git add Sources/SadaaApp/Pages/HistoryPage.swift
git commit -m "feat: rebuild history as transcript timeline"
```

## Task 7: Rebuild Settings And HUD

**Files:**
- Modify: `Sources/SadaaApp/Pages/SettingsPage.swift`
- Modify: `Sources/SadaaApp/HUD/HUDView.swift`

**Interfaces:**
- Consumes: cleaned settings from Task 1, shared command controls, `HUDState`.
- Produces: flat useful Settings and premium navy HUD without fallback-provider copy.

- [ ] **Step 1: Rebuild Settings**

Layout sections in one scrollable surface:

- Azure transcription,
- GPT formatting,
- language,
- hotkeys,
- app behavior,
- permissions,
- storage and cost,
- diagnostics.

No MAI, no legacy, no OpenAI fallback.

- [ ] **Step 2: Rebuild HUD polish**

Keep the existing HUD state enum. Restyle to navy capsule, cream text, gold waveform/focus detail, clear state labels, timer, Esc hint, retry/error copy.

- [ ] **Step 3: Scan for forbidden UI strings**

Run:

```bash
rg -n "MAI|Azure Speech|Legacy|OpenAI if Azure fails|fallback providers|Speech/MAI" Sources/SadaaApp README.md
```

Expected: no matches in active app UI or README.

- [ ] **Step 4: Run verification**

Run:

```bash
swift build
```

Expected: app builds with flat Settings and polished HUD.

- [ ] **Step 5: Commit**

```bash
git add Sources/SadaaApp/Pages/SettingsPage.swift Sources/SadaaApp/HUD/HUDView.swift README.md
git commit -m "feat: rebuild settings and hud for focused azure workflow"
```

## Task 8: Full Verification, Bundle, Install, PR, Merge Evidence

**Files:**
- Create: `docs/release/sadaa-world-class-redesign-evidence-2026-06-26.md`

**Interfaces:**
- Consumes: completed source changes.
- Produces: verification evidence and release-ready branch.

- [ ] **Step 1: Run full automated verification**

Run:

```bash
make test
swift build
make bundle
rg -n "documentDirectory|/Documents|NSDocumentDirectory" Sources Tests
rg -n "MAI|Azure Speech|Legacy|OpenAI if Azure fails|Speech/MAI" Sources/SadaaApp README.md
```

Expected:

- `make test` passes,
- `swift build` passes,
- `make bundle` produces `dist/Sadaa.app`,
- Documents scan returns no source/test matches,
- forbidden active UI string scan returns no matches.

- [ ] **Step 2: Launch and install locally**

Run:

```bash
open dist/Sadaa.app
make install
```

Expected: app launches and installed bundle replaces `/Applications/Sadaa.app`.

- [ ] **Step 3: Visual/runtime pass**

Inspect Home, Memory, Scratchpad, History, Settings, and HUD. Record:

- palette uses navy/cream/white/gold,
- Settings is flat and free of MAI/legacy/fallback clutter,
- Memory has Terms, Corrections, Snippets, Learning Queue,
- Scratchpad has writing workspace behavior,
- History has correction learning and reprocess actions,
- text does not obviously overflow at normal window sizes.

- [ ] **Step 4: Write evidence document**

Create `docs/release/sadaa-world-class-redesign-evidence-2026-06-26.md` with command outputs, launch/install notes, visual findings, and any manual checks blocked by credentials or macOS permissions.

- [ ] **Step 5: Commit evidence**

```bash
git add docs/release/sadaa-world-class-redesign-evidence-2026-06-26.md
git commit -m "docs: record world-class redesign verification"
```

- [ ] **Step 6: Push and PR**

Run:

```bash
git push -u origin codex/sadaa-world-class-redesign
gh pr create --title "Redesign Sadaa as world-class AI dictation command center" --body-file docs/release/sadaa-world-class-redesign-evidence-2026-06-26.md --draft
```

Expected: branch pushes and a draft PR is created.

- [ ] **Step 7: Review, merge, and final install check**

After review passes, merge PR to `main`, switch to `main`, pull, run:

```bash
make test
make bundle
make install
open /Applications/Sadaa.app
```

Expected: tests pass, bundle builds, installed app launches.

## Self-Review

- Spec coverage: Tasks 1 and 7 cover removal of MAI/legacy/fallback clutter; Tasks 2-7 cover the full visual redesign; Tasks 4 and 6 cover Memory learning and History teaching; Task 5 covers Scratchpad; Task 8 covers verification, install, PR, merge, and evidence.
- Red-flag scan: this plan contains no unresolved filler text or unspecified implementation slots.
- Type consistency: existing type names are preserved where possible; `TranscriptionPreset` is explicitly narrowed to `.fast` and `.accurate` or removed if direct Azure deployment makes it unnecessary.
