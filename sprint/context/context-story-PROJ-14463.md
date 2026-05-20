# Story Context: 82-2 - Sidecar pruning API

## Summary

Add a `POST /api/agent-load/prune-sidecar` endpoint to the agent-load router created in story 82-1. The endpoint accepts `{agent, file}`, resets the specified sidecar file to its header template (substituting `${AGENT_NAME}`), computes `tokensFreed`, invalidates the agent-load cache, and returns `{success, tokensFreed, agent, file}`. This is a destructive operation that wipes learned agent context back to the blank template.

## Current State

### Sidecar Files

Each of the 10 primary agents has up to 3 sidecar files in `.pennyfarthing/sidecars/{agent}/`:

| File | Template Lines | Max Lines (from sidecar-health.sh) |
|------|---------------|-------------------------------------|
| `patterns.md` | 35 | 50 |
| `gotchas.md` | 38 | 50 |
| `decisions.md` | 41 | 40 |

Sidecar directories confirmed at project root `.pennyfarthing/sidecars/` with subdirectories for: `architect`, `dev`, `devops`, `orchestrator`, `pm`, `reviewer`, `sm`, `tea`, `tech-writer`, `ux-designer`.

The Python loader at `pennyfarthing_scripts/prime/loader.py` lines 186-214 loads sidecars from `.pennyfarthing/sidecars/{agent_name}/` in priority order: `patterns.md`, `gotchas.md`, `decisions.md`.

### Sidecar Templates

Three template files exist at `pennyfarthing-dist/templates/sidecar/`:

- **`patterns.md.template`** (35 lines) -- starts with `# ${AGENT_NAME} Patterns`, includes pattern documentation format with Context/Solution/Example/Why sections
- **`gotchas.md.template`** (38 lines) -- starts with `# ${AGENT_NAME} Gotchas`, includes Situation/Problem/Prevention/Fix template
- **`decisions.md.template`** (41 lines) -- starts with `# ${AGENT_NAME} Decisions`, includes ADR format with Status/Context/Decision/Rationale/Alternatives/Consequences

All templates use `${AGENT_NAME}` as a placeholder (appears in header and description lines). The placeholder expects title-case names: "Dev", "Tech-Writer", "Ux-Designer".

### Existing Sidecar Health Script

`pennyfarthing-dist/scripts/maintenance/sidecar-health.sh` (91 lines) checks for bloated sidecars:
- Line 17: `SIDECAR_DIR="$PROJECT_ROOT/.pennyfarthing/sidecars"`
- Lines 21-23: Thresholds -- `GOTCHAS_MAX=50`, `PATTERNS_MAX=50`, `DECISIONS_MAX=40`
- Lines 53-60: `--fix` mode archives to `.pennyfarthing/sidecars/.archive/` but does NOT prune -- it just copies and tells user to manually prune

The new API provides actual automated pruning (reset to template), not just archiving.

### Token Estimation

Python side uses `estimate_tokens()` at `tiers.py` lines 19-35: `max(1, len(text) // 4)`. The TypeScript side should use the same formula for consistency:
```typescript
function estimateTokens(text: string): number {
  if (!text) return 0;
  return Math.max(1, Math.floor(text.length / 4));
}
```

### Template Path Resolution

`findPennyfarthingScripts()` in `prime.ts` lines 27-51 resolves the package root through three locations:
1. `node_modules/@pennyfarthing/core/pennyfarthing_scripts` (line 29)
2. `.pennyfarthing/scripts` symlink -> walk up to package root (lines 35-42)
3. Dev mode: relative to Cyclist source `__dirname/../../..` (lines 45-48)

Templates are at `{packageRoot}/pennyfarthing-dist/templates/sidecar/`. The same multi-location resolution approach should be used.

### No Prune API Exists

There is no POST endpoint for sidecar manipulation. The only existing sidecar management is the bash script `sidecar-health.sh` which requires CLI invocation.

## Target State

After implementation:

1. `POST /api/agent-load/prune-sidecar` accepts `{agent: string, file: string}`
2. Validates `agent` is one of the 10 primary agents
3. Validates `file` is one of `patterns.md`, `gotchas.md`, `decisions.md`
4. Reads current sidecar content, computes current tokens
5. Reads corresponding template from `pennyfarthing-dist/templates/sidecar/{file}.template`
6. Substitutes `${AGENT_NAME}` with title-cased agent name
7. Writes template content to sidecar file, replacing all learned content
8. Computes `tokensFreed = oldTokens - newTokens`
9. Calls `invalidateAgentLoadCache()` from story 82-1 so next GET reflects the change
10. Returns `{success: true, tokensFreed, agent, file}`

## Key Files

### Files to Modify

| File | Location | What Changes |
|------|----------|--------------|
| `agent-load.ts` | `pennyfarthing/packages/cyclist/src/api/agent-load.ts` | Add POST `/prune-sidecar` handler to the existing router (created in 82-1) |

### Files to Read (Context / Reference)

| File | Location | Why |
|------|----------|-----|
| `patterns.md.template` | `pennyfarthing/pennyfarthing-dist/templates/sidecar/patterns.md.template` | Template content (35 lines), `${AGENT_NAME}` placeholder locations |
| `gotchas.md.template` | `pennyfarthing/pennyfarthing-dist/templates/sidecar/gotchas.md.template` | Template content (38 lines) |
| `decisions.md.template` | `pennyfarthing/pennyfarthing-dist/templates/sidecar/decisions.md.template` | Template content (41 lines) |
| `loader.py` | `pennyfarthing/pennyfarthing_scripts/prime/loader.py` | `load_sidecars()` (lines 186-214): sidecar path pattern `.pennyfarthing/sidecars/{agent_name}/`, file list (`patterns.md`, `gotchas.md`, `decisions.md`) |
| `tiers.py` | `pennyfarthing/pennyfarthing_scripts/prime/tiers.py` | `estimate_tokens()` (lines 19-35): `max(1, len(text) // 4)` formula to replicate in TypeScript |
| `sidecar-health.sh` | `pennyfarthing/pennyfarthing-dist/scripts/maintenance/sidecar-health.sh` | Line count thresholds (lines 21-23), archive pattern (lines 53-60) |
| `prime.ts` | `pennyfarthing/packages/cyclist/src/prime.ts` | `findPennyfarthingScripts()` (lines 27-51) for template path resolution pattern |

## Technical Approach

### 1. Define constants and validation

Add to `agent-load.ts` (which already has `PRIMARY_AGENTS` from story 82-1):
```typescript
const VALID_SIDECAR_FILES = ['patterns.md', 'gotchas.md', 'decisions.md'] as const;

function formatAgentName(agent: string): string {
  // "dev" -> "Dev", "tech-writer" -> "Tech-Writer", "ux-designer" -> "Ux-Designer"
  return agent
    .split('-')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join('-');
}

function estimateTokens(text: string): number {
  if (!text) return 0;
  return Math.max(1, Math.floor(text.length / 4));
}
```

### 2. Resolve template path

Reuse the `findPennyfarthingScripts()` approach from `prime.ts` to locate the package root, then resolve templates relative to it:
```typescript
function findTemplatePath(projectDir: string, templateFile: string): string | null {
  // 1. node_modules path
  const nmPath = join(projectDir, 'node_modules', '@pennyfarthing', 'core',
    'pennyfarthing-dist', 'templates', 'sidecar', templateFile);
  if (existsSync(nmPath)) return nmPath;

  // 2. Dev mode: relative to Cyclist source
  const devPath = join(__dirname, '..', '..', '..', 'pennyfarthing-dist',
    'templates', 'sidecar', templateFile);
  if (existsSync(devPath)) return devPath;

  return null;
}
```

Note: `__dirname` is already available in `prime.ts` via `fileURLToPath(import.meta.url)`. The same pattern should be used in `agent-load.ts`, or import from prime.

### 3. Implement POST handler

Add to the router created in story 82-1:
```typescript
router.post('/prune-sidecar', async (req, res) => {
  const { agent, file } = req.body;

  // Validate agent
  if (!agent || !PRIMARY_AGENTS.includes(agent)) {
    return res.status(400).json({
      success: false,
      error: `Invalid agent. Must be one of: ${PRIMARY_AGENTS.join(', ')}`,
    });
  }

  // Validate file
  if (!file || !VALID_SIDECAR_FILES.includes(file)) {
    return res.status(400).json({
      success: false,
      error: `Invalid sidecar file. Must be one of: ${VALID_SIDECAR_FILES.join(', ')}`,
    });
  }

  const projectDir = getProjectDir();
  const sidecarPath = join(projectDir, '.pennyfarthing', 'sidecars', agent, file);

  // Check file exists
  if (!existsSync(sidecarPath)) {
    return res.status(404).json({
      success: false,
      error: `Sidecar file not found: .pennyfarthing/sidecars/${agent}/${file}`,
    });
  }

  // Read current content and compute tokens
  const oldContent = readFileSync(sidecarPath, 'utf-8');
  const oldTokens = estimateTokens(oldContent);

  // Find and read template
  const templatePath = findTemplatePath(projectDir, `${file}.template`);
  if (!templatePath) {
    return res.status(500).json({
      success: false,
      error: `Template not found: ${file}.template`,
    });
  }

  const templateContent = readFileSync(templatePath, 'utf-8');
  const newContent = templateContent.replace(/\$\{AGENT_NAME\}/g, formatAgentName(agent));
  const newTokens = estimateTokens(newContent);

  // Write pruned content
  writeFileSync(sidecarPath, newContent);

  // Invalidate cache so next GET /api/agent-load reflects the change
  invalidateAgentLoadCache();

  const tokensFreed = oldTokens - newTokens;

  res.json({
    success: true,
    tokensFreed,
    agent,
    file,
  });
});
```

### 4. Import fs functions

The handler needs `existsSync`, `readFileSync`, `writeFileSync` from `fs` -- add to imports at the top of `agent-load.ts`.

## Acceptance Criteria

- `POST /api/agent-load/prune-sidecar` with `{agent: "dev", file: "patterns.md"}` resets the file to template content
- Invalid `agent` returns 400 with descriptive error listing valid agents
- Invalid `file` returns 400 with descriptive error listing valid files (`patterns.md`, `gotchas.md`, `decisions.md`)
- Missing sidecar file returns 404 with the file path in the error message
- Missing template returns 500 (infrastructure error, not user error)
- `${AGENT_NAME}` in template is replaced with title-cased agent name (e.g., "Dev", "Tech-Writer")
- Response includes `tokensFreed` calculated as `oldTokens - newTokens` using `Math.floor(text.length / 4)` formula
- After prune, the agent-load cache (from 82-1) is invalidated so next GET returns fresh data
- The sidecar file on disk contains exactly the template content with substituted agent name
- Original sidecar content is not preserved or archived (archiving is out of scope -- `sidecar-health.sh --fix` handles archiving separately)

## Dependencies

### Depends On

- **82-1** (Agent load API endpoint) -- the POST handler is added to the same `agent-load.ts` router; depends on `invalidateAgentLoadCache()` export and the `PRIMARY_AGENTS` constant

### Depended On By

- **82-3** (Agent load React hook + dialog) -- the `pruneSidecar(agent, file)` method in the hook calls this endpoint; the Prune button in the dialog triggers it

## Risks / Open Questions

1. **No backup before prune:** Unlike `sidecar-health.sh --fix` which archives to `.pennyfarthing/sidecars/.archive/`, this API does a destructive overwrite with no backup. The dialog (82-3) will use `ConfirmDialog` for confirmation, but there's no server-side archive. Consider adding an optional archive step, or accept that the UI confirmation is sufficient. The epic notes "Prune button -> ConfirmDialog for destructive action" which suggests UI-level confirmation is the intended safeguard.

2. **Template path in dogfooding mode:** In the dogfooding setup (`pennyfarthing-orchestrator` with `pennyfarthing/` inlined), the template path is `pennyfarthing/pennyfarthing-dist/templates/sidecar/`. The dev-mode resolution (`__dirname/../../..`) from Cyclist source resolves to the `pennyfarthing/` directory, which has `pennyfarthing-dist/` directly. This should work, but needs testing with `CYCLIST_PROJECT_DIR` set correctly.

3. **Race condition with prime:** If a prune happens while a `getPrimeContextJson()` call is in flight (from the GET endpoint), the prime process reads stale file content. This is benign -- the cache is invalidated after the prune, so the next GET will re-read the pruned file. The 60-second cache means the stale data is at most 60 seconds old.

4. **File permission errors:** If the sidecar file is read-only or the directory doesn't have write permission, `writeFileSync` will throw. The handler should catch this and return a 500 error. Currently, the try/catch is on the individual operation, not the whole handler. Consider wrapping the entire handler in try/catch.

5. **Concurrent prune requests:** Two simultaneous prune requests for the same file are not guarded. This is acceptable since the operation is idempotent -- pruning an already-pruned file just writes the same template again and reports `tokensFreed: 0`.
