---
story_id: "156-5"
jira_key: ""
epic: "156"
workflow: "tdd"
---
# Story 156-5: sprint new crashes FileNotFoundError when sprint/ dir doesn't exist (gh #52)

## Story Details
- **ID:** 156-5
- **Jira Key:** (kanban-only — no Jira)
- **Workflow:** tdd
- **Repo:** pennyfarthing
- **Branch:** feat/156-5-sprint-new-mkdir-parent
- **Branch Strategy:** gitflow (PR → develop)

## Workflow Tracking
**Workflow:** tdd
**Phase:** green
**Phase Started:** 2026-06-04T07:40:00Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-04T07:30:00Z | 2026-06-04T07:31:00Z | ~1m |
| red   | 2026-06-04T07:31:00Z | 2026-06-04T07:40:00Z | ~9m |
| green | 2026-06-04T07:40:00Z | 2026-06-04T07:48:00Z | ~8m |
| review| 2026-06-04T07:48:00Z | - | - |

**GREEN result:** 6/6 — commit `aeb6213`. Fix: 1-line `path.parent.mkdir(parents=True, exist_ok=True)` in `_write_yaml_file` before temp-write. Scoped regression 279 passed. AC3 atomicity guards green.

**RED result:** 4 failed (AC1/AC2/AC4 FileNotFoundError on missing parent) / 2 passed (AC3 guards) — commit `94e1e49`. Chain: `new_sprint → write_sprint → _write_yaml_file` (yaml_io.py:347). Fix: `path.parent.mkdir(parents=True, exist_ok=True)` before temp-write.

## Context (from gh #52)

**Symptom:** On a freshly `pf init`'d project, the first `pf sprint new` crashes with an
unhandled `FileNotFoundError` because the `sprint/` directory it writes into was never created.
`--dry-run` reports success (false positive — doesn't exercise the write path).

**Root cause:** `_write_yaml_file` (`sprint/yaml_io.py:335-353`) writes to
`sprint/current-sprint.yaml.tmp` without ensuring the parent `sprint/` dir exists:
```python
tmp_path = path.with_suffix(".yaml.tmp")
with open(tmp_path, "w") as f:   # ← FileNotFoundError if sprint/ doesn't exist
    f.write(output)
os.replace(tmp_path, path)
```
`pf init` creates `.pennyfarthing/` and `.claude/` but NOT top-level `sprint/`.

**Approved fix (minimal, self-healing — issue suggestion 1):**
In `_write_yaml_file`, `path.parent.mkdir(parents=True, exist_ok=True)` before the atomic
temp-write. This protects EVERY sprint write path (new, update, add, move, …), not just
`sprint new`. (Do NOT add init-scaffolding / migration tooling — out of policy. The mkdir
in the write path is the robust fix.)

**Code pointer:**
- `pennyfarthing-dist/src/pf/sprint/yaml_io.py:335-353` — `_write_yaml_file`.

## Acceptance Criteria (TEA to finalize in RED)
- AC1: `_write_yaml_file(path, data)` (or `write_sprint`) succeeds when `path`'s parent dir
  does NOT yet exist — it creates the parent and writes the file. (RED: today raises
  `FileNotFoundError`.)
- AC2: end-to-end — `pf sprint new` (or its function-level API) into a project with no
  `sprint/` dir creates `sprint/current-sprint.yaml` successfully (no FileNotFoundError).
- AC3: atomicity preserved — still temp-file + `os.replace`; on a write failure the tmp file
  is cleaned up (existing contract); existing-dir case unchanged (no regression).
- AC4: idempotent — writing again when the dir already exists does not error (`exist_ok=True`).

## Delivery Findings
**Types:** Gap, Conflict, Question, Improvement | **Urgency:** blocking, non-blocking
<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Improvement** (non-blocking): `new_sprint` (cli.py:2265) mkdirs `archive_file.parent` but NOT the current-sprint.yaml parent — it relies on `write_sprint` to create `sprint/`, which currently it does not. The approved `_write_yaml_file` mkdir fix covers both (write_sprint runs first), so no extra change needed in cli.py. Affects `pennyfarthing-dist/src/pf/sprint/cli.py` only if Dev opts to fix at command level instead (not recommended — function-level fix self-heals all callers). *Found by TEA during test design.*
- **Improvement** (non-blocking): `--dry-run` path (cli.py:2222-2227) never exercises the write, so it reports success even on the broken state — a false-positive that masked this bug. Out of scope for 156-5 (fix is the write-path mkdir), but worth a future note. Affects `pennyfarthing-dist/src/pf/sprint/cli.py`. *Found by TEA during test design.*

## Design Deviations
<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->
