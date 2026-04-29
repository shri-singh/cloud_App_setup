# 02 — Basic Linux Command Cheat Sheet

A comprehensive reference for the Linux commands you'll use during EC2 setup and Streamlit deployment. Every command is explained in plain language.

---

## 1. Navigation — Where Am I and How Do I Move?

```bash
pwd
```
**Print Working Directory.** Shows the full path of your current location.
Example: `/opt/apps/my-streamlit-app`

```bash
cd /opt/apps
```
**Change Directory.** Move to the `/opt/apps` folder.

```bash
cd ..
```
Move up one directory level (to the parent folder).

```bash
cd ../..
```
Move up two directory levels.

```bash
cd ~
```
Go to your home directory (e.g., `/root` or `/home/ec2-user`).

```bash
cd -
```
Go back to the previous directory you were in.

```bash
cd /
```
Go to the root of the filesystem.

---

## 2. Listing Files — What Is In This Directory?

```bash
ls
```
List files and folders in the current directory.

```bash
ls -l
```
Long listing format — shows permissions, owner, size, date, and name.

```bash
ls -la
```
Long listing **including hidden files** (files starting with `.` like `.env`).

```bash
ls -lah
```
Long listing with hidden files and **human-readable file sizes** (KB, MB instead of raw bytes).

```bash
ls -ltr
```
Long listing sorted by **modification time**, oldest first. Good for seeing what changed recently.

```bash
ls -d */
```
List only **directories** (folders) in the current location.

---

## 3. Hidden Files

Files and directories starting with `.` are hidden by default.

```bash
ls -la
```
The `-a` flag shows hidden files. Important hidden files you'll use:
- `.env` — your secrets file
- `.gitignore` — tells Git what to ignore
- `.git/` — the Git repository data folder
- `.bashrc` / `.bash_profile` — shell configuration

---

## 4. Directory Creation

```bash
mkdir my_folder
```
Create a single directory.

```bash
mkdir -p /opt/apps/myapp/logs
```
Create a **full path** including all intermediate directories.
The `-p` flag means "create parents if they don't exist" and don't error if the directory already exists.

---

## 5. File Creation

```bash
touch file.txt
```
Create an empty file (or update the timestamp of an existing file).

```bash
nano file.txt
```
Open `file.txt` in the **nano** text editor (beginner-friendly).
- `Ctrl+O` then `Enter` to save
- `Ctrl+X` to exit

```bash
vi file.txt
```
Open `file.txt` in the **vi** editor (advanced, but available everywhere).
- Press `i` to enter insert/edit mode
- Press `Esc` to exit insert mode
- Type `:wq` then `Enter` to save and quit
- Type `:q!` then `Enter` to quit without saving

---

## 6. Copy, Move, Delete

```bash
cp source.txt destination.txt
```
Copy a file.

```bash
cp -r source_folder/ destination_folder/
```
Copy a folder and all its contents recursively.

```bash
mv old_name.txt new_name.txt
```
Rename a file. Also used to move files to a different location.

```bash
mv file.txt /opt/apps/
```
Move `file.txt` to the `/opt/apps/` directory.

```bash
rm file.txt
```
Delete a file permanently. There is no recycle bin on Linux.

```bash
rm -r folder/
```
Delete a folder and everything inside it.

```bash
rm -rf folder/
```
**Force** delete a folder and all contents without any confirmation prompts.
> ⚠️ **WARNING:** `rm -rf` is irreversible. Double-check the path before running.

---

## 7. Viewing Files

```bash
cat file.txt
```
Print the entire contents of a file to the terminal. Best for small files.

```bash
less file.txt
```
View a file one page at a time. Press `q` to quit, arrow keys to scroll, `/` to search.

```bash
head file.txt
```
Show the first 10 lines of a file.

```bash
head -n 50 file.txt
```
Show the first 50 lines.

```bash
tail file.txt
```
Show the last 10 lines of a file.

```bash
tail -n 50 file.txt
```
Show the last 50 lines.

```bash
tail -f app.log
```
**Follow** a log file in real time. New lines appear as they are written. Press `Ctrl+C` to stop.
Very useful for watching Streamlit logs.

---

## 8. Searching Files

```bash
find . -name "app.py"
```
Find all files named `app.py` starting from the current directory (`.`).

```bash
find / -name "python3.11" 2>/dev/null
```
Find `python3.11` anywhere on the entire filesystem. `2>/dev/null` hides "permission denied" errors.

```bash
find /opt/apps -name "*.py"
```
Find all `.py` files inside `/opt/apps`.

```bash
find . -name "*.log" -mtime -1
```
Find all `.log` files modified in the last 1 day.

---

## 9. Searching Text Inside Files

```bash
grep "streamlit" app.py
```
Find lines containing the word `streamlit` inside `app.py`.

```bash
grep -r "streamlit" .
```
Search recursively for `streamlit` in all files in the current directory.

```bash
grep -Rin "streamlit" .
```
Recursive (`-r`), case-**i**nsensitive (`-i`), show line **n**umbers (`-n`).

```bash
grep -r "error" /var/log/
```
Search all log files for errors.

---

## 10. Disk and Memory

```bash
df -h
```
Show disk space usage for all mounted filesystems. `-h` = human-readable (GB, MB).

```bash
du -sh .
```
Show the total size of the current directory. `-s` = summary, `-h` = human-readable.

```bash
du -sh /opt/apps/*
```
Show the size of each item in `/opt/apps`.

```bash
free -h
```
Show total, used, and free RAM. `-h` = human-readable.

---

## 11. Processes — What Is Running?

```bash
top
```
Interactive real-time view of all running processes and resource usage. Press `q` to quit.

```bash
ps -ef
```
Show all running processes with details (process ID, user, command).

```bash
ps -ef | grep streamlit
```
Filter the process list to find Streamlit processes. The `|` pipes output of `ps` into `grep`.

```bash
kill 12345
```
Send a termination signal to process ID 12345 (graceful stop).

```bash
kill -9 12345
```
**Force kill** process 12345 immediately. Use when the normal kill doesn't work.

```bash
pkill -f streamlit
```
Kill all processes whose command line contains the word `streamlit`.

---

## 12. Ports and Networking

```bash
ss -tulpn
```
Show all listening TCP/UDP ports and the processes using them.
- `-t` = TCP
- `-u` = UDP
- `-l` = listening sockets
- `-p` = show process
- `-n` = show numbers (not service names)

```bash
ss -tulpn | grep 8501
```
Check if anything is listening on port 8501 (Streamlit's default port).

```bash
ss -tulpn | grep nginx
```
Check Nginx port bindings.

```bash
curl http://localhost:8501
```
Make an HTTP request to Streamlit running on port 8501. If it returns HTML, the app is up.

```bash
curl -I http://localhost
```
Check HTTP response headers from Nginx on port 80.

---

## 13. Permissions

Linux files have three permission types: **read (r)**, **write (w)**, **execute (x)**.
Permissions apply to: **owner**, **group**, **others**.

```bash
ls -la .env
```
Example output: `-rw-------  1 root root  156 Apr 29 10:00 .env`
This means only the owner (root) can read and write it.

```bash
chmod +x script.sh
```
Make a script executable (add execute permission for all users).

```bash
chmod 600 .env
```
Set `.env` so **only the owner** can read and write it. No access for group or others.
(6 = read+write, 0 = no permission, 0 = no permission)

```bash
chmod 755 /opt/apps/myapp
```
Owner: read+write+execute. Group and others: read+execute. Good for directories.

```bash
chown ec2-user:ec2-user file.txt
```
Change the owner and group of a file.

```bash
chown -R ec2-user:ec2-user /opt/apps/myapp
```
Change ownership of a directory and all its contents recursively.

---

## 14. Root and Sudo

```bash
sudo su -
```
Become root with root's full environment.

```bash
sudo command
```
Run a single command as root without switching to a root shell.

```bash
exit
```
Exit from the current shell (exit root, or log out of SSH session).

```bash
whoami
```
Show your current username.

---

## 15. Package Managers

Different Linux distributions use different package managers:

```bash
# Amazon Linux 2, RHEL 7, CentOS 7:
yum install -y package_name
yum update -y
yum remove -y package_name
yum list installed

# Amazon Linux 2023, RHEL 8+, Fedora:
dnf install -y package_name
dnf update -y

# Ubuntu / Debian:
apt update
apt install -y package_name
apt upgrade -y
```

The `-y` flag automatically answers "yes" to confirmation prompts.

---

## 16. Git Basics

```bash
git --version
git clone https://github.com/ORG/REPO.git
git clone https://USER:TOKEN@github.com/ORG/REPO.git
cd REPO
git status
git pull origin main
git log --oneline -10
git branch
git remote -v
git remote set-url origin NEW_URL
```

---

## 17. Python Basics (on EC2)

```bash
# Check system Python versions
python3 --version
/usr/local/bin/python3.11 --version

# Create a virtual environment
/usr/local/bin/python3.11 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Deactivate
deactivate

# Install packages
pip install package_name
pip install -r requirements.txt
pip install --upgrade pip==24.0

# Check installed packages
pip list
pip freeze
pip show streamlit

# Check which Python is active
which python
which pip
```

---

## 18. Streamlit Basics

```bash
# Install Streamlit
pip install streamlit

# Check version
streamlit --version

# Run app — binds to all interfaces (for direct testing)
streamlit run app.py --server.port 8501 --server.address 0.0.0.0

# Run app — local only (use when Nginx is in front)
streamlit run app.py --server.port 8501 --server.address 127.0.0.1 --server.headless true

# Run on a different port
streamlit run app.py --server.port 8502

# Stop Streamlit
Ctrl+C
```

---

## 19. systemd Basics

```bash
# Start a service
sudo systemctl start streamlit-app

# Stop a service
sudo systemctl stop streamlit-app

# Restart a service
sudo systemctl restart streamlit-app

# Enable service to start at boot
sudo systemctl enable streamlit-app

# Disable auto-start at boot
sudo systemctl disable streamlit-app

# Check service status
sudo systemctl status streamlit-app

# View live service logs
sudo journalctl -u streamlit-app -f

# View last 100 log lines
sudo journalctl -u streamlit-app -n 100

# Reload systemd after editing a service file
sudo systemctl daemon-reload
```

---

## 20. Nginx Basics

```bash
# Test Nginx configuration syntax
sudo nginx -t

# Reload Nginx (applies config changes without downtime)
sudo systemctl reload nginx

# Restart Nginx (full restart)
sudo systemctl restart nginx

# Check Nginx status
sudo systemctl status nginx

# View Nginx access logs
sudo tail -f /var/log/nginx/access.log

# View Nginx error logs
sudo tail -f /var/log/nginx/error.log
```

---

## 21. Logs and Troubleshooting

```bash
# See all running services
systemctl list-units --type=service --state=running

# Check system logs
journalctl -xe

# See kernel messages
dmesg | tail -20

# Check disk space
df -h

# Check memory
free -h

# Check open file descriptors
ulimit -n

# View last 20 lines of a log file
tail -20 /var/log/messages

# Search for errors in a log
grep -i "error" /var/log/nginx/error.log

# Show all environment variables in current shell
env

# Show a specific variable
echo $PATH
echo $HOME

# Clear the terminal
clear

# Command history
history
history | grep streamlit
```

---

## Quick Reference Card

| Task | Command |
|---|---|
| Where am I? | `pwd` |
| List files | `ls -lah` |
| Go to folder | `cd /opt/apps` |
| Go home | `cd ~` |
| Create folder | `mkdir -p /opt/apps/myapp` |
| Create file | `touch app.py` |
| Edit file | `nano file.txt` |
| View file | `cat file.txt` |
| Follow log | `tail -f app.log` |
| Delete file | `rm file.txt` |
| Delete folder | `rm -rf folder/` |
| Search in files | `grep -Rin "word" .` |
| Find file | `find . -name "app.py"` |
| Disk space | `df -h` |
| RAM | `free -h` |
| Running processes | `ps -ef \| grep streamlit` |
| Kill process | `kill -9 PID` |
| Check ports | `ss -tulpn` |
| Become root | `sudo su -` |
| Install package | `yum install -y pkg` |
| Service status | `systemctl status streamlit-app` |
| View service logs | `journalctl -u streamlit-app -f` |
| Test Nginx | `nginx -t` |
