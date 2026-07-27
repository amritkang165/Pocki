import SwiftUI
import SwiftData

/// Dashboard answering “How am I doing this month?”
struct HomeView: View {
    let expenses: [Expense]
    let settings: AppSettings
    var onSeeAll: () -> Void
    var onSelectExpense: (Expense) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: HomeViewModel?
    @State private var appear = false

    var body: some View {
        NavigationStack {
            ZStack {
                PockiBackground()

                if let viewModel {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Constants.Layout.sectionSpacing) {
                            header(viewModel)

                            BudgetCard(
                                spent: viewModel.monthSpent,
                                budget: viewModel.budget,
                                currencyCode: viewModel.currencyCode,
                                monthLabel: viewModel.monthLabel
                            )
                            .opacity(appear ? 1 : 0)
                            .offset(y: appear ? 0 : 12)

                            statsGrid(viewModel)

                            recentSection(viewModel)
                        }
                        .padding(.horizontal, Constants.Layout.horizontalPadding)
                        .padding(.bottom, 100)
                    }
                    .scrollIndicators(.hidden)
                } else {
                    LoadingView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            bootstrapIfNeeded()
            refresh()
            withAnimation(.easeOut(duration: 0.45)) {
                appear = true
            }
        }
        .onChange(of: expenses.count) { _, _ in refresh() }
        .onChange(of: settings.monthlyBudget) { _, _ in refresh() }
        .onChange(of: settings.currencyCode) { _, _ in refresh() }
    }

    // MARK: - Sections

    private func header(_ viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.greeting)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(Constants.appName)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(Constants.tagline)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }

    private func statsGrid(_ viewModel: HomeViewModel) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            StatCard(
                title: "Today",
                value: viewModel.todaySpent.formatted(currencyCode: viewModel.currencyCode),
                icon: "sun.max.fill",
                accent: .pockiWarning
            )
            StatCard(
                title: "This Week",
                value: viewModel.weekSpent.formatted(currencyCode: viewModel.currencyCode),
                icon: "calendar",
                accent: .pockiAccent
            )
            StatCard(
                title: "Daily Average",
                value: viewModel.dailyAverage.formatted(currencyCode: viewModel.currencyCode),
                icon: "chart.line.uptrend.xyaxis",
                accent: Color(red: 0.45, green: 0.55, blue: 0.95)
            )
            StatCard(
                title: "Remaining",
                value: max(viewModel.remaining, 0).formatted(currencyCode: viewModel.currencyCode),
                icon: "leaf.fill",
                accent: .pockiSuccess
            )
        }
    }

    @ViewBuilder
    private func recentSection(_ viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Recent", actionTitle: "See All", action: onSeeAll)

            if viewModel.recentExpenses.isEmpty {
                GlassCard {
                    EmptyStateView(
                        title: "No expenses yet",
                        message: "Add your first expense to see it here.",
                        systemImage: "tray"
                    )
                    .frame(minHeight: 180)
                }
            } else {
                GlassCard(padding: 8) {
                    VStack(spacing: 0) {
                        ForEach(viewModel.recentExpenses, id: \.id) { expense in
                            Button {
                                onSelectExpense(expense)
                            } label: {
                                ExpenseRow(expense: expense, currencyCode: viewModel.currencyCode)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)

                            if expense.id != viewModel.recentExpenses.last?.id {
                                Divider()
                                    .padding(.leading, 70)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func bootstrapIfNeeded() {
        guard viewModel == nil else { return }
        viewModel = HomeViewModel(budgetService: BudgetService(modelContext: modelContext))
    }

    private func refresh() {
        viewModel?.refresh(expenses: expenses, settings: settings)
    }
}

#Preview {
    HomeView(
        expenses: MockData.sampleExpenses(),
        settings: AppSettings(),
        onSeeAll: {},
        onSelectExpense: { _ in }
    )
    .modelContainer(PreviewContainer.make(seeded: true))
}
