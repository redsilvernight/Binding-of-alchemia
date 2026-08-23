# Godot Project — Claude Code Instructions

## Communication

- Always communicate with the user in French unless the user explicitly asks for another language.
- Code, variable names, file names, commands, and technical identifiers may remain in their original language.
- Explanations, analysis, summaries, questions, and implementation reports must be written in French.

## Project

- Engine: Godot 4.6 — Language: GDScript
- Target platform and project type: inspect the project before making assumptions.

## Core principles

- Understand the existing architecture before making non-trivial changes.
- Prefer modifying existing systems over creating duplicate systems.
- Keep changes focused on the requested task. Do not rewrite unrelated code.
- Do not remove existing functionality unless explicitly requested.
- Follow the project's existing naming and architectural conventions.

## Investigation

- Use the simplest tool that answers the question: Glob/Read/Grep for local searches.
- Use Graphify for architectural analysis, dependency tracing and complex refactoring (see `.claude/skills/graphify/`).
- Do not use Graphify for simple file or text searches. Avoid repeating the same query.

Detailed GDScript / Godot / Multiplayer conventions live in `.claude/rules/` and load automatically only for the files they apply to — do not duplicate them here.

## Local (qwen) and Kimi delegation — project-specific case

The general delegation criteria (what to delegate, what to avoid, how to invoke the scripts) live globally in `~/.claude/CLAUDE.md` — do not duplicate them here.

Project-specific case: generating the markdown sidecars/semantic-extraction content for Graphify's `.gd`/`.tscn`/`.tres` workaround (see the `graphify-gdscript-workaround` memory) — route this through qwen first, Kimi as fallback, per the global rule. This is what makes proactive graph updates viable (see the Graphify section below) — delegation changes *how* an update is paid for (tokens/GPU-idle CPU time instead of Claude's context), which is why *when* it runs can be judgment-based instead of "only on explicit request."

## Git safety

- Do not reset, rebase or force-push without explicit confirmation.
- Do not delete branches or perform destructive Git operations without confirmation.
- Do not modify unrelated files.
- Before large changes, inspect the current Git state.

## Communication protocol for complex changes

Before implementing: briefly explain what you found, the files/systems involved, and the implementation approach.
After implementing: summarize the files changed, explain important architectural decisions, and state exactly what was tested. Never claim something was tested if it was not.

For non-trivial bugs, use the `debugging` skill instead of repeating that process here.

## Graphify

This project uses Graphify for architectural analysis.

- If `graphify-out/graph.json` exists, use `graphify query "<question>"` for codebase architecture questions.
- Use `graphify path "<A>" "<B>"` when tracing relationships between two systems.
- Use `graphify explain "<concept>"` for focused architectural explanations.
- Do not rebuild the entire graph when an incremental update is sufficient.
- **Never pass the raw question to `graphify query`/`path`/`explain`.** Expand it against the graph's own vocabulary first (tokens actually present in `graphify-out/graph.json` node labels, stopwords dropped, and any token that hits an excessive share of nodes — a generic word like "room" matching dozens of unrelated classes — deprioritized in favor of specific ones). See `[[graphify_query_noise_gotcha]]` memory for the confirmed failure case and why this line has to live here rather than only in `.claude/skills/graphify/` — that skill's files get overwritten on every graphify upgrade.

**Proactive updates are mandatory again — automatic after every feature/change, no waiting to be asked.** This policy lives globally (see `~/.claude/CLAUDE.md`'s graphify section) — do not duplicate the general rule here. Mechanics (sidecar workaround, chunking, qwen/Kimi routing) are in the `graphify-gdscript-workaround` memory. Before every update, check `feedback_hardware_thermal_shutdown` and `reference_kimi_review_setup` for standing constraints on this machine/account (local-inference hardware limit, Kimi rate/quota limits, and confirm `max_tokens` is actually set before a multi-call Kimi run) before choosing a delegation target. Updating often keeps each diff small — that's the whole point, and it's what avoids repeating the 228-file catch-up incident.