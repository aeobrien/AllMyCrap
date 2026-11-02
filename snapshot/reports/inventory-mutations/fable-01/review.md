# Independent source review — InventoryMutations prerequisite

**Scope reviewed:** `InventoryMutations.swift` (exact-ID moves, cycle/depth validation, persistence + readback, cascade preview, stale check, exclusion cleanup), the move-caller wiring in `LocationDetailView.swift` / `MoveDestinationPicker.swift`, the five model files, and the `tests/inventory_mutations.{swift,py}` harness. Out of scope by declaration: unmigrated deletion handlers (`deleteItem`, `deleteChild`, `deleteChildren`, `deleteItems`, `batchDelete`), text-only move plans, session/backup/phone/deployment, user authentication. I did not execute anything; the "21 checks passed" result is taken as reported, not re-verified.

## Verdict: no blocking faults found in the stated scope

### What I checked and why it holds

**Graph validation (`graph()`, L47–68).** Duplicate-ID rejection, parent-chain walk with a per-row `seen` set (catches self-loops and longer cycles), and both-direction parent↔children consistency checks. Every mutating entry point calls it before touching anything, so the `while let ancestor` walk in `moveLocation` cannot spin on a corrupt store.

**Self/descendant move (`moveLocation`, L87–92).** Walking from `destination` up to root and rejecting if any node's id equals the source id correctly rejects self and every descendant target. Depth arithmetic: `destinationDepth` = destination's depth (rooms = 1, matching `Location.depth`), source lands at `destinationDepth + 1`, deepest descendant at `+ height`; `<= 15` matches the UI's `depth >= 15` add-guard. The harness's "Level 2…15 → reject at 15, accept at 14" case is consistent with this arithmetic.

**Persistence/readback (L78–80, L101–103, L160–167).** Save failure rolls back and rethrows; verification uses a fresh `ModelContext(context.container)` so it reads store state, not the writing context's cache. On `verificationFailed` nothing is rolled back — correct, since the save already committed.

**Cascade preview (L106–145).** Descendant collection is a worklist over `children`; items are included if requested or in any affected location; history by affected location; exclusions if either `itemID` is an affected item (and *only* those — unrelated exclusions survive, as the harness asserts). `RemovalPreview` is `Equatable` with a `fileprivate` fingerpr
