# Story Context: 143-1 — Create native subagent definition for Dev in pennyfarthing-dist

## Summary

Create a native Claude Code subagent definition for the Dev agent. This is the first concrete step in the Native Subagent Migration epic (MSSCI-16358). The subagent definition will:

- Live at `pennyfarthing-dist/agents/native/dev.md`
- Be symlinked to consumer projects via `.claude/agents/dev.md`
- Enable Dev to function as a reusable Claude Code native subagent in other projects
- Follow the Claude Code `.claude/agents/*.md` format

The native subagent definition is a **markdown file with YAML frontmatter** (not an in-conversation prompt). It contains:
- Agent role and responsibilities
- Tool restrictions and capabilities
- Persona slot definition (for themed personas)
- Behavioral guidance and workflow instructions
- Extracted from the existing in-conversation agent definition at `pennyfarthing-dist/agents/dev.md`

## Technical Approach

### 1. Create Directory
```bash
mkdir -p pennyfarthing-dist/agents/native/
```

### 2. Extract from Existing Agent Definition
Read `pennyfarthing-dist/agents/dev.md` and extract:
- **Role:** Developer/implementer (from `<role>` section)
- **Discipline:** Minimalist discipline (from `<minimalist-discipline>` section)
- **Critical Guidance:** Pre-edit topology check, repository rules (from `<critical>` section)
- **Helpers:** Tool restrictions and delegation model (from `<helpers>` section)
- **Workflow:** Make tests GREEN (from `<workflow>` section)

### 3. Format as Native Subagent
Native subagent format (Claude Code `.claude/agents/*.md`):
```markdown
---
name: dev
type: strategic
persona_slot: true
tools:
  - code_editor
  - bash
  - file_search
  - git
restrictions:
  - never_edit_symlinks
  - topology_check_required
---

# Dev Agent — Implementation

[Role definition, discipline, capabilities, workflow, behavioral guidance]

## Tool Restrictions

- Write code, run tests, trace symlinks
- Check repository topology before editing
- Verify repo ownership and never_edit zones
- Report findings to session file

## Persona Slot

Accepts persona for Dev role (optional). Persona affects code style and explanation breadth.

## Workflow: Make Tests GREEN

[Implementation workflow from existing definition]
```

### 4. Key Sections to Include
- **Role:** Feature implementation, making tests pass
- **Minimalist Discipline:** Keep code simple, avoid unnecessary abstractions
- **Pre-Edit Topology Check:** Verify against repos.yaml before editing
- **Helpers & Delegation:** testing-runner for mechanical test execution
- **Workflow:** RED→GREEN→REFACTOR
- **Exit Protocol:** Assessment, delivery findings, handoff
- **Deviation Tracking:** Log implementation deviations from spec
- **Self-Review Gates:** Code review checklist before handoff

### 5. Symlink Registration
Register symlink in orchestrator's `.pennyfarthing/repos.yaml`:
```yaml
symlinks:
  - source: .claude/agents/dev.md
    target: pennyfarthing/pennyfarthing-dist/agents/native/dev.md
```

## Acceptance Criteria

- [x] Directory created
- [ ] Native subagent file created with valid YAML frontmatter
- [ ] Role and minimalist discipline documented
- [ ] Pre-edit topology check rules included
- [ ] Helpers and delegation model documented
- [ ] Workflow section (RED→GREEN→REFACTOR)
- [ ] Exit protocol and assessment template included
- [ ] Deviation tracking and delivery findings sections included
- [ ] Self-review gates checklist included
- [ ] File is valid Claude Code native subagent format
- [ ] Follows existing dev.md structure but adapted for native format
- [ ] Branch: `feat/143-1-native-subagent-dev-def` in pennyfarthing repo
- [ ] PR ready for review

## Related Files

- **Source:** `pennyfarthing/pennyfarthing-dist/agents/dev.md` (in-conversation definition)
- **Target:** `pennyfarthing/pennyfarthing-dist/agents/native/dev.md` (native subagent)
- **Symlink:** `.pennyfarthing/agents/dev.md` → `pennyfarthing/pennyfarthing-dist/agents/native/dev.md`
- **Reference:** `pennyfarthing/pennyfarthing-dist/agents/templates/agent-template-strategic.md` (strategic agent template)

## Dependencies

- [ ] Native subagent migration epic (MSSCI-16358) must be active
- [ ] Claude Code subagent format must be validated against local Claude Code version
- [ ] Symlink registration in orchestrator repos.yaml

## Notes

- Native subagents are **NOT** in-conversation prompts — they are reusable definitions
- They must be self-contained and work across different projects
- Persona slot allows consumer projects to pass their own personas
- Tool restrictions prevent common mistakes (symlink editing, topology violations)
