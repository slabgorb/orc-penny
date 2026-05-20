# Epic 93: Extract Benchmarking System into @pennyfarthing/benchmark

**Jira:** PROJ-14629
**ADR:** 0020-benchmark-package-extraction.md

## Summary

Extract the JobFair benchmarking system from @pennyfarthing/core into a standalone optional npm package (@pennyfarthing/benchmark). Benchmarking is a meta-operation — zero reverse dependencies from core.

## Key Architecture

- Package shell created in 93-1: `pennyfarthing/packages/benchmark/`
- Two TS modules already migrated: `job-fair-aggregator.ts`, `benchmark-integration.ts` (with tests)
- Peer deps: `@pennyfarthing/core`, `@pennyfarthing/shared`
- Cyclist integration via dynamic import (already gracefully degrades)

## Story Sequence

1. **93-1** (DONE) — Package shell with TS modules
2. **93-2** — Move commands, skills, scripts, scenarios
3. **93-3** — Plugin discovery mechanism
4. **93-4** — Move docs, results, showcase
5. **93-5** — Clean up core (remove benchmark exports)
6. **93-6** — Update Cyclist to use plugin

## Files to Move (93-2 scope)

See ADR-0020 for complete inventory: commands (4), skills (3 dirs), shell scripts (~10), Python scripts (~5), tier scripts (3), scenarios dir.
