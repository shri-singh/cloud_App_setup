# 03 — Install Python 3.11 Side-by-Side

This guide explains how to install Python 3.11 on an EC2 instance that already has a system Python (typically 3.7 on Amazon Linux 2 or RHEL), without replacing or interfering with the existing version.

---

## Why Not Replace System Python?

Corporate AWS Linux golden images (the base OS images your company provides) typically have Python 3.7 installed as part of the operating system. This system Python is used by:

- `yum` / `dnf` (the package manager itself)
- OS-level monitoring agents (CloudWatch agent, SSM agent)
- Corporate compliance and security tooling
- AWS CLI (in some configurations)

**If you overwrite or redirect system Python 3.7 to Python 3.11, these tools can break silently or loudly — and you may be unable to install or manage system packages.**

This is not a hypothetical risk — it has caused production outages.

---

## The Correct Approach: Side-by-Side Installation

Python 3.11 is installed to `/usr/local/bin/python3.11` without touching `/usr/bin/python3` or `/usr/bin/python`.

You then **always reference Python 3.11 by its full path** when creating virtual environments:

```bash
/usr/local/bin/python3.11 -m venv venv
```

Inside the virtual environment, `python` and `pip` automatically point to Python 3.11. You never need to touch the system Python.

---

## Key: `make altinstall` vs `make install`

When building Python from source:

| Command | What It Does |
|---|---|
| `make install` | Installs Python and **overwrites** the default `python3` symlink — DANGEROUS |
| `make altinstall` | Installs Python **without overwriting** any existing Python symlinks — SAFE |

**Always use `make altinstall`.**

`altinstall` creates `/usr/local/bin/python3.11` but does NOT touch `/usr/bin/python3`.

---

## Where Python 3.11 Gets Installed

After `make altinstall`:

| Path | What It Is |
|---|---|
| `/usr/local/bin/python3.11` | Python 3.11 interpreter |
| `/usr/local/bin/pip3.11` | pip for Python 3.11 |
| `/usr/local/lib/python3.11/` | Python 3.11 standard library |

The system Python at `/usr/bin/python3` remains completely unchanged.

---

## Amazon Linux 2 / RHEL / CentOS — Build from Source

This is the most reliable method for older Amazon Linux versions. You compile Python 3.11 yourself.

### Step 1 — Become Root

```bash
sudo su -
whoami   # should print: root
```

### Step 2 — Install Build Dependencies

These are the C libraries and tools needed to compile Python:

```bash
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
```

### Step 3 — Download Python 3.11 Source

```bash
cd /usr/src
wget https://www.python.org/ftp/python/3.11.9/Python-3.11.9.tgz
```

### Step 4 — Extract the Source

```bash
tar xzf Python-3.11.9.tgz
cd Python-3.11.9
```

### Step 5 — Configure the Build

```bash
./configure --enable-optimizations --with-ensurepip=install
```

- `--enable-optimizations` — builds a faster Python using profile-guided optimization (takes a bit longer to compile)
- `--with-ensurepip=install` — includes `pip` in the build

### Step 6 — Compile Python

```bash
make -j$(nproc)
```

`-j$(nproc)` uses all available CPU cores for faster compilation. This step typically takes 5–15 minutes depending on EC2 instance size.

### Step 7 — Install (Alt Install Only)

```bash
make altinstall
```

> ⚠️ **WARNING:** Do NOT run `make install`. Only run `make altinstall`.

### Step 8 — Verify Installation

```bash
/usr/local/bin/python3.11 --version
# Expected: Python 3.11.9

/usr/local/bin/python3.11 -m pip --version
# Expected: pip 24.x from /usr/local/lib/python3.11/...
```

### Step 9 — Upgrade pip

```bash
/usr/local/bin/python3.11 -m pip install --upgrade pip==24.0
```

### Step 10 — Confirm System Python is Unchanged

```bash
python3 --version
# Should still show Python 3.7.x (or whatever was there before)

which python3
# Should show /usr/bin/python3 — not changed
```

---

## Amazon Linux 2023 — Install via Package Manager

Amazon Linux 2023 ships Python 3.11 in its package repositories. No compilation needed.

```bash
sudo dnf install -y python3.11 python3.11-pip
```

Verify:

```bash
python3.11 --version
# Python 3.11.x

python3.11 -m pip --version

python3.11 -m pip install --upgrade pip==24.0
```

> Note: On AL2023, `python3.11` is available directly in PATH without needing the full path. Still use explicit versioned paths in scripts for clarity.

---

## Ubuntu 20.04 / 22.04

```bash
sudo apt update
sudo apt install -y software-properties-common

# Ubuntu 20.04 may need deadsnakes PPA for 3.11:
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt update

sudo apt install -y python3.11 python3.11-venv python3.11-dev python3.11-distutils
```

Verify:

```bash
python3.11 --version
```

Install pip for Python 3.11:

```bash
curl -sS https://bootstrap.pypa.io/get-pip.py | sudo python3.11
python3.11 -m pip --version
```

---

## What NOT to Do

```bash
# NEVER DO THIS — overwrites the system python3 symlink
ln -sf /usr/local/bin/python3.11 /usr/bin/python3

# NEVER DO THIS — same problem
ln -sf /usr/local/bin/python3.11 /usr/bin/python

# NEVER DO THIS — can overwrite default Python
make install    # <-- use make altinstall instead

# NEVER DO THIS — overwrites python3 in PATH
alias python3=/usr/local/bin/python3.11  # (in .bashrc for system-wide use)
```

---

## Verification Checklist

After installing Python 3.11, confirm all of the following:

```bash
# 1. Python 3.11 is accessible
/usr/local/bin/python3.11 --version      # Shows 3.11.9

# 2. pip works for Python 3.11
/usr/local/bin/python3.11 -m pip --version

# 3. System Python is unchanged
python3 --version                         # Shows 3.7.x or original version
which python3                             # Shows /usr/bin/python3

# 4. yum/dnf still works (confirms system Python not broken)
yum list installed | head -5              # Should work without errors
```

---

## Summary

| Step | Command |
|---|---|
| Install build deps | `yum install -y gcc openssl-devel ...` |
| Download source | `wget https://www.python.org/ftp/python/3.11.9/Python-3.11.9.tgz` |
| Build | `./configure ... && make -j$(nproc)` |
| Install safely | `make altinstall` |
| Verify | `/usr/local/bin/python3.11 --version` |
| Upgrade pip | `/usr/local/bin/python3.11 -m pip install --upgrade pip==24.0` |
