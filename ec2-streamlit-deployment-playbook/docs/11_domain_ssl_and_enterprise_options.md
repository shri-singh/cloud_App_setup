# 11 — Domain, SSL, and Enterprise Options

This guide covers making your Streamlit app accessible via a domain name and enabling HTTPS/SSL encryption.

---

## Option 1 — EC2 Public IP (Simplest, Development Only)

The simplest option: access the app directly via the EC2 public IP.

```
http://54.12.34.56
```

**Limitations:**
- Public IP changes when EC2 is stopped and restarted (unless you use an Elastic IP)
- No SSL/HTTPS — connection is unencrypted
- Browsers show "Not Secure" warning
- Not acceptable for production or sensitive data

**Good for:** Quick demos, development testing, internal proof-of-concept.

---

## Option 2 — Elastic IP (Static Public IP)

An Elastic IP is a static public IP address you can attach to your EC2 instance. It stays the same even when the instance is stopped.

### Allocate and Attach Elastic IP

1. AWS Console → **EC2** → **Network & Security** → **Elastic IPs**
2. Click **Allocate Elastic IP address**
3. Click **Allocate**
4. Select the new Elastic IP → **Actions** → **Associate Elastic IP address**
5. Choose your EC2 instance → **Associate**

Your app is now accessible at a fixed IP: `http://YOUR_ELASTIC_IP`

> ⚠️ Elastic IPs are free while attached to a running instance. You are charged if the Elastic IP is allocated but NOT attached to a running instance.

---

## Option 3 — Custom Domain via Route 53 or Corporate DNS

Point a domain name (or subdomain) to your EC2 instance's public IP.

### Using AWS Route 53

1. Register a domain in Route 53, or transfer an existing domain
2. In Route 53, create a **Hosted Zone** for your domain
3. Create an **A record** pointing to your EC2 public IP (or Elastic IP):
   ```
   Type: A
   Name: app.yourcompany.com
   Value: YOUR_EC2_PUBLIC_IP
   TTL: 300
   ```

After DNS propagates (a few minutes to 48 hours), your app is accessible at:

```
http://app.yourcompany.com
```

Update your Nginx config:

```nginx
server {
    listen 80;
    server_name app.yourcompany.com;
    ...
}
```

### Using Corporate DNS

If your company manages DNS internally, ask your network/IT team to create an A record:

```
app.yourcompany.com  →  YOUR_EC2_PUBLIC_IP
```

---

## Option 4 — SSL with Nginx + Certbot (Let's Encrypt)

Free SSL certificates from Let's Encrypt. Best for internet-facing apps with a public domain.

### Install Certbot

```bash
# Amazon Linux 2:
sudo amazon-linux-extras enable epel
sudo yum install -y certbot python2-certbot-nginx

# Amazon Linux 2023:
sudo dnf install -y certbot python3-certbot-nginx

# Ubuntu:
sudo apt install -y certbot python3-certbot-nginx
```

### Obtain and Install Certificate

```bash
sudo certbot --nginx -d app.yourcompany.com
```

Certbot will:
1. Verify you control the domain (via HTTP challenge)
2. Obtain a free certificate from Let's Encrypt
3. Automatically update your Nginx config to use HTTPS
4. Set up auto-renewal

### Manual Certificate Setup in Nginx

If you prefer to configure SSL manually in Nginx:

```nginx
server {
    listen 443 ssl;
    server_name app.yourcompany.com;

    ssl_certificate     /etc/letsencrypt/live/app.yourcompany.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/app.yourcompany.com/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://127.0.0.1:8501;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }
}

server {
    listen 80;
    server_name app.yourcompany.com;
    return 301 https://$host$request_uri;
}
```

The second server block redirects all HTTP traffic to HTTPS.

### Certificate Auto-Renewal

Let's Encrypt certificates expire every 90 days. Certbot sets up auto-renewal automatically. Test it:

```bash
sudo certbot renew --dry-run
```

---

## Option 5 — AWS Application Load Balancer + ACM Certificate (Enterprise Recommended)

For corporate AWS environments, this is the recommended approach.

### Architecture

```
User (HTTPS) 
     ↓
Route 53 / Corporate DNS
     ↓
AWS Application Load Balancer (ALB)
  - Listens on port 443
  - SSL certificate from AWS Certificate Manager (ACM) — free, auto-renewing
     ↓
EC2 Target Group (port 80 or 8501)
     ↓
Nginx on EC2 (optional, or skip if ALB handles routing)
     ↓
Streamlit on 127.0.0.1:8501
```

### Benefits of ALB + ACM

| Feature | Benefit |
|---|---|
| ACM certificates | Free, auto-renewing, no manual cert management |
| ALB handles SSL termination | EC2 only needs to handle HTTP (no SSL config on server) |
| ALB health checks | Automatically routes around unhealthy instances |
| Multiple EC2 instances | Horizontal scaling if needed |
| WAF integration | Apply AWS Web Application Firewall rules |
| Access logs | Centralized HTTP request logging in S3 |

### Setting Up ALB + ACM

1. **Request certificate in ACM:**
   - AWS Console → **Certificate Manager** → **Request a certificate**
   - Enter your domain: `app.yourcompany.com`
   - Choose DNS validation
   - Add the CNAME record to Route 53 (ACM can do this automatically)
   - Wait for validation (usually < 5 minutes with Route 53)

2. **Create an ALB:**
   - AWS Console → **EC2** → **Load Balancers** → **Create Load Balancer**
   - Choose **Application Load Balancer**
   - Scheme: **Internet-facing** (or **Internal** for VPN-only access)
   - Listeners: Add HTTPS port 443, attach your ACM certificate
   - Add HTTP port 80 with a redirect rule to HTTPS

3. **Create a Target Group:**
   - Target type: **Instance**
   - Protocol: **HTTP**, Port: **80** (Nginx on EC2)
   - Health check path: `/` (returns 200 from Streamlit)
   - Register your EC2 instance

4. **Update EC2 Security Group:**
   - Allow traffic on port 80 only from the ALB security group (not from 0.0.0.0/0)

---

## Comparison of SSL Options

| Option | Difficulty | Cost | Best For |
|---|---|---|---|
| No SSL (HTTP only) | None | Free | Local testing only |
| Certbot + Let's Encrypt | Low | Free | Internet-facing apps, smaller teams |
| ALB + ACM | Medium | ALB hourly charges | Corporate/enterprise AWS deployments |
| Private CA | High | Depends | Air-gapped or regulated environments |

---

## Enterprise Recommendation

For production deployments inside a corporate AWS account:

```
User → Route 53 or Corporate DNS → ALB (HTTPS + ACM cert) → EC2 private subnet → Nginx → Streamlit
```

- Keep EC2 in a **private subnet** (no public IP)
- Use ALB in a **public subnet** to receive internet traffic
- Restrict EC2 security group to accept traffic only from the ALB security group
- Use ACM for certificate management — no manual renewal
- Enable ALB access logs to S3 for audit/compliance
