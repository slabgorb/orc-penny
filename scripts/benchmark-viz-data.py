#!/usr/bin/env python3
"""
Extract benchmark data from pipeline-replay results and theme metadata
into a single JSON blob for the visualization dashboard.

Usage: python3 scripts/benchmark-viz-data.py
Output: internal/results/benchmark-viz-data.json
"""

import argparse
import json
import math
import os
import sys
from pathlib import Path

# pyyaml may not be installed; try ruamel.yaml as fallback
try:
    import yaml
except ImportError:
    try:
        from ruamel.yaml import YAML
        _ruamel = YAML(typ='safe')
        class _YamlCompat:
            @staticmethod
            def safe_load(stream):
                return _ruamel.load(stream)
        yaml = _YamlCompat()
    except ImportError:
        print("ERROR: neither pyyaml nor ruamel.yaml is installed", file=sys.stderr)
        sys.exit(1)

ROOT = Path(__file__).resolve().parent.parent
RESULTS_DIR = ROOT / "internal" / "results" / "pipeline-replay"
THEMES_DIR = ROOT / "pennyfarthing" / "pennyfarthing-dist" / "personas" / "themes"
OUTPUT_FILE = ROOT / "internal" / "results" / "benchmark-viz-data.json"
HTML_FILE = ROOT / "internal" / "results" / "benchmark-dashboard.html"


def parse_args():
    parser = argparse.ArgumentParser(description="Extract benchmark data for visualization dashboard")
    parser.add_argument("--results-dir", type=Path, default=RESULTS_DIR, help="Pipeline replay results directory")
    parser.add_argument("--themes-dir", type=Path, default=THEMES_DIR, help="Theme YAML directory")
    parser.add_argument("--html-file", type=Path, default=HTML_FILE, help="Dashboard HTML file to embed data into")
    parser.add_argument("--json-output", type=Path, default=OUTPUT_FILE, help="Output JSON file path")
    return parser.parse_args()

# Map result directory names to theme YAML file names
THEME_FILE_MAP = {
    "the-west-wing": "west-wing",
}


def load_yaml(path: Path):
    """Load a YAML file, returning None on failure."""
    try:
        with open(path) as f:
            return yaml.safe_load(f)
    except Exception as e:
        print(f"  WARN: Could not load {path}: {e}", file=sys.stderr)
        return None


def extract_theme_metadata(theme_dir_name: str, themes_dir: Path = None) -> dict:
    """Extract metadata from a theme YAML file."""
    tdir = themes_dir or THEMES_DIR
    file_name = THEME_FILE_MAP.get(theme_dir_name, theme_dir_name)
    theme_path = tdir / f"{file_name}.yaml"
    data = load_yaml(theme_path)
    if not data:
        return {
            "name": theme_dir_name,
            "tier": None,
            "zeitgeist": None,
            "category": None,
            "dimensions": {},
            "ocean": {},
            "characters": {},
        }

    theme_block = data.get("theme", {})
    zeitgeist_block = data.get("zeitgeist", {})
    agents_block = data.get("agents", {})

    # Extract OCEAN for tea, dev, reviewer
    ocean = {}
    characters = {}
    for role in ["tea", "dev", "reviewer"]:
        agent = agents_block.get(role, {})
        characters[role] = agent.get("character", agent.get("shortName", ""))
        agent_ocean = agent.get("ocean", {})
        if agent_ocean:
            ocean[role] = {
                "O": agent_ocean.get("O", 3),
                "C": agent_ocean.get("C", 3),
                "E": agent_ocean.get("E", 3),
                "A": agent_ocean.get("A", 3),
                "N": agent_ocean.get("N", 3),
            }

    return {
        "name": theme_block.get("name", theme_dir_name),
        "tier": theme_block.get("tier"),
        "zeitgeist": zeitgeist_block.get("score"),
        "category": data.get("category"),
        "dimensions": theme_block.get("dimensions", {}),
        "ocean": ocean,
        "characters": characters,
    }


def extract_scenario(scenario_dir: Path, themes_dir: Path = None) -> dict:
    """Extract all data for a single scenario."""
    scenario_id = scenario_dir.name
    print(f"Processing scenario: {scenario_id}")

    themes_data = {}
    ground_truth = None  # Will be populated from first score.yaml

    for theme_dir in sorted(scenario_dir.iterdir()):
        if not theme_dir.is_dir():
            continue

        theme_name = theme_dir.name
        print(f"  Theme: {theme_name}")

        # Get theme metadata
        meta = extract_theme_metadata(theme_name, themes_dir=themes_dir)

        runs = []
        for run_dir in sorted(theme_dir.iterdir()):
            if not run_dir.is_dir() or not run_dir.name.startswith("run-"):
                continue

            # Prefer majority_vote.yaml when available
            mv_path = run_dir / "majority_vote.yaml"
            score_path = run_dir / "score.yaml"
            if mv_path.exists():
                score = load_yaml(mv_path)
                score_source = "majority_vote"
            else:
                score = load_yaml(score_path)
                score_source = "score"
            if not score:
                continue

            run_num = int(run_dir.name.split("-")[1])

            # Extract ground truth from findings (first time only)
            if ground_truth is None and "findings" in score:
                ground_truth = []
                for f in score["findings"]:
                    ground_truth.append({
                        "id": f["finding_id"],
                        "title": f["title"],
                        "weight": f["weight"],
                        "severity": f.get("severity", "important"),
                        "phase_ideal": f["phase_ideal"],
                    })

            # Per-finding details
            findings_detail = []
            caught_by_phase = {"tea": 0, "dev": 0, "reviewer": 0}
            for f in score.get("findings", []):
                caught = f.get("caught", False)
                caught_by = f.get("caught_by")
                findings_detail.append({
                    "finding_id": f["finding_id"],
                    "caught": caught,
                    "caught_by": caught_by,
                })
                if caught and caught_by in caught_by_phase:
                    caught_by_phase[caught_by] += 1

            # Determine model: check score, then pipeline.yaml, default "opus"
            pipeline_meta = load_yaml(run_dir / "pipeline.yaml")
            run_model = (
                score.get("model")
                or (pipeline_meta.get("model") if pipeline_meta else None)
                or "opus"
            )

            # Framework version metadata
            fw_version = score.get("framework_version")
            if not fw_version and pipeline_meta:
                fw_version = pipeline_meta.get("framework_version")

            run_entry = {
                "run_id": run_num,
                "model": run_model,
                "score_pct": score.get("score_pct", 0),
                "weighted_caught": score.get("weighted_caught", 0),
                "total_caught": score.get("total_caught", 0),
                "total_findings": score.get("total_findings", 0),
                "total_weight": score.get("total_weight", 0),
                "findings": findings_detail,
                "caught_by_phase": caught_by_phase,
                "score_source": score_source,
                "judge_version": score.get("judge_version", "v1"),
                "framework_version": fw_version,
            }
            if score_source == "majority_vote":
                run_entry["n_judges"] = score.get("n_judges", 1)
            runs.append(run_entry)

        if not runs:
            continue

        # Compute stats
        scores = [r["score_pct"] for r in runs]
        n = len(scores)
        mean = sum(scores) / n
        std = math.sqrt(sum((s - mean) ** 2 for s in scores) / n) if n > 1 else 0

        # Compute per-finding catch rates
        finding_catch_rates = {}
        for r in runs:
            for f in r["findings"]:
                fid = f["finding_id"]
                if fid not in finding_catch_rates:
                    finding_catch_rates[fid] = {"caught": 0, "total": 0, "caught_by": {}}
                finding_catch_rates[fid]["total"] += 1
                if f["caught"]:
                    finding_catch_rates[fid]["caught"] += 1
                    cb = f["caught_by"]
                    if cb:
                        finding_catch_rates[fid]["caught_by"][cb] = \
                            finding_catch_rates[fid]["caught_by"].get(cb, 0) + 1

        # Compute phase attribution (average across runs)
        total_catches = sum(
            sum(r["caught_by_phase"].values()) for r in runs
        )
        phase_pct = {}
        if total_catches > 0:
            phase_totals = {"tea": 0, "dev": 0, "reviewer": 0}
            for r in runs:
                for phase, count in r["caught_by_phase"].items():
                    phase_totals[phase] += count
            for phase, total in phase_totals.items():
                phase_pct[phase] = round(total / total_catches * 100, 1)

        # Detect pipeline type from phases in pipeline.yaml
        pipeline_type = "pf"
        if theme_name == "bmad":
            pipeline_type = "bmad"
        else:
            # Check first run's pipeline.yaml for phase count
            first_run_dir = sorted(
                d for d in theme_dir.iterdir()
                if d.is_dir() and d.name.startswith("run-")
            )[0] if runs else None
            if first_run_dir:
                pm = load_yaml(first_run_dir / "pipeline.yaml")
                if pm and "phases" in pm:
                    phases = list(pm["phases"].keys())
                    if len(phases) == 2 and "tea" not in phases:
                        pipeline_type = "bmad"

        # Collect distinct framework versions across runs
        fw_versions = set()
        for r in runs:
            fv = r.get("framework_version")
            if fv:
                tag = fv.get("tag") or fv.get("commit") or fv.get("source")
                if tag:
                    fw_versions.add(tag)

        themes_data[theme_name] = {
            "meta": meta,
            "pipeline": pipeline_type,
            "runs": runs,
            "stats": {
                "n": n,
                "mean": round(mean, 1),
                "std": round(std, 1),
                "min": round(min(scores), 1),
                "max": round(max(scores), 1),
            },
            "framework_versions": sorted(fw_versions),
            "finding_catch_rates": finding_catch_rates,
            "phase_attribution": phase_pct,
        }

    return {
        "scenario_id": scenario_id,
        "ground_truth": ground_truth or [],
        "total_weight": ground_truth[0].get("weight", 0) if ground_truth else 0,
        "themes": themes_data,
    }


def main():
    args = parse_args()
    results_dir = args.results_dir
    themes_dir = args.themes_dir
    output_file = args.json_output
    html_file = args.html_file

    print(f"Results dir: {results_dir}")
    print(f"Themes dir: {themes_dir}")

    scenarios = {}
    for scenario_dir in sorted(results_dir.iterdir()):
        if not scenario_dir.is_dir():
            continue
        scenario = extract_scenario(scenario_dir, themes_dir=themes_dir)
        if scenario["themes"]:
            # Fix total_weight from ground truth
            if scenario["ground_truth"]:
                scenario["total_weight"] = sum(
                    f["weight"] for f in scenario["ground_truth"]
                )
            scenarios[scenario["scenario_id"]] = scenario

    output = {
        "generated": str(Path(__file__).name),
        "scenarios": scenarios,
    }

    output_file.parent.mkdir(parents=True, exist_ok=True)
    with open(output_file, "w") as f:
        json.dump(output, f, indent=2)

    print(f"\nWrote {output_file}")
    print(f"Scenarios: {list(scenarios.keys())}")
    for sid, s in scenarios.items():
        print(f"  {sid}: {len(s['themes'])} themes, {len(s['ground_truth'])} findings")

    # Embed JSON into HTML file as fallback for file:// protocol
    if html_file.exists():
        import re
        html = html_file.read_text()
        json_str = json.dumps(output)
        # Find and replace the EMBEDDED_DATA assignment inside the try block
        marker_start = "EMBEDDED_DATA = "
        try_idx = html.find("try {")
        if try_idx < 0:
            print(f"WARN: Could not find try block in HTML file")
        else:
            assign_idx = html.find(marker_start, try_idx)
            if assign_idx < 0:
                print(f"WARN: Could not find EMBEDDED_DATA assignment in try block")
            else:
                # Find the semicolon after the assignment value
                val_start = assign_idx + len(marker_start)
                semi_idx = html.find(";", val_start)
                # But the JSON itself may contain semicolons, so we need to find
                # the matching end. Since the value is either a placeholder word
                # or a JSON object, find the end properly.
                if html[val_start:val_start+1] == '{':
                    # JSON object - find matching closing brace by counting
                    depth = 0
                    i = val_start
                    while i < len(html):
                        if html[i] == '{': depth += 1
                        elif html[i] == '}': depth -= 1
                        if depth == 0:
                            semi_idx = i + 1  # point past the }
                            break
                        i += 1
                else:
                    # Placeholder word - semicolon search is fine
                    pass
                new_html = html[:val_start] + json_str + ";" + html[semi_idx+1:]
                html_file.write_text(new_html)
                print(f"Embedded data into {html_file}")


if __name__ == "__main__":
    main()
