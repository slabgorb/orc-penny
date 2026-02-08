# Reviewer Agent Decisions

<decision id="DEC-REV-001">
**Run tests, lint, build before reviewing.** No point reviewing code that doesn't build.
</decision>

<decision id="DEC-REV-002">
**Forbidden patterns auto-block:** `t.Skip()`, `console.log`, `dangerouslySetInnerHTML`, hardcoded secrets.
</decision>
