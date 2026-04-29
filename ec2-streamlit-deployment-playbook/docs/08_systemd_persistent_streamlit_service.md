# 08 — systemd Persistent Streamlit Service

This guide explains how to configure systemd to run Streamlit as a background service that persists across logouts and server reboots.

---

## The Problem with Terminal-Based Streamlit

When you run Streamlit directly in a terminal:

```bash
streamlit run app.py --server.port 8501 ...
```

The app is attached to your terminal session. When you:

- Close the SSH session
- Disconnect from SSM
- Log out
- The terminal times out

...Streamlit stops. All users lose access to the app.

**systemd solves this by running Streamlit as a background system service**, independent of any terminal session.

---

## What systemd Gives You

| Feature | Description |
|---|---|
| **Persistence** | App keeps running after you log out |
| **Auto-start on boot** | App starts automatically when the EC2 instance reboots |
| **Auto-restart on crash** | If the app crashes, systemd restarts it automatically |
| **Centralized logging** | All stdout/stderr goes to the system journal (`journalctl`) |
| **Standardized control** | Start, stop, restart, status — same commands as all system services |

---

## Step 1 — Create the Service File

Create a service unit file at `/etc/systemd/system/streamlit-app.service`:

```bash
sudo nano /etc/systemd/system/streamlit-app.service
```

Paste the following content (replace `YOUR_REPO_NAME` and `app.py` with your actual values):

```ini
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
```

Save with `Ctrl+O`, `Enter`, then `Ctrl+X`.

---

## Understanding the Service File

### `[Unit]` Section

| Directive | Meaning |
|---|---|
| `Description` | Human-readable name for the service |
| `After=network.target` | Wait until the network is ready before starting |

### `[Service]` Section

| Directive | Meaning |
|---|---|
| `User=root` | Run the service as the root user (change to a dedicated user for security) |
| `WorkingDirectory` | The directory where Streamlit runs — must contain `app.py` and `.env` |
| `Environment="PATH=..."` | Sets PATH so the venv's Python and pip are used |
| `EnvironmentFile` | Loads all variables from `.env` into the service environment |
| `ExecStart` | The exact command to run — uses full venv paths, no activation needed |
| `Restart=always` | Restart the service if it exits for any reason |
| `RestartSec=5` | Wait 5 seconds before restarting (prevents rapid crash loops) |

### `[Install]` Section

| Directive | Meaning |
|---|---|
| `WantedBy=multi-user.target` | Start this service when the system reaches normal multi-user mode |

---

## Step 2 — Reload systemd

After creating or modifying a service file, tell systemd to reload its configuration:

```bash
sudo systemctl daemon-reload
```

Run this command every time you edit the service file.

---

## Step 3 — Start the Service

```bash
sudo systemctl start streamlit-app
```

---

## Step 4 — Enable Auto-Start on Boot

```bash
sudo systemctl enable streamlit-app
```

This creates a symlink so the service starts automatically when the EC2 instance boots.

---

## Step 5 — Check Service Status

```bash
sudo systemctl status streamlit-app
```

Example of a healthy output:

```
● streamlit-app.service - Streamlit App
   Loaded: loaded (/etc/systemd/system/streamlit-app.service; enabled; ...)
   Active: active (running) since Tue 2026-04-29 10:00:00 UTC; 2min ago
 Main PID: 12345 (streamlit)
   CGroup: /system.slice/streamlit-app.service
           └─12345 /opt/apps/YOUR_REPO_NAME/venv/bin/python ...

Apr 29 10:00:00 ip-10-0-1-100 systemd[1]: Started Streamlit App.
Apr 29 10:00:05 ip-10-0-1-100 streamlit[12345]:   You can now view your Streamlit app in your browser.
```

Look for `Active: active (running)` — that means it's working.

---

## Step 6 — View Live Logs

```bash
sudo journalctl -u streamlit-app -f
```

The `-f` flag follows the log in real time. Press `Ctrl+C` to stop following.

View the last 100 log lines:

```bash
sudo journalctl -u streamlit-app -n 100
```

View logs since last boot:

```bash
sudo journalctl -u streamlit-app -b
```

---

## Other Service Control Commands

```bash
# Restart the service (e.g., after updating the app)
sudo systemctl restart streamlit-app

# Stop the service
sudo systemctl stop streamlit-app

# Reload the service gracefully (if supported by the app)
sudo systemctl reload streamlit-app

# Check if service is enabled (auto-start on boot)
sudo systemctl is-enabled streamlit-app

# Disable auto-start on boot
sudo systemctl disable streamlit-app
```

---

## Updating the App

After pulling new code from GitHub:

```bash
cd /opt/apps/YOUR_REPO_NAME
git pull origin main

source venv/bin/activate
pip install -r requirements.txt
deactivate

sudo systemctl restart streamlit-app
sudo systemctl status streamlit-app
```

---

## Editing the Service File After Creation

If you need to change the service configuration:

```bash
sudo nano /etc/systemd/system/streamlit-app.service
# Make your changes...

# Always reload after editing
sudo systemctl daemon-reload
sudo systemctl restart streamlit-app
```

---

## Using a Dedicated User (Security Best Practice)

For stricter security, run the app as a dedicated non-root user:

```bash
# Create the user
useradd -r -s /bin/false streamlituser

# Give the user ownership of the app directory
chown -R streamlituser:streamlituser /opt/apps/YOUR_REPO_NAME

# Update the service file
sudo nano /etc/systemd/system/streamlit-app.service
```

Change the `User` directive:

```ini
[Service]
User=streamlituser
```

Reload and restart:

```bash
sudo systemctl daemon-reload
sudo systemctl restart streamlit-app
```

---

## Testing Persistence

To confirm the service survives logout:

1. Start the service: `systemctl start streamlit-app`
2. Verify it's running: `systemctl status streamlit-app`
3. Log out of SSH: `exit`
4. Log back in
5. Check status again: `systemctl status streamlit-app` — should still show `active (running)`

To confirm auto-start after reboot:

```bash
sudo reboot
# Wait ~60 seconds
# SSH back in
sudo systemctl status streamlit-app
# Should show active (running) without you doing anything
```

---

## Quick Reference

```bash
# Create service file
nano /etc/systemd/system/streamlit-app.service

# After any service file change
systemctl daemon-reload

# Start / stop / restart
systemctl start streamlit-app
systemctl stop streamlit-app
systemctl restart streamlit-app

# Enable / disable auto-start
systemctl enable streamlit-app
systemctl disable streamlit-app

# Status and logs
systemctl status streamlit-app
journalctl -u streamlit-app -f
journalctl -u streamlit-app -n 100
```
