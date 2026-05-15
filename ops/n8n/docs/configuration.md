# n8n server — configuration checklist

A practical hardening + housekeeping checklist for the
`n8n.mocainteractive.com` VPS.

## 1. Secrets to back up offline (do this first)

These cannot be regenerated. Lose them and you lose data.

- [ ] `N8N_ENCRYPTION_KEY` — copy the value into Keeper / 1Password.
      Find it on the server:
      ```
      docker exec <n8n-container> printenv N8N_ENCRYPTION_KEY
      ```
- [ ] Owner email + password (already in Keeper).
- [ ] SSH private key for `d.pisciottano` (the one you use to log into the
      VPS). Keep a copy outside the laptop in case of disk failure.

## 2. n8n environment variables

Apply the values in `config/n8n.env.recommended`. After editing:

```
docker restart <n8n-container>
```

Verify with:

```
docker exec <n8n-container> printenv | grep -E 'TZ|N8N_|WEBHOOK|EXECUTIONS_'
```

## 3. Account security

- [ ] Change owner email to `account@mocainteractive.com`
      (see `docs/owner-change.md`).
- [ ] Enable 2FA on the owner account.
- [ ] Invite a second admin (yourself or a colleague) so the instance is
      never owned by a single account that could lose access.

## 4. Backups

- [ ] Run `setup-server.sh` to wire up the daily Git backup
      (see `../README.md`).
- [ ] Enable **weekly snapshots** of the Droplet in DigitalOcean
      (Droplet → Backups). ~20% Droplet cost, saves you in disaster
      scenarios where the filesystem is corrupt.
- [ ] Verify one backup run completed:
      `systemctl status n8n-backup.service` and check commits on the
      backup repo on GitHub.

## 5. Updates

- [ ] Decide an update cadence (e.g. once a month, after reading the
      changelog at https://docs.n8n.io/release-notes/).
- [ ] Procedure to update n8n (Docker):
      ```
      docker pull n8nio/n8n:latest
      docker compose -f /path/to/compose.yml up -d   # or whatever orchestrates it
      ```
      Always run a backup right before updating.
- [ ] OS updates: `apt update && apt upgrade` monthly, or enable
      `unattended-upgrades` for security patches only.

## 6. Monitoring

- [ ] Add `https://n8n.mocainteractive.com/healthz` to UptimeRobot
      (free tier is fine) — alerts you when n8n is down.
- [ ] Optional: connect the n8n instance itself to a workflow that
      pings on errors (n8n has an "Error workflow" feature, see
      Settings → Error workflow).

## 7. Inventory

Keep a one-pager in the team wiki / Notion with:

- VPS IP, hostname, DigitalOcean project link
- Owner email + role list
- Backup repo URL
- Pointer to this `ops/n8n/` directory in the repo
- Who has SSH access (the firewall allowlist)
