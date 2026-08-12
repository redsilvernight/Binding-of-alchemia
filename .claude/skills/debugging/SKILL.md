\---

name: debugging

description: Systematically investigate Godot and GDScript bugs, runtime errors, unexpected behavior, signal issues, lifecycle problems, and multiplayer bugs.

\---



\# Debugging Workflow



\## Principle



Do not immediately modify code.



First identify the root cause.



\## Process



\### 1. Identify the symptom



Determine exactly:



\- what happens;

\- what should happen;

\- when the problem occurs;

\- whether it happens every time;

\- whether it depends on a specific game state.



\### 2. Locate the execution path



Identify:



\- entry point;

\- caller;

\- relevant functions;

\- signals;

\- callbacks;

\- RPCs;

\- state changes.



\### 3. Trace state



Determine:



\- current state;

\- expected state;

\- where the state changes;

\- whether it can change more than once.



\### 4. Multiplayer



For multiplayer problems, explicitly separate:



\- server execution;

\- client execution;

\- authority;

\- RPC calls;

\- replicated state.



\### 5. Find the earliest divergence



Find the earliest point where the actual execution differs from the expected execution.



Do not focus only on the final visible symptom.



\### 6. Form a root-cause hypothesis



State the hypothesis before changing code.



The hypothesis should be supported by evidence from the code or runtime behavior.



\### 7. Implement the smallest fix



Prefer the smallest coherent change that fixes the root cause.



Do not rewrite unrelated systems.



\### 8. Validate



After the change:



\- reproduce the original situation;

\- verify the bug is gone;

\- check for regressions;

\- inspect relevant errors and warnings.



\## Avoid



Do not:



\- hide errors;

\- remove functionality just to stop an error;

\- add arbitrary delays;

\- add duplicate state;

\- add defensive code without understanding the cause;

\- rewrite large systems to fix a local problem.

