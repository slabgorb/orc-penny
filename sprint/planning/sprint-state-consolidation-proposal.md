# Proposal: Sprint State Engine Consolidation

**Date:** 2026-02-21
**Author:** M. Pursifull
**Status:** Draft
**Relates to:** prd-sprint-data-management.md, ADR-0018 (never edit YAML directly), GH issue #1028

---

## Problem

Sprint, epic, and story state is fragmented across 6 storage locations, read by 4 independent implementations, and synchronized by manual batch operations. This creates status drift (we found 11 mismatches in a single reconciliation pass on 2026-02-21), reader divergence (TypeScript and Python merge shards differently), and architectural hacks (the "active sprint switching" feature works by swapping file paths in a gitignored config file).

The existing PRD (prd-sprint-data-management.md) addressed the *write* side — deterministic YAML I/O, validation, atomic writes. This proposal addresses the *read* side and the *coordination* problem across consumers.

---

## Current State

### Where status lives (6 locations)

| # | Location | What it stores | Who writes it |
|---|----------|---------------|---------------|
| 1 | `sprint/epic-*.yaml` shards | Story status, points, assignee, dates | Python CLI (`yaml_io.py`) |
| 2 | Jira tickets | Status, points, assignee, sprint membership | Jira UI, `sync.py`, `story_finish.py` |
| 3 | `.session/{id}-session.md` | Active work context, phase, branch, PR | Agent sessions |
| 4 | `.pennyfarthing/config.local.yaml` | Per-user active sprint preference | `pf sprint use` |
| 5 | `sprint/sprints.yaml` | Registry mapping names to file paths + metadata | Manual / CLI |
| 6 | TypeScript in-memory (`sprint-data.ts`) | Merged sprint view, broadcast via WebSocket | File watcher triggers |

### Who reads it (4 independent implementations)

| Reader | Language | Files | Lines | Shard merge? | Registry resolution? | Orphan detection? |
|--------|----------|-------|-------|-------------|----------------------|-------------------|
| Python CLI | Python | `loader.py`, `yaml_io.py`, `shard_merge.py` | ~1100 | Yes | Yes | Yes |
| Cyclist server | TypeScript | `sprint-data.ts` | 656 | Yes | Yes (added 120-6) | No |
| BikeRack TUI | Python | `sprint_panel.py` | ~200 | Via CLI | Partial | No |
| Jira sync | Python | `sync.py`, `reconcile.py`, `bidirectional.py` | ~460 | Via `loader.py` | No | No |

### Known divergences

1. TypeScript doesn't detect orphan epic shards on disk (Python does via directory scan)
2. Future initiative resolution differs between TypeScript and Python
3. Session files have no structural link to sprint YAML — tied by naming convention only
4. Jira sync is batch-only; status can drift between runs indefinitely

---

## The Planning Model

### The 90%: Centralized orchestration

The orchestrator repo is the single home for all planning. Sprint YAML, epic shards, story context, session files — they all live here, even when the *code* lives in child repos (`pennyfarthing/`, sibling repos, etc.). This is by design: coordinating work across related repositories is the orchestrator's reason for existing. Projects do not own their own planning.

This means `sprint/current-sprint.yaml` in the orchestrator is the default source of truth for everyone on the team. No registry lookup, no config preference, no indirection. Most of the time, there's one sprint, one view, one set of files.

### The 10%: Focus switching for spikes and feature work

Occasionally, a person or sub-team needs to split off and focus on a scoped effort — a research spike in a sibling repo, a feature-focused mini-sprint, a proof of concept. These efforts may have their own sprint files, context roots, and session directories, sometimes in a different repo entirely.

The sprint registry (`sprints.yaml`) was introduced for this case. The mechanism:

1. `pf sprint use ocsf-rs1` writes `sprint.active: ocsf-rs1` to `config.local.yaml` (gitignored)
2. `loader.py` resolves `ocsf-rs1` → registry entry → `file: ../spike-ocsf-rs1/sprint/current-sprint.yaml`
3. Each registry entry can override `context_root` and `session_root`

This is an important 10%. When you assign someone to a spike, they need their tools to reflect that focus — the sprint panel should show the spike's stories, sessions should write to the spike's directory, and context files should resolve from the spike's tree. Getting this wrong means the focused person is fighting their tools instead of doing the work.

But the current implementation breaks down because:

- The TypeScript server reimplemented resolution independently (story 120-6)
- The Python TUI may or may not use the same resolution path
- The preference is per-user and invisible to teammates
- There's no concept of "sprint context" as a coherent bundle — just scattered path overrides
- Switching focus doesn't switch session files, context files, or repo scope — only the sprint YAML path

What the user *actually wants* when they "switch focus" is to **change their entire working context** — not just which YAML file gets loaded into the sprint panel.

---

## Proposed Consolidation

### Move 1: SprintContext as a first-class object (low effort, high leverage)

Define a `SprintContext` that bundles everything needed to work in a sprint:

```python
@dataclass
class SprintContext:
    name: str                    # "main", "ocsf-rs1"
    type: str                    # "project", "spike", "research"
    sprint_file: Path            # Resolved absolute path to sprint YAML
    context_root: Path           # Where story context .md files live
    session_root: Path           # Where .session/ files live
    repos: list[str]             # Which repos this sprint covers
    description: str             # Human-readable description
    is_default: bool             # True when using the orchestrator's main sprint
```

**The default case is simple:** When no preference is set (the 90%), `SprintContext` resolves to the orchestrator's own `sprint/current-sprint.yaml`, `sprint/context/`, `.session/`, with `is_default=True`. No registry lookup needed. The object still exists — it just reflects "you're on the main sprint, as expected."

**The focus case uses the registry:** When a user has switched focus (`pf sprint use ocsf-rs1`), the context resolves through `sprints.yaml` to the scoped sprint's file paths, with `is_default=False`. This is visible in the UI as a provenance indicator — "you're focused on a spike, not the main sprint."

**Resolution:** One function, `resolve_sprint_context(project_root) -> SprintContext`, replaces all the scattered "read config, look up registry, resolve path" logic. Every consumer calls it.

**Why this matters for #1028:** The TUI provenance display becomes trivial — render `context.name` and `context.type` when `is_default` is False, show nothing extra when it's True. No need for each UI to independently figure out "which sprint am I showing?"

### Move 2: Single canonical data service (medium effort, eliminates divergence)

Python is the canonical implementation for sprint data reading. It has the most complete logic (orphan detection, shard merge, validation). The TypeScript layer should not reimplement it.

**Option A — Subprocess:** TypeScript calls `pf sprint data --json` and parses the output. Simple, uses existing CLI.

**Option B — HTTP endpoint:** The WheelHub server (already in `packages/core/src/server/`) exposes `/api/sprint` backed by the Python CLI. TypeScript UI consumes the API.

**Option C — Shared schema, separate implementations with conformance tests:** Keep both implementations but add a test suite that runs the same inputs through Python and TypeScript and asserts identical output.

**Recommendation:** Option A for immediate wins, migrate to Option B as WheelHub matures. Option C as a safety net regardless.

### Move 3: Story lifecycle state machine (high effort, prevents drift)

Define explicit state transitions with atomic multi-system updates:

```
backlog → in_progress → review → done
    ↓         ↓           ↓
 canceled  canceled    canceled
```

Each transition is a single operation that:
1. Validates the transition is legal (e.g., can't go from `backlog` to `done`)
2. Updates the YAML shard atomically
3. Transitions the Jira ticket
4. Creates/updates/archives the session file
5. Emits a WebSocket event for real-time UI update

If any step fails, the operation reports the failure with partial state (no silent drift).

This replaces the current approach where `story_finish.py` does steps 2-5 for the `review → done` case, but every other transition is ad-hoc YAML edits + manual Jira updates.

### Move 4: Event-driven Jira sync (medium effort, eliminates batch reconciliation)

Every story transition (Move 3) syncs to Jira immediately. The batch `pf sprint sync` / `pf sprint reconcile` commands become *audit* tools that report drift, not the primary sync mechanism.

This means:
- `pf sprint story update 120-6 --status in_progress` also moves the Jira ticket
- `pf sprint story finish 120-6` (already does this) remains the model
- `pf sprint reconcile` runs periodically to catch anything that slipped through

### Move 5: Focus contexts as managed objects (medium effort, long-term)

The orchestrator centralizes all planning. That doesn't change. What changes is how we handle the 10% case where someone needs to focus on a scoped effort.

Today, `sprints.yaml` is a flat registry of name → path mappings. It knows nothing about *why* the focus exists, *who* is focused there, *when* the focus started, or *whether* it's still active. This makes it impossible to answer questions like "who's working on the OCSF spike right now?" or "is that spike still active or did it end last week?"

Formalize focus contexts as managed objects within the orchestrator:

```yaml
# sprint/sprints.yaml (extended)
sprints:
  main:
    file: current-sprint.yaml
    type: project
    description: Main project sprint
    # No special fields — this is the default, everyone sees it

  ocsf-rs1:
    file: ../spike-ocsf-rs1/sprint/current-sprint.yaml
    type: spike
    description: OCSF log source research spike
    context_root: ../spike-ocsf-rs1/sprint/context/
    session_root: ../spike-ocsf-rs1/.session/
    repos: [spike-ocsf-rs1]
    created: '2026-02-10'
    owner: dev@example.com    # Who initiated the focus
    participants: [dev]         # Who's currently focused here
    status: active                            # active | completed | abandoned
    parent_epic: PROJ-15200                  # Links back to orchestrator planning
```

Key principles:
- **Planning stays centralized.** The orchestrator's `sprint/` directory is still the home for all sprint planning. Focus contexts point *out* to scoped sprint files but are *defined and tracked* in the orchestrator.
- **Focus is explicit, not hidden.** `participants` and `status` fields make it visible who's split off and whether the focus is still active. No more invisible per-user config preferences.
- **Focus links back to planning.** A spike sprint typically exists because of an orchestrator-level epic or initiative. `parent_epic` ties the focus back to the planning hierarchy.
- **Focus has a lifecycle.** Spikes start, run, and end. `status` lets the team track that. `pf sprint focus close ocsf-rs1` marks it completed and optionally rolls findings back into the main sprint.

This doesn't replace `sprints.yaml` — it extends it from a dumb path registry into a managed record of where the team's attention is split.

---

## Sequencing

| Phase | Move | Prerequisite | Delivers |
|-------|------|-------------|----------|
| **Now** | 1 — SprintContext object | None | Unblocks #1028, clarifies "which sprint" everywhere |
| **Next sprint** | 2 — Single data service | Move 1 | Kills TS/Python divergence |
| **Next sprint** | 4 — Event-driven Jira sync | Move 3 (partial) | Eliminates batch reconciliation |
| **Future** | 3 — State machine | Moves 1 + 2 | Atomic transitions, no drift |
| **Future** | 5 — Managed focus contexts | Moves 1 + 2 | Visible, lifecycle-tracked team focus splitting |

---

## Relationship to Existing Work

- **prd-sprint-data-management.md:** Addressed write-side determinism (yaml_io, validation, atomic writes). This proposal addresses read-side consolidation and cross-system coordination. They're complementary.
- **ADR-0018 (never edit YAML directly):** This proposal extends that principle — not just "don't hand-edit YAML" but "don't hand-implement YAML reading either."
- **Story 120-6 (GH #1028):** Move 1 directly unblocks this story. The `SprintContext` object makes provenance display trivial.
- **Sprint reconciliation (2026-02-21 audit):** Moves 3 and 4 prevent the class of problems we found today (11 status mismatches from drift).
- **Orchestrator model:** The orchestrator centralizes planning across repos. This proposal preserves that — Moves 1-4 strengthen the centralized path, Move 5 formalizes the exception case (focus splitting for spikes/features) without undermining centralization.

---

## Open Questions

1. **Primary source of truth:** Is YAML primary with Jira as sync target? Or Jira primary with YAML as cache? Current system treats them as co-equal, which is the root of every reconciliation problem. This proposal assumes YAML-primary.
2. **Option A vs B for Move 2:** Subprocess call is simpler but adds latency per sprint panel refresh. HTTP endpoint is cleaner but requires WheelHub to always be running. Which fits better?
3. **Scope of Move 3:** Should the state machine cover only story status, or also epic status (`planning` → `active` → `complete` → `archived`) and sprint status?
4. **Focus context ownership:** When someone is focused on a spike sprint, should their story transitions still sync to the orchestrator's Jira board? Or does the spike have its own Jira sprint? This affects how Move 4 (event-driven sync) interacts with Move 5 (focus contexts).
5. **Focus visibility vs autonomy:** The `participants` field in Move 5 makes focus visible to the team. Should this be enforced (you must register to work on a spike) or advisory (the system tracks it but doesn't block)?
