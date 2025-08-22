import SwiftUI
import SwiftData

@main
struct AllMyCrapApp: App {
    @AppStorage("reviewExpirationDays") private var reviewExpirationDays = 30
    @StateObject private var backupManager = BackupManager()
    
    let container: ModelContainer = {
        let schema = Schema([
            Location.self,
            Item.self,
            Tag.self,
            ReviewHistory.self
        ])
        
        // Create configuration without CloudKit sync
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none  // Disable CloudKit sync
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(backupManager)
                .onAppear {
                    scheduleReviewExpirationCheck()
                    performAutoBackup()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    performAutoBackup()
                }
        }
        // This makes the data models available to the entire app.
        .modelContainer(container)
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
    
    private func performAutoBackup() {
        guard backupManager.shouldAutoBackup() else { return }
        
        Task {
            let context = container.mainContext
            
            do {
                try await backupManager.createBackup(modelContext: context)
            } catch {
                print("Auto backup failed: \(error)")
            }
        }
    }
}
