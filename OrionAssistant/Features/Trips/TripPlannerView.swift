import SwiftUI

struct TripPlannerView: View {
    @ObservedObject var viewModel: TripPlannerViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let summary = viewModel.summary {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(summary.dateRange)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                        Text(summary.title)
                            .font(.largeTitle.weight(.bold))
                        Text(summary.summary)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .appCardStyle(fill: AppTheme.Colors.primary, stroke: AppTheme.Colors.primary.opacity(0.3))
                    .foregroundStyle(.white)

                    sectionTitle("时间轴")
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(summary.timelineItems) { item in
                            HStack(alignment: .top, spacing: 14) {
                                Circle()
                                    .fill(AppTheme.Colors.accent)
                                    .frame(width: 12, height: 12)
                                    .padding(.top, 5)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(item.time)  \(item.title)")
                                        .font(.headline)
                                    Text(item.detail)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.Colors.secondaryText)
                                }
                            }
                        }
                    }
                    .appCardStyle()

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 14) {
                            metricCard(title: "预算", value: "¥\(summary.budgetSpent as NSDecimalNumber)", detail: "已录入 / ¥\(summary.budgetTotal as NSDecimalNumber)", tint: AppTheme.Colors.accent)
                            metricCard(title: "待办", value: "\(summary.pendingItems.count) 项", detail: "继续补充交通、酒店和发票", tint: AppTheme.Colors.primary)
                        }
                        VStack(spacing: 14) {
                            metricCard(title: "预算", value: "¥\(summary.budgetSpent as NSDecimalNumber)", detail: "已录入 / ¥\(summary.budgetTotal as NSDecimalNumber)", tint: AppTheme.Colors.accent)
                            metricCard(title: "待办", value: "\(summary.pendingItems.count) 项", detail: "继续补充交通、酒店和发票", tint: AppTheme.Colors.primary)
                        }
                    }

                    sectionTitle("待处理")
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(summary.pendingItems, id: \.self) { item in
                            Label(item, systemImage: "circle.dotted")
                                .font(.subheadline)
                        }
                    }
                    .appCardStyle()
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("还没有真实行程")
                            .font(.title3.weight(.bold))
                        Text("在助理页输入真实需求，例如“我要去丹东两天，给我安排下行程”。确认后，这里会展示最新生成并同步到系统的行程。")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                    .appCardStyle(fill: AppTheme.Colors.surface, stroke: .black.opacity(0.05))
                }
            }
            .appPageLayout()
            .padding(.vertical, 12)
        }
        .background(AppBackgroundView())
        .navigationTitle("行程")
        .scrollIndicators(.hidden)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.bold))
            .padding(.top, 4)
    }

    private func metricCard(title: String, value: String, detail: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.title2.weight(.bold))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle(fill: tint.opacity(0.08), stroke: tint.opacity(0.18))
    }
}
