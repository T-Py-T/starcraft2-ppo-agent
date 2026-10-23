#!/usr/bin/env bash
set -euo pipefail

PYTHON_VERSION="${PYTHON_VERSION:-3.12}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: '$1' not found on PATH (install it before running local CI)" >&2
    exit 1
  fi
}

require_cmd uv

uv python install "${PYTHON_VERSION}"
uv sync --locked --extra dev --python "${PYTHON_VERSION}"

if [[ "$(uname -s)" == "Linux" ]]; then
  if ! uv run --python "${PYTHON_VERSION}" python -c "import cv2" >/dev/null 2>&1; then
    echo "error: OpenCV needs libGL (install system package, e.g. libgl1 on Debian/Ubuntu)" >&2
    exit 1
  fi
fi

export PYTHON_VERSION
make ci-test
