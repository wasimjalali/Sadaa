# Sadaa Premium Redesign Smoke Check - 2026-06-26

## Verification Run (2026-06-26, Claude takeover)

The developer-tools blocker that stopped Codex did not exist in this session.
Command Line Tools are installed at `/Library/Developer/CommandLineTools`,
`swift` (6.3.1) runs, and Git resolves to `/opt/homebrew/bin/git`. All
previously-blocked commands were executed and pass.

## Automated Verification

- [x] No source code touches the user's Documents folder. Evidence: `grep -rniE "documentDirectory|/Documents|NSDocumentDirectory" Sources Tests` returns 0 hits.
- [x] Conflict-marker scan: 0 hits across `Sources` and `Tests`.
- [x] `swift --version` -> Apple Swift 6.3.1 (swiftlang-6.3.1.1.2).
- [x] `make test` -> 237 tests in 39 suites passed (13.98s).
- [x] `swift build` -> Build complete (debug).
- [x] `make bundle` -> Build complete (release), `dist/Sadaa.app` produced.
- [x] `codesign --verify --deep --strict dist/Sadaa.app` -> valid, satisfies its Designated Requirement, signed with "Sadaa Local Signing" (identifier `ai.karko.sadaa`).
- [x] Local launch: `open dist/Sadaa.app` -> process started and stayed alive, no crash report in `~/Library/Logs/DiagnosticReports`.
- [x] Interactive HTML walkthrough opens locally and is well-formed (DOCTYPE/html/head/body present, closes `</html>`, no conflict markers).

## Bugs Found And Fixed During This Run

- `AppDelegate.swift`: three multi-statement closures (`hint:`, `context:`, second `hint:`) were missing an explicit `return`, so `TranscriptionHint`/`FormattingContext` never returned. Added `return`. (Was a compile error.)
- `ScratchpadPage.swift:74`: `.frame(width:maxHeight:alignment:)` is not a valid SwiftUI overload. Changed to `.frame(minWidth:290, maxWidth:290, maxHeight:.infinity, alignment:.topLeading)` to keep the intended fixed-width sidebar that fills height. (Was a compile error.)
- `LanguageMemoryMatcherTests.swift`: missing `import Foundation` for `UUID`. Added it. (Was a compile error.)
- `LanguageMemoryMigratorTests.swift`: the test seeded its pending suggestion with "Codex", but "Codex" is a `BaseVocabulary` term, so `DictionaryStore.suggest()` correctly refuses to ever queue it. The test could not create the precondition it was migrating. Swapped the example term to "Helsinki" (not in BaseVocabulary). The migrator and stores were correct; only the test fixture was invalid. (Was a failing assertion.)

## Manual Smoke Checklist (requires Wasim: microphone, Azure keys, Accessibility grant, visual inspection)

These exercise the live GUI, the microphone, and your configured Azure
credentials. They cannot be honestly ticked by an automated CLI session, so
they are left for your hands-on pass. Where the underlying logic has passing
unit-test coverage, that is noted so you know the deterministic core is
already proven and only the on-screen interaction remains.

- [ ] App opens and the menu-bar item appears. (Bundle launches cleanly - confirmed; visual menu-bar check pending.)
- [ ] Home readiness states render correctly.
- [ ] Dictate into a normal editor and confirm insertion.
- [ ] Dictate into Scratchpad (normal focused text insertion).
- [ ] Scratchpad note row/editor word and character stats. (Logic unit-tested: `ScratchpadStoreTests`.)
- [ ] Copy Scratchpad workspace as Markdown or JSON backup. (Logic unit-tested: `ScratchpadStoreTests`.)
- [ ] Import Scratchpad JSON backup. (Logic unit-tested: `ScratchpadStoreTests`, `ScratchpadMigratorTests`.)
- [ ] Add Language Memory term. (Logic unit-tested: `LanguageMemoryStoreTests`.)
- [ ] Set Language Memory priority and language targeting. (Logic unit-tested: `MemoryBiasBuilderTests`.)
- [ ] Add replacement and preview via composer/reprocess/history. (Logic unit-tested: `ReplacementEngineTests`.)
- [ ] Add snippet and confirm deterministic expansion during dictation/reprocess. (Logic unit-tested: `SnippetExpansionEngineTests`, `LanguageMemoryPostProcessorTests`.)
- [ ] Stop with raw mode and confirm local replacements/snippets still apply without GPT. (Logic unit-tested: `LanguageMemoryPostProcessorTests`, `DictationControllerTests`.)
- [ ] Pause and resume replacements/snippets without deleting them. (Logic unit-tested: `LanguageMemoryStoreTests`.)
- [ ] Copy and import Language Memory JSON and CSV. (Logic unit-tested: `LanguageMemoryCSVTests`.)
- [ ] Accept and dismiss suggestions. (Logic unit-tested: `MemorySuggestionEngineTests`.)
- [ ] History memory-hit counts for matched Language Memory terms. (Logic unit-tested: `HistoryReprocessorTests`.)
- [ ] Language Memory usage counts increase after term/replacement/snippet hits and appear on rows. (Logic unit-tested: `LanguageMemoryStoreTests`.)
- [ ] Reprocess a history row from retained audio, with text-only fallback. (Logic unit-tested: `HistoryReprocessorTests`.)
- [ ] Learn correction from history.
- [ ] Send history item to Scratchpad.
- [ ] Provider configuration check with valid and invalid settings. (Redaction logic unit-tested: `ProviderHealthCheckTests`; live network probe needs your Azure key.)

## Notes

- An older `/Applications/Sadaa.app` was already running during this session (your prior install). It was left untouched. To run the new build in its place, use `make install` (pkills Sadaa, copies the new bundle to `/Applications`, relaunches).
