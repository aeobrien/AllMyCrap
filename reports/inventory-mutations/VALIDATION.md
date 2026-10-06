# Inventory mutation prerequisite — verification in progress

The new shared service validates exact-ID moves, rejects self/descendant/over-depth moves, explicitly saves and reads back, and prepares deterministic deletion effects with stale revalidation and removal of affected duplicate exclusions. The app's single-record move controls call it. The picker also passes exact selected locations to the existing batch-move handler; text-only move-plan callers keep their existing string contract. Xcode project changes only register the new Swift source.

Retained Understudy evidence:

- red-01: host macro sandbox refusal, not an inventory assertion failure.
- red-02: missing service plus test syntax errors; corrected test syntax before implementation.
- red-03: clean missing InventoryMutations API compiler failure before source implementation.
- green-01: first implementation could not type-check one long Swift expression. Expression split; failure retained.
- green-02: 17 isolated checks passed in 6.303 seconds.
- cross-context-red-01: despite the exploratory directory name, the new cross-context stale-preview regression PASSED, 6.837 seconds. No failure or repair is claimed for it.
- edges-01: 21 checks passed in 9.442 seconds, including an actual read-only SwiftData store save failure and a corrupt location cycle. Exact source hashes are recorded in the output.
- ui-build-01: generic iOS simulator Debug build passed in 70.658 seconds, code signing disabled, build output in a temporary directory. App not launched, no screenshots/phone/deployment.

All model tests compile copies of the actual unchanged five models plus the new service, with disposable on-disk stores and CloudKit disabled. They do not instantiate AllMyCrapApp or BackupManager. The compiler requires normal outer permissions for Swift macro execution; ordinary permission review approved those synthetic test launches. That is separate from the still-rejected recording-client Codex retry in another task.

Preview is not approval. The service accepts a trusted app caller's explicit `approved` assertion for the exact immutable preview; it does not authenticate a user or collect consent. Future session transport must obtain actual user approval for the complete cascade and bind it to this preview. No extra approval was added for moves or edits. Stale checking is deliberately conservative and can reject a preview after an unrelated inventory edit. Main-actor synchronous operations provide an app-local boundary, not a distributed concurrency or persistent retry protocol.

This slice does not migrate other deletion UI handlers, add tags/CRUD transport, repair all existing orphan rows, change backup format, expose live inventory, add operation receipts or prove phone behavior. Only exclusions referencing items in the approved removal are cleaned. Failed readback after a successful save is an uncertain outcome requiring inspection, not permission to retry blindly. Existing pending context edits are rejected rather than saved or rolled back by this service.

Independent Astra/Fable reviews and the alert-placement delta reviews passed. Final-models-01 passed all 21 checks in 15.968 seconds; ui-build-02 passed the alert relocation compile in 23.907 seconds. Owned source commit d657b7aec0587ab4487784d93aedaa296ab6d17e passed committed judge diffjudge-d657b7ae (all checks, $0.0500) and canonical run run-1791269149-83237 (complete/pass at that exact target head). Scoped autonomy was retired after checking terminal state. This bounded local prerequisite is complete; the limits above remain.
