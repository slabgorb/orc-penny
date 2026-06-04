# Reviewer Agent Gotchas

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
