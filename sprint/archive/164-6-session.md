---
story_id: "164-6"
jira_key: ""
epic: "164"
workflow: "tdd"
---
# Story 164-6: Harden PR title payload interpolation

## Story Details
- **ID:** 164-6
- **Jira Key:** (none — local sprint)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/164-6-harden-pr-title-payload-interpolation
- **PR:** (none yet — recorded when the PR is created)

## Vulnerability Summary

**CWE-94 Code Injection (bash-into-Python-literal splice)** discovered in 155-11 code review.

### Vulnerable Locations

Three markdown documents interpolate shell variables directly into Python `-c` string literals for PR title formatting:

1. **`pennyfarthing-dist/agents/sm-finish.md`** (line 41)
   ```bash
   PR_TITLE=$("${PF_PY}" -c "
   from pf.git.repos import format_pr_title
   print(format_pr_title(jira_key='${JIRA_KEY:-$STORY_ID}', title='${title}', scope='${scope}'))
   ")
   ```

2. **`pennyfarthing-dist/commands/pf-standalone.md`** (line 155)
   ```bash
   PR_TITLE=$("${PF_PY}" -c "
   from pf.git.repos import format_pr_title
   print(format_pr_title(jira_key='${JIRA_KEY}', title='${TITLE}'))
   ")
   ```

3. **`pennyfarthing-dist/workflows/git-cleanup/steps/step-03-execute.md`** (line 157)
   ```bash
   PR_TITLE=$("${PF_PY}" -c "
   from pf.git.repos import format_pr_title
   print(format_pr_title(jira_key='${JIRA_KEY}', title='{title}'))
   ")
   ```

### Attack Scenario

If a PR title contains metacharacters (quotes, newlines, backticks), an attacker can:
- **Break out of the Python string literal:** `'); import os; os.system('rm -rf /'); print('`
- **Corrupt the literal:** `'); raise Exception('`
- **Execute arbitrary Python code** or bash commands via subprocess

Example title payload:
```
My PR'; import sys; sys.exit(1); print('title
```

Would become:
```python
print(format_pr_title(jira_key='PROJ-123', title='My PR'; import sys; sys.exit(1); print('title'))
```

### Safe Pattern

The underlying `format_pr_title()` function in `pf/git/repos.py` is safe — it accepts keyword arguments and uses `str.format()` internally, never shell interpolation. The vulnerability exists only in the markdown docs' invocation pattern.

**Recommended fixes:**

**Option A: Pass via argv (safest)**
```bash
PR_TITLE=$("${PF_PY:?PF_PY not set}" - 'pennyfarthing' "$JIRA_KEY" "$title" "$scope" <<'PYEOF'
import sys
from pf.git.repos import format_pr_title
jira_key = sys.argv[1]
title = sys.argv[2]
scope = sys.argv[3] if len(sys.argv) > 3 else ""
print(format_pr_title(jira_key=jira_key, title=title, scope=scope))
PYEOF
)
```

**Option B: Pass via environment variable**
```bash
PR_TITLE=$("${PF_PY:?PF_PY not set}" -c "
import os
from pf.git.repos import format_pr_title
print(format_pr_title(
  jira_key=os.environ.get('PF_JIRA_KEY', ''),
  title=os.environ.get('PF_TITLE', ''),
  scope=os.environ.get('PF_SCOPE', '')
))
" <<< ''JIRA_KEY=$JIRA_KEY PF_TITLE=$title PF_SCOPE=$scope'
```

But this still has shell quoting risks.

**Option C: Create a CLI command** (recommended — cleanest)
```bash
PR_TITLE=$(pf git format-title --jira-key "$JIRA_KEY" --title "$title" --scope "$scope")
```

Then add a new Click command to `pf git ...` in `pf/git_group/cli.py`.

## Testable Surface

- **Python surface:** `pf.git.repos.format_pr_title()` — already safe
- **CLI surface (to create):** `pf git format-title` — new command to safely invoke format_pr_title with escaped args
- **Acceptance test:** A PR title containing `'); import os;` should produce literal output (the title text itself), not execute code or corrupt the command

## Acceptance Criteria

1. Neither `sm-finish.md`, `pf-standalone.md`, nor `step-03-execute.md` interpolates shell variables directly into a Python `-c` string literal. The PR title is passed safely (argv, env var, or dedicated CLI command).

2. A test proves the fix neutralizes the injection:
   - Test a title with payload: `Test PR'); import os; os.system('echo pwned');`
   - Verify the output is the literal title text (formatted according to `pr_title_format` but with quotes/parens preserved in the title itself), not Python error or shell execution
   - If using a new CLI command, document it in the command group's help

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-10T16:43:26Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-10T16:08:40Z | - | - |

## TEA Assessment

**Tests Required:** Yes
**Reason:** CWE-94 injection risk requires both CLI command tests and doc guard tests.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_164_6_format_title_cli.py` — CLI command existence, injection neutralisation, doc guard tests

**Tests Written:** 43 tests (31 failing, 12 passing) covering ACs 1-4
**Status:** RED (failing — ready for Dev)

**Failure breakdown:**
- 5 CLI existence tests → `No such command 'format-title'`
- 20 injection payload tests (exit_zero + literal_output) → same
- 3 dangerous-pattern guard tests → regex matches `format_pr_title(... '${VAR}'` in all 3 docs
- 3 safe-invocation guard tests → `pf git format-title` not yet in docs

**CLI command signature:**
```
pf git format-title --jira-key KEY --title TITLE [--scope SCOPE]
```
Lives in `pennyfarthing-dist/src/pf/git_group/cli.py`, added as `@git.command("format-title")`.

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/git_group/cli.py` — added `@git.command("format-title")` with `--jira-key`, `--title`, `--scope` options; calls `format_pr_title()` and prints result
- `pennyfarthing-dist/agents/sm-finish.md` — replaced `${PF_PY} -c "...format_pr_title(...'${JIRA_KEY:-$STORY_ID}'...)"` with `pf git format-title --jira-key "${JIRA_KEY:-$STORY_ID}" --title "$title" --scope "$scope"`
- `pennyfarthing-dist/commands/pf-standalone.md` — replaced `${PF_PY} -c` block with `pf git format-title --jira-key "$JIRA_KEY" --title "$TITLE"`
- `pennyfarthing-dist/workflows/git-cleanup/steps/step-03-execute.md` — replaced `${PF_PY} -c` block with `pf git format-title --jira-key "$JIRA_KEY" --title "$title"`
- `pennyfarthing-dist/src/pf/tests/test_164_6_format_title_cli.py` — fixed false-positive in `test_payload_does_not_execute_os_commands` for payloads containing "pwned" as literal text
- `pennyfarthing-dist/src/pf/tests/test_162_8_template_pf_py_policy.py` — removed `commands/pf-standalone.md` from SENTINEL_TEMPLATES (file no longer has pf-executing Python fences)

**Tests:** 43/43 passing (GREEN); regression suite clean (3040 passed, 1 skipped — same as pre-change baseline)
**Branch:** feat/164-6-harden-pr-title-payload-interpolation (pushed)
**Commit:** 5ef2800b1

**Handoff:** To Reviewer

## Delivery Findings

No upstream findings at setup time. Agents record observations during their phase.

### TEA (test design)
- **Gap** (non-blocking): `step-03-execute.md` session file annotation says line 157 but the content is in the middle of a long truncated display in test output — regex confirmed matching. No path ambiguity.

### Dev (implementation)
- **Gap** (non-blocking): `test_162_8_template_pf_py_policy.py::SENTINEL_TEMPLATES` was a pre-condition that my changes invalidated — `commands/pf-standalone.md` no longer has direct `${PF_PY}` invocations after the CWE-94 fix. Updated sentinel list accordingly. *Found by Dev during regression run.*

### Reviewer (code review)
- **Gap** (non-blocking): Five gate files (`gates/ac-completion.md`, `gates/spec-drift-precheck.md`, `gates/spec-reconcile-pass.md`, `gates/deviations-logged.md`, `gates/spec-check.md`) contain the same CWE-94 class of injection as this story fixed — `${SESSION_FILE}` and `${CONTEXT_FILE}` shell-expanded inside `python -c` string literals. Practical risk is low (paths use `[a-z0-9-]` chars), but the architectural pattern is identical to what 164-6 fixed. Follow-up story needed. *Found by reviewer-security during code review.*
- **Gap** (non-blocking): `test_payload_does_not_execute_os_commands` uses CliRunner which does not capture `os.system()` stdout (os.system writes to raw fd 1, bypassing Python capture). The "pwned"/"uid=" absence checks are structurally unable to detect os.system side-effects. The current implementation is safe (str.format() cannot exec anything), and sibling tests provide coverage, but this is a test design gap for future regressions. *Found by reviewer-test-analyzer during code review.*
- **Gap** (non-blocking): `_DANGEROUS_PATTERN` regex (`r"format_pr_title\([^)]*'\\?\$\{?[A-Z_a-z]\w*"`) matches single-quoted `'${VAR}'` but not double-quoted `"${VAR}"` kwargs. A future regression using double-quoted Python kwargs would bypass the guard test. Low risk (original vulnerable pattern used single quotes), but the regex's defensive scope is incomplete. *Found by reviewer-test-analyzer during code review.*

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

## Design Deviations

Design deviations are logged as they happen — not after the fact.

### TEA (test design)
- **Guard test scope narrowed:** Spec mentioned `agents/pf-standalone.md` but session file correctly identifies `commands/pf-standalone.md`. Tests use the session file path (confirmed exists at `pennyfarthing-dist/commands/pf-standalone.md`).
- **Regex approach for dangerous pattern:** Uses `format_pr_title(... '${VAR}` substring match rather than `python -c` prefix (docs invoke via `${PF_PY}` variable, not bare `python`).

### Dev (implementation)
- **test_payload_does_not_execute_os_commands false-positive:** Three payloads (`single_quote_injection`, `double_quote_injection`, `semicolon_chain`) contain "pwned" as literal title text. The original assertion `"pwned" not in lower_out` contradicted `test_payload_title_appears_literally_in_output` which requires the full title in output. Fixed by adding a guard: skip the "pwned" absence check when "pwned" is already in the payload title itself. This is a false-positive fix, not a test weakening.
- **test_162_8 SENTINEL_TEMPLATES regression:** Removing `${PF_PY}` from `pf-standalone.md` dropped that file from `_pf_exec_fences()` detection. Removed it from SENTINEL_TEMPLATES with explanatory comment; the sweep remains functional via the 3 remaining sentinels.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|------------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 43/43 pass, 162-8 15/16 pass (1 skip pre-existing), no rule violations | N/A |
| 2 | reviewer-edge-hunter | Yes | findings | repos.py yaml robustness gaps (pre-existing); empty strings pass required=True; newline in jira_key | All LOW, pre-existing or out-of-scope — dismissed |
| 3 | reviewer-silent-failure-hunter | Yes | findings | get_pr_title_format triple-fallback silent default (pre-existing); _DANGEROUS_PATTERN single-quote only (overlaps TEST); CliRunner catch_exceptions gap | LOW/MEDIUM — no blocks |
| 4 | reviewer-test-analyzer | Yes | findings | CliRunner can't capture os.system stdout (MEDIUM); _DANGEROUS_PATTERN misses double-quote variant (MEDIUM); "or title" vacuous branch (LOW); scope "git" weak assertion (LOW) | MEDIUM: documented in Delivery Findings; LOW: noted |
| 5 | reviewer-comment-analyzer | Yes | findings | TestDocumentGuards stale "RED phase" docstring; "root" check in docstring doesn't exist in code; module docstring says "agent markdown files" | All LOW — noted |
| 6 | reviewer-type-design | Yes | findings | jira_key: str accepts malformed keys (no format validation) | LOW — out of scope for CWE-94 fix |
| 7 | reviewer-security | Yes | findings | Gate files (5) have same CWE-94 class (pre-existing); str.format() safe; argv quoting correct | MEDIUM gate-file finding → Delivery Finding for follow-up |
| 8 | reviewer-simplifier | Yes | findings | Dead code line 184 (output unused); normalized_payload if/else complex; single_quote_close subsumed | All LOW — noted |
| 9 | reviewer-rule-checker | Yes | clean | All 5 rules checked, 0 violations | N/A |

**All received:** Yes (9 returned, 5 with findings, 4 clean)

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** `$title` in bash → argv token (properly double-quoted) → Click `--title` option → Python string → `format_pr_title(title=str)` → `fmt.format(..., title=title)` → literal output. `str.format()` does not re-process replacement values; injection chars appear as literal text. Verified programmatically.

**Pattern observed:** Lazy import pattern (`from pf.git.repos import format_pr_title` inside function body) at `git_group/cli.py:242` — consistent with snapshot, install-hooks, and all other sibling commands.

**Error handling:** No explicit error handling in `format_title` CLI command (`git_group/cli.py:231`). Click handles uncaught exceptions with exit code 1 + traceback. This matches all sibling commands in the file. Acceptable for CLI entry point. [SILENT]

**Two priority determinations:**
1. `test_payload_does_not_execute_os_commands` guard — LEGITIMATE FIX. The three "pwned"-containing payloads (`single_quote_injection`, `double_quote_injection`, `semicolon_chain`) produce "pwned" in output via safe literal-title embedding, so asserting absence would be a false positive. Coverage maintained via `test_payload_exits_zero` and `test_payload_title_appears_literally_in_output`. Residual gap [TEST]: CliRunner doesn't capture `os.system()` stdout (writes to raw fd), so the "pwned" absence check is structurally unable to detect os.system side-effects for any payload. The current implementation (str.format()) can't exec anything, so this is a test quality gap, not a code correctness gap.
2. SENTINEL_TEMPLATES removal — CORRECT. `pf-standalone.md` has zero bash fences that invoke a Python interpreter or import pf modules. `_executes_pf()` correctly classifies it as non-executing (grep confirmed: 0 PF_PY references). 162-8 tests pass 15/16 (1 skip pre-existing). No policy silencing. [RULE]

**Specialist findings reconciliation:**

[DOC] Three stale comments in test_164_6_format_title_cli.py: (1) TestDocumentGuards class docstring says "FAIL now (RED phase)" — false at HEAD; (2) `test_payload_does_not_execute_os_commands` docstring claims "root" is checked — not implemented; (3) module docstring says "agent markdown files" — only one of three is an agent. All LOW, no blocks.

[EDGE] repos.py has empty-string and yaml-robustness gaps. All pre-existing, not introduced by 164-6. [LOW]

[RULE] Clean — 0 violations across all project rules. All changed files are at `pennyfarthing-dist/` source paths, not symlinks.

[SEC] Gate files (5 files: `gates/ac-completion.md`, `gates/spec-drift-precheck.md`, `gates/spec-reconcile-pass.md`, `gates/deviations-logged.md`, `gates/spec-check.md`) use same CWE-94 class: `${SESSION_FILE}` and `${CONTEXT_FILE}` expanded inside `python -c` strings. Practical risk is low (paths use `[a-z0-9-]` chars), pre-existing, out of scope for 164-6. Follow-up story filed in Delivery Findings.

[SILENT] `get_pr_title_format` triple fallback silently returns default format when repos.yaml is absent/empty/missing key. Pre-existing in repos.py. [LOW]

[SIMPLE] Dead code: `output = result.output.rstrip('\n')` at line 184 assigned but never used. `normalized_payload` if/else can collapse to one line. `single_quote_close` payload subsumed by `single_quote_injection`. All [LOW] style issues.

[TEST] (1) CliRunner can't capture `os.system()` stdout — structural limitation means "pwned" absence checks don't detect subprocess execution; (2) `_DANGEROUS_PATTERN` regex anchors on single-quote only — `"${VAR}"` double-quoted variant bypasses the guard; (3) `or "title" in result.output.lower()` branch at line 78 is vacuous; (4) scope "git" test value also appears in command name. Items (1) and (2) are MEDIUM test quality gaps. None block.

[TYPE] `jira_key: str` accepts malformed keys at CLI boundary (empty, lowercase, no hyphen). Not a security concern for 164-6's scope (injection neutralization, not input validation). [LOW]

**Observations (9 total):**
1. CWE-94 fix verified complete — all three docs clean, guard tests pass 43/43
2. CLI command follows sibling pattern correctly, `required=True` enforces args
3. str.format() non-recursive — verified programmatically, title format-specs appear literally
4. Gate files (5) have same CWE-94 class — pre-existing, follow-up story needed
5. Regression suite: 3075 passed, 1 failed (pre-existing test_164_1 unrelated to diff), 2 skipped
6. [TEST] CliRunner structural gap: can't capture os.system() stdout
7. [TEST] _DANGEROUS_PATTERN misses double-quoted `"${VAR}"` variant
8. [RULE] All project rules clean
9. [DOC] Three stale comments in test file — all LOW

**Deviation audit:**
- TEA: guard test scope narrowed to `commands/` → ACCEPTED (correct path)
- TEA: regex approach for dangerous pattern → ACCEPTED (correctly matches actual vulnerable shape)
- Dev: false-positive guard in `test_payload_does_not_execute_os_commands` → ACCEPTED (legitimate, not a weakening)
- Dev: SENTINEL_TEMPLATES removal → ACCEPTED (verified correct via grep and 162-8 test pass)

**Handoff:** To SM for finish-story