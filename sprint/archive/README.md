# Sprint Archive

Historical records from Pennyfarthing development sprints (Dec 2025 - Feb 2026).

## Contents

| Category | Pattern | Description |
|----------|---------|-------------|
| **Consolidated YAML** | `sprints-*.yaml` | Lean sprint records by era |
| **History Summary** | `history-summary.md` | Human-readable overview |
| **Sprint Retros** | `sprint-*-retro*.md` | Retrospective notes (kept for learnings) |
| **Sidecar Archive** | `sidecar-archive/` | Historical agent learnings |

## Directory Structure

```
archive/
├── history-summary.md      # Overview of all 10 sprints
├── sprints-1-5.yaml        # Pre-Jira era (139 pts, 63 stories)
├── sprints-6-10.yaml       # Jira era (244 pts, 256 stories)
├── sprint-*-retro*.md      # Sprint retrospectives
├── sprint-9-grooming-report.md
├── sidecar-archive/        # Historical agent learnings
│   ├── dev-sidecar/
│   ├── tea-sidecar/
│   ├── sm-sidecar/
│   └── ...
└── README.md
```

## Pruning History

### 2026-02-08 (second pass)

Re-bloat from 200KB to 2.3MB. Deleted 240+ files that accumulated since first pruning:

| Deleted | Count | Rationale |
|---------|-------|-----------|
| `*-session*.md` | 227 | Session logs re-accumulated |
| `context-epic-*.md` | 4 | Epic context files |
| `sessions/` subfolder | 8 | Duplicate session storage |
| `epic-MSSCI-*.yaml` | 3 | Verbose epic archives |
| `sprint-*.yaml` (verbose) | 4 | Sprint 11/12/2604/2606 verbose files |
| `story-*.md` | 1 | Individual story file |
| `context/archived/` | 194 | Old story summaries and research notes |

**Reduction:** 2.3MB → ~250KB

### 2026-01-17 (first pass)

| Deleted | Count | Rationale |
|---------|-------|-----------|
| `story-*.md` | 185 | Individual story session logs |
| `context-*.md` | 51 | Technical context per story |
| `*-session*.md` | 41 | Work session files |
| `epic-*.md` | 3 | Epic-level context |
| `sprint-N.yaml` | 8 | Verbose sprint files (replaced by consolidated) |

**Reduction:** ~5MB → ~200KB

## Quick Reference

### Sprint Overview
```bash
cat history-summary.md
```

### Sprint Details
```bash
# Pre-Jira era (Sprints 1-5)
cat sprints-1-5.yaml

# Jira era (Sprints 6-10)
cat sprints-6-10.yaml
```

### Sprint Learnings
```bash
# List all retros
ls sprint-*-retro*.md

# Read specific retro
cat sprint-10-retro.md
```

### Agent Historical Patterns
```bash
cat sidecar-archive/dev-sidecar/*.md
```

## Retention Policy

- **Keep:** Consolidated YAML, retros, sidecar-archive, history summary
- **Pruned:** Individual story/context/session files (in git history)
- **Current size:** ~250KB

## Recovery

All pruned files remain in git history:
```bash
# Restore a specific file
git show HEAD~1:sprint/archive/story-24-5-20260112.md

# List deleted files
git diff --name-only HEAD~1
```
