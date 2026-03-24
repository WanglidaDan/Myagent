import SwiftUI

struct ActionCard: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let primaryTitle: String
    let secondaryTitle: String?
    let statusText: String?
    let primaryAction: () -> Void
    let secondaryAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.Colors.accent.opacity(0.12))
                    Image(systemName: "wand.and.stars")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.accent)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 6) {
                    Text(eyebrow)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.accent)

                    Text(title)
                        .font(.title3.weight(.bold))

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }

                Spacer()
            }

            if let statusText {
                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.Colors.primary.opacity(0.08))
                    .clipShape(Capsule())
            }

            Button(primaryTitle, action: primaryAction)
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.Colors.accent)
                .controlSize(.large)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let secondaryTitle, let secondaryAction {
                Button(secondaryTitle, action: secondaryAction)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .appCardStyle(fill: AppTheme.Colors.surface, stroke: AppTheme.Colors.accent.opacity(0.12))
    }
}
