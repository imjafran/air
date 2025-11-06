#!/bin/bash

# Air Docker Deployment Script
# Usage: ./deploy-docker.sh [server-ip-or-domain]

set -e

SERVER=$1
if [ -z "$SERVER" ]; then
    echo "Usage: ./deploy-docker.sh [server-ip-or-domain]"
    echo "Example: ./deploy-docker.sh air.arraystory.com"
    exit 1
fi

echo "🚀 Deploying Air (Docker) to $SERVER..."

# Create deployment archive
echo "📦 Creating deployment package..."
tar -czf air-deploy.tar.gz \
    --exclude='node_modules' \
    --exclude='mysql' \
    --exclude='certbot' \
    --exclude='.git' \
    --exclude='*.log' \
    --exclude='air-deploy.tar.gz' \
    --exclude='air' \
    --exclude='*.sh' \
    .

# Upload to server
echo "📤 Uploading files to server..."
scp air-deploy.tar.gz ubuntu@$SERVER:~/

# Connect and deploy
echo "🔧 Setting up on server..."
ssh ubuntu@$SERVER << 'ENDSSH'
    set -e

    # Create air directory
    mkdir -p ~/air
    cd ~/air

    # Extract files
    tar -xzf ~/air-deploy.tar.gz
    rm ~/air-deploy.tar.gz

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo "📦 Installing Docker..."

        # Update system
        sudo apt update

        # Install Docker
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        rm get-docker.sh

        # Add user to docker group
        sudo usermod -aG docker $USER

        # Install Docker Compose
        sudo apt install -y docker-compose-plugin

        echo "✅ Docker installed"
        echo ""
        echo "⚠️  IMPORTANT: You need to log out and back in for Docker permissions"
        echo "Then run this script again:"
        echo "  ssh ubuntu@$(hostname -I | awk '{print $1}')"
        echo "  cd ~/air"
        echo "  docker compose up -d"
        exit 0
    fi

    # Check if .env exists
    if [ ! -f .env ]; then
        echo "⚙️  Creating environment file..."

        # Generate random passwords
        ROOT_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        USER_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

        cat > .env << EOF
MYSQL_ROOT_PASSWORD=$ROOT_PASS
MYSQL_DATABASE=air_production
MYSQL_USER=air_user
MYSQL_PASSWORD=$USER_PASS
EOF

        echo "✅ Environment file created with random passwords"
    fi

    # Get domain for initial setup
    DOMAIN=$(hostname -f 2>/dev/null || hostname -I | awk '{print $1}')
    API_TOKEN=$(openssl rand -hex 32)

    # Create init SQL file
    cat > init-data.sql << EOF
INSERT INTO air_rooms (name, description, is_active) VALUES ('demo', 'Production demo room', TRUE) ON DUPLICATE KEY UPDATE name=name;
INSERT INTO air_room_domains (room_id, domain) VALUES (1, '$DOMAIN'), (1, 'localhost') ON DUPLICATE KEY UPDATE domain=domain;
INSERT INTO air_api_tokens (token, room_id, name, is_active) VALUES ('$API_TOKEN', 1, 'Production API Token', TRUE) ON DUPLICATE KEY UPDATE token=token;
EOF

    # Start Docker containers
    echo "🐳 Starting Docker containers..."
    docker compose -f docker-compose.prod.yml down 2>/dev/null || true
    docker compose -f docker-compose.prod.yml up -d --build

    # Wait for MySQL to be ready
    echo "⏳ Waiting for MySQL to be ready..."
    for i in {1..30}; do
        if docker compose -f docker-compose.prod.yml exec -T mysql mysqladmin ping -h localhost --silent 2>/dev/null; then
            echo "✅ MySQL is ready"
            break
        fi
        sleep 2
    done

    # Load initial data
    echo "📊 Loading initial data..."
    sleep 3
    docker compose -f docker-compose.prod.yml exec -T mysql mysql -u root -p"$(grep MYSQL_ROOT_PASSWORD .env | cut -d= -f2)" air_production < init-data.sql 2>/dev/null || true
    rm init-data.sql

    echo ""
    echo "✅ Deployment complete!"
    echo ""
    echo "========================================="
    echo "  Important Information"
    echo "========================================="
    echo ""
    echo "Domain: $DOMAIN"
    echo "API Token: $API_TOKEN"
    echo ""
    echo "Access Adminer (Database UI):"
    echo "  http://$DOMAIN:8283"
    echo "  Server: mysql"
    echo "  Username: air_user"
    echo "  Password: (check .env file)"
    echo ""
    echo "Save this information!"
    echo ""
    echo "========================================="
    echo "  Management Commands"
    echo "========================================="
    echo ""
    echo "View logs:"
    echo "  docker compose -f docker-compose.prod.yml logs -f"
    echo ""
    echo "Restart services:"
    echo "  docker compose -f docker-compose.prod.yml restart"
    echo ""
    echo "Stop services:"
    echo "  docker compose -f docker-compose.prod.yml down"
    echo ""
    echo "Check status:"
    echo "  docker compose -f docker-compose.prod.yml ps"
    echo ""
ENDSSH

# Cleanup
rm air-deploy.tar.gz

echo ""
echo "✨ Deployment finished!"
echo "🌐 Visit: http://$SERVER/"
echo ""
