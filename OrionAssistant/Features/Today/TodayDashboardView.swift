import SwiftUI

struct TodayDashboardView: View {
    @ObservedObject var viewModel: TodayDashboardViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if let suggestedAction = viewModel.suggestedAction {
                    ActionCard(
                        eyebrow: "AI 建议",
                        title: suggestedAction.title,
                        subtitle: suggestedAction.subtitle,
                        primaryTitle: "已同步",
                        secondaryTitle: nil,
                        statusText: "最近一次已生成的真实安排",
                        primaryAction: {},
                        secondaryAction: nil
                    )
                } else {
                    emptyCard(
                        title: "还没有今日建议",
                        subtitle: "当你确认一次真实的日程或出差安排后，这里会显示最近生成的动作。"
                    )
                }

                sectionTitle("时间线")

                if viewModel.agendaItems.isEmpty {
                    emptyCard(
                        title: "今天还没有汇总行程",
                        subtitle: "确认生成一次真实日程后，这里会展示今天最相关的安排。"
                    )
                } else {
                    ForEach(viewModel.agendaItems) { item in
                        HStack(alignment: .top, spacing: 14) {
                            Circle()
                                .fill(color(for: item.kind))
                                .frame(width: 12, height: 12)
                                .padding(.top, 6)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.timeRange)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                                Text(item.title)
                                    .font(.headline)
                                Text(item.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                            }
                        }
                        .appCardStyle()
                    }
                }

                sectionTitle("即将出发")
                if let recommendation = viewModel.routeRecommendation {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(recommendation.departureTime) 出发")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.accent)
                        Text("\(recommendation.origin) → \(recommendation.destination)")
                            .font(.title3.weight(.bold))
                        Text("预计 \(recommendation.durationMinutes) 分钟，建议预留 \(recommendation.bufferMinutes) 分钟缓冲")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                    .appCardStyle(fill: AppTheme.Colors.accent.opacity(0.08), stroke: AppTheme.Colors.accent.opacity(0.18))
                } else {
                    emptyCard(
                        title: "还没有路线建议",
                        subtitle: "生成一次带地点的真实行程后，这里会展示出发提示和路线预留时间。"
                    )
                }
            }
            .appPageLayout()
            .padding(.vertical, 12)
        }
        .background(AppBackgroundView())
        .navigationTitle("今日")
        .scrollIndicators(.hidden)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("周二 3月24日")
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.secondaryText)
            Text(viewModel.greeting)
                .font(.largeTitle.weight(.bold))
            Text("时间、路线和待办会在这里汇总成一条可执行的今天。")
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
    }

    private func color(for kind: AgendaKind) -> Color {
        switch kind {
        case .meeting: AppTheme.Colors.accent
        case .task: AppTheme.Colors.warning
        case .travel: AppTheme.Colors.primary
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.bold))
            .padding(.top, 8)
    }

    private func emptyCard(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
        .appCardStyle(fill: AppTheme.Colors.surface, stroke: .black.opacity(0.05))
    }
}
