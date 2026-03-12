---
parent: context-epic-144.md
workflow: tdd
---

# Story 144-1: Deviation Format Spec and Gate Validation Upgrade

## Business Context

This is the foundational story for Epic 144. Everything downstream — updated agent definitions (144-2), the AC-completion gate (144-3), the Architect phases (144-6, 144-7), and the wired TDD workflow (144-9) — depends on the format this story defines.

The core problem: the `## Design Deviations` section in session files is a convention, not a contract. Agents write whatever they write, gate checks for existence only, and the pipeline accepts it. When external reviewers find issues the pipeline missed (PR #50: 13+6 findings, PR #52: 8 findings), someone has to retroactively document deviations across all affected session archives. That's a symptom of goodwill-based documentation — Principle 6 says gates, not goodwill.

This story does two things:

1. **Creates the authoritative format spec** at `pennyfarthing-dist/guides/deviation-format.md` — the single document that agents, gates, and the Architect all reference. Six required fields. Three agent-specific subsections. A worked example that agents can model. Once this exists, there's one place to look for "what does a deviation entry look like."

2. **Upgrades `deviations-logged` from existence check to format validation** — the gate no longer accepts "there's something in this section." It checks each entry for all six fields and fails with a specific, actionable recovery message naming the missing field(s). Agents get exactly what they need to fix the entry and re-trigger without restarting the phase.

The boss's benefit is downstream: when 144-7 (Architect spec-reconcile) produces the definitive deviation manifest, every entry in it will be in this format — self-contained, no external lookups needed. This story is what makes that possible.

## Technical Guardrails

**Repo:** `pennyfarthing` (not the orchestrator). All deliverables go in `pennyfarthing/pennyfarthing-dist/`.

**Files to modify:**
- `pennyfarthing-dist/gates/deviations-logged.md` — upgrade existing gate from existence check to 6-field format validation

**Files to create:**
- `pennyfarthing-dist/guides/deviation-format.md` — new guide; the canonical deviation entry format specification

**Files to leave alone in this story:**
- `pennyfarthing-dist/workflows/tdd.yaml` — gate wiring happens in 144-9, not here
- `pennyfarthing-dist/agents/tea.md` and `dev.md` — agent definition updates happen in 144-2
- `pennyfarthing-dist/gates/deviations-audited.md` — Reviewer-side gate; separate from this story
- `pennyfarthing-dist/gates/ac-completion.md` — does not exist yet; created in 144-3

**Gate file format:** Read `pennyfarthing-dist/schemas/gate-schema.md` and the guides in `pennyfarthing-dist/guides/gates.md` before editing the gate file. The existing `deviations-logged.md` uses `<gate>`, `<purpose>`, `<arguments>`, `<pass>`, `<fail>` XML structure — preserve that structure.

**Guide file conventions:** New guides in `pennyfarthing-dist/guides/` are plain markdown. Check existing guides for length and style norms. The format spec guide should be prescriptive and example-heavy — agents read it and must be able to produce conforming entries without re-reading the gate error messages.

**Deviation format is the contract:** The 6-field format defined here becomes the machine-readable contract that the upgraded gate enforces and that 144-2, 144-6, 144-7 all reference. Do not abbreviate fields, rename fields, or change their order mid-story. If a design decision arises about the format, document it as a deviation.

**NFR-5 (machine-parseable):** The format must be parseable by regex or a simple line parser. Strict markdown structure: bullet-prefixed description, indented field lines. No prose-only blocks embedded in entries.

**NFR-4 (idempotent gate):** The upgraded gate must produce the same result on repeated runs against the same session file. No side effects.

## Scope Boundaries

**In scope:**
- Create `pennyfarthing-dist/guides/deviation-format.md` with: 6-field format definition, agent-specific subsection names, worked example, "No deviations from spec." handling, and forward-impact value set (none / minor / breaking)
- Upgrade `pennyfarthing-dist/gates/deviations-logged.md` to validate each entry for all 6 fields, not just section existence
- Gate fails with specific field-level recovery message: "Entry '{description}' missing: {field list}"
- Gate passes for "No deviations from spec." (explicit no-deviation is still valid)
- Gate fails with distinct message when `## Design Deviations` section is absent entirely: "Missing '## Design Deviations' section in session file"
- Gate remains idempotent — re-runs on the same file produce the same result
- Gate checks per-agent subsection (`### TEA (test design)` or `### Dev (implementation)`) as it does today — the AGENT argument is preserved

**Out of scope:**
- Wiring `deviations-logged` into `tdd.yaml` — that is 144-9
- Updating TEA or Dev agent definitions to mandate logging — that is 144-2
- Creating `deviations-audited.md` changes — that gate is for Reviewer, separate concern
- Creating `ac-completion.md` — that is 144-3
- Creating Architect phase gates (`spec-check-pass`, `spec-reconcile-pass`) — those are 144-6 and 144-7
- Updating the context schema `## Assumptions` section — that is 144-5
- Any changes to `tdd.yaml`, `tdd-tandem.yaml`, or other workflow files
- Severity scoring logic or automated classification — the format specifies `minor | major` as agent-assigned values; no automated assignment

## AC Context

### AC-1: Guide at `deviation-format.md` specifies 6 required fields

**What must be true:** `pennyfarthing-dist/guides/deviation-format.md` exists and clearly defines these six fields in order:
1. `Spec source` — document path and section/AC reference (e.g., `context-story-5-1.md, AC-3`)
2. `Spec text` — the original specification, quoted verbatim
3. `Implementation` — what was actually built or tested instead
4. `Rationale` — why the deviation was made
5. `Severity` — exactly one of: `minor` or `major`
6. `Forward impact` — exactly one of: `none`, `minor`, or `breaking`, followed by affected story IDs and their broken assumptions when not `none`

**Edge cases:**
- Field names must match exactly as listed — the gate uses these names for its checks. The guide and gate must agree on spelling.
- `Forward impact: none` is a complete value — no story IDs needed when there is no impact.
- `Spec text` requires quotation marks around the original text. The guide should show this explicitly.
- The field value for `Forward impact` when not `none` takes the form: `minor — Story 5-2 assumes FieldRef segments are iterable`. The guide should show the em-dash pattern.

**How a test verifies this:** Check that the file exists and contains all six field names. Optionally parse the worked example and verify all fields are present.

### AC-2: Guide specifies three agent-specific subsections

**What must be true:** The guide defines three subsection headings that organize deviation entries by phase:
- `### TEA (test design)` — entries from TEA during RED phase
- `### Dev (implementation)` — entries from Dev during GREEN phase
- `### Architect (reconcile)` — entries from Architect during spec-reconcile phase

**Edge cases:**
- The guide should make clear these are subsections under `## Design Deviations` in the session file, not standalone headings.
- The Architect subsection is defined here even though 144-7 creates the spec-reconcile phase — the format spec is the authoritative definition. 144-7 depends on this story knowing the `### Architect (reconcile)` heading name.
- The guide should specify that each agent populates only their own subsection. TEA does not write under `### Dev (implementation)`.

**How a test verifies this:** All three heading strings are present in the guide.

### AC-3: Gate passes for entries with all 6 fields

**What must be true:** When the `deviations-logged` gate runs against a session file that has a `## Design Deviations` section with a valid agent subsection heading and one or more entries where each entry has all 6 fields, the gate returns `status: pass`.

**Edge cases:**
- Multiple entries must all pass individually — one valid entry and one invalid entry in the same section means the gate fails.
- Entries do not need to be in any particular order of fields — but the gate must recognize all 6 regardless of order.
- The AGENT argument determines which subsection is checked (`tea` → `### TEA (test design)`, `dev` → `### Dev (implementation)`). The gate does not validate the other agent's subsection.
- Trailing whitespace or minor formatting variations should not cause a false fail — the gate is validating field presence, not whitespace.

**How a test verifies this:** Construct a session file with a well-formed entry. Run gate with AGENT=tea. Expect pass.

### AC-4: Gate fails with field-level recovery message for incomplete entries

**What must be true:** When an entry is present but missing one or more of the 6 required fields, the gate fails with a specific message that names the entry (by its short description) and the missing field(s).

**Format:** `"Entry '{description}' missing: {field list}"`

Example: `"Entry 'No ! as NOT alternative' missing: Forward impact"`

**Edge cases:**
- If multiple fields are missing, all missing fields appear in the field list (comma-separated or listed).
- The `{description}` in the error message should be the text from the `- **{short description}**` bullet, not a line number or generic label.
- If the entry has no description (malformed bullet), the gate should still produce a useful message — fall back to "Entry at line N" or similar rather than crashing.
- The recovery message should be enough for the agent to fix the entry and re-trigger without restarting the phase (NFR-1).

**How a test verifies this:** Construct a session file with a deviation entry missing "Forward impact". Run gate. Check that the fail message contains both the entry description and "Forward impact".

### AC-5: Gate auto-passes for explicit "No deviations from spec."

**What must be true:** When the `## Design Deviations` section contains the text "No deviations from spec." (or contains the agent subsection with "No deviations from spec." in it), the gate passes without requiring any 6-field entries.

**Edge cases:**
- The exact phrase matters — "No deviations" alone or "no deviations from spec" (lowercase) should be treated equivalently; the guide should specify the canonical phrase but the gate should be case-insensitive.
- If the section has "No deviations from spec." AND one or more entries that fail validation, the gate should still validate the entries — the phrase does not suppress validation of other content.
- An empty section (heading present, no content) is NOT the same as "No deviations from spec." — an empty section is a fail.

**How a test verifies this:** Construct a session file where the agent subsection contains only "- No deviations from spec." Run gate. Expect pass.

### AC-6: Gate fails with distinct message when section is absent

**What must be true:** When the session file has no `## Design Deviations` section at all, the gate fails with:

`"Missing '## Design Deviations' section in session file"`

This is a distinct failure mode from "section present but entries incomplete" — the message must be different from the field-level recovery message in AC-4.

**Edge cases:**
- A section with only a subsection heading and no content still counts as present — this case falls into AC-5's empty-section-is-fail rule, not this rule.
- The check for section absence should happen before checking subsection headings or entry content.
- The AGENT argument is irrelevant when the section is entirely absent — the same message applies regardless of whether AGENT=tea or AGENT=dev.

**How a test verifies this:** Construct a session file with no `## Design Deviations` heading. Run gate with any AGENT value. Check the fail message matches exactly.

### AC-7: Gate is idempotent

**What must be true:** Running the gate twice on the same session file produces the same result both times. The gate has no side effects — it does not modify the session file, write state files, or change behavior based on prior runs.

**Edge cases:**
- This is a property test, not a functional test — verify there are no writes or mutations in the gate implementation.
- The gate reads only the session file and produces output — any other file I/O is a violation of this AC.

**How a test verifies this:** Run gate twice consecutively on the same session file. Compare outputs — they must be identical.

## Assumptions

This is the first story in Epic 144. No other 144-series stories are complete; none are assumed to have delivered anything this story depends on.

Within the epic, other stories depend on this one (not the other way around):
- 144-2 depends on the 6-field format defined here (agent definitions reference it)
- 144-3 is independent of the deviation format but consistent with it
- 144-6 and 144-7 depend on the format definition existing in the guide
- 144-9 depends on the gate upgrade being complete before wiring

**This story assumes:**

- The existing `pennyfarthing-dist/gates/deviations-logged.md` file is the starting point. Its XML structure (`<gate>`, `<purpose>`, `<arguments>`, `<pass>`, `<fail>`) is preserved and extended — not replaced with a different schema.
- The AGENT argument contract (`tea` or `dev`) is preserved. The gate remains dual-purpose — same file, different subsection checked based on AGENT value.
- The `## Design Deviations` session section already exists as a convention. This story formalizes the format; it does not invent the section name.
- The `pennyfarthing-dist/guides/` directory exists and accepts new markdown guide files without build changes.
- Epic 143 (Native Subagent Migration) is complete for stories 143-1 through 143-8. The subagent infrastructure does not affect this story — 144-1 is pure gate/guide work, no subagent invocations.
- The gate model remains `haiku` as specified in the existing gate file. No model change is part of this story.
