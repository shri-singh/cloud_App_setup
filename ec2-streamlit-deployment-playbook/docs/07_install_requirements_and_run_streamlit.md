# 07 — Install Requirements and Run Streamlit

This guide covers installing your Python dependencies and running the Streamlit application on EC2.

---

## Prerequisites

Before this step, you should have:
- [ ] Cloned the GitHub repo to `/opt/apps/YOUR_REPO_NAME`
- [ ] Created the `.env` file
- [ ] Created the Python 3.11 virtual environment (`venv/`)

---

## Step 1 — Activate the Virtual Environment

Always activate the venv before installing packages or running the app:

```bash
cd /opt/apps/YOUR_REPO_NAME
source venv/bin/activate
```

Your prompt changes to show `(venv)` at the start.

Verify you are using Python 3.11 and the correct pip:

```bash
which python
# /opt/apps/YOUR_REPO_NAME/venv/bin/python

python --version
# Python 3.11.9

which pip
# /opt/apps/YOUR_REPO_NAME/venv/bin/pip
```

---

## Step 2 — Upgrade pip

Always upgrade pip before installing packages to avoid compatibility issues with newer package formats:

```bash
pip install --upgrade pip==24.0
```

---

## Step 3 — Install App Requirements

```bash
pip install -r requirements.txt
```

This reads `requirements.txt` and installs all packages listed there.

If there is no `requirements.txt` yet, create one:

```bash
# First install packages manually, then freeze:
pip install streamlit pandas numpy python-dotenv
pip freeze > requirements.txt
cat requirements.txt
```

### Troubleshooting pip Install Failures

If packages fail to install:

```bash
# Upgrade core build tools
pip install --upgrade pip setuptools wheel

# Try again
pip install -r requirements.txt
```

If a specific package fails due to a C extension compilation error, you may need additional system libraries:

```bash
# Amazon Linux 2 / RHEL:
yum install -y python3-devel gcc

# Ubuntu:
apt install -y python3.11-dev gcc
```

---

## Step 4 — Install Streamlit (If Not in requirements.txt)

```bash
pip install streamlit

# Verify
streamlit --version
```

---

## Step 5 — Test Streamlit Manually

Before setting up systemd, test the app by running it manually in the terminal. This lets you see startup errors directly.

### Option A — Direct Access Test (Binds to All Interfaces)

Use this to test from a browser via the EC2 public IP. Port 8501 must be open in the security group.

```bash
streamlit run app.py --server.port 8501 --server.address 0.0.0.0
```

Open browser: `http://YOUR_EC2_PUBLIC_IP:8501`

Press `Ctrl+C` to stop.

> ⚠️ The `0.0.0.0` address exposes the app directly to anyone who can reach port 8501. This is fine for a quick test but should not be the production configuration when Nginx is in use.

### Option B — Local-Only (Behind Nginx)

Use this when Nginx is already configured. Streamlit only listens on localhost:

```bash
streamlit run app.py --server.port 8501 --server.address 127.0.0.1 --server.headless true
```

- `--server.address 127.0.0.1` — only accessible from inside the server (Nginx connects to it)
- `--server.headless true` — disables Streamlit's browser auto-open and email prompt

Test from inside the server:

```bash
curl http://127.0.0.1:8501
```

If you get HTML back, Streamlit is running correctly.

---

## Streamlit Configuration Options

| Flag | Description |
|---|---|
| `--server.port 8501` | Port to listen on (default is 8501) |
| `--server.address 127.0.0.1` | Bind address (127.0.0.1 = local only, 0.0.0.0 = all interfaces) |
| `--server.headless true` | Run without trying to open a browser; suppress email prompt |
| `--server.maxUploadSize 200` | Max file upload size in MB (default 200) |
| `--server.enableCORS false` | Disable CORS check (sometimes needed behind proxies) |
| `--server.enableXsrfProtection false` | Disable XSRF protection (sometimes needed; understand the trade-off) |

---

## Using a Streamlit Config File

Instead of passing all flags on the command line, create a config file:

```bash
mkdir -p /opt/apps/YOUR_REPO_NAME/.streamlit

cat > /opt/apps/YOUR_REPO_NAME/.streamlit/config.toml << 'EOF'
[server]
port = 8501
address = "127.0.0.1"
headless = true
maxUploadSize = 200

[browser]
gatherUsageStats = false
EOF
```

Now you can run Streamlit with no flags:

```bash
streamlit run app.py
```

Streamlit reads `.streamlit/config.toml` automatically.

---

## Health Check

After starting Streamlit, verify it is responding:

```bash
# Check if Streamlit is listening on port 8501
ss -tulpn | grep 8501

# Make a test HTTP request
curl http://127.0.0.1:8501

# Check if the process is running
ps -ef | grep streamlit
```

---

## Keeping Streamlit Running After Logout

Running Streamlit directly in the terminal means it **stops when you log out or close the SSH session**.

Options:
1. Use `nohup` (quick workaround, not recommended for production):
   ```bash
   nohup streamlit run app.py --server.port 8501 --server.address 127.0.0.1 --server.headless true &
   ```
   This runs Streamlit in the background. Output goes to `nohup.out`.

2. **Use systemd** (recommended — see [docs/08_systemd_persistent_streamlit_service.md](08_systemd_persistent_streamlit_service.md))

systemd is preferred because it auto-restarts the app if it crashes and starts it automatically after a server reboot.

---

## Deactivating the Virtual Environment

When you are done with manual testing:

```bash
deactivate
```

The `(venv)` prefix disappears from your prompt.

---

## Quick Reference

```bash
# Full setup flow (inside venv)
cd /opt/apps/YOUR_REPO_NAME
source venv/bin/activate
pip install --upgrade pip==24.0
pip install -r requirements.txt
pip install streamlit

# Run for direct browser test
streamlit run app.py --server.port 8501 --server.address 0.0.0.0

# Run behind Nginx
streamlit run app.py --server.port 8501 --server.address 127.0.0.1 --server.headless true

# Health check
curl http://127.0.0.1:8501
ss -tulpn | grep 8501

# Stop
Ctrl+C

# Deactivate
deactivate
```
