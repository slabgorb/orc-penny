# Context Optimization Proposal

**For:** Keith
**From:** Michael
**Date:** 2026-01-03
**Status:** Proposal - Not committed

## Problem

Current Pennyfarthing context usage at session start: ~68k/200k tokens (34%)
This leaves less headroom for actual work, especially for complex multi-file operations.

## Findings

Claude Code loads ALL files from these directories into context at startup:
- `commands/*.md` - loaded as invocable skills
- `skills/*/SKILL.md` - loaded as knowledge skills

### Biggest Context Consumers

| File | Size | Tokens (est.) | Usage Frequency |
|------|------|---------------|-----------------|
| commands/theme-maker.md | 19KB | ~4,800 | Rarely |
| commands/benchmark.md | 12KB | ~3,100 | Occasional |
| skills/judge/SKILL.md | 12KB | ~3,000 | Benchmarking only |
| commands/solo.md | 9KB | ~2,200 | Occasional |
| commands/sync-work-with-sprint.md | 9KB | ~2,200 | Rarely |
| commands/create-branches-from-story.md | 8KB | ~2,100 | Rarely |
| commands/git-cleanup.md | 8KB | ~2,100 | Rarely |

**Total from infrequently-used commands: ~19,500 tokens (~10% of budget)**

## Proposed Solutions

### Option A: Lazy Loading Pattern (Recommended)

Move command bodies to separate files, leave minimal stubs:

```markdown
# theme-maker.md (stub - ~100 tokens instead of 4,800)
Creates custom persona themes interactively.
Usage: /theme-maker

For implementation, load: commands-impl/theme-maker-full.md
```

The agent reads the full implementation only when the command is invoked.

**Pros:** No functionality loss, transparent to users
**Cons:** Requires refactoring commands, two-step invocation

### Option B: Command Profiles

Create different command sets for different workflows:

```
commands/           # Core TDD commands (sm, tea, dev, reviewer, work)
commands-bench/     # Benchmarking (benchmark, solo, judge, finalize-run)
commands-admin/     # Admin/setup (theme-maker, git-cleanup, health-check)
```

Users symlink the profile they need for their session.

**Pros:** Clean separation, explicit control
**Cons:** Requires user action, might forget to switch

### Option C: Selective Exclusion via Settings

Add a `context.exclude_commands` setting:

```json
{
  "context": {
    "exclude_commands": ["theme-maker", "git-cleanup", "sync-work-with-sprint"]
  }
}
```

**Pros:** Simple, user-configurable
**Cons:** May need Claude Code support (check if this exists)

### Option D: Trim Command Verbosity

Many commands include extensive examples and edge cases. Reduce to essentials:

- theme-maker: 19KB could probably be 5KB
- benchmark: 12KB could probably be 4KB

**Pros:** No structural changes
**Cons:** May lose helpful context for complex commands

## User-Level Skills

The user's `~/.claude/commands/` also contributes:
- jira: 985 tokens
- ticketer: 516 tokens
- ast-grep: 465 tokens
- ripgrep: 297 tokens

These are loaded for every project. Consider if they're needed globally.

## Estimated Savings

| Approach | Token Savings | Effort |
|----------|---------------|--------|
| Lazy loading (Option A) | 15-18k | Medium |
| Command profiles (Option B) | 15-18k | Low |
| Trim verbosity (Option D) | 8-10k | Low |
| Combined A + D | 20-25k | Medium |

## Recommendation

Start with **Option D** (trim verbosity) for quick wins, then implement **Option A** (lazy loading) for the biggest offenders. This could recover 10-12% of context budget.

## Questions for Keith

1. Is lazy loading worth the added complexity?
2. Should we prioritize this over other backlog items?
3. Are there commands we could deprecate entirely?
4. Should this become a formal epic in the backlog?
