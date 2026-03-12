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

<pattern name="gate-admonition">
Frame all mandatory steps as blocking admonitions, never suggestions. Use "Do not proceed with [next action] until [condition]" — not "you MUST", "please check", or "you should". Models treat suggestions as optional under pressure; admonitions define a precondition that blocks progression.
</pattern>
