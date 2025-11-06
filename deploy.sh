#!/bin/bash

# Air Deployment Script for AWS Lightsail
# Usage: ./deploy.sh [server-ip-or-domain]

set -e

SERVER=$1
if [ -z "$SERVER" ]; then
    echo "Usage: ./deploy.sh [server-ip-or-domain]"
    echo "Example: ./deploy.sh air.arraystory.com"
    exit 1
fi

echo "🚀 Deploying Air to $SERVER..."

# Create deployment archive
echo "📦 Creating deployment package..."
tar -czf air-deploy.tar.gz \
    --exclude='node_modules' \
    --exclude='mysql' \
    --exclude='certbot' \
    --exclude='.git' \
    --exclude='*.log' \
    --exclude='*.bak*' \
    --exclude='*.temp' \
    .

# Upload to server
echo "📤 Uploading files to server..."
scp air-deploy.tar.gz ubuntu@$SERVER:~/

# Connect and deploy
echo "🔧 Setting up on server..."
ssh ubuntu@$SERVER << 'ENDSSH'
    # Extract files
    cd ~
    tar -xzf air-deploy.tar.gz
    rm air-deploy.tar.gz

    # Set up environment if not exists
    if [ ! -f .env ]; then
        echo "⚙️  Setting up environment file..."
        cp .env.production .env
        echo "⚠️  IMPORTANT: Edit ~/.env with production passwords!"
    fi

    # Build and start
    echo "🐳 Starting Docker containers..."
    docker compose -f docker-compose.prod.yml up -d --build

    echo "✅ Deployment complete!"
    echo ""
    echo "Check status with:"
    echo "  docker compose -f docker-compose.prod.yml ps"
    echo ""
    echo "View logs with:"
    echo "  docker compose -f docker-compose.prod.yml logs -f"
ENDSSH

# Cleanup
rm air-deploy.tar.gz

echo ""
echo "✨ Deployment finished!"
echo "🌐 Visit: https://$SERVER/"
