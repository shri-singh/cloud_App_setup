#!/usr/bin/env bash
# =============================================================================
# check_app_health.sh
# Comprehensive health check for the Streamlit + Nginx deployment
#
# Usage:
#   bash check_app_health.sh
#
# Checks:
#   - System info
#   - Python 3.11 availability
#   - pip version
#   - Virtual environment
#   - Streamlit service status
#   - Nginx service status
#   - Listening ports
#   - HTTP health checks
#   - Disk and memory
# =============================================================================

set -uo pipefail

# ---- Configuration ----
APP_DIR="/opt/apps/YOUR_REPO_NAME"
SERVICE_NAME="streamlit-app"
STREAMLIT_PORT="8501"
# -----------------------

PASS="[PASS]"
FAIL="[FAIL]"
WARN="[WARN]"

echo "============================================================"
echo " EC2 Streamlit Playbook — App Health Check"
echo " Timestamp: $(date)"
echo "============================================================"

# ---- System Info ----
echo ""
echo "--- System Information ---"
echo "Hostname:  $(hostname)"
echo "User:      $(whoami)"
echo "OS:        $(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || echo 'Unknown')"
echo "Uptime:    $(uptime -p 2>/dev/null || uptime)"

# ---- Python 3.11 ----
echo ""
echo "--- Python 3.11 ---"

PYTHON311_PATHS=(
    "/usr/local/bin/python3.11"
    "/usr/bin/python3.11"
    "$(command -v python3.11 2>/dev/null || echo '')"
)

PYTHON311_FOUND=""
for p in "${PYTHON311_PATHS[@]}"; do
    if [[ -n "${p}" && -f "${p}" ]]; then
        PYTHON311_FOUND="${p}"
        break
    fi
done

if [[ -n "${PYTHON311_FOUND}" ]]; then
    echo "${PASS} Python 3.11 found: ${PYTHON311_FOUND}"
    echo "       Version: $("${PYTHON311_FOUND}" --version 2>&1)"
else
    echo "${FAIL} Python 3.11 NOT found"
    echo "       Run: scripts/install_python311_amazon_linux2.sh"
fi

echo "       System Python: $(python3 --version 2>/dev/null || echo 'not found')"

# ---- Virtual Environment ----
echo ""
echo "--- Virtual Environment ---"

if [[ -d "${APP_DIR}/venv" ]]; then
    VENV_PYTHON="${APP_DIR}/venv/bin/python"
    if [[ -f "${VENV_PYTHON}" ]]; then
        VENV_VERSION=$("${VENV_PYTHON}" --version 2>&1)
        echo "${PASS} venv found at ${APP_DIR}/venv"
        echo "       venv Python: ${VENV_VERSION}"
        if echo "${VENV_VERSION}" | grep -q "3.11"; then
            echo "${PASS} venv is using Python 3.11"
        else
            echo "${FAIL} venv is NOT using Python 3.11"
            echo "       Fix: rm -rf ${APP_DIR}/venv && ${PYTHON311_FOUND:-/usr/local/bin/python3.11} -m venv ${APP_DIR}/venv"
        fi
    else
        echo "${FAIL} venv directory exists but Python binary not found inside"
    fi
else
    echo "${FAIL} venv not found at ${APP_DIR}/venv"
    echo "       Run: scripts/setup_streamlit_venv.sh"
fi

# ---- pip Version ----
echo ""
echo "--- pip ---"
if [[ -f "${APP_DIR}/venv/bin/pip" ]]; then
    PIP_VER=$("${APP_DIR}/venv/bin/pip" --version 2>&1)
    echo "${PASS} pip found: ${PIP_VER}"
else
    echo "${FAIL} pip not found in venv"
fi

# ---- Streamlit Version ----
echo ""
echo "--- Streamlit ---"
if [[ -f "${APP_DIR}/venv/bin/streamlit" ]]; then
    ST_VER=$("${APP_DIR}/venv/bin/streamlit" --version 2>&1)
    echo "${PASS} Streamlit installed: ${ST_VER}"
else
    echo "${FAIL} Streamlit NOT found in venv"
    echo "       Run: source ${APP_DIR}/venv/bin/activate && pip install streamlit"
fi

# ---- .env File ----
echo ""
echo "--- .env File ---"
if [[ -f "${APP_DIR}/.env" ]]; then
    ENV_PERMS=$(stat -c "%a" "${APP_DIR}/.env" 2>/dev/null || echo "unknown")
    echo "${PASS} .env file exists"
    echo "       Permissions: ${ENV_PERMS} (should be 600)"
    if [[ "${ENV_PERMS}" == "600" ]]; then
        echo "${PASS} .env permissions are correct (600)"
    else
        echo "${WARN} .env permissions should be 600 — run: chmod 600 ${APP_DIR}/.env"
    fi
else
    echo "${WARN} .env file not found at ${APP_DIR}/.env"
    echo "       Create it with: nano ${APP_DIR}/.env"
fi

# ---- Streamlit Service ----
echo ""
echo "--- Streamlit systemd Service ---"
if systemctl is-active "${SERVICE_NAME}" --quiet 2>/dev/null; then
    echo "${PASS} Service '${SERVICE_NAME}' is ACTIVE"
    systemctl status "${SERVICE_NAME}" --no-pager 2>/dev/null | head -8 | sed 's/^/       /'
else
    echo "${FAIL} Service '${SERVICE_NAME}' is NOT running"
    echo "       Check: journalctl -u ${SERVICE_NAME} -n 50"
fi

if systemctl is-enabled "${SERVICE_NAME}" --quiet 2>/dev/null; then
    echo "${PASS} Service '${SERVICE_NAME}' is ENABLED (auto-start on boot)"
else
    echo "${WARN} Service '${SERVICE_NAME}' is NOT enabled for auto-start"
    echo "       Fix: systemctl enable ${SERVICE_NAME}"
fi

# ---- Nginx Service ----
echo ""
echo "--- Nginx Service ---"
if systemctl is-active nginx --quiet 2>/dev/null; then
    echo "${PASS} Nginx is ACTIVE"
else
    echo "${FAIL} Nginx is NOT running"
    echo "       Check: systemctl status nginx"
fi

# ---- Listening Ports ----
echo ""
echo "--- Listening Ports ---"
echo "All listening TCP/UDP ports:"
ss -tulpn 2>/dev/null | grep LISTEN | sed 's/^/  /'

echo ""
if ss -tulpn 2>/dev/null | grep -q ":${STREAMLIT_PORT}"; then
    echo "${PASS} Streamlit IS listening on port ${STREAMLIT_PORT}"
else
    echo "${FAIL} Nothing listening on port ${STREAMLIT_PORT}"
fi

if ss -tulpn 2>/dev/null | grep -q ":80 "; then
    echo "${PASS} Nginx IS listening on port 80"
else
    echo "${FAIL} Nothing listening on port 80"
fi

# ---- HTTP Health Checks ----
echo ""
echo "--- HTTP Health Checks ---"

ST_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${STREAMLIT_PORT}" 2>/dev/null || echo "failed")
if [[ "${ST_CODE}" =~ ^2|^3 ]]; then
    echo "${PASS} Streamlit internal (127.0.0.1:${STREAMLIT_PORT}): HTTP ${ST_CODE}"
else
    echo "${FAIL} Streamlit internal unreachable — HTTP ${ST_CODE}"
fi

NGINX_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost" 2>/dev/null || echo "failed")
if [[ "${NGINX_CODE}" =~ ^2|^3 ]]; then
    echo "${PASS} Nginx local (http://localhost): HTTP ${NGINX_CODE}"
else
    echo "${FAIL} Nginx local unreachable — HTTP ${NGINX_CODE}"
fi

# ---- Disk and Memory ----
echo ""
echo "--- System Resources ---"
echo "Disk usage:"
df -h / 2>/dev/null | sed 's/^/  /'
echo ""
echo "Memory:"
free -h 2>/dev/null | sed 's/^/  /'

echo ""
echo "============================================================"
echo " Health check complete — $(date)"
echo "============================================================"
