import SwiftUI
import SwiftData
import PhotosUI

/// Bottom sheet form for creating or editing an expense.
struct AddExpenseView: View {
    var editingExpense: Expense? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: AddExpenseViewModel?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var showHistoryImport = false
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
                if viewModel?.screenshotImage == nil {
                    amountFocused = true
                }
            }
        }
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem, let viewModel else { return }
            Task {
                await loadPhoto(newItem, into: viewModel)
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image, .png, .jpeg, .heic, .webP],
            allowsMultipleSelection: false
        ) { result in
            guard let viewModel else { return }
            Task {
                await loadFile(result, into: viewModel)
            }
        }
    }

    private func formContent(_ viewModel: AddExpenseViewModel) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.showsScreenshotImport {
                    screenshotImportCard(viewModel)
                }

                amountField(viewModel)
                merchantField(viewModel)
                categoryPicker(viewModel)
                datePicker(viewModel)
                notesField(viewModel)

                if viewModel.source == .ocr, let confidence = viewModel.confidence {
                    ocrMetaCard(app: viewModel.sourceApp, confidence: confidence)
                }

                PrimaryButton(
                    title: viewModel.saveTitle,
                    isEnabled: viewModel.isValid && !viewModel.isScanningScreenshot
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

    // MARK: - Screenshot import

    private func screenshotImportCard(_ viewModel: AddExpenseViewModel) -> some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "text.viewfinder")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.pockiAccent)
                        .frame(width: 36, height: 36)
                        .background(Color.pockiAccent.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("From UPI screenshot")
                            .font(.headline)
                        Text("GPay · PhonePe · Paytm · BHIM · any UPI")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let image = viewModel.screenshotImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(alignment: .topTrailing) {
                            Button {
                                viewModel.clearScreenshot()
                                selectedPhoto = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .black.opacity(0.45))
                                    .font(.title2)
                                    .padding(8)
                            }
                            .accessibilityLabel("Remove screenshot")
                        }
                }

                if viewModel.isScanningScreenshot {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(viewModel.screenshotStatusMessage ?? "Reading…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if let error = viewModel.screenshotErrorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                } else if let status = viewModel.screenshotStatusMessage {
                    Text(status)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
                .disabled(viewModel.isScanningScreenshot)
                .accessibilityLabel("Choose screenshot from Photos")

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
                .disabled(viewModel.isScanningScreenshot)
                .accessibilityLabel("Choose screenshot from Files")

                Divider()
                    .overlay(Color.primary.opacity(0.08))

                Button {
                    showHistoryImport = true
                } label: {
                    Label("Import today's history", systemImage: "list.bullet.rectangle.portrait")
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
                .accessibilityLabel("Import today's transaction history")
            }
        }
        .sheet(isPresented: $showHistoryImport) {
            HistoryImportView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
    }

    private func ocrMetaCard(app: UPIPaymentApp?, confidence: Double) -> some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Read from \(app?.displayName ?? "UPI screenshot")", systemImage: "waveform.badge.magnifyingglass")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(confidence * 100))%")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Color.pockiAccent)
                }
                Text("Review and adjust — nothing saves until you tap Save.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Fields

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

    // MARK: - Helpers

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

    private func loadPhoto(_ item: PhotosPickerItem, into viewModel: AddExpenseViewModel) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                viewModel.screenshotErrorMessage = "Could not load that photo."
                return
            }
            amountFocused = false
            await viewModel.importScreenshot(image)
        } catch {
            viewModel.screenshotErrorMessage = error.localizedDescription
        }
    }

    private func loadFile(_ result: Result<[URL], Error>, into viewModel: AddExpenseViewModel) async {
        do {
            guard let url = try result.get().first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing { url.stopAccessingSecurityScopedResource() }
            }
            guard let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data) else {
                viewModel.screenshotErrorMessage = "Could not load that file."
                return
            }
            amountFocused = false
            await viewModel.importScreenshot(image)
        } catch {
            viewModel.screenshotErrorMessage = error.localizedDescription
        }
    }
}

#Preview {
    AddExpenseView()
        .modelContainer(PreviewContainer.make())
}
