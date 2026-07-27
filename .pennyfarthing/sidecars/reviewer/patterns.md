# Reviewer Agent Patterns

<pattern name="new-raise-condition-audit-all-caller-chains">
155-7 REJECT: when a diff ADDS raise conditions to an established raise-style resolver (`get_archive_path` gained charset/containment ValueErrors), the review question is not "is the guard sound" (it was — no charset bypass, resolve-before-compare correct) but "does EVERY call chain reaching the new raise still honor its own contract." Trace ALL production callers transitively: `archive_story` wrapped (155-3), but `archive_epic()` → `ensure_archive_file` and `story_finish._add_story_to_completed` (whose docstring even PROMISES SOUL #10) did not — and the new trigger surface ("any punctuated sprint name") is vastly wider than the old one ("name+number both unset"), so "pre-existing gap" is NOT a valid dismissal: the diff widened the blast radius, that's lang-review #13 verbatim ("adding validation but only on one code path"). Severity amplifier: locate the unwrapped call in its FLOW ORDER — story-finish step 4b runs AFTER the merge step, so the crash strands finish half-done (the epic-155 truthfulness failure class) → HIGH, reject. Second lesson: hardening tests with `except ValueError: return` escape hatches go INERT the moment the impl raises on every parametrized case — run the mental (or real) coverage check "which asserts still EXECUTE post-fix"; here 10/10 containment asserts became unreachable and a leak assert checked a dict key (`message`) the failure path never sets (always-empty → vacuous). Cross-check subagents against each other: rule-checker declared test-quality #6 compliant from pattern-reading while test-analyzer PROVED vacuousness empirically — line-level empirical evidence overrides checklist pattern-matching; record the override as a Challenged note. Also verify "central fix" claims by grepping for sibling construction sites of the same filename family (`epic-{ref}.yaml` shards, `pf sprint new`'s inline f-string) — "centralized" often means "centralized for the callers the tests name."
</pattern>

<pattern name="scoped-fix-vs-adjacent-rule-matching-leaks">
Reviewing a SCOPED security/sanitization story (160-18: sanitize the 5 `warnings.warn` sites in data_proxy.py), the security subagent will reliably surface ADJACENT leaks in the SAME file that the PR did NOT touch — here `get_context` (`str(e)` in a JSONResponse body, L322) and `get_project_info` (raw absolute `project_dir` in the body, L466). These MATCH project rule #11 (info-leak at boundary), so per the "rules are not suggestions" critical you may NOT DISMISS them — but matching a rule is NOT the same as blocking THIS PR. Decision rule: a finding blocks only if it is IN the PR's diff/scope. Pre-existing leaks in untouched functions (different sink: response body, not the warnings sink the story scopes) are CONFIRMED + DEFERRED to follow-ups, not REJECT grounds — rejecting a clean correctly-scoped change to force unrelated adjacent fixes is scope-creep with its own untested risk (the sidecars' recurring warning). Verify each subagent finding YOURSELF (read the cited lines) before recording — the security subagent's `get_project_info` catch was real and NEW (TEA/Dev missed it), but trust-but-verify. Route deferrals precisely: `get_context` → fold into the already-queued 160-19 (it owns that swallow); `get_project_info`/`get_git_all` → a NEW follow-up. Tell SM to file/fold AFTER the PR merges (epic-YAML id-collision trap: `pf sprint story add` pre-merge double-claims IDs). For the in-scope LOW (`_safe_exc`'s `type(exc).__name__` could leak a dynamically-named exception class): confirm at LOW with documented-acceptable-risk rationale (stdlib/pf exceptions have static names) — downgrade-with-rationale is allowed, dismissal is not. When only `preflight`+`security` subagents are enabled (the other 7 disabled via `workflow.reviewer_subagents`), still emit ALL 8 dispatch tags in the assessment (gate check #4) marking the disabled ones N/A + verified-directly, and do the Rule Compliance + test-quality checks YOURSELF since rule_checker/test_analyzer are off.
</pattern>

<pattern name="preflight">
Run `just test` and `just lint` before reviewing. Multi-repo: use `repo-utils.sh`.
</pattern>

<pattern name="forbidden">
Auto-block: `t.Skip()` without explanation, `console.log` in prod, `dangerouslySetInnerHTML` unsanitized, hardcoded secrets, `// TODO` without issue ref.
</pattern>

<pattern name="async-emitter">
EventEmitter doesn't await async handlers. Wrap in try-catch or unhandled rejections crash silently.
</pattern>

<pattern name="regex-review">
Check: edge case values, catastrophic backtracking, global flag with `exec()`, captured groups.
</pattern>

<pattern name="platform-shortcuts">
Dynamic modifier keys: `const modifier = isMac ? '⌘' : 'Ctrl+'`. Never hardcode Mac symbols.
</pattern>

<pattern name="fetch-errors">
`fetch()` only rejects on network failure. Always check `response.ok` before using data.
</pattern>

<pattern name="coverage-chore-review-shape">
155-9 (coverage-hardening chore: 8 green-on-arrival pins + 2 RED guard tests + 1 sibling-test tightening) — the review discharge for this story SHAPE: (1) inverse-binding probe is the headline check — exactly the N documented-RED tests must fail on develop source and every intentional green pin must hold (2 failed / 11 passed = the Design Deviation's claim verified, not taken on faith); (2) test-analyzer with mutation-testing enabled is the right heavy specialist here (it killed the no-record and no-sentinel guard mutations empirically) — note its residual finding class: an `error` assert that checks only non-emptiness doesn't pin message FIDELITY (generic-placeholder guard passes) — confirm MEDIUM non-blocking, defer; (3) extended caller sweep beyond Dev's batch (grep test files for the changed symbol, run the complement) found 3 reds → ALWAYS baseline against origin/develop source before attributing (all 3 pre-existing environmental Jira-sync fails in test_153_4; this repo has no CI). Toggle config THIS run: preflight+test_analyzer+type_design+security+rule_checker ON, edge/silent/comment/simplifier OFF — cover those 4 domains yourself and say so per-row. Deferral routing: encoding= omissions in a NEW test file inherited from sibling convention → don't file new work when a thematically-exact backlog story exists (155-23 encoding sweep); name it in the Delivery Finding.
</pattern>
