# Story 106-1: Create tests-pass gate file with schema

**Status:** in_progress
**Phase:** finish
**Workflow:** trivial
**Repos:** pennyfarthing
**Branch:** feature/106-1-create-tests-pass-gate-file
**Jira:** MSSCI-15004
**Points:** 1

---

## Context

Create `pennyfarthing-dist/gates/tests-pass.md` as the first gate file. Uses `<gate name="tests-pass" model="haiku">` schema with `<purpose>`, `<pass>`, and `<fail>` blocks. Pass block instructs evaluator to report test count, coverage, branch status. Fail block reports failing test files/lines, uncommitted files, with recovery guidance.

## Acceptance Criteria

- [ ] Gate file exists at `pennyfarthing-dist/gates/tests-pass.md`
- [ ] Uses schema: `<gate name="tests-pass" model="haiku">`
- [ ] Has `<purpose>` block describing what this gate validates
- [ ] Has `<pass>` block with instructions to report test count, coverage, branch status
- [ ] Has `<fail>` block with instructions to report failing tests, uncommitted files, recovery guidance

## Technical Approach

- Create `pennyfarthing-dist/gates/` directory if it doesn't exist
- Author `tests-pass.md` as a structured markdown file with XML-style tags
- Schema should be clear enough for a haiku-model subagent to execute reliably
- The gate file is a prompt template that will be fed to a subagent during phase transitions

## Files

- `pennyfarthing/pennyfarthing-dist/gates/tests-pass.md` (NEW)

---

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/gates/tests-pass.md` - First gate file with tests-pass schema (NEW)

**Tests:** N/A (content-only file, no code tests applicable for a 1pt trivial story)
**PR:** #908 - feat(106-1): create tests-pass gate file with schema
**Branch:** feature/106-1-create-tests-pass-gate-file (pushed)

**All ACs met:**
- Gate file created at correct path with `<gate name="tests-pass" model="haiku">` root
- `<purpose>` describes post-implementation GREEN state verification
- `<pass>` instructs evaluator to check test suite, working tree, branch status with GATE_RESULT contract
- `<fail>` provides actionable recovery: failing test files/lines, uncommitted files, wrong branch

**Handoff:** To General Burkhalter for code review

---

## Reviewer Assessment

**Verdict:** APPROVED

**Schema compliance verified:** All FR-1 required elements present — `<gate name="tests-pass" model="haiku">`, `<purpose>`, `<pass>`, `<fail>` at `gates/tests-pass.md:1,3,9,43`
**GATE_RESULT contract verified:** `status`, `message`, `checks[]` match context-epic-106.md spec. Additive `gate` and `recovery` fields are useful extensions
**Content guidance verified:** Pass block covers test suite, working tree, branch status per context-epic-106.md:127-131. Fail block has three actionable recovery steps

| Severity | Issue | Location |
|----------|-------|----------|
| [LOW] | Skipped test ambiguity — pass template reports skipped count without instructing whether skipped tests should fail. Workflow YAML condition provides this context at runtime | `gates/tests-pass.md:34` |
| [LOW] | Test command assumes `pnpm test` from repo root. Multi-package repos may need adaptation. Evaluator has session context for this | `gates/tests-pass.md:13` |

**Handoff:** To Colonel Hogan for finish-story
