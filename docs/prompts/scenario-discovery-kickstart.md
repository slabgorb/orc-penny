# Scenario Discovery Pilot — Kickstart Prompt

Paste this into a fresh session to get started.

---

## Prompt

I want to run the scenario-discovery workflow to create our first benchmark scenario from a real finding.

**Context:** We built a `scenario-discovery` stepped workflow (`pf workflow show scenario-discovery`) that uses party mode to discover which personas catch what, then codifies observations into formal benchmark scenarios. The scientific basis is PersonaGym (EMNLP 2025), BARS behavioral anchoring, and MBTI-in-Thoughts persona persistence verification.

**Starting point:** The Rust lang-review gate (`pennyfarthing-dist/gates/lang-review/rust.md`, on the develop branch) has 15 self-review checks sourced from real orc-ax findings. I want to use check #8 (`#[derive(Deserialize)]` bypassing validation) as our first scenario because:
- It's a real bug pattern we've seen in production
- It's subtle enough that not all personas will catch it
- It has a clear ground truth (use `#[serde(try_from)]` for types with validating constructors)
- It touches security (bypassing validation = trust boundary violation)

**What I want:**
1. Start the workflow: `pf workflow start scenario-discovery`
2. For step 1 (Source), the source type is `lang-review`, reference is `rust.md check #8`
3. For step 2 (Prepare), write a ~50-line Rust code snippet that contains this vulnerability plus 1-2 red herrings
4. For step 3 (Party), run party mode with dev, reviewer, tea, and architect — I want to watch how Firefly characters respond
5. Continue through steps 4-7 to codify and validate the scenario

This should produce our first scenario built entirely from real findings with empirically-grounded BARS anchors from observed persona behavior.
