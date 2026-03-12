---
parent: context-epic-144.md
workflow: trivial
---

# Story 144-4: Add Simplify Toggle to repos.yaml

## Business Context

The simplify teammates (simplify-reuse, simplify-quality, simplify-efficiency) currently spawn unconditionally during the TEA verify phase for every story in every repo. This is uncontrolled: some projects benefit from refactoring suggestions, others don't — and when simplify runs on a project that doesn't want it, agent-initiated "improvements" accumulate as undocumented deviations from spec. This directly undermines the spec fidelity goal of epic 144.

This story adds a single per-repo boolean toggle — `simplify_enabled` — to `.pennyfarthing/repos.yaml`. Default is `false`. When off, simplify teammates do not spawn; verify runs quality-pass only. When on, existing behavior is preserved.

The toggle is checked at runtime when TEA enters verify, not cached at workflow start. This means an operator can flip the setting mid-sprint without restarting anything — the next verify phase picks it up immediately (NFR-8).

The business outcome: simplify runs only where the project operator has explicitly opted in. Projects that disable simplify see zero agent-initiated refactoring beyond what the spec requires.

## Technical Guardrails

### Key File to Modify

| File | Change |
|------|--------|
| `.pennyfarthing/repos.yaml` | Add `simplify_enabled: false` to both `orchestrator` and `pennyfarthing` repo entries |

No other files change in this story. The workflow engine's runtime behavior (reading the flag and conditionally spawning teammates) is wired in story 144-9 (TDD workflow update). This story is purely the configuration schema change.

### Pattern to Follow

Existing repos.yaml fields (`branch_strategy`, `test_command`, `ui_layer`, etc.) are per-repo settings nested under each repo key. The new field follows the same pattern:

```yaml
repos:
  orchestrator:
    simplify_enabled: false
  pennyfarthing:
    simplify_enabled: false
```

### Runtime Read Location

Per the PRD (FR-7, NFR-8): the workflow engine reads `repos.yaml` fresh at TEA verify phase entry. This is already how other repos.yaml fields are consumed — no caching mechanism exists today, so the runtime read behavior is already the default. No additional implementation is needed in this story to achieve NFR-8.

### What NOT to Touch

- `pennyfarthing-dist/workflows/tdd.yaml` — workflow changes are story 144-9's scope
- Any gate files — no gate logic changes in this story
- Agent definitions — no changes to tea.md or simplify teammate definitions
- The `tdd.yaml` verify phase `team:` block — still present after this story; 144-9 wires the conditional read

## Scope Boundaries

**In scope:**
- Add `simplify_enabled: false` to the `orchestrator` repo entry in `.pennyfarthing/repos.yaml`
- Add `simplify_enabled: false` to the `pennyfarthing` repo entry in `.pennyfarthing/repos.yaml`
- The field is the single deliverable — schema presence is the AC

**Out of scope:**
- Workflow engine logic that reads and acts on the flag (story 144-9)
- Any changes to tdd.yaml verify phase (story 144-9)
- Setting `simplify_enabled: true` for any repo (operator decision, not framework default)
- Documentation or guide updates about the toggle (optional future work)
- Changes to the simplify agent definitions themselves

## AC Context

**AC 1: Missing field defaults to false**

Given `repos.yaml` with no `simplify_enabled` field for a repo, when the workflow engine reads the config at TEA verify phase entry, it defaults to `false`. This AC validates the default behavior — the flag need not be present for every repo to function. After this story, both repos will have the field explicitly set, but any newly initialized repo without it should also default to false. A test for this would confirm that the workflow engine (in 144-9) treats absence identically to `false`.

**AC 2: simplify_enabled: true causes simplify teammates to spawn**

Given `repos.yaml` with `simplify_enabled: true` for the pennyfarthing repo, when TEA enters the verify phase for a story in that repo, then simplify-reuse, simplify-quality, and simplify-efficiency spawn as teammates. The three teammate names are the exact agents defined in the current `tdd.yaml` verify phase `team:` block — no new agents, same behavior as today but now gated on the flag.

**AC 3: simplify_enabled: false suppresses simplify teammates**

Given `repos.yaml` with `simplify_enabled: false` for the orchestrator repo, when TEA enters the verify phase for a story in that repo, then simplify teammates do not spawn; verify runs quality-pass gate only. This is the default state after this story completes for both repos.

**AC 4: Runtime read, not cached**

Given an operator changes `simplify_enabled` from false to true between phases (e.g., after green, before verify), when TEA enters verify, it reads the current value from repos.yaml — not whatever value existed at workflow start. This is testable by confirming no caching layer stores the flag at session initialization. Since repos.yaml is already read at runtime for other fields, this AC is structurally satisfied by the existing read pattern — 144-9 just needs to not cache the value when it wires the conditional.

## Assumptions

No cross-story assumptions within epic 144. This story is Phase A (independent) and has no dependencies on any other 144-x story.

Assumes repos.yaml schema can be extended with a new per-repo field (`simplify_enabled`) without breaking existing consumers. This holds because all existing consumers read specific named fields — adding a new field is additive and ignored by readers that don't reference it.
