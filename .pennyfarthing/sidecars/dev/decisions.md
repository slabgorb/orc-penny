# Dev Agent Decisions

<decision id="ADR-001" status="accepted" date="2026-01-06">
**Cyclist uses Claude Code CLI subprocess, not Anthropic API.**
`claude -p --output-format stream-json` as subprocess. No API key needed. NDJSON stream parsing. Session resume via `--resume`.
</decision>

<decision id="ADR-002" status="proposed" date="2026-01-07">
**Consider adopting Claude Agent SDK message types.**
`claude-service.ts` hand-rolls types. SDK provides official `SDKSystemMessage`, `SDKAssistantMessage`, etc. Aligning prevents drift.
</decision>

<decision id="ADR-003" status="proposed" date="2026-01-07">
**Permission mode UI via canUseTool callback.**
Current: `--dangerously-skip-permissions`. SDK offers `canUseTool(toolName, input) => allow|deny` for per-tool approval modals.
</decision>
