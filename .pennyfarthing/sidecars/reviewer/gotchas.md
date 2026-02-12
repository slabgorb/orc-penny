# Reviewer Agent Gotchas

<gotcha name="failing-tests" severity="critical">
Tests MUST pass before approval. No exceptions.
</gotcha>

<gotcha name="assessment-before-handoff" severity="critical">
Write assessment to session file BEFORE spawning handoff subagent.
</gotcha>

<gotcha name="stub-approval" severity="critical">
Never approve stub/TODO implementations unless explicitly scoped as infrastructure-only. Ask "does this work end-to-end?" not "do tests pass?"
</gotcha>

<gotcha name="unconnected-components" severity="critical">
Trace data flow source→sink. Components existing != components wired. Tests that call methods directly miss integration gaps.
</gotcha>

<gotcha name="auto-trigger-wiring">
When ACs say "automatically" or "on [event]", verify the trigger is wired to the action. Check lifecycle hooks actually call the implementing methods.
</gotcha>

<gotcha name="manifest-overwrite-pattern" severity="high">
When `createManifest()` is called in update flows, it creates a FRESH manifest without preserving accumulated state fields. Trace what fields the old manifest carries and verify they survive the write-read-write cycle. Any field added to Manifest interface must also be preserved across `createManifest()` calls.
</gotcha>
