---
parent: context-epic-141.md
workflow: tdd
---

# Story 141-20: Consolidate Agent Validation — Port Shell Checks to pf validate

## Business Context

Agent validation is split across three implementations that have diverged. `validate-agent-schema.sh` (577 lines, in `scripts/validation/`) contains the most comprehensive checks, including mindset tag enforcement per agent, line-position thresholds for `<critical>` and `<on-activation>`, and orphan content detection (content outside XML tags). `validate-subagent-frontmatter.sh` (159 lines, in `scripts/misc/`) is a narrower subset covering frontmatter structure for subagents. The Python `pf validate agent` adapter (`src/pf/validate/adapters/agent.py`, 262 lines) has the hooks and model checks the shell scripts lack, but is missing mindset tag enforcement, line-position checks, and the orphan-content scan. Running all three produces conflicting results and confuses CI. The goal is a single authoritative validator in Python: port every shell-only check into `pf validate agent`, then delete both shell scripts so there is no second source of truth.

## Technical Guardrails

### Files Under Change

| File | Role |
|------|------|
| `pennyfarthing/pennyfarthing-dist/src/pf/validate/adapters/agent.py` | The Python adapter to extend — source of truth after this story |
| `pennyfarthing/pennyfarthing-dist/scripts/validation/validate-agent-schema.sh` | Shell script to delete (577 lines) |
| `pennyfarthing/pennyfarthing-dist/scripts/misc/validate-subagent-frontmatter.sh` | Shell script to delete (159 lines) |
| `pennyfarthing/pennyfarthing-dist/src/pf/validate/cli.py` | CLI entrypoint — no changes needed, `pf validate agent` already wired |
| `pennyfarthing/pennyfarthing-dist/agents/*.md` | The agent files under validation — must all pass after porting |

### Shell-Only Checks Not Yet in Python

The following checks exist in the shell scripts but are absent from `agent.py`:

**From `validate-agent-schema.sh`:**

1. **Mindset tag enforcement** (`check_mindset_tag`, lines 302-326): Each primary agent must contain its specific mindset tag (e.g., `sm.md` requires `<coordination-discipline>`, `dev.md` requires `<minimalist-discipline>`, etc.) and the tag must be properly closed. The full mapping is hardcoded in the shell `MINDSET_TAGS` associative array (lines 85-96).

2. **Line-position check for `<critical>`** (`check_best_practices`, lines 233-236): The first `<critical>` tag must appear at or before line 30 of the file. Violations are warnings, not errors.

3. **Line-position check for `<on-activation>`** (`check_best_practices`, lines 239-241): The `<on-activation>` tag must appear at or before line 100. Violations are warnings.

4. **File length check** (`check_best_practices`, lines 228-230): Files over 300 lines are flagged as errors.

5. **Orphan content check** (`check_all_content_in_tags`, lines 359-392): Non-blank lines that are not the first header line and are not inside any XML tag (depth tracking via open/close counts) are errors. The shell logic skips line 1 if it starts with `# ` and skips blank lines; all other lines at depth 0 without an opening tag on that line are orphan lines.

6. **Orphan content after last tag** (`check_no_orphan_content`, lines 277-300): Non-whitespace content after the last closing XML tag in the file is flagged.

7. **Checklist format check** (`check_checklist_format`, lines 191-218): Inside `<gate>`, `<handoff-gate>`, `<self-review>`, `<review-checklist>` tags, checklist items (lines matching `^\s*-\s*\[`) must match `^\s*-\s*\[\s*[x ]?\s*\]`. Malformed items are warnings.

8. **Header format check** (`check_header_format`, lines 264-275): First line of primary agents must match `^# .+ Agent`. Violations are warnings.

9. **`<parameters>` with `<helpers>`** (`check_parameters_section`, lines 328-338): If the file has a `<helpers>` tag, it should also have a `<parameters>` tag. Absence is a warning.

**From `validate-subagent-frontmatter.sh`:**

10. **Name matches filename** (lines 107-113): The `name` field in subagent frontmatter must equal the filename without `.md`. This check is absent from the Python `validate_subagent` function.

### Current Python Adapter State

`validate_main_agent` in `agent.py` currently checks:
- Required tags: `role`, `critical`, `helpers`, `skills`
- `<helpers>` model value is a valid model name
- Subagent reference table entries resolve to existing agent files
- Recommended tags: `on-activation`, `exit`/`exit-sequence` (warnings)

`validate_subagent` currently checks:
- Frontmatter present and parseable
- Required fields: `name`, `description`, `tools`, `model`
- `model` must be `haiku`
- Required tag: `output`
- Recommended tag: `arguments` (warning)

The `classify_agent_files` function classifies by presence of `name` + `tools` in frontmatter; primary agents with only a `hooks:` frontmatter key are correctly classified as main agents.

### Severity Mapping (Shell → Python)

| Shell classification | Python severity |
|---------------------|-----------------|
| Error (`has_error=true`, exit 1) | `errors` list |
| Warning (`has_warning=true`, exit 0) | `warnings` list (treated as errors under `--strict`) |

Shell treats these as **errors**: mindset tag missing/unclosed, file over 300 lines, orphan content in tags, content after last tag, missing required tags, unbalanced XML.
Shell treats these as **warnings**: line-position thresholds for `<critical>`/`<on-activation>`, checklist format, header format, missing `<parameters>`, missing recommended tags.

### Test File Convention

TDD workflow: TEA writes failing tests first. Test file:
`pennyfarthing/pennyfarthing-dist/src/pf/tests/test_141_20_agent_validator.py`

Use `tmp_path` (pytest fixture) to write synthetic agent files. No existing test file covers the agent adapter directly — this story creates the first one.

Run tests: `cd pennyfarthing && python -m pytest pennyfarthing-dist/src/pf/tests/test_141_20_agent_validator.py -v`

Run full validator against real agents: `pf validate agent`

## Scope Boundaries

**In scope:**
- `pennyfarthing/pennyfarthing-dist/src/pf/validate/adapters/agent.py` — add all 10 missing checks listed above
- `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_141_20_agent_validator.py` — new test file (TEA writes in RED phase)
- Delete `pennyfarthing/pennyfarthing-dist/scripts/validation/validate-agent-schema.sh`
- Delete `pennyfarthing/pennyfarthing-dist/scripts/misc/validate-subagent-frontmatter.sh`
- Verify `pf validate agent` exits 0 on all current agent files after porting

**Out of scope:**
- `pennyfarthing/pennyfarthing-dist/src/pf/validate/cli.py` — no CLI surface changes
- Other validate adapters (`sprint`, `schema`, `workflow`, `skill-command`, `tandem-awareness`, `context`)
- Any scripts in `scripts/validation/` other than `validate-agent-schema.sh`
- Any scripts in `scripts/misc/` other than `validate-subagent-frontmatter.sh`
- Changing existing severity levels for checks already present in `agent.py`
- Fixing agent files that currently fail — the validator must pass on the current set as-is (per AC 3)

## AC Context

### AC 0: Shell script behavior documented with test cases BEFORE porting (test the legacy, then migrate)

Before porting any check from shell to Python, the legacy shell behavior must be captured as test cases. This ensures the Python port matches exactly.

Process:
1. For each of the 10 missing checks, run the shell script against a synthetic agent file that triggers the check
2. Record the exact output (error/warning message format, exit code)
3. Write a Python test case that expects the same behavior
4. The test fails initially (check not yet ported) — this is the RED phase
5. Port the check, make the test pass — this is the GREEN phase

Testable: Each of the 10 checks has at least one test case written BEFORE the Python implementation. The test file should have a clear `# Legacy behavior captured from validate-agent-schema.sh` comment for each test.

### AC 1: `pf validate agent` includes all checks from shell scripts (mindset tags, line-position, content-outside-tags)

Testable: `pf validate agent` output covers every check category that the shell scripts covered. The 10 missing checks above must each have at least one test case in the test file.

**Mindset tag check (error):** For each primary agent file, the adapter must know which mindset tag is required and fail with `[ERROR] <filename>: Missing mindset tag: <tag-name>` if absent. The mapping from shell script lines 85-96:

| Agent file | Required mindset tag |
|------------|---------------------|
| `sm.md` | `coordination-discipline` |
| `tea.md` | `test-paranoia` |
| `dev.md` | `minimalist-discipline` |
| `reviewer.md` | `adversarial-mindset` |
| `orchestrator.md` | `systems-thinking` |
| `architect.md` | `pragmatic-restraint` |
| `pm.md` | `ruthless-prioritization` |
| `devops.md` | `automation-discipline` |
| `tech-writer.md` | `clarity-obsession` |
| `ux-designer.md` | `consistency-guardian` |

Agents not in this table (e.g., `ba.md`) do not require a mindset tag. The check must also verify the tag is closed (`</<tag>>` present).

**Line-position check for `<critical>` (warning):** If the first occurrence of `<critical>` in the file is after line 30, emit `[WARN] <filename>: First <critical> at line N (target: ≤30)`. Only fires if `<critical>` is present; absence is already an error from the existing required-tag check.

**Line-position check for `<on-activation>` (warning):** If `<on-activation>` first appears after line 100, emit `[WARN] <filename>: <on-activation> at line N (target: ≤100)`.

**File length check (error):** Files over 300 lines emit `[ERROR] <filename>: File has N lines (max: 300)`.

**Orphan content check (error):** Lines that are not blank, not the first heading line, and appear at XML depth 0 (not inside any tag) emit `[ERROR] <filename>: Content outside XML tags at lines: N, N, ...`. Depth tracking: increment on `<tag>`, decrement on `</tag>`, count occurrences per line. Lines containing an opening tag at depth 0 are themselves tag-opening lines, not orphans.

**Orphan content after last tag (warning):** Non-whitespace lines after the last closing `</tag>` emit `[WARN] <filename>: Content found after last closing tag (line N)`.

**Checklist format check (warning):** Inside `<gate>`, `<handoff-gate>`, `<self-review>`, `<review-checklist>` sections, checklist lines not matching `^\s*-\s*\[\s*[x ]?\s*\]` emit `[WARN] <filename>: Tag <tag> has malformed checklist items`.

**Header format check (warning):** First line of primary agent files not matching `^# .+ Agent` emits `[WARN] <filename>: Header should be '# Name Agent - Description'`.

**`<parameters>` section check (warning):** Primary agent files with `<helpers>` but without `<parameters>` emit `[WARN] <filename>: Has <helpers> but missing <parameters> section`.

**Subagent name-filename match (error):** For subagents, the `name` field in frontmatter must equal `path.stem` (filename without `.md`). Mismatch emits `[ERROR] <filename>: Name mismatch: expected '<stem>', got '<name>'`.

### AC 2: Shell validation scripts deleted

Testable: After the story is complete, neither file exists:
- `pennyfarthing/pennyfarthing-dist/scripts/validation/validate-agent-schema.sh` — deleted
- `pennyfarthing/pennyfarthing-dist/scripts/misc/validate-subagent-frontmatter.sh` — deleted

Any CI steps, Justfile targets, or script references that invoke these shell scripts must also be removed or updated to call `pf validate agent` instead. Search for callers: `grep -r "validate-agent-schema\|validate-subagent-frontmatter" pennyfarthing/ justfile .github/`.

### AC 4: Justfile recipes and CI references to deleted scripts updated

Testable: `grep -r "validate-agent-schema\|validate-subagent-frontmatter" justfile .github/ pennyfarthing/pennyfarthing-dist/scripts/` returns no hits referencing the deleted scripts. Any justfile recipe or CI step that previously called these scripts now calls `pf validate agent` instead (or is removed if redundant).

### AC 3: `pf validate agent` passes on current agent files

Testable: `pf validate agent` exits 0 (no errors) when run against the current set of agent files in `pennyfarthing/pennyfarthing-dist/agents/`. Warnings are acceptable; errors are not. If newly ported checks reveal legitimate issues in current agent files, those must be fixed as part of this story before the shell scripts are deleted.
