# Narrative

## Problem Statement
Problem: WheelHub has no way for external clients to query repository information — teams must inspect config files manually or rely on tribal knowledge to discover which repos exist and how they're structured. Why it matters: Without a machine-readable repos API, downstream tools (dashboards, CI pipelines, onboarding scripts) cannot self-configure, creating toil and drift as the repository landscape changes.

---

## What Changed
Think of WheelHub as a directory service for your codebase. Before this change, if a tool or service wanted to know "what repos do we have and how are they organized?", there was no official answer — you had to read internal config files yourself.

This story adds a proper front door: a set of API endpoints that let any authorized client ask WheelHub "give me the repo list" or "tell me about this specific repo" and get back a clean, structured answer. No more poking around in YAML files.

---

## Why This Approach
Repos metadata already exists in WheelHub's config layer — this doesn't reinvent anything. The engineering choice was to expose that existing data through a REST API following the same patterns already established in WheelHub for other resource types. This keeps the surface area small (1 point of work), avoids duplicating data, and means any future changes to repo configuration are automatically reflected in the API with no extra maintenance.

---
