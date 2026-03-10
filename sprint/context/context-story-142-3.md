---
parent: context-epic-142.md
workflow: tdd
---

# Story 142-3: Pipeline Replay BMAD Adapter

## Business Context

This story wires the BMAD templates (built in 142-2) into the Peloton pipeline replay harness so that `pf benchmark replay run --pipeline bmad` actually works. Without this adapter, the BMAD templates exist but can't be executed through the benchmark infrastructure.

This is the critical integration point — it connects the BMAD simulator to the existing replay harness, enabling head-to-head comparison runs.

## Technical Guardrails

### Architecture (from ADR-0035)

The adapter integrates with the existing `pf benchmark replay` infrastructure. Key integration points:

1. **`--pipeline bmad` flag** — new CLI option on `pf benchmark replay run` that selects the BMAD adapter
2. **CLAUDE.md builder swap** — when `--pipeline bmad`, the harness calls `build_bmad_dev_claude_md()` and `build_bmad_reviewer_claude_md()` instead of PF's normal agent definitions
3. **Phase mapping** — BMAD uses 2 phases (dev, reviewer) vs PF's 3 phases (TEA, dev, reviewer). The adapter must configure the phase list accordingly.
4. **Story file injection** — calls `translate_story_file()` to convert scenario context to BMAD format, writes to `implementation_artifacts/{story_key}.md`
5. **Result storage** — stores results under `bmad/run-N/` with `pipeline.yaml` metadata including `pipeline: bmad`

### Existing Infrastructure

| File | Purpose |
|------|---------|
| `pennyfarthing-dist/src/pf/benchmark/pipeline_replay.py` | Existing pipeline replay harness |
| `pennyfarthing-dist/src/pf/benchmark/bmad_adapter.py` | BMAD templates (from 142-2) — `BmadConfig`, `build_bmad_dev_claude_md`, `build_bmad_reviewer_claude_md`, `translate_story_file` |
| `pennyfarthing-dist/src/pf/benchmark/cli.py` | CLI commands for `pf benchmark replay` |

### BMAD Source Location

**Repository:** `/Users/keithavery/Projects/BMAD-METHOD/`
**Pinned commit:** `b7315c6e329eb72dc464f4e540bb67cdd22a9749`

The `BmadConfig(bmad_root=Path("/Users/keithavery/Projects/BMAD-METHOD"))` validates required files exist at construction.

### Worktree Setup (from ADR-0035)

For BMAD runs, the adapter must:
1. Create BMAD-format story file at `implementation_artifacts/{story_key}.md`
2. Create `project-context.md` from target project coding standards
3. Pass `story_path` directly in the prompt so BMAD's step 1 skips sprint-status lookup
4. NOT create `_bmad/` directory, `sprint-status.yaml`, or `config.yaml`

## Scope Boundaries

**In scope:**
- `--pipeline bmad` CLI option on `pf benchmark replay run`
- BMAD pipeline adapter that swaps CLAUDE.md builder and phase configuration
- Worktree setup for BMAD runs (story file + project-context.md)
- Result storage under `bmad/run-N/` with pipeline metadata
- Tests verifying adapter integration

**Out of scope:**
- BMAD template construction (done in 142-2)
- Context parity verification (142-4)
- Actually running comparison benchmarks (142-5)
- Comparative analysis report (142-6)

## AC Context

### AC1: --pipeline CLI Option

The `pf benchmark replay run` command accepts `--pipeline bmad` (default: `default`). When set to `bmad`, the harness uses the BMAD adapter for CLAUDE.md construction and phase configuration.

**Testable:** CLI accepts `--pipeline` flag. `bmad` value routes to BMAD adapter. Invalid values raise an error.

### AC2: BMAD Pipeline Adapter

The adapter configures the replay harness for BMAD execution: 2-phase pipeline (dev, reviewer), BMAD CLAUDE.md builders, BMAD story file translation, and result storage under `bmad/run-N/`.

**Testable:** Adapter produces correct phase list, calls correct CLAUDE.md builders, stores results in correct directory structure with `pipeline: bmad` metadata.

### AC3: Worktree Setup

The adapter creates the BMAD-specific files in the worktree: translated story file and project-context.md. The `story_path` is passed in the prompt.

**Testable:** Story file written to correct path. project-context.md created. story_path provided. No BMAD infrastructure files created.
