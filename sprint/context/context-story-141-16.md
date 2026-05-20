---
parent: context-epic-141.md
workflow: tdd
---

# Story 141-16: Add --json Output to pf CLI for GUI Consumption

## Business Context

The consolidation strategy for Epic 141's TypeScript/Python duplication category (stories 141-16 through 141-19) is: make the `pf` Python CLI the single source of truth for sprint data, workflow state, theme discovery, and persona assembly, then replace TypeScript direct-file-parsing with subprocess calls.

This story is the enabler. Until the CLI exposes structured JSON, the TypeScript layer has no choice but to reimplement the parsing logic itself. `story-parser.ts` exists in both `packages/core` and `packages/cyclist` (~886 lines each, ~1700 total) and implements 13+ regex formats for session file parsing, sprint YAML aggregation, workflow phase resolution, and story status normalization. `pennyfarthing.ts` in core independently reads theme YAML and assembles persona data. These TypeScript copies will drift from the Python implementations every time the session file schema or sprint YAML structure changes.

Adding `--json` to the five key commands is the prerequisite that unblocks 141-17 (story-parser replacement), 141-18 (workflow engine replacement), and 141-19 (theme/persona replacement).

## Technical Guardrails

**Files to modify — all in `pennyfarthing/pennyfarthing-dist/src/pf/`:**

- `sprint/cli.py` — add `--json` flag to `pf sprint story show` (the command the description calls `pf story info`); `story show` already has `--json` but verify the JSON schema matches what 141-17 needs: `id`, `title`, `points`, `status`, `priority`, `workflow`, `jira`, `description`, `ac` (acceptance criteria array), plus session data (phase, phase_owner, branch, pr) when a session file is active
- `workflow/cli.py` — add `pf workflow phases` subcommand with `--json`; currently only `pf workflow check --json` exists (returns `state`, `story_id`, `workflow`, `phase`); `phases` must return the full ordered phase list for the active workflow with `done`/`current`/`pending` status per phase and the owning agent
- `prime/cli.py` — `pf prime --json` already exists for full agent bootstrap; `pf persona current` does not exist as a standalone command; need to add `pf persona current` (or a subcommand under an appropriate group) that returns `{agent, character, theme, crew}` using the same logic as `prime.load_persona()`
- `theme/cli.py` — `pf theme show` currently outputs plain text; add `--json` flag that returns the full theme data dict parsed from the YAML (`theme` metadata + `agents` map)
- `handoff/cli.py` — `pf handoff status` does not exist; currently `handoff` group has `resolve-gate`, `complete-phase`, `marker`, and `phase-check`; add `status` subcommand that returns the current gate state: which story is active, which phase, which gate type, what the next phase and agent are

**Reference for what TypeScript currently parses directly (do not change these files in this story):**

- `pennyfarthing/packages/core/src/server/story-parser.ts` — 886 lines of regex-based session + sprint YAML parsing; `StoryInfo` interface is the target shape for `pf story info --json`
- `pennyfarthing/packages/core/src/server/pennyfarthing.ts` — reads `.pennyfarthing/config.local.yaml` and theme YAML files to build `Persona` objects; target shape for `pf theme show --json` and `pf persona current --json`
- `pennyfarthing/packages/core/src/server/story-parser.ts` — `WorkflowPhase` interface (`name`, `agent`, `label`, `status: 'done'|'current'|'pending'`) is the target shape for `pf workflow phases --json`

**Key Python modules for existing logic (read before implementing):**

- `sprint/loader.py` — `get_story_by_id()` already returns the story dict from YAML; `story show --json` uses it
- `workflow/state.py` — `get_workflow_state()` returns the current state dict; `workflow/helpers.py` has `load_workflow_data()` and phase enumeration
- `prime/persona.py` — `load_persona()` loads the Persona object from the current theme; `get_crew_manifest()` builds the crew array
- `common/themes.py` — `get_current_theme()`, `resolve_theme_path()`, `list_themes()`
- `handoff/gate_file.py` and `handoff/phase_check.py` — gate state reading logic

**Build/test commands:**

```bash
cd pennyfarthing && pnpm run build
cd pennyfarthing/pennyfarthing-dist/src && python -m pytest pf/tests/ -x
```

**Pattern to follow:** `workflow check --json` in `workflow/cli.py` (lines 51–65) is the gold standard for how `--json` is wired into a Click command using `@click.option("--json", "output_json", is_flag=True)` and `click.echo(json.dumps(state, indent=2))`.

## Scope Boundaries

**In scope:**
- Add `--json` flag to `pf sprint story show STORY_ID` — return the story dict from `get_story_by_id()` plus any active session data (phase, phase_owner, branch, pr, criteria) merged in
- Add `pf workflow phases [STORY_ID]` subcommand with `--json` — enumerate phases from the workflow YAML for the active (or specified) story, annotate each with `done`/`current`/`pending` status by comparing against the session file's current phase
- Add `pf persona current [AGENT]` subcommand with `--json` — return `{agent, character, theme, slug, style, crew: [{agent, character, displayName}...]}` using `load_persona()` and `get_crew_manifest()`
- Add `--json` flag to `pf theme show [NAME]` — return the raw parsed YAML dict (`{theme: {...}, agents: {...}}`) instead of the current formatted text output
- Add `pf handoff status` subcommand with `--json` — return `{story_id, phase, gate_type, next_phase, next_agent, status: 'pending'|'passed'|'blocked'}` by reading the session file and the workflow YAML gate definitions
- Document the JSON output schema for each command (inline docstrings are sufficient; no separate schema file required in this story)
- Tests for each new `--json` path (TEA writes these first in TDD flow)

**Out of scope:**
- Replacing any TypeScript file-parsing code — that is 141-17 (merged with 141-19), 141-18
- Adding `--json` to commands not listed above (e.g., `pf sprint status`, `pf workflow list`, `pf theme list`)
- Changing any human-readable (non-`--json`) output format of any existing command
- Adding a `pf story info` alias (the command is `pf sprint story show`; the description's shorthand is informal)
- Jira URL generation in the CLI — TypeScript hardcodes `https://slabgorb.atlassian.net/browse`; if the Jira base URL belongs in the CLI output, that is deferred to 141-17 when the TypeScript replacement is done
- Schema validation or JSON Schema files — docstring-level documentation is sufficient for this story
- Changes to `packages/core` or `packages/cyclist` TypeScript files

## AC Context

**AC1: Each listed command supports `--json` and returns structured data**

Five commands require `--json` support. The testable criterion for each:

`pf sprint story show STORY_ID --json`
- Output is valid JSON to stdout, exit 0
- Top-level keys: `id` (str), `title` (str), `points` (int), `status` (str), `priority` (str|null), `workflow` (str|null), `jira` (str|null), `description` (str|null)
- If a session file exists for the story: additionally includes `phase` (str), `phase_owner` (str), `branch` (str|null), `pr` (str|null)
- If the story is not found: exit 1 with `{"error": "Story not found: STORY_ID"}` to stdout (not stderr) so the TypeScript subprocess caller can parse it

`pf workflow phases [STORY_ID] --json`
- Output is valid JSON array of phase objects
- Each object: `{"name": str, "agent": str, "label": str, "status": "done"|"current"|"pending"}`
- Phase list comes from the workflow YAML file for the story's workflow type (e.g., tdd: `setup`, `red`, `green`, `review`, `approved`, `finish`)
- Status computed by comparing the session file's `**Phase:**` value against the ordered phase list: all phases before current are `done`, current phase is `current`, all after are `pending`
- If no active session: all phases are `pending`
- Wrapped in top-level object: `{"workflow": str, "story_id": str|null, "phases": [...]}`

`pf persona current [AGENT] --json`
- Returns the active agent persona assembled from the current theme
- Output: `{"agent": str, "character": str, "theme": str, "style": str|null, "crew": [{"agent": str, "character": str, "displayName": str}...]}`
- If AGENT is omitted: detects the most-recently-registered agent from `.session/agents/` (same logic `pennyfarthing.ts` uses via `readdirSync` sorted by mtime)
- If no theme is configured: `{"error": "No theme configured"}` with exit 1

`pf theme show [NAME] --json`
- Returns the full parsed theme YAML as JSON
- Output: `{"name": str, "theme": {"description": str, "tier": str|null, ...}, "agents": {"sm": {"character": str, "style": str, "ocean": {...}|null, ...}, ...}}`
- The `agents` dict includes all agents defined in the theme file
- If NAME is omitted: uses current theme (same as existing human-readable behavior)
- Exit 1 with `{"error": "Theme not found: NAME"}` if theme cannot be resolved

`pf handoff status --json`
- Returns current gate/handoff state for the active session
- Output: `{"story_id": str|null, "phase": str|null, "workflow": str|null, "gate_type": str|null, "next_phase": str|null, "next_agent": str|null, "status": "active"|"no_session"}`
- Reads from the active session file in `.session/`; if no session exists, `status` is `"no_session"` and all other fields are null
- `gate_type` is the gate type for the current phase (from the workflow YAML `phases[].gate.type`); `next_phase` and `next_agent` are the subsequent phase entry in the workflow

**AC2: Output schema documented (success AND error responses)**

Each command's docstring must include a `JSON Schema` section showing both the success and error output shapes. Error responses must return JSON to stdout (not bare stderr) so the TypeScript subprocess caller can always parse the output.

Error response contract — all commands use this shape on failure:
```
{
  "error": string,      // human-readable error message
  "code": string,       // machine-readable error code (e.g., "STORY_NOT_FOUND", "NO_SESSION", "THEME_NOT_FOUND")
  "detail": string|null // optional additional context
}
```

Exit codes: 0 for success, 1 for expected errors (story not found, no session, etc.), 2 for unexpected errors (Python traceback, YAML parse failure). The TypeScript layer must be able to distinguish between "no data" (exit 1, parseable error JSON) and "pf is broken" (exit 2, possibly no JSON).

Success response example for `pf handoff status --json`:
```
JSON Output (--json):
  {
    "story_id": string | null,
    "phase": string | null,
    "workflow": string | null,
    "gate_type": string | null,
    "next_phase": string | null,
    "next_agent": string | null,
    "status": "active" | "no_session"
  }
```

**AC3: pf binary resolution strategy defined for non-PATH contexts (IDE extensions, GUI launches)**

The TypeScript layer must resolve the `pf` binary reliably even when launched from environments where `~/.local/bin` is not on PATH (e.g., VS Code extensions, Electron apps, IDE-spawned processes). Strategy:

1. Check `PF_BIN` environment variable (explicit override)
2. Check `~/.local/bin/pf` (uv/pipx default install location)
3. Fall back to bare `pf` on PATH (works in terminal sessions)

This resolution logic should be a shared utility in core that all subprocess callers use. Document in the CLI docstring that `PF_BIN` is the override mechanism.

**AC4: TypeScript layer can replace direct file parsing with subprocess calls to these commands**

This is a forward-looking validation AC, not a code change in this story. The TEA verifies it by confirming that:
- `pf sprint story show 141-1 --json` produces output with all fields that `StoryInfo` (in `story-parser.ts`) currently computes from direct file parsing
- `pf workflow phases --json` produces output with the `WorkflowPhase[]` shape (`name`, `agent`, `label`, `status`) that `story-parser.ts` currently computes by reading workflow YAML files and comparing against session phase
- `pf theme show --json` produces the full agent map that `pennyfarthing.ts` currently reads by calling `loadThemeYaml()`

The test can be a simple integration test that calls each subprocess and checks for the required top-level keys — no need to validate every field value.

**AC5: Blocks 141-17, 141-18**

These two follow-on stories depend on the JSON output established here (141-19 was merged into 141-17). No implementation change required; this AC is satisfied when ACs 1–4 pass and the story is marked done. The dependency is tracked in the epic YAML.
