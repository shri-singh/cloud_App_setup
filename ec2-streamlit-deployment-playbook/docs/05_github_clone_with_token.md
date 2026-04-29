# 05 — Clone a GitHub Repo Using a Personal Access Token

This guide explains how to clone a private GitHub repository on an EC2 server using a personal access token (PAT).

---

## Why You Need a Token (Not a Password)

Since August 2021, **GitHub no longer accepts account passwords for HTTPS Git operations** (like `git clone`, `git pull`, `git push`). If you try to use your GitHub password, you will get:

```
remote: Support for password authentication was removed on August 13, 2021.
fatal: Authentication failed for 'https://github.com/...'
```

You must use a **personal access token** instead.

A personal access token is a long string (like `ghp_abc123xyz...`) that acts as a password but can be:
- Scoped to specific permissions (read-only, write, etc.)
- Set to expire automatically
- Revoked without changing your GitHub password

---

## Creating a Personal Access Token

### Classic Token (Simple)

1. Go to GitHub → **Settings** → **Developer settings** → **Personal access tokens** → **Tokens (classic)**
2. Click **Generate new token**
3. Set expiration (90 days is reasonable)
4. Check the `repo` scope (gives read/write access to private repos)
5. Click **Generate token**
6. **Copy the token immediately** — GitHub only shows it once

### Fine-Grained Token (More Secure)

1. Go to GitHub → **Settings** → **Developer settings** → **Personal access tokens** → **Fine-grained tokens**
2. Click **Generate new token**
3. Set resource owner to your organization
4. Select specific repositories (only the repos you need)
5. Under **Repository permissions**, set **Contents** to **Read-only** (for cloning only)
6. Click **Generate token**

> **Corporate/Enterprise best practice:** Use fine-grained tokens with minimum required permissions and short expiration times.

---

## Verify Git Is Installed

```bash
git --version
# Should show: git version 2.x.x
```

If not installed:

```bash
# Amazon Linux 2 / RHEL:
yum install -y git

# Amazon Linux 2023:
dnf install -y git

# Ubuntu:
apt install -y git
```

---

## Method 1 — Clone With Interactive Prompt (Safest)

This method does not expose your token in the command line or shell history.

```bash
mkdir -p /opt/apps
cd /opt/apps

git clone https://github.com/YOUR_ORG/YOUR_REPO.git
```

Git will prompt:

```
Username for 'https://github.com': YOUR_GITHUB_USERNAME
Password for 'https://YOUR_GITHUB_USERNAME@github.com': YOUR_GITHUB_TOKEN
```

Enter your token at the Password prompt (it will not be echoed — that is normal).

---

## Method 2 — Clone With Token in URL (Convenient but Use With Care)

```bash
git clone https://YOUR_GITHUB_USERNAME:YOUR_GITHUB_TOKEN@github.com/YOUR_ORG/YOUR_REPO.git
```

> ⚠️ **WARNING:** This exposes your token in shell history (`history` command) and in process listings. After cloning, clear it:

```bash
history -c    # Clear bash history for this session
```

---

## Method 3 — Safer Environment Variable Method

This avoids typing the token directly in the command:

```bash
# Read the token into a variable without echoing it
read -s GITHUB_TOKEN

# Now clone using the variable (token not visible in command)
git clone https://YOUR_GITHUB_USERNAME:${GITHUB_TOKEN}@github.com/YOUR_ORG/YOUR_REPO.git

# Immediately clear the variable from memory
unset GITHUB_TOKEN
```

`read -s` reads input silently (no echo). The token is temporarily in a shell variable but never visible in history.

---

## Enterprise GitHub (GitHub Enterprise Server)

If your company runs its own GitHub instance:

```bash
git clone https://github.yourcompany.com/YOUR_ORG/YOUR_REPO.git
```

Replace `github.yourcompany.com` with your company's actual GitHub Enterprise hostname.

---

## SSO / SAML Authorization

If your organization uses SAML single sign-on (SSO), your token must be authorized for that organization:

1. Go to GitHub → **Settings** → **Personal access tokens**
2. Next to your token, click **Configure SSO**
3. Click **Authorize** next to your organization name

Without this step, cloning will fail with a `403` or SSO authorization error even with a valid token.

---

## Credential Storage (Optional — For Repeated Operations)

If you need to frequently `git pull` without re-entering credentials, you can store them:

```bash
git config --global credential.helper store
```

After the next successful `git clone` or `git pull`, credentials are saved to `~/.git-credentials` in plain text.

Lock down the file:

```bash
chmod 600 ~/.git-credentials
```

View the file (contains your token in plain text — handle carefully):

```bash
cat ~/.git-credentials
```

> ⚠️ `credential.helper store` saves the token in plain text. In high-security environments, use AWS Secrets Manager to store tokens and retrieve them programmatically, or use SSH keys instead.

---

## SSH Key Alternative (More Secure Long-Term)

SSH key authentication avoids tokens entirely and is better for automation.

```bash
# Generate SSH key pair
ssh-keygen -t ed25519 -C "ec2-deploy-key" -f /root/.ssh/github_deploy_key

# View the public key
cat /root/.ssh/github_deploy_key.pub
```

Copy the public key and add it to GitHub:
- GitHub → **Settings** → **SSH and GPG keys** → **New SSH key**
- Or for a single repo (recommended): GitHub repo → **Settings** → **Deploy keys** → **Add deploy key**

Configure SSH to use the key:

```bash
cat >> /root/.ssh/config << 'EOF'
Host github.com
    HostName github.com
    User git
    IdentityFile /root/.ssh/github_deploy_key
    StrictHostKeyChecking no
EOF

chmod 600 /root/.ssh/config
```

Now clone with SSH:

```bash
git clone git@github.com:YOUR_ORG/YOUR_REPO.git
```

---

## Update an Existing Clone

If you already have the repo cloned and need to pull the latest code:

```bash
cd /opt/apps/YOUR_REPO_NAME

# Check current remote URL
git remote -v

# Update the remote URL if needed (e.g., to add token):
git remote set-url origin https://github.com/YOUR_ORG/YOUR_REPO.git

# Pull latest changes
git pull origin main
```

---

## ⚠️ Token Security Rules

1. **Never hardcode a token in a script file that gets committed to Git**
2. **Never print a token in logs** (`echo $GITHUB_TOKEN` is dangerous in scripts)
3. **Use short expiration times** — 30, 60, or 90 days maximum
4. **Use fine-grained tokens** with minimum permissions (read-only for deployment)
5. **Revoke tokens immediately** when they are no longer needed
6. **Rotate tokens regularly** — treat them like passwords
7. **Use SSH deploy keys for automated CI/CD** — never use your personal account PAT in automation

---

## Summary

| Method | Security | Convenience |
|---|---|---|
| Interactive prompt | High | Medium |
| Token in URL | Low (visible in history) | High |
| Environment variable (`read -s`) | Medium-High | Medium |
| `credential.helper store` | Low (plain text file) | High |
| SSH deploy key | High | High |
