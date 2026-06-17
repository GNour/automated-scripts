#!/usr/bin/env bash
# backup-check: last restic→B2 snapshot time, age, and repo health as JSON.
#
# Usage: backup-check.sh [--help]
#
# Required env vars (never hardcoded or logged):
#   RESTIC_REPOSITORY          restic repo URL (e.g. b2:<bucket>:vps-1)
#   RESTIC_PASSWORD            restic encryption password
#     -or- RESTIC_PASSWORD_FILE  path to a file containing the password
#   B2_ACCOUNT_ID              Backblaze B2 application key ID
#   B2_ACCOUNT_KEY             Backblaze B2 application key
#
# Optional:
#   BACKUP_CHECK_STALE_HOURS   staleness threshold in hours (default: 26)
#
# stdout: JSON — last_snapshot_time, age_hours, stale, repo_healthy
# Exit:   0 success  1 config error  2 restic error
set -euo pipefail

STALE_HOURS="${BACKUP_CHECK_STALE_HOURS:-26}"

usage() {
  sed -n 's/^# \?//p' "$0"
  exit 0
}

case "${1:-}" in
  -h|--help) usage ;;
esac

# Validate required env vars — check presence only, never log values
missing=()
for var in RESTIC_REPOSITORY B2_ACCOUNT_ID B2_ACCOUNT_KEY; do
  if [[ -z "${!var:-}" ]]; then
    missing+=("$var")
  fi
done
if [[ -z "${RESTIC_PASSWORD:-}" && -z "${RESTIC_PASSWORD_FILE:-}" ]]; then
  missing+=("RESTIC_PASSWORD or RESTIC_PASSWORD_FILE")
fi
if (( ${#missing[@]} > 0 )); then
  printf 'error: missing env var(s): %s\n' "${missing[*]}" >&2
  exit 1
fi

snap_file=$(mktemp)
trap 'rm -f "$snap_file"' EXIT

# Fetch all snapshots (small set under the retention policy; take last in Python)
if ! restic snapshots --json 2>/dev/null >"$snap_file"; then
  printf '{"error":"restic snapshots failed"}\n'
  exit 2
fi

# Metadata-only health check — no data download, no exclusive lock
check_ok=0
restic check --no-lock 2>/dev/null || check_ok=$?
repo_healthy="true"
if (( check_ok != 0 )); then
  repo_healthy="false"
fi

# Parse snapshot, compute age, emit JSON
python3 - "$STALE_HOURS" "$repo_healthy" "$snap_file" <<'PYEOF'
import sys, json, re
from datetime import datetime, timezone

stale_hours = float(sys.argv[1])
repo_healthy = sys.argv[2] == "true"

with open(sys.argv[3]) as fh:
    try:
        data = json.load(fh)
    except json.JSONDecodeError as exc:
        print(json.dumps({"error": "JSON parse failed", "detail": str(exc)}))
        sys.exit(0)

if not data:
    print(json.dumps({"error": "no snapshots found in repository"}))
    sys.exit(0)

snap_time = data[-1]["time"]
# Strip sub-second precision; normalise Z → +00:00 for fromisoformat
ts_norm = re.sub(r"\.\d+", "", snap_time).replace("Z", "+00:00")
snap_dt = datetime.fromisoformat(ts_norm)
age_s = max(0.0, (datetime.now(timezone.utc) - snap_dt).total_seconds())
age_hours = round(age_s / 3600, 2)

print(json.dumps({
    "last_snapshot_time": snap_time,
    "age_hours": age_hours,
    "stale": age_hours > stale_hours,
    "repo_healthy": repo_healthy,
}, indent=2))
PYEOF
