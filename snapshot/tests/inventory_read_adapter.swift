import Foundation
import SwiftData

@main struct ReadTests {
    @MainActor static func main() throws {
        let url = URL(fileURLWithPath: ProcessInfo.processInfo.environment["INVENTORY_READ_STORE"]!)
        let schema = Schema([Location.self, Item.self, Tag.self, ReviewHistory.self, DuplicateExclusion.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration("ReadTests", schema: schema, url: url, cloudKitDatabase: .none)])
        let context = ModelContext(container); context.autosaveEnabled = false
        let reader = InventoryReadAdapter(context: context)
        var passed = 0
        func check(_ value: Bool) { precondition(value); passed += 1 }
        func refuses(_ expected: InventoryReadAdapter.Failure, _ body: () throws -> Void) {
            do { try body(); fatalError("Expected \(expected)") }
            catch let error as InventoryReadAdapter.Failure { check(error == expected) }
            catch { fatalError("Wrong failure: \(error)") }
        }
        check(try reader.status().counts.items == 0)
        check(try reader.list(kind: .items, archive: .all, pageSize: 2).complete)
        let room = Location(name: "Same"), other = Location(name: "Same"), child = Location(name: "Box")
        child.parent = room; child.isReviewed = true; child.lastReviewedDate = Date(timeIntervalSince1970: 123)
        let item = Item(title: "Book", author: "Writer", location: child); item.name = "Stored name"; item.moveDestination = "Planned room"; item.plan = .move
        item.isArchived = true; item.archivedDate = Date(timeIntervalSince1970: 456); item.archivedPlan = .sell
        let second = Item(name: "Same", location: other), third = Item(name: "Same", location: child)
        let tag = Tag(name: "Label", color: "#AABBCC"); tag.dateAdded = nil; item.tags = [tag]; tag.items = [item]
        let history = ReviewHistory(action: .markedReviewed, isAutomatic: true, location: child)
        let exclusion = DuplicateExclusion(itemID1: item.id, itemID2: second.id)
        for l in [room, other, child] { context.insert(l) }; for i in [item, second, third] { context.insert(i) }
        context.insert(tag); context.insert(history); context.insert(exclusion); try context.save()
        let status = try reader.status(); check(status.counts.items == 3 && status.counts.locations == 3 && status.counts.tags == 1 && status.counts.histories == 1 && status.counts.exclusions == 1 && status.counts.archivedItems == 1)
        let shown = try reader.show(kind: .items, id: item.id)
        guard case .item(let dto) = shown.record else { fatalError() }
        check(dto.name == item.name && dto.displayName == item.displayName && dto.bookTitle == "Book" && dto.bookAuthor == "Writer" && dto.isBook)
        check(dto.moveDestination == "Planned room" && dto.plan == .move && dto.locationID == child.id && dto.tagIDs == [tag.id])
        check(dto.isArchived && dto.archivedPlan == .sell && dto.archivedDate == item.archivedDate && dto.dateAdded == item.dateAdded)
        check(shown.exclusions.first?.id == exclusion.id)
        let location = try reader.show(kind: .locations, id: child.id)
        guard case .location(let loc) = location.record else { fatalError() }
        check(loc.path.map(\.id) == [room.id, child.id] && loc.isReviewed && loc.lastReviewedDate == child.lastReviewedDate && loc.itemIDs.count == 2)
        check(location.histories.first?.isAutomatic == true && location.histories.first?.action == .markedReviewed)
        let tagged = try reader.show(kind: .tags, id: tag.id)
        guard case .tag(let t) = tagged.record else { fatalError() }
        check(t.color == "#AABBCC" && t.dateAdded == nil && t.itemIDs == [item.id])
        check(try reader.list(kind: .items, archive: .active, pageSize: 10).records.count == 2)
        check(try reader.list(kind: .items, archive: .archived, pageSize: 10).records.count == 1)
        let first = try reader.list(kind: .items, archive: .all, pageSize: 2)
        check(!first.complete && first.next != nil && first.records.count == 2)
        let last = try reader.list(kind: .items, archive: .all, pageSize: 2, cursor: first.next)
        check(last.complete && last.records.count == 1 && last.next == nil)
        check((first.records + last.records).map(\.id).map(\.uuidString) == [item.id, second.id, third.id].map(\.uuidString).sorted())
        refuses(.notFound) { _ = try reader.show(kind: .items, id: UUID()) }
        refuses(.invalidQuery) { _ = try reader.list(kind: .tags, archive: .active, pageSize: 2) }
        refuses(.invalidQuery) { _ = try reader.list(kind: .items, archive: .all, pageSize: 101) }
        refuses(.invalidCursor) { _ = try reader.list(kind: .items, archive: .all, pageSize: 2, cursor: "bad") }
        refuses(.invalidCursor) { _ = try reader.list(kind: .items, archive: .active, pageSize: 2, cursor: first.next) }
        refuses(.invalidCursor) { _ = try InventoryReadAdapter(context: context).list(kind: .items, archive: .all, pageSize: 2, cursor: first.next) }
        let external = ModelContext(container); external.autosaveEnabled = false
        let saved = try external.fetch(FetchDescriptor<Item>()).first { $0.id == item.id }!; saved.bookAuthor = "Changed"; try external.save()
        refuses(.staleCursor) { _ = try reader.list(kind: .items, archive: .all, pageSize: 2, cursor: first.next) }
        guard case .item(let changed) = try reader.show(kind: .items, id: item.id).record else { fatalError() }; check(changed.bookAuthor == "Changed")
        item.name = "Unsaved edit"
        refuses(.pendingEdits) { _ = try reader.status() }; check(context.hasChanges && item.name == "Unsaved edit")
        // Test cleanup is the test's explicit choice; the adapter never clears edits.
        context.rollback()
        check(!context.hasChanges)
        // Every related model participates in continuation freshness.
        for field in ["name", "archive", "tag", "location", "history", "exclusion"] {
            let page = try reader.list(kind: .items, archive: .all, pageSize: 1)
            let writer = ModelContext(container); writer.autosaveEnabled = false
            switch field {
            case "name": try writer.fetch(FetchDescriptor<Item>()).first!.name += " changed"
            case "archive": try writer.fetch(FetchDescriptor<Item>()).first!.isArchived.toggle()
            case "tag": try writer.fetch(FetchDescriptor<Tag>()).first!.color = "#123456"
            case "location": try writer.fetch(FetchDescriptor<Location>()).first!.name += " changed"
            case "history": try writer.fetch(FetchDescriptor<ReviewHistory>()).first!.isAutomatic.toggle()
            default: try writer.fetch(FetchDescriptor<DuplicateExclusion>()).first!.dateCreated = Date(timeIntervalSince1970: 999)
            }
            try writer.save()
            refuses(.staleCursor) { _ = try reader.list(kind: .items, archive: .all, pageSize: 1, cursor: page.next) }
        }
        let freshPage = try reader.list(kind: .items, archive: .all, pageSize: 1)
        refuses(.invalidCursor) { _ = try reader.list(kind: .locations, archive: .all, pageSize: 1, cursor: freshPage.next) }
        refuses(.invalidCursor) { _ = try reader.list(kind: .items, archive: .all, pageSize: 2, cursor: freshPage.next) }
        let parts = freshPage.next!.split(separator: ".")
        var badCursor = try JSONSerialization.jsonObject(with: Data(base64Encoded: String(parts[0]))!) as! [String: Any]
        badCursor["last"] = UUID().uuidString
        let altered = try JSONSerialization.data(withJSONObject: badCursor).base64EncodedString() + "." + parts[1]
        refuses(.invalidCursor) { _ = try reader.list(kind: .items, archive: .all, pageSize: 1, cursor: altered) }
        refuses(.invalidCursor) { _ = try reader.list(kind: .items, archive: .all, pageSize: 1, cursor: String(repeating: "x", count: 2049)) }
        // Independently stored tag back-links may differ; neither side is normalized.
        let tagWriter = ModelContext(container); tagWriter.autosaveEnabled = false
        try tagWriter.fetch(FetchDescriptor<Tag>()).first!.items = []; try tagWriter.save()
        guard case .tag(let independentTag) = try reader.show(kind: .tags, id: tag.id).record else { fatalError() }
        guard case .item(let independentItem) = try reader.show(kind: .items, id: item.id).record else { fatalError() }
        check(independentTag.itemIDs.isEmpty && independentItem.tagIDs == [tag.id])
        var serial = 0
        func fixture(_ body: (ModelContext, InventoryReadAdapter) throws -> Void) throws {
            serial += 1
            let local = try ModelContainer(for: schema, configurations: [ModelConfiguration("Edge\(serial)", schema: schema, url: url.deletingLastPathComponent().appendingPathComponent("edge\(serial).store"), cloudKitDatabase: .none)])
            let c = ModelContext(local); c.autosaveEnabled = false
            try body(c, InventoryReadAdapter(context: c))
        }
        try fixture { c, r in
            let row = Item(name: String(repeating: "é", count: 8192)); c.insert(row); try c.save()
            check(try r.status().counts.items == 1)
            row.name += "x"; try c.save(); refuses(.fieldLimit) { _ = try r.status() }
        }
        try fixture { c, r in
            for _ in 0..<100 { c.insert(Item(name: String(repeating: "x", count: 12000))) }; try c.save()
            check(try r.status().counts.items == 100)
            refuses(.responseLimit) { _ = try r.list(kind: .items, archive: .all, pageSize: 100) }
            check(try r.list(kind: .items, archive: .all, pageSize: 1).records.count == 1)
        }
        try fixture { c, r in
            for _ in 0..<400 { c.insert(Item(name: String(repeating: "x", count: 12000))) }; try c.save()
            refuses(.projectionLimit) { _ = try r.status() }
        }
        try fixture { c, r in
            for _ in 0..<5001 { c.insert(Item(name: "bounded")) }; try c.save()
            refuses(.rowLimit) { _ = try r.status() }
        }
        try fixture { c, r in
            let row = Location(name: "Cycle"); c.insert(row); row.parent = row; try c.save()
            refuses(.invalidData) { _ = try r.status() }
        }
        try fixture { c, r in
            var parent: Location? = nil
            for _ in 0..<16 { let row = Location(name: "Deep", parent: parent); c.insert(row); parent = row }; try c.save()
            refuses(.invalidData) { _ = try r.status() }
        }
        try fixture { c, r in
            c.insert(DuplicateExclusion(itemID1: UUID(), itemID2: UUID())); try c.save()
            refuses(.invalidData) { _ = try r.status() }
        }
        try fixture { c, r in
            let row = Item(name: "Nonfinite"); row.dateAdded = Date(timeIntervalSince1970: .infinity); c.insert(row); try c.save()
            refuses(.invalidData) { _ = try r.status() }
        }
        let incompleteSchema = Schema([DuplicateExclusion.self])
        let incomplete = try ModelContainer(for: incompleteSchema, configurations: [ModelConfiguration("Incomplete", schema: incompleteSchema, url: url.deletingLastPathComponent().appendingPathComponent("incomplete.store"), cloudKitDatabase: .none)])
        refuses(.unsupportedSchema) { _ = try InventoryReadAdapter(context: ModelContext(incomplete)).status() }
        // Break only a disposable SQLite table after container setup. A fetch error
        // must remain an error; it must never become an empty/complete inventory.
        let brokenURL = url.deletingLastPathComponent().appendingPathComponent("unavailable.store")
        let broken = try ModelContainer(for: schema, configurations: [ModelConfiguration("Unavailable", schema: schema, url: brokenURL, cloudKitDatabase: .none)])
        let brokenContext = ModelContext(broken); brokenContext.autosaveEnabled = false
        brokenContext.insert(Item(name: "Fixture only")); try brokenContext.save()
        let sqlite = Process(); sqlite.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        sqlite.arguments = [brokenURL.path, "ALTER TABLE ZITEM RENAME TO ZITEM_UNAVAILABLE;"]
        let sqliteError = Pipe(); sqlite.standardError = sqliteError
        try sqlite.run(); sqlite.waitUntilExit(); check(sqlite.terminationStatus == 0)
        do { _ = try InventoryReadAdapter(context: brokenContext).status(); fatalError("Fetch failure became success") }
        catch { check(true) }
        print("READ_RESULT=" + String(data: try JSONSerialization.data(withJSONObject: ["passed": passed]), encoding: .utf8)!)
    }
}
