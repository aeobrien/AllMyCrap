# Read exact inventory records without opening another store

Proposed bounded plan for root review before implementation. North star: another app-owned component can obtain bounded, typed status/list/show results from the existing inventory, with exact IDs, complete agreed fields and honest stale/error results. This is a local library prerequisite, not delivered session transport.

Baseline3337ecaeba0c6a0bec733201f190443d21e56b42. Own only new AllMyCrap/InventoryReadAdapter.swift, tests/inventory_read_adapter.swift, tests/inventory_read_adapter.py, docs/INVENTORY-READ-ADAPTER.md, this plan and reports/inventory-read-adapter/. No existing models/service/project file changes. The new source is compiled explicitly by the isolated harness; app-target wiring is outside this slice. Existing InventoryMutations completion stays complete. Primary .DS_Store/build lock/understudy artifacts and other workers' edits remain untouched.

No new ModelContainer, default store selection, BackupManager, backup import/export/restore, relay, polling, network, credentials, UI, app lifecycle, runtime onboarding, data writes or schema migration. Transport/foreground-mailbox architecture remains a proposal, not a selected production design. No new approval requirement for reads.

## Agreed projection and limits proposed for review

Adapter initialized on the main actor with an existing supplied ModelContext. It refuses pending changes in that context, does not save/reset/rollback it, and reads through a fresh context from the same existing container so another context's committed changes can be observed. No path initializer or implicit store exists. A generated adapter-instance scope UUID binds continuation tokens; it is not a claimed permanent device/store identity.

Typed Codable value DTOs only, no SwiftData objects escape. Status reports observed counts for all five models, active/archived item counts, adapter scope, projection revision and explicit bounded-read completeness. List covers items, locations and tags with stable UUID ordering, page size1–100, explicit item archive scope active/archived/all, continuation tied to kind/archive/page size/scope/revision. Show requires exact type+UUID and returns not-found instead of name fallback. Duplicate names remain separate. No implicit search or fuzzy matching.

Projection preserves:

- Item: id, name, dateAdded, locationID, sorted tagIDs, plan, moveDestination, isBook, bookTitle, bookAuthor, isArchived, archivedDate, archivedPlan. Display name is additional derived text, never a replacement for stored fields. Actual location and planned destination remain distinct.
- Location: id, name, dateAdded, parentID, sorted childIDs/itemIDs, isReviewed, lastReviewedDate; bounded cycle-checked ancestor path of IDs/names. No recursively embedded whole tree.
- Tag: id, name, colour string, optional dateAdded and sorted itemIDs. Tag assignments remain references; tags are not inferred from names.
- Relevant review metadata: id, date, action, isAutomatic, locationID. Relevant duplicate-exclusion metadata: id, itemID1, itemID2, dateCreated. Include bounded related rows on exact item/location shows and their counts in status; do not invent them as ordinary top-level mutation targets. Location show refers to direct location history; descendant inventory is reached through explicit child IDs, not a hidden cascade dump.

Fetch at most5001 rows per model and refuse above5000. Reject oversized field strings (>16KiB UTF-8), nonfinite dates, duplicate identities, invalid graph/relationship references or over-limit graph traversal. Cap total encoded projected inventory at4MiB and individual response at1MiB, refusing rather than truncating fields or pretending partial data is complete. These are conservative explicit support limits, not promises to browse arbitrarily large stores. Bound list cursors and decode/validate their fields before use.

Revision hashes every agreed projection field across all five models in canonical order. A continuation must match a newly observed revision and query/scope; changed content or metadata, altered filters, unknown cursor position, foreign adapter or deleted records returns stale/invalid continuation without a page. The first response is an observed read, not a distributed transactional snapshot. Cross-process/platform sync is not supplied. If a mutation occurs while materializing related rows and produces inconsistency, refuse; no retry loop or store repair.

## Step 1: Prove injected typed status/list/show

Write an isolated Swift compiler runner adapted from the existing inventory-mutation fixture approach: copy the unchanged five model sources plus new adapter and test source, use temporary disk SwiftData with CloudKit disabled, never create AllMyCrapApp or BackupManager. Record source hashes, bounded compiler/runtime output, and useful asserted result markers. Preserve meaningful red before adapter implementation, then green through Understudy. Test all projected fields with non-default values, archive scopes, duplicate names, exact missing IDs, empty store, stable order and a fresh context seeing committed changes. Verify original supplied context and saved records remain unchanged.

- The command `python3 tests/inventory_read_adapter.py` exits 0.
- The file `reports/inventory-read-adapter/red-01/cli-run-result.json` exists.

## Step 2: Enforce continuation, bounds and failure truth

Test multiple pages and exact complete indication, stale continuation after changed item/book/archive/tag/location/history/exclusion data, wrong kind/filter/size/adapter, malformed token and missing position. Test pending unsaved UI edits retained unchanged; fetch/unavailable errors not empty success; cycles, duplicate IDs/invalid references where constructible, oversized string/row/output limits, nonfinite dates and depth bounds. No changes to model mutation semantics. Do not duplicate previously accepted CRUD tests except where needed to prepare synthetic state for this read boundary.

- The file `AllMyCrap/InventoryReadAdapter.swift` exists.
- The file `tests/inventory_read_adapter.swift` exists.
- The command `python3 tests/inventory_read_adapter.py` exits 0.

## Step 3: Freeze, independently review and preserve original gates

Document exact API, fields, limits, revision semantics and local-only boundary. Freeze source hashes; obtain independent Astra (not this author) and Fable review subject to exact external disclosure authorization, preserve failures, repair real blockers, and run post-review Understudy. Commit only owned files, run committed-diff and original canonical completion checks. Missing review/authorization remains an explicit gap, not a fabricated pass. Root owns wider integration; no transport/host choice, app deployment or catalogue availability claim.

- The file `docs/INVENTORY-READ-ADAPTER.md` exists.
- The file `reports/inventory-read-adapter/VALIDATION.md` exists.
- The file `reports/inventory-read-adapter/candidate-01.json` exists.
