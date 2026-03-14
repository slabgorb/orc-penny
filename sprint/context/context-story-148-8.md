# Story 148-8: Peloton mode — spawn team panes and run TDD workflow through tmux

**Jira Key:** MSSCI-16421
**Points:** 5
**Workflow:** tdd
**Status:** in_progress

---

## Story Title

Implement "peloton mode" — an automated team pipeline that spawns and coordinates multiple tmux panes for TEA, Dev, and Reviewer agents, running a full TDD workflow through tmux automation. The command `pf peloton start <scenario-yaml>` orchestrates the complete cycle: load scenario, spawn panes, drive phases, resolve gates, aggregate results, and score against ground truth.

---

## Acceptance Criteria

1. **`pf peloton start` command exists and spawns agent panes**
   - CLI entry point at `pennyfarthing-dist/src/pf/commands/peloton.py`
   - Accepts `<scenario-yaml>` argument, optional `--theme` and `--model` flags
   - Spawns three dedicated panes: TEA (red), Dev (green), Reviewer (review)
   - Plus background worker panes for gate resolution and utilities
   - Naming convention: `{role}-agent` or `{story-id}-{role}`

2. **Panes registered in `.pennyfarthing/tmux-panes.json`**
   - Each pane has role, title, and protection status
   - Agent panes use role `agent`, worker panes use role `worker`
   - Panes discoverable via `pf tmux list`

3. **TEA phase runs in its pane**
   - `pf agent start tea` prompt injected into TEA pane via `pf tmux send`
   - Test failures captured from pane output
   - Findings written to session file

4. **Dev phase runs in its pane**
   - Prompt injected, test failures from TEA phase read as input
   - Implementation executed, tests pass
   - Output captured

5. **Reviewer phase runs in its pane**
   - Prompt injected, code evaluated against specification
   - Findings written to session file

6. **Phase transitions coordinated via gate resolution**
   - Pane readiness detected (shell prompt returns)
   - Output captured into temporary files for gate evaluation
   - Gate logic validates phase completion
   - Phase markers written to session file (BikeLane spec)
   - Next phase context prepared (e.g., extract test failures for Dev)

7. **Output aggregated into `pipeline.yaml` result file**
   - Per-phase results: TEA findings, Dev implementation, Reviewer assessment
   - Output directory: `internal/results/pipeline-replay/<scenario-id>/run-N/`

8. **Scoring works with LLM judge**
   - LLM judge compares pipeline findings against ground truth
   - Produces `score.yaml` with precision/recall metrics
   - Reference: `guides/peloton.md` scoring methodology

9. **Integration test: full peloton scenario end-to-end**
   - Run a complete scenario, verify output structure and scoring
   - Verify all panes created, phases executed, results aggregated

---

## Technical Guardrails

- **Python-only:** All peloton orchestration code is Python (SOUL principle #9)
- **Return results:** Functions return `{success, data?, error?}` — never throw
- **Use `pf tmux` commands:** Never use raw `tmux send-keys` — use `pf tmux send`, `pf tmux run`
- **Pane registry:** All panes must be registered in `.pennyfarthing/tmux-panes.json`
- **Protected panes:** Never auto-kill `claude` or `tui` panes
- **BikeLane phases:** Phase markers follow the existing BikeLane workflow engine spec
- **Gate resolution:** Use `pf handoff resolve-gate` / `complete-phase` / `marker` — don't reinvent

## Key Files

| File | Action | Purpose |
|------|--------|---------|
| `pennyfarthing-dist/src/pf/peloton/` | Create | New module for peloton mode |
| `pennyfarthing-dist/src/pf/peloton/__init__.py` | Create | Module init |
| `pennyfarthing-dist/src/pf/peloton/pane_orchestrator.py` | Create | Pane spawning, lifecycle, coordination |
| `pennyfarthing-dist/src/pf/peloton/workflow_driver.py` | Create | Phase execution and gate resolution |
| `pennyfarthing-dist/src/pf/peloton/result_aggregator.py` | Create | Output collection and scoring |
| `pennyfarthing-dist/src/pf/commands/peloton.py` | Create | CLI entry point for `pf peloton` |
| `pennyfarthing-dist/src/pf/benchmark/pipeline_replay.py` | Modify | Integrate peloton mode as execution engine |
| `.pennyfarthing/tmux-panes.json` | Manage | Pane registry (auto-maintained by pf tmux) |

## Related Guides

- `guides/tmux-panes.md` — tmux pane management via `pf tmux` commands
- `guides/peloton.md` — peloton testing (benchmarking with full agent teams)
- `guides/bikelane.md` — BikeLane workflow engine and phase transitions
- `guides/relay-mode.md` — auto-handoff execution (reference for automation patterns)

## Scope Boundaries

- **In scope:** CLI command, pane orchestration, phase driving, gate resolution, result aggregation, scoring
- **Out of scope:** Modifying the existing `pf tmux` commands themselves, changing BikeLane workflow engine internals, GUI integration
