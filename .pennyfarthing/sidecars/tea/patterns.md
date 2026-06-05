# TEA Agent Patterns

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

<pattern name="markdown-gate-not-enforced">
Many pennyfarthing "gates" are markdown files run by a **haiku subagent** (`gates/*.md`), but the script-first handoff path (`resolve-gate → complete-phase → marker`) NEVER spawns that subagent. `resolve_gate` only reads workflow YAML and returns `status: ready` + metadata; `complete_phase`'s only mechanical checks are session-exists, an `## … Assessment` heading, and (for `approval`) the Subagent Results table. So any gate check not ALSO coded into `complete_phase` is advisory-only goodwill — the phase advances regardless. When a story is "gate X passes/blocks without doing its job", the fix is usually to promote the markdown check into a mechanical guard in `complete_phase` (SOUL #11). Test it by calling `complete_phase(story, wf, from, to, gate_type, project_root)` against a `tmp_path` project (just `.pennyfarthing/workflows/{wf}.yaml` + `.session/{id}-session.md` with an Assessment heading) and asserting `status == "error"` AND the persisted `**Phase:**` did NOT advance. Story 158-3: setup→red advanced with no `sprint/context/context-{epic,story}-*.md`; guard keyed on `gate_type == "sm_setup_exit"`, presence+non-empty (mirrors the gate's documented Fallback, NOT the full schema validator). Pair blocking tests with a scope guard (green→review must still pass with no context) so Dev doesn't over-apply.
</pattern>
