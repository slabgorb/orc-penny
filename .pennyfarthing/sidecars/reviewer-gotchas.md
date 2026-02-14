
<gotcha name="deletion-story-existing-tests" severity="high">
When reviewing deletion stories, always diff the full test suite against develop baseline. Devs typically write new "absence" tests but forget to update existing tests that hardcode counts or reference the removed artifact. Run `git checkout develop && pnpm test` vs `pnpm test` on the feature branch to catch regressions.
</gotcha>

<gotcha name="copy-vs-move-verification" severity="critical">
When a story says "move X from A to B", verify that A was actually modified to import from B. Check `git diff --name-status -- packages/A/` — if zero files changed in the source package, the code was copied, not moved. Tests that only check exports (typeof checks) won't catch this — they pass with stubs. Always verify the consumer side of the move.
</gotcha>

<gotcha name="stub-security-implications" severity="high">
When stubs replace security-sensitive modules (e.g., `isDangerousPath` always returning false, `detectPennyfarthingProject` always returning true), flag as HIGH even if tests pass. Stubs that disable security gates are worse than stubs that return empty data — they create a false sense of safety.
</gotcha>
