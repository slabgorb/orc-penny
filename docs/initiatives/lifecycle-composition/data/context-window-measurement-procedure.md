---
bibliography: ../../../../references.bib
csl: chicago-author-date.csl
---

# Context Window Measurement Procedure

**Purpose:** Establish a repeatable methodology for measuring context window consumption at project session start, to ground the lifecycle improvement brief's context scaling arguments in empirical data.

**Date:** 2026-02-15
**Author:** Michael Pursifull

---

## Objective

Measure how much of a 200K-token context window is consumed by loading core project state (PRD, architecture, epics, stories) before any implementation work begins. This establishes the **context-to-first-useful-turn** baseline for each project.

## Environment

| Parameter | Value |
|-----------|-------|
| Model | `claude-opus-4-6` |
| Context window | 200,000 tokens |
| Autocompact buffer | 33,000 tokens (reserved by Claude Code) |
| **Effective capacity** | **167,000 tokens** (200K - 33K) |
| Platform | macOS (Darwin 25.1.0) |
| Tool | Claude Code CLI v2.1.x |

## Procedure

### Step 1: Clean Start

```bash
cd <project-root>
git checkout main
git pull origin main
```

Ensure no uncommitted changes, no stale session state.

### Step 2: New Claude Code Session

Start a fresh Claude Code session. Do not resume a previous conversation.

```bash
claude
```

### Step 3: Load PM Persona

For **BMAD projects**: The PM persona is part of the BMAD agent system. Load it according to the project's convention (typically an initial prompt or persona file).

For **Pennyfarthing projects**: Load the PM agent.

```
/pm
```

### Step 4: Read Core Project Artifacts

Issue the following prompt exactly:

```
Read the PRD, architecture, epics and stories. How many total epics and how many total stories?
```

This prompt causes the agent to:
1. Read the PRD document
2. Read the architecture document
3. Read all epic definitions
4. Read all story definitions
5. Report counts

Wait for the agent to complete its response.

### Step 5: Capture Context Usage

Run the `/context` command in Claude Code:

```
/context
```

### Step 6: Record Results

Record the following from the `/context` output:

| Field | Where to Find |
|-------|---------------|
| Total used / Total available | Top line (e.g., "92K/200K tokens (46%)") |
| System prompt | "System prompt" line |
| System tools | "System tools" line |
| Memory files | "Memory files" line |
| Skills | "Skills" line |
| Messages | "Messages" line |
| Free space | "Free space" line |
| Autocompact buffer | "Autocompact buffer" line |

Also record from the agent's response:
- Total epics reported
- Total stories reported

And from project knowledge:
- Framework (BMAD or Pennyfarthing)
- Project phase (pre-code, early, mid, mature)
- Team size

## Derived Metrics

Calculate these from the raw measurements:

| Metric | Formula |
|--------|---------|
| **Effective capacity** | 200K - autocompact buffer |
| **Fixed overhead** | System prompt + System tools + Memory files + Skills |
| **Project content** | Messages (includes prompt text + all loaded documents) |
| **Effective utilization** | (Fixed overhead + Project content) / Effective capacity |
| **Remaining for work** | Effective capacity - Fixed overhead - Project content |
| **Content per story** | Project content / Total stories |
| **Content per epic** | Project content / Total epics |
| **Above performance ceiling** | Total used > 100K (50% of 200K) |
| **Above effective ceiling** | Total used > 167K (effective capacity) |

## Notes and Limitations

1. **"Messages" is an approximation of project content.** It includes the prompt text, the agent's enumeration response, and all loaded documents. The actual project content is slightly less than the Messages value (subtract ~500-1000 tokens for prompt/response overhead).

2. **The prompt loads everything.** In normal Pennyfarthing use, agents load selectively via Prime tiers. This procedure deliberately loads all artifacts to measure the full project footprint — the worst-case scenario that a central organizer (PM, SM) faces when planning or re-integrating.

3. **The autocompact buffer is non-negotiable.** Claude Code reserves 33K tokens for conversation management. This is not configurable and reduces effective capacity from 200K to 167K.

4. **Different project content density.** A project with a 40-page PRD will consume more context than one with a 2-page PRD, independent of epic/story count. Content density varies by project maturity and documentation style.

5. **Framework overhead differs.** BMAD and Pennyfarthing load different system tools and skills. The fixed overhead is roughly comparable (~20-26K) but not identical.

## References

::: {#refs}
:::
