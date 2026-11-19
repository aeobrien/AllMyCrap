import Foundation
import SwiftData

@main struct MutationTests {
    @MainActor static func main() throws {
        let url = URL(fileURLWithPath: ProcessInfo.processInfo.environment["INVENTORY_AUDIT_STORE"]!)
        let schema = Schema([Location.self, Item.self, Tag.self, ReviewHistory.self, DuplicateExclusion.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration("MutationTests", schema: schema, url: url, cloudKitDatabase: .none)])
        let c = ModelContext(container); c.autosaveEnabled = false
        var checks = 0
        func expectFailure(_ body: () throws -> Void) {
            do { try body(); fatalError("Expected rejection") } catch { checks += 1 }
        }
        let root = Location(name: "Same"), other = Location(name: "Same")
        let child = Location(name: "Box", parent: root)
        let item = Item(name: "Kept", location: child)
        let doomed = Item(name: "Removed", location: child)
        let survivor = Item(name: "Unrelated", location: other)
        let history = ReviewHistory(action: .markedReviewed, location: child)
        let exclusion = DuplicateExclusion(itemID1: doomed.id, itemID2: survivor.id)
        let unrelated = DuplicateExclusion(itemID1: item.id, itemID2: survivor.id)
        for l in [root, other, child] { c.insert(l) }
        for i in [item, doomed, survivor] { c.insert(i) }
        c.insert(history); c.insert(exclusion); c.insert(unrelated); try c.save()
        let service = InventoryMutations(context: c)
        try service.moveItem(id: item.id, destinationID: other.id)
        precondition(item.location?.id == other.id); checks += 1
        expectFailure { try service.moveLocation(id: root.id, destinationID: root.id) }
        expectFailure { try service.moveLocation(id: root.id, destinationID: child.id) }
        expectFailure { try service.moveItem(id: UUID(), destinationID: other.id) }
        precondition(root.parent == nil && child.parent?.id == root.id); checks += 1
        let first = try service.previewDeletion(locationIDs: [root.id, child.id], itemIDs: [])
        precondition(first.locationIDs.count == 2 && first.itemIDs == [doomed.id] && first.historyIDs == [history.id] && first.exclusionIDs == [exclusion.id]); checks += 1
        let reordered = try service.previewDeletion(locationIDs: [child.id, root.id], itemIDs: [])
        precondition(first == reordered); checks += 1
        expectFailure { try service.applyDeletion(first, approved: false) }
        let extra = Item(name: "New affected", location: child); c.insert(extra); try c.save()
        expectFailure { try service.applyDeletion(first, approved: true) }
        let beforeExternalEdit = try service.previewDeletion(locationIDs: [root.id], itemIDs: [])
        let external = ModelContext(container)
        let externalDoomed = try external.fetch(FetchDescriptor<Item>()).first { $0.id == doomed.id }!
        externalDoomed.name = "Changed in another context"; try external.save()
        expectFailure { try service.applyDeletion(beforeExternalEdit, approved: true) }
        let current = try service.previewDeletion(locationIDs: [root.id], itemIDs: [])
        try service.applyDeletion(current, approved: true)
        let reader = ModelContext(container)
        let itemsAfter = try reader.fetch(FetchDescriptor<Item>())
        precondition(Set(itemsAfter.map(\.id)) == Set([item.id, survivor.id])); checks += 1
        let historyAfter = try reader.fetch(FetchDescriptor<ReviewHistory>())
        precondition(historyAfter.isEmpty); checks += 1
        let exclusionsAfter = try reader.fetch(FetchDescriptor<DuplicateExclusion>())
        precondition(exclusionsAfter.map(\.id) == [unrelated.id]); checks += 1
        expectFailure { try service.applyDeletion(current, approved: true) }
        var parent = other
        for n in 2...15 { let l = Location(name: "Level \(n)", parent: parent); c.insert(l); parent = l }
        let movable = Location(name: "Movable"); c.insert(movable); try c.save()
        expectFailure { try service.moveLocation(id: movable.id, destinationID: parent.id) }
        try service.moveLocation(id: movable.id, destinationID: parent.parent!.id)
        precondition(movable.depth == 15); checks += 1
        survivor.name = "Pending unrelated edit"
        expectFailure { try service.moveItem(id: item.id, destinationID: parent.id) }
        precondition(survivor.name == "Pending unrelated edit" && c.hasChanges); checks += 1
        c.rollback()
        let readOnly = try ModelContainer(for: schema, configurations: [ModelConfiguration("ReadOnlyTests", schema: schema, url: url, allowsSave: false, cloudKitDatabase: .none)])
        let readOnlyContext = ModelContext(readOnly)
        let readonlyService = InventoryMutations(context: readOnlyContext)
        expectFailure { try readonlyService.moveItem(id: item.id, destinationID: parent.id) }
        let afterFailure = try ModelContext(container).fetch(FetchDescriptor<Item>()).first { $0.id == item.id }!
        precondition(afterFailure.location?.id == other.id); checks += 1
        other.parent = parent; try c.save()
        expectFailure { _ = try service.previewDeletion(locationIDs: [other.id], itemIDs: []) }
        other.parent = nil; try c.save()
        print("AUDIT_RESULT=" + String(data: try JSONSerialization.data(withJSONObject: ["checks": checks, "passed": true]), encoding: .utf8)!)
    }
}
