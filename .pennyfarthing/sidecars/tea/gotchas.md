# TEA Agent Gotchas

<gotcha name="false-red" severity="critical">
Verify tests actually fail. Run them and grep for FAIL/failed. "RED state" means tests run and fail on assertions.
</gotcha>

<gotcha name="fail-loud-swallow-hides-constant-bug" severity="high">
On a fail-loud sweep story ("add warnings.warn to a silent except"), ALWAYS drive the
real code path first — a silent `except` very often masks a CONSTANT bug (the try-body
is 100% broken, not occasionally). Seen 160-15, 160-17 round-2, and 160-19:
`get_context` did `ContextConfig(project_dir=...)` — a field that doesn't exist — so it
raised `TypeError` on EVERY request and the swallow returned all-None silently;
`/api/context` never showed real data. A warn-ONLY fix over a constant bug makes the
warning fire every request (warn-spam) — the exact blocking defect 160-17 round-2 was
rejected for. So the story's REAL scope includes fixing the constant bug, so the warn is
reserved for genuine failures (SOUL #1). TEST TECHNIQUE that forces both: (1) monkeypatch
the seam to RETURN a healthy result and assert the real values reach the body + NO warn
fires — RED today (constant bug short-circuits before the seam) and RED on a naive
warn-only fix (it warns on a healthy call); (2) a `pytest.warns` test with the seam
raising, for the genuine-exception path; (3) optionally a real-wiring test patching a
deeper seam (e.g. `context_window.find_transcript`→None) to assert a graceful sentinel,
not a crash string. Confirm the constant bug with a 3-line `python3 -c` driving the live
route BEFORE designing tests. Log it as a blocking Delivery Finding + a scope-expansion
Design Deviation.
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

<gotcha name="preflight-lint-hardcodes-npm-not-repos-yaml" severity="high">
Story 155-5: the "stale repos.yaml language:javascript DRIVES npm lint" framing is
inaccurate — `pf.preflight.finish.check_lint` never reads repos.yaml at all; it
hardcodes `asyncio.create_subprocess_exec("npm","run","lint")` regardless of
language. So the code fix is "make check_lint language-aware" (reuse
`scripts/workflow/check.py::detect_project_type` / `repo_config.lint_cmd`), and it
lives in the pennyfarthing repo. The repos.yaml `language: python` config edit is a
SEPARATE concern in the ORCHESTRATOR repo at `.pennyfarthing/repos.yaml` — a REAL
file, NOT a symlink to pennyfarthing-dist (story context lied about "trace the
symlink"). AC split across two repos → flag as blocking Delivery Finding + minor
Design Deviation (framework pytest can only test the code half). TEST TECHNIQUE for
async subprocess dispatch: patch BOTH `asyncio.create_subprocess_exec` AND
`create_subprocess_shell` (robust to exec-vs-shell); assert on the captured command
tokens ("npm" not run on a Python project) AND the outcome (`LintResult.clean` True
when the Python linter passes). Always pair the RED with an over-reach guard (Node
project must STILL npm-lint; genuinely-missing PR must STILL block) so the fix can't
cheat by flipping the default.
</gotcha>

<gotcha name="testing-runner-sources-deleted-scripts" severity="high">
`agents/testing-runner.md` (and `agents/README.md`, `scripts/test/README.md`) still `source` bash helpers `test-cache.sh` / `test-setup.sh` that have been DELETED — only README stubs remain. The silent `source` failure is exactly why the haiku agent improvises and clobbers the session. Don't trust the markdown's bash flow; the real test runner is `pf check` / `scripts/workflow/check.py`.
</gotcha>
