import Foundation

/// Assembles the formatter system prompt from a profile, the speaker context,
/// and the dictionary. Pure and testable. Spec section 4.
public enum FormattingPromptBuilder {
    public static func systemPrompt(profile: FormattingProfile,
                                    dictionaryWords: [String],
                                    speakerContext: String,
                                    snippets: [Snippet] = []) -> String {
        var lines: [String] = []
        lines.append("You clean up dictated speech into polished written text.")
        lines.append(speakerContext)
        lines.append(profile.promptFragment)
        lines.append("Always: remove filler words, fix punctuation and casing, apply mid-sentence self-corrections (\"at 2, actually 3\" becomes \"at 3\"), and reply in the same language as the input (German stays German).")
        lines.append("Lists: when the speaker enumerates items or asks for a list (cues like \"first / second / third\", \"next point\", \"bullet\", \"number one\", or several parallel items in a row), format them as a clean Markdown list, one item per line, using \"- \" for unordered items or \"1.\", \"2.\" when order matters. Put each item on its own line with a line break between them. Do NOT turn ordinary sentences or prose into a list, and do not invent items the speaker did not say.")
        if !dictionaryWords.isEmpty {
            lines.append("Enforce these exact spellings when they occur: \(dictionaryWords.joined(separator: ", ")).")
        }
        if !snippets.isEmpty {
            let pairs = snippets.map { "\"\($0.trigger)\" -> \($0.expansion)" }
                .joined(separator: "; ")
            lines.append("Expand these spoken shortcuts when you hear the trigger phrase: \(pairs).")
        }
        lines.append("Respond ONLY with a JSON object of the form {\"text\": \"<the formatted text>\", \"newTerms\": [\"<unusual proper noun or jargon you had to guess>\"]}. newTerms holds at most 3 entries and is [] when there is nothing unusual. Do not wrap the JSON in markdown.")
        return lines.joined(separator: "\n")
    }
}
