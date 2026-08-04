# PM Agent Gotchas

<gotcha name="scope-creep">
Write explicit "out of scope" section in ACs. Stories grow without it.
</gotcha>

<gotcha name="vague-acs">
Every story needs testable, checkable acceptance criteria. Vague = disagreements.
</gotcha>

<gotcha name="over-sizing">
Break stories until each is 1-3 points maximum. 5+ = decompose.
</gotcha>

<gotcha name="context-pollution">
PM reads epic/story docs only, not implementation details. Re-read sprint files at session start.
</gotcha>

<gotcha name="missing-tech-context">
Include file hints, component names, existing patterns when handing off to SM.
</gotcha>

<gotcha name="ambiguous-priority">
Stack-rank stories explicitly (P0, P1, P2). Multiple "high priority" = no priority.
</gotcha>

<gotcha name="analysis-paralysis">
Time-box research, then decide with available info.
</gotcha>

<gotcha name="sprint-rollover-ordering">
Archive done standalone stories BEFORE renaming the sprint — get_archive_path derives the archive filename from the CURRENT sprint name's last token at runtime. Renaming first mis-attributes archives to the new sprint.
</gotcha>

<gotcha name="sprint-name-last-token">
Sprint `name:` last token becomes the archive file id (sprint-{token}-completed.yaml). A prose-only name like 'frontier model changes' archives to sprint-changes-completed.yaml — always end the name with the YYWW number.
</gotcha>

<gotcha name="no-demote-command">
No CLI demotes an epic to future work. Procedure: `pf sprint epic add` a tail epic, `pf sprint story move` P3s into it, write an initiative-{slug}.yaml shard referencing the epic id, remove the id from current-sprint.yaml epics list. Promote reads initiative-*.yaml shards, not future.yaml.
</gotcha>
