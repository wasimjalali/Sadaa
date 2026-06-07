import SwiftUI

/// Placeholder for the custom dictionary feature. No controls yet, just a
/// Karko-styled empty state describing what is coming.
struct DictionaryPage: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "character.book.closed")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(Theme.gold)

            Text("Custom dictionary")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.charcoal)

            Text("Teach Sadaa your names and jargon. Arriving in the next update.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.charcoal.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
