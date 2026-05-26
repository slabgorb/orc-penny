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

<gotcha name="dupe-phase-history-row" severity="high">
`pf handoff complete-phase` crashes with `ValueError: Invalid isoformat string: '-'` when the session's Phase History table has a duplicate phase row whose Started cell is `-`. sm-setup's setup→red transition can leave a second `red | - | - | -` placeholder row. Fix: delete the duplicate row, keep the one with the real ISO start timestamp, then re-run complete-phase.
</gotcha>

<gotcha name="missing-context-story-file" severity="high">
sm-setup may create `.session/{id}-session.md` but NOT `sprint/context/context-story-{id}.md`, so `pf validate context-story {id}` returns exit 2 and the TEA context-gate blocks RED. Do NOT auto-create it as TEA — relay back to SM to author it (validator only checks presence/bytes; model on a sibling `context-story-*.md`). Tracked by story 153-6.
</gotcha>
