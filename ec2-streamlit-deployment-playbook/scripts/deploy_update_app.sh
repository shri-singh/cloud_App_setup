#!/usr/bin/env bash
# =============================================================================
# deploy_update_app.sh
# Pull latest code from GitHub and restart the Streamlit service
#
# Usage:
#   sudo bash deploy_update_app.sh
#
# Run this every time you push new code to GitHub and want to update the live app.
#
# Variables to customize:
#   APP_DIR      — path to the app directory
#   GIT_BRANCH   — branch to pull from
#   SERVICE_NAME — systemd service name
# =============================================================================

set -euo pipefail

# ---- Configuration ----
APP_DIR="/opt/apps/YOUR_REPO_NAME"
GIT_BRANCH="main"
SERVICE_NAME="streamlit-app"
# -----------------------

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "============================================================"
echo " EC2 Streamlit Playbook — App Update Deployment"
echo " Timestamp: ${TIMESTAMP}"
echo " App directory: ${APP_DIR}"
echo " Branch: ${GIT_BRANCH}"
echo " Service: ${SERVICE_NAME}"
echo "============================================================"

# ---- Confirm running as root ----
if [[ "$(id -u)" -ne 0 ]]; then
    echo "ERROR: This script must be run as root."
    echo "Run: sudo bash $0"
    exit 1
fi

# ---- Validate app directory ----
if [[ ! -d "${APP_DIR}" ]]; then
    echo "ERROR: App directory not found: ${APP_DIR}"
    exit 1
fi

echo ""
echo "[1/5] Navigating to app directory..."
cd "${APP_DIR}"

echo ""
echo "[2/5] Pulling latest code from GitHub (branch: ${GIT_BRANCH})..."
git fetch origin
git pull origin "${GIT_BRANCH}"

echo ""
echo "Current git status:"
git log --oneline -5
git status

echo ""
echo "[3/5] Activating virtual environment and installing requirements..."
# shellcheck disable=SC1091
source venv/bin/activate

echo "Active Python: $(which python)"
echo "Python version: $(python --version)"

pip install --upgrade pip==24.0
pip install -r requirements.txt

deactivate

echo ""
echo "[4/5] Restarting Streamlit service..."
systemctl daemon-reload
systemctl restart "${SERVICE_NAME}"

echo ""
echo "[5/5] Verifying service is healthy..."
# Give the service a moment to start
sleep 3

if systemctl is-active "${SERVICE_NAME}" --quiet; then
    echo "Service '${SERVICE_NAME}' is ACTIVE and running."
else
    echo "ERROR: Service '${SERVICE_NAME}' failed to start."
    echo ""
    echo "Last 20 log lines:"
    journalctl -u "${SERVICE_NAME}" -n 20 --no-pager
    exit 1
fi

echo ""
echo "Testing Streamlit health check..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8501 || echo "failed")
echo "Streamlit HTTP response: ${HTTP_CODE}"

echo ""
echo "============================================================"
echo " Deployment Summary"
echo "============================================================"
systemctl status "${SERVICE_NAME}" --no-pager | head -10

echo ""
echo "============================================================"
echo " SUCCESS: Deployment complete at ${TIMESTAMP}"
echo ""
echo " View live logs:"
echo "   journalctl -u ${SERVICE_NAME} -f"
echo "============================================================"
