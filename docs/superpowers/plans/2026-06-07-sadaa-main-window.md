# Sadaa Main Window Implementation Plan

> Execute subagent-driven (Opus implementers). Spec: `docs/superpowers/specs/2026-06-07-sadaa-main-window-design.md`.

**Goal:** Give Sadaa a real application window (sidebar: Home, Dictionary, History, Settings) while keeping the menu bar + hotkey. Dock icon present only while the window is open.

**Tech:** Swift/SwiftUI + AppKit, SPM. Tests via `make test` (Swift Testing, never bare `swift test`). No em dashes in user-facing copy. Commit per task (conventional commits, Co-Authored-By trailer). The dictation pipeline is unchanged except one additive history hook.

**Conventions:** after each task `swift build` and `make test` must be green. SadaaApp is an executable target with no unit tests (UI/AppKit glue is verified live, like the existing HUD/TextInserter). Only SadaaCore gets unit tests.

---

### Task A: Theme (extract Karko palette, repoint HUD)

**Files:** Create `Sources/SadaaApp/Theme.swift`; modify `Sources/SadaaApp/HUD/HUDView.swift`.

- `enum Theme` (or `struct`) exposing SwiftUI `Color` statics: `navy` #1E3A5F, `navy800` #12243B, `gold` #D4A853, `gold300` #E0C687, `cream` #FAF7F2, `creamSurface` #FEFDFB, `sage` #5B8A72, `charcoal` #2D3748. Each `Color(red:green:blue:)` from hex/255. Add a helper `static func hex(_ r:_ g:_ b:) -> Color` if it reduces repetition.
- In HUDView, replace the three hardcoded `navy`/`gold`/`cream` static lets and the LevelBars gold with `Theme.navy`/`Theme.gold`/`Theme.cream`. Behavior identical.
- `swift build` clean, `make test` green (30 tests). Commit: `feat: add Karko Theme and route HUD colors through it`.

---

### Task B: DictationHistory store (SadaaCore, TDD)

**Files:** Create `Sources/SadaaCore/History/DictationRecord.swift`, `Sources/SadaaCore/History/DictationHistory.swift`, `Tests/SadaaCoreTests/DictationHistoryTests.swift`.

`DictationRecord`: `public struct DictationRecord: Codable, Equatable, Identifiable, Sendable` with `id: UUID`, `text: String`, `createdAt: Date`, `language: String?`, `provider: String`, `durationSeconds: Double?`; public memberwise init with `id: UUID = UUID()` default.

`DictationHistory`: `public final class DictationHistory` (not necessarily Sendable; used on main):
- `init(fileURL: URL)` - loads JSON array if present; on decode failure, move the bad file to `<file>.bak` (best-effort) and start empty; missing file starts empty. Never throws from init.
- `append(_ record: DictationRecord)` - inserts at front (newest-first), writes the whole array atomically to `fileURL` (Codable JSON, ISO8601 or default Date strategy - pick one and be consistent). Write failure is swallowed (best-effort; the dictation is already delivered).
- `all() -> [DictationRecord]` newest-first.
- `recent(_ limit: Int) -> [DictationRecord]` first `limit`.
- `search(_ query: String) -> [DictationRecord]` case-insensitive substring on `text`; empty/whitespace query returns `all()`.

**Tests (Swift Testing, translate the contract):**
- round-trip: append two records to a temp file, new `DictationHistory(fileURL:)` over the same file returns them newest-first.
- `recent(1)` returns only the newest.
- `search` case-insensitive substring; blank query returns all.
- corrupt recovery: write `"{ not json"` to the file, construct `DictationHistory`, expect `all().isEmpty` and a `<file>.bak` exists.
- `DictationRecord` Codable round-trip (encode then decode equals original).

Use temp dirs per test, clean up. Commit: `feat: add DictationHistory JSON store with recent/search/corruption recovery`.

---

### Task C: record hook in DictationController (SadaaCore)

**Files:** modify `Sources/SadaaCore/DictationController.swift`, `Tests/SadaaCoreTests/DictationControllerTests.swift`.

- Add an initializer param `record: @escaping (DictationRecord) -> Void = { _ in }` (defaulted so existing call sites/tests compile unchanged). Store it.
- In `stopAndProcess`, after `saveTranscript` and on success, build a `DictationRecord(text: transcript.text, createdAt: Date(), language: transcript.detectedLanguage, provider: <the provider name that succeeded>, durationSeconds: transcript.durationSeconds)` and call `record(...)` BEFORE `deliver(...)` (so history is recorded even if insertion has issues - never-lose). Capture the winning provider's `name` during the fallback loop.
- DictationController is `@MainActor`; `Date()` is fine on main.
- Update `DictationControllerTests`: the existing `testHappyPath` (or a new small test) passes a `record` closure capturing records and asserts one record with text "hello world" and provider name is recorded. Keep all other tests green (they rely on the default param).
- `make test` green (counts go up). Commit: `feat: record each delivered dictation to history via controller hook`.

---

### Task D: SadaaViewModel + MicButton + SidebarItem (SadaaApp, UI glue)

**Files:** Create `Sources/SadaaApp/SadaaViewModel.swift`, `Sources/SadaaApp/Components/MicButton.swift`, `Sources/SadaaApp/Components/SidebarItem.swift`.

`SadaaViewModel`: `@MainActor final class SadaaViewModel: ObservableObject`:
- `@Published var dictationState: DictationState = .idle`
- `@Published var recent: [DictationRecord] = []`
- `@Published var azureConfigured: Bool`
- `@Published var languagePin: LanguagePin`
- holds references (or closures) to call the controller's `toggle()` and to read settings; `init(toggle: @escaping () -> Void, settings: AppSettings, history: DictationHistory)`.
- `func refreshState(_ s: DictationState)`, `func refreshRecent()` (reads `history.recent(5)`), `func refreshConfig()` (azureConfigured = endpoint+deployment+keychain key all present; languagePin from settings), `func toggle()`.

`MicButton`: SwiftUI view taking `state: DictationState` and an `onTap`. Gold circle (Theme.gold), large. Idle: mic glyph + caption. Recording: pulsing ring + red accent + caption "Esc to cancel". Transcribing/delivering: ProgressView + caption. Uses SF Symbols ("mic.fill", etc.). Tap calls `onTap`.

`SidebarItem`: a small styled label (icon + title) for the sidebar rows in Karko colors.

`swift build` clean (no unit tests for these; live-verified). Commit: `feat: add SadaaViewModel state bridge and MicButton/SidebarItem components`.

---

### Task E: Pages + RootView shell (SadaaApp, UI)

**Files:** Create `Sources/SadaaApp/RootView.swift`, `Sources/SadaaApp/Pages/HomePage.swift`, `Pages/HistoryPage.swift`, `Pages/SettingsPage.swift`, `Pages/DictionaryPage.swift`.

- `RootView`: `NavigationSplitView` with a sidebar listing Home/Dictionary/History/Settings (enum-driven selection, SidebarItem styling, navy sidebar, gold selection) and a detail area switching on selection. Takes `@ObservedObject viewModel` and the `AppSettings`.
- `HomePage`: centered `MicButton(state: viewModel.dictationState, onTap: viewModel.toggle)`, status line (sage dot + "Azure connected" or gold + "Not configured. Open Settings." from `viewModel.azureConfigured`; plus language pin), and a "Recent" list from `viewModel.recent` (text + relative time via `RelativeDateTimeFormatter`). Empty state copy: "Your dictations will appear here."
- `HistoryPage`: a `@State searchText`; search field; list from `history.search(searchText)`; each row shows text (lineLimit 2), relative time, language + provider tags, and a Copy button (`NSPasteboard.general.setString`). Reads the same `DictationHistory` (pass it in or via the view-model). Empty state.
- `SettingsPage`: port the existing `SettingsView` Form into a page (Azure section identical fields + Keychain save), add a Language `Picker`/segmented control bound to `settings.languagePin` (write-through), and a read-only Hotkey section ("Toggle dictation: Right Option. Cancel: Esc."). Transient "Saved" confirmation. No em dashes.
- `DictionaryPage`: Karko empty state - SF Symbol, "Custom dictionary" title, one paragraph "Teach Sadaa your names and jargon. Arriving in the next update.", no functional controls.
- Keep the existing standalone `SettingsView.swift`/`SettingsWindowController.swift` for now OR remove if fully superseded - if removed, drop the menu's "Settings..." separate-window action and instead open the main window on the Settings page. Decide in Task F wiring; in this task just build the pages. Leave SettingsView.swift in place (Task F decides).
- `swift build` clean. Commit: `feat: add RootView shell and Home/History/Settings/Dictionary pages`.

---

### Task F: MainWindowController + hybrid activation + AppDelegate wiring + deploy

**Files:** Create `Sources/SadaaApp/MainWindowController.swift`; modify `Sources/SadaaApp/AppDelegate.swift`; possibly remove `SettingsWindowController.swift`/`SettingsView.swift` if superseded.

`MainWindowController`: `@MainActor final class` owning one `NSWindow` (titled, closable, miniaturizable, resizable; min size ~820x560; title "Sadaa") hosting `NSHostingView(rootView: RootView(...))`. `show()` creates-if-needed, sets `NSApp.setActivationPolicy(.regular)`, centers + `makeKeyAndOrderFront`, activates. A window delegate: on `windowWillClose`, set `NSApp.setActivationPolicy(.accessory)` (back to menu-bar-only) and do NOT release the window (`isReleasedWhenClosed = false`) so it can reopen. `show()` is idempotent.

AppDelegate changes:
- Own `mainWindow = MainWindowController()`, `history = DictationHistory(fileURL: appSupport/history.json)`, `viewModel = SadaaViewModel(...)`.
- In `setUpController`, pass a `record:` closure that `history.append(record)` then `viewModel.refreshRecent()`. `onStateChange` also calls `viewModel.refreshState(state)` (in addition to the existing `render`). 
- In `applicationDidFinishLaunching`, after wiring, call `mainWindow.show(viewModel:settings:history:)` so the window opens on launch. Keep `requestPermissions`, status item, hotkeys.
- Add menu item "Open Sadaa" (cmd-0 or none) that calls `mainWindow.show(...)`. Implement `applicationShouldHandleReopen(_:hasVisibleWindows:)` to show the window and return true.
- Keep the menu's language submenu and Quit. The "Settings..." menu item now opens the main window on Settings (or keep the small window - simplest: change "Settings..." to open the main window). Remove `SettingsWindowController`/`SettingsView` only if nothing references them after this; otherwise leave them.
- Because the window hosts SwiftUI that mutates `settings.languagePin`, keep the menu bar language checkmarks in sync best-effort (acceptable if they only refresh on menu open; do not over-engineer).

Then:
- `swift build -c release` clean, zero warnings (wrap any main-actor Timer/closure exactly like existing code if the compiler asks). `make test` green.
- `make bundle` then `make install` (installs to /Applications and relaunches).
- Live smoke checklist (report results): window opens on launch; sidebar switches pages; mic button tracks a real dictation idle->recording->transcribing->inserting->idle; the dictation shows up in History and Home Recent; History search filters; Copy works; Settings save persists, language change reflects; closing the window removes the Dock icon but keeps the menu bar icon and hotkey; "Open Sadaa" / clicking the Dock-less reopen path brings it back; Quit works.
- Commit: `feat: add main window with hybrid menu-bar/Dock activation and wire into app`.

---

## Self-review notes
- Spec coverage: Theme(A), history store(B), controller hook(C), view-model+components(D), pages+shell(E), window+hybrid+wiring+deploy(F). All spec sections mapped.
- The `record` param is defaulted so MVP tests stay green (Task C).
- SadaaApp types are not unit-tested (target structure); testable logic (history) is in SadaaCore. Consistent with MVP.
