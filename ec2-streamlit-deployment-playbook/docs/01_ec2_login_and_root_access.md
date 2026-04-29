# 01 — EC2 Login and Root Access

This guide explains how to connect to an AWS EC2 Linux instance and how to safely use root access during setup.

---

## Option A — SSH Login (Most Common)

SSH (Secure Shell) lets you connect from your laptop to the EC2 server over the internet using an encryption key pair.

### Prerequisites

- EC2 key pair `.pem` file downloaded when you launched the instance
- EC2 instance is running and you know its public IP address
- Port 22 is open in the EC2 security group (inbound rule)

### Connect via SSH

```bash
# Replace with your actual key file path and EC2 IP
ssh -i /path/to/your-key.pem ec2-user@54.12.34.56
```

**Common default usernames by AMI type:**

| AMI / Linux Distribution | Default SSH Username |
|---|---|
| Amazon Linux 2 | `ec2-user` |
| Amazon Linux 2023 | `ec2-user` |
| RHEL | `ec2-user` or `cloud-user` |
| CentOS | `centos` or `ec2-user` |
| Ubuntu | `ubuntu` |
| Debian | `admin` |

> If your corporate golden image uses a different username, check with your cloud/DevOps team.

### Fix Key Permissions (if SSH complains)

SSH requires your key file to be private. If you get a "bad permissions" error:

```bash
chmod 400 /path/to/your-key.pem
```

This means: only the owner can read the file. Everyone else gets no access.

---

## Option B — AWS Systems Manager (SSM) Session Manager

Many corporate AWS environments **disable SSH** and require SSM instead. SSM is more secure because it does not require port 22 to be open.

### Connect via SSM (AWS Console)

1. Go to **AWS Console → EC2 → Instances**
2. Select your instance
3. Click **Connect**
4. Choose **Session Manager**
5. Click **Connect**

A browser-based terminal opens. You are now inside the EC2 instance.

### Connect via SSM (AWS CLI)

```bash
aws ssm start-session --target i-0abcdef1234567890
```

Replace `i-0abcdef1234567890` with your actual instance ID.

> SSM requires the EC2 instance to have the SSM agent running and an IAM role with SSM permissions attached.

---

## Check Who You Are

After logging in, always confirm your identity:

```bash
whoami
```

This prints your current username — for example `ec2-user` or `root`.

```bash
id
```

This shows your user ID (uid), group ID (gid), and all groups you belong to.

Example output:

```
uid=1000(ec2-user) gid=1000(ec2-user) groups=1000(ec2-user),4(adm),10(wheel),190(systemd-journal)
```

---

## Check Your Location and System

```bash
pwd
```

Shows your current directory. When you first log in, this is usually `/home/ec2-user`.

```bash
hostname
```

Shows the server's hostname.

```bash
cat /etc/os-release
```

Shows the Linux distribution and version. This is important because package install commands differ by OS.

---

## Becoming Root

Root is the superuser account on Linux. Root has permission to do anything — install software, modify system files, start/stop services.

### Method 1 — Switch to Root Shell

```bash
sudo su -
```

The `-` means: switch to root AND load root's full environment (path, variables, home directory).

After running this, your prompt changes from `$` to `#`, which means you are root.

```bash
whoami
# root
```

### Method 2 — Root Shell via sudo -i

```bash
sudo -i
```

Similar to `sudo su -`. Starts a root login shell.

### Method 3 — Run One Command as Root

If you only need to run a single command as root:

```bash
sudo yum install -y nginx
```

This runs just that one command as root, then returns to your normal user.

---

## Exiting Root

When you are done with root-level work, return to the normal user:

```bash
exit
```

Or press `Ctrl + D`.

Your prompt should change back from `#` to `$`.

Always exit root when you no longer need elevated privileges. This reduces the risk of accidental damage.

---

## Why Root Is Powerful (and Risky)

As root you can:

- Delete any file on the system, including OS files
- Kill any process
- Overwrite system Python or critical binaries
- Change file ownership
- Install or remove packages system-wide

> **A single typo as root can break the entire server.**
> For example: `rm -rf /` (with a space) deletes everything.

Use root only for the specific tasks that require it (installing system packages, creating systemd services, configuring Nginx). Run your application as a normal user whenever possible.

---

## Corporate Best Practices

| Practice | Why |
|---|---|
| Use SSM instead of SSH | Avoids needing port 22 open; all access logged in CloudTrail |
| Use `sudo` for individual commands | Avoids staying in root shell for extended periods |
| Create a dedicated app user | Run the app as `streamlituser`, not root, when policy requires it |
| Avoid direct root login over SSH | Many corporate policies disable `PermitRootLogin` in SSH config |
| Log out of root when done | Reduces blast radius of accidental commands |

### Creating a Dedicated App User (Optional but Recommended for Production)

```bash
# Create a non-root user for running the app
useradd -m -s /bin/bash streamlituser

# Give the user ownership of the app directory
chown -R streamlituser:streamlituser /opt/apps/YOUR_REPO_NAME

# Then in systemd service file, set:
# User=streamlituser
```

---

## Summary of Commands

| Command | What It Does |
|---|---|
| `whoami` | Show current username |
| `id` | Show user ID, group ID, and groups |
| `sudo su -` | Become root with full root environment |
| `sudo -i` | Alternative way to become root |
| `exit` | Exit root (or log out of session) |
| `pwd` | Show current directory |
| `hostname` | Show server hostname |
| `cat /etc/os-release` | Show Linux distribution and version |
