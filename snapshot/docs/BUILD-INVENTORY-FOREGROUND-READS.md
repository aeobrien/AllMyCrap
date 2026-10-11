# Let a session request an app-owned inventory read

Proposal for root review, not a new build authorization. Baseline primary AllMyCrap57d255ce04a0ac0734753dc80ff0e6f0540467c0; exact inspected inputs in SOURCE-EVIDENCE.json and source-hashes.json. This reconciles the retained PLAN-author-first.md and PLAN-astra-proposal.md after a harmless report-write collision; no application source was involved. No source, app, remote, provider, account or inventory changes were made for this plan. Integrated51fixture checks were not repeated.

## Decision and outcome

Registering and constructing the reader alone does not deliver useful access: nothing submits a request or receives an answer. It can prove compilation and context injection, but must not be called session access. Do not add a paste/copy UI: root rejected that as a new manual burden rather than the intended automatic capability.

Recommend the smallest complete local channel: an explicit session client submits one typed read request to a disposable authenticated mailbox; an app-owned foreground worker claims it, calls the integrated reader against its supplied ModelContext and publishes a bounded response; the originating client receives that exact response. Exercise real HTTP on loopback with synthetic temporary SwiftData and register/wire the same worker into the actual iOS target. This is an executable prototype of the foreground mailbox architecture, not a selected production host, pairing flow or deployed phone connection.

Success at this slice means an actual client→mailbox→app-owned worker→existing reader→mailbox→client round trip, plus truthful inactive/stale/error behavior. It does not mean Claude or Codex can already reach the user’s phone or read live possessions.

## Existing boundary to preserve

AllMyCrapApp.swift:9–27 owns the five-model on-disk container and disables CloudKit; :45 injects it into the scene. ContentView.swift:5 uses that environment context. App startup/resign-active triggers backup work at AllMyCrapApp.swift:36–42, so ordinary app bootstrap must not be used in synthetic tests against its default store. Entitlements contain CloudDocuments only (AllMyCrap.entitlements:5–16); those document backups are not a request transport.

The project explicitly lists Sources, including InventoryMutations at project.pbxproj:352; InventoryReadAdapter is not registered yet. Its initializer at InventoryReadAdapter.swift:84 accepts an existing context; projection at :120 refuses pending changes and creates a fresh context only from the same container. Preserve that reader source and its field/row/output limits. Its scope/cursor key belong to one adapter lifetime; rebuilding it per request would break pagination. Source-only absence of a current command transport is established by the earlier source-grounded access plan; no new library search or provider call is needed.

## Owned implementation proposed

1. Register the existing adapter plus new protocol/coordinator/mailbox-client/session-owner files in the actual app target. Use a small injected app composition boundary that receives the existing container/main context. Keep one adapter for an enabled foreground session. The ordinary app path receives its current app-owned context; it must never open another store or read backups.
2. Add a strict typed protocol limited to status, list and show for items/locations/tags, including archive scope/page size/cursor/exact UUID. Reject unknown versions, operations and fields rather than ignoring write-like input. No arbitrary URLs, filesystem paths, model names, predicates or executable commands in requests.
3. Add a foreground worker using outgoing URLSession only. Construction requires explicit endpoint and an opaque credential from injected configuration; no default host, environment scan, provider key or automatic live activation. No host/pairing settings UI in this slice. Scene activation/deactivation controls the owner; inactive cancels polling and marks its current session unavailable. Do not promise background execution.
4. Add a minimal disposable loopback mailbox and local client under dedicated experiment/test tools. Use a generated per-run credential and explicit session/worker identities; no production endpoint or persistent inventory replica. Use distinct synthetic bearer credentials for client submission/readback and worker claim/result roles; reject cross-role access before parsing retained records. Authenticate submit/claim/result operations and bind each response to request UUID, canonical request digest, session generation and worker scope. CLI requires explicit endpoint and token input; there is no fallback to phone/default/backup data.

The production integration can compile but remains inactive while no supported configuration/pairing source exists. The real loopback acceptance uses the same coordinator, protocol and URLSession implementation, not fake successful responses. A separate test host/composition entry supplies only a temporary container and explicit fixture configuration; it must not instantiate BackupManager or the ordinary lifecycle’s backup/review-expiry behavior. Actual app-target registration and composition callsites are separately compiled/inspected. Do not represent that separate fixture-host execution as a live installed app session.

## Concrete ownership and app composition

Use a new isolated AllMyCrap checkout, preserving completed reader/mutation manifests and primary .DS_Store. Proposed files: AllMyCrap/InventoryReadProtocol.swift (typed strict read envelopes), InventorySessionReads.swift (retained reader and main-actor dispatch), InventoryForegroundReadWorker.swift (serialized lifecycle pump), InventoryMailboxTransport.swift (injected protocol plus actual URLSession implementation), narrow AllMyCrapApp.swift wiring, AllMyCrap.xcodeproj/project.pbxproj registration, tools/inventory_session/mailbox.py and client.py (local prototype, no installed wrapper), tests/inventory_session_protocol.swift/.py, tests/inventory_session_roundtrip.py plus shared synthetic contract fixtures, docs/BUILD-INVENTORY-FOREGROUND-READS.md and reports/inventory-foreground-reads/. No reader/model/schema/mutation/backup/UI/entitlement edits unless a concrete prerequisite is separately approved.

Registration needs unique PBXFileReference/PBXBuildFile/app-group/source-phase entries, not merely files on disk. Sources phase DDB89A122E08550700A24E47, app group DDB89A182E08550700A24E47, app target DDB89A152E08550700A24E47. Existing source membership remains intact. App composition retains one owner from the same container injected into ContentView and existing lifecycle callbacks. ScenePhase active/inactive changes are sent to the worker; backup/review expiry behavior and current container configuration stay unchanged. A retained instance preserves reader scope/key between requests. Construction performs no fetch or network operation.

The injected configuration is absent in the ordinary app until a later approved pairing/configuration source exists: absent means explicitly disabled/unconfigured, not a fallback endpoint. The local harness supplies an ephemeral loopback configuration to the actual worker/URLSession implementation and activates/deactivates it programmatically. This proves automatic worker behavior while the compiled app consumer remains inert when unconfigured. No runtime feature flag should open the production/default store for fixture use.

A typed transport seam permits deterministic failure tests, but the acceptance run must also cross actual HTTP with the maintained Swift implementation and the Python prototype client/mailbox. One callback processes one claimed request on the main actor. Completion publishes only while its generation/request remains active; foreground loss cancels owned URLSession tasks and cannot publish stale completion under a new generation. Do not start a second poller on duplicate active events.

The current AllMyCrapTests source phase is empty and its TEST_HOST launches the real app; do not use it for this fixture or count zero tests as success. Use an isolated executable compiling actual protocol/owner/worker/transport + reviewed models/reader, configured only with a temporary SwiftData store. Separately compile the actual app target without launch, installation, simulator boot or device interaction. No source stub may replace the actual reader/transport on the success path.

## Small protocol contract

Use a generated worker-session scope, not a fabricated durable store UUID. Scope represents one explicitly configured app-owned container/session; additionally inject independent synthetic device/store IDs into each local fixture configuration and bind requests to that tuple. They are test identities, not claims of a durable production identity. Two fixture stores must use separate IDs/scopes; restart or different pairing invalidates old cursors. Durable device/store identity and pairing persistence remain a later production prerequisite.

Requests contain version, request UUID, request digest, originating session ID, expected device/store IDs and worker scope and typed read arguments. Define one canonical UTF-8 JSON digest format, shared vectors and rejection for duplicate keys, nonfinite numbers or differing digests; the server recomputes the digest, not trusts a caller claim. Exact allowed fields/size are checked before enqueue/dispatch, and the Swift worker validates the binding before any reader call. A bounded authenticated metadata handshake returns the selected configured device/store/session scope without querying inventory. status/list/show then require that exact binding; there is no public inventory-discovery endpoint. Responses bind all those fields and include observed timestamp, app/build identity, reader revision, result or specific error and completeness. Preserve transactionalSnapshot=false. A response to a different request/client/scope is refused, never opportunistically consumed.

Keep bounded in-memory request/result custody in the disposable mailbox, with explicit expiry and count/byte limits. Same UUID plus same digest returns the retained result; same UUID with different input fails. Do not claim durable exactly-once execution or crash recovery. If worker/result state is lost, report expired/unknown/unavailable and require a fresh request ID; never silently recompute under an already completed request ID. Reads do not mutate records, but a newly observed result can differ, so distinguish it from the original request.

Suggested initial experiment limits: request16KiB, at most32 retained requests per fixture session,30-second overall wait, one in-flight read per worker, one-second foreground polling, five-minute result retention. Enforce a reply-envelope cap that explicitly includes wrapper overhead around the reader’s1MiB result; set the encoded envelope cap to2MiB including metadata; enforce it before custody/send and test overflow rather than assuming the reader’s inner cap covers the envelope. Reject overflow without truncated success. Logs contain request IDs/error classes/counts only, no inventory payload/token.

Transport follows only the explicitly supplied endpoint; reject redirects, origin changes and credentials in URLs. The experiment permits plaintext only for literal loopback endpoints in its test configuration. Do not add an app-wide arbitrary-HTTP exception to make tests pass. Production requires a separately selected authenticated HTTPS endpoint and token custody. Normal iOS networking permissions/ATS and device lifecycle behavior must be verified for that later destination.

## Meaningful isolated acceptance

Use red-green tests for the new round trip and missing target registration, without rerunning the accepted51field/graph fixtures as a substitute for transport tests.

- A real local client submits status, paginated item list, location/tag list and exact item show. Actual URLSession worker reads a seeded temporary ModelContext and returns source-backed IDs/values through the mailbox. Inspect request/delivery trace, not merely a fabricated result object.
- Two independently seeded stores/workers with different identities cannot answer each other’s request. Unknown/wrong credential, scope, request digest or client session is refused. Duplicate names do not change exact-ID routing.
- Stable adapter lifetime permits page2. Commit a synthetic change between pages and receive staleCursor. Restart the worker/session and reject old tokens instead of restarting silently at page1.
- Leave an unsaved edit in the supplied caller context; return pendingEdits and preserve that edit. Reader errors propagate as bounded typed failures, never empty success. One representative unavailable-store/error case exercises the envelope mapping; do not repeat every reader implementation check.
- Same ID/same request retries return retained result; same ID/different request fails. A late reply cannot satisfy a newer request. Expired/lost state gives an explicit unavailable/expired result, not success or an unannounced reread.
- Pause foreground processing, disconnect the fixture server and cancel the client. Pending/deadline/cancel states remain distinct; no reply is published by a cancelled old generation. No automatic polling survives session closure.
- Malformed/oversized/unknown/write requests fail before the reader; output overflow fails without partial success. Requests cannot select arbitrary files, URLs, code or model queries. Redirect attempts are rejected with a second disposable listener proving no credential/body delivery there.
- Build the actual iOS target for a generic simulator SDK destination without booting or launching a simulator with the registered files and composition wiring. Execute transport acceptance in the isolated injected test host without production boot side effects. No physical phone, real default store, iCloud documents or private backups are needed.

Run through Understudy under ordinary permissions. Do not take the screen without its existing user-approved lease. This slice has no new user interface; a physical foreground/lifecycle walkthrough belongs to later installed-device acceptance. Preserve actual red failures, independent source/protocol reviews, post-review tests and original canonical completion if root approves a build. Root should review this plan before arming anything.

## Bounded execution and evidence

Before implementation root must approve this complete plan, then arm its own new build/procedure. Red must show absent target membership and unavailable automatic round trip. Do not reseal or reopen completed read/mutation builds. Synthetic tests assert exact IDs/response bindings and traces rather than only exit codes. Record actual models/reader/transport/protocol/client/mailbox hashes, toolchain, request counts and effect boundaries.

Run protocol/coordinator fixture under Understudy160s and the actual multi-process loopback round trip under Understudy180s, with unique temporary directories, generated fixture credentials (never printed), OS-assigned ports, bounded stdout, explicit ready messages and process-group cleanup. Enforce actual assertion count so no-test success fails. Run only one live local fixture group at a time. Failures preserve results and perform exact owned cleanup; never kill unrelated processes. Failure/expiry tests may use injected clock/transport, but the successful status/list/show round trip and redirect non-delivery check use real loopback HTTP. No screen use and no public endpoint calls.

Unsigned app compile under Understudy600s, -jobs2, unique DerivedData, CODE_SIGNING_ALLOWED=NO, generic iOS Simulator destination, build only. Inspect scheme availability via read-only xcodebuild-list and use app scheme or explicit target/SDK with exact provenance. Current target deployment18.4/Swift5.0 and iPhone+iPad must remain supported. Do not run current hosted test target, install/open an app, change provisioning, fetch/update dependencies or delete shared caches. Host-load and owned-process check precedes the build; preserve existing unrelated compile failures and ask root about any prerequisite scope rather than weakening the build proof. Mac fixture runtime plus iOS compile is not an iOS-runtime or physical-lifecycle claim.

Freeze candidate after local checks; independent Astra/Fable review must cover both binding/transport and native owner/reader lifecycle. Retain normal permission review for any private-source transfer. Fix concrete blockers, rerun affected checks through Understudy, commit exact owned files, committed review and original new-build gates, then hand back for root integration. No production catalogue publication claiming installed access.

## Later user/device work and non-goals

Before live phone/session availability: select/deploy the host, design explicit authenticated pairing and credential custody/revocation, identify the installed app build and intended actual container, enable the foreground session on the device, and verify reachability/suspension/resume/expiry with user presence. Then prove separate fresh Claude and Codex discovery and real requested read against the paired device. Both clients need to distinguish waiting for the app from an empty inventory. User acceptance is not inferred from fixture success.

Read access adds no new approval ritual beyond ordinary authorization. Additions/removals still require their existing exact approval; ordinary edits retain existing rules. This proposal implements no mutation transport, creation, deletion/cascade, consent token, backup restore, CloudKit migration, push wake, background service, remote deployment, app onboarding UI or provider feature. Completed mutation/read library builds remain complete. Legacy UI mutation gaps are separate.

If root requires live automatic phone access as the next delivery rather than a local transport prototype, the host/pairing/device decisions must be included explicitly before building; app registration alone cannot satisfy that requirement.

## Step 1: Register and retain the app-owned reader

Compile the unchanged reader plus new typed owner/protocol into the actual application; initialize them from the app's same existing container, preserving behavior and context safety. The owner retains cursor scope across requests. No default data is opened by fixtures.

- The file `AllMyCrap/InventorySessionReads.swift` exists.
- The file `AllMyCrap/InventoryReadProtocol.swift` exists.
- The command `python3 tests/inventory_session_protocol.py` exits 0.

## Step 2: Automatically process bounded foreground read requests

Implement the actual URLSession worker, cancellation/generation behavior, read-only protocol and prototype authenticated mailbox/client. Preserve exact device/store/client/request/digest ownership and finite custody/waits. Make real synthetic client-to-worker-to-reader-to-client HTTP prove success and the named failure boundaries above.

- The file `AllMyCrap/InventoryForegroundReadWorker.swift` exists.
- The file `AllMyCrap/InventoryMailboxTransport.swift` exists.
- The file `tools/inventory_session/mailbox.py` exists.
- The file `tools/inventory_session/client.py` exists.
- The command `python3 tests/inventory_session_roundtrip.py` exits 0.

## Step 3: Prove actual iOS integration without launch or deployment

Compile the registered actual app target unsigned with the specified bounded build. Preserve actual build logs and byte-bound inputs. Record runtime testing on disposable SwiftData/loopback separately from app compile; claim no real app/device access.

- The file `reports/inventory-foreground-reads/IOS-BUILD.md` exists.
- The file `reports/inventory-foreground-reads/VALIDATION.md` exists.

## Step 4: Independently review and complete this exact source slice

Independent Astra/Fable source reviews, affected post-review Understudy tests, exact owned commit, committed review, original checkpoint/canonical completion, and truthful deployment limits are required. Preserve failed/held evidence. Parent owns primary integration and catalogue publication.

- The file `reports/inventory-foreground-reads/REVIEWS.md` exists.
- The file `reports/inventory-foreground-reads/HANDOFF.md` exists.
