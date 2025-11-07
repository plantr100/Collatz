try:  # pragma: no cover - tiny shim
    from .gui import run_app
except ImportError:  # Happens when PyInstaller treats this as a flat script
    from collatz_standalone.gui import run_app  # type: ignore[no-redef]


def main() -> None:
    run_app()


if __name__ == "__main__":
    main()
