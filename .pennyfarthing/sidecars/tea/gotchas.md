# TEA Agent Gotchas

<gotcha name="false-red" severity="critical">
Verify tests actually fail. Run them and grep for FAIL/failed. "RED state" means tests run and fail on assertions.
</gotcha>

<gotcha name="wrong-failure">
Tests must fail due to missing implementation, not syntax errors or import failures.
</gotcha>

<gotcha name="dedent-defeated-by-interpolated-block">
`textwrap.dedent(f"...{multi_line_block}...")` silently dedents NOTHING when the interpolated block has column-0 lines — dedent sees no common prefix and the whole fixture keeps its source indentation. Symptom: regex-based code under test copes (unanchored patterns) while the test's own `line.startswith(...)` reader returns '' → a regression pin fails for the wrong reason. Fix: dedent a template with an `@PLACEHOLDER@` line first, then `.replace()` the block in. Story 158-4.
</gotcha>

<gotcha name="git-add-symlinks">
`git add` fails beyond symlinks. Commit to `pennyfarthing-dist/`, not `.claude/` or `scripts/`.
</gotcha>

<gotcha name="containers">
Integration tests need running containers. Check: `docker ps | grep "$TEST_CONTAINER" || just test-api-setup`.
</gotcha>

<gotcha name="dupe-phase-history-row" severity="high">
`pf handoff complete-phase` crashes with `ValueError: Invalid isoformat string: '-'` when the session's Phase History table has a duplicate phase row whose Started cell is `-`. sm-setup's setup→red transition can leave a second `red | - | - | -` placeholder row. Fix: delete the duplicate row, keep the one with the real ISO start timestamp, then re-run complete-phase.
</gotcha>

<gotcha name="missing-context-story-file" severity="high">
sm-setup may create `.session/{id}-session.md` but NOT `sprint/context/context-story-{id}.md`, so `pf validate context-story {id}` returns exit 2 and the TEA context-gate blocks RED. Do NOT auto-create it as TEA — relay back to SM to author it (validator only checks presence/bytes; model on a sibling `context-story-*.md`). Tracked by story 153-6.
</gotcha>

<gotcha name="dont-run-the-SUT-runner" severity="critical">
When the story is a bug IN `testing-runner` itself (e.g. 158-2/gh #53: it clobbers `.session/{STORY_ID}-session.md`), NEVER verify RED by spawning `testing-runner` with the active `STORY_ID` — it will reproduce the bug on your OWN live session and erase your assessment. Verify RED with a direct scoped `uv run pytest <one file> -q` (the `scoped-red-run` pattern) and test the durable helper contract + a static guard on the agent `.md` instead of driving the non-deterministic subagent. Log both as Design Deviations.
</gotcha>

<gotcha name="testing-runner-hallucinates-failure-reasons" severity="high">
The `testing-runner` subagent (haiku) can correctly report the VERDICT (e.g. "VALID RED — all 6 AssertionError, file collects clean") yet HALLUCINATE the per-test details: 160-18 it invented exception types (KeyError/FileNotFoundError/URLError) that were NOT what the test seams injected (ValueError/RuntimeError), and misquoted a regex subject pattern. For security/contract RED where the *reason* a test fails IS the deliverable (sanitization, info-leak, fail-loud), do NOT trust the spy's prose — confirm ground truth yourself with a direct scoped run: `python3 -m pytest src/pf/tests/test_X.py -p no:cacheprovider -rA 2>&1 | grep -E "FAILED|AssertionError|assert |message ="`. Branch-safe as long as you name the single file (only `test_git_utils.py` hijacks the branch). The spy is fine for "did N tests fail"; it is NOT a source of truth for "WHY each failed".
</gotcha>

<gotcha name="testing-runner-sources-deleted-scripts" severity="high">
`agents/testing-runner.md` (and `agents/README.md`, `scripts/test/README.md`) still `source` bash helpers `test-cache.sh` / `test-setup.sh` that have been DELETED — only README stubs remain. The silent `source` failure is exactly why the haiku agent improvises and clobbers the session. Don't trust the markdown's bash flow; the real test runner is `pf check` / `scripts/workflow/check.py`.
</gotcha>
