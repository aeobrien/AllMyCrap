import Foundation
import SwiftData

@Model
final class ReviewHistory {
    @Attribute(.unique) var id: UUID
    var date: Date
    var action: ReviewAction
    var isAutomatic: Bool
    
    // Relationship to the location
    var location: Location?
    
    init(action: ReviewAction, isAutomatic: Bool = false, location: Location? = nil) {
        self.id = UUID()
        self.date = Date()
        self.action = action
        self.isAutomatic = isAutomatic
        self.location = location
    }
}

enum ReviewAction: String, Codable {
    case markedReviewed = "Marked as Reviewed"
    case markedUnreviewed = "Marked as Unreviewed"
}