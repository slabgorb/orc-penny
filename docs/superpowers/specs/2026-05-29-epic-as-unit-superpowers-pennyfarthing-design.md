# Epic-as-Unit: Superpowers Execution Over a Pennyfarthing Ledger — Design

**Date:** 2026-05-29
**Status:** Approved (design); pending implementation plan
**Predecessor context:** `docs/superpowers/specs/2026-04-16-superpowers-integration-design.md`, `2026-04-19-sdd-workflow-design.md`

## Problem

Pennyfarthing (PF) and superpowers are both in active use across consumer projects
(`~/Projects/words`, `~/Projects/sidequest`), but they run **side by side and
disconnected**. Each system has complementary strengths that the other lacks:

**Superpowers strengths**
- Works at the epic/feature level; ships a feature end-to-end.
- Few wiring problems between steps.
- Cuts ceremony; conserves tokens.
- Selects the right model per task far better than PF (PF tends to be Opus-or-Haiku).

**Pennyfarthing strengths**
- Far more documentation; the historical record of *what happened* is clear.
- Structured ledger (epics → stories) that git tracks and humans read.

**The gap:** superpowers specs/plans live in `docs/superpowers/`, PF epics live in
`sprint/`, and nothing bridges them. Superpowers plans, while thorough, do not break
work down into PF-compatible historical units (stories). Consumers already accumulate
dozens of plans in `docs/superpowers/plans/` while their `sprint/epic-*.yaml` ledgers
sit untouched.

## Goal

Make the **epic** the unit of work in Pennyfarthing. Each epic is brainstormed and
planned with superpowers; the resulting plan is materialized as a PF epic in the
sprint; as the plan executes, each plan Task corresponds to a PF story that is marked
done — one at a time — as its unit of work is committed.

Superpowers owns *thinking and doing*. Pennyfarthing owns *structure and record*.
The plan's task list is the bridge.

## Locked Decisions

1. **Execution engine.** Superpowers (`executing-plans` / `subagent-driven-development`)
   executes the plan. The per-story phased workflow (TEA → Dev → Reviewer, gates,
   handoffs, sessions) is **bypassed** for plan-driven stories. Adversarial review
   happens **once at epic completion**, as a rollup — fanned out per affected repo.
   - *Future aspiration (not in scope):* `subagent-driven-development` dispatches
     role-appropriate PF personas per task type (TEA for test steps, Dev for
     implementation). Deferred because per-task role routing is hard; the rollup
     review covers correctness for now.

2. **Unit mapping.** **1 Task = 1 story = 1 unit of work.** A single unit may produce
   **multiple commits across multiple repos** (e.g. a story touching `sidequest-ui`
   and `sidequest-server`). Stories may be sub-1-point; that is acceptable.

3. **Progress sync.** Story completion is an **explicit, deterministic act**, not
   inferred from a commit (a unit may span repos/commits). The plan's `writing-plans`
   output injects a final step into every Task: `pf sprint story complete <id>`. The
   executing engine runs it verbatim like any other step (SOUL #11, Automatic Beats
   Instructional). Source of truth for "done" = the `pf` command.

4. **Artifacts & source of truth.** `pf epic from-plan <plan.md>` parses the plan's
   `### Task N` headers and generates one story per task in an epic shard (via the
   existing story-add path). **The plan markdown is the source of truth** for task
   definitions (SOUL #2, One Truth One Place); the epic YAML is a generated ledger/index.

5. **Orchestration.** A single repurposed **`/pf-epic` conductor skill** owns the arc
   `brainstorm → plan → from-plan → execute → rollup review`. The existing `pf epic`
   CLI verbs (`start`/`close`/`show`/`add`/`update`/…) are retained; one new verb,
   `pf epic from-plan`, is added.

## Architecture

```
/pf-epic  (repurposed conductor skill)
  │
  ├─ brainstorm ──▶ superpowers:brainstorming      → docs/superpowers/specs/<date>-<topic>-design.md
  ├─ plan ────────▶ superpowers:writing-plans       → docs/superpowers/plans/<date>-<feature>.md
  │                   (plan carries a story-anchor line per Task)
  ├─ materialize ─▶ pf epic from-plan <plan.md>      → sprint/epic-NNN.yaml (1 story per ### Task N)
  ├─ execute ─────▶ superpowers:executing-plans / subagent-driven-development
  │                   each Task's closing step: pf sprint story complete <id>
  │                   (commits land across N repos per repos.yaml)
  └─ review ──────▶ rollup: one /pf-reviewer pass PER affected repo
                      (base branch + PR target from repos.yaml) → pf epic close → archive
```

### Source-of-truth summary

| Artifact | Role | Authority |
|----------|------|-----------|
| `docs/superpowers/specs/*.md` | Design intent | Brainstorm output |
| `docs/superpowers/plans/*.md` | Task definitions + bite-sized steps + checkboxes | **Source of truth** |
| `sprint/epic-NNN.yaml` | Generated ledger / index | Projection of the plan |
| Story `status: done` | Completion record | Set only via `pf sprint story complete` |

## Components

### 1. `pf epic from-plan <plan.md>` — new CLI verb

- Parses `### Task N: <title>` headers from the plan.
- Creates (or adopts) an epic shard and mints **one story per Task** via the existing
  story-add code path. **Never hand-edits YAML** (SOUL #2).
- Per-story fields:
  - `title` ← Task header text.
  - `repos` ← derived from the Task's `Files:` block by **longest-prefix match** of
    each file path against `repos.yaml` repo `path` entries. Single-repo projects
    resolve trivially to the one repo. A unit touching multiple repos lists all.
  - `points` ← default `1` (override via an optional Task tag).
  - `workflow: superpowers` ← sentinel (see Component 3).
  - `status: backlog`.
  - **back-link** ← plan file path + Task anchor (used by `story complete`).
- **Idempotent.** Re-running adds newly-introduced Tasks and never clobbers stories
  already marked `done` (supports plan edits mid-epic).
- Returns `{success, data?, error?}` (SOUL #10).

### 2. `pf sprint story complete <id>` — new/aliased CLI verb

- Flips story `status → done`, stamping `started`/`completed`.
- Resolves the story's plan back-link and **checks the corresponding `### Task N`
  checkbox(es)** in the source plan markdown.
- Repo-agnostic on the ledger side: the number of repos/commits backing the unit is
  irrelevant to the status flip.
- Returns `{success, data?, error?}`.

### 3. `workflow: superpowers` sentinel

- Marks stories whose execution is owned by the **plan**, not the phased
  `sm → tea → dev → reviewer` engine.
- For these stories, the per-story phased ceremony (handoffs, per-story gates,
  per-story sessions) is **bypassed**. The epic-level **rollup review** is the gate.
- The finish/merge ceremony still applies at **epic close**.

### 4. `writing-plans` convention (light)

- Generated plans must carry, per Task, enough to map to a story: a stable Task
  id/anchor and the repos touched (derivable from the standard `Files:` block).
- The conductor's `plan` leg adds a one-line instruction so generated plans include a
  story-id placeholder line that `from-plan` keys on, and a closing
  `pf sprint story complete <id>` step per Task.
- The plan remains the source of truth; the convention only makes it machine-mappable.

### 5. `/pf-epic` conductor skill (repurposed)

- Thin sequencer over the five legs. Invokes superpowers skills or `pf` verbs; holds no
  business logic itself.
- **Gates:**
  - **(a)** `from-plan` must have run (epic materialized) before `execute` begins — no
    execution against an unmaterialized epic.
  - **(b)** all stories `done` before `review`.

## Repo-Awareness (the multi-repo case)

`repos.yaml` is the authority. Consumers range from single-repo (`words`: one
`standalone` repo on `main`) to multi-repo (`sidequest`: orchestrator on `main` plus
`sidequest-ui`, `sidequest-content`, `sidequest-daemon`, `sidequest-server`, each its
own git repo with its own remote and `main`/`develop` strategy; PRs target individual
subrepos).

- A Task touching `sidequest-ui` + `sidequest-server` → one story, `repos: [ui, server]`.
- **Rollup review** = union of all stories' `repos:`, fanned out as **one review per
  repo**, each against that repo's `repos.yaml` `default_branch` / `branch_strategy`,
  with PRs to each subrepo. `words` collapses this to a single pass.

## Error Handling

- `from-plan` and `story complete` return `{success, data?, error?}` — every failure is
  visible, every caller decides (SOUL #10).
- `from-plan` is idempotent and safe to re-run after plan edits.
- A mid-execution blocker triggers superpowers' existing stop-and-ask behavior; the
  in-flight story stays `in_progress`. Nothing is silently skipped.

## Testing

- pytest in `pennyfarthing-dist/src/pf/`:
  - `from-plan` parser: fixture plans → expected story set (titles, repos, anchors).
  - `story complete`: status flip + plan checkbox edit + back-link resolution.
  - files → repos longest-prefix mapping against a fixture `repos.yaml`.
- Dogfood order: orchestrator → `words` (single-repo) → `sidequest` (multi-repo).

## Distribution & Dogfooding

- All three glue points (`from-plan`, `story complete`, repurposed `/pf-epic`) ship in
  the **distributed package** (`pennyfarthing-dist/`), run as plain `pf …`, and assume
  **no inlined source** and **possibly many repos**.
- The orchestrator uses symlinked source; consumers use installed copies (plugin-bound).
  Edit source at `pennyfarthing/pennyfarthing-dist/`, never the symlinked `.pennyfarthing/`.

## Out of Scope

- Role-appropriate per-task agent dispatch (future aspiration; rollup review covers
  correctness for now).
- Two-way plan↔epic sync (plan is the sole source of truth).
- Retrofitting the dozens of historical plans already in `words`/`sidequest`
  (YAGNI; the flow is forward-looking).
- Migration tooling for the cutover (handled manually, per standing preference).
