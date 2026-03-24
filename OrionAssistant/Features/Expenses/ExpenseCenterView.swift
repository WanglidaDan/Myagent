import SwiftUI

struct ExpenseCenterView: View {
    let viewModel: ExpenseCenterViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if viewModel.summary.recentItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("费用中心还没有真实记录")
                            .font(.title3.weight(.bold))
                        Text("后续接入发票扫描和出差费用归档后，这里只展示真实费用，不再预置演示票据。")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                    .appCardStyle(fill: AppTheme.Colors.primary, stroke: AppTheme.Colors.primary.opacity(0.3))
                    .foregroundStyle(.white)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(viewModel.summary.monthLabel) 共 \(viewModel.summary.recentItems.count) 笔最近记录")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                        Text("¥\(viewModel.summary.totalAmount as NSDecimalNumber)")
                            .font(.largeTitle.weight(.bold))
                        Text(viewModel.summary.categoryBreakdown.map { "\($0.title) ¥\($0.amount as NSDecimalNumber)" }.joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .appCardStyle(fill: AppTheme.Colors.primary, stroke: AppTheme.Colors.primary.opacity(0.3))
                    .foregroundStyle(.white)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) {
                        metricCard(title: "待提交", value: "\(viewModel.summary.pendingSubmissionCount) 笔", tint: AppTheme.Colors.accent)
                        metricCard(title: "待复核", value: "\(viewModel.summary.pendingReviewCount) 张票据", tint: AppTheme.Colors.warning)
                    }
                    VStack(spacing: 14) {
                        metricCard(title: "待提交", value: "\(viewModel.summary.pendingSubmissionCount) 笔", tint: AppTheme.Colors.accent)
                        metricCard(title: "待复核", value: "\(viewModel.summary.pendingReviewCount) 张票据", tint: AppTheme.Colors.warning)
                    }
                }

                sectionTitle("最近发票")
                if viewModel.summary.recentItems.isEmpty {
                    Text("暂无真实发票记录。")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .appCardStyle()
                } else {
                    ForEach(viewModel.summary.recentItems) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(item.title)
                                    .font(.headline)
                                Spacer()
                                Text("¥\(item.amount as NSDecimalNumber)")
                                    .font(.subheadline.weight(.semibold))
                            }

                            Text(item.detail)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Colors.secondaryText)

                            Text(item.status.rawValue)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(statusColor(for: item.status).opacity(0.15))
                                .foregroundStyle(statusColor(for: item.status))
                                .clipShape(Capsule())
                        }
                        .appCardStyle()
                    }
                }

                sectionTitle("录入方式")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        actionPill("拍照扫描", filled: true)
                        actionPill("相册导入", filled: false)
                        actionPill("PDF 导入", filled: false)
                    }
                }
            }
            .appPageLayout()
            .padding(.vertical, 12)
        }
        .background(AppBackgroundView())
        .navigationTitle("费用")
        .scrollIndicators(.hidden)
    }

    private func metricCard(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(tint)
            Text(value)
                .font(.title2.weight(.bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle(fill: tint.opacity(0.08), stroke: tint.opacity(0.18))
    }

    private func actionPill(_ title: String, filled: Bool) -> some View {
        Text(title)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(filled ? Color.white : AppTheme.Colors.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(filled ? AppTheme.Colors.primary : Color.white)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(.black.opacity(filled ? 0 : 0.06), lineWidth: 1)
            )
    }

    private func statusColor(for status: ExpenseStatus) -> Color {
        switch status {
        case .pendingSubmission: AppTheme.Colors.accent
        case .reviewNeeded: AppTheme.Colors.warning
        case .reimbursed: AppTheme.Colors.primary
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.bold))
            .padding(.top, 4)
    }
}
