#!/usr/bin/env bash
# cert-expiry.sh — Report TLS certificate expiry for each domain in CERT_DOMAINS.
#
# Usage:
#   CERT_DOMAINS="example.com,api.example.com" ./shell/cert-expiry.sh
#
# Environment:
#   CERT_DOMAINS   Space- or comma-separated list of domains to check (required).
#   CERT_PORT      Port to connect on each domain (default: 443).
#   CERT_TIMEOUT   Seconds to wait per host connection (default: 10).
#
# Output: one JSON document to stdout; diagnostics and progress to stderr.
# Domains with fewer than 14 days remaining are flagged with "warning": true
# and included in the top-level "warnings" array.
#
# Exit codes:
#   0 — completed (even if some certs are near-expiry or unreachable)
#   1 — usage error (CERT_DOMAINS unset)

set -euo pipefail

readonly WARN_DAYS=14

usage() {
  cat <<'EOF'
cert-expiry.sh — Report TLS certificate expiry for each domain in CERT_DOMAINS.

Usage:
  CERT_DOMAINS="example.com,api.example.com" ./shell/cert-expiry.sh

Environment:
  CERT_DOMAINS   Space- or comma-separated list of domains to check (required).
  CERT_PORT      Port to connect on each domain (default: 443).
  CERT_TIMEOUT   Seconds to wait per host connection (default: 10).
EOF
  exit 0
}

[[ "${1:-}" == "--help" ]] && usage

if [[ -z "${CERT_DOMAINS:-}" ]]; then
  printf 'Error: CERT_DOMAINS is not set.\n' >&2
  printf 'Set it to a space- or comma-separated list of domain names.\n' >&2
  exit 1
fi

CERT_PORT="${CERT_PORT:-443}"
CERT_TIMEOUT="${CERT_TIMEOUT:-10}"

# Normalise commas to spaces and split into array.
IFS=' ,' read -ra domain_list <<< "${CERT_DOMAINS}"

checked_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

domain_entries=()
warning_entries=()

for domain in "${domain_list[@]}"; do
  [[ -z "$domain" ]] && continue

  printf 'Checking %s:%s ...\n' "$domain" "$CERT_PORT" >&2

  expiry_raw=""
  if ! expiry_raw="$(timeout "${CERT_TIMEOUT}" openssl s_client \
        -connect "${domain}:${CERT_PORT}" \
        -servername "${domain}" \
        -verify_return_error \
        2>/dev/null \
        < /dev/null \
      | openssl x509 -noout -enddate 2>/dev/null)"; then
    printf 'Warning: failed to retrieve cert for %s\n' "$domain" >&2
    domain_entries+=("{\"domain\":\"${domain}\",\"error\":\"connection_failed\",\"warning\":true}")
    warning_entries+=("\"${domain}\"")
    continue
  fi

  if [[ -z "$expiry_raw" ]]; then
    printf 'Warning: empty cert response for %s\n' "$domain" >&2
    domain_entries+=("{\"domain\":\"${domain}\",\"error\":\"no_cert_data\",\"warning\":true}")
    warning_entries+=("\"${domain}\"")
    continue
  fi

  # expiry_raw format: "notAfter=Jun 30 00:00:00 2026 GMT"
  expiry_date="${expiry_raw#notAfter=}"

  expiry_epoch="$(date -d "${expiry_date}" +%s)"
  now_epoch="$(date -u +%s)"
  days_remaining=$(( (expiry_epoch - now_epoch) / 86400 ))

  expiry_iso="$(date -u -d "${expiry_date}" +"%Y-%m-%dT%H:%M:%SZ")"

  is_warning="false"
  if [[ $days_remaining -lt $WARN_DAYS ]]; then
    is_warning="true"
    warning_entries+=("\"${domain}\"")
  fi

  domain_entries+=("{\"domain\":\"${domain}\",\"days_remaining\":${days_remaining},\"expiry\":\"${expiry_iso}\",\"warning\":${is_warning}}")
done

# Build JSON arrays by accumulation; separator is injected only after the first element.
domains_json=""
if [[ ${#domain_entries[@]} -gt 0 ]]; then
  for entry in "${domain_entries[@]}"; do
    domains_json+="${domains_json:+,}${entry}"
  done
fi

warnings_json=""
if [[ ${#warning_entries[@]} -gt 0 ]]; then
  for entry in "${warning_entries[@]}"; do
    warnings_json+="${warnings_json:+,}${entry}"
  done
fi

printf '{"checked_at":"%s","domains":[%s],"warnings":[%s]}\n' \
  "${checked_at}" "${domains_json}" "${warnings_json}"
