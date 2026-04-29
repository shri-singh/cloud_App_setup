#!/usr/bin/env bash
# =============================================================================
# install_python311_amazon_linux2.sh
# Install Python 3.11 side-by-side on Amazon Linux 2 / RHEL 7 / CentOS 7
#
# Usage:
#   sudo bash install_python311_amazon_linux2.sh
#
# What this script does:
#   1. Installs all C build dependencies via yum
#   2. Downloads Python 3.11.9 source from python.org
#   3. Compiles and installs Python 3.11 using make altinstall
#      (altinstall does NOT overwrite system Python 3.7)
#   4. Upgrades pip to a known good version
#
# IMPORTANT: Do not replace system Python. This script uses altinstall.
# =============================================================================

set -euo pipefail

PYTHON_VERSION="3.11.9"
PYTHON_TARBALL="Python-${PYTHON_VERSION}.tgz"
PYTHON_URL="https://www.python.org/ftp/python/${PYTHON_VERSION}/${PYTHON_TARBALL}"
BUILD_DIR="/usr/src"
PIP_VERSION="24.0"

echo "============================================================"
echo " EC2 Streamlit Playbook — Python ${PYTHON_VERSION} Installer"
echo " Target OS: Amazon Linux 2 / RHEL 7 / CentOS 7"
echo "============================================================"

# ---- Step 1: Confirm running as root ----
if [[ "$(id -u)" -ne 0 ]]; then
    echo "ERROR: This script must be run as root."
    echo "Run: sudo bash $0"
    exit 1
fi

echo ""
echo "[1/6] Installing build dependencies via yum..."
yum groupinstall -y "Development Tools"
yum install -y \
    gcc \
    openssl-devel \
    bzip2-devel \
    libffi-devel \
    zlib-devel \
    xz-devel \
    wget \
    make \
    sqlite-devel \
    readline-devel \
    tk-devel \
    gdbm-devel \
    ncurses-devel

echo ""
echo "[2/6] Downloading Python ${PYTHON_VERSION} source..."
cd "${BUILD_DIR}"
if [[ -f "${PYTHON_TARBALL}" ]]; then
    echo "Tarball already exists — skipping download."
else
    wget "${PYTHON_URL}"
fi

echo ""
echo "[3/6] Extracting source..."
if [[ -d "Python-${PYTHON_VERSION}" ]]; then
    echo "Source directory already exists — skipping extraction."
else
    tar xzf "${PYTHON_TARBALL}"
fi

echo ""
echo "[4/6] Configuring build..."
cd "Python-${PYTHON_VERSION}"
./configure \
    --enable-optimizations \
    --with-ensurepip=install

echo ""
echo "[5/6] Compiling Python (this takes 5-15 minutes on small instances)..."
make -j"$(nproc)"

echo ""
echo "[6/6] Installing Python ${PYTHON_VERSION} using altinstall..."
echo "NOTE: Using altinstall — system Python is NOT affected."
make altinstall

echo ""
echo "============================================================"
echo " Verifying installation..."
echo "============================================================"
/usr/local/bin/python3.11 --version
/usr/local/bin/python3.11 -m pip --version

echo ""
echo "Upgrading pip to ${PIP_VERSION}..."
/usr/local/bin/python3.11 -m pip install --upgrade "pip==${PIP_VERSION}"

echo ""
echo "Confirming system Python is unchanged..."
python3 --version

echo ""
echo "============================================================"
echo " SUCCESS: Python 3.11 installed at /usr/local/bin/python3.11"
echo ""
echo " To use Python 3.11:"
echo "   /usr/local/bin/python3.11 --version"
echo "   /usr/local/bin/python3.11 -m venv /opt/apps/YOUR_APP/venv"
echo "============================================================"
