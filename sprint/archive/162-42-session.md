---
story_id: "162-42"
jira_key: ""
epic: "162-p2"
workflow: "tdd"
---
# Story 162-42: Wire sm-setup to the schema-validation backstop

## Story Details
- **ID:** 162-42
- **Jira Key:** (none)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-42-sm-setup-schema-validation-backstop
- **PR:** (none yet)

## SM Assessment

**Spec:** the title IS the full spec (from 162-11 review). One deliverable in `pennyfarthing-dist/agents/sm-setup.md`.

**The defect (grounded — I read the code):**
- `agents/sm-setup.md` frontmatter carries `name / description / tools: Bash, Read, Edit, Write / model: haiku` but **no `hooks.PreToolUse` block**. All eleven top-level agents (`dev, sm, tea, reviewer, architect, ba, pm, ux-designer, devops, orchestrator, tech-writer`) declare `hooks.PreToolUse: [{command: pf hooks schema-validation, matcher: Write}]`.
- sm-setup is the **155-32 producer** — the subagent that writes `.session/<id>-session.md` from the template (it has `Write` in `tools`). 162-11 built the schema-validation backstop (`src/pf/hooks/schema_validation.py`) precisely to deny a session Write whose Story Details block is missing the branch/PR lines. The producer of that very write does not declare the hook that guards it.

**Nuance TEA/Dev must not chase as a phantom:** this is a **declaration-completeness / consistency** fix, NOT a runtime behavior change.
- `hooks/dispatch.py` `DISPATCH_REGISTRY["PreToolUse"]` registers `schema-validation` on `Write` as a **single global dispatcher entry**; `pf init` collects it once (see `test_init_frontmatter_integration.py` — exactly 4 dispatcher entries, dispatcher-managed hooks are NOT duplicated per-agent). `frontmatter.collect_all_frontmatter_hooks` scans `agents/*.md` (sm-setup.md is top-level there) and de-dups.
- `subagent/loader.py` reads only `model` / `allowed-tools` from frontmatter — it installs **no** per-subagent hooks. Subagent panes inherit the project `settings.local.json`, where the entry already exists (from the eleven). So schema-validation already fires today.
- **Why fix it anyway (SOUL #11 — automatic beats instructional):** the producer's definition must honestly declare the backstop it depends on, so (a) `collect_all_frontmatter_hooks` on sm-setup alone yields the declaration, and (b) if hook scoping ever becomes per-agent, the producer is not silently dropped and 155-32 cannot recur. Frame the tests as *declaration/consistency enforcement*, which is exactly what stops instructional rot.

**Fix shape:** add the frontmatter block to `sm-setup.md`, mirroring the eleven verbatim:
```yaml
hooks:
  PreToolUse:
    - command: pf hooks schema-validation
      matcher: Write
```
Keep the existing `name/description/tools/model` keys. Minimal edit, no logic change.

**TEA (RED):** failing tests — parse agent frontmatter, no runtime/network:
- (1) `agents/sm-setup.md` frontmatter declares a `PreToolUse` hook with `command: pf hooks schema-validation` and `matcher: Write`. Use `frontmatter.parse_frontmatter` / `collect_all_frontmatter_hooks` (the real parser, not an ad-hoc regex).
- (2) **Class invariant (the durable pin):** every agent in `agents/*.md` whose `tools`/`allowed-tools` includes `Write` MUST declare the schema-validation PreToolUse hook. This catches the whole class, not just sm-setup, and prevents the next Write-capable subagent from repeating the gap. Parametrize over the real agents dir.

**Dev (GREEN):** add the frontmatter block to `sm-setup.md` only. Nothing else.

**Constraints (binding):** edit **source** at `pennyfarthing-dist/agents/sm-setup.md` — never the `.pennyfarthing/` symlink. SCOPED test runs only: `cd pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/<new file>.py -q`; also run `test_init_frontmatter_integration.py` as regression (frontmatter collection must still yield exactly the expected dispatcher entries — no dup). `ruff check`. Result objects, not throws.

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-12T15:27:23Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-12T15:03:40Z | 2026-08-12T15:07:04Z | 3m 24s |
| red | 2026-08-12T15:07:04Z | 2026-08-12T15:10:32Z | 3m 28s |
| green | 2026-08-12T15:10:32Z | 2026-08-12T15:12:33Z | 2m 1s |
| review | 2026-08-12T15:12:33Z | 2026-08-12T15:27:23Z | 14m 50s |
| finish | 2026-08-12T15:27:23Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### Reviewer (code review)
- **Gap** (non-blocking): `agents/native/*.md` holds a second, parallel roster of agent definitions (10 files, `allowed-tools` YAML-list form). Five are Write-capable — `native/dev.md`, `native/devops.md`, `native/orchestrator.md`, `native/tea.md`, `native/tech-writer.md` — and none declares the schema-validation hook. The new class invariant globs `agents/*.md` only (top level), so it does not see them. Inert today (`collect_all_frontmatter_hooks` also only scans top level, and `subagent/loader.py` reads only `model`/`allowed-tools`), but it is the same declaration-completeness gap this story exists to close, and it defeats the story's own "if hook scoping ever becomes per-agent" rationale. Affects `pennyfarthing-dist/agents/native/*.md` and the invariant's glob. *Found by Reviewer during code review.*
- **Gap** (non-blocking, process): No `## Dev Assessment` section and no `.session/162-42-handoff-green.md` were written; the green phase was completed without either. Audit trail for GREEN is missing. Reviewer verified the implementation independently instead of relying on Dev's report. Affects the tdd workflow's green-phase gate. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `test_real_dist_collects_schema_validation_exactly_once` (AC4) is guaranteed to pass by construction — `collect_all_frontmatter_hooks` dedups on `(event, command, matcher)`, so 13 identical declarations always collapse to 1 and a genuine intra-file duplicate would also collapse to 1. The real dup regression is already pinned by `test_init_frontmatter_integration.py`'s dispatcher-entry count. A per-file `parse_agent_hooks` count assertion would make AC4 load-bearing. Affects `src/pf/tests/test_agent_schema_validation_hooks.py:195`. *Found by Reviewer during code review.*

### TEA (test design)
- **Gap** (blocking for GREEN): The SM Assessment says "one deliverable — `agents/sm-setup.md`" and that "the eleven top-level agents pass." That is incomplete. `agents/tandem-backseat.md` also declares `tools: [Read, Glob, Grep, Write, Edit, Bash]` (YAML list form) and carries **no** `hooks.PreToolUse` block. It is a second instance of the same declaration gap, and it is also a session-adjacent writer (it Writes tandem observation files). The class-invariant test therefore fails for **both** `sm-setup.md` and `tandem-backseat.md`. Dev must add the identical frontmatter block to `pennyfarthing-dist/agents/tandem-backseat.md` as well, or the invariant cannot go GREEN. *Found by TEA during test design.*
- **Improvement** (non-blocking): `tools` appears in two shapes across the agent roster — comma string (`tools: Bash, Read, Edit, Write`) and YAML list (`tandem-backseat.md`). Nothing in `pf.hooks.frontmatter` normalizes this; the test file carries its own `_tools_tokens` normalizer. A shared normalizer in `pf/hooks/frontmatter.py` (or `pf validate agent` enforcing one shape) would remove the duplication. Affects `pennyfarthing-dist/src/pf/hooks/frontmatter.py`. *Found by TEA during test design.*

## TEA Assessment

**Tests Required:** Yes
**Reason:** n/a

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_agent_schema_validation_hooks.py` - frontmatter-only (no runtime, no network) declaration-completeness tests using the real `pf.hooks.frontmatter` parser

**Tests Written:** 20 tests covering 4 ACs (5 currently RED)
**Status:** RED (failing - ready for Dev)

RED failures (all assertion failures, no collection/import errors):
1. `TestSmSetupDeclaresSchemaValidation::test_sm_setup_declares_schema_validation_hook`
2. `TestSmSetupDeclaresSchemaValidation::test_collecting_sm_setup_alone_yields_the_declaration`
3. `TestWriteCapableAgentsDeclareSchemaValidation::test_write_capable_agent_declares_schema_validation[sm-setup.md]`
4. `TestWriteCapableAgentsDeclareSchemaValidation::test_write_capable_agent_declares_schema_validation[tandem-backseat.md]`
5. `TestWriteCapableAgentsDeclareSchemaValidation::test_no_write_capable_agent_is_missing_the_hook` → `['sm-setup.md', 'tandem-backseat.md']`

Passing guards that pin the fix shape (must stay green): `test_agents_dir_is_discoverable`, `test_invariant_covers_a_meaningful_population` (>=12 write-capable agents — prevents a vacuous invariant), `TestSmSetupFrontmatterPreserved` (name/description/tools/model survive the edit), `TestNoDuplicateCollectedHook` (real dist collects exactly one `pf hooks schema-validation` entry — no dup).

Regression: `src/pf/tests/test_init_frontmatter_integration.py` — 13 passed, undisturbed.
`ruff check` clean.

**Dev guidance:** add the block INSIDE the existing frontmatter fence (a second `---` fence would not parse). Verified in-memory that this shape reaches GREEN:
```yaml
name: sm-setup
description: ...
tools: Bash, Read, Edit, Write
model: haiku
hooks:
  PreToolUse:
    - command: pf hooks schema-validation
      matcher: Write
```
Same block for `tandem-backseat.md`.

**Handoff:** To Dev for implementation

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Scope widened from one file to the class:** Spec said the single deliverable is `agents/sm-setup.md` and that all other Write-capable agents already pass. The class-invariant test (which the spec itself mandated as "the durable pin") also fails on `agents/tandem-backseat.md`. Reason: narrowing the invariant to exempt `tandem-backseat.md` would make it dishonest and would leave the exact gap the story exists to close. GREEN now requires the same two-line-block edit in both files.
- **"Write-capable" defined to include agents with no `tools` key:** Spec framed the invariant as "tools includes Write." An absent `tools` key means unrestricted tool access, which includes Write, so those agents are in scope too. Reason: the eleven top-level agents declare no `tools` and would otherwise be excluded from the invariant entirely, leaving it pinning almost nothing. All eleven pass as written.
## Subagent Results

**All received: Yes** — 5 of 5 enabled specialists returned before this assessment was written.

| # | Specialist | Received | Status | Findings | Decision |
| 1 | reviewer-preflight | Yes | clean | 33 passed / 0 failed; 0 ruff violations in changed files (74 pre-existing dist-wide, all out of scope); `pf validate agent` 38 passed 0 errors; 0 code smells; symlink integrity CLEAN; diff 3 files +206/-3 | N/A — matches my own independent runs |
| 2 | reviewer-test-analyzer | Yes | findings | 5: AC4 test guaranteed by dedup impl; `_tools_tokens`/`_permits_write` re-implemented in test code; `> 10` roster guard loose (actual 28); `>= 12` population guard loose (actual 13); aggregate test duplicates parametrized test | 4 CONFIRMED as [LOW] non-blocking; 1 DISMISSED (aggregate test has real diagnostic value — it is what enumerated both offenders during RED) |
| 3 | reviewer-rule-checker | Yes | clean | 0 violations across 8 rules / 18 instances. Hooks block byte-identical to the 11 pre-existing declarations and to `guides/hooks.md`; edits in `pennyfarthing-dist/` not `.pennyfarthing/`; test placement conventional | N/A — confirms my own symlink and convention checks |
| 4 | reviewer-security | Yes | findings | 2, both in `src/pf/hooks/frontmatter.py` (NOT in diff): no allowlist on frontmatter `command` at parse time (CWE-78); `matcher` regex unvalidated | Both DISMISSED for this story as pre-existing and out-of-diff; filed as a Delivery Finding. The two added commands are safe — `schema-validation` is in `DISPATCHER_MANAGED_HOOKS`, matcher is a single known tool name. No new attack surface |
| 5 | reviewer-type-design | Yes | findings | 4: `HookDeclaration` not `frozen=True`; untyped `dict` params on test helpers; `str(t)` coercion in `_tools_tokens`; stringly-typed `"Write"`/`"*"` vs existing `VALID_TOOLS` | 1 CONFIRMED as [LOW] non-blocking (`frozen=True`, pre-existing); 3 DISMISSED as over-engineering for a 1-point test helper — TEA's shared-normalizer Delivery Finding is the correct vehicle |

## Reviewer Assessment

**Verdict:** APPROVED

**Independently re-derived the fix's completeness (did not trust SM/TEA/Dev):** parsed all 28 top-level `agents/*.md` with the real `pf.hooks.frontmatter` parser. Exactly 13 are Write-capable — 11 with no `tools` key (unrestricted: architect, ba, dev, devops, orchestrator, pm, reviewer, sm, tea, tech-writer, ux-designer) plus `sm-setup.md` (comma-string form) and `tandem-backseat.md` (YAML-list form). All 13 now declare `PreToolUse / pf hooks schema-validation / matcher Write`. The other 15 (reviewer-* helpers, simplify-*, sm-file-summary, sm-finish, testing-runner) carry no Write and correctly carry no hook. **sm-setup and tandem-backseat were the only two offenders and both are fixed. No third exists at top level.**

**Data flow traced (end-to-end):** sm-setup issues a `Write` to `.session/<id>-session.md` → Claude Code matches the single `PreToolUse` matcher `Write` entry in `settings.local.json` → `pf hooks dispatch` → `DISPATCH_REGISTRY["PreToolUse"]` → `pf.hooks.schema_validation` → deny/allow on the Story Details schema (the 155-32 surface). The frontmatter declaration feeds `collect_all_frontmatter_hooks` at `pf init` time and is deduped on `(event, command, matcher)` into that one settings entry. Safe: the new declarations cannot add a second dispatcher entry.

**SM's "declaration-only, not runtime" claim — sanity-checked and CONFIRMED, no hidden runtime gap:** `hooks/dispatch.py:20-27` registers schema-validation once, globally, on `Edit|Write`-class matchers; `subagent/loader.py` reads only `allowed-tools` (line 71-72) and `model` (line 76-77) from frontmatter and installs no per-subagent hooks. The hook already fired for sm-setup before this change. The fix is honest declaration, per SOUL #11 — correctly scoped, not under-scoped.

**Frontmatter validity:** single `---` fence in both files, no second fence. `parse_frontmatter` returns a dict with `name`/`description`/`tools`/`model` intact (`sm-setup`: name=sm-setup, model=haiku, tools={Bash,Read,Edit,Write}). `pf validate agent`: 38 passed, 0 errors, 2 warnings — both warnings pre-existing (tech-writer `<parameters>`, tandem-backseat `<arguments>`), neither introduced here.

**Symlink safety — verified good:** `.claude/agents` is a symlink into `pennyfarthing/pennyfarthing-dist/agents` (`.claude/agents/sm-setup.md` and the dist source share inode 254403294). The diff touches only `pennyfarthing-dist/` paths. Nothing was written to a `.pennyfarthing/` target. Working tree clean.

**Test quality — genuinely load-bearing, not vacuous:** the parametrization is over the real agents dir (13 cases), and it demonstrably had teeth — it is what surfaced `tandem-backseat.md`, a second offender the spec missed. `_permits_write` treating a missing `tools` key as unrestricted is correct (those 11 agents do have Write access; "read-only" is a persona convention, not an enforced restriction) and it costs nothing in false positives since all 11 already declared. A malformed-frontmatter agent parses to `{}` → classified Write-capable → test fails, which is the fail-safe direction. `DIST_ROOT = parents[3]` resolves correctly (tests→pf→src→pennyfarthing-dist). Guards are real but loose (see findings).

**Pattern observed (good):** the test reuses the production parser (`pf.hooks.frontmatter.parse_agent_hooks`, `collect_all_frontmatter_hooks`) rather than an ad-hoc regex — `test_agent_schema_validation_hooks.py:38-43`. That is the right call and is what makes the invariant trustworthy.

**Error handling:** no new error paths; the change is declarative YAML. `parse_frontmatter` already returns `{}` on `yaml.YAMLError` rather than throwing (`frontmatter.py`), so a future malformed edit degrades to a test failure, not a crash. No result-object rule to satisfy — no new functions.

**Verification run (by me, not taken on report):**
- `uv run pytest src/pf/tests/test_agent_schema_validation_hooks.py src/pf/tests/test_init_frontmatter_integration.py -q` → **33 passed**
- `uv run pytest src/pf/tests -q -k "hook or frontmatter or agent or init or validate"` → **1082 passed, 1 skipped**
- `uv run ruff check` on the new test → **All checks passed**
- `uv run pf validate agent` → **38 passed, 0 errors**

**Findings (none blocking):**

| Severity | Issue | Location | Note |
|----------|-------|----------|------|
| [MEDIUM] | `agents/native/*.md` — 5 Write-capable native definitions declare no schema-validation hook; the invariant's glob is top-level only | `agents/native/{dev,devops,orchestrator,tea,tech-writer}.md` | Inert today (collector + loader ignore that dir); same class of gap. Filed as Delivery Finding for follow-up |
| [MEDIUM] | No `## Dev Assessment`, no `handoff-green.md` — GREEN audit trail missing | `.session/162-42-*` | Process, not code. Reviewer verified implementation independently |
| [LOW] [TEST] | AC4 test guaranteed by the dedup implementation; cannot detect an intra-file duplicate | `test_agent_schema_validation_hooks.py:195` | Real dup risk already pinned by `test_init_frontmatter_integration.py` |
| [LOW] [TEST] | Guard thresholds loose: `> 10` files (actual 28), `>= 12` Write-capable (actual 13) — erosion by one still passes | `:104`, `:166` | Prevents collapse, not drift. Tighten to exact counts or named membership |
| [LOW] [TEST] [TYPE] | `_tools_tokens`/`_permits_write` re-implement tools classification in test code; no production equivalent to drift against, and `str(t)` silently coerces non-string YAML items | `:56-81` | Already filed by TEA as a non-blocking Delivery Finding (shared normalizer in `pf.hooks.frontmatter`) |
| [LOW] [TYPE] | `HookDeclaration` is a mutable `@dataclass`, not `frozen=True`, yet is used as an equality sentinel and value object (the dedup set already works around its unhashability with a tuple key) | `src/pf/hooks/frontmatter.py:34` | Pre-existing, out of diff. Equality works correctly today; `frozen=True` would make the intent structural |
| [LOW] [SEC] | No allowlist on the frontmatter `command` field at parse time (CWE-78) and no validation of `matcher`; `DISPATCHER_MANAGED_HOOKS` exists but is never consulted as an allowlist | `src/pf/hooks/frontmatter.py:78,82` | Pre-existing, out of diff. Threat model requires an attacker who can already commit agent `.md` files — i.e. already has repo write access. Filed as Delivery Finding |

**[RULE] Project rules: clean.** reviewer-rule-checker checked 8 rules across 18 instances with 0 violations, independently confirming my own symlink and frontmatter-convention findings. The added hooks block is byte-for-byte identical to the 11 pre-existing declarations and to the shape documented in `guides/hooks.md` and the `parse_agent_hooks` docstring.

**Dismissed with rationale:**
- **[TEST]** the aggregate `test_no_write_capable_agent_is_missing_the_hook` is not redundant copy-paste — whole-set reporting has real diagnostic value and is exactly what TEA used to enumerate both offenders during RED. Keep it.
- **[SEC]** both security findings live in `src/pf/hooks/frontmatter.py`, which this diff does not touch. The two commands added are `pf hooks schema-validation` (present in `DISPATCHER_MANAGED_HOOKS`) with `matcher: Write` (a single known tool name) — no new attack surface, no privilege escalation, no capability beyond what the global dispatcher already grants. Not this story's scope; filed upstream instead of blocking a 1-point declaration fix.
- **[TYPE]** the TypedDict-for-frontmatter and `Literal`-tool-name suggestions are over-engineering for two private test helpers on a 1-point story. The legitimate underlying point — that tools-shape normalization belongs in production, not duplicated in a test — is already captured by TEA's shared-normalizer Delivery Finding, which is the correct vehicle. `str(t)` coercion fails in the safe direction (a non-string item cannot match `"Write"`, so the agent is treated as Write-capable and must declare the hook).

**Deviation audit:**
- TEA **"scope widened from one file to the class" — ACCEPTED.** The spec itself mandated the class invariant as "the durable pin"; exempting `tandem-backseat.md` to preserve a one-file scope would have shipped a dishonest invariant and left the exact gap the story exists to close. Independently confirmed tandem-backseat was genuinely Write-capable and genuinely missing the hook.
- TEA **"Write-capable includes agents with no `tools` key" — ACCEPTED.** Verified: 11 top-level agents have no `tools` key and therefore unrestricted (Write-inclusive) access. Excluding them would have left the invariant pinning 2 of 13 files. Holds water.
- No undocumented deviations found — the diff contains exactly the two frontmatter blocks plus the test file, nothing extra.

**Handoff:** To SM for finish-story

### Reviewer (code review) — appended after specialist panel
- **Improvement** (non-blocking, security hardening): `pf.hooks.frontmatter._parse_hooks_from_dict` validates `event` against `VALID_EVENTS` but accepts any arbitrary string as `command` and any string as `matcher`. `collect_all_frontmatter_hooks` collects it verbatim and `pf init` writes it into `settings.local.json`, where the harness executes it before matching tool calls. `DISPATCHER_MANAGED_HOOKS` already exists as the canonical allowlist but is never consulted at parse time. Threat model requires repo write access, so this is hardening rather than an open hole. Affects `pennyfarthing-dist/src/pf/hooks/frontmatter.py:78,82`. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `HookDeclaration` is a mutable `@dataclass` used as a value object and equality sentinel; `collect_all_frontmatter_hooks` works around its unhashability with a `tuple[str, str, str | None]` dedup key. `@dataclass(frozen=True)` would let the `seen` set be `set[HookDeclaration]` directly and make the immutability structural. Affects `pennyfarthing-dist/src/pf/hooks/frontmatter.py:34`. *Found by Reviewer during code review.*