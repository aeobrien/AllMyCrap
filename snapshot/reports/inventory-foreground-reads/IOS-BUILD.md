# Actual iOS app target compiled, not launched

Understudy ios-build-01 PASS34.280s. After the worker owner-release correction, actual affected target build ios-build-02 PASS5.022s. Xcode scheme AllMyCrap was confirmed by xcode-list.json. Both builds used generic iOS Simulator, configurationDebug, CODE_SIGNING_ALLOWED=NO, -jobs2, -disableAutomaticPackageResolution and the same uniquely owned temporary DerivedData. No simulator boot, app launch, physical device, signing/provisioning change, real store or deployment.

The actual product contains compiled InventoryReadAdapter/InventoryReadProtocol/InventorySessionReads/InventoryMailboxTransport/InventoryForegroundReadWorker objects; ios-product-proof.json records their paths and the binary hash with exact app source hashes. Mac fixture execution is separate from this iOS compile proof. Existing hosted empty test target was not run.
