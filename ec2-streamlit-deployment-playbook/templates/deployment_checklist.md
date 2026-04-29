# Deployment Checklist

Use this checklist when deploying a new Streamlit app to EC2. Check each item as you complete it.

**App Name:** ___________________________
**EC2 Instance ID:** ___________________________
**EC2 Public IP / Domain:** ___________________________
**Deployment Date:** ___________________________

---

## Phase 1 — EC2 Access

- [ ] SSH or SSM Session Manager access to EC2 instance works
- [ ] Confirmed current user with `whoami`
- [ ] Checked OS version with `cat /etc/os-release`
- [ ] Became root with `sudo su -`

---

## Phase 2 — System Packages

- [ ] Updated system packages (`yum update -y` or `dnf update -y`)
- [ ] Installed build dependencies (gcc, openssl-devel, bzip2-devel, etc.)
- [ ] Installed git (`git --version` shows a version)

---

## Phase 3 — Python 3.11 Installation

- [ ] `/usr/local/bin/python3.11 --version` returns Python 3.11.x
- [ ] Confirmed `make altinstall` was used (not `make install`)
- [ ] System Python unchanged: `python3 --version` still shows original version
- [ ] pip upgraded: `/usr/local/bin/python3.11 -m pip install --upgrade pip==24.0`

---

## Phase 4 — Application Setup

- [ ] `/opt/apps` directory created
- [ ] Repository cloned to `/opt/apps/YOUR_REPO_NAME`
- [ ] App directory verified: `ls -la /opt/apps/YOUR_REPO_NAME/`
- [ ] `.env` file created with actual secret values
- [ ] `.env` permissions set to 600: `ls -la .env` shows `-rw-------`
- [ ] `.env` added to `.gitignore`

---

## Phase 5 — Python Virtual Environment

- [ ] venv created with Python 3.11: `/usr/local/bin/python3.11 -m venv venv`
- [ ] venv activated: `source venv/bin/activate`
- [ ] `python --version` inside venv shows Python 3.11.x
- [ ] pip upgraded inside venv: `pip install --upgrade pip==24.0`
- [ ] Requirements installed: `pip install -r requirements.txt`
- [ ] Streamlit installed: `streamlit --version` returns a version

---

## Phase 6 — Manual App Test

- [ ] App starts without errors: `streamlit run app.py --server.port 8501 --server.address 0.0.0.0`
- [ ] App loads in browser at `http://YOUR_EC2_PUBLIC_IP:8501`
- [ ] No Python import errors in terminal
- [ ] Environment variables loading correctly (APP_ENV shows "production")

---

## Phase 7 — systemd Service

- [ ] Service file created at `/etc/systemd/system/streamlit-app.service`
- [ ] `WorkingDirectory` in service file points to correct app directory
- [ ] `EnvironmentFile` points to `.env`
- [ ] `ExecStart` uses correct venv path and app file
- [ ] `systemctl daemon-reload` run after creating service file
- [ ] Service started: `systemctl start streamlit-app`
- [ ] Service enabled for auto-start: `systemctl enable streamlit-app`
- [ ] `systemctl status streamlit-app` shows `Active: active (running)`
- [ ] `journalctl -u streamlit-app -n 20` shows no errors
- [ ] `curl http://127.0.0.1:8501` returns HTTP 200

---

## Phase 8 — Nginx

- [ ] Nginx installed: `nginx -v` shows a version
- [ ] Nginx config created at `/etc/nginx/conf.d/streamlit.conf`
- [ ] Config includes WebSocket headers (`Upgrade` and `Connection`)
- [ ] `nginx -t` shows "syntax is ok" and "test is successful"
- [ ] Nginx started: `systemctl start nginx`
- [ ] Nginx enabled: `systemctl enable nginx`
- [ ] `systemctl reload nginx` applied config changes
- [ ] `curl http://localhost` returns Streamlit HTML (HTTP 200 or 302)

---

## Phase 9 — Security Group

- [ ] Port 80 (HTTP) open in EC2 security group
- [ ] Port 443 (HTTPS) open in EC2 security group (if using SSL)
- [ ] Port 22 (SSH) restricted to admin IP only (not 0.0.0.0/0)
- [ ] Port 8501 NOT open publicly (traffic goes through Nginx only)

---

## Phase 10 — Live App Verification

- [ ] App accessible from browser at `http://YOUR_EC2_PUBLIC_IP`
- [ ] App displays correct environment (shows "production")
- [ ] Interactive elements work (charts, inputs, uploads)
- [ ] Streamlit WebSocket connected (no spinner-only or frozen UI)
- [ ] Logs checked: `journalctl -u streamlit-app -n 50` — no errors

---

## Phase 11 — Post-Deployment

- [ ] Logout from EC2 and log back in — service still running
- [ ] Reboot test (optional): `sudo reboot` → service auto-starts
- [ ] Team notified of deployment
- [ ] App URL documented and shared

---

## Notes

```
Deployment notes, issues encountered, or decisions made:




```
