import SwiftUI
import SwiftData

@main
struct AllMyCrapApp: App {
    @AppStorage("reviewExpirationDays") private var reviewExpirationDays = 30
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    scheduleReviewExpirationCheck()
                }
        }
        // This makes the data models available to the entire app.
        .modelContainer(for: [Location.self, Item.self, Tag.self, ReviewHistory.self])
    }
    
    private func scheduleReviewExpirationCheck() {
        // Check for expired reviews on app launch and every hour
        Task {
            await checkExpiredReviews()
            
            // Schedule periodic checks
            Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
                Task {
                    await checkExpiredReviews()
                }
            }
        }
    }
    
    @MainActor
    private func checkExpiredReviews() async {
        guard reviewExpirationDays > 0 else { return }
        
        // Get the model container
        guard let container = try? ModelContainer(for: Location.self, Item.self, Tag.self, ReviewHistory.self) else { return }
        let context = container.mainContext
        
        let descriptor = FetchDescriptor<Location>(
            predicate: #Predicate<Location> { location in
                location.isReviewed == true
            }
        )
        
        do {
            let reviewedLocations = try context.fetch(descriptor)
            let now = Date()
            let expirationInterval = TimeInterval(reviewExpirationDays * 24 * 60 * 60)
            
            for location in reviewedLocations {
                if let lastReviewedDate = location.lastReviewedDate,
                   now.timeIntervalSince(lastReviewedDate) > expirationInterval {
                    // Mark as unreviewed
                    location.isReviewed = false
                    location.lastReviewedDate = nil
                    
                    // Add history entry
                    let historyEntry = ReviewHistory(
                        action: .markedUnreviewed,
                        isAutomatic: true,
                        location: location
                    )
                    context.insert(historyEntry)
                }
            }
            
            try context.save()
        } catch {
            print("Failed to check expired reviews: \(error)")
        }
    }
}
