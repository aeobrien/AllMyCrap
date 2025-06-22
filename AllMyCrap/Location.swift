import Foundation
import SwiftData

@Model
final class Location {
    @Attribute(.unique) var id: UUID
    var name: String
    var dateAdded: Date

    // A room’s parent == nil
    var parent: Location?

    // Children containers
    @Relationship(deleteRule: .cascade, inverse: \Location.parent)
    var children: [Location] = []

    // Items stored here
    @Relationship(deleteRule: .cascade, inverse: \Item.location)
    var items: [Item] = []

    // MARK: - Convenience

    /// Depth of this node in the hierarchy (rooms are depth 1).
    var depth: Int { (parent?.depth ?? 0) + 1 }

    /// Distance to the deepest descendant (0 if no children).
    func deepestSubtreeDistance() -> Int {
        guard !children.isEmpty else { return 0 }
        return 1 + (children.map { $0.deepestSubtreeDistance() }.max() ?? 0)
    }

    /// IDs of self + all descendants (helps block illegal move targets).
    func collectIDs() -> Set<UUID> {
        children.reduce(into: Set([id])) { partial, child in
            partial.formUnion(child.collectIDs())
        }
    }

    init(name: String, parent: Location? = nil) {
        self.id = UUID()
        self.name = name
        self.dateAdded = Date()
        self.parent = parent
    }
}
