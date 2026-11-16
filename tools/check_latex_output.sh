#!/bin/sh
# A paper of every question and every set of the library must compile to a
# PDF, with its answer key. This needs a TeX engine on the machine (rhema
# uses the first of pdflatex, xelatex, lualatex and tectonic it finds, or the
# one RHEMA_LATEX names); the package's own tests check what is written and
# run no TeX.
# Usage: tools/check_latex_output.sh [RHEMA] [OUTDIR]
#   RHEMA   the command (default: rhema on PATH)
#   OUTDIR  where the PDFs go (default: a new temporary directory, kept)
set -eu
RHEMA=${1:-rhema}
case "$RHEMA" in
  */*) RHEMA="$(cd "$(dirname "$RHEMA")" && pwd)/$(basename "$RHEMA")" ;;
esac
OUT=${2:-$(mktemp -d "${TMPDIR:-/tmp}/rhema-papers.XXXXXX")}
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
cd "$(dirname "$0")/../generator/stdlib"

total=0
failed=0
paper() {
  # paper NAME ARGUMENTS...: compile one paper, with its key
  name=$1
  shift
  total=$((total + 1))
  if ! "$RHEMA" "$@" --answers -o "$OUT/$name.pdf" > "$OUT/$name.log" 2>&1; then
    failed=$((failed + 1))
    echo "FAILED $name: $(head -3 "$OUT/$name.log" | tr '\n' ' ')"
  fi
}

for file in *.rhm; do
  stem=${file%.rhm}
  questions=$("$RHEMA" list "$file" | awk '/^questions:/{q=1; next} /^[a-z]/{q=0} q && NF {print $1}')
  for question in $questions; do
    paper "$stem-$question" "$file" --question "$question" --count 30
  done
  sets=$("$RHEMA" list "$file" | awk '/^sets:/{s=1; next} /^[a-z]/{s=0} s && NF {print $1}')
  for set in $sets; do
    paper "$stem-set-$set" "$file" --run "$set"
  done
done

# The grammars that grow with the budget, at their largest.
for stem in partial_fractions taylor inequality partial_derivatives row_reduction base_conversion definite_integral; do
  paper "$stem-budget-8" "$stem.rhm" --count 30 --set cost=8
done
paper "boolean-budget-14" boolean.rhm --count 30 --set cost=14
paper "calculus-budget-12" calculus.rhm --count 30 --set cost=12
paper "arithmetic-budget-20" arithmetic.rhm --count 30 --set cost=20

echo "LaTeX output: $((total - failed)) of $total papers compiled; they are in $OUT"
[ "$failed" -eq 0 ]
