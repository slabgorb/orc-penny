# Story Context: 79-1 - Create ToolDialog shared component

## Summary

Create a new `ToolDialog` wrapper component at `components/dialogs/ToolDialog.tsx` that wraps the existing shadcn `Dialog` primitives with `max-w-5xl` sizing, `80vh` max-height with internal scroll, a configurable header title, and controlled `open`/`onOpenChange` props. This becomes the standard wrapper for all observatory tools (hotspots, future dependency audit, bundle analysis) that need wider dialog layouts than the default `max-w-lg` provided by shadcn's `DialogContent`.

## Current State

### Existing Dialog Primitives

The shadcn `Dialog` component is installed at `packages/cyclist/src/public/components/ui/dialog.tsx` (121 lines). It exports: `Dialog`, `DialogPortal`, `DialogOverlay`, `DialogTrigger`, `DialogClose`, `DialogContent`, `DialogHeader`, `DialogFooter`, `DialogTitle`, `DialogDescription`.

Key constraint: `DialogContent` (line 30-52) has a hardcoded default of `max-w-lg` in its className (line 39):

```tsx
"fixed left-[50%] top-[50%] z-50 grid w-full max-w-lg translate-x-[-50%] translate-y-[-50%] gap-4 border bg-background p-6 shadow-lg ..."
```

This is overridable via the `className` prop using Tailwind's `cn()` utility, which is the intended approach -- the shadcn primitive itself must not be modified.

### Existing Dialog Patterns

1. **ConfirmDialog** (`packages/cyclist/src/public/components/ConfirmDialog.tsx`, 168 lines): Built on `AlertDialog` (not `Dialog`), uses `AlertDialogContent` which also defaults to `max-w-lg`. Has a `useConfirmDialog` hook returning `{ isOpen, confirm, dialogProps }` for promise-based confirm/cancel flow. This is the closest existing pattern for controlled dialog state.

2. **ApprovalModal** (`packages/cyclist/src/public/components/ApprovalModal.tsx`): Uses shadcn `Dialog` primitives with WebSocket subscription, mounted directly in `App.tsx` (lines 295-302) with `isOpen`, `onApprove`, `onReject` controlled props.

### No `dialogs/` Directory

The directory `packages/cyclist/src/public/components/dialogs/` does not exist yet and must be created by this story.

## Target State

After implementation:

1. New directory: `packages/cyclist/src/public/components/dialogs/`
2. New file: `packages/cyclist/src/public/components/dialogs/ToolDialog.tsx`
3. The component wraps shadcn `Dialog` + `DialogContent` with:
   - `max-w-5xl` overriding the default `max-w-lg` (via `className` prop on `DialogContent`)
   - `max-h-[80vh]` to prevent viewport overflow
   - Internal scrollable content area (`overflow-y-auto`)
   - `DialogHeader` with a `title` prop rendered in `DialogTitle`
   - Built-in close button (already included by `DialogContent` from `ui/dialog.tsx` line 45-48)
   - Controlled `open` / `onOpenChange` props (same pattern as `ConfirmDialog`)
   - `children` slot for tool-specific content
4. Optionally, a barrel export at `packages/cyclist/src/public/components/dialogs/index.ts`

## Key Files

### Files to Create

| File | Location | What It Does |
|------|----------|--------------|
| `ToolDialog.tsx` | `pennyfarthing/packages/cyclist/src/public/components/dialogs/ToolDialog.tsx` | Shared wide dialog wrapper for observatory tools |
| `index.ts` | `pennyfarthing/packages/cyclist/src/public/components/dialogs/index.ts` | Barrel export for dialog components |

### Files to Read (Context / Reference)

| File | Location | Why |
|------|----------|-----|
| `dialog.tsx` | `pennyfarthing/packages/cyclist/src/public/components/ui/dialog.tsx` | shadcn Dialog primitives to wrap; understand `DialogContent` className pattern (line 39), exports (lines 109-120) |
| `ConfirmDialog.tsx` | `pennyfarthing/packages/cyclist/src/public/components/ConfirmDialog.tsx` | Reference for controlled `open`/`onOpenChange` pattern; `useConfirmDialog` hook pattern (line 131) |
| `ApprovalModal.tsx` | `pennyfarthing/packages/cyclist/src/public/components/ApprovalModal.tsx` | Reference for Dialog-based controlled component mounted in App.tsx |
| `utils.ts` | `pennyfarthing/packages/cyclist/src/public/lib/utils.ts` | `cn()` utility for className merging |

## Technical Approach

### 1. Create `dialogs/` directory and `ToolDialog.tsx`

```tsx
import React from 'react';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from '@/components/ui/dialog';
import { cn } from '@/lib/utils';

export interface ToolDialogProps {
  /** Whether the dialog is open */
  open: boolean;
  /** Callback when open state changes (close via X button, overlay click, Escape) */
  onOpenChange: (open: boolean) => void;
  /** Dialog title displayed in the header */
  title: string;
  /** Optional description below the title */
  description?: string;
  /** Additional className for DialogContent */
  className?: string;
  /** Tool-specific content */
  children: React.ReactNode;
}

export function ToolDialog({
  open,
  onOpenChange,
  title,
  description,
  className,
  children,
}: ToolDialogProps): React.ReactElement {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent
        className={cn('max-w-5xl max-h-[80vh] flex flex-col', className)}
      >
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
          {description && <DialogDescription>{description}</DialogDescription>}
        </DialogHeader>
        <div className="flex-1 overflow-y-auto">
          {children}
        </div>
      </DialogContent>
    </Dialog>
  );
}
```

Key design decisions:
- `max-w-5xl` overrides the default `max-w-lg` from `DialogContent` because `cn()` (which uses `tailwind-merge`) deduplicates conflicting Tailwind classes, keeping the last one
- `max-h-[80vh]` + `flex flex-col` on `DialogContent`, with `flex-1 overflow-y-auto` on the content div, ensures the header stays fixed while the body scrolls for large data tables
- The close button is already baked into `DialogContent` (line 45-48 of `ui/dialog.tsx`), so no additional close button is needed
- Radix Dialog handles Escape key dismiss and overlay click natively

### 2. Create barrel export

```ts
// dialogs/index.ts
export { ToolDialog } from './ToolDialog';
export type { ToolDialogProps } from './ToolDialog';
```

### 3. Testing

Write a unit test at `packages/cyclist/src/public/components/dialogs/__tests__/ToolDialog.test.tsx`:
- Verify dialog renders when `open={true}`
- Verify dialog does not render when `open={false}` (Radix removes DOM)
- Verify title prop renders in the dialog header
- Verify description prop renders when provided
- Verify `onOpenChange` is called when overlay/close button is clicked
- Verify children are rendered inside the scrollable container
- Verify the dialog has `role="dialog"` (Radix default)

Note: Radix Dialog renders in a portal, so use `screen.getByRole('dialog')` rather than checking container children directly.

## Acceptance Criteria

- `ToolDialog` component exists at `components/dialogs/ToolDialog.tsx`
- Component wraps shadcn `Dialog` with `max-w-5xl` sizing (not `max-w-lg`)
- Content area has `max-h-[80vh]` with internal scroll for overflow
- `title` prop renders in `DialogHeader` / `DialogTitle`
- `open` and `onOpenChange` controlled props work correctly
- Close button (X) and Escape key dismiss the dialog
- Children slot renders tool-specific content
- Component is exported from `dialogs/index.ts`
- Unit tests pass

## Dependencies

### Depends On

- None (first story in epic, no prerequisites)

### Depended On By

- **79-2** (Migrate HotspotsPanel into HotspotsDialog) -- HotspotsDialog wraps itself in ToolDialog
- **79-3** (Add tool launcher row to DebugPanel) -- DebugPanel imports HotspotsDialog which uses ToolDialog

## Risks / Open Questions

1. **Tailwind class deduplication:** The `cn()` utility (built on `tailwind-merge`) should correctly resolve `max-w-lg` (from DialogContent default) vs `max-w-5xl` (from ToolDialog override), keeping the latter. Verify this works with the project's specific `tailwind-merge` version. If not, an `!important` override (`!max-w-5xl`) may be needed -- a pattern already used in `ModeSwitch` per project memory.

2. **Scroll container height:** The `80vh` max-height is a heuristic. On very short viewports this may feel cramped. Consider whether this needs to be configurable via a prop or if a single value works for all observatory tools.

3. **DialogDescription accessibility:** Radix Dialog warns in the console if `DialogContent` is rendered without a `DialogDescription` (for screen reader accessibility). The `description` prop is optional, so when omitted, Radix may log a warning. Consider adding `aria-describedby={undefined}` to suppress this or making `description` required for ToolDialog consumers.

4. **CSS custom property theming:** The shadcn Dialog uses `bg-background` and `border` tokens that map to Cyclist's CSS variable bridge. Verify that the dialog renders correctly with Cyclist's 30+ color presets -- the overlay (`bg-black/80`) and content background should respect the active theme.
