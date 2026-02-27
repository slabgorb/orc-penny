# Workflow Session: architecture

**Workflow:** architecture
**Type:** stepped
**Agent:** architect
**Started:** 2026-02-27T11:00:51Z

## Workflow State
- **Workflow Name:** architecture
- **Type:** stepped
- **Mode:** create
- **Started:** 2026-02-27T11:00:51Z
- **Last Updated:** 2026-02-27T11:19:16Z
- **Current Step:** 9
- **Steps Completed:** [1, 2, 3, 4, 5, 6, 7, 8]
- **Status:** completed
- **Notes:** Session created via pf workflow start

## Progress
- Total Steps: 8
- Completion: 100%

---

## Architecture Session: Story Session Feedback System

### PRD
- **Source:** `sprint/planning/session-feedback-prd.md`
- **Validation:** `sprint/planning/session-feedback-prd-validation.md` — 4/5, 0 critical, 3 warnings
- **Author:** Lady Jessica (PM Agent), 2026-02-23
- **Phases:** Phase 1 (Impact Summary), Phase 2 (Delivery Findings), Growth (Aggregation)

### Inputs Gathered
- PRD: `sprint/planning/session-feedback-prd.md` (validated, 4/5)
- Tier Model: `docs/lifecycle-tier-work-products.md` — defines Delivery Finding artifact (lines 228-248)
- Session Artifacts Guide: `pennyfarthing/pennyfarthing-dist/guides/session-artifacts.md`
- SM Finish Subagent: `pennyfarthing/pennyfarthing-dist/agents/sm-finish.md`
- SM Setup Subagent: `pennyfarthing/pennyfarthing-dist/agents/sm-setup.md`
- Example Session: `sprint/archive/MSSCI-15033-session.md` (MSSCI-15033, 5-point story)
- Existing ADRs: 30 on record (ADR-0001 through ADR-0030)

### Constraints
- Session files are markdown with structured sections, not YAML frontmatter
- `sm-finish` is currently a preflight-only subagent (PR check, lint, Jira, ACs)
- Agents already write structured assessments (TEA, Dev, Reviewer)
- Session archive workflow copies full session to `sprint/archive/`
- Backward compatibility required — existing sessions must continue to parse

### Stakeholders
- Decision maker: Keith (the boss)
- Affected agents: SM (finish), TEA, Dev, Reviewer
- Affected artifacts: session files, sm-finish subagent, agent definitions, session-artifacts guide

---

## Architecture Context

### Technical Constraints

**Performance:**
- Impact Summary generation: < 30 seconds (PRD NFR1)
- Finding entry by agent: < 5 seconds (structured template fill)
- Sprint aggregation: < 10 seconds for 20 stories

**Backward Compatibility:**
- Existing sessions (~90+ archived) MUST continue to parse
- `story_finish.py` uses regex-based `_parse_session()` — only extracts `**Key:** Value` fields
- `migration/session.py` has full markdown→XML parser with section awareness
- New sections are additive — low risk if placed correctly

**Schema:**
- Sessions are markdown with `**Key:** Value` field patterns (no YAML frontmatter)
- YAML code blocks within markdown = new convention (parseable, but novel for this system)
- `SESSION_FIELD_RE` in `story_finish.py` only matches `**Word:** Value` — won't conflict

**Agent Model:**
- `sm-finish` is a Haiku subagent — lightweight, preflight-only today
- TEA, Dev, Reviewer each write free-text assessments to session files before exit
- Assessment templates are markdown with `**Key:** Value` fields, not YAML

### Current Landscape

**Session File Flow:**
```
sm-setup creates → agents write assessments → sm-finish runs preflight → story_finish.py archives
```

**Existing Parsers:**
| Parser | Location | What It Reads | Risk |
|--------|----------|---------------|------|
| `_parse_session()` | `sprint/story_finish.py` | `**Key:** Value` fields (Jira, Branch, PR) | None — ignores unknown sections |
| `parse_markdown_session()` | `migration/session.py` | Full session structure (ACs, work log, assessments) | Low — section regex won't match new headers |
| `story_detail_data.py` | `bikerack/story_detail_data.py` | Session for BikeRack panel | Check needed |
| `context_window.py` | `hooks/context_window.py` | Session for context budget | Check needed |
| `preflight/finish.py` | `preflight/finish.py` | PR, lint, Jira, AC checks | None — doesn't parse assessments |

**Assessment Format (Current):**
- TEA: `## TEA Assessment` → `**Tests Required:**`, `**Test Files:**`, `**Status:**`
- Dev: `## Dev Assessment` → `**Implementation Complete:**`, `**Files Changed:**`, `**Tests:**`
- Reviewer: `## Reviewer Assessment` → `**Verdict:**`, observations as numbered list with severity tags

**sm-finish Today:**
1. Check PR exists → create if needed
2. Run `pf preflight finish` → PR state, lint, Jira, ACs
3. Return structured `FINISH_PREFLIGHT_RESULT`
4. SM calls `pf sprint story finish` → archive, merge, Jira Done, YAML update, cleanup

**No summary generation step exists anywhere in the finish flow.**

### Key Concerns

**1. Assessment Scanning Is LLM Work, Not Script Work**
The PRD's Phase 1 asks SM to "scan assessments for upstream observations." This is NLP-style classification — identifying which sentences describe upstream effects vs. routine implementation notes. A Haiku subagent can do this, but a regex script cannot. This is an important design decision: the summary generation is inherently an LLM task.

**2. Delivery Findings Are a Format Shift**
Current assessments are free-text markdown. Phase 2 asks agents to write structured YAML blocks alongside their assessments. This changes every agent's exit behavior — TEA, Dev, and Reviewer all gain a new responsibility. The template approach (provide YAML snippets in agent guides) is correct but needs careful design to avoid agents producing malformed YAML.

**3. Section Placement in Session Files**
The PRD says Impact Summary goes "after Phase Log" but the current session file has:
- Header fields (Jira, Epic, Points, etc.)
- Description, ACs, Technical Context
- Agent assessments (TEA, Dev, Reviewer)
- Phase Log (at bottom, as a table)

The Impact Summary should go AFTER all assessments (since it summarizes them) but BEFORE the Phase Log. Or alternatively, at the very top (after header) for boss readability — but it can't be generated until finish phase. This ordering needs a decision.

**4. Two-Phase Transition Is Clean But Needs a Bridge**
Phase 1 (SM scans assessments) and Phase 2 (agents write structured findings) are well-separated. But the transition means sm-finish's summary logic changes between phases. Design should anticipate both modes: "scan and classify" (Phase 1) → "compile from structured data" (Phase 2).

**5. `sm-finish` Scope Expansion**
Currently: preflight checks (mechanical, scripted).
Proposed: preflight + Impact Summary generation (requires LLM judgment).
This is a significant scope expansion for a Haiku subagent. The generation step should be a separate subagent or a distinct step within sm-finish.

### Design Direction (User Decision — 2026-02-27)

**Key constraints from the boss:**
1. **No YAML** — all findings are pure markdown, strictly human-readable
2. **Session file is the source of truth** — findings are written there by agents
3. **PR description is generated FROM the session file** — write once, publish twice
4. **Tie back to supporting docs** — findings reference specific docs/specs that may need updating
5. **PR body = session info + findings** — comprehensive, all-in-one for boss review

**Architecture:**
```
Agents write findings (markdown) → Session file (source of truth)
                                         ↓
                                   sm-finish compiles
                                         ↓
                                   PR description (generated view)
```

**Implications:**
- Session file gains Impact Summary + Delivery Findings sections (markdown, not YAML)
- Agents self-report findings referencing affected docs
- sm-finish reads session file, generates PR body from it
- Boss reads PR description which mirrors session content
- Archive preserves everything (session file already archived)
- Aggregation (future) can read archived sessions OR PR bodies

### Design Direction (User Decision — 2026-02-27)

**Key constraints from the boss:**
1. **No YAML** — all findings are markdown, strictly human-readable
2. **Target artifact is the PR description** — the boss reads this during PR review, not session files
3. **Tie back to supporting docs** — findings should reference specific docs/specs that may need updating
4. **PR description = session info + findings + plan** — comprehensive, all-in-one

This collapses the PRD's three-artifact approach (session section + YAML blocks + aggregation scripts) into a single artifact: **the PR body**. The PR becomes the delivery feedback document.

**Implications:**
- No YAML parsing needed, no schema validation for findings
- No session file format changes needed for Phase 1
- Agents self-report findings in their assessments (markdown)
- SM compiles findings + session context into PR description at finish time
- Aggregation (future) reads archived sessions or PR bodies
- Supporting doc references (ADRs, guides, agent definitions) are the key value-add

### Pattern Selection: B — Separate Findings Section + PR Body Generation

**Selected pattern:** Agents write findings to `## Delivery Findings` section in session file (markdown). SM compiles session file into rich PR body at finish time.

**Finding format:** Markdown list items — type, urgency, description, affected doc path, attribution.

**PR body:** Generated from session file — summary, impact, ACs, assessments, findings, docs-that-may-need-updating.

**Boss adapter constraint:** Boss doesn't use Pennyfarthing. PR body must be self-contained and legible to someone who has never seen a session file. No framework jargon (no "phase," "handoff," "gate"). The PR description IS the deliverable — a complete record of what was done, what was found, and what docs may be stale.

### Component Design

**Components:**
1. `## Delivery Findings` section in session file — agents append findings during their phase
2. `## Impact Summary` section in session file — SM compiles at finish from findings
3. PR Body Generator in sm-finish — reads session file, translates to boss-readable PR description
4. Updated agent assessment templates — prompt agents to self-report findings
5. Updated session file template in sm-setup — includes `## Delivery Findings` placeholder

**Consistency Rules:**
- R1: Fixed finding format: `- **{Type}** ({urgency}): {description}. Affects \`{path}\`. *Found by {Agent} during {phase}.*`
- R2: Agents ONLY append to Delivery Findings (never edit/remove)
- R3: "No findings" is explicit (distinguishes "checked" from "forgot")
- R4: Doc references use relative paths from project root
- R5: PR body uses zero framework jargon
- R6: Impact Summary is compiled from findings, not editorial

### Interface Definitions

**Finding entry format:**
```
- **{Type}** ({urgency}): {description}. Affects `{path}`. *Found by {Agent} during {phase}.*
```

**Session file section order:**
Header → Description → ACs → Technical Context → Delivery Findings (NEW) → Impact Summary (NEW) → TEA Assessment → Dev Assessment → Reviewer Assessment → Phase Log

**PR body structure (boss-readable, zero jargon):**
Summary → What Was Done → What This Work Revealed → Docs That May Need Updating → Details (assessments + findings)

**Jargon translation:** TEA→test design, Dev/green→implementation, Reviewer/review→code review, ACs→requirements

### Workflow Change: Late PR Creation

**Constraint:** `gh` cannot edit PR descriptions after creation. PR must be created with full body.

**New flow:** Agents work on branch (no PR) → Reviewer reviews branch diff → SM finish compiles Impact Summary → creates PR with full session body → preflight → merge.

**Files affected:**
- `sm-finish.md` — PR creation moves after summary compilation
- `reviewer-preflight.md` — PR_NUMBER becomes optional
- `reviewer.md` — Remove PR_NUMBER from required params
- `sm-setup.md` — Add Delivery Findings placeholder to session template
- `tea.md`, `dev.md`, `reviewer.md` — Add finding-capture to assessment templates
- `sm.md` — Add Impact Summary compilation + PR body generation
- `guides/session-artifacts.md` — Document new sections
- `story_finish.py` — No change needed (already finds PR by branch)

### Risk Assessment

**Top risks:**
1. Agents forget to write findings (HIGH likelihood) → Mitigated by R3 (explicit "no findings" required) + exit gate check
2. Reviewer-preflight fails without PR_NUMBER (MED) → Make PR_NUMBER optional
3. Breaking existing workflows during rollout (MED) → Phase rollout: findings+templates first, then summary+PR body
4. In-flight stories lack Delivery Findings section (MED) → SM finish handles missing section gracefully

**Agent risks:** Template separation (assessment vs findings), jargon translation map, SM compiles don't edit.
**No mitigation needed:** Session parsing, archive integrity, aggregation (future).

### ADR

**Written:** `docs/adr/0031-session-feedback-system.md`
**Status:** Proposed

