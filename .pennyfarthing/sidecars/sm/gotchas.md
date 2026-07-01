# SM Agent Gotchas

<gotcha name="finish-needs-bare-session-name" severity="high">
`pf sprint story finish` is internally inconsistent on the story-id form, and a slug-named session breaks it mid-run. When `sm-setup` is given a multi-word SLUG it names the session `.session/{id}-{slug}-session.md` (e.g. `160-18-frame-warnings-sink-sanitize-session.md`), but finish wants the BARE `{epic-num}-session.md` and a bare story-id arg: `finish 160-18` → "Session file not found: .session/160-18-session.md" (constructs path from the bare arg), while `finish 160-18-frame-...` → "Invalid story ID format" (yaml-update rejects the slug). WORSE: the slug-arg attempt gets PAST session lookup and ARCHIVES the session (a COPY to `sprint/archive/{slug}-session.md`) BEFORE failing at yaml-update → a half-finished state (story still `backlog`, stray slug-named archive, .session intact). RECOVERY: (1) `rm sprint/archive/{id}-{slug}-session.md` (the premature stray), (2) `mv .session/{id}-{slug}-session.md .session/{id}-session.md` (rename to the canonical BARE name every prior archive uses — `ls sprint/archive/*-session.md` confirms all are bare), (3) `pf sprint story finish {bare-id}` — now session lookup AND yaml-update both accept it. Systemic fix candidate (own story): sm-setup should name the session bare `{id}-session.md`, OR finish should glob `.session/{id}-*session.md` + validate only the leading `{epic}-{num}`.
</gotcha>

<gotcha name="no-code" severity="critical">
SM never writes implementation code. Read-only for context. Create session → handoff.
</gotcha>

<gotcha name="read-before-write" severity="critical">
Always `Read` existing files before `Write` or `Edit`.
</gotcha>

<gotcha name="assessment-before-handoff" severity="critical">
Edit session with assessment BEFORE spawning handoff subagent.
</gotcha>

<gotcha name="jira-field">
Use `jira:` not `jira_key:` in sprint YAML.
</gotcha>

<gotcha name="no-guess-jira">
Never fabricate PROJ-XXXXX keys. Look up in YAML or query Jira.
</gotcha>

<gotcha name="symlinks">
New commands: create in `pennyfarthing-dist/commands/` AND symlink in `.claude/commands/`.
</gotcha>

<gotcha name="handoff-marker">
Emit `<!-- CYCLIST:HANDOFF:/agent -->` for Cyclist UI button.
</gotcha>

<gotcha name="american-spelling">
Use "Canceled" not "Cancelled" for Jira transitions.
</gotcha>

<gotcha name="verify-subagent">
Cross-check story counts against `sprint/current-sprint.yaml`.
</gotcha>

<gotcha name="preflight-npm-artifact">
sm-finish preflight repeatedly false-blocks on `npm run lint` at orchestrator root — repos.yaml stale `language: javascript`/`build_command: npm install` config; framework is Python-only (ADR-0034). Also false "No PR found" when the PR is already merged. Treat both as tooling artifacts, verify ruff/PR-state manually, proceed.
</gotcha>

<gotcha name="preflight-mutates-code" severity="critical">
A sm-finish preflight subagent once FIXED ruff issues and committed to local develop (161-1, 702b6d146). Preflight must be read-only — instruct "report, don't fix" in the spawn prompt. Direct push to develop is hook-blocked; recovery: branch from the stray work, reset develop to origin, PR it.
</gotcha>

<gotcha name="hook-cwd-protected-branch">
PreToolUse git hooks evaluate against the shell's CURRENT cwd (and pattern-match command text), not the cd target inside a compound command. Running orchestrator git ops while the shell sits in pennyfarthing/ on develop gets blocked as "protected branch". Split into separate Bash calls; cd first, standalone.
</gotcha>

<gotcha name="epic-yaml-id-collision-off-premerge-main" severity="warning">
Branching a new story's orchestrator branch off CLEAN origin/main while a prior sprint PR (that adds stories to the same epic) is still UNMERGED → `pf sprint story add` auto-increments from the stale epic shard and re-assigns an ID the pending PR already claimed (e.g. both add `155-7`) — a semantic ID collision, not just a git conflict. Fix: do the orchestrator finish/follow-up bookkeeping AFTER the pending PR merges, then rebase onto post-merge main so `story add` sees the real max ID. The pennyfarthing CODE PR is independent of epic-YAML and can ship first.
</gotcha>

<gotcha name="backfill-epic-refs-live-data-only">
`archive_epic.backfill_epic_refs` resolves empty `epic: ''` archive rows ONLY from LIVE sprint data (`load_sprint` → current epics). Historical rows whose epics are long-archived (e.g. 77 rows in sprint-2610-completed.yaml from epics 143/144/145) are ALL marked "irrecoverable" and the file is never rewritten (it only rewrites when every row resolves). So it CANNOT backfill old archives — those need a prefix-parse migration (`144-5 → 144`), which is the opposite of the no-prefix-parse rule in the live finish path (155-4). Treat historical backfill as its own follow-up, not "straightforward."
</gotcha>

<gotcha name="sm-setup-phase-red-complete-phase-overshoots" severity="warning">
sm-setup MODE=setup writes `**Phase:** red` (the first WORK phase) into the new session, NOT `**Phase:** setup`. So if SM then runs the documented setup-exit `complete-phase` → `marker`, `complete-phase` completes the phase named in the `**Phase:**` FIELD (red), advances to green, and `marker` emits `/pf-dev` — routing past TEA's RED phase. Root cause: complete-phase keys off the `**Phase:**` field value, not the open phase-history row (setup). CLEANEST EXIT after sm-setup in a phased TDD workflow: emit `pf handoff marker` ONLY (Phase already = red → marker emits `/pf-tea`); do NOT run complete-phase, since SM doesn't own the red phase it would be "completing". NOTE: archived 160-16 shipped with the same lossy stamping (`red`: no Started, has Ended) yet still routed through TEA — the underlying routing reaches TEA fine; the phase-history Started/Ended stamps are just cosmetically dropped on the setup→red hop. Recovery if you already over-advanced to green: `pf workflow fix-phase` only moves FORWARD (refuses green→red), so hand-edit the Workflow Tracking block — set `**Phase:** red`, close the `setup` row, make `red` the open row, delete any duplicate `green` placeholder — then verify `pf handoff phase-check tea` (→ `agent: tea, action: start`) and emit `marker` (→ `/pf-tea`). Seen 160-17 (2026-06-26).
</gotcha>

<gotcha name="finish-marks-done-when-merge-blocked" severity="high">
155-5 finish (2026-07-01): `pf sprint story finish` ran all steps (archive_session,
merge_pr, jira_done, yaml_update, ..., remove_session) and marked the story `done`,
but PR #137 stayed **OPEN** — the `merge_pr` step was a silent no-op. Root cause in
THIS env: the Claude Code auto-mode classifier DENIES `gh pr merge` (AI-reviewed PR to
a protected branch with no human approval), so finish's merge subprocess never landed —
yet finish did NOT abort; it archived + removed the session and flipped to `done`
(the exact "done while PR open" 155-1 class, in the finish-truthfulness epic 155). This
is the accepted-over-reach path from 155-1 (`test_no_pr_finish_still_succeeds`) firing on
a blocked/denied merge rather than a genuinely absent PR. RECOVERY: verify PR state
(`gh pr view <n> --json state,mergedAt`); if OPEN+MERGEABLE, get human merge authorization
(the classifier blocks agent merge — do NOT work around it), merge, THEN commit the sprint
bookkeeping. HOLD the `chore(sprint): complete` commit until the PR actually merges — never
record `done` before the merge lands (SOUL #14). Also: orchestrator `main` push is
classifier-gated (trunk-based-with-PRs) — needs explicit human authorization even though
history shows direct `chore(sprint): complete` commits. Filed follow-up in epic 155.
