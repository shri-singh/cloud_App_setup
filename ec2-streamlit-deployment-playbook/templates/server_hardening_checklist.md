# Server Hardening Checklist

Security best practices for an EC2 instance running a Streamlit app in a corporate AWS environment.

**Reviewed by:** ___________________________
**Review Date:** ___________________________

---

## Access Control

- [ ] **Do not run the app as root in production** — create a dedicated service user
  ```bash
  useradd -r -s /bin/false streamlituser
  chown -R streamlituser:streamlituser /opt/apps/YOUR_REPO_NAME
  # Update User= in systemd service file to streamlituser
  ```

- [ ] **SSH access is restricted** — port 22 is open only to specific admin IPs, not `0.0.0.0/0`

- [ ] **Root SSH login disabled** — verify `/etc/ssh/sshd_config` contains `PermitRootLogin no`

- [ ] **SSM Session Manager preferred over SSH** — requires no port 22; sessions logged to CloudTrail

- [ ] **MFA enabled for all AWS IAM users** with console access to this account

---

## Network and Ports

- [ ] **Port 8501 is NOT open in the security group** — Streamlit is internal only; Nginx proxies traffic

- [ ] **Port 80/443 restricted** to intended audience (0.0.0.0/0 for public, corporate VPN range for internal)

- [ ] **No unnecessary ports open** — review all inbound rules in the security group

- [ ] **HTTPS enforced** — app served over HTTPS in production (via certbot or ALB + ACM)

- [ ] **HTTP redirects to HTTPS** — Nginx or ALB redirects all port 80 traffic to port 443

---

## Secrets Management

- [ ] **`.env` file permissions are 600** — only the owner can read it
  ```bash
  chmod 600 /opt/apps/YOUR_REPO_NAME/.env
  ls -la /opt/apps/YOUR_REPO_NAME/.env  # Verify: -rw-------
  ```

- [ ] **`.env` is not committed to GitHub** — verify with `git status` in the repo

- [ ] **No hardcoded secrets in Python code** — all secrets read from environment variables

- [ ] **Secrets not logged** — no `print(api_key)` or `st.write(secret)` in code

- [ ] **Secrets rotated regularly** — API keys and tokens have expiration and are rotated on schedule

- [ ] **AWS Secrets Manager or SSM Parameter Store** considered for production secret management

---

## GitHub and Code

- [ ] **GitHub personal access token has minimum required scope** — read-only for deployment

- [ ] **Token has an expiration date** — 30, 60, or 90 days maximum

- [ ] **SSH deploy key used for automation** instead of personal account token

- [ ] **GitHub token not stored in shell history**
  ```bash
  history | grep github  # Should not show any tokens
  ```

- [ ] **`.gitignore` includes `.env`, `venv/`, and `__pycache__/`**

---

## OS and Package Updates

- [ ] **OS updated before deployment** — `yum update -y` or `dnf update -y`

- [ ] **Automatic security updates configured** (if corporate policy allows)
  ```bash
  # Amazon Linux 2
  yum install -y yum-cron
  systemctl enable yum-cron
  ```

- [ ] **Unused packages removed** — less attack surface

- [ ] **Python packages pinned** in `requirements.txt` — prevents unexpected dependency updates

---

## IAM and AWS Permissions

- [ ] **EC2 instance has an IAM role** — do not use access keys on EC2 instances

- [ ] **IAM role follows least privilege** — only the permissions the app actually needs

- [ ] **If using S3:** role has access only to required buckets and paths

- [ ] **If using Secrets Manager:** role has `secretsmanager:GetSecretValue` for specific secrets only

- [ ] **AWS CloudTrail enabled** in the account — all API calls logged

---

## Monitoring and Logging

- [ ] **CloudWatch agent installed** on EC2 for system metrics (CPU, memory, disk)

- [ ] **systemd logs reviewed** after deployment — `journalctl -u streamlit-app -n 100`

- [ ] **Nginx access and error logs** reviewed — `/var/log/nginx/access.log`

- [ ] **Log retention configured** — either in CloudWatch log groups or `journald` limits

- [ ] **Alerts configured** — notification if the app crashes or EC2 CPU spikes

---

## Backup and Recovery

- [ ] **EBS volume snapshots** scheduled for the EC2 root volume

- [ ] **App code is in GitHub** — the repo is the source of truth, not just the EC2 disk

- [ ] **Recovery procedure documented** — how to redeploy the app from scratch if the EC2 is terminated

---

## Compliance (Check with Your Security Team)

- [ ] **Data classification** — does the app process PII, PHI, or other regulated data? If so, additional controls apply.

- [ ] **VPC flow logs enabled** — captures network traffic metadata for audit

- [ ] **AWS Config enabled** — tracks configuration changes to EC2, security groups, IAM

- [ ] **Corporate security baseline applied** — your company's golden image hardening applied to this instance

---

## Quick Security Commands

```bash
# Check who can log in via SSH
cat /etc/ssh/sshd_config | grep -E "PermitRootLogin|PasswordAuthentication|AllowUsers"

# List all open ports
ss -tulpn

# Check .env permissions
ls -la /opt/apps/YOUR_REPO_NAME/.env

# Check if 8501 is externally exposed (should NOT be in security group)
# Go to AWS Console → EC2 → Security Groups and verify

# Check for setuid/setgid files (potential privilege escalation)
find /opt/apps -perm /6000 -type f 2>/dev/null

# Check for world-writable files in app directory
find /opt/apps -perm -o+w -type f 2>/dev/null
```
