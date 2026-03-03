---
parent: 138
workflow: tdd
---

# Story 138-4: Extend TEA verify phase to spawn and aggregate simplify teammates

## Business Context

This is the integration story — the core of the simplify feature. TEA already owns the verify phase in TDD workflows, running quality checks after Dev's implementation. This story extends TEA to spawn three Haiku simplify teammates in parallel (fan-out), collect their structured findings (fan-in), make apply/reject decisions, commit fixes, and handle regressions via the quality-pass gate. Without this integration, the three subagent definitions (138-1, 138-2, 138-3) are inert files.

This is the highest-effort story in the epic (2 points) because it touches TEA's core verify behavior and requires careful orchestration of parallel agents with error handling.

## Technical Guardrails

- **Modify:** `pennyfarthing-dist/agents/tea.md` — add verify-phase teammate spawning and aggregation logic
- **Pattern:** Fan-out/fan-in per `pennyfarthing-dist/patterns/fan-out-fan-in-pattern.md`
- **Spawning:** Use Agent tool with `run_in_background: true` and `model: "haiku"`
- **Collection:** Use `TaskOutput` to gather results from background agents
- **Changed file discovery:** `git diff --name-only` against base branch, filter non-code files
- **Commit message:** `refactor: simplify code per verify review` when applying fixes
- **Regression safety:** If quality-pass gate fails after simplify changes, revert offending change and re-run gate
- **Partial failure tolerance:** If a teammate fails or times out, proceed with available results (per fan-out/fan-in pattern)
- **Do NOT modify:** quality-pass gate definition, Reviewer agent, workflow YAML (story 138-5)

## Scope Boundaries

**In scope:**
- TEA agent definition update with new verify-phase behavior
- Changed file discovery via `git diff --name-only` with non-code file filtering
- Parallel spawning of three simplify teammates with `run_in_background: true`
- Result collection and aggregation via `TaskOutput`
- Apply/reject decision logic based on confidence levels (high = auto-apply, medium/low = manual review)
- Commit simplify fixes with standardized commit message
- Regression detection and rollback when quality-pass gate fails post-simplify
- Teammate failure handling (log and proceed)

**Out of scope:**
- Subagent definitions (stories 138-1, 138-2, 138-3)
- Workflow YAML `team:` block additions (story 138-5)
- Assessment template update (story 138-6)
- SIMPLIFY_RESULT format definition (story 138-7)
- Changes to quality-pass gate behavior

## AC Context

1. **Changed file discovery works** — TEA runs `git diff --name-only` and filters to code files only (excludes images, lockfiles, configs). Edge case: if no code files changed, skip simplify entirely and note "no code changes" in assessment
2. **Three teammates spawned in parallel** — TEA uses Agent tool with `run_in_background: true` for all three simplify agents. Each receives the same filtered file list. Verify they run as Haiku models
3. **Results collected and aggregated** — TEA uses `TaskOutput` to collect `SIMPLIFY_RESULT` YAML from each teammate. Handles the case where a teammate returns `status: clean` (no findings)
4. **Confidence-based decisions** — `high` confidence findings are auto-apply candidates; `medium` and `low` are reviewed manually by TEA. TEA documents reasons for rejecting any finding
5. **Fixes committed correctly** — If changes applied, TEA commits with message `refactor: simplify code per verify review`
6. **Regression safety works** — If quality-pass gate fails after simplify changes, TEA reverts the simplify commit, re-runs gate, and documents the regression in assessment. Edge case: multiple simplify changes where only one causes regression
7. **Partial failure tolerance** — If a teammate fails/times out, TEA logs the failure in the assessment and proceeds with results from the other teammates. All three failing should not block verify phase completion
8. **Assessment includes simplify findings** — TEA writes a summary of what each teammate found and what was applied/rejected (detailed format in story 138-6)
