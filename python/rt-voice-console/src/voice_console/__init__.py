"""Voice Console package root.

Reintroduced to allow hatchling to detect the package under src/ for building wheels/editable installs.
"""
from importlib.metadata import version, PackageNotFoundError

try:  # pragma: no cover - simple metadata fetch
    __version__ = version("rt-voice-console")
except PackageNotFoundError:  # pragma: no cover
    __version__ = "0.0.0+dev"

# Import the main function for console script access
from .voice_console import main

__all__ = ["__version__", "main"]