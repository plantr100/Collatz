#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/build_unix.sh [debug]
# Creates a virtualenv, installs dependencies, and runs PyInstaller to
# generate dist/CollatzExplorer.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_PATH="${VENV_PATH:-$ROOT_DIR/.venv}"
CONFIG="${1:-release}"

cd "$ROOT_DIR"

if [[ ! -d "$VENV_PATH" ]]; then
  echo "Creating virtual environment at $VENV_PATH"
  python3 -m venv "$VENV_PATH"
fi

source "$VENV_PATH/bin/activate"
python -m pip install --upgrade pip
python -m pip install -e .[dev]

PYINSTALLER_ARGS=(
  "--name" "CollatzExplorer"
  "--windowed"
  "--noconfirm"
  "--clean"
  "src/collatz_standalone/__main__.py"
)

if [[ "${CONFIG,,}" == "debug" ]]; then
  PYINSTALLER_ARGS+=("--debug" "all")
fi

echo "Running PyInstaller..."
python -m PyInstaller "${PYINSTALLER_ARGS[@]}"
echo "Done. Executable is available under dist/CollatzExplorer."
