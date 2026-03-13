# Standalone: Enhance Architect spec-check with mismatch taxonomy

**Jira:** MSSCI-16432
**Points:** 2
**Priority:** P2
**Workflow:** standalone
**Status:** done
**Repos:** pennyfarthing
**Branch:** feat/MSSCI-16432-architect-spec-check
**PR:** 1393
**Started:** 2026-03-13
**Completed:** 2026-03-13

---

## Description

Upgraded the Architect's spec-check phase from a mechanical gate rubber-stamp to a 4-step substantive analysis process. Cherry-picked mismatch taxonomy, severity classification, and resolution recommendation patterns from the Spec Evolution and Reconciliation skill (mcpmarket.com).

**Changes:**
- Step 1: Run the gate (structural validation, unchanged)
- Step 2: Mismatch analysis with 4 categories (Missing/Extra/Different/Ambiguous) and severity/type/impact classification
- Step 3: Resolution recommendation (Update spec / Fix code / Clarify spec / Defer)
- Step 4: Structured Architect Assessment output format

## Files Changed

| File | Change |
|------|--------|
| `pennyfarthing-dist/agents/architect.md` | Expanded `<spec-check>` section from 9 lines to 63 lines |
