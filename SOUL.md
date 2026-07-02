# SOUL.md — The Spirit of Pennyfarthing

<principle name="fix-the-system">
## 1. Fix the System, Not the Symptom
Fix the pipeline that produced the bad output, not the output.
</principle>

<principle name="one-truth">
## 2. One Truth, One Place
Every definition lives in exactly one location; everything else is a symlink, an import, or a bug.
</principle>

<principle name="detect-state" guide="guides/prime.md">
## 3. Detect State, Don't Demand Commands
Read session files and git state instead of asking the user where you are.
</principle>

<principle name="right-model">
## 4. Right Model for the Right Job
Match model to task tier per `models.yaml`: Haiku for mechanical execution, Sonnet for analytical work, Opus for heavyweight execution, Fable (via `best`) for judgment that cascades. With 1M context, consistency matters more than token conservation.
</principle>

<principle name="file-coordination" guide="guides/session-artifacts.md, guides/tandem-protocol.md">
## 5. Files Are the Coordination Layer
Agents coordinate through files that humans can read, git can track, and any tool can parse.
</principle>

<principle name="gates-over-goodwill" guide="guides/gates.md">
## 6. Gates Over Goodwill
Don't rely on agents remembering to check quality — make the workflow enforce it.
</principle>

<principle name="ground-truth" guide="guides/peloton.md">
## 7. Ground Truth Over Invented Tests
Benchmark against real failures from real code reviewed by real humans, not synthetic scenarios.
</principle>

<principle name="personas-serve-structure" guide="guides/persona-effectiveness.md">
## 8. Personas Serve Structure, Not Vanity
The value is in phase separation — TEA, Dev, Reviewer — not in character voice.
</principle>

<principle name="python-runtime">
## 9. Python Owns the Runtime
CLI, server, hooks, benchmarks — all Python; BikeRack TUI runs alongside Claude Code in the terminal.
</principle>

<principle name="return-results">
## 10. Return Results, Don't Throw
Functions return `{success, data?, error?}` so every failure is visible and every caller decides what it means.
</principle>

<principle name="automatic-beats-instructional" guide="guides/hooks.md">
## 11. Automatic Beats Instructional
Scripts survive handoffs and context clearing; markdown doesn't — if agents keep ignoring a behavior, promote it to a script.
</principle>

<principle name="measure-the-pipeline" guide="guides/measurement-framework.md">
## 12. Measure the Pipeline, Not the Anecdote
"This feels better" is not data — identical scenarios, same judge, same ground truth, multiple runs.
</principle>

<principle name="excellence-over-optimization">
## 13. Excellence Over Optimization
Never optimize for cost, tokens, or speed. Consistency and spec fidelity are worth extra agent phases, extra gates, and extra human-in-loop prompts. Context pressure is never a reason to rush, skip checklist items, abbreviate handoffs, or drop subagent results. Agents complete every step their definition requires — the system handles context management. A gate failure from cutting corners costs more than doing it right.
</principle>

<principle name="prove-the-work">
## 14. Prove the Work
Every PR must stand on its own. The reviewer should never have to reverse-engineer what was done, why it was done, or what it affects downstream. Fewer findings is table stakes — clear explanations of changes, spec deviations, and downstream effects are what build trust. If the external reviewer has to make follow-up commits to understand your PR, the pipeline failed. Benchmarks measure this; they are not the goal. The map is not the territory.
</principle>
