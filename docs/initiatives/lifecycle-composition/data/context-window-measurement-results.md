---
bibliography: ../../../../references.bib
csl: chicago-author-date.csl
---

# Context Window Measurement Results

**Procedure:** `context-window-measurement-procedure.md`
**Date:** 2026-02-15
**Measured by:** Michael Pursifull
**Model:** `claude-opus-4-6` (200K context window)

---

## Raw Measurements

All measurements taken following the standard procedure: clean session, load PM persona, read PRD + architecture + epics + stories, then `/context`.

### BMAD Projects

| Metric | consumer-project | ccmp | peu |
|--------|----------|------|-----|
| **Framework** | BMAD | BMAD | BMAD |
| **Phase** | Pre-launch (pre-code) | ~1/8 to delivery | Mature (v2.x) |
| **Epics** | 25 | 7 | 14 (10 lost in v4→v6) |
| **Stories** | 268 | 51 | 40+ (11 exist in v4→v6) |
| **Team size** | 1 | 1 | 1 |
| **Total used** | **162K (81%)** | **73K (36%)** | **36K (18%)** |
| System prompt | 3.0K (1.5%) | 3.1K (1.5%) | 3.1K (1.5%) |
| System tools | 15.1K (7.5%) | 15.3K (7.7%) | 15.1K (7.5%) |
| Memory files | 3.6K (1.8%) | 0.5K (0.2%) | 6.4K (3.2%) |
| Skills | 1.5K (0.8%) | 1.6K (0.8%) | 1.5K (0.8%) |
| Messages | 139.7K (69.8%) | 51.8K (25.9%) | 10.7K (5.4%) |
| Free space | 4K (2.0%) | 95K (47.4%) | 130K (65.1%) |
| Autocompact buffer | 33K (16.5%) | 33K (16.5%) | 33K (16.5%) |

### Pennyfarthing Projects

| Metric | poller-orchestrator | bmad-community |
|--------|---------------------|----------------|
| **Framework** | Pennyfarthing | Pennyfarthing |
| **Phase** | Pre-epic planning (research spike) | Active development |
| **Epics** | 1 (5 research tracks) | 7 |
| **Stories** | 20 | 49 |
| **Team size** | 1 | 1 |
| **Total used** | **92K (46%)** | **88K (44%)** |
| System prompt | 3.1K (1.5%) | 3.0K (1.5%) |
| System tools | 13.5K (6.7%) | 13.5K (6.7%) |
| Memory files | 1.6K (0.8%) | 1.7K (0.8%) |
| Skills | 3.1K (1.6%) | 3.1K (1.6%) |
| Messages | 72.2K (36.1%) | 67.3K (33.7%) |
| Free space | 74K (36.8%) | 78K (39.2%) |
| Autocompact buffer | 33K (16.5%) | 33K (16.5%) |

---

## Derived Metrics

**Effective capacity:** 167K (200K window - 33K autocompact buffer)

### Fixed Overhead (System Prompt + Tools + Memory + Skills)

| Project | Framework | Fixed Overhead | % of Effective Capacity |
|---------|-----------|---------------|------------------------|
| consumer-project | BMAD | 23.2K | 13.9% |
| ccmp | BMAD | 20.5K | 12.3% |
| peu | BMAD | 26.1K | 15.6% |
| poller | Pennyfarthing | 21.3K | 12.8% |
| bmad-community | Pennyfarthing | 21.3K | 12.8% |

**Observation:** Fixed overhead is roughly constant across all projects (~20-26K, 12-16% of effective capacity). The variance comes from Memory files (peu has a large CLAUDE.md at 5.9K) and tool registration differences between BMAD (~15K tools) and Pennyfarthing (~13.5K tools + ~3.1K skills).

### Project Content (Messages)

| Project | Framework | Epics | Stories | Project Content | Content/Story | Content/Epic |
|---------|-----------|-------|---------|----------------|---------------|-------------|
| consumer-project | BMAD | 25 | 268 | 139.7K | 521 | 5,588 |
| ccmp | BMAD | 7 | 51 | 51.8K | 1,016 | 7,400 |
| peu | BMAD | 14 | 11 | 10.7K | 973 | 764 |
| poller | Pennyfarthing | 1 | 20 | 72.2K | 3,610 | 72,200 |
| bmad-community | Pennyfarthing | 7 | 49 | 67.3K | 1,373 | 9,614 |

**Observations:**

1. **consumer-project has the lowest per-story cost (521 tokens/story)** because its 268 story definitions are terse and templated. But the sheer count overwhelms the window.
2. **poller has the highest per-story cost (3,610 tokens/story)** because it has substantial research documents (spike findings, charter) loaded alongside relatively few stories. Document depth drives context, not just count.
3. **Content per epic varies by 94x** (764 to 72,200), confirming that raw artifact counts are poor predictors. Document density and depth matter.
4. **The base documents (PRD + architecture) are a large fixed cost.** Even peu, with minimal stories, consumes 10.7K in project content — most of which is PRD and architecture, not stories.

### Effective Utilization

| Project | Framework | Total Used | Effective Capacity | **Effective Utilization** | Remaining for Work | Above 100K Ceiling? |
|---------|-----------|------------|-------------------|--------------------------|--------------------|--------------------|
| consumer-project | BMAD | 162K | 167K | **97.0%** | **5K (3.0%)** | **YES (+62K)** |
| poller | Pennyfarthing | 92K | 167K | **55.1%** | 75K (44.9%) | No (-8K under) |
| bmad-community | Pennyfarthing | 88K | 167K | **52.7%** | 79K (47.3%) | No (-12K under) |
| ccmp | BMAD | 73K | 167K | **43.7%** | 94K (56.3%) | No (-27K under) |
| peu | BMAD | 36K | 167K | **21.6%** | 131K (78.4%) | No (-64K under) |

**Critical finding:** consumer-project — a BMAD project with 25 epics and 268 stories, before a single line of code is written — consumes 97% of effective capacity just loading project state. The PM agent literally cannot do useful work. This is not a theoretical projection; it is a measured fact.

---

## Apples-to-Apples Comparisons

### Same Scale: ccmp (BMAD) vs bmad-community (Pennyfarthing)

| Metric | ccmp (BMAD) | bmad-community (PF) | Difference |
|--------|-------------|---------------------|------------|
| Epics | 7 | 7 | Same |
| Stories | 51 | 49 | ~Same |
| Total used | 73K (36%) | 88K (44%) | PF +15K |
| Fixed overhead | 20.5K | 21.3K | PF +0.8K |
| Project content | 51.8K | 67.3K | PF +15.5K |
| Free space | 95K | 78K | BMAD +17K |

**At comparable scale (7 epics, ~50 stories), Pennyfarthing actually uses MORE context than BMAD** in this full-load test. This is because:

1. Pennyfarthing's project artifacts are denser (sharded YAML with rich metadata vs. flat markdown)
2. Pennyfarthing's CLAUDE.md and framework structure add context BMAD doesn't have
3. The PM persona in Pennyfarthing loads more framework documentation

**But this misses the point.** In actual Pennyfarthing use, the PM never loads all 49 stories at once. Prime tiers, sprint sharding, and session extraction keep the per-session load fraction. The full-load test measures the *total project footprint*, not the *per-session footprint*. For BMAD, the full-load IS the per-session footprint — there's no selective loading.

### The Scale Problem: consumer-project Breaks BMAD

| Metric | ccmp (BMAD, 7 epics) | consumer-project (BMAD, 25 epics) | Growth Factor |
|--------|----------------------|--------------------------|---------------|
| Epics | 7 | 25 | 3.6x |
| Stories | 51 | 268 | 5.3x |
| Project content | 51.8K | 139.7K | 2.7x |
| Total used | 73K | 162K | 2.2x |
| Free space | 95K | 4K | **0.04x** |
| Effective utilization | 43.7% | 97.0% | 2.2x |

Going from 7 to 25 epics (3.6x) and 51 to 268 stories (5.3x), free space collapses from 95K to 4K — a **96% reduction**. The PM cannot plan, cannot re-integrate, cannot do any meaningful work.

---

## Framework Overhead Comparison

### System Tool Registration

| Category | BMAD | Pennyfarthing | Delta |
|----------|------|---------------|-------|
| System tools | ~15.1-15.3K | ~13.5K | BMAD +1.7K |
| Skills | ~1.5-1.6K | ~3.1K | PF +1.5K |
| **Total tool overhead** | **~16.7K** | **~16.6K** | **~Equal** |

Despite different architectures (BMAD loads more built-in tools; Pennyfarthing loads fewer tools but more deferred skills), total tool overhead is nearly identical.

### Memory Files

| Project | Framework | Memory Files |
|---------|-----------|-------------|
| consumer-project | BMAD | 3.6K (CLAUDE.md + global) |
| ccmp | BMAD | 0.5K (global only) |
| peu | BMAD | 6.4K (large CLAUDE.md) |
| poller | Pennyfarthing | 1.6K (CLAUDE.md + global) |
| bmad-community | Pennyfarthing | 1.7K (CLAUDE.md + global) |

Memory file overhead varies by project configuration, not framework. peu's 6.4K CLAUDE.md is an outlier.

---

## Key Observations

### 1. The Central Organizer Cannot Function at Scale

The consumer-project measurement proves the core argument: a PM/SM agent that needs the full project picture — all epics, all stories, the PRD, the architecture — cannot fit it in the context window for a project of even moderate size (25 epics). This agent role exists in both BMAD and Pennyfarthing. Without selective retrieval, the central organizer hits a hard wall.

### 2. The Problem Is Document Volume, Not Framework Overhead

Fixed overhead (system prompt + tools + memory + skills) accounts for only 12-16% of effective capacity across all projects. The remaining 84-88% is either project content or free space. The problem is not that the frameworks are bloated — it's that the project artifacts themselves grow without bound and both frameworks load all of them.

### 3. Pennyfarthing's Sharding Doesn't Help in Full-Load Scenarios

When measuring the total project footprint (this procedure), Pennyfarthing's sharding provides no benefit — it may even cost slightly more due to metadata overhead. The benefit of sharding appears in *routine use*, where agents load only the shards relevant to their current task. This test measures the floor; routine use measures the ceiling of what sharding can save.

### 4. Both Frameworks Require RAG, Reranking, and Graph Support

With even modest projects consuming 36-92% of effective capacity at session start, and a 25-epic project consuming 97%, the trajectory is clear. Projects will only grow. Stories will accumulate. Research will compound. Neither framework has a mechanism to scale context loading sublinearly with project size. All current approaches are O(n) — load everything, every time. The path to O(log n) or O(1) context loading requires:

- **RAG** — semantic search over project artifacts for selective retrieval
- **Reranking** — prioritize retrieved context by task relevance
- **Knowledge graphs** — relationship-aware traversal for dependency chains

These are not enhancements. They are architectural prerequisites for continued operation as projects grow beyond the current 5-10 epic comfort zone.

### 5. The Performance Ceiling Makes the Problem Worse Than It Looks

Research shows LLM performance degrades at ~50% of context window capacity [@an_etal_2024; @hsieh_etal_2024]. For a 200K window, the effective performance ceiling is ~100K. Three of five tested projects (consumer-project, poller, bmad-community) are at or near this ceiling at session start — before any work begins. The agent is already impaired before it writes a line of code or makes a planning decision.

---

## Chart Plan for lifecycle-improvement-rs.md

### Chart 1 (REPLACE existing hypothetical chart): Measured Context at Session Start

Replace the current chart (which uses projected values) with actual measured data.

**Type:** xychart-beta bar chart
**X-axis:** Total stories [11, 20, 49, 51, 268]
**Bars:** Total context used [36, 92, 88, 73, 162] (K tokens)
**Lines:** 100K (performance ceiling), 167K (effective capacity)
**Labels:** Annotate each bar with project name and framework (B=BMAD, P=Pennyfarthing)
**Caption:** "Measured context window usage at session start across five projects. B = BMAD, P = Pennyfarthing. Procedure: load PM, read PRD + architecture + all epics + all stories. Zero implementation work. Two projects are near or above the 100K performance ceiling before any work begins."

**Problem:** xychart-beta x-axis with story counts [11, 20, 49, 51, 268] will space disproportionately. Alternative: use categorical labels or a numbered index [1, 2, 3, 4, 5] with caption identifying projects.

### Chart 2 (NEW): Context Composition Breakdown

Show what makes up the context for each project — fixed overhead vs project content vs free space.

**Type:** xychart-beta (stacked bars not supported — use grouped or describe in table)
**Alternative:** Render as a table with visual bar indicators, or as multiple bar series.
**Data:**

| Project | Fixed Overhead (K) | Project Content (K) | Free Space (K) | Reserved (K) |
|---------|-------------------|--------------------|--------------------|---|
| peu (B) | 26 | 11 | 130 | 33 |
| ccmp (B) | 21 | 52 | 95 | 33 |
| bmad-comm (P) | 21 | 67 | 78 | 33 |
| poller (P) | 21 | 72 | 74 | 33 |
| consumer-project (B) | 23 | 140 | 4 | 33 |

**Key message:** Fixed overhead is roughly constant; project content is what drives the budget collapse.

### Chart 3 (KEEP with annotation): Context Growth Over Time

The existing sprint-over-time chart (hypothetical) should be kept but annotated to note that empirical data shows the starting point is already higher than the chart assumed. The chart projected 40K at sprint 1 for a 15-epic project; measured data shows ccmp (7 epics, partly built) is already at 73K.

### Chart 4 (NEW): Effective Utilization Gauge

Simple bar chart showing % of effective capacity (167K) consumed before work begins.

**Type:** xychart-beta horizontal bars (if supported) or vertical
**X-axis:** Projects
**Y-axis:** % of effective capacity
**Bars:** [22, 44, 53, 55, 97]
**Line:** 60% (performance ceiling as % of effective = 100K/167K)
**Caption:** "Percentage of effective context capacity consumed before any implementation work. The 60% line marks the performance ceiling (100K of 167K effective tokens). consumer-project is at 97% — the agent cannot function."

### Chart 5 (REPLACE existing team-size chart): Team Size Projection

The team-size chart should note it remains projected (no multi-developer measurements yet) but now anchored to the measured single-developer baselines. If ccmp is 73K with 1 developer, the 2-developer projection starts from 73K + coordination overhead, not from a hypothetical.

---

## Next Steps

1. Gather additional data points — measure more BMAD and Pennyfarthing projects at various scales
2. Measure per-session footprint (not full-load) for Pennyfarthing projects to quantify sharding benefit
3. Measure context after N stories of work to validate the growth-over-time projection
4. Update -rs.md charts with measured data per chart plan above

## References

::: {#refs}
:::
