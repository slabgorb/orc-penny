# Epic 133: Agent Finding Capture & Workflow Unblocking

## Vision
Agents systematically record upstream findings during their phase. A validation gate confirms finding format correctness. The reviewer workflow is unblocked to operate without a PR.

## Initiative
Part of the **session-feedback** initiative (3 epics: 133 finding capture, 134 impact summary, 135 sprint aggregation). Epic 133 is the foundation — 134 and 135 depend on findings being captured and validated here.

## Success Criteria
- Every agent phase produces either structured findings or explicit "no findings" entries
- All findings conform to R1 format (type, urgency, description, affected spec, action)
- Validation gate catches malformed findings before downstream compilation
- Reviewer operates without PR_NUMBER during review phase

## Scope Boundaries

**In scope:**
- Delivery Findings section in session template (133-1, done)
- Agent exit behaviors writing findings (133-2)
- Gate script validating finding format (133-3)
- Guide documentation (133-4)

**Out of scope:**
- Impact Summary compilation (Epic 134)
- Boss-readable PR generation (Epic 134)
- Sprint-level findings aggregation (Epic 135)
- Jira integration with findings

## Technical Guardrails
- **R1 format:** `- **{Type}** ({urgency}): {description}. Affects \`{path}\` ({what needs to change}). *Found by {Agent} during {human-phase-name}.*`
- **R2:** Agents only append — never edit or remove another agent's entries
- **R3:** "No findings" must be explicit (distinguishes "checked, found nothing" from "forgot")
- **R4:** Doc references use relative paths from project root
- **Valid types:** Gap, Conflict, Question, Improvement
- **Valid urgencies:** blocking, non-blocking
- **Human phase names:** RED→"test design", GREEN→"implementation", REVIEW→"code review"
- **Pure markdown** — no YAML code blocks in findings, must be script-parseable list items

## Key Files
- `pennyfarthing-dist/agents/sm-setup.md` — session template with Delivery Findings section (modified by 133-1)
- `pennyfarthing-dist/agents/tea.md`, `dev.md`, `reviewer.md` — agent exit behaviors (133-2)
- `pennyfarthing-dist/agents/reviewer-preflight.md` — PR_NUMBER optional (133-2)
- `pennyfarthing-dist/gates/` — existing gate definitions (pattern for 133-3)
- `pennyfarthing-dist/guides/session-artifacts.md` — guide to update (133-4)
- `pennyfarthing-dist/src/pf/handoff/gate_file.py` — gate resolution system
- `pennyfarthing-dist/src/pf/handoff/gate_runner.py` — gate execution system

## Authoritative References
- PRD: `sprint/planning/session-feedback-prd.md`
- Epic breakdown: `sprint/planning/create-epics-and-stories.md`
- PRD validation: `sprint/planning/session-feedback-prd-validation.md`

## Story Dependency Chain
133-1 (template) → 133-2 (agent capture) + 133-3 (validation gate) → 133-4 (docs)
Stories 133-2 and 133-3 can proceed in parallel since 133-1 is done.
