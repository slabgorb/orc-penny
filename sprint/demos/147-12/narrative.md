# Narrative

## Problem Statement
**Problem:** Running the "finish story" command would fail silently or throw false error warnings depending on how work was started and whether Jira was configured. Why it matters: developers lost trust in the tool — a story that was genuinely complete would appear broken at the finish line, forcing manual workarounds or confusion about whether work was actually done.

---

## What Changed
Think of the finish flow like checking out of a hotel. Before this fix, the system expected you to have already moved through every room on the way to the checkout desk. If you skipped a step — which the tool itself caused — checkout would fail.

**Two specific problems were fixed:**

1. **The status ladder was incomplete.** Stories live in one of several states: backlog → in progress → in review → done. The finish command only knew how to climb the last two rungs. But because the "start work" function never actually wrote "in progress" into the story file, stories stayed in "backlog." Finish would try to jump straight from backlog to done — which the system refused. Fix: the finish command now walks the full ladder automatically, no matter which rung you're on.

2. **Jira wasn't configured, but the tool complained like it was.** When Jira isn't set up (many projects don't use it), the tool would still try to sync with Jira, get nothing back, and then report "drift" — as if something was wrong. Fix: the tool now checks whether Jira is configured before attempting sync. If it isn't, it silently skips that step rather than flagging a false failure.

---

## Why This Approach
Both fixes were surgical — two small, targeted changes rather than a broader rewrite. That was intentional:

- **The backlog bridge** was added at the finish layer because that's where the symptom manifests. The deeper root cause (start_work never writing "in progress") is a separate problem — already logged for a future story. Fixing the symptom here prevents breakage now without touching unrelated logic.
- **The Jira skip** was added at the transition layer — the right place to ask "is Jira even in play here?" before attempting API calls. This matches the existing pattern for stories that have no Jira key at all, keeping the logic consistent.

The test suite (58 tests, all green) confirms both bugs are fixed and no existing behavior was broken.

---

## Before/After
| Scenario | Before | After |
|----------|--------|-------|
| Story in `backlog` status at finish time | `ERROR: cannot transition from backlog to done` — finish blocked | Finish walks `backlog → in_progress → in_review → done` automatically |
| Jira not configured | `drift: True` warning with remediation instructions — false alarm | Jira sync silently skipped; finish completes cleanly |
| Story in `in_progress` (normal Jira path) | Worked correctly | Unchanged — no regression |
| Story in `in_review` (Jira-enabled) | Worked correctly | Unchanged — no regression |
