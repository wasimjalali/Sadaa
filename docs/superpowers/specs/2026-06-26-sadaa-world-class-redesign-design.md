# Sadaa World-Class Redesign - Design Spec

**Date:** 2026-06-26
**Status:** Fresh directive spec for implementation
**Platform:** macOS 14+, Apple Silicon, native Swift/SwiftUI
**Owner/User:** Wasim Jalali

## 1. Decision

The earlier premium redesign is not the target. It can be reused only where
the code helps the new direction. The product target is a complete redesign:
Sadaa should feel like a high-end, local-first AI dictation command center for
an AI specialist, not a settings-heavy utility.

The visual system must use navy, cream, white, and restrained gold:

- Navy is the primary brand and navigation color.
- Cream is the warm workspace background.
- White is used for crisp work surfaces and focused editors.
- Gold is an accent for focus, learning, progress, and premium detail.
- Avoid one-note gradients, decorative blobs, oversized marketing layouts, and
  nested cards.

## 2. Product Position

Sadaa is a private voice layer for daily AI work: prompts, code discussions,
client messages, research notes, product thinking, and technical vocabulary.
It should compete with the best 2026 dictation applications by combining:

- fast system-wide dictation,
- strong personal vocabulary,
- deterministic corrections,
- snippets,
- scratchpad capture,
- history recovery and reprocessing,
- command editing of selected text,
- local-first storage and no authentication.

Sadaa should not become a public SaaS app in this version. Do not add auth,
cloud sync, teams, billing, analytics, or onboarding marketing screens.

## 3. Competitive Patterns

Market patterns checked on 2026-06-26:

- Wispr Flow: command editing, snippets, scratchpad, dictionary.
- Superwhisper: vocabulary, text replacements, modes, history reprocessing.
- MacWhisper: local/private transcription and clear export-oriented utility.
- Aqua Voice: fast any-app dictation with AI cleanup.

Sadaa adapts these patterns for a personal local app:

- Language Memory is first-class, explainable, and correction-driven.
- Scratchpad is a daily capture workspace, not a basic notes list.
- History is a recovery and teaching surface, not a dump of old text.
- Settings is flat, calm, and limited to the useful local workflow.

## 4. Global Information Architecture

The main window has five sections:

1. Home
2. Memory
3. Scratchpad
4. History
5. Settings

The app remains menu-bar first. The floating HUD and hotkeys remain the primary
daily workflow; the main window is the command center for readiness, learning,
notes, recovery, and configuration.

## 5. Visual System

### 5.1 Shell

Use a fixed navy sidebar with compact navigation. The selected item should feel
precise and premium: white or cream label, gold focus line or indicator, and no
large decorative pill competing with the content.

The main content should sit on a cream background. Work surfaces inside the
page should be white or near-white with crisp borders and subtle depth. Use
cards for repeated rows and editors only; page sections should be full-width
layouts, not cards inside cards.

### 5.2 Type And Density

Use system San Francisco. Avoid hero-scale text inside utility pages. Use:

- 24-28 pt for page titles,
- 15-17 pt for section titles,
- 12-14 pt for controls and metadata,
- compact badges for metrics.

No negative letter spacing. Text must not overflow buttons, tabs, sidebars, or
rows on the supported macOS window sizes.

### 5.3 Interaction Details

Use SF Symbols for actions. Icon buttons need hover feedback and help text.
Use segmented controls for tab-like modes, toggles for binary states, menus for
secondary actions, and bordered inputs for forms.

Motion should be subtle and purposeful: state changes, saved confirmations,
learning events, recording feedback. Respect Reduce Motion where the platform
provides it.

## 6. Home

Home is the command cockpit. It should answer, at a glance:

- Is Sadaa ready to dictate?
- Which language and Azure model are active?
- Is the hotkey active?
- Did Memory improve recent dictations?
- What can I do next?

Required layout:

- Top command strip with app status, language, hotkey, Azure readiness.
- Large premium mic control with clear listening/transcribing/delivering/error
  states, but not a marketing hero.
- "Today" metrics: dictations, minutes, words, memory hits.
- Recent dictations with action buttons: copy, send to Scratchpad, learn
  correction, reprocess.
- A Learning Pulse panel showing pending Memory suggestions and the last
  applied corrections.

Home should never expose MAI, legacy, provider fallback, or model plumbing.

## 7. Memory

Memory replaces the dictionary concept. It is Sadaa's intelligence layer.

### 7.1 Structure

Memory has four modes:

1. Terms
2. Corrections
3. Snippets
4. Learning Queue

The page uses a split workbench:

- Left rail: search, mode switcher, summary metrics, import/export.
- Center list: filtered rows with confidence, usage, language, last used.
- Right inspector/composer: edit the selected item or create a new item.

This should feel like a premium data tool, not a long form stacked vertically.

### 7.2 Terms

Terms store names, acronyms, product names, frameworks, API names, company
names, and multi-word technical phrases.

Term fields:

- phrase,
- pronunciation/sounds-like list,
- aliases,
- language: any, English, German,
- priority: normal, high, always,
- notes,
- usage count,
- last used.

Default AI-specialist vocabulary must include or bias toward terms such as
Claude, Claude Code, Codex, OpenAI, Anthropic, ChatGPT, GPT-4o, GPT-5,
Supabase, Vercel, Cloudflare, Cursor, Workers, Durable Objects, embeddings,
vector database, RAG, evals, agents, prompt engineering, fine-tuning, MCP,
tool calling, structured outputs, and relevant capitalization patterns.

### 7.3 Corrections

Corrections are deterministic "never make this mistake again" rules. They are
stronger than terms.

Examples:

- "cloud code" -> "Claude Code"
- "codecs" -> "Codex"
- "super base" -> "Supabase"
- "rag" -> "RAG"

Corrections support:

- heard phrase,
- correct phrase,
- match mode,
- language,
- enabled state,
- live preview,
- usage count,
- last used.

Corrections run locally even when GPT formatting is off or unavailable.

### 7.4 Snippets

Snippets are voice shortcuts for repeated output. They support:

- spoken trigger,
- expansion,
- tags,
- language,
- enabled state,
- preview,
- usage count.

Snippets run locally and are visible beside terms and corrections as part of
the same Memory system.

### 7.5 Learning Queue

The Learning Queue is where Sadaa becomes smart.

Inputs:

- formatter-discovered new terms,
- repeated raw transcript anomalies,
- history "Learn correction" actions,
- reprocess differences,
- manual correction pairs,
- accepted snippets or terms.

Behavior:

- repeated observations increase evidence count,
- accepted corrections immediately become deterministic rules,
- accepted same-text terms become high-priority terms,
- dismissed suggestions do not keep coming back,
- rows explain why they exist with recent evidence snippets.

The user should feel: "If I correct it once, Sadaa remembers."

## 8. Scratchpad

Scratchpad is a premium local note workspace for dictated thinking.

Required layout:

- Left list with pinned notes first, search, tags, and new note.
- Center editor with white writing surface, title, tags, body, autosave status,
  word count, character count, created/updated metadata.
- Right utility rail or top utility strip for actions: append latest dictation,
  copy Markdown, duplicate, pin, export, delete.

Required functions:

- create, edit, autosave, delete,
- pin/unpin,
- duplicate,
- search title/body/tags,
- tags,
- append latest dictation,
- send history item to note,
- copy selected note as Markdown,
- copy all notes as Markdown,
- JSON backup/restore.

The page should feel closer to a polished writing desk than a table of notes.

## 9. History

History becomes a transcript timeline and recovery surface.

Required layout:

- Top filters/search: text, date grouping, language, memory hits, raw/formatted.
- Day-grouped timeline with compact premium rows.
- Optional detail inspector for selected record.

Each row exposes:

- final text,
- raw text availability indicator,
- provider/model,
- language,
- timestamp,
- duration,
- memory hits,
- correction hits,
- snippet hits,
- copy,
- send to Scratchpad,
- learn correction,
- reprocess,
- delete.

"Learn correction" must be prominent and fast: observed text and corrected text
are prefilled, and saving creates either a correction or a term depending on
whether the values differ.

History should make Memory better; it is not just an archive.

## 10. Settings

Settings must be flat in one place, calm, and useful. Remove MAI, legacy model
options, OpenAI fallback UI, and fallback-provider language from the primary
app.

Keep:

- Azure endpoint,
- Azure transcription deployment,
- Azure API version,
- Azure API key,
- Azure test button,
- GPT formatting toggle,
- GPT deployment,
- speaker context,
- language pin,
- hotkeys,
- sound effects,
- launch at login,
- microphone/accessibility permissions,
- storage/retention,
- cost estimate rates if already useful,
- diagnostics that do not expose secrets.

Remove from UI and active provider construction:

- MAI/Speech settings,
- legacy model preset,
- OpenAI fallback toggle/model/key,
- fallback-provider ordering.

The runtime provider chain should be simple: configured Azure transcription is
the transcription provider. Formatting uses configured Azure GPT when enabled.
If Azure transcription fails, keep audio for retry and show a clear error.

## 11. HUD

The HUD should feel like a premium instrument:

- navy capsule,
- cream text,
- gold waveform/focus detail,
- clear states: listening, transcribing, formatting, inserting, done, copied,
  error, language switched,
- timer and Esc hint while recording,
- retry prompt when audio is retained after failure.

No provider fallback messaging remains because fallback providers are removed.

## 12. Data Flow

Live dictation:

1. User records audio through hotkey/HUD.
2. Azure transcription returns raw text.
3. Local Memory pre-processing applies deterministic corrections/snippets.
4. GPT formatting optionally cleans punctuation, casing, lists, and new-term
   extraction.
5. Local Memory post-processing applies deterministic corrections/snippets
   again.
6. Final text is inserted and copied as backup.
7. History stores raw/final text, model/provider, language, duration, memory
   hits, correction hits, snippet hits, and cost estimate.
8. Memory usage counts increment.
9. New terms and repeated anomalies enter Learning Queue.

Correction learning:

1. User clicks Learn correction from History or Home.
2. Observed and corrected text are prefilled.
3. If values differ, save as a deterministic correction.
4. If values match but casing/spelling is important, save as a high-priority
   term.
5. Reprocess can immediately test the new Memory rule.

## 13. Error Handling

- No Azure config: clear Settings action.
- Azure failure: keep audio, show retry, do not silently use a fallback.
- GPT formatting failure: insert locally post-processed raw transcript and show
  "Inserted raw text; formatting unavailable."
- Insertion failure: leave text on clipboard and show paste instruction.
- Corrupt local stores: back up corrupt files and continue with empty stores.
- Import errors: show inserted/updated/invalid counts, never crash.

## 14. Verification Requirements

Automated:

- `make test`
- `swift build`
- `make bundle`
- no source references to `Documents` or `.documentDirectory`
- no MAI/Speech/legacy/fallback UI strings in active app pages
- tests for Azure-only provider construction or equivalent behavior
- tests for correction learning and deterministic Memory application
- tests for Scratchpad and History actions that feed Memory

Visual/runtime:

- launch bundled app,
- inspect Home, Memory, Scratchpad, History, Settings, and HUD,
- verify navy/cream/white/gold palette is consistently used,
- verify Settings is flat and free of MAI/legacy/fallback clutter,
- verify text does not overflow common window sizes,
- perform a local smoke pass for app launch, notes, memory edits, history
  actions, and settings save/test where credentials are available.

Release:

- commit changes on feature branch,
- create PR,
- merge to `main` after review,
- install/launch the app locally,
- leave an evidence document with commands, screenshots or notes, and remaining
  manual checks if credentials/permissions prevent a full live dictation test.
