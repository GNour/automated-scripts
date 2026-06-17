from __future__ import annotations

import json
import subprocess
from pathlib import Path
from typing import Any

from hermes.plugins.ops_scripts.schemas import ManifestTool
from hermes.plugins.ops_scripts.tools import build_handler, load_manifest, register_manifest_tools


class FakeContext:
    def __init__(self) -> None:
        self.tools: dict[str, dict[str, Any]] = {}

    def register_tool(
        self,
        name: str,
        handler: object,
        *,
        description: str,
        parameters: dict[str, Any],
    ) -> None:
        self.tools[name] = {
            "handler": handler,
            "description": description,
            "parameters": parameters,
        }


def write_manifest(tmp_path: Path, body: str) -> Path:
    manifest = tmp_path / "manifest.yaml"
    manifest.write_text(body, encoding="utf-8")
    return manifest


def test_empty_manifest_registers_no_tools(tmp_path: Path) -> None:
    manifest = write_manifest(tmp_path, "tools: []\n")
    ctx = FakeContext()

    registered = register_manifest_tools(ctx, manifest_path=manifest)

    assert registered == []
    assert ctx.tools == {}


def test_manifest_registers_named_tool_with_fixed_argv(tmp_path: Path) -> None:
    manifest = write_manifest(
        tmp_path,
        """
tools:
  - name: vps_health
    path: shell/health-report.sh
    tier: t1
    language: sh
    argv: ["--json"]
    description: VPS health report
""",
    )
    ctx = FakeContext()

    registered = register_manifest_tools(ctx, manifest_path=manifest)

    assert registered == ["vps_health"]
    assert set(ctx.tools) == {"vps_health"}
    assert ctx.tools["vps_health"]["parameters"]["additionalProperties"] is False


def test_t1_handler_runs_host_subprocess_with_fixed_command(tmp_path: Path) -> None:
    calls: list[list[str]] = []
    tool = ManifestTool(
        name="vps_health",
        path="shell/health-report.sh",
        tier="t1",
        language="sh",
        argv=("--json",),
    )

    def runner(argv: list[str], **_: object) -> subprocess.CompletedProcess[str]:
        calls.append(argv)
        return subprocess.CompletedProcess(argv, 0, stdout='{"ok": true}', stderr="")

    handler = build_handler(tool, repo_root=tmp_path, runner=runner)

    result = json.loads(handler({}))

    assert result["ok"] is True
    assert result["stdout"] == '{"ok": true}'
    assert calls == [[str(tmp_path / "shell/health-report.sh"), "--json"]]


def test_t3_handler_requires_confirm_before_running(tmp_path: Path) -> None:
    calls: list[list[str]] = []
    tool = ManifestTool(
        name="docker_cleanup",
        path="shell/docker-cleanup.sh",
        tier="t3",
        language="sh",
        argv=("--dry-run",),
    )

    def runner(argv: list[str], **_: object) -> subprocess.CompletedProcess[str]:
        calls.append(argv)
        return subprocess.CompletedProcess(argv, 0, stdout="{}", stderr="")

    handler = build_handler(tool, repo_root=tmp_path, runner=runner)

    blocked = json.loads(handler({}))
    allowed = json.loads(handler({"confirm": True}))

    assert blocked["ok"] is False
    assert blocked["requires_confirm"] is True
    assert blocked["target"] == "shell/docker-cleanup.sh"
    assert calls == [[str(tmp_path / "shell/docker-cleanup.sh"), "--dry-run"]]
    assert allowed["ok"] is True


def test_handler_returns_error_json_instead_of_raising(tmp_path: Path) -> None:
    tool = ManifestTool(name="broken", path="shell/broken.sh", tier="t1", language="sh")

    def runner(*_: object, **__: object) -> subprocess.CompletedProcess[str]:
        raise OSError("boom")

    handler = build_handler(tool, repo_root=tmp_path, runner=runner)

    result = json.loads(handler({}))

    assert result == {
        "error": "OSError",
        "message": "boom",
        "ok": False,
        "tool": "broken",
    }


def test_manifest_validation_rejects_open_argv_passthrough(tmp_path: Path) -> None:
    manifest = write_manifest(
        tmp_path,
        """
tools:
  - name: bad_tool
    path: shell/bad.sh
    tier: t1
    language: sh
    argv: --model-supplied
""",
    )

    try:
        load_manifest(manifest)
    except ValueError as exc:
        assert "argv" in str(exc)
    else:
        raise AssertionError("invalid manifest should fail validation")
