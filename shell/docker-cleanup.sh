#!/usr/bin/env bash
# docker-cleanup.sh — prune dangling images, unused volumes, and build cache
#
# Usage: docker-cleanup.sh [--dry-run] [--yes] [--help]
#
#   --dry-run  (default) Report what would be removed as JSON; exit 0.
#   --yes      Execute the prune. Output JSON summary of reclaimed space.
#   --help     Print this usage and exit 0.
#
# Conservative targets — NEVER removes running containers or in-use volumes:
#   · Dangling (untagged) images
#   · Unused volumes (not referenced by any container)
#   · Build cache
#
# Stdout: JSON    Stderr: human-readable progress and diagnostics

set -euo pipefail

DRY_RUN=true

for arg in "$@"; do
  case "${arg}" in
    --dry-run) DRY_RUN=true ;;
    --yes)     DRY_RUN=false ;;
    --help|-h)
      cat >&2 <<'USAGE'
Usage: docker-cleanup.sh [--dry-run] [--yes] [--help]

  --dry-run  (default) Report what would be removed as JSON; exit 0.
  --yes      Execute the prune. Output JSON summary of reclaimed space.
  --help     Print this usage and exit 0.

Conservative targets — NEVER removes running containers or in-use volumes:
  · Dangling (untagged) images
  · Unused volumes (not referenced by any container)
  · Build cache

Stdout: JSON    Stderr: human-readable progress and diagnostics
USAGE
      exit 0
      ;;
    *)
      printf 'docker-cleanup: unknown argument: %s\n' "${arg}" >&2
      exit 1
      ;;
  esac
done

for cmd in docker jq; do
  if ! command -v "${cmd}" > /dev/null 2>&1; then
    printf 'docker-cleanup: required command not found: %s\n' "${cmd}" >&2
    exit 1
  fi
done

# ── helpers ──────────────────────────────────────────────────────────────────

collect_dangling_images() {
  local raw
  raw="$(docker images --filter "dangling=true" \
    --format $'{{.ID}}\t{{.Repository}}\t{{.Tag}}\t{{.Size}}')"
  if [ -z "${raw}" ]; then
    printf '[]'
    return 0
  fi
  printf '%s\n' "${raw}" \
    | jq -R 'split("\t") | {"id":.[0],"repository":.[1],"tag":.[2],"size":.[3]}' \
    | jq -s '.'
}

collect_unused_volumes() {
  local raw
  raw="$(docker volume ls --filter "dangling=true" \
    --format $'{{.Name}}\t{{.Driver}}')"
  if [ -z "${raw}" ]; then
    printf '[]'
    return 0
  fi
  printf '%s\n' "${raw}" \
    | jq -R 'split("\t") | {"name":.[0],"driver":.[1]}' \
    | jq -s '.'
}

# Extract reclaimable field from `docker system df` for a given type label.
# Strips the trailing "(XX%)" annotation so only the size string is returned.
reclaimable_for() {
  docker system df 2>/dev/null \
    | awk -v t="${1}" 'index($0, t) == 1 {
        gsub(/[[:space:]]*\([^)]*\)/, "")
        print $NF
      }' \
    | head -1
}

# ── collect ───────────────────────────────────────────────────────────────────

printf 'Collecting dangling images...\n' >&2
images_json="$(collect_dangling_images)"

printf 'Collecting unused volumes...\n' >&2
volumes_json="$(collect_unused_volumes)"

printf 'Querying reclaimable space estimates...\n' >&2
images_reclaimable="$(reclaimable_for "Images")"
volumes_reclaimable="$(reclaimable_for "Local Volumes")"
build_cache_reclaimable="$(reclaimable_for "Build Cache")"

# ── dry-run output ────────────────────────────────────────────────────────────

if "${DRY_RUN}"; then
  jq -n \
    --argjson images "${images_json}" \
    --argjson volumes "${volumes_json}" \
    --arg img_reclaim "${images_reclaimable:-0B}" \
    --arg vol_reclaim "${volumes_reclaimable:-0B}" \
    --arg cache_reclaim "${build_cache_reclaimable:-0B}" \
    '{
      mode: "dry_run",
      targets: {
        dangling_images: $images,
        unused_volumes: $volumes,
        build_cache: { reclaimable: $cache_reclaim }
      },
      estimated_reclaimable: {
        dangling_images: $img_reclaim,
        unused_volumes: $vol_reclaim,
        build_cache: $cache_reclaim
      },
      warning: "Dry-run mode: no changes made. Pass --yes to execute."
    }'
  exit 0
fi

# ── execute ───────────────────────────────────────────────────────────────────

printf 'Pruning dangling images...\n' >&2
images_prune_out="$(docker image prune -f 2>&1)"
images_space="$(printf '%s\n' "${images_prune_out}" \
  | sed -n 's/Total reclaimed space: //p' | head -1)"
images_space="${images_space:-0B}"

printf 'Pruning unused volumes...\n' >&2
volumes_prune_out="$(docker volume prune -f 2>&1)"
volumes_space="$(printf '%s\n' "${volumes_prune_out}" \
  | sed -n 's/Total reclaimed space: //p' | head -1)"
volumes_space="${volumes_space:-0B}"

printf 'Pruning build cache...\n' >&2
cache_prune_out="$(docker builder prune -f 2>&1)"
cache_space="$(printf '%s\n' "${cache_prune_out}" \
  | sed -n 's/Total reclaimed space: //p; s/Total freed space: //p' | head -1)"
cache_space="${cache_space:-0B}"

printf 'Prune complete.\n' >&2

jq -n \
  --argjson images "${images_json}" \
  --argjson volumes "${volumes_json}" \
  --arg img_space "${images_space}" \
  --arg vol_space "${volumes_space}" \
  --arg cache_space "${cache_space}" \
  '{
    mode: "execute",
    pruned: {
      dangling_images: $images,
      unused_volumes: $volumes,
      build_cache: true
    },
    space_reclaimed: {
      dangling_images: $img_space,
      unused_volumes: $vol_space,
      build_cache: $cache_space
    }
  }'
