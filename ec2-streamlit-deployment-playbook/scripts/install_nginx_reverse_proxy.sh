#!/usr/bin/env bash
# =============================================================================
# install_nginx_reverse_proxy.sh
# Install Nginx and configure it as a reverse proxy for Streamlit
#
# Usage:
#   sudo bash install_nginx_reverse_proxy.sh
#
# Variables to customize:
#   STREAMLIT_PORT — internal port Streamlit listens on
#   NGINX_CONF     — output path for the Nginx config file
# =============================================================================

set -euo pipefail

# ---- Configuration ----
STREAMLIT_PORT="8501"
NGINX_CONF="/etc/nginx/conf.d/streamlit.conf"
# -----------------------

echo "============================================================"
echo " EC2 Streamlit Playbook — Nginx Reverse Proxy Setup"
echo " Streamlit port: ${STREAMLIT_PORT}"
echo " Nginx config: ${NGINX_CONF}"
echo "============================================================"

# ---- Confirm running as root ----
if [[ "$(id -u)" -ne 0 ]]; then
    echo "ERROR: This script must be run as root."
    echo "Run: sudo bash $0"
    exit 1
fi

# ---- Detect OS and install Nginx ----
echo ""
echo "[1/5] Detecting OS and installing Nginx..."

if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_VERSION="${VERSION_ID:-unknown}"
    echo "Detected OS: ${OS_ID} ${OS_VERSION}"
else
    OS_ID="unknown"
fi

case "${OS_ID}" in
    amzn)
        if [[ "${OS_VERSION}" == "2" ]]; then
            echo "Installing Nginx for Amazon Linux 2..."
            amazon-linux-extras enable nginx1
            yum clean metadata
            yum install -y nginx
        else
            echo "Installing Nginx for Amazon Linux 2023..."
            dnf install -y nginx
        fi
        ;;
    rhel|centos|fedora)
        echo "Installing Nginx for RHEL/CentOS/Fedora..."
        dnf install -y nginx 2>/dev/null || yum install -y nginx
        ;;
    ubuntu|debian)
        echo "Installing Nginx for Ubuntu/Debian..."
        apt-get update -y
        apt-get install -y nginx
        ;;
    *)
        echo "WARNING: Unknown OS '${OS_ID}'. Attempting dnf install..."
        dnf install -y nginx 2>/dev/null || {
            echo "dnf failed. Trying yum..."
            yum install -y nginx 2>/dev/null || {
                echo "ERROR: Could not install Nginx. Install it manually and re-run."
                exit 1
            }
        }
        ;;
esac

echo "Nginx installed successfully."

echo ""
echo "[2/5] Creating Nginx reverse proxy config..."

cat > "${NGINX_CONF}" << EOF
server {
    listen 80;
    server_name _;

    # Reverse proxy all traffic to Streamlit
    location / {
        proxy_pass http://127.0.0.1:${STREAMLIT_PORT};
        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # Required for Streamlit WebSocket support
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        # Long timeout for interactive Streamlit sessions
        proxy_read_timeout 86400;
        proxy_connect_timeout 60;
        proxy_send_timeout 86400;
    }
}
EOF

echo "Nginx config created at: ${NGINX_CONF}"

echo ""
echo "[3/5] Testing Nginx configuration syntax..."
nginx -t

echo ""
echo "[4/5] Starting and enabling Nginx..."
systemctl start nginx
systemctl enable nginx

echo ""
echo "[5/5] Reloading Nginx to apply config..."
systemctl reload nginx

echo ""
echo "============================================================"
echo " Verification"
echo "============================================================"
systemctl status nginx --no-pager | head -15
echo ""
ss -tulpn | grep :80 || echo "WARNING: Nothing listening on port 80"
echo ""
echo "Testing Nginx on localhost..."
curl -s -o /dev/null -w "HTTP response: %{http_code}\n" http://localhost || \
    echo "NOTE: Streamlit must also be running for a successful response."

echo ""
echo "============================================================"
echo " SUCCESS: Nginx installed and configured."
echo ""
echo " Next steps:"
echo "   1. Make sure Streamlit service is running:"
echo "      systemctl status streamlit-app"
echo "   2. Open port 80 in your EC2 security group"
echo "   3. Test from browser: http://YOUR_EC2_PUBLIC_IP"
echo ""
echo " Nginx logs:"
echo "   tail -f /var/log/nginx/access.log"
echo "   tail -f /var/log/nginx/error.log"
echo "============================================================"
