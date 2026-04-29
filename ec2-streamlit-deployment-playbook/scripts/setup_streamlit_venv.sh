#!/usr/bin/env bash
# =============================================================================
# setup_streamlit_venv.sh
# Create a Python 3.11 virtual environment and install app requirements
#
# Usage:
#   sudo bash setup_streamlit_venv.sh
#
# Variables to customize:
#   APP_DIR   — path to your cloned repository
#   PYTHON_BIN — full path to Python 3.11 binary
# =============================================================================

set -euo pipefail

# ---- Configuration — edit these variables ----
APP_DIR="/opt/apps/YOUR_REPO_NAME"
PYTHON_BIN="/usr/local/bin/python3.11"
PIP_VERSION="24.0"
# ----------------------------------------------

echo "============================================================"
echo " EC2 Streamlit Playbook — Virtual Environment Setup"
echo " App directory: ${APP_DIR}"
echo " Python binary: ${PYTHON_BIN}"
echo "============================================================"

# ---- Validate Python 3.11 is available ----
if [[ ! -f "${PYTHON_BIN}" ]]; then
    echo ""
    echo "ERROR: Python binary not found at: ${PYTHON_BIN}"
    echo ""
    echo "Options:"
    echo "  Amazon Linux 2: Run scripts/install_python311_amazon_linux2.sh first"
    echo "  Amazon Linux 2023: PYTHON_BIN=/usr/bin/python3.11"
    echo "  Ubuntu: PYTHON_BIN=/usr/bin/python3.11"
    exit 1
fi

echo ""
echo "Python binary found:"
"${PYTHON_BIN}" --version

# ---- Validate app directory exists ----
if [[ ! -d "${APP_DIR}" ]]; then
    echo ""
    echo "ERROR: App directory not found: ${APP_DIR}"
    echo "Make sure you have cloned the repository first."
    echo "Run: git clone YOUR_REPO_URL /opt/apps/YOUR_REPO_NAME"
    exit 1
fi

echo ""
echo "[1/5] Navigating to app directory..."
cd "${APP_DIR}"
echo "Working directory: $(pwd)"

echo ""
echo "[2/5] Removing any existing virtual environment..."
if [[ -d "venv" ]]; then
    rm -rf venv
    echo "Old venv removed."
else
    echo "No existing venv found — fresh install."
fi

echo ""
echo "[3/5] Creating new virtual environment with Python 3.11..."
"${PYTHON_BIN}" -m venv venv

echo ""
echo "[4/5] Activating venv and upgrading pip..."
# shellcheck disable=SC1091
source venv/bin/activate

echo "Active Python: $(which python)"
echo "Python version: $(python --version)"
echo "Active pip: $(which pip)"

pip install --upgrade "pip==${PIP_VERSION}"

echo ""
echo "[5/5] Installing requirements..."
if [[ -f "requirements.txt" ]]; then
    pip install -r requirements.txt
    echo "requirements.txt installed."
else
    echo "WARNING: No requirements.txt found — installing streamlit only."
fi

# Always ensure streamlit is installed
pip install streamlit

echo ""
echo "============================================================"
echo " Verification"
echo "============================================================"
echo "Python version: $(python --version)"
echo "Pip version:    $(pip --version)"
echo "Streamlit:      $(streamlit --version)"
echo ""
pip list | grep -E "streamlit|python-dotenv|pandas|numpy" || true

deactivate

echo ""
echo "============================================================"
echo " SUCCESS: Virtual environment created."
echo ""
echo " To activate:"
echo "   cd ${APP_DIR}"
echo "   source venv/bin/activate"
echo ""
echo " To run Streamlit:"
echo "   streamlit run app.py --server.port 8501 --server.address 127.0.0.1"
echo "============================================================"
