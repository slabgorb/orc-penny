# Model Tiering — Central Tier Map for the Claude 5 Era

**Date:** 2026-07-02
**Status:** Approved (brainstorm with Keith, 2026-07-02)
**Repo:** `pennyfarthing/` (framework source), plus doc touches in orchestrator

## Problem

The model landscape now spans four capability levels — Fable 5, Opus 4.8, Sonnet 5,
Haiku 4.5 — but Pennyfarthing's model policy predates it:

- **Main-session phase agents** (SM, TEA, Dev, Reviewer, Architect, PM, …) have no
  model control at all. Every phase runs at the session default. When the operator
  is on Fable, mechanical ceremony burns Fable quota.
- **Subagent frontmatter** encodes a three-tier world (`haiku`/`sonnet`/`opus`) with
  policy scattered across ~20 files.
- **Hardcoded stale model IDs** in the benchmark harness (`claude-opus-4-6`,
  `claude-sonnet-4-6` in `pipeline_replay.py`, `benchmark/cli.py`), peloton judge
  (`claude-sonnet-4-20250514` in `result_aggregator.py`), and demo generator —
  these are quietly mis-benchmarking today.
- **Validator** rejects the Claude 5 family: `VALID_MODELS = {"haiku", "sonnet", "opus"}`
  (`validate/adapters/agent.py:19`).
- **Docs drift**: `agent-coordination.md` documents `reviewer-preflight` and
  `tandem-backseat` as haiku; their frontmatter says sonnet.

Goal: conserve Fable for high-stakes judgment, promote Sonnet 5 as the analytical
workhorse, degrade aggressively elsewhere — with the policy in one place.

## Principles alignment

This is capability allocation (SOUL #4: Right Model for the Right Job), not cost
optimization (which SOUL #13 forbids as a design driver). Judgment phases keep the
top model; downgrades are validated by pipeline replay before being trusted
(SOUL #12: Measure the Pipeline). One file owns the policy (SOUL #2: One Truth,
One Place).

## Mechanism facts (verified against Claude Code docs, 2026-07-02)

These constrain the design:

1. **`best` alias**: "Uses Fable 5 where your organization has access to it,
   otherwise the latest Opus model." Ceiling-aware Fable→Opus degrade is built in;
   pf never needs to detect model availability.
2. **Skill/command `model:` frontmatter is turn-scoped**: the override applies for
   the rest of the current turn and is not saved; the session model resumes on the
   next user prompt. In relay/autonomous runs one invoke ≈ one long turn, so it
   covers a whole phase; in interactive use it reverts as soon as the user types.
3. **No programmatic durable switch** of the main-loop model exists. Only `/model`,
   `--model`, `ANTHROPIC_MODEL`, or the settings `model` field change it, and all
   are user/startup-scoped. Therefore main-session tiering is turn-scoped +
   advisory, never enforced.
4. **`fable` is a valid alias** for subagent spawns (Agent tool `model` param) and
   `/model`. `sonnet` resolves to Sonnet 5 on the Anthropic API, `opus` to Opus 4.8.
   Full `claude-*` model names are also accepted everywhere aliases are.
5. Alias resolution differs by provider (Bedrock/Vertex/Foundry lag) — one more
   reason to write aliases, not pinned IDs, and let Claude Code resolve.

## Design

### 1. The tier map: `pennyfarthing-dist/models.yaml`

Single source of truth. Tiers are named by the nature of the work, so a model
generation change is a one-line edit.

```yaml
tiers:
  judgment:    best     # Fable where available, else Opus — decisions that cascade
  heavyweight: opus     # deep execution — real reasoning, not judgment
  analytical:  sonnet   # analytical middle (Sonnet 5)
  mechanical:  haiku    # runners, setup, summaries

agents:                 # main-session phase agents
  architect:    judgment      # design, ADRs, spec-check, spec-reconcile
  reviewer:     judgment      # adversarial synthesis of the finding fleet
  pm:           judgment      # epic/sprint planning
  tea:          judgment      # red phase = test design (see TEA note)
  dev:          heavyweight   # green phase
  sm:           analytical    # routing and ceremony, not judgment
  ba:           analytical
  ux-designer:  analytical
  tech-writer:  analytical
  devops:       analytical
  orchestrator: analytical

subagents:
  "reviewer-*":       analytical    # already sonnet → Sonnet 5 via alias drift
  tandem-backseat:    analytical
  reviewer-preflight: mechanical    # DOWNGRADE from sonnet — gathers diff stats
  testing-runner:     mechanical
  "sm-*":             mechanical
  "simplify-*":       mechanical

judges:
  benchmark: heavyweight   # scoring consistency > peak brilliance
  peloton:   heavyweight

native_agents: judgment    # agents/native/*.md
```

**Per-install override:** a `models:` section in `.pennyfarthing/config.local.yaml`
may override any tier alias or assignment (for orgs without Fable access, or for
experiments). Merge is shallow per key; unknown tier names are a validation error
listing the valid set.

**Glob precedence:** in the `subagents:` map, an exact name match always beats a
glob (`reviewer-preflight: mechanical` wins over `"reviewer-*": analytical`).
Two globs matching the same name is a validation error.

**Resolution semantics:** pf maps role/phase → tier → alias and hands the *alias*
to Claude Code (frontmatter, `--model`, Task spawns). Alias→model resolution is
Claude Code's job.

**TEA note:** TEA spans red (judgment) and verify (mechanical-ish). Command
frontmatter cannot vary by phase, so `/pf-tea` pins the judgment tier. Acceptable:
verify's heavy lifting is already delegated to haiku `testing-runner` subagents.

### 2. Consumers — projections of the map, drift caught by validator

| Consumer | Change |
|---|---|
| `/pf-*` agent commands | Gain `model:` frontmatter per the `agents:` map (turn-scoped). `pf validate` compares frontmatter to models.yaml; drift = error. |
| Subagent frontmatter (`agents/*.md`) | Validated against `subagents:` map. Only actual edit: `reviewer-preflight` sonnet→haiku. |
| Inline Task-spawn templates in agent bodies | Validator scans structured `model:` lines in spawn blocks, checks against map. |
| `agents/native/*.md` | Validator rule "model must be opus" (`agent.py:424`) becomes "must match tier map" → `best`. |
| Peloton `pane_orchestrator.py` | Existing per-pane `model` override driven from map: `claude --model <alias>` per role pane. |
| Benchmarks (`pipeline_replay.py`, `benchmark/cli.py`) | Hardcoded IDs removed; defaults read from map (judges → `opus`). `--model`/`--judge-model` flags remain as explicit overrides (replay A/B depends on them). |
| Peloton judge (`result_aggregator.py`), demo generator | Stale IDs → aliases from map. |
| Validator `VALID_MODELS` | `{haiku, sonnet, opus, fable, best, inherit}` + accept explicit `claude-*` full names. |

### 3. Advisory guardrail (interactive sessions)

Pattern precedent: ADR-0041 advisory never-edit-zone hook. Never blocks.

- `pf agent start` Workflow State output gains `expected_model:` resolved from the
  map for the active phase.
- An advisory hook compares the session's actual model — read from the last
  assistant message in the transcript (hooks receive `transcript_path`) — against
  the expectation and injects a one-line nudge, e.g. *"green phase expects `opus`;
  session is on `fable` — consider `/model opus` to conserve quota."*
- Fires once per phase (state kept in the session dir), not per prompt.
- If the transcript model can't be determined, the hook stays silent (advisory
  means fail-quiet, but log to hook debug output).

### 4. The sweep (increment one) + doc reconciliation

- All Section 2 touchpoint edits.
- Docs updated to the four-tier world: SOUL.md #4, orchestrator CLAUDE.md rule 7,
  `guides/agent-coordination.md` (fix backseat/preflight contradictions),
  `guides/tandem-protocol.md`, `agents/README.md`, and the "I Do (Opus) / Helper
  Does (Haiku)" delegation tables in agent bodies (retitle to tier names).

### 5. Measurement — settle the Opus squeeze empirically

After landing, two pipeline-replay experiments (judge held fixed at `opus`):

1. **Dev on `opus` vs `sonnet`** — does Sonnet 5 take the heavyweight slot?
2. **reviewer-preflight on `haiku` vs `sonnet`** — validates the aggressive downgrade.

Resulting tier-map changes are one-line edits; that is the point of the design.

## Error handling

- Invalid tier name (map or local override) → validation error listing valid tiers.
- models.yaml missing → `pf validate` and consumers fail loudly; no silent defaults.
- Alias unavailable on a provider → Claude Code's own fallback/warning behavior;
  pf does not second-guess it.
- Fable safety-classifier fallback (documented Claude Code behavior) is out of
  scope; it is transparent to pf.

## Non-goals

- **No hard enforcement** (Plan C, rejected): gates will not block on model
  mismatch — mechanically unenforceable for the main loop and fights the operator.
- **No mid-session model switching machinery**: does not exist in the harness;
  we do not build shims pretending otherwise.
- **No effort-level tuning** in this iteration (skill `effort:` frontmatter noted
  as a future lever).
- **No per-story model selection** (e.g. trivial-workflow stories on cheaper
  tiers): future work, needs the map first.

## Testing

- Unit: tier-map loader (parse, override merge, unknown-key errors); validator
  checks (frontmatter drift, spawn-template drift, native-agent rule, new
  VALID_MODELS set).
- Integration: `pf agent start` emits `expected_model:`; advisory hook fires once
  per phase and stays silent on missing transcript data; peloton pane spawn
  includes `--model`.
- Manual: one relay handoff on a live session confirming the advisory nudge text.

## Decision trail

- Approaches considered: (A) static sweep only — rejected: policy stays scattered;
  (B) central map + advisory — **chosen**; (C) map + gate enforcement — rejected:
  unenforceable for the main loop, adds handoff friction.
- Fable-tier membership (Keith, 2026-07-02): architect, reviewer, pm, tea(red).
- Opus retained as heavyweight tier (Dev green, judges) pending replay evidence;
  Sonnet 5 may take the slot later via one-line map change.
- Deviation (plan, 2026-07-02): peloton panes do not spawn `claude` processes
  (pane content is driven by the team/subagent substrate), so the spec's
  "pane spawns `claude --model <alias>`" line is inoperative. Model policy
  reaches peloton through native-agent frontmatter, subagent spawns, and the
  `result_aggregator` judge default (all map-driven). `spawn_agent_panes`'s
  unused `model` param left as-is.
- Deviation (plan, 2026-07-02): current-model detection uses statusline
  persistence (`.pennyfarthing/.runtime/current-model`, written on every
  render from the statusline input's `model` field) instead of the spec's
  transcript parsing — statusline receives the model id directly from
  Claude Code, so no transcript format coupling. Advisory behavior unchanged.
