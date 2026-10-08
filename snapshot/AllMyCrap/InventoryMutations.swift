import Foundation
import SwiftData
import CryptoKit

/// Synchronous main-actor boundary for the app's local store. Callers must first
/// finish unrelated edits; this service never saves or rolls them back for them.
@MainActor
final class InventoryMutations {
    enum Failure: Error, LocalizedError {
        case pendingEdits, missingTarget, invalidGraph, invalidMove, depthLimit
        case approvalRequired, stalePreview, verificationFailed
        var errorDescription: String? {
            switch self {
            case .pendingEdits: return "Finish saving your other changes before moving or removing records."
            case .missingTarget: return "A selected record no longer exists. Refresh the selection."
            case .invalidGraph: return "The location hierarchy is inconsistent. No records were changed."
            case .invalidMove: return "A location cannot be moved into itself or one of its children."
            case .depthLimit: return "That move would exceed 15 nested location levels."
            case .approvalRequired: return "Approval of the complete removal is required."
            case .stalePreview: return "The inventory changed. Review a new removal preview before approving."
            case .verificationFailed: return "The saved result could not be verified. Check current records before retrying."
            }
        }
    }

    struct RemovalPreview: Equatable {
        let requestedLocationIDs: [UUID]
        let requestedItemIDs: [UUID]
        let locationIDs: [UUID]
        let itemIDs: [UUID]
        let historyIDs: [UUID]
        let exclusionIDs: [UUID]
        /// Display text is included so approval can name every affected record.
        let descriptions: [String]
        fileprivate let fingerprint: String
    }

    private let context: ModelContext
    init(context: ModelContext) { self.context = context }

    private func clean() throws {
        guard !context.hasChanges else { throw Failure.pendingEdits }
    }
    private func ordered(_ ids: Set<UUID>) -> [UUID] {
        ids.sorted { $0.uuidString < $1.uuidString }
    }
    private func graph() throws -> [UUID: Location] {
        let rows = try context.fetch(FetchDescriptor<Location>())
        var result: [UUID: Location] = [:]
        for row in rows {
            guard result.updateValue(row, forKey: row.id) == nil else { throw Failure.invalidGraph }
        }
        for row in rows {
            var seen: Set<UUID> = []
            var current: Location? = row
            while let node = current {
                guard result[node.id] != nil, seen.insert(node.id).inserted else { throw Failure.invalidGraph }
                current = node.parent
            }
            if let parent = row.parent, !parent.children.contains(where: { $0.id == row.id }) {
                throw Failure.invalidGraph
            }
            for child in row.children {
                guard result[child.id] != nil, child.parent?.id == row.id else { throw Failure.invalidGraph }
            }
        }
        return result
    }

    func moveItem(id: UUID, destinationID: UUID) throws {
        try clean()
        let locations = try graph()
        guard let destination = locations[destinationID],
              let item = try context.fetch(FetchDescriptor<Item>()).first(where: { $0.id == id }) else {
            throw Failure.missingTarget
        }
        item.location = destination
        do { try context.save() } catch { context.rollback(); throw error }
        let saved = try ModelContext(context.container).fetch(FetchDescriptor<Item>()).first { $0.id == id }
        guard saved?.location?.id == destinationID else { throw Failure.verificationFailed }
    }

    func moveLocation(id: UUID, destinationID: UUID) throws {
        try clean()
        let locations = try graph()
        guard let source = locations[id], let destination = locations[destinationID] else { throw Failure.missingTarget }
        var ancestor: Location? = destination
        var destinationDepth = 0
        while let node = ancestor {
            guard node.id != id else { throw Failure.invalidMove }
            destinationDepth += 1; ancestor = node.parent
        }
        var height = 0
        var pending: [(Location, Int)] = [(source, 0)]
        while let (node, distance) = pending.popLast() {
            height = max(height, distance)
            pending += node.children.map { ($0, distance + 1) }
        }
        guard destinationDepth + 1 + height <= 15 else { throw Failure.depthLimit }
        source.parent = destination
        do { try context.save() } catch { context.rollback(); throw error }
        let saved = try ModelContext(context.container).fetch(FetchDescriptor<Location>()).first { $0.id == id }
        guard saved?.parent?.id == destinationID else { throw Failure.verificationFailed }
    }

    func previewDeletion(locationIDs: [UUID], itemIDs: [UUID]) throws -> RemovalPreview {
        try clean()
        let locations = try graph()
        let allItems = try context.fetch(FetchDescriptor<Item>())
        let allHistory = try context.fetch(FetchDescriptor<ReviewHistory>())
        let allExclusions = try context.fetch(FetchDescriptor<DuplicateExclusion>())
        let requestedLocations = Set(locationIDs), requestedItems = Set(itemIDs)
        guard !requestedLocations.isEmpty || !requestedItems.isEmpty,
              requestedLocations.allSatisfy({ locations[$0] != nil }),
              requestedItems.isSubset(of: Set(allItems.map(\.id))) else { throw Failure.missingTarget }
        var affectedLocations = requestedLocations
        var queue = requestedLocations.compactMap { locations[$0] }
        while let current = queue.popLast() {
            for child in current.children where affectedLocations.insert(child.id).inserted { queue.append(child) }
        }
        let items = allItems.filter { requestedItems.contains($0.id) || $0.location.map { affectedLocations.contains($0.id) } == true }
        let affectedItems = Set(items.map(\.id))
        let history = allHistory.filter { $0.location.map { affectedLocations.contains($0.id) } == true }
        let exclusions = allExclusions.filter { affectedItems.contains($0.itemID1) || affectedItems.contains($0.itemID2) }
        let descriptions = (affectedLocations.compactMap { locations[$0].map { "Location \($0.id): \($0.name)" } }
            + items.map { "Item \($0.id): \($0.displayName)" }
            + history.map { "Review \($0.id): \($0.action.rawValue)" }
            + exclusions.map { "Duplicate exclusion \($0.id): \($0.itemID1), \($0.itemID2)" }).sorted()
        // Conservative freshness: all inventory graph/member metadata is bound.
        // An unrelated edit can require a fresh preview; no changed effect is
        // silently accepted. No settings or backup credentials enter this token.
        var rows: [[String]] = locations.values.map { ["location", $0.id.uuidString, $0.name, $0.parent?.id.uuidString ?? "", String($0.isReviewed), String(describing: $0.lastReviewedDate)] }
        for item in allItems {
            var row = ["item", item.id.uuidString, item.name, item.location?.id.uuidString ?? ""]
            row += [item.tags.map { $0.id.uuidString }.sorted().joined(separator: ","), item.plan?.rawValue ?? "", item.moveDestination ?? ""]
            row += [String(item.isArchived), String(describing: item.archivedDate), item.archivedPlan?.rawValue ?? ""]
            row += [String(item.isBook), item.bookTitle ?? "", item.bookAuthor ?? ""]
            rows.append(row)
        }
        rows += allHistory.map { ["history", $0.id.uuidString, $0.location?.id.uuidString ?? "", $0.action.rawValue, String($0.isAutomatic), String($0.date.timeIntervalSince1970)] }
        rows += allExclusions.map { ["exclusion", $0.id.uuidString, $0.itemID1.uuidString, $0.itemID2.uuidString] }
        rows.sort { $0.lexicographicallyPrecedes($1) }
        let fingerprint = SHA256.hash(data: try JSONEncoder().encode(rows)).map { String(format: "%02x", $0) }.joined()
        return RemovalPreview(requestedLocationIDs: ordered(requestedLocations), requestedItemIDs: ordered(requestedItems),
            locationIDs: ordered(affectedLocations), itemIDs: ordered(affectedItems), historyIDs: ordered(Set(history.map(\.id))),
            exclusionIDs: ordered(Set(exclusions.map(\.id))), descriptions: descriptions, fingerprint: fingerprint)
    }

    /// `approved` is supplied only by a caller that obtained approval of this
    /// exact preview. This library does not authenticate a user or grant consent.
    func applyDeletion(_ preview: RemovalPreview, approved: Bool) throws {
        guard approved else { throw Failure.approvalRequired }
        let current = try previewDeletion(locationIDs: preview.requestedLocationIDs, itemIDs: preview.requestedItemIDs)
        guard current == preview else { throw Failure.stalePreview }
        let locations = try context.fetch(FetchDescriptor<Location>())
        let items = try context.fetch(FetchDescriptor<Item>())
        let exclusions = try context.fetch(FetchDescriptor<DuplicateExclusion>())
        for row in exclusions where preview.exclusionIDs.contains(row.id) { context.delete(row) }
        // Explicit item deletion also covers requested items outside a location
        // subtree. Cascades remove descendants/history from selected roots.
        for row in items where preview.itemIDs.contains(row.id) { context.delete(row) }
        for row in locations where preview.requestedLocationIDs.contains(row.id)
            && !(row.parent.map { preview.locationIDs.contains($0.id) } ?? false) { context.delete(row) }
        do { try context.save() } catch { context.rollback(); throw error }
        let reader = ModelContext(context.container)
        guard Set(try reader.fetch(FetchDescriptor<Location>()).map(\.id)).isDisjoint(with: preview.locationIDs),
              Set(try reader.fetch(FetchDescriptor<Item>()).map(\.id)).isDisjoint(with: preview.itemIDs),
              Set(try reader.fetch(FetchDescriptor<ReviewHistory>()).map(\.id)).isDisjoint(with: preview.historyIDs),
              Set(try reader.fetch(FetchDescriptor<DuplicateExclusion>()).map(\.id)).isDisjoint(with: preview.exclusionIDs) else {
            throw Failure.verificationFailed
        }
    }
}
