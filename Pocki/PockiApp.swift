import SwiftUI
import SwiftData

@main
struct PockiApp: App {
    private let container: ModelContainer

    init() {
        do {
            let schema = Schema([Expense.self, AppSettings.self])
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(container)
    }
}
