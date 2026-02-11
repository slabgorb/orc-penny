# Story 87-3: Add topology validation to pre-edit guide

**Epic:** 87 — Repo Topology & Agent Spatial Awareness
**Jira:** MSSCI-14787
**Points:** 1
**Priority:** P1
**Workflow:** tdd-tandem
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/87-3-topology-validation-pre-edit-guide
**Assigned:** Keith Avery

---

## Context

This story extends the dev agent guide to prevent targeting wrong files or wrong repos before edit operations. Story 87-1 added topology data to repos.yaml (ownership boundaries, never_edit zones, symlink mappings), and 87-2 will wire this into agent prime context. This story adds a pre-edit validation section to the dev agent guide that references the repos.yaml topology structure, helping agents verify file editability before making changes.

## Acceptance Criteria

- **Pre-edit check added to dev agent guide** — new section referencing repos.yaml topology schema with clear validation rules (check path is not in never_edit zones, verify file belongs to correct repo)
- **Worked examples of common mistakes** — at least 3 realistic examples showing mistakes agents should avoid (editing symlinked .pennyfarthing/ paths, attempting to edit node_modules, editing from wrong repo)
- **Guide text is clear and actionable** — written for agent consumption, explains WHY the checks matter (prevent wrong-repo/wrong-file errors), and HOW to use repos.yaml data

## Technical Notes

**Key files:**
- Dev agent guide: `pennyfarthing/pennyfarthing-dist/agents/dev.md` (source of truth)
- Repos topology: `repos.yaml` (orchestrator root)

**Repos topology schema (from story 87-1):**
- `owns` — glob patterns for directories repo is responsible for
- `never_edit` — off-limits paths (symlinks, build output, dependencies)
- `symlinks` — mapping of symlink paths → actual source locations
- `ui_layer` — rendering context (react | cli | none)
- `components_path` — where UI components live (optional)

**Current dev.md structure:**
- No pre-edit validation section exists
- Guide covers minimalist discipline, handoff markers, phase checks, delegation, workflow steps, self-review
- Insert pre-edit check as new section early in the guide (after role definition, before workflow details)

---

## TEA Assessment

**Tests Required:** No
**Reason:** Chore bypass — all 3 ACs are documentation updates to an agent guide markdown file (`dev.md`). No executable code, functions, or APIs to test. The "validation" is prose instructions for agents, not runtime logic.

**Bypass justification:**
- AC1: Add markdown section to dev.md → documentation
- AC2: Write worked examples in markdown → documentation
- AC3: Ensure guide text is clear → documentation quality

**Handoff:** To Dev for implementation (documentation writing)

---

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/agents/dev.md` — Added Pre-Edit Topology Check section (47 lines) with 3 validation rules and 4 worked examples

**Tests:** N/A (TEA chore bypass — documentation only)
**PR:** #820 — feat(87-3): add pre-edit topology validation to dev agent guide
**Branch:** feat/87-3-topology-validation-pre-edit-guide (pushed)

**ACs met:**
- AC1: Pre-edit check section added with rules for `never_edit`, `owns`, and `symlinks` validation
- AC2: 4 worked examples (symlinks, node_modules, wrong repo, build output) — exceeds 3 minimum
- AC3: BAD/FIX/WHY format with clear explanations of what breaks and how to fix it

**Handoff:** To Reviewer for code review

---

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** repos.yaml (disk) → prime loader (87-2) → agent context → dev agent reads rules → validates before editing (safe — no user input, controlled documentation)
**Pattern observed:** BAD/FIX/WHY format is excellent for agent-consumable documentation at `dev.md:33-64`
**Accuracy verified:** All 4 examples cross-referenced against actual repos.yaml — symlinks:35, never_edit:24+65, owns:19, dist:66
**Observations:** 1 LOW (absolute phrasing at `dev.md:23` — degrades gracefully when repos.yaml absent) — non-blocking

**Handoff:** To SM for finish-story

---

## Session Notes

Ready for TEA/Architect handoff for test planning.
- **Handoff to TEA:** 2026-02-11T00:00:00Z — Phase: red (tdd-tandem)
- **TEA bypass:** No tests needed — pure documentation update
- **Handoff to Dev:** 2026-02-11T00:00:00Z — Phase: green (tdd-tandem, chore bypass)
- **Handoff to Reviewer:** 2026-02-11T18:52:30Z — Phase: review (PR #820)
- **Reviewer APPROVED:** 2026-02-11 — PR #820 merged, phase: finish
