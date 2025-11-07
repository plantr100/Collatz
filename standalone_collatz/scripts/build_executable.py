#!/usr/bin/env python3
"""Cross-platform helper that drives PyInstaller via Python."""

from __future__ import annotations

import argparse
import pathlib
import sys

try:
    from PyInstaller.__main__ import run as pyinstaller_run
except ModuleNotFoundError as exc:  # noqa: BLE001
    raise SystemExit(
        "PyInstaller is not installed. Install optional dependency `.[dev]` first."
    ) from exc


def build_executable(*, name: str, debug: bool, onefile: bool) -> None:
    root = pathlib.Path(__file__).resolve().parents[1]
    entry = root / "src" / "collatz_standalone" / "__main__.py"
    dist_path = root / "dist"

    args = [
        f"--name={name}",
        "--windowed",
        "--noconfirm",
        "--clean",
        f"--distpath={dist_path}",
    ]

    if onefile:
        args.append("--onefile")
    if debug:
        args.append("--debug=all")

    args.append(str(entry))
    print(f"Running PyInstaller with args: {args}")
    pyinstaller_run(args)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Cross-platform PyInstaller driver.")
    parser.add_argument("--name", default="CollatzExplorer", help="Executable name.")
    parser.add_argument(
        "--onefile",
        action="store_true",
        help="Bundle as a single binary instead of a directory.",
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Emit a debug build with console output.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> None:
    args = parse_args(argv)
    build_executable(name=args.name, debug=args.debug, onefile=args.onefile)


if __name__ == "__main__":
    main(sys.argv[1:])
