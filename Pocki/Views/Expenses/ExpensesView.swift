import SwiftUI
import SwiftData

/// Searchable, date-grouped list of all expenses.
struct ExpensesView: View {
    let expenses: [Expense]
    let currencyCode: String
    var onSelect: (Expense) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ExpensesViewModel?
    @State private var expenseToEdit: Expense?

    var body: some View {
        NavigationStack {
            ZStack {
                PockiBackground()

                if let viewModel {
                    content(viewModel)
                } else {
                    LoadingView()
                }
            }
            .navigationTitle("Expenses")
            .searchable(
                text: Binding(
                    get: { viewModel?.searchText ?? "" },
                    set: { viewModel?.searchText = $0 }
                ),
                prompt: "Merchant, category, notes"
            )
            .sheet(item: $expenseToEdit) { expense in
                AddExpenseView(editingExpense: expense)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .onAppear { bootstrapIfNeeded() }
    }

    @ViewBuilder
    private func content(_ viewModel: ExpensesViewModel) -> some View {
        let groups = viewModel.groupedByDate(expenses)

        if expenses.isEmpty {
            EmptyStateView(
                title: "No expenses yet",
                message: "Start tracking spending with the + button.",
                systemImage: "creditcard",
                actionTitle: nil
            )
        } else if groups.isEmpty {
            EmptyStateView(
                title: "No matches",
                message: "Try a different search term.",
                systemImage: "magnifyingglass"
            )
        } else {
            List {
                ForEach(groups, id: \.key) { group in
                    Section {
                        ForEach(group.expenses, id: \.id) { expense in
                            Button {
                                onSelect(expense)
                            } label: {
                                ExpenseRow(expense: expense, currencyCode: currencyCode)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    withAnimation {
                                        viewModel.delete(expense)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    expenseToEdit = expense
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.pockiAccent)
                            }
                            .listRowBackground(Color.pockiCard.opacity(0.65))
                        }
                    } header: {
                        Text(group.key.relativeDayLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .padding(.bottom, 72)
        }
    }

    private func bootstrapIfNeeded() {
        guard viewModel == nil else { return }
        viewModel = ExpensesViewModel(expenseService: ExpenseService(modelContext: modelContext))
    }
}

#Preview {
    ExpensesView(
        expenses: MockData.sampleExpenses(),
        currencyCode: "USD",
        onSelect: { _ in }
    )
    .modelContainer(PreviewContainer.make(seeded: true))
}
