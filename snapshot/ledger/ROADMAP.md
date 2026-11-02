# Roadmap

## Next Up

| Task | Milestone | Phase | Status | Effort |
|------|-----------|-------|--------|--------|

No active tasks. App is in maintenance mode — add tasks here as refinement needs arise.

---

## Phase 1: Core App (Complete)
**Status:** Done
**Definition of Done:** Functional home cataloguing app with location hierarchy, item management, tagging, and search.

### 1.1 — Data Model & Persistence
**Status:** Done
**Priority:** High
**Definition of Done:** SwiftData models for locations, items, tags with relationships and cascade deletes.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 1.1.1 | Location model with hierarchy | Done | Deep Focus | |
| 1.1.2 | Item model with plans and book support | Done | Deep Focus | |
| 1.1.3 | Tag model with colours | Done | Deep Focus | |
| 1.1.4 | Review history tracking | Done | Deep Focus | |
| 1.1.5 | Duplicate exclusion model | Done | Deep Focus | |

### 1.2 — Item & Location CRUD
**Status:** Done
**Priority:** High
**Definition of Done:** Full create/read/update/delete for items and locations, including bulk operations.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 1.2.1 | Location add/edit/delete | Done | Deep Focus | |
| 1.2.2 | Item add/edit/delete with plan assignment | Done | Deep Focus | |
| 1.2.3 | Bulk item add (with voice input) | Done | Deep Focus | OpenAI API |
| 1.2.4 | Bulk sub-location add | Done | Deep Focus | |
| 1.2.5 | Book detection and special handling | Done | Deep Focus | |

### 1.3 — Search & Browse
**Status:** Done
**Priority:** High
**Definition of Done:** Users can find items by name, tag, plan, or book fields.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 1.3.1 | Name search | Done | Deep Focus | |
| 1.3.2 | Tag browse/search | Done | Deep Focus | |
| 1.3.3 | Plan browse/search | Done | Deep Focus | |
| 1.3.4 | Book search | Done | Deep Focus | |

---

## Phase 2: Workflow Features (Complete)
**Status:** Done
**Definition of Done:** Tinder Mode, Action Mode, archive, duplicate detection, and backup all working.

### 2.1 — Tinder Mode (Quick Sort)
**Status:** Done
**Priority:** High
**Definition of Done:** Swipe-style rapid plan assignment with filters and undo.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 2.1.1 | Core card-based plan assignment | Done | Deep Focus | |
| 2.1.2 | Location filter | Done | Deep Focus | |
| 2.1.3 | Plan/tag/book filters | Done | Deep Focus | |
| 2.1.4 | Undo and skip | Done | Quick Win | |
| 2.1.5 | Move destination picker | Done | Deep Focus | |

### 2.2 — Action Mode & Archive
**Status:** Done
**Priority:** Normal
**Definition of Done:** Users can execute plans and archive completed items.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 2.2.1 | Action Mode grouped by plan | Done | Deep Focus | |
| 2.2.2 | Batch check-off and archive | Done | Deep Focus | |
| 2.2.3 | Archive view with filtering | Done | Deep Focus | |

### 2.3 — Data Safety
**Status:** Done
**Priority:** High
**Definition of Done:** Backup and restore via iCloud Drive, duplicate detection.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 2.3.1 | JSON backup to iCloud Drive | Done | Deep Focus | |
| 2.3.2 | Auto-backup on app lifecycle events | Done | Quick Win | |
| 2.3.3 | Restore from backup | Done | Deep Focus | |
| 2.3.4 | Duplicate detection with fuzzy matching | Done | Deep Focus | |
| 2.3.5 | Duplicate exclusion pairs | Done | Quick Win | |

---

## Phase 3: Refinement
**Status:** Todo
**Definition of Done:** Quality-of-life improvements based on ongoing use.

### 3.1 — UX Polish
**Status:** Todo
**Priority:** Normal
**Definition of Done:** Improvements identified through daily use are addressed.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| | (No tasks yet — add as needs arise) | | | |

---

## Reference

### Status Values
| Status | Meaning |
|--------|---------|
| Todo | Not yet started |
| In Progress | Actively being worked on |
| Blocked: [reason] | Cannot proceed — reason is one of: poorly-defined, too-large, missing-info, missing-resource, decision-required |
| Waiting | User's part done, waiting on external input |
| Done | Complete |
| Dropped | Deliberately abandoned |

### Effort Types
| Type | Description |
|------|-------------|
| Deep Focus | Sustained concentration, problem-solving, design work |
| Creative | Open-ended, generative, exploratory |
| Administrative | Organising, documenting, updating, filing |
| Communication | Discussions, reviews, feedback |
| Physical | Hands-on work, building, soldering |
| Quick Win | Small, low-effort, momentum-building |

### Priority
High / Normal / Low — milestones only. Tasks inherit from their milestone unless overridden.
