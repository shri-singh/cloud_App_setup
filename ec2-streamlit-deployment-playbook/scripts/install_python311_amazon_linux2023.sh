#!/usr/bin/env bash
# =============================================================================
# install_python311_amazon_linux2023.sh
# Install Python 3.11 on Amazon Linux 2023 using dnf package manager
#
# Usage:
#   sudo bash install_python311_amazon_linux2023.sh
#
# Amazon Linux 2023 ships Python 3.11 in its package repositories.
# No compilation from source is needed.
# =============================================================================

set -euo pipefail

PIP_VERSION="24.0"

echo "============================================================"
echo " EC2 Streamlit Playbook — Python 3.11 Installer"
echo " Target OS: Amazon Linux 2023"
echo "============================================================"

# ---- Confirm running as root ----
if [[ "$(id -u)" -ne 0 ]]; then
    echo "ERROR: This script must be run as root."
    echo "Run: sudo bash $0"
    exit 1
fi

# ---- Confirm this is Amazon Linux 2023 ----
if ! grep -q "Amazon Linux" /etc/os-release 2>/dev/null; then
    echo "WARNING: This script is intended for Amazon Linux 2023."
    echo "Detected OS:"
    cat /etc/os-release | head -5
    echo ""
    read -r -p "Continue anyway? (y/N) " CONFIRM
    if [[ "${CONFIRM}" != "y" && "${CONFIRM}" != "Y" ]]; then
        echo "Aborted."
        exit 1
    fi
fi

echo ""
echo "[1/3] Updating package cache..."
dnf update -y

echo ""
echo "[2/3] Installing Python 3.11 and pip via dnf..."
dnf install -y python3.11 python3.11-pip

echo ""
echo "[3/3] Installing git and other useful packages..."
dnf install -y git wget

echo ""
echo "============================================================"
echo " Verifying installation..."
echo "============================================================"
python3.11 --version
python3.11 -m pip --version

echo ""
echo "Upgrading pip to ${PIP_VERSION}..."
python3.11 -m pip install --upgrade "pip==${PIP_VERSION}"

echo ""
echo "Confirming system Python is unchanged..."
python3 --version

echo ""
echo "============================================================"
echo " SUCCESS: Python 3.11 installed."
echo ""
echo " To use Python 3.11:"
echo "   python3.11 --version"
echo "   python3.11 -m venv /opt/apps/YOUR_APP/venv"
echo "============================================================"
