# Benchmark Version Tagging Plan

## Problem

Pipeline replay runs don't record which version of PF (or BMAD) produced them. When we change agent definitions (e.g., adding the edge case hunter to reviewer), we can't distinguish runs made before vs after the change. We need version tagging to track PF-against-PF improvement over time.

## What to Record

Each run's metadata should include:

```yaml
framework_version:
  commit: "46530ef92..."       # pennyfarthing repo HEAD at run time
  semver: "12.7.0"             # from pyproject.toml
  tag: "post-edge-hunter"      # optional human label
  agent_hashes:                # SHA256 of agent .md files used in run
    tea: "abc123..."
    dev: "def456..."
    reviewer: "ghi789..."
```

The `agent_hashes` field is the key differentiator — semver won't bump for every agent tweak, but hashing the actual agent files captures exactly what the pipeline saw.

## Part 1: Mark Runs Moving Forward

### 1a. Collect version info at run time

In `run_pipeline()` (pipeline_replay.py), before running phases:

```python
import hashlib

def _framework_version(project_dir: Path) -> dict:
    pf_repo = project_dir / "pennyfarthing"
    commit = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=pf_repo
    ).decode().strip()

    version_file = pf_repo / "pennyfarthing-dist" / "pyproject.toml"
    semver = re.search(r'version = "(.+?)"', version_file.read_text()).group(1)

    # Hash each agent definition used in the scenario phases
    agents_dir = pf_repo / "pennyfarthing-dist" / "agents"
    agent_hashes = {}
    for role in ["tea", "dev", "reviewer"]:
        agent_file = agents_dir / f"{role}.md"
        if agent_file.exists():
            agent_hashes[role] = hashlib.sha256(
                agent_file.read_bytes()
            ).hexdigest()[:12]

    return {
        "commit": commit[:12],
        "semver": semver,
        "agent_hashes": agent_hashes,
    }
```

### 1b. Store in pipeline.yaml

Add `framework_version` to the metadata written by `save_result()`. It lands in `pipeline.yaml` alongside existing fields (scenario_id, theme, model, timestamp).

### 1c. Store in majority_vote.yaml

The judge scoring step should copy `framework_version` from `pipeline.yaml` into `majority_vote.yaml` so comparison tools don't need to cross-reference files.

### 1d. For BMAD runs

Same pattern but hash the BMAD template files instead:

```python
def _bmad_version(bmad_root: Path) -> dict:
    commit = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=bmad_root
    ).decode().strip()

    return {
        "commit": commit[:12],
        "source": "BMAD-METHOD",
    }
```

## Part 2: Migrate Existing Runs

### 2a. Determine framework version for existing runs

All existing PF runs were made before the edge hunter change. The version can be reconstructed:

- **dpgd-116 themed runs** (firefly, dune, etc.): Made during peloton benchmarking. The pennyfarthing commit at that time can be recovered from git log timestamps cross-referenced with run timestamps.
- **dpgd-116 control runs**: Same era as themed runs.
- **dpgd-117 control runs**: Made during story 142-5 work.

### 2b. Migration script

```python
"""Backfill framework_version into existing pipeline.yaml files."""

import yaml
from pathlib import Path

RESULTS = Path("internal/results/pipeline-replay")
DEFAULT_VERSION = {
    "commit": "pre-edge-hunter",
    "semver": "12.7.0",
    "tag": "baseline-pre-edge-hunter",
    "agent_hashes": {},  # not recoverable retroactively
}

for pipeline_yaml in RESULTS.rglob("pipeline.yaml"):
    data = yaml.safe_load(pipeline_yaml.read_text())
    if "framework_version" not in data:
        data["framework_version"] = DEFAULT_VERSION
        pipeline_yaml.write_text(yaml.dump(data, default_flow_style=False))
        print(f"  Backfilled: {pipeline_yaml}")
```

### 2c. Backfill majority_vote.yaml

Same pattern — add `framework_version` to each existing majority_vote.yaml.

## Comparison Workflow

With version tagging in place, `pf benchmark replay compare` gains a new dimension:

```
pf benchmark replay compare dpgd-116 --group-by framework_version
```

Output:
```
Framework Version     | Runs | Median | Mean  | StdDev
pre-edge-hunter       |   11 |  40.5% | 48.9% |  15.2
post-edge-hunter      |    5 |  54.1% | 52.3% |   8.7
```

This lets us track whether changes to PF agents actually improve detection rates.

## Implementation Order

1. Migration script (backfill existing runs) — 30 min
2. `_framework_version()` helper in pipeline_replay.py — 30 min
3. Wire into `run_pipeline()` and `save_result()` — 30 min
4. Wire into judge scoring — 15 min
5. Update `compare` command to group by version — 1 hr
