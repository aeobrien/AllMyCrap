# Read inventory through an existing app-owned context

`InventoryReadAdapter` is a main-actor Swift library, not a CLI, relay or session transport. Initialize it with an already selected `ModelContext`. It has no file-path/default-store initializer and does not construct a ModelContainer, access backups, save, reset or roll back the caller. It is not wired into the app target in this slice. The unchanged five model sources plus the adapter are compiled explicitly by the fixture runner.

```swift
let reader = InventoryReadAdapter(context: selectedContext)
let status = try reader.status()
let page = try reader.list(kind: .items, archive: .all, pageSize: 25)
let next = try reader.list(kind: .items, archive: .all, pageSize: 25, cursor: page.next)
let exact = try reader.show(kind: .items, id: selectedItemID)
```

Only call the continuation form when `page.next` is non-nil; nil starts a new first page. Other kinds are `.locations` and `.tags`, using archive `.all`. Items require explicit `.active`, `.archived` or `.all`. Show looks up an exact type and UUID across archive states; names are display data and missing IDs throw `notFound`. Pages contain typed `Record` enum values sorted by UUID string, total count, revision, scope, complete and optional next. `complete` means this page reaches the end; it does not assert that earlier pages were consumed. Status includes all five model counts, active/archived item counts, complete and `transactionalSnapshot:false`.

## Fields preserved

- Item: id, name, dateAdded, locationID, tagIDs, plan, moveDestination, isBook, bookTitle, bookAuthor, displayName, isArchived, archivedDate, archivedPlan. Plan is a Codable enum with the actual stored Keep/Throw Away/Sell/Charity/Move/Fix values. Display name is additional; stored name and book fields remain separate. Planned destination is not actual location.
- Location: id, name, dateAdded, parentID, childIDs, itemIDs, isReviewed, lastReviewedDate and root-to-record path entries of exact IDs/names. No recursively embedded descendants.
- Tag: id, name, color, optional dateAdded, itemIDs. The actual Tag schema has an optional date. Item.tags and Tag.items are independently stored arrays: both are projected as saved, not silently repaired or normalized into one relationship.
- History: id, date, action, isAutomatic, locationID. A location show includes its direct history rows; histories for descendants require their own exact location read.
- Duplicate exclusion: id, itemID1, itemID2, dateCreated. An item show includes exclusions involving that item; location show includes exclusions involving its directly contained items. An unrelated record referenced by such an exclusion is identified but not recursively expanded. Tag show has no unrelated history/exclusion expansion.

All relationship arrays are deterministically sorted. Values are detached Codable DTOs; no managed SwiftData object escapes. Missing references, duplicate IDs/relationship IDs, location cycles, inconsistent declared parent/child or location/item inverses, and more than15 location levels refuse the projection. The adapter does not invent a reverse constraint between the separately maintained tag/item arrays. Existing orphan exclusions are reported as invalid data, not silently erased.

## Bounds and freshness

Each model fetch requests at most5001 rows and refuses more than5000. Individual projected strings are capped at16KiB UTF-8, including derived display names; dates must be finite. Full projected inventory is capped at4MiB, checked incrementally and after final encoding. A result is capped at1MiB. These sizes use compact sorted-key JSON with dates as seconds since1970; a future transport choosing another encoding must impose its own byte bound. No fields are truncated to meet limits. Page size is1–100. A large page may exceed the response limit even when a smaller page is supported.

Every read first rejects unsaved changes in the supplied context. It then creates a fresh read context from that same existing container, which observes externally committed changes without resetting the caller. It verifies the required model schema and propagates actual fetch errors; unavailable/incompatible/corrupt data is never an empty-success fallback.

Revision is SHA256 over the full canonical projection of all five models, including related metadata. Any observed field change can invalidate an item-page cursor, even an unrelated tag/history change. Cursors bind revision, query kind, archive scope, page size, last exact ID and adapter-instance scope, and carry a per-instance HMAC. Oversized/malformed/tampered/foreign/query-changed tokens throw `invalidCursor`; a changed observed revision throws `staleCursor`. The key and scope exist only for this adapter's lifetime. Tokens are not durable cross-process transport identities or permission credentials.

These are fresh observed projections across multiple fetches, not a database-wide distributed snapshot or a sync protocol. Detected graph inconsistency refuses; a valid concurrent edit between model fetches is not claimed to be transactionally excluded. Pagination detects differences between the observed projections. No retry loop, database repair or backup promotion occurs.

## Errors and verification

Typed failures: pendingEdits, invalidQuery, notFound, invalidCursor, staleCursor, rowLimit, fieldLimit, projectionLimit, responseLimit, invalidData and unsupportedSchema. Underlying SwiftData fetch/encoding errors remain thrown. The caller decides how to present a safe error; this library has no logging or credential-bearing fields.

`python3 tests/inventory_read_adapter.py` copies only the five unchanged models, adapter and test harness, compiles with Swift5/macOS14 target in a temporary directory and opens disposable on-disk SwiftData stores with CloudKit disabled. It never initializes AllMyCrapApp or BackupManager. The host compiler needs normal Swift macro permissions; run automated checks through Understudy. Fixtures cover saved/non-default fields, archived/duplicate-name records, cross-context freshness, relation metadata, cursor boundaries, pending edit preservation, sizes/rows, invalid graph/data/schema and actual SQLite fetch failure. The fetch-failure fixture renames one table only in its own disposable database.

All current checks are local prerequisites. Independent reviews, post-review tests and committed completion gates are tracked in reports/inventory-read-adapter. No network, app polling, runtime onboarding, UI, host/relay choice, backup/default-store access, account pairing, device deployment, live inventory or fresh-client availability is established. Reading/editing/addition/removal consent policy is not changed by this read-only component.
