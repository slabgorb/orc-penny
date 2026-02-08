# SM Agent Decisions

<decision id="DEC-SM-001">
**Trivial stories (1-2 pts) skip TEA, go directly to Dev.** Quick fixes shouldn't wait for test design ceremony.
</decision>

<decision id="DEC-SM-002">
**Session file is authoritative for workflow state.** Single source of truth that survives agent restarts.
</decision>

<decision id="DEC-SM-005" date="2026-01">
**Sprint naming: `TO Sprint YYWW`** with `jira_sprint_id` and `jira_sprint_name`. Timeboxed by team calendar.
</decision>

<decision id="DEC-SM-007" date="2026-01">
**Archive completed stories to `sprint/archive/sprint-{YYWW}-completed.yaml`.** Keeps working file lean.
</decision>
