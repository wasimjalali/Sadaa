import SwiftUI
import SadaaCore

struct MemoryTermRow: View {
    let term: MemoryTerm
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: term.priority == .always ? "star.fill" : "textformat")
                .foregroundStyle(term.priority == .always ? Theme.gold : Theme.sage)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 4) {
                Text(term.phrase)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.charcoal)
                HStack(spacing: 6) {
                    PremiumStatusBadge(text: priorityTitle(term.priority),
                                       tint: term.priority == .always ? Theme.gold : Theme.navy)
                    if term.language != .auto {
                        PremiumStatusBadge(text: languageTitle(term.language), tint: Theme.sage)
                    }
                    if term.usageCount > 0 {
                        PremiumStatusBadge(text: "\(term.usageCount)x used", tint: Theme.sage)
                    }
                }
                if !term.pronunciations.isEmpty || !term.aliases.isEmpty {
                    Text((term.pronunciations + term.aliases).joined(separator: ", "))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.charcoal.opacity(0.58))
                        .lineLimit(2)
                }
                if !term.notes.isEmpty {
                    Text(term.notes)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.charcoal.opacity(0.55))
                        .lineLimit(2)
                }
            }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(PremiumIconButtonStyle())
            .help("Remove term")
        }
        .padding(12)
        .background(Theme.cream, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct ReplacementRuleRow: View {
    let rule: ReplacementRule
    let onToggleEnabled: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: rule.isEnabled ? "arrow.left.arrow.right" : "pause.circle")
                .foregroundStyle(rule.isEnabled ? Theme.sage : Theme.charcoal.opacity(0.4))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(rule.match)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.charcoal)
                Text(rule.replacement)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.charcoal.opacity(0.62))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                if !rule.isEnabled {
                    PremiumStatusBadge(text: "Paused", tint: Theme.charcoal.opacity(0.45))
                }
                PremiumStatusBadge(text: matchModeTitle(rule.matchMode), tint: Theme.navy)
                if rule.language != .auto {
                    PremiumStatusBadge(text: languageTitle(rule.language), tint: Theme.sage)
                }
                if rule.usageCount > 0 {
                    PremiumStatusBadge(text: "\(rule.usageCount)x used", tint: Theme.sage)
                }
            }
            Button(action: onToggleEnabled) {
                Image(systemName: rule.isEnabled ? "pause" : "play.fill")
            }
            .buttonStyle(PremiumIconButtonStyle())
            .help(rule.isEnabled ? "Pause replacement" : "Resume replacement")
            Button(action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(PremiumIconButtonStyle())
            .help("Remove replacement")
        }
        .padding(12)
        .background(Theme.cream, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct MemorySnippetRow: View {
    let snippet: MemorySnippet
    let onToggleEnabled: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: snippet.isEnabled ? "text.badge.plus" : "pause.circle")
                .foregroundStyle(snippet.isEnabled ? Theme.gold : Theme.charcoal.opacity(0.4))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 4) {
                Text(snippet.trigger)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.charcoal)
                Text(snippet.expansion)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.charcoal.opacity(0.62))
                    .lineLimit(3)
                if !snippet.tags.isEmpty {
                    Text(snippet.tags.map { "#\($0)" }.joined(separator: " "))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.sage)
                }
                if !snippet.isEnabled {
                    PremiumStatusBadge(text: "Paused", tint: Theme.charcoal.opacity(0.45))
                }
                if snippet.language != .auto {
                    PremiumStatusBadge(text: languageTitle(snippet.language), tint: Theme.sage)
                }
                if snippet.usageCount > 0 {
                    PremiumStatusBadge(text: "\(snippet.usageCount)x used", tint: Theme.sage)
                }
            }
            Spacer()
            Button(action: onToggleEnabled) {
                Image(systemName: snippet.isEnabled ? "pause" : "play.fill")
            }
            .buttonStyle(PremiumIconButtonStyle())
            .help(snippet.isEnabled ? "Pause snippet" : "Resume snippet")
            Button(action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(PremiumIconButtonStyle())
            .help("Remove snippet")
        }
        .padding(12)
        .background(Theme.cream, in: RoundedRectangle(cornerRadius: 8))
    }
}

private func languageTitle(_ language: MemoryLanguage) -> String {
    switch language {
    case .auto: return "Any language"
    case .en: return "English"
    case .de: return "German"
    }
}

private func priorityTitle(_ priority: MemoryPriority) -> String {
    switch priority {
    case .normal: return "Normal"
    case .high: return "High"
    case .always: return "Always"
    }
}

private func matchModeTitle(_ mode: ReplacementMatchMode) -> String {
    switch mode {
    case .exactPhrase: return "Exact"
    case .caseInsensitivePhrase: return "Case-insensitive"
    case .wordBoundaryPhrase: return "Word boundary"
    }
}

struct MemorySuggestionRow: View {
    let suggestion: MemorySuggestion
    let onAccept: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(Theme.gold)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(suggestion.proposed)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.charcoal)
                Text("\(suggestion.evidenceCount) signals")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.charcoal.opacity(0.55))
            }
            Spacer()
            Button(action: onAccept) {
                Image(systemName: "checkmark")
            }
            .buttonStyle(PremiumIconButtonStyle())
            .help("Accept suggestion")
            Button(action: onDismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(PremiumIconButtonStyle())
            .help("Dismiss suggestion")
        }
        .padding(12)
        .background(Theme.cream, in: RoundedRectangle(cornerRadius: 8))
    }
}
