# Quick Start — EC2 Streamlit Deployment

> Copy-paste flow for Amazon Linux 2 / Amazon Linux 2023 / RHEL-style systems.
> Replace all `YOUR_*` placeholders with your actual values before running.

---

## Placeholders — Replace These First

| Placeholder | What to Replace With |
|---|---|
| `YOUR_REPO_URL` | Full HTTPS GitHub URL, e.g. `https://github.com/YOUR_ORG/YOUR_REPO.git` |
| `YOUR_REPO_NAME` | The folder name after cloning, e.g. `my-streamlit-app` |
| `YOUR_GITHUB_USERNAME` | Your GitHub username |
| `YOUR_GITHUB_TOKEN` | Your GitHub personal access token |
| `YOUR_DOMAIN_OR_PUBLIC_IP` | EC2 public IP or domain, e.g. `54.12.34.56` |
| `app.py` | Your Streamlit entry point file |

---

## Step 1 — Login and Become Root

```bash
# SSH login (replace with your key and IP)
ssh -i /path/to/your-key.pem ec2-user@YOUR_DOMAIN_OR_PUBLIC_IP

# Become root
sudo su -

# Confirm you are root
whoami     # should print: root
```

---

## Step 2 — Check OS Version

```bash
cat /etc/os-release
```

---

## Step 3 — Update System and Install Build Dependencies

```bash
# For Amazon Linux 2 / RHEL / CentOS:
yum update -y
yum install -y git wget gcc make openssl-devel bzip2-devel libffi-devel \
    zlib-devel xz-devel sqlite-devel readline-devel tk-devel gdbm-devel \
    ncurses-devel

# For Amazon Linux 2023:
# dnf update -y
# dnf install -y git wget gcc make openssl-devel bzip2-devel libffi-devel \
#     zlib-devel xz-devel sqlite-devel readline-devel tk-devel gdbm-devel \
#     ncurses-devel
```

---

## Step 4 — Install Python 3.11 Side-by-Side

> ⚠️ **WARNING:** Use `make altinstall` — never `make install`.
> `altinstall` does NOT overwrite system Python. `make install` would.

```bash
cd /usr/src
wget https://www.python.org/ftp/python/3.11.9/Python-3.11.9.tgz
tar xzf Python-3.11.9.tgz
cd Python-3.11.9
./configure --enable-optimizations --with-ensurepip=install
make -j$(nproc)
make altinstall
```

### Verify Python 3.11

```bash
/usr/local/bin/python3.11 --version
# Expected: Python 3.11.9

/usr/local/bin/python3.11 -m pip --version
# Expected: pip 24.x ... (python 3.11)

/usr/local/bin/python3.11 -m pip install --upgrade pip==24.0
```

### Confirm System Python is Untouched

```bash
python3 --version
# Should still show 3.7.x or whatever was there before
```

---

## Step 5 — Clone Your GitHub Repo

```bash
mkdir -p /opt/apps
cd /opt/apps

# Clone (you will be prompted for username and token as password)
git clone YOUR_REPO_URL

# Example:
# git clone https://github.com/YOUR_ORG/YOUR_REPO.git
# Username: YOUR_GITHUB_USERNAME
# Password: YOUR_GITHUB_TOKEN

cd YOUR_REPO_NAME
```

---

## Step 6 — Create the `.env` File

> ⚠️ Never commit `.env` to GitHub. Create it manually on the server.

```bash
cat > .env << 'EOF'
OPENAI_API_KEY=replace_me
DATABASE_URL=replace_me
APP_ENV=production
STREAMLIT_SERVER_PORT=8501
EOF

# Lock down permissions so only root can read it
chmod 600 .env
ls -la .env
```

---

## Step 7 — Create Python 3.11 Virtual Environment

```bash
cd /opt/apps/YOUR_REPO_NAME

# Create venv using Python 3.11 explicitly
/usr/local/bin/python3.11 -m venv venv

# Activate
source venv/bin/activate

# Confirm we are using Python 3.11
which python       # Should show: /opt/apps/YOUR_REPO_NAME/venv/bin/python
python --version   # Should show: Python 3.11.9
which pip
pip --version

# Upgrade pip
pip install --upgrade pip==24.0
```

---

## Step 8 — Install Requirements and Streamlit

```bash
pip install -r requirements.txt
pip install streamlit

# Verify
streamlit --version
```

---

## Step 9 — Test Streamlit Manually

```bash
# Quick test — binds to all interfaces (use for testing only)
streamlit run app.py --server.port 8501 --server.address 0.0.0.0

# Press Ctrl+C to stop
```

Open browser: `http://YOUR_DOMAIN_OR_PUBLIC_IP:8501`

> Note: Port 8501 must be open in your EC2 security group for this direct test.

---

## Step 10 — Create systemd Service (Persistent)

```bash
# Deactivate venv first
deactivate

# Create service file
cat > /etc/systemd/system/streamlit-app.service << 'EOF'
[Unit]
Description=Streamlit App
After=network.target

[Service]
User=root
WorkingDirectory=/opt/apps/YOUR_REPO_NAME
Environment="PATH=/opt/apps/YOUR_REPO_NAME/venv/bin:/usr/local/bin:/usr/bin:/bin"
EnvironmentFile=/opt/apps/YOUR_REPO_NAME/.env
ExecStart=/opt/apps/YOUR_REPO_NAME/venv/bin/streamlit run app.py \
    --server.port 8501 \
    --server.address 127.0.0.1 \
    --server.headless true
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Load and start service
systemctl daemon-reload
systemctl start streamlit-app
systemctl enable streamlit-app
systemctl status streamlit-app
```

---

## Step 11 — Install and Configure Nginx

```bash
# Amazon Linux 2:
amazon-linux-extras enable nginx1
yum clean metadata
yum install -y nginx

# Amazon Linux 2023:
# dnf install -y nginx

# Ubuntu:
# apt update && apt install -y nginx

# Start Nginx
systemctl start nginx
systemctl enable nginx

# Create reverse proxy config
cat > /etc/nginx/conf.d/streamlit.conf << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8501;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Required for Streamlit WebSocket support
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_read_timeout 86400;
    }
}
EOF

# Test config and reload
nginx -t
systemctl reload nginx
```

---

## Step 12 — Open Security Group Ports

In the AWS Console or via CLI:

```
Inbound Rules:
  HTTP   TCP  80   from 0.0.0.0/0 (or your VPN/office IP range)
  HTTPS  TCP  443  from 0.0.0.0/0 (or your VPN/office IP range)
  SSH    TCP  22   from YOUR_ADMIN_IP only

Do NOT open port 8501 publicly when Nginx is in use.
```

---

## Step 13 — Test Live App

```bash
# Health check from inside the server
curl http://127.0.0.1:8501
curl http://localhost

# Check service status
systemctl status streamlit-app
systemctl status nginx

# View live logs
journalctl -u streamlit-app -f
```

Open browser: `http://YOUR_DOMAIN_OR_PUBLIC_IP`

---

## Step 14 — Update App After Code Changes

```bash
cd /opt/apps/YOUR_REPO_NAME
git pull origin main
source venv/bin/activate
pip install -r requirements.txt
deactivate
systemctl restart streamlit-app
systemctl status streamlit-app
```

---

## Troubleshooting Quick Reference

| Problem | Command |
|---|---|
| App not loading | `systemctl status streamlit-app` |
| View app logs | `journalctl -u streamlit-app -f` |
| Nginx not working | `nginx -t && systemctl status nginx` |
| Check ports | `ss -tulpn` |
| Test Streamlit locally | `curl http://127.0.0.1:8501` |
| Python version wrong in venv | `rm -rf venv && /usr/local/bin/python3.11 -m venv venv` |

For detailed troubleshooting, see [docs/12_troubleshooting.md](docs/12_troubleshooting.md).
