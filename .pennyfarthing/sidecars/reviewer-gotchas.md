
<gotcha name="deletion-story-existing-tests" severity="high">
When reviewing deletion stories, always diff the full test suite against develop baseline. Devs typically write new "absence" tests but forget to update existing tests that hardcode counts or reference the removed artifact. Run `git checkout develop && pnpm test` vs `pnpm test` on the feature branch to catch regressions.
</gotcha>
