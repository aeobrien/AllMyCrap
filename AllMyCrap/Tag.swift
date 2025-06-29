import Foundation
import SwiftData

@Model
final class Tag {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var name: String
    var color: String // Hex color string
    var items: [Item] = []
    
    init(name: String, color: String = "#007AFF") {
        self.id = UUID()
        self.name = name
        self.color = color
    }
}