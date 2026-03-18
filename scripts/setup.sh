#!/bin/bash
# setup.sh — EC2 bootstrap script (runs once on first boot via user_data)
# This script is executed as root by cloud-init.

set -euo pipefail

LOG_FILE="/var/log/setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[$(date)] Starting EC2 bootstrap..."

# -------------------------------------------------------
# 1. System update
# -------------------------------------------------------
apt-get update -y
apt-get upgrade -y

# -------------------------------------------------------
# 2. Install Nginx
# -------------------------------------------------------
apt-get install -y nginx
systemctl enable nginx
systemctl start nginx

echo "[$(date)] Nginx installed and started."

# -------------------------------------------------------
# 3. Deploy the static site
# The CI/CD pipeline (deploy.yml) owns all subsequent deploys.
# This just puts a placeholder so Nginx serves something on first boot.
# -------------------------------------------------------
NGINX_ROOT="/var/www/html"

cat > "$NGINX_ROOT/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>Deploying...</title>
</head>
<body>
  <h1>Site is being deployed via CI/CD. Check back in a moment.</h1>
</body>
</html>
EOF

# -------------------------------------------------------
# 4. Install Certbot for HTTPS (Let's Encrypt)
# HTTPS activation is a manual step — run after DNS is pointed at this server:
#   sudo certbot --nginx -d yourdomain.com
# Certbot auto-renew is configured via systemd timer (installed with snap).
# -------------------------------------------------------
snap install --classic certbot
ln -sf /snap/bin/certbot /usr/bin/certbot

echo "[$(date)] Certbot installed. Run: sudo certbot --nginx -d <your-domain>"

# -------------------------------------------------------
# 5. Harden Nginx — hide version from response headers
# -------------------------------------------------------
sed -i 's/# server_tokens off;/server_tokens off;/' /etc/nginx/nginx.conf
nginx -t && systemctl reload nginx

echo "[$(date)] Bootstrap complete. Nginx is live."
