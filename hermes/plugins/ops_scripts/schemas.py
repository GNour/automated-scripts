"""Manifest schema for the ops_scripts Hermes plugin."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Literal

Tier = Literal["t1", "t3"]
Language = Literal["sh", "py"]

DEFAULT_MANIFEST_PATH = Path("/home/dev/projects/automated-scripts/manifest.yaml")


@dataclass(frozen=True)
class ManifestTool:
    """One reviewed manifest entry exposed as a named Hermes tool."""

    name: str
    path: str
    tier: Tier
    language: Language
    argv: tuple[str, ...] = ()
    description: str = ""

    @property
    def requires_confirm(self) -> bool:
        return self.tier == "t3"
