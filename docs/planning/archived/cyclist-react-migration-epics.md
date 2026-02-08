# Cyclist React Migration - Epics and Stories

**Source:** docs/planning/ux-design-specification.md
**Date:** 2026-01-31
**Author:** Gaius Octavian (Architect)

## Overview

Transform Cyclist from vanilla JS to React + shadcn/ui + Tailwind CSS, implementing flexible workspace layout while maintaining the sacred center message view.

## Requirements Inventory

### Functional Requirements

- FR1: MessageView with streaming text support
- FR2: Collapsible left/right sidebars with tabbed panels
- FR3: Panel drag-and-drop between sidebars
- FR4: Layout persistence per-project
- FR5: Command Palette (Cmd+Shift+P)
- FR6: DiffViewer with syntax highlighting
- FR7: FileTree showing changed files
- FR8: ContextIndicator with warning states
- FR9: ApprovalModal for tool permissions
- FR10: ModeSwitch (Plan/Manual/Accept)
- FR11: StatsStrip (context %, model, identity)
- FR12: PersonaHeader with portrait
- FR13: Color palettes (Midnight, Daylight, High Contrast)
- FR14: Font customization
- FR15: Responsive breakpoints

### Non-Functional Requirements

- NFR1: WCAG AA compliance
- NFR2: 100% keyboard navigable
- NFR3: ARIA labels on all interactive elements
- NFR4: 4.5:1 minimum contrast
- NFR5: Respect prefers-reduced-motion
- NFR6: Native app responsiveness
- NFR7: Never override system shortcuts
- NFR8: Screen reader support

## Epic List

### Epic 69: Core Conversation Experience
Users can have conversations with Claude using a React-based interface with streaming responses, markdown rendering, and tool call display.
**FRs covered:** FR1, FR11, FR12

### Epic 70: Flexible Workspace
Users can arrange their workspace - dragging panels between sidebars, collapsing what they don't need, and having the layout remembered per-project.
**FRs covered:** FR2, FR3, FR4

### Epic 71: Codebase Awareness
Users can see what files Claude modified, review diffs with syntax highlighting, and monitor their context usage.
**FRs covered:** FR6, FR7, FR8, FR9

### Epic 72: Command & Navigation
Users can navigate the entire application via keyboard, access any action through the command palette.
**FRs covered:** FR5, FR10
**NFRs:** NFR2, NFR7

### Epic 73: Visual Customization & Accessibility
Users can customize their visual experience and use the application with assistive technology.
**FRs covered:** FR13, FR14, FR15
**NFRs:** NFR1, NFR3, NFR4, NFR5, NFR6, NFR8

---

## Epic 69: Core Conversation Experience

### Story 69-1: React + Tailwind Build Pipeline

As a **developer**,
I want **the Cyclist Electron app to support React components with Tailwind CSS**,
So that **I can build the new UI using modern tooling**.

**Acceptance Criteria:**

**Given** the existing Cyclist Electron application
**When** I add a React component to the codebase
**Then** it compiles and renders correctly in the Electron window
**And** Tailwind CSS classes are applied and work as expected
**And** existing vanilla JS continues to function during migration
**And** hot reload works for development

**Points:** 2

---

### Story 69-2: MessageView Component with Streaming

As a **user**,
I want **to see Claude's responses stream in real-time with proper markdown rendering**,
So that **I can read the AI output as it's being generated**.

**Acceptance Criteria:**

**Given** a React-based MessageView component exists
**When** Claude sends a streaming response
**Then** text appears progressively (not all at once)
**And** markdown is rendered correctly (headings, code blocks, lists, links)
**And** code blocks have syntax highlighting
**And** tool call blocks are visually distinct
**And** the view auto-scrolls to follow new content
**And** scroll position is preserved if user scrolls up

**Given** a subagent is spawned during conversation
**When** the subagent messages are displayed
**Then** all messages from that subagent are visually grouped together
**And** the group is identified as a span with the subagent type/name
**And** the span is collapsible to reduce visual noise
**And** nested subagent spans are properly indented

**Points:** 5

---

### Story 69-3: StatsStrip Component

As a **user**,
I want **to see my context usage, current model, and identity info at a glance**,
So that **I know my session state without opening panels**.

**Acceptance Criteria:**

**Given** the StatsStrip component is rendered below the editor
**When** context usage changes
**Then** the percentage updates in real-time
**And** a mini-bar visualizes the usage
**And** warning colors appear at 70% (amber) and 90% (red)
**When** I look at the strip
**Then** I see: PWD, Jira user, GitHub user, model badge, context %

**Points:** 1

---

### Story 69-4: PersonaHeader Component

As a **user**,
I want **to see which agent persona is active with their portrait and character info**,
So that **I know who I'm working with and can quickly identify which project I'm in**.

**Acceptance Criteria:**

**Given** an agent is activated via `/agent` command
**When** the PersonaHeader renders
**Then** I see the agent's portrait image
**And** I see the character name and role
**And** clicking the portrait opens a persona popup with full details
**And** the header updates when switching agents

**Given** I have multiple Cyclist instances open across different projects
**When** each project has a different theme configured
**Then** the persona visuals (portraits, names, styling) are distinct per theme
**And** I can instantly identify which project window I'm looking at by the theme
**And** the theme colors/styling carry through the header for quick recognition

**Points:** 2

---

## Epic 70: Flexible Workspace

### Story 70-1: Docking System Foundation

As a **user**,
I want **a flexible panel system that replaces the fixed sidebar layout**,
So that **I can arrange my workspace to match my workflow**.

**Acceptance Criteria:**

**Given** FlexLayout or Dockview is integrated
**When** Cyclist renders
**Then** the message view remains fixed in the center (sacred, never moves)
**And** left and right sidebars support tabbed panels
**And** panels can be collapsed individually
**And** the docking system respects the existing panel inventory (Changed, Diffs, Debug, Sprint, Progress, Background, Git, Settings)

**Points:** 3

---

### Story 70-2: Panel Drag-and-Drop

As a **user**,
I want **to drag panels between sidebars and reorder tabs**,
So that **I can put frequently-used panels where I want them**.

**Acceptance Criteria:**

**Given** multiple panels exist in sidebars
**When** I drag a panel tab
**Then** a ghost preview shows where it will drop
**And** I can drop it in the other sidebar
**And** I can reorder tabs within the same sidebar
**And** drop zones highlight when dragging over them
**And** the message view center area rejects drops (cannot place panels there)

**Points:** 2

---

### Story 70-3: Layout Persistence

As a **user**,
I want **my panel arrangement to be remembered per-project**,
So that **I don't have to reconfigure every time I open Cyclist**.

**Acceptance Criteria:**

**Given** I have arranged my panels
**When** I close and reopen Cyclist for the same project
**Then** my panel positions are restored exactly
**And** my panel widths are restored
**And** collapsed/expanded states are restored
**And** layout is stored in `.pennyfarthing/config.local.yaml`

**Given** I open a different project
**Then** that project's layout loads (or default if none saved)
**And** each project maintains independent layout preferences

**Points:** 2

---

## Epic 71: Codebase Awareness

### Story 71-1: FileTree Component

As a **user**,
I want **to see a list of all files Claude has modified in the current session**,
So that **I know what changed without hunting through the conversation**.

**Acceptance Criteria:**

**Given** Claude modifies files during a conversation
**When** I look at the FileTree panel
**Then** I see all modified files listed with their paths
**And** each file shows its status (created, modified, deleted)
**And** files are grouped by directory
**And** clicking a file opens it in the DiffViewer
**And** a badge shows the total count of changed files
**And** the list updates in real-time as changes occur

**Points:** 2

---

### Story 71-2: DiffViewer Component

As a **user**,
I want **to see the exact changes Claude made to each file with syntax highlighting**,
So that **I can review and understand what was modified**.

**Acceptance Criteria:**

**Given** I select a file from the FileTree
**When** the DiffViewer renders
**Then** I see a side-by-side or unified diff view
**And** additions are highlighted in green
**And** deletions are highlighted in red
**And** syntax highlighting matches the file type
**And** I can navigate between hunks with keyboard (n/p or arrow keys)
**And** line numbers are visible
**And** I can toggle between partial (hunk) and full file view

**Points:** 3

---

### Story 71-3: ContextIndicator Component

As a **user**,
I want **to see my context window usage prominently displayed**,
So that **I can anticipate when I'll hit the limit and plan accordingly**.

**Acceptance Criteria:**

**Given** the ContextIndicator is visible
**When** context usage changes
**Then** the percentage updates in real-time
**And** a visual bar shows the fill level
**And** color changes at thresholds: green (<70%), amber (70-90%), red (>90%)
**When** context exceeds 90%
**Then** a subtle warning appears (not blocking)
**And** tooltip shows exact token count on hover

**Points:** 1

---

### Story 71-4: ApprovalModal Component

As a **user**,
I want **to review and approve tool executions with a clear preview of what will happen**,
So that **I can trust the AI's actions while maintaining control**.

**Acceptance Criteria:**

**Given** Claude requests permission to execute a tool
**When** the ApprovalModal appears
**Then** I see the tool name and a preview of the command/action
**And** I can approve with Enter key (keyboard-first)
**And** I can reject with Escape key
**And** destructive actions (delete, overwrite) have red accent and require explicit confirmation
**And** I have an "Always allow" checkbox for this tool type
**And** the modal does not block the conversation view entirely (side panel or overlay)

**Points:** 2

---

## Epic 72: Command & Navigation

### Story 72-1: Command Palette

As a **user**,
I want **to access any Cyclist action through a searchable command palette**,
So that **I can work efficiently without hunting through menus**.

**Acceptance Criteria:**

**Given** I am anywhere in the application
**When** I press Cmd+Shift+P
**Then** the command palette opens with a search input focused
**And** I can type to filter available commands
**And** commands are organized by category (Panels, Navigation, Settings, Agents)
**And** each command shows its keyboard shortcut (if any)
**And** I can execute a command with Enter
**And** Escape closes the palette
**And** recent commands appear at the top

**Points:** 3

---

### Story 72-2: ModeSwitch Component

As a **user**,
I want **a 3-way toggle to switch between Plan, Manual, and Accept modes**,
So that **I can control Claude's autonomy level quickly**.

**Acceptance Criteria:**

**Given** the ModeSwitch is visible in the editor toolbar
**When** I click a mode segment
**Then** the mode changes immediately
**And** a sliding highlight animates to the selected segment
**When** I press Cmd+1, Cmd+2, or Cmd+3
**Then** the mode switches to Plan, Manual, or Accept respectively
**And** tooltip on hover explains each mode's behavior
**And** current mode is visually distinct

**Points:** 1

---

### Story 72-3: Keyboard Shortcut System

As a **user**,
I want **consistent keyboard shortcuts that never conflict with system defaults**,
So that **I can navigate efficiently without unexpected behavior**.

**Acceptance Criteria:**

**Given** the keyboard shortcut system is implemented
**Then** system shortcuts are NEVER overridden (Cmd+R, Cmd+W, Cmd+Q, Cmd+T)
**And** Cyclist-specific actions use Cmd+Shift+* prefix
**And** panel focus uses Cmd+Shift+1/2/3...
**And** navigation uses Cmd+[ and Cmd+] for back/forward
**And** all shortcuts are documented in command palette
**And** shortcuts work regardless of which panel has focus

**Points:** 2

---

## Epic 73: Visual Customization & Accessibility

### Story 73-1: Color Palette System

As a **user**,
I want **to switch between color palettes (Midnight, Daylight, High Contrast)**,
So that **I can work comfortably in different lighting conditions and meet my accessibility needs**.

**Acceptance Criteria:**

**Given** I open the Settings panel
**When** I select a different palette
**Then** the entire UI updates immediately without restart
**And** Midnight (dark) is the default
**And** Daylight (light) provides a true light theme
**And** High Contrast meets WCAG AAA contrast requirements
**And** palette preference is stored per-project in `.pennyfarthing/config.local.yaml`
**And** CSS variables update to reflect the selected palette
**And** all components respect the palette (no hardcoded colors)

**Points:** 2

---

### Story 73-2: Font Customization

As a **user**,
I want **to choose my preferred UI and code fonts**,
So that **I can read comfortably with fonts I'm familiar with**.

**Acceptance Criteria:**

**Given** I open the Settings panel
**When** I change the UI font setting
**Then** all UI text updates to the selected font (System, Inter, or custom)
**When** I change the Code font setting
**Then** all code blocks and monospace text update (System mono, JetBrains Mono, Fira Code, or custom)
**And** font preferences persist globally (across all projects)
**And** font size scale follows Tailwind conventions (xs through 2xl)
**And** changes apply immediately without restart

**Points:** 2

---

### Story 73-3: Responsive Breakpoints

As a **user**,
I want **the UI to adapt gracefully when I resize the window**,
So that **I can work effectively at any window size**.

**Acceptance Criteria:**

**Given** window width < 1024px
**Then** sidebars auto-collapse to tabs only
**And** message view takes full width
**Given** window width 1024-1440px
**Then** default layout with moderate panel widths
**Given** window width > 1440px
**Then** comfortable spacing, expanded panels
**And** minimum window size of 800x600 is enforced
**And** transitions between breakpoints are smooth

**Points:** 2

---

### Story 73-4: Accessibility Compliance

As a **user with accessibility needs**,
I want **the application to be fully accessible via keyboard and screen reader**,
So that **I can use Cyclist effectively regardless of ability**.

**Acceptance Criteria:**

**Given** WCAG AA compliance is required
**Then** all interactive elements have ARIA labels
**And** focus indicators are visible on all focusable elements
**And** tab order is logical throughout the application
**And** color contrast is minimum 4.5:1 for all text
**And** `prefers-reduced-motion` is respected (no animations when set)
**And** screen reader announces streaming message updates appropriately
**And** skip links allow jumping between major regions (sidebar, message view, editor)

**Points:** 3

---

## Summary

| Epic | Title | Stories | Points |
|------|-------|---------|--------|
| 69 | Core Conversation Experience | 4 | 10 |
| 70 | Flexible Workspace | 3 | 7 |
| 71 | Codebase Awareness | 4 | 8 |
| 72 | Command & Navigation | 3 | 6 |
| 73 | Visual Customization & Accessibility | 4 | 9 |
| **Total** | | **18** | **40** |
