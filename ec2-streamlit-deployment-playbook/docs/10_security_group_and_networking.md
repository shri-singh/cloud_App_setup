# 10 — Security Group and Networking

This guide explains EC2 security groups, which ports to open, and how to configure networking correctly for a Streamlit deployment behind Nginx.

---

## What Is an EC2 Security Group?

An EC2 security group is a virtual firewall that controls traffic in and out of your EC2 instance. Think of it as a list of rules:

- **Inbound rules** — what traffic is allowed to reach your instance
- **Outbound rules** — what traffic can leave your instance (usually unrestricted)

Security groups are stateful: if an inbound connection is allowed, the response traffic is automatically allowed back out — you do not need separate outbound rules for responses.

---

## Port Overview for This Deployment

| Port | Protocol | Who Uses It | Should It Be Public? |
|---|---|---|---|
| `22` | TCP (SSH) | Admin SSH access | Only from specific admin IPs |
| `80` | TCP (HTTP) | Users → Nginx | Yes (or VPN range) |
| `443` | TCP (HTTPS) | Users → Nginx (SSL) | Yes (or VPN range) |
| `8501` | TCP | Nginx → Streamlit (internal) | **NO — keep internal only** |

**Key principle:** Streamlit runs on port 8501 inside the server. Nginx listens on port 80/443 and proxies to 8501. Users never connect directly to port 8501. Do not open 8501 in the security group.

---

## Recommended Security Group Inbound Rules

### For Public-Facing Applications

```
Type        Protocol  Port   Source
HTTP        TCP       80     0.0.0.0/0 (all IPv4)
HTTP        TCP       80     ::/0      (all IPv6, optional)
HTTPS       TCP       443    0.0.0.0/0
HTTPS       TCP       443    ::/0
SSH         TCP       22     YOUR_ADMIN_IP/32    (only your IP)
```

### For Internal/Corporate Applications (VPN Required)

```
Type        Protocol  Port   Source
HTTP        TCP       80     10.0.0.0/8     (corporate VPN CIDR)
HTTPS       TCP       443    10.0.0.0/8
SSH         TCP       22     10.1.2.0/24    (admin subnet only)
```

### Do NOT Add

```
# WRONG — exposes Streamlit directly, bypasses Nginx
Custom TCP   8501   0.0.0.0/0    ← Never do this in production
```

---

## Updating Security Groups — AWS Console

1. Go to **AWS Console → EC2 → Instances**
2. Select your instance
3. Click the **Security** tab
4. Click the security group name (e.g., `sg-0abc123`)
5. Click **Edit inbound rules**
6. Add or modify rules
7. Click **Save rules**

---

## Updating Security Groups — AWS CLI

```bash
# Allow HTTP from anywhere
aws ec2 authorize-security-group-ingress \
    --group-id sg-YOUR_SECURITY_GROUP_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0

# Allow HTTPS from anywhere
aws ec2 authorize-security-group-ingress \
    --group-id sg-YOUR_SECURITY_GROUP_ID \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0

# Allow SSH only from specific IP
aws ec2 authorize-security-group-ingress \
    --group-id sg-YOUR_SECURITY_GROUP_ID \
    --protocol tcp \
    --port 22 \
    --cidr YOUR_ADMIN_IP/32
```

---

## Verifying Ports from Inside the EC2 Instance

```bash
# Show all listening ports and processes
ss -tulpn

# Check specifically for Streamlit on 8501
ss -tulpn | grep 8501

# Check Nginx on 80
ss -tulpn | grep :80

# Check Nginx on 443
ss -tulpn | grep :443
```

Expected output after full setup:

```
tcp   LISTEN  0   100   127.0.0.1:8501   0.0.0.0:*   users:(("python",pid=...,fd=...))
tcp   LISTEN  0   128   0.0.0.0:80       0.0.0.0:*   users:(("nginx",pid=...,fd=...))
```

Note: Streamlit binds to `127.0.0.1:8501` (local only) while Nginx binds to `0.0.0.0:80` (all interfaces).

---

## Health Check Commands

```bash
# Test Streamlit is responding internally
curl http://127.0.0.1:8501

# Test Nginx is responding
curl http://localhost

# Test app is accessible from internet (from inside server, simulates external)
curl http://YOUR_EC2_PUBLIC_IP

# Test with response code only
curl -o /dev/null -s -w "%{http_code}" http://localhost
```

---

## Public vs Private EC2 Subnet

### Public Subnet

- EC2 instance has a public IP address
- Internet Gateway routes traffic from the internet to the instance
- Security group controls which ports are open

### Private Subnet

- EC2 instance does NOT have a public IP
- Not directly reachable from the internet
- Traffic flows through a NAT Gateway (outbound) or a Load Balancer (inbound)
- For inbound traffic, an Application Load Balancer (ALB) in a public subnet routes to the private EC2

For private subnet deployments:

```
User → Internet → ALB (public subnet, port 80/443) → EC2 (private subnet, port 8501 or 80)
```

In this case, configure the EC2 security group to accept traffic only from the ALB's security group:

```
Inbound:
  TCP  80  from sg-ALB_SECURITY_GROUP_ID  (only the ALB can reach this EC2)
```

---

## Corporate VPN Scenario

If your company requires VPN access to reach internal tools:

1. Configure your EC2 in a private subnet (no public IP)
2. Route traffic through a VPN Gateway or Direct Connect
3. Open ports 80/443 only from the corporate IP range
4. SSM Session Manager for admin access (no SSH needed over VPN)

```
Corporate User → VPN → Corporate Network → AWS VPC → Private Subnet EC2 → Nginx → Streamlit
```

The security group only needs to allow:

```
TCP  80   from 10.0.0.0/8  (corporate VPN range — check with your network team)
TCP  443  from 10.0.0.0/8
```

---

## NACLs (Network ACLs) — Additional Layer

Network ACLs are stateless subnet-level firewalls (different from security groups). In most setups, the default NACL allows all traffic and security groups handle the actual access control. If your corporate environment has restrictive NACLs, work with your cloud networking team to open the required ports at the subnet level too.

---

## Summary — Security Group Rules Cheat Sheet

### Minimum Required for This Deployment

| Direction | Protocol | Port | Source | Purpose |
|---|---|---|---|---|
| Inbound | TCP | 80 | Approved range | Nginx HTTP |
| Inbound | TCP | 443 | Approved range | Nginx HTTPS |
| Inbound | TCP | 22 | Admin IP only | SSH admin (if SSH enabled) |
| Outbound | All | All | 0.0.0.0/0 | Allow all outbound (default) |

### Do NOT Open

| Port | Reason |
|---|---|
| 8501 (public) | Exposes Streamlit directly — bypasses Nginx and security controls |
| 22 from 0.0.0.0/0 | SSH from anywhere is a major attack surface |
| All ports from 0.0.0.0/0 | Never open all ports publicly |
