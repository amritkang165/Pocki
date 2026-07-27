import Foundation
import SwiftData

/// In-memory SwiftData container for SwiftUI previews.
enum PreviewContainer {
    @MainActor
    static func make(seeded: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(
                for: Expense.self, AppSettings.self,
                configurations: configuration
            )
            if seeded {
                let context = container.mainContext
                context.insert(AppSettings())
                for expense in MockData.sampleExpenses() {
                    context.insert(expense)
                }
            }
            return container
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }
}
