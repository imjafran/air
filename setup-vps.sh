#!/bin/bash

# Air VPS Setup Script
# Run this ON your VPS after git pull

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}     Air - VPS Setup${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

DOMAIN="air.arraystory.com"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Installing Docker...${NC}"

    # Update system
    sudo apt update -qq

    # Install Docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh

    # Add user to docker group
    sudo usermod -aG docker $USER

    # Install Docker Compose plugin
    sudo apt install -y docker-compose-plugin

    echo -e "${GREEN}✓ Docker installed${NC}"
    echo ""
    echo -e "${YELLOW}IMPORTANT: Log out and back in for Docker permissions to take effect${NC}"
    echo "Then run this script again."
    echo ""
    exit 0
else
    echo -e "${GREEN}✓ Docker already installed${NC}"
fi

# Create .env if not exists
if [ ! -f .env ]; then
    echo ""
    echo -e "${YELLOW}Creating environment file...${NC}"

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

    echo -e "${GREEN}✓ Environment file created with secure passwords${NC}"
    echo "  Saved in: .env"
else
    echo -e "${GREEN}✓ Using existing .env file${NC}"
fi

# Stop existing containers if running
echo ""
echo -e "${YELLOW}Stopping any existing containers...${NC}"
docker compose -f docker-compose.prod.yml down 2>/dev/null || true

# Start containers
echo ""
echo -e "${BLUE}Starting Docker containers...${NC}"
docker compose -f docker-compose.prod.yml up -d --build

echo "Waiting for services to start..."
sleep 10

# Wait for MySQL to be ready
echo "Waiting for MySQL to be ready..."
for i in {1..30}; do
    if docker compose -f docker-compose.prod.yml exec -T mysql mysqladmin ping -h localhost --silent 2>/dev/null; then
        echo -e "${GREEN}✓ MySQL is ready${NC}"
        break
    fi
    sleep 2
done

# Initialize database
echo ""
echo -e "${BLUE}Initializing database...${NC}"

# Generate API token
API_TOKEN=$(openssl rand -hex 32)

# Get password from .env
MYSQL_PASS=$(grep MYSQL_ROOT_PASSWORD .env | cut -d= -f2)

# Create initial data SQL
cat > /tmp/init-data.sql << EOSQL
INSERT INTO air_rooms (name, description, is_active)
VALUES ('demo', 'Production demo room', TRUE)
ON DUPLICATE KEY UPDATE name=name;

INSERT INTO air_room_domains (room_id, domain)
VALUES (1, '${DOMAIN}'), (1, 'localhost')
ON DUPLICATE KEY UPDATE domain=domain;

INSERT INTO air_api_tokens (token, room_id, name, is_active)
VALUES ('${API_TOKEN}', 1, 'Production API Token', TRUE)
ON DUPLICATE KEY UPDATE token=token;
EOSQL

# Load initial data
sleep 3
docker compose -f docker-compose.prod.yml exec -T mysql mysql -u root -p"${MYSQL_PASS}" air_production < /tmp/init-data.sql 2>/dev/null || true
rm /tmp/init-data.sql

# Save API token
echo "${API_TOKEN}" > api-token.txt

echo -e "${GREEN}✓ Database initialized${NC}"

# Setup SSL
echo ""
echo -e "${BLUE}SSL Certificate Setup${NC}"
echo ""
echo "Do you want to set up SSL certificate now?"
echo "Requirements: DNS must be pointing to this server"
echo ""
read -p "Set up SSL? (y/n): " SETUP_SSL

if [ "$SETUP_SSL" = "y" ] || [ "$SETUP_SSL" = "Y" ]; then
    echo ""
    read -p "Enter your email for SSL certificate notifications: " SSL_EMAIL

    if [ -n "$SSL_EMAIL" ]; then
        echo "Obtaining SSL certificate for ${DOMAIN}..."

        docker compose -f docker-compose.prod.yml run --rm certbot certonly \
            --webroot \
            --webroot-path=/var/www/certbot \
            -d ${DOMAIN} \
            --email "$SSL_EMAIL" \
            --agree-tos \
            --no-eff-email \
            --non-interactive 2>&1 | grep -v "Saving debug log"

        # Reload nginx
        docker compose -f docker-compose.prod.yml exec nginx nginx -s reload

        echo -e "${GREEN}✓ SSL certificate installed${NC}"
    fi
else
    echo "Skipped SSL setup. You can run it later with: ./setup-ssl.sh"
fi

# Show status
echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}     Setup Complete!${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Check container status
echo "Container Status:"
docker compose -f docker-compose.prod.yml ps

echo ""
echo -e "${GREEN}✓ Air is now running!${NC}"
echo ""
echo "Access your application:"
if [ "$SETUP_SSL" = "y" ] || [ "$SETUP_SSL" = "Y" ]; then
    echo "  🌐 https://${DOMAIN}"
else
    echo "  🌐 http://${DOMAIN}"
    echo "  (SSL not configured - using HTTP)"
fi
echo ""
echo "API Token (save this):"
echo "  ${API_TOKEN}"
echo "  Also saved in: api-token.txt"
echo ""
echo "Useful commands:"
echo "  docker compose -f docker-compose.prod.yml logs -f     # View logs"
echo "  docker compose -f docker-compose.prod.yml ps          # Check status"
echo "  docker compose -f docker-compose.prod.yml restart     # Restart services"
echo "  docker compose -f docker-compose.prod.yml down        # Stop services"
echo ""
echo "Database password saved in: .env"
echo ""
