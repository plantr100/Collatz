"""Tkinter GUI launcher for the Collatz explorer."""

from __future__ import annotations

import tkinter as tk
from tkinter import filedialog, messagebox, ttk

from .core import CollatzResult, run_collatz_sequence


class CollatzApp(tk.Tk):
    """Simple desktop window for visualising Collatz sequences."""

    def __init__(self) -> None:
        super().__init__()
        self.title("Collatz Explorer")
        self.geometry("640x480")
        self.minsize(540, 360)

        self.seed_var = tk.StringVar(value="27")
        self.limit_var = tk.StringVar(value="256")

        self._build_widgets()

    def _build_widgets(self) -> None:
        padding = {"padx": 8, "pady": 4}

        frm = ttk.Frame(self)
        frm.pack(fill=tk.BOTH, expand=True, **padding)

        seed_row = ttk.Frame(frm)
        seed_row.pack(fill=tk.X, **padding)
        ttk.Label(seed_row, text="Start value:").pack(side=tk.LEFT)
        ttk.Entry(seed_row, textvariable=self.seed_var, width=12).pack(
            side=tk.LEFT, padx=6
        )

        limit_row = ttk.Frame(frm)
        limit_row.pack(fill=tk.X, **padding)
        ttk.Label(limit_row, text="Display limit:").pack(side=tk.LEFT)
        ttk.Entry(limit_row, textvariable=self.limit_var, width=12).pack(
            side=tk.LEFT, padx=6
        )

        btn_row = ttk.Frame(frm)
        btn_row.pack(fill=tk.X, pady=8)
        ttk.Button(btn_row, text="Calculate", command=self._on_calculate).pack(
            side=tk.LEFT
        )
        ttk.Button(btn_row, text="Export JSON", command=self._on_export).pack(
            side=tk.LEFT, padx=6
        )

        self.summary_text = tk.Text(frm, height=5, wrap=tk.WORD)
        self.summary_text.pack(fill=tk.X, **padding)
        self.summary_text.configure(state=tk.DISABLED)

        self.sequence_box = tk.Listbox(frm, height=12)
        self.sequence_box.pack(fill=tk.BOTH, expand=True, **padding)

    def _parse_inputs(self) -> tuple[int, int]:
        try:
            seed = int(self.seed_var.get())
            limit = int(self.limit_var.get())
            if seed < 1 or limit < 1:
                raise ValueError
            return seed, limit
        except ValueError:
            messagebox.showerror(
                title="Invalid input",
                message="Please provide positive integers for both fields.",
            )
            raise

    def _run_sequence(self) -> CollatzResult | None:
        try:
            seed, limit = self._parse_inputs()
        except ValueError:
            return None

        try:
            return run_collatz_sequence(seed, limit=limit)
        except Exception as exc:  # noqa: BLE001
            messagebox.showerror(title="Error", message=str(exc))
            return None

    def _update_display(self, result: CollatzResult) -> None:
        self.summary_text.configure(state=tk.NORMAL)
        self.summary_text.delete("1.0", tk.END)
        self.summary_text.insert(tk.END, result.as_summary())
        self.summary_text.configure(state=tk.DISABLED)

        self.sequence_box.delete(0, tk.END)
        for idx, value in enumerate(result.sequence, start=1):
            self.sequence_box.insert(tk.END, f"{idx:>4}: {value}")

    def _on_calculate(self) -> None:
        result = self._run_sequence()
        if result:
            self._update_display(result)

    def _on_export(self) -> None:
        result = self._run_sequence()
        if not result:
            return

        path = filedialog.asksaveasfilename(
            defaultextension=".json",
            filetypes=[("JSON", "*.json"), ("All Files", "*.*")],
            title="Save sequence as JSON",
        )
        if not path:
            return

        try:
            from .cli import _result_to_dict  # lazy import to avoid CLI deps
            import json

            with open(path, "w", encoding="utf-8") as fh:
                json.dump(_result_to_dict(result), fh, indent=2)
        except Exception as exc:  # noqa: BLE001
            messagebox.showerror(title="Export failed", message=str(exc))
        else:
            messagebox.showinfo(title="Export complete", message=f"Saved to {path}")


def run_app() -> None:
    CollatzApp().mainloop()


if __name__ == "__main__":
    run_app()
