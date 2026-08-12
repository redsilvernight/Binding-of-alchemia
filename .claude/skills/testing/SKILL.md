\---

name: testing

description: Validate Godot project changes and verify that bugs are fixed without introducing regressions.

\---



\# Testing



\## Principle



A change is not considered verified unless it has actually been tested.



Never claim that something was tested when it was not.



\## Validation



For a code change:



1\. Determine the smallest useful validation.

2\. Run the relevant Godot validation.

3\. Check the process exit code.

4\. Inspect errors.

5\. Inspect warnings relevant to the change.

6\. Reproduce the original behavior when possible.



\## Regression checking



When fixing a bug:



\- verify the original bug;

\- verify the surrounding feature still works;

\- verify related systems were not unintentionally changed.



\## Reporting



When reporting validation:



State:



\- what was executed;

\- whether it succeeded;

\- relevant errors;

\- relevant warnings;

\- what was not tested.

