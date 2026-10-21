import Foundation
import SwiftData

@Model
final class DuplicateExclusion {
    @Attribute(.unique) var id: UUID
    var itemID1: UUID   // Canonical ordering: smaller UUID string first
    var itemID2: UUID
    var dateCreated: Date

    init(itemID1: UUID, itemID2: UUID) {
        self.id = UUID()
        self.dateCreated = Date()

        // Canonical ordering: smaller UUID string goes first
        if itemID1.uuidString < itemID2.uuidString {
            self.itemID1 = itemID1
            self.itemID2 = itemID2
        } else {
            self.itemID1 = itemID2
            self.itemID2 = itemID1
        }
    }

    /// Check if this exclusion covers the given pair (order-independent).
    func covers(_ a: UUID, _ b: UUID) -> Bool {
        let canonA = a.uuidString < b.uuidString ? a : b
        let canonB = a.uuidString < b.uuidString ? b : a
        return itemID1 == canonA && itemID2 == canonB
    }
}
