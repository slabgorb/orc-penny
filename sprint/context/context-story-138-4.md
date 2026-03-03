---
parent: context-epic-138.md
workflow: tdd
---

# Story 138-4: Extend TEA verify phase to spawn and aggregate simplify teammates

## Business Context

This is the core integration story that wires the three simplify agents into TEA's workflow. Without this, the teammates are isolated subagent definitions with no way to activate. Story 138-4 makes simplify automatic by injecting the fan-out/fan-in pattern into TEA's verify phase. When TEA enters verify, it reads changed files via `git diff`, spawns three Haiku teammates in parallel, collects their findings, applies clean wins, and commits fixes. The quality-pass gate then serves as a regression safety net. This story unblocks stories 138-5 (workflow YAML updates) and 138-6 (assessment template), and it's the most technically complex in the epic because it orchestrates parallel agent spawning, structured result aggregation, and sophisticated decision logic for applying or rejecting suggestions based on confidence levels.

## Technical Guardrails

**Agent Role & Parallelism:**
- TEA is the Opus-class team leader that orchestrates the fan-out/fan-in pattern during verify
- Teammates (`simplify-reuse`, `simplify-quality`, `simplify-efficiency`) are Haiku-class subagents spawned with `run_in_background: true`
- Follow the fan-out/fan-in pattern documented in `pennyfarthing-dist/patterns/fan-out-fan-in-pattern.md` — identify independent work (each teammate analyzes the same files but through a different lens), spawn in parallel, collect results via `TaskOutput`, aggregate into a unified decision structure

**Changed File Discovery:**
- Use `git diff --name-only <base-branch>` to identify files changed in the current story
- Filter out non-code files (images, configs, lockfiles) — only pass source code to teammates
- The file list is the same for all three teammates; each team member analyzes through its own specialized lens

**Result Format & Aggregation:**
- Each teammate returns a `SIMPLIFY_RESULT` YAML block (defined in story 138-7, `context-story-138-7.md`)
- SIMPLIFY_RESULT structure: `agent`, `status` (clean | findings), `findings[]` with `file`, `line`, `category`, `description`, `suggestion`, `confidence`
- Confidence levels: `high` = auto-apply, `medium` = review manually, `low` = review manually (likely reject)
- Aggregate results into a unified report; apply `high` suggestions automatically, review `medium`/`low` with human judgment

**Regression Safety & Rollback:**
- After applying any simplify fixes, re-run quality checks locally (lint, typecheck, tests) BEFORE the formal quality-pass gate
- If changes introduce test failures, rollback the offending suggestion and document in the assessment
- The existing quality-pass gate serves as the final safety net — unchanged from current TDD workflow behavior
- Preserve the opposition dynamic: Dev creates, TEA tests, Reviewer critiques. Simplify is constructive (improve what Dev wrote), not adversarial

**Commit Discipline:**
- If simplify makes changes, commit with message: `refactor: simplify code per verify review`
- Each suggestion applied should be auditable — consider including rationale in commit or session notes

## Scope Boundaries

**In scope:**
- Modifying `pennyfarthing-dist/agents/tea.md` to add verify-phase teammate spawning logic
- Changed file discovery using `git diff --name-only` with non-code filtering
- Spawning three teammates via Agent tool with `run_in_background: true` and collecting results via `TaskOutput`
- Aggregating SIMPLIFY_RESULT blocks from all three teammates into a unified findings structure
- Decision logic: apply `high`-confidence suggestions automatically, manually review `medium`/`low`-confidence suggestions
- Rerunning quality checks after applying changes; reverting changes if tests fail
- Committing fixes if any suggestions are applied
- Integration with the existing quality-pass gate (no changes to the gate definition itself)
- Documenting simplify results in TEA's session assessment

**Out of scope:**
- Creating the three subagent definitions (`simplify-reuse.md`, `simplify-quality.md`, `simplify-efficiency.md`) — those are stories 138-1, 138-2, 138-3
- Modifying the workflow YAML files (`tdd.yaml`, `tdd-tandem.yaml`) to add the `team:` block — that's story 138-5
- Updating the TEA assessment template to display simplify report — that's story 138-6
- Defining the SIMPLIFY_RESULT format specification — that's story 138-7
- Quality-pass gate definition — unchanged from current behavior (no modifications needed)
- Metrics, dashboards, or historical tracking — those are growth features (post-MVP)

## AC Context

1. **TEA verify activation** — When TEA enters the verify phase and the workflow YAML includes a `team:` block with simplify teammates, TEA spawns the teammates (rather than running verify in isolation)

2. **Changed file discovery** — TEA runs `git diff --name-only` against the base branch (main for orchestrator, develop for pennyfarthing) to identify changed files; filters out non-code files (*.png, *.jpg, *.lock, node_modules/*, .env, etc.); passes the resulting list to all three teammates

3. **Parallel teammate spawning** — TEA spawns all three simplify teammates simultaneously using the Agent tool with `run_in_background: true`, each with the file list and a prompt to analyze through its specific lens (reuse, quality, efficiency); no blocking — TEA continues immediately

4. **Result collection** — TEA collects results from all three teammates via `TaskOutput` with a reasonable timeout (60-120 seconds); handles partial failure gracefully (if one teammate times out, proceed with results from the other two)

5. **Structured result parsing** — Each result is parsed as SIMPLIFY_RESULT YAML; extracts `agent`, `status`, and `findings[]` array from each teammate

6. **Aggregation and decision logic** — TEA builds a unified findings structure across all three teammates; categorizes each finding by confidence level:
   - `high`: TEA auto-applies the suggestion (edits the file inline)
   - `medium`: TEA flags for manual review; includes in assessment; does NOT auto-apply without explicit decision
   - `low`: TEA flags for manual review; likely rejects; includes in assessment with rationale

7. **Change application** — If any `high`-confidence suggestions are auto-applied, TEA modifies the affected files and commits with message: `refactor: simplify code per verify review`

8. **Regression detection** — After committing changes (if any), TEA re-runs quality checks:
   ```bash
   npm run lint          # ESLint
   npm run typecheck     # TypeScript
   npm test              # Unit tests
   ```
   If any check fails, TEA reverts the simplify commit, re-runs quality checks to confirm they pass, documents the revert in the assessment with the root cause

9. **Quality-pass gate execution** — After simplify is complete (changes applied and tested, or no changes made), the existing quality-pass gate executes as normal; gate is unmodified; if gate fails, it fails the verify phase (not a simplify regression — indicates a deeper issue)

10. **Assessment documentation** — TEA writes a Simplify Report section in its TEA Assessment (see story 138-6 for template format); includes:
    - Summary of findings per teammate (reuse, quality, efficiency)
    - Applied suggestions with counts
    - Rejected suggestions with rationales
    - Any reverts due to test failures
    - Indicates "simplify: clean" if no teammates found issues

11. **Handoff** — After TEA completes verify (simplify done, quality-pass gate passed), TEA hands off to Reviewer with updated code and assessment including simplify report

**Testable criteria:**
- TEA correctly identifies changed files (manual test: check files passed to teammates match `git diff` output)
- Teammates are spawned in parallel and complete within reasonable time (< 60s typical)
- Results are correctly parsed and aggregated into a unified findings structure
- High-confidence suggestions are auto-applied and committed
- Medium/low-confidence suggestions are NOT auto-applied (only documented in assessment)
- Regressions are caught by quality-pass and changes reverted
- Assessment includes complete simplify report with applied/rejected counts
