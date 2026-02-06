# Story Context: MSSCI-14209

## Sprint Panel Story Metadata Indicators (context, jira, status)

**Epic:** MSSCI-14186 (Sprint Data Management)
**Points:** 3 | **Workflow:** tdd | **Priority:** P1

## Overview

Enhance the Sprint panel to display richer metadata for each story and epic, giving visibility into readiness state before attempting actions like archive.

## Status: Already Implemented

Investigation reveals these indicators are **already built** into `EnhancedSprintPanel`. The story should verify styling consistency with Cyclist design system.

## Key Files

| File | Purpose |
|------|---------|
| `packages/cyclist/src/public/components/panels/SprintPanel.tsx` | Panel implementation with all indicators |
| `packages/cyclist/src/sprint-data.ts` | Data fetching with context detection |
| `packages/cyclist/src/public/styles/tailwind.css` | Status badge styling |

## Existing Components

### StatusBadge (SprintPanel.tsx:148-160)
```tsx
<span className="story-status-badge {className}">
  {icon} // done(✓), in_progress(●), blocked(⚠), backlog(○)
</span>
```
- Test ID: `story-status-badge-{storyId}`

### JiraLink (SprintPanel.tsx:165-187)
```tsx
<a className="jira-link cyclist-link" href="https://1898andco.atlassian.net/browse/{jiraKey}">
  {jiraKey}
</a>
```
- Opens in new tab or Electron shell
- Test ID: `story-jira-link-{storyId}`

### ContextIndicator (SprintPanel.tsx:124-143)
```tsx
<span className="context-indicator has-context|no-context" data-has-context="true|false">
  📄  // or empty when missing
</span>
```
- Test IDs: `{epic|story}-context-indicator-{id}`

## Data Structure (sprint-data.ts)

```typescript
interface SprintStory {
  id: string;
  title: string;
  points: number;
  status: 'backlog' | 'in_progress' | 'done' | 'cancelled' | 'blocked';
  jiraKey: string | null;
  hasContext?: boolean;  // Detected via context file existence
}

interface SprintEpic {
  id: string;
  title: string;
  jiraKey: string | null;
  stories: SprintStory[];
  hasContext?: boolean;
}
```

## Context File Detection (sprint-data.ts:149-163)

- Epic: `sprint/context/context-epic-{number}.md`
- Story: `sprint/context/{storyId}-context.md`

## Status Badge Styling (tailwind.css:1310-1328)

| Status | Border Color |
|--------|--------------|
| backlog | `--text-secondary` (#8b8b8b) |
| in_progress | `--accent-color` (#007acc) |
| done | `--success-color` (#4ec9b0) |
| cancelled | `--error-color` (#f14c4c) + opacity 0.6 |

## Acceptance Criteria

- [x] Epic rows show context existence indicator
- [x] Story rows show Jira ticket as clickable link
- [x] Story status badges are visually distinct (done/todo/blocked/in_progress)
- [x] Context file existence shown for stories
- [ ] Consistent styling with Cyclist design system (verify)

## Notes

All infrastructure exists. Story scope is likely:
1. Verify visual consistency with design system
2. Add any missing test coverage
3. Polish indicator styling if needed
