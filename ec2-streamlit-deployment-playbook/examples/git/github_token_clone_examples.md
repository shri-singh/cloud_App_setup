# GitHub Token Clone Examples

This file shows safe and unsafe ways to clone a private GitHub repository using a personal access token.

---

## ⚠️ Shell History Warning

Bash and most Linux shells record every command you type in a history file (`~/.bash_history`). If your GitHub token appears in a command, it will be stored in plain text in this file.

```bash
# Anyone with access to your account can see your history
history | grep github
cat ~/.bash_history | grep github
```

**Always clear the token from history or use methods that keep it out of history entirely.**

---

## Method 1 — Interactive Prompt (MOST SECURE)

Git will ask for credentials. Type your token at the password prompt. It is NOT stored in history.

```bash
git clone https://github.com/YOUR_ORG/YOUR_REPO.git

# Git prompts:
# Username for 'https://github.com': YOUR_GITHUB_USERNAME
# Password for 'https://YOUR_GITHUB_USERNAME@github.com': [paste your token here]
```

The token is not echoed to the terminal and not stored in shell history.

---

## Method 2 — Read into Variable (SECURE — Token Not in History)

Use `read -s` to silently capture the token into a shell variable. The variable is not stored in history.

```bash
# Prompt for token without echoing
read -s GITHUB_TOKEN
# (paste your token and press Enter — nothing is shown)

# Clone using the variable
git clone https://YOUR_GITHUB_USERNAME:${GITHUB_TOKEN}@github.com/YOUR_ORG/YOUR_REPO.git

# Immediately clear the variable from memory
unset GITHUB_TOKEN

# Also clear history for this session
history -c
```

**Why this is safer:** The token is in a shell variable, not embedded in a command string in history.

---

## Method 3 — Token Embedded in URL (CONVENIENT but INSECURE)

```bash
# WARNING: This stores the token in shell history
git clone https://YOUR_GITHUB_USERNAME:ghp_YourTokenHere@github.com/YOUR_ORG/YOUR_REPO.git
```

> ⚠️ **Do NOT use this method in production or on shared servers.**
> The token appears in:
> - `~/.bash_history`
> - The process list (`ps -ef`) while git is running
> - Potentially in audit logs

If you must use this method, clear history immediately:

```bash
history -c    # Clear entire session history
history -d $(history | tail -1 | awk '{print $1}')   # Delete just the last entry
```

---

## Method 4 — Credential Helper Store (CONVENIENT, MODERATE SECURITY)

Configure git to store credentials after the first successful authentication:

```bash
git config --global credential.helper store

# First clone — enter credentials interactively
git clone https://github.com/YOUR_ORG/YOUR_REPO.git

# Subsequent operations (pull, push) reuse stored credentials
git pull origin main
```

Credentials are stored in `~/.git-credentials` in plain text:

```
https://YOUR_GITHUB_USERNAME:YOUR_TOKEN@github.com
```

Secure the file:

```bash
chmod 600 ~/.git-credentials
```

> For production servers, this is acceptable if root access is tightly controlled and `.git-credentials` is protected. For shared or multi-user systems, prefer SSH keys.

---

## Method 5 — SSH Deploy Key (MOST SECURE FOR AUTOMATION)

For automated deployments (scripts, CI/CD), use SSH keys instead of tokens.

```bash
# Generate an SSH key pair (no passphrase for automation)
ssh-keygen -t ed25519 -C "ec2-deploy-$(hostname)" -f /root/.ssh/github_deploy_key -N ""

# Display the public key — add this to GitHub
cat /root/.ssh/github_deploy_key.pub
```

Add to GitHub:
- **For one repo:** GitHub → Repo Settings → Deploy keys → Add deploy key (Read-only is enough for clone/pull)
- **For all repos in org:** GitHub → Org Settings → SSH keys

Configure SSH:

```bash
cat >> /root/.ssh/config << 'EOF'
Host github.com
    HostName github.com
    User git
    IdentityFile /root/.ssh/github_deploy_key
    StrictHostKeyChecking no
EOF

chmod 600 /root/.ssh/config
chmod 600 /root/.ssh/github_deploy_key
```

Clone with SSH:

```bash
git clone git@github.com:YOUR_ORG/YOUR_REPO.git
git pull origin main
```

No tokens needed — the SSH key handles authentication.

---

## Enterprise GitHub (GitHub Enterprise Server)

Replace `github.com` with your company's GitHub Enterprise hostname:

```bash
# HTTPS clone
git clone https://github.yourcompany.com/YOUR_ORG/YOUR_REPO.git

# SSH clone
git clone git@github.yourcompany.com:YOUR_ORG/YOUR_REPO.git

# SSH config for Enterprise
cat >> /root/.ssh/config << 'EOF'
Host github.yourcompany.com
    HostName github.yourcompany.com
    User git
    IdentityFile /root/.ssh/github_deploy_key
    StrictHostKeyChecking no
EOF
```

---

## After Cloning — Update Remote URL

If you cloned with one method and want to switch to SSH:

```bash
cd /opt/apps/YOUR_REPO_NAME

# Check current remote
git remote -v

# Switch to SSH remote
git remote set-url origin git@github.com:YOUR_ORG/YOUR_REPO.git

# Verify
git remote -v
git fetch
```

---

## Summary

| Method | Security | Best For |
|---|---|---|
| Interactive prompt | High | One-time manual clones |
| `read -s` variable | High | Scripts that run interactively |
| Token in URL | Low | Never (only if no alternative) |
| `credential.helper store` | Medium | Repeated pulls on dedicated server |
| SSH deploy key | High | CI/CD, automation, production |
