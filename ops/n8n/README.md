# n8n — operations

Tooling and documentation for the `n8n.mocainteractive.com` VPS.

```
ops/n8n/
├── scripts/
│   ├── setup-server.sh        # one-time setup, run as root on the VPS
│   ├── backup.sh              # exports workflows + credentials, pushes to git
│   └── restore.sh             # restore workflows from the backup repo
├── systemd/
│   ├── n8n-backup.service     # runs backup.sh
│   └── n8n-backup.timer       # daily at 03:00 UTC
├── config/
│   ├── n8n-backup.env.example # overrides for backup script
│   └── n8n.env.recommended    # recommended n8n container env vars
└── docs/
    ├── owner-change.md
    ├── configuration.md
    └── disaster-recovery.md
```

## Quick start

### 1. Create the backup repository on GitHub

Create an **empty private** repo:

- Org: `mocainteractive`
- Suggested name: `n8n-workflows-backup`
- Initialize with a `main` branch (one empty commit is enough — the script
  pulls before pushing).

### 2. Wire up the backup on the VPS

SSH into the n8n server, then:

```bash
ssh d.pisciottano@165.245.247.223
sudo su

# 1. Get the latest version of these scripts on the server
git clone https://github.com/mocainteractive/mapei.git /opt/mapei

# 2. Identify the n8n container name
docker ps        # look for the n8n image; remember the NAME (e.g. "n8n")

# 3. (Optional) override defaults
#    N8N_CONTAINER=n8n   BACKUP_REPO_URL=git@github.com:mocainteractive/n8n-workflows-backup.git

# 4. Run setup — it will print a public key for you to register as a
#    GitHub deploy key (with WRITE access) on the backup repo.
sudo bash /opt/mapei/ops/n8n/scripts/setup-server.sh
```

### 3. Verify

```bash
# Force a backup run right now
sudo systemctl start n8n-backup.service

# Watch what it does
sudo journalctl -u n8n-backup.service -f

# See when it will next run
systemctl list-timers n8n-backup.timer
```

Open the backup repo on GitHub — you should see a `Backup <timestamp>`
commit with `workflows/` (and `credentials/` if enabled).

### 4. Apply the recommended n8n configuration

See `docs/configuration.md` for the full checklist (encryption key backup,
env vars, 2FA, snapshots, monitoring).

### 5. Change the owner email

See `docs/owner-change.md`.

## Common operations

| Want to... | Command |
|---|---|
| Trigger a backup right now | `sudo systemctl start n8n-backup.service` |
| Tail backup logs | `sudo journalctl -u n8n-backup.service -f` |
| Restore workflows from backup | `sudo /usr/local/sbin/n8n-restore` |
| Restore workflows + credentials | `sudo RESTORE_CREDENTIALS=true /usr/local/sbin/n8n-restore` |
| Change backup schedule | `sudo systemctl edit n8n-backup.timer` |
| Disable backups temporarily | `sudo systemctl disable --now n8n-backup.timer` |
| Update scripts on the VPS | `cd /opt/mapei && git pull && sudo bash ops/n8n/scripts/setup-server.sh` |

## Security notes

- Backups include **encrypted** credential blobs. They are only readable
  with the server's `N8N_ENCRYPTION_KEY`. Keep the backup repo **private**
  and never commit the encryption key alongside them.
- If you want to skip credentials entirely, set `INCLUDE_CREDENTIALS=false`
  in `/etc/default/n8n-backup` and re-run a backup.
- The deploy key on GitHub has access **only** to the backup repo and only
  from this server. Rotate it from the GitHub repo settings if the server
  is ever compromised.
