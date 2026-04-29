# 04 — Python Virtual Environment Best Practices

This guide explains Python virtual environments, why they matter, and how to create them correctly using Python 3.11 on EC2.

---

## What Is a Virtual Environment?

A Python virtual environment (venv) is an **isolated folder** containing its own copy of:

- The Python interpreter (symlinked from the version you choose)
- pip
- All installed packages

When you activate a virtual environment, all `python` and `pip` commands inside it point only to that environment. Changes inside the venv do NOT affect system Python or other venvs.

### Why Use a Virtual Environment?

| Without venv | With venv |
|---|---|
| Packages install globally — conflicts between apps | Each app has its own isolated packages |
| Updating one app can break another | Updating one app doesn't affect others |
| Hard to replicate exact dependencies | `pip freeze > requirements.txt` captures exact versions |
| System Python can get cluttered | System Python stays clean |

For EC2 deployment, always use one virtual environment per application.

---

## Critical Concept: venv Does NOT Install Python

A virtual environment does NOT install a new Python. It **uses the Python interpreter you tell it to use** when you create the venv.

This means:

```bash
# This creates a venv using SYSTEM Python 3.7 — WRONG for our use case
python3 -m venv venv

# This creates a venv using Python 3.11 — CORRECT
/usr/local/bin/python3.11 -m venv venv
```

If you accidentally create the venv with Python 3.7 and your app requires Python 3.11 features, you will get errors. Always specify the full path to Python 3.11.

---

## Why `python3 -m venv venv` May Use Python 3.7

On Amazon Linux 2 and similar systems, `python3` in PATH points to the system Python 3.7:

```bash
which python3
# /usr/bin/python3

python3 --version
# Python 3.7.16
```

So `python3 -m venv venv` creates a Python 3.7 venv. This is not what we want.

**Always use the explicit full path:**

```bash
/usr/local/bin/python3.11 -m venv venv
```

---

## Creating the Virtual Environment

### Step 1 — Navigate to Your App Directory

```bash
cd /opt/apps/YOUR_REPO_NAME
```

### Step 2 — Remove Any Old venv (Fresh Start)

```bash
rm -rf venv
```

### Step 3 — Create venv with Python 3.11

```bash
/usr/local/bin/python3.11 -m venv venv
```

This creates a `venv/` folder in the current directory containing:

```
venv/
├── bin/
│   ├── python          ← symlink to Python 3.11
│   ├── python3         ← symlink to Python 3.11
│   ├── python3.11      ← symlink to Python 3.11
│   ├── pip
│   ├── pip3
│   └── activate        ← the activation script
├── lib/
│   └── python3.11/
│       └── site-packages/    ← your installed packages go here
└── pyvenv.cfg          ← records which Python was used
```

### Step 4 — Activate the Virtual Environment

```bash
source venv/bin/activate
```

After activation, your prompt changes to show the venv name:

```
(venv) root@ip-10-0-1-100:/opt/apps/my-app#
```

This prefix `(venv)` tells you the virtual environment is active.

---

## Verifying the venv is Using Python 3.11

After activation, confirm everything is pointing to Python 3.11:

```bash
which python
# /opt/apps/YOUR_REPO_NAME/venv/bin/python

python --version
# Python 3.11.9

which pip
# /opt/apps/YOUR_REPO_NAME/venv/bin/pip

pip --version
# pip 24.0 from /opt/apps/YOUR_REPO_NAME/venv/lib/python3.11/site-packages/pip (python 3.11)
```

Both `python` and `pip` should point to locations inside your `venv/` folder, and both should reference Python 3.11.

If `python --version` shows Python 3.7, your venv was created with the wrong Python. Delete it and recreate.

---

## Upgrading pip Inside the venv

Always upgrade pip inside the venv before installing packages:

```bash
pip install --upgrade pip==24.0
```

Pinning to `==24.0` ensures reproducible behavior. You can also use `--upgrade` without a pin to get the latest.

---

## Installing Requirements

```bash
pip install -r requirements.txt
```

Install all packages listed in `requirements.txt`. This command reads the file and installs each package at the specified version.

---

## Deactivating the Virtual Environment

When you are done working inside the venv:

```bash
deactivate
```

Your prompt returns to normal. `python` and `pip` now point back to system versions.

---

## Useful pip Commands Inside the venv

```bash
# Install a specific package
pip install streamlit

# Install a package at a specific version
pip install streamlit==1.35.0

# List all installed packages
pip list

# Show details about a specific package (version, location, dependencies)
pip show streamlit

# Generate a requirements file from currently installed packages
pip freeze > requirements.txt

# Install all packages from requirements.txt
pip install -r requirements.txt

# Uninstall a package
pip uninstall package_name

# Check for outdated packages
pip list --outdated
```

---

## Virtual Environment and systemd

When running the app via systemd (as a persistent service), you do **not** activate the venv. Instead, you reference the venv's Python and Streamlit directly by full path:

```ini
ExecStart=/opt/apps/YOUR_REPO_NAME/venv/bin/streamlit run app.py \
    --server.port 8501 \
    --server.address 127.0.0.1 \
    --server.headless true
```

The binary at `venv/bin/streamlit` already knows to use the venv's Python.

---

## Common Mistakes and Fixes

### Mistake: venv Created with Wrong Python

**Symptom:** `python --version` inside venv shows Python 3.7

**Fix:**
```bash
deactivate
rm -rf venv
/usr/local/bin/python3.11 -m venv venv
source venv/bin/activate
python --version   # Now should show Python 3.11.9
```

### Mistake: Forgetting to Activate Before Installing

**Symptom:** Packages install to system Python instead of venv

**Fix:** Always check `which pip` before installing. It should show a path inside `venv/bin/`.

```bash
source venv/bin/activate
which pip   # Must be inside venv before installing
pip install -r requirements.txt
```

### Mistake: Committing venv/ to Git

**Symptom:** Repository is very large; venv/ appears in `git status`

**Fix:** Add venv to `.gitignore`:

```bash
echo "venv/" >> .gitignore
git rm -r --cached venv/   # Remove from git tracking if already added
```

### Mistake: venv Missing After Reboot

**Symptom:** App fails after server restart

**Fix:** The venv directory persists on disk — it does not disappear on reboot. If the venv is missing, the `/opt/apps` directory may have been on ephemeral storage (instance store). Use EBS volumes for application storage.

---

## Best Practices Summary

| Practice | Why |
|---|---|
| Use `/usr/local/bin/python3.11 -m venv venv` | Ensures Python 3.11, not system 3.7 |
| Put venv inside the app directory | Easy to find; one venv per app |
| Add `venv/` to `.gitignore` | Don't commit thousands of library files |
| Pin pip version with `pip==24.0` | Reproducible builds |
| Generate `requirements.txt` with `pip freeze` | Captures exact versions for reproducibility |
| Use full venv path in systemd | No need to activate in service files |
| Delete and recreate venv if wrong Python | Faster than debugging wrong-Python issues |
