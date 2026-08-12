# Godot Project — Claude Code Instructions

## Communication

- Always communicate with the user in French unless the user explicitly asks for another language.
- Code, variable names, file names, commands, and technical identifiers may remain in their original language.
- Explanations, analysis, summaries, questions, and implementation reports must be written in French.

## Project

- Engine: Godot 4.6
- Language: GDScript
- Target platform and project type: inspect the project before making assumptions.

## Core principles

- Understand the existing architecture before making non-trivial changes.
- Prefer modifying existing systems over creating duplicate systems.
- Keep changes focused on the requested task.
- Do not rewrite unrelated code.
- Do not remove existing functionality unless explicitly requested.
- Preserve existing behavior unless the task requires changing it.
- Prefer typed GDScript.
- Follow the project's existing naming and architectural conventions.

## Investigation

Use the simplest tool that answers the question.

- Use Glob/Read/Grep for simple file searches.
- Use Graphify when understanding relationships between multiple systems.
- Use Graphify for architectural analysis, dependency tracing and complex refactoring.
- Do not use Graphify for simple file or text searches.
- Avoid repeatedly retrieving the same information.

## Godot

- Target Godot 4.6 APIs unless the project clearly uses another version.
- Do not use Godot 3.x APIs unless the project requires them.
- Respect existing Scene/Node ownership.
- Be careful with node lifecycle and initialization order.
- Prefer signals for decoupled communication where appropriate.
- Avoid unnecessary polling in _process().
- Inspect project.godot and relevant scenes before making architectural assumptions.

## Multiplayer

- If the project uses multiplayer, always distinguish server and client execution.
- Consider multiplayer authority when modifying networked systems.
- Preserve existing RPC and synchronization behavior unless explicitly changing it.
- Do not assume that code executes on only one peer without verifying it.

## Debugging

For non-trivial bugs:

1. Reproduce or understand the exact symptom.
2. Locate the relevant execution path.
3. Trace dependencies, signals and callbacks.
4. For multiplayer issues, distinguish server/client execution.
5. Identify the root cause before modifying code.
6. Make the smallest coherent fix.
7. Verify that the original problem is resolved.
8. Check for regressions.

Do not hide errors simply to make them disappear.

## Git safety

- Do not reset, rebase or force-push without explicit confirmation.
- Do not delete branches or perform destructive Git operations without confirmation.
- Do not modify unrelated files.
- Before large changes, inspect the current Git state.

## Communication

Before implementing a complex change:

1. Briefly explain what you found.
2. Identify the files/systems involved.
3. State the implementation approach.
4. Then implement the change.

After implementation:

- Summarize the files changed.
- Explain important architectural decisions.
- State what was tested or verified.
- Do not claim something was tested if it was not actually tested.

## Graphify

This project uses Graphify for architectural analysis.

- If graphify-out/graph.json exists, use `graphify query "<question>"` for codebase architecture questions.
- Use `graphify path "<A>" "<B>"` when tracing relationships between two systems.
- Use `graphify explain "<concept>"` for focused architectural explanations.
- After modifying code, run `graphify update .` to keep the graph current.
- Do not rebuild the entire graph when an incremental update is sufficient.