# Story: Complete Cross-Role Benchmark Implementation

**ID:** BENCH-CR-001
**Title:** Implement --as flag across benchmark infrastructure
**Author:** Granny Weatherwax (via review)
**Created:** 2026-01-03
**Assignee:** Jesse Pinkman (Dev)
**Status:** Ready for Development

---

## Context

The `/solo` command documentation was updated to support `--as <role>` for cross-role benchmarking. This allows running any character as any role (e.g., Prospero the SM doing dev work).

**Use Case:** Research whether persona traits affect performance independent of role-specific training.

**Example:**
```bash
/solo shakespeare:prospero --as dev --scenario django-10554
```

**Problem:** Only the documentation was updated. The actual implementation doesn't exist yet.

---

## Scope

### Files Requiring Changes

| Priority | File | Current State | Required Change |
|----------|------|---------------|-----------------|
| **P0** | `scripts/solo-runner.sh` | Parses `theme:agent` as role lookup | Accept `--as` arg, search by character name |
| **P0** | `pennyfarthing-dist/commands/benchmark.md` | Validates agent as role name only | Support `--as` in spawned `/solo` calls |
| **P1** | `scripts/generate-leaderboard.sh` | Glob pattern `*-${ROLE}/` misses cross-role dirs | Handle `theme-character-as-role/` pattern |
| **P1** | `pennyfarthing-dist/templates/LEADERBOARD.schema.yaml` | Only has `role` field | Add `source_role`, `effective_role`, `cross_role` |
| **P2** | `pennyfarthing-dist/commands/benchmark-control.md` | Wrapper, inherits from benchmark | Verify cross-role baseline strategy |

---

## Technical Decisions (Confirmed)

### Decision 1: Baseline Strategy - CONFIRMED

**Decision:** Cross-role tests compare against the **effective role's baseline**.

`shakespeare:prospero --as dev` compares against `control:dev` baseline.

**Rationale:** We're testing if personality affects task performance. The task (dev) is the same, so the baseline should be the same. No new baseline infrastructure needed.

### Decision 2: solo-runner.sh Interface - CONFIRMED

**Decision:** Use positional argument with `--as` flag.

```bash
./solo-runner.sh shakespeare:prospero django-10554 /tmp --as dev
```

**Rationale:** Minimal change, backwards compatible. Existing calls continue to work.

### Decision 3: Leaderboard Presentation - CONFIRMED

**Decision:** Cross-role results appear on the **same leaderboard** as standard role results.

If Prospero-as-dev scores 90, he ranks alongside Puck (Shakespeare's native dev). Add indicator to show cross-role entries (e.g., "Prospero (as dev)" or `cross_role: true` in data).

**Rationale:** The comparison is valid - both performed the same task. Separating them would fragment the data.

---

## Implementation Plan

### Phase 1: solo-runner.sh (P0)

1. **Parse new argument:**
   ```bash
   SPEC="$1"
   SCENARIO="$2"
   OUTPUT_DIR="${3:-/tmp/solo-results}"
   ROLE_OVERRIDE=""

   # Check for --as flag
   if [[ "$4" == "--as" && -n "$5" ]]; then
       ROLE_OVERRIDE="$5"
   fi
   ```

2. **Character lookup function:**
   ```bash
   find_character_in_theme() {
       local theme_file="$1"
       local query="$2"  # character name (case-insensitive)

       # Search all agents for matching character
       yq -r ".agents | to_entries[] | select(.value.character |
           test(\"$query\"; \"i\")) | .key" "$theme_file"
   }
   ```

3. **Conditional lookup:**
   ```bash
   if [[ -n "$ROLE_OVERRIDE" ]]; then
       # Query is a character name, find which agent has it
       CHARACTER_QUERY="${SPEC##*:}"
       SOURCE_ROLE=$(find_character_in_theme "$PERSONA_FILE" "$CHARACTER_QUERY")
       EFFECTIVE_ROLE="$ROLE_OVERRIDE"
   else
       # Standard: query is the role name
       SOURCE_ROLE="${SPEC##*:}"
       EFFECTIVE_ROLE="$SOURCE_ROLE"
   fi
   ```

4. **Update output path:**
   ```bash
   if [[ -n "$ROLE_OVERRIDE" ]]; then
       # Cross-role: theme-character-as-role
       CHARACTER_SLUG=$(echo "$CHARACTER" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
       OUTPUT_SUBDIR="${THEME}-${CHARACTER_SLUG}-as-${EFFECTIVE_ROLE}"
   else
       OUTPUT_SUBDIR="${THEME}-${EFFECTIVE_ROLE}"
   fi
   ```

5. **Update JSON output to include cross-role fields:**
   ```bash
   --arg source_role "$SOURCE_ROLE" \
   --arg effective_role "$EFFECTIVE_ROLE" \
   --argjson cross_role "${CROSS_ROLE:-false}" \
   ```

### Phase 2: benchmark.md (P0)

1. **Update argument parsing (Step 1):**
   - Accept `--as <role>` after theme/agent
   - Pass through to `/solo` invocation

2. **Update validation (Line 87):**
   - If `--as` present, agent can be a character name
   - Validate `--as` value is a valid role

3. **Update solo spawn (Step 5, Line 223):**
   ```
   /solo {theme}:{agent_or_character} --scenario {scenario_name} [--as {role}]
   ```

### Phase 3: generate-leaderboard.sh (P1)

1. **Update glob pattern (Line 66):**
   ```bash
   # Old: for dir in "$BENCHMARK_DIR"/*-"$ROLE"/
   # New: Include both standard and cross-role directories
   for dir in "$BENCHMARK_DIR"/*-"$ROLE"/ "$BENCHMARK_DIR"/*-as-"$ROLE"/; do
   ```

2. **Extract cross-role metadata:**
   ```bash
   CROSS_ROLE=$(yq -r '.agent.cross_role // false' "$dir/summary.yaml")
   SOURCE_ROLE=$(yq -r '.agent.source_role // .agent.role' "$dir/summary.yaml")
   ```

3. **Add indicator to output:**
   - If cross-role, append "(as dev)" to character name in table

### Phase 4: LEADERBOARD.schema.yaml (P1)

Add to rankings columns:
```yaml
- name: Cross-Role
  type: boolean
  optional: true
  description: "True if character is performing outside their native role"

- name: Source Role
  type: string
  optional: true
  description: "Character's native role (e.g., sm for Prospero)"
```

---

## Acceptance Criteria

### Must Have
- [ ] `./solo-runner.sh shakespeare:prospero django-10554 /tmp --as dev` executes successfully
- [ ] Output saved to `results/benchmarks/django-10554/shakespeare-prospero-as-dev/`
- [ ] summary.yaml includes `cross_role: true`, `source_role: sm`, `effective_role: dev`
- [ ] `/benchmark shakespeare prospero --as dev --scenario django-10554` works
- [ ] Cross-role results appear in leaderboard alongside standard results

### Should Have
- [ ] Leaderboard indicates cross-role entries (e.g., "Prospero (as dev)")
- [ ] `/benchmark` scenario discovery filters by effective_role, not source_role
- [ ] Error messages guide users on correct cross-role syntax

### Nice to Have
- [ ] OCEAN analysis includes cross-role correlation insights
- [ ] Summary report compares character's cross-role vs native-role performance

---

## Test Cases

```bash
# Test 1: Basic cross-role execution
./scripts/solo-runner.sh shakespeare:prospero tdd-shopping-cart /tmp/test --as dev
# Expected: Runs with Prospero persona, dev task, saves to shakespeare-prospero-as-dev/

# Test 2: Character name matching (case insensitive)
./scripts/solo-runner.sh shakespeare:PROSPERO tdd-shopping-cart /tmp/test --as dev
# Expected: Works (finds Prospero despite caps)

# Test 3: Partial character match
./scripts/solo-runner.sh discworld:granny tdd-shopping-cart /tmp/test --as dev
# Expected: Finds "Granny Weatherwax" from reviewer role

# Test 4: Invalid character
./scripts/solo-runner.sh shakespeare:hamlet tdd-shopping-cart /tmp/test --as dev
# Expected: Error - "Character 'hamlet' not found in shakespeare theme"

# Test 5: Invalid role override
./scripts/solo-runner.sh shakespeare:prospero tdd-shopping-cart /tmp/test --as wizard
# Expected: Error - "Invalid role 'wizard'. Must be: sm, dev, reviewer, architect, tea, pm"

# Test 6: Benchmark command integration
/benchmark shakespeare prospero --as dev --scenario tdd-shopping-cart --runs 2
# Expected: 2 runs executed, compared against control:dev baseline
```

---

## Notes for Jesse

Yo Jesse, here's the deal:

1. **Start with solo-runner.sh** - that's the actual execution engine
2. **The character lookup is the tricky bit** - you need to search ALL agents in the theme to find where a character lives
3. **Don't break backwards compatibility** - existing `theme:role` syntax must keep working
4. **Use the existing baseline** - `control:dev` for all dev tasks, regardless of who's doing them

The solo.md changes Ponder already made tell you WHAT should happen. You need to make it ACTUALLY happen.

Yeah, science!

---

## Review Notes (Granny Weatherwax)

I don't do nice. I do RIGHT.

This story exists because someone thought writing documentation was the same as writing code. It's not. Documentation is a PROMISE. Now you have to KEEP it.

The acceptance criteria are non-negotiable. The test cases are minimum coverage. If you're not sure, ASK before you code yourself into a corner.

*Adjusts hat and departs*
