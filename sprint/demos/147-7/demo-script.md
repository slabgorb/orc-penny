**Total runtime:** ~6 minutes

---

**Slide 1 (Title) — 0:00–0:30**
Open with the slide. Introduce the story: "This is a small but foundational change — we're opening up WheelHub's repo data to the rest of the system."

---

**Slide 2 (Problem) — 0:30–1:30**
Walk through the problem. Say: "Right now, if our CI pipeline wants to know which repos are in the project, it reads a YAML file directly. That's fragile — any rename or restructure breaks it silently. We need a contract."

---

**Slide 3 (What We Built) — 1:30–3:00**
Switch to terminal. Run the list endpoint live:

```bash
curl -s http://localhost:8080/api/repos | jq .
```

Point out the response shape: repo names, branch strategies, PR targets. Say: "Every repo in the system, structured and queryable. Took one request."

Then drill into a single repo:

```bash
curl -s http://localhost:8080/api/repos/pennyfarthing | jq .
```

Show fields like `pr_strategy`, `base_branch`, `never_edit_zones`. Say: "This is the same data that was locked in `repos.yaml` — now any tool can ask for it."

**Fallback:** If the live server isn't running, show Slide 3's screenshot of the JSON response with the `pennyfarthing` repo payload highlighted.

---

**Slide 4 (Why This Approach) — 3:00–4:00**
Return to slides. Key talking point: "We didn't move data, we added a window to it. The source of truth stays in one place."

---

**Roadmap slide — 4:00–5:00**
Connect to sibling stories and upcoming consumers of this API. Frame as: "This is the foundation — sprint tooling, onboarding scripts, and the WheelHub dashboard all read from here next."

---

**Questions — 5:00–6:00**
Open floor.

---