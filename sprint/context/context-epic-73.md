# Epic Context: Visual Customization & Accessibility

## Epic
- **ID:** epic-73
- **Jira:** [PROJ-12767](https://slabgorb.atlassian.net/browse/PROJ-12767)
- **Title:** Visual Customization & Accessibility

## Vision
Users can customize their visual experience and use the application with assistive technology. WCAG AA compliance.

## Stories
| ID | Jira | Title | Points | Priority |
|----|------|-------|--------|----------|
| 73-1 | PROJ-12768 | Color Palette System | 2 | P1 |
| 73-2 | PROJ-12769 | Font Customization | 2 | P1 |
| 73-3 | PROJ-12770 | Responsive Breakpoints | 2 | P2 |
| 73-4 | PROJ-12771 | Accessibility Compliance | 3 | P2 |

## Technical Context

### Package Location
`pennyfarthing/packages/cyclist/` - Electron app with React UI

### Existing Theme Infrastructure

**Primary Theme File:** `src/public/css/theme-system.css`

Comprehensive CSS custom properties already defined:
- **UI Colors:** `--bg-primary`, `--bg-secondary`, `--bg-tertiary`, `--text-primary`, `--text-secondary`, `--text-muted`, `--accent`, `--accent-hover`, `--border`, `--border-focus`, `--shadow`
- **Panel Colors:** `--sidebar-bg`, `--message-bg`, `--tool-bg`, `--header-bg`, `--footer-bg`
- **Status Colors:** `--status-success`, `--status-warning`, `--status-error`, `--status-info`
- **Terminal Colors:** Full 16-color palette for terminal compatibility
- **Syntax Highlighting:** Keywords, strings, numbers, comments, functions, etc.
- **Fonts:** `--font-ui` (system fonts), `--font-mono` (monospace)

**Theme Browser:** `src/public/css/theme-browser.css`
- Tier-based theming (S/A/B/U tiers)
- Dark mode via `@media (prefers-color-scheme: dark)`
- Card system with hover/selected states

### Existing Accessibility Patterns

**ARIA Already Implemented:**
- `role="tablist"`, `role="tab"`, `role="tabpanel"` in DockingWorkspace
- `aria-selected`, `tabIndex` management
- `aria-label` on interactive elements
- `aria-live="polite"` on PersonaHeader
- `aria-hidden="true"` on decorative icons
- `.visually-hidden` class for screen reader text

**Keyboard Navigation:**
- Arrow key navigation between tabs (DockingWorkspace)
- Enter/Escape handling (ApprovalModal)
- Focus management with `useRef` and `.focus()`

### Design Patterns

**Spacing Scale:** 2px, 4px, 6px, 8px, 12px, 16px
**Border Radius:** 3px (small), 4px (standard), 6px (large), 8px (modal)
**Transitions:** `0.15s ease` (standard), `0.3s ease` (theme/layout)

**Color Contrast (Status):**
- Success: #22c55e (green)
- Warning: #eab308 (amber)
- Error: #ef4444 (red)
- Info: #3b82f6 (blue)

### Story-Specific Implementation Notes

#### 73-1: Color Palette System
- **Foundation exists:** CSS variables in theme-system.css
- **Add:** Theme selector dropdown, 3 presets (Midnight/Daylight/High Contrast)
- **Persist:** Use `config.local.yaml` for per-project settings
- **Pattern:** Follow existing `@media (prefers-color-scheme: dark)` approach but make switchable via JS

#### 73-2: Font Customization
- **Foundation exists:** `--font-ui` and `--font-mono` variables
- **Add:** Font picker component, size scale (Tailwind-like: xs/sm/base/lg/xl)
- **Presets:** System, Inter, JetBrains Mono, Fira Code
- **Persist:** Global (not per-project)

#### 73-3: Responsive Breakpoints
- **Current state:** No explicit breakpoints, uses `prefers-color-scheme` only
- **Add:** Breakpoint system (<1024px, 1024-1440px, >1440px)
- **Behavior:** Auto-collapse sidebars at <1024px, expand panels at >1440px
- **Min dimensions:** 800x600

#### 73-4: Accessibility Compliance
- **Current state:** Good ARIA foundation, needs audit
- **Add:** WCAG AA audit, 4.5:1 contrast verification
- **Add:** `prefers-reduced-motion` support
- **Add:** Skip links for main content
- **Add:** Screen reader announcements for streaming content

### Relevant Files
- `src/public/css/theme-system.css` - Core CSS variables
- `src/public/css/theme-browser.css` - Theme selection UI
- `src/public/css/tailwind.css` - Component styles
- `src/public/components/DockingWorkspace.tsx` - Main layout with ARIA
- `src/public/components/ContextIndicator/` - Status colors pattern
- `src/public/components/ApprovalModal/` - Modal accessibility pattern

### Testing Requirements
- Visual regression tests for theme switching
- Keyboard navigation tests
- Screen reader compatibility tests (VoiceOver, NVDA)
- Contrast ratio validation
- Responsive layout tests at breakpoints

### Dependencies
- Stories 73-1 and 73-2 can run in parallel
- Story 73-3 depends on 73-1 (color palette affects layout)
- Story 73-4 should run last as audit/refinement
