# SM Agent Patterns

<pattern name="peloton-inline-p2p3-run-162" date="2026-08-10">
Epic-162 p2/p3 backlog run (peloton-inline, named background agents, one story at a time,
merge between). Landed 162-14, 162-18 clean. Key NEW datapoints:
(1) `gh pr merge <n> --merge --delete-branch` to `develop` NOW WORKS with no classifier
denial (merged #195 batch, #196, #198 all clean) — the old 155-5 "classifier denies agent
merge to protected branch" gotcha did NOT recur this session. SM owns PR create + merge +
finish as usual; still verify state=MERGED before bookkeeping.
(2) REVIEWER-REQUESTED HARDENING MUST BE PINNED OR DON'T ADD IT. On 162-18 I relayed the
reviewer's own "cheap isinstance hardening" suggestion to Dev; the reviewer then REJECTED
cycle-2 because the guard landed as unpinned dead code (deletable with zero test failures),
violating the story's tdd constraint — and the guard only defended JSON-unreachable inputs.
Lesson: when relaying a reviewer's "while you're in the file" hardening, require a failing
test for it, or decline it. An unpinned guard in trust machinery is itself the defect class.
Recovered via option-(b) revert in one round. (Same family as 155-47/162-47 "probe the
suggested fix" — reviewer suggestions are not automatically correct.)
(3) 503 AUTH WAVES: Dev and Reviewer both died mid-phase on transient 503s. Work was intact
on disk every time; resume via SendMessage to the named agent. If it dies again immediately,
back off ~75s (bash sleep) before re-nudging — hammering a flapping auth service just re-dies.
Dev had even committed + written its assessment before dying at the handoff; I advanced the
phase myself (SM owns routing in inline mode) rather than resuming just for the transition.
(4) IDLE-WITHOUT-FILING held ~50% this run: reviewer completed its assessment + ran
resolve-gate/complete-phase but sent NO summary message twice. ALWAYS grep the session for
`**Verdict:**` + check `**Phase:**` before nudging — the verdict is on disk.
(5) MERGE --STAT SHOWS BOTH PARENTS: `gh pr merge` prints the combined two-parent delta, so
unrelated files (vite.config.ts, a 164-prefixed test) appeared in the stat. Benign — confirm
your branch's real contribution via `PR headRefOid == local HEAD` + your known commit list;
no need to git-diff on the protected branch (the develop-cwd hook blocks reads too).
(6b) APPROVAL-GATE FORMAT (enforced at Reviewer's complete-phase, NOT resolve-gate — resolve-gate returns ready then complete-phase errors). In peloton-inline the Reviewer spawns no subagents, so it must MANUALLY satisfy these or complete-phase blocks (discovered one-per-attempt on 162-20 — bake ALL into the Reviewer spawn prompt upfront): (a) a `## Subagent Results` section with a table row per enabled specialist (preflight, rule-checker[RULE], security[SEC], test-analyzer[TEST], type-design[TYPE]) marked "self (inline)"; (b) a literal `**All received:** Yes` line after that table; (c) inline `[RULE] [SEC] [TEST] [TYPE]` tags in the Reviewer Assessment prose. The single bold `**Verdict:**` line still required. Tell every Reviewer spawn to write these as part of its assessment BEFORE running complete-phase.
(7) Clean setup→red every time with the proven sm-setup spawn (bare session name, `**Phase:**
setup`, bare `tdd`, poison-token discipline); SM adds `## SM Assessment` then resolve-gate →
complete-phase advances setup→red with no overshoot. Model tiers: sonnet TEA/Dev, opus
Reviewer for high-blast-radius (finish/merge machinery) diffs, sonnet Reviewer for trivial.
</pattern>

<pattern name="routing">
| Points | Workflow |
|--------|----------|
| 1-2 | SM → Dev (skip TEA) |
| 3+ | SM → TEA → Dev |
</pattern>

<pattern name="helpers">
| Task | Subagent |
|------|----------|
| Backlog research | `sm-setup MODE=research` |
| Story setup | `sm-setup MODE=setup` |
| Finish preflight | `sm-finish PHASE=preflight` |
| Finish execute | `sm-finish PHASE=execute` |
</pattern>

<pattern name="delivered-in">
When one story covers another: `status: done`, `delivered_in: 28-1`, `notes: Implemented as part of 28-1`.
</pattern>

<pattern name="peloton-inline" date="2026-06">
Peloton inline mode (no tmux): SM stays lead and drives TEA/Dev/Reviewer via the Agent tool (subagent_type per role, model per user direction). Each spawn prompt must include: (1) `pf agent start "<role>"` as first step, (2) inline-mode overrides — no `pf handoff marker`, no relay/skill invocation, no PR create/merge by Reviewer, stop after `complete-phase` and return summary to SM, (3) session/context/handoff file paths, (4) the prior agent's designed interface verbatim. SM owns PR create + merge + finish ceremony. Ran 7 stories clean (160-8, 161-1, 157-6, 159-4; epic-153 run: 153-11, 153-7, 153-8 — all Opus, zero rejections). If a subagent dies mid-phase (socket error), SendMessage to its agentId resumes from transcript with context intact. For multi-story runs: accumulate each story's sprint commit on one `chore/sprint-...` branch and land a single PR to main at the end; gate resolve-gate needs a `## Sm Assessment` heading in the session before setup-exit passes. Reviewer deferred findings → file follow-up story immediately via `pf sprint story add` to the thematically-matching epic before landing the sprint PR.
</pattern>

<pattern name="sprint-yaml-sharded">
Sprint YAML is sharded. `current-sprint.yaml` has epics as string refs (e.g. `PROJ-14510`) and a small top-level `stories` list. Most stories live in shard files: `sprint/epic-{ref}.yaml`. The `load_sprint()` loader merges shards into nested epic dicts with `stories` arrays. Code that reads raw `current-sprint.yaml` without the loader will miss shard stories. `write_sprint()` from `yaml_io` handles writing back to shards correctly. The `execute_sync_plan` in `jira/bidirectional.py` reads raw YAML and uses `_update_story_in_sprint` which expects the merged format — this is the bug causing `--assignee` (and `--status`/`--points`) apply to silently skip shard stories.
</pattern>

<pattern name="single-session-relay-pipeline-clean-run" date="2026-07-30">
155-11 (2 pts, tdd): full SM→TEA→Dev→Reviewer→SM pipeline in ONE session via relay markers (/pf-tea → /pf-dev → /pf-reviewer → /pf-sm), zero rejections. Datapoints worth repeating: (1) sm-setup honored the "name the session bare `{id}-session.md`" spawn instruction — no slug-rename recovery needed, and it wrote `**Phase:** setup` (not red), so the DOCUMENTED exit (resolve-gate → complete-phase → marker) worked without the overshoot workaround. (2) SM pre-created the PR (ready, full prove-the-work body incl. deviations + review summary + follow-ups) BEFORE `pf sprint story finish`; finish's merge_pr landed clean — third clean datapoint for pre-create-then-finish (155-10, 161-x family). ALWAYS still verify `gh pr view N --json state,mergedAt` before committing bookkeeping. (3) Finish run FROM pennyfarthing/ per finish-cwd memory; git_cleanup leaves that shell on develop — cd with absolute path before orchestrator git ops. (4) Bookkeeping accumulates on the already-open chore/sprint-* branch (PR #55) — one PR to main, Keith merges; follow-up stories (sibling .venv sweep + title-interpolation hardening from the 155-11 review) intentionally NOT filed until #55 lands (epic-yaml id-collision gotcha). (5) sm-finish preflight's two blocks (PR-open, repo-wide ruff) were the known artifacts — story-scoped lint/tests clean; proceed. (6) When the merged PR closes a gh issue that carried a "secondary issue" already shipped by a sibling story, comment the routing on the issue so it isn't refiled.
</pattern>

<pattern name="single-session-full-pipeline-datapoint-3" date="2026-07-31">
155-16 (2 pts, tdd): third clean single-session relay pipeline (SM→TEA→Dev→Reviewer→SM, zero rejections, ~26 min setup-to-finish) and fourth clean pre-create-then-finish datapoint (PR #159 created ready with full prove-the-work body BEFORE `pf sprint story finish`; merge_pr landed clean; verified state=MERGED before bookkeeping). New wrinkles: (1) sm-finish preflight spawned with explicit "REPORT, DON'T FIX" + known-false-blocker list returned clean with a paste-ready Impact Summary — no false-block noise at all this run. (2) Auto-mode classifier denied Reviewer's `git checkout origin/develop -- <file>` inverse probe AND `gh pr merge` probes — reviewers should lean on commit-order evidence + test-analyzer's self-restoring mutation runs instead (recorded in reviewer sidecar). (3) Follow-ups (155-29/155-30) filed via `pf sprint story add` on the fresh chore branch cut from up-to-date main AFTER the code PR merged — no id-collision risk since no orchestrator PR was pending. Bookkeeping PR #58 to main awaits Keith.
</pattern>

<pattern name="single-session-full-pipeline-datapoint-4" date="2026-07-31">
155-29 (2 pts, tdd): fourth clean single-session relay pipeline (SM→TEA→Dev→Reviewer→SM, zero rejections, ~26 min setup-to-finish) and FIFTH clean pre-create-then-finish datapoint (PR #160 ready with full prove-the-work body BEFORE finish; merge_pr landed; verified state=MERGED). Notes: (1) the story itself fixed the finish retry wedge (already-merged short-circuit) — future post-merge aborts are now retryable, which de-risks this whole ceremony. (2) sm-finish preflight with the report-don't-fix leash + false-blocker list returned ready:true with ZERO false-blocker noise and a paste-ready Impact Summary — second clean run of that spawn shape; keep it verbatim. (3) Follow-up routing: when a review finding's class matches an EXISTING backlog story, fold via `pf sprint story update <id> --add-ac "..."` (there is NO --notes option) instead of filing a duplicate; new stories only for distinct work (155-31 dry-run preview, 155-32 probe consolidation). (4) Reviewer Questions that need Keith's product call (no-PR acceptance revisit, human-mode resume path) stay as findings in the archived session + surfaced in the final report — not auto-filed as stories.
</pattern>

<pattern name="single-session-full-pipeline-datapoint-5" date="2026-08-01">
155-33 (2 pts, tdd): fifth clean single-session relay pipeline (SM→TEA→Dev→Reviewer→SM,
zero rejections, ~36 min setup-to-merge) and SIXTH pre-create-then-finish datapoint —
but the first where the standing verify-after-finish rule caught a LIVE false-done
(see gotcha session-prose-poisons-finish-field-parse; do not skip the verify, ever).
Working notes: (1) `pf sprint work next` picked a p3 over six p1s — filed 160-25;
pick priority manually until fixed. (2) sm-setup wrote `**Workflow:** tdd (phased)`
into the tracking block — resolve-gate rejects the parenthetical; trim to the bare
identifier before the exit protocol. (3) Follow-up routing this run: five stories
filed AFTER the code PR merged, on the already-open chore branch (its shards carried
the latest IDs, no id-collision risk); accumulate pattern retitles the chore PR to
list all completed stories. (4) Reviewer ran with only preflight+security enabled —
covering the 7 disabled domains personally with tagged observations satisfied the
gate; adversarial-verify both subagent claims first-hand before confirming (both
security claims reproduced exactly). (5) zsh eats a bare `===` echo separator —
use '---'.
</pattern>

<pattern name="single-session-full-pipeline-datapoint-6" date="2026-08-01">
155-40 (2 pts, tdd, p1): sixth clean single-session relay pipeline (SM→TEA→Dev→Reviewer→SM,
zero rejections, ~32 min setup-to-merge) and SEVENTH clean pre-create-then-finish datapoint
(PR #166 ready with full prove-the-work body BEFORE finish; merge landed; verified
state=MERGED at 13:42Z before bookkeeping). Notable: this story WAS the finish-parser fix,
and the finish ran with the fix live (editable pf follows the working tree) — the anchored
parser resolved its own `- **PR:** #166` field from a session deliberately written with
poison-token discipline (backticks-only in prose); first live outing clean, but the
verify-after-finish rule stays MANDATORY regardless. Working notes: (1) the poison-token
spawn instruction to sm-setup (never write bold field tokens in session prose; backticks
only) is now proven end-to-end and belongs in every spawn for stories touching the session
parser. (2) sm-setup again honored bare session name + `**Phase:** setup` + bare `tdd` —
third clean run of that spawn shape; keep it verbatim. (3) sm-finish preflight with
report-don't-fix + false-blocker list: third consecutive zero-noise run, paste-ready
Impact Summary. (4) Follow-up routing: 3 new stories (155-44 fence/first-heading hardening,
155-45 decode-raise wrap, 155-46 parser consolidation) filed on the accumulate chore branch
AFTER the code PR merged; Reviewer's placeholder-shape Question folded into 155-34 via
--add-ac (fold-don't-duplicate rule). (5) Manual p1 pick from the backlog (155-40 over five
other p1s) keyed on the critical-gotcha linkage — until 160-25 fixes `work next`, keep
picking manually and prefer the story that de-risks the ceremony itself.
</pattern>

<pattern name="single-session-full-pipeline-datapoint-7" date="2026-08-01">
155-34 (2 pts, tdd, p1): seventh clean single-session relay pipeline (SM→TEA→Dev→Reviewer→SM,
zero rejections, ~46 min setup-to-merge) and EIGHTH clean pre-create-then-finish datapoint
(PR #167 ready with full prove-the-work body BEFORE finish; merge landed; verified
state=MERGED at 17:45Z + merge commit == origin/develop tip before bookkeeping). Landmark:
this finish ran with the story's OWN no-PR verification gate live (editable pf, working
tree) — the PR path resolved #167 from Story Details under the 155-40 authority parser
with Dev-assessment field lines present and correctly outranked. Working notes:
(1) manual p1 pick again (155-34 over four 1-pt p1 siblings + a 3-pt triage) keyed on
de-risk-the-ceremony — the heuristic keeps paying; 160-25 still open. (2) TEA's per-FILE
field-count sibling sweep missed 4 multi-session fixtures (no_jira, 160-3, 155-6, 153-4
inline) that Dev caught at green — the sweep recipe is now count-per-SESSION-fixture
(recorded in TEA sidecar). (3) Reviewer probed the security subagent's SUGGESTED fix and
found it broken (`--` separator kills rev-parse --verify) — follow-up stories must carry
the PROBED fix shape, not the subagent's guess (155-47 filed with the refs-prefix shape).
(4) Follow-up routing: 1 new story + 5 folds via --add-ac (155-45/42/39/19/18), all filed
on the fresh chore branch cut from post-merge main — fold-don't-duplicate held; only the
genuinely-new hardening got a story. (5) sm-finish preflight with report-don't-fix +
false-blocker list: FOURTH consecutive zero-noise run, paste-ready Impact Summary.
(6) Poison-token discipline held through four agents' session writes; the finish parsed
branch/PR correctly from a session dense with field-token prose in backtick form.
<pattern name="single-session-full-pipeline-datapoint-5-155-30" date="2026-07-31">
155-30 (1 pt, tdd, test-polish): fifth clean single-session relay pipeline (SM→TEA→Dev→Reviewer→SM, zero rejections, ~23 min setup-to-finish) and SIXTH clean pre-create-then-finish datapoint (PR #161 ready with full body BEFORE finish; merge_pr landed; verified MERGED). New wrinkles: (1) TEST-POLISH story shape: no RED state exists — SM assessment should pre-authorize green-on-arrival ("if pins FAIL against production, that's a blocking finding, stop") so TEA logs one clean deviation instead of agonizing; Dev green = verification-only + prove pre-existing failures on clean develop (branch-switch probe was permitted this run). (2) Bookkeeping stacked onto the ALREADY-OPEN chore/sprint PR (#59, now 155-29+155-30) — the accumulate pattern works fine while Keith's merge is pending, and `story add` on this branch sees the branch's own epic state (no id collision within the branch). (3) Reviewer follow-up finding routed to a DIFFERENT epic (159-15 baseline triage) — cross-epic story add while an epic-155 PR is pending is collision-safe. (4) reviewer subagents idle-without-filing ~40% of the time; one SendMessage nudge recovers them.
</pattern>

<pattern name="peloton-inline-epic-162-run" date="2026-08-05">
Epic 162 run (peloton-inline, one story at a time, merge between): 162-1..7 clean, one Reviewer
rejection (162-2) recovered via hand-rollback of the tracking block + SendMessage rework loop.
Key datapoints: (1) resolve-gate IGNORES reviewer verdict (162-21 filed) — SM must read the
verdict from the Reviewer's returned summary, never from gate routing; warn Reviewer spawns
about it. (2) Since 162-6 merged, `pf sprint story finish` works from the ORCHESTRATOR ROOT
(first live outing on 162-7 finish, clean) — the run-from-pennyfarthing/ ritual is retired,
but verify-after-finish stays MANDATORY. (3) 503-killed subagents resume cleanly via
SendMessage to the agentId — work was intact on disk both times (162-5 TEA). (4) Since 162-5,
the suite exits 0 with 7 loud xfails — spawn prompts should say "suite stays exit 0" instead
of carrying a false-blocker baseline list. (5) Stray `venv/` (not .venv) created by a subagent
trips the leakage gate (162-37) — check for it when the leakage test fails mysteriously.
(6) Reviewer-recommended one-line pre-merge folds (162-7 F2): send Dev back via SendMessage,
no full re-review needed for a fold the Reviewer already specified.
</pattern>

<pattern name="out-of-sprint-epic-shard-fold-via-sprint-file" date="2026-08-06">
162-13 finish: folding a review finding into a story on an epic shard NOT registered in current-sprint.yaml (epic-164 "Deferred hardening tail") — `pf sprint story update 164-5 --add-ac ...` fails with story-not-found because update reads the sprint index, but `--sprint-file sprint/epic-164.yaml` targets the shard directly and works (dry-run confirmed first). No manual YAML edit needed. Rest of the run: fifth+ clean relay pipeline (TEA→Dev→Reviewer→SM, zero rejections), seventh clean pre-create-then-finish datapoint (PR pennyfarthing#185 ready with prove-the-work body before finish; merge verified state=MERGED at 48694f824). Follow-up routing shape held: new stories (162-45 multi-parent consumers, 162-46 polish) to the in-sprint epic via story add + --description in a second update call (add takes no description flag); class-matching finding folded into existing backlog story via --add-ac.
</pattern>

<pattern name="peloton-inline-named-agents-162-49" date="2026-08-07">
162-49 (2 pts, p1, tdd): first peloton-inline run using NAMED background agents (Agent tool with
name:, SendMessage routing) instead of foreground spawns. One Reviewer rejection (4 measured
blockers), rework via SendMessage, cycle-2 approve — ~90 min setup-to-merge. Key datapoints:
(1) MESSAGE RACES ARE THE NORM: three message crossings this run (nudge vs work-in-flight,
gate answer vs gate question). ALWAYS check disk state (session file, git log) before nudging
an idle agent — "idle" often means "already done, report in flight". A no-op-looking resume
may be a stale view on YOUR side. (2) Idle-without-filing still ~40%: reviewer needed 2 nudges
before its (already-complete) report arrived; the assessment was on disk the whole time — grep
the session BEFORE assuming lost work. (3) GATE/POISON-TOKEN COLLISION: resolve-gate requires
a literal bold Verdict field line; the poison-token discipline forbids bold field tokens in
prose. Reviewer threaded it (one bold line, backticks elsewhere) — tell Reviewer spawns
explicitly. (4) STALE-VERDICT GATE TRAP: after rework, resolve-gate re-reads the round-1
REJECTED verdict and returns approval_rework/dev/green even though the session is at review —
Dev running complete-phase there would double-advance past the re-review. Rework spawns must
be told: after round-1 exit already advanced the phase, do NOT re-run the exit protocol; SM
verifies with pf handoff phase-check. Filed as AC on 162-47. (5) Reviewer pre-declaring its
cycle-2 probes (re-run the exact establishing probes + mutation checks, not a fresh sweep)
made re-review fast and decisive — ask for that shape explicitly. (6) Dev racing SM's addendum
relay: forward reviewer addenda to Dev IMMEDIATELY, not after digesting — Dev finished rework
before two of my messages arrived. (7) approval gate enforces 5 format requirements the rework
gate doesn't, discovered one-per-attempt (162-47 AC). (8) Two-cwd suite runs must be SERIAL
(concurrent pytest races test_pypi_packaging's wheel-build dir) — put it in every preflight
spawn for two-cwd stories.
</pattern>

<pattern name="dogfooding-the-gate-you-just-built-162-47" date="2026-08-07">
162-47 (3 pts, p1, tdd): the story CHANGED the review gate's own requirements, so the Reviewer
was the first live consumer of the shape it had just reviewed into existence. Datapoints worth
repeating: (1) SELF-REFERENTIAL TRAP: B3 (reviewer sections must outnumber round-trips) means a
cycle-2 reviewer must APPEND a second `## Reviewer Assessment` rather than edit in place. SM
wrongly warned that this forces neutralizing cycle-1's bold verdict line to avoid "two verdicts";
the Reviewer MEASURED it instead of obeying: the one-verdict rule is PER-SECTION (select_last_section
returns only the last; read_agent_verdict scans only that), so two sections with one bold verdict
line each is unambiguous and cycle-1's rejection record stays INTACT. Lesson: never instruct a
lossy session edit to satisfy a gate without measuring the gate's actual scope first — the
safe-looking fix was the destructive one. Filed as a doc-clarification AC (162-63).
(2) REVIEWER'S SUGGESTED FIX WAS WRONG, TWICE, AND BOTH AGENTS PROVED IT: Dev measured that both
of the Reviewer's proposed F1 remedies break an AC test, and implemented a third shape; the
Reviewer then implemented both of its OWN proposals in cycle 2, confirmed 3 and 4 failures
respectively, and withdrew them. Rework briefs should say "if the Reviewer's suggested fix
doesn't work, measure and propose your own" — carrying the PROBED shape beats the suggested one
(same lesson as 155-47). (3) The Cycle tag tracks completed ROUND-TRIPS, not review rounds —
cycle 2 requires `Cycle: 1`. Warn Reviewer spawns. (4) Two rejections this run (162-49, 162-47),
both recovered in one rework round via SendMessage with a per-finding disposition requirement
(FIXED/DEFERRED per item) — that requirement is what made cycle 2 fast both times; make it
standard in every rework brief. (5) sm-finish preflight must be told the two-section state is
BY DESIGN or it may flag it.
</pattern>
