"""Typed, teacher-facing adapters to existing Rhema mathematical primitives."""

OPERATIONS = []


def operation(name, label, group, output, arguments, *, operator=None):
    OPERATIONS.append({"id": name, "label": label, "group": group, "output": output,
                       "arguments": [{"name": n, "type": t, "default": default}
                                     for n, t, default in arguments], "operator": operator})


N = lambda name, default=1: (name, "Number", default)
T = lambda name, default="x": (name, "Text", default)
B = lambda name, default=True: (name, "Truth", default)
V = lambda name, kind: (name, kind, None)

for name, label, symbol in (("add", "Add numbers", "+"), ("subtract", "Subtract numbers", "-"),
                             ("multiply", "Multiply numbers", "*"), ("divide", "Divide numbers", "/"),
                             ("power", "Raise a number to a power", "^"), ("modulo", "Remainder", "%")):
    operation(name, label, "Numbers and sequences", "Number", [N("Left"), N("Right", 2)], operator=symbol)
for name, label, symbol in (("equal", "Numbers are equal", "="), ("not_equal", "Numbers are different", "!="),
                             ("less", "Less than", "<"), ("greater", "Greater than", ">"),
                             ("at_least", "Greater than or equal", ">="), ("at_most", "Less than or equal", "<=")):
    operation(name, label, "Conditions", "Truth", [N("Left"), N("Right")], operator=symbol)
operation("both", "Both conditions", "Conditions", "Truth", [B("First"), B("Second")], operator="and")
operation("either", "Either condition", "Conditions", "Truth", [B("First"), B("Second")], operator="or")
operation("not_condition", "Negate condition", "Conditions", "Truth", [B("Condition")], operator="not")
operation("cond", "Choose a number by condition", "Conditions", "Number", [B("Condition"), N("If true"), N("If false", 0)])
for name, label in (("abs", "Absolute value"), ("min", "Minimum"), ("max", "Maximum")):
    operation(name, label, "Numbers and sequences", "Number", [N("Number")] if name == "abs" else [N("First"), N("Second", 2)])

for name, label, args in (
    ("formula_constant", "Constant formula", [N("Value")]),
    ("formula_variable", "Formula variable", [T("Variable")]),
    ("formula_power", "Power of a formula", [V("Formula", "Formula"), N("Exponent", 2)]),
    ("formula_substitute", "Substitute a formula", [V("Formula", "Formula"), T("Variable"), V("Replacement", "Formula")]),
    ("differentiate", "Differentiate a formula", [V("Formula", "Formula"), T("Variable")])):
    operation(name, label, "Formulas and calculus", "Formula", args)
for suffix, label in (("add", "Add formulas"), ("subtract", "Subtract formulas"), ("multiply", "Multiply formulas"), ("divide", "Divide formulas")):
    operation("formula_" + suffix, label, "Formulas and calculus", "Formula", [V("First", "Formula"), V("Second", "Formula")])
for suffix, label in (("negate", "Negate formula"), ("sin", "Sine"), ("cos", "Cosine"), ("tan", "Tangent"),
                      ("exp", "Exponential"), ("ln", "Natural logarithm"), ("sqrt", "Square root")):
    operation("formula_" + suffix, label, "Formulas and calculus", "Formula", [V("Formula", "Formula")])
operation("formula_is_zero", "Formula is zero", "Conditions", "Truth", [V("Formula", "Formula")])
operation("formula_to_polynomial", "Convert formula to polynomial", "Polynomials", "Polynomial", [V("Formula", "Formula"), T("Variable")])

for name, label, args in (
    ("polynomial_constant", "Constant polynomial", [N("Value"), T("Variable")]),
    ("polynomial_variable", "Polynomial variable", [T("Variable")]),
    ("polynomial_monomial", "Monomial", [N("Coefficient"), N("Exponent", 2), T("Variable")]),
    ("polynomial_linear", "Linear polynomial", [N("Coefficient of x"), N("Constant", 2), T("Variable")]),
    ("polynomial_quadratic", "Quadratic polynomial", [N("Coefficient of x squared", 2), N("Coefficient of x", -3), N("Constant"), T("Variable")]),
    ("polynomial_scale", "Scale polynomial", [N("Scale", 2), V("Polynomial", "Polynomial")]),
    ("polynomial_power", "Power of polynomial", [V("Polynomial", "Polynomial"), N("Exponent", 2)]),
    ("polynomial_derivative", "Differentiate polynomial", [V("Polynomial", "Polynomial")])):
    operation(name, label, "Polynomials", "Polynomial", args)
for suffix, label in (("add", "Add polynomials"), ("subtract", "Subtract polynomials"), ("multiply", "Multiply polynomials")):
    operation("polynomial_" + suffix, label, "Polynomials", "Polynomial", [V("First", "Polynomial"), V("Second", "Polynomial")])
operation("polynomial_evaluate", "Evaluate polynomial at a point", "Polynomials", "Number", [V("Polynomial", "Polynomial"), N("Point", 2)])
operation("polynomial_coefficient", "Extract a coefficient", "Polynomials", "Number", [V("Polynomial", "Polynomial"), N("Exponent", 2)])
operation("polynomial_degree", "Degree of polynomial", "Polynomials", "Number", [V("Polynomial", "Polynomial")])
operation("polynomial_is_zero", "Polynomial is zero", "Conditions", "Truth", [V("Polynomial", "Polynomial")])
operation("polynomial_formula", "Convert polynomial to formula", "Formulas and calculus", "Formula", [V("Polynomial", "Polynomial")])

operation("equation", "Equation between formulas", "Equations", "Equation", [V("Left side", "Formula"), V("Right side", "Formula")])
operation("polynomial_equation", "Equation between polynomials", "Equations", "Equation", [V("Left side", "Polynomial"), V("Right side", "Polynomial")])
operation("equation_normal_form", "Equation normal form", "Equations", "Formula", [V("Equation", "Equation")])
for name, label, kind in (("equation_has_exact_solutions", "Equation has exact solutions", "Truth"),
                          ("equation_solution_count", "Number of exact solutions", "Number"),
                          ("equation_solution_set", "Set of exact solutions", "FiniteSet"),
                          ("equation_unique_solution", "Unique exact solution", "Number")):
    operation(name, label, "Equations", kind, [V("Equation", "Equation"), T("Variable")])
operation("equation_is_satisfied", "Value satisfies equation", "Conditions", "Truth", [V("Equation", "Equation"), T("Variable"), N("Value")])

operation("complex", "Complex number from components", "Complex numbers", "Complex", [N("Real part", 2), N("Imaginary part", 3)])
operation("complex_latex", "Complex-number notation", "Complex numbers", "MathText", [N("Real part", 2), N("Imaginary part", 3)])

operation("bool_var", "Boolean variable", "Boolean algebra", "Boolean", [T("Variable", "p")])
for name, label in (("bool_true", "True expression"), ("bool_false", "False expression")):
    operation(name, label, "Boolean algebra", "Boolean", [])
operation("bool_not", "NOT expression", "Boolean algebra", "Boolean", [V("Expression", "Boolean")])
for name, label in (("bool_and", "AND expressions"), ("bool_or", "OR expressions"), ("bool_xor", "XOR expressions"),
                    ("bool_imp", "Implication"), ("bool_iff", "Biconditional")):
    operation(name, label, "Boolean algebra", "Boolean", [V("First", "Boolean"), V("Second", "Boolean")])
operation("bool_equivalent", "Expressions are equivalent", "Boolean algebra", "Truth", [V("First", "Boolean"), V("Second", "Boolean")])
operation("bool_evaluate", "Evaluate under an assignment", "Boolean algebra", "Truth", [V("Expression", "Boolean"), T("Variable order", "p,q"), N("Assignment mask", 0)])
operation("bool_sensitivity", "Assignment sensitivity", "Boolean algebra", "Number", [V("Expression", "Boolean"), T("Variable order", "p,q"), N("Assignment mask", 0)])
for suffix, label in (("is_tautology", "Always true"), ("is_contradiction", "Always false"), ("is_tidy", "Expression is tidy"), ("is_atom", "Expression is an atom")):
    operation("bool_" + suffix, label, "Boolean algebra", "Truth", [V("Expression", "Boolean")])
for suffix, label in (("size", "Expression size"), ("negations", "Number of negations"), ("depth", "Expression depth"),
                      ("variable_count", "Number of distinct variables"), ("model_count", "Number of satisfying assignments")):
    operation("bool_" + suffix, label, "Boolean algebra", "Number", [V("Expression", "Boolean")])
operation("bool_count", "Count a connective", "Boolean algebra", "Number", [V("Expression", "Boolean"), T("Connective", "and")])
operation("bool_without_conditionals", "Remove conditional connectives", "Boolean algebra", "Boolean", [V("Expression", "Boolean")])

for size in (2, 3):
    operation("matrix" + str(size), f"{size} x {size} matrix", "Matrices", "Matrix",
              [N(f"Row {row + 1}, column {column + 1}", int(row == column)) for row in range(size) for column in range(size)])
operation("matrix_identity", "Identity matrix", "Matrices", "Matrix", [N("Dimension", 2)])
for suffix, label in (("add", "Add matrices"), ("subtract", "Subtract matrices"), ("multiply", "Multiply matrices")):
    operation("matrix_" + suffix, label, "Matrices", "Matrix", [V("First", "Matrix"), V("Second", "Matrix")])
operation("matrix_scale", "Scale matrix", "Matrices", "Matrix", [N("Scale", 2), V("Matrix", "Matrix")])
for suffix, label in (("transpose", "Transpose matrix"), ("inverse", "Invert matrix")):
    operation("matrix_" + suffix, label, "Matrices", "Matrix", [V("Matrix", "Matrix")])
operation("matrix_determinant", "Matrix determinant", "Matrices", "Number", [V("Matrix", "Matrix")])
operation("matrix_is_invertible", "Matrix is invertible", "Conditions", "Truth", [V("Matrix", "Matrix")])
operation("matrix_entry", "Matrix entry", "Matrices", "Number", [V("Matrix", "Matrix"), N("Row"), N("Column")])
operation("matrix_vector", "Multiply matrix and vector", "Matrices", "Vector", [V("Matrix", "Matrix"), V("Vector", "Vector")])
for size in (2, 3, 4):
    operation("vector" + str(size), f"{size}-dimensional vector", "Vectors", "Vector", [N(f"Component {n + 1}", n + 1) for n in range(size)])
for suffix, label, result in (("add", "Add vectors", "Vector"), ("subtract", "Subtract vectors", "Vector"),
                              ("dot", "Dot product", "Number"), ("cross", "Cross product", "Vector")):
    operation("vector_" + suffix, label, "Vectors", result, [V("First", "Vector"), V("Second", "Vector")])
operation("vector_scale", "Scale vector", "Vectors", "Vector", [N("Scale", 2), V("Vector", "Vector")])
operation("vector_entry", "Vector component", "Vectors", "Number", [V("Vector", "Vector"), N("Index")])
operation("vector_is_zero", "Vector is zero", "Conditions", "Truth", [V("Vector", "Vector")])
for suffix, label, result in (("norm_answer", "Magnitude of vector", "VectorNormAnswer"), ("unit_answer", "Unit vector", "VectorUnitAnswer"),
                              ("parallel_answer", "A parallel vector", "VectorDirectionAnswer"), ("same_direction_answer", "A vector in the same direction", "VectorDirectionAnswer")):
    operation("vector_" + suffix, label, "Vectors", result, [V("Vector", "Vector")])

operation("set_empty", "Empty finite set", "Sets", "FiniteSet", [])
operation("set_insert", "Insert element into finite set", "Sets", "FiniteSet", [V("Set", "FiniteSet"), N("Element")])
operation("set_interval", "Interval", "Sets", "Set", [N("Lower", 0), N("Upper", 4), B("Include lower"), B("Include upper")])
for name, label in (("set_above", "Interval above a bound"), ("set_below", "Interval below a bound")):
    operation(name, label, "Sets", "Set", [N("Bound"), B("Include bound")])
for suffix, label in (("union", "Union of sets"), ("intersection", "Intersection of sets"), ("difference", "Set difference")):
    operation("set_" + suffix, label, "Sets", "Set", [V("First", "Set"), V("Second", "Set")])

for name, label, args in (("factorial", "Factorial", [N("n", 5)]), ("choose", "Combinations", [N("n", 5), N("k", 2)]),
                         ("permutations", "Permutations", [N("n", 5), N("k", 2)]), ("gcd", "Greatest common divisor", [N("First", 12), N("Second", 8)]),
                         ("lcm", "Least common multiple", [N("First", 3), N("Second", 4)]),
                         ("pow_mod", "Modular power", [N("Base", 2), N("Exponent", 3), N("Modulus", 5)]),
                         ("mod_inverse", "Modular inverse", [N("Number", 3), N("Modulus", 7)])):
    operation(name, label, "Counting and number theory", "Number", args)

BY_ID = {item["id"]: item for item in OPERATIONS}
CONTEXTS = {"Number": "Numeric", "Truth": "Numeric", "Formula": "Numeric", "Polynomial": "Numeric",
            "Complex": "Complex", "Boolean": "Boolean", "Matrix": "Matrix", "Set": "Interval", "FiniteSet": "Interval", "Vector": "Vector",
            "VectorNormAnswer": "Vector", "VectorUnitAnswer": "Vector", "VectorDirectionAnswer": "Vector"}
RENDERERS = {"Number": "str", "Formula": "formula_latex", "Polynomial": "polynomial_latex", "Equation": "equation_latex",
             "Boolean": "bool_latex", "Matrix": "matrix_latex", "Set": "set_latex", "FiniteSet": "set_latex", "Vector": "vector_latex"}
