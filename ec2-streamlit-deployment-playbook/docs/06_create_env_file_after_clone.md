# 06 — Create a `.env` File After Cloning

This guide explains how to securely provide your application's secrets and configuration on the EC2 server after cloning the repository.

---

## Why Secrets Should Not Be in GitHub

Your repository should **never contain real API keys, database passwords, or other secrets**. Reasons:

- GitHub repos can be accidentally made public
- Even private repos: if a contributor's account is compromised, secrets are exposed
- Secrets in Git history are hard to fully remove
- Corporate security scanners will flag secrets in repos and may auto-revoke them

**The correct pattern:**

1. Commit a `.env.example` file to GitHub (with placeholder values, no real secrets)
2. After cloning on the server, manually create the real `.env` file with actual values
3. Add `.env` to `.gitignore` so it is never committed

---

## What `.env` Is

A `.env` file is a simple text file with one `KEY=VALUE` pair per line:

```
APP_ENV=production
OPENAI_API_KEY=sk-abc123
DATABASE_URL=postgresql://user:pass@host:5432/dbname
```

Your Python application reads this file at startup and loads the values as environment variables.

---

## Step 1 — Navigate to Your App Directory

```bash
cd /opt/apps/YOUR_REPO_NAME
```

---

## Step 2 — Create the `.env` File

Use a "heredoc" to write multiple lines to the file at once. Everything between `EOF` and `EOF` is written exactly as-is:

```bash
cat > .env << 'EOF'
OPENAI_API_KEY=replace_me
ANTHROPIC_API_KEY=replace_me
DATABASE_URL=replace_me
APP_ENV=production
STREAMLIT_SERVER_PORT=8501
EOF
```

Now open the file and replace the placeholder values with real values:

```bash
nano .env
```

Your final `.env` should look like:

```
APP_ENV=production
OPENAI_API_KEY=sk-abc123def456...
ANTHROPIC_API_KEY=sk-ant-...
DATABASE_URL=postgresql://myuser:mypassword@myhost:5432/mydb
STREAMLIT_SERVER_PORT=8501
```

---

## Step 3 — Lock Down `.env` File Permissions

The `.env` file contains secrets. Only the owner should be able to read it:

```bash
chmod 600 .env
```

`600` means:
- Owner (root or app user): read + write
- Group: no access
- Others: no access

Verify the permissions:

```bash
ls -la .env
# Output should show: -rw------- 1 root root ... .env
```

---

## Step 4 — Verify the File

```bash
cat .env
```

Confirm all values are filled in correctly before starting the app.

---

## Step 5 — Create `.env.example` in Your Repo (One-Time Setup)

If your repo does not already have a `.env.example`, create one now and commit it:

```bash
cat > .env.example << 'EOF'
# Copy this file to .env and fill in the values
APP_ENV=development
OPENAI_API_KEY=
ANTHROPIC_API_KEY=
DATABASE_URL=
STREAMLIT_SERVER_PORT=8501
EOF
```

This file shows what variables the app needs, without exposing real values.

---

## Step 6 — Update `.gitignore`

Make sure `.env` is excluded from Git:

```bash
cat >> .gitignore << 'EOF'

# Secret files — never commit
.env
.env.*
!.env.example

# Python artifacts
venv/
__pycache__/
*.pyc
*.pyo
.pytest_cache/
*.egg-info/
dist/
build/
EOF
```

Check that `.env` is now ignored:

```bash
git status
# .env should NOT appear in the output
```

If `.env` is already tracked by Git, remove it from tracking (but keep the file on disk):

```bash
git rm --cached .env
git commit -m "Remove .env from tracking"
```

---

## Step 7 — Load `.env` in Your Python App

Install `python-dotenv`:

```bash
source venv/bin/activate
pip install python-dotenv
```

In your Python application:

```python
from dotenv import load_dotenv
import os

load_dotenv()  # Reads .env file and loads variables into os.environ

api_key = os.getenv("OPENAI_API_KEY")
db_url = os.getenv("DATABASE_URL")
app_env = os.getenv("APP_ENV", "development")  # Default if not set
```

`load_dotenv()` looks for `.env` in the current directory (or parent directories). In systemd services, set `WorkingDirectory` to your app folder so `.env` is found automatically.

---

## Using Environment Variables in Streamlit

Streamlit apps can read environment variables the same way any Python app does:

```python
import streamlit as st
import os
from dotenv import load_dotenv

load_dotenv()

st.title("My App")
env = os.getenv("APP_ENV", "development")
st.info(f"Running in: {env} mode")
```

> **Never display secret values in the Streamlit UI** — only display non-sensitive config like environment name.

---

## systemd and Environment Variables

When running via systemd, you can load `.env` using the `EnvironmentFile` directive:

```ini
[Service]
EnvironmentFile=/opt/apps/YOUR_REPO_NAME/.env
```

This makes all variables in `.env` available to the service. Your app can then read them with `os.getenv()` — with or without `python-dotenv`.

> If using `EnvironmentFile`, ensure `.env` does not have `export` prefixes. systemd reads `KEY=VALUE` format directly.

After editing `.env`:

```bash
# Restart the service to apply new values
systemctl restart streamlit-app
```

---

## Enterprise Secret Management Options

For higher security in corporate environments, consider these alternatives to plain `.env` files:

### AWS Secrets Manager

Store secrets in AWS Secrets Manager and retrieve them at runtime:

```python
import boto3
import json

def get_secret(secret_name, region_name="us-east-1"):
    client = boto3.client("secretsmanager", region_name=region_name)
    response = client.get_secret_value(SecretId=secret_name)
    return json.loads(response["SecretString"])

secrets = get_secret("my-app/production")
api_key = secrets["OPENAI_API_KEY"]
```

EC2 needs an IAM role with `secretsmanager:GetSecretValue` permission.

### AWS SSM Parameter Store

```python
import boto3

ssm = boto3.client("ssm", region_name="us-east-1")
response = ssm.get_parameter(
    Name="/myapp/production/OPENAI_API_KEY",
    WithDecryption=True
)
api_key = response["Parameter"]["Value"]
```

---

## Security Rules for `.env`

| Rule | Why |
|---|---|
| Never commit `.env` | Secrets would be in Git history forever |
| Use `chmod 600 .env` | Prevents other users on the server from reading it |
| Never log secret values | Logs may be forwarded to centralized logging |
| Rotate secrets regularly | Limits damage if a secret is compromised |
| Use Secrets Manager for production | Audit trail, rotation, IAM control |
| Use `.env.example` in the repo | Tells other developers what variables are needed |

---

## Quick Reference

```bash
# Create .env
cat > .env << 'EOF'
APP_ENV=production
OPENAI_API_KEY=replace_me
EOF

# Secure it
chmod 600 .env

# Verify
ls -la .env
cat .env

# Make sure it's gitignored
echo ".env" >> .gitignore
git status   # .env should not appear
```
