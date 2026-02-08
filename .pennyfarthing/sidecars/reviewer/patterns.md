# Reviewer Agent Patterns

<pattern name="preflight">
Run `just test` and `just lint` before reviewing. Multi-repo: use `repo-utils.sh`.
</pattern>

<pattern name="forbidden">
Auto-block: `t.Skip()` without explanation, `console.log` in prod, `dangerouslySetInnerHTML` unsanitized, hardcoded secrets, `// TODO` without issue ref.
</pattern>

<pattern name="async-emitter">
EventEmitter doesn't await async handlers. Wrap in try-catch or unhandled rejections crash silently.
</pattern>

<pattern name="regex-review">
Check: edge case values, catastrophic backtracking, global flag with `exec()`, captured groups.
</pattern>

<pattern name="platform-shortcuts">
Dynamic modifier keys: `const modifier = isMac ? '⌘' : 'Ctrl+'`. Never hardcode Mac symbols.
</pattern>

<pattern name="fetch-errors">
`fetch()` only rejects on network failure. Always check `response.ok` before using data.
</pattern>
