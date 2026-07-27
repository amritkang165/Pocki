import SwiftUI
import SwiftData

/// Root tab navigation with a floating add button.
struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query private var settingsList: [AppSettings]

    @State private var selectedTab: AppTab = .home
    @State private var showAddExpense = false
    @State private var expenseToEdit: Expense?

    private var settings: AppSettings {
        settingsList.first ?? AppSettings()
    }

    enum AppTab: Hashable {
        case home, expenses, insights, settings
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                    HomeView(
                        expenses: expenses,
                        settings: settings,
                        onSeeAll: { selectedTab = .expenses },
                        onSelectExpense: { expenseToEdit = $0 }
                    )
                }

                Tab("Expenses", systemImage: "creditcard.fill", value: AppTab.expenses) {
                    ExpensesView(
                        expenses: expenses,
                        currencyCode: settings.currencyCode,
                        onSelect: { expenseToEdit = $0 }
                    )
                }

                Tab("Insights", systemImage: "chart.bar.fill", value: AppTab.insights) {
                    InsightsView(
                        expenses: expenses,
                        currencyCode: settings.currencyCode
                    )
                }

                Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                    SettingsView()
                }
            }
            .tint(Color.pockiAccent)

            FloatingAddButton {
                showAddExpense = true
            }
            .padding(.trailing, 24)
            .padding(.bottom, 56)
        }
        .sheet(isPresented: $showAddExpense) {
            AddExpenseView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .sheet(item: $expenseToEdit) { expense in
            NavigationStack {
                ExpenseDetailView(expense: expense)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .task {
            ensureSettings()
        }
    }

    private func ensureSettings() {
        if settingsList.isEmpty {
            modelContext.insert(AppSettings())
            try? modelContext.save()
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(PreviewContainer.make())
}
