# Candidate02 validation after independent HTTP deadline finding

Independent Astra candidate01 BLOCK and its actual socket probe remain under reviews/astra-01. Our http-budget-red-01 independently failed all three cases (12.121s): silent incomplete headers, continuously trickled headers, continuously trickled body.

Repair: start an absolute three-second timer before request-line/header parsing, shutting down only the owned connection on expiry; ordinary handler finalization releases its capacity slot. Progress does not reset this deadline. Response writes handle the expected closed socket.

- http-budget-green-01: all17 Python cases PASS14.241s, including eight occupied slots per deadline case and healthy authenticated read recovery.
- roundtrip-08: all25 actual local client→URLSession worker→temporary SwiftData→reply assertions PASS23.149s after repair.
- protocol-05:30 native assertions and ios-build-02 actual unsigned app compile remain applicable: every Swift/project input is unchanged. No needless app rebuild.

Candidate02 has18 owned inputs, hashes in candidate-hashes-02.json; six unchanged reader/model hashes also rechecked. Only mailbox.py, the explanatory document and the new deadline test differ from candidate01. Prior candidate01 report copies and all failures remain. No Fable package was generated or transferred. Astra delta, Fable, post-review/committed/original gates remain outstanding.

# Frozen candidate01 validation

- protocol-05:30 assertions PASS8.933s. Actual compiled owner/protocol/worker/transport and temporary SwiftData; pending edit preservation, stable/stale cursor, exact IDs, distinct stores, unsupported/duplicate-key/binding refusal, endpoint guards, duplicate activation, cancelled late response and owner release.
- roundtrip-07:25 assertions PASS23.762s. Actual local Python client/mailbox → separately compiled actual Swift URLSession worker → actual reader/temp SwiftData → bound response.11 read publications. Status/item pagination/location+tag lists/exactshow/error/read retry/stale/pending edit/cancel/deadline/newscope/late ownership/no read mutations/owned process cleanup. Actual second listener received no credential/body during redirect probe; oversized/unauthorized URLSession replies refused.
- python-contracts-03:14 tests PASS2.130s. Role/store/client/digest/operation validation, duplicate/nonfinite/oversized input, completed retry offline/conflicting ID, cancelled reply, expiry/tombstones, liveness/scope reset, finite custody, response limits, malformed IDs; actual loopback wrong-role, redirect non-delivery and slow-body wall-clock timeout.
- ios-build-02:actual app compile/link PASS5.022s, after initial34.280s build. See IOS-BUILD.md and ios-product-proof.json. No simulatorboot/app/device launch.

Frozen17 owned inputs are in candidate-hashes-01.json. Original reader+five models match baseline57d255ce in unchanged-reader-models.json. Files copied to the test compiler are the maintained current inputs; no success-path reader or HTTP transport stub. Fake delayed transport is only for deterministic cancellation/owner-loss failure tests.

Failures preserved: red-01 missing actual app membership; roundtrip-red-01 missing consumer; compile-01 macro sandbox refusal (then normal host permissions approved); roundtrip-01/-03 final harness trace/count accounting faults; roundtrip-02 actual Swift/Python floating number byte-normalization fault corrected on responses while keeping canonical requests/duplicate-key refusal. Later total client body deadlines and weak owner across awaits have current direct and real regression evidence. No old receipt overwritten.

Not proved: iOS runtime/network/lifecycle, physicaldevice/installedapplication behavior, production authenticated host/pairing/durable storeidentity, foregrounduser acceptance, deployed sessiondiscovery, privateinventory, mutationoperations or background execution. The app consumer is unconfigured by default. Mailbox liveness follows4s grace; a sent HTTP request cannot be recalled but cannot satisfy a later request/scope. Deadline may leave a bounded pending read; it is not proof no read occurred.

Independent source reviews, post-review verification, sourcecommit/committedreview and original canonical gates remain outstanding.

Independent candidate02 delta:21 actual socket assertions PASS16.161s, including silent-before-request-line and8-slot recovery; reviews/astra-01/DELTA-02.md. Local Fable launcher6 synthetic tests PASS0.127s; no actual provider call.
