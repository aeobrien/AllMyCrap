**Verdict: PASS** (bounded scope: new service moves, cascade preview/apply, exclusion cleanup, exact-ID move wiring)

**No blocking faults found in supplied source.**

Checked, within scope:

- `InventoryMutations.swift` `graph()`: duplicate-ID, dangling parent, parent/child inverse mismatch and ancestor cycle all throw `invalidGraph` before any write; ordering (clean → graph → target lookup) means no partial mutation on rejection.
- `moveLocation`: self/descendant rejection via destination-ancestor walk; depth = destination depth + 1 + subtree height, limit 15 inclusive — consistent with `Location.depth` semantics (rooms = 1) and the UI's `depth >= 15` add-guard. Save failure rolls back; readback uses a fresh context, so verification reflects the store, not the dirty context.
- `moveItem`: exact-ID lookup, no display-path resolution, readback against store.
- `previewDeletion`: cascade closure over children → items → history; exclusions limited to pairs touching affected items; deterministic ordering (`ordered`, sorted descriptions, sorted rows); fingerprint covers the whole graph so any cross-context edit forces a fresh preview (conservative, matches the "no silently accepted changed effect" requirement).
- `applyDeletion`: approval gate before any fetch; stale check compares the full `Equatable` preview including fingerprint; explicit deletes for items/exclusions (which have no cascade path), root-only location deletes relying on declared `.cascade` rules for children/items/history; rollback on save failure; post-save disjointness readback for all four record kinds.
- `LocationDetailView.performMove` / `MoveDestinationPicker.onLocationConfirm`: pass `Location` objects and call the service with `.id`; the duplicate-named "Same"/"Same" case is unambiguous. Text-only `onConfirm` path untouched.
- Model files are unchanged; harness compiles exactly those five plus the service; `expectFailure`/`precondition` are real assertion failures, not permission masking.

Out of scope as stated and not counted: raw `modelContext.delete` in `deleteChild/deleteItem/deleteChildren/deleteItems/batchDelete`, `batchMove` direct assignment, session/backup/auth.

**Optional suggestions (non-blocking):**

1. `LocationDetailView.swift`, `moveDestinationSheet` → `performMove` failure path: `showDepthAlert = true` is set while `showMoveSheet` is still presented; the `.alert` is attached to the parent view, and SwiftUI commonly does not present an alert beneath an active sheet. Data stays unchanged, but the user may get no visible error. Consider surfacing the error inside `MoveDestinationPicker` or dismissing the sheet first.
2. `LocationDetailView.swift`, `batchMove`: still assigns `item.location` directly with no readback. Items have no graph constraint, so this is safe, but routing through `moveItem` would make the move path uniform.
3. `LocationDetailView.swift`, context menu `Button("Clear Plan") { item.plan = nil }`: no explicit save; with autosave this is transient, but if a move follows immediately it will surface as `.pendingEdits`. Consider saving, as `assignPlan` does.
4. `InventoryMutations.swift`, `previewDeletion` fingerprint: `String(describing:)` on `Date?` is locale/format-stable enough here but `timeIntervalSince1970` (as used for history) would be more explicit.
5. `MoveDestinationPicker.swift`: debug `print` calls (init, Section body, row buttons) should be removed before commit.
6. `tests/inventory_mutations.py`: `platform.machine()` yields `x86_64`/`arm64`, both valid triples; a `-apple-macos14.0` hardcode will fail on older hosts — record as an environment limit in VALIDATION.md.

No executed test results are asserted by this review; the 21-check pass is taken as reported.
