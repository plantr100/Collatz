"""Core utilities for working with Collatz sequences."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable, List


@dataclass(slots=True)
class CollatzResult:
    """Container for the outcome of a Collatz walk."""

    start_value: int
    steps: int
    max_value: int
    sequence: List[int]
    truncated: bool

    def as_summary(self) -> str:
        """Return a short human-readable summary."""
        summary = (
            f"Start: {self.start_value}\n"
            f"Steps to 1: {self.steps}\n"
            f"Max value: {self.max_value}\n"
            f"Sequence length: {len(self.sequence)}"
        )
        if self.truncated:
            summary += "\n(Sequence trimmed to display limit)"
        return summary


def run_collatz_sequence(
    value: int, *, limit: int | None = 2048, guard: int = 1_000_000
) -> CollatzResult:
    """Compute the Collatz sequence for ``value``.

    Parameters
    ----------
    value:
        Positive integer to start from.
    limit:
        Truncate the stored sequence after ``limit`` entries (None means no truncation).
    guard:
        Hard stop for the iterator to avoid runaway loops if the Collatz conjecture
        turns out to fail for some large seed.
    """

    if value < 1:
        raise ValueError("Collatz sequence requires a positive integer.")

    current = value
    sequence: List[int] = [current]
    max_value = current
    truncated = False

    steps = 0

    for _ in range(guard):
        if current == 1:
            break

        current = current // 2 if current % 2 == 0 else 3 * current + 1
        steps += 1
        max_value = max(max_value, current)

        if limit is None or len(sequence) < limit:
            sequence.append(current)
        else:
            truncated = True

    else:
        raise RuntimeError(
            "Guard rail reached while iterating. "
            "Increase `guard` if you need longer traces."
        )

    return CollatzResult(
        start_value=value,
        steps=steps,
        max_value=max_value,
        sequence=sequence,
        truncated=truncated,
    )
