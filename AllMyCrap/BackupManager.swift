import Foundation
import SwiftData
import SwiftUI

struct BackupData: Codable {
    let version: Int
    let date: Date
    let locations: [LocationData]
    let items: [ItemData]
    let tags: [TagData]
    let reviewHistory: [ReviewHistoryData]
    let settings: SettingsData?
    
    struct LocationData: Codable {
        let id: UUID
        let name: String
        let dateAdded: Date
        let parentID: UUID?
        let isReviewed: Bool
        let lastReviewedDate: Date?
    }
    
    struct ItemData: Codable {
        let id: UUID
        let name: String
        let dateAdded: Date
        let locationID: UUID?
        let tagIDs: [UUID]
        let plan: String?
        let isBook: Bool?
        let bookTitle: String?
        let bookAuthor: String?
    }
    
    struct TagData: Codable {
        let id: UUID
        let name: String
        let dateAdded: Date?
    }
    
    struct ReviewHistoryData: Codable {
        let id: UUID
        let date: Date
        let action: String
        let isAutomatic: Bool
        let locationID: UUID?
    }
    
    struct SettingsData: Codable {
        let openAIKey: String?
        let bulkItemPrompt: String?
        let reviewDaysThreshold: Int?
        let showReviewReminders: Bool?
    }
}

@MainActor
class BackupManager: ObservableObject {
    @Published var backups: [BackupFile] = []
    @Published var lastBackupDate: Date?
    @Published var isBackingUp = false
    @Published var isRestoring = false
    
    private let iCloudContainerURL: URL? = {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents/Backups")
    }()
    
    struct BackupFile: Identifiable {
        let id = UUID()
        let url: URL
        let date: Date
        let size: Int64
        
        var formattedSize: String {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return formatter.string(fromByteCount: size)
        }
    }
    
    init() {
        loadLastBackupDate()
        Task {
            await MainActor.run {
                setupiCloudDirectory()
                loadBackups()
            }
        }
    }
    
    private func setupiCloudDirectory() {
        guard let url = iCloudContainerURL else { return }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    
    func loadBackups() {
        guard let url = iCloudContainerURL else { return }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey])
            
            backups = files.compactMap { file in
                guard file.pathExtension == "json" else { return nil }
                let attributes = try? FileManager.default.attributesOfItem(atPath: file.path)
                let size = attributes?[.size] as? Int64 ?? 0
                let date = attributes?[.creationDate] as? Date ?? Date()
                return BackupFile(url: file, date: date, size: size)
            }.sorted { $0.date > $1.date }
        } catch {
            print("Failed to load backups: \(error)")
        }
    }
    
    private func loadLastBackupDate() {
        lastBackupDate = UserDefaults.standard.object(forKey: "lastBackupDate") as? Date
    }
    
    private func saveLastBackupDate(_ date: Date) {
        lastBackupDate = date
        UserDefaults.standard.set(date, forKey: "lastBackupDate")
    }
    
    func createBackup(modelContext: ModelContext) async throws {
        isBackingUp = true
        defer { isBackingUp = false }
        
        // Fetch all data
        let locations = try modelContext.fetch(FetchDescriptor<Location>())
        let items = try modelContext.fetch(FetchDescriptor<Item>())
        let tags = try modelContext.fetch(FetchDescriptor<Tag>())
        let reviewHistory = try modelContext.fetch(FetchDescriptor<ReviewHistory>())
        
        // Get settings from UserDefaults
        let settings = BackupData.SettingsData(
            openAIKey: UserDefaults.standard.string(forKey: "openAIKey"),
            bulkItemPrompt: UserDefaults.standard.string(forKey: "bulkItemPrompt"),
            reviewDaysThreshold: UserDefaults.standard.object(forKey: "reviewDaysThreshold") as? Int,
            showReviewReminders: UserDefaults.standard.object(forKey: "showReviewReminders") as? Bool
        )
        
        // Convert to backup format
        let backupData = BackupData(
            version: 1,
            date: Date(),
            locations: locations.map { location in
                BackupData.LocationData(
                    id: location.id,
                    name: location.name,
                    dateAdded: location.dateAdded,
                    parentID: location.parent?.id,
                    isReviewed: location.isReviewed,
                    lastReviewedDate: location.lastReviewedDate
                )
            },
            items: items.map { item in
                BackupData.ItemData(
                    id: item.id,
                    name: item.name,
                    dateAdded: item.dateAdded,
                    locationID: item.location?.id,
                    tagIDs: item.tags.map { $0.id },
                    plan: item.plan?.rawValue,
                    isBook: item.isBook,
                    bookTitle: item.bookTitle,
                    bookAuthor: item.bookAuthor
                )
            },
            tags: tags.map { tag in
                BackupData.TagData(
                    id: tag.id,
                    name: tag.name,
                    dateAdded: tag.dateAdded ?? Date()
                )
            },
            reviewHistory: reviewHistory.map { history in
                BackupData.ReviewHistoryData(
                    id: history.id,
                    date: history.date,
                    action: history.action.rawValue,
                    isAutomatic: history.isAutomatic,
                    locationID: history.location?.id
                )
            },
            settings: settings
        )
        
        // Save to iCloud
        guard let url = iCloudContainerURL else {
            throw BackupError.iCloudNotAvailable
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "backup_\(formatter.string(from: Date())).json"
        let fileURL = url.appendingPathComponent(filename)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backupData)
        
        try data.write(to: fileURL)
        
        saveLastBackupDate(Date())
        loadBackups()
    }
    
    func restoreBackup(from url: URL, modelContext: ModelContext) async throws {
        isRestoring = true
        defer { isRestoring = false }
        
        // Load backup data
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backupData = try decoder.decode(BackupData.self, from: data)
        
        // Clear existing data
        let existingLocations = try modelContext.fetch(FetchDescriptor<Location>())
        let existingItems = try modelContext.fetch(FetchDescriptor<Item>())
        let existingTags = try modelContext.fetch(FetchDescriptor<Tag>())
        let existingHistory = try modelContext.fetch(FetchDescriptor<ReviewHistory>())
        
        existingItems.forEach { modelContext.delete($0) }
        existingLocations.forEach { modelContext.delete($0) }
        existingTags.forEach { modelContext.delete($0) }
        existingHistory.forEach { modelContext.delete($0) }
        
        try modelContext.save()
        
        // Restore tags first
        var tagMap: [UUID: Tag] = [:]
        for tagData in backupData.tags {
            let tag = Tag(name: tagData.name)
            tag.id = tagData.id
            tag.dateAdded = tagData.dateAdded
            modelContext.insert(tag)
            tagMap[tagData.id] = tag
        }
        
        // Restore locations (parents first)
        var locationMap: [UUID: Location] = [:]
        
        // First pass: create all locations without parent relationships
        for locationData in backupData.locations {
            let location = Location(name: locationData.name)
            location.id = locationData.id
            location.dateAdded = locationData.dateAdded
            location.isReviewed = locationData.isReviewed
            location.lastReviewedDate = locationData.lastReviewedDate
            modelContext.insert(location)
            locationMap[locationData.id] = location
        }
        
        // Second pass: set parent relationships
        for locationData in backupData.locations {
            if let parentID = locationData.parentID,
               let location = locationMap[locationData.id],
               let parent = locationMap[parentID] {
                location.parent = parent
            }
        }
        
        // Restore items
        for itemData in backupData.items {
            let item = Item(name: itemData.name)
            item.id = itemData.id
            item.dateAdded = itemData.dateAdded
            item.isBook = itemData.isBook ?? false
            item.bookTitle = itemData.bookTitle
            item.bookAuthor = itemData.bookAuthor
            
            if let locationID = itemData.locationID,
               let location = locationMap[locationID] {
                item.location = location
            }
            
            item.tags = itemData.tagIDs.compactMap { tagMap[$0] }
            
            if let planString = itemData.plan {
                item.plan = ItemPlan(rawValue: planString)
            }
            
            modelContext.insert(item)
        }
        
        // Restore review history
        for historyData in backupData.reviewHistory {
            if let action = ReviewAction(rawValue: historyData.action) {
                let history = ReviewHistory(
                    action: action,
                    isAutomatic: historyData.isAutomatic,
                    location: historyData.locationID.flatMap { locationMap[$0] }
                )
                history.id = historyData.id
                history.date = historyData.date
                modelContext.insert(history)
            }
        }
        
        // Restore settings if available
        if let settings = backupData.settings {
            if let openAIKey = settings.openAIKey {
                UserDefaults.standard.set(openAIKey, forKey: "openAIKey")
            }
            if let bulkItemPrompt = settings.bulkItemPrompt {
                UserDefaults.standard.set(bulkItemPrompt, forKey: "bulkItemPrompt")
            }
            if let reviewDaysThreshold = settings.reviewDaysThreshold {
                UserDefaults.standard.set(reviewDaysThreshold, forKey: "reviewDaysThreshold")
            }
            if let showReviewReminders = settings.showReviewReminders {
                UserDefaults.standard.set(showReviewReminders, forKey: "showReviewReminders")
            }
        }
        
        try modelContext.save()
    }
    
    func deleteBackup(_ backup: BackupFile) throws {
        try FileManager.default.removeItem(at: backup.url)
        loadBackups()
    }
    
    func shouldAutoBackup() -> Bool {
        guard let lastBackup = lastBackupDate else { return true }
        return Date().timeIntervalSince(lastBackup) > 3600 // 1 hour
    }
    
    enum BackupError: LocalizedError {
        case iCloudNotAvailable
        
        var errorDescription: String? {
            switch self {
            case .iCloudNotAvailable:
                return "iCloud is not available. Please check your iCloud settings."
            }
        }
    }
}