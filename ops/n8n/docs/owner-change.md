# Change n8n owner email

Goal: change the owner account from a personal email to
`account@mocainteractive.com`.

## Option A — rename the existing owner (recommended)

Keeps all workflow ownership history. Use when you have access to both
inboxes.

1. Log in to https://n8n.mocainteractive.com with the current owner account.
2. Top-right avatar → **Settings** → **Personal**.
3. Change **Email** to `account@mocainteractive.com` and **Save**.
4. n8n sends a verification email to the new address — open it and confirm.
5. (Optional) change the password on the same screen.
6. Log out, log back in with the new email to confirm.

> Requires SMTP to be configured on n8n (see `config/n8n.env.recommended`).
> If you haven't configured SMTP yet, do that **before** changing the email,
> otherwise the verification email never leaves the server.

## Option B — invite the new email as Admin

Use when you want both accounts to exist. n8n self-hosted has only **one
Owner** per instance, so you can't have two owners — but an Admin has
essentially the same powers minus instance-level config.

1. Settings → **Users** → **Invite**.
2. Enter `account@mocainteractive.com`, role Admin.
3. Open the invite email on the receiving account and finish signup.

## Post-change checklist

- Verify login with the new email works.
- Re-share the credentials in Keeper with the team using the new identity.
- Update any "Owner" reference in internal docs / runbooks.
- Ensure 2FA is enabled on the new owner account (Settings → Personal →
  Two-factor authentication).
