# Disaster recovery — n8n

Procedure for rebuilding the n8n instance from scratch on a fresh server.

## What you need

- A fresh VPS with Docker installed and n8n running (any way: 1-click image,
  `docker compose`, etc.).
- The **N8N_ENCRYPTION_KEY** value from Keeper (set it on the new instance
  via env vars **before first start**, otherwise n8n generates a new one and
  the imported credentials will be unreadable).
- Access to the backup repo on GitHub.

## Steps

1. **Stand up the new container** with the original `N8N_ENCRYPTION_KEY` and
   restart it.

   ```
   docker exec <n8n> printenv N8N_ENCRYPTION_KEY    # must match the saved one
   ```

2. **Bootstrap the backup tooling** on the new server:

   ```
   git clone https://github.com/mocainteractive/mapei.git /tmp/mapei
   sudo /tmp/mapei/ops/n8n/scripts/setup-server.sh
   ```

3. **Restore workflows** (and credentials):

   ```
   sudo RESTORE_CREDENTIALS=true /usr/local/sbin/n8n-restore
   ```

4. **Recreate the owner user** through the n8n setup wizard with the same
   email. Workflows imported via CLI keep their internal IDs but get
   re-assigned to whichever owner exists.

5. **Reactivate workflows**. Imported workflows come in **deactivated** by
   default. Open each one and toggle Active back on, or use:

   ```
   docker exec <n8n> n8n update:workflow --all --active=true
   ```

6. **Verify** webhooks/schedules fire — trigger a manual run on each
   critical workflow.

## Notes

- If you lost the encryption key, credentials cannot be decrypted. You'll
  have to delete the encrypted credential blobs and re-enter every
  credential by hand.
- For full disaster recovery (server gone, including the DB) the workflow
  Git backup is enough only if you also have the encryption key. The
  DigitalOcean weekly snapshot is the cheaper safety net for everything
  else (logs, execution history, etc.).
