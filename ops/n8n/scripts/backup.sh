#!/usr/bin/env bash
#
# n8n backup script.
#
# Exports all workflows (one JSON per workflow for clean git diffs) and
# optionally credentials (encrypted blobs — only safe to store in a private
# repo, since the N8N_ENCRYPTION_KEY lives on the server).
#
# Then commits and pushes to the backup repository.
#
# Run via systemd timer (see ops/n8n/systemd/n8n-backup.timer).
# Configuration can be overridden in /etc/default/n8n-backup.

set -euo pipefail

BACKUP_REPO_DIR="${BACKUP_REPO_DIR:-/opt/n8n-backup}"
N8N_CONTAINER="${N8N_CONTAINER:-n8n}"
INCLUDE_CREDENTIALS="${INCLUDE_CREDENTIALS:-true}"
GIT_BRANCH="${GIT_BRANCH:-main}"
GIT_USER_NAME="${GIT_USER_NAME:-n8n-backup}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-n8n-backup@mocainteractive.com}"

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
TAG="n8n-backup"

log() {
  logger -t "$TAG" -- "$*" 2>/dev/null || true
  printf '[%s] %s\n' "$(date -Is)" "$*"
}

die() { log "ERROR: $*"; exit 1; }

[ -d "$BACKUP_REPO_DIR/.git" ] \
  || die "Backup repo not initialized at $BACKUP_REPO_DIR. Run setup-server.sh first."

command -v docker >/dev/null || die "docker not found in PATH"
docker inspect "$N8N_CONTAINER" >/dev/null 2>&1 \
  || die "Container '$N8N_CONTAINER' not found. Set N8N_CONTAINER in /etc/default/n8n-backup."

cd "$BACKUP_REPO_DIR"

git fetch origin --quiet || log "WARN: git fetch failed (offline?), continuing"
git checkout "$GIT_BRANCH" --quiet 2>/dev/null || true
git pull --ff-only --quiet origin "$GIT_BRANCH" 2>/dev/null || log "WARN: git pull skipped"

# Recreate from scratch so deleted workflows actually disappear from backup.
rm -rf workflows credentials
mkdir -p workflows

docker exec "$N8N_CONTAINER" sh -c 'rm -rf /tmp/n8n-backup && mkdir -p /tmp/n8n-backup'

log "Exporting workflows..."
docker exec "$N8N_CONTAINER" \
  n8n export:workflow --all --separate --output=/tmp/n8n-backup/workflows >/dev/null
docker cp "$N8N_CONTAINER:/tmp/n8n-backup/workflows/." workflows/

if [ "$INCLUDE_CREDENTIALS" = "true" ]; then
  mkdir -p credentials
  log "Exporting credentials (encrypted)..."
  docker exec "$N8N_CONTAINER" \
    n8n export:credentials --all --separate --output=/tmp/n8n-backup/credentials >/dev/null
  docker cp "$N8N_CONTAINER:/tmp/n8n-backup/credentials/." credentials/
fi

docker exec "$N8N_CONTAINER" rm -rf /tmp/n8n-backup

git add -A
if git diff --cached --quiet; then
  log "No changes since last backup"
  exit 0
fi

git -c user.name="$GIT_USER_NAME" -c user.email="$GIT_USER_EMAIL" \
  commit -m "Backup ${TIMESTAMP}" --quiet

for attempt in 1 2 3 4; do
  if git push origin "$GIT_BRANCH" --quiet; then
    log "Backup pushed (commit $(git rev-parse --short HEAD))"
    exit 0
  fi
  wait_s=$((2 ** attempt))
  log "Push failed (attempt $attempt), retrying in ${wait_s}s"
  sleep "$wait_s"
done

die "git push failed after retries"
