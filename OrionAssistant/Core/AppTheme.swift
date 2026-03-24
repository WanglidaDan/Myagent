import SwiftUI

enum AppTheme {
    enum Colors {
        static let primary = Color(red: 0.11, green: 0.24, blue: 0.45)
        static let accent = Color(red: 0.16, green: 0.63, blue: 0.60)
        static let background = Color(red: 0.96, green: 0.95, blue: 0.92)
        static let surface = Color.white
        static let elevatedSurface = Color(red: 0.985, green: 0.983, blue: 0.975)
        static let secondaryText = Color(red: 0.41, green: 0.46, blue: 0.53)
        static let warning = Color(red: 0.91, green: 0.69, blue: 0.29)
    }

    enum Metrics {
        static let cornerRadius: CGFloat = 24
        static let cardPadding: CGFloat = 20
        static let screenPadding: CGFloat = 20
        static let contentMaxWidth: CGFloat = 760
    }
}

extension View {
    func appCardStyle(fill: Color = AppTheme.Colors.surface, stroke: Color = .black.opacity(0.06)) -> some View {
        self
            .padding(AppTheme.Metrics.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Metrics.cornerRadius, style: .continuous)
                    .fill(fill)
                    .stroke(stroke, lineWidth: 1)
            )
    }

    func appPageLayout() -> some View {
        self
            .frame(maxWidth: AppTheme.Metrics.contentMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, AppTheme.Metrics.screenPadding)
    }
}

struct AppBackgroundView: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.98, green: 0.97, blue: 0.94),
                Color(red: 0.93, green: 0.95, blue: 0.97),
                Color(red: 0.95, green: 0.97, blue: 0.96)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(AppTheme.Colors.accent.opacity(0.08))
                .frame(width: 220, height: 220)
                .blur(radius: 20)
                .offset(x: 60, y: -40)
        }
    }
}
