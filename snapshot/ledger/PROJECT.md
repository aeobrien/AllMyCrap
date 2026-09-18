# AllMyCrap — Ledger

> iOS home cataloguing app for tracking everything in the house, with Tinder-style sorting, bulk input, and iCloud backup.

## Status

**Lane:** personal
**Phase:** Maintenance / Refinement — app is functional and in active use
**Last updated:** 2026-04-04

## Overview

AllMyCrap is a SwiftUI + SwiftData iOS app for cataloguing household items. Items live in a hierarchical location tree (rooms contain sub-locations which contain items). Each item can be tagged, assigned a plan (Keep, Throw Away, Sell, Charity, Move, Fix), and archived once actioned. Books are a first-class item type with separate title/author fields.

### Core Features
- **Location hierarchy** — rooms > sub-locations, unlimited nesting depth
- **Item management** — add, edit, tag, assign plans, archive
- **Tinder Mode ("Quick Sort")** — swipe-style rapid plan assignment with filters (location, plan status, tags, books)
- **Action Mode** — view items grouped by plan, check them off, archive when actioned
- **Bulk input** — add multiple items or sub-locations at once (with OpenAI-powered voice transcription)
- **Book detection** — special handling for books with title/author parsing
- **Duplicate detection** — fuzzy matching with exclusion list
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
| Location hierarchy | Stable | Unlimited depth, cascade delete |
| Item CRUD | Stable | Including book variant |
| Tinder Mode | Stable | Location/plan/tag/book filters, undo, skip |
| Action Mode | Stable | Group by plan, check off, archive |
| Bulk input | Stable | Multi-item and multi-location, voice support |
| Search | Stable | Name, tag, plan, book search |
| Review tracking | Stable | Auto-expiry with configurable threshold |
| Backup/restore | Stable | iCloud Drive, auto-backup, versioned JSON format (v2) |
| Duplicate detection | Stable | Fuzzy matching with exclusion pairs |
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

- Last commit was 2026-02-09 (approximately). The app has been in steady use without code changes since then.
- Backup format is at version 2 (added archive fields, duplicate exclusions).
- The app stores an OpenAI API key in UserDefaults for bulk voice input.
