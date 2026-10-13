# Safe inventory moves and approved deletion effects

Build a shared app-owned mutation service, using exact record identities and isolated SwiftData contexts. No session transport, backup, real inventory, phone, deployment or provider operation. Preserve unrelated working-tree edits. Additions/removals require approval for exact full effects; a preview alone is not approval. Moves/edits have no extra approval rule.

## Step 1: Preserve failing isolated cases

Create synthetic model tests covering missing service, self/descendant/over-depth moves, duplicate display paths, complete deletion cascade, stale preview and exclusion cleanup. Run through Understudy before implementation; preserve real compiler or assertion failure separately from host permission failures.

- The file `reports/inventory-mutations/red-01/cli-run-result.json` exists.

## Step 2: Implement the bounded mutation boundary

Add InventoryMutations.swift with exact-ID moves, cycle-safe graph validation, depth limit 15, explicit persistence and readback. Add deterministic full cascade preview and apply with separately supplied exact approval, stale revalidation and cleanup only of exclusions affected by deleted items. Preserve unrelated/moved-out records and location history semantics. Wire necessary LocationDetailView and MoveDestinationPicker move callers without display-path target ambiguity; existing text-only move plans remain text.

- The command `python3 tests/inventory_mutations.py` exits 0.

## Step 3: Review and document practical limits

Obtain independent Astra/Fable source review, verify relevant UI caller compilation where available and record any gap. Commit owned paths only, run committed review and canonical gate. No session availability, migration of every deletion caller or production verification claim.

- The file `reports/inventory-mutations/VALIDATION.md` exists.
