import Foundation
import SwiftData

@Model
final class Item {
    @Attribute(.unique) var id: UUID
    var name: String
    var dateAdded: Date
    var tags: [Tag] = []
    
    // Relationship to the location it's stored in
    var location: Location?
    
    init(name: String, location: Location? = nil) {
        self.id = UUID()
        self.name = name
        self.dateAdded = Date()
        self.location = location
        self.tags = []
    }
}
