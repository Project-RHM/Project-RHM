#!/bin/sh
# Every example file the documentation shows must check and run: each
# question of each file is generated, and each set is generated in full.
# Usage: tools/check_doc_examples.sh [RHEMA]   (default: rhema on PATH)
set -eu
RHEMA=${1:-rhema}
# A path given relative to where the script was called from stays valid
# after the cd below.
case "$RHEMA" in
  */*) RHEMA="$(cd "$(dirname "$RHEMA")" && pwd)/$(basename "$RHEMA")" ;;
esac
cd "$(dirname "$0")/../docs/examples"
for file in *.rhm; do
  "$RHEMA" check "$file"
  questions=$("$RHEMA" list "$file" | awk '/^questions:/{q=1; next} /^[a-z]/{q=0} q && NF {print $1}')
  for question in $questions; do
    "$RHEMA" run "$file" --question "$question" --count 20 > /dev/null
  done
  sets=$("$RHEMA" list "$file" | awk '/^sets:/{s=1; next} /^[a-z]/{s=0} s && NF {print $1}')
  for set in $sets; do
    "$RHEMA" run "$file" --run "$set" > /dev/null
  done
done
echo "documentation examples: all checked and run"
