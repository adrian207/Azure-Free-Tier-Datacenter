#!/bin/bash
# Guacamole Setup Script for Bastion Host
# Run this on vm-bastion-dev-westus2-001

set -e

echo "=========================================="
echo "Apache Guacamole Setup"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Update system
echo "Step 1: Updating system packages..."
apt-get update
apt-get upgrade -y

echo "✓ System updated"
echo ""

# Install Docker
echo "Step 2: Installing Docker..."
if ! command -v docker &> /dev/null; then
    apt-get install -y ca-certificates curl gnupg lsb-release
    
    # Add Docker's official GPG key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    echo "✓ Docker installed"
else
    echo "✓ Docker already installed"
fi
echo ""

# Install Docker Compose
echo "Step 3: Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo "✓ Docker Compose installed"
else
    echo "✓ Docker Compose already installed"
fi

docker-compose --version
echo ""

# Install Ansible
echo "Step 4: Installing Ansible..."
if ! command -v ansible &> /dev/null; then
    apt-get install -y software-properties-common
    add-apt-repository --yes --update ppa:ansible/ansible
    apt-get install -y ansible
    echo "✓ Ansible installed"
else
    echo "✓ Ansible already installed"
fi

ansible --version
echo ""

# Create Guacamole directory
echo "Step 5: Setting up Guacamole directories..."
GUAC_DIR="/opt/guacamole"
mkdir -p $GUAC_DIR/{init-db,guacamole-config}

# Download Guacamole database initialization script
echo "Downloading Guacamole PostgreSQL schema..."
docker run --rm guacamole/guacamole:latest /opt/guacamole/bin/initdb.sh --postgres > $GUAC_DIR/init-db/initdb.sql

echo "✓ Guacamole directories created"
echo ""

# Copy docker-compose file
echo "Step 6: Deploying Guacamole configuration..."
if [ -f "/home/azureuser/guacamole-compose.yml" ]; then
    cp /home/azureuser/guacamole-compose.yml $GUAC_DIR/docker-compose.yml
    echo "✓ Docker Compose file copied"
else
    echo "Warning: guacamole-compose.yml not found. Please copy it manually to $GUAC_DIR"
fi
echo ""

# Generate secure password
GUAC_DB_PASS=$(openssl rand -base64 32)
echo "GUAC_DB_PASSWORD=$GUAC_DB_PASS" > $GUAC_DIR/.env

echo "Step 7: Starting Guacamole services..."
cd $GUAC_DIR
docker-compose up -d

echo "✓ Guacamole services started"
echo ""

# Wait for services to be ready
echo "Waiting for services to initialize (30 seconds)..."
sleep 30

# Check service status
echo "Step 8: Checking service status..."
docker-compose ps

echo ""
echo "=========================================="
echo "Guacamole Setup Complete!"
echo "=========================================="
echo ""
echo "Access Guacamole at: http://$(curl -s ifconfig.me):8080/guacamole"
echo ""
echo "Default credentials:"
echo "  Username: guacadmin"
echo "  Password: guacadmin"
echo ""
echo "IMPORTANT: Change the default password immediately!"
echo ""
echo "To manage Guacamole:"
echo "  Start:   cd $GUAC_DIR && docker-compose up -d"
echo "  Stop:    cd $GUAC_DIR && docker-compose stop"
echo "  Restart: cd $GUAC_DIR && docker-compose restart"
echo "  Logs:    cd $GUAC_DIR && docker-compose logs -f"
echo ""
echo "Database password stored in: $GUAC_DIR/.env"
echo ""

