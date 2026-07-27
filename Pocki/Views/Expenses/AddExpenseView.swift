import SwiftUI
import SwiftData

/// Bottom sheet form for creating or editing an expense.
struct AddExpenseView: View {
    var editingExpense: Expense? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: AddExpenseViewModel?
    @FocusState private var amountFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                PockiBackground()

                if let viewModel {
                    formContent(viewModel)
                } else {
                    LoadingView()
                }
            }
            .navigationTitle(viewModel?.title ?? "Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            bootstrapIfNeeded()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                amountFocused = true
            }
        }
    }

    private func formContent(_ viewModel: AddExpenseViewModel) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                amountField(viewModel)
                merchantField(viewModel)
                categoryPicker(viewModel)
                datePicker(viewModel)
                notesField(viewModel)

                PrimaryButton(
                    title: viewModel.saveTitle,
                    isEnabled: viewModel.isValid
                ) {
                    if viewModel.save() {
                        dismiss()
                    }
                }
                .padding(.top, 8)
            }
            .padding(Constants.Layout.horizontalPadding)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func amountField(_ viewModel: AddExpenseViewModel) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Amount")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(currencySymbol)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    TextField("0", text: Binding(
                        get: { viewModel.amountText },
                        set: { viewModel.amountText = $0 }
                    ))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .accessibilityLabel("Amount")
                }
            }
        }
    }

    private func merchantField(_ viewModel: AddExpenseViewModel) -> some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Merchant")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("Where did you spend?", text: Binding(
                    get: { viewModel.merchant },
                    set: { viewModel.merchant = $0 }
                ))
                .font(.body.weight(.medium))
                .textInputAutocapitalization(.words)
            }
        }
    }

    private func categoryPicker(_ viewModel: AddExpenseViewModel) -> some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Category")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 96), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(ExpenseCategory.allCases) { category in
                        let selected = viewModel.category == category
                        Button {
                            HapticService.selection()
                            viewModel.category = category
                        } label: {
                            VStack(spacing: 8) {
                                CategoryBadge(category: category, size: 36)
                                Text(category.rawValue)
                                    .font(.caption2.weight(.medium))
                                    .lineLimit(1)
                                    .foregroundStyle(selected ? .primary : .secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(selected ? category.color.opacity(0.14) : Color.clear)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(
                                        selected ? category.color.opacity(0.45) : Color.primary.opacity(0.06),
                                        lineWidth: 1
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func datePicker(_ viewModel: AddExpenseViewModel) -> some View {
        GlassCard(padding: 16) {
            DatePicker(
                "Date",
                selection: Binding(
                    get: { viewModel.date },
                    set: { viewModel.date = $0 }
                ),
                displayedComponents: [.date, .hourAndMinute]
            )
            .font(.body.weight(.medium))
        }
    }

    private func notesField(_ viewModel: AddExpenseViewModel) -> some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("Optional", text: Binding(
                    get: { viewModel.note },
                    set: { viewModel.note = $0 }
                ), axis: .vertical)
                .lineLimit(3...6)
            }
        }
    }

    private var currencySymbol: String {
        let code = (try? modelContext.fetch(FetchDescriptor<AppSettings>()).first?.currencyCode) ?? "USD"
        let locale = Locale.availableIdentifiers
            .compactMap { Locale(identifier: $0) }
            .first { $0.currency?.identifier == code }
        return locale?.currencySymbol ?? "$"
    }

    private func bootstrapIfNeeded() {
        guard viewModel == nil else { return }
        viewModel = AddExpenseViewModel(
            expenseService: ExpenseService(modelContext: modelContext),
            editingExpense: editingExpense
        )
    }
}

#Preview {
    AddExpenseView()
        .modelContainer(PreviewContainer.make())
}
