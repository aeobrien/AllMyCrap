import SwiftUI
import SwiftData

@main
struct AllMyCrapApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // This makes the data models available to the entire app.
        .modelContainer(for: [Location.self, Item.self])
    }
}
