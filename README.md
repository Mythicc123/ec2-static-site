# EC2 Static Site

> Static website hosted on AWS EC2 running Nginx — provisioned with Terraform, deployed automatically via GitHub Actions CI/CD, and secured with HTTPS via Let's Encrypt.

[![Deploy to EC2](https://github.com/Mythicc123/ec2-static-site/actions/workflows/deploy.yml/badge.svg)](https://github.com/Mythicc123/ec2-static-site/actions/workflows/deploy.yml)

🌐 **Live site:** [http://54.66.248.75](http://54.66.248.75) &nbsp;|&nbsp; 📋 **Project spec:** [roadmap.sh/projects/ec2-instance](https://roadmap.sh/projects/ec2-instance)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        GitHub                               │
│  ┌──────────────┐    push to main    ┌──────────────────┐  │
│  │  Developer   │ ─────────────────► │  GitHub Actions  │  │
│  └──────────────┘                    │  (deploy.yml)    │  │
│                                      └────────┬─────────┘  │
└───────────────────────────────────────────────┼────────────┘
                                                │ rsync over SSH
                                                ▼
┌─────────────────────────────────────────────────────────────┐
│                        AWS (ap-southeast-2)                  │
│                                                             │
│   ┌──────────────┐    ┌───────────────────────────────┐    │
│   │   Route 53   │    │         EC2 Instance           │    │
│   │  (DNS A rec) │───►│  ┌─────────────────────────┐  │    │
│   └──────────────┘    │  │  Nginx (port 80/443)     │  │    │
│                        │  │  /var/www/html/          │  │    │
│   ┌──────────────┐    │  └─────────────────────────┘  │    │
│   │ Elastic IP   │───►│                               │    │
│   │ (static IP)  │    │  Security Group:              │    │
│   └──────────────┘    │  • Port 22  (SSH)             │    │
│                        │  • Port 80  (HTTP)            │    │
│                        │  • Port 443 (HTTPS)           │    │
│                        └───────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

**Flow:** A push to `main` triggers GitHub Actions → rsync copies `site/` to the EC2 instance → Nginx reloads → site is live.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Compute | AWS EC2 (t3.micro, Ubuntu 22.04 LTS) |
| Web server | Nginx |
| Provisioning | Terraform ≥ 1.5 |
| CI/CD | GitHub Actions |
| DNS | AWS Route 53 |
| TLS/HTTPS | Let's Encrypt (Certbot) |
| Region | ap-southeast-2 (Sydney) |

---

## Project Structure

```
ec2-static-site/
├── .github/
│   └── workflows/
│       └── deploy.yml       # CI/CD pipeline
├── scripts/
│   └── setup.sh             # EC2 bootstrap (runs once on first boot)
├── site/
│   └── index.html           # Static website
├── terraform/
│   ├── main.tf              # EC2, security group, Elastic IP, Route 53
│   ├── outputs.tf           # Public IP, SSH command, site URL
│   ├── provider.tf          # AWS provider + Terraform version lock
│   └── variables.tf         # Input variables
└── .gitignore               # Protects .pem keys and tfstate
```

---

## Setup Guide

### Prerequisites

- [AWS account](https://aws.amazon.com/free/) with IAM user credentials (`AmazonEC2FullAccess`, `AmazonRoute53FullAccess`)
- [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.5 installed locally
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured (`aws configure`)
- An EC2 Key Pair created in AWS Console → EC2 → Key Pairs (download the `.pem` file)

---

### Step 1 — Configure AWS credentials

```bash
aws configure
# AWS Access Key ID: <your key>
# AWS Secret Access Key: <your secret>
# Default region: ap-southeast-2
# Default output format: json
```

### Step 2 — Set Terraform variables

Create a `terraform/terraform.tfvars` file (this is gitignored — never commit it):

```hcl
key_pair_name = "your-key-pair-name"   # Name in AWS Console, not the filename
domain_name   = "yourdomain.com"       # Leave as "" to skip Route 53 + HTTPS
instance_type = "t3.micro"             # Free tier in ap-southeast-2
```

### Step 3 — Provision infrastructure

```bash
cd terraform
terraform init       # Downloads AWS provider plugin
terraform plan       # Preview what will be created
terraform apply      # Creates EC2, security group, Elastic IP (type 'yes' to confirm)
```

Terraform will output your public IP and SSH command:

```
Outputs:
  instance_id  = "i-0abc123def456"
  public_ip    = "13.54.xxx.xxx"
  ssh_command  = "ssh -i ~/.ssh/your-key.pem ubuntu@13.54.xxx.xxx"
  site_url     = "http://13.54.xxx.xxx"
```

### Step 4 — Verify Nginx is running

```bash
# SSH in using the output command
ssh -i ~/.ssh/your-key.pem ubuntu@<public_ip>

# Check Nginx status
sudo systemctl status nginx

# Check bootstrap log
cat /var/log/setup.log
```

Visit `http://<public_ip>` in your browser — you should see the site.

### Step 5 — Fix web root permissions

```bash
# Allow the ubuntu user to write to the Nginx web root (required for CI/CD rsync)
sudo chown -R ubuntu:ubuntu /var/www/html
```

### Step 6 — Configure GitHub Actions secrets

In your GitHub repo: **Settings → Secrets and variables → Actions → New repository secret**

| Secret name | Value |
|---|---|
| `EC2_SSH_KEY` | Your `.pem` file contents, base64-encoded: `base64 -w 0 your-key.pem` |
| `EC2_HOST` | Your Elastic IP (from Terraform output) |
| `EC2_USER` | `ubuntu` |

Now push any change to `site/index.html` — the GitHub Action will automatically deploy it.

---

### Step 7 — Enable HTTPS (Stretch Goal)

> Requires a domain name pointed at your Elastic IP via Route 53 (Terraform handles the DNS record if `domain_name` is set).

```bash
# SSH into the instance
ssh -i ~/.ssh/your-key.pem ubuntu@<public_ip>

# Run Certbot — replaces the HTTP Nginx config with an HTTPS one
sudo certbot --nginx -d yourdomain.com

# Test auto-renewal
sudo certbot renew --dry-run
```

Certbot installs a systemd timer that auto-renews the certificate before it expires.

---

### Tear Down

```bash
cd terraform
terraform destroy   # Removes ALL provisioned resources (EC2, EIP, security group)
```

> ⚠️ Always destroy when done experimenting — Elastic IPs incur a small charge when not attached.

---

## How It Works — Interview Explainer

### What is EC2?

EC2 (Elastic Compute Cloud) is AWS's virtual machine service. You rent a server that runs in AWS's data centre — you choose the OS (Ubuntu here), CPU/RAM (t3.micro = 2 vCPU, 1 GB RAM), and storage. It's "elastic" because you can resize it or spin up hundreds more in minutes.

### What is a Security Group?

A security group is a virtual firewall for your EC2 instance. It controls which network traffic is allowed in (ingress) and out (egress) based on port, protocol, and source IP. This project opens:
- **Port 22** — SSH access (for admin and CI/CD deploys)
- **Port 80** — HTTP traffic
- **Port 443** — HTTPS traffic

In production, you'd restrict port 22 to a specific IP range instead of `0.0.0.0/0`.

### What is an Elastic IP?

By default, an EC2 instance gets a new public IP every time it stops and starts. An Elastic IP is a static IP address you reserve in AWS and attach to your instance — it stays the same across reboots. Essential for DNS (you can't point a domain at an IP that keeps changing).

### What is Terraform?

Terraform is an Infrastructure-as-Code (IaC) tool. Instead of clicking through the AWS console, you write `.tf` files describing what resources you want — Terraform figures out what to create, modify, or destroy. The key workflow is:
1. `terraform init` — downloads the AWS provider plugin
2. `terraform plan` — diffs your code against real AWS state, shows what will change
3. `terraform apply` — makes those changes

Terraform tracks what it created in a **state file** (`terraform.tfstate`). This project uses local state — in production you'd store it in S3 so a team can share it.

### What does user_data / setup.sh do?

`user_data` is a script passed to EC2 that runs automatically as root on the **first boot only**, via a service called `cloud-init`. This project uses it to install Nginx and Certbot so the server is ready to serve traffic without any manual SSH. Subsequent deployments are handled by CI/CD — not `user_data`.

### What does the CI/CD pipeline do?

Every push to `main` that modifies `site/` triggers the GitHub Actions workflow:
1. Checks out the code
2. Writes the SSH private key from a GitHub Secret to a temp file
3. Uses `rsync` to sync the `site/` directory to `/var/www/html/` on the EC2 instance
4. SSHs in and runs `sudo systemctl reload nginx`

This means you never manually copy files to the server — Git is the source of truth.

### What is Route 53?

Route 53 is AWS's DNS service. A DNS A record maps a domain name (e.g. `yourdomain.com`) to an IP address (your Elastic IP). Terraform creates this record automatically when `domain_name` is set.

### What is Let's Encrypt / Certbot?

Let's Encrypt is a free Certificate Authority that issues TLS certificates for HTTPS. Certbot is the tool that automates requesting, installing, and renewing those certificates. It modifies the Nginx config to redirect HTTP → HTTPS and serve traffic over TLS.

---

## What I'd Do Next (Production Improvements)

- **Remote Terraform state** — move `tfstate` to an S3 bucket with DynamoDB locking so teams can collaborate without conflicts
- **Restrict SSH** — change security group port 22 to your office/VPN CIDR instead of `0.0.0.0/0`
- **CloudFront CDN** — put CloudFront in front of EC2 for caching, DDoS protection, and global edge delivery
- **ALB + Auto Scaling** — replace single EC2 with an Application Load Balancer + Auto Scaling Group for high availability
- **S3 Static Hosting** — for a truly static site, S3 + CloudFront is cheaper and more scalable than running EC2 24/7
- **IAM roles** — instead of storing AWS credentials in GitHub Secrets, use GitHub Actions OIDC to assume an IAM role directly (no long-lived keys)

---

*Deployed in AWS ap-southeast-2 (Sydney) — built as part of the [roadmap.sh EC2 Instance project](https://roadmap.sh/projects/ec2-instance)*
