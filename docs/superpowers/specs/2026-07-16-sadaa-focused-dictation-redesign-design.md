# Sadaa Focused Dictation Redesign

**Date:** 2026-07-16
**Status:** Approved by the implementation brief

## Product direction

Sadaa is a beginner-friendly macOS dictation utility. Its primary job is to turn speech into clean text at the cursor with as little product knowledge as possible. It is an internal productivity tool, so clarity and speed take priority over dashboards, decorative metrics and AI terminology.

This redesign removes the visible concept of multiple working modes. The product has one primary action: dictate. Smart cleanup is a setting, not a mode. Raw output remains an automatic fallback when cleanup is unavailable, not a user-facing workflow. Voice Edit and its separate hotkey are removed from the active app path.

## Research findings

The implementation was informed by current open-source dictation apps:

- OpenWhispr keeps personal words and snippets close to quick-add controls and supports provider routing, including custom and self-hosted transcription endpoints.
- VoiceInk separates vocabulary from deterministic word replacements, gives each a direct add form and applies replacements after transcription.
- Whispering exposes providers as connections rather than making the whole settings experience provider-specific.

The common useful pattern is a small number of understandable concepts: one dictation action, a searchable transcript list, a personal vocabulary, deterministic corrections and provider connections hidden behind progressive disclosure.

## Information architecture

The fixed sidebar order is:

1. Dictate
2. Library
3. Dictionary
4. Notes
5. Settings

The current Home page becomes Dictate. History becomes Library. Memory becomes Dictionary. Scratchpad becomes Notes. These labels describe the user object or action without requiring product-specific vocabulary.

## Visual system

Sadaa uses a light-first system with white as the dominant canvas.

- `surface`: `#FFFFFF`
- `surface-subtle`: `#F8F6F0`
- `brand`: `#102A43`
- `brand-strong`: `#071B2D`
- `accent`: `#C49A46`
- `ink`: `#132238`
- `ink-muted`: `#667085`
- `border`: `#E5E7EB`
- `danger`: `#B42318`
- `success`: `#2F6B4F`, semantic use only

Cream is limited to quiet secondary surfaces. Sage and unrelated decorative colors are removed. Gold is the single interactive accent. Hairline borders are the primary separation mechanism. Shadows are used only for elevated overlays and the recording control.

Typography uses the macOS system family because this is a native utility and must feel integrated with the platform. Display text uses system rounded only for the Sadaa wordmark and the large recording state. Body, controls and data use the standard system face. This deliberate split gives the app one recognizable signature without introducing a web-style type system.

The signature interaction is the Dictate stage: a restrained navy recording control with a thin gold state ring and a live text status. The rest of the interface stays quiet.

## Dictate

The page has one primary recording stage. The top area shows only connection readiness, active language and the selected hotkey. Dashboard metric cards are removed.

Below the recording stage, show the latest transcript with Copy and Send to notes actions. A short recent list shows the last three transcripts and links to Library. Provider model names, costs and memory counts are not shown on this page.

States are explicit: ready, listening, transcribing, inserting, retry available, no provider and permission needed.

## Library

Library uses a stable split view: a compact searchable transcript list on the left and a readable detail pane on the right. Rows show time, a two-line text preview, duration and language. Actions appear in the detail toolbar, not as a row of icon buttons on every transcript.

The detail pane shows final text first. Raw text, provider diagnostics, cost and memory evidence move into a collapsed Details section. Learn correction is the prominent secondary action because it improves future dictation. Delete uses undo where feasible and a confirmation only for clearing all history.

Empty search and empty library states include the next useful action.

## Dictionary

Dictionary has two top-level views only:

- Words and names: exact spellings, proper nouns, acronyms and product terms.
- Auto-corrections: deterministic heard-to-written replacements.

Each view has a direct add row above a simple table/list. Advanced term fields such as pronunciations, aliases, priority, notes and language live in an optional disclosure when adding or editing. Match mode is hidden under Advanced and defaults to word-boundary phrase.

Learning suggestions are not a separate mode. They appear as a review strip at the top when suggestions exist, with Accept and Dismiss actions. Existing snippets remain supported by the processing layer but creation and management move under an Advanced text shortcuts disclosure so they do not compete with dictionary basics.

Import and export move to a single overflow menu. Destructive clear actions are not primary toolbar controls.

## Notes

Notes uses a two-pane layout: searchable notes list and editor. The separate action rail is removed. Pin, duplicate, export and delete live in one toolbar menu. New note remains the only primary action.

Tags are optional metadata below the title. Word count and save state are quiet footer text, not multiple colored badges. Append latest dictation is available from the editor toolbar and from transcript actions.

## Settings and provider architecture

Settings is grouped into four sections: General, Speech provider, Writing and Data. The default view shows only controls needed by most users. Advanced fields use disclosures.

Speech provider offers two connection types:

- Azure OpenAI: endpoint, transcription deployment, API version and Keychain API key.
- OpenAI-compatible: base URL, model and optional Keychain bearer token. Requests use the standard `/v1/audio/transcriptions` shape and therefore support OpenAI-compatible hosted or self-hosted Whisper services.

The UI presents provider choice as a connection, not a mode. Test connection is adjacent to Save connection and returns a concise redacted result.

Text cleanup remains optional. Existing Azure cleanup continues to work when an Azure connection and GPT deployment are configured. For OpenAI-compatible transcription, cleanup can be off and deterministic dictionary corrections still run locally. The UI clearly explains this instead of implying cleanup is required.

API keys remain in Keychain. Endpoints, models and preferences remain in UserDefaults. Diagnostics must sanitize keys and bearer tokens.

## Active feature removal

- Remove Voice Edit from Settings, hotkey routing, HUD states and active app wiring.
- Stop using Shift on the dictation hotkey as a raw-mode modifier.
- Remove mode terminology from primary UI and transcript rows.
- Keep lenient history decoding for old records.
- Preserve old Voice Edit source files only if deleting them would create unrelated migration risk. They must have no active runtime references.

## Responsive and accessibility behavior

The minimum window remains usable around 820 by 560. At compact widths, Library and Notes switch from side-by-side panes to a single selected-detail flow. Dictionary forms stack above lists. Settings fields become single-column.

All controls have at least 40-point hit areas where practical, visible focus rings, accessible labels and keyboard order that follows reading order. Motion stays between 120 and 250 milliseconds, uses ease-out and respects Reduce Motion.

## Verification

- Add request-shape and error tests for the OpenAI-compatible transcription provider.
- Update AppSettings tests for provider selection and generic connection settings.
- Update hotkey tests and app wiring so only dictation and language switching remain active.
- Run `make test`, `swift build`, `make bundle` and code-sign verification.
- Capture and inspect Dictate, Library, Dictionary, Notes and Settings at 1440px-class and minimum-width layouts.
- Run the visual code sweep for gradients, blur decoration, banned color families, excessive animation and emoji UI icons.
