"""Statistical comparison of benchmark results across themes.

Usage:
    pf benchmark stats dpgd-116 [--results-dir DIR]
"""

from __future__ import annotations

import math
from pathlib import Path

import click
import yaml


def register(parent):
    @parent.command("stats")
    @click.argument("scenario_id")
    @click.option(
        "--results-dir",
        default=None,
        type=click.Path(exists=True),
        help="Base results directory",
    )
    @click.option("--save", is_flag=True, help="Save comparison-stats.yaml alongside results")
    def stats(scenario_id, results_dir, save):
        """Statistical comparison of pipeline results across themes."""
        base = Path(results_dir) if results_dir else Path.cwd() / "internal" / "results" / "pipeline-replay"
        scenario_dir = base / scenario_id

        if not scenario_dir.exists():
            click.echo(f"No results found at {scenario_dir}", err=True)
            raise SystemExit(1)

        # Collect scores per theme
        theme_scores: dict[str, list[float]] = {}
        for theme_dir in sorted(scenario_dir.iterdir()):
            if not theme_dir.is_dir() or theme_dir.name.startswith("_"):
                continue
            scores = []
            for run_dir in sorted(theme_dir.iterdir()):
                if not run_dir.is_dir() or not run_dir.name.startswith("run-"):
                    continue
                score_data = _load_score(run_dir)
                if score_data and "score_pct" in score_data:
                    scores.append(float(score_data["score_pct"]))
            if scores:
                theme_scores[theme_dir.name] = scores

        if not theme_scores:
            click.echo("No scored runs found.", err=True)
            raise SystemExit(1)

        control = theme_scores.get("control")
        if not control:
            click.echo("Warning: no control baseline found — effect sizes unavailable.", err=True)

        # Compute stats
        results = {}
        for tag in sorted(theme_scores.keys()):
            scores = theme_scores[tag]
            n = len(scores)
            mean = sum(scores) / n
            std = math.sqrt(sum((s - mean) ** 2 for s in scores) / (n - 1)) if n > 1 else 0.0
            ci_95 = 1.96 * std / math.sqrt(n) if n > 1 else 0.0

            entry = {
                "n": n,
                "mean": round(mean, 2),
                "std": round(std, 2),
                "ci_95": round(ci_95, 2),
            }

            if control and tag != "control" and len(control) > 1:
                ctrl_mean = sum(control) / len(control)
                ctrl_std = math.sqrt(
                    sum((s - ctrl_mean) ** 2 for s in control) / (len(control) - 1)
                )
                entry["cohens_d"] = round(_cohens_d(mean, std, n, ctrl_mean, ctrl_std, len(control)), 3)
                entry["p_value"] = round(_welch_t_test(mean, std, n, ctrl_mean, ctrl_std, len(control)), 4)

            results[tag] = entry

        # Print table
        _print_stats_table(results, control is not None)

        # Aggregate tests (if control exists and there are persona themes)
        persona_tags = [t for t in results if t != "control"]
        if control and len(persona_tags) >= 2:
            click.echo()
            _print_aggregate(results, persona_tags, control)

        # Save
        if save:
            out_path = scenario_dir / "comparison-stats.yaml"
            with open(out_path, "w") as f:
                yaml.dump({"scenario_id": scenario_id, "themes": results}, f, default_flow_style=False)
            click.echo(f"\nSaved to {out_path}")

    return stats


def _load_score(run_dir: Path) -> dict | None:
    """Load majority_vote.yaml if available, else score.yaml."""
    for name in ("majority_vote.yaml", "score.yaml"):
        path = run_dir / name
        if path.exists():
            try:
                with open(path) as f:
                    return yaml.safe_load(f)
            except Exception:
                pass
    return None


def _cohens_d(m1, s1, n1, m2, s2, n2):
    """Cohen's d with pooled standard deviation."""
    pooled = math.sqrt(((n1 - 1) * s1**2 + (n2 - 1) * s2**2) / (n1 + n2 - 2))
    if pooled == 0:
        return 0.0
    return (m1 - m2) / pooled


def _welch_t_test(m1, s1, n1, m2, s2, n2):
    """Welch's t-test p-value (two-tailed, approximate)."""
    se = math.sqrt(s1**2 / n1 + s2**2 / n2) if (s1 > 0 or s2 > 0) else 0
    if se == 0:
        return 1.0
    t = abs(m1 - m2) / se

    # Welch-Satterthwaite degrees of freedom
    num = (s1**2 / n1 + s2**2 / n2) ** 2
    denom = (s1**2 / n1) ** 2 / (n1 - 1) + (s2**2 / n2) ** 2 / (n2 - 1) if (n1 > 1 and n2 > 1) else 1
    df = num / denom if denom > 0 else 1

    # Approximate p-value using normal distribution for large df
    # For small df, this underestimates p (conservative)
    p = 2 * _normal_cdf(-t)
    return p


def _normal_cdf(x):
    """Approximate standard normal CDF (Abramowitz & Stegun)."""
    if x < -8:
        return 0.0
    if x > 8:
        return 1.0
    a1, a2, a3, a4, a5 = 0.254829592, -0.284496736, 1.421413741, -1.453152027, 1.061405429
    p = 0.3275911
    sign = 1 if x >= 0 else -1
    x = abs(x) / math.sqrt(2)
    t = 1.0 / (1.0 + p * x)
    y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * math.exp(-x * x)
    return 0.5 * (1.0 + sign * y)


def _print_stats_table(results, has_control):
    """Print formatted stats table."""
    # Header
    cols = ["Theme", "N", "Mean", "Std", "95% CI"]
    if has_control:
        cols += ["Cohen's d", "p-value"]

    widths = [20, 4, 7, 7, 12]
    if has_control:
        widths += [10, 9]

    header = "".join(c.ljust(w) for c, w in zip(cols, widths))
    click.echo(header)
    click.echo("-" * len(header))

    # Sort: control first
    for tag in sorted(results.keys(), key=lambda t: ("" if t == "control" else t)):
        r = results[tag]
        ci_str = f"{r['mean'] - r['ci_95']:.1f}-{r['mean'] + r['ci_95']:.1f}"
        row = [
            tag[:19].ljust(20),
            str(r["n"]).ljust(4),
            f"{r['mean']:.1f}".ljust(7),
            f"{r['std']:.1f}".ljust(7),
            ci_str.ljust(12),
        ]
        if has_control:
            d = r.get("cohens_d")
            p = r.get("p_value")
            d_str = f"{d:.2f}" if d is not None else "—"
            p_str = f"{p:.4f}" if p is not None else "—"
            # Significance markers
            if p is not None:
                if p < 0.001:
                    p_str += " ***"
                elif p < 0.01:
                    p_str += " **"
                elif p < 0.05:
                    p_str += " *"
            row += [d_str.ljust(10), p_str.ljust(9)]
        click.echo("".join(row))


def _print_aggregate(results, persona_tags, control_scores):
    """Print aggregate sign test across persona themes."""
    ctrl_mean = sum(control_scores) / len(control_scores)

    above = sum(1 for t in persona_tags if results[t]["mean"] > ctrl_mean)
    below = len(persona_tags) - above

    click.echo(f"Aggregate: {above}/{len(persona_tags)} themes above control mean ({ctrl_mean:.1f}%)")
    click.echo(f"  Sign test: {above} above, {below} below")

    # Mean delta
    deltas = [results[t]["mean"] - ctrl_mean for t in persona_tags]
    mean_delta = sum(deltas) / len(deltas)
    click.echo(f"  Mean delta vs control: {mean_delta:+.2f}%")
