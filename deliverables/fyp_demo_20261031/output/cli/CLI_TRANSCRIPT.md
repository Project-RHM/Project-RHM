# Actual CLI demo transcript

Generated: 2026-10-31T09:41:25.798292+00:00

Commit: `5545aa182494797ce7d2859bacd15353a620d921`

The extension's compile command was reproduced in a disposable directory; its absolute temp path is historical evidence, not a reusable demo path.

## check

Working directory: `/Users/ray/Desktop/Project-RHM_latest 2/deliverables/fyp_demo_20261031`

```sh
'/Users/ray/Desktop/Project-RHM_latest 2/generator/_build/install/default/bin/rhema' check demo_budget.rhm -I '/Users/ray/Desktop/Project-RHM_latest 2/generator/stdlib'
```

Exit status: 0

```text
demo_budget.rhm: OK (4 rules; questions: main; sets: none)

```

## list

Working directory: `/Users/ray/Desktop/Project-RHM_latest 2/deliverables/fyp_demo_20261031`

```sh
'/Users/ray/Desktop/Project-RHM_latest 2/generator/_build/install/default/bin/rhema' list demo_budget.rhm -I '/Users/ray/Desktop/Project-RHM_latest 2/generator/stdlib'
```

Exit status: 0

```text
questions:
  main           start E, context Numeric
budgets: cost = 4

```

## extension_run_equivalent

Working directory: `/Users/ray/Desktop/Project-RHM_latest 2/deliverables/fyp_demo_20261031`

```sh
'/Users/ray/Desktop/Project-RHM_latest 2/generator/_build/install/default/bin/rhema' run --question main -I '/Users/ray/Desktop/Project-RHM_latest 2/generator/stdlib' demo_budget.rhm
```

Exit status: 0

```text
 1. Evaluate [`8 + 3 + (2 - 7)`].
    answer: 6
 2. Evaluate [`2 + (3 - 7 + 4)`].
    answer: 2
 3. Evaluate [`(9 + 3) \cdot 2`].
    answer: 24
 4. Evaluate [`4 + 4 + 4 + (8 + 6)`].
    answer: 26
 5. Evaluate [`3 + 5 + 5 - 9`].
    answer: 4

```

## extension_compile_equivalent

Working directory: `/var/folders/dr/hbzkf_0d2j924z7ch9xnqrd80000gn/T/rhema-extension-compile-7mkymhp_`

```sh
'/Users/ray/Desktop/Project-RHM_latest 2/generator/_build/install/default/bin/rhema' --question main -I '/Users/ray/Desktop/Project-RHM_latest 2/generator/stdlib' demo_budget.rhm
```

Exit status: 0

```text
(No standard output; inspect the generated files.)
```

## personalized_run

Working directory: `/Users/ray/Desktop/Project-RHM_latest 2/deliverables/fyp_demo_20261031`

```sh
'/Users/ray/Desktop/Project-RHM_latest 2/generator/_build/install/default/bin/rhema' run demo_budget.rhm -I '/Users/ray/Desktop/Project-RHM_latest 2/generator/stdlib' --question main --count 1 --assignment demo_budget.rhm:main --student FYP2026 --set cost=10
```

Exit status: 0

```text
 1. Evaluate [`3 + 9 + (4 - (8 + 6)) \cdot (9 - 8)`].
    answer: 2

```

## compile_with_debug_artifacts

Working directory: `/Users/ray/Desktop/Project-RHM_latest 2/deliverables/fyp_demo_20261031`

```sh
'/Users/ray/Desktop/Project-RHM_latest 2/generator/_build/install/default/bin/rhema' demo_budget.rhm -I '/Users/ray/Desktop/Project-RHM_latest 2/generator/stdlib' --question main --count 1 --assignment demo_budget.rhm:main --student FYP2026 --set cost=10 -o '/Users/ray/Desktop/Project-RHM_latest 2/deliverables/fyp_demo_20261031/output/cli/cost10.pg' --ast-out '/Users/ray/Desktop/Project-RHM_latest 2/deliverables/fyp_demo_20261031/output/cli/cost10_ast.txt' --visualization-out '/Users/ray/Desktop/Project-RHM_latest 2/deliverables/fyp_demo_20261031/output/cli/cost10_trees.html'
```

Exit status: 0

```text
(No standard output; inspect the generated files.)
```

## reproducible_replay

Working directory: `/Users/ray/Desktop/Project-RHM_latest 2/deliverables/fyp_demo_20261031`

```sh
'/Users/ray/Desktop/Project-RHM_latest 2/generator/_build/install/default/bin/rhema' demo_budget.rhm -I '/Users/ray/Desktop/Project-RHM_latest 2/generator/stdlib' --question main --count 1 --assignment demo_budget.rhm:main --student FYP2026 --set cost=10 -o -
```

Exit status: 0

```text
DOCUMENT();
loadMacros("PGstandard.pl", "MathObjects.pl", "PGML.pl");
Context("Numeric");

BEGIN_PGML
Evaluate [`3 + 9 + (4 - (8 + 6)) \cdot (9 - 8)`].[_____]{2}
END_PGML
ENDDOCUMENT();

```

## other_student_variant

Working directory: `/Users/ray/Desktop/Project-RHM_latest 2/deliverables/fyp_demo_20261031`

```sh
'/Users/ray/Desktop/Project-RHM_latest 2/generator/_build/install/default/bin/rhema' run demo_budget.rhm -I '/Users/ray/Desktop/Project-RHM_latest 2/generator/stdlib' --question main --count 1 --assignment demo_budget.rhm:main --student FYP2027 --set cost=10
```

Exit status: 0

```text
 1. Evaluate [`(7 - 6) \cdot (4 - 5 \cdot 3)`].
    answer: -11

```

## assignment_set

Working directory: `/Users/ray/Desktop/Project-RHM_latest 2/deliverables/fyp_demo_20261031`

```sh
'/Users/ray/Desktop/Project-RHM_latest 2/generator/_build/install/default/bin/rhema' run demo_assignment.rhm -I '/Users/ray/Desktop/Project-RHM_latest 2/generator/stdlib' --run defense --assignment demo_assignment.rhm:main --student FYP2026
```

Exit status: 0

```text
demo_assignment.rhm:main for FYP2026: 5 questions in 3 parts

1. Sequences

1  [seq.main; cost 2]
An arithmetic sequence has first term [`a_1 = -7`] and common difference [`d = -6`].
(a) Find [`a_{5}`]: [___]
(b) Find the sum [`S_{5}`]: [___]
    answers: -31; -95

2. Logic
  2(a)  [logic.main; cost 8]
Evaluate [`(r \to p) \to q`] when [`p = \mathsf{F}`], [`q = \mathsf{F}`] and [`r = \mathsf{T}`].
Enter 1 for true and 0 for false.
    answer: true
  2(b)  [logic.main; cost 10]
Evaluate [`(q \land \neg r) \leftrightarrow \neg p`] when [`p = \mathsf{F}`], [`q = \mathsf{T}`] and [`r = \mathsf{F}`].
Enter 1 for true and 0 for false.
    answer: true
  2(c)  [logic.main; cost 12]
Suppose [`p = \mathsf{F}`], [`q = \mathsf{T}`] and [`r = \mathsf{T}`]. What is the truth value of [`(q \lor \neg r) \to ((\neg q \lor p) \land r)`]?
Enter 1 for true and 0 for false.
    answer: false

3. Linear algebra

3  [eigen.main; cost 2]
Find the eigenvalues of [`A = \begin{pmatrix} 36 & 12 \\ -120 & -40 \end{pmatrix}`]. Enter the eigenvalues as a set, such as [`\{-1, 4\}`].
    answer: Set({-4, 0})

budget means:
  part 1 Sequences: cost 2.00 over 1
  part 2 Logic: cost 10.00 over 3
  part 3 Linear algebra: cost 2.00 over 1

```
