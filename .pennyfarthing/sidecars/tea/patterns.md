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
