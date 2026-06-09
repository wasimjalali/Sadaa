import Foundation

/// The built-in model packs and the on-disk override mechanism. Each pack's
/// guidance is embedded markdown; a user can override any pack by editing
/// `<overridesDirectory>/<id>.md`. The optimizer reads `pack(for:)`.
public enum ModelPackLibrary {
    /// Returns the pack for `id`. When `overridesDirectory` is given and holds a
    /// non-empty `<id>.md`, that file's content replaces the built-in guidance;
    /// otherwise the built-in guidance is used.
    public static func pack(for id: ModelPackID,
                            overridesDirectory: URL? = nil) -> ModelPack {
        if let dir = overridesDirectory {
            let url = dir.appendingPathComponent("\(id.rawValue).md")
            if let content = try? String(contentsOf: url, encoding: .utf8),
               !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return ModelPack(id: id, guidance: content)
            }
        }
        return ModelPack(id: id, guidance: builtIn(id))
    }

    /// Creates `directory` if needed and writes each built-in pack to
    /// `<id>.md`, but only when that file does not already exist, so a user's
    /// edits are never overwritten.
    public static func seedOverrides(into directory: URL) throws {
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        for id in ModelPackID.allCases {
            let url = directory.appendingPathComponent("\(id.rawValue).md")
            if !FileManager.default.fileExists(atPath: url.path) {
                try builtIn(id).write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    private static func builtIn(_ id: ModelPackID) -> String {
        switch id {
        case .claude: return claudeGuidance
        case .gpt: return gptGuidance
        case .gemini: return geminiGuidance
        case .generic: return genericGuidance
        }
    }

    static let claudeGuidance = """
    When the target is a Claude model (Opus, Sonnet, Haiku, Fable and their successors, including Claude Code):

    - Lead with context, then the instruction. Claude reasons best when it knows the situation before it's told what to do. Open with the relevant background the speaker gave (the project, the file, the bug), then state the task.
    - Be explicit and direct. Spell out exactly what you want. Claude follows clear, declarative instructions well and does not need coaxing or roleplay framing.
    - When the prompt has multiple parts (a task plus code, plus an error, plus an example), wrap each part in XML-style tags to delimit it: <task>, <code>, <error>, <example>. This keeps Claude from confusing data with instructions.
    - State the goal AND the acceptance criteria. Make "done" concrete: "done means the test passes and tsc is clean", "done means the endpoint returns 200 with the new field". If the speaker implied a finish line, name it.
    - Phrase as positive instructions, not prohibitions. Prefer "edit only the auth module" over "don't touch other files". Tell Claude what to do, not just what to avoid.
    - For coding-agent prompts, surface the scope guards the speaker implied: which files or directories are in play, and what must NOT change (no refactors, keep the public API, don't rename things). Make these explicit even when the speaker only hinted at them.
    - Give the motivation. A short "why" ("because users are hitting a 500 on checkout") helps Claude make better judgment calls inside the task.
    - For multi-step work, use a numbered list of sequential steps so the agent executes in order.
    - Keep all technical identifiers, file paths, code, function names and product names exactly as spoken or corrected. Never alter them.
    - Never invent requirements the speaker did not state. If they didn't ask for tests, don't add "and write tests".
    - Keep output proportional. A one-sentence command becomes a one-to-three-sentence prompt, never an essay. Only structure heavily when the dictation was genuinely complex.
    - Preserve the speaker's actual intent. The template serves the intent, not the other way around.

    General (non-coding) Claude prompts: same shape, lighter. Context first, then a direct ask, then the desired output form (a list, a paragraph, a table). Tags only when there's source material to quote. Don't over-structure a simple request.
    """

    static let gptGuidance = """
    When the target is a GPT model (GPT-4.x, GPT-5.x, the o-series, Codex and their successors):

    - GPT-5 and Codex follow instructions very literally. Remove every ambiguity and contradiction. If the dictation says "make it fast but also log everything", resolve or rank the tension so the model isn't pulled two ways.
    - Put the single most important instruction first. GPT weights the opening of the prompt heavily, so the primary goal goes at the top, details below.
    - Structure with Markdown. Use short headers and bullet lists to separate the goal, the constraints and the inputs. GPT parses this structure cleanly.
    - Specify the output format explicitly: "return only the diff", "respond with a numbered list", "output valid JSON with keys x and y". Don't leave the shape to chance.
    - Avoid vague qualifiers ("good", "nice", "appropriate", "some"). Replace them with concrete criteria the model can check against.
    - For agentic prompts, add persistence cues so the agent doesn't stop early: "keep going until the task is fully resolved", "do not hand back until tests pass". State that it should not ask for confirmation on routine steps if the speaker wants it to run autonomously.
    - For agentic prompts, set tool-use expectations: which tools or commands it may run, when to read files before editing, when to verify with a build or test. Make the workflow explicit.
    - Keep all technical identifiers, file paths, code, function names and product names exactly as spoken or corrected. Never alter them.
    - Never invent requirements the speaker did not state. Literal models will execute the extras you add, so add nothing.
    - Keep output proportional. A one-sentence command becomes a one-to-three-sentence prompt, never an essay. Reserve heavy headers and bullets for genuinely multi-part dictation.
    - Preserve the speaker's actual intent over any template structure.

    General (non-coding) GPT prompts: same literalness rules. Most important instruction first, explicit output format, no vague qualifiers. Use headers only when the request has distinct parts. Keep a short ask short.
    """

    static let geminiGuidance = """
    When the target is a Gemini model (Gemini family and Gemini CLI, including their successors):

    - Open with a clear preamble that states the role and the task in one or two sentences: "You are working in a TypeScript repo. Task: add retry logic to the API client." Gemini responds well to a stated role plus an explicit objective up front.
    - Use structured input with headings. Separate sections like Task, Context, Constraints and Output with clear labels so the model can navigate them.
    - State constraints explicitly as their own section: language, framework, what to leave untouched, performance or style limits.
    - Gemini handles long context well, so dumping the relevant context (file contents, error logs, prior decisions) is fine and helps. Include what's useful rather than trimming aggressively.
    - Gemini works well with examples. When the speaker described a pattern or showed a sample, include it under an Example heading to anchor the output.
    - Be explicit about desired output length and format: "one paragraph", "a bullet list of at most five items", "only the changed function". Gemini benefits from a stated target.
    - For coding-agent prompts (Gemini CLI), name the files or directories in scope, the steps in order, and what must not change. Be explicit about whether it should run, verify, or only propose.
    - Keep all technical identifiers, file paths, code, function names and product names exactly as spoken or corrected. Never alter them.
    - Never invent requirements the speaker did not state.
    - Keep output proportional. A one-sentence command becomes a one-to-three-sentence prompt, never an essay. The heading structure is for multi-part dictation, not for simple asks.
    - Preserve the speaker's actual intent over the template.

    General (non-coding) Gemini prompts: role and task preamble, a Context section if there's material to ground on, explicit output format and length. Examples help. Keep a short request short.
    """

    static let genericGuidance = """
    When the target model is unknown or unlisted, apply distilled cross-model best practices:

    - State the goal first, in one clear sentence. What should the model produce or accomplish?
    - Give the necessary context next: the project, the file, the error, the prior decision. Just enough to ground the task, no more.
    - List the constraints explicitly: language, framework, scope, what to leave untouched, any limits on style or length.
    - Specify the output format: a diff, a numbered list, a single function, valid JSON, a short paragraph. Name the shape you want back.
    - Keep it to one task per prompt. If the dictation bundled several unrelated asks, keep the speaker's primary intent central and don't merge them into a tangle.
    - For coding-agent prompts, name the files or directories in scope, give sequential steps if there's an order, and state what must NOT change.
    - Use light structure (a few headers or bullets) only when the dictation is genuinely multi-part. A simple ask stays plain prose.
    - Keep all technical identifiers, file paths, code, function names and product names exactly as spoken or corrected. Never alter them.
    - Never invent requirements the speaker did not state.
    - Keep output proportional. A one-sentence command becomes a one-to-three-sentence prompt, never an essay.
    - Preserve the speaker's actual intent over any template structure.

    General (non-coding) prompts: goal, context, constraints, output format, one task. Apply the same proportionality, the same fidelity to identifiers, the same restraint on invention.
    """
}
