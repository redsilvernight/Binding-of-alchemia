---
name: architecture
description: Analyze the architecture and dependencies of the Godot project. Use for complex features, refactoring, cross-system bugs, dependency tracing, or when the ownership of a system is unclear.
---

# Architecture Investigation

## Purpose

Use this skill when understanding how multiple systems interact.

Do not use this skill for simple local searches.

## Investigation strategy

Start with the smallest useful investigation.

For simple questions:
- Use Glob.
- Use Grep.
- Read the relevant files.

For cross-system questions:
- Identify the systems involved.
- Identify entry points.
- Identify dependencies.
- Identify signals.
- Identify RPCs.
- Identify Autoloads.
- Use Graphify when relationship information is useful.

## Graphify

Graphify is an architectural analysis tool.

Use it when:

- tracing dependencies between multiple files;
- understanding system relationships;
- investigating call/dependency chains;
- analyzing a large refactor;
- determining how a system is connected to the rest of the project.

Do not use Graphify for:

- finding one file;
- searching for a simple string;
- reading a known file;
- answering a local code question.

Avoid repeated Graphify queries that return overlapping information.

## Architecture analysis

Before proposing a major change, determine:

1. Which system owns the relevant state?
2. Which system is responsible for the behavior?
3. Which systems depend on it?
4. How is communication performed?
5. Where is initialization performed?
6. What can trigger the behavior?
7. What can trigger it more than once?

## Output

When completing an architectural investigation, provide:

- relevant systems;
- important dependencies;
- execution flow;
- ownership;
- potential risks;
- recommended implementation approach.

Do not modify project files unless explicitly asked to implement the proposed solution.