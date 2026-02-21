# The Pennyfarthing Project: A Field Researcher's Guide

*Sub-entry filed under: Earth, Developer Tools, Mostly Impressive*
*Researcher: Ford Prefect, field correspondent, Betelgeuse sector*
*Filed: February 21, 2026 (Earth calendar, obviously)*

---

> **GUIDE ENTRY — PENNYFARTHING**
>
> A multi-agent orchestration framework for an AI coding assistant called Claude Code,
> developed on the small, out-of-the-way planet Earth in the unfashionable end of the
> Western Spiral arm of the Galaxy. Remarkable primarily for having been built in
> sixty-three days by a species that still argues about tabs versus spaces.
>
> See also: *Ambition, Unreasonable Amounts Of*

---

## Chapter 1: In Which a Thing Called BMAD Appears and Immediately Refuses to Keep Its Name

I've been stranded on this planet for fifteen years now, and in that time I've observed that humans have a peculiar relationship with naming things. They'll name a child in nine months but rename a software project three times in a week.

On December 21st, 2025, a developer named Keith Avery committed something called BMAD to a git repository. Within *hours* — and I want to stress this, because on Betelgeuse a naming committee would have taken at least six local years and consumed four civil servants — the project was renamed to Pennyfarthing. It would later go through another identity crisis on January 19th, shedding an intermediate name called "Conductor."

The thing itself was straightforward enough: eleven AI agents coordinated through markdown files and bash scripts, each playing a role in software development. A Scrum Master to manage stories. A Test Engineer to write tests. A Developer to write code. A Reviewer to argue about the code. All communicating through session files — a concept not entirely unlike the way the Babel fish works, except instead of translating languages, it translates intent between AI instances that can't remember each other.

Three themes shipped on day one: Discworld, Star Trek TNG, and Literary Classics. These allowed the agents to adopt character personas while working — which, I should note, is exactly the kind of delightfully unnecessary thing that makes humans worth studying.

The velocity was, by Earth standards, absurd. Six version bumps in two days. By day three they had release scripts, structured logging, session file locking, and a sprint retrospective for a sprint that had barely started. I've seen Magrathean planet factories with less efficient throughput.

But the thing that caught my attention — the thing I underlined in my notes with the small pencil I keep behind my ear for exactly these moments — was a feature called **sidecar memory files**. Day two. Agents writing learnings to local files that persist across sessions. Agents that *remember*.

On Betelgeuse, we have a saying: "The universe is big. Memory is what makes it manageable." (We actually don't have that saying. I just made it up. But we should.)

---

## Chapter 2: In Which 1,000 Fictional Characters Are Given Personality Tests

There is a theory which states that if ever anyone discovers exactly why the universe was created and what it is for, it will instantly disappear and be replaced by something even more bizarre and inexplicable.

There is another theory which states that this has already happened.

I mention this because nothing else adequately explains what happened to Pennyfarthing's theme system.

It started, sensibly enough, with three themes. Star Trek. Jane Austen. Discworld. A reasonable set of costumes for AI agents to wear while reviewing code.

By January 5th there were **ninety-one themes with nine hundred and ten characters**, each profiled with OCEAN personality scores (Openness, Conscientiousness, Extraversion, Agreeableness, Neuroticism — a system that, I should note, fails to account for the personality dimension most common in the galaxy: Resistance to Filling Out Personality Questionnaires).

But here's where it gets interesting, and by "interesting" I mean "the kind of thing that makes the Guide's editorial board send back your expense claims with question marks."

They *tested* the personalities. A benchmarking framework called **JobFair** was built to measure whether character traits actually correlate with task performance. Standardized scenarios. Ground-truth judges. Cohen's d effect size tracking. A static website was generated with **768 pages** of personality data.

The finding — and I want to be careful here because I'm a journalist, not a scientist, despite what my editor thinks — was that personality profiles *matter*. Different characters perform measurably differently at code review versus test writing. Fifty-three themes were rebalanced based on the data.

Then came the portraits. AI-generated Rider-Waite tarot-style character art for every single one of the thousand-plus characters. The images got so large they required a **Git LFS migration** — which is to say, they were too big for the normal way of storing things and had to be put in a special warehouse, a problem I'm quite familiar with from my attempts to pack for interstellar travel.

One hundred themes. One thousand characters. Each with a face, a personality profile, and benchmarked performance data. All for a code review tool.

I love this planet.

---

## Chapter 3: In Which Installation Proves to Be the Final Boss

The Hitchhiker's Guide has this to say about installing software on Earth: *Don't.*

The Pennyfarthing project has attempted five distinct installation models. Each one worked perfectly for the developer and confounded everyone else. This is, I'm told, a universal constant — not just on Earth, but across all civilizations that have ever produced package managers. (The Sirius Cybernetics Corporation once produced a package manager so difficult to use that its entire user base formed a support group, which then failed to install the support group's scheduling software.)

The timeline:

**v1-v3: Copy Mode.** Files are copied into the user's project. Problem: pollutes the codebase with framework files, like spilling Gargle Blaster on someone else's towel.

**v4: Symlink Mode.** Files point to `node_modules/`. Problem: requires npm to be installed first, and breaks if anything moves. Rather like using a hyperspace bypass that only works if you don't move the origin planet — which, as we know, sometimes happens.

**v7: Scoped Packages.** Twelve npm packages under `@pennyfarthing/`. Problem: twelve things to install is eleven too many.

**v10: Consolidation.** Everything under `.pennyfarthing/`. Problem: files were still scattered across `.claude/` and `.pennyfarthing/` like a particularly unhelpful filing system.

**v11+: Progressive Setup (ADR-0027).** The current approach: fast minimal install, first-session auto-setup, runtime activation. *In progress.*

Four separate epics were dedicated to fixing installation problems. Epic 85. Epic 98. Epic 117 — twelve stories born from a single diagnostic run that uncovered real-world failures. Epic 123.

The lesson, which I've noted in the margin of my Guide entry under "Things Humans Keep Relearning": **every installation model works for the developer. None of them work for the user — until you've watched them fail.**

This is, incidentally, also true for Babel fish insertion.

---

## Chapter 4: In Which the UI Takes a Tour of Every Possible Technology and Settles on Three

The user interface history of Pennyfarthing reads like a particularly indecisive restaurant order.

"We'll have the CLI, please."

"Actually, make that an Electron app."

"Oh, and could we also get a VS Code extension?"

"We've changed our minds about the VS Code extension. We'll return that."

"And could we add a Python terminal UI?"

"We'll keep all three of the remaining ones, thanks."

**The CLI (v1-v5)** was the original and, in many ways, remains the purest expression. Markdown files, bash scripts, slash commands. It worked the way the Guide itself works — text in, text out, no unnecessary graphical flourishes. (The Guide's only concession to visual design is the words "DON'T PANIC" on the cover, and those were added by the marketing department over the objections of editorial.)

**Cyclist (v6+)** was the Electron app. React 19, Tailwind v4, shadcn/ui, thirteen monitoring panels. A visual terminal that showed you what your AI agents were doing in real time — messages, diffs, sprint progress, git status, workflow state, tool calls, telemetry. It became, against all reasonable expectation, genuinely beautiful. Tufte-inspired message design. WCAG AA compliance. The kind of attention to aesthetics you normally see in Magrathean planetary coastline work.

**The VS Code extension (v7.3)** lasted twelve days. Built on January 21st, deprecated via ADR-0019 on February 2nd, completely removed in v9.0. The reasoning was sound — Claude Code's own VS Code integration made a separate extension redundant. But twelve days of development, discarded. I've seen civilizations rise and fall in less time, but never a VS Code extension.

**BikeRack TUI (v11.0)** arrived on February 14th — the biggest day in the project's history, with 507 commits. A complete Python Textual-based terminal UI. WebSocket client, sprint panel, git panel, audit log, context meter, auto-reload. A full-featured dashboard that runs in a terminal alongside the CLI, without requiring Electron.

The project now supports three interface paradigms (CLI, Electron GUI, terminal TUI), which is exactly the right number if you believe, as I do, that the answer to "which one?" is always "yes."

**The small thing that turned out to be enormous:** The Reflector protocol. HTML comment markers — `<!-- CYCLIST:TYPE:value -->` — embedded invisibly in agent output. In the CLI, they're invisible. In Cyclist, they drive interactive buttons. One stream of text, two entirely different experiences. Rather like how the Babel fish produces different translations for different listeners from the same source, except less slimy.

---

## Chapter 5: In Which Workflows Learn to Harmonize

The workflow system evolved through four generations, each more sophisticated than the last, in a pattern I've observed across many species: first you build a thing, then you make the thing flexible, then you make the flexibility manageable, then you make the management invisible.

**Gen 1 (v1-v5):** One workflow. SM → TEA → Dev → Reviewer → SM. Like a Vogon bureaucratic process, but intentionally so.

**Gen 2 (v6.4):** YAML-defined workflow state machines. Routing based on story metadata. The trivial workflow appeared (skipping TEA for quick fixes) — a recognition that not every two-line change needs a test design ceremony. This is wisdom. The Vogons never learned it.

**Gen 3 (v7.3):** Stepped workflows for human-paced processes. Architecture reviews. PRD creation. Sprint planning. Guided step-by-step, with gates at each transition. Less "assembly line," more "choose your own adventure."

**Gen 4 (v10.2-v11.2):** Two breakthroughs.

The **Tandem Protocol** is my favorite. A background observer agent watches your work and injects quiet observations via hooks. Your Architect partner notices a coupling issue. Your TEA notices a test gap. They whisper into your context without interrupting your flow. It's the software equivalent of having a knowledgeable friend leaning over your shoulder, except the friend is an AI that never gets bored, never needs coffee, and never says "well, actually" unless it's genuinely warranted.

**Native Teams** let phase agents spawn collaborators. The lead coordinates via messages, teammates work in parallel, everyone shuts down before handoff. Teams scoped to a single phase — created at the start, destroyed at the end.

And underneath it all, the **gate system** (ADR-0025). Declarative gate files with pass/fail criteria. Bash scripts handle state transitions atomically. The architecture shifted from "agents decide everything" to **"scripts guarantee state, agents make decisions."** This is, I suspect, how the Magratheans ran their planet factory — the machinery handles the physics, the designers handle the coastlines.

---

## Chapter 6: In Which Everything That Was Distributed Gets Consolidated

There is a pattern in this project that I find deeply familiar because it mirrors the editorial process at the Guide.

First, you create many entries on related topics. Then you realize they overlap. Then you merge them. Then someone creates a new entry that overlaps with the merged one. Then you merge *that*. Eventually you have one very good entry where you once had twelve mediocre ones.

Pennyfarthing's consolidation arc:

- Twelve npm packages → one (`@pennyfarthing/core`)
- `packages/shared/` → absorbed into `packages/core/src/shared/`
- Benchmark package → extracted, then re-absorbed into core
- WheelHub server → moved from cyclist to core
- React UI build → moved from cyclist to core
- Scattered files across `.claude/` → consolidated under `.pennyfarthing/`
- Two git branches (develop + main) → trunk-based development

February 13th was the inflection point. The project shed accumulated complexity. Cyclist became a thin Electron wrapper. Core became the gravity well.

The `pf.sh` wrapper script deserves special mention. It started as a convenience — a single entry point to the framework. It became the canonical way to invoke *anything*. Every hook, every agent activation, every sprint operation routes through it. It self-locates via `BASH_SOURCE`, detects monorepos, handles nested repos, and dispatches to the Python CLI.

I've seen simpler routing protocols on interstellar trade routes. But I've rarely seen one that works as reliably.

---

## Chapter 7: In Which Some Things Are Built and Then Immediately Destroyed

The Guide has a policy on failed experiments: document them. Not to shame the experimenters, but because knowing what *doesn't* work is often more valuable than knowing what does. (The entry for the Sirius Cybernetics Corporation's Genuine People Personality prototype is seven pages longer than the entry for their most successful product.)

**Chernoff Faces (January 19th).** Built and killed on the same day. Statistical personality visualizations rendered as cartoon faces, with features mapped to OCEAN trait values. Nose width for Openness. Mouth curvature for Agreeableness. I'm told it was technically impressive and entirely useless for its intended purpose, which is a combination I've encountered frequently on this planet.

**The VS Code Extension (January 21st - February 2nd).** Twelve days of development, deprecated by architectural reality. Claude Code added its own VS Code integration, making a separate extension redundant. The developers had the grace to kill it quickly rather than maintain it out of sunk-cost sentiment. This is rarer than you'd think — both on Earth and in the wider galaxy.

**TTY Panel / node-pty.** A terminal emulator inside the Cyclist GUI, using native code bindings. Removed because it introduced a dependency that broke clean installations. The TUI (BikeRack) solved the same need without the dependency — a lesson in how constraints (no native modules) can force better solutions.

**DockingWorkspace.** A custom panel docking system. Replaced by Dockview, a mature third-party library. Sometimes the best engineering decision is to let someone else do the engineering.

**`packages/shared/`.** A shared utilities package. Absorbed back into core within weeks. The abstraction was created before anyone knew what needed to be shared, which is rather like building a bridge before you know where the river is.

---

## Chapter 8: The Numbers (For Those Who Find Numbers Reassuring)

The Hitchhiker's Guide notes that the Answer to the Ultimate Question of Life, the Universe, and Everything is 42. The numbers below are somewhat less ultimate but considerably more verifiable.

| Metric | Value |
|--------|-------|
| **Age** | 63 days |
| **Framework commits** | ~10,641 (effective ~3,500 unique) |
| **Orchestrator commits** | 763 |
| **Tagged releases** | 120 (v1.3.0 through v11.4.0) |
| **Pull requests merged** | 1,054+ |
| **Architecture Decision Records** | 27 |
| **Breaking version bumps** | 7 |
| **Epics completed** | 60+ |
| **Stories delivered** | 500+ |
| **Story points** | 1,000+ |
| **Agents** | 11 core + 13 subagents |
| **Themes** | 100 |
| **Characters** | 1,000+ |
| **Workflow types** | 7 |
| **Average commits/day** | ~169 (framework) |
| **Peak day** | Feb 14, 2026 — 507 commits |
| **Primary contributor** | Keith Avery (93%) |
| **Days between first commit and VS Code deprecation** | 43 |
| **Days the VS Code extension existed** | 12 |
| **Installation model pivots** | 5 |
| **Times the project was renamed** | 3 |

The ratio of 120 releases in 63 days means an average release cycle of 12.6 hours. For context, the Guide's editorial cycle is six months, and even then they rarely get the Pluto entry right.

---

## Chapter 9: In Which We Consider Where This is All Going

The question of where a project is headed is, in my experience, best answered by looking at where it's been and extrapolating with cautious optimism. (The alternative — asking the developers directly — tends to produce answers that are either terrifyingly ambitious or depressingly modest, with no middle ground.)

**What's happening now (Sprint 2608):**
- The BikeRack TUI is getting polished — richer progress displays, connection stability, settings toggles
- Release tooling is being hardened — package assertions, changelog automation, smoke tests
- The installation architecture (ADR-0027) is being reimagined — progressive, three-phase, deferred Python

**What's coming next:**
- **BikeRack Extraction** — The TUI becoming a fully standalone product, possibly with an Electron wrapper (BikeShow.app)
- **Complete Python CLI** — The remaining bash scripts migrated to the `pf` Click CLI
- **Agent Quality Awareness** — Smarter routing, capability detection, tandem mode improvements
- **Multi-session WheelHub** — Multiple Claude instances sharing one dashboard

**The strategic direction**, as I read it:
- **Progressive disclosure** — Install fast, discover features gradually
- **Script-first coordination** — Machines handle guarantees, agents handle judgment
- **Interface pluralism** — CLI, Electron, TUI, web — pick your own
- **Plugin architecture** — Project-specific extensions

The trajectory, if I'm reading it correctly (and I usually am; it's one of the few benefits of being a galactic field researcher), is from "collection of agent definitions" toward **"development infrastructure platform."** A system that coordinates AI agents the way an orchestral conductor coordinates musicians — each one an expert, none of them aware of the full score, all of them producing something coherent because someone (or something) is keeping time.

---

## Epilogue

I've been filing entries for the Guide for longer than most civilizations have had written language. I've documented the rise and fall of empires, the invention and abandonment of technologies, and the eating habits of creatures that would make a Ravenous Bugblatter Beast of Traal lose its appetite.

Pennyfarthing is, by galactic standards, very small. One developer, sixty-three days, a few thousand commits. It won't stop the Vogons from demolishing your planet (nothing will — they have the forms in triplicate). It won't answer the Ultimate Question.

But it does something I find genuinely admirable: it takes the messy, context-limited, attention-scattered reality of working with AI agents and imposes *structure* on it. Workflows. Gates. Session files. Handoff protocols. Scripts that guarantee state so agents can focus on decisions. And it does it all while letting you pretend you're Malcolm Reynolds, or Slartibartfast, or Trillian, or any of a thousand other characters — because humans, it turns out, do their best work when they're having fun.

The entry for Earth in the Guide still says "Mostly Harmless." I've been trying to get it expanded for years.

Pennyfarthing, at least, I can give a proper entry:

> **PENNYFARTHING** — A framework that coordinates AI agents for software development.
> Built in sixty-three days. Renamed three times. Five installation models. One thousand
> characters. Zero excuses.
>
> *Don't panic. Do bring a towel.*

---

*Ford Prefect is a roving researcher for the Hitchhiker's Guide to the Galaxy. He has been stranded on Earth since 2011 and has recently taken up documenting developer tools as a way to pass the time until the next Vogon constructor fleet arrives. His previous works include the original Earth entry ("Mostly Harmless") and a strongly-worded letter to editorial about the inadequacy of two-word planet descriptions.*
