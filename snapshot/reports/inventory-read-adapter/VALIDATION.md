# Inventory read adapter — local candidate01

Root approved the complete plan before implementation. Build session inventory-read-adapter-20261006; manifest build-BUILD-INVENTORY-READ-ADAPTER-f94f5ab0; saved procedure51be483e-e26b-44cb-93ba-b15b23fe2b53. Baseline3337eca. No existing model/service/project source changed.

- red-01 FAIL: restricted Swift macro execution; not an adapter assertion result.
- red-host-01 FAIL: normal-permission Swift compilation reaches missing InventoryReadAdapter API. Missing-adapter and dependent-type diagnostics retained. Compiler diagnostics are bounded to their last30,000characters by the runner, not claimed complete logs.
- green-01 FAIL: initial adapter incorrectly assumed item/tag relationships were automatically symmetric. Actual schema and app call sites show independently maintained links; preserve both as stored and validate referenced IDs without imposing a new inverse.
- green-02 PASS:26 assertions,29.595s.
- edges-red-01 FAIL: missing explicit unsupportedSchema failure; no boundary suite execution claimed for that compile failure.
- edges-green-01 PASS:49 assertions,24.601s, including scoped signed cursors, related-model changes, schema/graph/string/row/projection/response limits.
- fetch-error-01 PASS:51 assertions,28.567s; adds actual fetch-error propagation from a deliberately broken table in a disposable SQLite store. No timeout or Understudy output truncation.

Tests compile the actual unchanged five models and adapter. Stores, corrupt table, commands and all data are synthetic temporary fixtures. Caller pending edits are asserted unchanged; only the fixture itself explicitly rolls back its own test context after checking the adapter refusal. No app/default container, backup, network, credential, UI, device or production record accessed. Prior five-model CRUD and mutation-service suites are not duplicated or relabeled.

Independent Astra must be another agent, because this author is Astra. Astra/Fable, exact external disclosure authorization, post-review Understudy, source commit, committed-diff review and original canonical completion remain pending. A passing fixture does not prove live access or selection of any transport architecture.

## Independent review and post-review execution

Separate maintained Codex read-only gpt-6-astra invocation PASS (61.051s), reviews/astra-independent-01. Fable5.1 single request PASS, reviews/fable-01; payload53,296 bytes SHA256 b834a01a7efeb1647d9b2f9bb0c384575b82c15f0525b9a2dfaabe80b5b61509, low reasoning/8000 output tokens, cost $0.36733, no retry. Both are static source reviews and executed no tests. No blocking fault found. Optional field-by-field fixture expansion is deferred; actual projection inspected correct. Future enum-case exhaustiveness is a maintenance note, not current failure.

Required post-review Understudy post-review-01:51 assertions PASS21.721s, exit0, no timeout/truncation. Same10 frozen input hashes match (post-review-hashes.json). Actual SwiftData temporary-store runtime coverage belongs to this run, not to either static reviewer. No real records, backup/default store, network, UI, app wiring or deployment tested.
