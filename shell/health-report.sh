#!/usr/bin/env bash
# health-report.sh — Emit VPS host health metrics as JSON.
#
# Usage: ./health-report.sh
#
# Probes: disk (/), RAM, CPU load averages, uptime, and systemctl active
# status for hermes-ops and docker. All output is JSON on stdout; diagnostics
# go to stderr. Exits non-zero with a clear message if any probe fails.
# No arguments; read-only (T1 — no mutations).

set -euo pipefail

die() { printf 'health-report: %s\n' "$*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || die "jq is required but not found in PATH"

# --- disk (/) ---
disk_line=$(df -P / | awk 'NR==2') || die "df probe failed"
[[ -n "$disk_line" ]] || die "df returned no data for /"
disk_total_kb=$(printf '%s' "$disk_line" | awk '{print $2}')
disk_used_kb=$(printf  '%s' "$disk_line" | awk '{print $3}')
disk_avail_kb=$(printf '%s' "$disk_line" | awk '{print $4}')
disk_pct=$(printf      '%s' "$disk_line" | awk '{gsub(/%/,"",$5); print $5}')

# --- RAM (/proc/meminfo) ---
[[ -r /proc/meminfo ]] || die "cannot read /proc/meminfo"
mem_total_kb=$(awk '/^MemTotal:/    {print $2; exit}' /proc/meminfo)
mem_avail_kb=$(awk '/^MemAvailable:/{print $2; exit}' /proc/meminfo)
[[ -n "$mem_total_kb" ]] || die "MemTotal not found in /proc/meminfo"
[[ -n "$mem_avail_kb" ]] || die "MemAvailable not found in /proc/meminfo"
mem_used_kb=$(( mem_total_kb - mem_avail_kb ))

# --- CPU load (/proc/loadavg) ---
[[ -r /proc/loadavg ]] || die "cannot read /proc/loadavg"
read -r load1 load5 load15 _ < /proc/loadavg || die "loadavg read failed"

# --- uptime (/proc/uptime) ---
[[ -r /proc/uptime ]] || die "cannot read /proc/uptime"
read -r uptime_frac _ < /proc/uptime || die "uptime read failed"
uptime_sec="${uptime_frac%.*}"

# --- service status ---
hermes_status=$(systemctl is-active hermes-ops 2>/dev/null || true)
docker_status=$(systemctl is-active docker        2>/dev/null || true)
[[ -n "$hermes_status" ]] || die "systemctl is-active hermes-ops returned no output"
[[ -n "$docker_status" ]] || die "systemctl is-active docker returned no output"

# --- JSON output ---
jq --null-input \
  --argjson disk_total_kb "$disk_total_kb"  \
  --argjson disk_used_kb  "$disk_used_kb"   \
  --argjson disk_avail_kb "$disk_avail_kb"  \
  --argjson disk_pct      "$disk_pct"       \
  --argjson mem_total_kb  "$mem_total_kb"   \
  --argjson mem_used_kb   "$mem_used_kb"    \
  --argjson mem_avail_kb  "$mem_avail_kb"   \
  --arg     load1         "$load1"          \
  --arg     load5         "$load5"          \
  --arg     load15        "$load15"         \
  --argjson uptime_sec    "$uptime_sec"     \
  --arg     hermes_ops    "$hermes_status"  \
  --arg     docker_svc    "$docker_status"  \
  '{
    disk: {
      path:     "/",
      total_kb: $disk_total_kb,
      used_kb:  $disk_used_kb,
      avail_kb: $disk_avail_kb,
      used_pct: $disk_pct
    },
    memory: {
      total_kb: $mem_total_kb,
      used_kb:  $mem_used_kb,
      avail_kb: $mem_avail_kb
    },
    load: {
      "1m":  ($load1  | tonumber),
      "5m":  ($load5  | tonumber),
      "15m": ($load15 | tonumber)
    },
    uptime_sec: $uptime_sec,
    services: {
      "hermes-ops": $hermes_ops,
      docker:       $docker_svc
    }
  }'
