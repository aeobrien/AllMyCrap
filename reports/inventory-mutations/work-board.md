# Inventory correctness prerequisite

Outcome: moves target the selected record, invalid nesting is rejected, and future removal callers can obtain a complete, fresh preview before applying approved effects. No session transport or live inventory operation.

Reuse: retained SwiftData models and relationships, adapted existing move picker, and added one shared service because mutations were embedded in individual views. The reusable-building-blocks catalogue has no inventory mutation component; voice/transcription/chat leads do not fit this job.

| Promise | Current evidence |
| --- | --- |
| Exact-ID move and cycle/depth validation | 21 synthetic checks, four independent scenarios, unchanged identities and metadata |
| Full cascade preview, stale check, affected exclusion cleanup | Actual disposable SwiftData store tests including another context's edit, overlap and unrelated survival |
| Failures do not claim success | Read-only-store save refusal and pending edits tests; fresh-context readback |
| Existing real-move caller uses selected identity | Source review plus generic simulator compile; no screen interaction claim |
| Approved removal boundary | Preview plus explicit caller assertion; consent capture/authentication intentionally absent until transport exists |
| Independent review | Astra PASS; Fable02 PASS after retained incomplete01; alert-placement Astra/Fable delta reviews PASS |
| Final checks | UI build02 PASS23.907s; owned commit and committed/canonical checks pending |

Optional review follow-up: moved the error alert onto the active move sheet so refusal can be shown there. Existing batch-move persistence handling, other deletion UI callers, automatic-save behavior and debug logging remain documented follow-on work. No scheme/signing/settings changes beyond registering one source file. macOS14 or newer SDK/runtime is required by the synthetic SwiftData runner.

Build armed at the start with key 01a0fcb2-7788-7d21-9627-c24c34f60149-inventory-mutations and manifest build-BUILD-INVENTORY-MUTATIONS-747505ee. Named software-build bookkeeping run 072ee98a-de38-4ebe-ab09-2e295e1c750c was started on the r000023 protocol refresh; it is not a second build engine or evidence that previous steps were automatically verified.
