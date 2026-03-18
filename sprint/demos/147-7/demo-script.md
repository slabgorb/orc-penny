**Total runtime: ~6 minutes**

**Slide 1 — Title (0:00–0:30)**
Open with the slide. Introduce the story in one sentence: "Today we shipped the repos API — WheelHub can now answer questions about repositories over the network."

**Slide 2 — Problem (0:30–1:30)**
Walk through the problem. Say: "Before today, if another service needed repo data, it had no front door to knock on. That means workarounds, hardcoded paths, and fragile integrations." Point to the 'before' state on the slide.

**Slide 3 — What We Built (1:30–2:30)**
Describe the new endpoints. "We added two routes: one that returns the full list of repos, and one that returns details for a specific repo by ID." Reference the diagram on this slide.

**Live Demo (2:30–4:30)**
Switch to terminal. Run:
```
curl -s http://localhost:8080/api/repos | jq .
```
Show output — a JSON array with repo objects, e.g. `[{"id": "pennyfarthing", "name": "Pennyfarthing", "visibility": "private"}, ...]`

Then run:
```
curl -s http://localhost:8080/api/repos/pennyfarthing | jq .
```
Show the single-repo response with fields like `id`, `name`, `description`, `default_branch`, `visibility`.

**Fallback:** If the live demo fails, switch to Slide 3 and show the pre-recorded screenshot of the JSON response. Say: "Here's what a real response looks like — clean, structured, ready to consume."

**Slide 4 — Why This Approach (4:30–5:15)**
"One front door, many consumers. Every future feature that needs repo data comes here — no duplication, no drift."

**Roadmap Slide (5:15–5:45)**
"This is the foundation. Next up: filtering, pagination, and permissions scoping."

**Questions (5:45–6:00)**

---