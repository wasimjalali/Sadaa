# Sadaa Premium Redesign Adversarial Review - 2026-06-26

## Findings

### Build And Launch

- **Risk:** No Swift/Git verification could run in this machine session because command-line developer tools are unavailable.
- **Mitigation:** Kept changes source-local, added targeted tests, ran text audits, and documented the blocker. The next required step is `make test && swift build` after toolchain repair.

### Migration Failure Paths

- **Risk:** Corrupt `language-memory.json` or `scratchpad.json` could wipe user-visible state.
- **Mitigation:** New stores move corrupt JSON aside with `.bak` and start empty, matching existing store behavior. Legacy dictionary pending-suggestion counts are preserved as Language Memory suggestion evidence during migration.
- **Residual risk:** Actual migrated user files were not launch-tested due toolchain blocker.

### Replacement Accidental Partial Matches

- **Risk:** A replacement like `cloud` could alter `cloudflare`.
- **Mitigation:** Default replacements use `wordBoundaryPhrase`; the composer includes a live preview; the engine includes a word-boundary mode and tests for inside-word avoidance.
- **Residual risk:** User can intentionally choose exact or case-insensitive phrase modes; UI labels should be refined after launch testing if confusion appears.

### Import And Export Malformed Data

- **Risk:** Bad imported memory data could create blank terms or snippets.
- **Mitigation:** `LanguageMemoryStore.importSnapshot` rejects blank phrases, blank replacement outputs, and blank snippet expansions.
- **Residual risk:** Import/export is exposed as JSON/CSV copy-paste, not file picker flows; this avoids accidental default-save locations but still needs launch testing.

### Provider Diagnostics Secret Leakage

- **Risk:** Health check or diagnostics could print API keys.
- **Mitigation:** The Settings test uses the real Azure transcription provider with generated probe audio, carries a redacted endpoint only, strips query/path, and sanitizes common key/header patterns from provider failures.
- **Residual risk:** The network probe itself could not be launch-tested in this machine session because Swift build tooling is unavailable.

### Text Insertion Paths

- **Risk:** Dictation/voice edit insertion could regress while stores changed.
- **Mitigation:** Existing delivery closures and `TextInserter` are unchanged. Voice Edit only gets clearer HUD display states. Successful dictations now record a retained audio path for future history reprocessing when retention has not pruned it.
- **Residual risk:** Cannot verify live insertion until app builds and launches.

### Language Memory Observability

- **Risk:** A premium dictionary can feel untrustworthy if the user cannot tell whether terms were actually matched.
- **Mitigation:** Language Memory now records matched term IDs and expanded snippet IDs through dictation formatting and history reprocessing, increments term/replacement/snippet usage counts, displays used-count badges in memory rows, and History displays memory/snippet-hit counts on rows.
- **Residual risk:** The hit labels are source-verified but not visually launch-tested due the toolchain blocker.

### Snippet Reliability

- **Risk:** Prompt-only snippets could fail when GPT was unavailable or when the model ignored the shortcut.
- **Mitigation:** Snippets now expand deterministically before/after formatting, during raw-mode dictation, during formatter fallback, and during text-only history reprocessing, using the same boundary-safe matching as Language Memory replacements.
- **Residual risk:** Live dictation expansion still needs app launch verification after Swift tooling is restored.

### Raw Mode Personalization

- **Risk:** The Shift-to-stop raw path could accidentally bypass the user's local dictionary/replacement work while skipping GPT.
- **Mitigation:** Dictation now separates local Language Memory post-processing from GPT formatting. Raw mode and formatter fallback can still apply deterministic replacements/snippets and record memory-hit diagnostics without calling GPT.
- **Residual risk:** The split has targeted tests and source review, but the hotkey gesture still needs launch verification after Swift tooling is restored.

### Rule Experimentation

- **Risk:** Delete-only management makes users afraid to test aggressive replacements or snippets.
- **Mitigation:** Replacement and snippet rows now expose pause/resume controls and persist the enabled state, so experiments can be disabled without losing them.
- **Residual risk:** Toggle visuals need launch review after Swift tooling is restored.

### Language-Specific Biasing

- **Risk:** German-only or English-only terms could pollute the wrong transcription context and reduce recognition quality.
- **Mitigation:** The Language Memory UI now captures language and priority, rows display both, and the bias builder filters language-specific terms when dictation is pinned.
- **Residual risk:** Picker layout and badge density still need visual launch testing.

### UI Clipping And Overlap

- **Risk:** New History row actions may crowd narrow windows.
- **Mitigation:** Actions reveal on hover; Scratchpad uses a fixed list/editor split; Language Memory uses constrained content width.
- **Residual risk:** Needs visual review on the real app after Swift build tooling is restored.

### Scratchpad Portability

- **Risk:** A local notes workspace can feel risky if there is no obvious backup/export path.
- **Mitigation:** Scratchpad can now copy the whole workspace as Markdown or JSON and restore JSON backups without opening file pickers or defaulting into sensitive folders.
- **Residual risk:** The menu export/import flow is source-verified but not launch-tested.

### Scratchpad Scanability

- **Risk:** A notes surface becomes hard to trust when note size and recency are hidden.
- **Mitigation:** Scratchpad rows and the editor now show lightweight word/character metadata without changing the persisted note schema.
- **Residual risk:** The stat badges still need visual launch review after Swift tooling is restored.

### No-Documents Constraint

- **Result:** Source and tests do not reference Documents or `.documentDirectory`. Mentions are limited to docs/README statements of the rule.

### Scope Honesty

- **Implemented:** Premium shell labels, Home badges, Language Memory backend/UI/JSON+CSV import/export, language-targeted priority/usage biasing, pause/resume controls, live-preview deterministic replacements, deterministic snippet expansion in formatted/raw/fallback paths, memory/snippet-hit history diagnostics, Scratchpad backend/UI/workspace export/import/stats, History send/reprocess-from-audio/learn actions, provider presets, redacted Azure health probe, Voice Edit HUD polish, README, release docs, walkthrough.
- **Not fully implemented:** App bundle launch, install, commit, push. These are blocked honestly rather than faked.
