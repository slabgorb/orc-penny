# ADR-0020: Extract Benchmarking System into Separate npm Package

## Status: Proposed

## Context

The Pennyfarthing benchmarking system (codename: JobFair) is a mature, scientifically rigorous persona evaluation system comprising ~30 files, 100+ scenarios, and 185+ historical job-fair runs. It provides OCEAN personality trait correlation, Cohen's d statistical analysis, and dimension-based filtering.

However, benchmarking is a **meta-operation** — it evaluates how well personas perform, but is not required for the core Pennyfarthing workflow of agent coordination, theme application, or sprint management. Most Pennyfarthing users will never run benchmarks.

**Current problems:**
1. Benchmarking code ships with every `@pennyfarthing/core` install, adding ~2000 lines of aggregation/correlation logic
2. Four benchmark commands (`/solo`, `/benchmark`, `/benchmark-control`, `/job-fair`) clutter the command namespace for non-benchmark users
3. Three benchmark skills (`judge`, `finalize-run`, `persona-benchmark`) load into agent context unnecessarily
4. Cyclist API router for benchmarks is dynamically imported (already partially decoupled)
5. The `scenarios/` directory (100+ YAML files) and `internal/results/` are development-only assets that shouldn't be in the distributed package

**Key architectural finding:** Benchmarking has **zero reverse dependencies**. Core framework does not import from benchmarking. The only integration point is Cyclist's dynamic import which already gracefully degrades.

## Decision

Extract the benchmarking system into `@pennyfarthing/benchmark` — an optional, installable npm package.

### Package Boundary

**Moves TO `@pennyfarthing/benchmark`:**

| Category | Files | Notes |
|----------|-------|-------|
| **Commands** | `solo.md`, `benchmark.md`, `benchmark-control.md`, `job-fair.md` | Benchmark execution workflows |
| **Skills** | `judge/`, `finalize-run/`, `persona-benchmark/` | Evaluation and scoring |
| **TypeScript** | `job-fair-aggregator.ts`, `benchmark-integration.ts` + tests | Aggregation and OCEAN correlation |
| **API** | `packages/cyclist/src/api/benchmark.ts` | REST endpoints (stays as optional Cyclist plugin) |
| **Scripts** | `benchmark-runner.*`, `aggregate-benchmark-stats.*`, `job-fair-*.sh`, `parallel-benchmark.sh`, `consolidate-job-fair.sh`, `convert-jobfair-to-benchmarks.sh` | Automation scripts |
| **Python** | `swebench-judge.py`, `ground-truth-judge.py`, `ensure-swebench-data.sh`, `test-cache.sh`, `test-setup.sh` | Deterministic evaluation |
| **Tier scripts** | `compute_theme_tiers.py`, `compute-theme-tiers.sh`, `update-theme-tiers.sh` | Theme tier ranking |
| **Docs** | `guides/benchmarks.md`, `personas/BENCHMARK-METHODOLOGY.md`, `docs/BENCHMARKING.md` | Benchmark documentation |
| **Scenarios** | `scenarios/` (entire directory) | Test definitions |
| **Results** | `internal/results/` (entire directory) | Historical data |
| **Showcase** | `internal/showcase/src/lib/benchmark-loader.ts` + tests | Build-time data pipeline |

**Stays IN `@pennyfarthing/core`:**

| Item | Reason |
|------|--------|
| Theme YAML files (with OCEAN scores, dimensions) | Used for persona application, not just benchmarking |
| Agent role definitions | Core framework identity |
| File system utilities (`findMonorepoRoot`, etc.) | General-purpose |
| YAML helpers | General-purpose |

### Dependencies

```
@pennyfarthing/benchmark
  ├── peerDependency: @pennyfarthing/core (for theme YAML schema, file utils)
  ├── peerDependency: @pennyfarthing/shared (YAML helpers)
  └── optionalDependency: (none — scenarios bundled within)
```

The new package **reads** theme YAML files but does not modify them (tier updates become an explicit CLI command in the benchmark package, writing to theme files that live in core).

### Cyclist Integration

The existing dynamic import pattern in `packages/cyclist/src/server.ts` already handles this:

```typescript
// Current code — already works with extraction
try {
  const { createBenchmarkRouter } = await import('./api/benchmark.js');
  app.use('/api/benchmark', createBenchmarkRouter(getProjectDir));
} catch {
  // Benchmark features disabled
}
```

Post-extraction, `benchmark.ts` moves to the new package and Cyclist discovers it via plugin registration (or the benchmark package provides a Cyclist plugin entry point).

### Installation UX

```bash
# Core install (no benchmarking)
npx @pennyfarthing/core init

# Add benchmarking
npm install @pennyfarthing/benchmark
# or: pf install benchmark
```

Commands, skills, and the Cyclist API become available automatically when the package is installed, using the existing `pennyfarthing-dist/` discovery mechanism.

### Theme Tier Field

The `tier:` field in theme YAML files becomes **optional metadata**. It is:
- Written by `@pennyfarthing/benchmark` (via `compute_theme_tiers.py`)
- Read by theme display UI (informational only)
- Not required for any core framework operation

Themes without tiers simply display "Unranked" in the UI.

## Consequences

### Positive
- Core package shrinks significantly (~2000 LoC of TS, 100+ scenario files, all result data)
- Clean command namespace for non-benchmark users (removes 4 commands, 3 skills)
- Benchmark system can version independently (research iterations don't require core releases)
- Clearer separation of concerns aligns with single-responsibility principle
- Cyclist already handles the optional nature via dynamic imports

### Negative
- Theme tier updates require the benchmark package installed (acceptable — tiers are a benchmark output)
- Two packages to maintain instead of one (mitigated: benchmark changes less frequently)
- Need a plugin discovery mechanism for commands/skills from installed packages (may already exist or be a small addition)

### Risks
- `@pennyfarthing/core` public API changes (removing 11 functions + 11 types from exports) — breaking change, requires major version bump or deprecation period
- Scenario schema evolution must stay compatible across packages
- Historical results data needs a migration path (stays in the dev repo, not distributed)

## Implementation Phases

### Phase 1: Create Package Shell
- New `packages/benchmark/` directory in the monorepo
- `package.json` with peer dependencies on `@pennyfarthing/core` and `@pennyfarthing/shared`
- Move TypeScript files: `job-fair-aggregator.ts`, `benchmark-integration.ts`
- Move tests alongside
- Export from new package index

### Phase 2: Move Commands, Skills, Scripts
- Move 4 commands to `packages/benchmark/commands/`
- Move 3 skills to `packages/benchmark/skills/`
- Move shell/JS/Python scripts to `packages/benchmark/scripts/`
- Move scenarios to `packages/benchmark/scenarios/`
- Update all internal path references

### Phase 3: Plugin Discovery
- Implement (or extend existing) mechanism for `@pennyfarthing/core` to discover commands/skills from installed packages
- Register benchmark commands and skills when package is detected
- Cyclist plugin entry point for benchmark API router

### Phase 4: Clean Up Core
- Remove benchmark exports from `@pennyfarthing/core` index.ts
- Remove benchmark API from Cyclist (replaced by plugin)
- Remove benchmark-related scripts from root `scripts/`
- Update documentation
- Major version bump or deprecation aliases

### Phase 5: Results & Documentation
- Move `internal/results/` to benchmark package (dev-only, not published)
- Move `internal/showcase/` benchmark components
- Update all cross-references in guides
- Migration guide for existing users
