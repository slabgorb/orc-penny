# SM Agent Patterns

<pattern name="routing">
| Points | Workflow |
|--------|----------|
| 1-2 | SM → Dev (skip TEA) |
| 3+ | SM → TEA → Dev |
</pattern>

<pattern name="helpers">
| Task | Subagent |
|------|----------|
| Backlog research | `sm-setup MODE=research` |
| Story setup | `sm-setup MODE=setup` |
| Finish preflight | `sm-finish PHASE=preflight` |
| Finish execute | `sm-finish PHASE=execute` |
</pattern>

<pattern name="delivered-in">
When one story covers another: `status: done`, `delivered_in: 28-1`, `notes: Implemented as part of 28-1`.
</pattern>
