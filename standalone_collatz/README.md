# Collatz Standalone

This directory hosts a self-contained build of the Collatz explorer that can
ship as either a Python package, a CLI, or a Windows `.exe`. It contains:

- A reusable Python module (`collatz_standalone`) with Collatz utilities.
- A Tkinter GUI launcher (`python -m collatz_standalone` or `collatz-gui`).
- A CLI (`collatz-cli`) for scripted or batch analysis.
- Packaging scripts for generating a single-file Windows executable via
  PyInstaller.

## Quick start

```bash
cd standalone_collatz
python -m venv .venv
. .venv/bin/activate
sudo apt install python3-tk    # Linux: ensure Tkinter is available for the GUI
pip install -e .[dev]

# Launch the GUI
python -m collatz_standalone

# Or run the CLI
collatz-cli 97 --print-sequence --export-json results.json
```

## Building executables

### Windows (PowerShell)

```powershell
Set-Location standalone_collatz
.\scripts\build_windows.ps1               # creates dist/CollatzExplorer.exe
```

### macOS / Linux (Bash)

```bash
cd standalone_collatz
chmod +x scripts/build_unix.sh
./scripts/build_unix.sh                   # add "debug" for more logs
```

### Cross-platform via Python

After installing the optional `dev` dependencies (`pip install -e .[dev]`) you can
run the PyInstaller driver from any OS:

```bash
cd standalone_collatz
python scripts/build_executable.py --onefile
```

All scripts bootstrap a virtual environment (or reuse an existing one), install
PyInstaller, and populate `dist/` with the resulting launcher.

## Project structure

```
standalone_collatz/
├── pyproject.toml                # packaging metadata
├── scripts/
│   └── build_windows.ps1         # helper for producing an .exe
│   ├── build_unix.sh             # Bash build helper
│   └── build_executable.py       # Python-based cross-platform driver
└── src/collatz_standalone/
    ├── core.py                   # Collatz solver + data model
    ├── cli.py                    # argparse-based command line
    ├── gui.py                    # Tkinter desktop UI
    └── __main__.py               # entry point for python -m
```

The root-level shell scripts (`init*.sh`, `collatz_state.sh`, etc.) remain
unchanged so the original environment continues to work. The standalone build
focuses purely on portable Python components suitable for Windows packaging.
