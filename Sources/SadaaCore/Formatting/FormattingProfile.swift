import Foundation

/// A named system-prompt fragment plus the app bundle ids it applies to. Spec
/// section 4 "Formatting profiles".
public struct FormattingProfile: Equatable, Sendable {
    public let name: String
    public let bundleIDs: [String]
    public let promptFragment: String

    public init(name: String, bundleIDs: [String], promptFragment: String) {
        self.name = name
        self.bundleIDs = bundleIDs
        self.promptFragment = promptFragment
    }
}

public enum FormattingProfiles {
    public static let code = FormattingProfile(
        name: "Prompt/code",
        bundleIDs: [
            "com.todesktop.230313mzl4w4u92", // Cursor
            "com.microsoft.VSCode",
            "com.apple.Terminal",
            "dev.warp.Warp-Stable",
            "com.googlecode.iterm2",
            "com.wasimjalali.bunyan",        // Bunyan (personal terminal)
        ],
        promptFragment: "The target app is a code editor or terminal. Keep technical terms, identifiers, camelCase and snake_case exactly. No greetings, no filler, no sign-offs. Plain imperative sentences.")

    public static let chat = FormattingProfile(
        name: "Chat",
        bundleIDs: [
            "com.tinyspeck.slackmacgap",   // Slack
            "com.hnc.Discord",
            "net.whatsapp.WhatsApp",
            "ru.keepcoder.Telegram",
        ],
        promptFragment: "The target app is a casual chat. Keep it conversational and short, use contractions, drop heavy punctuation.")

    public static let mail = FormattingProfile(
        name: "Mail/docs",
        bundleIDs: [
            "com.apple.mail",
            "com.apple.iWork.Pages",
            "com.microsoft.Outlook",
        ],
        promptFragment: "The target app is email or a document. Use full sentences, proper punctuation and capitalization.")

    public static let `default` = FormattingProfile(
        name: "Default",
        bundleIDs: [],
        promptFragment: "Light cleanup, neutral tone.")

    /// Profiles with explicit bundle ids, checked in order.
    public static let all = [code, chat, mail]

    /// Maps a frontmost app bundle id to its profile, falling back to `default`.
    public static func resolve(bundleID: String?) -> FormattingProfile {
        guard let bundleID else { return Self.default }
        for profile in all where profile.bundleIDs.contains(bundleID) {
            return profile
        }
        return Self.default
    }
}
