# Candidate02: Astra passed; Fable package held

Original build inventory-foreground-reads-20261006 and procedure30d5670f-dece-47fa-a68d-bafae6ce2083 remain active. No commit, live install, app launch or external transfer.

Candidate01 had a real blocker: incomplete HTTP headers could occupy all8 worker slots indefinitely. Current candidate02 implements an absolute3-second owned-connection deadline starting before header parsing. It also closes trickling bodies/headers and releases slots for normal requests. Meaningful3-case red preserved; all17 Python tests and25 actual automatic loopback assertions now pass.

Read candidate-hashes-02.json (18 owned files), unchanged-reader-models.json and VALIDATION.md. Only mailbox.py and its documentation changed, plus tests/test_inventory_http_budget.py. Native/iOS bytes unchanged and prior evidence retained. Full original candidate01 report preserved as candidate01-HANDOFF.md. Astra delta has passed; the Fable package is prepared locally and held for root-controlled release/permission.

Update: Astra affected review PASS,21 independent checks16.161s, all24 hashes stable; see reviews/astra-01/DELTA-02.md. Fable package is now prepared locally under reviews/fable-preparation-01; exact payload129,099 bytes, SHA29e9777f8fca2405926c56567201bd844138d6e48699d25ce6119a40322dadee. No transfer/key load/price lookup. Root controls release/approval; original gates remain active.
