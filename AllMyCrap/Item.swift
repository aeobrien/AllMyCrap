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
    
    // Relationship to the location it's stored in
    var location: Location?
    
    init(name: String, location: Location? = nil) {
        self.id = UUID()
        self.name = name
        self.dateAdded = Date()
        self.location = location
        self.tags = []
        self.plan = nil
    }
}
