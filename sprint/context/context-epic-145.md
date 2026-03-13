# Epic 145: Demo Artifact Generator — Core Pipeline

## Overview

Collection → classification → generation → assembly pipeline for auto-generating presentation-ready demo artifacts from completed stories. System executes on story completion (`pf sprint story finish`), zero developer effort, with management-friendly ELI5 narratives per story type.

**Priority:** P1
**Repo:** pennyfarthing
**Stories:** 7 (17 points)
**ADR:** ADR-0038
**PRD:** `sprint/planning/demo-prd.md`

## Planning Documents

| Document | Relevant Sections |
|----------|-------------------|
| **Demo Artifact Generator PRD** (`sprint/planning/demo-prd.md`) | Full PRD — success criteria, user journeys, story type classification, artifact formats, configuration |
| **ADR-0038** (`docs/adr/0038-demo-artifact-generator.md`) | Architecture, pipeline flow, component interfaces, dataclasses, implementation consistency rules |

## Technical Approach Summary

Five-stage pipeline with strategy-based format selection:

```
pf demo generate <story-id>
         │
         ▼
┌──────────────────┐
│  DemoOrchestrator │──── pipeline entry point, executes stages sequentially
└────────┬─────────┘
         │
    ┌────▼────┐
    │Collector │──── gather signals: ACs, PR diff, commits, session, review findings
    └────┬────┘
         │ SignalBundle
    ┌────▼──────┐
    │Classifier │──── deterministic rule-based story type → strategy mapping
    └────┬──────┘
         │ ClassifiedStory
    ┌────▼──────┐
    │ Generator │──── Claude-powered ELI5 content translation
    └────┬──────┘
         │ GeneratedContent
    ┌────▼──────┐
    │ Assembler │──── mechanical Python: build PPTX slides, demos, diagrams
    └────┬──────┘
         │
         ▼
  sprint/demos/<story-id>/
```

**Key Design Constraints:**
- Fail hard — no partial output, no placeholders
- Classification is deterministic (rule-based, no AI)
- Only Generator invokes Claude; Assembler is pure mechanical Python
- Config is optional — sensible defaults work without `demo.yaml`
- All functions return `{success, data?, error?}` (ADR-0008)

## Story Breakdown & Integration Points

### 145-1: Signal Collector (3 pts) — Core Integration Point

**Responsibility:** Gather all story signals before archival

**Inputs:**
- Story ID (e.g., "145-1")
- Project root (via `get_project_root()`)

**Outputs:** `SignalBundle` dataclass:
```python
@dataclass
class SignalBundle:
    story_id: str
    title: str
    jira_key: str | None
    points: int | None
    acceptance_criteria: list[str]
    pr_diff: str                          # capped at 50K chars
    commit_messages: list[str]
    session_fields: dict[str, str]        # from session file **Key:** Value lines
    review_findings: str | None           # from archive/findings or Jira custom field
    file_extensions: set[str]             # .rs, .ts, .py, etc. → strategy hint
```

**Data Sources & Patterns:**

1. **Sprint YAML** — Use `pf.sprint.loader.load_sprint()` → find story by ID → extract:
   - title, points, jira_key (story.get("jira"))
   - acceptance_criteria: `story.get("acceptance_criteria", [])`
   - Compare with signal collection timing in `story_finish.py` (lines 32-57)

2. **Session File** — Parse `.session/{story-id}-session.md`:
   - Extract markdown `**Key:** Value` fields via regex: `\*\*(\w[\w\s]*):\*\*\s*(.*)`
   - Populate `session_fields` dict (see `story_finish.py` lines 60-75 for pattern)
   - Non-fatal fallback if missing (file may be archived/deleted by time of collection)

3. **PR Diff** — Via `gh pr view --json`:
   ```bash
   gh pr view <pr-number> --json additions,deletions,files
   ```
   - Truncate to 50K chars if oversized (ADR-0038 risk mitigation)
   - Fallback if PR not found: `git diff <merge-base>..HEAD` (see ADR-0038)
   - Detect file_extensions: `.rs`, `.ts`, `.py`, `.go`, `.java` → classification hints

4. **Commit Messages** — Git log since branch creation:
   ```bash
   git log <base-branch>..HEAD --pretty=format:%B
   ```
   - Split on double newlines for multi-line commits
   - Non-fatal: empty list if no commits (rare but possible)

5. **Review Findings** — Optional, from:
   - `sprint/archive/findings/{story-id}.md` (if exists)
   - Jira custom field "Internal Review Findings" (if synced)
   - Fallback: None (non-fatal; Assembler handles empty findings)

**Dependencies:**
- Existing: `pf.sprint.loader` (loads sprint YAML)
- Existing: `pf.common.config.get_project_root()`
- CLI tools: `gh`, `git`
- Pattern: Same session parsing as `story_finish.py` (reuse, don't duplicate)

**Timing Constraint (CRITICAL):**
- Collector must run **BEFORE** session archival in `story_finish.py`
- ADR-0038 risk: "Session and dialogue files are archived/deleted during `story_finish`"
- Integration: Call as **step 0** in `finish_story()` before archival (line ~200 of story_finish.py)
- If story_finish is already running: Collector triggers from within; otherwise: manual CLI call

### 145-2: Story Type Classifier (2 pts) — Rule-Based, No ML

**Responsibility:** Deterministic story type detection

**Input:** `SignalBundle` from Collector

**Output:** `ClassifiedStory` dataclass:
```python
@dataclass
class ClassifiedStory:
    signals: SignalBundle
    story_type: StoryType          # enum: ui, backend, infrastructure, refactor, bugfix
    artifacts: list[ArtifactType]  # [ ui_screenshots, slide_deck, demo_script, mermaid_diagram, narrative ]
```

**Classification Rules (Deterministic):**

| Story Type | Detection Rule | Artifacts |
|------------|---|---|
| **UI** | title contains "UI\|screen\|button\|form\|layout" OR signals.file_extensions has `.tsx`, `.jsx`, `.css` | Screenshots + Slide Deck + Demo Script |
| **Backend** | file_extensions has `.rs`, `.py`, `.go`, `.java` AND NOT ui-keywords; title contains "API\|endpoint\|database\|query" | Mermaid Diagrams + Narrative + Demo Script |
| **Infrastructure** | title contains "infra\|deployment\|docker\|ci/cd\|k8s"; OR files: Dockerfile, .github, terraform | Mermaid Diagrams + Narrative + Demo Script |
| **Refactor** | title contains "refactor\|cleanup\|tech-debt\|simplify" | Before/After Comparison + Narrative |
| **Bug Fix** | title contains "fix\|bug\|patch\|regression" | Problem Statement + Narrative |

**Optional Config Override:** `demo.yaml` (checked into repo):
```yaml
classification:
  rules:
    - pattern: "streaming.*feature"      # regex on title
      type: "backend"                    # override type
      artifacts: ["mermaid", "narrative"]
```

**Implementation Pattern:**
- Deterministic only (no AI, no fuzzy matching)
- Fall back to title keywords if file_extensions empty
- Fail hard if classification ambiguous (e.g., title "Refactor API UI") — return error
- Config rules apply first, built-in rules as fallback

**Dependencies:**
- Config loader: `load_config()` → reads optional `demo.yaml`
- No external APIs

### 145-3: Content Generator (3 pts) — Claude-Powered ELI5 Translation

**Responsibility:** Translate technical signals to non-technical narratives

**Input:** `ClassifiedStory` from Classifier
**Optional:** `corrections: str` (developer feedback for regeneration)

**Output:** `GeneratedContent` dataclass:
```python
@dataclass
class GeneratedContent:
    problem_statement: str                # "Problem: X. Why it matters: Y."
    what_changed: str                     # Technical summary → ELI5
    why_this_approach: str                # Engineering reasoning
    before_after: str | None              # For refactors + bugfixes
    demo_script: str                      # Step-by-step presenter walkthrough
    diagram_source: str | None            # Mermaid source (backend/infra/refactor)
    slide_outline: list[dict]             # Per-slide metadata: title, bullets, speaker_notes
```

**Generator Prompt Structure:**
- Input: Full SignalBundle, story_type, ACs
- Task: ELI5 translation for non-technical executive audience
- Constraints: Ground all claims in signals (PR diff, ACs, commits); no hallucination
- Multi-pass for complex stories: If outline is 30+ slides, split generation into batches (ADR-0038 NFR)

**Demo Script Format:**
```markdown
## Demo Script — Story 145-3

### Scene 1: Setup (30 sec)
**Presenter says:** "Today we built content generation from signals."
**Show:** Commit diff on screen
**Click:** Show file changes in IDE

### Scene 2: Test Example (1 min)
**Show:** Example signal bundle
**Narrate:** "The system collects these signals..."
```

**Corrections Workflow (FR-22):**
- Developer sees generated output, submits: `pf demo generate 145-3 --corrections "Slide 2 says 40% but spec says 30%"`
- Generator receives: previous output + corrections + original signals
- Generator regenerates revised version
- Assembler overwrites original artifacts in `sprint/demos/<story-id>/`

**Dependencies:**
- Claude API (Opus for strategic content, via existing PF patterns)
- Existing: `pf.prime.loader` or direct API call (check Framework CLAUDE.md for pattern)
- Pattern: Reuse PF's helper delegation (Haiku for mechanical work, Opus for reasoning)

**Non-Fatal Graceful Degradation:**
- If Claude unavailable: Return error → Assembler skips PPTX slides, writes `.md` fallbacks
- No retries (fail hard principle) — developer re-runs with fixes

### 145-4: Demo Script Generator (2 pts) — Narrative Walkthrough

**Responsibility:** Produce step-by-step presenter walkthroughs per story type

**Input:** `GeneratedContent` from Generator

**Output:** Markdown file `demo-script.md` with:
- Scene breakdowns (Setup, Demo Act 1, Act 2, Closing)
- What to say, what to show, what to click
- Timing estimates per scene
- Non-technical language
- Integration point: presenter doesn't need code knowledge

**Story Type-Specific Formats:**

1. **UI Stories:**
   - Scene: "Open app to X screen"
   - Click: "Tap button Y → notice Z changes"
   - No code shown unless UX-critical

2. **Backend/Infrastructure:**
   - Scene: "Before: system did X. Now: system does Y."
   - Diagram: Show before/after architecture
   - No implementation details; focus on user impact

3. **Refactor/Bug Fix:**
   - Scene: "Problem was X. We fixed it by Y."
   - No internal changes; just impact

**Dependencies:**
- Input: GeneratedContent.demo_script (from Generator)
- No AI: Pure formatting/structuring

### 145-5: PPTX Assembler (3 pts) — Mechanical Slide Deck Builder

**Responsibility:** Assemble generated content into presentation-ready PPTX

**Input:** `GeneratedContent` from Generator + `ClassifiedStory` from Classifier

**Output:** `sprint/demos/<story-id>/deck.pptx` + supporting files

**Output Structure:**
```
sprint/demos/<story-id>/
  ├── deck.pptx                  # Main presentation
  ├── demo-script.md             # Presenter walkthrough
  ├── narrative.md               # ELI5 content summary
  ├── diagram.mmd                # Mermaid source (backend/infra/refactor)
  ├── diagram.png                # Rendered (if mmdc available)
  ├── screenshots/               # UI screenshots (Playwright)
  │   ├── screen-01-home.png
  │   └── screen-02-feature.png
  └── metadata.yaml              # Run date, story ID, classifier decisions
```

**PPTX Slide Deck Content:**

| Slide | Content |
|-------|---------|
| 1 | Title: Story ID + Title |
| 2 | Problem Statement |
| 3 | What We Built |
| 4+ | Screenshots OR Diagrams (per story type) |
| N-2 | Why This Approach (engineering reasoning) |
| N-1 | Before/After (if applicable) |
| N | Call-to-Action / Questions |

**Dependencies:**
- Library: `python-pptx` (ADR-0038 consequence: new dependency)
- Imports: `from pptx import Presentation; from pptx.util import Inches, Pt`
- Pattern: Simple templates; avoid fancy styling that breaks on different systems

**Optional Dependencies (Graceful Degradation):**
- Playwright screenshots: If unavailable, skip UI screenshot slides
- `mmdc` (mermaid CLI): If available, render `.mmd` → `.png`; otherwise write `.mmd` file only
- No hard failures for either

### 145-6: Mermaid Diagram Generation (2 pts) — Backend/Infrastructure Visualization

**Responsibility:** Generate architecture/flow diagrams in Mermaid format

**Input:** `GeneratedContent` from Generator (diagram_source field)

**Output:** `diagram.mmd` source + optional `diagram.png` (if mmdc available)

**Diagram Types per Story Type:**

1. **Backend Story:**
   ```mermaid
   graph LR
     A["Request"] --> B["API Endpoint"]
     B --> C["Database"]
     C --> D["Response"]
   ```

2. **Infrastructure Story:**
   ```mermaid
   graph TD
     A["App"] --> B["Docker Container"]
     B --> C["K8s Pod"]
     C --> D["Load Balancer"]
   ```

3. **Refactor Story:**
   ```mermaid
   graph LR
     A["Before: Monolith"] -->|Refactored| B["After: Modular"]
   ```

**Rendering:**
- Check if `mmdc` is available on PATH
- If yes: Render `.mmd` → `.png`, embed in PPTX slides
- If no: Write `.mmd` file only; reference in slide as "See diagram.mmd"
- Non-fatal: Missing mmdc doesn't block PPTX generation

**Dependencies:**
- Generator produces diagram_source (mermaid syntax string)
- Assembler calls subprocess: `mmdc -i diagram.mmd -o diagram.png`
- Pattern: Similar to Playwright optional dependency handling

### 145-7: DemoOrchestrator (2 pts) — Pipeline Entry Point & Output Writer

**Responsibility:** Orchestrate all stages; short-circuit on failure

**Interface:**
```python
def generate(story_id: str, corrections: str | None = None, dry_run: bool = False) -> dict:
    """Generate demo artifacts for completed story.

    Returns: {success, data, error} per ADR-0008
    """
```

**Flow:**

```python
1. Validate story exists in sprint YAML
2. Call Collector → SignalBundle
   ├─ If fails: return {success: False, error: "..."}
3. Call Classifier → ClassifiedStory
   ├─ If fails: return {success: False, error: "..."}
4. Call Generator → GeneratedContent
   ├─ If fails: return {success: False, error: "..."}
5. Call Assembler (Mermaid) → diagram.mmd + diagram.png
   ├─ If diagram not needed: skip
6. Call Assembler (PPTX) → deck.pptx
   ├─ If fails: return {success: False, error: "..."}
7. Call Assembler (Demo Script) → demo-script.md
8. Write metadata.yaml
9. If corrections: re-run Generator(corrections) → regenerate artifacts
10. Return {success: True, data: {output_dir: "...", files: [...]}}
```

**File Output:**
- All to `sprint/demos/{story_id}/` (checked into repo, version-controlled)
- Create dir if missing: `mkdir -p sprint/demos/{story_id}`
- Overwrite existing artifacts (re-run generates new version)

**CLI Entry Points:**

1. **Direct trigger:**
   ```bash
   pf demo generate 145-3
   pf demo generate 145-3 --dry-run
   pf demo generate 145-3 --corrections "Slide 2 math is wrong"
   ```

2. **Skill wrapper:**
   ```bash
   /pf-demo 145-3
   ```

3. **Hook trigger (from story_finish):**
   ```python
   # In story_finish.py, as step 0 (before archival)
   demo_result = generate(story_id)
   if not demo_result["success"]:
       log.warning(f"Demo generation failed: {demo_result['error']}")
       # Non-blocking; continue with story finish
   ```

**Dependencies:**
- All other components (Collector, Classifier, Generator, Assembler)
- Click CLI framework (for `pf demo generate` command)
- Config loader (optional)

## Key Integration Points

### 1. Timing: Before Session Archival (CRITICAL)

**Location:** `pf/sprint/story_finish.py` (line ~200)
**Current Code:**
```python
def finish_story(project_root, story_id, *, dry_run=False):
    session_path = project_root / ".session" / f"{story_id}-session.md"
    # ... validate session ...

    # Step 1: Archive session file
    shutil.copy(session_path, archive_dir / archive_name)

    # Step 2: Merge PR
    # ...
```

**Integration:**
```python
def finish_story(project_root, story_id, *, dry_run=False):
    session_path = project_root / ".session" / f"{story_id}-session.md"
    # ... validate session ...

    # --- STEP 0 (NEW): Generate demo artifacts BEFORE archival ---
    from pf.demo.orchestrator import generate as generate_demo
    demo_result = generate_demo(story_id, dry_run=dry_run)
    if not demo_result["success"]:
        log.warning(f"Demo generation skipped: {demo_result['error']}")
    else:
        log.info(f"Demo artifacts: {demo_result['data']['output_dir']}")

    # Step 1: Archive session file (now safe; signals already captured)
    shutil.copy(session_path, archive_dir / archive_name)

    # Step 2+: Continue existing flow...
```

**Why Step 0:** Session file is deleted after finish completes. Collector needs it to extract fields.

### 2. Collector Dependencies: Reuse Existing Patterns

**Session Parsing:**
- Reuse regex from `story_finish.py` lines 60-75
- Create shared function in `pf.sprint.loader` or `pf.demo.collector` (don't duplicate)

**Sprint YAML Loading:**
- Use `pf.sprint.loader.load_sprint()` (already proven pattern)
- Use `find_epic()`, `find_story()` from same module

**Jira & PR Access:**
- Same `gh` CLI patterns as `story_finish.py` (lines 150-155)
- Fallback strategy if PR not found (git diff as backup)

### 3. Configuration: Optional `demo.yaml`

**Location:** Repository root (checked in)
**Format:**
```yaml
demo:
  branding:
    project_name: "My Project"
    logo_path: "assets/logo.png"
  classification:
    rules:
      - pattern: "streaming.*feature"
        type: "backend"
        artifacts: ["mermaid", "narrative"]
  output:
    screenshots_max_count: 5
    max_diff_chars: 50000
```

**Loading Pattern:**
```python
def load_config():
    config_path = get_project_root() / "demo.yaml"
    if config_path.exists():
        return load_yaml_config(config_path)
    return {}  # Sensible defaults
```

**Reuse:** Same `load_yaml_config` as sprint loader

### 4. Claude API Integration: Existing Prime Pattern

**Pattern:** Use `pf.prime.loader` (existing framework pattern for agent activation)
**Alternative:** Direct Claude API call with Opus model
**Reuse:** Helper delegation pattern from PF (Opus for content, Haiku for mechanical assembly)

## Dependencies Between Stories

```
145-1 (Collector) ──┐
                     ├──> 145-2 (Classifier) ──┐
                     │                          ├──> 145-3 (Generator) ──┐
                     │                          │                        ├──> 145-7 (Orchestrator)
                     └──────────────────────────┤                        │
                                                ├──> 145-4 (Script Gen) ┤
                                                │                        │
                                                ├──> 145-5 (Assembler) ─┤
                                                │                        │
                                                └──> 145-6 (Mermaid) ───┘
```

**Dependency Chain:**
- **145-1 (Collector)** is foundational: must complete first; blocks 145-2, 145-3, 145-7
- **145-2 (Classifier)** depends on 145-1; produces input for 145-7
- **145-3 (Generator)** depends on 145-2; produces input for 145-5
- **145-4 (Script Gen)** depends on 145-3
- **145-5 (Assembler)** depends on 145-3 + 145-6
- **145-6 (Mermaid)** independent; depends only on 145-3's diagram_source
- **145-7 (Orchestrator)** depends on all; orchestrates the entire pipeline

**Parallel Opportunities:**
- 145-4, 145-5, 145-6 could run in parallel after 145-3 completes
- But MVP is sequential (simpler testing, easier debugging)

## Relevant Existing Code & Patterns

### Modules to Reuse

| Module | Purpose | Usage in Demo |
|--------|---------|---|
| `pf.sprint.loader` | Load sprint YAML, find epic/story | Collector: get ACs, title, points |
| `pf.common.config` | Load YAML, get project root | Config loading, path resolution |
| `pf.sprint.story_finish` | Session file parsing | Collector: reuse regex patterns |
| `pf.prime.loader` | Activate agents with full context | Generator: prompt construction |

### Existing Result Object Pattern (ADR-0008)

All functions return:
```python
{
    "success": bool,
    "data": dict | list | str | None,      # Filled if success=True
    "error": str | None,                     # Filled if success=False
}
```

Examples from codebase:
- `pf.init.core.py`: `return {"success": False, "error": "..."}`
- `pf.init.setup.py`: `return {"success": True, "data": {...}}`

### Existing CLI Pattern (Click Groups)

Location: `pf/cli.py`
Registration:
```python
LAZY_COMMANDS = {
    "demo": ("pf.demo.cli", "demo"),  # New entry
    "sprint": ("pf.sprint.cli", "sprint"),
    # ...
}
```

CLI Structure:
```python
# pf/demo/cli.py
@click.group()
def demo():
    """Demo artifact generation."""
    pass

@demo.command()
@click.argument("story_id")
@click.option("--dry-run", is_flag=True)
@click.option("--corrections", type=str)
def generate(story_id, dry_run, corrections):
    """Generate demo artifacts for a completed story."""
    from pf.demo.orchestrator import generate
    result = generate(story_id, corrections=corrections, dry_run=dry_run)
    # ... format output ...
```

### Optional Dependency Pattern (Playwright, mmdc)

Check availability at runtime:
```python
def _has_mmdc() -> bool:
    """Check if mermaid CLI is available."""
    result = subprocess.run(["which", "mmdc"], capture_output=True)
    return result.returncode == 0

# Usage:
if _has_mmdc():
    render_mermaid_to_png()
else:
    log.info("mmdc not available; write .mmd source only")
```

## Architecture Decisions (From ADR-0038)

### Why Pipeline Pattern (not Event-Driven)

Single trigger point (`story finish`) + clear data contracts. Event bus adds indirection for no benefit.

### Why Strategy Pattern (for format selection)

Story type → format mapping is declarative. New story types only need new strategy, not code changes.

### Why Fail Hard (no partial output)

Incomplete artifacts (e.g., PPTX without narratives) are worse than no artifacts. Developer sees failure, reruns with fixes.

### Why Optional Playwright/mmdc (graceful degradation)

Hard dependency on GUI tooling is a distribution problem. Let consumers choose extras; framework works without.

## Implementation Consistency Rules (From ADR-0038)

1. All demo code in `pennyfarthing-dist/src/pf/demo/`; no demo logic elsewhere
2. `DemoOrchestrator.generate(story_id) → OperationResult` is the only public API
3. Signal collection runs before session archival in `story_finish.py`
4. Classification is deterministic (rule-based only; no AI)
5. Only Generator invokes Claude; Assembler is pure mechanical Python
6. Output always to `sprint/demos/<story-id>/`; never `.session/` or temp dirs
7. All functions return `{success, data?, error?}`; no exceptions for business logic
8. Config is optional; sensible defaults work without `demo.yaml`

## Story Type Reference (Classification Targets)

| Type | Indicators | Artifacts |
|------|------------|-----------|
| **UI** | Keywords: "screen", "button", "layout", "form"; Extensions: `.tsx`, `.jsx`, `.css` | Screenshots + Slide Deck + Demo Script |
| **Backend** | Keywords: "API", "endpoint", "query", "database"; Extensions: `.rs`, `.py`, `.go`, `.java` | Diagrams + Narrative + Demo Script |
| **Infrastructure** | Keywords: "infra", "deploy", "docker", "k8s", "ci/cd"; Files: Dockerfile, terraform | Diagrams + Narrative + Demo Script |
| **Refactor** | Keywords: "refactor", "cleanup", "tech-debt"; No new features | Before/After + Narrative |
| **Bug Fix** | Keywords: "fix", "bug", "patch", "regression" | Problem + Narrative |

## Output Structure Reference

```
sprint/demos/
  └── 145-3/
      ├── deck.pptx                 # Main presentation (PPTX)
      ├── demo-script.md            # Step-by-step walkthrough
      ├── narrative.md              # ELI5 summary
      ├── diagram.mmd               # Mermaid source (backend/infra/refactor)
      ├── diagram.png               # Rendered diagram (optional, if mmdc available)
      ├── metadata.yaml             # Generated: {story_id, generated_at, classifier_decision, ...}
      └── screenshots/              # UI story only
          ├── screen-01-home.png
          ├── screen-02-feature.png
          └── manifest.json         # Screenshot coordinates/metadata
```

## Placeholder & Null Handling

**No Placeholders:** Every field in output is real or omitted.
- If review_findings missing: narrative doesn't mention "external feedback"
- If diagram not applicable: diagram.mmd not created
- If screenshots unavailable: skip screenshot slides in PPTX

**Graceful Absence:**
- diagram_source = None → skip mermaid generation
- screenshots = [] → skip UI slides
- review_findings = None → narrative still valid

## Testing Strategy (For Agents)

### Collector Tests
- Mock sprint YAML loader
- Mock git/gh CLI outputs
- Verify SignalBundle completeness
- Test with missing files (session, PR, findings)

### Classifier Tests
- Rule-based determinism: same input → same output
- Edge cases: ambiguous titles ("Refactor API UI")
- Config override behavior

### Generator Tests
- Prompt construction (all signals included)
- Token budget compliance
- Corrections workflow (previous output + corrections input)
- Multi-pass for 30+ slides

### Assembler Tests
- PPTX generation (non-corrupt file)
- Mermaid rendering (mmdc available vs missing)
- Screenshot embedding (Playwright mocks)
- File output structure matches spec

### Integration Tests
- End-to-end: Collector → Classifier → Generator → Assembler
- story_finish hook integration
- CLI command parsing and routing
- Config loading and override behavior

## Known Unknowns & Open Questions

1. **Claude API Pricing:** Multi-pass generation for 30+ slide decks may be expensive. Monitor and document.
2. **Screenshot Timing:** Playwright requires runnable app. How do we detect app readiness? (Scope: Phase 2)
3. **Diagram Complexity:** Mermaid syntax limits on very large architectures. Test with actual backend stories.
4. **PDF Export (Phase 2):** PPTX works for MVP; PDF via LibreOffice or weasyprint later.
5. **Playwright Installation:** Not a hard dependency; consumers choose. Document in setup guides.

## Acceptance Criteria Mapping

| AC | Coverage | Stories |
|----|----------|---------|
| Auto-collect story signals on completion | 145-1 | Collector integration with story_finish |
| Classification-based format selection | 145-2 | Classifier rules → strategy mapping |
| ELI5 content generation via Claude | 145-3 | Generator prompt + multi-pass |
| Demo script generation per story type | 145-4 | Script formatting per type |
| PPTX slide deck assembly | 145-5 | python-pptx integration |
| Mermaid diagram generation + optional rendering | 145-6 | Mermaid syntax + mmdc fallback |
| Pipeline entry point + orchestration | 145-7 | DemoOrchestrator.generate() + CLI |

---

**Last Updated:** 2026-03-12
**Author:** Orchestrator Research
**Status:** Epic context complete; ready for story-level breakdown.
