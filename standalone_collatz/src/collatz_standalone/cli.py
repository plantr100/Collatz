"""Command-line interface for the standalone Collatz explorer."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Iterable

from .core import CollatzResult, run_collatz_sequence


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="collatz-cli",
        description="Compute Collatz sequences and export the results.",
    )
    parser.add_argument(
        "seed",
        type=int,
        help="Positive integer to feed into the Collatz sequence.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=256,
        help="Number of sequence elements to retain (default: 256).",
    )
    parser.add_argument(
        "--export-json",
        type=Path,
        help="Optional path to export the entire result as JSON.",
    )
    parser.add_argument(
        "--print-sequence",
        action="store_true",
        help="Echo the generated sequence to stdout.",
    )
    return parser


def _result_to_dict(result: CollatzResult) -> dict:
    return {
        "start_value": result.start_value,
        "steps": result.steps,
        "max_value": result.max_value,
        "truncated": result.truncated,
        "sequence": result.sequence,
    }


def run_cli(args: argparse.Namespace) -> CollatzResult:
    result = run_collatz_sequence(args.seed, limit=args.limit)

    print(result.as_summary())
    if args.print_sequence:
        print("\nSequence:")
        print(", ".join(str(n) for n in result.sequence))

    if args.export_json:
        args.export_json.write_text(
            json.dumps(_result_to_dict(result), indent=2), encoding="utf-8"
        )
        print(f"\nSaved JSON payload to {args.export_json}")

    return result


def main(argv: Iterable[str] | None = None) -> None:
    parser = _build_parser()
    args = parser.parse_args(argv)
    run_cli(args)


if __name__ == "__main__":
    main()
