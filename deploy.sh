#!/bin/bash

# Air Deployment Script (No Docker)
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
    --exclude='air-deploy.tar.gz' \
    --exclude='Dockerfile' \
    --exclude='docker-compose*.yml' \
    .

# Upload to server
echo "📤 Uploading files to server..."
scp air-deploy.tar.gz ubuntu@$SERVER:~/

# Connect and deploy
echo "🔧 Setting up on server..."
ssh ubuntu@$SERVER << 'ENDSSH'
    # Create air directory if not exists
    mkdir -p ~/air
    cd ~/air

    # Extract files
    tar -xzf ~/air-deploy.tar.gz
    rm ~/air-deploy.tar.gz

    # Check if this is first time setup
    if ! command -v go &> /dev/null || ! systemctl is-active --quiet air; then
        echo "🔧 Running first-time setup..."
        echo "⚠️  You will be prompted for MySQL passwords"
        chmod +x setup.sh
        ./setup.sh
    else
        echo "🔄 Running update..."
        chmod +x update.sh
        ./update.sh
    fi

    echo "✅ Deployment complete!"
    echo ""
    echo "Check status with:"
    echo "  sudo systemctl status air"
    echo ""
    echo "View logs with:"
    echo "  sudo journalctl -u air -f"
ENDSSH

# Cleanup
rm air-deploy.tar.gz

echo ""
echo "✨ Deployment finished!"
echo "🌐 Visit: http://$SERVER/ (or https:// after SSL setup)"
