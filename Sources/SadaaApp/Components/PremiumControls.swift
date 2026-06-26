import SwiftUI

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
        .background(Capsule().fill(tint.opacity(0.12)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.28), lineWidth: 1))
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
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: hovering)
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: configuration.isPressed)
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
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(Theme.creamSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(focused ? Theme.gold.opacity(0.7) : Theme.gold.opacity(0.18),
                              lineWidth: focused ? 1.5 : 1)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: focused)
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
        .background(Theme.creamSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Theme.gold.opacity(0.18), lineWidth: 1)
        )
    }
}
