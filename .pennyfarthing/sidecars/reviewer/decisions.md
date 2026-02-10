# Reviewer Agent Decisions

<decision id="DEC-REV-001">
**Run tests, lint, build before reviewing.** No point reviewing code that doesn't build.
</decision>

<decision id="DEC-REV-002">
**Forbidden patterns auto-block:** `t.Skip()`, `console.log`, `dangerouslySetInnerHTML`, hardcoded secrets.
</decision>

<decision id="DEC-REV-003">
**inspect.getsource() tests are MEDIUM severity, not blocking.** When tests use source code inspection to verify function wiring (e.g., "does X call Y?"), flag as medium — they verify text presence not execution path. Acceptable when behavioral testing requires external services or complex state setup that's disproportionate to the verification value.
</decision>
