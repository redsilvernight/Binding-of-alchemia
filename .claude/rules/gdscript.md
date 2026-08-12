\# GDScript Rules



\## Typing



\- Prefer explicit static typing when practical.

\- Use typed function parameters and return types for important systems.

\- Preserve existing typing conventions when modifying existing code.



\## Naming



Follow the naming conventions already used by the project.



Prefer clear names over abbreviations.



\## Functions



\- Keep functions focused on one responsibility.

\- Avoid unnecessarily large functions.

\- Avoid introducing abstractions for purely theoretical flexibility.

\- Reuse existing helpers and systems when appropriate.



\## Signals



\- Prefer signals when communication should be decoupled.

\- Do not introduce signals when a direct call is clearly simpler and appropriate.

\- Preserve existing signal connections when refactoring.



\## State



\- Avoid unnecessary global state.

\- Do not introduce new Autoloads without a clear architectural reason.

\- Prefer explicit ownership of state.



\## Async code



\- Preserve existing await/coroutine behavior when modifying asynchronous code.

\- Be careful when changing code that depends on frame timing or signal ordering.



\## Error handling



\- Do not silently swallow errors.

\- Do not add defensive checks solely to hide an underlying bug.

\- Prefer identifying and fixing the root cause.

