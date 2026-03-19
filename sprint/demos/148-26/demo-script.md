**Total runtime: ~6 minutes**

---

**Slide 1: Title (0:00–0:20)**
Open on the title slide. Introduce the fix as part of Epic 148: TUI-tmux Fixer. Set the context: "We found a small but disruptive bug in how Peloton manages terminal windows during benchmark runs. Here's what was happening and how we fixed it."

---

**Slide 2: Problem (0:20–1:30)**
Walk through the before behavior. Say: "When Peloton starts a benchmark, it opens one terminal window per agent — Tea, Dev, and Reviewer. But if anything triggered `spawn_agent_panes` a second time — a retry, a re-entry, a workflow restart — it would open a second window for each agent. Then a third. We've seen sessions end up with 9 panes where 3 should have been."

Point to the before column in the Before/After slide if available, or narrate: "Three agents, called twice, equals six panes. No deduplication, no guard."

Fallback if live demo unavailable: Show Slide 2 and the Before/After slide side by side.

---

**Slide 3: What We Built (1:30–3:00)**
Live demo section. In a terminal, run:

```bash
cd pennyfarthing
python3 -m pytest pennyfarthing-dist/src/pf/tests/test_peloton_max_panes.py -v
```

Expected output:
```
PASSED test_peloton_max_panes.py::TestOnePanePerRole::test_spawn_same_phases_twice_no_duplicates
PASSED test_peloton_max_panes.py::TestOnePanePerRole::test_spawn_returns_existing_pane_on_reuse
PASSED test_peloton_max_panes.py::TestOnePanePerRole::test_get_pane_returns_single_entry
PASSED test_peloton_max_panes.py::TestOnePanePerRole::test_different_roles_get_different_panes
PASSED test_peloton_max_panes.py::TestRegistryReuse::test_reuses_live_registry_pane
PASSED test_peloton_max_panes.py::TestRegistryReuse::test_no_reuse_when_registry_pane_dead
6 passed in 0.XXs
```

Narrate: "Six tests, all green. The first four confirm no duplicates. The last two confirm the system correctly reuses live panes from the registry and doesn't blindly reuse dead ones."

**Fallback:** If pytest fails, show Slide 3 and read the test names aloud — they are self-documenting.

---

**Slide 4: Why This Approach (3:00–4:30)**
Narrate the two-layer check: in-memory → registry → new pane. Emphasize that the fix is ~50 lines of change, entirely within `_create_pane`. No new configuration, no behavior change for healthy sessions.

---

**Before/After Slide (4:30–5:15)**
Walk through the comparison. Say: "Before, every call to spawn was unconditional. After, it's a guarded check-and-reuse. The result is a stable, predictable pane count regardless of how many times the workflow re-enters that code path."

---

**Questions Slide (5:15–6:00)**
Open for questions.

---