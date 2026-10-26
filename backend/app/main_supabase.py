"""Compatibility import; `app.main` is the sole implementation and ASGI entrypoint."""
from .main import app

__all__ = ["app"]
