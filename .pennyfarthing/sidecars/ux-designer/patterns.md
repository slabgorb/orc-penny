# UX Designer Agent Patterns

<pattern name="component-spec">
Purpose → Variants (default/active/disabled/error) → States (idle/hover/focus/loading) → Accessibility (keyboard + screen reader).
</pattern>

<pattern name="collapsible-panel">
Collapsed panels: 20×60px expand button with vertical rotated label (`writing-mode: vertical-rl; transform: rotate(180deg)`). Same position as collapse button. Idle=muted, hover=accent.
</pattern>

<pattern name="cyclist-layout">
`#app-container` (flex row): file-panel → resize → diff-panel → resize → #main-content (message-view, tool-bar, editor) → #sidebar. Expand buttons absolute-positioned, visible when panels collapse.
</pattern>

<pattern name="message-width">
`.message-assistant p { max-width: 72ch }`. Use `max-width: min(72ch, 100%)` for responsive.
</pattern>

<pattern name="dark-theme-shadcn-bridge">
## shadcn + Cyclist Theme Integration

**The problem:** Two naming systems (Cyclist CSS vars + shadcn/Tailwind tokens) arm-wrestling. Specificity coin-flips cause invisible borders, dark-on-dark dialogs, and ghost progress bars.

**Variable alignment:** `tailwind.config.js` border maps to `var(--border-color)` but theme-system.css defines `--border`. Fix: `border: 'var(--border)'`. Remove hand-written utility classes in theme-system.css (`.bg-primary`, `.text-secondary`, `.text-muted` etc.) — Tailwind generates these from config, having both is a specificity conflict.

**Rule:** Always use explicit CSS variable references (`var(--border)`, `var(--text-secondary)`) in component className when Tailwind's mapping is ambiguous.
</pattern>

<pattern name="dialog-as-card">
## Dialogs Are Cards, Not Backgrounds

shadcn dialog default `bg-background` assumes light theme where background ≠ overlay. In Cyclist's dark theme, `bg-background` (#1a1a2e) against `bg-black/80` overlay is nearly invisible.

**Fix:** Dialogs use `bg-card` (#16213e) — visible step up from overlay. ToolDialog defaults: `bg-card border-[var(--border)] shadow-2xl shadow-black/40 max-h-[80vh] overflow-y-auto`.

Progress bar tracks: never `bg-primary/20` (invisible). Use `bg-[var(--border)]` or `bg-muted`.
</pattern>

<pattern name="tufte-data-dialogs">
## Tufte Principles for Debug/Data Dialogs

1. **Data-ink ratio:** Every pixel communicates data. No decorative borders/shadows that don't carry information.
2. **Rule lines, not boxes:** Use `border-b` separators between logical groups, not `border` around everything. Table headers get a single thin bottom border.
3. **Clear figure-ground:** Dialog must visually separate from overlay (see dialog-as-card pattern).
4. **Typography does the hierarchy work:**
   - Title: `text-base font-medium tracking-tight` (calm, authoritative)
   - Description: `text-sm text-[var(--text-secondary)]`
   - Table headers: `text-xs font-medium uppercase tracking-wider text-[var(--text-muted)]` with bottom rule line
   - Numbers: `tabular-nums text-right font-mono` always — let numbers align
   - Table cells: `text-sm text-[var(--text-primary)] py-1.5` — consistent vertical rhythm
5. **No italic for de-emphasis** — italics are emphasis. Use `text-[var(--text-muted)] text-xs` instead.
6. **Tab active state:** `border-b-2 border-[var(--accent)] bg-transparent` (underline, not highlight box).
7. **Empty states:** Centered text `py-12 text-[var(--text-muted)]`, hide table headers when count is 0.
8. **Error states:** Small card `p-4 rounded border border-[var(--status-error)]/20 bg-[var(--status-error)]/5`.
9. **Controls layout:** flex-wrap rows, `gap-x-4 gap-y-2`. Checkboxes need `gap-2` between input and label, `gap-x-6` between groups. Primary action (Analyze) right-aligned.
</pattern>
