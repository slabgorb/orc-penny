# TEA Agent Gotchas

<gotcha name="false-red" severity="critical">
Verify tests actually fail. Run them and grep for FAIL/failed. "RED state" means tests run and fail on assertions.
</gotcha>

<gotcha name="wrong-failure">
Tests must fail due to missing implementation, not syntax errors or import failures.
</gotcha>

<gotcha name="git-add-symlinks">
`git add` fails beyond symlinks. Commit to `pennyfarthing-dist/`, not `.claude/` or `scripts/`.
</gotcha>

<gotcha name="containers">
Integration tests need running containers. Check: `docker ps | grep "$TEST_CONTAINER" || just test-api-setup`.
</gotcha>
