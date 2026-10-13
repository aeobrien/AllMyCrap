import Foundation
import SwiftData
import CryptoKit

/// Read-only, main-actor adapter for an already selected app-owned container.
/// It never selects a path, creates a container, or saves/resets the caller.
@MainActor
final class InventoryReadAdapter {
    enum Failure: Error, Equatable {
        case pendingEdits, invalidQuery, notFound, invalidCursor, staleCursor
        case rowLimit, fieldLimit, projectionLimit, responseLimit, invalidData, unsupportedSchema
    }
    enum Kind: String, Codable { case items, locations, tags }
    enum ArchiveScope: String, Codable { case active, archived, all }
    enum Plan: String, Codable {
        case keep = "Keep", throwAway = "Throw Away", sell = "Sell", charity = "Charity", move = "Move", fix = "Fix"
    }
    struct PathEntry: Codable { let id: UUID; let name: String }
    struct ItemValue: Codable {
        let id: UUID; let name: String; let dateAdded: Date; let locationID: UUID?
        let tagIDs: [UUID]; let plan: Plan?; let moveDestination: String?
        let isBook: Bool; let bookTitle: String?; let bookAuthor: String?; let displayName: String
        let isArchived: Bool; let archivedDate: Date?; let archivedPlan: Plan?
    }
    struct LocationValue: Codable {
        let id: UUID; let name: String; let dateAdded: Date; let parentID: UUID?
        let childIDs: [UUID]; let itemIDs: [UUID]; let isReviewed: Bool; let lastReviewedDate: Date?
        let path: [PathEntry]
    }
    struct TagValue: Codable {
        let id: UUID; let name: String; let color: String; let dateAdded: Date?; let itemIDs: [UUID]
    }
    struct HistoryValue: Codable {
        let id: UUID; let date: Date; let action: ReviewAction; let isAutomatic: Bool; let locationID: UUID?
    }
    struct ExclusionValue: Codable {
        let id: UUID; let itemID1: UUID; let itemID2: UUID; let dateCreated: Date
    }
    enum Record: Codable {
        case item(ItemValue), location(LocationValue), tag(TagValue)
        var id: UUID {
            switch self { case .item(let v): return v.id; case .location(let v): return v.id; case .tag(let v): return v.id }
        }
    }
    struct Counts: Codable {
        let items: Int; let locations: Int; let tags: Int; let histories: Int; let exclusions: Int
        let activeItems: Int; let archivedItems: Int
    }
    struct Status: Codable {
        let scope: UUID; let revision: String; let counts: Counts
        let complete: Bool; let transactionalSnapshot: Bool
    }
    struct Page: Codable {
        let scope: UUID; let revision: String; let records: [Record]; let total: Int
        let complete: Bool; let next: String?
    }
    struct Detail: Codable {
        let scope: UUID; let revision: String; let record: Record
        let histories: [HistoryValue]; let exclusions: [ExclusionValue]
    }
    private struct Projection: Codable {
        let items: [ItemValue]; let locations: [LocationValue]; let tags: [TagValue]
        let histories: [HistoryValue]; let exclusions: [ExclusionValue]
        func records(_ kind: Kind, _ archive: ArchiveScope) -> [Record] {
            switch kind {
            case .items: return items.filter { archive == .all || $0.isArchived == (archive == .archived) }.map(Record.item)
            case .locations: return locations.map(Record.location)
            case .tags: return tags.map(Record.tag)
            }
        }
    }
    private struct Cursor: Codable {
        let version: Int; let scope: UUID; let revision: String; let kind: Kind
        let archive: ArchiveScope; let size: Int; let last: UUID
    }
    private let context: ModelContext
    private let scope = UUID()
    private let cursorKey = SymmetricKey(size: .bits256)
    static let maximumRows = 5000
    static let maximumFieldBytes = 16 * 1024
    static let maximumProjectionBytes = 4 * 1024 * 1024
    static let maximumResponseBytes = 1024 * 1024

    init(context: ModelContext) { self.context = context }

    private func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(value)
    }
    private func bounded<T: Encodable>(_ value: T) throws -> T {
        guard try encoded(value).count <= Self.maximumResponseBytes else { throw Failure.responseLimit }
        return value
    }
    private func rows<T: PersistentModel>(_ type: T.Type, _ reader: ModelContext) throws -> [T] {
        var descriptor = FetchDescriptor<T>(); descriptor.fetchLimit = Self.maximumRows + 1
        let values = try reader.fetch(descriptor)
        guard values.count <= Self.maximumRows else { throw Failure.rowLimit }
        return values
    }
    private func text(_ values: String?...) throws {
        guard values.allSatisfy({ ($0?.utf8.count ?? 0) <= Self.maximumFieldBytes }) else { throw Failure.fieldLimit }
    }
    private func dates(_ values: Date?...) throws {
        guard values.allSatisfy({ $0?.timeIntervalSince1970.isFinite ?? true }) else { throw Failure.invalidData }
    }
    private func ids(_ values: [UUID]) throws -> [UUID] {
        guard values.count <= Self.maximumRows, Set(values).count == values.count else { throw Failure.invalidData }
        return values.sorted { $0.uuidString < $1.uuidString }
    }
    private func index<T>(_ values: [T], _ id: (T) -> UUID) throws -> [UUID: T] {
        var result: [UUID: T] = [:]
        for value in values { guard result.updateValue(value, forKey: id(value)) == nil else { throw Failure.invalidData } }
        return result
    }
    private func charge<T: Encodable>(_ value: T, _ used: inout Int) throws {
        used += try encoded(value).count
        guard used <= Self.maximumProjectionBytes else { throw Failure.projectionLimit }
    }
    private func projection() throws -> (Projection, String) {
        guard !context.hasChanges else { throw Failure.pendingEdits }
        let names = Set(context.container.schema.entities.map { $0.name.split(separator: ".").last.map(String.init) ?? $0.name })
        guard Set(["Location", "Item", "Tag", "ReviewHistory", "DuplicateExclusion"]).isSubset(of: names) else { throw Failure.unsupportedSchema }
        let reader = ModelContext(context.container); reader.autosaveEnabled = false
        // Independent fresh fetches are an observed projection, not a distributed snapshot.
        let locations = try rows(Location.self, reader), items = try rows(Item.self, reader), tags = try rows(Tag.self, reader)
        let histories = try rows(ReviewHistory.self, reader), exclusions = try rows(DuplicateExclusion.self, reader)
        let lm = try index(locations, { $0.id }), im = try index(items, { $0.id }), tm = try index(tags, { $0.id })
        _ = try index(histories, { $0.id }); _ = try index(exclusions, { $0.id })
        var lv: [LocationValue] = [], iv: [ItemValue] = [], tv: [TagValue] = []
        var hv: [HistoryValue] = [], ev: [ExclusionValue] = []
        var encodedBytes = 0
        for row in locations {
            try text(row.name); try dates(row.dateAdded, row.lastReviewedDate)
            var path: [PathEntry] = [], seen: Set<UUID> = [], current: Location? = row
            while let node = current {
                guard lm[node.id] != nil, seen.insert(node.id).inserted, path.count < 15 else { throw Failure.invalidData }
                try text(node.name); path.append(PathEntry(id: node.id, name: node.name)); current = node.parent
            }
            let children = try ids(row.children.map(\.id)), contained = try ids(row.items.map(\.id))
            guard children.allSatisfy({ lm[$0]?.parent?.id == row.id }), contained.allSatisfy({ im[$0]?.location?.id == row.id }) else { throw Failure.invalidData }
            if let parent = row.parent { guard lm[parent.id]?.children.contains(where: { $0.id == row.id }) == true else { throw Failure.invalidData } }
            lv.append(LocationValue(id: row.id, name: row.name, dateAdded: row.dateAdded, parentID: row.parent?.id, childIDs: children, itemIDs: contained, isReviewed: row.isReviewed, lastReviewedDate: row.lastReviewedDate, path: path.reversed()))
            try charge(lv.last!, &encodedBytes)
        }
        for row in items {
            try text(row.name, row.moveDestination, row.bookTitle, row.bookAuthor, row.displayName); try dates(row.dateAdded, row.archivedDate)
            if let location = row.location { guard lm[location.id]?.items.contains(where: { $0.id == row.id }) == true else { throw Failure.invalidData } }
            let tagIDs = try ids(row.tags.map(\.id))
            guard tagIDs.allSatisfy({ tm[$0] != nil }) else { throw Failure.invalidData }
            iv.append(ItemValue(id: row.id, name: row.name, dateAdded: row.dateAdded, locationID: row.location?.id, tagIDs: tagIDs, plan: row.plan.flatMap { Plan(rawValue: $0.rawValue) }, moveDestination: row.moveDestination, isBook: row.isBook, bookTitle: row.bookTitle, bookAuthor: row.bookAuthor, displayName: row.displayName, isArchived: row.isArchived, archivedDate: row.archivedDate, archivedPlan: row.archivedPlan.flatMap { Plan(rawValue: $0.rawValue) }))
            try charge(iv.last!, &encodedBytes)
        }
        for row in tags {
            try text(row.name, row.color); try dates(row.dateAdded)
            let itemIDs = try ids(row.items.map(\.id))
            guard itemIDs.allSatisfy({ im[$0] != nil }) else { throw Failure.invalidData }
            tv.append(TagValue(id: row.id, name: row.name, color: row.color, dateAdded: row.dateAdded, itemIDs: itemIDs))
            try charge(tv.last!, &encodedBytes)
        }
        for row in histories {
            try dates(row.date)
            if let location = row.location { guard lm[location.id] != nil else { throw Failure.invalidData } }
            hv.append(HistoryValue(id: row.id, date: row.date, action: row.action, isAutomatic: row.isAutomatic, locationID: row.location?.id))
            try charge(hv.last!, &encodedBytes)
        }
        for row in exclusions {
            try dates(row.dateCreated)
            guard im[row.itemID1] != nil, im[row.itemID2] != nil else { throw Failure.invalidData }
            ev.append(ExclusionValue(id: row.id, itemID1: row.itemID1, itemID2: row.itemID2, dateCreated: row.dateCreated))
            try charge(ev.last!, &encodedBytes)
        }
        let value = Projection(items: iv.sorted { $0.id.uuidString < $1.id.uuidString }, locations: lv.sorted { $0.id.uuidString < $1.id.uuidString }, tags: tv.sorted { $0.id.uuidString < $1.id.uuidString }, histories: hv.sorted { $0.id.uuidString < $1.id.uuidString }, exclusions: ev.sorted { $0.id.uuidString < $1.id.uuidString })
        let data = try encoded(value)
        guard data.count <= Self.maximumProjectionBytes else { throw Failure.projectionLimit }
        return (value, SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())
    }
    private func token(_ cursor: Cursor) throws -> String {
        let data = try encoded(cursor)
        let signature = Data(HMAC<SHA256>.authenticationCode(for: data, using: cursorKey))
        return data.base64EncodedString() + "." + signature.base64EncodedString()
    }
    private func decode(_ raw: String) throws -> Cursor {
        guard raw.utf8.count <= 2048 else { throw Failure.invalidCursor }
        let parts = raw.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2, let data = Data(base64Encoded: String(parts[0])), let signature = Data(base64Encoded: String(parts[1])), HMAC<SHA256>.isValidAuthenticationCode(signature, authenticating: data, using: cursorKey) else { throw Failure.invalidCursor }
        do { return try JSONDecoder().decode(Cursor.self, from: data) } catch { throw Failure.invalidCursor }
    }
    func status() throws -> Status {
        let (p, revision) = try projection(); let archived = p.items.filter(\.isArchived).count
        return try bounded(Status(scope: scope, revision: revision, counts: Counts(items: p.items.count, locations: p.locations.count, tags: p.tags.count, histories: p.histories.count, exclusions: p.exclusions.count, activeItems: p.items.count - archived, archivedItems: archived), complete: true, transactionalSnapshot: false))
    }
    func list(kind: Kind, archive: ArchiveScope, pageSize: Int, cursor: String? = nil) throws -> Page {
        guard (1...100).contains(pageSize), kind == .items || archive == .all else { throw Failure.invalidQuery }
        let decoded = try cursor.map(decode)
        if let c = decoded { guard c.version == 1, c.scope == scope, c.kind == kind, c.archive == archive, c.size == pageSize else { throw Failure.invalidCursor } }
        let (p, revision) = try projection(); let records = p.records(kind, archive)
        var start = 0
        if let c = decoded {
            guard c.revision == revision else { throw Failure.staleCursor }
            guard let previous = records.firstIndex(where: { $0.id == c.last }), previous + 1 < records.count else { throw Failure.invalidCursor }
            start = previous + 1
        }
        let end = min(start + pageSize, records.count), batch = Array(records[start..<end])
        let next = end < records.count ? try token(Cursor(version: 1, scope: scope, revision: revision, kind: kind, archive: archive, size: pageSize, last: batch.last!.id)) : nil
        return try bounded(Page(scope: scope, revision: revision, records: batch, total: records.count, complete: next == nil, next: next))
    }
    func show(kind: Kind, id: UUID) throws -> Detail {
        let (p, revision) = try projection()
        guard let record = p.records(kind, .all).first(where: { $0.id == id }) else { throw Failure.notFound }
        let relatedItems: Set<UUID>
        if case .location(let location) = record { relatedItems = Set(location.itemIDs) }
        else if case .item = record { relatedItems = [id] }
        else { relatedItems = [] }
        return try bounded(Detail(scope: scope, revision: revision, record: record, histories: kind == .locations ? p.histories.filter { $0.locationID == id } : [], exclusions: p.exclusions.filter { relatedItems.contains($0.itemID1) || relatedItems.contains($0.itemID2) }))
    }
}
