# Orchestrator Handoff — 2026-03-16

## Session Summary

Deep investigation into benchmark detection gaps. Started at 54% on DPGD-116, built new scenario DPGD-114 (Plugin SDK, 16 findings), and systematically identified why the pipeline misses findings.

## Critical Discoveries

### 1. pf module was loading from wrong project
Runs 26-29 were executing pf-3's harness code, not pf-1's. All our pipeline_replay.py changes (post-Dev scouts, TEA validator, expanded file globs) were never running. Fixed the `.pth` file and added a version gate that hard-fails if the harness is from the wrong project.

### 2. Agents were missing the project rulebook
`build_phase_claude_md()` was NOT including the axiathon repo's CLAUDE.md, SOUL.md, or `.claude/rules/` files. Agents didn't know about `#[non_exhaustive]`, validated constructors, private-fields-with-getters, or tenant isolation rules. Also had a hardcoded "axiathon-server" reference that was wrong for non-server scenarios. Fixed — now includes repo CLAUDE.md, SOUL.md, and all rules/*.md files.

### 3. Haiku subagents too weak for analytical work
DPGD-114 run 1 (Haiku): 4/16 caught. Silent-failure-hunter returned "clean" on a critical finding. Security returned "clean" on 4 tenant isolation issues. Upgraded to Sonnet: 7/16. Then Opus: 6-7/16. Model capability matters for analytical subagents. Mechanical tasks (test runner, preflight) are fine on Haiku.

### 4. Reviewer checklist inflation BACKFIRES
Run-28 (0% score): Added user-intent, prove-it-breaks, and build-config checklist items. Reviewer fabricated answers — "All deps use workspace=true" (false). Judge correctly penalized as opposite conclusions. Reverted to devil's advocate approach instead. Lesson: more checkboxes = more fabrication surface.

### 5. The bugs ARE in the generated code
Inspected run-6 worktree: EVERY finding's bug is present in Dev's code. `pub tenant_id`, `execute(&self, params)` with no TenantId, `#[derive(Deserialize)]` without validation, `type Err = String`, `as core` shadowing. Dev faithfully reproduces the bugs. The reviewer has the rulebook AND the buggy code and still misses them.

### 6. Reviewer bottleneck: thematic vs exhaustive
The reviewer does thematic analysis ("are there security issues?") not exhaustive checking ("does EVERY pub field violate the private-fields-with-getters rule?"). It catches 7/16 but misses the systematic violations (every trait method missing TenantId, every struct with public security-critical fields).

## What Was Built

### Pipeline Infrastructure
- Post-Dev scout pass (runs after Dev, before reviewer)
- TEA test validator (warns Dev about weak tests)
- Expanded file globs (Cargo.toml, package.json visible to scouts)
- Repo context injection (SOUL.md, rust.md, CLAUDE.md in benchmark CLAUDE.md)
- pf module version gate (hard-fail if wrong project)
- Subagent-before-conclusions gate
- Devil's advocate reviewer checklist item
- Keep worktree by default + save full.patch per run
- Benchmark OTEL panel wired up (F2 → 2 key, initial data fetcher)
- Peloton teammate pre-priming (SOUL #11)
- Subagent model upgrade path: Haiku → Sonnet → Opus

### Stories Completed
- 148-24: Peloton layout selection (horizontal/vertical/grid)
- 148-28: Peloton pre-priming (automatic agent context)
- 149-1/2/3: Detection gap fixes (post-Dev scouts, file globs, devil's advocate)
- 149-8: pf module version gate
- 149-9: Subagent-before-conclusions gate

### Scenarios
- DPGD-114 built (PR #53, Plugin SDK, 1C + 15I)
- Candidates identified: PR #55 (query parser), #58 (webhooks/security), #59 (query engine)

### SOUL.md
- Principle #14 added: Prove the Work

### PRD
- `docs/prd/prd-prove-the-work.md` — two axes: fewer findings + better explanations

## Detection Rate Summary (DPGD-114)

| Run | Model | Rules | Score | Caught |
|-----|-------|-------|-------|--------|
| 1 | Haiku subagents | No rules | 22% | 4/16 |
| 3 | Sonnet subagents | No rules | 33% | 7/16 |
| 4 | Opus subagents | No rules | 24% | 6/16 |
| 5 | Opus subagents | With rules | 37% | 7/16 |
| 6 | Opus everything | With rules + keep worktree | Running... | TBD |

## Next Session: Reviewer Deep Dive

### The core question
The reviewer has the rulebook (SOUL.md, rust.md) and the buggy code (every finding's bug is present). Why doesn't it catch them?

### What to investigate
1. **Read the reviewer output from run 5/6** — what did the subagents actually report? Which findings did the reviewer dismiss vs miss entirely?
2. **Compare subagent findings vs ground truth** — are the subagents flagging the right things but the reviewer dismissing them? Or are the subagents also missing?
3. **The exhaustive checking problem** — the reviewer does "are there security issues?" not "check every field against the private-fields rule." Can we make the subagents do exhaustive rule-by-rule checking instead of thematic scanning?
4. **TEA framing** — TEA writes tests that don't enforce project rules (no test for private tenant_id, no test for TenantId params). If TEA wrote rule-enforcing tests, Dev would implement correctly.

### Files to examine
- `/tmp/pf-replay/dpgd-114-control-run-6/` — the worktree with actual generated code
- `internal/results/pipeline-replay/dpgd-114/control/run-6/` — reviewer output, subagent findings
- `pennyfarthing-dist/agents/reviewer.md` — current reviewer definition
- `pennyfarthing-dist/agents/reviewer-security.md` — does it check tenant isolation?
- `pennyfarthing-dist/agents/reviewer-type-design.md` — does it check non_exhaustive?

### Hypothesis to test
The subagents are THEMATIC scanners ("find security issues") but the ground truth findings require RULE-BASED checking ("check every enum for non_exhaustive per rust.md"). A rule-based subagent that takes rust.md as input and checks every type/function against each rule might catch what thematic scanners miss.

## Uncommitted Work
- Pennyfarthing branch `feat/148-24-peloton-layout-selection` has all framework changes (needs PR to develop)
- Orchestrator branch `feature/test` has sprint changes and benchmark results
- Run 6 is in progress in tmux pane %300

## Epics in Flight
- **148**: TUI-tmux Fixer (stories 148-25 through 148-28 in backlog)
- **149**: Detection Gap Closure (149-5/6/7 in backlog, rest done)
- **150**: PR Explanation Quality (all 5 stories in backlog)
