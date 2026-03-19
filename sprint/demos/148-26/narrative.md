# Narrative

## Problem Statement
**Problem:** During a Peloton benchmark run — where a full team of AI agents (Test Engineer, Developer, Reviewer) work together in a shared terminal — the system kept opening extra terminal windows for each agent role every time it checked in. A reviewer agent that should have had one window ended up with two, three, or more, cluttering the screen and wasting resources.

**Why it matters:** Peloton is how we measure whether our AI pipeline is improving. If the test harness itself is unreliable — spawning phantom windows and confusing the agent coordination layer — benchmark results become noisy and the team loses confidence in what the data is actually telling them.

---

## What Changed
Think of each AI agent (Tea, Dev, Reviewer) as having an assigned desk in an open office. Before this fix, every time the system checked whether an agent was at their desk, it would pull up a *new* desk for them — even if they were already sitting at one. After enough check-ins, the office was full of empty desks that nobody was using.

The fix teaches the system to look for an existing desk before pulling up a new one. It checks two places: its own memory (is this agent already seated?) and the room's seating chart (is there a registered desk that's still in use?). Only if neither check turns up a live seat does it open a new one.

---

## Why This Approach
The check was intentionally built in two layers:

1. **In-memory first** — the fastest check. If this orchestrator instance already created a pane for "dev," don't create another.
2. **Registry fallback** — handles the case where a pane was created in a previous run and is still alive in the terminal. The system can adopt it rather than orphan it.

A third case is handled cleanly: if the registry *says* a pane exists but it's no longer actually alive in the terminal, the system creates a fresh one. No blind reuse of dead processes.

This keeps the fix surgical — no architectural changes, no new state machines, just a guard at the one place where allocation happens (`_create_pane`).

---

## Before/After
| | Before | After |
|---|---|---|
| **First spawn (3 roles)** | 3 panes created | 3 panes created |
| **Second spawn (same roles)** | 3 more panes created — now 6 total | Existing 3 panes reused — still 3 total |
| **Registry has a live "dev" pane** | Ignored — new pane created anyway | Reused — same pane ID returned |
| **Registry has a dead "dev" pane** | Ignored — new pane created | Dead entry skipped — new pane created |
| **Workflow retry mid-benchmark** | Pane count doubles each retry | Pane count stays flat |
| **Teardown** | All orphaned panes must be hunted and killed | Only the canonical set of panes to clean up |
