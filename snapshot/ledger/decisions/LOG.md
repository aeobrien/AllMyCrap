# Decision Log

| # | Date | Decision | Context | Alternatives Considered |
|---|------|----------|---------|------------------------|
| 1 | Pre-ledger | Use SwiftData over Core Data | Modern persistence for SwiftUI-first app | Core Data, Realm, SQLite |
| 2 | Pre-ledger | Disable CloudKit sync, use iCloud Drive for backups only | Simpler architecture, avoids sync conflicts | CloudKit sync |
| 3 | Pre-ledger | JSON backup format (versioned) | Human-readable, portable, easy to debug | SQLite copy, binary plist |
| 4 | Pre-ledger | OpenAI API for voice-to-item transcription | Higher accuracy for item name extraction from speech | On-device Speech framework |
| 5 | Pre-ledger | Tinder-style UI for rapid plan assignment | Makes sorting hundreds of items feel quick and low-effort | Traditional list editing |
| 6 | Pre-ledger | Archive rather than delete actioned items | Preserves history, allows undo of real-world actions | Hard delete |
| 7 | Pre-ledger | Books as a special Item variant (not separate model) | Simpler data model, shared location/tag/plan logic | Separate Book model |

## Template

```
| # | YYYY-MM-DD | Decision summary | Why this was decided | What else was considered |
```
