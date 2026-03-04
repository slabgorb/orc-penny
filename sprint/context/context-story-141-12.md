---
parent: context-epic-141.md
workflow: tdd
---

# Story 141-12: Remove as-any from UI Components

## Business Context

Four BikeRack UI components carry `as any` casts that bypass TypeScript's strict type checker. The React frontend (`packages/cyclist/src/public/`) is compiled under `tsconfig.vite.json` with `"strict": true`, so these casts are active suppressions of compiler safety — not gaps in coverage. Each cast hides a real typing problem: panel ID narrowing that could silently accept unknown strings, filter callbacks that erase the known `CriteriaItem` and `TodoItem` shapes, a message group prop mismatch between `MessageData[]` and `SubagentMessage[]`, and Electron API calls that were never removed when Electron was deprecated. Eliminating these casts makes the component contracts self-documenting and ensures future refactors (panel additions, type changes in hooks) are caught at compile time rather than at runtime in the browser.

## Technical Guardrails

**Files to change:**
- `pennyfarthing/packages/cyclist/src/public/components/DockviewWorkspace.tsx` — two `as any` casts at lines 132–133 inside `restorePanel()`, used with `Array.includes()` against typed const arrays
- `pennyfarthing/packages/cyclist/src/public/components/panels/ProgressPanel.tsx` — four inline `: any` annotations in filter/find/map callbacks at lines 73, 79, 81, 121
- `pennyfarthing/packages/cyclist/src/public/components/MessageView.tsx` — one `as any` cast at line 238 on `group.messages` passed to `<SubagentSpan messages={...} />`
- `pennyfarthing/packages/cyclist/src/public/components/panels/SprintPanel.tsx` — three `(window as any).electronAPI` accesses at lines 202, 468, 469, 496, 497 (and the surrounding dead Electron branch)

**Key types already defined (do not redefine):**
- `PanelId` — `typeof PANEL_INVENTORY[keyof typeof PANEL_INVENTORY]` exported from `DockviewWorkspace.tsx`
- `LEFT_SIDEBAR_PANELS` / `RIGHT_SIDEBAR_PANELS` — `as const` tuple arrays of `PanelId` literals in `DockviewWorkspace.tsx`
- `CriteriaItem` — `{ text: string; completed: boolean }` from `pennyfarthing/packages/cyclist/src/story-parser.ts`, re-exported by `hooks/useStory.ts`
- `WorkflowPhase` — `{ name: string; label: string; status: 'done' | 'current' | 'pending' }` from `src/story-parser.ts`
- `TodoItem` — `{ id: string; content: string; activeForm: string; status: 'pending' | 'in_progress' | 'completed'; ... }` from `hooks/useTodos.ts`
- `SubagentMessage` — extends `MessageData` with required `parent_id`, defined in `src/public/types/message.ts`
- `SubagentGroup` — local interface in `MessageView.tsx` with `messages: MessageData[]` — this is the mismatch with `SubagentSpan`'s `messages: SubagentMessage[]` prop

**TypeScript config:** `tsconfig.vite.json` governs the public React tree (`"include": ["src/public/**/*.tsx", "src/public/**/*.ts"]`), `"strict": true`.

**Build command:** `cd pennyfarthing/packages/cyclist && npx tsc -p tsconfig.vite.json --noEmit`

**Test command:** `cd pennyfarthing/packages/cyclist && pnpm vitest run`

**Relevant test files:**
- `pennyfarthing/packages/cyclist/tests/MSSCI-14001-dockview-workspace.test.tsx` — covers `DockviewWorkspace` panel ID constants and `restorePanel`/`getClosedPanels` exports
- `pennyfarthing/packages/cyclist/tests/MSSCI-14188-split-progress-panel.test.tsx` — covers `ProgressPanel` AC/todo row rendering
- `pennyfarthing/packages/cyclist/tests/MSSCI-14189-enhanced-sprint-panel.test.tsx` — covers `SprintPanel`

**Key constraint:** The `SprintPanel` Electron branch already falls back to `window.open()` or a REST `fetch()` call when `electronAPI` is absent. Removing Electron references means removing the conditional `if (electronAPI?.shell?.openExternal)` guard entirely and keeping only the `window.open()` fallback (for `JiraLink`) and the REST calls (for `handleArchive`/`handlePromote`).

## Scope Boundaries

**In scope:**
- Replace `panelId as any` in `DockviewWorkspace.restorePanel()` with a proper `PanelId`-aware type guard or narrowed type assertion
- Replace `: any` callback annotations in `ProgressPanel.tsx` (lines 73, 79, 81, 121) with `CriteriaItem`, `TodoItem`, and `WorkflowPhase` types imported from their existing sources
- Fix the `group.messages as any` cast in `MessageView.tsx` by aligning `SubagentGroup.messages` type with `SubagentMessage[]` (or casting the array to `SubagentMessage[]` with a narrower, justified assertion)
- Remove `(window as any).electronAPI` references in `SprintPanel.tsx` — delete the dead Electron conditional branches and retain only the REST API calls (`fetch`) and `window.open()` fallback
- Verify `npx tsc -p tsconfig.vite.json --noEmit` completes with zero errors
- Verify `pnpm vitest run` passes for all existing tests

**Out of scope:**
- Changes to `packages/core/` — covered by Story 141-11
- Extracting `CriteriaItem`, `WorkflowPhase`, or `TodoItem` into a shared package — larger refactor
- Adding new test cases — existing coverage is sufficient for a type-only chore
- Changing any rendering logic, UI behavior, or REST API call patterns
- Removing the `window.open()` fallback in `JiraLink` — it is the correct non-Electron path
- Other components not named in the ACs (e.g., `ProgressPanel` split panels `ACPanel`, `TodoPanel`, `WorkflowPanel`)

## AC Context

**AC1: DockviewWorkspace.tsx panel ID assertions replaced with proper types**

In `restorePanel()` (lines 132–133), `panelId` arrives as `string`. `LEFT_SIDEBAR_PANELS` and `RIGHT_SIDEBAR_PANELS` are `readonly` tuples of `PanelId` literals. `Array.prototype.includes()` on a `readonly` typed tuple only accepts the element type, not `string` — hence the `as any` bypass.

The fix is to use a typed guard helper:

```typescript
function isPanelId(id: string, arr: readonly PanelId[]): id is PanelId {
  return (arr as readonly string[]).includes(id);
}
```

Then replace:
```typescript
const isLeftPanel = LEFT_SIDEBAR_PANELS.includes(panelId as any);
const isRightPanel = RIGHT_SIDEBAR_PANELS.includes(panelId as any);
```
with:
```typescript
const isLeftPanel = isPanelId(panelId, LEFT_SIDEBAR_PANELS);
const isRightPanel = isPanelId(panelId, RIGHT_SIDEBAR_PANELS);
```

Testable: `pnpm vitest run tests/MSSCI-14001-dockview-workspace.test.tsx` still passes; `tsc --noEmit` reports no errors in this file.

**AC2: ProgressPanel.tsx criteria/todo filtering properly typed**

Four callback annotations use `: any` because the hook return types are not imported. The fix imports the existing types and annotates correctly.

At the top of `ProgressPanel.tsx`, add:
```typescript
import type { CriteriaItem, WorkflowPhase } from '../../../story-parser.js';
import type { TodoItem } from '../../hooks/useTodos.js';
```

Then replace:
- Line 73: `criteria.filter((c: any) => c.completed)` → `criteria.filter((c: CriteriaItem) => c.completed)`
- Line 79: `todos.filter((t: any) => t.status === 'completed')` → `todos.filter((t: TodoItem) => t.status === 'completed')`
- Line 81: `todos.find((t: any) => t.status === 'in_progress')` → `todos.find((t: TodoItem) => t.status === 'in_progress')`
- Line 121: `phases.map((phase: any) => ...)` → `phases.map((phase: WorkflowPhase) => ...)`

All four types are already defined — no new interface needed. `criteria` is `CriteriaItem[] | null` (from `useStory`), `todos` is `TodoItem[]` (from `useTodos`), `phases` is `WorkflowPhase[] | null` (from `useStory`).

Testable: `pnpm vitest run tests/MSSCI-14188-split-progress-panel.test.tsx` still passes; `tsc --noEmit` reports no errors.

**AC3: MessageView.tsx message group assertion replaced with proper types**

`SubagentGroup` (local interface in `MessageView.tsx`) declares `messages: MessageData[]`. `SubagentSpan` expects `messages: SubagentMessage[]`. `SubagentMessage extends Omit<MessageData, 'parent_id'> & { parent_id: string }`. Every message in a `SubagentGroup` must have `parent_id` (that is the grouping key), so the cast is semantically correct but the type is wrong at the interface level.

Fix: update the local `SubagentGroup` interface:
```typescript
import type { MessageData, SubagentMessage } from '../types/message';

interface SubagentGroup {
  parent_id: string;
  type: string;
  name: string;
  messages: SubagentMessage[];  // was: MessageData[]
}
```

Then remove `as any` from line 238:
```typescript
messages={group.messages}  // was: messages={group.messages as any}
```

The grouping logic in `MessageView` already filters by `parent_id` presence, ensuring all items in a group have `parent_id`, so narrowing the type is safe.

Testable: `tsc --noEmit` reports no errors; existing message rendering tests pass.

**AC4: SprintPanel.tsx Electron API references removed**

Three usage sites in `SprintPanel.tsx` reference `(window as any).electronAPI`:

1. `JiraLink.handleClick` (line 202): conditional `if (api?.shell?.openExternal)` branch — remove the `try`/`catch` block, keep only `window.open(url, '_blank')`
2. `handleArchive` (lines 468–469): `if (typeof window !== 'undefined' && (window as any).electronAPI?.sprint?.archiveEpic)` branch — remove the conditional, keep only the `fetch('/api/sprint/archive-epic/${epicId}')` REST call
3. `handlePromote` (lines 496–497): same pattern as archive — remove Electron branch, keep only `fetch('/api/sprint/promote-epic/${epicId}')` REST call

After removal, the `try`/`catch` wrappers in `handleArchive` and `handlePromote` remain valid (they catch `fetch` errors). No `as any` references remain.

Testable: `pnpm vitest run tests/MSSCI-14189-enhanced-sprint-panel.test.tsx` still passes; `tsc --noEmit` reports no errors; no runtime behavior change in the web/GUI path.

**AC5: Build passes with strict type checking**

Run from `pennyfarthing/packages/cyclist/`:
```bash
npx tsc -p tsconfig.vite.json --noEmit
```

Zero TypeScript errors. This is the same config Vite uses for the production build (`"strict": true`, `"noImplicitAny"` enabled). The command covers all four changed files since they are under `src/public/`.
