#!/bin/bash

# Air - AWS Lightsail Deployment Script
# Simple one-command deployment with Docker

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DOMAIN="air.arraystory.com"
SERVER_USER="ubuntu"

# Banner
echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}     Air - Lightsail Deployment${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Check if SERVER_IP is provided
if [ -z "$1" ]; then
    echo -e "${YELLOW}Usage: ./deploy-lightsail.sh <server-ip>${NC}"
    echo ""
    echo "Example:"
    echo "  ./deploy-lightsail.sh 54.123.45.67"
    echo ""
    exit 1
fi

SERVER_IP=$1

echo "Domain: ${DOMAIN}"
echo "Server: ${SERVER_IP}"
echo ""

# Confirmation
echo -e "${YELLOW}This will deploy Air to your Lightsail server.${NC}"
echo "Press Enter to continue, or Ctrl+C to cancel..."
read

# Step 1: Create deployment package
echo ""
echo -e "${BLUE}[1/6]${NC} Creating deployment package..."
tar -czf air-deploy.tar.gz \
    --exclude='node_modules' \
    --exclude='mysql' \
    --exclude='certbot' \
    --exclude='.git' \
    --exclude='*.log' \
    --exclude='air-deploy.tar.gz' \
    --exclude='air' \
    . 2>/dev/null

echo -e "${GREEN}✓ Package created${NC}"

# Step 2: Upload to server
echo ""
echo -e "${BLUE}[2/6]${NC} Uploading files to server..."
scp -o StrictHostKeyChecking=no air-deploy.tar.gz ${SERVER_USER}@${SERVER_IP}:~/
echo -e "${GREEN}✓ Files uploaded${NC}"

# Step 3: Deploy on server
echo ""
echo -e "${BLUE}[3/6]${NC} Setting up server..."

ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${SERVER_IP} bash << 'ENDSSH'
set -e

# Colors for remote
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Create directory
mkdir -p ~/air
cd ~/air

# Extract files
echo "Extracting files..."
tar -xzf ~/air-deploy.tar.gz
rm ~/air-deploy.tar.gz

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Installing Docker...${NC}"

    # Update system
    sudo apt update -qq

    # Install Docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh > /dev/null 2>&1
    rm get-docker.sh

    # Add user to docker group
    sudo usermod -aG docker $USER

    # Install Docker Compose plugin
    sudo apt install -y docker-compose-plugin -qq

    echo -e "${GREEN}✓ Docker installed${NC}"

    # Need to re-login for docker group
    echo -e "${YELLOW}Note: Docker installed. Group membership will be active after this script.${NC}"
else
    echo -e "${GREEN}✓ Docker already installed${NC}"
fi

# Create .env if not exists
if [ ! -f .env ]; then
    echo "Creating environment file..."

    # Generate secure random passwords
    ROOT_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    USER_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)

    cat > .env << EOF
# Generated on $(date)
MYSQL_ROOT_PASSWORD=${ROOT_PASS}
MYSQL_DATABASE=air_production
MYSQL_USER=air_user
MYSQL_PASSWORD=${USER_PASS}
EOF

    echo -e "${GREEN}✓ Environment configured with secure passwords${NC}"
else
    echo -e "${GREEN}✓ Using existing .env file${NC}"
fi

echo -e "${GREEN}✓ Server setup complete${NC}"
ENDSSH

# Step 4: Start Docker containers
echo ""
echo -e "${BLUE}[4/6]${NC} Starting Docker containers..."

ssh ${SERVER_USER}@${SERVER_IP} bash << 'ENDSSH'
set -e

cd ~/air

# Use newgrp to get docker group permissions
sudo -u $USER bash << 'DOCKER_COMMANDS'
cd ~/air

# Stop existing containers
docker compose -f docker-compose.prod.yml down 2>/dev/null || true

# Pull images and start
docker compose -f docker-compose.prod.yml pull -q
docker compose -f docker-compose.prod.yml up -d --build

echo "Waiting for services to start..."
sleep 10

# Check if containers are running
docker compose -f docker-compose.prod.yml ps

DOCKER_COMMANDS

ENDSSH

echo -e "${GREEN}✓ Containers started${NC}"

# Step 5: Initialize database
echo ""
echo -e "${BLUE}[5/6]${NC} Initializing database..."

ssh ${SERVER_USER}@${SERVER_IP} bash << 'ENDSSH'
set -e

cd ~/air

# Generate API token
API_TOKEN=$(openssl rand -hex 32)

# Wait for MySQL to be fully ready
echo "Waiting for MySQL to be ready..."
for i in {1..30}; do
    if docker compose -f docker-compose.prod.yml exec -T mysql mysqladmin ping -h localhost --silent 2>/dev/null; then
        break
    fi
    sleep 2
done

# Get password from .env
MYSQL_PASS=$(grep MYSQL_ROOT_PASSWORD .env | cut -d= -f2)

# Create initial data SQL
cat > init-data.sql << EOSQL
INSERT INTO air_rooms (name, description, is_active)
VALUES ('demo', 'Production demo room', TRUE)
ON DUPLICATE KEY UPDATE name=name;

INSERT INTO air_room_domains (room_id, domain)
VALUES (1, 'air.arraystory.com'), (1, 'localhost')
ON DUPLICATE KEY UPDATE domain=domain;

INSERT INTO air_api_tokens (token, room_id, name, is_active)
VALUES ('${API_TOKEN}', 1, 'Production API Token', TRUE)
ON DUPLICATE KEY UPDATE token=token;
EOSQL

# Load initial data
sleep 3
docker compose -f docker-compose.prod.yml exec -T mysql mysql -u root -p"${MYSQL_PASS}" air_production < init-data.sql 2>/dev/null || true

# Save API token
echo "${API_TOKEN}" > api-token.txt

echo -e "${GREEN}✓ Database initialized${NC}"

ENDSSH

echo -e "${GREEN}✓ Database ready${NC}"

# Step 6: Setup SSL
echo ""
echo -e "${BLUE}[6/6]${NC} Setting up SSL certificate..."

ssh ${SERVER_USER}@${SERVER_IP} bash << ENDSSH
set -e

cd ~/air

# Read your email for Let's Encrypt
echo ""
echo -e "${YELLOW}Enter your email for SSL certificate notifications:${NC}"
read -p "Email: " SSL_EMAIL

if [ -z "\$SSL_EMAIL" ]; then
    echo "Skipping SSL setup (no email provided)"
    echo "You can set it up later with: ./setup-ssl.sh"
else
    echo "Obtaining SSL certificate for air.arraystory.com..."

    # Request certificate
    docker compose -f docker-compose.prod.yml run --rm certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        -d air.arraystory.com \
        --email "\$SSL_EMAIL" \
        --agree-tos \
        --no-eff-email \
        --non-interactive 2>&1 | grep -v "Saving debug log"

    # Reload nginx
    docker compose -f docker-compose.prod.yml exec nginx nginx -s reload

    echo -e "${GREEN}✓ SSL certificate installed${NC}"
fi

ENDSSH

# Cleanup
rm -f air-deploy.tar.gz

# Get API token
echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}     Deployment Complete!${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

API_TOKEN=$(ssh ${SERVER_USER}@${SERVER_IP} "cat ~/air/api-token.txt 2>/dev/null || echo 'Not found'")

echo -e "${GREEN}✓ Air is now running!${NC}"
echo ""
echo "Access your application:"
echo "  🌐 https://air.arraystory.com"
echo ""
echo "API Token (save this):"
echo "  ${API_TOKEN}"
echo ""
echo "Useful commands (run on server):"
echo "  cd ~/air"
echo "  docker compose -f docker-compose.prod.yml logs -f     # View logs"
echo "  docker compose -f docker-compose.prod.yml ps          # Check status"
echo "  docker compose -f docker-compose.prod.yml restart     # Restart"
echo "  docker compose -f docker-compose.prod.yml down        # Stop"
echo ""
echo "Database password saved in: ~/air/.env"
echo ""
