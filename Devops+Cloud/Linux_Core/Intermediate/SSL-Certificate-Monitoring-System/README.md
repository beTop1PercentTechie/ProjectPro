# SSL Certificate Monitoring System

A complete, start-to-finish guide to standing up an Ubuntu EC2 server, serving a site over Nginx, securing it with a free Let's Encrypt certificate, and deploying this project to monitor that certificate's expiry, alert by HTML email, and drive its renewal automatically.

[![Bash](https://img.shields.io/badge/Bash-5.x-4EAA25?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Nginx](https://img.shields.io/badge/Nginx-reverse%20proxy-009639?logo=nginx&logoColor=white)](https://nginx.org/)
[![Let's Encrypt](https://img.shields.io/badge/Let's%20Encrypt-Certbot-003A70?logo=letsencrypt&logoColor=white)](https://certbot.eff.org/)
[![AWS EC2](https://img.shields.io/badge/AWS-EC2-FF9900?logo=amazonaws&logoColor=white)](https://aws.amazon.com/ec2/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

This README assumes **nothing is set up yet** — no server, no domain, no certificate — and walks through every step in the order you'd actually do them. If you already have a server running Nginx behind a Let's Encrypt certificate, skip ahead to [Phase 11](#phase-11--deploy-the-ssl-monitoring-system).

---

## Table of Contents

- [Architecture](#architecture)
- [What you'll need](#what-youll-need)
- [Phase 1 — Launch the EC2 instance](#phase-1--launch-the-ec2-instance)
- [Phase 2 — Connect to the instance via SSH](#phase-2--connect-to-the-instance-via-ssh)
- [Phase 3 — Update the server](#phase-3--update-the-server)
- [Phase 4 — Install Nginx](#phase-4--install-nginx)
- [Phase 5 — Install the mail stack and project dependencies](#phase-5--install-the-mail-stack-and-project-dependencies)
- [Phase 6 — Point your domain at the server](#phase-6--point-your-domain-at-the-server)
- [Phase 7 — Confirm the site over HTTP (checkpoint)](#phase-7--confirm-the-site-over-http-checkpoint)
- [Phase 8 — Issue the Let's Encrypt certificate](#phase-8--issue-the-lets-encrypt-certificate)
- [Phase 9 — Verify HTTPS](#phase-9--verify-https)
- [Phase 10 — Configure Postfix to relay mail through Gmail](#phase-10--configure-postfix-to-relay-mail-through-gmail)
- [Phase 11 — Deploy the SSL Monitoring System](#phase-11--deploy-the-ssl-monitoring-system)
- [Phase 12 — Run and test the monitor](#phase-12--run-and-test-the-monitor)
- [Phase 13 — Automate with cron](#phase-13--automate-with-cron)
- [Configuration reference](#configuration-reference)
- [Email notifications](#email-notifications)
- [Troubleshooting](#troubleshooting)
- [Roadmap](#roadmap)
- [License](#license)

---

## Architecture

```mermaid
flowchart TD
    A[Your domain, e.g. yourdomain.com] --> B[DNS A record]
    B --> C[EC2 public IP]
    C --> D[Security group: 22 / 80 / 443]
    D --> E[Nginx]
    E --> F[Let's Encrypt certificate]
    F --> G["/etc/letsencrypt/live/yourdomain.com/"]
    G --> H[ssl-monitor.sh]
    H --> I[OpenSSL: read expiry]
    I --> J{Status?}
    J -->|HEALTHY| K[No action]
    J -->|WARNING / CRITICAL| L[Send HTML alert email]
    J -->|inside renewal window| M[certbot renew]
    M --> N[nginx -t]
    N --> O[systemctl reload nginx]
    O --> P[Verify live HTTPS cert]
    P --> Q[Send renewal result email]
```

---

## What you'll need

- An AWS account with permission to launch EC2 instances
- A domain name you control (any registrar — GoDaddy is used as the example here, but Route 53, Namecheap, Cloudflare, etc. all work the same way)
- A Gmail account with an **app password** generated (for relaying alert email — never use your real Gmail password)
- A terminal on your own machine (macOS/Linux Terminal, or Windows Terminal / WSL / PuTTY)

---

## Phase 1 — Launch the EC2 instance

1. Sign in to the **AWS Console** and open **EC2 → Instances**.
2. Click **Launch instance**.
3. Configure the instance:

   | Setting | Value |
   |---|---|
   | **Name** | `ssl-monitor` (or any name you like) |
   | **AMI** | Ubuntu Server (latest LTS) |
   | **Instance type** | `t2.micro` or `t3.micro` — sufficient for this project |
   | **Key pair** | Create a new key pair (e.g. `ssl-monitor-key`), type `.pem`, and **download it** — you cannot re-download it later |
   | **Storage** | 8 GiB gp3 (the default is enough) |
   | **Security group** | Create a new one allowing the three rules below |

4. Configure the **security group** inbound rules:

   | Type | Protocol | Port | Source | Purpose |
   |---|---|---|---|---|
   | SSH | TCP | 22 | My IP (recommended) or 0.0.0.0/0 | Server administration |
   | HTTP | TCP | 80 | 0.0.0.0/0 | ACME HTTP-01 challenge + HTTP→HTTPS redirect |
   | HTTPS | TCP | 443 | 0.0.0.0/0 | Encrypted site traffic |

📸 **Screenshot (`1.png`) — Launch configuration summary.**

<p align="center">
  <img src="images/1.png" alt="1.png — EC2 launch configuration summary showing name, Ubuntu AMI, key pair, 8 GiB storage, and security group rules" width="750">
</p>

5. Click **Launch instance**, then open the instance and wait for:
   - **Instance state:** `Running`
   - **Status check:** `2/2 checks passed`

📸 **Screenshot (`2.png`) — Instance up and running.**

<p align="center">
  <img src="images/2.png" alt="2.png — EC2 instances page showing running state, status checks passed, and public IPv4 address" width="750">
</p>

---

## Phase 2 — Connect to the instance via SSH

1. Select the instance in the console and click **Connect**.

📸 **Screenshot (`3.png`) — Select instance and click Connect.**

<p align="center">
  <img src="images/3.png" alt="3.png — EC2 instances page with instance selected and Connect button highlighted" width="750">
</p>

2. Open the **SSH client** tab — it shows the exact command to use, built from your key pair and the instance's public DNS name.

📸 **Screenshot (`4.png`) — Connect dialog & SSH client tab.**

<p align="center">
  <img src="images/4.png" alt="4.png — EC2 Connect to instance dialog, SSH client tab showing command details" width="750">
</p>

3. On your own machine, open a terminal and go to the folder where the `.pem` file downloaded — usually **Downloads**:

   ```bash
   cd ~/Downloads
   ls -l *.pem
   ```

4. Lock down the key's permissions (required on macOS/Linux — SSH refuses to use a key that's readable by others):

   ```bash
   chmod 400 ssl-monitor-key.pem
   ```

5. Paste the command copied from the Connect dialog and run it, substituting your own key filename and public IP/DNS:

   ```bash
   ssh -i "ssl-monitor-key.pem" ubuntu@YOUR_PUBLIC_IP
   ```

   Type `yes` if prompted to trust the host's fingerprint.

📸 **Screenshot (`5.png`) — Key permissions and SSH connection prompt.**

<p align="center">
  <img src="images/5.png" alt="5.png — Terminal showing chmod 400 and ssh command with host fingerprint prompt" width="750">
</p>

📸 **Screenshot (`6.png`) — SSH connection successful.**

<p align="center">
  <img src="images/6.png" alt="6.png — Terminal showing successful SSH login landed at ubuntu@ip prompt" width="750">
</p>

---

## Phase 3 — Update the server

Always start a fresh instance with an update, before installing anything:

```bash
sudo apt update
sudo apt upgrade -y
```

Verify the OS if you like:

```bash
cat /etc/os-release
```

---

## Phase 4 — Install Nginx

```bash
sudo apt install nginx -y
sudo systemctl enable nginx
sudo systemctl status nginx
```

You want to see `Active: active (running)`. Press `q` to exit the status view.

📸 **Screenshot (`7.png`) — Nginx service status.**

<p align="center">
  <img src="images/7.png" alt="7.png — Terminal output of systemctl status nginx showing active running status" width="750">
</p>

Now open `http://YOUR_PUBLIC_IP` in a browser — you should see the default Nginx welcome page. This is an important checkpoint: if this doesn't load, fix it here before touching DNS or HTTPS.

📸 **Screenshot (`8.png`) — Default Nginx welcome page.**

<p align="center">
  <img src="images/8.png" alt="8.png — Browser showing stock Welcome to nginx page at public IP" width="750">
</p>

Put your own site content in place and remove the placeholder:

```bash
# Download your site's HTML from GitHub
sudo curl -fsSL https://raw.githubusercontent.com/Deepak8260/index/refs/heads/main/index.html -o /var/www/html/index.html

# Remove Nginx's default page
sudo rm -f /var/www/html/index.nginx-debian.html

# Set ubuntu as the owner
sudo chown -R ubuntu:ubuntu /var/www/html

# Set correct permissions for directories
sudo find /var/www/html -type d -exec chmod 755 {} \;

# Set correct permissions for files
sudo find /var/www/html -type f -exec chmod 644 {} \;
```

📸 **Screenshot (`9.png`) — Setting up website files and permissions.**

<p align="center">
  <img src="images/9.png" alt="9.png — Terminal showing curl download, removing default page, and setting file ownership/permissions" width="750">
</p>

Reload the IP in your browser (hard refresh with `Ctrl+Shift+R` if you still see the old page) to confirm your own content is now served.

📸 **Screenshot (`10.png`) — Custom website served over HTTP.**

<p align="center">
  <img src="images/10.png" alt="10.png — Browser showing custom website Verra Estates served at public IP over HTTP" width="750">
</p>

---

## Phase 5 — Install the mail stack and project dependencies

Install everything the SSL monitor needs in one pass — the web server dependency (OpenSSL, usually already present), the certificate tool, and the full mail-sending stack:

```bash
# Mail stack: Postfix (MTA), SASL auth modules, CA certs, and mail-sending utilities
sudo apt install postfix libsasl2-modules ca-certificates mailutils -y
```

When the Postfix installer prompts you, choose **Internet Site** and set the system mail name to your domain.

📸 **Screenshot (`16.png`) — Postfix installer configuration type prompt.**

<p align="center">
  <img src="images/16.png" alt="16.png — Postfix package configuration selecting Internet Site" width="750">
</p>

📸 **Screenshot (`17.png`) — Postfix system mail name prompt.**

<p align="center">
  <img src="images/17.png" alt="17.png — Postfix system mail name set to kumardevops.online" width="750">
</p>

```bash
# Certbot, via Snap (the officially recommended install method)
sudo apt install snapd -y
sudo snap install core
sudo snap refresh core
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot
certbot --version

# Confirm OpenSSL is already present (it ships with Ubuntu — don't reinstall blindly)
openssl version

# Git, to pull this repository
sudo apt install git -y
```

📸 **Screenshot (`18.png`) — Installing Certbot, OpenSSL check, and Git.**

<p align="center">
  <img src="images/18.png" alt="18.png — Terminal output of certbot, openssl version check, and git installation" width="750">
</p>

| Package | Why it's needed |
|---|---|
| `nginx` | Serves the site and terminates TLS |
| `postfix` | Local mail transfer agent — relays the monitor's alert emails |
| `libsasl2-modules` | Lets Postfix authenticate to an external SMTP server (Gmail) |
| `ca-certificates` | Trusted root certificates, needed for Postfix's TLS connection to Gmail |
| `mailutils` | Provides the `mail` command used to send test messages |
| `certbot` | Requests and renews the Let's Encrypt certificate |
| `openssl` | Reads certificate expiry/issuer/subject — this project's monitoring engine |
| `git` | Clones this repository onto the server |

---

## Phase 6 — Point your domain at the server

1. Buy or use an existing domain at any registrar (GoDaddy is used here as the example).

📸 **Screenshot (`11.png`) — Domain management dashboard.**

<p align="center">
  <img src="images/11.png" alt="11.png — GoDaddy domain management overview and DNS tab" width="750">
</p>

2. Open **DNS Management** for the domain and add an **A record**:

   | Type | Name | Value | TTL |
   |---|---|---|---|
   | A | `@` | Your EC2 public IPv4 address | Default / 1 hour |

📸 **Screenshot (`12.png`) — Adding the A record.**

<p align="center">
  <img src="images/12.png" alt="12.png — GoDaddy add new A record pointing @ to EC2 public IP" width="750">
</p>

📸 **Screenshot (`13.png`) — DNS record saved successfully.**

<p align="center">
  <img src="images/13.png" alt="13.png — GoDaddy success notification confirming DNS record update" width="750">
</p>

3. DNS changes can take anywhere from a few minutes to a few hours to propagate. Check from the server:

   ```bash
   getent hosts yourdomain.com
   ping -c 1 yourdomain.com
   ```

   Both should resolve to your EC2 public IP before you continue.

📸 **Screenshot (`14.png`) — Verifying DNS propagation on the server.**

<p align="center">
  <img src="images/14.png" alt="14.png — Terminal showing getent hosts resolving domain to EC2 public IP and ping test" width="750">
</p>

---

## Phase 7 — Confirm the site over HTTP (checkpoint)

```bash
curl -I http://yourdomain.com
```

Expect `HTTP/1.1 200 OK`. Then open `http://yourdomain.com` in a browser and confirm you see your site.

📸 **Screenshot (`15.png`) — HTTP headers response check.**

<p align="center">
  <img src="images/15.png" alt="15.png — Terminal output of curl -I http://kumardevops.online returning HTTP/1.1 200 OK" width="750">
</p>

Validate the Nginx config before moving on:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

---

## Phase 8 — Issue the Let's Encrypt certificate

Only once HTTP is confirmed working should you request a certificate:

```bash
sudo certbot --nginx -d yourdomain.com
```

Certbot will ask for an email address, ask you to accept the terms, and ask whether to redirect HTTP to HTTPS — choose **yes, redirect**. It then contacts Let's Encrypt, validates domain ownership, obtains the certificate, and edits the Nginx config for you.

📸 **Screenshot (`19.png`) — Certbot certificate issuance.**

<p align="center">
  <img src="images/19.png" alt="19.png — Terminal output of certbot issuing and deploying certificate for domain" width="750">
</p>

Confirm it's on disk:

```bash
sudo certbot certificates
sudo openssl x509 -in /etc/letsencrypt/live/yourdomain.com/fullchain.pem -noout -dates -issuer -subject
```

📸 **Screenshot (`20.png`) — Certificate details on disk.**

<p align="center">
  <img src="images/20.png" alt="20.png — Terminal output of certbot certificates showing valid certificate path and expiry" width="750">
</p>

---

## Phase 9 — Verify HTTPS

Open `https://yourdomain.com` in a browser — you should see a padlock and your site.

📸 **Screenshot (`21.png`) — Site secured with HTTPS.**

<p align="center">
  <img src="images/21.png" alt="21.png — Browser showing custom website served securely over HTTPS with padlock icon" width="750">
</p>

📸 **Screenshot (`22.png`) — Checking SSL padlock icon.**

<p align="center">
  <img src="images/22.png" alt="22.png — Browser window with green arrow highlighting HTTPS connection lock icon" width="750">
</p>

📸 **Screenshot (`23.png`) — Connection is secure popup.**

<p align="center">
  <img src="images/23.png" alt="23.png — Browser connection popup showing Connection is secure" width="750">
</p>

📸 **Screenshot (`24.png`) — Valid certificate status.**

<p align="center">
  <img src="images/24.png" alt="24.png — Browser security menu pointing to Certificate is valid" width="750">
</p>

📸 **Screenshot (`25.png`) — Live Let's Encrypt certificate details.**

<p align="center">
  <img src="images/25.png" alt="25.png — Browser Certificate Viewer displaying Let's Encrypt issuer and validity dates" width="750">
</p>

Confirm the redirect and the live certificate from the server side too:

```bash
curl -I http://yourdomain.com          # expect a 301 to https://

echo | openssl s_client -connect yourdomain.com:443 -servername yourdomain.com 2>/dev/null \
  | openssl x509 -noout -dates -issuer -subject

sudo certbot renew --dry-run           # simulates renewal without touching the live cert
```

A successful dry run prints `Congratulations, all simulated renewals succeeded` — nothing is actually replaced.

📸 **Screenshot (`26.png`) — Server-side HTTP redirect, OpenSSL check, and Certbot dry-run.**

<p align="center">
  <img src="images/26.png" alt="26.png — Terminal showing 301 redirect, openssl s_client certificate dates, and successful certbot dry-run" width="750">
</p>

---

## Phase 10 — Configure Postfix to relay mail through Gmail

The monitor sends mail via the local `sendmail` binary; Postfix needs to relay it out through a real SMTP provider.

### Step 1 — Set Postfix configuration options

```bash
sudo postconf -e 'myhostname = yourdomain.com'
sudo postconf -e 'mydomain = yourdomain.com'
sudo postconf -e 'myorigin = $mydomain'
sudo postconf -e 'relayhost = [smtp.gmail.com]:587'
sudo postconf -e 'smtp_sasl_auth_enable = yes'
sudo postconf -e 'smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd'
sudo postconf -e 'smtp_sasl_security_options = noanonymous'
sudo postconf -e 'smtp_tls_security_level = encrypt'
sudo postconf -e 'smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt'
sudo postconf -e 'inet_interfaces = loopback-only'
sudo postconf -e 'mynetworks = 127.0.0.0/8'
```

📸 **Screenshot (`27.png`) — Executing Postfix configuration commands.**

<p align="center">
  <img src="images/27.png" alt="27.png — Terminal executing postconf commands to set relayhost and SASL auth" width="750">
</p>

### Step 2 — Generate a Gmail App Password

> [!IMPORTANT]
> Postfix **cannot** use your personal Gmail account password. You must generate a dedicated 16-character **App Password**.

1. Go to your [Google Account Security Settings](https://myaccount.google.com/security).
2. Ensure **2-Step Verification** is turned **ON**.

📸 **Screenshot (`28.png`) — Confirming 2-Step Verification is enabled.**

<p align="center">
  <img src="images/28.png" alt="28.png — Google Account security page showing 2-Step Verification enabled" width="750">
</p>

3. Search for **App passwords** (or visit [`myaccount.google.com/apppasswords`](https://myaccount.google.com/apppasswords)).
4. Enter an app name (e.g. `Postfix SSL Monitor`) and click **Create**.

📸 **Screenshot (`29.png`) — Creating a new App Password.**

<p align="center">
  <img src="images/29.png" alt="29.png — Google App passwords page entering Postfix SSL Monitor app name" width="750">
</p>

5. Copy the generated 16-character password (e.g. `abcd efgh ijkl mnop`).

📸 **Screenshot (`30.png`) — Generated 16-character App Password.**

<p align="center">
  <img src="images/30.png" alt="30.png — Generated app password modal showing 16-character pass-code" width="750">
</p>

### Step 3 — Create the SASL credential file

Open `/etc/postfix/sasl_passwd` in `vim`:

```bash
sudo vim /etc/postfix/sasl_passwd
```

Add your Gmail address and the 16-character App Password (without spaces) as a single line:

```text
[smtp.gmail.com]:587    your-account@gmail.com:abcdefghijklmnop
```

📸 **Screenshot (`31.png`) — Editing sasl_passwd in vim.**

<p align="center">
  <img src="images/31.png" alt="31.png — Terminal in vim editing /etc/postfix/sasl_passwd with Gmail account and App Password" width="750">
</p>

*(Alternatively, run this single command to create the file directly):*

```bash
echo "[smtp.gmail.com]:587 your-account@gmail.com:abcdefghijklmnop" | sudo tee /etc/postfix/sasl_passwd
```

### Step 4 — Secure permissions, generate database map, and restart Postfix

```bash
# Restrict permissions so plain text credentials are only readable by root
sudo chmod 600 /etc/postfix/sasl_passwd

# Process sasl_passwd into a Postfix lookup map (/etc/postfix/sasl_passwd.db)
sudo postmap /etc/postfix/sasl_passwd

# Restrict permissions on the generated database file
sudo chmod 600 /etc/postfix/sasl_passwd.db

# Restart Postfix to apply all configuration changes
sudo systemctl restart postfix
```

### Step 5 — Send a test email to confirm delivery

```bash
echo "SSL Monitor Postfix test" | mail -s "SSL Monitor Test" you@example.com
sudo tail -f /var/log/mail.log
# look for: status=sent (250 2.0.0 OK ...)
```

📸 **Screenshot (`32.png`) — Terminal sending Postfix test mail & inspecting mail.log.**

<p align="center">
  <img src="images/32.png" alt="32.png — Terminal showing mail command and tail -f /var/log/mail.log with status=sent" width="750">
</p>

📸 **Screenshot (`33.png`) — Postfix test email delivered to Gmail inbox.**

<p align="center">
  <img src="images/33.png" alt="33.png — Gmail inbox showing received test email SSL Monitor Test - SSL Monitor Postfix test" width="750">
</p>

---

## Phase 11 — Deploy the SSL Monitoring System

```bash
cd ~
git clone https://github.com/Deepak8260/SSL-Monitoring-System.git
mv SSL-Monitoring-System ssl-monitor
cd ssl-monitor
chmod +x bin/*.sh
```

📸 **Screenshot (`34.png`) — Cloning repository and setting file permissions.**

<p align="center">
  <img src="images/34.png" alt="34.png — Terminal output of git clone, renaming folder to ssl-monitor, and chmod +x scripts" width="750">
</p>

Project layout:

```
ssl-monitor/
├── bin/
│   ├── ssl-monitor.sh        # Main controller — run this from cron
│   ├── certificate.sh        # Reads the cert with OpenSSL, computes status
│   ├── email.sh               # Renders templates and sends HTML mail
│   ├── renewal.sh             # Drives Certbot, Nginx reload, verification
│   ├── verification.sh        # Confirms the live HTTPS cert after renewal
│   └── test-email.sh          # Sends a sample of any one template on demand
├── config/
│   ├── ssl-monitor.conf       # Domain, thresholds, demo mode, log path
│   └── email.conf             # SMTP identity and alert recipient (chmod 600)
├── templates/                 # One HTML template per status/event
└── logs/
    └── ssl-monitor.log
```

Edit the two config files:

```bash
vim config/ssl-monitor.conf
vim config/email.conf
chmod 600 config/email.conf
```

See [Configuration reference](#configuration-reference) below for every key.

---

## Phase 12 — Run and test the monitor

```bash
cd bin
sudo ./ssl-monitor.sh
```

📸 **Screenshot (`35.png`) — Monitor execution & CRITICAL status alert.**

<p align="center">
  <img src="images/35.png" alt="35.png — Terminal output of ssl-monitor.sh running in demo mode reporting CRITICAL status" width="750">
</p>

📸 **Screenshot (`36.png`) — Automated renewal workflow completion.**

<p align="center">
  <img src="images/36.png" alt="36.png — Terminal output showing certbot dry-run success, nginx reload, and live HTTPS verification" width="750">
</p>

Send a sample of each template to check the visual design in your inbox:

```bash
sudo ./test-email.sh healthy
```

📸 **Screenshot (`37.png`) — Testing HEALTHY email template.**

<p align="center">
  <img src="images/37.png" alt="37.png — Terminal running test-email.sh healthy with successful send output" width="750">
</p>

📸 **Screenshot (`38.png`) — Received HEALTHY status HTML email.**

<p align="center">
  <img src="images/38.png" alt="38.png — Gmail inbox showing received SSL Certificate Healthy HTML email" width="750">
</p>

```bash
sudo ./test-email.sh critical
```

📸 **Screenshot (`39.png`) — Testing CRITICAL email template.**

<p align="center">
  <img src="images/39.png" alt="39.png — Terminal running test-email.sh critical with successful send output" width="750">
</p>

📸 **Screenshot (`40.png`) — Received CRITICAL status HTML email.**

<p align="center">
  <img src="images/40.png" alt="40.png — Gmail inbox showing received URGENT SSL Certificate Critical HTML email" width="750">
</p>

```bash
sudo ./test-email.sh warning
sudo ./test-email.sh expired
sudo ./test-email.sh renewal-success
```

---

## Phase 13 — Automate with cron

```bash
sudo crontab -e
```

Add a single line — **hourly**, never every minute (see [Troubleshooting](#troubleshooting) for why):

```
0 * * * * /home/ubuntu/ssl-monitor/bin/ssl-monitor.sh >> /home/ubuntu/ssl-monitor/logs/cron.log 2>&1
```

📸 **Screenshot 15 — Cron schedule confirmed.**

<p align="center">
  <img src="docs/screenshots/15-crontab.png" alt="crontab -l output showing the hourly ssl-monitor schedule" width="750">
</p>

---

## Configuration reference

**`config/ssl-monitor.conf`**

| Key | Meaning |
|---|---|
| `DOMAIN` | The domain the certificate belongs to |
| `CERTIFICATE` | Absolute path to `fullchain.pem` |
| `WARNING_DAYS` | Days remaining that triggers `WARNING` (default 30) |
| `CRITICAL_DAYS` | Days remaining that triggers `CRITICAL` (default 7) |
| `RENEWAL_DAYS` | Days remaining that triggers a renewal attempt (default 30) |
| `LOG_FILE` | Absolute path for the run log |
| `DEMO_MODE` | `true` simulates expiry and runs `certbot renew --dry-run`; set `false` in production |
| `DEMO_REMAINING_DAYS` | Fake remaining-day count used only in demo mode |

**`config/email.conf`**

| Key | Meaning |
|---|---|
| `EMAIL_FROM` | Sending mailbox |
| `EMAIL_FROM_NAME` | Display name recipients see |
| `ALERT_EMAIL` | Address that receives alerts |
| `EMAIL_ON_HEALTHY` | `false` recommended in production; `true` only for demos |

> Keep `config/email.conf` at `chmod 600` and out of version control — it is effectively a credential file.

---

## Email notifications

| Status / event | Template | Subject |
|---|---|---|
| HEALTHY | `healthy.html` | SSL Certificate Healthy - {domain} |
| WARNING | `warning.html` | SSL Certificate Warning - {domain} |
| CRITICAL | `critical.html` | URGENT: SSL Certificate Critical - {domain} |
| EXPIRED | `expired.html` | URGENT: SSL Certificate Expired - {domain} |
| Renewal succeeded | `renewal-success.html` | SSL Certificate Renewal Successful - {domain} |
| Renewal succeeded (demo) | `renewal-simulation-success.html` | SSL Renewal Simulation Successful - {domain} |
| Renewal failed | `renewal-failure.html` | URGENT: SSL Certificate Renewal Failed - {domain} |

Exit codes from `ssl-monitor.sh`: `0` HEALTHY · `1` WARNING · `2` CRITICAL · `3` EXPIRED · `4` configuration/environment error.

---

## Troubleshooting

- **Browser can't reach the public IP at all** — check the security group has ports 80/443 open, and that the instance passed both status checks.
- **`Permission denied (publickey)` on SSH** — confirm `chmod 400` was run on the `.pem` file, and that you're using the `ubuntu` user, not `root` or `ec2-user`.
- **`ERROR: Configuration file not found`** — `ssl-monitor.sh` resolves its config path from its own script location; make sure you're running it from inside the cloned repo, and that the path in `CONFIG_FILE` (if hardcoded) matches where you actually cloned the project.
- **`Another instance of Certbot is already running`** — caused by scheduling the monitor more often than one Certbot run takes to finish (e.g. every minute). Use the hourly cron schedule from Phase 13.
- **`Permission denied` reading the certificate** — always run the scripts with `sudo`; the Let's Encrypt directory is root-owned.
- **No renewal email after a CRITICAL email** — the CRITICAL/WARNING email and the renewal email are sent by two different code paths; a renewal email only fires if the Certbot → `nginx -t` → reload → verification chain fully succeeds.
- **Postfix test mail never arrives** — check `sudo tail -f /var/log/mail.log` for the actual SMTP response; a `Network is unreachable` line usually means outbound port 587 is blocked somewhere upstream of the instance.

---

## Roadmap

- [ ] Replace any hardcoded config path in `ssl-monitor.sh` with one derived from the script's own location
- [ ] Add a `state/` directory to suppress duplicate alerts on unchanged status
- [ ] Migrate from crontab to a `systemd` service + timer pair
- [ ] Set `DEMO_MODE=false` and `EMAIL_ON_HEALTHY=false` as the committed defaults

---

## License

MIT — see [`LICENSE`](LICENSE).