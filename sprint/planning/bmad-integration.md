# Using Pennyfarthing with BMAD 6.0

## One-Liner

**BMAD plans. Pennyfarthing executes.**

They're complementary tools, not competing ones.

---

## The Handoff

```
BMAD (Phases 1-3)                    Pennyfarthing (Phase 4)
┌─────────────────────┐              ┌─────────────────────┐
│ Analysis            │              │ Implementation      │
│ • Brainstorming     │              │ • TDD workflow      │
│ • Research          │              │ • Sprint tracking   │
│ • Product Brief     │              │ • Agent orchestration│
├─────────────────────┤              │ • Code review       │
│ Planning            │              │ • Retrospectives    │
│ • PRD               │   Stories    │                     │
│ • UX Spec           │ ──────────►  │ /sprint work        │
├─────────────────────┤   (BDD ACs)  │ /tea → /dev → /rev  │
│ Solutioning         │              │                     │
│ • Architecture      │              │                     │
│ • Epics & Stories   │              │                     │
└─────────────────────┘              └─────────────────────┘
```

**Handoff artifact:** Story files with BDD acceptance criteria (Given/When/Then).

---

## What Each Tool Does

| BMAD (Planning Layer) | Pennyfarthing (Execution Layer) |
|-----------------------|---------------------------------|
| PRD creation | TDD workflow (TEA → Dev → Reviewer) |
| Architecture decisions | Sprint execution & tracking |
| Epic/Story breakdown | Agent orchestration |
| Implementation readiness gate | Real-time code review |
| UX specifications | Session management |
| Strategic planning | Tactical implementation |

**Division of labor:**
- **Management/PM** uses BMAD to define *what* to build
- **Developer** uses Pennyfarthing to execute *how* to build it

---

## How to Use Together

1. **PM creates artifacts in BMAD**
   - PRD with requirements
   - Architecture decisions
   - Stories with acceptance criteria

2. **Developer picks up story in Pennyfarthing**
   ```bash
   /sprint work PROJ-12345
   ```

3. **Pennyfarthing agents implement it**
   - TEA writes tests from BDD acceptance criteria
   - Dev implements to pass tests
   - Reviewer validates against architecture

4. **Code review references BMAD artifacts**
   - Architecture decisions enforced
   - Requirements traced to implementation

---

## Artifact Compatibility

| Artifact | BMAD Format | Pennyfarthing | Status |
|----------|-------------|---------------|--------|
| Stories | Markdown + YAML frontmatter | Native support | ✅ |
| Acceptance Criteria | BDD (Given/When/Then) | TEA consumes directly | ✅ |
| Architecture | Markdown with ADRs | Referenced in review | ✅ |
| Sprint tracking | YAML | `current-sprint.yaml` | ✅ |
| Project context | `project-context.md` | `/brownfield` produces same | ✅ |
| PRD | Markdown | Can create or consume | ✅ |

**100% format compatibility.** No conversion needed.

---

## Workflow Overlap (That's OK)

Pennyfarthing includes BMAD-style workflows locally:

| Workflow | Use Case |
|----------|----------|
| `/workflow start prd` | Quick local PRD when BMAD not available |
| `/workflow start architecture` | Local architecture decisions |
| `/workflow start epics-and-stories` | Break down work locally |

**These don't conflict.** Use BMAD's output when available, or Pennyfarthing's workflows for standalone work.

---

## FAQ

**Q: Do we need both tools?**

A: Yes. BMAD excels at collaborative planning with stakeholders. Pennyfarthing excels at disciplined implementation with AI agents. Different strengths for different phases.

**Q: Will they conflict?**

A: No. Pennyfarthing consumes BMAD artifacts as input. The handoff is clean: story files with acceptance criteria.

**Q: What if I want to do planning locally?**

A: Pennyfarthing has the same workflows. Use them standalone, or consume BMAD output when it exists.

**Q: Where do BMAD artifacts go?**

A: BMAD outputs to `_bmad-output/` or configured directories. Pennyfarthing reads from there or from story files directly.

**Q: Who owns what?**

| Role | Tool | Responsibility |
|------|------|----------------|
| PM/Management | BMAD | Define requirements, architecture, stories |
| Developer | Pennyfarthing | Implement, test, review, ship |

---

## Quick Reference

### Starting from BMAD artifacts

```bash
# BMAD produced stories in _bmad-output/
# Pick one up in Pennyfarthing:
/sprint work PROJ-12345

# TEA reads the BDD acceptance criteria
/tea

# Dev implements
/dev

# Reviewer checks against architecture
/reviewer
```

### Starting fresh (no BMAD)

```bash
# Use Pennyfarthing's built-in workflows
/workflow start prd
/workflow start architecture
/workflow start epics-and-stories

# Then implement
/sprint work next
```

---

## Summary

| Question | Answer |
|----------|--------|
| Are they compatible? | Yes, 100% |
| Do they compete? | No, they complement |
| Who uses BMAD? | PM/Management (planning) |
| Who uses Pennyfarthing? | Developers (implementation) |
| Handoff point? | Story files with BDD acceptance criteria |
