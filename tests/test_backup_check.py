import json
import os
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]


def test_backup_check_rejects_invalid_stale_hours(tmp_path: Path) -> None:
    restic = tmp_path / "restic"
    restic.write_text(
        """#!/usr/bin/env bash
set -euo pipefail

case "$1" in
  snapshots)
    printf '[{"time":"2026-06-17T00:00:00Z"}]\\n'
    ;;
  check)
    exit 0
    ;;
  *)
    exit 64
    ;;
esac
""",
        encoding="utf-8",
    )
    restic.chmod(0o755)

    env = {
        **os.environ,
        "PATH": f"{tmp_path}{os.pathsep}{os.environ['PATH']}",
        "RESTIC_REPOSITORY": "b2:example:vps-1",
        "RESTIC_PASSWORD": "placeholder-password",
        "B2_ACCOUNT_ID": "placeholder-account",
        "B2_ACCOUNT_KEY": "placeholder-key",
        "BACKUP_CHECK_STALE_HOURS": "notanumber",
    }

    result = subprocess.run(
        [str(REPO_ROOT / "shell" / "backup-check.sh")],
        check=False,
        env=env,
        text=True,
        capture_output=True,
    )

    assert result.returncode == 1
    assert json.loads(result.stdout) == {
        "error": "invalid BACKUP_CHECK_STALE_HOURS: notanumber",
    }
    assert "Traceback" not in result.stdout
    assert "Traceback" not in result.stderr
