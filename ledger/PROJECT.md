# AllMyCrap — Ledger

> iOS home cataloguing app for tracking everything in the house, with Tinder-style sorting, bulk input, and iCloud backup.

## Status

**Lane:** personal
**Phase:** Maintenance / Refinement — app is functional and in active use
**Last updated:** 2026-11-02

## Overview

AllMyCrap is a SwiftUI + SwiftData iOS app for cataloguing household items. Items live in a hierarchical location tree (rooms contain sub-locations which contain items). Each item can be tagged, assigned a plan (Keep, Throw Away, Sell, Charity, Move, Fix), and archived once actioned. Books are a first-class item type with separate title/author fields.

### Core Features
- **Location hierarchy** — rooms > sub-locations, nested up to 15 levels
- **Item management** — add, edit, tag, assign plans, archive
- **Tinder Mode ("Quick Sort")** — swipe-style rapid plan assignment with filters (location, plan status, tags, books)
- **Action Mode** — view items grouped by plan, check them off, archive when actioned
- **Bulk input** — add multiple items or sub-locations at once (with OpenAI-powered voice transcription)
- **Book detection** — special handling for books with title/author parsing
- **Duplicate detection** — fuzzy matching with exclusion list
- **Inventory access** — bounded typed reads, validated moves, and approved removals
- **Item-name standardization** — OpenAI-powered bulk review and renaming
- **Search** — by name, tag, plan, or book-specific search
- **Review tracking** — mark locations as reviewed, auto-expire after configurable days
- **Backup/restore** — JSON backups to iCloud Drive, auto-backup on app resign/launch
- **Archive** — completed items preserved with their original plan

### Tech Stack
- Swift / SwiftUI
- SwiftData (local persistence, CloudKit disabled)
- iCloud Drive (backup storage only)
- OpenAI API (optional, for voice-to-item transcription)

## Data Model

| Model | Purpose | Key Relationships |
|-------|---------|-------------------|
| `Location` | Hierarchical container (rooms, shelves, drawers) | parent/children (self-referential), items |
| `Item` | A catalogued thing | location, tags, plan |
| `Tag` | Colour-coded label | items (many-to-many) |
| `ReviewHistory` | Audit trail for location reviews | location |
| `DuplicateExclusion` | Pair of items confirmed as not-duplicates | none (stores UUIDs) |

## Subsystems

| Subsystem | Status | Notes |
|-----------|--------|-------|
| Data model & persistence | Stable | SwiftData with 5 model types |
| Location hierarchy | Stable | Up to 15 levels (enforced on create and move), cascade delete |
| Item CRUD | Stable | Including book variant |
| Tinder Mode | Stable | Location/plan/tag/book filters, undo, skip |
| Action Mode | Stable | Group by plan, check off, archive |
| Bulk input | Stable | Multi-item and multi-location, voice support |
| Search | Stable | Name, tag, plan, book search |
| Review tracking | Stable | Auto-expiry with configurable threshold |
| Backup/restore | Stable | iCloud Drive, auto-backup, versioned JSON format (v2) |
| Duplicate detection | Stable | Fuzzy matching with exclusion pairs |
| Inventory access | Built, not connected | `InventoryReadAdapter.swift` provides bounded typed reads; `InventoryMutations.swift` validates moves and removals. A foreground worker (`InventoryForegroundReadWorker`, `InventoryMailboxTransport`, `InventorySessionReads`) is installed at launch, but no pairing source is installed, so its transport stays unconfigured (`AllMyCrapApp.swift`). |
| Item-name standardization | Available | OpenAI-powered bulk review and renaming from Settings |
| Archive | Stable | Preserves plan, filterable, restorable |

## Key Decisions

See [decisions/LOG.md](decisions/LOG.md) for the full decision log.

## Linked Projects

| Project | Relationship | Notes |
|---------|-------------|-------|

## Open Questions

- Should CloudKit sync be reconsidered for multi-device use, or is iCloud Drive backup sufficient?
- Is the OpenAI dependency for voice input still the best approach, or could on-device speech recognition replace it?
- Any UX friction points discovered through ongoing use?

## Notes

- Checked 2026-11-03: code changed after February (inventory access, 6 to 15 Oct 2026); the latest commit is a 2 Nov doc fix. `InventoryReadAdapter.swift` and `InventoryMutations.swift` are present; the foreground transport has no pairing source.
- Backup format is at version 2 (added archive fields, duplicate exclusions).
- The app stores an OpenAI API key in UserDefaults for bulk voice input.
