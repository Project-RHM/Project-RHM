#!/usr/bin/env bash
set -euo pipefail

mkdir -p /app/runtime /app/generator/generated_questions \
    /app/generator/generated_asts /app/generator/generated_visualizations

# Build the Rhema CLI, its installed stdlib and the teacher-mode bridge.
# _build stays in the Linux container, separate from Windows artifacts.
(cd /app/generator && dune build)
exec "$@"
