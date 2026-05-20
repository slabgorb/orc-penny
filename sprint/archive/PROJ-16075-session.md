# Session: 138-2 — Create simplify-quality subagent definition

## Story
- **ID:** 138-2 / PROJ-16075
- **Epic:** 138 — Simplify Integration
- **Title:** Create simplify-quality subagent definition
- **Points:** 1
- **Priority:** p0
- **Workflow:** trivial (direct implementation, no TDD)
- **Assignee:** Keith Avery
- **Status:** active

## Acceptance Criteria

The story is complete when:
- [ ] File `pennyfarthing-dist/agents/simplify-quality.md` exists and follows the tactical template structure
- [ ] Agent definition clearly describes what files it receives and what it analyzes for
- [ ] Output format section shows the SIMPLIFY_RESULT YAML structure with representative fields
- [ ] Responsibilities include semantic quality analysis (naming, readability, structure, dead code, comments)
- [ ] Explicitly excludes lint rules — focuses on semantic quality only
- [ ] Confidence levels (high/medium/low) are documented with TEA's decision rules
- [ ] The agent can be invoked via Agent tool with parameters: file list, story context (optional)
- [ ] No code modifications — the definition explicitly states "Report only. Do NOT edit files."
- [ ] Finding categories: naming, readability, structure, dead-code, comments
- [ ] Definition can be read and used as a foundation for the TEA integration (story 138-4)

## Implementation Notes

**Status:** File simplify-quality.md already exists at `/Users/keithavery/Projects/pf-1/pennyfarthing/pennyfarthing-dist/agents/simplify-quality.md`

**Key Differences from simplify-reuse:**
- simplify-reuse focuses on code duplication and extraction opportunities
- **simplify-quality focuses on semantic code quality** — naming, readability, structure, dead code, unnecessary comments
- Explicitly NOT about linting rules (eslint/ruff territory)

**Finding Categories for simplify-quality:**
- `naming-inconsistency` — Variable/function/file naming breaks conventions
- `architecture-violation` — Wrong dependency direction or layer crossing
- `error-handling-gap` — Missing or inconsistent error handling
- `type-safety-issue` — Weak typing, unchecked casts, missing null guards
- `dead-code` — Unused imports, unreachable branches, commented-out code
- `convention-violation` — Breaks project-specific conventions

**Model:** Haiku (per Rule 7)
**Report-only:** No file modifications

## Phase: implement

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/agents/simplify-quality.md` - Added explicit lint exclusion to responsibilities

**Tests:** N/A (agent definition file, no code tests)
**Branch:** feat/PROJ-16075-simplify-quality-subagent (pushed)

**AC Verification:**
- [x] File exists, tactical template structure
- [x] Input/output contracts documented (FILE_LIST, SIMPLIFY_RESULT)
- [x] Semantic quality focus: naming, architecture, error handling, type safety, dead code, conventions
- [x] Explicit lint exclusion added
- [x] Confidence levels with TEA decision rules
- [x] Report-only, no file modifications
- [x] Example invocation for TEA integration
- [x] Structurally consistent with simplify-reuse.md

**Handoff:** To Reviewer (Zorg) for review phase

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** TEA reads agent def → spawns with FILE_LIST → agent reads files → produces SIMPLIFY_RESULT → TEA aggregates. Contract well-defined.
**Pattern observed:** Consistent subagent structure matching simplify-reuse at `pennyfarthing-dist/agents/simplify-reuse.md`
**Error handling:** N/A (definition file, not code)
**Observations:**
- [LOW] Stray `</output>` tag at `simplify-quality.md:161` — orphaned, no matching open tag
- [MEDIUM] AC categories refined from spec (naming/readability/structure/dead-code/comments → 6 more specific categories) — improvement, not defect
- [VERIFIED] Template structure, lint exclusion, report-only, SIMPLIFY_RESULT format, confidence levels, example invocation
**Handoff:** To Ruby Rhod (SM) for finish-story

## Delivery Findings

<!-- findings-start -->
### Dev (implementation)
- No upstream findings during implementation.

### Reviewer (code review)
- **Improvement** (non-blocking): Stray `</output>` tag at end of `simplify-quality.md`. Affects `pennyfarthing-dist/agents/simplify-quality.md` (remove orphaned closing tag at line 161). *Found by Reviewer during code review.*
<!-- findings-end -->

## SM Assessment

**Routing:** Trivial workflow → Korben Dallas (Dev) for implement phase.

**Key context for Dev:**
- File `pennyfarthing/pennyfarthing-dist/agents/simplify-quality.md` already exists — verify it meets all ACs
- Compare against `simplify-reuse.md` (138-1, completed) for structural consistency
- Finding categories differ from reuse: naming, architecture, error-handling, type-safety, dead-code, convention
- 1-point story — verify existing file, adjust if needed, done