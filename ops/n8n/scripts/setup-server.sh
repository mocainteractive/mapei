#!/usr/bin/env bash
#
# One-time setup of n8n workflow backups on the VPS.
# Run as root on the n8n server.
#
# What it does:
#   1. Generates an SSH deploy key (if missing) and prints the public key,
#      so you can register it on GitHub as a deploy key with write access.
#   2. Clones the backup repository into BACKUP_REPO_DIR.
#   3. Installs backup/restore scripts to /usr/local/sbin/.
#   4. Installs the systemd service + timer and enables the daily timer.
#
# Configuration via env vars or /etc/default/n8n-backup:
#   BACKUP_REPO_DIR   default /opt/n8n-backup
#   BACKUP_REPO_URL   default git@github.com:mocainteractive/n8n-workflows-backup.git
#   N8N_CONTAINER     default n8n

set -euo pipefail

BACKUP_REPO_DIR="${BACKUP_REPO_DIR:-/opt/n8n-backup}"
BACKUP_REPO_URL="${BACKUP_REPO_URL:-git@github.com:mocainteractive/n8n-workflows-backup.git}"
N8N_CONTAINER="${N8N_CONTAINER:-n8n}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OPS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

[ "$EUID" -eq 0 ] || { echo "Run as root (sudo $0)"; exit 1; }

echo "==> Checking docker access..."
command -v docker >/dev/null || { echo "docker not installed"; exit 1; }
docker inspect "$N8N_CONTAINER" >/dev/null 2>&1 \
  || { echo "Container '$N8N_CONTAINER' not found. List with: docker ps"; exit 1; }

KEY_PATH=/root/.ssh/n8n_backup_deploy_key
SSH_HOST_ALIAS=github-n8n-backup

if [ ! -f "$KEY_PATH" ]; then
  echo "==> Generating SSH deploy key at $KEY_PATH..."
  mkdir -p /root/.ssh
  chmod 700 /root/.ssh
  ssh-keygen -t ed25519 -N '' -C 'n8n-backup-deploy' -f "$KEY_PATH"

  if ! grep -q "Host $SSH_HOST_ALIAS" /root/.ssh/config 2>/dev/null; then
    cat >> /root/.ssh/config <<EOF

Host $SSH_HOST_ALIAS
  HostName github.com
  User git
  IdentityFile $KEY_PATH
  IdentitiesOnly yes
EOF
    chmod 600 /root/.ssh/config
  fi

  echo ""
  echo "================================================================"
  echo " ADD THIS PUBLIC KEY AS A DEPLOY KEY (with WRITE access) ON THE"
  echo " GITHUB REPO, then come back here and press Enter."
  echo ""
  echo "   Repo:  $BACKUP_REPO_URL"
  echo "   Page:  https://github.com/<org>/<repo>/settings/keys/new"
  echo "================================================================"
  echo ""
  cat "${KEY_PATH}.pub"
  echo ""
  read -r -p "Press Enter once the deploy key has been added... "
fi

# Make sure github.com is in known_hosts
ssh-keyscan -t ed25519 github.com 2>/dev/null >> /root/.ssh/known_hosts
sort -u /root/.ssh/known_hosts -o /root/.ssh/known_hosts

# Rewrite the repo URL to use the host alias so the right key is used
SSH_REPO_URL="$(echo "$BACKUP_REPO_URL" | sed "s|git@github.com:|git@${SSH_HOST_ALIAS}:|")"

if [ ! -d "$BACKUP_REPO_DIR/.git" ]; then
  echo "==> Cloning $SSH_REPO_URL into $BACKUP_REPO_DIR..."
  git clone "$SSH_REPO_URL" "$BACKUP_REPO_DIR"
else
  echo "==> Repo already cloned at $BACKUP_REPO_DIR, skipping clone"
fi

echo "==> Installing scripts..."
install -m 0755 "$SCRIPT_DIR/backup.sh"  /usr/local/sbin/n8n-backup
install -m 0755 "$SCRIPT_DIR/restore.sh" /usr/local/sbin/n8n-restore

echo "==> Installing systemd units..."
install -m 0644 "$OPS_DIR/systemd/n8n-backup.service" /etc/systemd/system/
install -m 0644 "$OPS_DIR/systemd/n8n-backup.timer"   /etc/systemd/system/

if [ ! -f /etc/default/n8n-backup ]; then
  install -m 0644 "$OPS_DIR/config/n8n-backup.env.example" /etc/default/n8n-backup
fi

systemctl daemon-reload
systemctl enable --now n8n-backup.timer

echo ""
echo "==> Setup complete."
echo ""
echo "Useful commands:"
echo "  Force a backup now:        systemctl start n8n-backup.service"
echo "  Tail backup logs:          journalctl -u n8n-backup.service -f"
echo "  Show next scheduled run:   systemctl list-timers n8n-backup.timer"
echo "  Edit config:               \$EDITOR /etc/default/n8n-backup"
