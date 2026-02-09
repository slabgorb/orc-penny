# ADR-0021: Safe Install, Upgrade, and Namespace Isolation

**Status:** Proposed
**Date:** 2026-02-09
**Author:** Architect (Will Bailey)
**Supersedes:** Partially extends ADR-0005 (Single Source of Truth via Symlinks)

## Context

Five interconnected problems in the current install/upgrade system create a fragile experience for users upgrading Pennyfarthing:

### Problem 1: Directory-Level Symlinks Destroy User Content

`init.ts` and `update.ts` create **directory-level symlinks** for six paths in `.pennyfarthing/` (agents, guides, output-styles, personas, scripts, workflows). Each call to `createDirectorySymlink()` first calls `removeSymlinkOrDirectory()`, which blows away the existing symlink or directory — including any user files that may have been placed there.

While ADR-0005 states "never modify symlinked directories," this is an unenforced convention. A user who doesn't understand the symlink structure (or an agent that writes to `.pennyfarthing/agents/`) loses their work silently on the next `update` or `init --force`.

**Impact:** `.claude/commands/` and `.claude/skills/` suffer a variant of this — they're directories with individually symlinked files, but `createCommandsDirectory()` and `createSkillsDirectory()` call `removeSymlinkOrDirectory(commandsDir)` first (symlinks.ts:56, symlinks.ts:127), nuking the entire directory and recreating it from scratch.

### Problem 2: No Post-Update Setup Trigger

After `npm install` pulls a new version of `@pennyfarthing/core`, nothing happens automatically. The user must know to run `pennyfarthing update`. There is no sentinel file, no version check on agent activation, no hook that detects "framework version changed."

The `manifest.json` tracks `version` and `updatedAt`, but nothing reads the manifest at activation time to compare against the installed package version.

### Problem 3: Fragile Upgrade Path

The update command (`update.ts`) handles:
- Manifest migration (`.claude/` to `.pennyfarthing/`)
- Template file migration
- Settings file migration
- Legacy directory cleanup
- Sidecar migration (two legacy locations)
- Copy-mode rejection

But it has no **versioned migration system**. Each migration is hard-coded inline. There's no way to know which migrations have already run, no idempotency guarantees beyond file-existence checks, and no rollback mechanism.

### Problem 4: Sprint Shard Migration is Manual

The Python layer in `yaml_io.py` transparently handles both monolithic and sharded epic formats — excellent backwards compatibility. But the one-time migration from monolithic to sharded requires manually running `sprint/migrate-to-shards.py`. The `pennyfarthing update` command has no awareness of sprint data format migration.

### Problem 5: Skill and Command Name Collisions

Built-in skills use generic names: `testing`, `sprint`, `workflow`, `permissions`, `changelog`, `jira`, `theme`, `mermaid`, `yq`. If a user project has a skill with the same name, the collision resolution is "skip the user's with a warning" (symlinks.ts:89, symlinks.ts:166). For commands, the same pattern — user commands that match built-in names are silently skipped.

This violates the principle of least surprise. A framework should never silently override user content.

## Decision

### 1. Version Sentinel for Auto-Update Detection

Add a sentinel file `.pennyfarthing/.installed-version` containing only the package version string. On agent activation (in `prime.sh` or `pf agent start`), compare this sentinel against the installed package version:

```bash
INSTALLED=$(cat .pennyfarthing/.installed-version 2>/dev/null)
PACKAGE=$(pennyfarthing --version 2>/dev/null)
if [ "$INSTALLED" != "$PACKAGE" ]; then
  echo "Pennyfarthing updated ($INSTALLED -> $PACKAGE). Running setup..."
  pennyfarthing update --auto
fi
```

The sentinel is written by `init.ts` and `update.ts` after successful completion. This is simpler than reading `manifest.json` — it's a single `cat` vs JSON parsing.

### 2. Namespace Skills and Commands with `pf-` Prefix

Rename all built-in skill directories from `{name}/` to `pf-{name}/`:

| Current | New |
|---------|-----|
| `skills/testing/` | `skills/pf-testing/` |
| `skills/sprint/` | `skills/pf-sprint/` |
| `skills/workflow/` | `skills/pf-workflow/` |
| `skills/permissions/` | `skills/pf-permissions/` |
| `skills/jira/` | `skills/pf-jira/` |
| `skills/theme/` | `skills/pf-theme/` |
| `skills/changelog/` | `skills/pf-changelog/` |
| `skills/mermaid/` | `skills/pf-mermaid/` |
| `skills/yq/` | `skills/pf-yq/` |
| `skills/cyclist/` | `skills/pf-cyclist/` |
| ... | ... |

**Similarly for commands:** `commands/setup.md` becomes `commands/pf-setup.md`, etc.

**Migration:** The update command detects old-named symlinks in `.claude/skills/` and `.claude/commands/`, removes them, and creates new `pf-`-prefixed ones. The skill registry (`skill-registry.yaml`) is updated to use `pf-` names. Agent definitions that reference `/testing` or `/sprint` are updated to `/pf-testing` or `/pf-sprint`.

**Claude Code discovery** is unaffected — it scans `.claude/skills/` for subdirectories regardless of naming convention.

**User skills remain unprefixed** — no collision possible since the framework namespace is now explicit.

### 3. Versioned Migration System

Replace inline migration code in `update.ts` with a structured migration runner:

```
pennyfarthing-dist/migrations/
  0001-move-manifest-to-pennyfarthing.ts
  0002-migrate-sidecars.ts
  0003-migrate-template-files.ts
  0004-prefix-skills-commands.ts
  0005-shard-sprint-epics.ts
```

Each migration:
- Has a unique numeric ID
- Exports `{ id, description, up(), down?(), check() }`
- `check()` returns whether migration is needed (idempotent detection)
- `up()` performs the migration
- `down()` optionally reverses it (rollback support)

The manifest gains a `migrationsRun: number[]` field tracking which migrations have executed. On `pennyfarthing update`, the runner:
1. Reads `migrationsRun` from manifest
2. Scans migrations directory for new migrations
3. Runs pending migrations in order
4. Updates `migrationsRun`

This replaces the scattered migration code in `update.ts` (`migrateManifest`, `removeLegacyClaudeDirectories`, `migrateTemplateFiles`, `migrateSidecars`) with a single, predictable system.

### 4. Sprint Shard Migration as a Versioned Migration

Add `0005-shard-sprint-epics.ts` to the migration system:

- `check()`: Read `sprint/current-sprint.yaml`, check if `epics[0]` is a string (already sharded) or dict (needs migration)
- `up()`: Run the equivalent of `migrate-to-shards.py` — extract inline epics to `epic-{ref}.yaml` files, replace with string references
- `down()`: Run reassembly (merge shards back to monolithic)

This integrates sprint migration into the standard upgrade path. Users upgrading from pre-shard era get automatic migration on `pennyfarthing update`.

### 5. Protective Symlink Strategy

**No change to the symlink architecture** (ADR-0005 remains valid). But add safeguards:

a. **Pre-flight check before removal:** Before `removeSymlinkOrDirectory()`, verify the path is either a symlink or an empty directory. If it's a non-empty directory that isn't a symlink, **warn and skip** rather than nuke.

b. **Document the "writable zones" explicitly:** Update `init.ts` to create a `.pennyfarthing/README.md` (or similar) listing which directories are managed (symlinked, will be replaced on update) vs user-writable (sidecars, project/, config files).

c. **Doctor check for stray files:** Add a doctor check that warns if non-symlinked files exist in managed directories — early detection before an update nukes them.

## Consequences

### Positive

- **Upgrades become safe** — versioned migrations run exactly once, in order, with rollback support
- **No more silent data loss** — pre-flight checks prevent directory nuking, namespace prefixing prevents skill collision
- **Auto-update detection** — sentinel file triggers update on first activation after `npm install`
- **Sprint migration is automatic** — users don't need to know about `migrate-to-shards.py`
- **Clear framework namespace** — `pf-` prefix makes built-in vs user content unambiguous

### Negative

- **Breaking change for skill references** — all agent definitions, documentation, and user muscle memory for `/sprint`, `/testing` etc. must update to `/pf-sprint`, `/pf-testing`
- **Migration system is new code** — adds maintenance surface area to `@pennyfarthing/core`
- **Sentinel file is another artifact** — one more file in `.pennyfarthing/` to manage

### Migration Path

1. **Phase 1:** Add sentinel file + auto-update detection (non-breaking)
2. **Phase 2:** Implement migration runner infrastructure (non-breaking)
3. **Phase 3:** Add `pf-` prefix migration (breaking, but automated via migration runner)
4. **Phase 4:** Add sprint shard migration (non-breaking, transparent)

### Risks

- **Skill reference breakage:** The `pf-` rename touches agent definitions, skill registry, command files, and any documentation referencing skill names. This is a large blast radius. Mitigation: the migration can create compatibility symlinks (`testing/` -> `pf-testing/`) for one version cycle.
- **Sprint migration edge cases:** Projects with unusual YAML formatting or hand-edited sprint files may not parse cleanly. Mitigation: `check()` validates before `up()` runs, with `--dry-run` support.

## Alternatives Considered

### 1. File-Level Symlinks for Everything (Not Just Commands/Skills)

Instead of symlinking entire directories like `.pennyfarthing/agents/`, symlink individual files within them (like we already do for commands).

**Deferred:** This would be more protective but significantly more complex — need to track individual files, handle additions/deletions between versions, and manage a much larger symlink surface. The current directory symlink approach works well for the `.pennyfarthing/` paths since those aren't meant for user files anyway. The real fix is making the "don't write here" boundary clearer, not changing the symlink granularity.

### 2. Scoped Namespacing (e.g., `@pf/testing`)

Use npm-style scoped naming instead of prefix.

**Rejected:** Claude Code skill discovery doesn't support `@`-scoped directory names. The `pf-` prefix is simpler and compatible with filesystem conventions.

### 3. User-Wins Collision Resolution

When a user skill collides with a built-in, keep the user's version.

**Rejected:** This would silently break framework functionality. The `pf-` prefix eliminates the collision entirely, which is better than choosing a winner.

## Implementation Notes

Key files to modify:
- `packages/core/src/cli/commands/init.ts` — write sentinel, use migration runner
- `packages/core/src/cli/commands/update.ts` — replace inline migrations with runner
- `packages/core/src/cli/utils/symlinks.ts` — add pre-flight safety check
- `pennyfarthing-dist/skills/` — rename all directories to `pf-` prefix
- `pennyfarthing-dist/commands/` — rename all files to `pf-` prefix
- `pennyfarthing-dist/skills/skill-registry.yaml` — update all names
- `pennyfarthing-dist/agents/*.md` — update skill references
- `pennyfarthing_scripts/prime/` — add sentinel version check

## References

- ADR-0005: Single Source of Truth via Symlinks
- ADR-0018: Sprint YAML Script Access Pattern
- Situation Room infrastructure audit (2026-02-09)
