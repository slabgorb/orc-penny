#!/usr/bin/env python3
"""Extract benchmark-relevant sections from pf agent start output.

Keeps from Agent Definition: role, adversarial-mindset/minimalist-discipline/test-paranoia,
  critical (rubber-stamp warning), review-checklist, severity-levels
Keeps: Persona block, Sidecars (patterns, gotchas, decisions)
Strips: Workflow State, Agent Behavior Guide, Sprint Context, Repos Topology,
  and workflow-specific XML tags (helpers, parameters, phase-check, on-activation,
  assessment-templates, finding-capture, exit, tandem-*, team-mode, research-tools, skills)

Usage:
    pf agent start reviewer | python3 scripts/cr003-extract-prompt.py
    pf agent start reviewer --no-persona | python3 scripts/cr003-extract-prompt.py
"""
import sys
import re

text = sys.stdin.read()

# Split into sections by top-level headers (# ...)
sections = re.split(r'^(# .+)$', text, flags=re.MULTILINE)

KEEP_PREFIXES = [
    '# Agent Definition',
    '# Persona:',
    '# Agent Sidecar:',
]

SKIP_PREFIXES = [
    '# Workflow State',
    '# Agent Behavior Guide',
    '# Sprint Context',
    '# Repos Topology',
]

# XML tags that are workflow-specific (strip from agent definition)
STRIP_TAGS = [
    'helpers', 'parameters', 'phase-check', 'on-activation',
    'assessment-templates', 'finding-capture', 'exit',
    'tandem-consultation', 'tandem-backseat', 'team-mode',
    'research-tools', 'skills',
    'user-title', 'crew',
]

output_parts = []
i = 0
while i < len(sections):
    part = sections[i]
    if part.startswith('# '):
        header = part.strip()
        content = sections[i + 1] if i + 1 < len(sections) else ''
        keep = any(header.startswith(p) for p in KEEP_PREFIXES)
        skip = any(header.startswith(p) for p in SKIP_PREFIXES)
        if keep:
            output_parts.append(header + '\n' + content)
        elif not skip:
            # Unknown section — keep by default
            output_parts.append(header + '\n' + content)
        i += 2
    else:
        if part.strip():
            output_parts.append(part)
        i += 1

result = '\n'.join(output_parts).strip()

# Strip hooks block
result = re.sub(r'^---\nhooks:.*?^---\n', '', result, flags=re.MULTILINE | re.DOTALL)

# Strip workflow-specific XML tag sections
for tag in STRIP_TAGS:
    result = re.sub(
        rf'<{tag}[^>]*>.*?</{tag}>\n*',
        '', result, flags=re.DOTALL
    )

# Clean up excessive blank lines
result = re.sub(r'\n{3,}', '\n\n', result)

print(result)
