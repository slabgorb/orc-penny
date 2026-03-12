# Context: 143-2 — Native Subagent TEA and Reviewer Definitions

## Story Metadata
- **Story ID:** 143-2
- **Jira Key:** MSSCI-16360
- **Epic:** 143 — Native Subagent Migration (MSSCI-16358)
- **Title:** Create native subagent definitions for TEA and Reviewer in pennyfarthing-dist
- **Type:** Feature
- **Priority:** P0
- **Points:** 3
- **Workflow:** trivial

## Technical Approach

This story creates native `.claude/agents/tea.md` and `.claude/agents/reviewer.md` definitions that will be deployed at `.pennyfarthing/agents/` via symlink.

### Reference Pattern

The Dev agent definition at `pennyfarthing-dist/agents/native/dev.md` (created in PR #144) provides the template:

1. **YAML Frontmatter:**
   - `name:` Agent display name
   - `description:` Brief purpose
   - `model:` opus (for strategic agents)
   - `allowed-tools:` List of tools specific to the agent's role

2. **Content Structure:**
   - `<role>` block: Concise statement of the agent's responsibility
   - Role-specific discipline (e.g., `<minimalist-discipline>` for Dev)
   - Workflow section: Input → Output → Step-by-step process
   - Pre-Edit Topology Check: File safety checks (repos.yaml)
   - Helpers section: Delegation to subagents (if applicable)
   - Assessment/Handoff templates: Expected deliverables format

3. **Tool Restrictions (ADR-0037):**
   - TEA: Read, Glob, Grep, Bash, Write (test files only), Edit (test files only)
   - Reviewer: Read, Glob, Grep, Bash (read-only commands only)

### TEA Agent (`tea.md`)

**Role:** Test Engineer — writes failing tests that define feature requirements. Spawned by SM at workflow start (RED phase).

**Input:** User story with acceptance criteria (or feature description)
**Output:** Failing test suite (RED state), branch pushed

**Discipline:** Test-Driven Discipline
- Tests are the contract, not code
- Clarity over cleverness
- Assert ground truth, not implementation details
- Test names are documentation

**Workflow:**
1. Read session file for story context
2. Analyze acceptance criteria
3. Design test structure (files, test classes, test names)
4. Write failing tests that cover all ACs
5. Verify RED state (tests fail as expected)
6. Commit and push: `git add . && git commit -m "test(143-2): {description}"`
7. Write TEA Assessment to session file
8. Write handoff document to `.session/143-2-handoff-test.md`

**Key Sections to Match Dev Pattern:**
- Pre-test Topology Check (verify test file locations)
- Verify RED state (failing test suite)
- Refactor if needed (keep RED)
- TEA Assessment template (test count, coverage, branch)
- Delivery Findings (gaps, conflicts, questions)

### Reviewer Agent (`reviewer.md`)

**Role:** Code Reviewer — adversarially reviews code to find issues before production. Spawned after Dev (REVIEW phase).

**Input:** Dev's passing tests and implementation, dev branch
**Output:** Review findings (pass/fail/fix-required), branch comments

**Discipline:** Adversarial Mindset
- Assume bugs exist; hunt for them
- Severity-driven: CWE/OWASP/CVE > Logic > Style
- Find asymmetries: special cases, off-by-one, edge cases
- Question assumptions, not syntax

**Workflow:**
1. Read session file for story context and Dev handoff
2. Review acceptance criteria against implementation
3. Check test coverage (TEA and Dev gaps)
4. Scan for CWE/OWASP/CVE issues
5. Check design patterns (repos.yaml topology)
6. Write Review Assessment to session file
7. Write handoff document (findings, severity, recommendation) to `.session/143-2-handoff-review.md`
8. Recommendation: PASS, MINOR_FIXES, MAJOR_REWORK, BLOCK

**Key Sections to Match Dev Pattern:**
- Pre-review Topology Check (verify file locations)
- Review Checklist (severity levels, CWE, patterns)
- Reviewer Assessment template (findings count, severity distribution, recommendation)
- Delivery Findings (test gaps, logic errors, security issues)

## Acceptance Criteria

1. TEA definition created at `pennyfarthing-dist/agents/native/tea.md`
   - Follows Dev template pattern
   - Includes test-driven discipline block
   - Defines allowed-tools for test file write/edit only
   - Includes Pre-Test Topology Check section
   - Includes TEA Assessment template

2. Reviewer definition created at `pennyfarthing-dist/agents/native/reviewer.md`
   - Follows Dev template pattern
   - Includes adversarial mindset discipline block
   - Defines allowed-tools for read-only + bash
   - Includes Pre-Review Topology Check section
   - Includes Reviewer Assessment template

3. Both files follow agent definition conventions:
   - YAML frontmatter with proper metadata
   - Markdown sections with clear hierarchy
   - Consistent with agent-template-strategic.md guidance
   - Include workflow step-by-step instructions
   - Include assessment/handoff templates for SM consumption

4. Files integrated into pennyfarthing-dist:
   - Deployed at runtime via `.pennyfarthing/agents/` symlink
   - Tested that files are readable and valid YAML/Markdown
   - Committed to feat/143-2 branch

## Related Files

- **Reference:** `pennyfarthing-dist/agents/native/dev.md` (created in PR #144)
- **Agent template:** `pennyfarthing-dist/agents/templates/agent-template-strategic.md`
- **ADR:** `docs/adr/0037-native-subagent-migration.md`
- **Gate patterns:** `pennyfarthing-dist/gates/tea-entry.md` and `pennyfarthing-dist/gates/dev-entry.md`
