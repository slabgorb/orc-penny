# ADR-0041: Live Context Injection Layer (UserPromptSubmit + advisory PreToolUse)

**Status:** Proposed
**Date:** 2026-07-01
**Author:** Architect
**Story:** (none yet — exploratory; prompted by evaluation of the Eigenwise `codebase-mapper` and `live-rules` plugins)
**Prior art:** [Eigenwise `codebase-mapper`](https://github.com/Eigenwise/eigenwise-toolshed/tree/main/plugins/codebase-mapper), [Eigenwise `live-rules`](https://github.com/Eigenwise/eigenwise-toolshed/tree/main/plugins/live-rules) (both MIT, Node)

## Context

Pennyfarthing delivers standing guidance to agents through three channels, all
of which fire **once** or **reactively**:

- **`SessionStart` hook** (`hooks/session_start.py`) and `pf agent start` inject
  prime context (ADR-0015) through a **stateful, tiered model that shrinks per
  invocation** (`prime/tiers.py`): **FULL** (~4000 tok, first turn — agent def,
  SOUL, persona, guide, sprint, session, **and sidecars**), **REFRESH** (~600
  tok, resumed same agent — workflow/sprint/topology/session-header), **HANDOFF**
  (~700 tok, new agent — agent def, compressed persona, topology), and
  **MINIMAL** (~200 tok, turn 3+ same agent — **workflow state only**). This is
  the opposite of a blunt re-dump: prime already recognizes "deep conversation"
  and *deliberately* sheds everything but routing state, precisely to avoid
  crowding context late in a session. Note the consequence: **sidecars ship only
  in the FULL (and SUBAGENT) tier** — every REFRESH/HANDOFF/MINIMAL tick drops
  them by design.
- **`PreToolUse` hooks** (`schema_validation`, `branch_protection`,
  `pre_edit_check`, `frontmatter`) **block or validate** an action. They do not
  *inform* — they gate.
- **`CLAUDE.md` `<critical>` blocks** are static, always-on, and identical for
  every task in the session.

A survey of the framework confirms the gap: **there is no `UserPromptSubmit`
hook anywhere in `pennyfarthing-dist`** (`grep -r UserPromptSubmit` → 0 hits;
the only wired events are `SessionStart`, `PreToolUse`, `PostToolUse`). We have
no mechanism for keeping advisory context *salient* as a session runs long, and
no mechanism for surfacing advice *at the moment an action makes it relevant*.

### Problem Statement

**Defect 1 — sidecar guidance is *deliberately* shed deep in a session, with
nothing to bring the governing fact back at the point of action.** This is not a
flaw in prime — it is prime working as designed. Prime's tiered model drops to
**MINIMAL (~200 tok, workflow-state only) at turn 3+**, and sidecars ride *only*
in the FULL tier. So the Architect's `DEC-ARCH-002` frame-liveness ruling is
present at activation and then correctly shed on every subsequent tick, because
re-dumping the full sidecar on every turn is exactly the context-crowding prime
exists to prevent. The residual gap is therefore narrow and specific: when an
agent, forty turns deep on the MINIMAL tier, is about to edit the very file that
a shed decision governs, there is **no mechanism that returns that one fact**.
`codebase-mapper`'s answer — re-injecting a full block on *every* prompt — is
precisely the hammer prime's tiering was built to avoid; adopting it would fight
prime's own principled shrink-to-MINIMAL. The right fix is not "inject more,
more often" but "inject the *one* governing fact, *only* at the moment of the
edit" — i.e. Defect 2's event-scoped mechanism.

**Defect 2 — advisory guidance is unscoped and reactive.** Our strongest
guardrails — the `repos.yaml` **never-edit zones** (`.pennyfarthing/` symlinks,
`node_modules/`, `packages/*/dist/`) — live as a static `CLAUDE.md` `<critical>`
block that every agent is expected to *remember*. When an agent forgets and
edits a symlinked target, we catch it reactively (a `PreToolUse` block, or worse,
a human noticing later). We have no channel that says, *at the instant the agent
targets a never-edit path,* "edit the source at `pennyfarthing-dist/`, not this
symlink." `PreToolUse` is the only event that knows **which file** is about to
be edited — and today we use it only to slam doors, never to post a signpost.

### External prior art (what prompted this)

Two Eigenwise plugins are built on one mechanism — `UserPromptSubmit`
re-injection for salience — pointed at two jobs:

- **`codebase-mapper`**: auto-generates atomic project docs and re-injects a
  compact `INDEX.md` every prompt.
- **`live-rules`**: scoped rule files (`.claude/rules/*.md`) whose scope is
  *inferred from frontmatter* (`globs`/`dirs`/`prompt`), injected on
  `UserPromptSubmit` (global/keyword/cwd) **and `PreToolUse`** (glob/dir rules,
  delivered the instant before a matching edit).

Their reusable engineering is worth copying: **scope-by-inference** (no explicit
`type` field), a **~10k-char injection budget** with `priority`-ordered
truncation and a "N held back" note, and **fail-soft hooks** (any error → exit 0,
never block a prompt or edit). Their runtime (Node) and `codebase-mapper`'s
forceful per-prompt `MANDATORY_INSTRUCTION` compliance block are **not** worth
copying — see Decision.

### Decision Drivers

- **Salience must survive long sessions** — close Defect 1 without a restart or
  re-prime (SOUL #11).
- **Advice at the point of action** — surface scoped guidance when it is
  relevant, not once at the top and not only as a reactive block (SOUL #6, Gates
  Over Goodwill, extended from "block" to "inform-then-block").
- **One truth, one place** (SOUL #2) — never-edit zones already live in
  `repos.yaml`; a rule layer must *read* that, not restate it.
- **Reuse-first** (Architect pragmatic-restraint) — extend the existing hook
  dispatch (`hooks/dispatch.py`, `hooks/cli.py`), don't stand up a parallel one.
- **Python owns the runtime** (SOUL #9) — the concepts port; the Node does not.
- **Fail-soft** (SOUL #10, Return Results) — an injection hook must never break a
  prompt or block an edit; a malformed rule degrades to "skip that rule."
- **Don't tax context with nags** — re-injection must be lean and conditional,
  not a forceful wall re-asserted every prompt.

## Considered Options

### Option 1 — Do nothing (keep static `CLAUDE.md` + activation-time sidecars)

- **Pros:** Zero new machinery; no new hot-path hook.
- **Cons:** Both defects stand. Sidecars keep decaying; never-edit guidance stays
  a memory test the agent periodically fails. Directly at odds with SOUL #11.

### Option 2 — Adopt the Eigenwise plugins as-is

Install `live-rules` (and maybe `codebase-mapper`) directly.

- **Pros:** Working code today; nothing to build.
- **Cons:** Node runtime (violates SOUL #9). Introduces a **second source of
  truth** — `.claude/rules/*.md` restating never-edit zones that already live in
  `repos.yaml` (violates SOUL #2). `codebase-mapper`'s auto-generated docs are
  *lower* fidelity than our hand-authored `guides/`, ADRs, and SOUL.md, and its
  every-prompt `MANDATORY_INSTRUCTION` block is a context tax and reads as
  scolding. Rejected as a wholesale adoption; mined for design instead.

### Option 3 — Build a Python "live context injection" layer

A new `UserPromptSubmit` hook plus an *advisory* `PreToolUse` hook, wired through
the existing `hooks/dispatch.py`, driven by scoped rule sources:

- **`UserPromptSubmit`** re-injects lean, salient context each prompt: a
  **sidecar salience-refresh** mode (surface the active agent's live
  decisions/gotchas), plus any prompt-keyword-scoped rules.
- **advisory `PreToolUse`** injects file-scoped guidance the instant before a
  matching edit — **first consumer: `repos.yaml` never-edit zones** (glob-match
  the target path → inject "edit source at `pennyfarthing-dist/`, not this
  symlink"). This is *additional context only*; it never returns a permission
  decision, so the existing block/validate hooks are unchanged.

Steal from `live-rules`: **scope-by-inference**, the **budget + priority
truncation**, and **fail-soft** discipline. Read never-edit zones from
`repos.yaml` (single source of truth), not a parallel rule file.

- **Pros:** Closes both defects; Python-native; reuses `repos.yaml` and the
  existing hook dispatch; salience without a restart; advice exactly at the point
  of action. Every principle above is satisfied.
- **Cons:** Adds a hook on the `UserPromptSubmit` hot path (must stay lean and
  fail-soft). Two delivery modes to reason about. Largest scope of the three.

### Option 4 — Minimal slice: advisory `PreToolUse` never-edit hook only

Ship *only* the file-scoped never-edit-zone reminder (`PreToolUse`, reads
`repos.yaml`), defer the `UserPromptSubmit` salience-refresh.

- **Pros:** Smallest, highest-confidence value; no new hot-path prompt hook;
  proves the "inform, don't just block" pattern in isolation.
- **Cons:** Leaves Defect 1 (sidecar decay) open.

## Decision

Adopt **Option 3 as the target design, sequenced so Option 4 is the first
shippable slice.**

1. **Advisory `PreToolUse` never-edit-zone reminder (first story).** A new
   *inform-only* `PreToolUse` hook glob-matches the edit target against the
   never-edit zones **read from `repos.yaml`**; on a match it injects a short
   reminder pointing at the correct source path. It returns no permission
   decision — `branch_protection`/`pre_edit_check` keep owning enforcement. This
   is the smallest slice that proves the pattern and immediately hardens our most
   common self-inflicted wound.
2. **Event-scoped sidecar surfacing (second story — event-driven, NOT
   every-prompt).** Surface a sidecar decision through the *same `PreToolUse`
   file-match path* as Phase 1: when an agent edits a file a decision governs,
   inject that decision. **Blanket every-prompt re-injection is explicitly
   rejected** — prime + TirePump already re-ground at breaks, and re-asserting
   the full sidecar every prompt is precisely the "hammer" this ADR avoids. A
   `UserPromptSubmit` / prompt-keyword injection is added *only* for guidance
   that is genuinely prompt-triggered rather than file-triggered (e.g. a "deploy"
   checklist), and even then it is conditional and budgeted, never a standing
   re-injection of everything. If Phase 1 proves sufficient in practice, Phase 2
   may reduce to nothing.
3. **Design borrowed from `live-rules`, runtime is ours.** Scope-by-inference
   frontmatter, a ~9k-char budget with `priority`-ordered truncation and a
   "N held back" note, and strict fail-soft hooks. **No Node.** **No every-prompt
   `MANDATORY_INSTRUCTION` nag block.** **No auto-generated codebase docs** — our
   `guides/`/ADRs/SOUL.md already own that ground.
4. **`repos.yaml` stays the single source of truth** for never-edit zones. The
   hook reads it; it does not restate zones in a parallel rule file.

### The Injection Contract (the reusable invariant)

> Injected advisory context must be **additive, scoped, and fail-soft**. It may
> inform, never decide: an advisory hook returns context only, never a permission
> verdict — enforcement stays with the dedicated gate hooks. Its scope is
> inferred from the source it reads (a `repos.yaml` glob, a sidecar's owning
> agent, a prompt keyword), never duplicated into a second source of truth. It is
> budgeted (highest-`priority` first, remainder dropped with a visible count) and
> fail-soft (any error or missing source → no output, exit 0, never break a
> prompt or edit). **Prefer event-scoped injection** (fire at the point of
> action) over blanket re-injection: prime's tiered model *deliberately* shrinks
> to a MINIMAL (~200-token, workflow-only) tier deep in a session, so any
> standing every-prompt refresh directly fights that design and must clear a high
> bar rather than being the default. Re-injection exists to return a *specific*
> shed fact at the moment it matters, not to re-assert compliance — it carries
> the fact, not a scolding.

Future context-injection changes must preserve this contract, not the specific
hook plumbing.

## Consequences

**Positive**

- The most common self-inflicted error — editing a `.pennyfarthing/` symlink
  instead of `pennyfarthing-dist/` source — is caught *at the point of action*
  with a corrective signpost, not reactively or after a human notices.
- Agent sidecar decisions stay salient deep into long sessions; the Architect's
  own frame-liveness decision would still be in context at turn 40, when it
  matters.
- Pennyfarthing gains a general, Python-native, fail-soft **advisory injection**
  capability it currently lacks entirely — reusable for future scoped guidance
  (e.g. `.js`-extension-in-TS-imports reminders scoped to `*.ts` edits).
- No new source of truth: never-edit zones remain defined once, in `repos.yaml`.

**Negative / trade-offs**

- The main mechanism is `PreToolUse` (edit-time), which fires rarely and only on
  a real match — near-zero idle cost and no context tax on ordinary prompts. Any
  `UserPromptSubmit` use (Phase 2) is deliberately kept off the "re-inject
  everything" path; if added it must be conditional, budgeted, and fail-soft, or
  it becomes the hammer we set out to avoid.
- Two possible delivery modes (edit-time scoped advice, and narrow prompt-keyword
  advice) to document — but Phase 1 alone may be all we ship.

## Implementation Notes (for TEA → Dev)

- **Reuse, don't rebuild:** extend `hooks/dispatch.py` / `hooks/cli.py`; register
  the new events alongside the existing `PreToolUse` matchers. Do not stand up a
  parallel hook runner.
- **Phase 1 touch points:** a new advisory `PreToolUse` handler (sibling to
  `pre_edit_check.py`) that reads never-edit zones via the existing `repos.yaml`
  loader and glob-matches the tool's target path. Returns `additionalContext`
  only — assert in tests that it emits **no** permission decision.
- **Phase 1 RED tests:** (1) edit targeting a `.pennyfarthing/` symlink → reminder
  injected naming the `pennyfarthing-dist/` source; (2) edit targeting an ordinary
  owned path → no output; (3) malformed/absent `repos.yaml` → exit 0, no output,
  edit not blocked; (4) the hook never returns a deny/allow decision.
- **Phase 2 touch points:** a new `UserPromptSubmit` handler that loads the active
  agent's sidecars (reuse the `agent start` sidecar loader) and any
  prompt-keyword rules; apply the ~9k-char budget + `priority` truncation +
  "N held back" note; fail-soft to empty output.
- **Phase 2 RED tests:** (1) long-session simulation → sidecar decision present in
  injected context; (2) over-budget rule set → highest-priority kept, remainder
  dropped with an accurate held-back count; (3) any parse error in one sidecar →
  that one skipped, others still injected, prompt never broken.
- **Explicitly out of scope:** auto-generated codebase docs (`codebase-mapper`'s
  job — we don't need it), any Node, and any every-prompt forced-compliance
  instruction block.
