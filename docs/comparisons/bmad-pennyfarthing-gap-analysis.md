# BMAD-METHOD vs Pennyfarthing: Gap Analysis

**Date:** 2026-02-13
**Updated:** 2026-02-13 (party-mode roleplay — PROJ-15038) (party mode roleplay)
**Purpose:** Identify gaps between BMAD-METHOD and Pennyfarthing agents, workflows, and infrastructure.

## Changes Applied

- **Architecture data files**: Added `data/domain-complexity.csv` (5-column, 12 domains incl. OT) and `data/project-types.csv` (6 project types) to `workflows/architecture/data/`
- **Quick-spec workflow**: Imported 4-step workflow (understand → investigate → generate → review) + template to `workflows/quick-spec/`
- **OT domains**: Added `process_control` and `building_automation` to PRD `domain-complexity.csv`, `step-v-08`, and `prd-purpose.md`
- **Party-mode roleplay**: Added `party-mode-roleplay` stepped workflow (3 steps) adapted from BMAD's party-mode. Coexists with existing quick brainstorm as two variants. PROJ-15038

---

## Agents

| Role | BMAD-METHOD | Pennyfarthing | Notes |
|------|-------------|---------------|-------|
| Scrum Master | Bob (sm) | SM + 4 subagents | PF decomposed into sm-setup, sm-finish, sm-handoff, sm-file-summary |
| Developer | Amelia (dev) | Dev | Parity |
| Architect | Winston (architect) | Architect | Parity |
| Product Manager | John (pm) | PM | Parity |
| UX Designer | Sally (ux-designer) | UX Designer | Parity |
| Business Analyst | Mary (analyst) | BA | Parity |
| Tech Writer | Paige (tech-writer) | Tech Writer | BMAD has sidecar; PF has sidecars for all agents |
| TEA | Murat (external module) | TEA | BMAD has richer TEA with 9 workflows; PF has core TEA for TDD |
| QA Engineer | Quinn (qa) | -- | **BMAD only** — PF splits QA duties between TEA and Reviewer |
| Quick Flow Solo Dev | Barry | -- | **BMAD only** |
| BMad Master | BMad Master (core) | -- | **BMAD only** — closest PF analog is Orchestrator but different scope |
| Orchestrator | -- (BMad Master is partial analog) | Orchestrator | **PF only** — meta-operations, process improvement |
| Reviewer | -- | Reviewer + reviewer-preflight | **PF only** — adversarial code review gate |
| DevOps | Possibly "Sam" (v4, not found in workspace) | DevOps | **PF only confirmed** — BMAD may have importable legacy |
| Tandem Observer | -- | Tandem Backseat | **PF only** — dual-agent advisory pattern |
| Testing Runner | -- | testing-runner subagent | **PF only** — config-driven test execution |
| Handoff | -- | handoff subagent | **PF only** — workflow-driven handoff |

### Agent Architecture Differences

- **BMAD** uses YAML agent definitions (`.agent.yaml`), menu-driven commands per agent
- **Pennyfarthing** uses Markdown agent definitions (`.md`), separate command system (37 commands)
- **BMAD** has external modules for specialized agents (TEA, Game Dev, Creative Intelligence, WDS, Cyber Sec)
- **Pennyfarthing** is monolithic dist with all agents bundled
- **Pennyfarthing** decomposes complex agents into primary + subagents for mechanical tasks

### BMad Master vs Orchestrator

These are **not** exact equivalents, though BMad Master is the closest BMAD analog:

- **BMad Master**: Runtime task executor and resource manager. Loads resources dynamically, lists available tasks/workflows, serves as the BMAD execution engine.
- **Orchestrator**: Meta-operations agent. Fixes systems and processes, not the work itself. Updates agent behavior files, designs workflows, conducts retrospectives, audits documentation. Explicitly never writes feature code.

---

## Workflows — Analysis Phase

| Workflow | BMAD | Pennyfarthing | Notes |
|----------|------|---------------|-------|
| Product Brief | 7 steps (.md) | 7 steps | Parity |
| Market Research | 6 steps | 7 steps | PF has extra customer-insights step |
| Domain Research | 6 steps | 6 steps | Parity |
| Technical Research | 6 steps | 6 steps | Parity |

---

## Workflows — Planning Phase

| Workflow | BMAD | Pennyfarthing | Notes |
|----------|------|---------------|-------|
| PRD Create | 13 steps (steps-c/) | 13 steps (steps-c/) | Parity |
| PRD Validate | 14 steps (steps-v/) | 14 steps (steps-v/) | Parity |
| PRD Edit | 5 steps (steps-e/) | 5 steps (steps-e/) | Parity |
| PRD Data | 3 files (2 CSV + prd-purpose) | 3 files (2 CSV + prd-purpose) | Parity (both now include OT domains) |
| UX Design | 14 steps | 15 steps | PF has extra step |

---

## Workflows — Solutioning Phase

| Workflow | BMAD | Pennyfarthing | Notes |
|----------|------|---------------|-------|
| Architecture | 9 steps (.md) + 2 data files | 8 steps + 2 data files | Parity (data files imported) |
| Epics & Stories | 4 steps | 5 steps | PF adds step-05-import-to-future (sprint import) |
| Implementation Readiness | 6 steps | 6 steps | Parity |

### Architecture Workflow Data — RESOLVED

BMAD's architecture workflow has its own `data/domain-complexity.csv` (5-column simplified format) and `data/project-types.csv`. These have been imported to Pennyfarthing's `workflows/architecture/data/` directory. Note: the architecture steps don't directly reference these CSVs yet (neither do BMAD's) — they serve as reference data for the agent during solutioning.

---

## Workflows — Implementation Phase

| Workflow | BMAD | Pennyfarthing | Notes |
|----------|------|---------------|-------|
| Code Review | .yaml | Checklist workflow | Different architecture |
| Dev Story | .yaml | -- | Handled by phased TDD/trivial workflows in PF |
| Create Story | .yaml + template | -- | Handled by SM agent in PF |
| Sprint Planning | .yaml + template | 5 steps | PF more detailed |
| Sprint Status | .yaml | -- | Merged into sprint-planning in PF |
| Correct Course | .yaml | -- | **BMAD only** |
| Retrospective | .yaml | Checklist workflow | Parity |
| QA Automate | .yaml | -- | **BMAD only** |
| Document Project | .yaml + 4 templates | -- | **BMAD only** |
| Generate Project Context | 3 steps (.md) | 3 steps | Parity |

**Note:** BMAD Phase 4 workflows still use `.yaml` format (being deprecated). Phase 1-3 already migrated to `.md` with step-file architecture. Newer workflows (quick-flow) use `.md`, confirming the migration direction.

---

## Workflows — Quick Flow

| Workflow | BMAD | Pennyfarthing | Notes |
|----------|------|---------------|-------|
| Quick Spec | 4 steps (.md) | 4 steps | Parity (imported) |
| Quick Dev | 6 steps (.md) | 6 steps | Parity |

---

## Workflows — Core / Utility

| Workflow | BMAD | Pennyfarthing | Notes |
|----------|------|---------------|-------|
| Brainstorming | 8 steps + brain-methods.csv | Procedural + brain-methods.csv | Parity |
| ~~Party Mode~~ | 3-step workflow (roundtable) | Command (quick) + Workflow (roleplay) | **RESOLVED** — both variants now exist, see Party Mode Analysis |
| Advanced Elicitation | .xml + methods.csv | -- | **BMAD only** |

---

## Workflows — Pennyfarthing Only (Phased)

Phased workflows are agent-driven with automatic handoffs. BMAD has no equivalent — it uses menu-driven per-agent workflows instead.

| Workflow | Flow | Description |
|----------|------|-------------|
| TDD | SM → TEA → Dev → Reviewer → SM | Full TDD lifecycle with handoffs |
| Trivial | SM → Dev → Reviewer → SM | Quick fixes, no TEA phase |
| BDD | SM → UX → TEA → Dev → Reviewer → SM | Behavior-driven with UX |
| 2party-tdd | SM → party → TEA → Dev → QA → Reviewer → SM | Story refinement + TDD |
| tdd-tandem | Tandem pairs through phases | TDD with backseat observers |
| bdd-tandem | Tandem pairs through phases | BDD with backseat observers |
| tdd-team | Dev + Architect team through phases | TDD with full-session teammate collaboration |
| bdd-team | UX + Architect team through phases | BDD with full-session teammate collaboration |
| review-tandem | SM → TEA → Dev → Reviewer (+Architect) → SM | TDD with focused architectural review tandem |
| agent-docs | Orchestrator → Tech Writer → SM | Agent documentation updates |
| patch | Dev only | Interrupt-driven bug fix |

### Workflows — Pennyfarthing Only (Stepped)

| Workflow | Steps | Description |
|----------|-------|-------------|
| Project Setup | 10 | New project configuration wizard |
| Release | 11 | Gated release process (bump, changelog, README, commit, merge, push, publish) |
| Git Cleanup | 5 | Organize uncommitted changes into proper commits |
| Interactive Debug | 4 | Connect → Explore → Fix → Commit |

---

## TEA Module Detail (BMAD External)

BMAD's TEA module (`bmad-method-test-architecture-enterprise`) is a standalone importable module with 9 dedicated workflows that go well beyond Pennyfarthing's core TEA agent:

| Code | Workflow | Description |
|------|----------|-------------|
| TMT | Teach Me Testing | Interactive learning, 7 progressive sessions |
| TF | Test Framework | Production-ready test framework architecture |
| AT | ATDD | Acceptance tests + implementation checklist |
| TA | Test Automation | Prioritized API/E2E tests, fixtures |
| TD | Test Design | Risk assessment + coverage strategy |
| TR | Trace Requirements | Requirements-to-tests mapping |
| NR | NFR Assessment | Non-functional requirements testing |
| CI | CI Pipeline | CI/CD quality pipeline design |
| RV | Review Tests | Quality check against tests |

Pennyfarthing's TEA focuses on the RED phase of TDD (writing failing tests, acceptance criteria analysis). It does not have standalone test architecture workflows.

---

## Infrastructure Comparison

| Category | BMAD | Pennyfarthing |
|----------|------|---------------|
| Commands | Menu-driven (per agent YAML) | 37 dedicated command files |
| Guides | -- | 33 system behavior docs |
| Persona Themes | -- | **98** themed character packs across 8 packages |
| Skills | -- | 22 reusable capability libraries |
| Scripts | -- | 18 script directories |
| Output Styles | -- | 3 (terse, verbose, teaching) |
| Migrations | -- | 6 framework upgrade scripts |
| Sidecars | Tech Writer only | All agents (templates + health check + migration) |
| External Modules | TEA, Game Dev, Creative Intelligence, WDS, Cyber Sec | -- (monolithic dist) |

### Sidecar System

**BMAD:** Only the Tech Writer agent (Paige) has a sidecar (`tech-writer-sidecar/documentation-standards.md`). No other agents have sidecars.

**Pennyfarthing:** Full sidecar system for all agents:
- Templates: `decisions.md`, `gotchas.md`, `patterns.md` per agent
- Location: `.pennyfarthing/sidecars/{agent}/`
- Health check script enforces line limits (gotchas: 50, patterns: 50, decisions: 40)
- Migration script handles legacy locations
- Referenced by 17+ files (commands, guides, skills, agents, workflows)
- Integrated into prime (context loading tier 5) and retro (consolidation)

### Theme Breakdown (98 total)

| Package | Count | Themes |
|---------|-------|--------|
| pennyfarthing-dist/personas | 27 | a-team, alice-in-wonderland, battlestar-galactica, blade-runner, catch-22, control, cowboy-bebop, discworld, doctor-who, dune, fifth-element, firefly, game-of-thrones, harry-potter, hitchhikers-guide, lord-of-the-rings, mad-max, mash, princess-bride, sandman, star-trek-tng, star-wars, the-expanse, the-matrix, watchmen, west-wing, x-files |
| themes-comedy | 9 | big-lebowski, futurama, gilligans-island, monty-python, parks-and-rec, ted-lasso, the-good-place, the-office, the-simpsons |
| themes-literary | 15 | 1984, agatha-christie, arthurian-mythos, count-of-monte-cristo, dickens, don-quixote, gothic-literature, great-gatsby, jane-austen, les-miserables, lovecraft-mythos, moby-dick, shakespeare, sherlock-holmes, the-odyssey |
| themes-mythology-fantasy | 4 | greek-mythology, his-dark-materials, norse-mythology, the-witcher |
| themes-prestige-tv | 17 | better-call-saul, black-sails, breaking-bad, deadwood, fargo, hannibal, house-md, justified, mad-men, peaky-blinders, rome, succession, the-americans, the-crown, the-sopranos, the-wire, twin-peaks |
| themes-realistic | 14 | ancient-philosophers, ancient-strategists, classical-composers, enlightenment-thinkers, film-auteurs, historical-figures, jazz-legends, military-commanders, renaissance-masters, russian-masters, scientific-revolutionaries, software-pioneers, world-explorers, wwii-leaders |
| themes-scifi | 8 | babylon-5, expeditionary-force, foundation, imperial-radch, neuromancer, snow-crash, star-trek-tos, vorkosigan-saga |
| themes-superheroes | 4 | avatar-the-last-airbender, legion-of-doom, marvel-mcu, superfriends |

---

## BMAD External Modules (Not in Pennyfarthing)

These BMAD modules have no Pennyfarthing equivalent:

| Module | Type | Description |
|--------|------|-------------|
| bmad-method-test-architecture-enterprise | library | TEA/Murat — test architecture and quality strategy (9 workflows) |
| bmad-module-game-dev-studio | library | Game dev agents (Game Architect, Designer, Dev, QA, SM, Solo Dev, Tech Writer) |
| bmad-module-creative-intelligence-suite | library | Creative agents (Brainstorming Coach, Creative Problem Solver, Design Thinking Coach, Innovation Strategist, Presentation Master, Storyteller) |
| bmad-method-wds-expansion | library | Whiteport Design Studio methodology |
| bmad-cyber-sec | library | Cybersecurity (template stage) |
| bmad-builder | cli | Module creation tool |
| bmad-utility-skills | plugin | Claude plugin for contributor utilities |

---

## Key Gaps Summary

### BMAD has, Pennyfarthing lacks

| Gap | Impact | Notes |
|-----|--------|-------|
| QA Engineer agent (Quinn) | Medium | PF splits QA between TEA and Reviewer |
| Quick Flow Solo Dev (Barry) | Low | PF has quick-dev workflow without dedicated agent |
| ~~Quick Spec workflow~~ | -- | Imported to PF |
| Correct Course workflow | Medium | No PF equivalent for mid-sprint course correction |
| QA Automate workflow | Medium | No PF standalone QA automation workflow |
| Document Project workflow | Medium | 4 templates for project documentation generation |
| Advanced Elicitation workflow | Low | XML-based elicitation methods |
| ~~Party Mode (as stepped workflow)~~ | -- | RESOLVED — added as `party-mode-roleplay` workflow (PROJ-15038) |
| ~~Architecture data files~~ | -- | Imported to PF |
| TEA module depth | Medium | BMAD's Murat has 9 specialized testing workflows vs PF's TDD-focused TEA |
| External module system | Low | BMAD supports importable modules; PF is monolithic |
| ~~PRD step-11-polish~~ | -- | Both have step-11-polish — parity confirmed |

### Pennyfarthing has, BMAD lacks

| Gap | Impact | Notes |
|-----|--------|-------|
| Phased workflow engine (11 workflows) | High | TDD, BDD, trivial, patch, tandem, team, review-tandem, agent-docs — automatic agent handoffs |
| Reviewer agent | High | Adversarial code review gate with preflight subagent |
| DevOps agent | Medium | CI/CD, infrastructure, deployment |
| Orchestrator agent | Medium | Meta-operations, process improvement |
| Tandem Observer | Low | Dual-agent advisory pattern |
| SM subagent decomposition | Medium | 4 subagents for mechanical SM tasks |
| Project Setup workflow (10 steps) | Medium | New project configuration wizard |
| Release workflow (11 steps) | Medium | Gated release process |
| Git Cleanup workflow (5 steps) | Low | Commit organization |
| Interactive Debug workflow (4 steps) | Low | Structured debugging |
| Full sidecar system | Medium | All agents, health checks, migration, prime integration |
| 37 dedicated commands | Medium | Decoupled command system |
| 33 guides | High | System behavior documentation |
| 98 persona themes | Low | Themed character packs |
| 22 skills | Medium | Reusable capability libraries |
| 18 script directories | Medium | Workflow execution and integrations |
| Output styles | Low | Terse, verbose, teaching |
| Migration system | Low | Framework upgrade scripts |

---

## Party Mode Analysis

PF and BMAD have fundamentally different implementations that serve different use cases. Neither replaces the other.

### PF: Party Mode Command ("Brainstorm Flash")

**What it is:** A 78-line single-page prompt. Puts the agent into a "yes, and..." persona, lists 9 agent perspectives with one-line role descriptions, picks 3-4 per topic, produces a structured artifact.

| Strength | Detail |
|----------|--------|
| Simplicity | Zero ceremony, instant activation |
| Output-focused | Defined format: Ideas Generated, Most Promising, Wild Cards, Next Steps |
| Theme-aware | Pulls character names from active theme |
| Wired in everywhere | Used as `[P]` option across 13+ workflow step A/P/C menus |
| Intervention-friendly | Quick in-and-out within another workflow |

| Weakness | Detail |
|----------|--------|
| Single-shot | One brainstorm dump, no sustained discussion |
| Hardcoded perspectives | Agent "perspectives" are role descriptions, not real persona data |
| No cross-talk | Agents don't reference or build on each other's points |
| No session management | No exit protocol, no state tracking, no return-to-parent |

### BMAD: Party Mode Workflow ("Roundtable")

**What it is:** A 3-step workflow (~500 lines) that loads agent data from a CSV manifest, builds a roster with merged personalities, runs multi-round discussion with intelligent agent selection and cross-talk, and exits gracefully with in-character farewells.

| Strength | Detail |
|----------|--------|
| Real agent data | Loads name, communicationStyle, principles, identity from manifest |
| Multi-round | Sustained back-and-forth with `[E] Exit` after each round |
| Intelligent selection | Analyzes each user message for domain/expertise match, picks 2-3 agents |
| Cross-talk | Agents reference each other, build on points, respectfully disagree |
| Question protocol | Differentiates direct-to-user, rhetorical, and inter-agent questions |
| Return protocol | Knows how to hand control back to a parent workflow |
| Moderation | Handles circular discussions, topic drift |

| Weakness | Detail |
|----------|--------|
| Heavy | 4 files, ~500 lines of orchestration |
| No structured output | Conversational session, no defined artifact |
| Manifest dependency | Requires `agent-manifest.csv` which PF doesn't have |
| BMAD-specific paths | References `_bmad/core/config.yaml`, `_bmad/_config/agent-manifest.csv` |
| Over-engineered exit | 169-line step-03 for what amounts to "say goodbye" |

### What PF Would Lose by Replacing

1. **A/P/C menu integration** — 13+ workflow steps use party mode as a quick intervention via `[P]`. A stepped workflow can't be dropped into a checkpoint menu the same way.
2. **Structured output** — PF produces an artifact; BMAD's is conversational with no deliverable.
3. **Theme integration** — PF pulls from active theme; BMAD pulls from a manifest CSV that PF doesn't have.

### What PF Would Gain from BMAD's

1. **Multi-round sustained sessions** — actual back-and-forth, not one-shot.
2. **Real persona data** — responses grounded in actual agent definitions.
3. **Cross-talk and intelligent selection** — agents building on each other.
4. **Standalone deep-session use case** — not just a quick intervention.

### Resolution: Two Variants (PROJ-15038)

Implemented as recommended — both variants coexist under the `party-mode` command:

- **`party-mode quick`** — existing brainstorm flash, unchanged. Still used as `[P]` in A/P/C menus. Single-shot, structured output, zero ceremony.
- **`party-mode roleplay`** — new stepped workflow adapted from BMAD. Sustained multi-round agent discussion with PF agent loading, theme personas, cross-talk, intelligent selection, and structured summary on exit.
- **`party-mode`** (bare) — routes to user's `party_mode_default` preference in `config.local.yaml` (defaults to `quick`).

**Adaptations applied:**
- Replaced BMAD CSV manifest loading with PF agent `.md` file scanning + theme persona resolution
- Replaced `_bmad/` paths with `.pennyfarthing/` paths
- Removed `bmad-master`, `bmad-speak.sh` hook, `{communication_language}` config references
- Added PF structured output format (Ideas Generated, Most Promising, Wild Cards, Next Steps) to exit step
- Used PF workflow step XML schema (`<step-meta>`, `<purpose>`, `<instructions>`, etc.)
- Slimmed exit step from BMAD's 169 lines to ~80 lines
- Added Key Disagreements section to capture where agents diverged

---

## Open Questions

1. **DevOps "Sam"**: User referenced a v4 BMAD DevOps agent named Sam. Not found in current workspace — may exist in a separate location or archive.
2. ~~**Architecture data parity**~~: RESOLVED — imported both CSVs.
3. **TEA enrichment**: Should Pennyfarthing import any of BMAD's 9 TEA workflows, or is the TDD-focused TEA sufficient?
4. **Module system**: Is BMAD's importable module pattern something Pennyfarthing should adopt, or is monolithic dist the intended architecture?
