import Foundation
import SwiftData

enum ItemPlan: String, CaseIterable, Codable {
    case keep = "Keep"
    case throwAway = "Throw Away"
    case sell = "Sell"
    case charity = "Charity"
    case move = "Move"
}

@Model
final class Item {
    @Attribute(.unique) var id: UUID
    var name: String
    var dateAdded: Date
    var tags: [Tag] = []
    var plan: ItemPlan?
    
    // Book-specific fields (nil for non-book items)
    var isBook: Bool = false
    var bookTitle: String?
    var bookAuthor: String?
    
    // Relationship to the location it's stored in
    var location: Location?
    
    // Computed property for display name
    var displayName: String {
        if isBook, let title = bookTitle, let author = bookAuthor {
            return "\(title) by \(author)"
        }
        return name
    }
    
    init(name: String, location: Location? = nil) {
        self.id = UUID()
        self.name = name
        self.dateAdded = Date()
        self.location = location
        self.tags = []
        self.plan = nil
        self.isBook = false
    }
    
    // Convenience initializer for books
    init(title: String, author: String, location: Location? = nil) {
        self.id = UUID()
        self.name = "\(title) by \(author)" // Store as name for compatibility
        self.bookTitle = title
        self.bookAuthor = author
        self.isBook = true
        self.dateAdded = Date()
        self.location = location
        self.tags = []
        self.plan = nil
    }
}
