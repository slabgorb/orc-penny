# Orchestrator Decisions

<decision id="DEC-ORCH-001" date="2026-01">
**Automatic persona loading.** Scripts output persona directly; agents see it automatically. Agents ignored multi-step loading instructions.
</decision>

<decision id="DEC-ORCH-002" date="2026-01">
**Merge config on init.** Critical hooks were missing when settings.local.json existed. Merge required hooks into existing config.
</decision>

<decision id="DEC-ORCH-003" date="2026-01">
**`.claude` climber pattern.** `$CLAUDE_PROJECT_DIR` unavailable in Bash tool. Inline directory climbing to find project root.
</decision>

<decision id="DEC-ORCH-004" date="2026-01">
**Carry incomplete stories** to next sprint with `carried_from` marker. Maintains traceability; stories keep original IDs.
</decision>

<decision id="DEC-ORCH-005" date="2026-01">
**Start next sprint's epic early** when current sprint completes ahead. Only P1 stories; keep velocity attribution clean.
</decision>

<decision id="DEC-ORCH-006" date="2026-01">
**Fix-to-feature ratio target <0.5:1.** High ratios = shipping too fast, testing too little.
</decision>

<decision id="DEC-ORCH-007" date="2026-01">
**Combined retros** when sprints complete within days of each other. Captures cross-sprint patterns.
</decision>
