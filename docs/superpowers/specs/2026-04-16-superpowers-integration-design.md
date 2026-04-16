# Superpowers Plugin Integration — Design

**Status:** Draft
**Date:** 2026-04-16
**Author:** Keith Avery (via brainstorm with SM)

## Context

Pennyfarthing has accumulated generic software-craft skills (brainstorming, systematic debugging, code review checklists) that duplicate capabilities now available in the `superpowers@claude-plugins-official` Claude Code plugin. The pf-brainstorming command in particular was derived from the same BMAD source material that shaped superpowers' own brainstorming skill.

The goal is **best of both worlds**: pennyfarthing stops maintaining parallel implementations of generic workflows and instead declares superpowers as a required companion plugin. Pennyfarthing keeps sole ownership of its framework-specific machinery — sprint tracking, handoffs, workflows, themes, Jira, tmux, benchmarks — and treats superpowers skills as first-class participants in that machinery.

Superpowers skills wire into pennyfarthing in two ways: thin forwarder commands that preserve the `/pf-*` namespace for user-facing workflows, and atomic gate files that invoke or verify superpowers skills as part of phase-transition enforcement.

## Principles

1. **Don't duplicate superpowers.** If superpowers ships a skill that covers a pf skill's purpose, pf's version gets deleted or converted to a forwarder.
2. **Pennyfarthing owns framework-specific work.** Sprint, handoff, workflow, themes, Jira, tmux, peloton, persona-benchmark stay pennyfarthing-native.
3. **Gates are the enforcement seam.** Superpowers skills that represent quality checks (verification-before-completion, TDD discipline, code review ceremony) get invoked from gate files, not from agent memory.
4. **Superpowers is a required companion plugin.** Pennyfarthing docs, health check, and setup wizard reflect this; agents may freely reference `superpowers:*` skills.

## Taxonomy

Every superpowers skill fits into exactly one of three tracks.

### Track 1 — Forwarder Commands (user-invoked)

Preserve `/pf-*` muscle memory; implementation lives in superpowers.

| pf entrypoint | Forwards to |
|---------------|-------------|
| `/pf-brainstorming` | `superpowers:brainstorming` |
| `/pf-write-plan` | `superpowers:writing-plans` |
| `/pf-execute-plan` | `superpowers:executing-plans` |
| `/pf-worktree` | `superpowers:using-git-worktrees` |
| `/pf-parallel` | `superpowers:dispatching-parallel-agents` |
| `/pf-write-skill` | `superpowers:writing-skills` |
| `/pf-systematic-debugging` | `superpowers:systematic-debugging` |

### Track 2 — Atomic Gates (enforcement, not user-typed)

Each skill becomes one gate file in `pennyfarthing-dist/gates/`. Composes into existing and new composite gates.

| Gate file | Wraps | Verifies |
|-----------|-------|----------|
| `superpowers-brainstorming.md` | `superpowers:brainstorming` | Spec file exists at `docs/superpowers/specs/*` |
| `superpowers-verification.md` | `superpowers:verification-before-completion` | Session marker or transcript evidence |
| `superpowers-requesting-review.md` | `superpowers:requesting-code-review` | Review request artifact in session |
| `superpowers-receiving-review.md` | `superpowers:receiving-code-review` | Delivery-findings updated after review |
| `superpowers-tdd.md` | `superpowers:test-driven-development` | Test file diff precedes implementation diff |
| `superpowers-finishing-branch.md` | `superpowers:finishing-a-development-branch` | Branch finish checklist artifact |

### Track 3 — Reference Only

Named in agent guides; no adapter, no gate.

- `superpowers:subagent-driven-development` — technique cited in `guides/agent-behavior.md`
- `superpowers:using-superpowers` — already fires via plugin SessionStart hook

## Track 1 Design — Forwarder Pattern

A forwarder command is the thinnest possible shim. Example `pennyfarthing-dist/commands/pf-brainstorming.md`:

```md
---
description: Brainstorm ideas into designs (forwarder to superpowers:brainstorming)
---

Invoke the `superpowers:brainstorming` skill via the Skill tool. No preamble.
```

Three lines plus frontmatter. Identical shape for every other forwarder.

### Skill Registry Changes

`pennyfarthing-dist/skills/skill-registry.schema.json` gains one optional field:

```yaml
delegates_to: "superpowers:<skill-name>"
```

Entries that duplicate a superpowers skill keep their registry row but set `delegates_to:` and drop their `skills/pf-*/` folder contents. The registry remains the discovery surface for `pf skill list` and points users at the correct invocation.

### Deletions

- `pennyfarthing-dist/commands/pf-brainstorming.md` — existing BMAD-derived time-boxed session content. Replaced by forwarder.
- `pennyfarthing-dist/skills/pf-systematic-debugging/` — entire folder. Registry entry kept with `delegates_to:`.

## Track 2 Design — Atomic Gate Pattern

Each atomic gate is one file using the existing gate schema (`schemas/gate-schema.md`). No schema changes required. The `<fail>` block instructs the agent to invoke the wrapped skill; the `<pass>` block verifies the artifact.

Gates are fungible and recursive — composite gates reference atoms by name and the runtime resolves them through the existing `gates/{name}.md` discovery path. Composition example:

```xml
<gate name="dev-exit">
  <gate name="tests-pass"/>
  <gate name="quality-pass"/>
  <gate name="superpowers-verification"/>
</gate>
```

### Pass Criteria Pattern

Atomic gates favor **artifact checks over agent claims**. Each atom's `<pass>` block verifies a concrete file, session field, or diff pattern rather than asking the gate subagent to certify that the skill "actually ran." This keeps gates cheap, deterministic, and resistant to agent hallucination.

Where no natural artifact exists, the gate's `<fail>` block directs the agent to invoke the skill and write a specific session marker (e.g., `verification.completed: <timestamp>`), which the `<pass>` block then checks.

### Workflow Wiring

Atoms compose into existing and new composite gates:

- `dev-exit` — add `superpowers-verification` as child
- `red-phase-entry` (new or via `tests-fail`) — compose `superpowers-tdd` + `tests-fail`
- `review-entry` (new composite) — compose `superpowers-requesting-review` + `quality-pass`
- `release-ready` — add `superpowers-finishing-branch` as child
- Reviewer post-delivery — `superpowers-receiving-review` fires when Delivery Findings block populates

Workflow YAMLs (`tdd.yaml`, `bdd.yaml`, etc.) don't require structural changes; they already reference gates by name.

## Dependency Declaration

Pennyfarthing declares `superpowers@claude-plugins-official` as a required companion plugin.

- **`pf health-check`** — warns loudly if superpowers plugin is not installed
- **`/pf-setup` wizard** — adds "install superpowers" as a post-install step with the exact `/plugin install` command
- **Framework `CLAUDE.md`** — names superpowers in the install prerequisites section
- **Agent `<skills>` blocks** — Dev, TEA, Reviewer agents list `superpowers:*` skills alongside `/pf-*` entries so prime output includes them

## Rollout Order

Each step is one story unless noted.

1. **Pilot — brainstorming forwarder.** Replace `pf-brainstorming.md` with forwarder content. Add superpowers to `pf health-check` and setup wizard. Trivial workflow, 1-2 pts.
2. **Expand Track 1 forwarders.** Write remaining forwarder commands. Delete `pf-systematic-debugging/` folder. Add `delegates_to:` field to registry schema. 2-3 pts.
3. **Introduce atomic gates.** Write the six `superpowers-*.md` atomic gate files. No workflow wiring yet. 3 pts.
4. **Wire atoms into composites.** One story per composite touched (dev-exit, review-entry, release-ready, red-phase-entry). 2-3 pts each, sequential.
5. **Agent `<skills>` refresh.** Dev, TEA, Reviewer agent files gain `superpowers:*` references in their skills blocks. Tech-writer story, 1-2 pts.

## Out of Scope

- Hook-based auto-invocation of superpowers skills. Gates are sufficient for enforcement; hook automation can be revisited after atoms are in production.
- Vendoring or forking superpowers skill content into pennyfarthing-dist. Hard dependency only.
- Migrating `pf-code-review` or `pf-testing` into the forwarder pattern. They sit at different abstraction layers than their superpowers counterparts and stay pennyfarthing-owned for now.
- Auto-chaining (e.g., brainstorming → writing-plans → implementation). Each transition stays user-initiated.

## Open Questions

None blocking. Implementation may surface schema edge cases in the `delegates_to:` field, and Track 2 artifact criteria for individual atoms will be finalized as each gate file is authored.
