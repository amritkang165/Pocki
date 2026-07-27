import SwiftUI
import Charts

/// Charts and spending analytics.
struct InsightsView: View {
    let expenses: [Expense]
    let currencyCode: String

    @State private var viewModel = InsightsViewModel()
    @State private var appear = false

    var body: some View {
        NavigationStack {
            ZStack {
                PockiBackground()

                if expenses.isEmpty {
                    EmptyStateView(
                        title: "No insights yet",
                        message: "Add a few expenses to unlock charts and trends.",
                        systemImage: "chart.bar"
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Constants.Layout.sectionSpacing) {
                            summaryRow
                            weeklyChart
                            monthlyChart
                            categoryBreakdown
                            topMerchants
                            trendCard
                        }
                        .padding(.horizontal, Constants.Layout.horizontalPadding)
                        .padding(.bottom, 100)
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 10)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Insights")
        }
        .onAppear {
            viewModel.refresh(expenses: expenses, currencyCode: currencyCode)
            withAnimation(.easeOut(duration: 0.4)) { appear = true }
        }
        .onChange(of: expenses.count) { _, _ in
            viewModel.refresh(expenses: expenses, currencyCode: currencyCode)
        }
        .onChange(of: currencyCode) { _, newValue in
            viewModel.refresh(expenses: expenses, currencyCode: newValue)
        }
    }

    // MARK: - Sections

    private var summaryRow: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            StatCard(
                title: "This Month",
                value: viewModel.monthTotal.formatted(currencyCode: currencyCode),
                icon: "calendar",
                accent: .pockiAccent
            )
            StatCard(
                title: "Daily Average",
                value: viewModel.dailyAverage.formatted(currencyCode: currencyCode),
                icon: "chart.line.uptrend.xyaxis",
                accent: Color(red: 0.45, green: 0.55, blue: 0.95)
            )
        }
    }

    private var weeklyChart: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "This Week")
                Text(viewModel.weekTotal.formatted(currencyCode: currencyCode))
                    .font(.system(.title2, design: .rounded).weight(.bold))

                Chart(viewModel.weekly) { item in
                    BarMark(
                        x: .value("Day", item.date, unit: .day),
                        y: .value("Amount", item.amount)
                    )
                    .foregroundStyle(Color.pockiAccent.gradient)
                    .cornerRadius(6)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date.shortWeekday)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(amount.compactCurrency(currencyCode: currencyCode))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 180)
                .animation(.easeInOut(duration: 0.6), value: viewModel.weekTotal)
            }
        }
    }

    private var monthlyChart: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "This Month")

                Chart(viewModel.monthly) { item in
                    AreaMark(
                        x: .value("Day", item.date, unit: .day),
                        y: .value("Amount", item.amount)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.pockiAccent.opacity(0.35), Color.pockiAccent.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Day", item.date, unit: .day),
                        y: .value("Amount", item.amount)
                    )
                    .foregroundStyle(Color.pockiAccent)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5))
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 180)
                .animation(.easeInOut(duration: 0.6), value: viewModel.monthTotal)
            }
        }
    }

    private var categoryBreakdown: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Categories")

                if viewModel.categories.isEmpty {
                    Text("No spending this month")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Chart(viewModel.categories) { item in
                        SectorMark(
                            angle: .value("Amount", item.amount),
                            innerRadius: .ratio(0.62),
                            angularInset: 1.5
                        )
                        .foregroundStyle(item.category.color)
                        .cornerRadius(4)
                    }
                    .frame(height: 200)
                    .animation(.easeInOut(duration: 0.55), value: viewModel.categories.map(\.amount))

                    VStack(spacing: 10) {
                        ForEach(viewModel.categories.prefix(6)) { item in
                            HStack(spacing: 12) {
                                CategoryBadge(category: item.category, size: 28)
                                Text(item.category.rawValue)
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Text(item.amount.formatted(currencyCode: currencyCode))
                                    .font(.subheadline.monospacedDigit())
                                Text("\(Int(item.percentage * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 36, alignment: .trailing)
                            }
                        }
                    }
                }
            }
        }
    }

    private var topMerchants: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Top Merchants")

                if viewModel.topMerchants.isEmpty {
                    Text("No merchants yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(viewModel.topMerchants.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.merchant)
                                    .font(.subheadline.weight(.semibold))
                                Text("\(item.count) purchase\(item.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(item.amount.formatted(currencyCode: currencyCode))
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                        }
                        .padding(.vertical, 4)

                        if item.id != viewModel.topMerchants.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var trendCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Recent Trend")
                let rising = viewModel.trendDelta > 0
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: rising ? "arrow.up.right" : "arrow.down.right")
                        .foregroundStyle(rising ? Color.pockiWarning : Color.pockiSuccess)
                    Text(abs(viewModel.trendDelta).formatted(currencyCode: currencyCode))
                        .font(.title3.weight(.bold))
                    Text(rising ? "more than last week" : "less than last week")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    InsightsView(expenses: MockData.sampleExpenses(), currencyCode: "USD")
}
