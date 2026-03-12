"""Regenerate the benchmark visualization dashboard.

Usage:
    pf benchmark viz [--results-dir DIR]
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import click


def register(parent):
    @parent.command("viz")
    @click.option(
        "--results-dir",
        default=None,
        type=click.Path(exists=True),
        help="Pipeline replay results directory",
    )
    @click.option(
        "--themes-dir",
        default=None,
        type=click.Path(exists=True),
        help="Theme YAML directory",
    )
    @click.option(
        "--html-file",
        default=None,
        type=click.Path(),
        help="Dashboard HTML file to embed data into",
    )
    @click.option(
        "--json-output",
        default=None,
        type=click.Path(),
        help="Output JSON file path",
    )
    def viz(results_dir, themes_dir, html_file, json_output):
        """Regenerate the benchmark visualization dashboard."""
        script = Path.cwd() / "scripts" / "benchmark-viz-data.py"
        if not script.exists():
            click.echo(f"Script not found: {script}", err=True)
            raise SystemExit(1)

        args = [sys.executable, str(script)]
        if results_dir:
            args += ["--results-dir", results_dir]
        if themes_dir:
            args += ["--themes-dir", themes_dir]
        if html_file:
            args += ["--html-file", html_file]
        if json_output:
            args += ["--json-output", json_output]

        result = subprocess.run(args, cwd=Path.cwd())
        raise SystemExit(result.returncode)

    return viz
