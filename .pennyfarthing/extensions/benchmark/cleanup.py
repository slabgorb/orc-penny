"""Results maintenance — detect and fix common issues in benchmark results.

Usage:
    pf benchmark cleanup [--results-dir DIR] [--execute]
"""

from __future__ import annotations

import shutil
from pathlib import Path

import click
import yaml


def register(parent):
    @parent.command("cleanup")
    @click.option(
        "--results-dir",
        default=None,
        type=click.Path(exists=True),
        help="Pipeline replay results directory",
    )
    @click.option("--execute", is_flag=True, help="Apply fixes (default is dry-run)")
    def cleanup(results_dir, execute):
        """Detect and fix issues in benchmark results (dry-run by default)."""
        base = Path(results_dir) if results_dir else Path.cwd() / "internal" / "results" / "pipeline-replay"

        if not base.exists():
            click.echo(f"Results directory not found: {base}", err=True)
            raise SystemExit(1)

        mode = "EXECUTE" if execute else "DRY-RUN"
        click.echo(f"=== Benchmark Cleanup ({mode}) ===")
        click.echo(f"  Directory: {base}")
        click.echo()

        issues = []

        # 1. Detect double-nested runs (run-N/run-N/*)
        issues += _detect_nested_runs(base)

        # 2. Detect rate-limited runs
        issues += _detect_rate_limited(base)

        # 3. Detect runs without any score file
        issues += _detect_unscored(base)

        if not issues:
            click.echo("No issues found.")
            return

        click.echo(f"Found {len(issues)} issue(s):\n")
        for issue in issues:
            click.echo(f"  [{issue['type']}] {issue['path']}")
            click.echo(f"    {issue['description']}")
            if issue.get("action"):
                click.echo(f"    Action: {issue['action']}")

            if execute and issue.get("fix"):
                issue["fix"]()
                click.echo("    -> Applied")

        if not execute:
            click.echo(f"\nRe-run with --execute to apply fixes.")

    return cleanup


def _detect_nested_runs(base: Path) -> list[dict]:
    """Find run dirs that contain another run dir (save_result double-nesting bug)."""
    issues = []
    for scenario_dir in sorted(base.iterdir()):
        if not scenario_dir.is_dir():
            continue
        for theme_dir in sorted(scenario_dir.iterdir()):
            if not theme_dir.is_dir() or theme_dir.name.startswith("_"):
                continue
            for run_dir in sorted(theme_dir.iterdir()):
                if not run_dir.is_dir() or not run_dir.name.startswith("run-"):
                    continue
                # Check if this run dir contains another run dir
                nested = [
                    d for d in run_dir.iterdir()
                    if d.is_dir() and d.name.startswith("run-")
                ]
                for nested_dir in nested:
                    def _fix(src=nested_dir, dst=run_dir):
                        # Move contents up one level
                        for item in src.iterdir():
                            target = dst / item.name
                            if not target.exists():
                                shutil.move(str(item), str(target))
                        if not any(src.iterdir()):
                            src.rmdir()

                    issues.append({
                        "type": "nested-run",
                        "path": str(nested_dir.relative_to(base)),
                        "description": f"Double-nested run dir inside {run_dir.name}",
                        "action": f"Move contents to {run_dir.relative_to(base)}",
                        "fix": _fix,
                    })
    return issues


def _detect_rate_limited(base: Path) -> list[dict]:
    """Find runs that were rate-limited (contain 'out of extra usage' or similar)."""
    issues = []
    rate_limit_markers = [
        "out of extra usage",
        "rate_limited",
        "rate limit",
        "overloaded",
    ]

    for scenario_dir in sorted(base.iterdir()):
        if not scenario_dir.is_dir():
            continue
        for theme_dir in sorted(scenario_dir.iterdir()):
            if not theme_dir.is_dir() or theme_dir.name.startswith("_"):
                continue
            for run_dir in sorted(theme_dir.iterdir()):
                if not run_dir.is_dir() or not run_dir.name.startswith("run-"):
                    continue

                # Check text output files for rate limit markers
                for txt_file in run_dir.glob("*-output.txt"):
                    try:
                        content = txt_file.read_text().lower()
                        for marker in rate_limit_markers:
                            if marker in content:
                                rejected_dir = theme_dir / "_rejected"

                                def _fix(src=run_dir, dst=rejected_dir):
                                    dst.mkdir(exist_ok=True)
                                    shutil.move(str(src), str(dst / src.name))

                                issues.append({
                                    "type": "rate-limited",
                                    "path": str(run_dir.relative_to(base)),
                                    "description": f"Rate-limited run (found '{marker}' in {txt_file.name})",
                                    "action": f"Move to {rejected_dir.relative_to(base)}/",
                                    "fix": _fix,
                                })
                                break
                        else:
                            continue
                        break
                    except Exception:
                        continue
    return issues


def _detect_unscored(base: Path) -> list[dict]:
    """Find runs with no score.yaml or majority_vote.yaml."""
    issues = []
    for scenario_dir in sorted(base.iterdir()):
        if not scenario_dir.is_dir():
            continue
        for theme_dir in sorted(scenario_dir.iterdir()):
            if not theme_dir.is_dir() or theme_dir.name.startswith("_"):
                continue
            for run_dir in sorted(theme_dir.iterdir()):
                if not run_dir.is_dir() or not run_dir.name.startswith("run-"):
                    continue
                has_score = (run_dir / "score.yaml").exists()
                has_mv = (run_dir / "majority_vote.yaml").exists()
                has_pipeline = (run_dir / "pipeline.yaml").exists()
                if has_pipeline and not has_score and not has_mv:
                    issues.append({
                        "type": "unscored",
                        "path": str(run_dir.relative_to(base)),
                        "description": "Run has pipeline.yaml but no score — needs judging",
                        "action": None,
                        "fix": None,
                    })
    return issues
