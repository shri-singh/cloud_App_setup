#!/usr/bin/env bash
# =============================================================================
# install_python311_ubuntu.sh
# Install Python 3.11 on Ubuntu 20.04 / 22.04
#
# Usage:
#   sudo bash install_python311_ubuntu.sh
#
# Ubuntu 22.04 ships Python 3.11 in its repositories.
# Ubuntu 20.04 requires the deadsnakes PPA.
# =============================================================================

set -euo pipefail

PIP_VERSION="24.0"

echo "============================================================"
echo " EC2 Streamlit Playbook — Python 3.11 Installer"
echo " Target OS: Ubuntu 20.04 / 22.04"
echo "============================================================"

# ---- Confirm running as root ----
if [[ "$(id -u)" -ne 0 ]]; then
    echo "ERROR: This script must be run as root."
    echo "Run: sudo bash $0"
    exit 1
fi

echo ""
echo "[1/4] Updating apt package cache..."
apt-get update -y

echo ""
echo "[2/4] Installing prerequisites..."
apt-get install -y \
    software-properties-common \
    curl \
    git \
    wget

# Detect Ubuntu version and add deadsnakes PPA if needed (for 20.04)
UBUNTU_VERSION=$(lsb_release -rs 2>/dev/null || echo "unknown")
echo "Detected Ubuntu version: ${UBUNTU_VERSION}"

if [[ "${UBUNTU_VERSION}" == "20.04" ]]; then
    echo "Ubuntu 20.04 detected — adding deadsnakes PPA for Python 3.11..."
    add-apt-repository -y ppa:deadsnakes/ppa
    apt-get update -y
fi

echo ""
echo "[3/4] Installing Python 3.11..."
apt-get install -y \
    python3.11 \
    python3.11-venv \
    python3.11-dev \
    python3.11-distutils 2>/dev/null || true

echo ""
echo "[4/4] Installing pip for Python 3.11..."
# Some Ubuntu versions don't include pip in python3.11 package
if ! python3.11 -m pip --version &>/dev/null; then
    echo "pip not found via package manager — installing via get-pip.py..."
    curl -sS https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
    python3.11 /tmp/get-pip.py
    rm -f /tmp/get-pip.py
fi

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
