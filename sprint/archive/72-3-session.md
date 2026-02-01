# Session: 72-3 - PersonaHeader Catchphrase and Badge Improvements

**Story:** 72-3
**Epic:** MSSCI-12465 (Cyclist UX Polish)
**Points:** 1
**Workflow:** trivial
**Phase:** approved
**Jira:** None (quick feature)
**Repos:** pennyfarthing
**Feature Branch:** feat/persona-catchphrase-and-badge

## Acceptance Criteria
- [ ] Random catchphrase displays in PersonaHeader matching current agent
- [ ] Agent role pill is positioned next to portrait image (more prominent)
- [ ] Agent role pill is color-coded by agent type

## Feature Requirements

### 1. Random Catchphrase Display
- Show a random catchphrase in the PersonaHeader
- Catchphrases come from theme files (`pennyfarthing-dist/personas/themes/*.yaml`)
- Each agent in a theme has a `catchphrases` array
- Match catchphrase to the currently displayed persona/agent
- Pick randomly on component mount or agent change

### 2. Agent Badge Improvements
- Move agent role pill next to persona portrait (currently after character name)
- Color-code the pill based on agent type
- Reference Claude CLI statusbar for agent color theme

## Technical Context

### Key Files
- PersonaHeader: `packages/cyclist/src/public/components/PersonaHeader.tsx`
- usePersona hook: `packages/cyclist/src/public/hooks/usePersona.ts`
- Theme files: `pennyfarthing-dist/personas/themes/*.yaml` (e.g., princess-bride.yaml)
- CLI statusbar colors: Check `pennyfarthing-dist/` or packages for agent color definitions

### Theme File Structure (example from princess-bride.yaml)
```yaml
agents:
  dev:
    character: Inigo Montoya
    role: The Spaniard who implements with singular dedication
    catchphrases:
      - "Hello. My name is Inigo Montoya. You killed my father. Prepare to die."
      - "You keep using that word. I do not think it means what you think it means."
      - ...
```

### Current PersonaHeader Data (from usePersona)
- `persona.character` - Character name (e.g., "Inigo Montoya")
- `persona.theme` - Theme name (e.g., "princess-bride")
- `persona.role` - Role/agent type (e.g., "dev")
- `persona.slug` - Agent slug for portraits

### Implementation Notes
- The persona hook already provides `role` which maps to agent type
- Catchphrases need to be loaded from theme file or passed via IPC
- Agent colors should be consistent with CLI statusbar for recognition

## SM Handoff Notes
- Trivial workflow: Direct to Dev (skip TEA)
- Fun UI enhancement - no formal tests required
- Focus on visual polish and personality

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/public/components/PersonaHeader.tsx` - Added catchphrase display, moved role badge to portrait group, added AGENT_COLORS map matching CLI statusbar
- `packages/cyclist/src/public/hooks/usePersona.ts` - Added `quote` field to PersonaData interface
- `packages/cyclist/src/public/styles/tailwind.css` - New `.persona-portrait-group` wrapper, vertical layout for `.persona-info`, catchphrase styling
- `packages/cyclist/tests/MSSCI-12700-persona-header.test.tsx` - Updated tests to match empty state behavior

**Tests:** 35/35 passing (PersonaHeader tests)
**PR:** #592 - feat(cyclist): PersonaHeader catchphrase and color-coded badge
**Branch:** feat/persona-catchphrase-and-badge (pushed)

**Implementation Details:**
1. **Catchphrase**: The backend already provides `quote` (random catchphrase) via `getCurrentPersona()`. Added to PersonaData interface and displayed in italics below theme name.
2. **Role Badge Position**: Created new `persona-portrait-group` wrapper to position badge at bottom of portrait image using absolute positioning.
3. **Agent Colors**: Extracted colors from `statusline.sh` and created AGENT_COLORS map for dynamic inline styling.

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Review Status:** Approved (manual testing)
**PR:** #592
**Merge Status:** Ready to merge

**Manual Testing:**
- Catchphrase displays correctly in PersonaHeader
- Theme name humanized and positioned next to character name
- Role badge color-coded and positioned at bottom of portrait

**Handoff:** To SM for story completion
