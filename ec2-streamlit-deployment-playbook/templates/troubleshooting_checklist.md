# Troubleshooting Checklist

Run these commands in order when something is not working. Each command gives you information to narrow down the problem.

---

## Step 1 — Who Am I and Where Am I?

```bash
whoami
# Should be: root (or your deployment user)

pwd
# Should be in your app directory, e.g.: /opt/apps/YOUR_REPO_NAME

cat /etc/os-release
# Shows Linux distribution — determines which package manager to use
```

---

## Step 2 — Is Python 3.11 Available?

```bash
/usr/local/bin/python3.11 --version
# Expected: Python 3.11.9
# If not found: run scripts/install_python311_amazon_linux2.sh

python3 --version
# This should still show system Python (3.7.x) — unchanged

which python3.11
# Shows where Python 3.11 is on this system
```

---

## Step 3 — Is the Virtual Environment Correct?

```bash
cd /opt/apps/YOUR_REPO_NAME
ls -la
# Should see: app.py, requirements.txt, .env, venv/

source venv/bin/activate
which python
# Must show: /opt/apps/YOUR_REPO_NAME/venv/bin/python

python --version
# Must show: Python 3.11.x
# If it shows 3.7.x: rm -rf venv && /usr/local/bin/python3.11 -m venv venv

which pip
# Must show: /opt/apps/YOUR_REPO_NAME/venv/bin/pip

pip --version

pip list
# Shows all installed packages in the venv

pip show streamlit
# Shows if streamlit is installed and at what version
```

---

## Step 4 — Is Git Working?

```bash
git --version

cd /opt/apps/YOUR_REPO_NAME
git remote -v
# Shows the remote repo URL

git status
# Shows any uncommitted local changes

git log --oneline -5
# Shows last 5 commits — verifies the right code is deployed
```

---

## Step 5 — Is the Streamlit Service Running?

```bash
systemctl status streamlit-app
# Should show: Active: active (running)
# If failed or inactive, check logs below

journalctl -u streamlit-app -n 100
# Last 100 lines of service logs — look for error messages

journalctl -u streamlit-app -f
# Follow live logs — run this then trigger the problem to see what happens
```

---

## Step 6 — Is Nginx Running?

```bash
systemctl status nginx
# Should show: Active: active (running)

nginx -t
# Should show: syntax is ok / test is successful
# If errors: open /etc/nginx/conf.d/streamlit.conf and check syntax

cat /etc/nginx/conf.d/streamlit.conf
# Review the proxy configuration
```

---

## Step 7 — What Ports Are Listening?

```bash
ss -tulpn
# Shows all listening ports

ss -tulpn | grep 8501
# Should show Streamlit listening on 127.0.0.1:8501

ss -tulpn | grep :80
# Should show Nginx listening on 0.0.0.0:80

ss -tulpn | grep :443
# Should show Nginx or other service on 443 if SSL is configured
```

---

## Step 8 — Can We Reach Streamlit Internally?

```bash
curl http://127.0.0.1:8501
# Should return HTML content
# If connection refused: Streamlit is not running or on a different port

curl -v http://127.0.0.1:8501
# Verbose — shows exact headers and response
```

---

## Step 9 — Can We Reach Nginx?

```bash
curl http://localhost
# Should return Streamlit HTML (proxied through Nginx)
# If 502: Nginx is up but Streamlit is down
# If connection refused: Nginx is not running

curl -I http://localhost
# Just the HTTP headers — quick check
```

---

## Step 10 — Is the .env File Correct?

```bash
ls -la /opt/apps/YOUR_REPO_NAME/.env
# Should show: -rw------- (permissions 600)

cat /opt/apps/YOUR_REPO_NAME/.env
# Review that all keys have values (no empty required keys)

# After editing .env, restart the service:
systemctl restart streamlit-app
```

---

## Step 11 — System Resources

```bash
df -h
# Check disk space — if / is 100% full, many things will fail

free -h
# Check available RAM — if near 0, the app may be OOMing

top
# Live process list — check CPU and memory usage
```

---

## Step 12 — Nginx Logs

```bash
tail -50 /var/log/nginx/access.log
# Recent HTTP requests and response codes

tail -50 /var/log/nginx/error.log
# Nginx errors — look for upstream connection failures, proxy errors
```

---

## Quick All-in-One Diagnostic

Copy and run this entire block to get a health snapshot:

```bash
echo "==========================="
echo "HEALTH CHECK $(date)"
echo "==========================="
echo ""
echo "--- Who / Where ---"
whoami; pwd

echo ""
echo "--- OS ---"
cat /etc/os-release 2>/dev/null | grep PRETTY_NAME

echo ""
echo "--- Python ---"
/usr/local/bin/python3.11 --version 2>/dev/null || echo "python3.11 NOT FOUND"
python3 --version 2>/dev/null

echo ""
echo "--- Streamlit Service ---"
systemctl status streamlit-app --no-pager 2>/dev/null | head -8

echo ""
echo "--- Nginx Service ---"
systemctl status nginx --no-pager 2>/dev/null | head -5

echo ""
echo "--- Ports ---"
ss -tulpn 2>/dev/null | grep -E "8501|:80 |:443 "

echo ""
echo "--- HTTP Checks ---"
echo -n "Streamlit internal: "
curl -s -o /dev/null -w "HTTP %{http_code}" http://127.0.0.1:8501 2>/dev/null || echo "FAILED"
echo ""
echo -n "Nginx local: "
curl -s -o /dev/null -w "HTTP %{http_code}" http://localhost 2>/dev/null || echo "FAILED"

echo ""
echo "--- Disk / RAM ---"
df -h / 2>/dev/null | tail -1
free -h 2>/dev/null | grep Mem

echo ""
echo "--- Last 10 App Log Lines ---"
journalctl -u streamlit-app -n 10 --no-pager 2>/dev/null

echo "==========================="
```

---

## Common Problem → Fix Quick Reference

| Symptom | Most Likely Cause | First Command to Run |
|---|---|---|
| `python3.11: not found` | Python 3.11 not installed | `ls /usr/local/bin/python*` |
| venv Python is 3.7 | Created with wrong Python | `rm -rf venv && /usr/local/bin/python3.11 -m venv venv` |
| Service not starting | Syntax error or bad path | `journalctl -u streamlit-app -n 50` |
| 502 Bad Gateway | Streamlit not running | `systemctl status streamlit-app` |
| 504 Gateway Timeout | App too slow or not responding | `curl http://127.0.0.1:8501` |
| WebSocket frozen | Missing Nginx headers | `grep Upgrade /etc/nginx/conf.d/streamlit.conf` |
| `.env` not loaded | Missing EnvironmentFile or wrong format | `cat /etc/systemd/system/streamlit-app.service` |
| Disk full | Large logs or build artifacts | `df -h && du -sh /usr/src/*` |
| Git clone auth fails | Wrong token or SSO not authorized | Use `read -s` method; authorize SSO |
