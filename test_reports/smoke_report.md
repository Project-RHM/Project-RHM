# Question Generator Test Report

- Started: `2026-06-15T14:27:02`
- Finished: `2026-06-15T14:27:18`
- Cases run: `15`
- Passed: `15`
- Failed: `0`
- Bugs found: `0`
- WeBWorK skipped: `15`
- Seeds per case: `1`

> Online WeBWorK validation was skipped for some/all cases because `WEBWORK_VALIDATE_URL` was not set. Local PGML/static/semantic checks still ran.

## Case Summary

| Case | Seed | Status | Detected Kinds | WeBWorK | PGML File |
|---|---|---:|---|---|---|
| `all_mixed` | `test_all_mixed_1` | `PASS` | arithmetic, boolean, boolean_equiv, boolean_eval, calculus, calculus_derivative, calculus_integral, complex, complex_arithmetic, complex_conjugate, complex_power_i, set, vector | `SKIPPED` | `generator/generated_questions/test_all_mixed_1_20260615_142705.pg` |
| `arithmetic_only` | `test_arithmetic_only_1` | `PASS` | arithmetic | `SKIPPED` | `generator/generated_questions/test_arithmetic_only_1_20260615_142706.pg` |
| `set_only` | `test_set_only_1` | `PASS` | set | `SKIPPED` | `generator/generated_questions/test_set_only_1_20260615_142707.pg` |
| `vector_only` | `test_vector_only_1` | `PASS` | vector | `SKIPPED` | `generator/generated_questions/test_vector_only_1_20260615_142707.pg` |
| `calculus_mixed` | `test_calculus_mixed_1` | `PASS` | calculus, calculus_derivative, calculus_integral | `SKIPPED` | `generator/generated_questions/test_calculus_mixed_1_20260615_142708.pg` |
| `calculus_derivative_only` | `test_calculus_derivative_only_1` | `PASS` | calculus, calculus_derivative | `SKIPPED` | `generator/generated_questions/test_calculus_derivative_only_1_20260615_142709.pg` |
| `calculus_integral_only` | `test_calculus_integral_only_1` | `PASS` | calculus, calculus_integral | `SKIPPED` | `generator/generated_questions/test_calculus_integral_only_1_20260615_142710.pg` |
| `boolean_mixed` | `test_boolean_mixed_1` | `PASS` | boolean, boolean_equiv, boolean_eval | `SKIPPED` | `generator/generated_questions/test_boolean_mixed_1_20260615_142712.pg` |
| `boolean_evaluation_only` | `test_boolean_evaluation_only_1` | `PASS` | boolean, boolean_eval | `SKIPPED` | `generator/generated_questions/test_boolean_evaluation_only_1_20260615_142713.pg` |
| `boolean_equivalence_only` | `test_boolean_equivalence_only_1` | `PASS` | boolean, boolean_equiv | `SKIPPED` | `generator/generated_questions/test_boolean_equivalence_only_1_20260615_142714.pg` |
| `complex_mixed` | `test_complex_mixed_1` | `PASS` | complex, complex_arithmetic, complex_conjugate, complex_modulus, complex_power_i | `SKIPPED` | `generator/generated_questions/test_complex_mixed_1_20260615_142715.pg` |
| `complex_arithmetic_only` | `test_complex_arithmetic_only_1` | `PASS` | complex, complex_arithmetic | `SKIPPED` | `generator/generated_questions/test_complex_arithmetic_only_1_20260615_142716.pg` |
| `complex_conjugate_only` | `test_complex_conjugate_only_1` | `PASS` | complex, complex_conjugate | `SKIPPED` | `generator/generated_questions/test_complex_conjugate_only_1_20260615_142716.pg` |
| `complex_modulus_only` | `test_complex_modulus_only_1` | `PASS` | complex, complex_modulus | `SKIPPED` | `generator/generated_questions/test_complex_modulus_only_1_20260615_142717.pg` |
| `complex_power_i_only` | `test_complex_power_i_only_1` | `PASS` | complex, complex_power_i | `SKIPPED` | `generator/generated_questions/test_complex_power_i_only_1_20260615_142718.pg` |

## Bugs

No bugs found by the configured tests.

## Notes

- Boolean evaluation/equivalence answers are rechecked locally with direct evaluation/truth tables.
- Complex arithmetic/conjugate/modulus/i^n answers are rechecked locally with Python complex arithmetic.
- Arithmetic answers are rechecked locally for generated numeric expressions.
- Set, Vector, and Calculus checks are structural locally; full answer grading for those should be delegated to a configured WeBWorK endpoint.
- The script restores `config_setting/config.json` and `generator/config.ml` after running.
