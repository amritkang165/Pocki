import SwiftUI
import SwiftData

/// Full detail for a single expense with edit and delete actions.
struct ExpenseDetailView: View {
    let expense: Expense

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [AppSettings]

    @State private var viewModel: ExpenseDetailViewModel?
    @State private var showEdit = false
    @State private var showDeleteConfirm = false

    private var currencyCode: String {
        settingsList.first?.currencyCode ?? "USD"
    }

    var body: some View {
        ZStack {
            PockiBackground()

            ScrollView {
                VStack(spacing: 20) {
                    hero
                    detailsCard
                    futurePlaceholders
                    actions
                }
                .padding(Constants.Layout.horizontalPadding)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(isPresented: $showEdit) {
            AddExpenseView(editingExpense: expense)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "Delete this expense?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                viewModel?.delete()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            if viewModel == nil {
                viewModel = ExpenseDetailViewModel(
                    expense: expense,
                    expenseService: ExpenseService(modelContext: modelContext)
                )
            }
        }
    }

    private var hero: some View {
        GlassCard {
            VStack(spacing: 16) {
                CategoryBadge(category: expense.category, size: 64)

                Text(expense.amount.formatted(currencyCode: currencyCode))
                    .font(.system(size: 40, weight: .bold, design: .rounded))

                Text(expense.merchant)
                    .font(.title3.weight(.semibold))

                Text(expense.category.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private var detailsCard: some View {
        GlassCard(padding: 0) {
            VStack(spacing: 0) {
                detailRow(title: "Date", value: expense.date.formatted(date: .abbreviated, time: .shortened))
                Divider().padding(.leading, 20)
                detailRow(title: "Source", value: expense.source.displayName, icon: expense.source.icon)
                Divider().padding(.leading, 20)
                detailRow(
                    title: "Notes",
                    value: (expense.note?.isEmpty == false) ? (expense.note ?? "") : "None"
                )
                Divider().padding(.leading, 20)
                detailRow(title: "Verified", value: expense.isVerified ? "Yes" : "No")
            }
        }
    }

    /// Placeholders for OCR confidence and related future fields.
    private var futurePlaceholders: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recognition")
                    .font(.headline)

                HStack {
                    Label("OCR Confidence", systemImage: "text.viewfinder")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(confidenceLabel)
                        .foregroundStyle(.tertiary)
                }
                .font(.subheadline)

                Text("Available when expenses are captured from screenshots.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            PrimaryButton(title: "Edit") {
                showEdit = true
            }

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Text("Delete")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: Constants.Layout.buttonRadius, style: .continuous)
                            .fill(Color.red.opacity(0.12))
                    )
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private func detailRow(title: String, value: String, icon: String? = nil) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.body)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var confidenceLabel: String {
        if let confidence = expense.confidence {
            return "\(Int(confidence * 100))%"
        }
        return "—"
    }
}

#Preview {
    NavigationStack {
        ExpenseDetailView(
            expense: Expense(amount: 12.5, merchant: "Blue Bottle", category: .food, note: "Latte")
        )
    }
    .modelContainer(PreviewContainer.make())
}
