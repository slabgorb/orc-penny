# Epic 153 Context — Framework reliability fixes from downstream reports

## Summary
Three (now eight) independent framework bugs surfaced while using pennyfarthing in external projects (`oq-1`, `oq-2`). All affect the SM/TEA/Dev pipeline reliability and the CLI surface. Goal: clear them so external usage stops snagging on the same edges.

## Repo
`pennyfarthing/` (inlined framework source). Base branch: `develop`.

## Story Map

| ID | Title (short) | Pts | Pri | Type |
|----|---------------|-----|-----|------|
| 153-1 | sm-setup writes session files to wrong path; add migration | 2 | p0 | bug |
| 153-2 | Skip branch creation on orchestrator (main-only) repos | 2 | p2 | bug |
| 153-3 | Add `pf sprint story move` + `--epic` flag; document lifecycle CLI | 5 | p2 | feat |
| 153-4 | `pf sprint story remove/update/finish` fail on epic shards (BLOCKING) | 5 | p1 | bug |
| 153-5 | TEA/SM workflows reference missing CLI (`pf check`, context validator) | 2 | p2 | bug |
| 153-6 | sm-setup doesn't create `sprint/context/context-story-{ID}.md` | 3 | p2 | bug |
| 153-7 | Cyclist sprint-yaml PostToolUse hook crashes (`yaml` node module) | 2 | p3 | bug |
| 153-8 | DX bundle — update --title, smart error messages, --brief, etc. | 3 | p3 | bug |

**Total:** 24 points.

## Themes

1. **Path correctness** (153-1, 153-6) — agents writing artifacts to the wrong directory or skipping writes entirely.
2. **CLI surface gaps** (153-3, 153-4, 153-5, 153-8) — commands documented or referenced by agents don't exist or fail on the sharded sprint YAML.
3. **Repo topology assumptions** (153-2) — workflow assumes feature-branch flow on every repo.
4. **Hook robustness** (153-7) — hooks should fail soft when their dependencies aren't installed.

## Ordering Suggestion (SM's view, not prescriptive)
1. **153-1** first — P0, smallest, unblocks downstream usage.
2. **153-4** next — P1, blocks the SM finish ceremony (highest pain-per-fix ratio).
3. Then 153-6 (paired with 153-1 thematically), 153-2, 153-5, 153-3, 153-8, 153-7.

## Reference Sources
- `oq-1` and `oq-2` downstream pennyfarthing consumer projects (where these were observed).
- `sprint/epic-153.yaml` — full descriptions and repro steps for each story.

## Non-Goals
- Workflow YAML redesign.
- Sprint YAML schema migration beyond what 153-4 implies.
- New agent personas.
