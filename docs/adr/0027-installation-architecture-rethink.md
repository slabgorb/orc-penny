# ADR-0027: Installation Architecture Rethink

**Status:** Proposed
**Date:** 2026-02-17
**Author:** Architect (Corporal Newkirk)
**Supersedes:** Partially extends ADR-0005, ADR-0021, ADR-0026

## Context

The current Pennyfarthing installation experience is painful. Users must navigate a multi-step, multi-tool gauntlet spanning npm, Python, symlinks, git hooks, and configuration files — any of which can fail silently or catastrophically.

### Current Install Flow

1. `npm install @pennyfarthing/core` — npm package with postinstall chmod
2. `npx pennyfarthing init` — 19 distinct operations in one shot
3. User must know to run `/setup` — interactive project configuration
4. `pennyfarthing doctor` — 30 health checks because things break

### Root Problems

1. **Two-runtime dependency.** Node handles installation, but Python handles ALL runtime behavior. All 13 Claude Code hooks delegate through shell shims to the `pf` Python CLI. If Python breaks, every hook fails silently.

2. **Init does too much.** 19 operations including 7 directory symlinks, 11 agent sidecar directories, template file generation, git hook installation, Python CLI installation, and a monolithic settings.local.json blob with 13 hooks.

3. **Symlinks solve a development problem, not a user problem.** End users getting the package from npm don't benefit from symlinks — they just get breakage vectors (especially on `npm ci`).

4. **Doctor exists because things break.** 30 health checks means 30 things that can go wrong. The goal should be an architecture where doctor is unnecessary.

5. **Hook registration is a monolith.** `settings.local.json` contains 13 hooks, permissions, MCP servers, context budget — all generated as one blob.

6. **No progressive disclosure.** Users get ALL of Pennyfarthing or NONE.

### Dead Artifacts Discovered

**preferences.yaml** is broken: `init.ts` creates it at `.pennyfarthing/preferences.yaml` but both runtime readers (`persona.py`, `agent-session.sh`) look at `.claude/pennyfarthing/preferences.yaml` (old path). Only 1 of 3 settings has runtime behavior.

## Decision Drivers

- Installation must be fast, reliable, and require minimal user knowledge
- Python must be optional for basic agent operation
- Claude Code's frontmatter hooks (2.1+) allow hooks scoped to component lifecycle
- Existing user configurations must never be destroyed
- `uv tool install` has matured for Python CLI distribution
- Progressive disclosure: simple start, opt into complexity

## Considered Options

### Option 1: Frontmatter-Scoped Hooks (SELECTED)

Move 8 of 13 hooks from `settings.local.json` into agent and skill frontmatter. Each component declares its own hooks. Settings shrinks from 13 hooks to 5.

**Fit: 5/5.** Directly addresses hook monolith and progressive disclosure.

### Option 2: Lazy Init + Auto-Setup Detection (SELECTED)

Split installation into two phases: Init does minimal plumbing (8 ops), then a SessionStart hook auto-detects incomplete setup and triggers `/pf-setup` on next Claude session.

**Fit: 5/5.** Addresses init overload and the setup gap.

### Option 3: Node-First with Optional Python (SELECTED)

Port critical-path hooks (session-start, context-warning, statusline) to Node. Python becomes optional for advanced features (sprint, Jira, workflow).

**Fit: 4/5.** Addresses two-runtime trap. Partial port is pragmatic.

### Option 4: Polite Config Guest Pattern (SELECTED)

Every config modification asks first or merges additively. Never nuke, never overwrite.

**Fit: 5/5.** Addresses config politeness requirement.

### Rejected: Plugin-Based Distribution

Claude Code plugins are still maturing. Pennyfarthing's needs are too complex for current plugin system.

### Rejected: Full Python-to-Node Port

Porting all of `pennyfarthing_scripts` would take months and lose the Python ecosystem (pydriller, ruamel.yaml). Not worth it.

## Decision Outcome

### Three-Phase Installation

**Phase 1: `pennyfarthing init` (immediate, fast, Node only)**

8 operations, no prompts:
1. Create `.pennyfarthing/` directory structure
2. Create `.claude/` directory structure
3. Find node_modules
4. Copy commands to `.claude/commands/` (pf-* prefix)
5. Copy skills to `.claude/skills/` (pf-* prefix)
6. Write base `settings.local.json` (5 hooks only)
7. Write manifest (`setup_completed: false`)
8. Update `.gitignore`

NOT done at init: No Python install, no sidecars, no templates, no git hooks, no theme selection.

**Phase 2: Auto-triggered `/pf-setup` (on first Claude session)**

SessionStart hook (`setup-detector.js`) reads manifest, detects `setup_completed: false`, injects `additionalContext` telling Claude to run `/pf-setup`.

Setup Workflow interactively walks user through:
- Repo discovery → `repos.yaml`
- CLAUDE.md generation
- Theme selection → `config.local.yaml`
- Git hook installation (asks permission)
- Python CLI installation (asks permission)

Setup Workflow writes `setup_completed: true` to manifest on completion.

**Phase 3: Runtime (self-contained components)**

Each agent `.md` declares its own hooks in frontmatter:
```yaml
---
name: pf-dev
hooks:
  PreToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: "\"$CLAUDE_PROJECT_DIR\"/.pennyfarthing/scripts/hooks/pf-wrapper.sh hooks pre-edit-check"
  PostToolUse:
    - hooks:
        - type: command
          command: "\"$CLAUDE_PROJECT_DIR\"/.pennyfarthing/scripts/hooks/pf-wrapper.sh hooks bell-mode"
---
```

Sidecars created lazily on first agent activation, not at init.

### settings.local.json (Minimal — 5 hooks)

| Hook | Event | Purpose |
|------|-------|---------|
| setup-detector.js | SessionStart (startup) | Auto-trigger /pf-setup if needed |
| session-start.js | SessionStart | PROJECT_ROOT, SESSION_ID, WheelHub |
| setup-env.sh | SessionStart | User's environment setup |
| pf-wrapper session-stop | Stop | Session checkpoint |
| pf-wrapper statusline | statusLine | Status bar display |

### config.local.yaml (Single Config)

Absorbs preferences.yaml and persona-config.yaml:
```yaml
theme: hogans-heroes
preferences:
  character_voice: true
  explain_decisions: true
  auto_commit: false
workflow:
  bell_mode: true
  relay_mode: true
display:
  colorPreset: tokyo-night
```

### pf-wrapper.sh (Python Safety Net)

All frontmatter hooks that need Python go through `pf-wrapper.sh`:
```bash
#!/usr/bin/env bash
if ! command -v pf &>/dev/null; then
  exit 0  # Feature unavailable, don't break Claude
fi
exec pf "$@"
```

On first pass-through when `pf` is absent, writes a marker file. SessionStart detects the marker and injects a one-time message suggesting Python installation.

### Component Structure

| Component | Responsibility | Phase |
|-----------|---------------|-------|
| Init Command | Minimal bootstrap (8 ops) | Install |
| Setup Detector | SessionStart hook, checks manifest | First session |
| Setup Workflow | Interactive configuration | First session |
| File Copier | Copy pf-* commands/skills | Install + Update |
| Config Manager | Single config.local.yaml | Runtime |
| Agent Definitions | Self-contained with frontmatter hooks | Runtime |
| Skill Definitions | Self-contained with frontmatter hooks | Runtime |
| Sidecar Lazy Creator | Creates sidecars on first activation | Runtime |
| pf-wrapper.sh | Python CLI safety net | Runtime |
| Python CLI (optional) | Sprint, Jira, workflow, prime | Runtime |
| Doctor (reduced) | ~10 health checks (down from 30) | Maintenance |
| Manifest | Version, migrations, setup_completed flag | All phases |

### Boundary Decisions

1. **Init ↔ Setup:** Init does filesystem plumbing (silent). Setup does user configuration (interactive). Bridge: manifest `setup_completed` flag.
2. **settings.local.json ↔ Frontmatter:** Infrastructure hooks in settings. Component hooks in frontmatter. Rule: Active Scope Principle.
3. **Node ↔ Python:** Node owns init/update/doctor/base hooks. Python owns sprint/Jira/workflow/prime. Bridge: pf-wrapper.sh.
4. **Framework ↔ User:** Framework owns pf-* prefixed files. User owns everything else. Framework NEVER writes user files after init.
5. **Dogfooding ↔ End-user:** Dogfooding uses symlinks. End-users use copies. Manifest `installationType` field.

## Consequences

### Positive

- **One install, one command.** `npm install && npx pennyfarthing init` → done. Setup auto-triggers.
- **Python is optional.** Basic agent operation works with zero Python. Sprint/Jira/workflow are opt-in.
- **Hooks are self-contained.** Each agent/skill carries its own hooks. No monolithic blob.
- **Init is fast and safe.** 8 operations instead of 19. No git hooks, no Python install, no templates.
- **Doctor shrinks.** ~10 checks instead of 30 because fewer things can break.
- **Config is consolidated.** One file (config.local.yaml) instead of three (+ preferences.yaml + persona-config.yaml).
- **User configs are respected.** Polite merge pattern, opt-in git hooks, pf- namespace.

### Negative

- **Frontmatter hooks are new territory.** Claude Code 2.1+ feature, untested at Pennyfarthing's scale. Requires spike.
- **Major version bump required.** Migration from v11 (13 hooks) to v12 (5 hooks + frontmatter).
- **pf-wrapper silent failure.** Users may not realize Python features are missing. Mitigated by one-time notification.
- **Two-phase install may confuse.** "I ran init, why is it asking me to set up?" Mitigated by clear messaging.
- **Session-start.js must be ported from Python.** One-time effort, but behavior must match exactly.

### Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Frontmatter hooks unreliable | High | Medium | Spike required. Fallback to reduced settings.local.json. |
| Breaking existing installs | High | Medium | Migration preserves user hooks, only replaces pf- hooks. |
| pf-wrapper masks missing features | Medium | High | One-time SessionStart notification when pf is absent. |
| Setup Detector loops | Medium | Low | Session-scoped guard file prevents re-trigger. |
| Config migration breaks personas | High | Medium | Audit all readers. Update atomically. Test every agent. |

## Implementation Consistency Rules

> These rules prevent AI agents from making conflicting implementation choices.

1. **Active Scope Principle.** Component-specific hooks → frontmatter. Infrastructure hooks → settings.local.json.
2. **Init never prompts, Setup always prompts.** Clear split of silent vs. interactive.
3. **Config Manager is single source.** Kill preferences.yaml. Absorb into config.local.yaml.
4. **Python is optional, never silent-fail.** Clear message if missing. pf-wrapper.sh is the only Python entry point.
5. **Manifest flags, not filesystem heuristics.** `setup_completed: true/false`. Don't check file existence.
6. **pf- prefix is the namespace boundary.** Framework files prefixed. User files not. Update never touches unprefixed files.
7. **Git hooks are opt-in.** Offered during Setup, not forced during Init.
8. **Sidecars are lazy.** Created on first agent activation, not at init.

## Contract Enforcement Rules

1. **CE-1:** Setup Detector reads manifest only, never filesystem heuristics.
2. **CE-2:** pf-wrapper.sh is the ONLY way frontmatter hooks call Python.
3. **CE-3:** Init output is deterministic and idempotent.
4. **CE-4:** Framework files require pf- prefix. Violating this destroys user content.
5. **CE-5:** Config reads MUST have defaults. Missing key = default, not error.

## Implementation Plan

### Phase 0: Spike (before any implementation)
- Test Claude Code frontmatter hooks with 3 Pennyfarthing agents
- Verify hook lifecycle (fire on active, cleanup on inactive)
- Verify no conflicts with overlapping hook events
- If spike fails: fall back to reduced settings.local.json

### Phase 1: Foundation (non-breaking)
- Write setup-detector.js (Node)
- Write session-start.js (Node)
- Write pf-wrapper.sh
- Create new config.local.yaml schema
- Write migration 0006: preferences.yaml → config.local.yaml

### Phase 2: Frontmatter Migration (breaking, major version)
- Add frontmatter hooks to all agent .md files
- Add frontmatter hooks to relevant skill directories
- Write migration 0007: shrink settings.local.json from 13 to 5 hooks
- Update init.ts: reduce to 8 operations
- Update Setup Workflow to handle deferred configuration

### Phase 3: Cleanup
- Remove dead preferences.yaml template
- Remove dead persona-config.yaml template
- Update doctor: remove checks for things that can't break anymore
- Update all documentation

### Migration Testing Checklist
- [ ] Fresh install on empty project
- [ ] Upgrade from v11.x to v12.x
- [ ] Upgrade preserves user custom hooks
- [ ] Upgrade preserves user custom commands/skills
- [ ] Setup Detector triggers correctly on first session
- [ ] Setup Detector does NOT trigger after setup complete
- [ ] pf-wrapper works with Python installed
- [ ] pf-wrapper gracefully handles missing Python
- [ ] Frontmatter hooks fire correctly for agents
- [ ] Frontmatter hooks fire correctly for skills
- [ ] Dogfooding mode still works

## Related Decisions

- [ADR-0005: Single Source of Truth via Symlinks](0005-single-source-of-truth-symlinks.md) — foundational symlink architecture (still valid for dogfooding; end-users get copies)
- [ADR-0021: Safe Install, Upgrade, and Namespace Isolation](0021-safe-install-upgrade-path.md) — migration system and pf- prefix (partially implemented; this ADR extends it)
- [ADR-0026: Single Package Consolidation](0026-single-package-consolidation.md) — merge 12 packages into 1 (orthogonal; can be done independently)

## References

- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks) — frontmatter hooks, hook types, lifecycle events
- Architecture workflow session: `.session/architecture-workflow-session.md`
