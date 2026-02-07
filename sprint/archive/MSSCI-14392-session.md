# MSSCI-14392: Agent-level permission scoping

**Jira:** MSSCI-14392
**Epic:** epic-78 — Cyclist Permission System
**Points:** 3 | **Priority:** P1
**Workflow:** tdd
**Phase:** approved
**Repos:** pennyfarthing
**Branch:** feature/MSSCI-14392-agent-level-permission-scoping
**PR:** #705 - feat: agent-level permission scoping

## Summary

Thread agent identity through the full permission stack so grants can be scoped per-agent. Global grants (no agent) match any request; agent-scoped grants require exact agent match.

## Files Changed

- `packages/cyclist/src/settings-store.ts` — agent? on PermissionGrant, agent-aware checkGrant/addGrant/removeGrant
- `packages/cyclist/src/api/hook-request.ts` — agent threading through handler, broadcast, grant storage
- `packages/cyclist/src/public/components/ApprovalModal/index.tsx` — agent display in modal header
- `pennyfarthing_scripts/pretooluse_hook.py` — _resolve_agent() from .session/agents/{session_id}
- `packages/cyclist/tests/MSSCI-14321-hook-request-grant-integration.test.ts` — updated checkGrant assertions
- `packages/cyclist/tests/MSSCI-14392-agent-level-permission-scoping.test.ts` — 20 new tests
- `packages/cyclist/tests/MSSCI-14392-hook-request-agent.test.ts` — 10 new tests

## Review

**Verdict:** APPROVED by Reviewer
- 45/45 tests pass (30 new + 15 updated)
- 168 existing permission tests pass, 0 regressions
- All ACs covered
