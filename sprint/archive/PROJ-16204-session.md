# Standalone: Consumer gate extensions via config + gate files

**Jira:** PROJ-16204
**Points:** 2
**Priority:** P2
**Workflow:** standalone
**Status:** done
**Repos:** pennyfarthing
**Branch:** feat/PROJ-16204-gate-extensions
**PR:** 1283
**Started:** 2026-03-05
**Completed:** 2026-03-05

---

## Description

Consumer repos can now extend existing workflow gates with custom quality checks
(e.g., rustfmt, license checks, cargo clippy) without forking or overriding
built-in gate files. Extensions are declared in config.local.yaml and run
sequentially after the primary gate with AND semantics.

## Files Changed

| File | Change |
|------|--------|
| `pennyfarthing-dist/src/pf/handoff/gate_file.py` | Added `resolve_gate_extensions()` |
| `pennyfarthing-dist/src/pf/handoff/resolve_gate.py` | Added `gate_extensions` to RESOLVE_RESULT |
| `pennyfarthing-dist/src/pf/handoff/gate_runner.py` | Added `merge_gate_results()` |
| `pennyfarthing-dist/guides/gates.md` | Consumer Gate Extensions section |
| `pennyfarthing-dist/schemas/gate-schema.md` | RESOLVE_RESULT extensions docs |
| `pennyfarthing-dist/guides/handoff-cli.md` | Exit protocol step 2b |
| `pennyfarthing-dist/src/pf/tests/test_gate_extensions.py` | 19 new tests |
