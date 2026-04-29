# EC2 Streamlit Deployment Playbook

> **A beginner-friendly, corporate-ready guide to deploying Streamlit apps on AWS EC2 Linux instances.**

---

## What This Repo Teaches

This playbook walks you through every step of deploying a Python Streamlit application on an AWS EC2 Linux server — from first login to a live, production-grade deployment.

You will learn how to:

- Log in to an EC2 instance via SSH or AWS Systems Manager (SSM)
- Use essential Linux/Unix commands
- Install Python 3.11 **side-by-side** with the existing system Python (without breaking it)
- Create isolated Python virtual environments
- Clone private GitHub repositories using personal access tokens
- Create `.env` files to store secrets securely on the server
- Install app dependencies and run Streamlit
- Configure `systemd` to keep the app running after logout and across reboots
- Configure Nginx as a reverse proxy on port 80/443
- Open EC2 security group ports correctly
- Make the app accessible from a browser
- Troubleshoot common deployment problems

---

## Who This Is For

- **Data scientists and developers** who are new to Linux server administration
- **Teams working inside AWS enterprise/corporate accounts** with Linux golden images
- **Anyone deploying a Streamlit app** to EC2 for the first time
- Beginner to intermediate skill level — no deep Linux expertise required

---

## High-Level Architecture

```
User Browser
     ↓
EC2 Public IP / Domain  (e.g., http://54.12.34.56 or https://app.yourcompany.com)
     ↓
Nginx on port 80 / 443  (reverse proxy — listens publicly)
     ↓
Streamlit running locally on 127.0.0.1:8501  (never exposed directly to internet)
     ↓
Python virtual environment using Python 3.11
     ↓
Your application code in /opt/apps/YOUR_REPO_NAME
```

**Why this architecture?**

- Nginx handles public traffic, SSL termination, and WebSocket proxying
- Streamlit stays locked to `127.0.0.1` — only accessible from within the server
- Systemd keeps Streamlit alive after logout and auto-restarts it on crash
- Python 3.11 in a virtual environment keeps your app isolated from the OS

---

## Core Deployment Flow

```
Step 1:  Login to EC2 (SSH or SSM)
Step 2:  Become root (or use sudo)
Step 3:  Check OS version
Step 4:  Install system packages (gcc, wget, openssl-devel, etc.)
Step 5:  Install Python 3.11 side-by-side using make altinstall
Step 6:  Create /opt/apps directory
Step 7:  Clone GitHub repo using personal access token
Step 8:  Create .env file with secrets
Step 9:  Create Python 3.11 virtual environment
Step 10: Activate venv and install requirements.txt
Step 11: Run Streamlit manually to test
Step 12: Create systemd service for persistence
Step 13: Install and configure Nginx reverse proxy
Step 14: Open port 80/443 in EC2 security group
Step 15: Access app from browser
Step 16: Verify logs and health
```

---

## ⚠️ Critical Warning — Do Not Replace System Python

> **Corporate Linux golden images typically have Python 3.7 (or another system Python) installed as part of the base OS.**
> System tools, package managers, and OS scripts depend on this Python.
>
> **NEVER run:**
> ```bash
> # DANGEROUS — do not do this
> ln -sf /usr/local/bin/python3.11 /usr/bin/python3
> ln -sf /usr/local/bin/python3.11 /usr/bin/python
> ```
>
> **Always use `make altinstall` (not `make install`) when building from source.**
> Always create application-specific virtual environments.
> Always reference Python 3.11 by its full path: `/usr/local/bin/python3.11`

---

## Quick Command Examples

```bash
# Check current user and OS
whoami
cat /etc/os-release

# Become root
sudo su -

# Install Python 3.11 (Amazon Linux 2 / RHEL-style)
cd /usr/src
wget https://www.python.org/ftp/python/3.11.9/Python-3.11.9.tgz
tar xzf Python-3.11.9.tgz
cd Python-3.11.9
./configure --enable-optimizations --with-ensurepip=install
make -j$(nproc)
make altinstall                     # <-- altinstall, never install

# Verify
/usr/local/bin/python3.11 --version

# Clone repo and set up app
mkdir -p /opt/apps
cd /opt/apps
git clone https://github.com/YOUR_ORG/YOUR_REPO.git
cd YOUR_REPO

# Create .env
cat > .env << 'EOF'
APP_ENV=production
OPENAI_API_KEY=replace_me
EOF
chmod 600 .env

# Create virtual environment using Python 3.11
/usr/local/bin/python3.11 -m venv venv
source venv/bin/activate
pip install --upgrade pip==24.0
pip install -r requirements.txt
pip install streamlit

# Run Streamlit
streamlit run app.py --server.port 8501 --server.address 127.0.0.1 --server.headless true
```

---

## Repository Structure

```
ec2-streamlit-deployment-playbook/
├── README.md                          ← You are here
├── QUICK_START.md                     ← Fast copy-paste deployment guide
├── docs/
│   ├── 01_ec2_login_and_root_access.md
│   ├── 02_basic_linux_command_cheat_sheet.md
│   ├── 03_install_python_311_side_by_side.md
│   ├── 04_python_virtual_environment_best_practices.md
│   ├── 05_github_clone_with_token.md
│   ├── 06_create_env_file_after_clone.md
│   ├── 07_install_requirements_and_run_streamlit.md
│   ├── 08_systemd_persistent_streamlit_service.md
│   ├── 09_nginx_reverse_proxy_setup.md
│   ├── 10_security_group_and_networking.md
│   ├── 11_domain_ssl_and_enterprise_options.md
│   ├── 12_troubleshooting.md
│   └── 13_full_end_to_end_deployment_flow.md
├── notebooks/                         ← Jupyter notebook tutorials
├── scripts/                           ← Automated shell scripts
├── examples/                          ← Sample app, configs, templates
└── templates/                         ← Checklists and templates
```

---

## Getting Started

1. Read [QUICK_START.md](QUICK_START.md) for a fast copy-paste flow
2. Start with [docs/01_ec2_login_and_root_access.md](docs/01_ec2_login_and_root_access.md) for a detailed walkthrough
3. Use the scripts in [scripts/](scripts/) to automate installation steps
4. Use [templates/deployment_checklist.md](templates/deployment_checklist.md) to track your progress

---

## License

MIT — see [LICENSE](LICENSE)
