import SwiftUI
import SwiftData
import PhotosUI

/// Imports a UPI transaction-history screenshot as multiple expenses.
/// Each detected row is editable and must be reviewed before saving.
struct HistoryImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// When set (e.g. routed from the Add Expense picker), the screenshot is
    /// scanned automatically instead of asking the user to pick one.
    var initialImage: UIImage? = nil

    @State private var viewModel: HistoryImportViewModel?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showFileImporter = false

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
            .navigationTitle("Import history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            bootstrapIfNeeded()
            if let initialImage, viewModel?.transactions.isEmpty ?? true {
                Task { await viewModel?.importHistory(initialImage) }
            }
        }
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem, let viewModel else { return }
            Task { await loadPhoto(newItem, into: viewModel) }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image, .png, .jpeg, .heic, .webP],
            allowsMultipleSelection: false
        ) { result in
            guard let viewModel else { return }
            Task { await loadFile(result, into: viewModel) }
        }
    }

    @ViewBuilder
    private func content(_ viewModel: HistoryImportViewModel) -> some View {
        if viewModel.transactions.isEmpty {
            emptyContent(viewModel)
        } else {
            reviewContent(viewModel)
        }
    }

    // MARK: - Pick a history screenshot

    private func emptyContent(_ viewModel: HistoryImportViewModel) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                pickerCard(viewModel)

                if viewModel.isScanning {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(viewModel.statusMessage ?? "Reading…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                } else if let status = viewModel.statusMessage {
                    Text(status)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let image = viewModel.screenshotImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(20)
        }
    }

    private func pickerCard(_ viewModel: HistoryImportViewModel) -> some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.pockiAccent)
                        .frame(width: 36, height: 36)
                        .background(Color.pockiAccent.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today's transaction history")
                            .font(.headline)
                        Text("One screenshot → many expenses")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                PhotosPicker(
                    selection: $selectedPhoto,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label("Photos", systemImage: "photo.on.rectangle.angled")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .foregroundStyle(Color.pockiAccent)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.pockiAccent.opacity(0.12))
                        )
                }
                .disabled(viewModel.isScanning)

                Button {
                    showFileImporter = true
                } label: {
                    Label("Files", systemImage: "folder")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .foregroundStyle(Color.pockiAccent)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.pockiAccent.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isScanning)
            }
        }
    }

    // MARK: - Review & save

    private func reviewContent(_ viewModel: HistoryImportViewModel) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                summaryCard(viewModel)

                if let status = viewModel.statusMessage {
                    Text(status)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                ForEach(viewModel.transactions.filter { !$0.isFailed }) { transaction in
                    transactionRow(transaction)
                }

                if !viewModel.failedTransactions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Failed", systemImage: "xmark.octagon.fill")
                            .font(.headline)
                            .foregroundStyle(.red)
                        Text("These didn’t go through — they won’t be saved unless you check them.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(viewModel.failedTransactions) { transaction in
                            transactionRow(transaction)
                        }
                    }
                }

                Button("Start over") {
                    viewModel.clear()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                PrimaryButton(
                    title: "Save \(viewModel.includedTransactions.count) expense\(viewModel.includedTransactions.count == 1 ? "" : "s")",
                    isEnabled: viewModel.isValid
                ) {
                    if viewModel.saveAll() > 0 {
                        dismiss()
                    }
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
    }

    private func summaryCard(_ viewModel: HistoryImportViewModel) -> some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Found \(viewModel.transactions.count) transactions")
                    .font(.headline)
                Text("\(viewModel.sourceApp?.displayName ?? "UPI") · \(viewModel.includedTransactions.count) to save\(viewModel.failedTransactions.isEmpty ? "" : " · \(viewModel.failedTransactions.count) failed") · \(viewModel.includedTransactions.count == 0 ? "₹0" : currencySymbol + String(format: "%.0f", viewModel.includedTotal))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Check each row — edit anything wrong, remove what's not yours.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                if viewModel.transactions.contains(where: \.needsReview) {
                    Text("\(viewModel.transactions.filter(\.needsReview).count) row\(viewModel.transactions.filter(\.needsReview).count == 1 ? "" : "s") flagged — those amounts were read two ways. Verify them.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private func transactionRow(_ transaction: HistoryTransaction) -> some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Button {
                        transaction.isIncluded.toggle()
                        HapticService.selection()
                    } label: {
                        Image(systemName: transaction.isIncluded ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(transaction.isIncluded ? Color.pockiAccent : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(transaction.isIncluded ? "Include transaction" : "Exclude transaction")

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            TextField("Amount", text: transaction.amountTextBinding)
                                .keyboardType(.decimalPad)
                                .font(.title3.weight(.semibold))
                                .monospacedDigit()
                                .frame(width: 110)
                                .opacity(transaction.isIncluded ? 1 : 0.4)

                            TextField("Merchant", text: transaction.merchantBinding)
                                .font(.subheadline.weight(.medium))
                                .opacity(transaction.isIncluded ? 1 : 0.4)
                        }

                        HStack(spacing: 8) {
                            if transaction.isFailed {
                                Label("Failed", systemImage: "xmark.octagon.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.red)
                            }
                            if transaction.needsReview {
                                Label("Check amount", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.orange)
                            }
                            Label(transaction.date.formatted(date: .abbreviated, time: .shortened),
                                  systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("· \(Int(transaction.confidence * 100))%")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        if let altAmount = transaction.altAmount {
                            Text("Also read as \(currencySymbol)\(formatAmount(altAmount)) — double-check before saving.")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }

                    Spacer(minLength: 0)

                    Button {
                        viewModel?.remove(transaction)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.secondary.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove transaction")
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatAmount(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.2f", value)
    }

    private var currencySymbol: String {
        let code = (try? modelContext.fetch(FetchDescriptor<AppSettings>()).first?.currencyCode) ?? "INR"
        let locale = Locale.availableIdentifiers
            .map { Locale(identifier: $0) }
            .first { $0.currency?.identifier == code }
        return locale?.currencySymbol ?? "₹"
    }

    private func bootstrapIfNeeded() {
        guard viewModel == nil else { return }
        viewModel = HistoryImportViewModel(
            expenseService: ExpenseService(modelContext: modelContext)
        )
    }

    private func loadPhoto(_ item: PhotosPickerItem, into viewModel: HistoryImportViewModel) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                viewModel.errorMessage = "Could not load that photo."
                return
            }
            await viewModel.importHistory(image)
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private func loadFile(_ result: Result<[URL], Error>, into viewModel: HistoryImportViewModel) async {
        do {
            guard let url = try result.get().first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing { url.stopAccessingSecurityScopedResource() }
            }
            guard let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data) else {
                viewModel.errorMessage = "Could not load that file."
                return
            }
            await viewModel.importHistory(image)
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Bindings

extension HistoryTransaction {
    var amountTextBinding: Binding<String> {
        Binding(get: { self.amountText }, set: { self.amountText = $0 })
    }

    var merchantBinding: Binding<String> {
        Binding(get: { self.merchant }, set: { self.merchant = $0 })
    }
}

#Preview {
    HistoryImportView()
        .modelContainer(PreviewContainer.make())
}
