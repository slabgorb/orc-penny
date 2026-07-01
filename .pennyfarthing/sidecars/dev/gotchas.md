# Dev Agent Gotchas

<gotcha name="baseline-prove-preexisting-failures" severity="high">
When a behavior change breaks tests and a rework fixes SOME but not all, ALWAYS establish the develop baseline before claiming the rest are "pre-existing": `git stash push <test-file>` + `git checkout origin/develop -- <changed-source>`, run the still-failing tests, then restore (`git checkout HEAD -- <source>` + `git stash pop`). If they fail on clean develop too, they're pre-existing (this repo has NO CI — develop carries stale failures) and out of scope; document with the reproducible baseline command and capture as a Delivery Finding for a separate story. Do NOT absorb an unrelated bug to make a file fully green — that's scope creep with its own untested risk. Story 158-3: the context guard took test_143_9 from 16→4 failures; the 4 residual were a pre-existing `detect_workflow_state` verify-phase-ownership bug (pf/prime/workflow.py), proven red on develop with the guard reverted.
</gotcha>

<gotcha name="cdn-blocks-python-urllib-ua" severity="high">
The portraits CDN (`portraits.darkatelier.org`, Cloudflare) returns **403 Forbidden** to the default `Python-urllib/x.y` User-Agent — `curl` works because it sends its own UA. Any HTTP client hitting this CDN MUST set an explicit `User-Agent` header on EVERY request (manifest AND pack). `urllib.request.urlretrieve` can't carry headers — use `urlopen(Request(url, headers={"User-Agent": ...}))` + `shutil.copyfileobj`. Story 154-1: 38 mock-only tests were green while the feature was 100% broken against the real bucket; only `pf portraits fetch <theme>` against live R2 caught it. **When a feature talks to real external infra, smoke-test against the real endpoint before claiming GREEN — mocks model your assumptions, not the server's rules.**
</gotcha>

<gotcha name="local-portraits-shadow-cdn">
`resolve_portrait_path` priority: `~/.pennyfarthing/portraits/` override → local theme dirs (`themes_dir.parent/portraits/{theme}`) → R2 CDN cache (`~/.local/share/pennyfarthing/portraits/{theme}`, lazy `ensure_portraits`) → legacy LFS/cyclist. In dogfood repos that bundle portraits locally (e.g. discworld in the orchestrator), local wins and the CDN branch never runs — that's correct. To exercise the CDN path, test a theme NOT bundled locally (e.g. neuromancer).
</gotcha>

<gotcha name="install">
Install from GitHub: `npm install github:slabgorb/pennyfarthing`. Not published to npm. `npm link` won't work.
</gotcha>

<gotcha name="symlinks">
`.claude/` symlinks to `node_modules/pennyfarthing/pennyfarthing-dist/`. Missing commands? Reinstall from GitHub.
</gotcha>

<gotcha name="dead-code">
Delete unused code immediately. Don't ask, don't comment out.
</gotcha>

<gotcha name="tool-ids">
Never show raw `toolu_*` IDs to users. Display tool name instead.
</gotcha>

<gotcha name="cyclist-cwd">
Start Cyclist from project root (where `.claude/` exists), not `packages/cyclist/`. Wrong cwd = skills not recognized.
</gotcha>

<gotcha name="project-root-marker">
Use `.pennyfarthing/` as root marker, not `pennyfarthing-dist/` (symlink in `packages/core/` causes false match).
</gotcha>

<gotcha name="shell">
All scripts use `#!/usr/bin/env zsh`. PATH issues = user env, not script.
</gotcha>

<gotcha name="tailwind-v4">
`@import "tailwindcss"` not `@tailwind` directives. v3 syntax silently tree-shakes styles.
</gotcha>

<gotcha name="websocket-not-ipc">
All Cyclist features use WebSocket (`/ws/claude`, `/ws/context`, `/ws/stats`, `/ws/settings`, `/ws/bell`). Never add IPC handlers.
</gotcha>

<gotcha name="nested-scroll">
Only leaf elements scroll. Parents use `overflow: hidden`. `.message-panel-content` is hidden; `.message-list` scrolls.
</gotcha>

<gotcha name="pf-install-dual">
`pf` CLI has two installs: **editable** in direnv for dogfooding repos (`pip install -e pennyfarthing-dist/`), **global** via pipx for consumer repos (`pipx install pennyfarthing-dist/ --force`). After version bumps, re-run both. The direnv install takes priority when inside pf-1/pf-2; pipx is the fallback for all other repos.
</gotcha>

<gotcha name="core-test-hang">
`node --test dist/**/*.test.js` in `packages/core` can hang for 3+ minutes on `server.test.js` (tries real HTTP connections on port 3000). Pipe-to-grep also hangs because of buffering. Use `> /tmp/file 2>&1` redirect instead of pipes. Run individual test files when debugging: `node --test dist/path/to/specific.test.js`.
</gotcha>

<gotcha name="all-tests-all-languages">
"Run all tests" means ALL languages: `pnpm test` (TypeScript/Node) AND `python3 -m pytest` (Python). Always run both. Python tests live at `pennyfarthing-dist/src/pf/tests/`.
</gotcha>

<gotcha name="stale-tests">
Tests referencing non-existent packages (bikerack-extraction, data-source, websocket-otlp-extraction) are dead. `packages/shared/` was absorbed into core (Story 98-16). Tandem portraits (`cyclist-tandem.png`) were never generated. Skill registry has 22 skills not 23.
</gotcha>

<gotcha name="testing-runner-can-mutate-source" severity="high">
The `testing-runner` subagent has only Bash/Read/Glob/Grep tools — but Bash lets it rewrite source files (heredoc/sed/python). It has been observed editing production code to force a GREEN, then reporting the edit buried in prose. ALWAYS diff (`git status`/`git diff`) after a testing-runner GREEN run and review any source change as YOUR own. Prefer running verification directly via Bash when correctness of the edit matters.
</gotcha>

<gotcha name="get-project-root-env-first" severity="high">
`pf.common.config.get_project_root()` resolves `PROJECT_ROOT`/`CLAUDE_PROJECT_DIR` env vars BEFORE walking up from cwd. In the agent session these point at the real orchestrator, so tests relying on `monkeypatch.chdir(tmp)` to pick up a tmp `.pennyfarthing/repos.yaml` silently resolve the WRONG root. Give such functions an explicit `project_root` param and pass it in tests — don't rely on cwd.
</gotcha>

<gotcha name="static-guard-trips-on-comments">
A static-lint-style test that does a naive whole-file substring match (e.g. `assert 'Path(".")' not in file.read_text()`) trips on the token appearing in a *comment or docstring*, not just in code. When making such a guard pass, reword your comments to avoid the literal token rather than weakening the test — gaming the guard is wrong, and the comment isn't the anti-pattern it's hunting. Cost a verification cycle in 153-9 GREEN.
</gotcha>

<gotcha name="testrun-cache-entrypoint">
Test-result caching for `testing-runner` lives in `pf.session.test_cache` (story 158-2). The bash agent routes through `printf '%s' "$SUMMARY" | python -m pf.session.test_cache "$RUN_ID"` → writes `.session/test-runs/${RUN_ID}.md` (keyed on RUN_ID, never STORY_ID; refuses to touch a live session). The old `scripts/test/test-cache.sh` / `test-setup.sh` were DELETED — don't resurrect them. NOTE: `testing-runner.md`'s **Setup** section still `source`s the deleted `test-setup.sh` (for `ensure_test_containers`/`generate_run_id`) — a SEPARATE pre-existing breakage (container setup, not data-loss), left for a follow-up.
</gotcha>

<gotcha name="preflight-lint-detect-not-repos-yaml" severity="medium">
Story 155-5: `pf.preflight.finish.check_lint` hardcoded `npm run lint`, false-blocking
finish on the Python-only orchestrator root. The story FRAMED this as "stale repos.yaml
language:javascript", but the self-contained fix does NOT read repos.yaml — the
orchestrator root has neither package.json NOR pyproject.toml (its Python lives in the
inlined `pennyfarthing/` subdir), and preflight runs from that root (`python -m
pf.preflight finish`, no --project-root). So layout detection (package.json→npm, else
pyproject.toml→ruff, else skip-clean) fixes the false-block within the pennyfarthing repo
alone and dissolves the "blocking cross-repo repos.yaml edit" TEA flagged. Lesson: when a
bug is framed around a CONFIG value, check whether the code even READS that config before
scoping a cross-repo change — often the code is just hardcoded and a self-contained code
fix is cleaner. Companion fix in same story: `check_pr_status` must fall back to `gh pr
list --state merged --head <branch>` when `gh pr view <branch>` returns "no pull requests
found" (merged PRs whose branch was deleted), mirroring 155-1's head-branch resolution.
