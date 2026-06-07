# Sadaa Main Window - Design Spec

**Date:** 2026-06-07
**Status:** Approved pending user review
**Builds on:** `2026-06-07-sadaa-design.md` (the MVP). This adds a real application window; it does not change the dictation pipeline.

## 1. Why

The MVP is menu-bar-only (a status item, a tiny settings form, a floating HUD). User feedback: "it's a small pop-up at the top, it doesn't have a proper UI." This spec adds a proper resizable app window with sidebar navigation and real pages, while keeping the fast menu-bar + hotkey workflow.

## 2. Decisions (with Wasim, 2026-06-07)

| Topic | Decision |
|---|---|
| App type | Hybrid: real window AND menu bar icon. Dock icon present only while the window is open. |
| Open on launch | Yes, the window opens on launch so the app is visible. |
| Navigation | Left sidebar (NavigationSplitView): Home, Dictionary, History, Settings. |
| Home | Large gold mic button reflecting live dictation state, status line, recent dictations. |
| History | Real and working: searchable list of past dictations, one-click copy. |
| Settings | Existing Azure config moved into a proper page + language selector + hotkey display. |
| Dictionary | Polished "coming next" placeholder this pass (real feature lands in Plan 2). |
| Branding | Karko palette (navy #1E3A5F, gold #D4A853, cream #FAF7F2, sage #5B8A72), Inter. |
| Pipeline | Unchanged. This is a UI + history-store pass only. |

## 3. App behavior: the hybrid window

The app currently runs with `NSApplication.activationPolicy = .accessory` (LSUIElement, no Dock, menu-bar only). New behavior:

- **Launch:** set policy `.regular`, create and show the main window, keep the status item. The user sees a real app.
- **Window closed (red button):** the window hides and the app returns to `.accessory` (Dock icon disappears, menu bar icon and global hotkey remain). The app does NOT quit. `windowShouldClose`/`windowWillClose` drives the transition; the window is not released.
- **Reopen:** menu bar gains an "Open Sadaa" item (and `applicationShouldHandleReopen` returns true) that sets `.regular` and re-shows the window.
- **Quit** stays explicit (menu "Quit Sadaa" / Cmd-Q).

`LSUIElement` stays `true` in Info.plist (so it starts without bouncing the Dock); the policy is flipped at runtime. This is the standard menu-bar-app-with-window pattern.

## 4. Architecture

New files (SadaaApp), one clear responsibility each:

| File | Responsibility |
|---|---|
| `MainWindowController.swift` | Owns the single `NSWindow` hosting the SwiftUI root; create/show/hide; drives the `.regular`/`.accessory` policy transitions on show/close. |
| `RootView.swift` | `NavigationSplitView` shell: sidebar (4 items) + detail; injects the view-model and settings. |
| `Pages/HomePage.swift` | Big mic button + status + recent dictations. |
| `Pages/HistoryPage.swift` | Searchable history list, copy action. |
| `Pages/DictionaryPage.swift` | Placeholder "coming next" empty state. |
| `Pages/SettingsPage.swift` | Azure config form + language picker + hotkey display (supersedes the standalone SettingsView). |
| `SadaaViewModel.swift` | `@MainActor ObservableObject` bridging DictationController state + recent history into SwiftUI. |
| `Components/MicButton.swift` | The stateful gold mic control. |
| `Components/SidebarItem.swift` | Sidebar row styling (Karko). |
| `Theme.swift` | Karko colors + shared SwiftUI styling constants (one source of truth, reused by HUD too). |

New file (SadaaCore, testable):

| File | Responsibility |
|---|---|
| `History/DictationHistory.swift` | A Codable JSON-backed store of dictation records. Append, load, recent(limit:), search(query:). Lives in `~/Library/Application Support/Sadaa/history.json`. |

### DictationRecord

```swift
public struct DictationRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let text: String
    public let createdAt: Date
    public let language: String?     // detected language, if any
    public let provider: String      // provider name that served it
    public let durationSeconds: Double?
}
```

### DictationHistory (store)

```swift
public final class DictationHistory {
    public init(fileURL: URL)
    public func append(_ record: DictationRecord)          // persists immediately
    public func all() -> [DictationRecord]                 // newest first
    public func recent(_ limit: Int) -> [DictationRecord]  // newest first, capped
    public func search(_ query: String) -> [DictationRecord] // case-insensitive substring on text
}
```

Persistence: load the JSON array on init (empty if missing/corrupt - corruption is logged, not fatal, and a corrupt file is backed up to `history.json.bak` before starting fresh, so a dictation is never lost silently). `append` writes the full array atomically. Records are stored newest-first in memory; `all()`/`recent()` return that order.

### Wiring into the pipeline

`DictationController` already calls `deliver(text)` on success. We add one optional hook so the controller records history without taking a UI dependency:

- `DictationController` gains an optional `onDelivered: ((DictationRecord) -> Void)?` (or the existing `deliver` closure is widened to receive the `Transcript` + provider name). Chosen approach: add a separate `record: (DictationRecord) -> Void` closure to the initializer, called right after `saveTranscript` and before/with `deliver`, carrying text + detectedLanguage + provider name + duration. This keeps `deliver` (text insertion) and `record` (history) as distinct, single-purpose seams.
- AppDelegate passes a `record` closure that appends to `DictationHistory` and notifies `SadaaViewModel` to refresh.

This is a minimal, additive change to the controller's init; existing tests pass a no-op `record` or the new param is defaulted.

### SadaaViewModel

```swift
@MainActor
final class SadaaViewModel: ObservableObject {
    @Published var dictationState: DictationState   // mirrors controller
    @Published var recent: [DictationRecord]
    @Published var azureConfigured: Bool
    @Published var languagePin: LanguagePin
    // toggle() -> calls the controller; refresh(from:) -> updates published state
}
```

AppDelegate owns the controller and the view-model; `controller.onStateChange` updates `viewModel.dictationState`; the `record` closure refreshes `viewModel.recent`. The mic button reads `dictationState`; tapping calls `viewModel.toggle()` which calls `controller.toggle()`.

## 5. Pages

### Home
- Centered `MicButton` (gold), large. States map from `DictationState`:
  - `.idle` / `.error`: solid gold mic, caption "Tap or press Right Option".
  - `.recording`: pulsing gold ring + elapsed timer + "Esc to cancel".
  - `.transcribing`: spinner + "Transcribing".
  - `.delivering`: spinner + "Inserting".
- Status line under the mic: a dot + "Azure connected" (green/sage) when configured, else "Not configured. Open Settings." (gold warning); plus the current language pin (Auto/EN/DE).
- "Recent" section: up to 5 most recent records (text, relative time). Empty state: "Your dictations will appear here."

### History
- Search field (filters by `search(query:)`).
- List of records: text (2-line truncate), relative time, language tag, provider tag; hover/select reveals a Copy button (copies full text to clipboard). Empty state mirrors Home.

### Settings
- Section "Azure OpenAI": endpoint, deployment, API version, API key (SecureField, Keychain). Same fields and save behavior as the current SettingsView, restyled as a page.
- Section "Language": segmented Auto / English / German, writes `settings.languagePin` (and reflects in the menu bar checkmarks).
- Section "Hotkey": read-only display "Toggle dictation: Right Option. Cancel: Esc." (rebinding is later work.)
- A "Save" affordance with a transient "Saved" confirmation (as today). No em dashes in any copy.

### Dictionary (placeholder)
- Karko-styled empty state: icon, "Custom dictionary", one paragraph ("Teach Sadaa your names and jargon. Arriving in the next update."), disabled-looking preview. No fake controls that do nothing.

## 6. Theme

`Theme.swift` centralizes the Karko palette and is reused by the HUD (which currently hardcodes the same hex values - point it at Theme so there is one source of truth). Colors: navy `#1E3A5F`, navy-800 `#12243B`, gold `#D4A853`, gold-300 `#E0C687`, cream `#FAF7F2`, cream-100 surfaces, sage `#5B8A72` (success), charcoal `#2D3748` (text on light). Font: Inter with system fallback. Sidebar uses navy; content uses cream surfaces; selection and the mic use gold.

## 7. Error handling

- History file missing -> start empty. Corrupt JSON -> back up to `history.json.bak`, start empty, log once. Never crash, never lose an in-progress dictation (the audio + sidecar from the pipeline are unaffected).
- `append` write failure -> logged; the dictation was still delivered and the on-disk sidecar still exists (never-lose-a-dictation holds via the existing RecordingStore path).
- Window/policy transitions are idempotent (showing an already-shown window just focuses it; closing when already accessory is a no-op).

## 8. Testing

- **Unit (XCTest/Swift Testing):** `DictationHistory` - append+load round-trip, newest-first ordering, `recent(limit:)` cap, `search` case-insensitive substring, corrupt-file recovery (writes a bad file, expects empty + `.bak` created). `SadaaViewModel` - state mapping from a fed `DictationState`, `recent` refresh, `azureConfigured` derivation. `DictationRecord` Codable round-trip.
- **Live (manual checklist, in Task wiring):** window opens on launch; closing hides window and removes Dock icon but keeps menu bar; "Open Sadaa" reopens; mic button tracks a real dictation through all states; a completed dictation appears in History and Home Recent; search filters; copy works; Settings save persists and language reflects in the menu bar; Dictionary shows the placeholder.

## 9. Scope boundaries

- IN: the window, sidebar, Home, History (real), Settings (page), Dictionary (placeholder), `DictationHistory` store, view-model, theme extraction, the `record` hook in the controller.
- OUT (later plans): dictionary management + bias wiring + auto-suggest (Plan 2); cost meter, provider-fallback UI, OpenAI/MAI providers, SwiftData migration of history if desired (Plan 3); snippets, voice-edit, notes, onboarding, launch-at-login, hotkey rebinding (Plan 4).

## 10. Build sequence (high level)

1. `Theme.swift` (extract palette; point HUD at it).
2. `DictationHistory` + `DictationRecord` + tests (SadaaCore).
3. `record` hook in DictationController + test the no-op/default path stays green.
4. `SadaaViewModel` + tests.
5. `MicButton`, `SidebarItem` components.
6. Pages: Home, History, Settings, Dictionary placeholder.
7. `RootView` shell + `MainWindowController` + activation-policy hybrid.
8. AppDelegate wiring: own the window/view-model/history, open on launch, "Open Sadaa" menu item, reopen handling; bundle + install + live smoke checklist.

Detailed task breakdown lives in the implementation plan (next document).
