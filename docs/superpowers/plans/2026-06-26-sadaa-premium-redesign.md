# Sadaa Premium Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the approved personal, local-first premium redesign for Sadaa: premium shell, Language Memory, Scratchpad, provider/model UX, history reprocessing, verification, launch, push to `main`, and an interactive HTML walkthrough.

**Architecture:** Execute in seven independently testable phases. Keep Sadaa's current dictation pipeline working after every phase, put new domain logic in `SadaaCore` with Swift Testing coverage, and keep SwiftUI/AppKit UI changes in focused SadaaApp files. The approved spec is broad, so this plan is the master implementation plan; each phase below is a review gate and can be implemented by a fresh subagent or by inline execution with checkpoint reviews.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit, Foundation JSON stores, macOS Keychain, SPM, Swift Testing through `make test`, macOS 14+ on Apple Silicon.

## Global Constraints

- Sadaa remains macOS 14+, Apple Silicon, native Swift/SwiftUI.
- This version is for Wasim first.
- No auth, cloud accounts, team management, billing, sync, or public launch infrastructure belongs in v1.
- V1 storage remains local under Sadaa's Application Support directory.
- API keys remain in macOS Keychain.
- Import/export and local backup are in scope.
- Do not access or use the user's `Documents` folder.
- Export and backup flows default to a user-chosen folder or Sadaa-controlled Application Support paths, never `~/Documents`.
- Keep the hotkey/HUD workflow primary; the main window is the control center.
- Keep current dictation behavior working after every phase.
- Every phase must end with `make test`; UI phases must also run `swift build`.
- Completion requires tests, bundle build, local launch, smoke checklist, adversarial review, push to GitHub `main`, and an interactive HTML walkthrough.

---

## Scope Split

The approved spec covers several independent subsystems: shell/UI, Language Memory, Scratchpad, provider UX, history reprocessing, Voice Edit polish, deployment, and walkthrough. Treat this as a phase-sequenced implementation, not one giant edit. Each task below should be committed separately.

## File Structure

### SadaaCore files to create

- `Sources/SadaaCore/LanguageMemory/LanguageMemoryModels.swift`: memory terms, replacements, snippets, suggestions, persisted container, enums.
- `Sources/SadaaCore/LanguageMemory/LanguageMemoryMatcher.swift`: canonicalization, duplicate detection, phrase boundaries.
- `Sources/SadaaCore/LanguageMemory/ReplacementEngine.swift`: deterministic pre/post formatting replacements.
- `Sources/SadaaCore/LanguageMemory/MemoryBiasBuilder.swift`: provider hint list ordering and caps.
- `Sources/SadaaCore/LanguageMemory/MemorySuggestionEngine.swift`: suggestion ranking and dismissal.
- `Sources/SadaaCore/LanguageMemory/LanguageMemoryStore.swift`: versioned JSON persistence and mutation API.
- `Sources/SadaaCore/LanguageMemory/LanguageMemoryMigrator.swift`: migration from `DictionaryStore` and `SnippetStore`.
- `Sources/SadaaCore/Scratchpad/ScratchpadModels.swift`: scratchpad note model.
- `Sources/SadaaCore/Scratchpad/ScratchpadStore.swift`: versioned JSON persistence and note actions.
- `Sources/SadaaCore/Scratchpad/ScratchpadMigrator.swift`: migration from `NotesStore`.
- `Sources/SadaaCore/ProviderHealth/ProviderHealthCheck.swift`: redacted provider test result model and local request helpers.
- `Sources/SadaaCore/History/HistoryReprocessor.swift`: pure/service logic for reprocessing saved text/audio without altering originals on failure.

### SadaaCore files to modify

- `Sources/SadaaCore/DictationController.swift`: wire memory replacement and richer history diagnostics.
- `Sources/SadaaCore/Formatting/FormattingContext.swift`: carry memory terms, replacements, snippets, and scratchpad actions where needed.
- `Sources/SadaaCore/Formatting/FormattingPromptBuilder.swift`: add structured Language Memory sections.
- `Sources/SadaaCore/History/DictationRecord.swift`: add raw/final diagnostics, model/deployment, memory hits, replacement hits, voice-edit metadata.
- `Sources/SadaaCore/History/DictationHistory.swift`: support richer search/filter/reprocess actions while preserving legacy decoding.
- `Sources/SadaaCore/Settings/AppSettings.swift`: model presets, health-check defaults, export folder bookmark/path, retention settings.

### SadaaApp files to create

- `Sources/SadaaApp/Components/PremiumControls.swift`: reusable search field, icon button, segmented tab, status badge.
- `Sources/SadaaApp/Components/MemoryRows.swift`: Language Memory row views.
- `Sources/SadaaApp/Components/ScratchpadRows.swift`: scratchpad list rows and note metadata badges.
- `Sources/SadaaApp/Pages/LanguageMemoryPage.swift`: terms/replacements/snippets/suggestions UI.
- `Sources/SadaaApp/Pages/ScratchpadPage.swift`: notes list/editor/pins/search/tags/export.
- `Sources/SadaaApp/Pages/DiagnosticsPage.swift` or settings subsection components if Settings needs splitting.
- `Sources/SadaaApp/ViewModels/LanguageMemoryViewModel.swift`: app-facing memory state.
- `Sources/SadaaApp/ViewModels/ScratchpadViewModel.swift`: app-facing scratchpad state.
- `Sources/SadaaApp/ViewModels/ProviderSettingsViewModel.swift`: presets and health checks.
- `Sources/SadaaApp/ViewModels/HistoryActionsViewModel.swift`: reprocess, learn correction, send-to-note.

### SadaaApp files to modify

- `Sources/SadaaApp/RootView.swift`: rename Dictionary to Language Memory and Notes to Scratchpad.
- `Sources/SadaaApp/SadaaViewModel.swift`: own new feature stores or compose feature view models.
- `Sources/SadaaApp/AppDelegate.swift`: create new stores, run migrations, wire memory into dictation/formatting, wire scratchpad.
- `Sources/SadaaApp/Pages/HomePage.swift`: premium readiness cockpit.
- `Sources/SadaaApp/Pages/HistoryPage.swift`: filters, reprocess, learn correction, send to Scratchpad.
- `Sources/SadaaApp/Pages/SettingsPage.swift`: provider presets, health checks, diagnostics, storage.
- `Sources/SadaaApp/HUD/HUDView.swift`: Voice Edit and staged processing labels.
- `README.md`: update recommended Azure models and local-first storage.

### Tests to create

- `Tests/SadaaCoreTests/LanguageMemoryModelsTests.swift`
- `Tests/SadaaCoreTests/LanguageMemoryMatcherTests.swift`
- `Tests/SadaaCoreTests/ReplacementEngineTests.swift`
- `Tests/SadaaCoreTests/MemoryBiasBuilderTests.swift`
- `Tests/SadaaCoreTests/MemorySuggestionEngineTests.swift`
- `Tests/SadaaCoreTests/LanguageMemoryStoreTests.swift`
- `Tests/SadaaCoreTests/LanguageMemoryMigratorTests.swift`
- `Tests/SadaaCoreTests/ScratchpadStoreTests.swift`
- `Tests/SadaaCoreTests/ScratchpadMigratorTests.swift`
- `Tests/SadaaCoreTests/ProviderHealthCheckTests.swift`
- `Tests/SadaaCoreTests/HistoryReprocessorTests.swift`

### Tests to modify

- `Tests/SadaaCoreTests/DictationControllerTests.swift`
- `Tests/SadaaCoreTests/FormattingPromptBuilderTests.swift`
- `Tests/SadaaCoreTests/DictationHistoryTests.swift`
- `Tests/SadaaCoreTests/AppSettingsTests.swift`

## Interfaces

Implement these public interfaces unless a phase review finds a smaller equivalent that still satisfies the spec.

```swift
public enum MemoryLanguage: String, Codable, CaseIterable, Sendable {
    case auto, en, de
}

public enum MemoryPriority: String, Codable, CaseIterable, Sendable {
    case normal, high, always
}

public enum ReplacementMatchMode: String, Codable, CaseIterable, Sendable {
    case exactPhrase, caseInsensitivePhrase, wordBoundaryPhrase
}

public enum MemorySuggestionKind: String, Codable, CaseIterable, Sendable {
    case term, replacement, snippetCandidate
}

public enum MemorySuggestionSource: String, Codable, CaseIterable, Sendable {
    case formatter, historyCorrection, manualImport, reprocess
}

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

```swift
public final class LanguageMemoryStore {
    public init(fileURL: URL)
    public func snapshot() -> LanguageMemorySnapshot
    public func terms() -> [MemoryTerm]
    public func replacements() -> [ReplacementRule]
    public func snippets() -> [MemorySnippet]
    public func suggestions() -> [MemorySuggestion]
    @discardableResult public func upsertTerm(_ term: MemoryTerm) -> MemoryTerm
    @discardableResult public func upsertReplacement(_ rule: ReplacementRule) -> ReplacementRule
    @discardableResult public func upsertSnippet(_ snippet: MemorySnippet) -> MemorySnippet
    public func removeTerm(id: UUID)
    public func removeReplacement(id: UUID)
    public func removeSnippet(id: UUID)
    public func acceptSuggestion(id: UUID, as kind: MemorySuggestionKind)
    public func dismissSuggestion(id: UUID)
    public func importSnapshot(_ snapshot: LanguageMemorySnapshot) -> LanguageMemoryImportResult
    public func exportSnapshot() -> LanguageMemorySnapshot
}
```

```swift
public enum ReplacementEngine {
    public static func apply(_ rules: [ReplacementRule],
                             to text: String,
                             language: MemoryLanguage) -> ReplacementResult
}

public struct ReplacementResult: Equatable, Sendable {
    public let text: String
    public let appliedRuleIDs: [UUID]
}

public enum MemoryBiasBuilder {
    public static func biasList(terms: [MemoryTerm],
                                baseVocabulary: [String],
                                budget: Int) -> [String]
}
```

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

public final class ScratchpadStore {
    public init(fileURL: URL)
    public func all() -> [ScratchpadNote]
    public func search(_ query: String) -> [ScratchpadNote]
    @discardableResult public func add(title: String, body: String, tags: [String], createdAt: Date) -> ScratchpadNote?
    public func update(_ note: ScratchpadNote)
    public func delete(id: UUID)
    public func duplicate(id: UUID, now: Date) -> ScratchpadNote?
    public func setPinned(id: UUID, isPinned: Bool)
    public func exportMarkdown(id: UUID) -> String?
}
```

## Task 1: Baseline, Safety Rails, And Phase Branching

**Files:**
- Modify: no source files.
- Read: `docs/superpowers/specs/2026-06-26-sadaa-premium-redesign-design.md`
- Verify: `Makefile`, current Git state, current test baseline.

**Interfaces:**
- Consumes: current repo state.
- Produces: verified baseline and a feature branch such as `codex/sadaa-premium-redesign`.

- [ ] **Step 1: Verify repo state**

Run:

```bash
git status --short --branch
```

Expected: `main` is ahead by the spec commit and only unrelated `NH_LP/` is untracked. Do not stage or modify `NH_LP/`.

- [ ] **Step 2: Create implementation branch**

Run:

```bash
git switch -c codex/sadaa-premium-redesign
```

Expected: branch switches successfully.

- [ ] **Step 3: Run baseline tests**

Run:

```bash
make test
```

Expected: all existing tests pass. The last known baseline was 188 passing tests.

- [ ] **Step 4: Commit safety note if branch metadata changes**

No commit is required if only the branch was created and tests ran.

## Task 2: Premium Shell And Home Cockpit

**Files:**
- Create: `Sources/SadaaApp/Components/PremiumControls.swift`
- Modify: `Sources/SadaaApp/RootView.swift`
- Modify: `Sources/SadaaApp/Pages/HomePage.swift`
- Modify: `Sources/SadaaApp/SadaaViewModel.swift`
- Test: existing tests only, plus live smoke after build.

**Interfaces:**
- Consumes: existing `SadaaViewModel`, `DictationHistory`, `CostMeter`, `Theme`.
- Produces: premium navigation labels and Home readiness cockpit without changing dictation pipeline behavior.

- [ ] **Step 1: Add shared controls**

Create `PremiumControls.swift` with these UI primitives:

```swift
import SwiftUI

struct PremiumStatusBadge: View {
    let icon: String?
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(tint.opacity(0.12)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.28), lineWidth: 1))
    }
}

struct PremiumIconButtonStyle: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.navy)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Theme.navy.opacity(hovering ? 0.10 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(Theme.navy.opacity(hovering ? 0.35 : 0.16), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .onHover { hovering = $0 }
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: hovering)
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: configuration.isPressed)
    }
}
```

- [ ] **Step 2: Rename navigation**

Modify `SidebarSection` in `RootView.swift`:

```swift
enum SidebarSection: String, CaseIterable, Identifiable {
    case home, languageMemory, scratchpad, history, settings
}
```

Map titles: `Home`, `Language Memory`, `Scratchpad`, `History`, `Settings`. Map icons: `house`, `text.book.closed`, `note.text`, `clock.arrow.circlepath`, `gearshape`.

- [ ] **Step 3: Keep compatibility page routing**

Until later tasks create new pages, route:

```swift
case .languageMemory:
    DictionaryPage(viewModel: viewModel)
case .scratchpad:
    NotesPage(viewModel: viewModel)
```

This preserves current behavior while the shell gets renamed.

- [ ] **Step 4: Upgrade HomePage layout**

Modify `HomePage` so the top section has:

```swift
private var readinessBadges: some View {
    HStack(spacing: 8) {
        PremiumStatusBadge(
            icon: viewModel.azureConfigured ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
            text: viewModel.azureConfigured ? "Azure ready" : "Azure setup needed",
            tint: viewModel.azureConfigured ? Theme.sage : Theme.gold
        )
        PremiumStatusBadge(
            icon: "globe",
            text: PageFormat.languageLabel(viewModel.languagePin),
            tint: Theme.navy
        )
        PremiumStatusBadge(
            icon: viewModel.hotkeyActive ? "keyboard.fill" : "keyboard",
            text: viewModel.hotkeyActive ? "Hotkeys active" : "Grant Accessibility",
            tint: viewModel.hotkeyActive ? Theme.sage : Theme.gold
        )
    }
}
```

Use this in the body above recent dictations. Keep `MicButton`, retry, today strip, and recent dictations working.

- [ ] **Step 5: Verify**

Run:

```bash
swift build
make test
```

Expected: build succeeds and all tests pass.

- [ ] **Step 6: Commit**

Run:

```bash
git add Sources/SadaaApp/Components/PremiumControls.swift Sources/SadaaApp/RootView.swift Sources/SadaaApp/Pages/HomePage.swift Sources/SadaaApp/SadaaViewModel.swift
git commit -m "feat: refine premium shell and home readiness cockpit"
```

## Task 3: Language Memory Backend

**Files:**
- Create: `Sources/SadaaCore/LanguageMemory/LanguageMemoryModels.swift`
- Create: `Sources/SadaaCore/LanguageMemory/LanguageMemoryMatcher.swift`
- Create: `Sources/SadaaCore/LanguageMemory/ReplacementEngine.swift`
- Create: `Sources/SadaaCore/LanguageMemory/MemoryBiasBuilder.swift`
- Create: `Sources/SadaaCore/LanguageMemory/MemorySuggestionEngine.swift`
- Create: `Sources/SadaaCore/LanguageMemory/LanguageMemoryStore.swift`
- Create: `Sources/SadaaCore/LanguageMemory/LanguageMemoryMigrator.swift`
- Test: `Tests/SadaaCoreTests/LanguageMemoryModelsTests.swift`
- Test: `Tests/SadaaCoreTests/LanguageMemoryMatcherTests.swift`
- Test: `Tests/SadaaCoreTests/ReplacementEngineTests.swift`
- Test: `Tests/SadaaCoreTests/MemoryBiasBuilderTests.swift`
- Test: `Tests/SadaaCoreTests/MemorySuggestionEngineTests.swift`
- Test: `Tests/SadaaCoreTests/LanguageMemoryStoreTests.swift`
- Test: `Tests/SadaaCoreTests/LanguageMemoryMigratorTests.swift`

**Interfaces:**
- Consumes: `DictionaryStore`, `DictionaryEntry`, `SnippetStore`, `Snippet`, `BaseVocabulary`, `TermMatcher`.
- Produces: Language Memory models/store, deterministic replacement, bias lists, suggestions, and migration.

- [ ] **Step 1: Write model tests first**

Create `LanguageMemoryModelsTests.swift`:

```swift
import Testing
import Foundation
@testable import SadaaCore

@Suite struct LanguageMemoryModelsTests {
    @Test func testMemoryTermCodableRoundTrip() throws {
        let term = MemoryTerm(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            phrase: "Karko AI",
            pronunciations: ["car co ai"],
            aliases: ["Karko"],
            language: .auto,
            priority: .high,
            notes: "Company name",
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 2),
            usageCount: 3
        )
        let data = try JSONEncoder().encode(term)
        let decoded = try JSONDecoder().decode(MemoryTerm.self, from: data)
        #expect(decoded == term)
    }
}
```

- [ ] **Step 2: Implement models**

Create `LanguageMemoryModels.swift` using the interfaces in this plan. Add `LanguageMemorySnapshot`, `LanguageMemoryImportResult`, and `LanguageMemoryPersisted`:

```swift
public struct LanguageMemorySnapshot: Codable, Equatable, Sendable {
    public var terms: [MemoryTerm]
    public var replacements: [ReplacementRule]
    public var snippets: [MemorySnippet]
    public var suggestions: [MemorySuggestion]
}

public struct LanguageMemoryImportResult: Equatable, Sendable {
    public let inserted: Int
    public let updated: Int
    public let duplicates: Int
    public let invalid: [String]
}

struct LanguageMemoryPersisted: Codable {
    var version: Int
    var snapshot: LanguageMemorySnapshot
}
```

- [ ] **Step 3: Write matcher tests**

Create tests for canonicalization, duplicate detection, and word boundaries:

```swift
@Suite struct LanguageMemoryMatcherTests {
    @Test func testCanonicalMatchesCaseHyphenAndPossessive() {
        #expect(LanguageMemoryMatcher.canonical("Claude-Code's") == "claude code")
    }

    @Test func testWordBoundaryDoesNotReplaceInsideWord() {
        #expect(LanguageMemoryMatcher.containsWordBoundaryPhrase("cloud code", in: "use cloud code today"))
        #expect(!LanguageMemoryMatcher.containsWordBoundaryPhrase("cloud", in: "cloudflare"))
    }
}
```

- [ ] **Step 4: Implement matcher**

Use `TermMatcher.canonical(_:)` as the base, then add word-boundary matching:

```swift
public enum LanguageMemoryMatcher {
    public static func canonical(_ text: String) -> String {
        TermMatcher.canonical(text)
    }

    public static func duplicates(_ a: String, _ b: String) -> Bool {
        TermMatcher.matches(a, b)
    }

    public static func containsWordBoundaryPhrase(_ phrase: String, in text: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: phrase)
        let pattern = "\\b\(escaped)\\b"
        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
```

- [ ] **Step 5: Write replacement tests**

Create tests for exact, case-insensitive, word-boundary, language filtering, disabled rules:

```swift
@Suite struct ReplacementEngineTests {
    @Test func testCaseInsensitiveReplacementApplies() {
        let id = UUID()
        let rule = ReplacementRule(id: id, match: "cloud code", replacement: "Claude Code",
                                   matchMode: .caseInsensitivePhrase, language: .auto,
                                   isEnabled: true, createdAt: Date(), updatedAt: Date(), usageCount: 0)
        let result = ReplacementEngine.apply([rule], to: "I use cloud code.", language: .en)
        #expect(result.text == "I use Claude Code.")
        #expect(result.appliedRuleIDs == [id])
    }

    @Test func testDisabledRuleDoesNotApply() {
        let rule = ReplacementRule(id: UUID(), match: "x", replacement: "y",
                                   matchMode: .exactPhrase, language: .auto,
                                   isEnabled: false, createdAt: Date(), updatedAt: Date(), usageCount: 0)
        #expect(ReplacementEngine.apply([rule], to: "x", language: .en).text == "x")
    }
}
```

- [ ] **Step 6: Implement replacement engine**

Implement exact and case-insensitive with `range(of:)`, word-boundary with regex, and language match when rule language is `.auto` or equals the current language. Return applied IDs in application order.

- [ ] **Step 7: Write bias builder tests**

Test ordering: `.always`, `.high`, recent usage, normal, then base vocabulary, no duplicates, cap.

```swift
@Suite struct MemoryBiasBuilderTests {
    @Test func testAlwaysAndHighTermsComeFirstAndCapApplies() {
        let now = Date()
        let normal = MemoryTerm(id: UUID(), phrase: "Normal", pronunciations: [], aliases: [], language: .auto, priority: .normal, notes: "", createdAt: now, updatedAt: now, usageCount: 0)
        let high = MemoryTerm(id: UUID(), phrase: "High", pronunciations: ["hie"], aliases: [], language: .auto, priority: .high, notes: "", createdAt: now, updatedAt: now, usageCount: 0)
        let always = MemoryTerm(id: UUID(), phrase: "Always", pronunciations: [], aliases: ["Always Alias"], language: .auto, priority: .always, notes: "", createdAt: now, updatedAt: now, usageCount: 0)
        let list = MemoryBiasBuilder.biasList(terms: [normal, high, always], baseVocabulary: ["Base"], budget: 4)
        #expect(list == ["Always", "Always Alias", "High", "hie"])
    }
}
```

- [ ] **Step 8: Implement bias builder**

Sort terms by `priorityRank`, then `usageCount`, then `updatedAt`. Include phrase, aliases, pronunciations. Deduplicate by `TermMatcher.canonical`. Append base vocabulary after personal terms. Cap at `budget`.

- [ ] **Step 9: Write store and migration tests**

Cover missing file, corrupt file `.bak`, upsert/delete persistence, import duplicate summary, migration from existing dictionary/snippet files.

- [ ] **Step 10: Implement store and migrator**

Follow existing store style: best-effort JSON read/write, corruption backup, atomic writes. Migrator reads old stores by constructing them from their existing file URLs, maps entries/snippets to memory models, writes new store, and leaves old files intact.

- [ ] **Step 11: Verify**

Run:

```bash
make test
```

Expected: all tests pass, including new Language Memory tests.

- [ ] **Step 12: Commit**

Run:

```bash
git add Sources/SadaaCore/LanguageMemory Tests/SadaaCoreTests/LanguageMemory*Tests.swift Tests/SadaaCoreTests/ReplacementEngineTests.swift Tests/SadaaCoreTests/MemoryBiasBuilderTests.swift Tests/SadaaCoreTests/MemorySuggestionEngineTests.swift
git commit -m "feat: add Language Memory backend"
```

## Task 4: Wire Language Memory Into Dictation And Formatting

**Files:**
- Modify: `Sources/SadaaCore/Formatting/FormattingContext.swift`
- Modify: `Sources/SadaaCore/Formatting/FormattingPromptBuilder.swift`
- Modify: `Sources/SadaaCore/DictationController.swift`
- Modify: `Sources/SadaaCore/History/DictationRecord.swift`
- Modify: `Sources/SadaaApp/AppDelegate.swift`
- Modify: `Sources/SadaaApp/SadaaViewModel.swift`
- Test: `Tests/SadaaCoreTests/FormattingPromptBuilderTests.swift`
- Test: `Tests/SadaaCoreTests/DictationControllerTests.swift`
- Test: `Tests/SadaaCoreTests/DictationHistoryTests.swift`

**Interfaces:**
- Consumes: `LanguageMemoryStore`, `MemoryBiasBuilder`, `ReplacementEngine`.
- Produces: memory-aware transcription hints, formatting prompt sections, local deterministic replacement, richer history diagnostics.

- [ ] **Step 1: Extend formatting context tests**

Add a test that the prompt includes terms, replacements, snippets:

```swift
@Test func testPromptIncludesLanguageMemorySections() {
    let prompt = FormattingPromptBuilder.systemPrompt(
        profile: FormattingProfiles.default,
        dictionaryWords: ["Karko AI"],
        speakerContext: "ctx",
        snippets: [Snippet(trigger: "my sig", expansion: "Wasim")],
        language: .auto,
        replacementRules: [
            ReplacementRule(id: UUID(), match: "cloud code", replacement: "Claude Code",
                            matchMode: .caseInsensitivePhrase, language: .auto,
                            isEnabled: true, createdAt: Date(), updatedAt: Date(), usageCount: 0)
        ]
    )
    #expect(prompt.contains("Karko AI"))
    #expect(prompt.contains("cloud code -> Claude Code"))
    #expect(prompt.contains("\"my sig\" -> Wasim"))
}
```

- [ ] **Step 2: Modify prompt builder signature**

Add `replacementRules: [ReplacementRule] = []` to `FormattingPromptBuilder.systemPrompt`. Existing callers continue compiling because of the default.

- [ ] **Step 3: Extend DictationRecord**

Add optional legacy-safe fields:

```swift
public let rawText: String?
public let intermediateText: String?
public let modelDeployment: String?
public let memoryHitIDs: [UUID]?
public let replacementRuleIDs: [UUID]?
```

Default them to `nil` in the initializer. Add tests that old JSON without these fields still decodes.

- [ ] **Step 4: Wire AppDelegate stores**

In `setUpController`, create:

```swift
let languageMemory = LanguageMemoryMigrator.migrateIfNeeded(
    memoryURL: sadaaDir.appendingPathComponent("language-memory.json"),
    dictionaryURL: sadaaDir.appendingPathComponent("dictionary.json"),
    snippetsURL: sadaaDir.appendingPathComponent("snippets.json")
)
```

If migration API returns a store directly, assign it to `self.languageMemory`.

- [ ] **Step 5: Replace hint source**

Change hint closure from `dictionary.biasList(budget: 50)` to:

```swift
let memory = languageMemory.snapshot()
let bias = MemoryBiasBuilder.biasList(
    terms: memory.terms,
    baseVocabulary: BaseVocabulary.terms,
    budget: 50
)
return TranscriptionHint(languagePin: settings.languagePin, dictionaryWords: bias)
```

- [ ] **Step 6: Apply replacements**

In `DictationController.process`, after raw transcript is saved and before formatting, apply pre-format replacements through an injected closure or formatter context. Keep the simplest design: AppDelegate's `format` closure receives raw text, applies `ReplacementEngine`, calls formatter, applies post-format replacements, and returns `FormattingResult`.

- [ ] **Step 7: Verify**

Run:

```bash
swift build
make test
```

Expected: all tests pass.

- [ ] **Step 8: Commit**

Run:

```bash
git add Sources/SadaaCore/Formatting Sources/SadaaCore/DictationController.swift Sources/SadaaCore/History Sources/SadaaApp/AppDelegate.swift Sources/SadaaApp/SadaaViewModel.swift Tests/SadaaCoreTests/FormattingPromptBuilderTests.swift Tests/SadaaCoreTests/DictationControllerTests.swift Tests/SadaaCoreTests/DictationHistoryTests.swift
git commit -m "feat: wire Language Memory into dictation and formatting"
```

## Task 5: Language Memory UI

**Files:**
- Create: `Sources/SadaaApp/ViewModels/LanguageMemoryViewModel.swift`
- Create: `Sources/SadaaApp/Components/MemoryRows.swift`
- Create: `Sources/SadaaApp/Pages/LanguageMemoryPage.swift`
- Modify: `Sources/SadaaApp/RootView.swift`
- Modify: `Sources/SadaaApp/SadaaViewModel.swift`
- Modify: `Sources/SadaaApp/AppDelegate.swift`
- Remove or retire from navigation: `Sources/SadaaApp/Pages/DictionaryPage.swift` only after `LanguageMemoryPage` fully replaces it.

**Interfaces:**
- Consumes: `LanguageMemoryStore`.
- Produces: tabs for Terms, Replacements, Snippets, Suggestions; add/edit/delete/search; accept/dismiss suggestions; import/export entry points.

- [ ] **Step 1: Create view model**

Create `LanguageMemoryViewModel`:

```swift
@MainActor
final class LanguageMemoryViewModel: ObservableObject {
    @Published var terms: [MemoryTerm] = []
    @Published var replacements: [ReplacementRule] = []
    @Published var snippets: [MemorySnippet] = []
    @Published var suggestions: [MemorySuggestion] = []
    @Published var query = ""

    private let store: LanguageMemoryStore

    init(store: LanguageMemoryStore) {
        self.store = store
        refresh()
    }

    func refresh() {
        terms = store.terms()
        replacements = store.replacements()
        snippets = store.snippets()
        suggestions = store.suggestions()
    }
}
```

- [ ] **Step 2: Build tab shell**

Create `LanguageMemoryPage` with a segmented picker for `.terms`, `.replacements`, `.snippets`, `.suggestions`, a search field, and the count summary.

- [ ] **Step 3: Implement rows and editors**

In `MemoryRows.swift`, add:

```swift
struct MemoryTermRow: View { let term: MemoryTerm; let onDelete: () -> Void }
struct ReplacementRuleRow: View { let rule: ReplacementRule; let onDelete: () -> Void }
struct MemorySnippetRow: View { let snippet: MemorySnippet; let onDelete: () -> Void }
struct MemorySuggestionRow: View { let suggestion: MemorySuggestion; let onAccept: () -> Void; let onDismiss: () -> Void }
```

Use `PremiumIconButtonStyle` for edit/delete/accept/dismiss icons.

- [ ] **Step 4: Wire navigation**

In `RootView`, route `.languageMemory` to:

```swift
LanguageMemoryPage(viewModel: viewModel.languageMemory)
```

If `SadaaViewModel` owns feature view models, add `let languageMemory: LanguageMemoryViewModel`.

- [ ] **Step 5: Verify**

Run:

```bash
swift build
make test
```

Manual check: app opens, Language Memory page loads, empty and populated states render, add/delete works on a test data file.

- [ ] **Step 6: Commit**

Run:

```bash
git add Sources/SadaaApp/ViewModels/LanguageMemoryViewModel.swift Sources/SadaaApp/Components/MemoryRows.swift Sources/SadaaApp/Pages/LanguageMemoryPage.swift Sources/SadaaApp/RootView.swift Sources/SadaaApp/SadaaViewModel.swift Sources/SadaaApp/AppDelegate.swift
git commit -m "feat: add Language Memory workspace UI"
```

## Task 6: Scratchpad Backend And UI

**Files:**
- Create: `Sources/SadaaCore/Scratchpad/ScratchpadModels.swift`
- Create: `Sources/SadaaCore/Scratchpad/ScratchpadStore.swift`
- Create: `Sources/SadaaCore/Scratchpad/ScratchpadMigrator.swift`
- Create: `Tests/SadaaCoreTests/ScratchpadStoreTests.swift`
- Create: `Tests/SadaaCoreTests/ScratchpadMigratorTests.swift`
- Create: `Sources/SadaaApp/ViewModels/ScratchpadViewModel.swift`
- Create: `Sources/SadaaApp/Components/ScratchpadRows.swift`
- Create: `Sources/SadaaApp/Pages/ScratchpadPage.swift`
- Modify: `Sources/SadaaApp/RootView.swift`
- Modify: `Sources/SadaaApp/AppDelegate.swift`
- Retire from navigation: `Sources/SadaaApp/Pages/NotesPage.swift` after `ScratchpadPage` replaces it.

**Interfaces:**
- Consumes: `NotesStore`, existing note data.
- Produces: versioned scratchpad store, migrated notes, pins/search/tags/export, auto-save editor.

- [ ] **Step 1: Write ScratchpadStore tests**

Create tests:

```swift
@Suite struct ScratchpadStoreTests {
    private func tempFile() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("scratchpad-\(UUID().uuidString).json")
    }

    @Test func testAddPersistsPinnedFirstThenRecent() {
        let url = tempFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = ScratchpadStore(fileURL: url)
        let first = store.add(title: "First", body: "one", tags: ["a"], createdAt: Date(timeIntervalSince1970: 1))!
        _ = store.add(title: "Second", body: "two", tags: [], createdAt: Date(timeIntervalSince1970: 2))!
        store.setPinned(id: first.id, isPinned: true)
        #expect(store.all().map(\.title) == ["First", "Second"])
    }
}
```

- [ ] **Step 2: Implement Scratchpad models and store**

Use the interface in this plan. Store newest first, with pinned notes sorted before unpinned notes. Persist with atomic JSON writes and corruption `.bak`, matching `NotesStore`.

- [ ] **Step 3: Write migrator tests**

Create a `NotesStore` file with two notes, migrate, assert body/title/createdAt are preserved.

- [ ] **Step 4: Implement migrator**

`ScratchpadMigrator.migrateIfNeeded(scratchpadURL:notesURL:) -> ScratchpadStore` reads existing `NotesStore`, creates `ScratchpadNote` records, writes scratchpad store, leaves old notes file intact, and backs up corrupt scratchpad JSON.

- [ ] **Step 5: Create Scratchpad UI**

Create a left list/right editor layout. Debounce auto-save with `DispatchWorkItem` in `ScratchpadViewModel`:

```swift
func updateDraftBody(_ body: String) {
    selected?.body = body
    scheduleSave()
}
```

Use direct store update after 350ms. Keep in-memory text if save fails and expose `@Published var saveError: String`.

- [ ] **Step 6: Wire dictation into focused note**

Keep current insertion behavior: focused `TextEditor` receives normal dictation at cursor. Add app-level action "Append latest dictation" in Scratchpad using `viewModel.recent.first`.

- [ ] **Step 7: Verify**

Run:

```bash
swift build
make test
```

Manual check: create note, edit body, wait for auto-save, relaunch app, note persists; pin/unpin; search; export markdown to a user-selected path outside Documents.

- [ ] **Step 8: Commit**

Run:

```bash
git add Sources/SadaaCore/Scratchpad Sources/SadaaApp/ViewModels/ScratchpadViewModel.swift Sources/SadaaApp/Components/ScratchpadRows.swift Sources/SadaaApp/Pages/ScratchpadPage.swift Sources/SadaaApp/RootView.swift Sources/SadaaApp/AppDelegate.swift Tests/SadaaCoreTests/ScratchpadStoreTests.swift Tests/SadaaCoreTests/ScratchpadMigratorTests.swift
git commit -m "feat: add Scratchpad notes workspace"
```

## Task 7: Provider Presets, Health Checks, Diagnostics, And README

**Files:**
- Create: `Sources/SadaaCore/ProviderHealth/ProviderHealthCheck.swift`
- Create: `Tests/SadaaCoreTests/ProviderHealthCheckTests.swift`
- Create: `Sources/SadaaApp/ViewModels/ProviderSettingsViewModel.swift`
- Modify: `Sources/SadaaCore/Settings/AppSettings.swift`
- Modify: `Sources/SadaaApp/Pages/SettingsPage.swift`
- Modify: `README.md`

**Interfaces:**
- Consumes: existing provider request builders, Keychain, AppSettings.
- Produces: Fast/Accurate/Speech-MAI/Legacy presets, safe health-check result, diagnostics panel, README model guidance.

- [ ] **Step 1: Add settings defaults and tests**

Add model preset enum:

```swift
public enum TranscriptionPreset: String, CaseIterable, Sendable {
    case fast, accurate, speechMAI, legacy
}
```

In `AppSettings`, add `transcriptionPreset`, `fastTranscriptionDeployment`, `accurateTranscriptionDeployment`, and `lastExportFolder`. Test defaults in `AppSettingsTests`.

- [ ] **Step 2: Add health-check result model**

Create:

```swift
public struct ProviderHealthResult: Equatable, Sendable {
    public let providerName: String
    public let ok: Bool
    public let latencyMilliseconds: Int?
    public let message: String
    public let redactedEndpoint: String
}
```

Tests assert redaction removes query strings and never includes API keys.

- [ ] **Step 3: Implement safe request check**

Use existing provider request builders with generated tiny WAV data from `WavWriter` or a static minimal audio fixture generated in memory. The health checker reports HTTP/provider errors with body excerpts but strips secrets.

- [ ] **Step 4: Update SettingsPage**

Split settings into sections:

- Hotkeys.
- Language.
- Provider preset.
- Azure OpenAI deployments.
- Azure Speech/MAI.
- Formatting.
- Diagnostics.
- Storage and backup.
- Permissions.

Add Test buttons for providers.

- [ ] **Step 5: Update README**

Document recommended Azure model choices:

- Fast: `gpt-4o-mini-transcribe`.
- Accurate: `gpt-4o-transcribe`.
- Azure Speech/MAI: `mai-transcribe-1.5` where available.
- Realtime Whisper is not part of v1.

Also document local storage and no Documents default.

- [ ] **Step 6: Verify and commit**

Run:

```bash
swift build
make test
```

Then:

```bash
git add Sources/SadaaCore/ProviderHealth Sources/SadaaCore/Settings/AppSettings.swift Sources/SadaaApp/ViewModels/ProviderSettingsViewModel.swift Sources/SadaaApp/Pages/SettingsPage.swift Tests/SadaaCoreTests/ProviderHealthCheckTests.swift Tests/SadaaCoreTests/AppSettingsTests.swift README.md
git commit -m "feat: add provider presets health checks and diagnostics"
```

## Task 8: History Reprocess, Learn Correction, And Voice Edit Polish

**Files:**
- Create: `Sources/SadaaCore/History/HistoryReprocessor.swift`
- Create: `Tests/SadaaCoreTests/HistoryReprocessorTests.swift`
- Create: `Sources/SadaaApp/ViewModels/HistoryActionsViewModel.swift`
- Modify: `Sources/SadaaApp/Pages/HistoryPage.swift`
- Modify: `Sources/SadaaCore/VoiceEdit/VoiceEditController.swift`
- Modify: `Sources/SadaaApp/HUD/HUDView.swift`
- Modify: `Sources/SadaaApp/AppDelegate.swift`
- Test: `Tests/SadaaCoreTests/VoiceEditTests.swift`

**Interfaces:**
- Consumes: `DictationHistory`, `LanguageMemoryStore`, `ScratchpadStore`, providers, formatter.
- Produces: row actions for send to Scratchpad, reprocess, learn correction; clearer Voice Edit states and history.

- [ ] **Step 1: Write reprocessor tests**

Create tests that a failed reprocess returns an error and leaves the original record unchanged.

```swift
@Suite struct HistoryReprocessorTests {
    @Test func testFailureDoesNotMutateOriginalRecord() async {
        let record = DictationRecord(text: "old", createdAt: Date(), language: nil, provider: "test", durationSeconds: 1)
        let result = await HistoryReprocessor.reprocess(record: record) {
            throw ProviderError.badResponse
        }
        #expect(result.original == record)
        #expect(result.reprocessed == nil)
    }
}
```

- [ ] **Step 2: Implement HistoryReprocessor**

Define:

```swift
public struct HistoryReprocessResult: Equatable, Sendable {
    public let original: DictationRecord
    public let reprocessed: DictationRecord?
    public let errorMessage: String?
}
```

Implement async function taking closures for transcription/formatting so tests stay pure.

- [ ] **Step 3: Add History actions UI**

Each row gets icon buttons:

- Copy.
- Send to Scratchpad.
- Reprocess.
- Learn correction.
- Delete.

Learn correction sheet saves either `MemoryTerm` or `ReplacementRule`.

- [ ] **Step 4: Polish Voice Edit HUD**

Add display cases:

```swift
case voiceEditRecording(seconds: Int, level: Float)
case voiceEditRewriting
case replacing
```

Map Voice Edit states in `AppDelegate.renderVoiceEdit` to these display cases. Copy text: "Editing selection", "Rewriting", "Replacing".

- [ ] **Step 5: Verify and commit**

Run:

```bash
swift build
make test
```

Then:

```bash
git add Sources/SadaaCore/History/HistoryReprocessor.swift Sources/SadaaApp/ViewModels/HistoryActionsViewModel.swift Sources/SadaaApp/Pages/HistoryPage.swift Sources/SadaaCore/VoiceEdit/VoiceEditController.swift Sources/SadaaApp/HUD/HUDView.swift Sources/SadaaApp/AppDelegate.swift Tests/SadaaCoreTests/HistoryReprocessorTests.swift Tests/SadaaCoreTests/VoiceEditTests.swift
git commit -m "feat: add history reprocess correction learning and voice edit polish"
```

## Task 9: Verification, Adversarial Review, Deploy, Push, Walkthrough

**Files:**
- Create: `docs/release/sadaa-premium-redesign-smoke-2026-06-26.md`
- Create: `docs/release/sadaa-premium-redesign-adversarial-review-2026-06-26.md`
- Create: `docs/release/sadaa-premium-redesign-walkthrough.html`
- Modify: source files only for bugs found during review.

**Interfaces:**
- Consumes: completed app.
- Produces: verified local launch, GitHub push to `main`, interactive HTML walkthrough.

- [ ] **Step 1: Full automated verification**

Run:

```bash
make test
swift build -c release
make bundle
```

Expected: tests pass, release build succeeds, `dist/Sadaa.app` exists.

- [ ] **Step 2: No-Documents audit**

Run:

```bash
rg -n "Documents|documentDirectory|urls\\(for: \\.documentDirectory" Sources Tests docs README.md
```

Expected: only spec/plan/docs mention the no-Documents rule. Source code must not read, scan, index, or default-save to Documents.

- [ ] **Step 3: Secret leakage audit**

Run:

```bash
rg -n "apiKey|azure-openai-key|openai-key|azure-speech-key|Keychain.get|diagnostic|export" Sources/SadaaApp Sources/SadaaCore
```

Review every diagnostic/export path. Expected: keys are read only from Keychain for provider calls and are never written to diagnostics, logs, JSON exports, or walkthrough files.

- [ ] **Step 4: Manual smoke checklist**

Create `docs/release/sadaa-premium-redesign-smoke-2026-06-26.md` with checked results for:

- App opens.
- Home readiness states render.
- Dictate into a normal editor.
- Dictate into Scratchpad.
- Add Language Memory term.
- Add replacement and preview it.
- Add snippet.
- Accept and dismiss suggestions.
- Reprocess a history row.
- Learn correction from history.
- Send history item to Scratchpad.
- Provider health check with valid and invalid settings.
- Bundle launches.

- [ ] **Step 5: Adversarial review**

Create `docs/release/sadaa-premium-redesign-adversarial-review-2026-06-26.md` covering:

- Migration failure paths.
- Text insertion paths.
- Replacement accidental partial-match risk.
- Import/export malformed data.
- Provider diagnostics secret leakage.
- UI clipping and overlap at narrow widths.
- No-Documents constraint.

Fix found bugs with focused commits.

- [ ] **Step 6: Install and launch**

Run:

```bash
make install
```

Expected: `/Applications/Sadaa.app` is replaced and launched.

- [ ] **Step 7: Create walkthrough**

Create `docs/release/sadaa-premium-redesign-walkthrough.html` as a self-contained interactive local HTML file. It must include:

- What changed.
- Home workflow.
- Language Memory workflow.
- Scratchpad workflow.
- History reprocess and learn correction.
- Provider/model recommendations.
- Verification performed.

Use static HTML/CSS/JS only. Do not reference Documents.

- [ ] **Step 8: Final tests and push main**

Run:

```bash
make test
git status --short --branch
git push origin main
```

Expected: tests pass, only intentional files are modified/committed, push succeeds.

## Self-Review

### Spec Coverage

- Product intent and personal local-first: Global Constraints, Task 9 no-Documents and secret audits.
- Premium UI and Home: Task 2.
- Language Memory backend and pipeline: Tasks 3 and 4.
- Language Memory UI: Task 5.
- Scratchpad: Task 6.
- Provider/model UX: Task 7.
- History reprocess and learn correction: Task 8.
- Voice Edit polish: Task 8.
- Verification, adversarial review, deploy, push, walkthrough: Task 9.
- V2/public release deferral: Global Constraints and no implementation tasks for auth/cloud/team/public features.

### Placeholder Scan

This plan intentionally has no deferred implementation slots inside v1. V2 items are explicit out-of-scope constraints from the spec.

### Type Consistency

The types named in the tasks match the interfaces section:

- `MemoryTerm`, `ReplacementRule`, `MemorySnippet`, `MemorySuggestion`.
- `LanguageMemoryStore`, `LanguageMemorySnapshot`, `LanguageMemoryImportResult`.
- `ReplacementEngine`, `ReplacementResult`, `MemoryBiasBuilder`.
- `ScratchpadNote`, `ScratchpadStore`.
- `ProviderHealthResult`.
- `HistoryReprocessResult`, `HistoryReprocessor`.

### Execution Recommendation

Use **Subagent-Driven** execution for implementation. Dispatch a fresh agent per task or phase, then review after each commit. This goal is broad enough that inline execution is possible but slower and riskier.
