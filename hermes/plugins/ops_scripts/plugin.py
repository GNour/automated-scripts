"""Hermes plugin entrypoint."""

from __future__ import annotations

from typing import Any

from .schemas import DEFAULT_MANIFEST_PATH
from .tools import register_manifest_tools


def register(ctx: Any) -> list[str]:
    """Register manifest-driven ops script tools with Hermes."""

    return register_manifest_tools(ctx, manifest_path=DEFAULT_MANIFEST_PATH)
