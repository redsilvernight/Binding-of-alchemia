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

## Local (qwen) and Kimi delegation for token-heavy work

- For large, read-only analysis — big diff/code reviews, wide code-comprehension passes, or generating the markdown sidecars/semantic-extraction content for Graphify's `.gd`/`.tscn`/`.tres` workaround (see the `graphify-gdscript-workaround` memory) — delegate instead of spending Claude's own context. Do this proactively, without waiting for the user to type `/kimi-review`.
- **Prefer qwen (local, free) first**, via `~/.claude/scripts/qwen_query.ps1` — it calls the user's local Ollama (`qwen2.5-coder:7b` by default, CPU-only on this machine, ~8 tok/s). No API key, no cost. Fall back to Kimi (cloud, faster, stronger, but paid) when the task exceeds what the local 7B handles well: very large context, complex multi-file synthesis, or when a first qwen pass came back thin/unreliable.
- **This includes Explore-agent-style codebase search before an edit, not just standalone reviews.** Caught a gap on 2026-08-18: a session spent 92.7k + 89.8k tokens on two `Explore` dispatches ("find footstep audio hookup points") without ever considering delegation. Whenever a search is expected to touch many files or read a lot of code to locate where something should hook in, do the shortlisting myself with a cheap Glob/Grep pass, then hand the shortlisted files' content to qwen (or Kimi if it's a harder synthesis) with the actual question, and pull back only the narrow answer (file + function) to implement. Skip this for a single quick lookup — not worth the round-trip.
- Never pipe into either script (`... | pwsh ...`). Write the context to a temp file first, then invoke directly: `pwsh -NoProfile -File "$HOME/.claude/scripts/qwen_query.ps1" -Prompt "..." -Files <tempfile>` or the `kimi_query.ps1` equivalent. Only those literal prefixes are pre-approved (no confirmation prompt) — a piped form hits the permission classifier instead.
- Do not delegate the actual edit/implementation, or anything requiring tool use or direct interaction with Godot/Claude Code — both qwen and Kimi only read text and return text.
- This is precisely what makes proactive graph updates viable again (see the Graphify section below) — local/Kimi delegation changes *how* an update is paid for (tokens or GPU-idle CPU time instead of Claude's context), which is why *when* it runs can now be judgment-based instead of "only on explicit request."

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

**Proactive updates (revised 2026-08-18, see `graphify-gdscript-workaround` memory for the full history):** update the graph on my own judgment, without waiting to be asked, when the graph is meaningfully stale relative to the task at hand — e.g. a chunk of work just finished (feature/phase done, several files changed) and I'm about to rely on the graph for an architecture question, or the user is asking one directly. Do NOT trigger on every trivial edit or every commit — that was tried before and reversed for cost reasons; judgment-based, not blanket-automatic. This project's `.gd`/`.tscn`/`.tres` files need the sidecar workaround (see the memory and `~/.claude/references/graphify-sidecar-workaround.md`) with extraction routed through Kimi per the delegation rule above — always tell the user afterward that an auto-update ran, with the token cost.