\---

name: gdscript

description: Write, refactor and review GDScript using the project's conventions and Godot 4.6 patterns.

\---



\# GDScript Development



\## General



\- Use Godot 4.6 syntax and APIs.

\- Prefer explicit typing when practical.

\- Follow existing project conventions.

\- Keep changes focused.



\## Types



Prefer:



var player: Player



over untyped variables when the type is known and useful.



Prefer explicit return types for important functions.



\## Functions



Keep functions focused.



Avoid large functions that handle unrelated responsibilities.



Before creating a helper, check whether an equivalent helper already exists.



\## Signals



Use signals when they provide meaningful decoupling.



Before adding a signal, check whether an existing signal already represents the event.



\## State



Avoid unnecessary duplicated state.



Before adding a variable representing game state, check whether that state already has an authoritative owner.



\## Async



Be careful when modifying:



await;

timers;

signal awaits;

scene instantiation;

deferred calls.



Consider execution order when changing asynchronous code.



\## Refactoring



When refactoring:



Identify all callers.

Identify signals and callbacks.

Identify RPC usage.

Identify external dependencies.

Make the smallest coherent change.

Validate the affected behavior.

