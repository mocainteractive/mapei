#!/usr/bin/env bash
#
# Restore n8n workflows (and optionally credentials) from a checkout of the
# backup repo.
#
# WARNING: workflows with the same ID will be OVERWRITTEN.
#
# Usage:
#   sudo /usr/local/sbin/n8n-restore                    # workflows only
#   sudo RESTORE_CREDENTIALS=true /usr/local/sbin/n8n-restore

set -euo pipefail

BACKUP_REPO_DIR="${BACKUP_REPO_DIR:-/opt/n8n-backup}"
N8N_CONTAINER="${N8N_CONTAINER:-n8n}"
RESTORE_CREDENTIALS="${RESTORE_CREDENTIALS:-false}"

[ -d "$BACKUP_REPO_DIR/.git" ] || { echo "No backup repo at $BACKUP_REPO_DIR"; exit 1; }

cd "$BACKUP_REPO_DIR"

echo "Restoring from $BACKUP_REPO_DIR"
echo "  commit:               $(git rev-parse --short HEAD) — $(git log -1 --format=%s)"
echo "  RESTORE_CREDENTIALS:  $RESTORE_CREDENTIALS"
echo "  container:            $N8N_CONTAINER"
read -r -p "Continue? [y/N] " confirm
[ "$confirm" = "y" ] || { echo "Aborted"; exit 1; }

docker exec "$N8N_CONTAINER" sh -c 'rm -rf /tmp/n8n-restore && mkdir -p /tmp/n8n-restore/workflows'
docker cp workflows/. "$N8N_CONTAINER:/tmp/n8n-restore/workflows/"
docker exec "$N8N_CONTAINER" \
  n8n import:workflow --separate --input=/tmp/n8n-restore/workflows

if [ "$RESTORE_CREDENTIALS" = "true" ] && [ -d credentials ]; then
  docker exec "$N8N_CONTAINER" mkdir -p /tmp/n8n-restore/credentials
  docker cp credentials/. "$N8N_CONTAINER:/tmp/n8n-restore/credentials/"
  docker exec "$N8N_CONTAINER" \
    n8n import:credentials --separate --input=/tmp/n8n-restore/credentials
fi

docker exec "$N8N_CONTAINER" rm -rf /tmp/n8n-restore
echo "Restore complete. Reload the n8n UI to see changes."
