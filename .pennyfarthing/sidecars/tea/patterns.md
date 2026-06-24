# TEA Agent Patterns

<pattern name="exception-taxonomy-red">
When REDding a fail-loud fix around file reads, cover the FULL raisable taxonomy of the guarded call, not just the obvious malformed case: `Path.read_text()` raises (a) `yaml`-level parse errors AFTER decode, (b) `UnicodeDecodeError` (a ValueError — escapes `except OSError`!) via `write_bytes(b"caf\xe9 \xff\xfe")`, (c) `PermissionError` via `shard.chmod(0o000)` (guard with `skipif(os.geteuid()==0)` and restore perms in `finally` or tmp_path cleanup breaks), (d) FileNotFoundError (usually owned by a downstream exists()-gated warning — pin that it stays SILENT at the load layer). Story 160-4 round 1 covered only (a)+(d); Reviewer rejected on (b) — a regression where the narrowed catch crashed the whole fetch on develop-survivable input. Pin warning text by FILENAME pattern only + a negative ("not found" must not appear for present files); leave wording to Dev. Same lesson as Dev's narrowed-exception gotcha, from the test side: enumerate the taxonomy FIRST, in round 1.
</pattern>

<pattern name="cache-poison-selfheal-red">
To RED a "validate-on-cache-hit / self-heal" requirement (story 153-12: `portrait_cdn.fetch_portrait` must reject a poisoned stub on a cache hit and re-fetch): reuse the `FakeCDN` shape from `test_portrait_cdn_direct.py` (monkeypatch stdlib `urllib.request.urlopen` to serve `PNG_BYTES` for seeded keys, 404 the rest, record `.requested`). Then **pre-seed the cache path with a poisoned payload** (`b"version https://git-lfs…"` LFS pointer, or `b""`) via a `_seed(cache, theme, size, slug, data)` helper, and assert the END-TO-END outcome, not the predicate: (1) poisoned + CDN-has-it → `p.read_bytes() == PNG_BYTES` AND `cdn.requested` non-empty (network WAS hit despite the "hit"); (2) poisoned + dead CDN (`install_cdn(set())`) → `p is None` (the stub must NEVER be returned); (3) a *valid* `PNG_BYTES` cache entry + `urlopen=_boom` → still served offline (preservation guard — don't punish a healthy cache). Use the full 8-byte sig `b"\x89PNG\r\n\x1a\n"` for the valid fixture so it passes whether Dev checks 4 or 8 magic bytes — robust to the impl's exact predicate. For "self-heal is logged to debug output", assert via `caplog.at_level(logging.DEBUG)` that a record matches the slug or a keyword — this *forces* `logging` over `print` (lang-review #4) and is the spec. Log all three (green-guard, logging-mechanism, AC1 source-scan) as Design Deviations.
</pattern>

<pattern name="source-removal-red">
To RED a "delete this function + its call sites" AC robustly (153-12 AC1/AC2): pair a **behavioral** check with a **source-scan**. Behavioral: `assert not hasattr(module, "_fn")` (def gone) and `assert "param" not in inspect.signature(fn).parameters` (signature cleaned) and `CliRunner().invoke(cmd, ["--help"])` output lacks the flag. Source-scan: `assert "_fn" not in Path(module.__file__).read_text()` — this is the only cheap way to assert *call sites* (not just the def) are gone, which the AC usually demands ("both call sites gone"). hasattr alone passes if the def is deleted but a call site lingers (would only fail at runtime). When the removed function has existing direct tests (here `test_153_10_*` calls `_install_portraits`; `test_init_custom_agents.py` patches it), flag them as **blocking Delivery Findings** for Dev to delete during GREEN — don't edit them yourself in RED, but do NOT leave them silent or the suite errors at GREEN.
</pattern>

<pattern name="no-jira-call-guard">
To prove a code path makes NO Jira call (Jira-less project fallback, story 158-5/gh #48): drive `is_jira_enabled()` to False by monkeypatching `pf.common.config.load_pennyfarthing_config` → `{}` (NOT the predicate itself — this is robust to wherever the Dev imports it), `delenv` JIRA_PROJECT/JIRA_URL, redirect `pf.common.config.get_project_root` → tmp_path, and pin identity with `monkeypatch.setenv("JIRA_USER", ...)` (so `get_current_user_email()` resolves locally without a `git` shell-out). Then wrap the call in `patch("pf.jira.claim.get_client", side_effect=AssertionError("Jira must not be contacted"))` — a successful claim proves no Jira call; a wrong claim that reaches `check_availability()` → `get_client()` fails loudly on HEAD = clean RED for the right reason (root cause = Jira contacted), independent of the fix's internal naming. Pair with one explicit `patch("...get_client")` + `assert call_count == 0`. Mirror `test_jira_cli_disabled_gate.py`'s config-driven disable technique. Note: `pf jira claim` (jira/cli.py) already gates; the bug was `pf sprint story claim` (sprint/cli.py::story_claim → jira.claim.claim_issue) which had NO gate. `transition_story` already skips Jira for keyless stories (the `if jira_key:` guard), so the local fallback should reuse it, not reimplement.
</pattern>

<pattern name="ac-as-green-regression-guard">
When an AC is "behavior X is UNCHANGED" (a preservation requirement, not new behavior), its test is correctly GREEN on HEAD — don't force a spurious RED. Shape it as a guard that fails only if the fix over-applies (e.g. 158-5 AC3: with Jira enabled, claim must still route through `check_availability`; goes red only if Dev collapses both paths into local-only). Log it as a Design Deviation so the gate/Reviewer know the green test is intentional, and pair it with genuinely-RED AC1/AC2 tests.
</pattern>

<pattern name="red-state">
1. Read ACs from session. 2. Design tests per AC. 3. Write failing tests. 4. Verify they fail for the right reason (assertions, not imports).
</pattern>

<pattern name="assessment">
```
## TEA Assessment
**Tests:** X failing (RED state confirmed)
**Coverage:** All ACs covered
**Files:** path/to/test.ext (new)
```
</pattern>

<pattern name="placement">
Go: `internal/service/user_test.go` next to `user.go`. React: `Component.test.tsx` next to `Component.tsx`.
</pattern>

<pattern name="stub">
Create stubs that compile but throw `Error('not implemented')`. Tests fail on assertion, not import.
</pattern>

<pattern name="test-categories">
Variable resolution: single source, priority chain, standard vars, unresolved tracking, edge cases (type coercion, null, empty).
</pattern>

<pattern name="fake-cdn-hermetic">
Testing a download/CDN module (urllib): build a `FakeCDN` that monkeypatches the *stdlib* `urllib.request.urlopen` + `urlretrieve`, serving a **real** tar.gz pack (built on tmp_path) with a **real** sha256 in a fake manifest. Gives hermetic coverage of download → SHA-verify → extract → sentinel with no network and no real LFS assets. Age the 24h manifest rate-limit by monkeypatching `time.time` (controllable holder dict). Tell Dev in the stub docstring to keep network calls *qualified* (`urllib.request.urlopen`) so the stdlib monkeypatch intercepts. Used story 154-1.
</pattern>

<pattern name="rule-tests-beyond-ac">
For untrusted-input modules, add lang-review rule-enforcement tests the ACs don't mention: resource-leak (assert no leftover `*.tmp` after failure, rule #7) and unsafe-deserialization (a malicious `../escaped.png` tar member must not escape the extract dir, rule #8 — `tar.extractall(..., filter="data")`). These catch the bug *before* Dev copies a reference module verbatim. 154-1's #17 reference module had the traversal hole.
</pattern>

<pattern name="scoped-red-run">
Verify RED with a single-file scoped run, never the full suite (full suite leaks a `feature/test` checkout via test_git_utils.py): `cd pennyfarthing-dist && uv run pytest src/pf/tests/test_X.py -q`. `N failed in …` = all collected+failed (good RED); any `errored` = collection/fixture defect to fix before handoff.
</pattern>

<pattern name="gate-admonition">
Frame all mandatory steps as blocking admonitions, never suggestions. Use "Do not proceed with [next action] until [condition]" — not "you MUST", "please check", or "you should". Models treat suggestions as optional under pressure; admonitions define a precondition that blocks progression.
</pattern>

<pattern name="suite-side-effect-meta-test">
When the bug is a test *leaking* a side effect onto the real repo/filesystem (not a source defect), the source-level fix is often already in place — verify it first. The faithful RED test then has to observe the offending test's behavior, so write a **meta-test**: spawn `sys.executable -m pytest <abs path to offending file> -k <selector> -q` in a `subprocess` with `cwd=` and `PROJECT_ROOT=` pinned to a `tmp_path` sandbox repo (mimic enough of the real layout — e.g. a `develop` branch and a `.pennyfarthing/` marker — that the leak path actually fires), then assert the sandbox is unchanged (e.g. branch still `main`). Guard against false-green by asserting the inner run actually executed ("no tests ran" not in stdout). RED now / green once the offending test uses `tmp_path`. Pair it with a cheap **static guard** (`assert 'Path(".")' not in offending_file.read_text()`). Drives a test-hygiene fix WITHOUT forcing a spurious source guard. Story 153-9.
</pattern>

<pattern name="ac-already-satisfied">
Before writing RED tests, check whether the literal ACs already hold in source — if AC says "pin git calls to passed path / none rely on cwd" and every call already passes `cwd=path`, an AC-literal test is green-on-arrival and won't drive the fix. Reframe to the property that is actually broken (here: suite hermeticity), and log the gap as a Design Deviation so the Reviewer/Dev know the AC wording trails the real root cause. Story 153-9: real leak was `test_git_utils.py` feeding `Path(".")` (the live repo) into `create_feature_branches`; `should_create_branch(None)` is permissive for unknown repos, so a real checkout ran on cwd.
</pattern>

<pattern name="duplicate-resolver-one-truth-red">
When the bug is "function A computes X wrong" and a sister function B already computes X correctly (story 155-3/gh #28: `archive.py::archive_story` had its own regex resolver defaulting to `"unknown"` while `archive_epic.py::get_archive_path` — fixed in 151-1 — already does name→number→fail-loud), the systemic fix is consolidation (SOUL #2), so RED tests must be **fix-agnostic**: they must pass whether Dev fixes A inline OR delegates A→B. Anchor on a REAL mini-project, never monkeypatch a specific resolver: `monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))` reroutes EVERY root consumer (`get_project_root` honors `PROJECT_ROOT` as its highest-priority layer-1 source → so `load_sprint`, `get_story_by_id`, `get_archive_path` all follow), then write `sprint/current-sprint.yaml` (raw read by the resolver) + an inline epic with one `status: done` story (so `get_story_by_id` finds it via `get_all_stories`). Use `dry_run=True` to assert the resolved filename via the return message WITHOUT pre-creating the archive file (dry-run returns before the `archive_file.exists()` check) — pair it with a non-dry-run test that pre-creates `sprint-{n}-completed.yaml` and reproduces the LITERAL symptom ("Archive file not found: …/sprint-unknown-completed.yaml" → success False). For the fail-loud AC, accept EITHER a raised `ValueError` OR a returned `{success: False}` (try/except + return), leaving SOUL #10 vs raise to Dev — assert only the invariant ("unknown" never appears, never succeeds). Add a name-priority preservation guard (`jira_sprint_name` present + a *different* `number` → name token wins); it's green on HEAD AND post-fix, so log it as a Design Deviation (intentional green, per `ac-as-green-regression-guard`). Result: 3 red + 1 green, 0 errored.
</pattern>

<pattern name="markdown-gate-not-enforced">
Many pennyfarthing "gates" are markdown files run by a **haiku subagent** (`gates/*.md`), but the script-first handoff path (`resolve-gate → complete-phase → marker`) NEVER spawns that subagent. `resolve_gate` only reads workflow YAML and returns `status: ready` + metadata; `complete_phase`'s only mechanical checks are session-exists, an `## … Assessment` heading, and (for `approval`) the Subagent Results table. So any gate check not ALSO coded into `complete_phase` is advisory-only goodwill — the phase advances regardless. When a story is "gate X passes/blocks without doing its job", the fix is usually to promote the markdown check into a mechanical guard in `complete_phase` (SOUL #11). Test it by calling `complete_phase(story, wf, from, to, gate_type, project_root)` against a `tmp_path` project (just `.pennyfarthing/workflows/{wf}.yaml` + `.session/{id}-session.md` with an Assessment heading) and asserting `status == "error"` AND the persisted `**Phase:**` did NOT advance. Story 158-3: setup→red advanced with no `sprint/context/context-{epic,story}-*.md`; guard keyed on `gate_type == "sm_setup_exit"`, presence+non-empty (mirrors the gate's documented Fallback, NOT the full schema validator). Pair blocking tests with a scope guard (green→review must still pass with no context) so Dev doesn't over-apply.
</pattern>
