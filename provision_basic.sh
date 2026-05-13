#!/bin/bash

set -e

export DEBIAN_FRONTEND=noninteractive

# Install required packages
apt-get update
apt-get install -y \
    ca-certificates \
    curl \
    sqlite3 \
    apache2-utils \
    gnupg \
    lsb-release

# =========================================
# Install Docker (Ubuntu)
# =========================================

# Create keyrings directory
install -m 0755 -d /etc/apt/keyrings

# Add Docker GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc

chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update

# Install Docker packages
apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# =========================================
# Open WebUI setup
# =========================================

mkdir -p /etc/open-webui.d/



# Pull image
/usr/bin/docker pull ghcr.io/open-webui/open-webui:ollama

# First run to initialize DB
/usr/bin/docker run -d \
    -p 3000:8080 \
    -v /etc/open-webui.d:/root/.open_web_ui \
    -v /etc/open-webui.d:/app/backend/data \
    --name openwebui \
    ghcr.io/open-webui/open-webui:ollama

# Wait for startup
timeout 300 bash -c \
'while [[ "$(curl -s -o /dev/null -w "%%{http_code}" localhost:3000)" != "200" ]]; do sleep 5; done' || false

# =========================================
# Wait for Open WebUI DB initialization
# =========================================

until sudo sqlite3 /etc/open-webui.d/webui.db ".tables" | grep -q "auth"; do
    echo "Waiting for Open WebUI database initialization..."
    sleep 2
done

echo "Database initialized"

# =========================================
# Stop temporary container before DB write
# =========================================
sudo docker stop openwebui
sudo docker rm openwebui


# Remove WAL files to avoid SQLite lock issues
sudo rm -f /etc/open-webui.d/webui.db-wal
sudo rm -f /etc/open-webui.d/webui.db-shm

ADMIN_EMAIL="${open_webui_user}"
ADMIN_PASS="$(echo '${open_webui_password_b64}' | base64 -d)"
PASSWD=$(htpasswd -bnBC 10 "" "$ADMIN_PASS" | tr -d ':\n')

# =========================================
# Inject admin user into SQLite DB
# =========================================
sudo tee /etc/open-webui.d/webui.sql > /dev/null << EOF
PRAGMA foreign_keys=OFF;
BEGIN TRANSACTION;

INSERT INTO auth (
    id,
    email,
    password,
    active
)
VALUES (
    '488af2d3-dd38-4310-a549-6d8ad11ae69e',
    '$ADMIN_EMAIL',
    '$PASSWD',
    1
);

INSERT INTO user (
    id,
    name,
    email,
    role,
    profile_image_url,
    created_at,
    updated_at,
    last_active_at
)
VALUES (
    '488af2d3-dd38-4310-a549-6d8ad11ae69e',
    'Admin User',
    '$ADMIN_EMAIL',
    'admin',
    '',
    strftime('%s','now'),
    strftime('%s','now'),
    strftime('%s','now')
);

COMMIT;
EOF

sudo sqlite3 /etc/open-webui.d/webui.db < /etc/open-webui.d/webui.sql

sudo rm -f /etc/open-webui.d/webui.sql

echo "Admin user injected successfully"
# =========================================
# Systemd service
# =========================================

sudo tee /etc/systemd/system/openwebui.service > /dev/null << 'EOF'
[Unit]
Description=Open WebUI
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=0
Type=simple
Restart=always

ExecStartPre=-/usr/bin/docker stop openwebui
ExecStartPre=-/usr/bin/docker rm openwebui

ExecStart=/usr/bin/docker run \
  -p 3000:8080 \
  -e RAG_EMBEDDING_MODEL_AUTO_UPDATE=true \
  -v /etc/open-webui.d:/root/.open_web_ui \
  -v /etc/open-webui.d:/app/backend/data \
  --name openwebui \
  ghcr.io/open-webui/open-webui:ollama

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable openwebui.service
sudo systemctl start openwebui.service