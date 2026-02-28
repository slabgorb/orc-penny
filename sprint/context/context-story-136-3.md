---
parent: context-epic-136.md
workflow: trivial
---

# Story 136-3: Fix init/doctor prefix filtering for Python dist layout

## Business Context

Every pip-installed consumer who runs `pf init` gets zero commands and zero skills copied into their project. Then `pf doctor` reports false positives -- it warns about missing "symlinks" (actually file copies since the npm-to-pip migration) and nags about a missing `node_modules/` directory that pip consumers will never have. The result is that a fresh pip install appears broken even when the underlying package is fine.

This is the third story in the post-install reliability epic (136). It depends on 136-1 (dist_root resolution) which ensures `get_dist_root()` returns a usable path. This story makes `init` and `doctor` actually work once that path is correct, so the full init-then-doctor flow produces accurate results for both monorepo developers and pip consumers.

## Technical Guardrails

### Key Files to Modify

| File | Change |
|------|--------|
| `pennyfarthing-dist/src/pf/init/core.py` | `_find_pf_commands()` and `_find_pf_skills()` must locate commands/skills in the pip `_dist/` layout, not just `dist_root/commands/` and `dist_root/skills/` |
| `pennyfarthing-dist/src/pf/common/config.py` | `get_dist_root()` pip fallback (step 5) returns `_dist/` -- ensure it returns a path where `commands/` and `skills/` are actually present, or provide an alternative resolution for pip layout |
| `pennyfarthing-dist/src/pf/doctor/checks.py` | `check_symlinks()` -- rename to `check_content_dirs()` and update label/detail text to say "content directories" not "symlinks"; `check_node_packages()` -- suppress warning when install method is pip/pipx/uv (no node_modules expected); `check_commands()` and `check_skills()` -- no logic changes needed (they check `.claude/` targets, not dist_root) |
| `pennyfarthing-dist/src/pf/_dist/__init__.py` | If the fix strategy bundles content into `_dist/` at build time, update `is_populated()` to also check `skills/` (currently only checks `agents/` and `commands/`) |

### Key Files to Consume (Read-Only)

| File | Purpose |
|------|---------|
| `pennyfarthing-dist/src/pf/_dist/__init__.py` | `get_root()` returns `_dist/` package path; `is_populated()` checks whether content dirs are bundled -- currently only checks `agents/` and `commands/`, not `skills/` |
| `pennyfarthing-dist/src/pf/init/core.py` (`init_project`) | Calls `_find_pf_commands()` and `_find_pf_skills()` to build the copy list; also iterates `_CONTENT_DIRS` for agent/guide/persona copies -- understand the full copy flow before changing finders |
| `pennyfarthing-dist/src/pf/doctor/models.py` | `CheckResult` dataclass -- name, status, detail, fix_fn fields |
| `pennyfarthing-dist/src/pf/init/core.py` (`verify_pf_cli`) | Returns `install_method` field (pipx/uv/pip/unknown) -- doctor can use this to decide whether `node_modules` warning is appropriate |

### Patterns to Follow

- Return result objects `{success, data?, error?}` from any new functions -- do not throw
- `_find_pf_commands` and `_find_pf_skills` must work with both monorepo `dist_root` (where `commands/` is a direct child) and pip `_dist/` (where `commands/` may be a symlink or bundled copy)
- Doctor check functions take `root: Path` and return `CheckResult` -- keep this signature
- Use `is_populated()` from `pf._dist` to detect pip layout rather than hardcoding path checks
- In dev (monorepo), `_dist/` contains symlinks to `../../../commands` etc. -- these resolve correctly and `is_populated()` returns True. The code path must handle both real dirs and symlinks

### What NOT to Touch

- `pf_launcher.py` entry point (story 136-1 scope)
- `INFRASTRUCTURE_HOOKS` or hook command strings (story 136-1 scope)
- WheelHub / BikeRack launcher paths (story 136-2 scope)
- TUI color thresholds (story 136-4 scope)
- TUI data pipeline / WebSocket error handling (story 136-5 scope)
- The wheel build configuration (`pyproject.toml` package-data) -- if `_dist/` needs to bundle content, that is a build change out of scope unless trivially required to make the fix work
- `_CONTENT_DIRS` list in `init/core.py` -- the content-dir copy loop already works if `dist_root` resolves to a populated directory

## Scope Boundaries

**In scope:**
- `_find_pf_commands()` and `_find_pf_skills()` find files in pip layout where `get_dist_root()` returns `_dist/`
- `check_symlinks()` renamed to `check_content_dirs()` with accurate label ("Content directories present" not "Symlink targets present")
- `check_node_packages()` returns `pass` (not `warn`) when the install method is pip/pipx/uv
- `CHECKS` registry updated with new check name and description
- Backward compatibility: monorepo layout continues to work identically
- `is_populated()` updated to also verify `skills/` presence

**Out of scope:**
- Wheel build changes to bundle additional content into `_dist/` (separate if needed)
- PATH resolution for hook subprocesses (story 136-1)
- WheelHub entry point discovery (story 136-2)
- Any changes to the `.claude/commands/` or `.claude/skills/` target checks in doctor -- those check the installed output, not the source, and already work
- New doctor checks beyond renaming and suppression

## AC Context

### AC1: init copies commands in pip layout

**Given** a pip-installed `pf` where `get_dist_root()` returns the `_dist/` package path
**And** the `_dist/` directory contains `commands/pf-*.md` files (bundled or symlinked)
**When** the user runs `pf init` in a fresh project
**Then** `_find_pf_commands()` discovers all `pf-*.md` files from `_dist/commands/`
**And** they are copied to both `.pennyfarthing/commands/` and `.claude/commands/`
**And** the `data.commands_copied` count in the result is greater than 0

**Edge cases:**
- `_dist/commands/` contains non-pf-prefixed files -- they are excluded (only `pf-*.md` matched)
- `_dist/commands/` is a symlink to a real directory (dev layout) -- glob resolves through symlink
- `_dist/` exists but `is_populated()` returns False -- `get_dist_root()` returns None, init reports error

### AC2: init copies skills in pip layout

**Given** a pip-installed `pf` where `get_dist_root()` returns the `_dist/` package path
**And** the `_dist/` directory contains `skills/pf-*/` directories (bundled or symlinked)
**When** the user runs `pf init` in a fresh project
**Then** `_find_pf_skills()` discovers all `pf-*` skill directories from `_dist/skills/`
**And** they are copied to both `.pennyfarthing/skills/` and `.claude/skills/`
**And** the `data.skills_copied` count in the result is greater than 0

**Edge cases:**
- `_dist/skills/` contains non-pf-prefixed directories -- they are excluded
- Skill directory contains nested files -- entire tree is copied via `_copy_tree()`

### AC3: doctor content-dirs check uses accurate label

**Given** a project initialized with `pf init` (file copies, not symlinks)
**When** the user runs `pf doctor`
**Then** the check previously named `symlinks` is now named `content_dirs`
**And** the CHECKS registry description reads "Content directories present" (not "Symlink targets present")
**And** the pass detail reads "All content directories present" (not "All symlink targets present")
**And** the fail detail lists missing directories by name

**Edge cases:**
- Legacy monorepo projects with actual symlinks -- check still passes (`.exists()` resolves through symlinks)
- Partial init where some content dirs exist and others do not -- check fails and lists only the missing ones

### AC4: doctor suppresses node_modules warning for pip installs

**Given** a pip-installed project with no `node_modules/` directory
**When** the user runs `pf doctor`
**Then** `check_node_packages()` returns status `pass` with detail indicating node packages are not required for pip installs
**And** the check does NOT return status `warn` with "run npm install"

**Edge cases:**
- Monorepo layout with `node_modules/` present -- still returns `pass` (existing behavior)
- Monorepo layout without `node_modules/` -- still returns `warn` with "run npm install" (npm is expected in monorepo)
- Install method detection fails (returns "unknown") -- preserve current warn behavior as safe default

### AC5: monorepo backward compatibility

**Given** a monorepo development environment where `get_dist_root()` returns `pennyfarthing-dist/`
**When** the user runs `pf init` followed by `pf doctor`
**Then** init copies the same commands, skills, and content directories as before this change
**And** doctor reports the same pass/fail results (with updated labels)
**And** no regressions in the monorepo developer workflow

**Edge cases:**
- Orchestrator layout where `pennyfarthing/pennyfarthing-dist/` is the resolved dist root -- init and doctor both work through the inlined path
- `dist_root` found via step 3 (relative to `__file__`) -- commands and skills directories exist at expected relative positions
