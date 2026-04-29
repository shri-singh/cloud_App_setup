# 13 — Full End-to-End Deployment Flow

This is a single, complete, copy-paste-ready guide that takes you from a blank EC2 instance to a live Streamlit app behind Nginx. All steps are in order with explanations.

Replace all `YOUR_*` placeholders before running.

---

## Your Placeholders

| Placeholder | Your Value |
|---|---|
| `YOUR_EC2_PUBLIC_IP` | EC2 public IP, e.g. `54.12.34.56` |
| `YOUR_REPO_URL` | GitHub HTTPS clone URL |
| `YOUR_REPO_NAME` | Folder name after cloning |
| `YOUR_GITHUB_USERNAME` | GitHub username |
| `YOUR_GITHUB_TOKEN` | GitHub personal access token |
| `YOUR_APP_FILE` | Your Streamlit entry file, e.g. `app.py` |
| `YOUR_OPENAI_KEY` | Your OpenAI API key (or other secret) |

---

## Phase 1 — Login and System Check

```bash
# SSH into EC2 (from your laptop)
ssh -i /path/to/your-key.pem ec2-user@YOUR_EC2_PUBLIC_IP

# Confirm your identity
whoami    # ec2-user (or root)

# Check OS
cat /etc/os-release

# Become root
sudo su -
whoami    # root

# Check current directory
pwd    # /root
```

---

## Phase 2 — Update System and Install Build Dependencies

```bash
# Amazon Linux 2 / RHEL-style:
yum update -y

yum install -y \
    git \
    wget \
    gcc \
    make \
    openssl-devel \
    bzip2-devel \
    libffi-devel \
    zlib-devel \
    xz-devel \
    sqlite-devel \
    readline-devel \
    tk-devel \
    gdbm-devel \
    ncurses-devel

# ---- OR for Amazon Linux 2023 / RHEL 8+: ----
# dnf update -y
# dnf install -y git wget gcc make openssl-devel bzip2-devel libffi-devel \
#     zlib-devel xz-devel sqlite-devel readline-devel tk-devel gdbm-devel ncurses-devel
```

---

## Phase 3 — Install Python 3.11 Side-by-Side

> ⚠️ Use `make altinstall` — NOT `make install`

```bash
cd /usr/src
wget https://www.python.org/ftp/python/3.11.9/Python-3.11.9.tgz
tar xzf Python-3.11.9.tgz
cd Python-3.11.9
./configure --enable-optimizations --with-ensurepip=install
make -j$(nproc)
make altinstall
```

This step takes 5–15 minutes depending on your EC2 instance type.

```bash
# Verify Python 3.11 is installed
/usr/local/bin/python3.11 --version
# Expected: Python 3.11.9

# Verify pip
/usr/local/bin/python3.11 -m pip --version

# Upgrade pip
/usr/local/bin/python3.11 -m pip install --upgrade pip==24.0

# Confirm system Python is unchanged
python3 --version
# Expected: still Python 3.7.x
```

---

## Phase 4 — Create App Directory and Clone Repository

```bash
mkdir -p /opt/apps
cd /opt/apps

# Clone the repository (you will be prompted for username and token as password)
git clone YOUR_REPO_URL

# Example:
# git clone https://github.com/YOUR_ORG/YOUR_REPO.git
# Username: YOUR_GITHUB_USERNAME
# Password: YOUR_GITHUB_TOKEN

# Enter the repo directory
cd YOUR_REPO_NAME

# Confirm files are there
ls -la
```

---

## Phase 5 — Create the `.env` File

```bash
# Make sure you're in the app directory
pwd    # /opt/apps/YOUR_REPO_NAME

# Create .env with your actual secret values
cat > .env << 'EOF'
APP_ENV=production
OPENAI_API_KEY=YOUR_OPENAI_KEY
STREAMLIT_SERVER_PORT=8501
EOF

# Open with nano to fill in all values
nano .env

# Lock permissions — only root can read this file
chmod 600 .env

# Verify
ls -la .env
cat .env
```

---

## Phase 6 — Create Python 3.11 Virtual Environment

```bash
cd /opt/apps/YOUR_REPO_NAME

# Create venv using Python 3.11
/usr/local/bin/python3.11 -m venv venv

# Activate the venv
source venv/bin/activate

# Verify Python 3.11 is active inside the venv
which python
# /opt/apps/YOUR_REPO_NAME/venv/bin/python

python --version
# Python 3.11.9

# Upgrade pip inside venv
pip install --upgrade pip==24.0
```

---

## Phase 7 — Install Requirements and Streamlit

```bash
# Inside venv (check for (venv) prefix in your prompt)
pip install -r requirements.txt
pip install streamlit

# Verify
streamlit --version
pip list | grep streamlit
```

---

## Phase 8 — Test Streamlit Manually

```bash
# Run for direct testing (needs port 8501 open in security group)
streamlit run YOUR_APP_FILE --server.port 8501 --server.address 0.0.0.0

# Open browser: http://YOUR_EC2_PUBLIC_IP:8501
# If you see your app — success!
# Press Ctrl+C to stop
```

---

## Phase 9 — Create systemd Service for Persistence

```bash
# Deactivate venv (systemd will use venv path directly)
deactivate

# Create the service file
cat > /etc/systemd/system/streamlit-app.service << 'EOF'
[Unit]
Description=Streamlit App
After=network.target

[Service]
User=root
WorkingDirectory=/opt/apps/YOUR_REPO_NAME
Environment="PATH=/opt/apps/YOUR_REPO_NAME/venv/bin:/usr/local/bin:/usr/bin:/bin"
EnvironmentFile=/opt/apps/YOUR_REPO_NAME/.env
ExecStart=/opt/apps/YOUR_REPO_NAME/venv/bin/streamlit run YOUR_APP_FILE \
    --server.port 8501 \
    --server.address 127.0.0.1 \
    --server.headless true
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Load, start, and enable the service
systemctl daemon-reload
systemctl start streamlit-app
systemctl enable streamlit-app

# Check status
systemctl status streamlit-app

# View logs
journalctl -u streamlit-app -n 30

# Verify Streamlit is listening internally
curl http://127.0.0.1:8501
```

---

## Phase 10 — Install Nginx

```bash
# Amazon Linux 2:
amazon-linux-extras enable nginx1
yum clean metadata
yum install -y nginx

# Amazon Linux 2023:
# dnf install -y nginx

# Ubuntu:
# apt update && apt install -y nginx

# Start and enable Nginx
systemctl start nginx
systemctl enable nginx
systemctl status nginx

# Verify Nginx is running on port 80
curl http://localhost
```

---

## Phase 11 — Configure Nginx as Reverse Proxy

```bash
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

        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_read_timeout 86400;
    }
}
EOF

# Test Nginx config
nginx -t

# Apply changes
systemctl reload nginx

# Test full stack
curl http://localhost
```

---

## Phase 12 — Open Security Group Ports

In AWS Console (or via CLI):

```
Inbound Rules to Add:
  HTTP    TCP  80   Source: 0.0.0.0/0  (or your approved IP range)
  HTTPS   TCP  443  Source: 0.0.0.0/0  (or your approved IP range)
  SSH     TCP  22   Source: YOUR_ADMIN_IP/32 only

Do NOT add a rule for port 8501.
```

---

## Phase 13 — Full Verification

```bash
# System health
echo "=== Services ===" 
systemctl is-active streamlit-app
systemctl is-active nginx

echo "=== Ports ==="
ss -tulpn | grep -E ":80|:443|:8501"

echo "=== App Health ==="
curl -s -o /dev/null -w "Streamlit internal: HTTP %{http_code}\n" http://127.0.0.1:8501
curl -s -o /dev/null -w "Nginx local: HTTP %{http_code}\n" http://localhost

echo "=== Logs (last 10 lines) ==="
journalctl -u streamlit-app -n 10 --no-pager
```

Open a browser: `http://YOUR_EC2_PUBLIC_IP`

Your Streamlit app should load. If it does — congratulations, deployment complete.

---

## Phase 14 — Updating the App (Future Deployments)

Each time you push new code to GitHub and want to update the live app:

```bash
cd /opt/apps/YOUR_REPO_NAME

# Pull latest code
git pull origin main

# Activate venv and install any new packages
source venv/bin/activate
pip install -r requirements.txt
deactivate

# Restart the service
systemctl restart streamlit-app

# Verify
systemctl status streamlit-app
journalctl -u streamlit-app -n 20
```

---

## Full Deployment Summary

```
Phase  1: Login → Become Root → Check OS
Phase  2: yum update + install build tools
Phase  3: Build Python 3.11 from source (make altinstall)
Phase  4: mkdir /opt/apps → git clone repo
Phase  5: Create .env file with secrets → chmod 600
Phase  6: python3.11 -m venv venv → activate → upgrade pip
Phase  7: pip install -r requirements.txt → pip install streamlit
Phase  8: streamlit run app.py --server.address 0.0.0.0 (manual test)
Phase  9: Create systemd service → daemon-reload → start → enable
Phase 10: yum install nginx → start → enable
Phase 11: Create /etc/nginx/conf.d/streamlit.conf → nginx -t → reload
Phase 12: Open ports 80/443 in EC2 security group
Phase 13: Full health check → browser test
Phase 14: (Future) git pull → pip install → systemctl restart
```
