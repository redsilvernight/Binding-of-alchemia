---
paths: ["**/*.gd", "**/*.tscn", "**/*.tres", "**/project.godot"]
---

# Godot Rules

## Version

This project uses Godot 4.6. Never assume Godot 3.x APIs.

## Nodes and Scenes

- Respect the existing scene hierarchy.
- Do not move nodes between scenes without understanding their ownership.
- Prefer existing nodes and managers over creating duplicates.
- Consider node lifecycle when modifying initialization code.

## Lifecycle

Be careful with: `_init()`, `_ready()`, `_enter_tree()`, `_exit_tree()`, `_process()`, `_physics_process()`.

When modifying lifecycle-sensitive code, verify the order in which nodes and systems are initialized.

## Signals

Before creating a new signal:
1. Check whether an existing signal already provides the required communication.
2. Check where the signal should be emitted.
3. Check who owns the state represented by the signal.

## Autoloads

- Do not create new Autoloads without an architectural reason.
- Reuse existing global managers when appropriate.
- Be aware that Autoloads persist independently from individual scenes.

## Resources

Prefer Godot Resources for reusable data when that matches the existing architecture.
Do not convert simple data into Resources solely for abstraction purposes.

## Performance

- Avoid unnecessary work in `_process()`.
- Avoid repeatedly traversing large scene trees when the result can be cached.
- Do not optimize speculative performance problems before identifying an actual bottleneck.