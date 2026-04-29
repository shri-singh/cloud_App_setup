# 12 — Troubleshooting Guide

A systematic guide to diagnosing and fixing common problems during Streamlit deployment on EC2.

---

## General Diagnostic Approach

When something is not working, run these in order:

```bash
# 1. Who are you and where are you?
whoami
pwd
cat /etc/os-release

# 2. Is Python 3.11 available?
/usr/local/bin/python3.11 --version

# 3. Is the app directory correct?
ls -la /opt/apps/YOUR_REPO_NAME/

# 4. Is the .env file there and readable?
ls -la /opt/apps/YOUR_REPO_NAME/.env

# 5. Is Streamlit running?
systemctl status streamlit-app

# 6. Is Nginx running?
systemctl status nginx

# 7. What ports are listening?
ss -tulpn

# 8. Can we reach Streamlit internally?
curl http://127.0.0.1:8501

# 9. Can we reach Nginx on 80?
curl http://localhost
```

---

## Problem 1: `python3.11: command not found`

**Symptom:**
```
bash: python3.11: command not found
```

**Cause:** Python 3.11 was not installed, or was installed to a non-standard path.

**Fix:**

```bash
# Check if Python 3.11 binary exists at the expected path
ls -l /usr/local/bin/python3.11

# Check all Python binaries on the system
ls -l /usr/local/bin/python*
ls -l /usr/bin/python*

# Find any python3.11 anywhere
find / -name "python3.11" 2>/dev/null
```

If not found, Python 3.11 was never installed — go through [docs/03_install_python_311_side_by_side.md](03_install_python_311_side_by_side.md).

If it exists at a different path, use that path when creating the venv.

---

## Problem 2: Virtual Environment Uses Wrong Python Version

**Symptom:** After activating venv, `python --version` shows Python 3.7 (or another old version).

**Diagnosis:**

```bash
source venv/bin/activate
python --version   # Shows Python 3.7 — wrong
```

**Cause:** The venv was created with `python3 -m venv venv` which used the system Python 3.7.

**Fix:**

```bash
deactivate
rm -rf venv
/usr/local/bin/python3.11 -m venv venv
source venv/bin/activate
python --version   # Now should show Python 3.11.9
```

---

## Problem 3: `pip install -r requirements.txt` Fails

**Symptom:** Various error messages during package installation.

**Diagnostic Commands:**

```bash
# Ensure venv is active
which pip
pip --version

# Upgrade build tools first
pip install --upgrade pip setuptools wheel

# Try installing again
pip install -r requirements.txt
```

**Common causes and fixes:**

| Error | Likely Cause | Fix |
|---|---|---|
| `Could not build wheels` | Missing C build tools | `yum install -y gcc python3-devel` |
| `SSL certificate verify failed` | Outdated certificates or corporate proxy | `pip install --trusted-host pypi.org ...` |
| `Version not found` | Package version doesn't exist for Python 3.11 | Check PyPI for compatible version |
| `No module named 'pip'` | pip missing in Python install | Reinstall Python with `--with-ensurepip=install` |

---

## Problem 4: Git Clone Fails — Authentication Error

**Symptom:**
```
remote: Support for password authentication was removed on August 13, 2021.
fatal: Authentication failed
```
or
```
ERROR: Repository not found
fatal: repository 'https://github.com/...' not found
```

**Fixes:**

```bash
# Verify git is installed
git --version

# Check the repo URL is correct
git ls-remote https://github.com/YOUR_ORG/YOUR_REPO.git

# Clone with username and token
git clone https://YOUR_GITHUB_USERNAME:YOUR_GITHUB_TOKEN@github.com/YOUR_ORG/YOUR_REPO.git
```

For enterprise GitHub with SAML SSO: authorize the token for your organization at GitHub Settings → Personal access tokens → Configure SSO.

---

## Problem 5: App Starts Manually But Not Accessible in Browser

**Symptom:** `streamlit run app.py` seems to work, but browser shows "connection refused" or times out.

**Diagnostic:**

```bash
# Is Streamlit actually listening?
ss -tulpn | grep 8501

# Is it bound to the right address?
# If it shows 127.0.0.1:8501, it's local-only
# If you're testing directly (not via Nginx), it needs 0.0.0.0:8501
```

**Fixes:**

```bash
# For direct browser access (no Nginx), bind to all interfaces:
streamlit run app.py --server.port 8501 --server.address 0.0.0.0

# Also check EC2 security group — port 8501 must be open for direct access
# AWS Console → EC2 → Security Groups → Add inbound rule: TCP 8501 from your IP
```

---

## Problem 6: systemd Service Not Starting

**Symptom:**
```
systemctl status streamlit-app
● streamlit-app.service - Streamlit App
   Active: failed (Result: exit-code)
```

**Diagnostic:**

```bash
# View detailed logs
journalctl -u streamlit-app -n 50

# Check for common issues:
# - Wrong path to venv
# - Wrong path to app.py
# - .env file missing or wrong permissions
# - App crashes at startup (Python import error)

# Try running the exact ExecStart command manually:
/opt/apps/YOUR_REPO_NAME/venv/bin/streamlit run /opt/apps/YOUR_REPO_NAME/app.py \
    --server.port 8501 \
    --server.address 127.0.0.1 \
    --server.headless true
```

If the manual command works but systemd fails, the issue is in the service file. Common service file problems:

```bash
# Check the service file
cat /etc/systemd/system/streamlit-app.service

# After any change to the service file:
systemctl daemon-reload
systemctl restart streamlit-app
```

---

## Problem 7: 502 Bad Gateway from Nginx

**Symptom:** Browser shows `502 Bad Gateway`.

**Cause:** Nginx can reach port 8501 but gets no valid response. Usually means Streamlit is not running.

**Fix:**

```bash
# Check if Streamlit service is running
systemctl status streamlit-app

# Start it if stopped
systemctl start streamlit-app

# Check logs for startup errors
journalctl -u streamlit-app -n 100

# Verify Streamlit is responding
curl http://127.0.0.1:8501

# Check Nginx config is correct
nginx -t

# Reload Nginx
systemctl reload nginx

# Check Nginx error log for details
tail -50 /var/log/nginx/error.log
```

---

## Problem 8: 504 Gateway Timeout

**Symptom:** Browser shows `504 Gateway Timeout`.

**Cause:** Nginx waited too long for a response from Streamlit.

**Fix:**

Check if Streamlit is actually running and responding:

```bash
curl http://127.0.0.1:8501
```

If it's slow to respond, increase the timeout in Nginx config:

```nginx
location / {
    proxy_pass http://127.0.0.1:8501;
    proxy_read_timeout 86400;
    proxy_connect_timeout 60;
    proxy_send_timeout 86400;
}
```

```bash
nginx -t
systemctl reload nginx
```

---

## Problem 9: `.env` Variables Not Loaded

**Symptom:** `os.getenv("MY_KEY")` returns `None` in the app.

**Diagnosis:**

```bash
# Check .env file exists
ls -la /opt/apps/YOUR_REPO_NAME/.env

# Check .env file content
cat /opt/apps/YOUR_REPO_NAME/.env

# Check systemd service has EnvironmentFile set
grep EnvironmentFile /etc/systemd/system/streamlit-app.service
```

**Fixes:**

1. If using systemd `EnvironmentFile`: restart the service after editing `.env`:
   ```bash
   systemctl restart streamlit-app
   ```

2. If using `python-dotenv`: verify `load_dotenv()` is called at the top of your app and that the `.env` file is in the working directory.

3. Check the format — no quotes around values in `.env` for systemd:
   ```
   # Correct for systemd EnvironmentFile:
   OPENAI_API_KEY=sk-abc123

   # Incorrect for systemd (causes parse errors):
   OPENAI_API_KEY="sk-abc123"
   ```

---

## Problem 10: Streamlit Shows Blank Page or Spinner Only

**Symptom:** The browser loads but shows a blank page or an infinite spinner.

**Cause:** Usually a WebSocket connection failure between browser and Streamlit (via Nginx).

**Fix:**

Verify Nginx config has WebSocket headers:

```bash
grep -A 5 "proxy_set_header Upgrade" /etc/nginx/conf.d/streamlit.conf
```

Should show:

```nginx
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

If missing, add them and reload Nginx:

```bash
nginx -t
systemctl reload nginx
```

Also try:

```bash
# Clear browser cache and hard reload
# In Chrome: Ctrl+Shift+R (Windows) or Cmd+Shift+R (Mac)
```

---

## Problem 11: App Not Updated After Git Pull

**Symptom:** After `git pull`, old version of app is still running.

**Fix:**

Streamlit and systemd do not auto-detect code changes. You must restart the service:

```bash
cd /opt/apps/YOUR_REPO_NAME
git pull origin main

source venv/bin/activate
pip install -r requirements.txt   # Install any new packages
deactivate

systemctl restart streamlit-app
systemctl status streamlit-app
```

---

## Problem 12: Disk Space Full

**Symptom:** Errors about "no space left on device", pip install fails, logs stop writing.

**Diagnosis:**

```bash
df -h          # Check disk usage of all filesystems
du -sh /opt/apps/*  # Check size of app directories
du -sh /var/log/*   # Check log file sizes
```

**Fix:**

```bash
# Clean up old Python build files (if you built from source)
rm -rf /usr/src/Python-3.11.9/

# Clean pip cache
pip cache purge

# Clean old journal logs (keep last 7 days)
journalctl --vacuum-time=7d

# Truncate large log files (be careful — do not delete logs you may need)
> /var/log/nginx/access.log
```

---

## Quick Diagnostic Script

Run all the key health checks at once:

```bash
echo "=== System ===" && whoami && cat /etc/os-release | head -3
echo "=== Python ===" && /usr/local/bin/python3.11 --version
echo "=== Streamlit Service ===" && systemctl status streamlit-app --no-pager | head -10
echo "=== Nginx Service ===" && systemctl status nginx --no-pager | head -10
echo "=== Ports ===" && ss -tulpn | grep -E "8501|:80|:443"
echo "=== Streamlit Health ===" && curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8501
echo "=== Nginx Health ===" && curl -s -o /dev/null -w "%{http_code}" http://localhost
echo "=== Disk ===" && df -h /
echo "=== RAM ===" && free -h
```

---

## Log File Locations

| Service | Log Location |
|---|---|
| Streamlit (via systemd) | `journalctl -u streamlit-app` |
| Nginx access log | `/var/log/nginx/access.log` |
| Nginx error log | `/var/log/nginx/error.log` |
| System log | `/var/log/messages` or `journalctl -xe` |
| Auth log | `/var/log/secure` (Amazon Linux) or `/var/log/auth.log` (Ubuntu) |
