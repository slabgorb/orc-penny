# Reviewer Agent Gotchas

<gotcha name="narrowed-exception-rewrite-lets-new-class-escape" severity="critical">
When a fail-loud fix narrows a broad `except Exception` into typed catches, ENUMERATE the full raisable set of every guarded call before approving — the rewrite routinely converts a silent-drop bug into a crash bug for the exception class the author forgot. `Path.read_text()` raises OSError AND `UnicodeDecodeError` (a ValueError!); catching only OSError lets a non-UTF-8 file escape. Probe empirically, two ways: (1) `write_bytes(b"caf\xe9 \xff\xfe")` to a referenced input on the branch — does the entry point raise?; (2) same scenario with the file checked out from origin/develop — silent-drop there + raise on branch = REGRESSION introduced by the fix (HIGH, reject), not pre-existing debt. Also probe `chmod 0o000` (PermissionError hides inside `except OSError` while `exists()`-gated "not found" warnings stay silent — present-but-unreadable becomes invisible). This is lang-review python.md check #13 (fix-introduced regressions) made concrete. Story 160-4: tests covered YAML-syntax errors + scalars but not undecodable bytes; 150-green scoped suite missed it entirely.
</gotcha>

<gotcha name="jira-less-fallback-check-the-symmetric-op" severity="medium">
When a story adds a Jira-less (local-YAML) fallback to ONE operation, always check the SYMMETRIC/sibling operation in the same module — it usually still hits the network unconditionally and reproduces the exact bug being fixed. Story 158-5 gated `claim_issue` on `is_jira_enabled()` but `unclaim_issue` (same file) still calls `get_client()` directly → `pf sprint story claim --unclaim` stays broken on kanban-only projects. Capture as a non-blocking Delivery Finding (out of AC scope) rather than blocking, but ALWAYS name it — it's the highest-value gap a focused-on-the-diff review misses. Same lens applies to any add-a-local-path story: grep the module for other `get_client()`/network callers.
</gotcha>

<gotcha name="inline-fixture-vs-sharded-repo-transitively-covered" severity="low">
A claim/transition story's tests often use an INLINE-epic sprint YAML fixture while the real dogfood repo (orc-penny) is SHARDED (epics as string refs + `epic-*.yaml`). Don't reflexively block on "tests don't exercise sharded write-back" — if the new code reuses the production `transition_story` / `write_sprint` round-trip (read_sprint→find_story_in_data→mutate→write_sprint), the shard write-back is covered transitively by `test_156_1_*` and by transition_story being the live workflow path. Verify the reuse (not a reimplementation of YAML mutation), then rate it a LOW coverage-thinness note, not a bug. Story 158-5.
</gotcha>

<gotcha name="confidence-not-severity-on-edge-findings" severity="medium">
reviewer-edge-hunter/test-analyzer rate findings by CONFIDENCE (does it exist?), not SEVERITY (does it matter?). On a bugfix PR, an edge they rate "HIGH confidence" (e.g. 158-5: re-claiming your own already-in_progress story returns cryptic exit_code 3) is frequently a MEDIUM/LOW non-blocking UX wart — out-of-AC, loud failure, no corruption, and the pre-fix behavior also blocked. Confirm it (don't dismiss), downgrade severity with explicit rationale (judge by blast radius / can-it-reintroduce-the-bug), capture as a non-blocking Delivery Finding. Don't let a subagent's confidence score drive a reject.
</gotcha>

<gotcha name="subset-green-hides-regressions" severity="critical">
When a story changes the BEHAVIOR of a shared function, a Dev/preflight "GREEN" on a hand-picked subset of test files routinely misses regressions in OTHER callers. ALWAYS enumerate every caller of the changed symbol and run THEIR tests before trusting any GREEN: `grep -rln "<symbol_or_gate_type>" src/pf/tests/`, then run each file scoped. Story 158-3: the guard keyed on `gate_type == "sm_setup_exit"`; Dev + preflight ran `test_handoff_cli/e2e/108_2` (92 green) but never ran `test_143_9_tdd_cycle_e2e.py`, whose e2e `project` fixture seeds no `sprint/context/` and drives `complete_phase(..., "sm_setup_exit")` ~16 times → `16 failed, 41 passed`. The reviewer-test-analyzer subagent flagged it HIGH; I verified by running the file. A new mandatory precondition on a function invalidates every fixture that modeled the old precondition — find them by symbol search, not by trusting the author's regression list.
</gotcha>

<gotcha name="reproduce-preexisting-before-approving-red" severity="high">
If you APPROVE a PR while tests are still red, you MUST independently reproduce the "pre-existing" claim — never take Dev's word. Revert the change to `origin/develop` (`git checkout origin/develop -- <changed files>`), run the still-red tests, confirm they fail on clean develop, then restore (`git checkout HEAD -- <files>`). Only then is "pre-existing, out of scope" a defensible approval. This repo has NO CI, so develop genuinely carries stale failures — but "stale" must be PROVEN, not assumed. Story 158-3 Round 2: approved with 4 red verify-phase tests after reproducing `4 failed` on develop with the guard+fixture reverted (a `detect_workflow_state` bug in pf/prime/workflow.py, unrelated to the context gate). Pair this with scoping discipline: don't force the current story to absorb an unrelated module's bug.
</gotcha>

<gotcha name="failing-tests" severity="critical">
Tests MUST pass before approval. No exceptions.
</gotcha>

<gotcha name="assessment-before-handoff" severity="critical">
Write assessment to session file BEFORE spawning handoff subagent.
</gotcha>

<gotcha name="stub-approval" severity="critical">
Never approve stub/TODO implementations unless explicitly scoped as infrastructure-only. Ask "does this work end-to-end?" not "do tests pass?"
</gotcha>

<gotcha name="unconnected-components" severity="critical">
Trace data flow source→sink. Components existing != components wired. Tests that call methods directly miss integration gaps.
</gotcha>

<gotcha name="auto-trigger-wiring">
When ACs say "automatically" or "on [event]", verify the trigger is wired to the action. Check lifecycle hooks actually call the implementing methods.
</gotcha>

<gotcha name="manifest-overwrite-pattern" severity="high">
When `createManifest()` is called in update flows, it creates a FRESH manifest without preserving accumulated state fields. Trace what fields the old manifest carries and verify they survive the write-read-write cycle. Any field added to Manifest interface must also be preserved across `createManifest()` calls.
</gotcha>

<gotcha name="drop-in-reference-module-security-debt" severity="high">
When a story adopts a "drop-in" reference module pasted into an issue/spec, audit it for security debt the spec author skipped — mock-heavy tests and "it works live" verification both pass while CWE-class bugs slip through. Story 154-1's #17 reference module shipped: arbitrary-dir deletion via unsanitized `theme` in `clean()`→`rmtree` (CWE-22), `theme` path-traversal into cache paths, SSRF via trusting `manifest['base_url']` for the download URL (CWE-918), and unguarded dict keys that broke its own "never raises" contract. Always: sanitize any external string used in a `Path` join or URL; never trust a downloaded manifest's URLs (build from a hardcoded base); `tarfile filter="data"` is necessary-not-sufficient (it guards members, not the destination dir, and TypeErrors on Python <3.11.4).
</gotcha>

<gotcha name="test-claims-no-network-but-falls-through" severity="high">
A fixture docstring saying "no network — sentinel pre-seeded" only holds for tests that seed the sentinel. The "returns None when nothing cached" sibling test deliberately omits the sentinel, so a lazy `ensure_portraits()` inside the resolver falls through to a real `urlopen`. Check each test's setup individually against the lazy-download path — don't trust the fixture's blanket claim.
</gotcha>

<gotcha name="deletion-story-test-diffs" severity="medium">
When a story removes or absorbs a package, verify source→destination symbol parity by comparing original barrel exports with migrated barrel exports line-by-line. Glob may fail on symlinked directories — fall back to `ls` for verification.
</gotcha>

<gotcha name="false-green-guard-string-not-returncode" severity="high">
A test that runs another test runner in a subprocess and tries to prevent a false green by string-matching stdout (e.g. `assert "no tests ran" not in result.stdout`) is almost always vacuous — VERIFY the actual output/exit codes before trusting it. Empirically (story 153-9): pytest prints `"N deselected"` and exits **5** when `-k` matches nothing, exits **4** on collection/import error, and exits **0** only when tests actually ran and passed — it never prints "no tests ran" for the deselection case. So the only robust liveness check is `assert result.returncode == 0` (plus optionally `"passed" in stdout`). When a meta-test's whole job is to keep a regression alive, a guard that can't detect "zero tests ran" is a blocking defect, not a nit — the regression can silently stop guarding on a rename or broken import.
</gotcha>

<gotcha name="stale-local-develop-pollutes-diff" severity="high">
`git diff develop...HEAD` can show DOZENS of unrelated files (other merged stories' changes) when local `develop` is behind `origin/develop` — the merge-base is then an old commit. sm-setup cuts branches from `origin/develop`, so ALWAYS `git fetch origin develop` then diff `git diff origin/develop...HEAD` (verify `git merge-base origin/develop HEAD == origin/develop`). Story 158-2: local develop showed portrait_cdn/test_154/git_utils churn that wasn't in the branch at all.
</gotcha>

<gotcha name="delegation-widens-exposure-to-preexisting-resolver" severity="medium">
When a bugfix consolidates onto a SHARED resolver (story 155-3/gh #28: `archive_story` dropped its `\d{4}` regex and now calls `archive_epic.get_archive_path`), the security subagent will flag the shared resolver's lack of input sanitization (CWE-22 path-traversal via `str(name).split()[-1]` / `str(number)` interpolated into a `Path`). Two-part judgment: (1) LOCATION — the resolver is PRE-EXISTING (shipped in 151-1), NOT in this diff; the diff only *widened the caller's exposure* (regex-constrained → arbitrary token). That widening is real but is the CORRECT consolidation (SOUL #2); the right fix is to harden the resolver CENTRALLY in a follow-up so BOTH callers (story + epic archive) benefit — not to re-add a caller-local guard. (2) SEVERITY — sprint YAML is local, self-authored config: no trust boundary is crossed, so CWE-22 (an untrusted-input class) doesn't really apply; and the downstream `if not archive_file.exists(): return error` guard makes a typo'd/`/`-bearing name fail LOUD, not silently corrupt. So: CONFIRM (rule-matching #5/#11 — can't dismiss), DOWNGRADE to LOW, capture as a non-blocking Delivery Finding recommending a central `get_archive_path` hardening story (resolve()+containment + `re.fullmatch(r"[\w.-]+", sprint_id)` + `encoding="utf-8"` on the append). Do NOT block the consolidation. Same family as `severity-by-blast-radius-for-bugfix-PRs` and `confidence-not-severity-on-edge-findings`.
</gotcha>

<gotcha name="severity-by-blast-radius-for-bugfix-PRs">
When reviewing a fix FOR a data-loss/corruption bug, judge residual-finding severity by whether it REINTRODUCES the loss, not by the finding's intrinsic class. Failure modes that are loud (traceback + non-zero exit), benign (a missing cache vs the old clobber), or threat-model-inapplicable (CWE-59 needing pre-existing FS write on a single-user local tool) are MEDIUM/LOW even when a subagent rates them "high confidence" — confidence ≠ severity. Confirm them (don't dismiss, esp. rule-matching ones like python.md #5/#6), downgrade with explicit rationale, capture as non-blocking Delivery Findings. Story 158-2 approved with 13 such findings because none could reintroduce the gh #53 clobber.
</gotcha>
