# Epic Context: Command & Navigation

## Epic
- **ID:** epic-72
- **Jira:** [MSSCI-12720](https://1898andco.atlassian.net/browse/MSSCI-12720)
- **Title:** Command & Navigation

## Vision
Users can navigate the entire application via keyboard, access any action through the command palette.

## Stories
| ID | Title | Points | Priority |
|----|-------|--------|----------|
| 72-1 | Command Palette | 3 | P0 |
| 72-2 | ModeSwitch Component | 1 | P1 |
| 72-3 | Keyboard Shortcut System | 2 | P1 |

## Technical Context

### Package Location
`pennyfarthing/packages/cyclist/` - Electron app with React UI

### Relevant Files
- `src/public/App.tsx` - Main React app entry point
- `src/public/components/` - React components
- `src/public/styles/` - CSS styling
- `src/preload.ts` - Electron preload (window.electronAPI)

### Design Patterns
- React functional components with hooks
- TypeScript for type safety
- CSS modules or inline styles
- Keyboard event handling via React

### Command Palette Requirements
1. **Trigger:** Cmd+Shift+P (Mac) / Ctrl+Shift+P (Windows)
2. **UI:** Modal overlay with search input
3. **Categories:** Panels, Navigation, Settings, Agents
4. **Features:**
   - Fuzzy search/filter
   - Show keyboard shortcuts
   - Recent commands at top
   - Enter executes, Escape closes
