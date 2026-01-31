# Story: MSSCI-12710 - FileTree Component

**Jira:** MSSCI-12710
**Epic:** 71 - Codebase Awareness (MSSCI-12709)
**Points:** 2
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Feature Branch:** feat/MSSCI-12710-filetree-component

---

## Story Context

Build a FileTree component for the Cyclist React UI that displays files modified during a Claude Code session. This is part of Epic 71 (Codebase Awareness) which enables users to see what files Claude modified, review diffs, and monitor context usage.

### Requirements

- Display list of modified files with full paths
- Show file status: created, modified, or deleted
- Group files by directory for organization
- Click handler to open file in DiffViewer component
- Badge showing total count of modified files
- Real-time updates as files change during session

### Technical Approach

This component will integrate with the existing Cyclist React architecture in `packages/cyclist/`. It should follow the patterns established by other components like DockingWorkspace.

### Related Components

- DiffViewer (71-2) - Will be opened when files are clicked
- ContextIndicator (71-3) - Shows context usage
- ApprovalModal (71-4) - Approval UI

---

## Acceptance Criteria

- [ ] FileTree displays modified files with paths and status indicators
- [ ] Files grouped by directory with collapsible sections
- [ ] Click on file opens DiffViewer
- [ ] Badge shows count of modified files
- [ ] Component updates in real-time when files change
- [ ] Tests cover all interactions and state changes

---

## TEA Assessment

**Tests Required:** Yes
**Reason:** New UI component with user interactions

**Test Files:**
- `packages/cyclist/tests/71-1-filetree.test.tsx` - 39 failing tests
- `packages/cyclist/src/public/components/FileTree.tsx` - Stub implementation

**Tests Written:** 39 tests covering 6 ACs
| AC | Tests | Coverage |
|----|-------|----------|
| AC1: Display files with status | 7 | File rendering, status indicators, empty state |
| AC2: Directory grouping | 7 | Grouping, collapsible sections, badges |
| AC3: Click opens DiffViewer | 6 | Click handler, keyboard support |
| AC4: Badge with count | 5 | Count display, tooltip, accessibility |
| AC5: Real-time updates | 6 | Prop changes, state preservation |
| Edge cases + A11y | 8 | Long paths, special chars, ARIA |

**Status:** RED (39 failing - ready for Dev)

**Handoff:** To Lucius Vorenus (Dev) for implementation

---

## Session Log

### Setup (SM)
- Jira synced: Epic MSSCI-12709, Story MSSCI-12710
- Story moved to In Progress
- Branch created: feat/MSSCI-12710-filetree-component
- Handoff to TEA for test design

### RED Phase (TEA)
- 39 failing tests written covering all ACs
- Stub component created for import resolution
- Tests verify: file display, directory grouping, click handling, badges, real-time updates, accessibility
- Commit: c760330cd
- Handoff to Dev for implementation

### GREEN Phase (Dev)

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/public/components/FileTree.tsx` - Complete FileTree implementation
- `packages/cyclist/tests/71-1-filetree.test.tsx` - Minor test fix for React focus events

**Tests:** 39/39 passing (GREEN)
**PR:** #578 - feat(cyclist): FileTree component for codebase awareness
**Branch:** feat/MSSCI-12710-filetree-component (pushed)

**Implementation Details:**
- FileTree component with directory grouping
- Status indicators for created/modified/deleted files
- Collapsible directory sections with file counts
- Click handler with onFileClick callback
- Keyboard navigation (Enter, Space, Tab)
- ARIA tree structure for accessibility
- Focus state tracking and preservation

**Handoff:** To Marcus Tullius Cicero (Reviewer) for code review

### Review Phase (Reviewer)

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** files prop → groupFilesByDirectory → DirectorySection → FileItem → onFileClick callback (safe, no XSS)

**Observations:**
| # | Type | Description | Location |
|---|------|-------------|----------|
| 1 | `[VERIFIED]` | Tests pass - 39/39 GREEN | tests/71-1-filetree.test.tsx |
| 2 | `[VERIFIED]` | useRef for focus preservation | FileTree.tsx:229 |
| 3 | `[VERIFIED]` | Optional chaining on callbacks | FileTree.tsx:121, 128 |
| 4 | `[VERIFIED]` | Defensive status handling | FileTree.tsx:64, 89, 116 |
| 5 | `[LOW]` | Inline style preference | FileTree.tsx:206 |
| 6 | `[VERIFIED]` | ARIA tree structure | FileTree.tsx:145, 186-187 |
| 7 | `[VERIFIED]` | Keyboard accessibility | FileTree.tsx:124-132 |

**Error handling:** Null/undefined status defaults to 'modified', empty array shows "No files changed"
**Security:** No XSS risk - file paths rendered as text, not HTML

**PR #578 merged.** Handoff to SM for finish-story.
