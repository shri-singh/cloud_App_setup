# 09 — Nginx Reverse Proxy Setup

This guide explains how to install and configure Nginx to serve your Streamlit app on port 80 (HTTP) by proxying requests to Streamlit running on `127.0.0.1:8501`.

---

## Why Use Nginx in Front of Streamlit?

| Without Nginx | With Nginx |
|---|---|
| App exposed directly on port 8501 | App runs internally; Nginx handles port 80/443 |
| No SSL/HTTPS support built-in | Nginx can terminate SSL |
| Port 8501 must be open in security group | Only ports 80/443 need to be public |
| Streamlit handles all connections | Nginx can handle load balancing, caching, headers |
| Browser URL includes `:8501` | Clean URLs without port number |

Nginx acts as a **reverse proxy**: it receives requests from users on port 80, forwards them to Streamlit on port 8501, and sends Streamlit's response back to the user.

---

## Streamlit and WebSockets

Streamlit uses **WebSockets** for real-time UI updates (showing progress bars, live data updates, interactive widgets). Nginx must be configured to support WebSocket proxying — otherwise the UI will appear to load but then freeze or disconnect.

The key headers required are:

```nginx
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

These are included in the config below.

---

## Step 1 — Install Nginx

### Amazon Linux 2

```bash
sudo amazon-linux-extras enable nginx1
sudo yum clean metadata
sudo yum install -y nginx
```

### Amazon Linux 2023

```bash
sudo dnf install -y nginx
```

### RHEL 8 / CentOS 8+

```bash
sudo dnf install -y nginx
```

### Ubuntu 20.04 / 22.04

```bash
sudo apt update
sudo apt install -y nginx
```

---

## Step 2 — Start and Enable Nginx

```bash
sudo systemctl start nginx
sudo systemctl enable nginx
sudo systemctl status nginx
```

Verify Nginx is running and listening on port 80:

```bash
ss -tulpn | grep :80
curl http://localhost
```

The `curl` command should return Nginx's default welcome page HTML.

---

## Step 3 — Create the Streamlit Proxy Configuration

Create a new Nginx config file for your Streamlit app:

```bash
sudo nano /etc/nginx/conf.d/streamlit.conf
```

Paste the following:

```nginx
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

        # Long timeout for interactive apps
        proxy_read_timeout 86400;
    }
}
```

Save: `Ctrl+O`, `Enter`, `Ctrl+X`.

---

## Understanding the Nginx Configuration

| Directive | What It Does |
|---|---|
| `listen 80` | Nginx listens for HTTP connections on port 80 |
| `server_name _` | Match all domain names (wildcard). Replace with your domain for production. |
| `proxy_pass http://127.0.0.1:8501` | Forward all requests to Streamlit on localhost port 8501 |
| `proxy_http_version 1.1` | Use HTTP/1.1 (required for WebSockets and keep-alive) |
| `proxy_set_header Host $host` | Pass the original hostname to Streamlit |
| `proxy_set_header X-Real-IP` | Pass the real client IP (so Streamlit logs real IPs) |
| `proxy_set_header X-Forwarded-For` | Append client IP to proxy chain header |
| `proxy_set_header X-Forwarded-Proto` | Tell Streamlit whether request was HTTP or HTTPS |
| `proxy_set_header Upgrade $http_upgrade` | Enable WebSocket protocol upgrade |
| `proxy_set_header Connection "upgrade"` | Tell upstream to treat this as a WebSocket connection |
| `proxy_read_timeout 86400` | Wait up to 24 hours for a response (prevents timeouts in interactive sessions) |

---

## Step 4 — Test the Nginx Configuration

Always test your Nginx config before reloading — a syntax error can bring down Nginx:

```bash
sudo nginx -t
```

Expected output:

```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

If you see errors, open the config file and fix them before proceeding.

---

## Step 5 — Reload Nginx

```bash
sudo systemctl reload nginx
```

`reload` applies configuration changes without interrupting existing connections. Use `restart` only if `reload` doesn't work.

---

## Step 6 — Test the Full Stack

```bash
# Test Streamlit is running internally
curl http://127.0.0.1:8501

# Test Nginx is proxying to Streamlit
curl http://localhost

# Test from outside (replace with your EC2 public IP)
# curl http://YOUR_EC2_PUBLIC_IP
```

Open a browser and navigate to `http://YOUR_EC2_PUBLIC_IP` — your Streamlit app should load.

---

## Production Configuration — Named Domain

When you have a domain pointing to your EC2 instance, update `server_name`:

```nginx
server {
    listen 80;
    server_name app.yourcompany.com;

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
```

---

## Multiple Apps on Different Paths (Optional)

If you run multiple Streamlit apps on the same server:

```nginx
server {
    listen 80;
    server_name _;

    # App 1 at /app1
    location /app1/ {
        proxy_pass http://127.0.0.1:8501/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }

    # App 2 at /app2
    location /app2/ {
        proxy_pass http://127.0.0.1:8502/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }
}
```

---

## Nginx Log Files

```bash
# Access log — every request Nginx receives
sudo tail -f /var/log/nginx/access.log

# Error log — Nginx errors and upstream errors
sudo tail -f /var/log/nginx/error.log
```

---

## Common Nginx Issues

### 502 Bad Gateway

Nginx can connect to the upstream address but gets no response. Usually means Streamlit is not running.

```bash
# Check if Streamlit is up
systemctl status streamlit-app
curl http://127.0.0.1:8501
```

### 504 Gateway Timeout

Nginx waited too long for a response. May need to increase `proxy_read_timeout`.

### WebSocket Errors in Browser Console

Missing or incorrect WebSocket headers. Ensure both `Upgrade` and `Connection` headers are set in the Nginx config.

### Permission Denied in Nginx Error Log

SELinux may be blocking Nginx from connecting to Streamlit. On RHEL/Amazon Linux:

```bash
sudo setsebool -P httpd_can_network_connect 1
```

---

## Quick Reference

```bash
# Install (Amazon Linux 2023)
dnf install -y nginx

# Start and enable
systemctl start nginx
systemctl enable nginx

# Create config
nano /etc/nginx/conf.d/streamlit.conf

# Test config
nginx -t

# Apply config
systemctl reload nginx

# Status
systemctl status nginx

# Logs
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
```
