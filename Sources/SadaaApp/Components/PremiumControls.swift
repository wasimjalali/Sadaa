import AppKit
import SwiftUI

private struct ClickableCursorModifier: ViewModifier {
    let enabled: Bool
    @Environment(\.isEnabled) private var isEnabled
    @State private var cursorPushed = false

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                guard enabled, isEnabled else {
                    popIfNeeded()
                    return
                }
                if inside, !cursorPushed {
                    NSCursor.pointingHand.push()
                    cursorPushed = true
                } else if !inside {
                    popIfNeeded()
                }
            }
            .onDisappear {
                popIfNeeded()
            }
    }

    private func popIfNeeded() {
        if cursorPushed {
            NSCursor.pop()
            cursorPushed = false
        }
    }
}

extension View {
    func clickableCursor(_ enabled: Bool = true) -> some View {
        modifier(ClickableCursorModifier(enabled: enabled))
    }

    func premiumInputChrome() -> some View {
        textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.line, lineWidth: 1))
    }
}

struct PremiumStatusBadge: View {
    let icon: String?
    let text: String
    let tint: Color

    init(icon: String? = nil, text: String, tint: Color) {
        self.icon = icon
        self.text = text
        self.tint = tint
    }

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 6).fill(tint.opacity(0.08)))
    }
}

struct PremiumIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PremiumIconButtonBody(configuration: configuration)
    }
}

private struct PremiumIconButtonBody: View {
    let configuration: ButtonStyle.Configuration
    @State private var hovering = false

    var body: some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.navy)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Theme.navy.opacity(hovering ? 0.10 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(Theme.navy.opacity(hovering ? 0.35 : 0.16), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .onHover { hovering = $0 }
            .clickableCursor()
            .animation(.easeOut(duration: 0.14), value: hovering)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct PremiumSearchField: View {
    let placeholder: String
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(focused ? Theme.gold : Theme.charcoal.opacity(0.45))
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .focused($focused)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.charcoal.opacity(0.35))
                }
                .buttonStyle(.plain)
                .clickableCursor()
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(focused ? Theme.accent : Theme.line,
                              lineWidth: 1)
        )
        .shadow(color: focused ? Theme.accent.opacity(0.12) : .clear, radius: 0, x: 0, y: 0)
        .animation(.easeOut(duration: 0.16), value: focused)
    }
}

struct PremiumSection<Content: View>: View {
    let title: String
    let icon: String?
    let content: Content

    init(_ title: String, icon: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(Theme.gold)
                }
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.navy)
                Spacer(minLength: 0)
            }
            content
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
    }
}

struct CommandPageHeader<Accessory: View>: View {
    let eyebrow: String?
    let title: String
    let subtitle: String
    let accessory: Accessory

    init(eyebrow: String? = nil,
         title: String,
         subtitle: String,
         @ViewBuilder accessory: () -> Accessory) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 18) {
                titleBlock
                Spacer(minLength: 12)
                accessory
                    .fixedSize(horizontal: true, vertical: false)
            }

            VStack(alignment: .leading, spacing: 14) {
                titleBlock
                accessory
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension CommandPageHeader where Accessory == EmptyView {
    init(eyebrow: String? = nil, title: String, subtitle: String) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle) {
            EmptyView()
        }
    }
}

struct CommandPanel<Content: View>: View {
    let title: String?
    let icon: String?
    let content: Content

    init(_ title: String? = nil,
         icon: String? = nil,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if title != nil || icon != nil {
                HStack(spacing: 8) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.gold)
                    }
                    if let title {
                        Text(title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.navy)
                    }
                    Spacer(minLength: 0)
                }
            }
            content
        }
        .padding(18)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
    }
}

struct CommandMetric: View {
    let icon: String
    let value: String
    let label: String
    var tint: Color = Theme.navy

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.surfaceSubtle, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
    }
}

struct CommandToolbarButton: View {
    let systemImage: String
    let title: String
    var tint: Color = Theme.navy
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint)
        .background(Theme.white, in: RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(tint.opacity(0.24), lineWidth: 1)
        )
        .help(title)
        .clickableCursor()
    }
}

struct CommandEmptyState: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Theme.gold)
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text(detail)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
    }
}
