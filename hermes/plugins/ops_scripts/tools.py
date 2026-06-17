"""Tool registration and host execution for reviewed ops scripts."""

from __future__ import annotations

import json
import os
import re
import subprocess
from collections.abc import Callable, Iterable, Mapping, MutableMapping
from pathlib import Path
from typing import Any, cast

from .schemas import DEFAULT_MANIFEST_PATH, Language, ManifestTool, Tier

type JsonObject = dict[str, Any]
type ToolHandler = Callable[[Mapping[str, Any] | None], str]

_NAME_RE = re.compile(r"^[a-z][a-z0-9_]*$")
_VALID_TIERS = {"t1", "t3"}
_VALID_LANGUAGES = {"sh", "py"}


def load_manifest(path: Path = DEFAULT_MANIFEST_PATH) -> list[ManifestTool]:
    """Read a manifest and return valid tool definitions.

    The repo contract intentionally uses a small YAML subset. Keeping parsing
    local avoids adding a runtime dependency to the host ops path.
    """

    if not path.exists():
        raise FileNotFoundError(f"manifest not found: {path}")

    data = _parse_manifest_yaml(path.read_text(encoding="utf-8"))
    raw_tools = data.get("tools", [])
    if not isinstance(raw_tools, list):
        raise ValueError("manifest field 'tools' must be a list")

    return [_coerce_tool(raw_tool, index) for index, raw_tool in enumerate(raw_tools)]


def register_manifest_tools(
    ctx: Any,
    *,
    manifest_path: Path = DEFAULT_MANIFEST_PATH,
    repo_root: Path | None = None,
    runner: Callable[..., subprocess.CompletedProcess[str]] = subprocess.run,
) -> list[str]:
    """Register one Hermes tool per manifest entry and return their names."""

    root = repo_root or manifest_path.parent
    registered: list[str] = []
    for tool in load_manifest(manifest_path):
        handler = build_handler(tool, repo_root=root, runner=runner)
        _register_tool(ctx, tool, handler)
        registered.append(tool.name)
    return registered


def build_handler(
    tool: ManifestTool,
    *,
    repo_root: Path,
    runner: Callable[..., subprocess.CompletedProcess[str]] = subprocess.run,
) -> ToolHandler:
    """Build a Hermes handler that always returns a JSON string."""

    def handle(args: Mapping[str, Any] | None = None) -> str:
        payload = dict(args or {})
        if tool.requires_confirm and payload.get("confirm") is not True:
            return _json(
                {
                    "ok": False,
                    "requires_confirm": True,
                    "tool": tool.name,
                    "action": _command_for_display(tool, repo_root),
                    "target": tool.path,
                    "message": "T3 tool requires confirm=true before execution.",
                }
            )

        argv = _command_for_execution(tool, repo_root)
        try:
            completed = runner(
                argv,
                cwd=repo_root,
                env=os.environ.copy(),
                text=True,
                capture_output=True,
                check=False,
            )
        except Exception as exc:  # noqa: BLE001 - plugin contract is never-raise.
            return _json(
                {
                    "ok": False,
                    "tool": tool.name,
                    "error": type(exc).__name__,
                    "message": str(exc),
                }
            )

        return _json(
            {
                "ok": completed.returncode == 0,
                "tool": tool.name,
                "returncode": completed.returncode,
                "stdout": completed.stdout,
                "stderr": completed.stderr,
            }
        )

    return handle


def _coerce_tool(raw_tool: Any, index: int) -> ManifestTool:
    if not isinstance(raw_tool, dict):
        raise ValueError(f"manifest tool #{index} must be a mapping")

    name = _required_str(raw_tool, "name", index)
    if not _NAME_RE.fullmatch(name):
        raise ValueError(f"manifest tool #{index} has invalid name: {name!r}")

    tier_raw = _required_str(raw_tool, "tier", index).lower()
    if tier_raw not in _VALID_TIERS:
        raise ValueError(f"manifest tool {name!r} has invalid tier: {tier_raw!r}")
    tier = cast(Tier, tier_raw)

    language_raw = _required_str(raw_tool, "language", index).lower()
    if language_raw not in _VALID_LANGUAGES:
        raise ValueError(f"manifest tool {name!r} has invalid language: {language_raw!r}")
    language = cast(Language, language_raw)

    argv = raw_tool.get("argv", [])
    if not isinstance(argv, list) or not all(isinstance(item, str) for item in argv):
        raise ValueError(f"manifest tool {name!r} field 'argv' must be a list of strings")

    description = raw_tool.get("description", "")
    if not isinstance(description, str):
        raise ValueError(f"manifest tool {name!r} field 'description' must be a string")

    return ManifestTool(
        name=name,
        path=_required_str(raw_tool, "path", index),
        tier=tier,
        language=language,
        argv=tuple(argv),
        description=description,
    )


def _required_str(raw_tool: Mapping[str, Any], key: str, index: int) -> str:
    value = raw_tool.get(key)
    if not isinstance(value, str) or not value:
        raise ValueError(f"manifest tool #{index} field {key!r} must be a non-empty string")
    return value


def _register_tool(ctx: Any, tool: ManifestTool, handler: ToolHandler) -> None:
    description = tool.description or f"Run reviewed ops script {tool.name}."
    parameters: JsonObject = {
        "type": "object",
        "properties": {},
        "additionalProperties": False,
    }
    if tool.requires_confirm:
        parameters["properties"] = {
            "confirm": {
                "type": "boolean",
                "description": "Must be true after Hermes echoes the action and target.",
            }
        }
        parameters["required"] = ["confirm"]

    if hasattr(ctx, "register_tool"):
        ctx.register_tool(tool.name, handler, description=description, parameters=parameters)
        return

    tools = getattr(ctx, "tools", None)
    if tools is not None and hasattr(tools, "register"):
        tools.register(tool.name, handler, description=description, parameters=parameters)
        return

    if hasattr(ctx, "add_tool"):
        ctx.add_tool(tool.name, handler, description=description, parameters=parameters)
        return

    raise TypeError("Hermes context does not expose a supported tool registration method")


def _command_for_execution(tool: ManifestTool, repo_root: Path) -> list[str]:
    if tool.language == "py":
        command = tool.path.split()
        if command[:2] == ["python", "-m"]:
            return [*command, *tool.argv]
        return ["python", tool.path, *tool.argv]

    script = Path(tool.path)
    if not script.is_absolute():
        script = repo_root / script
    return [str(script), *tool.argv]


def _command_for_display(tool: ManifestTool, repo_root: Path) -> list[str]:
    return _command_for_execution(tool, repo_root)


def _parse_manifest_yaml(text: str) -> JsonObject:
    lines = list(_meaningful_lines(text))
    if not lines:
        return {"tools": []}

    tools: list[MutableMapping[str, Any]] = []
    index = 0
    saw_tools = False
    while index < len(lines):
        indent, content = lines[index]
        if indent == 0 and content == "tools: []":
            saw_tools = True
            index += 1
            continue
        if indent == 0 and content == "tools:":
            saw_tools = True
            index += 1
            while index < len(lines):
                item_indent, item_content = lines[index]
                if item_indent == 0:
                    break
                if item_indent != 2 or not item_content.startswith("- "):
                    raise ValueError("manifest tools must be a YAML list of mappings")
                tool: MutableMapping[str, Any] = {}
                inline = item_content[2:].strip()
                if inline:
                    key, value = _split_key_value(inline)
                    tool[key] = _parse_scalar_or_list(value)
                index += 1
                while index < len(lines):
                    field_indent, field_content = lines[index]
                    if field_indent <= item_indent:
                        break
                    if field_indent != 4:
                        raise ValueError("manifest tool fields must use 4-space indentation")
                    key, value = _split_key_value(field_content)
                    tool[key] = _parse_scalar_or_list(value)
                    index += 1
                tools.append(tool)
            continue
        index += 1

    if not saw_tools:
        raise ValueError("manifest must define a top-level 'tools' list")
    return {"tools": tools}


def _meaningful_lines(text: str) -> Iterable[tuple[int, str]]:
    for raw_line in text.splitlines():
        line = raw_line.split("#", 1)[0].rstrip()
        if not line:
            continue
        yield len(line) - len(line.lstrip(" ")), line.lstrip(" ")


def _split_key_value(content: str) -> tuple[str, str]:
    if ":" not in content:
        raise ValueError(f"manifest field must be key/value: {content!r}")
    key, value = content.split(":", 1)
    key = key.strip()
    if not key:
        raise ValueError("manifest field key cannot be empty")
    return key, value.strip()


def _parse_scalar_or_list(value: str) -> str | list[str]:
    if value == "[]":
        return []
    if value.startswith("[") and value.endswith("]"):
        inner = value[1:-1].strip()
        if not inner:
            return []
        return [_unquote(item.strip()) for item in inner.split(",")]
    return _unquote(value)


def _unquote(value: str) -> str:
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
        return value[1:-1]
    return value


def _json(payload: JsonObject) -> str:
    return json.dumps(payload, sort_keys=True)
