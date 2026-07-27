import SwiftUI
import SwiftData

/// Simple preferences: budget, currency, about, and data reset.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        NavigationStack {
            ZStack {
                PockiBackground()

                if let viewModel {
                    Form {
                        budgetSection(viewModel)
                        currencySection(viewModel)
                        dataSection(viewModel)
                        aboutSection
                    }
                    .scrollContentBackground(.hidden)
                } else {
                    LoadingView()
                }
            }
            .navigationTitle("Settings")
        }
        .onAppear {
            bootstrapIfNeeded()
            viewModel?.load()
        }
        .alert(
            "Reset all data?",
            isPresented: Binding(
                get: { viewModel?.showResetConfirmation ?? false },
                set: { viewModel?.showResetConfirmation = $0 }
            )
        ) {
            Button("Reset", role: .destructive) {
                try? viewModel?.resetAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes every expense and restores the default budget.")
        }
        .alert(
            "Export Coming Soon",
            isPresented: Binding(
                get: { viewModel?.showExportPlaceholder ?? false },
                set: { viewModel?.showExportPlaceholder = $0 }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("CSV and PDF export will arrive in a future update.")
        }
    }

    // MARK: - Sections

    private func budgetSection(_ viewModel: SettingsViewModel) -> some View {
        Section {
            HStack {
                Text("Monthly Budget")
                Spacer()
                TextField("Amount", text: Binding(
                    get: { viewModel.budgetText },
                    set: { viewModel.budgetText = $0 }
                ))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 140)
                .onSubmit { viewModel.saveBudget() }
            }

            Button("Save Budget") {
                viewModel.saveBudget()
            }
            .foregroundStyle(Color.pockiAccent)
        } header: {
            Text("Budget")
        } footer: {
            Text("Used on Home to show remaining balance and progress.")
        }
        .listRowBackground(Color.pockiCard.opacity(0.7))
    }

    private func currencySection(_ viewModel: SettingsViewModel) -> some View {
        Section("Currency") {
            Picker("Currency", selection: Binding(
                get: { viewModel.selectedCurrency },
                set: {
                    viewModel.selectedCurrency = $0
                    viewModel.saveCurrency()
                }
            )) {
                ForEach(viewModel.availableCurrencies, id: \.self) { code in
                    Text(code).tag(code)
                }
            }
            .pickerStyle(.navigationLink)
        }
        .listRowBackground(Color.pockiCard.opacity(0.7))
    }

    private func dataSection(_ viewModel: SettingsViewModel) -> some View {
        Section("Data") {
            Button {
                viewModel.showExportPlaceholder = true
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }

            Button(role: .destructive) {
                viewModel.showResetConfirmation = true
            } label: {
                Label("Reset All Data", systemImage: "trash")
            }
        }
        .listRowBackground(Color.pockiCard.opacity(0.7))
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("App", value: Constants.appName)
            LabeledContent("Version", value: "\(Constants.appVersion) (\(Constants.buildNumber))")
            LabeledContent("Tagline", value: Constants.tagline)
        }
        .listRowBackground(Color.pockiCard.opacity(0.7))
    }

    private func bootstrapIfNeeded() {
        guard viewModel == nil else { return }
        viewModel = SettingsViewModel(
            budgetService: BudgetService(modelContext: modelContext),
            expenseService: ExpenseService(modelContext: modelContext)
        )
    }
}

#Preview {
    SettingsView()
        .modelContainer(PreviewContainer.make())
}
