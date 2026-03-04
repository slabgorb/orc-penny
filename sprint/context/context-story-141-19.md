---
parent: context-epic-141.md
workflow: tdd
---

# Story 141-19: MERGED into 141-17

This story's scope was merged into Story 141-17 (Replace TypeScript File Parsers with pf CLI Subprocess Calls).

**Rationale:** Theme-loader replacement and story-parser replacement follow the identical pattern — TypeScript that parses files directly, replaced with subprocess calls to `pf` CLI `--json` endpoints. Consolidating them into one story reduces PR count, review burden, and ensures a single consistent delegation pattern.

**All original scope is covered in 141-17:**
- `theme-loader.ts` replacement with `pf theme list --json` / `pf theme show --json`
- `CATEGORY_MAP` migration into theme YAML files
- `pennyfarthing.ts` project detection and persona assembly replacement
- FSWatcher retention for cache invalidation

See `context-story-141-17.md` for full context.
