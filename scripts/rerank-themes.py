#!/usr/bin/env python3
"""
Bulk-update all theme YAML files:
1. Assign proper tiers (S/A/B/C/D) based on source material quality
2. Convert zeitgeist score to enum (low/moderate/high) and add to dimensions
3. Update zeitgeist.rating to match new enum

Usage: python3 scripts/rerank-themes.py [--dry-run]
"""
import re
import sys
from pathlib import Path

DRY_RUN = "--dry-run" in sys.argv

THEMES_DIR = Path(__file__).resolve().parent.parent / "pennyfarthing" / "pennyfarthing-dist" / "personas" / "themes"

# ── Tier Assignments ──
TIERS = {
    # S — Iconic, deeply characterized, excellent role mapping
    "S": [
        "west-wing", "star-trek-tng", "game-of-thrones", "discworld",
        "firefly", "lord-of-the-rings", "sherlock-holmes", "the-wire",
        "breaking-bad", "princess-bride",
    ],
    # A — Strong cultural resonance, good character depth
    "A": [
        "star-wars", "dune", "hitchhikers-guide", "monty-python",
        "shakespeare", "mash", "the-office", "parks-and-rec",
        "succession", "mad-men", "the-sopranos", "harry-potter",
        "avatar-the-last-airbender", "better-call-saul", "rome",
        "the-expanse", "foundation", "battlestar-galactica",
        "doctor-who", "jane-austen", "fargo", "star-trek-tos",
        "ted-lasso", "1984", "stephen-king",
    ],
    # B — Solid themes, well-known source material
    "B": [
        "agatha-christie", "fifth-element",
        "deadwood", "futurama", "the-simpsons", "blade-runner",
        "watchmen", "sandman", "the-matrix", "alice-in-wonderland",
        "greek-mythology", "norse-mythology", "the-good-place",
        "peaky-blinders", "twin-peaks", "house-md", "cowboy-bebop",
        "justified", "x-files", "snow-crash", "big-lebowski",
        "hannibal", "the-americans", "black-sails", "his-dark-materials",
        "dickens", "arthurian-mythos", "the-crown", "great-gatsby",
        "neuromancer", "lovecraft-mythos", "don-quixote", "catch-22",
        "the-witcher",
    ],
    # C — Adequate but less distinctive
    "C": [
        "russian-masters", "gothic-literature", "les-miserables",
        "renaissance-masters", "ancient-philosophers", "classical-composers",
        "film-auteurs", "moby-dick", "the-odyssey", "hogans-heroes",
        "gilligans-island", "babylon-5", "vorkosigan-saga", "mad-max",
        "a-team", "superfriends", "marvel-mcu", "legion-of-doom",
        "expeditionary-force", "count-of-monte-cristo", "imperial-radch",
        "world-explorers", "jazz-legends",
    ],
    # D — Nonfiction/abstract, harder to characterize
    "D": [
        "software-pioneers", "military-commanders", "scientific-revolutionaries",
        "ancient-strategists", "historical-figures", "enlightenment-thinkers",
        "wwii-leaders",
    ],
}

# Build reverse lookup
TIER_MAP = {}
for tier, names in TIERS.items():
    for name in names:
        TIER_MAP[name] = tier

def zeit_enum(score):
    """Convert zeitgeist score to enum."""
    if score is None:
        return None
    if score < 75:
        return "low"
    elif score < 85:
        return "moderate"
    else:
        return "high"

def extract_zeit_score(text):
    """Extract zeitgeist score from YAML text."""
    # Match both valid YAML and corrupted format from previous run
    m = re.search(r'zeitgeist:\s*\n\s+score:\s*([\d.]+)', text)
    if m:
        return float(m.group(1))
    # Corrupted: "  moderate 84.5" instead of "  score: 84.5"
    m = re.search(r'zeitgeist:\s*\n\s+\w+ ([\d.]+)', text)
    if m:
        return float(m.group(1))
    return None

def update_theme(path):
    """Update a single theme file."""
    text = path.read_text()
    name = path.stem
    changes = []

    # Skip control
    if name == "control":
        return changes

    # 0. Fix corrupted zeitgeist section from previous run
    # Pattern: "  moderate 84.5" should be "  score: 84.5"
    m = re.search(r'(zeitgeist:\n)  \w+ ([\d.]+)\n', text)
    if m:
        text = text[:m.start()] + m.group(1) + f"  score: {m.group(2)}\n" + text[m.end():]
        changes.append(f"fixed corrupted zeitgeist score: {m.group(2)}")

    # 1. Update tier
    new_tier = TIER_MAP.get(name)
    if new_tier:
        old = re.search(r'(\s+tier:\s*)(\S+)', text)
        if old and old.group(2) != new_tier:
            text = text[:old.start(2)] + new_tier + text[old.end(2):]
            changes.append(f"tier: {old.group(2)} → {new_tier}")
    else:
        changes.append(f"WARNING: no tier assignment for {name}")

    # 2. Get zeitgeist score and convert to enum
    zeit_score = extract_zeit_score(text)
    zeit_val = zeit_enum(zeit_score)

    # 3. Add zeitgeist to dimensions block
    # Look for "    zeitgeist:" (4-space indent = inside dimensions)
    if zeit_val:
        dim_zeit = re.search(r'^    zeitgeist: \S+', text, re.MULTILINE)
        if dim_zeit:
            # Already in dimensions — update
            text = text[:dim_zeit.start()] + f"    zeitgeist: {zeit_val}" + text[dim_zeit.end():]
            changes.append(f"dimensions.zeitgeist: updated → {zeit_val}")
        else:
            # Insert after energy line (4-space indent)
            m = re.search(r'(    energy: \S+\n)', text)
            if m:
                text = text[:m.end()] + f"    zeitgeist: {zeit_val}\n" + text[m.end():]
                changes.append(f"dimensions.zeitgeist: added {zeit_val}")
            else:
                changes.append(f"WARNING: could not find energy dimension")

    # 4. Update zeitgeist.rating (2-space indent, under zeitgeist section)
    if zeit_val:
        old_rating = re.search(r'^  rating: (\S+)', text, re.MULTILINE)
        if old_rating and old_rating.group(1) != zeit_val:
            text = text[:old_rating.start(1)] + zeit_val + text[old_rating.end(1):]
            changes.append(f"zeitgeist.rating: {old_rating.group(1)} → {zeit_val}")

    if changes and not DRY_RUN:
        path.write_text(text)

    return changes


def main():
    # Verify all themes are assigned
    all_themes = {p.stem for p in THEMES_DIR.glob("*.yaml")} - {"control"}
    assigned = set(TIER_MAP.keys())
    missing = all_themes - assigned
    extra = assigned - all_themes

    if missing:
        print(f"UNASSIGNED themes ({len(missing)}):")
        for m in sorted(missing):
            print(f"  {m}")
        print()

    if extra:
        print(f"EXTRA (no file): {sorted(extra)}")
        print()

    total_changes = 0
    for path in sorted(THEMES_DIR.glob("*.yaml")):
        changes = update_theme(path)
        if changes:
            print(f"{path.stem}:")
            for c in changes:
                print(f"  {c}")
            total_changes += len(changes)

    mode = "DRY RUN" if DRY_RUN else "APPLIED"
    print(f"\n{mode}: {total_changes} changes across {len(list(THEMES_DIR.glob('*.yaml')))} files")

    # Print tier distribution
    print("\nTier distribution:")
    for tier in ["S", "A", "B", "C", "D"]:
        print(f"  {tier}: {len(TIERS[tier])}")


if __name__ == "__main__":
    main()
