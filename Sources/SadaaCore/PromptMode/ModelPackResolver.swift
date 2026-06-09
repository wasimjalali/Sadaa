import Foundation

/// Detects the target model family the speaker named in their dictation, so
/// Prompt Mode can route to the right pack. Pure and offline. Only the first 6
/// words and the last 8 words are scanned, so a model name mentioned in the
/// middle of a long dictation is treated as content, not as a routing
/// instruction. First match wins; the trailing window is checked first because
/// "...this is for GPT" at the end is the most common form.
public enum ModelPackResolver {
    private static let gptPhrases =
        ["for gpt", "for chatgpt", "for codex", "for openai", "für gpt"]
    private static let claudePhrases =
        ["for claude", "for claude code", "for opus", "for sonnet", "for haiku",
         "for fable", "for anthropic", "für claude"]
    private static let geminiPhrases =
        ["for gemini", "for google", "für gemini"]

    public static func resolve(transcript: String,
                               defaultTarget: ModelPackID) -> ModelPackID {
        let words = transcript.lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        guard !words.isEmpty else { return defaultTarget }

        let leading = words.prefix(6).joined(separator: " ")
        let trailing = words.suffix(8).joined(separator: " ")

        // Trailing window first: trailing meta-mentions are most common.
        for window in [trailing, leading] {
            if let match = match(in: window) { return match }
        }
        return defaultTarget
    }

    /// Returns the first family whose phrase appears as whole words in `window`,
    /// or nil. GPT, Claude and Gemini phrase sets are checked in that order.
    private static func match(in window: String) -> ModelPackID? {
        if gptPhrases.contains(where: { contains(window, phrase: $0) }) { return .gpt }
        if claudePhrases.contains(where: { contains(window, phrase: $0) }) { return .claude }
        if geminiPhrases.contains(where: { contains(window, phrase: $0) }) { return .gemini }
        return nil
    }

    /// Whole-word, case-insensitive containment. The window is already
    /// lowercased and space-joined, so padding with spaces gives word
    /// boundaries without a regex.
    private static func contains(_ window: String, phrase: String) -> Bool {
        (" " + window + " ").contains(" " + phrase + " ")
    }

    /// The target family implied by the app being dictated into: inside the
    /// Claude desktop app the prompt is for Claude, inside ChatGPT it is for
    /// GPT. A spoken mention still wins; this only replaces the settings
    /// default. Returns nil for apps that imply no particular family.
    public static func appImpliedTarget(bundleID: String?) -> ModelPackID? {
        switch bundleID {
        case "com.anthropic.claudefordesktop": return .claude
        case "com.openai.chat": return .gpt
        default: return nil
        }
    }
}
