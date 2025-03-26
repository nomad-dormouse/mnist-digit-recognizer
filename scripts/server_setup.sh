#!/bin/bash
set -e

# Configuration
REMOTE_USER="root"
REMOTE_HOST="37.27.197.79"
SSH_KEY="~/.ssh/hatzner_key"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Setting up server...${NC}"

# Update SSH configuration
ssh -i ${SSH_KEY} ${REMOTE_USER}@${REMOTE_HOST} "bash -s" << 'EOF'
    # Backup original sshd_config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

    # Update SSH configuration
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

    # Restart SSH service
    systemctl restart ssh

    # Install Docker and other dependencies
    apt-get update
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    # Set up Docker repository
    echo \
      "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io

    # Install Docker Compose
    curl -L "https://github.com/docker/compose/releases/download/v2.5.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    # Create ubuntu user and set up permissions
    useradd -m -s /bin/bash ubuntu || true
    usermod -aG docker ubuntu

    echo -e "${GREEN}Server setup completed successfully!${NC}"
EOF

echo -e "${GREEN}Server setup script executed successfully!${NC}" 