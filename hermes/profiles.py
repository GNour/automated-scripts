"""Hermes profile plugin allowlists."""

from __future__ import annotations

OPS_ONLY_PLUGINS = frozenset({"ops_scripts"})


def is_plugin_allowed(profile: str, plugin_name: str) -> bool:
    """Return whether a plugin may be loaded for a Hermes profile."""

    if plugin_name in OPS_ONLY_PLUGINS:
        return profile == "ops"
    return True
