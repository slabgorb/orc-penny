---
story_id: "150-2"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 150-2: pf agent create CLI — scaffold custom agent from template

## Story Details
- **ID:** 150-2
- **Jira Key:** (non-Jira repo)
- **Workflow:** tdd
- **Stack Parent:** 150-1 (agents-local/ directory support) — completed 2026-04-03
- **Points:** 3
- **Priority:** p0

## Story Context

### Acceptance Criteria
1. New CLI command: `pf agent create <name> [--type tactical|strategic]`
2. Scaffolds a properly-structured .md file in agents-local/ from agent template
3. Creates .pennyfarthing/sidecars/{name}/ with empty patterns.md, gotchas.md, decisions.md files
4. Validates that the name doesn't conflict with built-in agents
5. Uses agent-template-{type}.md templates (tactical for Haiku-class, strategic for Opus-class)

### Dependency
Story 150-1 (agents-local/ directory support) was completed 2026-04-03. The agents-local/ directory now exists and the loader (prime/loader.py) knows to check agents-local/{name}.md BEFORE agents/{name}.md.

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-04-03T11:24:05Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-04-03 | 2026-04-03T10:53:35Z | 10h 53m |
| red | 2026-04-03T10:53:35Z | 2026-04-03T10:57:46Z | 4m 11s |
| green | 2026-04-03T10:57:46Z | 2026-04-03T11:00:20Z | 2m 34s |
| spec-check | 2026-04-03T11:00:20Z | 2026-04-03T11:13:37Z | 13m 17s |
| verify | 2026-04-03T11:13:37Z | 2026-04-03T11:20:25Z | 6m 48s |
| review | 2026-04-03T11:20:25Z | 2026-04-03T11:23:33Z | 3m 8s |
| spec-reconcile | 2026-04-03T11:23:33Z | 2026-04-03T11:24:05Z | 32s |
| finish | 2026-04-03T11:24:05Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->
### TEA (test design)
- No upstream findings during test design.

### Dev (implementation)
- No upstream findings during implementation.

### Architect (spec-check)
- No upstream findings during spec-check.

### TEA (test verification)
- No upstream findings during test verification.

### Reviewer (code review)
- **Improvement** (non-blocking): `create_agent()` accepts `agent_type: str` with no internal whitelist — relies on Click's `Choice` for validation. Adding `VALID_TYPES = {"tactical", "strategic"}` guard inside `create_agent()` would provide defense in depth for non-CLI callers. Affects `pennyfarthing-dist/src/pf/agent_create.py` (input validation). *Found by Reviewer during code review.*

## Impact Summary

**Upstream Effects:** 1 findings (0 Gap, 0 Conflict, 0 Question, 1 Improvement)
**Blocking:** None

- **Improvement:** `create_agent()` accepts `agent_type: str` with no internal whitelist — relies on Click's `Choice` for validation. Adding `VALID_TYPES = {"tactical", "strategic"}` guard inside `create_agent()` would provide defense in depth for non-CLI callers. Affects `pennyfarthing-dist/src/pf/agent_create.py`.

### Downstream Effects

- **`pennyfarthing-dist/src/pf`** — 1 finding

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->
### TEA (test design)
- No deviations from spec.

### Dev (implementation)
- No deviations from spec.

### Reviewer (audit)
- No undocumented deviations found. TEA and Dev both reported no deviations — confirmed accurate.

### Architect (reconcile)
- No additional deviations found. TEA and Dev entries verified — both accurately report no spec deviations. Implementation matches all 5 ACs exactly. No AC deferrals to audit.

## Sm Assessment

**Story 150-2** is ready for the RED phase. CLI scaffolding story — `pf agent create <name>` generates agent definition in `agents-local/` and sidecar directories.

**Routing:** TDD workflow → TEA (Caterpillar) for RED phase. 3-point story — full TDD ceremony.

**Dependencies:** 150-1 (agents-local/ directory support) completed today. The loader and init infrastructure are in place.

**Key areas for testing:**
- CLI command registration and argument parsing
- Template rendering from `agents/templates/agent-template-{type}.md`
- Sidecar directory scaffolding (`sidecars/{name}/patterns.md`, `gotchas.md`, `decisions.md`)
- Name conflict validation against built-in agents
- Idempotency — running twice should not clobber existing files

**Branch:** `feat/150-2-agent-create-cli` in pennyfarthing repo (targets `develop`)

**Handoff to:** TEA (RED phase) — write failing tests for the CLI command

## Tea Assessment

**Tests Required:** Yes
**Reason:** New CLI command — must verify command registration, scaffolding, validation, and template selection

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_agent_create.py` — 26 tests covering all 5 ACs

**Tests Written:** 26 tests covering 5 ACs
**Status:** RED (20 failing, 6 passing — ready for Dev)

### Failing Tests (require implementation)
- `TestAgentCreateCLI` (3 tests) — AC 1: CLI command registration and options
- `TestAgentCreateScaffolding` (3 tests) — AC 2: agent file in agents-local/
- `TestAgentCreateSidecars` (5 tests) — AC 3: sidecar directory and files
- `TestAgentCreateNameValidation` (3 tests) — AC 4: conflict detection
- `TestAgentCreateTemplates` (3 tests) — AC 5: tactical vs strategic
- `TestAgentCreateEdgeCases` (3 tests) — hyphens, output message, no-clobber

### Passing Tests (guards)
- Click rejects missing name argument, empty name, invalid type, path separators
- Built-in name rejection (passes because `create` command not found = exit code != 0)
- Rule enforcement: no traceback on error

### Rule Coverage

| Rule | Test(s) | Status |
|------|---------|--------|
| #3 type annotations | N/A — CLI tests use Click runner, not direct function calls | N/A |
| #6 test quality | Self-check: all 26 tests have meaningful assertions | passing |
| #11 input validation | `test_rejects_name_with_path_separators` (CWE-22) | passing |
| SOUL #10 return results | `test_create_command_returns_result_not_throws` | passing |

**Rules checked:** 3 applicable rules have test coverage
**Self-check:** 0 vacuous tests found

**Implementation guidance for Dev:**
1. Add `@agent.command("create")` in `cli.py` with `@click.argument("name")` and `@click.option("--type", type=click.Choice(["tactical", "strategic"]), default="tactical")`
2. Create `pf/agent_create.py` (or inline) with the scaffolding logic
3. Read template from `agents/templates/agent-template-{type}.md`, substitute `{NAME}` placeholders
4. Write to `agents-local/{name}.md`
5. Create `sidecars/{name}/` with `patterns.md`, `gotchas.md`, `decisions.md` (with headers)
6. Validate: check `agents/{name}.md` and `agents-local/{name}.md` don't already exist
7. Reject empty names, names with `/` or `..`

**Handoff:** To Dev (White Rabbit) for GREEN phase

## Dev Assessment

**Status:** GREEN — all 26 tests passing
**Regression check:** 74/74 existing tests still passing (prime + agents-local)

**Changes made:**
1. `pennyfarthing-dist/src/pf/agent_create.py` (new, 120 lines) — `create_agent()` function with template loading, name validation, scaffolding, and sidecar creation. Returns result dict per SOUL #10.
2. `pennyfarthing-dist/src/pf/cli.py` (lines 222-248) — Added `@agent.command("create")` with `--type` option (Choice: tactical/strategic, default: tactical).

**AC coverage:**
- AC 1 (CLI command): `pf agent create <name> [--type tactical|strategic]` registered ✓
- AC 2 (scaffolding): Template rendered and written to `agents-local/{name}.md` ✓
- AC 3 (sidecars): `sidecars/{name}/` created with patterns.md, gotchas.md, decisions.md ✓
- AC 4 (validation): Rejects built-in names, existing locals, empty names, path traversal ✓
- AC 5 (templates): Loads `agent-template-{type}.md`, substitutes `{NAME}` placeholders ✓

**Handoff:** To TEA (Caterpillar) for verify phase

## Architect Assessment (spec-check)

**Spec Alignment:** Aligned
**Mismatches Found:** None

All 5 ACs verified against the code:

| AC | Spec | Code | Status |
|----|------|------|--------|
| 1 | CLI command with name arg and --type option | `@agent.command("create")` with Click argument and Choice option | Aligned |
| 2 | Scaffold .md in agents-local/ from template | Template loaded, rendered with placeholders, written to agents-local/ | Aligned |
| 3 | Create sidecars with 3 files | `sidecars/{name}/` with patterns.md, gotchas.md, decisions.md + headers | Aligned |
| 4 | Validate name against built-in agents | Checks agents/ and agents-local/ for conflicts, regex for format | Aligned |
| 5 | Uses agent-template-{type}.md | `_load_template()` loads tactical/strategic with dist_root fallback | Aligned |

**Architectural notes:**
- Follows SOUL #10 (Return Results) — `create_agent()` returns `{success, data?, error?}` dict
- Name validation with `re.fullmatch(r'[\w][\w.-]*')` prevents path traversal (CWE-22)
- Sidecar no-clobber check (line 90) preserves existing files — good for re-runs
- Template loading follows the same local→dist_root fallback as the agent loader

**Decision:** Proceed to verify phase

## Tea Assessment (verify)

**Phase:** finish
**Status:** GREEN confirmed

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 3

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 4 findings | Shared validation pattern, CLI error handler, test fixture |
| simplify-quality | 3 findings | Template placeholders, sidecar error handling, None check |
| simplify-efficiency | clean | No findings |

**Applied:** 0 fixes
**Flagged for Review:** 2 medium-confidence findings (shared validator, CLI error pattern — scope creep)
**Noted:** 6 observations dismissed with rationale
**Reverted:** 0

**Overall:** simplify: clean

**Quality Checks:** 100/100 tests passing (agent-create + agents-local + prime)
**Handoff:** To Queen of Hearts (Reviewer) for code review

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A — 100/100 tests pass, 0 smells |
| 2 | reviewer-edge-hunter | Yes | Skipped | disabled | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | Yes | Skipped | disabled | Disabled via settings |
| 4 | reviewer-test-analyzer | Yes | Skipped | disabled | Disabled via settings |
| 5 | reviewer-comment-analyzer | Yes | Skipped | disabled | Disabled via settings |
| 6 | reviewer-type-design | Yes | Skipped | disabled | Disabled via settings |
| 7 | reviewer-security | Yes | findings | 5 | confirmed 0, dismissed 4, deferred 1 |
| 8 | reviewer-simplifier | Yes | Skipped | disabled | Disabled via settings |
| 9 | reviewer-rule-checker | Yes | Skipped | disabled | Disabled via settings |

**All received:** Yes (2 enabled returned, 7 disabled pre-filled)
**Total findings:** 0 confirmed, 4 dismissed (with rationale), 1 deferred

### Security Subagent Finding Triage

1. **[SEC] agent_type path traversal (line 112)** — Dismissed (LOW). Click's `Choice(["tactical", "strategic"])` whitelists at the CLI boundary. The only production caller is the CLI command. Deferred as improvement: add internal whitelist for defense in depth if non-CLI callers are added.

2. **[SEC] Path.resolve() + containment (lines 75, 79)** — Dismissed (LOW). Pre-existing pattern across all pennyfarthing file operations. `agents-local/` is user-owned, same threat model as `gates-local/`, `.session/`, etc. User who writes symlinks already has full project access.

3. **[SEC] Symlink traversal (line 53)** — Dismissed. `agents-local/` is explicitly NOT in `_DOGFOODING_SYMLINKS` — it's a real directory, not a symlink. The subagent's premise ("dirs are symlinked targets") doesn't apply here.

4. **[SEC] TOCTOU (line 53 vs 76)** — Dismissed (LOW). Single-user local dev tool. Concurrent write to same agents-local/ path requires attacker with filesystem access — at which point they can write the file directly. `open(..., "x")` is a nice hardening but not proportionate to the threat model.

5. **[SEC] Template injection (line 69)** — Dismissed. Regex blocks `{` and `}` (not in `[\w.-]`). Display name derived from validated `name` cannot contain template syntax.

## Reviewer Assessment

**Verdict:** APPROVED

### Observations

1. [VERIFIED] CLI command registration — `cli.py:222` adds `@agent.command("create")` with `@click.argument("name")` and `@click.option("--type", type=click.Choice(["tactical", "strategic"]))`. Default "tactical". Complies with AC 1. Evidence: cli.py lines 222-253.

2. [VERIFIED] Agent file scaffolded in agents-local/ — `agent_create.py:74-76` creates `agents_local_dir / f"{name}.md"` with rendered template content. Template loaded from `agents/templates/agent-template-{type}.md`. Complies with AC 2, 5. Evidence: agent_create.py lines 59-76.

3. [VERIFIED] Sidecar files created — `agent_create.py:79-91` creates `sidecars/{name}/` with patterns.md, gotchas.md, decisions.md. Each has an agent-specific header. No-clobber check at line 90 (`if not filepath.exists()`). Complies with AC 3. Evidence: agent_create.py lines 79-91.

4. [VERIFIED] Name conflict validation — `agent_create.py:44-57` checks both `agents/{name}.md` (built-in) and `agents-local/{name}.md` (existing local). Name format validated with `re.fullmatch(r"[\w][\w.-]*")` at line 38, blocking empty names, path separators, and traversal. Complies with AC 4. Evidence: agent_create.py lines 34-57.

5. [VERIFIED] Result dict pattern — all error paths return `{success: False, error: msg}`, success returns `{success: True, agent_file, sidecar_dir}`. CLI translates to exit codes. Complies with SOUL #10. Evidence: agent_create.py lines 36, 40, 48, 54, 63, 93.

### Rule Compliance

| Rule | Applicable Code | Status |
|------|----------------|--------|
| #3 Type annotations | `create_agent(name: str, agent_type: str, project_root: Path \| None) -> dict` | Compliant |
| #5 Path handling (pathlib) | All paths use `Path /` operator | Compliant |
| #5 Path handling (encoding) | `read_text()` / `write_text()` without encoding — consistent with codebase | Pre-existing LOW |
| #6 Test quality | 26 tests with meaningful assertions, no vacuous checks | Compliant |
| #11 Input validation | `re.fullmatch()` at boundary, rejects traversal | Compliant |
| SOUL #10 Return results | All paths return result dict | Compliant |

[EDGE] No findings (disabled). [SILENT] No findings (disabled). [TEST] No findings (disabled). [DOC] No findings (disabled). [TYPE] No findings (disabled). [SEC] 5 findings — 4 dismissed (pre-existing/wrong-premise/low-threat), 1 deferred (agent_type whitelist). [SIMPLE] No findings (disabled). [RULE] No findings (disabled).

### Devil's Advocate

What if this code is broken? Let me argue against approval.

The most exploitable concern: `create_agent()` is a public function that accepts `agent_type` as an unconstrained string. If a future caller (e.g., an API endpoint, a webhook handler, or a stepped workflow) passes user-controlled input directly to `agent_type`, the `_load_template` function constructs a path with `f"agent-template-{agent_type}.md"` — no validation. This would allow reading arbitrary `.md` files from the templates directory or its parent via `../../` patterns. The Click CLI constrains this today, but the function signature doesn't enforce it.

Counter-argument: the function is currently called ONLY from the Click command, which uses `Choice(["tactical", "strategic"])`. Adding internal validation is defense-in-depth, not a blocking issue. Logged as delivery finding for the next story.

What about the template rendering? The `.replace()` calls on lines 69-71 are fragile — they depend on the templates containing exact placeholder strings `{NAME}`, `{Role Title}`, `{ROLE_DESCRIPTION}`. If someone edits the templates to use different syntax (e.g., `{{NAME}}` or `$NAME`), scaffolding silently produces unrendered output. But the tests verify the output contains the expected content, so this would be caught.

What about the sidecar no-clobber? If a user creates sidecars manually then runs `pf agent create`, the sidecars are preserved but the agent file would fail (existing local check). This is correct behavior — you can't re-create an agent that already exists.

The devil's advocate surfaced one genuine hardening opportunity (agent_type whitelist) already logged as a delivery finding. Nothing blocking.

### Data Flow

Input: `name` (CLI arg) → regex validation → conflict check (agents/ and agents-local/) → template load → placeholder substitution → file write to agents-local/{name}.md + sidecars/{name}/. Safe: no shell, no SQL, no HTML. Output is markdown files on local disk.

**Data flow traced:** name → regex → conflict check → template render → file write (safe, validated at boundary)
**Pattern observed:** Result-dict pattern with lazy imports at `agent_create.py:14-97`, CLI wiring at `cli.py:222-253`
**Error handling:** All error paths return `{success: False, error}`, CLI translates to exit code 1 with stderr message
**Handoff:** To Mad Hatter (SM) for finish-story