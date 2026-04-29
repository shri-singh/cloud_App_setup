#!/usr/bin/env bash
# =============================================================================
# create_streamlit_systemd_service.sh
# Create and enable a systemd service for Streamlit
#
# Usage:
#   sudo bash create_streamlit_systemd_service.sh
#
# Variables to customize:
#   APP_NAME — systemd service name
#   APP_DIR  — full path to the app directory
#   APP_FILE — the Streamlit entry point Python file
#   APP_PORT — port for Streamlit to listen on
# =============================================================================

set -euo pipefail

# ---- Configuration — edit these variables ----
APP_NAME="streamlit-app"
APP_DIR="/opt/apps/YOUR_REPO_NAME"
APP_FILE="app.py"
APP_PORT="8501"
SERVICE_USER="root"    # Change to a dedicated user for production
# ----------------------------------------------

SERVICE_FILE="/etc/systemd/system/${APP_NAME}.service"
VENV_BIN="${APP_DIR}/venv/bin"

echo "============================================================"
echo " EC2 Streamlit Playbook — systemd Service Setup"
echo " Service name: ${APP_NAME}"
echo " App directory: ${APP_DIR}"
echo " App file: ${APP_FILE}"
echo " Port: ${APP_PORT}"
echo " User: ${SERVICE_USER}"
echo "============================================================"

# ---- Confirm running as root ----
if [[ "$(id -u)" -ne 0 ]]; then
    echo "ERROR: This script must be run as root."
    echo "Run: sudo bash $0"
    exit 1
fi

# ---- Validate paths ----
if [[ ! -d "${APP_DIR}" ]]; then
    echo "ERROR: App directory not found: ${APP_DIR}"
    exit 1
fi

if [[ ! -f "${APP_DIR}/${APP_FILE}" ]]; then
    echo "ERROR: App file not found: ${APP_DIR}/${APP_FILE}"
    exit 1
fi

if [[ ! -f "${VENV_BIN}/streamlit" ]]; then
    echo "ERROR: Streamlit not found in venv: ${VENV_BIN}/streamlit"
    echo "Run scripts/setup_streamlit_venv.sh first."
    exit 1
fi

if [[ ! -f "${APP_DIR}/.env" ]]; then
    echo "WARNING: .env file not found at ${APP_DIR}/.env"
    echo "The service file will reference it, but you must create it before starting the service."
fi

echo ""
echo "[1/4] Creating systemd service file at ${SERVICE_FILE}..."

cat > "${SERVICE_FILE}" << EOF
[Unit]
Description=Streamlit App - ${APP_NAME}
After=network.target

[Service]
User=${SERVICE_USER}
WorkingDirectory=${APP_DIR}
Environment="PATH=${VENV_BIN}:/usr/local/bin:/usr/bin:/bin"
EnvironmentFile=${APP_DIR}/.env
ExecStart=${VENV_BIN}/streamlit run ${APP_FILE} \\
    --server.port ${APP_PORT} \\
    --server.address 127.0.0.1 \\
    --server.headless true
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

echo "Service file created at: ${SERVICE_FILE}"
cat "${SERVICE_FILE}"

echo ""
echo "[2/4] Reloading systemd daemon..."
systemctl daemon-reload

echo ""
echo "[3/4] Enabling service (auto-start on boot)..."
systemctl enable "${APP_NAME}"

echo ""
echo "[4/4] Starting service..."
systemctl start "${APP_NAME}"

echo ""
echo "============================================================"
echo " Service Status"
echo "============================================================"
systemctl status "${APP_NAME}" --no-pager

echo ""
echo "============================================================"
echo " SUCCESS: systemd service '${APP_NAME}' created and started."
echo ""
echo " Useful commands:"
echo "   systemctl status ${APP_NAME}"
echo "   systemctl restart ${APP_NAME}"
echo "   systemctl stop ${APP_NAME}"
echo "   journalctl -u ${APP_NAME} -f"
echo "   journalctl -u ${APP_NAME} -n 100"
echo "============================================================"
